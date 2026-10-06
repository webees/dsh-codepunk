#!/usr/bin/env bash
# =============================================================================
# evidence-verify.sh —— 证据校验器（D069 实现 · 防假通过机械门 S1）
# -----------------------------------------------------------------------------
# 退出码：0=校验通过（verdict=PASS） · 1=校验未过（列出问题） · 2=用法/文件缺失/环境错误
# 用法：
#   bash evidence-verify.sh <evidence.yaml> [任务交付目录]
#
# 对 sdet 产出的 evidence.yaml 做四条机械断言（任一 FAIL 即打回）：
#   ① command 可执行性：非 N/A 命令须以真实可执行前缀开头，且不得含描述性文本
#   ② log_ref 文件真实存在（相对路径以交付目录为基）
#   ① task_id 必填、evidence id 唯一（D069 结构强约束）
#   ③ exit_code 必须为 0（非 0 即判 FAIL：证据门定义是「成功命令 + exit_code=0 + log 引用」）
#   ④ validated_at 晚于交付目录 mtime（R12 数值断言，替代 LLM 目测）
#   ⑤ 输出 verdict 供合并门/评分门机械采信（PASS 且全部断言真）
#
# 评分/合并门集成：本脚本是 D069 的唯一机械校验器；sdet 产出后、release-eng
# 合并前 MUST 执行一次。审计/巡检可复用。
# =============================================================================
set -u

# F197：本工具的判据/内联脚本含**多字节**内容（中文结论、计数标签）。非 UTF-8 locale（C/POSIX/ISO-8859 系）
#   下会被逐字节或按 US-ASCII 处理，甚至把**环境问题**误诊为数据损坏（实证：`link.sh index` 在 `LC_ALL=C`
#   下报「INDEX 语义非法：invalid multibyte char (US-ASCII)」并提示「从备份恢复或重建」——而 INDEX 完好）。
#   故在非 UTF-8 且系统存在 UTF-8 locale 时固定之；探测只用 ASCII。
case "$(locale charmap 2>/dev/null)" in
  UTF-8|utf8|UTF8) ;;
  *)
    for _l in en_US.UTF-8 UTF-8; do
      if locale -a 2>/dev/null | grep -qx "$_l"; then export LC_ALL="$_l"; break; fi
    done ;;
esac

if [ $# -lt 1 ]; then
  echo "用法: evidence-verify.sh <evidence.yaml> [交付目录]" >&2
  exit 2                       # 用法错误 = 2（与 acceptance-verify 及全仓约定一致）
fi
EVID="$1"
DELIVERY_DIR="${2:-}"

[ -f "$EVID" ] || { echo "❌ [fetch] evidence 文件不存在: $EVID"; exit 2; }   # 2=文件缺失

# F254：python3 不可用（缺失/执行失败）时下方断言体输出为空 ⇒ 结果退化为「rc=1 且**不列任何问题**」，
#   违背本脚本「列出问题」契约且无任何诊断（方向是失败安全，但无法核验的成因不可见，用户无从修复）。
#   与本仓教义（无法核验 ≠ 通过）对齐：统一前置为显式失败（2）并说明成因。
command -v python3 >/dev/null 2>&1 && python3 -c 'pass' 2>/dev/null \
  || { echo "✗ python3 不可用（缺失或执行失败）——无法核验 ≠ 通过" >&2; exit 2; }

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

# D069 结构强约束：task_id 必填（证据须能对回具体 task，否则交接/评分/合并门无法定责）
m_task = re.search(r'^task_id:\s*(\S+)', src, re.M)
if not m_task:
    problems.append("① 缺 task_id（D069 必填：证据须能对回具体 task）")

# D069 结构强约束：evidence id 必须唯一（重复 id 使评审/审计无法唯一定位条目）
_ids = re.findall(r'^\s*- id:\s*(\S+)', src, re.M)
_dup = sorted({i for i in _ids if _ids.count(i) > 1})
if _dup:
    problems.append(f"② evidence id 重复: {', '.join(_dup)}（每条 id 必须唯一）")

# 交付目录 mtime（R12 ④）
# 未提供或目录不存在时必须显式记为「未检」，否则结论会宣称已做时间序断言（假保证）。
TIME_CHECKED = False
if delivery and os.path.isdir(delivery):
    TIME_CHECKED = True
else:
    warnings.append("⑤ 时间序未检（未提供交付目录或目录不存在）—— R12 基线断言本次未执行")
if TIME_CHECKED:
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
            # F280：validated_at **已提供但不可解析**属**数据错误**（与「未提供交付目录」的环境缺口不同）；
            #   旧实现仅 WARN + 最终 PASS ⇒ 「无法核验」被当「通过」。此处判 FAIL；「未提供交付目录」仍走上一分支的 WARN。
            problems.append(f"③ validated_at 不可解析({e}) → 数据错误（须为 ISO 8601）—— 无法核验 ≠ 通过")
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
        # F279：log_ref 语义是**日志文件**；旧实现用 os.path.exists ⇒ 指向**目录**亦算「存在」⇒ 假通过。
        _dirhits = [c for c in cands if os.path.isdir(c)]
        if _dirhits:
            problems.append(f"⑤ log_ref 指向目录（须为日志文件）: {_dirhits[0]}")
        elif not any(os.path.isfile(c) for c in cands):
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
    print("PASS: 断言通过（command 可执行 / log_ref 存在" + (" / exit_code=0 / 时间序成立" if TIME_CHECKED else " / exit_code=0；时间序未检，见 WARN") + "）")
if warnings:
    print("WARN:")
    for w in warnings:
        print("  ⚠ " + w)
print(f"verdict={'FAIL' if problems else 'PASS'}")
PYEOF
cat "$EV_OUT"
grep -q "verdict=PASS" "$EV_OUT" && exit 0 || exit 1
