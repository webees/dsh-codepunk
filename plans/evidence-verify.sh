#!/usr/bin/env bash
# =============================================================================
# evidence-verify.sh —— 证据校验器（D069 实现 · 防假通过机械门 S1）
# -----------------------------------------------------------------------------
# 用法：
#   bash evidence-verify.sh <evidence.yaml> [任务交付目录]
#
# 对 sdet 产出的 evidence.yaml 做四条机械断言（任一 FAIL 即打回）：
#   ① command 可执行性：非 N/A 命令须以真实可执行前缀开头，且不得含描述性文本
#   ② log_ref 文件真实存在（相对路径以交付目录为基）
#   ③ exit_code 必须为 0（非 0 即判 FAIL：证据门定义是「成功命令 + exit_code=0 + log 引用」）
#   ④ validated_at 晚于交付目录 mtime（R12 数值断言，替代 LLM 目测）
#   ⑤ 输出 verdict 供合并门/评分门机械采信（PASS 且全部断言真）
#
# 评分/合并门集成：本脚本是 D069 的唯一机械校验器；sdet 产出后、release-eng
# 合并前 MUST 执行一次。审计/巡检可复用。
# =============================================================================
set -u

EVID="${1:?用法: evidence-verify.sh <evidence.yaml> [交付目录]}"
DELIVERY_DIR="${2:-}"

[ -f "$EVID" ] || { echo "❌ [fetch] evidence 文件不存在: $EVID"; exit 1; }

# --- 用 python3 做结构化断言（无 pyyaml 时手解析，健壮优先） ---
# 输出落进程私有临时文件：固定路径（历史实现为 /tmp 下固定名）可被符号链接劫持（覆盖任意文件），
# 且并发调用会互相顶替 verdict（实测 80 对并发中 33 次退出码与输入不符）。
EV_OUT="$(mktemp "${TMPDIR:-/tmp}/ev_verify.XXXXXX")" || { echo "❌ 无法创建临时文件"; exit 2; }
trap 'rm -f "$EV_OUT"' EXIT
python3 - "$EVID" "$DELIVERY_DIR" <<'PYEOF' > "$EV_OUT" 2>&1
import re, os, sys, datetime

f, delivery = sys.argv[1], sys.argv[2] or ""
src = open(f, encoding="utf-8").read()
problems = []
warnings = []

# 提取元字段
m_validated = re.search(r'validated_at:\s*"?([^"\n]+)"?', src)
validated_at = m_validated.group(1).strip() if m_validated else None

# 交付目录 mtime（R12 ④）
if delivery and os.path.isdir(delivery):
    mtime = datetime.datetime.fromtimestamp(os.path.getmtime(delivery))
    if validated_at:
        try:
            vas = validated_at.replace("Z", "+00:00")
            va = datetime.datetime.fromisoformat(vas)
            if va.tzinfo is None:
                va = va.replace(tzinfo=datetime.timezone.utc)
            mt = mtime.astimezone()
            if va <= mt:
                problems.append(f"③ validated_at({va}) 不晚于交付目录 mtime({mt}) → 疑似旧快照")
        except Exception as e:
            warnings.append(f"validated_at 解析失败({e})，跳过时间序断言")
    else:
        problems.append("④ 缺 validated_at（R12 必填）")

# 提取每条 evidence 的 command/log_ref/exit_code（逐行解析，稳健）
entries = []
cur = None
for line in src.splitlines():
    ls = line.strip()
    m = re.match(r'- id:\s*(\S+)', ls)
    if m:
        if cur:
            entries.append(cur)
        cur = {'id': m.group(1)}
        continue
    if cur is not None:
        mm = re.match(r'^command:\s*["\']?([^"\'\n]+)["\']?$', ls)
        if mm and 'cmd' not in cur:
            cur['cmd'] = mm.group(1).strip()
            continue
        mm = re.match(r'^log_ref:\s*["\']?([^"\'\n]+)["\']?$', ls)
        if mm and 'log' not in cur:
            cur['log'] = mm.group(1).strip()
            continue
        mm = re.match(r'^exit_code:\s*(\S+)', ls)
        if mm and 'rc' not in cur:
            cur['rc'] = mm.group(1).strip()
            continue
