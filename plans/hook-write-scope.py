#!/usr/bin/env python3
"""机械写盘护栏（hooks 拦截层）——PreToolUse 命令钩子，命中黑名单即阻断该次工具调用。

用法：
  python3 plans/hook-write-scope.py -h        # 打印本用法块（rc=0）
  echo '<hook JSON>' | python3 plans/hook-write-scope.py    # 由 hooks 桥按 PreToolUse 调用
  python3 plans/hook-write-scope.py --fixture <载荷文件>     # 从文件读载荷（自检/人工复现用）
  钩子配置见 `plans/hooks/hooks.json`（Claude Code 兼容），经
  `@deepseek-ai/dsh-hooks-claude-code` 挂载（`agent.cordis.yml` 的 `hooks-write-scope` 条目）。

退出码: 0=放行（含无法判定写入目标）；2=阻断（stderr 即回给模型的理由）
依赖：python3（标准库；无第三方包）
模式：默认 `deny`＝黑名单阻断（系统路径 / 凭据目录 / 用户平面 DSH 配置 / 主目录顶层散落文件）；
      `DSH_CODEPUNK_HOOK_MODE=strict`＝白名单放行（只许预设仓库根、`~/.dsh-codepunk/**`、
      `${TMPDIR}` 与 `/tmp`、会话 cwd 之下），其余一律阻断。取值非法时按 deny 处理并告警。
输入（stdin，Claude Code 同形载荷）：`{session_id, cwd, hook_event_name, tool_name, tool_input}`；
      `write`/`edit` 取 `tool_input.file_path`；`bash`/`pwsh` 用命令文本启发式抽取写入目标。
环境变量：`DSH_CODEPUNK_HOOK_MODE`（模式开关，见上）；`CLAUDE_PLUGIN_ROOT`（预设根，由桥按
      `pluginRoot` 注入，作白名单根与 `~/.dsh-codepunk/**` 的宿主）；`CLAUDE_PROJECT_DIR`
      （会话 cwd，由桥注入，作 strict 白名单根）；`TMPDIR`（临时区白名单根，缺省 `/tmp`）；
      `HOME`（黑名单与白名单的锚点；缺省取 `os.path.expanduser`）。

启发式局限声明（MUST 知悉，护栏不是证明）：
  ① 只覆盖**可判定**的写入目标。`bash`/`pwsh` 侧靠命令文本启发式抽取（重定向、`tee`/`cp`/`mv`/
     `rm`/`sed -i`/`install` 等目标位、PowerShell 写 cmdlet），**混淆写法可规避**（变量拼接、
     `eval`、`$'\x2f'`、base64 解码后执行、经解释器间接写盘等），故非沙箱、非安全边界。
  ② 不做路径规范化外的符号链接解析：指向黑名单的**符号链接**按其字面路径判定。
  ③ 仅拦工具调用层，拦不住工具内派生进程的任意写（如 `python3 -c` 内部 open 写盘）。
  ④ 定位是「宿主层沙箱 → 预设层三层纪律 → 拦截层 hooks」的**最内一层机械拦网**，
     与 `plans/write-scope-check.sh`（事后扫描）互补；未命中即放行**不等于**合规。
  判据权威与层级关系见 `skills/dsh-codepunk-workflow/references/file-hygiene.md` §六/§八。
"""
import json
import os
import posixpath
import re
import sys

EXIT_ALLOW = 0   # 放行
EXIT_BLOCK = 2   # 阻断（stderr 为理由，回给模型）

USAGE_LINES = (3, 31)   # 用法块行区间（1-based，含端点）——`-h` 逐行打印（不含首尾引号行）
# ── 系统路径（`/var` 单独处理：排除 macOS TMPDIR 实际落点 `/var/folders`）────────
SYS_DENY = ("/etc", "/usr", "/bin", "/sbin", "/System", "/Library", "/boot", "/opt")
VAR_DENY = "/var"
VAR_TMP_EXEMPT = "/var/folders"      # macOS `TMPDIR` 实际落点：不得误拦
CRED_REL = (".ssh", ".aws", ".gnupg")   # 凭据目录（相对 $HOME）
DSH_USER_REL = (".dsh", "profiles")     # 用户平面 DSH 配置：~/.dsh/profiles/**（MUST NOT 擅改）
TMP_FALLBACK = "/tmp"

