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
#   6. 头部自称项数（preset-compat「七项检查」↔ 源码输出分支数，双分支时按咨询处理）（**仅提示，不计失败**）
#   23. 简报检索日（含 URL 的 benchmarks MUST 带 `retrieved_at`；若原始检索日不可考，须显式写
#       「未记录」并注明依据——依赖约定「URL+retrieved_at+事实/推断」；F151 实证）
#   22. 矩阵覆盖（每个检查类 1..N 须在 skill-governance 矩阵中被提及——含「第 a–b 类」范围写法；
#       防「新增检查类却忘记登记矩阵」，F150 实证）
#   21. 岗位数一致性（`N 岗位` 声称须与配置实况相符：内建 11 + 外部后端 2；出现「13 岗位」的行
#       须带历史/例外标记——F149 实证：现在时声称「13 岗位全 continuable」属过度声称）
#   20. 退出码契约实测（探针表：用法/环境错误必须 2——F128/F146 类的契约漂移机械门；
#       输入不存在、参数非法、坏根等，逐条实跑断言）
#   19. 硬规则命名空间洁净（`R###`（三位以上）不得出现——`R1–R15` 是硬规则号，轮次引用请写
#       「轮次 N」，避免同形误读；F144 实证）
#   18. pwsh 钩子参数语法（Windows 侧生成的钩子体不得用 `$1`/`$2` 位置参数——PowerShell 无该
#       语法，参数恒空致钩子静默退化；F142 实证）
#   17. 移植对等性（sh↔ps1 对数由实况派生（不写死）：POSIX 侧已修的关键守卫关键词 MUST 在 Windows 端口出现——
#       防「修了一侧忘另一侧」；F139 实证：link.ps1 曾缺解析/语义核验）
#   16. 自检期望串特异性（`check_rc` 的期望串 MUST NOT 被被检脚本的**小节标题**包含——
#       否则断言可能仅凭标题即通过＝假通过；实测由轮次 131 的「死状态」误判导出）
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

# F195：本工具多处判据依赖**多字节**模式（占位符、编号、①②③…）。C/POSIX locale 下 BSD 工具链会
#   逐字节处理，`grep`/`cut` 甚至报 `Invalid argument` / `Illegal byte sequence` → 判据失效或**误报**
#   （假拒绝；F192/F193 已各实证一处）。故在当前 locale 为 C/POSIX（或未设）且系统存在 UTF-8 locale 时固定之。
# F196：以 `locale charmap` 判定**是否 UTF-8**，而非枚举 C/POSIX——非 UTF-8 locale（如 ISO-8859 系）同样会
#   逐字节处理并误报（实证：`LC_ALL=de_DE.ISO8859-15` 下 doc-consistency 误报 1 处不一致）。
case "$(locale charmap 2>/dev/null)" in
  UTF-8|utf8|UTF8) ;;
  *)
    for _l in en_US.UTF-8 UTF-8; do
      if locale -a 2>/dev/null | grep -qx "$_l"; then export LC_ALL="$_l"; break; fi
    done ;;
esac
# -h/--help：打印头部用法（与其余脚本一致的通用约定）
case "${1:-}" in
  -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
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
# F164：同一声称可能在源内出现多处（如 README 两处「N 指标」「N 组」）——只取首处会导致
#   两处各自漂移而不被发现。本助手要求「全部出现处一致且等于实况」，零声明则报错（防空转）。
cmp_claims_all() { # 标签 实况 模式 文件
  local label="$1" actual="$2" pat="$3" file="$4"
  local vals bad=""
  vals="$(grep -oE "$pat" "$file" 2>/dev/null | grep -oE '[0-9]+' | tr '\n' ' ')"
  for v in $vals; do [ "$v" = "$actual" ] || bad="$bad $v"; done
  if [ -z "$vals" ]; then bad "${label}：源内未找到计数声称（判据空转风险）"
  elif [ -n "$bad" ]; then bad "${label} 声称不一致（源内多值含:${bad}，实际 ${actual}）"
  else ok "${label} 实际 ${actual} = 声称（全部出现处一致）"; fi
}

