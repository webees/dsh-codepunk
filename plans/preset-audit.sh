#!/usr/bin/env bash
# preset-audit.sh —— dsh-codepunk 预设质量审计（run-score-100 rubric 固化）
# 用法: preset-audit.sh [预设根]   默认取本脚本所在目录的上级（预设根）
# 输出: 组 A-F 分数（满分 100）+ 失分项清单 + 终验（解析/体积/零旧名）
# 依赖: 任选其一做 YAML 解析校验（node+js-yaml / ruby）；均不可用时跳过解析项并告警
# 环境变量: OLD_NAME=<旧名> 时额外做「品牌卫生」回归检查（默认跳过）

set -u
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT" || { echo "✗ 预设根不存在: $ROOT"; exit 1; }

PASS="✅"; FAIL="✗"; LOSE=0
report() { echo "  [$1] $2"; if [ "$1" = "$FAIL" ]; then LOSE=$((LOSE+1)); fi; return 0; }

echo "===== dsh-codepunk 预设审计 ====="
echo "[组A 配置层 25]"
# A1 解析合法
parse_ok="skip"
if command -v ruby >/dev/null 2>&1; then
  ruby -ryaml -e 'd=YAML.load_file("agent.cordis.yml"); exit(d.is_a?(Array) && d.all?{|r| r.is_a?(Hash) && r.key?("name")} ? 0 : 1)' 2>/dev/null && parse_ok="ok" || parse_ok="fail"
elif command -v node >/dev/null 2>&1; then
  node -e 'const p=process.argv[1];const y=require("js-yaml");const d=y.load(require("fs").readFileSync("agent.cordis.yml","utf8"));process.exit(Array.isArray(d)&&d.every(r=>r&&r.name)?0:1)' 2>/dev/null && parse_ok="ok" || parse_ok="fail"
fi
case "$parse_ok" in
  ok)   report "$PASS" "A1 解析 OK" ;;
  fail) report "$FAIL" "A1 YAML 解析失败" ;;
  skip) report "$PASS" "A1 解析跳过（无 ruby/node，未验证）" ;;
esac
# A2 岗位 6 维
A2=$(python3 - <<'PYEOF'
import re
s=open("agent.cordis.yml").read()
names=["squad-lead","engineer","sdet","product","research","people","docs","proc-audit","sys-arch","code-review","release-eng"]
ok=sum(1 for n in names if all(d in (re.search(r"tool-subagent-"+n+r".*?persona: \|-(.*?)(?=\n\s+- id:|\Z)",s,re.S).group(1) if re.search(r"tool-subagent-"+n+r".*?persona: \|-(.*?)(?=\n\s+- id:|\Z)",s,re.S) else "") for d in ["你是","边界：","协作：","质量：","禁区：","输出："]))
print("OK" if ok==11 else f"FAIL {ok}/11")
PYEOF
)
[ "$A2" = "OK" ] && report "$PASS" "A2 岗位 6 维 11/11" || report "$FAIL" "A2 $A2"
# A3 无过期注释
[ "$(grep -c 'str_replace' agent.cordis.yml)" -eq 0 ] && report "$PASS" "A3 无 str_replace 残留" || report "$FAIL" "A3 str_replace 残留"
# A5 品牌卫生：如本仓库有改名历史，用 OLD_NAME 环境变量注入旧名做回归检查（默认跳过，不在仓库内硬编码旧名）
if [ -n "${OLD_NAME:-}" ]; then
  n=$(grep -ic -- "$OLD_NAME" agent.cordis.yml 2>/dev/null || echo 0)
  [ "$n" -eq 0 ] && report "$PASS" "A5 零旧名（OLD_NAME=${OLD_NAME}）" || report "$FAIL" "A5 旧名残留 $n 处"
else
  report "$PASS" "A5 品牌卫生（未设 OLD_NAME，跳过）"
fi

# A7 配置不变量（机械守护核心契约：可恢复 / 工具面收口 / 岗位在位 / 可派遣）
A7=$(python3 - <<'PYEOF'
import re, sys
s = open('agent.cordis.yml', encoding='utf-8').read()
# 岗位条目：tool-subagent-* 且非外部后端（codex/claude-code 为一次性、不套本契约）
entries = re.findall(r'    - id: (tool-subagent[a-z0-9-]*)\n(.*?)(?=\n    - id:|\Z)', s, re.S)
bad = []
n_role = 0
for name, body in entries:
    # 只审「派遣条目」：控制面单元（tool-subagent-control / -list-agents 等）本就不带
    # persona/toolFilter/backgroundMode，纳入会误报。
    if "name: '@deepseek-ai/dsh-tool-subagent'" not in body:
        continue
    if name in ('tool-subagent-codex', 'tool-subagent-claude-code'):
        continue
    n_role += 1
    if re.search(r'^      disabled:\s*true', body, re.M):
        bad.append(f'{name} 被 disabled')
    if 'persona:' not in body:
        bad.append(f'{name} 缺 persona')
    if name == 'tool-subagent-fork' or name == 'tool-subagent':
        pass                      # 通用委派两席同样要求过滤与可恢复（下方一视同仁）
    if 'backgroundMode: continuable' not in body:
        bad.append(f'{name} 非 continuable（破坏可恢复/可追问）')
    if 'toolFilter:' not in body:
        bad.append(f'{name} 缺 toolFilter（孩子将回到完整工具面）')
    m = re.search(r'^        maxDepth:\s*(\d+)', body, re.M)
    if m and int(m.group(1)) < 1:
        bad.append(f'{name} maxDepth={m.group(1)}（无法再派遣）')
if n_role < 13:
    bad.append(f'岗位条目仅 {n_role} 个（应 ≥13：11 岗位 + 通用委派 2 席）')
print(' | '.join(bad))
PYEOF
)
[ -z "$A7" ] && report "$PASS" "A7 配置不变量（可恢复/工具面收口/岗位在位/可派遣）" \
             || report "$FAIL" "A7 配置不变量违规: $A7"