# ── 命令文本启发式（bash/pwsh）───────────────────────────────────────────────
SHELL_TOOLS = ("bash", "pwsh", "shell", "sh", "zsh")
SHELL_WRITE_CMDS = (
    "tee", "cp", "mv", "install", "touch", "mkdir", "rmdir", "rm", "truncate", "dd",
    "chmod", "chown", "ln", "rsync", "sed",
)
PS_WRITE_CMDS = (
    "set-content", "add-content", "out-file", "new-item", "remove-item", "copy-item",
    "move-item", "rename-item", "clear-content", "tee-object", "set-itemproperty",
    "new-itemproperty",
)
# 重定向：`> path` / `>> path` / `2> path` / `&> path`（引号可选；含 PowerShell 的 `>`）
REDIR_RE = re.compile(r"(?:[0-9]|&)?>>?\s*(?P<q>['\"]?)(?P<path>[^\s'\"|;&<>()]+)(?P=q)")
# `sed -i[SUFFIX] [EXPR] FILE`：就地改写，目标在**末位**（表达式可能含空格，故取行尾 token）
SED_I_RE = re.compile(r"\bsed\b[^|;&]*?\s-i(?:\s*[A-Za-z]*)?\s+(?P<rest>.+)$")
# 写入型命令的目标位（大小写不敏感：PowerShell cmdlet 为 `Set-Content` 驼峰形）
CMD_TAIL_RE = re.compile(
    r"\b(?P<cmd>" + "|".join(SHELL_WRITE_CMDS) + r")\b(?P<rest>[^|;&\n]*)", re.IGNORECASE)
PS_CMD_RE = re.compile(
    r"\b(?P<cmd>" + "|".join(PS_WRITE_CMDS) + r")\b(?P<rest>[^|;&\n]*)", re.IGNORECASE)
# 位置参数（PowerShell 的 `-Path x` / `-LiteralPath x` / `-Destination x`）
NAMED_PATH_RE = re.compile(
    r"-(?:Path|LiteralPath|Destination|FilePath|OutFile|Name)\s+(?P<q>['\"]?)(?P<path>[^\s'\"]+)(?P=q)",
    re.IGNORECASE)
# 值像路径的判据（用于尾随 token 过滤，防把 `-rf`/表达式当路径）
PATHISH_RE = re.compile(r"[~/.]|/")
SKIP_TOKEN = ("-", "/dev/null", "/dev/stdout", "/dev/stderr", "nul", "NUL")


def usage() -> None:
    """打印头部用法块（与文件头注释同源）。"""
    try:
        with open(__file__, encoding="utf-8") as fh:
            lines = fh.read().split("\n")
    except OSError:
        return
    start, end = USAGE_LINES
    for line in lines[start - 1:end]:
        print(line)


def env_mode() -> str:
    """读模式开关；非法取值按 deny 处理并告警（fail-safe）。"""
    raw = (os.environ.get("DSH_CODEPUNK_HOOK_MODE") or "").strip().lower()
    if raw == "":
        return "deny"
    if raw in ("deny", "strict"):
        return raw
    sys.stderr.write(
        "hook-write-scope: 未知模式 DSH_CODEPUNK_HOOK_MODE=%r（可用 deny|strict），按 deny 处理\n" % raw)
    return "deny"


def home_dir() -> str:
    """$HOME（黑名单锚点）；缺省回退 expanduser。"""
    return posixpath.normpath(os.environ.get("HOME") or os.path.expanduser("~"))


def plugin_root() -> str:
    """预设仓库根（`${CLAUDE_PLUGIN_ROOT}`，由桥按 pluginRoot 注入）；未注入时为空串。"""
    v = (os.environ.get("CLAUDE_PLUGIN_ROOT") or "").strip()
    return posixpath.normpath(v) if v else ""


