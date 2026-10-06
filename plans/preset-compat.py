#!/usr/bin/env python3
"""preset-compat —— 核对组合与当前 DSH 安装的兼容性（可复跑，随 DSH 升级执行）。

七项检查（全部基于实测事实，不做版本号猜测）：
  1. 引用的插件包存在        —— 组合里每个 `@deepseek-ai/<pkg>` 是否在该 DSH 安装内
  2. 配置键被插件接受        —— 键要么在插件 `Config` schema 内声明，要么被插件源码消费
  3. 组/隔离形态合法        —— 顶层条目均为列表行，`group: true` 的服务行落在 `isolate` 域内
  4. allow 名单工具名有注册来源 —— 名单里每个名字须在安装内有插件注册（F021 类缺陷防线：
                                  名字不在当前平台的全局工具集里时，`restrict()` 直接抛错）
  5. 锚点顺序              —— `&role-allow` 定义须早于任何 `*role-allow` 别名（YAML 硬要求）
  6. allow 名单一致性       —— 研究岗内联名单 = 角色锚点名单 + {web_search, web_fetch}
  7. agentOptions 覆盖面（信息行）—— 统计未显式声明路由的岗位数（默认继承父会话路由，非缺陷）

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
import sys
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
        # 文案类观察（R552）：旧文案对「路径非目录」与「目录但缺 dsh 标记」不作区分 ⇒ 诊断路径变长。
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
    import re as _re2
    _lines7 = combo.read_text(encoding="utf-8").splitlines()
    allow_names = set()
    for l in _lines7:
        if 'allow:' in l and '!!js' in l:
            body = l.split('!!js "', 1)[-1].rstrip('"')
            for elem in body.split(','):
                # 平台三元里 `?` 之前是判据（如 'win32'），不是工具名，只取 `?` 之后的分支
                part = elem.split('?', 1)[1] if '?' in elem else elem
                allow_names |= set(_re2.findall(r"'([a-z_][a-z0-9_]*)'", part))
    reg = set()
    _nm = os.path.join(app, "node_modules", SCOPE)
    for pkg in os.listdir(_nm) if os.path.isdir(_nm) else []:
        libd = os.path.join(_nm, pkg, 'lib')
        if not os.path.isdir(libd):
            continue
        for fn in os.listdir(libd):
            if fn.endswith('.js'):
                try:
                    reg |= set(_re2.findall(r'name:\s*"([a-z][a-z0-9_]{1,40})"',
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