# B1b 全角紧邻陷阱守护：`$VAR` 直接跟全角标点时，bash 会把全角字节并进变量名，
#     在 set -u 下报 unbound variable 并中止脚本（本会话实测在 init.sh 真实发生）。
#     规则：shell 脚本内变量引用后若接全角字符，MUST 用 ${VAR} 形式。
B1B=$(grep -nP '\$[A-Za-z_][A-Za-z0-9_]*[（）：，。；、「」【】]' plans/*.sh 2>/dev/null | head -3 | cut -d: -f1,2 | tr '\n' ' ')
[ -z "$B1B" ] && report "$PASS" "B1b 无全角紧邻陷阱（变量引用均用 \${VAR}）" \
             || report "$FAIL" "B1b 全角紧邻陷阱（set -u 下会崩栈）: $B1B"

echo "[组B 手册层 25]"
SIZE=$(wc -c < skills/dsh-codepunk-workflow/SKILL.md)
[ "$SIZE" -le 32768 ] && report "$PASS" "B1 SKILL ${SIZE}B ≤32768" || report "$FAIL" "B1 SKILL ${SIZE}B 超限"
# B5 品牌卫生（全仓）：同样由 OLD_NAME 驱动，排除本脚本自身避免自命中
if [ -n "${OLD_NAME:-}" ]; then
  N=$(git grep -ic -- "$OLD_NAME" 2>/dev/null | awk -F: '{s+=$2}END{print s+0}')
  [ "${N:-0}" -eq 0 ] && report "$PASS" "B5 全仓零旧名" || report "$FAIL" "B5 旧名残留=$N"
else
  report "$PASS" "B5 品牌卫生（未设 OLD_NAME，跳过）"
fi

echo "[组D 调研层 10]"
DMISS=$(for f in skills/dsh-codepunk-workflow/benchmarks/*.md; do grep -qcE "支撑决策号|性质" "$f" || echo "$(basename $f)"; done | head -3)
[ -z "$DMISS" ] && report "$PASS" "D1 全基准标决策号" || report "$FAIL" "D1 缺: $DMISS"

# D3 源码行号引用守护：行号须与符号名同行（行号会随重排漂移，单留行号即成死指针）
D3=$(python3 - <<'PYEOF'
import re, subprocess
files = [f for f in subprocess.run(['git','ls-files'],capture_output=True,text=True).stdout.split()
         if f.endswith('.md')]
bad = []
sym = re.compile(r'`[A-Za-z_][A-Za-z0-9_]*(?:\(\))?`|`[A-Za-z_][A-Za-z0-9_.]*\(`')
for f in files:
    for i, ln in enumerate(open(f, encoding='utf-8', errors='ignore'), 1):
        if not re.search(r'\.js:[0-9]+', ln):
            continue
        if not sym.search(ln):
            bad.append(f'{f}:{i}')
print(' '.join(bad[:3]))
PYEOF
)
[ -z "$D3" ] && report "$PASS" "D3 行号引用均附符号名（可复核）" \
             || report "$FAIL" "D3 行号引用缺符号名（行号会漂移）: $D3"

echo "[组E 文档层 10]"
EC=$(grep -c "^## " README.md)
[ "$EC" -ge 7 ] && report "$PASS" "E2 README ${EC} 节 ≥7" || report "$FAIL" "E2 README ${EC} 节 <7"

echo "[组F 工具层 10]"
FSYNC=$(for p in plans/*.sh; do f=$(basename "$p"); diff -q "$HOME/.dsh-codepunk/scripts/$f" "$p" >/dev/null 2>&1 || echo "${f%.sh}"; done)
# Windows 侧（plans/windows/*.ps1）与总库 scripts/ 同源对照
WSYNC=$(for p in plans/windows/*.ps1; do [ -f "$p" ] || continue; f=$(basename "$p"); diff -q "$HOME/.dsh-codepunk/scripts/$f" "$p" >/dev/null 2>&1 || echo "${f%.ps1}"; done)
FSYNC="$(printf '%s %s' "$FSYNC" "$WSYNC" | tr -s ' ' ' ' | sed 's/^ *//; s/ *$//')"
[ -z "$FSYNC" ] && report "$PASS" "F2 plans↔scripts 同步" || report "$FAIL" "F2 不同步: $FSYNC"

echo
echo "===== 审计结论 ====="
if [ "$LOSE" -eq 0 ]; then
  echo "总分 100/100 —— 全项达标"
else
  echo "失分项 $LOSE 处 —— 见上方 $FAIL"
fi
[ "$LOSE" -gt 0 ] && exit 1 || exit 0