def cwd_of(payload: dict) -> str:
    """会话 cwd：载荷 `cwd` 优先，其次 `${CLAUDE_PROJECT_DIR}`，最后进程 cwd。"""
    c = payload.get("cwd")
    if not isinstance(c, str) or not c.strip():
        c = os.environ.get("CLAUDE_PROJECT_DIR") or os.getcwd()
    return posixpath.normpath(c)


def allow_roots(payload: dict) -> list:
    """白名单根（永远放行；strict 模式下是唯一放行集）。"""
    home = home_dir()
    roots = [
        home + "/.dsh-codepunk",      # 总库（运行根、worktrees、knowledge）
        home + "/.dsh/.agent-presets",  # 预设源（本任务写集所在）
        os.environ.get("TMPDIR") or TMP_FALLBACK,
        TMP_FALLBACK,
        cwd_of(payload),
    ]
    pr = plugin_root()
    if pr:
        roots.append(pr)             # 预设仓库根
    out = []
    for r in roots:
        if not r:
            continue
        n = posixpath.normpath(r)
        if n not in out:
            out.append(n)
    return out


def abs_path(raw: str, cwd: str) -> str:
    """把候选路径字面量解析为绝对路径（展开 `~`，相对路径按会话 cwd）。"""
    p = raw.strip().strip("'\"")
    if not p:
        return ""
    if p.startswith("~"):
        p = home_dir() + p[1:]
    if not p.startswith("/"):
        p = posixpath.join(cwd, p)
    return posixpath.normpath(p)


def under(path: str, root: str) -> bool:
    """path 是否在 root 之下（含 root 自身）；root 为空或 `/` 时按不覆盖处理。"""
    if not root or root == "/":
        return False
    return path == root or path.startswith(root.rstrip("/") + "/")


def unquote(tok: str) -> str:
    return tok.strip().strip("'\"").strip()


def candidates_from_command(command: str) -> list:
    """从命令文本启发式抽取写入目标（原样字面量，未解析为绝对路径）。"""
    out = []

    def add(tok: str) -> None:
        t = unquote(tok)
        if t and t not in SKIP_TOKEN and not t.startswith("$") and not t.startswith("%"):
            out.append(t)

    for m in REDIR_RE.finditer(command):
        add(m.group("path"))
    for m in SED_I_RE.finditer(command):
        toks = m.group("rest").split()
        if toks:
            add(toks[-1])
    for rx in (CMD_TAIL_RE, PS_CMD_RE):
        for m in rx.finditer(command):
            cmd = m.group("cmd").lower()
            rest = m.group("rest")
            for nm in NAMED_PATH_RE.finditer(rest):
                add(nm.group("path"))
            rest_wo_named = NAMED_PATH_RE.sub(" ", rest)
            toks = [t for t in rest_wo_named.split() if not t.startswith("-")]
            if not toks:
                continue
            if cmd == "sed":
                continue                       # sed 无 -i 时按只读处理（避免表达式误判）
            if cmd in ("dd",):
                continue                       # dd 目标写作 of=…，非位置参数
            if cmd == "ln":
                add(toks[-1])                  # 末位为链接名
            elif cmd in ("cp", "mv", "install", "rsync"):
                add(toks[-1])                  # 末位为目标位
            else:
                add(toks[0])                   # 首位为目标位（tee/touch/mkdir/rm/chmod/…）
    for m in re.finditer(r"\bdd\b[^|;&\n]*?\bof=(?P<q>['\"]?)(?P<path>[^\s'\"]+)(?P=q)", command):
        add(m.group("path"))
    return out


def candidates_from_payload(tool: str, tool_input: dict, cwd: str) -> list:
    """按工具类型抽取候选写入目标（已解析为绝对路径；顺序即发现顺序）。"""
    t = tool.strip().lower()
    if t in ("write", "edit", "multiedit", "multi_edit", "apply_patch", "notebookedit", "str_replace_editor"):
        raw = tool_input.get("file_path") or tool_input.get("path") or tool_input.get("notebook_path")
        return [abs_path(raw, cwd)] if isinstance(raw, str) and raw.strip() else []
    if t in SHELL_TOOLS:
        cmd = tool_input.get("command")
        if not isinstance(cmd, str) or not cmd.strip():
            return []
        return [abs_path(x, cwd) for x in candidates_from_command(cmd)]
    return []


