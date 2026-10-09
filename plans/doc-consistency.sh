#!/usr/bin/env bash
# =============================================================================
# doc-consistency.sh —— 文档「声称 ↔ 实现」一致性核对（补覆盖矩阵的首要空档）
#
# 退出码: 0=无硬性不一致（各检查类全通过）; 1=存在不一致（逐条列出）; 2=用法/环境错误（预设根不存在或不可读）
# -----------------------------------------------------------------------------
# 覆盖矩阵（references/skill-governance.md）把「文档声称 ↔ 实现」列为无机械检查的首要空档——
# 历次审计中该类最高产（F077/F082/F083/F088/F090/F092/F093）。本脚本固化其中可机械化的部分：
#   1. 计数声称（15 指标 / 5 组 / 电池项数 / 18 references / 16 benchmarks）
#   2. 阶段口径（README 表 = preset.yml 阶段项 = stages.md 阶段号 = 6）
#   3. 术语咨询（裸用「工作区」列出供人工确认；**咨询不判失败**——矩阵已把术语一致性列为人工项）
#   4. 工具存在性（**全部跟踪的 .md** 中提到的 `plans/*` 引用必须真实存在；扩展名 sh|py|mjs|cjs|ps1；
#      域与空枚举口径见 F327/F408）
#   5. 退出码契约（头部「# 退出码」行声明的码集合须覆盖实现用到的 `exit N`；子项：外部输入
#      变量（未赋值或 `${VAR:-默认}` 形式）MUST 被记载于任一 .md 或脚本头部注释块——F358）
#   6. 头部自称项数（preset-compat「七项检查」↔ 源码输出分支数，双分支时按咨询处理）（**仅提示，不计失败**）
#   26. 治理矩阵载体可解析（矩阵行内反引号的文件型引用 MUST 在仓内可解析，或为 `artifacts.md`
#       以 `##` 小节声明的制品名，或该行显式标注「非仓内」——F385：原「巡检节奏」行以运行根
#       本地脚本 `tools/patrol-cadence.py` 作为「机械」载体，仓内不可复现且仓内已有等价门）
#   25. 同一制品的多处生成器须一致（INDEX 骨架模板：link 与 init 的 heredoc 须逐字节一致——F360）
#   24. Markdown 表格列数一致（表格行的单元格数 MUST NOT 超过表头——GFM 规范下多余单元格被忽略
#       ⇒ 内容静默丢失；代码跨度内的 `|` 须转义为 `\|`。行单元格数少于表头则补空单元格，不判失败。
#       F295 实证：10 行不一致，其中 4 行为代码跨度内未转义 `|`）
#   23. 简报检索日（含 URL 的 benchmarks MUST 带 `retrieved_at`；若原始检索日不可考，须显式写
#       「未记录」并注明依据——依赖约定「URL+retrieved_at+事实/推断」；F151 实证）
#   22. 矩阵覆盖（每个检查类 1..N 须在 skill-governance 矩阵中被提及——含「第 a–b 类」范围写法；
#       防「新增检查类却忘记登记矩阵」，F150 实证）
#   21. 岗位数一致性（`N 岗位` 声称须与配置实况相符：内建 11 + 外部后端 2；出现「13 岗位」的行
#       须带历史/例外标记——F149 实证：现在时声称「13 岗位全 continuable」属过度声称）
#   20. 退出码契约实测（探针表：用法/环境错误必须 2——F128/F146 类的契约漂移机械门；
#       子项：`-h`/`--help` 约定须由**全部运行型脚本**实现，且探针表覆盖全部实现者——F361）
#       输入不存在、参数非法、坏根等，逐条实跑断言）
#   19. 硬规则命名空间洁净（`R###`（三位以上）不得出现——`R1–R16` 是硬规则号，轮次引用请写
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
#   8. 日期形态与未来日期（须 YYYY-MM-DD / YYYY-MM；不得出现未来日期——「实测」不能发生在未来；
#      未来日期上限＝UTC 今天 +1 天，容忍时区偏移：作者本机今天可超前 UTC 今天 1 天，而 CI 为 UTC 时钟——
#      F365 实证：本地 00:00–07:00（UTC+7）产生的合法日期在 CI 上被判未来、PR 假红）
#   7. 跨文件阈值一致（同一机制在文档/脚本/配置中的数值必须唯一：评分基准与上下限、
#      retries 扣分与上限、handoff 缺件扣分、巡检周期、收口轮数、证据门退出码；
#      另含「分支保护必需检查名」：`plans/github-setup.sh` 的 `CHECK_CONTEXTS` ↔
#      `.github/workflows/ci.yml` 的作业 `name` ↔ `docs/maintenance.md` 的提及——
#      ruleset 按**上下文名**匹配，作业改名后该检查永不出现 ⇒ PR 永久阻塞且无门禁可见；F347 实证；
#      另含「必需检查的文档声称 ↔ 作业实际执行」：`CONTRIBUTING.md` 门禁表给出的可执行等价命令
#      必须真被该作业执行、声称覆盖 Windows 侧则该作业须触及 ps1、指向电池项则电池须有该项——
#      实测（修复前）「跨平台可移植」声称 Windows 侧对等 + 电池「跨平台项」，两者皆不成立；F354 实证；
#      另含「Dependabot 声明 ↔ 仓库与治理脚本」：声明的生态须有对应清单（否则该条目恒不产出 PR）、
#      `labels` 引用的标签须由 `plans/github-setup.sh` 幂等创建（否则该字段静默失效）、
#      `docs/maintenance.md` 的生态清单须与声明一致——实测（修复前）声明 `pip` 而仓库无任何 pip 清单且
#      文档声称巡检该生态；本轮巡检实证）
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
    for _l in en_US.UTF-8 C.UTF-8 C.utf8 UTF-8; do
      if locale -a 2>/dev/null | grep -qx "$_l"; then export LC_ALL="$_l"; break; fi
    done ;;
esac
# -h/--help：打印头部用法并返回 0。仓内约定只对**实现者**成立（实现者 MUST 返回 0 并打印用法；
#   未实现者按用法错误返回 2）——实测 10 个实现 / 8 个未实现，第 20 类探针覆盖全部实现者。
case "${1:-}" in
  -h|--help) sed -n '2,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT" 2>/dev/null || { echo "✗ 预设根不存在: $ROOT" >&2; exit 2; }
# 仓库标识校验：存在但非本预设仓库的根路径属「用法/环境错误」（exit 2），
#   否则检查器会在错误的树上判 1、甚至挂起（实测：preset-score 于错误根 rc=124）。
if [ ! -f skills/dsh-codepunk-workflow/SKILL.md ] || [ ! -d plans ]; then
  printf '✗ 根路径不是本预设仓库（缺 skills/dsh-codepunk-workflow/SKILL.md 或 plans/）: %s\n' "$ROOT" >&2
  exit 2
fi

# F253：python3 不可用时，下游未加守卫的判定点（11 处：123/143/152/199/230/572/607/637/830/866/888）
#   会以**空值**参与比较 ⇒ 输出**虚假不一致**（例：凭空报「阶段口径不一」「文档未声明计数」），
#   即把「无法核验」归因为「文档缺陷」。与本仓教义（无法核验 ≠ 通过）相悖 ⇒ 统一前置为显式失败（2）。
#   既有 6 处细粒度 `command -v python3` + na() 分支保持不变（各自标注无法核验）。
command -v python3 >/dev/null 2>&1 && python3 -c 'pass' 2>/dev/null \
  || { echo "✗ python3 不可用（缺失或执行失败）——无法核验 ≠ 通过" >&2; exit 2; }

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
  if [ -z "$3" ]; then bad "$1：文档未声明计数（实际 $2）"
  elif [ "$2" = "$3" ]; then ok "$1 实际 $2 = 声称 $3"
  else bad "$1 实际 $2，文档声称 $3"; fi
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
# F240：README 电池行曾自称「14 项」，而其**自身枚举仅 13、实现仅 11** ⇒ 三方不符（与 F238「五条↔7 条」同族）。
#   判据：以**实现**为准（脚本的编号项 `# N)`），与 README 该行标签后的「（**N 项**」比对；锚定「完整验证电池」以免误取他行。
cmp_num "验证电池项数" "$(grep -cE '^# [0-9]+\)' plans/verify-battery.sh)" \
        "$(grep -oE '完整验证电池（\*\*[0-9]+ 项\*\*' README.md | grep -oE '[0-9]+')"
# F241：治理表曾称 class 20 为「9 条探针」，而实现（第 465 轮扩项后）为 19 条 ⇒ 陈旧计数（与 F240/F238 同族）。
#   判据：实现侧派生（`probe_rc`/`probe_msg` 调用数）↔ `skill-governance.md` 治理表声称的「**N 条探针**」。
cmp_num "治理表探针数" "$(grep -cE '^probe_rc |^probe_msg ' plans/doc-consistency.sh)" \
        "$(grep -oE '\*\*[0-9]+ 条探针\*\*' skills/dsh-codepunk-workflow/references/skill-governance.md | grep -oE '[0-9]+')"