cmp_num() {
  if [ -z "$3" ]; then bad "$1：README 未声明计数（实际 $2）"
  elif [ "$2" = "$3" ]; then ok "$1 实际 $2 = 声称 $3"
  else bad "$1 实际 $2，README 声称 $3"; fi
}
cmp_claims_all "评分指标" "$(grep -cE '^# ── [AB][0-9]+ ' plans/preset-score.sh)" \
                '[0-9]+ 指标' README.md
cmp_claims_all "审计分组" "$(grep -cE '^echo "\[组' plans/preset-audit.sh)" \
                '[0-9]+ 组' README.md
BAT_N="$(grep -cE '^# [0-9]+[a-c]?\)' plans/verify-battery.sh)"
# F162：README 中**每一处**该计数声称都必须唯一且等于实况——原先只取 head -1，
#   导致README 两处声称（命令表与文件清单）可各自漂移而不被发现。
BAT_CLAIMS="$(grep -oE '[0-9]+ 项(独立验证|一次跑完)' README.md | grep -oE '[0-9]+' | sort -u | tr '\n' ' ')"
BAT_UNIQ="$(printf '%s' "$BAT_CLAIMS" | wc -w | tr -d ' ')"
cmp_claims_all "电池项数" "$BAT_N" '[0-9]+ 项(独立验证|一次跑完)' README.md
# F163/F164：references 与 benchmarks 的篇数声称按**标签行**绑定取值（对 README 重排免疫），
#   且复用多值一致助手：标签行作为唯一取值来源，避免「按顺序取首处」的脆弱绑定。
REF_CLAIM="$(grep -E '^  references/' README.md | grep -oE '[0-9]+ 篇' | grep -oE '[0-9]+')"
BM_CLAIM="$(grep -E '^  benchmarks/' README.md | grep -oE '[0-9]+ 篇' | grep -oE '[0-9]+')"
if [ -z "$REF_CLAIM" ]; then bad "references：README 标签行未声明篇数（判据空转风险）"
else cmp_num "references" "$(ls "$REF"/*.md 2>/dev/null | wc -l | tr -d ' ')" "$REF_CLAIM"; fi
if [ -z "$BM_CLAIM" ]; then bad "benchmarks：README 标签行未声明篇数（判据空转风险）"
else cmp_num "benchmarks" "$(ls "$BM"/*.md 2>/dev/null | wc -l | tr -d ' ')" "$BM_CLAIM"; fi
cmp_num "硬规则上限" "$(grep -oE '^\| R[0-9]+ ' "$SKILL" 2>/dev/null | grep -oE '[0-9]+' | sort -n | tail -1)" \
        "$(python3 -c '
import re,sys
# F193：多字节模式在 C locale 下会被 BSD grep 拒绝或按字节误配——改用 python（locale 无关）
t=open("README.md",encoding="utf-8",errors="replace").read()
m=re.search(r"硬规则 R1[\u2013-]R([0-9]+)", t)
print(m.group(1) if m else "")
')"
cmp_num "自检变异项" "$(grep -oE 'M[0-9]+' plans/checker-self-test.sh | sort -u | wc -l | tr -d ' ')" \
        "$(grep -oE '\*\*[0-9]+ 项\*\*已知缺陷' README.md | head -1 | grep -oE '[0-9]+')"

echo "[2] 阶段口径（六阶段）"
P_README=$(awk '/^## 流程总览/,/^```/' README.md | grep -cE '^\| [1-6]️⃣')
P_PRESET=$(python3 -c '
# F193：多字节字符类在 C locale 下逐字节匹配 → 计数漂移（曾致 6/8/1 之类误报）
marks="①②③④⑤⑥"
t=open("preset.yml",encoding="utf-8",errors="replace").read()
print(len({c for c in t if c in marks}))
')
# F175：stages.md 缺失时不抛 raw grep 噪声；置 0 由下方比较给出清晰结论
P_STAGES=0
if [ -f "$REF/stages.md" ]; then
  P_STAGES=$(python3 -c '
import sys
marks="①②③④⑤⑥"
seen=set()
for l in open(sys.argv[1],encoding="utf-8",errors="replace"):
    if l.startswith("## ") and len(l) > 3 and l[3] in marks:
        seen.add(l[3])
print(len(seen))
' "$REF/stages.md")
fi
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
# F231：**空输入守卫** —— plans 下无可检脚本时，下方两处循环均不执行 ⇒ 两个判据都会**恒真通过**（0 脚本 ⇒ 「无违规」）。
#   与 F230/class 18、F201/B0 的「空输入下判据恒真——无法核验 ≠ 通过」口径统一：以哨兵值让两条判据自行失败。
if ! ls plans/*.sh plans/*.py plans/*.mjs 2>/dev/null | grep -qv '^plans/doc-consistency\.sh$'; then
  RC_EMPTY_SENTINEL="（plans 下无可检脚本：无法核验 ≠ 通过）"
else
  RC_EMPTY_SENTINEL=""
fi
rc_bad="$RC_EMPTY_SENTINEL"
# F187：覆盖面从 .sh 扩到 .py/.mjs（规则文本为「**运行型**脚本 MUST 声明退出码」，README 亦记载外层工具的码）；
#   声明判定=**头部 30 行内的码表行**（同时含「退出码」与形如 `0=` 的码），兼容 `#` / JSDoc `*` / docstring 三种风格。
for f in plans/*.sh plans/*.py plans/*.mjs; do
  # F192：多字节词用 `grep -F`（字节级、locale 无关——BSD grep 在 C locale 下用多字节 **模式**会报
  #   `Invalid argument` 并致本检查恒空转）；码表另以 ASCII 的 `[0-9]=` 判定。
  decl_line=$(python3 - "$f" <<'PYEOF'
import sys
# F192：不使用多字节 grep 参数——BSD grep 在 C locale 下会报 `Invalid argument`（与 F097 的
#   `grep -P` 同族），曾致本检查恒空转。python 读文件与判字符均不受 locale 影响。
try:
    head = open(sys.argv[1], encoding='utf-8', errors='replace').read().split('\n')[:30]
except Exception:
    head = []
for l in head:
    if '退出码' in l and '=' in l and any(c.isdigit() for c in l):
        print(l)
        break
PYEOF
)   # F187/F192：头部 30 行内含「退出码」且含码表；三种注释风格皆可
  [ -n "$decl_line" ] || continue
  decl=$(printf '%s' "$decl_line" | grep -oE '[0-9][[:space:]]*=' | grep -oE '[0-9]' | sort -u | tr -d '\n')
  [ -n "$decl" ] || { na "$(basename "$f") 退出码行未解析出码"; continue; }
  missing=""
  for c in $(grep -oE '\bexit [0-9]+|sys\.exit\([0-9]+\)|process\.exit\([0-9]+\)' "$f" | grep -oE '[0-9]+' | sort -u); do
    [ -n "$c" ] || continue
    printf '%s' "$decl" | grep -q -- "$c" || missing="$missing$c"
  done
  [ -z "$missing" ] || rc_bad="$rc_bad $(basename "$f")(缺:$missing)"
done
[ -z "$rc_bad" ] && ok "实现用到的退出码均在头部契约内" || bad "退出码契约缺声明:${rc_bad}"
# 缺声明检测（F152）：**运行型**脚本 MUST 在头部声明退出码；纯 source/库脚本豁免。
#   旧写法对无声明者 `|| continue` 静默跳过，「缺声明」分支实为空转。
RC_UNDECL="$RC_EMPTY_SENTINEL"
for f in plans/*.sh plans/*.py plans/*.mjs; do
  base=$(basename "$f")
  case "$base" in dsh-codepunk-home.sh) continue ;; esac        # 纯 source 的路径常量脚本，无退出码
  python3 -c '
import sys
try:
    head = open(sys.argv[1], encoding="utf-8", errors="replace").read().split("\n")[:30]
except Exception:
    head = []
ok = any(("退出码" in l) and ("=" in l) and any(c.isdigit() for c in l) for l in head)
sys.exit(0 if ok else 1)
' "$f" && continue   # F192：同上，避免多字节 grep 参数在 C locale 下失效
  case "$f" in *.sh) grep -qE '\bsource\b|^\s*\.\s' "$f" 2>/dev/null && continue ;; esac  # F187：库脚本豁免**仅限 .sh**（.py/.mjs 里的 source 字样会误豁免）
  grep -qE 'exit [0-9]|sys\.exit\(|process\.exit\(' "$f" 2>/dev/null || continue   # F187：非「运行型」（无显式退出调用）豁免
  RC_UNDECL="$RC_UNDECL $base"
done
[ -z "$RC_UNDECL" ] && ok "运行型脚本均声明了退出码" || bad "运行型脚本缺退出码声明:${RC_UNDECL}"

echo "[6] 头部自称项数（仅提示，不计失败——计数口径以实跑输出为准）"
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
证据门 exit_code|all|exit_code[ ]*[=＝][ ]*([0-9]+)
SKILL 体积上限（字节）|all|(?:≤|超预算[ ]*)([0-9]{5})
汇报摘要 token 预算|all|≤[ ]*([0-9]{3,4})[ ]*token
续行空转阈值（轮）|all|连续[ ]*([0-9]+)[ ]*轮无产出
并行上限 S|all|S≤([0-9]+)
并行上限 M|all|M≤([0-9]+)
并行上限 L|all|L≤([0-9]+)'
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
# F175：文件缺失时给出清晰结论而非 FileNotFoundError（与 class 2 的结论一致）
if os.path.isfile(stages_md):
    defined = set(re.findall(r'^##\s*([①②③④⑤⑥])', open(stages_md, encoding='utf-8').read(), re.M))
else:
    print('stages.md 缺失（阶段定义文件）'); raise SystemExit(1)
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

echo "[17] 移植对等性（sh ↔ ps1）"
PARITY_ISSUE=$(python3 <<'PYEOF'
import os
import re
pairs = [
    ('dsh-codepunk-link.sh',       'dsh-codepunk-link.ps1',       ['结构非法', '语义非法', '未初始化']),
    ('dsh-codepunk-leak-guard.sh', 'dsh-codepunk-leak-guard.ps1', ['禁词', '通用']),
    ('dsh-codepunk-init.sh',       'dsh-codepunk-init.ps1',       ['总库', '骨架']),
    ('dsh-codepunk-home.sh',       'dsh-codepunk-home.ps1',       ['路径常量']),
]
miss = []
# leak-guard 专项：通用模式**签名**须两侧皆有（防「一侧加模式、另一侧忘」）
sigs = ['/Users/', '/home/', 'Applications/', '10\\.', '192\\.168\\.', 'sk-[A-Za-z0-9]{20,}',
        'AKIA', 'gh[pousr]_', 'xox[baprs]-', 'PRIVATE KEY', '@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}']
for sh, ps, keys in pairs:
    shp, psp = 'plans/' + sh, 'plans/windows/' + ps
    if not (os.path.isfile(shp) and os.path.isfile(psp)):
        miss.append(sh + '/缺文件')
        continue
    st = open(shp, encoding='utf-8').read()
    pt = open(psp, encoding='utf-8').read()
    for k in keys:
        if k in st and k not in pt:
            miss.append(ps + '缺「' + k + '」')
    if 'leak-guard' in sh:
        for sig in sigs:
            if sig in st and sig not in pt:
                miss.append(ps + '缺签名 ' + sig)
    # 功能开关集合对等（轮次 170：F139/F142/F160 三次「修了 sh 忘 ps1」的共同盲区）
    #   保守白名单判据，且不使用正则（规避嵌套转义风险）。
    FLAGS = ['help', 'tree', 'history', 'staged', 'msg', 'list', 'installhook', 'check']
    sh_flags = {t[2:].replace('-', '').lower() for t in re.findall('--[a-z-]+', st)}
    ps_flags = set()
    for key in ('[switch]$', '[string]$'):
        idx = 0
        while True:
            idx = pt.find(key, idx)
            if idx < 0:
                break
            j = idx + len(key)
            name = ''
            while j < len(pt) and (pt[j].isalnum() or pt[j] == '_'):
                name = name + pt[j]
                j = j + 1
            if name:
                ps_flags.add(name.lower())
            idx = j
    alias_key = '[Alias(' + chr(39) + 'h' + chr(39) + ')]'
    if alias_key in pt:
        ps_flags.add('help')
    for fl in FLAGS:
        if fl in sh_flags and fl not in ps_flags:
            miss.append(ps + ' 缺开关 --' + fl)
        if fl in ps_flags and fl not in sh_flags:
            miss.append(sh + ' 缺选项 -' + fl)
    # F165：退出码集合对等（sh 的字面 exit N ∪ ps1 的 exit N 与 $script:rc = N）
    sh_codes = {m.group(1) for m in re.finditer('exit ([0-9]+)', st)}
    ps_codes = {m.group(1) for m in re.finditer('exit ([0-9]+)', pt)}
    ps_codes |= {m.group(1) for m in re.finditer('script:rc = ([0-9]+)', pt)}
    only_sh = sorted(sh_codes - ps_codes)
    if only_sh:
        miss.append(ps + ' 缺退出码 ' + ','.join(only_sh))
    # F166：param 里声明的**命名**开关 MUST 在该文件头部用法注释中出现（防「有开关却不写用法」）。
    #   位置参数（[Parameter(Position = N)]）与已用别名写法（如 -y 代表 -Yes）不计。
    head_lines = [ln for ln in pt.split('\n')[:45] if ln.lstrip().startswith('#')]
    head = '\n'.join(head_lines)
    _pi = pt.find('param(')
    if _pi >= 0:
        _depth = 0
        _k = _pi + len('param(') - 1
        while _k < len(pt):
            if pt[_k] == '(':
                _depth = _depth + 1
            elif pt[_k] == ')':
                _depth = _depth - 1
                if _depth == 0:
                    break
            _k = _k + 1
        pblock = pt[_pi:_k + 1]
    else:
        pblock = ''
    _segs = pblock.split(',')          # 参数以逗号分隔，逐段判定（避免跨段误取别名）
    for _seg in _segs:
        _ii = _seg.find('$')
        if _ii < 0:
            continue
        _j = _ii + 1
        _nm = ''
        while _j < len(_seg) and (_seg[_j].isalnum() or _seg[_j] == '_'):
            _nm = _nm + _seg[_j]
            _j = _j + 1
        if not _nm:
            continue
        if 'Position' in _seg:
            continue                    # 位置参数：用法里以 <占位> 形式出现
        _ai = _seg.find("[Alias('")
        _alias = _seg[_ai + 8] if _ai >= 0 else None
        if _nm in head or ('-' + _nm) in head or (_alias and ('-' + _alias) in head):
            continue
        miss.append(ps + ' 用法未列 -' + _nm)
print('PARITY-DONE:' + '; '.join(miss[:4]))
PYEOF
)
  case "$PARITY_ISSUE" in
    PARITY-DONE:*) REST="${PARITY_ISSUE#PARITY-DONE:}"
      # F183：对数与核验范围**同源派生**（class 17 逐对比较 plans/windows/*.ps1 与其 POSIX 对应体），
    #   避免新增一对后消息仍写死**固定对数**而静默低报。
    PAIRS_CN=$(ls plans/windows/*.ps1 2>/dev/null | wc -l | tr -d ' ')
    if [ -z "$REST" ]; then ok "${PAIRS_CN} 对 sh↔ps1 关键守卫关键词与功能开关对等"
      else bad "移植对等性缺口 → ${REST}"; fi ;;
    *) bad "第 17 类未完成（疑似被吞错，无法核验≠通过）：${PARITY_ISSUE:-空输出}" ;;
  esac

echo "[18] pwsh 钩子参数语法"
# F230：**空输入守卫** —— 无 ps1 时旧实现 `grep` 得空 ⇒ 直接 `ok`（0 文件 ⇒ 恒真）。
#   与 class 1/B0/B7 的「空/截断输入下判据恒真——无法核验 ≠ 通过」口径统一。
if ! ls plans/windows/*.ps1 >/dev/null 2>&1; then
  bad "pwsh 钩子语法无法核验：plans/windows 下无 .ps1 文件——无法核验 ≠ 通过"
else
# 排除注释行（说明文字里可能提到 `$1` 作反例）
HOOK_SYNTAX=$(grep -nE '\$[1-9]' plans/windows/*.ps1 2>/dev/null | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' | grep -vE '\\\$[1-9]' | head -3)
if [ -z "$HOOK_SYNTAX" ]; then ok "Windows 侧未使用 PS 不支持的位置参数语法（\$1/…）"
else bad "Windows 侧出现 PS 不支持的位置参数语法 → $(printf '%s' "$HOOK_SYNTAX" | head -1 | cut -c1-96)"; fi
fi

echo "[19] 硬规则命名空间洁净（禁 R### 轮次引用）"
NS_ISSUE=$(grep -rnoE '\bR[0-9]{3,}\b' skills README.md plans/*.sh plans/*.py plans/*.mjs agent.cordis.yml 2>/dev/null \
             | grep -v bench | grep -v 'checker-self-test.sh' | head -3)   # 排除变异夹具（其载荷含三位 R 号）
  # 注意：消息里不得出现反引号（双引号内会被当命令替换）或三位以上 R 样例（会被本类自匹配）
  if [ -z "$NS_ISSUE" ]; then ok "无与硬规则同形的 R 三位号引用（轮次引用一律写作「轮次 N」）"
  else bad "出现与硬规则同形的 R 三位号引用 → $(printf '%s' "$NS_ISSUE" | head -1 | cut -c1-90)"; fi

echo "[20] 退出码契约实测（用法/环境错误 → 2）"
RC_BAD=""; RC_N=0; RC_V=0; RC_GAP=""
probe_rc() { # probe_rc <期望码> <标签> <命令> [缺口标记]
  local want="$1" label="$2" cmd="$3" gap="${4:-}" rc=0 out=""
  out=$(eval "$cmd" 2>&1) || rc=$?
  RC_N=$((RC_N + 1))                                  # 探针计数：确保每个探针都真的执行了
  # F180：若探针因**环境缺口**（如缺 tree-sitter 依赖）而返回期望码，则它并没有真正核验契约，
  #   不得计入通过（否则「用法错误 2」会被「缺依赖 2」冒充 = 假通过）。
  if [ -n "$gap" ] && printf '%s' "$out" | grep -q "$gap"; then
    RC_V=$((RC_V + 1))
    RC_GAP="${RC_GAP}${label} "
    return 0
  fi
  # F209：rc 126/127 = **运行时不可用/不可执行**（`command not found`，如缺 node/pwsh）——属**环境缺口**，
  #   不是「退出码契约漂移」。否则缺运行时的环境会被误报为**质量缺陷**（实测：隐藏 node 后本项报
  #   「✗ 退出码契约漂移 → ps-validate 缺参数(rc=127,want=2) …」），与 F180 的缺口口径及 F194/F203/F207 同族冲突。
  if [ "$rc" = 126 ] || [ "$rc" = 127 ]; then
    RC_V=$((RC_V + 1))
    RC_GAP="${RC_GAP}${label}(缺运行时) "
    return 0
  fi
  [ "$rc" = "$want" ] || RC_BAD="${RC_BAD}${label}(rc=${rc},want=${want}) "
}
probe_rc 2 "compat 坏根"      "timeout 60 python3 plans/preset-compat.py /nonexistent"
probe_rc 2 "compat 缺 DSH 根" "env -u DSH_APP_ROOT -u DSH_ASAR timeout 60 python3 plans/preset-compat.py /nonexistent"
probe_rc 2 "fidelity 缺参数"  "timeout 60 python3 plans/fidelity-gate.py"
probe_rc 2 "fidelity 坏模式"  "timeout 60 python3 plans/fidelity-gate.py bogus"
probe_rc 2 "ps-validate 缺参数" "timeout 60 node plans/ps-validate.mjs" "缺依赖"
probe_rc 2 "ps-validate 缺文件" "timeout 60 node plans/ps-validate.mjs /nonexistent/x.ps1" "缺依赖"
probe_rc 2 "declare 坏子命令"  "timeout 60 node plans/preset-declare.mjs bogus"
probe_rc 2 "audit 坏根"       "bash plans/preset-audit.sh /tmp"
probe_rc 2 "doc-consistency 坏根" "bash plans/doc-consistency.sh /tmp"
# -h/--help 通用约定：六个脚本均须返回 0（F153）
probe_rc 0 "audit -h"           "bash plans/preset-audit.sh -h"
probe_rc 0 "score -h"           "bash plans/preset-score.sh -h"
probe_rc 0 "doc-consistency -h" "bash plans/doc-consistency.sh -h"
probe_rc 0 "verify-worktree -h" "bash plans/verify-worktree.sh -h"
probe_rc 0 "link -h"            "bash plans/dsh-codepunk-link.sh -h"
probe_rc 0 "leak-guard -h"      "bash plans/dsh-codepunk-leak-guard.sh -h"
RC_DECL=15   # 声明探针数（9 条用法/环境错 + 6 条 -h）；新增探针须同步此值
if [ "$RC_N" -ne "$RC_DECL" ]; then bad "退出码探针仅执行 ${RC_N}/${RC_DECL} 条（疑似被吞错，无法核验≠通过）"
elif [ -n "$RC_BAD" ]; then bad "退出码契约漂移 → ${RC_BAD}"
elif [ "$RC_V" -gt 0 ]; then info "退出码探针 ${RC_N} 条中 ${RC_V} 条因**环境缺口**无法核验（${RC_GAP}）——无法核验≠通过（F180）"
else ok "${RC_DECL} 条探针：用法/环境错误返回 2、-h 返回 0"; fi

echo "[21] 岗位数一致性（11 内建 + 2 外部）"
ROLE_COUNT_ISSUE=$(python3 <<'PYEOF'
import glob, os, re
# 实况：yml 中 tool-subagent-* 条目 = 11 内建岗位 + 2 外部后端 + 3 控制面
# F234：**输入存在性守卫** —— 旧实现 `open('agent.cordis.yml')` 无守卫 ⇒ 文件缺失时抛 **原始 Traceback**（违反本套件
#   「禁裸 Traceback」卫生规则），且 python 中断后 stdout 为空 ⇒ 变量空 ⇒ **判据假通过（报「岗位数声称与配置实况一致」）**。
try:
    t = open('agent.cordis.yml', encoding='utf-8').read()
except OSError:
    print('无法核验：agent.cordis.yml 缺失或不可读——无法核验 ≠ 通过')
    raise SystemExit
ids = re.findall(r'id:\s*tool-subagent-([a-z-]+)', t)
EXT = {'codex', 'claude-code'}
CTRL = {'control', 'list-agents', 'fork'}
builtin = [i for i in ids if i not in EXT | CTRL]
ext = [i for i in ids if i in EXT]
bad = []
if len(builtin) != 11 or len(ext) != 2:
    bad.append('配置实况异常：内建 %d / 外部 %d（期望 11/2）' % (len(builtin), len(ext)))
files = (['skills/dsh-codepunk-workflow/SKILL.md', 'README.md']
         + glob.glob('skills/dsh-codepunk-workflow/references/*.md'))
MARK = ('历史', '当时', '已废弃', '⚠', '外部后端', 'one-shot', '不适用')
for f in files:
    try:
        tt = open(f, encoding='utf-8').read()
    except OSError:
        continue
    for ln in tt.split('\n'):
        if '13 岗位' in ln and not any(m in ln for m in MARK):
            bad.append(os.path.basename(f) + ':' + ln.strip()[:60])
print('; '.join(bad[:3]))
PYEOF
)
  if [ -z "$ROLE_COUNT_ISSUE" ]; then ok "岗位数声称与配置实况一致（11 内建 + 2 外部；13 仅见于历史/例外语境）"
  else bad "岗位数声称问题 → ${ROLE_COUNT_ISSUE}"; fi

echo "[22] 矩阵覆盖（新增检查类须登记矩阵）"
MTX_ISSUE=$(python3 <<'PYEOF'
import re
dc = open('plans/doc-consistency.sh', encoding='utf-8').read()
classes = sorted({int(m) for m in re.findall(r'^echo "\[(\d+)\]', dc, re.M)})
# F234：同上（class 22）——矩阵来源文件缺失时抛 Traceback 且判据假通过；改为显式「无法核验」并干净退出。
try:
    g = open('skills/dsh-codepunk-workflow/references/skill-governance.md', encoding='utf-8').read()
except OSError:
    print('无法核验：skill-governance.md 缺失或不可读——无法核验 ≠ 通过')
    raise SystemExit
covered = set()
for m in re.finditer(r'第\s*(\d+)\s*[–\-—~]\s*(\d+)\s*类', g):
    covered |= set(range(int(m.group(1)), int(m.group(2)) + 1))
covered |= {int(m.group(1)) for m in re.finditer(r'第\s*(\d+)\s*类', g)}
missing = [c for c in classes if c not in covered]
print('; '.join('类 ' + str(c) for c in missing[:4]))
PYEOF
)
  if [ -z "$MTX_ISSUE" ]; then ok "全部检查类均已在治理矩阵登记"
  else bad "矩阵缺登记 → ${MTX_ISSUE}"; fi

echo "[23] 简报检索日（含 URL 须带 retrieved_at）"
BM_ISSUE=$(python3 <<'PYEOF'
import glob, os, re
bad = []
for f in sorted(glob.glob('skills/dsh-codepunk-workflow/benchmarks/*.md')):
    t = open(f, encoding='utf-8').read()
    if not re.search(r'https?://', t):
        continue
    if 'retrieved_at' not in t and '未记录' not in t:
        bad.append(os.path.basename(f))
print(', '.join(bad[:3]))
PYEOF
)
  if [ -z "$BM_ISSUE" ]; then ok "含 URL 的简报均带 retrieved_at（或无检索日时显式标注）"
  else bad "简报缺检索日 → ${BM_ISSUE}"; fi

# class 17 子项（F179）：ps1 工作树行尾须为 CRLF（.gitattributes eol=crlf 的落地校验）
if git rev-parse --git-dir >/dev/null 2>&1; then
  EOLBAD=$(git ls-files --eol plans/windows/ 2>/dev/null | awk '$2 != "w/crlf" {print $NF}' | tr '\n' ' ')
  [ -z "$EOLBAD" ] && ok "ps1 工作树行尾均为 CRLF（eol=crlf 落地）" || bad "ps1 工作树行尾非 CRLF: ${EOLBAD}"
else
  info "非 git 工作区，跳过 ps1 行尾校验"
fi

echo
if [ "$NFAIL" = 0 ]; then echo "✔ 无硬性不一致（23 类检查）"; exit 0; fi
echo "✗ 存在 ${NFAIL} 处不一致" >&2
exit 1