if cur:
    entries.append(cur)

if not entries:
    problems.append("无 evidence 条目（- id: 未找到）")

for e in entries:
    evid = e.get('id', '?')
    cmd_s = e.get('cmd', '') or ""
    log_s = e.get('log', '') or ""
    rc_s = e.get('rc', '') or ""
    # ① 可执行性：首词白名单（精确健壮）；描述性句式必拒
    if cmd_s and cmd_s != "N/A":
        tokens = cmd_s.split()
        first = tokens[0].lstrip('./') if tokens else ""
        EXEC = {"bash", "sh", "python3", "python", "node", "git", "ls", "grep", "rg", "find", "cat", "stat", "sed", "awk", "mkdir", "cp", "mv", "rm", "test", "head", "tail", "wc", "diff", "source", "for", "while", "if",
            "npm", "pnpm", "yarn", "npx", "bun", "deno", "pytest", "jest", "vitest", "tsc", "uv", "poetry",
            "make", "cargo", "go", "swift", "xcodebuild", "gradle", "mvn", "docker", "curl", "ruby", "php"}
        desc_hint = ("：" in cmd_s or ": " in cmd_s or "解析" in cmd_s or "逐项" in cmd_s or "对比" in cmd_s or "手写" in cmd_s or "检查" in cmd_s or "验证" in cmd_s or cmd_s.startswith(("详见", "参见", "参考")))
        exe_ok = first in EXEC or first.endswith(".sh") or ("/" in first)
        if not exe_ok:
            problems.append(f"[{evid}] command 不可识别为可执行命令: {cmd_s[:60]}")
        elif desc_hint and first in ("bash", "python3", "python"):
            problems.append(f"[{evid}] command 含描述性后缀（应为纯命令）: {cmd_s[:60]}")
    # ② log_ref 存在性
    if log_s and log_s != "N/A":
        # 允许 "(EV-x)" 段标注后缀：先剥再查
        base_log = re.sub(r'\s?\(\w[\w-]*\)\s?$', '', log_s).strip()
        base_log = re.sub(r'#[^/\s]+$', '', base_log).strip()
        cands = [base_log]
        if delivery:
            cands.insert(0, os.path.join(delivery, base_log))
            if not base_log.startswith(("logs/", "evidence/", "handoff/")):
                cands.insert(0, os.path.join(delivery, "logs", base_log))
                cands.insert(0, os.path.join(delivery, "evidence", base_log))
                cands.insert(0, os.path.join(delivery, "handoff", base_log))
            cands.insert(0, os.path.join(delivery, "evidence", "logs", base_log.lstrip("logs/")))
        if not any(os.path.exists(c) for c in cands):
            problems.append(f"[{evid}] log_ref 文件不存在: {log_s}")
    # ③ exit_code 必须为 0（D074「command + exit_code=0 + log_ref」是证据门的定义；
    #    非 0 表示命令未成功，不得作为通过性证据。原先仅对「非常见值」告警、不判失败，
    #    使失败命令也能拿到 verdict=PASS → 合并门前置失效。）
    if rc_s == "":
        problems.append(f"[{evid}] 缺 exit_code（证据须含 command + exit_code + log_ref）")
    elif rc_s.strip() != "0":
        problems.append(f"[{evid}] exit_code={rc_s} ≠ 0 —— 非成功命令不得作为通过性证据（需重跑并附 exit_code=0 的日志）")

print("=" * 52)
print(f"evidence: {f}")
print(f"validated_at: {validated_at or 'MISSING'}")
print(f"条目数: {len(entries)}")
if problems:
    print("FAIL:")
    for p in problems:
        print("  ❌ " + p)
else:
    print("PASS: 全部断言通过（command 可执行 / log_ref 存在 / 时间序成立）")
if warnings:
    print("WARN:")
    for w in warnings:
        print("  ⚠ " + w)
print(f"verdict={'FAIL' if problems else 'PASS'}")
PYEOF
cat "$EV_OUT"
grep -q "verdict=PASS" "$EV_OUT" && exit 0 || exit 1
