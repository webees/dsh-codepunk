#!/usr/bin/env python3
"""preset-compat —— 核对组合与当前 DSH 安装的兼容性（可复跑，随 DSH 升级执行）。

十项检查（全部基于实测事实，不做版本号猜测）：
  1. 引用的插件包存在        —— 组合里每个 `@deepseek-ai/<pkg>` 是否在 DSH 安装或 profile 内
  2. 配置键被插件接受        —— 键要么在插件 `Config` schema 内声明，要么被插件源码消费
  3. 组/隔离形态合法        —— 顶层条目均为列表行，`group: true` 的服务行落在 `isolate` 域内
  4. spawn 角色可达         —— 每个 spawn 的 `agentPreset` 必须指向已声明的角色 preset，且 maxDepth 合法
  5. fork 禁用边界          —— fork 必须显式禁用且不得配置 `agentPreset`
  6. 角色 persona 在位       —— 每个角色 preset 必须挂载 persona 插件并声明 prefix
  7. 联网边界               —— 仅 research 角色可挂载 `tool-web`
  8. 不递归派遣             —— 角色 preset 不得挂载 `tool-subagent`
  9. 退役字段清理           —— `tool-subagent` 不得再出现 persona/toolFilter/backgroundMode 等旧键
  10. 声明块可被产品 CLI 组合 —— 用 2.0.18 的 `--dump-config` / `--dump-config-schema` 把
                                  `plans/preset-declare.mjs emit` 的声明块叠加到产品自带 profile 上：
                                  组合须 rc=0 且产物含本预设条目，且不得引入新的诊断类别。
                                  边界（实测）：组合成功证明「YAML 可解析 + patch/insert 可组合 +
                                  条目被 loader 接受」，**不证明插件可解析或可挂载**（把插件名改成
                                  不存在的包，`--dump-config` 仍 rc=0）；坏 YAML 则 rc=1。

DSH 安装位置由环境变量给出（不硬编码平台路径）：
  DSH_APP_ROOT   解包后的 app 目录（0.1.7 起的布局；插件在 `<root>/node_modules/@deepseek-ai/`）
  DSH_ASAR       旧布局的 app.asar 路径（以其同级 `app/` 目录为插件根）
  取不到时任一项降级为「跳过」，并以非零退出码提示未完成核验。

用法：python3 plans/preset-compat.py [预设根]
退出码：0=全部通过；1=存在不兼容项；2=无法定位 DSH 安装
"""


from __future__ import annotations

# F198：非 UTF-8 locale 下 python stdout 编码随 locale（如 ISO-8859-15）⇒ 输出中文结论抛
#   `UnicodeEncodeError: 'charmap' codec can't encode`，把「本应清晰降级」变成**崩溃**并破坏退出码契约
#   （实证：本脚本直接调用时 rc 0 → 1；fidelity-gate.py verify 由 2 → 1）。故进程内固定 stdout/stderr 为
#   UTF-8（与仓内全 UTF-8 内容一致）；reconfigure 仅 3.7+ 可用，缺失则忽略。
try:
    import sys as _sys
    for _s in (_sys.stdout, _sys.stderr):
        try:
            _s.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
except Exception:
    pass

import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SCOPE = "@deepseek-ai"


def resolve_app_root() -> Path | None:
    for key in ("DSH_APP_ROOT",):
        v = os.environ.get(key)
        if v and (Path(v) / "node_modules" / SCOPE).is_dir():
            return Path(v)
    asar = os.environ.get("DSH_ASAR")
    if asar:
        cand = Path(asar).parent / "app"
        if (cand / "node_modules" / SCOPE).is_dir():
            return cand
    return None


def package_roots(app: Path) -> list[Path]:
    """插件可来自应用安装、当前 desktop profile 或共享 profile 根。"""
    roots = [
        app / "node_modules",
        Path.home() / ".dsh" / "profiles" / "desktop" / "node_modules",
        Path.home() / ".dsh" / "profiles" / "node_modules",
    ]
    out: list[Path] = []
    for root in roots:
        if (root / SCOPE).is_dir() and root not in out:
            out.append(root)
    return out


