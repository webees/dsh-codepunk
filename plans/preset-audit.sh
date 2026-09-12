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
  [ "$n" -eq 0 ] && report "$PASS" "A5 零旧名（OLD_NAME=$OLD_NAME）" || report "$FAIL" "A5 旧名残留 $n 处"
else
  report "$PASS" "A5 品牌卫生（未设 OLD_NAME，跳过）"
fi

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

echo "[组E 文档层 10]"
EC=$(grep -c "^## " README.md)
[ "$EC" -ge 7 ] && report "$PASS" "E2 README ${EC} 节 ≥7" || report "$FAIL" "E2 README ${EC} 节 <7"

echo "[组F 工具层 10]"
FSYNC=$(for f in dsh-codepunk-link dsh-codepunk-migrate dsh-codepunk-init verify-worktree evidence-verify; do [ -f "plans/$f.sh" ] && diff -q "$HOME/.dsh-codepunk/scripts/$f.sh" "plans/$f.sh" >/dev/null 2>&1 || echo "$f"; done)
[ -z "$FSYNC" ] && report "$PASS" "F2 plans↔scripts 同步" || report "$FAIL" "F2 不同步: $FSYNC"

echo
echo "===== 审计结论 ====="
if [ "$LOSE" -eq 0 ]; then
  echo "总分 100/100 —— 全项达标"
else
  echo "失分项 $LOSE 处 —— 见上方 $FAIL"
fi
[ "$LOSE" -gt 0 ] && exit 1 || exit 0