# F338：开源规格化引入 `docs/**` 后，其**计数声称**不在任何门禁域（本类此前只扫 README）⇒
#   `docs/development.md` 与 `docs/architecture.md` 长期声称「137 项变异（M1–M137）」，实现已 146（陈旧计数）。
#   现把「实现派生量」的声称域扩到 README + docs/**，判据沿用**同一实现值**（变异项数 / 电池主检项数），
#   只识别 docs 实际使用的写法（`N 项变异` / `N 项**已知缺陷` / `N 项**电池` / `N 项，一次跑完` / `N 项**：`），
#   域与覆盖范围明写在结论里（避免再次过度声称——F294/F327 同族教训）。
MUT_N="$(grep -oE 'M[0-9]+' plans/checker-self-test.sh | sort -u | wc -l | tr -d ' ')"
BAT_MAIN="$(grep -cE '^# [0-9]+\)' plans/verify-battery.sh)"
DOC_CN_BAD=""
DOC_CN_HITS=0
for _f in docs/*.md docs/*/*.md; do
  [ -f "$_f" ] || continue
  for _v in $(grep -oE '[0-9]+ 项(\*\*)?(变异|已知缺陷)' "$_f" | grep -oE '^[0-9]+'); do
    DOC_CN_HITS=$((DOC_CN_HITS + 1))
    [ "$_v" = "$MUT_N" ] || DOC_CN_BAD="$DOC_CN_BAD ${_f}:变异=${_v}(实况 ${MUT_N})"
  done
  for _v in $(grep -oE '[0-9]+ 项(\*\*)?(电池|：|，一次跑完)' "$_f" | grep -oE '^[0-9]+'); do
    DOC_CN_HITS=$((DOC_CN_HITS + 1))
    [ "$_v" = "$BAT_MAIN" ] || DOC_CN_BAD="$DOC_CN_BAD ${_f}:电池=${_v}(实况 ${BAT_MAIN})"
  done
done
if [ -n "$DOC_CN_BAD" ]; then bad "docs/ 计数声称陈旧:${DOC_CN_BAD}"
elif [ "$DOC_CN_HITS" -eq 0 ]; then info "docs/ 未出现可识别的计数声称（域：docs/**；写法 N 项变异/已知缺陷/电池/：/，一次跑完）"
else ok "docs/ 计数声称与实现一致（命中 ${DOC_CN_HITS} 处；域 docs/**，仅识别该族写法）"; fi

# F255：README 与 fidelity-gate.py 均声称保护闸为「14 类」，但**无任何工具**核验该计数
#   （battery「11 项」/ mutations「126 项」已由上方 cmp_num 守护 ⇒ 覆盖不对称：增删 PATTERNS 会静默漂移）。
#   派生严格按实现（ast 取 PATTERNS 字典键数），比对 README 内唯一的「**N 类**」声称。
FID_DERIVED=$(python3 - <<'PY'
import ast
t = open('plans/fidelity-gate.py', encoding='utf-8').read()
for node in ast.walk(ast.parse(t)):
    if isinstance(node, ast.Assign) and any(getattr(tg, 'id', '') == 'PATTERNS' for tg in node.targets):
        print(len(node.value.keys))
        break
PY
)
cmp_num "fidelity 类数" "$FID_DERIVED" "$(grep -oE '\*\*[0-9]+ 类\*\*' README.md | grep -oE '[0-9]+')"

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

# F256：第 2 类只比「README 表格行数 / preset.yml 阶段号 / stages.md 阶段号」，**不覆盖** README 散文与标题里的
#   阶段字样 ⇒ 把标题写成「七阶段闭环」而表格仍 6 行时**无任何门禁发现**（与 F240/F241 的计数守护不对称）。
#   现以派生值反查中文数字（1–10），核标题字样与派生阶段数一致（不硬编码计数）。
CN_NUM=(一 二 三 四 五 六 七 八 九 十)
if [ "${P_README:-0}" -ge 1 ] && [ "${P_README:-0}" -le 10 ]; then
  EXPECT_CN="${CN_NUM[$((P_README - 1))]}"
  grep -qE "^## 流程总览（${EXPECT_CN}阶段闭环）" README.md \
    || bad "README 标题阶段字样与派生阶段数不一致（表格 ${P_README} ⇒ 期望「${EXPECT_CN}阶段闭环」）"
fi