def find_package(app: Path, pkg: str) -> Path | None:
    for root in package_roots(app):
        cand = root / SCOPE / pkg
        if cand.is_dir():
            return cand
    return None


def _has_product_marker(root: Path) -> bool:
    """F267：安装**真实性**判据。

    背景：本工具此前仅凭「目录名（`node_modules/@deepseek-ai` 是否目录）+ 文本正则」即宣称
    「与当前 DSH 安装兼容」——独立复核以**伪造同构根**（26 个同名包目录，各只写一个生成的
    `lib/index.js`，内含 27 键 `Config` 与 16 个工具 `name`，零真实插件代码）实测 **rc=0**，
    即「静默通过」（假通过）。
    真安装根自带产品标记：`package.json` 顶层含 `dsh` 键（实测真根 name=dsh-plugin-desktop、
    version=2.0.18、顶层键含 dsh）。此处要求该标记存在，否则按本仓口径「**无法核验 ≠ 通过**」拒绝。
    """
    try:
        data = json.loads((root / "package.json").read_text(encoding="utf-8", errors="replace"))
    except (OSError, ValueError):
        return False
    if not isinstance(data, dict):
        return False
    return "dsh" in data or str(data.get("name", "")).startswith("dsh")


def parse_entries(text: str) -> list[dict]:
    """行级解析组合（与仓内其它工具一致，避免引入 YAML 依赖）。"""
    entries: list[dict] = []
    cur: dict | None = None
    lines = text.split("\n")
    for i, line in enumerate(lines):
        m = re.match(r"^(\s*)- id: (\S+)\s*$", line)
        if m:
            cur = {
                "id": m.group(2),
                "indent": len(m.group(1)),
                "line": i + 1,
                "name": None,
                "keys": [],
                "group": False,
                "has_isolate": False,
                "disabled": False,
                "values": {},
            }
            entries.append(cur)
            continue
        if cur is None:
            continue
        ind = len(line) - len(line.lstrip())
        # 任意缩进的列表项都可能开启新条目（包括 `- &锚点` / `- *别名`）；
        # 只识别 `- id:` 会把别名行误并进上一个插件，进而把后续 config 键
        # 错记到前一个条目上（实测 persona.maxBytes / persistent-pwsh.*）。
        if line.strip() and re.match(r"^\s*-\s+", line) and ind <= cur["indent"]:
            cur = None
            continue
        if cur["name"] is None:
            m2 = re.match(r"^\s*name: '([^']+)'", line)
            if m2:
                cur["name"] = m2.group(1)
                continue
        if re.match(r"^\s*group: true\s*$", line):
            cur["group"] = True
        if re.match(r"^\s*disabled:\s*true\s*$", line) and ind <= cur["indent"] + 2:
            cur["disabled"] = True
        if re.match(r"^\s*isolate:\s*$", line) and ind < cur["indent"] + 8:
            cur["has_isolate"] = True
        mcfg = re.match(r"^(\s*)config:\s*$", line)
        if mcfg:
            base = len(mcfg.group(1))
            for j in range(i + 1, len(lines)):
                l2 = lines[j]
                if not l2.strip():
                    continue
                ind2 = len(l2) - len(l2.lstrip())
                if ind2 <= base:
                    break
                m3 = re.match(r"^\s+([A-Za-z_][A-Za-z0-9_]*):", l2)
                if m3 and ind2 == base + 2:
                    key = m3.group(1)
                    value = l2.split(":", 1)[1].strip()
                    value = re.sub(r"\s+#.*$", "", value).strip()
                    cur["keys"].append(key)
                    cur["values"][key] = value.strip("'\"")
    return entries


def parse_role_presets(text: str) -> list[dict]:
    """读取 role-presets.cordis.yml 的顶层角色声明（config.id + 原文块）。"""
    roles: list[dict] = []
    cur: dict | None = None
    for line in text.split("\n"):
        m = re.match(r"^- id: (\S+)\s*$", line)
        if m:
            cur = {"row_id": m.group(1), "config_id": None, "body": [line]}
            roles.append(cur)
            continue
        if cur is None:
            continue
        cur["body"].append(line)
        m2 = re.match(r"^    id: (\S+)\s*$", line)
        if m2 and cur["config_id"] is None:
            cur["config_id"] = m2.group(1).strip("'\"")
    for role in roles:
        role["body"] = "\n".join(role["body"])
    return roles


