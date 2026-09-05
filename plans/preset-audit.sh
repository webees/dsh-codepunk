#!/usr/bin/env bash
# preset-audit.sh —— dsh-codepunk 预设质量审计（run-score-100 rubric 固化）
# 用法: preset-audit.sh [预设根]   默认 /Users/x/.dsh/.agent-presets/dsh-codepunk
# 输出: 组 A-F 分数（满分 100）+ 失分项清单 + 终验（解析/体积/零旧名）
# 依据: D0xx 质量门（评分体系见 run-score-100/prompts/execution-prompt.md）

set -u
ROOT="${1:-/Users/x/.dsh/.agent-presets/dsh-codepunk}"
cd "$ROOT" || { echo "✗ 预设根不存在: $ROOT"; exit 1; }

PASS="✅"; FAIL="✗"; LOSE=0
report() { echo "  [$1] $2"; if [ "$1" = "$FAIL" ]; then LOSE=$((LOSE+1)); fi; return 0; }

echo "===== dsh-codepunk 预设审计 ====="
echo "[组A 配置层 25]"
# A1 解析合法
if /opt/homebrew/bin/node -e '
const { load } = require("/Applications/DSH Desktop.app/Contents/Resources/app.asar.unpacked/node_modules/js-yaml");
const { entryListSchema } = require("/Applications/DSH Desktop.app/Contents/Resources/app.asar.unpacked/node_modules/@deepseek-ai/cordis-plugin-include/lib/index.js");
const rows = load(require("fs").readFileSync("agent.cordis.yml","utf8"), { schema: entryListSchema });
process.exit(rows.filter(r=>!r||!("name" in r)).length===0?0:1);' 2>/dev/null; then report "$PASS" "A1 解析 OK"; else report "$FAIL" "A1 entryListSchema 解析失败"; fi
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
# A5 零旧名
[ "$(grep -ic picode agent.cordis.yml)" -eq 0 ] && report "$PASS" "A5 零旧名" || report "$FAIL" "A5 picode 残留"

echo "[组B 手册层 25]"
SIZE=$(wc -c < skills/dsh-codepunk-workflow/SKILL.md)
[ "$SIZE" -le 32768 ] && report "$PASS" "B1 SKILL ${SIZE}B ≤32768" || report "$FAIL" "B1 SKILL ${SIZE}B 超限"
# B5 零旧名全仓
N=$(git grep -ic picode -- . ':!plans/preset-audit.sh' 2>/dev/null | awk -F: '{s+=$2}END{print s+0}')
[ "${N:-0}" -eq 0 ] && report "$PASS" "B5 全仓零 picode" || report "$FAIL" "B5 picode=$N"

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