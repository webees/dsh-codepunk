#!/usr/bin/env python3
"""preset-compat —— 核对组合与当前 DSH 安装的兼容性（可复跑，随 DSH 升级执行）。

三项检查（全部基于实测事实，不做版本号猜测）：
  1. 引用的插件包存在        —— 组合里每个 `@deepseek-ai/<pkg>` 是否在该 DSH 安装内
  2. 配置键被插件接受        —— 键要么在插件 `Config` schema 内声明，要么被插件源码消费
  3. 组/隔离形态合法        —— 顶层条目均为列表行，`group: true` 的服务行落在 `isolate` 域内

DSH 安装位置由环境变量给出（不硬编码平台路径）：
  DSH_APP_ROOT   解包后的 app 目录（0.1.7 起的布局；插件在 `<root>/node_modules/@deepseek-ai/`）
  DSH_ASAR       旧布局的 app.asar 路径（以其同级 `app/` 目录为插件根）
  取不到时任一项降级为「跳过」，并以非零退出码提示未完成核验。

用法：python3 plans/preset-compat.py [预设根]
退出码：0=全部通过；1=存在不兼容项；2=无法定位 DSH 安装
"""

from __future__ import annotations

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
        print("  ✗ 未定位 DSH 安装：设 DSH_APP_ROOT（解包 app 目录）或 DSH_ASAR（旧 asar 路径）")
        return 2

    entries = parse_entries(combo.read_text(encoding="utf-8"))
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
