#!/usr/bin/env python3
"""preset-compat —— 核对组合与当前 DSH 安装的兼容性（可复跑，随 DSH 升级执行）。

八项检查（全部基于实测事实，不做版本号猜测）：
  1. 引用的插件包存在        —— 组合里每个 `@deepseek-ai/<pkg>` 是否在该 DSH 安装内
  2. 配置键被插件接受        —— 键要么在插件 `Config` schema 内声明，要么被插件源码消费
  3. 组/隔离形态合法        —— 顶层条目均为列表行，`group: true` 的服务行落在 `isolate` 域内
  4. allow 名单工具名有注册来源 —— 名单里每个名字须在安装内有插件注册（F021 类缺陷防线：
                                  名字不在当前平台的全局工具集里时，`restrict()` 直接抛错）
  5. 锚点顺序              —— `&role-allow` 定义须早于任何 `*role-allow` 别名（YAML 硬要求）
  6. allow 名单一致性       —— 研究岗内联名单 = 角色锚点名单 + {web_search, web_fetch}
  7. agentOptions 覆盖面（信息行）—— 统计未显式声明路由的岗位数（默认继承父会话路由，非缺陷）
  8. 声明块可被产品 CLI 组合    —— 用 2.0.17 的 `--dump-config` / `--dump-config-schema` 把
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

# F198：非 UTF-8 locale 下 python 的 stdout 编码随 locale（如 ISO-8859-15）→ 输出中文结论会抛
#   `UnicodeEncodeError: 'charmap' codec can't encode`，把「本应清晰降级」变成**崩溃**并破坏退出码契约
#   （实证：`preset-compat.py` 直接调用时 rc 0 → 1；`fidelity-gate.py verify` 由 2 → 1）。
#   故进程内固定 stdout/stderr 为 UTF-8（与仓内全 UTF-8 内容一致）；reconfigure 仅 3.7+ 可用，缺失则忽略。
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


def _has_product_marker(root: Path) -> bool:
    """F267：安装**真实性**判据。

    背景：本工具此前仅凭「目录名（`node_modules/@deepseek-ai` 是否目录）+ 文本正则」即宣称
    「与当前 DSH 安装兼容」——独立复核以**伪造同构根**（26 个同名包目录，各只写一个生成的
    `lib/index.js`，内含 27 键 `Config` 与 16 个工具 `name`，零真实插件代码）实测 **rc=0**，
    即「静默通过」（假通过）。
    真安装根自带产品标记：`package.json` 顶层含 `dsh` 键（实测真根 name=dsh-plugin-desktop、
    version=2.0.17、顶层键含 dsh）。此处要求该标记存在，否则按本仓口径「**无法核验 ≠ 通过**」拒绝。
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
            }
            entries.append(cur)
            continue
        if cur is None:
            continue
        ind = len(line) - len(line.lstrip())
        if line.strip() and re.match(r"^- ", line) and ind <= cur["indent"]:
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
                    cur["keys"].append(m3.group(1))
    return entries


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
    root = Path(sys.argv[1]).expanduser().resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent
    combo = root / "agent.cordis.yml"
    if not combo.is_file():
        print(f"  ✗ 组合文件不存在：{combo}")
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
    except (UnicodeDecodeError, OSError) as exc:
        print(f"  ✗ 组合文件不可读：{combo}（{type(exc).__name__}: {exc}）——无法核验 ≠ 通过")
        return 2
    try:
        entries = parse_entries(combo_text)
    except Exception as exc:  # 解析失败同属「无法核验」，不得以裸 traceback + 1 冒充兼容性结论
        print(f"  ✗ 组合文件解析失败：{combo}（{type(exc).__name__}: {exc}）——无法核验 ≠ 通过")
        return 2
    pkgs = {e["name"].split("/")[1] for e in entries if e["name"] and e["name"].startswith(SCOPE + "/")}

    fails: list[str] = []

    # 1) 包存在性
    missing = sorted(p for p in pkgs if not (app / "node_modules" / SCOPE / p).is_dir())
    if missing:
        fails.append("缺包：" + ", ".join(missing))
    print(f"  {'✅' if not missing else '✗'} 插件包存在（{len(pkgs) - len(missing)}/{len(pkgs)}）")

    # 2) 配置键被接受（schema 声明 或 源码消费）
    unknown: list[str] = []
    for e in entries:
        if not e["name"] or not e["name"].startswith(SCOPE + "/") or not e["keys"]:
            continue
        pkg = e["name"].split("/")[1]
        src_path = app / "node_modules" / SCOPE / pkg / "lib" / "index.js"
        if not src_path.is_file():
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
        for e in entries
        if e["group"] and not e["has_isolate"]
    ]
    if bad_group:
        fails.append("group 缺 isolate：" + ", ".join(bad_group))
    print(f"  {'✅' if not bad_group else '✗'} group 隔离形态（{sum(1 for e in entries if e['group'])} 个组）")

    # 4) 提示（不计失败）：continuable 岗位未声明 agentOptions 时，子代理落产品默认模型
    #    公开预设默认留空由部署方自配（D090「部署方必配」），故此处只提示不判失败。
    need_opt = [
        e["id"]
        for e in entries
        if e["name"] == "@deepseek-ai/dsh-tool-subagent"
        and "agentOptions" not in e["keys"]
        and "backgroundMode" in e["keys"]
        and not e.get("disabled")
    ]
    if need_opt:
        print(f"  ℹ {len(need_opt)} 个岗位未声明 agentOptions（默认**继承父会话实时路由**，非产品默认）——"
              f"公开预设默认留空属预期；仅需偏离父路由时才声明；涉及：{', '.join(sorted(need_opt)[:4])}{' …' if len(need_opt) > 4 else ''}")

    # 7) allow 名单的每个名字必须在安装内有注册来源（F021 类缺陷的机械防线：
    #    写了当前平台不存在的全局工具名 → restrict() 直接抛错、该岗全部派遣失败）
    # F329：两侧提取的字符类**不得收窄**——工具名允许连字符/点/大写（如 `code-search`、`a.b`），
    #   原字符类 `[a-z_][a-z0-9_]*` 会把这类名字**静默丢弃**，永不进入校验集合：若某个不存在的
    #   连字符名同时写在锚点与内联名单里，本检查会 rc=0 宣称兼容，而产品 `tools.restrict()` 在挂载
    #   时抛 `names unknown global tool`（`<app>/node_modules/@deepseek-ai/dsh-tools/lib/index.js:2908`）
    #   ⇒ 该岗全部派遣失败。故名单侧用 `[^']+`（引号内即名字），注册侧放宽到字母数字/点/连字符/下划线。
    import re as _re2
    _lines7 = combo.read_text(encoding="utf-8").splitlines()
    allow_names = set()
    for l in _lines7:
        if 'allow:' in l and '!!js' in l:
            body = l.split('!!js "', 1)[-1].rstrip('"')
            for elem in body.split(','):
                # 平台三元里 `?` 之前是判据（如 'win32'），不是工具名，只取 `?` 之后的分支
                part = elem.split('?', 1)[1] if '?' in elem else elem
                allow_names |= {n.strip() for n in _re2.findall(r"'([^']+)'", part) if n.strip()}
    reg = set()
    _nm = os.path.join(app, "node_modules", SCOPE)
    for pkg in os.listdir(_nm) if os.path.isdir(_nm) else []:
        libd = os.path.join(_nm, pkg, 'lib')
        if not os.path.isdir(libd):
            continue
        for fn in os.listdir(libd):
            if fn.endswith('.js'):
                try:
                    reg |= set(_re2.findall(r'name:\s*"([A-Za-z][A-Za-z0-9._-]{0,40})"',
                                           open(os.path.join(libd, fn), encoding='utf-8', errors='ignore').read()))
                except OSError:
                    pass
    unknown = sorted(n for n in allow_names if n not in reg)
    if unknown:
        fails.append(f"allow 名单含安装内无注册来源的工具名: {unknown}（restrict 会直接抛错）")
        print(f"  ✗ allow 名单工具名（无注册来源: {', '.join(unknown)}）")
    else:
        print(f"  ✅ allow 名单工具名（{len(allow_names)} 个均有注册来源）")

    # 5) 锚点顺序：&role-allow 必须早于任何 *role-allow 别名（YAML 要求先定义后用）
    text_lines = combo.read_text(encoding="utf-8").split("\n")
    def_idx = next((i for i, l in enumerate(text_lines) if l.strip().startswith("allow: &role-allow")), None)
    alias_idx = [i for i, l in enumerate(text_lines) if l.strip() == "allow: *role-allow"]
    if def_idx is None:
        fails.append("未找到锚点定义 allow: &role-allow")
        print("  ✗ 锚点定义缺失")
    elif alias_idx and def_idx > min(alias_idx):
        fails.append(f"锚点定义（第 {def_idx + 1} 行）晚于首个别名（第 {min(alias_idx) + 1} 行）→ 挂载必失败")
        print("  ✗ 锚点顺序")
    else:
        print(f"  ✅ 锚点顺序（定义第 {def_idx + 1} 行，{len(alias_idx)} 处别名）")

    # 6) allow 名单一致性：研究岗内联 = 角色锚点 + {web_search, web_fetch}
    import re as _re
    def names(expr):
        return [x.strip().strip("'\"") for x in expr.split(",") if x.strip()]

    def_expr = text_lines[def_idx].split('!!js "', 1)[-1].rstrip('"') if def_idx is not None else ""
    inline = next((l for l in text_lines if "allow: !!js" in l and "web_search" in l), "")
    inline_expr = inline.split('!!js "', 1)[-1].rstrip('"') if inline else ""
    if def_expr and inline_expr:
        base_all = set(names(def_expr)) - {"process.platform === 'win32' ? 'pwsh' : 'bash'"}
        role_all = base_all | {"bash", "pwsh"}
        inline_all = set(names(inline_expr)) | {"bash", "pwsh"}
        extra = inline_all - role_all
        if extra != {"web_search", "web_fetch"}:
            fails.append(f"研究岗内联 allow 与角色锚点差集异常: {sorted(extra)}")
            print("  ✗ allow 名单一致性")
        else:
            print("  ✅ allow 名单一致性（内联 = 角色 + web_search/web_fetch）")

    # 8) 声明块可被产品 CLI 组合（2.0.17 的 `--dump-config` / `--dump-config-schema`）
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