echo "[3] 术语咨询（人工确认，不计失败）"
BARE=$(grep -rn '工作区' "$SKILL" "$REF"/*.md agent.cordis.yml 2>/dev/null \
       | grep -v 'benchmarks/' | grep -v 'git 工作区' | wc -l | tr -d ' ')
if [ "$BARE" = 0 ]; then ok "无裸用「工作区」"
else info "裸用「工作区」${BARE} 处（含「工作区检查点/工作区治理/术语对照」等合法用法，请人工确认是否易与「工作房」混淆）"; fi

echo "[4] 工具存在性"
# F327：扫描域原先只含 SKILL / references / README / CONTRIBUTING，**不含 docs/**（开源规格化时新增 9 篇，
#   内有 90+ 处 `plans/...` 引用）⇒ 通过消息「文档提到的 plans 脚本均存在」属**过度声称**，且
#   `docs/documentation-policy.md` 的占位路径 `plans/xxx.sh` 无任何机械门可发现。故扩展域并写明域。
# F408：域再扩至**全部跟踪的 .md**（此前域为 SKILL / references / README / CONTRIBUTING / docs，
#   `CHANGELOG.md` 等根级文档不在域内 ⇒ 其 `plans/patrol-readback.cjs` 不可解析却无门禁可见）；
#   扩展名集补 `cjs`/`ps1`（原集只有 sh|py|mjs，`.cjs` 形态的引用根本不被识别）；
#   空枚举判「无法核验 ≠ 通过」（与类 17/18 口径统一）。
MD_LIST=$(git ls-files '*.md' 2>/dev/null)
MD_SRC="git ls-files '*.md'"
if [ -z "$MD_LIST" ]; then
  MD_LIST=$(find . -name '*.md' -not -path './.git/*' 2>/dev/null | sed 's#^\./##')
  MD_SRC="find 回退（非 git 工作区）"
fi
MD_N=$(printf '%s\n' "$MD_LIST" | grep -c '[^[:space:]]' || true)
MISS=""
if [ "${MD_N:-0}" -eq 0 ]; then
  na "文档枚举为空（${MD_SRC}）：无法核验 ≠ 通过"
else
  for f in $MD_LIST; do
    [ -f "$f" ] || continue
    case "$f" in */benchmarks/*) continue ;; esac
    for s in $(grep -oE 'plans/[a-z0-9._-]+\.(sh|py|mjs|cjs|ps1)' "$f" 2>/dev/null | sed 's#plans/##' | sort -u); do
      [ -f "plans/$s" ] || [ -f "plans/windows/$s" ] || MISS="$MISS $f:$s"
    done
  done
  [ -z "$MISS" ] && ok "文档提到的 plans 脚本均存在（域：全部跟踪 .md ${MD_N} 篇，来源 ${MD_SRC}；排除 */benchmarks/*；扩展名 sh|py|mjs|cjs|ps1）" || bad "文档提到但不存在的脚本:${MISS}"
fi

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
  # F336：旧判据为 `grep -qE '\bsource\b|^\s*\.\s'`——对**任意**含 `source` 一词的 .sh 一律豁免，
  #   注释散文即可触发（实证：doc-consistency.sh 因自身 class 5 规则文本含「source」而**自我豁免**；
  #   verify-battery.sh 因 `:221` 注释含「source 它」而豁免；link.sh 为运行型 CLI 却因加载常量被豁免）。
  #   由此三者长期无退出码声明，且上方「实现用到的退出码 ⊆ 头部契约」判据对其恒空转。
  #   现**取消 source 启发式**：豁免只剩 home 脚本特例与下方「无显式退出调用」——
  #   「加载了别的脚本」不等于「纯库脚本」，判据须以**是否可运行**（有无显式退出调用）为准。
  grep -qE 'exit [0-9]|sys\.exit\(|process\.exit\(' "$f" 2>/dev/null || continue   # F187：非「运行型」（无显式退出调用）豁免
  RC_UNDECL="$RC_UNDECL $base"
done
[ -z "$RC_UNDECL" ] && ok "运行型脚本均声明了退出码" || bad "运行型脚本缺退出码声明:${RC_UNDECL}"

# class 5 子项（F358）：**外部输入变量**（本文件内无赋值，或写成 `${VAR:-默认}` 的覆盖开关）
#   MUST 被记载——出现在任一 `.md`，或任一 `plans/*` 脚本的**头部注释块**（shebang 后的连续 `#`；
#   `.py` 的首个 docstring 块；`.mjs` 的首个 `/** … */` 块）。
#   依据：CONTRIBUTING「声称与实现是否同步——文档、脚本头注释、退出码契约三者一致」；
#   实证：`plans/git-merge-flow.sh` 的 `$PR_BODY`（PR 正文覆盖）原只在实现里存在、头部与文档零记载。
ENVDOC=$(python3 <<'PYEOF'
import io, re, subprocess
SYS = {"PATH","HOME","PWD","OLDPWD","IFS","SHELL","USER","TMPDIR","LANG","LC_ALL","LC_CTYPE","LC_MESSAGES",
       "TERM","BASH_SOURCE","LINENO","FUNCNAME","RANDOM","SECONDS","OSTYPE","BASH","SHLVL","PPID","UID","EUID",
       "BASH_VERSION","BASH_ENV","ENV","REPLY","EDITOR","PAGER","GIT_PAGER","TZ","NO_COLOR","COLUMNS","LINES",
       "PYTHONIOENCODING","NF","NR","FS","OFS","ORS","RS","FILENAME","FNR","LOGNAME","HOSTNAME","MACHTYPE",
       "HOSTTYPE","PROGRAMFILES","SystemRoot","COMPUTERNAME","TEMP","TMP","OS","ARCH","SOURCE_DATE_EPOCH",
       "DOCKER_HOST","CI","GITHUB_ACTIONS","GITHUB_OUTPUT","GITHUB_STEP_SUMMARY","GITHUB_WORKSPACE","RUNNER_OS",
       "GITHUB_REPOSITORY","GITHUB_SHA","GITHUB_REF","GITHUB_REF_NAME","GITHUB_EVENT_NAME","GITHUB_BASE_REF",
       "GITHUB_HEAD_REF","GITHUB_TOKEN","GITHUB_ENV","GITHUB_PATH"}
REF_SH = re.compile(r"\$\{([A-Z][A-Z0-9_]*)(:?[-=+?][^}]*)?\}|\$([A-Z][A-Z0-9_]*)")
ASSIGN_SH = re.compile(r"(?:^|[;&|(\s])(?:local\s+|readonly\s+|declare\s+-\w+\s+|export\s+)?([A-Z][A-Z0-9_]*)=")
REF_PY = re.compile(r"os\.environ(?:\.get)?(?:\[|\.get\()?['\"]([A-Z][A-Z0-9_]*)['\"]|os\.getenv\(['\"]([A-Z][A-Z0-9_]*)['\"]")
REF_MJS = re.compile(r"process\.env\.([A-Z][A-Z0-9_]*)")
REF_PS = re.compile(r"\$env:([A-Z][A-Z0-9_]*)")

def tracked(pat):
    out = subprocess.run(["git", "ls-files"], capture_output=True, text=True).stdout
    return [f for f in out.split("\n") if f and re.search(pat, f)]

def read(p):
    return io.open(p, encoding="utf-8", errors="replace").read()

def header(text, path):
    lines = text.split("\n")
    i = 1 if lines and lines[0].startswith("#!") else 0
    if path.endswith(".py") and i < len(lines) and lines[i].lstrip()[:3] in ('"""', "'''"):
        q = lines[i].lstrip()[:3]
        if q not in lines[i].lstrip()[3:]:
            j = i + 1
            while j < len(lines) and q not in lines[j]:
                j += 1
            return "\n".join(lines[i:j + 1])
        return lines[i]
    if path.endswith(".mjs") and i < len(lines) and lines[i].lstrip().startswith("/**"):
        j = i
        while j < len(lines) and "*/" not in lines[j]:
            j += 1
        return "\n".join(lines[i:j + 1])
    out = []
    while i < len(lines):
        s = lines[i]
        if s.strip() == "" or s.lstrip().startswith("#"):
            out.append(s)
            i += 1
        else:
            break
    return "\n".join(out)

code = tracked(r"^(plans/.*\.(sh|py|mjs|ps1)|Makefile)$")
doc_all = "\n".join(read(f) for f in tracked(r"\.md$"))
head_all = "\n".join(header(read(f), f) for f in code)
bad = []
nref = 0
for f in code:
    text = read(f)
    assigns, refs = set(), {}
    for i, line in enumerate(text.split("\n"), 1):
        if f.endswith(".py"):
            for m in REF_PY.finditer(line):
                n = m.group(1) or m.group(2)
                if n:
                    refs.setdefault(n, (False, i))
        elif f.endswith(".mjs"):
            for m in REF_MJS.finditer(line):
                refs.setdefault(m.group(1), (False, i))
        elif f.endswith(".ps1"):
            for m in REF_PS.finditer(line):
                refs.setdefault(m.group(1), (False, i))
        else:
            for m in REF_SH.finditer(line):
                n = m.group(1) or m.group(3)
                if not n:
                    continue
                has_def = bool(m.group(1) and m.group(2) and m.group(2)[0] in "-=?+")
                old = refs.get(n, (False, i))
                refs[n] = (old[0] or has_def, i)
            for m in ASSIGN_SH.finditer(line):
                assigns.add(m.group(1))
    for n, (has_def, ln) in refs.items():
        if n in SYS:
            continue
        if not (has_def or n not in assigns):
            continue
        nref += 1
        pat = re.compile(r"(?<![A-Za-z0-9_])" + re.escape(n) + r"(?![A-Za-z0-9_])")
        if not pat.search(doc_all) and not pat.search(head_all):
            bad.append("%s:%d:%s" % (f, ln, n))
if nref == 0:
    print("NOVAR")
else:
    print(",".join(bad[:5]) + ("" if len(bad) <= 5 else " 等共 %d 处" % len(bad)))
PYEOF
)
if [ "$ENVDOC" = "NOVAR" ]; then
  info "外部输入变量无法核验（未扫到任何变量）——无法核验 ≠ 通过"
elif [ -z "$ENVDOC" ]; then
  ok "外部输入变量均被记载（任一 .md 或脚本头部注释块）"
else
  bad "外部输入变量未被记载（文档或头部注释块零提及）→ ${ENVDOC}"
fi

echo "[6] 头部自称项数（仅提示，不计失败——计数口径以实跑输出为准）"
DOC_CN=$(grep -oE '[一二三四五六七八九十]+项检查' plans/preset-compat.py | head -1)
REAL_CN=$(grep -cE 'print\(f?"  [✅✗ℹ]' plans/preset-compat.py)
if [ -z "$DOC_CN" ]; then ok "preset-compat 未在头部声称项数（跳过）"
else info "preset-compat 头部称「${DOC_CN}」；源码输出分支 ${REAL_CN} 处（同项含成功/失败双分支，以实跑输出为准）"; fi

echo "[7] 跨文件阈值一致（同一机制取值必须唯一）"
# 每类：<标签>|<正则（须含一个捕获组）>
# 可移植性（本轮实测）：这些正则经 `grep -E`（POSIX ERE）执行，**不得使用 `(?:…)` 非捕获组**——
#   BSD grep（macOS）容忍，GNU grep / busybox（Linux、CI）报「Repetition not preceded by valid
#   expression」⇒ 片段为空 ⇒ 本类退化为「未匹配到取值」的信息行而不判失败（假绿），
#   且会让存活自检的 M39 变异在 Linux 上失败。新增模式请一律用普通捕获组。
THRESH='评分基准 base|all|base[：: ]+([0-9]+)
评分下限 clamp|last|clamp[ ]*0[–—-]([0-9]+)
retries 单次扣分|all|每次[ ]*[−-]([0-9]+)
retries 上限扣分|all|上限[ ]*[−-]([0-9]+)
handoff 缺件扣分|last|每缺[ ]*1[ ]*文件[ ]*[−-]([0-9]+)
巡检周期（轮）|all|每[ ]*([0-9]+)[ ]*轮
收口轮数|all|([0-9]+)[ ]*轮未交付
证据门 exit_code|all|exit_code[ ]*[=＝][ ]*([0-9]+)
SKILL 体积上限（字节）|all|(≤|超预算[ ]*)([0-9]{5})
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
    info "${label} 未匹配到取值（正则或表述已变，需人工确认）——无法核验≠通过（同 F180 口径）"
  else
    bad "${label} 取值不一: ${vals}（同一机制必须唯一）"
  fi
done <<<"$THRESH"

# 分支保护必需检查名（F347）：脚本声明 ↔ 工作流作业名 ↔ 维护文档提及
# ruleset 的 required_status_checks 按**上下文名**匹配：作业改名后该检查永不出现 ⇒ PR 永久阻塞，
# 且改名不会让任何既有门禁失败（实测：四个作业名各加 -v2 后本脚本仍 rc=0）。改名属常见重构动作。
CI_YML=".github/workflows/ci.yml"
MAINT_DOC="docs/maintenance.md"
if [ -f plans/github-setup.sh ] && [ -f "$CI_YML" ]; then
  WANT_CTX=$(grep -oE '^CHECK_CONTEXTS=\(.*\)' plans/github-setup.sh | sed -E 's/^CHECK_CONTEXTS=\(//; s/\)$//')
  GOT_CTX=$(grep -E '^    name: ' "$CI_YML" | sed -E 's/^    name: //')
  if [ -z "$WANT_CTX" ] || [ -z "$GOT_CTX" ]; then
    info "必需检查名未取到（脚本或工作流结构已变，需人工确认）——无法核验≠通过"
  else
    MISS_CTX=$(printf '%s\n' "$WANT_CTX" | tr ' ' '\n' | grep . | while read -r w; do
                 printf '%s\n' "$GOT_CTX" | grep -qxF "$w" || printf '%s ' "$w"; done)
    EXTRA_CTX=$(printf '%s\n' "$GOT_CTX" | grep . | while read -r g; do
                 printf '%s\n' "$WANT_CTX" | tr ' ' '\n' | grep -qxF "$g" || printf '%s ' "$g"; done)
    UNDOC_CTX=""
    if [ -f "$MAINT_DOC" ]; then
      UNDOC_CTX=$(printf '%s\n' "$WANT_CTX" | tr ' ' '\n' | grep . | while read -r w; do
                    grep -qF "$w" "$MAINT_DOC" || printf '%s ' "$w"; done)
    fi
    if [ -z "$MISS_CTX$EXTRA_CTX$UNDOC_CTX" ]; then
      ok "分支保护必需检查名一致（脚本 ↔ ci.yml 作业名 ↔ docs/maintenance.md）：$(printf '%s' "$WANT_CTX" | tr ' ' ',')"
    else
      bad "必需检查名不一致: 工作流缺[${MISS_CTX}] 工作流多[${EXTRA_CTX}] 文档未提[${UNDOC_CTX}]（ruleset 按上下文名匹配 ⇒ 改名后必需检查永不出现、PR 永久阻塞）"
    fi
  fi
else
  info "必需检查名核验跳过（缺 plans/github-setup.sh 或 ${CI_YML}）——无法核验≠通过"
fi

# 必需检查的「文档声称 ↔ 作业实际执行」（F354）：
# CONTRIBUTING.md 的 CI 门禁表逐行声明每个必需检查的「覆盖内容 / 等价本地命令」。若文档给出可执行的
# 等价命令，它必须**真的**被该作业执行；若声称覆盖 Windows 侧，该作业段内必须出现 ps1 路径；若指向
# 电池的某一项，电池项标题内必须有该词。实测（修复前）：「跨平台可移植」声称覆盖 Windows 侧对等性、
# 等价命令写作电池的「跨平台项」——而该作业只扫 plans/*.sh、电池并无此项 ⇒ 读者会以为平台对等有机械
# 守护，实际只有人工公约。判据只看**正向**声称：不带 runner 动词的纯路径提及（如「近似项见 …」）不计。
if [ -f CONTRIBUTING.md ] && [ -f "$CI_YML" ]; then
  CONTRIB_ISSUE=$(python3 <<'PYEOF'
import io, os, re, sys
try:
    ci = io.open('.github/workflows/ci.yml', encoding='utf-8').read()
    co = io.open('CONTRIBUTING.md', encoding='utf-8').read()
    bat = io.open('plans/verify-battery.sh', encoding='utf-8').read()
except OSError as e:
    print('无法读取（%s）' % e); sys.exit(0)
ms = list(re.finditer(r'^  ([a-z][a-z0-9-]*):\s*$', ci, re.M))
jobs = {}
for i, m in enumerate(ms):
    end = ms[i + 1].start() if i + 1 < len(ms) else len(ci)
    jobs[m.group(1)] = ci[m.end():end]
name2job = {}
for j, body in jobs.items():
    nm = re.search(r'^\s+name:\s*(.+?)\s*$', body, re.M)
    if nm:
        name2job[nm.group(1).strip()] = j
titles = ' '.join(t for _, t in re.findall(r'^# ([0-9]+[a-c]?)\) (.+)$', bat, re.M))
sec = co.split('### 5.2 CI 门禁', 1)
if len(sec) < 2:
    print('CONTRIBUTING.md 缺「### 5.2 CI 门禁」小节'); sys.exit(0)
issues = []
for line in sec[1].split('\n'):
    m = re.match(r'^\|\s*`([^`]+)`\s*\|\s*(.+?)\s*\|\s*(.+?)\s*\|\s*$', line)
    if not m:
        continue
    name, cover, local = m.group(1), m.group(2), m.group(3)
    if name not in name2job:
        continue
    body = jobs[name2job[name]]
    for cmd in re.findall(r'`(?:bash|python3|node)\s+(plans/[A-Za-z0-9_.-]+)`', local):
        if not os.path.exists(cmd):
            issues.append('%s 等价命令 %s 不存在' % (name, cmd))
        elif cmd not in body:
            issues.append('%s 声称等价命令 %s，而作业 %s 段内未执行它' % (name, cmd, name2job[name]))
    if 'Windows' in cover and 'plans/windows' not in body and '.ps1' not in body:
        issues.append('%s 声称覆盖 Windows 侧，而作业 %s 段内无任何 ps1 路径' % (name, name2job[name]))
    for item in re.findall(r'verify-battery\.sh`?\s*的\s*[`「]?([^`」）|]{2,12})[`」]?\s*项', local):
        if item.strip() and item.strip() not in titles:
            issues.append('%s 指向电池的「%s」项，而电池项标题内无该词' % (name, item.strip()))
print('；'.join(issues[:4]) + ('' if len(issues) <= 4 else ' 等共 %d 项' % len(issues)))
PYEOF
)
  if [ -z "$CONTRIB_ISSUE" ]; then
    ok "CONTRIBUTING 的 CI 门禁表与工作流实际执行相符（等价命令存在且被该作业执行；未声称不存在的覆盖）"
  else
    bad "CI 门禁表与实现不符：${CONTRIB_ISSUE}"
  fi
else
  info "CI 门禁表核验跳过（缺 CONTRIBUTING.md 或 ${CI_YML}）——无法核验≠通过"
fi

# Dependabot 声明 ↔ 仓库与治理脚本（本轮巡检实测）：
# `.github/dependabot.yml` 声明的每个生态（package-ecosystem）必须在仓库内有对应清单——声明而无清单的
# 条目恒不产出 PR（静默空转，实测：曾声明 `pip` 而仓库无任何 pip 清单、`plans/*.py` 仅用标准库）；
# 每个 `labels` 引用的标签必须由 `plans/github-setup.sh` 幂等创建——标签不存在时该字段静默失效；
# 且 `docs/maintenance.md` 的生态清单须与声明一致（文档不得声称不存在的巡检）。
if [ -f .github/dependabot.yml ] && [ -f plans/github-setup.sh ]; then
  DEP_ISSUE=$(python3 <<'PYEOF'
import io, os, re, sys
try:
    dep = io.open('.github/dependabot.yml', encoding='utf-8').read()
    gs = io.open('plans/github-setup.sh', encoding='utf-8').read()
except OSError as e:
    print('无法读取（%s）' % e); sys.exit(0)
md = ''
if os.path.exists('docs/maintenance.md'):
    md = io.open('docs/maintenance.md', encoding='utf-8').read()
issues = []
ecos = re.findall(r'package-ecosystem:\s*([A-Za-z0-9_-]+)', dep)
PIP = ['requirements.txt', 'requirements-dev.txt', 'pyproject.toml', 'setup.py', 'setup.cfg', 'Pipfile', 'poetry.lock', 'uv.lock']
NPM = ['package.json', 'package-lock.json', 'pnpm-lock.yaml', 'yarn.lock']
for eco in sorted(set(ecos)):
    if eco == 'github-actions':
        d = '.github/workflows'
        found = os.path.isdir(d) and any(f.endswith(('.yml', '.yaml')) for f in os.listdir(d))
    elif eco == 'pip':
        found = any(os.path.exists(p) for p in PIP)
    elif eco == 'npm':
        found = any(os.path.exists(p) for p in NPM)
    elif eco == 'docker':
        found = any(os.path.exists(p) for p in ['Dockerfile', 'docker-compose.yml'])
    else:
        issues.append('生态 %s 未在判据内登记清单形态（无法核验 ≠ 通过）' % eco)
        continue
    if not found:
        issues.append('声明生态 %s 但仓库无对应清单（该条目恒不产出 PR）' % eco)
labels = []
for m in re.finditer(r'^([ \t]*)labels:[ \t]*\n((?:[ \t]+-[^\n]*\n)+)', dep, re.M):
    labels += re.findall(r'-[ \t]*([A-Za-z0-9_.-]+)', m.group(2))
for lab in sorted(set(labels)):
    if '"%s"' % lab not in gs:
        issues.append('标签「%s」未被 plans/github-setup.sh 创建（标签不存在时 labels 字段静默失效）' % lab)
if md:
    for eco in sorted(set(ecos)):
        if eco not in md:
            issues.append('docs/maintenance.md 未提及声明的生态 %s' % eco)
if issues:
    print(', '.join(issues[:4]) + ('' if len(issues) <= 4 else ' 等共 %d 处' % len(issues)))
PYEOF
)
  if [ -z "$DEP_ISSUE" ]; then
    ok "Dependabot 声明自洽（每个生态有对应清单；每个标签由 plans/github-setup.sh 幂等创建；docs/maintenance.md 与声明一致）"
  else
    bad "Dependabot 配置与仓库/治理脚本不符 → ${DEP_ISSUE}"
  fi
else
  info "Dependabot 配置核验跳过（缺 .github/dependabot.yml 或 plans/github-setup.sh）——无法核验≠通过"
fi

# 类 7 子项（F368）：钩子配置完整性——`plans/hooks/hooks.json` 由产品在启动时读取（`agent.cordis.yml`
#   的 `hooks-write-scope` 条目 configPath）。实测：截断为非法 JSON、或把命令路径改成不存在的文件时，
#   doc·audit·score·preset-compat·write-scope **五个门禁全绿**、零处提到 hooks ⇒ 拦截层静默消失
#   （产品侧仅 `logger.warn(… — no hooks registered)`）。此处核验语法、结构、命令引用的仓库内文件
#   是否存在，以及**解释器是否在 PATH 内**（失败开放：命令起不来时产品不设 decision ⇒ 放行）。
if [ -f plans/hooks/hooks.json ]; then
  HOOK_INTERP=$(sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"[:space:]]*\).*/\1/p' plans/hooks/hooks.json | head -1)
  if [ -n "$HOOK_INTERP" ] && ! command -v "$HOOK_INTERP" >/dev/null 2>&1; then
    bad "钩子解释器 \`${HOOK_INTERP}\` 不在 PATH ⇒ 钩子命令无法启动、产品不设 decision ⇒ 放行（拦截层静默失效）：装该解释器，或移除 agent.cordis.yml 的 hooks-write-scope 条目"
  fi
  if command -v python3 >/dev/null 2>&1; then
    HOOK_ISSUE=$(python3 <<'PYEOF'
import json, os, re
issues = []
try:
    d = json.load(open('plans/hooks/hooks.json', encoding='utf-8'))
except Exception as e:
    print('plans/hooks/hooks.json 不是合法 JSON（%s）' % e)
    raise SystemExit
groups = (d.get('hooks') or {}).get('PreToolUse')
if not isinstance(groups, list) or not groups:
    issues.append('hooks.PreToolUse 缺失或为空')
else:
    for i, g in enumerate(groups):
        if not (g.get('matcher') or '').strip():
            issues.append('第 %d 组的 matcher 为空（缺 matcher 即匹配全部工具）' % (i + 1))
        for h in (g.get('hooks') or []):
            if h.get('type') != 'command':
                issues.append('第 %d 组的 hook type 非 command' % (i + 1))
                continue
            cmd = h.get('command') or ''
            # 注：本行 MUST 用双引号 python 字面量——在 `$()` 内的 heredoc 正文里出现 `\'`
            #   （反斜杠+单引号）会让 bash 的 `$()` 引号扫描失衡 ⇒ 整脚本 `bash -n` 报
            #   「unexpected EOF while looking for matching `'`」（实测：单引号版本 rc=2）。
            for m in re.finditer(r"\$\{CLAUDE_PLUGIN_ROOT\}/([^\"'\s]+)", cmd):
                if not os.path.exists(m.group(1)):
                    issues.append('命令引用的仓库内文件不存在：%s' % m.group(1))
if issues:
    print(', '.join(issues[:4]) + ('' if len(issues) <= 4 else ' 等共 %d 处' % len(issues)))
PYEOF
)
    if [ -z "$HOOK_ISSUE" ]; then
      ok "钩子配置完整（JSON 可解析 · matcher/type/command 齐备 · 命令引用的仓库内文件存在 · 解释器在 PATH 内）"
    else
      bad "钩子配置不完整 → ${HOOK_ISSUE}"
    fi
  else
    info "钩子配置结构核验跳过（无 python3）——无法核验≠通过"
  fi
else
  info "钩子配置核验跳过（缺 plans/hooks/hooks.json）——无法核验≠通过"
fi

echo "[8] 日期形态与未来日期"
TODAY=$(date +%F)
if ! command -v python3 >/dev/null 2>&1; then
  na "日期核验（缺 python3）"
else
  # F365：未来日期判据 MUST 容忍时区偏移 —— 作者本机「今天」最多可超前 UTC「今天」1 天（UTC+14 时区），
  #   而 CI 运行器为 UTC 时钟；不设容忍时，本地 00:00–07:00（UTC+7）产生的合法日期在 CI 上必被判未来
  #   ⇒ 每个这样的 PR 都假红（实测：PR 的「文档一致性」作业在 CI 上 rc=1「未来日期: agent.cordis.yml:2026-10-08」，
  #   同一提交在本机（UTC+7）rc=0）。上限取 UTC 今天 + 1 天：仍能拦住 2099-01-01 一类真实未来日期。
  LIMIT=$(python3 -c "import datetime;print((datetime.datetime.now(datetime.timezone.utc).date()+datetime.timedelta(days=1)).isoformat())")
  DATE_ISSUE=$(python3 - "$LIMIT" <<'PYEOF'
import re, subprocess, sys
limit = sys.argv[1]
# F299：非 git 工作区（或 git 不可用）时 `git ls-files` **静默返回空** ⇒ 本类空转却输出
#   「✅ 无未来日期」= 假绿灯（与同脚本类 17 的「ℹ 非 git 工作区…无法核验≠通过」口径不一致）。
#   改为：git 索引不可用即**回退文件系统遍历**（真核验，非跳过），并由 shell 侧 info 明示回退。
r = subprocess.run(['git', 'ls-files'], capture_output=True, text=True)
files = r.stdout.split() if r.returncode == 0 else []
mode = 'git'
if not files:
    import os
    # F339：glob('**/*', recursive=True) 默认**跟随符号链接** ⇒ 检出内含链接环（自引用目录、指向祖先的链接、
    #   构建产物链接农场）时无限递归、门禁**永不返回**（实测 rc=124，无判定行）；os.walk 默认 followlinks=False。
    files = []
    for _dp, _dns, _fns in os.walk('.'):
        _dns[:] = [d for d in _dns if d != '.git']
        for _fn in _fns:
            if _fn.endswith(('.md', '.yml')):
                files.append(os.path.relpath(os.path.join(_dp, _fn), '.'))
    mode = 'walk'
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
        if d > limit:
            future.append(f'{f}:{d}')
out = []
if future:
    out.append('未来日期: ' + ', '.join(future[:3]))
if bad_form:
    out.append('非 ISO 形态: ' + ', '.join(bad_form[:3]))
print(mode + '|' + '; '.join(out))
PYEOF
)
  DATE_MODE="${DATE_ISSUE%%|*}"; DATE_ISSUE="${DATE_ISSUE#*|}"
  if [ "$DATE_MODE" = walk ]; then info "非 git 工作区：类 8 回退到文件系统遍历核验（已核验，非跳过）"; fi
  if [ -z "$DATE_ISSUE" ]; then ok "日期形态与新鲜度（ISO 形态；无未来日期（上限 ${LIMIT}＝UTC 今天 +1 天，容忍时区偏移）；今日 ${TODAY}）"
  else bad "日期问题 → ${DATE_ISSUE}"; fi
fi

echo "[9] 编号引用可解析（D 逐条登记 / P 落在声明范围内）"
if ! command -v python3 >/dev/null 2>&1; then
  na "编号引用核验（缺 python3）"
else
  NUM_ISSUE=$(python3 <<'PYEOF'
import glob, os, re
std = open('skills/dsh-codepunk-workflow/references/standard.md', encoding='utf-8', errors='replace').read()
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
        t = open(f, encoding='utf-8', errors='replace').read()
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
# F294：原 patA 要求 `.md` **紧邻**「」⇒ 漏检仓内常见写法 `references/x.md`「名」（路径带反引号）
#   与 `references/x.md 的「名」`。本轮巡检实测 实证：该类对「`references/artifacts.md`「chunks.yaml 迁移主体」」
#   （名称与目标章节不符）**未报错**，而矩阵却声称该类机械覆盖「章节级引用可解析」。现容忍反引号/「的」/空白。
patA = re.compile(r'references/([a-z0-9-]+)\.md`?[ \t]*(?:的)?[ \t]*[「『]([^」』]{2,40})[」』]')
patB = re.compile(r'(?:SKILL\.md|references/([a-z0-9-]+)\.md)[^\n]{0,6}?§([0-9]+(?:\.[0-9]+)?)')
badA, badB = [], []
for f in files:
    try:
        t = open(f, encoding='utf-8', errors='replace').read()
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
# F344：制品「字段模板见 `references/artifacts.md`」的声称 MUST 在 artifacts.md 有对应小节——
#   否则该制品的字段契约悬空（实测：SKILL 的 `plan_draft.md` 曾指向 artifacts.md，而后者只在运行根树状图里出现该名）。
artdoc = open(f'{S}/references/artifacts.md', encoding='utf-8', errors='ignore').read()
art_heads = re.findall(r'^#{2,4}\s*([^\n]+)$', artdoc, re.M)
badC = []
for f in sorted(set(files + glob.glob(f'{S}/references/*.md'))):
    try:
        t = open(f, encoding='utf-8', errors='replace').read()
    except OSError:
        continue
    for m in re.finditer(r'`([a-z_]+\.(?:yaml|md))`[^\n]{0,60}?字段模板见\s*`?references/artifacts\.md', t):
        name = m.group(1)
        if not any(name in h for h in art_heads):
            badC.append(f'{os.path.basename(f)}→{name}')
out = []
if badA:
    out.append('章节名未找到: ' + ', '.join(badA[:3]))
if badB:
    out.append('§ 指向不存在: ' + ', '.join(badB[:3]))
if badC:
    out.append('制品字段模板悬空: ' + ', '.join(badC[:3]))
print('; '.join(out))
PYEOF
)
  if [ -z "$SEC_ISSUE" ]; then ok "章节级引用均可解析（章节名 + 限定式 § + 制品字段模板）"
  else bad "章节级引用问题 → ${SEC_ISSUE}"; fi
fi

echo "[11] benchmarks 支撑决策号语义相符"
if ! command -v python3 >/dev/null 2>&1; then
  na "决策号语义核验（缺 python3）"
else
  SEM_ISSUE=$(python3 <<'PYEOF'
import glob, re
S = 'skills/dsh-codepunk-workflow'
std = open(f'{S}/references/standard.md', encoding='utf-8', errors='replace').read()
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
    t = open(f, encoding='utf-8', errors='replace').read()
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
        t = open(f, encoding='utf-8', errors='replace').read()
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
            t = open(f, encoding='utf-8', errors='replace').read()
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
        t = open(f, encoding='utf-8', errors='replace').read()
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
            t = open(f, encoding='utf-8', errors='replace').read()
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
    defined = set(re.findall(r'^##\s*([①②③④⑤⑥])', open(stages_md, encoding='utf-8', errors='replace').read(), re.M))
else:
    print('stages.md 缺失（阶段定义文件）'); raise SystemExit(1)
# 注意（F137）：**定义文件自身不算引用**——否则「孤立阶段」分支结构上永不可达
#   （stages.md 的 `## <阶段号>` 标题会被当成一次引用）。
files = (['skills/dsh-codepunk-workflow/SKILL.md', 'preset.yml', 'README.md']
         + [f for f in glob.glob('skills/dsh-codepunk-workflow/references/*.md') if f != stages_md])
refs = {}
for f in files:
    try:
        t = open(f, encoding='utf-8', errors='replace').read()
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
st = open('plans/checker-self-test.sh', encoding='utf-8', errors='replace').read()

def headers_of(path):
    try:
        t = open(path, encoding='utf-8', errors='replace').read()
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
    st = open(shp, encoding='utf-8', errors='replace').read()
    pt = open(psp, encoding='utf-8', errors='replace').read()
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
# F239：坏根/非法参数不仅要**码对**（2），还须**只给友好提示**——不得把 bash 原始错误
#   （`cd: --: invalid option` / `cd: usage: …`）直接抛给使用者，也不得**完全没有**提示行
#   （实测：verify-battery 曾仅输出裸错、无任何解释）。缺提示与泄漏原始错误同属可观测性缺陷。
probe_msg() { # probe_msg <标签> <命令> <须含串> <禁含串>
  local label="$1" cmd="$2" must="$3" forbid="$4" rc=0 out=""
  out=$(eval "$cmd" 2>&1) || rc=$?
  RC_N=$((RC_N + 1))
  [ "$rc" = 2 ] || RC_BAD="${RC_BAD}${label}(rc=${rc},want=2) "
  printf '%s' "$out" | grep -q "$must" || RC_BAD="${RC_BAD}${label}(缺友好提示) "
  if printf '%s' "$out" | grep -q "$forbid"; then RC_BAD="${RC_BAD}${label}(泄漏原始错误) "; fi
  return 0
}
probe_msg "audit 坏根提示"           "bash plans/preset-audit.sh --bogus"    "预设根不存在" "cd: usage"
probe_msg "score 坏根提示"           "bash plans/preset-score.sh --bogus"    "预设根不存在" "cd: usage"
probe_msg "doc-consistency 坏根提示" "bash plans/doc-consistency.sh --bogus" "预设根不存在" "cd: usage"
probe_msg "battery 坏根提示"         "bash plans/verify-battery.sh --bogus"  "预设根不存在" "cd: usage"
# -h/--help 约定：**实现该约定的脚本** MUST 返回 0 并打印头部用法（F153）；
#   探针覆盖全部实现者（F361 后为 **15 个**：audit/score/doc-consistency/verify-worktree/link/
#   leak-guard/init/git-merge-flow/github-setup/write-scope-check/patrol-check + acceptance-verify/evidence-verify/
#   checker-self-test/verify-battery；唯 `dsh-codepunk-home.sh` 为纯 source 库，不属 CLI 入口）；
#   另有 4 条坏根提示形状探针。下方静态子项保证「实现者集合」无遗漏。
probe_rc 0 "audit -h"           "bash plans/preset-audit.sh -h"
probe_rc 0 "score -h"           "bash plans/preset-score.sh -h"
probe_rc 0 "doc-consistency -h" "bash plans/doc-consistency.sh -h"
probe_rc 0 "verify-worktree -h" "bash plans/verify-worktree.sh -h"
probe_rc 0 "link -h"            "bash plans/dsh-codepunk-link.sh -h"
probe_rc 0 "leak-guard -h"      "bash plans/dsh-codepunk-leak-guard.sh -h"
probe_rc 0 "init -h"            "bash plans/dsh-codepunk-init.sh -h"
probe_rc 0 "git-merge-flow -h"  "bash plans/git-merge-flow.sh -h"
probe_rc 0 "github-setup -h"    "bash plans/github-setup.sh -h"
probe_rc 0 "write-scope -h"     "bash plans/write-scope-check.sh -h"
probe_rc 0 "patrol-check -h"    "bash plans/patrol-check.sh -h"
# F361（本轮巡检实测）：以下 4 个脚本原无 `-h` 分支（`-h` 被当位置参数，rc=2 且无用法输出），
#   而本类的注释自述「探针 MUST 覆盖全部实现者」⇒ 判据集合与实现集合脱节（`checker-self-test.sh`
#   的 M149 甚至把该约定写进了夹具，自身却是缺口）。
probe_rc 0 "acceptance-verify -h" "bash plans/acceptance-verify.sh -h"
probe_rc 0 "evidence-verify -h"   "bash plans/evidence-verify.sh -h"
probe_rc 0 "checker-self-test -h" "bash plans/checker-self-test.sh -h"
probe_rc 0 "verify-battery -h"    "bash plans/verify-battery.sh -h"
# F366（本轮巡检实测）：用法约定的**实现集合**含 `plans/` 下全部可执行入口（`.sh`/`.py`/`.mjs`），
#   而本类的静态子项与探针表此前只覆盖 `.sh` ⇒ 4 个可执行 CLI 把 `-h` 当位置参数（rc=2；其中
#   preset-compat 报「组合文件不存在：<仓库>/-h/agent.cordis.yml」）⇒ 与「覆盖全部实现者」不符。
probe_rc 0 "fidelity-gate -h"    "timeout 60 python3 plans/fidelity-gate.py -h"
probe_rc 0 "preset-compat -h"    "timeout 60 python3 plans/preset-compat.py -h"
probe_rc 0 "preset-declare -h"   "timeout 60 node plans/preset-declare.mjs -h"
probe_rc 0 "ps-validate -h"      "timeout 60 node plans/ps-validate.mjs -h"
RC_DECL=32   # 声明探针数（9 条用法/环境错 + 4 条坏根提示形状 + 19 条 -h）；新增探针须同步此值
# F361 静态子项：**每个运行型入口都 MUST 实现 `-h`**——探针表是人工枚举，
#   新增脚本时极易漏挂（本轮即 4 个实现者不在表内）。此处以源码为准机械核验实现集合。
# F366 起域扩为 `plans/` 下全部可执行入口（纯 source 库除外）——否则 `.py`/`.mjs` 永不在域。
RC_HGAP=""
for f in plans/*.sh plans/*.py plans/*.mjs; do
  base=$(basename "$f")
  case "$base" in dsh-codepunk-home.sh) continue ;; esac   # 纯 source 库：无 $1/$@，不属 CLI 入口
  # 接受两种书写顺序（`-h|--help` / `--help|-h`）与尾部追加别名（如 `-h|--help|help`）：
  #   实测 link.sh 用 `--help|-h|"")`、git-merge-flow.sh 用 `-h|--help|help)`。
  case "$base" in
    *.sh) grep -qE '^[[:space:]]*(-h\|--help|--help\|-h)' "$f" || RC_HGAP="${RC_HGAP} ${base}" ;;
    # 非 shell 入口写法各异（py 的 `in ('-h', '--help')`、mjs 的 `=== '-h'`/`includes('-h')`），
    #   故判据取「同时含 `-h` 与 `--help` 字面量」：弱于 .sh 的结构判据，但守住「有分支」这一事实。
    *) { grep -q -- "'-h'" "$f" || grep -q -- '"-h"' "$f"; } && grep -q -- '--help' "$f" \
         || RC_HGAP="${RC_HGAP} ${base}" ;;
  esac
done
[ -z "$RC_HGAP" ] || bad "运行型入口未实现 -h/--help 用法约定:${RC_HGAP}"
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
    t = open('agent.cordis.yml', encoding='utf-8', errors='replace').read()
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
        tt = open(f, encoding='utf-8', errors='replace').read()
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
dc = open('plans/doc-consistency.sh', encoding='utf-8', errors='replace').read()
classes = sorted({int(m) for m in re.findall(r'^echo "\[(\d+)\]', dc, re.M)})
# F234：同上（class 22）——矩阵来源文件缺失时抛 Traceback 且判据假通过；改为显式「无法核验」并干净退出。
try:
    g = open('skills/dsh-codepunk-workflow/references/skill-governance.md', encoding='utf-8', errors='replace').read()
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
    t = open(f, encoding='utf-8', errors='replace').read()
    if not re.search(r'https?://', t):
        continue
    if 'retrieved_at' not in t and '未记录' not in t:
        bad.append(os.path.basename(f))
print(', '.join(bad[:3]))
PYEOF
)
  if [ -z "$BM_ISSUE" ]; then ok "含 URL 的简报均带 retrieved_at（或无检索日时显式标注）"
  else bad "简报缺检索日 → ${BM_ISSUE}"; fi

echo "[24] Markdown 表格列数一致与结构完整（表头↔分隔行↔数据行；围栏/缩进/引用块/无行首竖线）"
TBL_ISSUE=$(python3 <<'PYEOF'
# F296/F297 修复：原实现只认「行首竖线」且仅按 ``` 前缀切换围栏 ⇒ 对**引用块内表格**与「无行首
#   竖线」的真表格漏检（其多余单元格仍会被渲染器静默丢弃），对 ~~~ 围栏、4 空格/制表符缩进代码块、
#   长反引号围栏内嵌 ``` 的**代码示例**误报；且对「表头列数 ≠ 分隔行列数」「分隔行后紧跟空行」两类
#   **结构性断表**不报，却输出「全部一致」（过度声称；实证：learned-skills.md:8 表头 5 vs 分隔行 4、
#   standard.md:29 分隔行后空行 ⇒ GFM 整表不成立，表体渲染为字面管道文本）。
# 新口径（分隔行驱动）：仅当某行**紧邻**一个列数相符的分隔行时才成立表头；围栏按字符+长度配对；
#   排除缩进代码块；空行即断表；另新增两条结构性判据（表头↔分隔行列数、分隔行后紧跟空行）。
import glob, os, re

def strip_bq(s):
    while True:
        m = re.match(r'^[ \t]{0,3}>[ \t]?', s)
        if not m:
            return s
        s = s[m.end():]

def fence_of(s):
    m = re.match(r'^[ \t]{0,3}(`{3,}|~{3,})', s)
    return (m.group(1)[0], len(m.group(1))) if m else None

def is_code_line(s):
    return s.startswith('    ') or s.startswith('\t')

def cells(s):
    t = strip_bq(s).strip()
    if t.startswith('|'):
        t = t[1:]
    if t.endswith('|') and not t.endswith('\\|'):
        t = t[:-1]
    return re.split(r'(?<!\\)\|', t)

def is_delim(s):
    t = strip_bq(s).strip()
    if '-' not in t or set(t) - set('|-: '):
        return False
    return all(re.fullmatch(r':?-+:?', c.strip()) for c in t.strip('|').split('|') if c.strip())

excess, struct = [], []
# F339：同 class 8 —— glob('**/*.md', recursive=True) 默认跟随符号链接 ⇒ 链接环下无限递归（门禁永不返回）；
#   改用 os.walk（followlinks=False，默认不进入符号链接目录）。
_md_files = []
for _dp, _dns, _fns in os.walk('.'):
    _dns[:] = [d for d in _dns if d != '.git']
    for _fn in _fns:
        if _fn.endswith('.md'):
            _md_files.append(os.path.relpath(os.path.join(_dp, _fn), '.'))
for f in sorted(_md_files):
    if '/.git/' in f or f.startswith('.git/'):
        continue
    lines = open(f, encoding='utf-8', errors='replace').read().split('\n')
    fence = None
    i = 0
    while i < len(lines):
        raw = lines[i]
        if fence:
            fo = fence_of(raw)
            if fo and fo[0] == fence[0] and fo[1] >= fence[1]:
                fence = None
            i += 1
            continue
        fo = fence_of(raw)
        if fo:
            fence = fo
            i += 1
            continue
        if is_code_line(raw):
            i += 1
            continue
        cur = strip_bq(raw).strip()
        nxt = strip_bq(lines[i + 1]).strip() if i + 1 < len(lines) else ''
        if '|' not in cur or not nxt or not is_delim(nxt):
            i += 1
            continue
        h, d = len(cells(raw)), len(cells(nxt))
        if h != d:
            struct.append('%s:%d(表头 %d ≠ 分隔行 %d)' % (f, i + 1, h, d))
        j = i + 2
        if j < len(lines) and strip_bq(lines[j]).strip() == '':
            k = j
            while k < len(lines) and strip_bq(lines[k]).strip() == '':
                k += 1
            if k < len(lines) and '|' in strip_bq(lines[k]) and not is_code_line(lines[k]) \
               and not fence_of(lines[k]) and len(cells(lines[k])) <= d:
                struct.append('%s:%d(分隔行后紧跟空行，表体被断)' % (f, i + 2))
        while j < len(lines):
            r = lines[j]
            if is_code_line(r) or fence_of(r) or strip_bq(r).strip() == '' or '|' not in strip_bq(r):
                break
            c = len(cells(r))
            if c > d:
                excess.append('%s:%d(%d>%d)' % (f, j + 1, c, d))
            j += 1
        i = max(j, i + 1)
if excess:
    print('EXCESS ' + ', '.join(excess[:4]) + ('' if len(excess) <= 4 else ' 等共 %d 行' % len(excess)))
if struct:
    print('STRUCT ' + ', '.join(struct[:4]) + ('' if len(struct) <= 4 else ' 等共 %d 处' % len(struct)))
PYEOF
)
  TBL_EXCESS="$(printf '%s' "$TBL_ISSUE" | grep '^EXCESS ' | sed 's/^EXCESS //')"
  TBL_STRUCT="$(printf '%s' "$TBL_ISSUE" | grep '^STRUCT ' | sed 's/^STRUCT //')"
  if [ -z "$TBL_EXCESS" ] && [ -z "$TBL_STRUCT" ]; then
    ok "全部 Markdown 表格列数一致且结构完整（表头↔分隔行↔数据行）"
  else
    if [ -n "$TBL_EXCESS" ]; then bad "表格行单元格数超过表头 → ${TBL_EXCESS}"; fi
    if [ -n "$TBL_STRUCT" ]; then bad "表格结构异常（断表）→ ${TBL_STRUCT}"; fi
  fi

echo "[25] 同一制品的多处生成器须一致（INDEX 骨架模板单一来源）"
# F360（本轮巡检实测）：`plans/dsh-codepunk-link.sh`（INDEX 缺失时自建骨架）与
#   `plans/dsh-codepunk-init.sh`（总库初始化时写骨架）是**同一制品的两处生成器**，且 init 见
#   INDEX 已存在即跳过 ⇒ 两者模板不一致时，终态内容取决于「谁先建文件」（顺序① init→register
#   保留 init 的模板；顺序② register→init 只有 link 的模板）——实测 link 原为 1 行头、init 为 11 行
#   注释块，同一输入两种顺序终态不同。此处机械核验两处 heredoc 块**逐字节一致**。
SKEL_ISSUE=$(python3 <<'PYEOF'
import io, re
def skel(p):
    t = io.open(p, encoding="utf-8", errors="replace").read()
    m = re.search(r"<<'?EOF'\n(.*?)\nEOF\n", t, re.S)
    if not m or "schema_version: 1" not in m.group(1):
        return None
    return m.group(1)
a = skel('plans/dsh-codepunk-link.sh')
b = skel('plans/dsh-codepunk-init.sh')
if a is None or b is None:
    print('MISSING link=%s init=%s' % (a is None, b is None))
elif a != b:
    la, lb = a.split('\n'), b.split('\n')
    d = [str(i + 1) for i in range(max(len(la), len(lb)))
         if (la[i] if i < len(la) else None) != (lb[i] if i < len(lb) else None)]
    print('DRIFT 差异行 %s（link %d 行 / init %d 行）' % (','.join(d[:6]), len(la), len(lb)))
PYEOF
)
if [ -z "$SKEL_ISSUE" ]; then
  ok "INDEX 骨架模板单一来源：link 与 init 逐字节一致"
elif [ "${SKEL_ISSUE%% *}" = "MISSING" ]; then
  info "INDEX 骨架模板无法核验（未定位到含 schema_version 的 heredoc 块）——无法核验 ≠ 通过"
else
  bad "INDEX 骨架模板漂移 → ${SKEL_ISSUE}"
fi

echo "[26] 治理矩阵载体可解析（行内文件型引用须仓内可解析 / artifacts.md 制品名 / 显式标注非仓内）"
# F385（本轮巡检实测）：治理矩阵是「声称 ↔ 能力互证」表，其「载体」列的引用若指向**仓外**文件
#   （如运行根本地便利脚本），读者与 CI 都无法复现该「机械」声称 ⇒ 过度声称（F294/F315/F327 同族）。
#   判据：矩阵行内反引号的文件型 token 必须①仓内可解析（多基准目录）②或是 `artifacts.md` 以
#   `##` 小节声明的**制品名**（制品在运行期生成，本就不在仓内）③或该行显式标注「非仓内」。
MATRIX_ISSUE=$(python3 <<'PYEOF'
import io, os, re
GOV = 'skills/dsh-codepunk-workflow/references/skill-governance.md'
ART = 'skills/dsh-codepunk-workflow/references/artifacts.md'
BASES = ['', 'plans', 'skills/dsh-codepunk-workflow', 'skills/dsh-codepunk-workflow/references',
         'docs', '.github/workflows', '.github']
try:
    rows = [l for l in io.open(GOV, encoding='utf-8').read().split('\n') if l.startswith('| **')]
    arts = set(re.findall(r'^##\s+([A-Za-z0-9_.-]+)', io.open(ART, encoding='utf-8').read(), re.M))
except OSError as e:
    print('MISSING %s' % e)
    raise SystemExit(0)
bad = []
for i, row in enumerate(rows, 1):
    if '非仓内' in row:
        continue
    for t in re.findall(r'`([A-Za-z0-9_./-]+\.(?:sh|py|mjs|md|yml|json))`', row):
        if t in arts:
            continue
        if any(os.path.exists(os.path.join(b, t)) for b in BASES):
            continue
        bad.append('行%d:%s' % (i, t))
print(', '.join(bad[:4]) + ('' if len(bad) <= 4 else ' 等共 %d 处' % len(bad)))
PYEOF
)
if [ -z "$MATRIX_ISSUE" ]; then
  ok "治理矩阵载体均可仓内解析（或为制品名 / 已标注非仓内）"
elif [ "${MATRIX_ISSUE%% *}" = "MISSING" ]; then
  info "治理矩阵载体无法核验（${MATRIX_ISSUE}）——无法核验 ≠ 通过"
else
  bad "治理矩阵载体不可解析 → ${MATRIX_ISSUE}"
fi

# class 17 子项（F179）：ps1 工作树行尾须为 CRLF（.gitattributes eol=crlf 的落地校验）
# F335：git 不可用（无 .git / 索引损坏）时原实现**跳过**该类，却仍以 rc=0 与
#   「无硬性不一致（24 类检查）」收尾 ⇒ 环境导致**假绿灯**（与 F299 同类）。改为**回退文件系统
#   字节核验**（真核验，非跳过）：逐个 ps1 读原始字节，出现**裸 LF**（前一个字节不是 CR）即不合格。
if git rev-parse --git-dir >/dev/null 2>&1; then
  EOLBAD=$(git ls-files --eol plans/windows/ 2>/dev/null | awk '$2 != "w/crlf" {print $NF}' | tr '\n' ' ')
  [ -z "$EOLBAD" ] && ok "ps1 工作树行尾均为 CRLF（eol=crlf 落地）" || bad "ps1 工作树行尾非 CRLF: ${EOLBAD}"
else
  EOLBAD=$(python3 - <<'PYEOF'
import glob
bad = []
for p in sorted(glob.glob('plans/windows/*.ps1')):
    try:
        b = open(p, 'rb').read()
    except OSError:
        bad.append(p.split('/')[-1] + '（不可读）')
        continue
    if b'\n' in b.replace(b'\r\n', b''):   # 剥掉合法 CRLF 后仍有 LF ⇒ 存在裸 LF
        bad.append(p.split('/')[-1])
print(' '.join(bad))
PYEOF
)
  info "非 git 工作区：ps1 行尾回退到文件系统字节核验（已核验，非跳过）"
  [ -z "$EOLBAD" ] && ok "ps1 行尾均为 CRLF（文件系统字节核验）" || bad "ps1 工作树行尾非 CRLF（文件系统字节核验）: ${EOLBAD}"
fi

echo "[27] 产品/用户平面行号引用可核验（PROF 禁写行号；锚点须落在引用区间）"
# F390/F391：`references/file-hygiene.md` 的「行号引用规则（MUST）」原以「引用 MUST 同时给出符号名检索式」
#   声称，但实测 13 处行号引用仅 3 处附检索式、且该类声称无任何门禁（同 F294/F315/F327/F338/F347 家族）。
#   本轮实测另证两处行号漂移：`PROF/cordis.patch.yml` 的 permission 区块（旧稿 `:216-229`）与 `defaultPreset`
#   （旧稿 `:229`）在用户平面编辑后各后移 1 行（实况 `:217-230`、`:230`）；两处虽带检索式、读者按检索式可发现，
#   但门禁此前无从发现。口径（与 `tools/cite-anchor.py` 一致）：仅判同行**单处**引用——有检索式者首命中行须落在
#   引用区间内（不设容差），无检索式者反引号内符号名须在区间内出现一次；缺 `DSH_APP_ROOT`/`DSH_ASAR`、
#   目标文件不存在（如 CI 无私用用户平面）记无法核验，不判失败。
# F392（medium）：同轮合并后复跑问出**第四次漂移**——该区块由 `:217-230` 漂到 `:205-218`、`defaultPreset`
#   由 `:230` 漂到 `:218`，且**非人工编辑**：`~/.dsh/profiles/desktop/cordis.patch.yml` 的 mtime 与漂移同刻，
#   即 DSH Desktop 会自行重写用户平面（模型目录等）⇒ 对用户平面写行号在结构上必然失准（同一轮内即失效，
#   merge 后 main 的文档门因此转红）。故新增子判据：`PROF/<路径>:<数字>` 一律判失败（用户平面 MUST 以符号锚点定位，
#   不写行号）；`PKG/`（产品源码，随版本升级才变）仍按原口径核验。
CITE_ISSUE=$(python3 <<'PYEOF'
import glob, os, re
CITE_RE = re.compile(r"(?P<pre>PKG|PROF)/(?P<path>[A-Za-z0-9._/-]+):(?P<start>\d+)(?:-(?P<end>\d+))?(?P<extra>,\d+)?")
EXPR_RE = re.compile(r"grep -n\s+'([^']+)'\s+<?([^ >`|]*)>?")
SPAN_RE = re.compile(r"`([^`]+)`")
IDENT_RE = re.compile(r"[A-Za-z_][A-Za-z0-9_.]{3,}")
app = os.environ.get('DSH_APP_ROOT') or os.environ.get('DSH_ASAR')
home = os.environ.get('HOME')
bases = {'PKG': os.path.join(app, 'node_modules', '@deepseek-ai') if app else None,
         'PROF': os.path.join(home, '.dsh', 'profiles', 'desktop') if home else None}
docs = sorted(glob.glob('skills/*/references/*.md')) + sorted(glob.glob('docs/*.md')) + sorted(glob.glob('docs/*/*.md'))
PROF_LINE_RE = re.compile(r"PROF/[A-Za-z0-9._/-]+:\d+")
bad = []
for doc in docs:
    with open(doc, encoding='utf-8', errors='replace') as fh:
        dlines = fh.read().split('\n')
    for i, line in enumerate(dlines, start=1):
        for pl in PROF_LINE_RE.finditer(line):
            bad.append('%s:%d %s 用户平面引用不得写行号（应用会重写该文件，行号必失准）' % (doc, i, pl.group(0)))
        found = list(CITE_RE.finditer(line))
        if len(found) != 1:
            continue
        m = found[0]
        base = bases[m.group('pre')]
        if base is None:
            continue
        target = os.path.join(base, m.group('path'))
        if not os.path.isfile(target):
            continue
        with open(target, encoding='utf-8', errors='replace') as fh:
            tlines = fh.read().split('\n')
        start = int(m.group('start'))
        end = int(m.group('end') or start)
        if end > len(tlines):
            bad.append('%s:%d %s 越界(共 %d 行)' % (doc, i, m.group(0), len(tlines)))
            continue
        e = EXPR_RE.search(line)
        if e:
            sym = e.group(1)
            hits = [j for j, l in enumerate(tlines, start=1) if sym in l]
            if not hits or not (start <= hits[0] <= end):
                bad.append('%s:%d %s 检索式 %r 首命中 %s 不在区间' % (doc, i, m.group(0), sym, hits[0] if hits else '无'))
            continue
        toks = []
        for span in SPAN_RE.findall(line):
            for t in IDENT_RE.findall(span):
                t = t.rstrip('.')
                if len(t) >= 4 and t not in toks:
                    toks.append(t)
        if not any(any(t in l for l in tlines[start - 1:end]) for t in toks):
            bad.append('%s:%d %s 锚点未在区间内出现' % (doc, i, m.group(0)))
print(', '.join(bad[:4]) + ('' if len(bad) <= 4 else ' 等共 %d 处' % len(bad)))
PYEOF
)
if [ -z "$CITE_ISSUE" ]; then ok "产品/用户平面行号引用的锚点均落在引用区间（用户平面不写行号；单引用行机械核验；无法核验者不判失败）"
else bad "行号引用锚点未落在引用区间 → ${CITE_ISSUE}"; fi

echo
# F261：原为**字面量**「23 类检查」，与实现（`echo "[N] …"` 类段数）**无任何联动**——
#   自检对「类检查」的断言数为 0（实测），故改错字面量不会有任何门禁报错（实测：改成「24 类检查」后
#   本脚本仍 rc=0 并原样输出错误计数）。按本仓「计数须派生」口径（同 F240/F241 与第 484 轮的 cmp_num 家族），
#   此处从自身源码派生类段数，新增/删除类时自动跟随。
NCLASS=$(grep -cE '^echo "\[[0-9]+\]' "$0")
# F373：doc 类数声称（实现派生量＝类数）——`doc-consistency.sh` 行内的「N 类」。
#   域：README.md + docs/**（开源规格化的对外文档面）。MUST 以「同行出现 doc-consistency」限定，
#   否则会与 `fidelity-gate.py` 的「**14 类**」（另一实现、另一实况值）同形误报。
#   实证：`docs/architecture.md` 长期写「24 类」（实况已 25），而此前类数声称不在任何门禁域。
DOC_CLS_BAD=""; DOC_CLS_HITS=0
for _f in README.md docs/*.md docs/*/*.md; do
  [ -f "$_f" ] || continue
  # 先剔除**序数**写法（`doc-consistency.sh 第 10 类`／`第 1–6 类`）——那是类号引用、不是类数声称；
  #   再只认**计数**写法（`**N 类**` / `N 类：` / `N 类（` / `N 类检查`），避免把类号当成类数（实测：
  #   未剔除序数时 docs/documentation-policy.md 报 10 处假阳性）。
  _seg="$(grep -oE 'doc-consistency.{0,120}' "$_f" 2>/dev/null | sed -E 's/第 ?[0-9]+( ?[/–-] ?[0-9]+)? 类//g')"
  for _v in $(printf '%s\n' "$_seg" | grep -oE '(\*\*)?[0-9]+ 类(\*\*|：|（|检查)' | grep -oE '[0-9]+' | sort -u); do
    DOC_CLS_HITS=$((DOC_CLS_HITS + 1))
    [ "$_v" = "$NCLASS" ] || DOC_CLS_BAD="$DOC_CLS_BAD ${_f}:类数=${_v}(实况 ${NCLASS})"
  done
done
if [ -n "$DOC_CLS_BAD" ]; then bad "doc 类数声称陈旧:${DOC_CLS_BAD}"
elif [ "$DOC_CLS_HITS" -eq 0 ]; then info "未出现 doc 类数声称（域：README + docs/**；写法：doc-consistency 同行 N 类）"
else ok "doc 类数声称与实现一致（命中 ${DOC_CLS_HITS} 处，实际 ${NCLASS} 类）"; fi
# F393：保真闸的语义项类数声称（实现派生量＝`plans/fidelity-gate.py` 的 `PATTERNS` 键数）。
#   与上一条同族但**另一实现、另一实况值**（doc 类数 27 ↔ 保真类数 14），且两者在文档里写法同形（「N 类」），
#   此前只有 doc 类数入域 ⇒ 保真类数无核验。实证（本轮）：计数同步若只按「**N 类**」在文件级替换，
#   会误伤相邻的保真行——README 的「**14 类**」被改成 27 类而**四门禁全绿**，文档静默说谎。
FIDCLS=$(grep -cE "^    '[^']+':" plans/fidelity-gate.py 2>/dev/null || true)
FID_BAD=""; FID_HITS=0
if [ -z "$FIDCLS" ] || [ "$FIDCLS" -eq 0 ] 2>/dev/null; then
  info "保真闸类数无法核验（未取到 plans/fidelity-gate.py 的 PATTERNS 键数）——无法核验 ≠ 通过"
else
  for _f in README.md docs/*.md docs/*/*.md; do
    [ -f "$_f" ] || continue
    _seg="$(grep -oE 'fidelity-gate.{0,120}' "$_f" 2>/dev/null | sed -E 's/第 ?[0-9]+( ?[/–-] ?[0-9]+)? 类//g')"
    for _v in $(printf '%s\n' "$_seg" | grep -oE '(\*\*)?[0-9]+ 类(\*\*|：|（|检查)' | grep -oE '[0-9]+' | sort -u); do
      FID_HITS=$((FID_HITS + 1))
      [ "$_v" = "$FIDCLS" ] || FID_BAD="$FID_BAD ${_f}:类数=${_v}(实况 ${FIDCLS})"
    done
  done
  if [ -n "$FID_BAD" ]; then bad "保真闸类数声称陈旧:${FID_BAD}"
  elif [ "$FID_HITS" -eq 0 ]; then info "未出现保真闸类数声称（域：README + docs/**；写法：fidelity-gate 同行 N 类）"
  else ok "保真闸类数声称与实现一致（命中 ${FID_HITS} 处，实际 ${FIDCLS} 类）"; fi
fi
# F375：`docs/development.md` §7「派生计数口径」表的**当前实况**列是**活声称**（表内只写裸数字或
#   「N（M1–MN）」形态）⇒ 既不在第 1 类「N 项…」族域内、也无任何门禁覆盖（实证：长期漂移
#   「167（M1–M167）」与「24」而实况 171/25）。本检查按**行标签**定位该表（标签即契约），取末列
#   首个整数与派生值比对；表或标签缺失 ⇒ ℹ（无法核验 ≠ 通过）。
DERIV_BAD=""; DERIV_HITS=0
if [ -f docs/development.md ]; then
  _deriv_row() { # 标签 派生值
    _l="$(grep -E "^\| $1 \|" docs/development.md | head -1)"
    [ -n "$_l" ] || return 0
    _v="$(printf '%s' "$_l" | awk -F'|' '{print $(NF-1)}' | grep -oE '[0-9]+' | head -1)"
    [ -n "$_v" ] || return 0
    DERIV_HITS=$((DERIV_HITS + 1))
    [ "$_v" = "$2" ] || DERIV_BAD="$DERIV_BAD $1=${_v}(实况 $2)"
  }
  _deriv_row 变异项数 "$MUT_N"
  _deriv_row 文档一致性类数 "$NCLASS"
  _deriv_row 电池项数 "$BAT_MAIN"
fi
if [ -n "$DERIV_BAD" ]; then bad "派生计数表实况陈旧:${DERIV_BAD}"
elif [ "$DERIV_HITS" -eq 0 ]; then info "未出现派生计数表（域：docs/development.md §7，按行标签定位）"
else ok "派生计数表实况与实现一致（命中 ${DERIV_HITS} 行：变异项数 / 文档一致性类数 / 电池项数）"; fi
if [ "$NFAIL" = 0 ]; then echo "✔ 无硬性不一致（${NCLASS} 类检查）"; exit 0; fi
echo "✗ 存在 ${NFAIL} 处不一致" >&2
exit 1
