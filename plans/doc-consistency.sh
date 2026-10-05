#!/usr/bin/env bash
# =============================================================================
# doc-consistency.sh —— 文档「声称 ↔ 实现」一致性核对（补覆盖矩阵的首要空档）
# -----------------------------------------------------------------------------
# 覆盖矩阵（references/skill-governance.md）把「文档声称 ↔ 实现」列为无机械检查的首要空档——
# 历次审计中该类最高产（F077/F082/F083/F088/F090/F092/F093）。本脚本固化其中可机械化的部分：
#   1. 计数声称（15 指标 / 5 组 / 电池项数 / 18 references / 16 benchmarks）
#   2. 阶段口径（README 表 = preset.yml 阶段项 = stages.md 阶段号 = 6）
#   3. 术语咨询（裸用「工作区」列出供人工确认；**咨询不判失败**——矩阵已把术语一致性列为人工项）
#   4. 工具存在性（文档提到的 plans/*.sh 必须真实存在）
#   5. 退出码契约（头部「# 退出码」行声明的码集合须覆盖实现用到的 `exit N`）
#   6. 头部自称项数（preset-compat「七项检查」↔ 源码输出分支数，双分支时按咨询处理）
#   16. 自检期望串特异性（`check_rc` 的期望串 MUST NOT 被被检脚本的**小节标题**包含——
#       否则断言可能仅凭标题即通过＝假通过；实测由 R131「死状态」误判导出）
#   15. 阶段引用可解析（全仓阶段引用须在 stages.md 有定义；已定义阶段须至少被引用一次——
#       「部分流程自洽」的机械判据）
#   14. 夹具字面量纪律（自检夹具不得含触发本仓守卫的字面量：用户目录绝对路径 / 邮箱形态 /
#       私网地址——须运行时拼接，否则副本内评分与泄露门会命中夹具自身）
#   13. 状态值正文引用（模板声明的每个状态值 MUST 在**正文**被某步骤引用——否则属「死状态」，#       无主体/无触发条件；排除模板注释行）
#   12. 状态取值合法性（`status:`/`expected:` 取值须落在**任一**已声明状态机集合内；
#      集合自 `status: <值>  # a | b | c` 模板行自动采集，无需手工维护）
#   11. benchmarks 支撑决策号语义相符（括注短名 ↔ standard 含义的 2-gram 重叠：
#      零重叠=✗，仅 1 个重叠=ℹ 待人工确认）
#   10. 章节级引用可解析（`references/x.md「章节名」` 与限定式 `§N` 须在目标文件中存在）
#   9. 编号引用可解析（D 号须逐条登记；P 号须落在已声明范围/span 内）
#   8. 日期形态与未来日期（须 YYYY-MM-DD / YYYY-MM；不得出现未来日期——「实测」不能发生在未来）
#   7. 跨文件阈值一致（同一机制在文档/脚本/配置中的数值必须唯一：评分基准与上下限、
#      retries 扣分与上限、handoff 缺件扣分、巡检周期、收口轮数、证据门退出码）
#
# 计数一律**静态**取（不实跑子工具，避免环境依赖与递归）。
# 用法: doc-consistency.sh [预设根]
# 退出码: 0=全部一致；1=存在不一致；2=环境/用法错误
# =============================================================================
set -u
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT" || { echo "✗ 预设根不存在: $ROOT" >&2; exit 2; }
# 仓库标识校验：存在但非本预设仓库的根路径属「用法/环境错误」（exit 2），
#   否则检查器会在错误的树上判 1、甚至挂起（实测：preset-score 于错误根 rc=124）。
if [ ! -f skills/dsh-codepunk-workflow/SKILL.md ] || [ ! -d plans ]; then
  printf '✗ 根路径不是本预设仓库（缺 skills/dsh-codepunk-workflow/SKILL.md 或 plans/）: %s\n' "$ROOT" >&2
  exit 2
fi

SKILL="skills/dsh-codepunk-workflow/SKILL.md"
REF="skills/dsh-codepunk-workflow/references"
BM="skills/dsh-codepunk-workflow/benchmarks"
NFAIL=0
ok()  { printf '  ✅ %s\n' "$1"; }
bad() { printf '  ✗ %s\n' "$1"; NFAIL=$((NFAIL + 1)); }
na()  { printf '  ⚠ 无法核验：%s（无法核验 ≠ 通过）\n' "$1"; NFAIL=$((NFAIL + 1)); }
info(){ printf '  ℹ %s\n' "$1"; }