def deny_rule(path: str) -> str:
    """黑名单判据（deny 模式阻断集）；未命中返回空串。规则名随理由回给模型。"""
    home = home_dir()
    if any(under(path, s) for s in SYS_DENY):
        return "系统路径"
    if under(path, VAR_DENY) and not under(path, VAR_TMP_EXEMPT):
        return "系统路径（/var，已排除 /var/folders）"
    for rel in CRED_REL:
        if under(path, home + "/" + rel):
            return "凭据目录"
    if under(path, posixpath.join(home, *DSH_USER_REL)):
        return "用户平面 DSH 配置"
    # 主目录顶层散落文件：`$HOME/<名字>` 且该路径不是已有目录（深度 1；对应既有 G2 判据）
    if posixpath.dirname(path) == home and not os.path.isdir(path):
        return "主目录顶层散落文件"
    return ""


def strict_allowed(path: str, roots: list) -> bool:
    """strict 模式：只放行白名单根之下的写入。"""
    return any(under(path, r) for r in roots)


def main() -> int:
    argv = sys.argv[1:]
    if argv and argv[0] in ("-h", "--help", "help"):
        usage()
        return EXIT_ALLOW

    mode = env_mode()
    # `--fixture <文件>`：从文件读载荷而非 stdin——供存活自检（M164）与人工复现使用。
    raw = ""
    if len(argv) >= 2 and argv[0] == "--fixture":
        try:
            with open(argv[1], encoding="utf-8") as fh:
                raw = fh.read()
        except OSError as exc:
            sys.stderr.write(
                "hook-write-scope: 无法读取夹具 %s（%s），未能判定写入目标，按放行处理"
                "（护栏为启发式，不是证明）\n" % (argv[1], exc))
            return EXIT_ALLOW
    else:
        raw = sys.stdin.read()
    if not raw.strip():
        sys.stderr.write(
            "hook-write-scope: stdin 为空，未能判定写入目标，按放行处理（护栏为启发式，不是证明）\n")
        return EXIT_ALLOW
    try:
        payload = json.loads(raw)
    except ValueError as exc:
        sys.stderr.write(
            "hook-write-scope: stdin 非合法 JSON（%s），未能判定写入目标，按放行处理"
            "（护栏为启发式，不是证明）\n" % exc)
        return EXIT_ALLOW
    if not isinstance(payload, dict):
        sys.stderr.write(
            "hook-write-scope: stdin JSON 非对象，未能判定写入目标，按放行处理"
            "（护栏为启发式，不是证明）\n")
        return EXIT_ALLOW

    tool = payload.get("tool_name")
    tool_input = payload.get("tool_input")
    if not isinstance(tool, str) or not tool.strip() or not isinstance(tool_input, dict):
        sys.stderr.write(
            "hook-write-scope: 载荷缺 tool_name/tool_input，未能判定写入目标，按放行处理"
            "（护栏为启发式，不是证明）\n")
        return EXIT_ALLOW

    cwd = cwd_of(payload)
    targets = [p for p in candidates_from_payload(tool, tool_input, cwd) if p]
    if not targets:
        sys.stderr.write(
            "hook-write-scope: 未能判定写入目标（tool=%s），按放行处理（护栏为启发式，不是证明）\n" % tool)
        return EXIT_ALLOW

    roots = allow_roots(payload)
    for path in targets:
        rule = deny_rule(path)
        if rule:
            sys.stderr.write(
                "hook-write-scope: 阻断（模式 %s · 规则 %s）：%s —— 黑名单路径不得由工具写入；"
                "写盘落点见 file-hygiene.md §6.1（运行根优先）\n" % (mode, rule, path))
            return EXIT_BLOCK
        if mode == "strict" and not strict_allowed(path, roots):
            sys.stderr.write(
                "hook-write-scope: 阻断（模式 strict · 规则 白名单外路径）：%s —— 仅允许预设仓库根、"
                "~/.dsh-codepunk/**、${TMPDIR} 与 /tmp、会话 cwd 之下的写入\n" % path)
            return EXIT_BLOCK
    return EXIT_ALLOW


if __name__ == "__main__":
    sys.exit(main())
