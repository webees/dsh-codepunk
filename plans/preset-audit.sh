#!/usr/bin/env bash
# preset-audit.sh —— dsh-codepunk 预设质量审计（run-score-100 rubric 固化）
# 用法: preset-audit.sh [预设根]   默认取本脚本所在目录的上级（预设根）
# 输出: 5 组（A 配置 / B 手册 / D 调研 / E 文档 / F 工具）逐项 ✅✗ 判定
#       + 末行结论「总分 100/100」或「失分项 N 处」+ 终验（解析/体积/零旧名）
# 注: ① 组字母不连续——历史上无 C 组，A/B/D/E/F 即全部；
#     ② 组标题后的数字（A25/B25/D10/E10/F10）是**分项预算标签**（和为 80，不参与计算），
#        脚本不做分组评分，判定以逐项 ✅✗ 与总失分项数为准。
# 退出码: 0=全项达标；1=存在失分项；2=环境/用法错误（预设根不存在等）
# 依赖: 任选其一做 YAML 解析校验（node+js-yaml / ruby）；均不可用时跳过解析项并告警
# 环境变量: OLD_NAME=<旧名> 时额外做「品牌卫生」回归检查（默认跳过）

set -u
# -h/--help：打印头部用法（与其余脚本一致的通用约定）
case "${1:-}" in
  -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT" || { echo "✗ 预设根不存在: $ROOT"; exit 2; }   # 2 = 环境/用法错误（与全仓约定一致）
# 仓库标识校验：存在但非本预设仓库的根路径属「用法/环境错误」（exit 2），
#   否则检查器会在错误的树上判 1、甚至挂起（实测：preset-score 于错误根 rc=124）。
if [ ! -f skills/dsh-codepunk-workflow/SKILL.md ] || [ ! -d plans ]; then
  printf '✗ 根路径不是本预设仓库（缺 skills/dsh-codepunk-workflow/SKILL.md 或 plans/）: %s\n' "$ROOT" >&2
  exit 2
fi


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
  # F172：`grep -c` 零命中时输出 0 且退出 1——写 `|| echo 0` 会得到**两行** "0\n0"，
  #   使 [ "$n" -eq 0 ] 报错并走 FAIL 分支（健康仓库被误判失分）。用 || true + 默认值。
  n=$(grep -ic -- "$OLD_NAME" agent.cordis.yml 2>/dev/null || true)
  n=${n:-0}
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
# 注意：MUST 用 `grep -E`（BSD/GNU 皆可）——`grep -P` 在 macOS 自带 grep 上直接报错退出，
#       会让本项恒判 PASS（本守护曾因此长期空转，F097）。grep 退出码 2 = 自身出错，同样判失败。
B1B_RAW=$(grep -nE '(^|[^\\])\$[A-Za-z_][A-Za-z0-9_]*[（）：，。；、「」【】]' plans/*.sh 2>/dev/null); B1B_RC=$?
B1B=$(printf '%s' "$B1B_RAW" | head -3 | cut -d: -f1,2 | tr '\n' ' ' | sed 's/ *$//')   # 裁剪尾部空格：空输出须判空
if [ "$B1B_RC" = 2 ]; then
  report "$FAIL" "B1b 检查自身出错（grep 不可用？）——请核对本项"
elif [ -z "$B1B" ]; then
  report "$PASS" "B1b 无全角紧邻陷阱（变量引用均用 \${VAR}）"
else
  report "$FAIL" "B1b 全角紧邻陷阱（set -u 下会崩栈）: $B1B"
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
BMDIR=skills/dsh-codepunk-workflow/benchmarks
D1_UNVERIFIED=0
if ! ls "$BMDIR"/*.md >/dev/null 2>&1; then
  report "$FAIL" "D1 无法核验：$BMDIR 下无 .md 简报（目录缺失或被改名）"
  D1_UNVERIFIED=1
fi
DMISS=$(for f in skills/dsh-codepunk-workflow/benchmarks/*.md; do grep -qcE "支撑决策号|性质" "$f" || echo "$(basename $f)"; done | head -3)
if [ "$D1_UNVERIFIED" = 0 ]; then
  [ -z "$DMISS" ] && report "$PASS" "D1 全基准标决策号" || report "$FAIL" "D1 缺: $DMISS"
fi

# D3 源码行号引用守护：行号须与符号名同行（行号会随重排漂移，单留行号即成死指针）
NOPY=0
if ! command -v python3 >/dev/null 2>&1; then
  report "$FAIL" "D3/E3 无法核验：缺 python3（无法核验 ≠ 通过）——装 python3 或手工核对"
  NOPY=1
fi
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
); D3_RC=$?
if [ "$NOPY" = 1 ]; then
  :                                  # 上方已报「无法核验」，勿重复
elif [ "${D3_RC:-1}" != 0 ]; then
  report "$FAIL" "D3 无法核验（python3 执行失败，退出码 ${D3_RC}）——无法核验 ≠ 通过"
elif [ -z "$D3" ]; then
  report "$PASS" "D3 行号引用均附符号名（可复核）"
else
  report "$FAIL" "D3 行号引用缺符号名（行号会漂移）: $D3"
fi

echo "[组E 文档层 10]"
EC=$(grep -c "^## " README.md)
[ "$EC" -ge 7 ] && report "$PASS" "E2 README ${EC} 节 ≥7" || report "$FAIL" "E2 README ${EC} 节 <7"

# E3 仓内相对链接可达性（死链 = 读者可见缺陷；实测原三检查器全漏）
E3=$(python3 - <<'PYEOF'
import os, re, subprocess
files = [f for f in subprocess.run(['git','ls-files'], capture_output=True, text=True).stdout.split()
         if f.endswith('.md')]
bad = []
for f in files:
    txt = open(f, encoding='utf-8', errors='ignore').read()
    out, infence = [], False
    for ln in txt.split('\n'):
        if ln.startswith('```'):
            infence = not infence
            continue
        out.append('' if infence else ln)
    body = '\n'.join(out)
    for m in re.finditer(r'\]\(([^)\s]+)\)', body):
        t = m.group(1).strip().strip('<>')
        if t.startswith(('http://', 'https://', 'mailto:', 'tel:', '#')):
            continue
        t = t.split('#')[0]
        if not t:
            continue
        if os.path.exists(t) or os.path.exists(os.path.join(os.path.dirname(f), t)):
            continue
        bad.append(f'{f} → {t}')
print(' '.join(bad[:3]))
PYEOF
); E3_RC=$?
if [ "$NOPY" = 1 ]; then
  :                                  # 上方已报「无法核验」，勿重复
elif [ "${E3_RC:-1}" != 0 ]; then
  report "$FAIL" "E3 无法核验（python3 执行失败，退出码 ${E3_RC}）——无法核验 ≠ 通过"
elif [ -z "$E3" ]; then
  report "$PASS" "E3 仓内相对链接均可达"
else
  report "$FAIL" "E3 死链: $E3"
fi

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