echo "== 文档「声称 ↔ 实现」一致性核对 =="

echo "[1] 计数声称（静态）"
cmp_num() {
  if [ -z "$3" ]; then bad "$1：README 未声明计数（实际 $2）"
  elif [ "$2" = "$3" ]; then ok "$1 实际 $2 = 声称 $3"
  else bad "$1 实际 $2，README 声称 $3"; fi
}
cmp_num "评分指标" "$(grep -cE '^# ── [AB][0-9]+ ' plans/preset-score.sh)" \
        "$(grep -oE '[0-9]+ 指标' README.md | head -1 | grep -oE '[0-9]+')"
cmp_num "审计分组" "$(grep -cE '^echo "\[组' plans/preset-audit.sh)" \
        "$(grep -oE '[0-9]+ 组' README.md | head -1 | grep -oE '[0-9]+')"
cmp_num "电池项数" "$(grep -cE '^# [0-9]+[a-c]?\)' plans/verify-battery.sh)" \
        "$(grep -oE '[0-9]+ 项一次跑完' README.md | head -1 | grep -oE '[0-9]+')"
cmp_num "references" "$(ls "$REF"/*.md 2>/dev/null | wc -l | tr -d ' ')" \
        "$(grep -oE '[0-9]+ 篇' README.md | head -1 | grep -oE '[0-9]+')"
cmp_num "benchmarks" "$(ls "$BM"/*.md 2>/dev/null | wc -l | tr -d ' ')" \
        "$(grep -oE '[0-9]+ 篇' README.md | sed -n 2p | grep -oE '[0-9]+')"
cmp_num "自检变异项" "$(grep -oE 'M[0-9]+' plans/checker-self-test.sh | sort -u | wc -l | tr -d ' ')" \
        "$(grep -oE '\*\*[0-9]+ 项\*\*已知缺陷' README.md | head -1 | grep -oE '[0-9]+')"

echo "[2] 阶段口径（六阶段）"
P_README=$(awk '/^## 流程总览/,/^```/' README.md | grep -cE '^\| [1-6]️⃣')
P_PRESET=$(grep -oE '[①②③④⑤⑥]' preset.yml | sort -u | wc -l | tr -d ' ')
P_STAGES=$(grep -oE '^## [①②③④⑤⑥]' "$REF/stages.md" | sort -u | wc -l | tr -d ' ')
if [ "$P_README" = 6 ] && [ "$P_PRESET" = 6 ] && [ "$P_STAGES" = 6 ]; then
  ok "三处一致：README 表 ${P_README} / preset.yml ${P_PRESET} / stages.md 阶段号 ${P_STAGES}"
else
  bad "阶段口径不一：README ${P_README} / preset.yml ${P_PRESET} / stages.md ${P_STAGES}（期望均 6）"
fi

echo "[3] 术语咨询（人工确认，不计失败）"
BARE=$(grep -rn '工作区' "$SKILL" "$REF"/*.md agent.cordis.yml 2>/dev/null \
       | grep -v 'benchmarks/' | grep -v 'git 工作区' | wc -l | tr -d ' ')
if [ "$BARE" = 0 ]; then ok "无裸用「工作区」"
else info "裸用「工作区」${BARE} 处（含「工作区检查点/工作区治理/术语对照」等合法用法，请人工确认是否易与「工作房」混淆）"; fi

echo "[4] 工具存在性"
MISS=""
for f in "$SKILL" "$REF"/*.md README.md CONTRIBUTING.md; do
  [ -f "$f" ] || continue
  case "$f" in */benchmarks/*) continue ;; esac
  for s in $(grep -oE 'plans/[a-z0-9._-]+\.(sh|py|mjs)' "$f" 2>/dev/null | sed 's#plans/##' | sort -u); do
    [ -f "plans/$s" ] || [ -f "plans/windows/$s" ] || MISS="$MISS $(basename "$f"):$s"
  done
done
[ -z "$MISS" ] && ok "文档提到的 plans 脚本均存在" || bad "文档提到但不存在的脚本:${MISS}"

echo "[5] 退出码契约"
rc_bad=""
for f in plans/*.sh; do
  decl_line=$(grep -m1 -E '^#[[:space:]]*退出码' "$f" 2>/dev/null)   # 仅契约行（行首即「退出码」），避免散文提及误配
  [ -n "$decl_line" ] || continue
  decl=$(printf '%s' "$decl_line" | grep -oE '[0-9][[:space:]]*=' | grep -oE '[0-9]' | sort -u | tr -d '\n')
  [ -n "$decl" ] || { na "$(basename "$f") 退出码行未解析出码"; continue; }
  missing=""
  for c in $(grep -oE '\bexit [0-9]+' "$f" | grep -oE '[0-9]+' | sort -u); do
    printf '%s' "$decl" | grep -q -- "$c" || missing="$missing$c"
  done
  [ -z "$missing" ] || rc_bad="$rc_bad $(basename "$f")(缺:$missing)"
done
[ -z "$rc_bad" ] && ok "实现用到的退出码均在头部契约内" || bad "退出码契约缺声明:${rc_bad}"

echo "[6] 头部自称项数"
DOC_CN=$(grep -oE '[一二三四五六七八九十]+项检查' plans/preset-compat.py | head -1)
REAL_CN=$(grep -cE 'print\(f?"  [✅✗ℹ]' plans/preset-compat.py)
if [ -z "$DOC_CN" ]; then ok "preset-compat 未在头部声称项数（跳过）"
else info "preset-compat 头部称「${DOC_CN}」；源码输出分支 ${REAL_CN} 处（同项含成功/失败双分支，以实跑输出为准）"; fi

echo "[7] 跨文件阈值一致（同一机制取值必须唯一）"
# 每类：<标签>|<正则（须含一个捕获组）>
THRESH='评分基准 base|all|base[：: ]*([0-9]+)
评分下限 clamp|last|clamp[ ]*0[–—-]([0-9]+)
retries 单次扣分|all|每次[ ]*[−-]([0-9]+)
retries 上限扣分|all|上限[ ]*[−-]([0-9]+)
handoff 缺件扣分|last|每缺[ ]*1[ ]*文件[ ]*[−-]([0-9]+)
巡检周期（轮）|all|每[ ]*([0-9]+)[ ]*轮
收口轮数|all|([0-9]+)[ ]*轮未交付
证据门 exit_code|all|exit_code[ ]*[=＝][ ]*([0-9]+)'
TH_BAD=""
# 用 here-string 而非管道：管道右侧是子 shell，其中的 NFAIL 自增会丢失（总判定仍 ✔）
while IFS='|' read -r label mode pat; do
  [ -n "$label" ] || continue
  # 排除 checker-self-test.sh：它以**变异载荷**形式故意含有缺陷字面量（例：把证据门退出码
  # 写成非 0 值以验证本项能失败），属测试夹具而非真实取值（曾致本项假阳性）。本脚本自身亦
  # 不含真实取值字面量（注释只作描述）。
  frags=$(grep -rhoE "$pat" "$SKILL" "$REF"/*.md README.md CONTRIBUTING.md agent.cordis.yml \
          $(ls plans/*.sh | grep -v 'checker-self-test.sh') 2>/dev/null)
  if [ "$mode" = last ]; then
    # 变量在匹配片段末尾（模式含常量前导数字，如 clamp 0–100、每缺 1 文件 −5）
    vals=$(printf '%s\n' "$frags" | while read -r fr; do printf '%s\n' "$fr" | grep -oE '[0-9]+' | tail -1; done \
           | sort -u | tr '\n' ',')
  else
    vals=$(printf '%s\n' "$frags" | grep -oE '[0-9]+' | sort -u | tr '\n' ',')
  fi
  n=$(printf '%s' "$vals" | tr ',' '\n' | grep -c .)
  if [ "$n" = 1 ]; then
    ok "${label} 全仓唯一取值 $(printf '%s' "$vals" | tr -d ',')"
  elif [ "$n" = 0 ]; then
    info "${label} 未匹配到取值（正则或表述已变，需人工确认）"
  else
    bad "${label} 取值不一: ${vals}（同一机制必须唯一）"
  fi
done <<<"$THRESH"

echo "[8] 日期形态与未来日期"
TODAY=$(date +%F)
if ! command -v python3 >/dev/null 2>&1; then
  na "日期核验（缺 python3）"
else
  DATE_ISSUE=$(python3 - "$TODAY" <<'PYEOF'
import re, subprocess, sys
today = sys.argv[1]
files = subprocess.run(['git', 'ls-files'], capture_output=True, text=True).stdout.split()
files = [f for f in files if f.endswith(('.md', '.yml')) and '/benchmarks/' not in f]
bad_form, future = [], []
for f in files:
    try:
        txt = open(f, encoding='utf-8', errors='ignore').read()
    except OSError:
        continue
    for m in re.finditer(r'20\d{2}[-/年]\d{1,2}[-/月]\d{1,2}日?', txt):
        d = m.group(0)
        if '-' not in d or '年' in d or '月' in d:
            bad_form.append(f'{f}:{d}')
            continue
        p = d.split('-')
        if len(p[1]) == 1 or len(p[2]) == 1:
            bad_form.append(f'{f}:{d}')
            continue
        if d > today:
            future.append(f'{f}:{d}')
out = []
if future:
    out.append('未来日期: ' + ', '.join(future[:3]))
if bad_form:
    out.append('非 ISO 形态: ' + ', '.join(bad_form[:3]))
print('; '.join(out))
PYEOF
)
  if [ -z "$DATE_ISSUE" ]; then ok "日期形态与新鲜度（ISO 形态；无未来日期；今日 ${TODAY}）"
  else bad "日期问题 → ${DATE_ISSUE}"; fi
fi

echo "[9] 编号引用可解析（D 逐条登记 / P 落在声明范围内）"
if ! command -v python3 >/dev/null 2>&1; then
  na "编号引用核验（缺 python3）"
else
  NUM_ISSUE=$(python3 <<'PYEOF'
import glob, os, re
std = open('skills/dsh-codepunk-workflow/references/standard.md', encoding='utf-8').read()
D = {int(m) for m in re.findall(r'^\| D(\d{3})', std, re.M)}
P_ind = {int(m) for m in re.findall(r'^\| P(\d{2})(?!\d)', std, re.M)}
P_rng = set()
for a, b in re.findall(r'P(\d{2})[–-]P(\d{2})', std):
    P_rng |= set(range(int(a), int(b) + 1))
files = ([ 'skills/dsh-codepunk-workflow/SKILL.md', 'README.md', 'CONTRIBUTING.md' ]
         + glob.glob('skills/dsh-codepunk-workflow/references/*.md')
         + glob.glob('skills/dsh-codepunk-workflow/benchmarks/*.md')
         + [f for f in glob.glob('plans/*.sh') if 'checker-self-test.sh' not in f]   # 排除变异夹具
         + glob.glob('plans/*.mjs') + glob.glob('plans/*.py'))
bad_d, bad_p = [], []
for f in files:
    try:
        t = open(f, encoding='utf-8').read()
    except OSError:
        continue
    # D：逐条登记；排除 standard.md 自身与其自述样例
    if not f.endswith('standard.md'):
        for n in {int(x) for x in re.findall(r'\bD(\d{3})\b', t)}:
            if n not in D:
                bad_d.append(f'{os.path.basename(f)}:D{n:03d}')
    # P：落在 个体 ∪ 范围 内
    covered = P_ind | P_rng
    for n in {int(x) for x in re.findall(r'\bP(\d{2})\b', t)}:
        if covered and n not in covered:
            bad_p.append(f'{os.path.basename(f)}:P{n:02d}')
out = []
if bad_d:
    out.append('D 未登记: ' + ', '.join(sorted(set(bad_d))[:3]))
if bad_p:
    out.append('P 越界: ' + ', '.join(sorted(set(bad_p))[:3]))
print('; '.join(out))
PYEOF
)
  if [ -z "$NUM_ISSUE" ]; then ok "编号引用均可解析（D 逐条登记 / P 在范围内）"
  else bad "编号引用问题 → ${NUM_ISSUE}"; fi
fi

echo "[10] 章节级引用可解析"
if ! command -v python3 >/dev/null 2>&1; then
  na "章节级引用核验（缺 python3）"
else
  SEC_ISSUE=$(python3 <<'PYEOF'
import glob, os, re
S = 'skills/dsh-codepunk-workflow'
# benchmarks 不参与：它们分析的是**外部**项目的文档（如 diagram-design 的 SKILL.md §9），
# 其中的「SKILL.md §N」不是对本仓章节的引用。
files = [f'{S}/SKILL.md', 'README.md', 'CONTRIBUTING.md'] + glob.glob(f'{S}/references/*.md')
patA = re.compile(r'references/([a-z0-9-]+)\.md[「『]([^」』]{2,40})[」』]')
patB = re.compile(r'(?:SKILL\.md|references/([a-z0-9-]+)\.md)[^\n]{0,6}?§([0-9]+(?:\.[0-9]+)?)')
badA, badB = [], []
for f in files:
    try:
        t = open(f, encoding='utf-8').read()
    except OSError:
        continue
    for m in patA.finditer(t):
        target, sec = m.group(1), m.group(2).strip()
        tp = f'{S}/references/{target}.md'
        if not os.path.isfile(tp):
            continue
        body = open(tp, encoding='utf-8', errors='ignore').read()
        key = sec.split('（')[0].strip()
        if key and key not in body:
            badA.append(f'{os.path.basename(f)}→{target}「{sec}」')
    for m in patB.finditer(t):
        sub, num = m.group(1), m.group(2)
        tp = f'{S}/SKILL.md' if sub is None else f'{S}/references/{sub}.md'
        if not os.path.isfile(tp):
            continue
        body = open(tp, encoding='utf-8', errors='ignore').read()
        # 标题可写作「## 3.1 …」或「## §3.1 …」（实测两种并存）
        if not re.search(r'^#{2,4} §?' + re.escape(num) + r'(?:\.|\s|$)', body, re.M):
            badB.append(f'{os.path.basename(f)}→§{num}@{os.path.basename(tp)}')
out = []
if badA:
    out.append('章节名未找到: ' + ', '.join(badA[:3]))
if badB:
    out.append('§ 指向不存在: ' + ', '.join(badB[:3]))
print('; '.join(out))
PYEOF
)
  if [ -z "$SEC_ISSUE" ]; then ok "章节级引用均可解析（章节名 + 限定式 §）"
  else bad "章节级引用问题 → ${SEC_ISSUE}"; fi
fi

echo "[11] benchmarks 支撑决策号语义相符"
if ! command -v python3 >/dev/null 2>&1; then
  na "决策号语义核验（缺 python3）"
else
  SEM_ISSUE=$(python3 <<'PYEOF'
import glob, re
S = 'skills/dsh-codepunk-workflow'
std = open(f'{S}/references/standard.md', encoding='utf-8').read()
mean = {int(m.group(1)): m.group(2).strip()
        for m in re.finditer(r'^\| D(\d{3}) \| ([^|]+?) \|', std, re.M)}
CJK = re.compile(r'[\u4e00-\u9fffA-Za-z0-9]+')
def grams(x):
    out = set()
    for t in CJK.findall(x):
        out |= {t[i:i+2] for i in range(max(0, len(t)-1))}
        out.add(t)
    return out
zero, weak = [], []
for f in sorted(glob.glob(f'{S}/benchmarks/*.md')):
    t = open(f, encoding='utf-8').read()
    m = re.search(r'支撑决策号：([^\n]{0,120})', t)
    if not m:
        zero.append(f"{f.split('/')[-1]}:无支撑决策号行")
        continue
    for d, name in re.findall(r'D(\d{3})（([^）]{1,20})）', m.group(1)):
        d = int(d)
        if d not in mean:
            zero.append(f"{f.split('/')[-1]}:D{d:03d}未登记")
            continue
        n = len(grams(name) & grams(mean[d]))
        if n == 0:
            zero.append(f"{f.split('/')[-1]}:D{d:03d}「{name}」与登记含义无共同词")
        elif n == 1:
            weak.append(f"{f.split('/')[-1]}:D{d:03d}「{name}」")
out = []
if zero:
    out.append('疑似错配: ' + '; '.join(zero[:3]))
# weak 只作提示，不判失败
print('; '.join(out))
if weak:
    print('WEAK=' + ','.join(weak[:3]))
PYEOF
)
  SEM_HARD=$(printf '%s' "$SEM_ISSUE" | sed -n '1p')
  SEM_WEAK=$(printf '%s' "$SEM_ISSUE" | sed -n '2p' | sed 's/^WEAK=//')
  if [ -z "$SEM_HARD" ]; then ok "支撑决策号与登记含义相符（零重叠 0 处）"
  else bad "决策号语义问题 → ${SEM_HARD}"; fi
  [ -n "$SEM_WEAK" ] && info "短括注（重叠 1，人工确认即可）: ${SEM_WEAK}"
fi

echo "[12] 状态取值合法性"
if ! command -v python3 >/dev/null 2>&1; then
  na "状态取值核验（缺 python3）"
else
  ST_ISSUE=$(python3 <<'PYEOF'
import glob, os, re
files = (['skills/dsh-codepunk-workflow/SKILL.md', 'README.md', 'agent.cordis.yml', 'preset.yml']
         + glob.glob('skills/dsh-codepunk-workflow/references/*.md')
         + [f for f in glob.glob('plans/*.sh') if 'checker-self-test.sh' not in f]   # 排除变异夹具
         + glob.glob('plans/*.py') + glob.glob('plans/*.mjs'))
declared = set()
for f in files:
    try:
        t = open(f, encoding='utf-8').read()
    except OSError:
        continue
    for m in re.finditer(r'status:\s*([a-z_]+)\s*#\s*([^\n]{3,200})', t):
        for tok in re.findall(r'[a-z_]{3,20}', m.group(2)):
            declared.add(tok)   # 注释内全部 ASCII 记号（含箭头式机器 a → b ⇄ c | d；粘连中文不影响）
    # 无 `#` 注释但同类列举（如 agents.yaml 的 last_seen 注释已含）
if not declared:
    print('无法采集已声明集合（模板已变）')
else:
    bad = []
    for f in files:
        if f.endswith(('standard.md',)):
            continue
        try:
            t = open(f, encoding='utf-8').read()
        except OSError:
            continue
        for i, ln in enumerate(t.split('\n'), 1):
            for m in re.finditer(r'\b(status|expected)[:：]\s*([a-z_]{3,20})', ln):
                if m.group(2) not in declared:
                    bad.append(f'{os.path.basename(f)}:{i} {m.group(2)}')
    print('; '.join(bad[:3]))
PYEOF
)
  if [ -z "$ST_ISSUE" ]; then ok "状态取值均在已声明集合内（集合自模板注释采集）"
  elif printf '%s' "$ST_ISSUE" | grep -q '无法采集'; then bad "状态取值核验失效：${ST_ISSUE}"
  else bad "状态取值越界 → ${ST_ISSUE}"; fi
fi

echo "[13] 状态值正文引用（死状态检测）"
if ! command -v python3 >/dev/null 2>&1; then
  na "死状态核验（缺 python3）"
else
  DEAD_ISSUE=$(python3 <<'PYEOF'
import glob, os, re
files = (['skills/dsh-codepunk-workflow/SKILL.md', 'README.md', 'agent.cordis.yml']
         + glob.glob('skills/dsh-codepunk-workflow/references/*.md'))
# 采集：模板行 `status: <值>  # a → b | c` 中声明的取值
vals, srcs = set(), {}
for f in files:
    try:
        t = open(f, encoding='utf-8').read()
    except OSError:
        continue
    for m in re.finditer(r'status:\s*[a-z_]+\s*#\s*([^\n]{3,120})', t):
        for tok in re.findall(r'[a-z_]{3,20}', m.group(1)):
            if tok in ('status', 'ok', 'fail'):
                continue
            vals.add(tok); srcs.setdefault(tok, m.group(1)[:40])
dead = []
for v in sorted(vals):
    hits = 0
    for f in files:
        try:
            t = open(f, encoding='utf-8').read()
        except OSError:
            continue
        for ln in t.split('\n'):
            if v not in ln:
                continue
            if re.match(r'^\s*-?\s*(status|expected)\s*:', ln):
                continue          # YAML 声明行不算正文引用（注释尾部可能含中文，勿按字符类判）
            hits += 1
    if hits == 0:
        dead.append(v)
print('; '.join(dead[:4]))
PYEOF
)
  if [ -z "$DEAD_ISSUE" ]; then ok "无死状态（每个声明取值均有正文引用）"
  else bad "死状态（仅存在于模板注释，无主体/无触发条件）→ ${DEAD_ISSUE}"; fi
fi

echo "[14] 夹具字面量纪律（自检夹具勿含触发守卫的字面量）"
FIXTURE="plans/checker-self-test.sh"
if [ ! -f "$FIXTURE" ]; then
  na "夹具字面量核验（缺 ${FIXTURE}）"
else
  FIX_HITS="$(grep -nE '/Users/[A-Za-z][A-Za-z0-9_-]*/|/home/[a-z][a-z0-9_-]*/|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}|192\.168\.[0-9]+\.[0-9]+|10\.[0-9]+\.[0-9]+\.[0-9]+' "$FIXTURE" 2>/dev/null | grep -vE '^\s*[0-9]+:\s*#' | head -3)"
  if [ -z "$FIX_HITS" ]; then ok "夹具无触发守卫的字面量（触发串须运行时拼接）"
  else bad "夹具含触发守卫的字面量 → $(printf '%s' "$FIX_HITS" | head -1 | cut -c1-100)；请改为运行时拼接"; fi
fi

echo "[15] 阶段引用可解析（流程自洽）"
STAGE_ISSUE=$(python3 <<'PYEOF'
import glob, os, re
CIRCLED = '①②③④⑤⑥'
stages_md = 'skills/dsh-codepunk-workflow/references/stages.md'
defined = set(re.findall(r'^##\s*([①②③④⑤⑥])', open(stages_md, encoding='utf-8').read(), re.M))
# 注意（F137）：**定义文件自身不算引用**——否则「孤立阶段」分支结构上永不可达
#   （stages.md 的 `## <阶段号>` 标题会被当成一次引用）。
files = (['skills/dsh-codepunk-workflow/SKILL.md', 'preset.yml', 'README.md']
         + [f for f in glob.glob('skills/dsh-codepunk-workflow/references/*.md') if f != stages_md])
refs = {}
for f in files:
    try:
        t = open(f, encoding='utf-8').read()
    except OSError:
        continue
    for c in re.findall(r'[①②③④⑤⑥]', t):
        refs.setdefault(c, set()).add(os.path.basename(f))
dangling = sorted(set(refs) - defined, key=CIRCLED.index)
orphan = sorted(defined - set(refs), key=CIRCLED.index)
out = []
if dangling:
    out.append('悬空引用（stages.md 未定义）: ' + ''.join(dangling))
if orphan:
    out.append('孤立阶段（零引用）: ' + ''.join(orphan))
print('; '.join(out))
PYEOF
)
  if [ -z "$STAGE_ISSUE" ]; then ok "六阶段定义与引用自洽（无悬空、无孤立）"
  else bad "阶段引用不自洽 → ${STAGE_ISSUE}"; fi

echo "[16] 自检期望串特异性（防「仅凭标题即通过」）"
SPEC_ISSUE=$(python3 <<'PYEOF'
import os, re
st = open('plans/checker-self-test.sh', encoding='utf-8').read()

def headers_of(path):
    try:
        t = open(path, encoding='utf-8').read()
    except OSError:
        return []
    h = re.findall(r'echo\s+"(\[[^\]]*\][^"]*)"', t)
    h += re.findall(r"printf\s+'(\[[^']*\][^']*)'", t)
    return h

bad = []
for label, cmd, rc, want in re.findall(r'check_rc\s+"([^"]+)"\s+"([^"]+)"\s+(\d+)\s+"([^"]*)"', st):
    if len(want) < 2:
        continue
    # 只看该断言**实际调用的脚本**的标题；自检自身标题不算（否则自伤）
    for tgt in [m for m in re.findall(r'plans/[A-Za-z0-9_.-]+\.(?:sh|mjs)', cmd)
                if 'checker-self-test' not in m]:
        for h in headers_of(tgt):
            if want in h:
                bad.append(label + ':「' + want + '」⊂' + os.path.basename(tgt) + '标题「' + h[:22] + '」')
print('; '.join(bad[:3]))
PYEOF
)
  if [ -z "$SPEC_ISSUE" ]; then ok "自检期望串均未被小节标题包含（无「仅凭标题通过」风险）"
  else bad "自检期望串特异性不足 → ${SPEC_ISSUE}"; fi

echo
if [ "$NFAIL" = 0 ]; then echo "✔ 无硬性不一致（16 类检查）"; exit 0; fi
echo "✗ 存在 ${NFAIL} 处不一致" >&2
exit 1