def schema_keys(src: str) -> set[str]:
    """取插件 `Config = z.object({...})` 的顶层键（花括号配平，避免嵌套截断）。"""
    keys: set[str] = set()
    for m in re.finditer(r"(?:static\s+)?Config\s*=\s*\w*\.?object\(\{", src):
        start = m.end() - 1
        depth = 0
        for k in range(start, len(src)):
            if src[k] == "{":
                depth += 1
            elif src[k] == "}":
                depth -= 1
                if depth == 0:
                    body = src[start : k + 1]
                    for km in re.finditer(r"([A-Za-z_][A-Za-z0-9_]*)\s*:", body):
                        keys.add(km.group(1))
                    break
    return keys


def main() -> int:
    # F366：全预设统一的用法约定（`-h`/`--help` ⇒ 打印用法并 rc=0）；此前 `-h` 被当预设根路径，
    #   报「组合文件不存在：<仓库>/-h/agent.cordis.yml」——同一套 CLI 的用法约定不一致。
    if len(sys.argv) > 1 and sys.argv[1] in ('-h', '--help'):
        print("用法: preset-compat.py [<预设根>]")
        print("  核验组合与当前 DSH 安装的兼容性（十项：插件包存在 / 配置键被接受 / 组与隔离形态 /")
        print("  spawn 角色可达 / fork 禁用边界 / 角色 persona / 联网边界 / 不递归派遣 / 退役字段 / 声明块可组合）")
        print("  环境变量: DSH_APP_ROOT（解包 app 目录）· DSH_ASAR（旧 asar 布局）")
        print("  退出码: 0=兼容 · 1=存在不兼容项 · 2=用法错误或未定位 DSH 安装")
        return 0
    root = Path(sys.argv[1]).expanduser().resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent
    combo = root / "agent.cordis.yml"
    roles_path = root / "role-presets.cordis.yml"
    if not combo.is_file():
        print(f"  ✗ 组合文件不存在：{combo}")
        return 2
    if not roles_path.is_file():
        print(f"  ✗ 角色 preset 源不存在：{roles_path}")
        return 2

    app = resolve_app_root()
    if app is None:
        # 文案类观察：旧文案对「路径非目录」与「目录但缺 dsh 标记」不作区分 ⇒ 诊断路径变长（本仓文档禁写 R+三位号，以免与硬规则号同形）。
        _envr = os.environ.get("DSH_APP_ROOT", "")
        if _envr and not os.path.isdir(_envr):
            _hint = f"（DSH_APP_ROOT={_envr} **不是目录**）"
        elif _envr:
            _hint = f"（DSH_APP_ROOT={_envr} 是目录，但缺 dsh 产品标记）"
        else:
            _hint = ""
        print(f"  ✗ 未定位 DSH 安装{_hint}：设 DSH_APP_ROOT（解包 app 目录）或 DSH_ASAR（旧 asar 路径）")
        return 2

    # F267：定位成功 ≠ 安装真实。伪造同构根（同名包目录 + 生成的 lib/index.js）实测可获 rc=0 与
    #   「结论：与当前 DSH 安装兼容」⇒ 假通过。要求产品标记，缺失即按「无法核验 ≠ 通过」判 2。
    if not _has_product_marker(app):
        print(f"  ⚠ 无法核验安装真实性（{app}/package.json 缺 `dsh` 产品标记或不可读）——无法核验 ≠ 通过")
        return 2

    # F247：截断/损坏配置曾以**未捕获** UnicodeDecodeError 抛裸 traceback，且退出码 1 被文档释义为
    #   「存在不兼容项」⇒ 把「无法解析／无法核验」冒充成兼容性结论（与 F234/F239/F241 同族）。
    #   按本仓教义显式报错，并归入「环境/用法错误」（2），与上面「组合文件不存在」同档。
    try:
        combo_text = combo.read_text(encoding="utf-8")
        roles_text = roles_path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError) as exc:
        print(f"  ✗ 组合文件不可读：{combo}（{type(exc).__name__}: {exc}）——无法核验 ≠ 通过")
        return 2
    try:
        entries = parse_entries(combo_text)
        role_entries = parse_entries(roles_text)
        roles = parse_role_presets(roles_text)
    except Exception as exc:  # 解析失败同属「无法核验」，不得以裸 traceback + 1 冒充兼容性结论
        print(f"  ✗ 组合文件解析失败：{combo}（{type(exc).__name__}: {exc}）——无法核验 ≠ 通过")
        return 2
    all_entries = entries + role_entries
    pkgs = {e["name"].split("/")[1] for e in all_entries if e["name"] and e["name"].startswith(SCOPE + "/")}

    fails: list[str] = []

    # 1) 包存在性
    missing = sorted(p for p in pkgs if find_package(app, p) is None)
    if missing:
        fails.append("缺包：" + ", ".join(missing))
    print(f"  {'✅' if not missing else '✗'} 插件包存在（{len(pkgs) - len(missing)}/{len(pkgs)}）")

    # 2) 配置键被接受（schema 声明 或 源码消费）
    unknown: list[str] = []
    for e in all_entries:
        if not e["name"] or not e["name"].startswith(SCOPE + "/") or not e["keys"]:
            continue
        pkg = e["name"].split("/")[1]
        pkg_dir = find_package(app, pkg)
        src_path = (pkg_dir / "lib" / "index.js") if pkg_dir else None
        if src_path is None or not src_path.is_file():
            continue
        src = src_path.read_text(encoding="utf-8", errors="ignore")
        declared = schema_keys(src)
        for key in e["keys"]:
            consumed = bool(re.search(rf"config[?]?\.{re.escape(key)}\b", src)) or bool(
                re.search(rf"[\"']{re.escape(key)}[\"']", src)
            )
            if key not in declared and not consumed:
                unknown.append(f"{e['id']}.{key}")
    if unknown:
        fails.append("键未被接受：" + ", ".join(sorted(set(unknown))))
    print(f"  {'✅' if not unknown else '✗'} 配置键被插件接受")

    # 3) group / isolate 形态
    bad_group = [
        e["id"]
        for e in all_entries
        if e["group"] and not e["has_isolate"]
    ]
    if bad_group:
        fails.append("group 缺 isolate：" + ", ".join(bad_group))
    print(f"  {'✅' if not bad_group else '✗'} group 隔离形态（{sum(1 for e in all_entries if e['group'])} 个组）")

    # 4) spawn 角色可达：agentPreset 必须指向 role-presets.cordis.yml 的 config.id。
    role_ids = {r["config_id"] for r in roles if r["config_id"]}
    subagent_entries = [e for e in entries if e["name"] == "@deepseek-ai/dsh-tool-subagent"]
    role_bad: list[str] = []
    for e in subagent_entries:
        if e.get("disabled"):
            continue
        preset = e["values"].get("agentPreset", "")
        if not preset:
            role_bad.append(f"{e['id']} 缺 agentPreset")
        elif preset not in role_ids:
            role_bad.append(f"{e['id']} 指向未声明角色 {preset}")
        depth = e["values"].get("maxDepth", "")
        if depth != "1":
            role_bad.append(f"{e['id']} maxDepth={depth or '缺失'}（本地 spawn 应为 1）")
    if role_bad:
        fails.append("spawn 角色不可达：" + ", ".join(role_bad))
    print(f"  {'✅' if not role_bad else '✗'} spawn 角色可达（{len(role_ids)} 个角色 preset）")

    # 5) fork 禁用且不得配置 agentPreset。
    fork = next((e for e in subagent_entries if e["id"] == "tool-subagent-fork"), None)
    fork_bad = []
    if fork is None:
        fork_bad.append("缺 tool-subagent-fork 条目")
    else:
        if not fork.get("disabled"):
            fork_bad.append("fork 未禁用")
        if fork["values"].get("agentPreset"):
            fork_bad.append("fork 不得配置 agentPreset")
    if fork_bad:
        fails.append("fork 边界违规：" + ", ".join(fork_bad))
    print(f"  {'✅' if not fork_bad else '✗'} fork 禁用边界")

    # 6) 每个角色 preset 必须挂载 persona 且声明 prefix；prompt 变量必须是 DSH 已注册的内置变量。
    persona_bad = []
    for role in roles:
        rid = role["config_id"] or role["row_id"]
        body = role["body"]
        if "@deepseek-ai/dsh-persona" not in body:
            persona_bad.append(f"{rid} 缺 persona 插件")
        elif not re.search(r"^\s+prefix:\s*\S", body, re.M):
            persona_bad.append(f"{rid} persona 缺 prefix")
    prompt_vars = set(re.findall(r"\{\{([A-Za-z_][A-Za-z0-9_]*)\}\}", combo_text + "\n" + roles_text))
    unsupported_vars = sorted(prompt_vars - {"provider", "model"})
    if unsupported_vars:
        persona_bad.append("不支持的提示词变量: " + ", ".join(unsupported_vars))
    if persona_bad:
        fails.append("persona 不完整：" + ", ".join(persona_bad))
    print(f"  {'✅' if not persona_bad else '✗'} 角色 persona（{len(roles)} 个）")

    # 7) 联网边界：只有 research 角色可挂载 tool-web。
    web_bad = []
    for role in roles:
        rid = role["config_id"] or role["row_id"]
        has_web = "@deepseek-ai/dsh-tool-web" in role["body"]
        if has_web != rid.endswith("-research"):
            web_bad.append(f"{rid} tool-web={has_web}")
    if web_bad:
        fails.append("联网边界违规：" + ", ".join(web_bad))
    print(f"  {'✅' if not web_bad else '✗'} 联网边界（仅 research 挂 tool-web）")

    # 8) 角色 preset 不得递归挂载 tool-subagent。
    recurse_bad = [
        (r["config_id"] or r["row_id"])
        for r in roles
        if re.search(r"name:\s*'@deepseek-ai/dsh-tool-subagent'\s*$", r["body"], re.M)
    ]
    if recurse_bad:
        fails.append("角色递归派遣：" + ", ".join(recurse_bad))
    print(f"  {'✅' if not recurse_bad else '✗'} 不递归派遣")

    # 9) tool-subagent 不得再出现退役字段。
    retired = {"persona", "toolFilter", "backgroundMode", "enableRunInBackground"}
    retired_bad = [
        f"{e['id']}.{key}"
        for e in subagent_entries
        for key in e["keys"]
        if key in retired
    ]
    if retired_bad:
        fails.append("退役字段残留：" + ", ".join(sorted(set(retired_bad))))
    print(f"  {'✅' if not retired_bad else '✗'} 退役字段清理")

    # 10) 声明块可被产品 CLI 组合（2.0.18 的 `--dump-config` / `--dump-config-schema`）
    #    边界（实测，MUST 知悉）：组合成功只证明「YAML 可解析 + patch/insert 结构可组合 + 条目被产品
    #    loader 接受」；**不证明插件可解析或可挂载**——把插件名改成不存在的包，`--dump-config` 仍 rc=0；
    #    坏 YAML 则 rc=1（`failed to parse …`）。诊断比对按「消息类别」（`[/N]` 索引归一化），
    #    因为叠加声明会使索引整体位移，而产品自带 profile 本身也会产生 carrier 类诊断。
    cli = app / "node_modules" / "@deepseek-ai" / "dsh" / "lib" / "bin.js"
    declare = root / "plans" / "preset-declare.mjs"
    node = shutil.which("node")
    prof = next(
        (p for p in ("web", "headless") if (Path.home() / ".dsh" / "profiles" / p).is_dir()),
        None,
    )
    why = []
    if not cli.is_file():
        why.append(f"未找到 DSH CLI（{cli}）")
    if not declare.is_file():
        why.append(f"未找到 {declare}")
    if node is None:
        why.append("缺 node")
    if prof is None:
        why.append("缺可检视 profile（~/.dsh/profiles/web|headless）")
    if why:
        print(f"  ℹ 声明块可被产品 CLI 组合：无法核验（{'；'.join(why)}）——无法核验 ≠ 通过")
    else:
        def run_cli(extra, timeout=180):
            try:
                p = subprocess.run(
                    [node, str(cli), "--profile", prof] + extra,
                    capture_output=True, text=True, timeout=timeout, cwd=str(root),
                )
                return p.returncode, p.stdout, p.stderr
            except Exception as exc:  # 超时或启动失败：按 rc=124 处理，不当作通过
                return 124, "", f"{type(exc).__name__}: {exc}"

        tmpd = tempfile.mkdtemp(prefix="preset-compat-")
        patch = Path(tmpd) / "declaration.yml"
        try:
            # 管道采集（capture_output）与文件重定向各跑一次：二者字节数必须相等，
            # 否则说明 emit 在管道下被截断（F362：Node `process.exit` 丢弃管道缓冲）。
            emit = subprocess.run(
                [node, str(declare), "emit"], capture_output=True, text=True, timeout=180,
                cwd=str(root),
            )
            with open(patch, "w", encoding="utf-8") as fh:
                emit_file = subprocess.run(
                    [node, str(declare), "emit"], stdout=fh, stderr=subprocess.PIPE,
                    text=True, timeout=180, cwd=str(root),
                )
        except Exception as exc:
            emit = None
            emit_file = None
            print(f"  ℹ 声明块可被产品 CLI 组合：无法核验（emit 失败：{exc}）——无法核验 ≠ 通过")
        if emit is not None and emit_file is not None:
            pipe_len = len(emit.stdout.encode("utf-8"))
            file_len = patch.stat().st_size
            if pipe_len != file_len:
                fails.append(
                    f"emit 输出在管道下被截断（管道 {pipe_len} B / 文件重定向 {file_len} B）"
                    "——`process.exit` 会丢弃管道缓冲（F362）"
                )
            preset_id = "dsh-codepunk"
            try:
                m = re.search(r"^name:\s*(\S+)", (root / "preset.yml").read_text(encoding="utf-8"), re.M)
                if m:
                    preset_id = m.group(1).strip().strip("'\"")
            except Exception:
                pass
            base_rc, base_out, base_err = run_cli(["--dump-config"])
            rc, out, err = run_cli(["--patch", str(patch), "--dump-config"])
            marker = f"id: preset-{preset_id}"
            ok = emit.returncode == 0 and emit_file.returncode == 0 and rc == 0 and marker in out
            if not ok:
                first = ((err or out).strip().splitlines() or [""])[0]
                fails.append(
                    f"声明块未能被产品组合（emit_rc={emit.returncode} dump_rc={rc}）：{first[:120]}"
                )

            def kinds(text):
                return {
                    re.sub(r"\[/\d+\]", "[/N]", ln).strip()
                    for ln in text.splitlines()
                    if ln.startswith("dsh:")
                }

            newk = []
            if base_rc != 124:
                s_base = run_cli(["--dump-config-schema"])
                s_ours = run_cli(["--patch", str(patch), "--dump-config-schema"])
                if s_base[0] != 124 and s_ours[0] != 124:
                    newk = sorted(kinds(s_ours[2]) - kinds(s_base[2]))
                    if newk:
                        fails.append("声明块引入新的诊断类别：" + " | ".join(newk))
                else:
                    print("  ℹ 诊断类别比对：无法核验（--dump-config-schema 未完成）——无法核验 ≠ 通过")
            print(
                f"  {'✅' if ok and not newk else '✗'} 声明块可被产品 CLI 组合"
                f"（{prof} profile；组合成功不证明插件可解析/可挂载）"
            )
            shutil.rmtree(tmpd, ignore_errors=True)

    print(f"\n  DSH 安装：{app}")
    print(f"  条目 {len(entries)} 行；引用插件 {len(pkgs)} 个")
    if fails:
        print("\n  不兼容项：")
        for f in fails:
            print("    · " + f)
        return 1
    print("\n  结论：与当前 DSH 安装兼容")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
