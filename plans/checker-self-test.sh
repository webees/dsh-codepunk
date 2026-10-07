#!/usr/bin/env bash
# =============================================================================
# checker-self-test.sh —— 检查器**存活自检**（变异测试）
# -----------------------------------------------------------------------------
# 动机（实证）：F097/F099/F101/F102 一整类缺陷是「检查项因工具不可用/正则不兼容/空值判定
# 而恒判 PASS」——静态审计自身无法发现这种「守护空转」。本脚本用**注入已知缺陷**的方式验证
# 检查项真的会失败：在临时副本内逐个变异，断言**对应检查项**（按名称核对，非仅看退出码）
# MUST 判失败——只看退出码会因「其它项恰好也在失败」而误判为「已捕获」（实测踩到过）。
#
# 变异表覆盖：内容型守护（B1b/A7/E3/D1/F2）、格式型（电池格式项）、环境依赖型（D3/E3 缺
# python3、score/battery 非 git 工作区）、退出码契约型（evidence/acceptance 用法码、init 只读
# 失败）与工具型（link index 坏注册表）。
#
# 用法: checker-self-test.sh [预设根]
# 退出码: 0=全部变异均被对应检查项捕获；1=存在未被捕获的变异（守护失效/空转）；2=环境/自检问题
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
SRC="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
[ -d "$SRC/plans" ] || { echo "✗ 预设根无效: $SRC" >&2; exit 2; }
FAILED=0
ASSERT_N=0     # F190：断言**实际执行**计数（与调用点数比对，防助手缺失致变异静默空转）
MUTFAIL=0

# 递归防护：若自身已在自检上下文内（如 M5 经电池再次触发本脚本），立即退出
if [ "${DSH_CODEPUNK_SKIP_SELFTEST:-0}" = 1 ]; then
  echo "ℹ 已在自检上下文内，跳过（递归防护）"
  exit 0
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/cst.XXXXXX")" || { echo "✗ 无法建临时目录" >&2; exit 2; }
trap 'rm -rf "$work"' EXIT
# 沙箱会话：自检与操作者本机状态无关（hub 同步/tools 均用副本内构造）
SANDBOX="$work/home"
REAL_HOME="$HOME"
mkdir -p "$SANDBOX/.dsh-codepunk/scripts"
for f in "$SRC"/plans/*.sh "$SRC"/plans/*.py "$SRC"/plans/*.mjs "$SRC"/plans/windows/*.ps1; do
  [ -f "$f" ] && cp "$f" "$SANDBOX/.dsh-codepunk/scripts/" 2>/dev/null
done
# tools 目录用符号链接：PS 校验器依赖其 node_modules（tree-sitter）——只复制 .mjs 会因缺依赖失败
if [ -d "$REAL_HOME/.dsh-codepunk/tools" ]; then
  ln -s "$REAL_HOME/.dsh-codepunk/tools" "$SANDBOX/.dsh-codepunk/tools" 2>/dev/null \
    || mkdir -p "$SANDBOX/.dsh-codepunk/tools"
else
  mkdir -p "$SANDBOX/.dsh-codepunk/tools"
fi
export HOME="$SANDBOX"

fresh()      { rm -rf "$work/cur"; cp -R "$SRC" "$work/cur"; }
fresh_nogit(){ rm -rf "$work/cur"; mkdir -p "$work/cur"
               tar -C "$SRC" --exclude=.git -cf - . 2>/dev/null | tar -C "$work/cur" -xf - 2>/dev/null; }

# mutate <描述> <文件> <grep 模式>：确认变异**真的落盘**——否则自检会误报「守护未捕获」
mutate() {
  local desc="$1" f="$2" pat="$3"
  if ! grep -qE "$pat" "$f" 2>/dev/null; then
    printf '  ‼ 变异未生效（%s）——自检自身问题，非守护问题\n' "$desc" >&2
    MUTFAIL=1
  fi
}

# check <标签> <命令> <必须出现的检查项名|BASELINE>
check() {
  ASSERT_N=$((ASSERT_N + 1))
  local label="$1" cmd="$2" marker="$3" rc=0 out
  out="$( cd "$work/cur" && eval "$cmd" 2>&1 )" || rc=1
  if [ "$marker" = "BASELINE" ]; then
    if [ "$rc" = 0 ] && ! printf '%s' "$out" | grep -q '✗'; then
      printf '  ✅ %s（基线全绿）\n' "$label"
    else
      printf '  ✗ %s（基线即失败）: %s\n' "$label" "$(printf '%s' "$out" | grep '✗' | head -1 | cut -c1-72)"
      FAILED=1
    fi
    return
  fi
  # 判定：整体失败（退出码非 0 或含 ✗）且输出中出现该检查项名/关键短语
  # 说明：score 的扣分行形如 `- [A2 −20] 无法核验…` 不含 ✗，故按**全输出**匹配
  if { [ "$rc" != 0 ] || printf '%s' "$out" | grep -q '✗'; } && printf '%s' "$out" | grep -q -- "$marker"; then
    printf '  ✅ %s（已捕获）\n' "$label"
  else
    printf '  ✗ %s（**未被 %s 捕获**）实际失败项: %s\n' "$label" "$marker" \
      "$(printf '%s' "$out" | grep -E '✗|−' | head -1 | cut -c1-68)"
    FAILED=1
  fi
}

# check_rc <标签> <命令> <期望退出码> [必须出现的关键词]
# mutate_gone <描述> <文件> <grep 模式>：**删除型**变异的生效确认——模式须已**消失**
mutate_gone() {
  local desc="$1" f="$2" pat="$3"
  if grep -qE "$pat" "$f" 2>/dev/null; then
    printf '  ‼ 删除型变异未生效（%s）——自检自身问题，非守护问题\n' "$desc" >&2
    MUTFAIL=1
  fi
}
check_rc() {
  ASSERT_N=$((ASSERT_N + 1))
  local label="$1" cmd="$2" want="$3" kw="${4:-}" rc=0 out
  out="$( cd "$work/cur" && eval "$cmd" 2>&1 )" || rc=$?
  if [ "$rc" = "$want" ] && { [ -z "$kw" ] || printf '%s' "$out" | grep -q -- "$kw"; }; then
    printf '  ✅ %s（退出码 %s）\n' "$label" "$rc"
  else
    printf '  ✗ %s（退出码 %s，期望 %s%s）\n' "$label" "$rc" "$want" \
      "$([ -n "$kw" ] && printf '，且须含「%s」' "$kw")"
    FAILED=1
  fi
}

# check_no_match <标签> <命令> <不得出现的模式>：断言命令输出**不含**该模式（防「守卫回显原文」类缺陷）
check_no_match() {
  ASSERT_N=$((ASSERT_N + 1))
  local label="$1" cmd="$2" pat="$3" rc=0 out
  out="$( cd "$work/cur" && eval "$cmd" 2>&1 )" || rc=$?
  if printf '%s' "$out" | grep -qF -- "$pat"; then
    printf '  ✗ %s（输出含不应出现的原文）\n' "$label"
    FAILED=1
  else
    printf '  ✅ %s（退出码 %s，输出未回显原文）\n' "$label" "$rc"
  fi
}
# F190：M78/M79 引用过本助手但**它当时不存在** → 断言静默空转、自检仍报「通过」= 自检自身的假通过
check_contains() {   # check_contains <标签> <命令> <必须出现的子串>
  ASSERT_N=$((ASSERT_N + 1))
  local label="$1" cmd="$2" want="$3" out rc=0
  out="$( cd "$work/cur" && eval "$cmd" 2>&1 )" || rc=$?
  if printf '%s' "$out" | grep -qF -- "$want"; then
    printf '  ✅ %s\n' "$label"
  else
    printf '  ✗ %s（未含「%s」）\n' "$label" "$want"
    FAILED=1
  fi
}

FW=$(printf '\357\274\210')   # 全角左括号：载荷用拼接构造，避免本脚本自身被 B1b 误判

echo "[M110 class 3 术语咨询须「检出但不计失败」（F227）]"
fresh
printf '\n> 探针：本行裸用工作区一词。\n' >> "$work/cur/skills/dsh-codepunk-workflow/SKILL.md"
mutate "SKILL 注入裸用「工作区」" "$work/cur/skills/dsh-codepunk-workflow/SKILL.md" '裸用工作区一词'
check_rc "M110 注入术语问题 → 仍须 rc 0（不计失败）" "bash plans/doc-consistency.sh" 0 ""
check_contains "M110 术语咨询须真的检出（特异提示行出现）" "bash plans/doc-consistency.sh 2>&1" "裸用「工作区」"

echo "[M111 class 6 头部自称项数须「提示但不计失败」（F227）]"
fresh
python3 - "$work/cur/plans/preset-compat.py" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s.replace('七项检查', '九项检查', 1))
PYEOF
mutate "preset-compat 头部自称改为九项检查" "$work/cur/plans/preset-compat.py" '九项检查'
check_rc "M111 注入头部自称项数 → 仍须 rc 0（不计失败）" "bash plans/doc-consistency.sh" 0 ""
check_contains "M111 头部自称项数须真的提示（特异提示行出现）" "bash plans/doc-consistency.sh 2>&1" "头部称「九项检查」"

echo "[M107 审计分组计数声称被守护（F226）]"
fresh
python3 - "$work/cur/README.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s.replace('5 组 rubric', '9 组 rubric', 1))
PYEOF
mutate "README 审计分组声称改为 9" "$work/cur/README.md" '9 组 rubric'
check_rc "M107 篡改审计分组声称 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "审计分组"

echo "[M108 benchmarks 篇数声称被守护（F226）]"
fresh
# F300：计数声称类变异不得硬编码期望值（README 计数一变，sed 即静默不匹配 ⇒ 守护空转）。
#   改为按标签行地址替换为固定错值 99，并用不带数字的关键词断言，从此对实际计数免疫。
sed -i.bak -E "/^  benchmarks\//s/[0-9]+ 篇/99 篇/" "$work/cur/README.md"
mutate "README benchmarks 篇数声称改为 99（按标签行派生）" "$work/cur/README.md" '99 篇'
check_rc "M108 篡改 benchmarks 篇数声称 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "benchmarks 实际"

echo "[M109 硬规则上限声称被守护（F226）]"
fresh
python3 - "$work/cur/skills/dsh-codepunk-workflow/SKILL.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s.replace('| R15 |', '| R19 |', 1))
PYEOF
mutate "SKILL 硬规则最大号改为 R19" "$work/cur/skills/dsh-codepunk-workflow/SKILL.md" 'R19'
check_rc "M109 篡改硬规则上限 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "硬规则上限"

echo "[M106 「自检变异项」计数声称被守护（F225 修复存活）]"
fresh
python3 - "$work/cur/README.md" <<'PYEOF'
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
# F298：此处曾硬编码 '129 项**已知缺陷'。计数**合法**更新（如 129→131）后目标串即失效，
#   于是变异未落地、自检误报「有变异未生效」并**提前退出**（其后全部变异不再执行）。
#   改为按模式匹配当前计数，使变异目标不随计数增长而陈旧。
n = re.sub(r'\*\*\d+ 项\*\*已知缺陷', '**105 项**已知缺陷', s, count=1)
assert n != s, 'M106 变异目标串未找到（README 的计数声称文案已变）'
open(p, 'w', encoding='utf-8').write(n)
PYEOF
mutate "README 变异项声称改为 105" "$work/cur/README.md" '105 项'
check_rc "M106 篡改变异计数声称 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "自检变异项"

echo "[M105 硬规则表 R1–R15 须按数字序（F224 修复存活）]"
fresh
check_contains "M105 R14 在 R15 之前" "awk '/ R14 /{a=NR} / R15 /{b=NR} END{print (a<b)+0}' skills/dsh-codepunk-workflow/SKILL.md" "1"

echo "[M104 D3 行号引用守护范围须覆盖全部脚本类型（F218 修复存活）]"
fresh
check_contains "M104 D3 正则已扩围" "grep -c 'js|mjs|sh|py|ps1' plans/preset-audit.sh" "1"

echo "[M103 写入后 YAML 校验在无 ruby 时须声明（F217 修复存活）]"
fresh
check_contains "M103 link.sh 含 F217 声明" "grep -c F217 plans/dsh-codepunk-link.sh" "1"

echo "[M102 preset-score 的双路径谓词与 INDEX 缺口声明（F215/F216 修复存活）]"
fresh
check_contains "M102 score 含 F215 说明" "grep -c F215 plans/preset-score.sh" "2"
check_contains "M102 score 含 F216 缺口声明" "grep -c F216 plans/preset-score.sh" "1"

echo "[M101 解析双路径谓词须语义一致（F214 修复存活）]"
fresh
check_contains "M101 preset-audit 含 F214 说明" "grep -c F214 plans/preset-audit.sh" "2"

echo "[M100 回退路径的 front-matter 行数上限须与 python 路径一致（F213 修复存活）]"
fresh
check_contains "M100 awk front-matter 上限为 25" "grep -c 'NR > 25' plans/dsh-codepunk-link.sh" "1"

echo "[M99 缺 python3 时不得漏裸 stderr（F212 修复存活）]"
fresh
check_contains "M99 工具含 F212 重定向说明" "grep -c F212 plans/preset-audit.sh" "1"

echo "[M98 缺 python3 时 A7 不得假通过（F211 修复存活）]"
fresh
check_contains "M98 A7 含 python3 守卫" "grep -c 'A7=\"无法核验（缺 python3）' plans/preset-audit.sh" "1"
check_contains "M98 A2 含 python3 守卫" "grep -c 'A2=\"无法核验（缺 python3）' plans/preset-audit.sh" "1"

echo "[M97 缺运行时须判为环境缺口而非契约漂移（F209 修复存活）]"
fresh
check_contains "M97 probe_rc 含 rc126/127 自动缺口判定" "grep -c 'rc\" = 126' plans/doc-consistency.sh" "1"

echo "[M95/M96 fidelity-gate 快照异常须清晰降级（F207/F208 修复存活）]"
fresh
check_contains "M95 快照损坏分支存在" "grep -c 快照损坏或不可读 plans/fidelity-gate.py" "1"
# F258：原断言以**决策号字面量计数**（`grep -c F208 … == 1`）判存活 ⇒ 任何**合法**新增的 F208 引用
#   都会把断言击穿（R475 的 F249 修复在注释中新增第二处 F208 ⇒ 套件转红，而 F208 守护实际健在：
#   实测 `grep -c F208 plans/fidelity-gate.py` = 2）。改为断言**提示消息本体**（该消息在 fidelity-gate.py 中唯一）。
check_contains "M96 空快照提示存在" "grep -c '快照为空（未捕获受保护 token）' plans/fidelity-gate.py" "1"

echo "[M94 总库目录创建失败不得漏裸 stderr（F204 修复存活）]"
fresh
check_contains "M94 link.sh 的 mkdir 已静默 stderr" "grep -c 'mkdir -p \"\$hosted\" 2>/dev/null' plans/dsh-codepunk-link.sh" "1"

echo "[M93 apply 写入失败须清晰降级（F203 修复存活）]"
fresh
check_contains "M93 declare 含写入失败捕获分支" "grep -c '无法写入 profile patch' plans/preset-declare.mjs" "1"

echo "[M92 A5 成段重复扣分可达（15 指标全覆盖收口）]"
fresh
python3 - "$work/cur/skills/dsh-codepunk-workflow/SKILL.md" <<'PYEOF'
import sys
dup = "这是一段用于探针的重复长句：它足够长以便超过六十字符阈值，并且不以特殊字符开头，重复出现应当被检测为成段重复；此处再补足若干字符以确保长度明显超过阈值。"
p = sys.argv[1]
open(p, "a", encoding="utf-8").write("\n" + "\n".join([dup] * 4) + "\n")
print("MUTATED")
PYEOF
check_rc "M92 注入成段重复 → A5 扣分" "bash plans/preset-score.sh 2>&1" 1 "成段重复"

echo "[M91 空 SKILL 下审计不得满分（F201 修复存活）]"
fresh
: > "$work/cur/skills/dsh-codepunk-workflow/SKILL.md"
check_rc "M91 清空 SKILL → 审计须失分并说明" "bash plans/preset-audit.sh 2>&1" 1 "B0 SKILL 内容过少"

echo "[M90 两处 awk 回退同样校验（F200 修复存活）]"
fresh
check_contains "M90 awk 回退校验点存在（应为 2 处）" "grep -c 'F200：两处 awk 回退' plans/dsh-codepunk-link.sh" "2"

echo "[M89 link.sh 标记值须做形状校验（F199 修复存活）]"
fresh
check_contains "M89 link.sh 含 _validate_marker" "grep -n _validate_marker plans/dsh-codepunk-link.sh" "_validate_marker"

echo "[M88 python 工具须进程内固定 UTF-8 输出（F198 修复存活）]"
fresh
check_contains "M88 preset-compat 含 UTF-8 reconfigure" "grep -c F198：非 UTF-8 locale 下 python 的 stdout 编码随 locale plans/preset-compat.py" "1"
check_contains "M88 fidelity-gate 含 UTF-8 reconfigure" "grep -c F198：非 UTF-8 locale 下 python 的 stdout 编码随 locale plans/fidelity-gate.py" "1"

echo "[M87 其余 shell 工具亦须按需固定 UTF-8 locale（F197 修复存活）]"
fresh
check_contains "M87 link.sh 含 locale 固定片段" "grep -c F197 plans/dsh-codepunk-link.sh" "1"
check_contains "M87 init.sh 含 locale 固定片段" "grep -c F197 plans/dsh-codepunk-init.sh" "1"

echo "[M86 门禁工具须按需固定 UTF-8 locale（F195 修复存活）]"
fresh
check_contains "M86 preset-score 含 locale 固定片段" "grep -c F195 plans/preset-score.sh" "1"
check_contains "M86 doc-consistency 含 locale 固定片段" "grep -c F195 plans/doc-consistency.sh" "1"

echo "[M85 preset-score 缺 python3 时须给明确核验缺口（F194 修复存活）]"
fresh
check_contains "M85 缺 python3 分支存在（A5 无法核验扣分）" "grep -n 'command -v python3' plans/preset-score.sh" "command -v python3"

echo "[M84 自检须含「未定义断言助手」守卫（F191 修复存活）]"
fresh
check_contains "M84 自检含未定义助手守卫" "grep -n UNKNOWN_HELPERS plans/checker-self-test.sh" "UNKNOWN_HELPERS"

echo "[M82 运行型 mjs 缺退出码声明须被检出（F187 覆盖面）]"
fresh
python3 - "$work/cur/plans/ps-validate.mjs" <<'PYEOF'
import sys
p = sys.argv[1]
keep = [l for l in open(p, encoding='utf-8').read().split('\n') if '退出码' not in l]
open(p, 'w', encoding='utf-8').write('\n'.join(keep))
print('MUTATED' if len(keep) else 'EMPTY')
PYEOF
check_rc "M82 抽掉 mjs 的码表行 → 报缺声明" "bash plans/doc-consistency.sh 2>&1" 1 "缺退出码声明"

echo "[M83 对照：无退出调用的 py 抽掉声明行不应报缺（F187 豁免不得误伤）]"
fresh
python3 - "$work/cur/plans/preset-compat.py" <<'PYEOF'
import sys
p = sys.argv[1]
keep = [l for l in open(p, encoding='utf-8').read().split('\n') if '退出码' not in l]
open(p, 'w', encoding='utf-8').write('\n'.join(keep))
print('MUTATED')
PYEOF
check_no_match "M83 非运行型 py 抽掉声明后不得报缺（豁免正确）" "bash plans/doc-consistency.sh 2>&1" "preset-compat.py"

echo "== 检查器存活自检（变异测试） =="
echo "预设根: $SRC"

fresh; echo "[基线]"
check "未变异·审计" "bash plans/preset-audit.sh" BASELINE
check "未变异·自检内层电池（跳过自检项）" "DSH_CODEPUNK_SKIP_SELFTEST=1 bash plans/verify-battery.sh" BASELINE

echo "[M1-M6 内容/格式型守护]"
fresh; printf '\nfail "x $HOME%s注入"\n' "$FW" >> "$work/cur/plans/dsh-codepunk-home.sh"
check "M1 全角紧邻陷阱 → B1b" "bash plans/preset-audit.sh" "B1b"

fresh
sed -i '' '1,/backgroundMode: continuable/{s/backgroundMode: continuable/backgroundMode: one-shot/;}' "$work/cur/agent.cordis.yml" 2>/dev/null \
  || sed -i '1,/backgroundMode: continuable/{s/backgroundMode: continuable/backgroundMode: one-shot/;}' "$work/cur/agent.cordis.yml"
mutate "岗位改为 one-shot" "$work/cur/agent.cordis.yml" 'backgroundMode: one-shot'
check "M2 削弱岗位可恢复性 → A7" "bash plans/preset-audit.sh" "A7"

fresh; printf '\n见 [工具](plans/no-such-tool-xyz.sh)。\n' >> "$work/cur/README.md"
check "M3 仓内死链 → E3" "bash plans/preset-audit.sh" "E3"

fresh; mv "$work/cur/skills/dsh-codepunk-workflow/benchmarks" "$work/cur/skills/dsh-codepunk-workflow/bm_x"
check "M4 基准目录改名 → D1" "bash plans/preset-audit.sh" "D1"

fresh; printf 'x = 1   \n' >> "$work/cur/CONTRIBUTING.md"
check "M5 行尾空白 → 电池格式项" "DSH_CODEPUNK_SKIP_SELFTEST=1 bash plans/verify-battery.sh" "格式"

fresh; printf '\n# 注入\n' >> "$work/cur/plans/preset-score.sh"
check "M6 源与总库不同步 → F2" "bash plans/preset-audit.sh" "F2"

echo "[M7-M9 环境依赖型守护（无法核验 ≠ 通过）]"
# python3 失败桩：command -v 成功但执行失败
fresh; mkdir -p "$work/bin"; printf '#!/bin/sh\nexit 1\n' > "$work/bin/python3"; chmod +x "$work/bin/python3"
check "M7 缺 python3 → D3/E3 无法核验" \
  "PATH=\"$work/bin:\$PATH\" bash plans/preset-audit.sh" "无法核验"

fresh_nogit
check "M8 非 git 工作区 → score 无法核验" "bash plans/preset-score.sh" "无法核验"
check "M9 非 git 工作区 → 电池无法核验" "DSH_CODEPUNK_SKIP_SELFTEST=1 bash plans/verify-battery.sh" "无法核验"

echo "[M10-M13 退出码契约与失败路径]"
fresh; mkdir -p "$work/hub"
check_rc "M10 坏注册表 → link index 失败" \
  "DSH_CODEPUNK_HOME=\"$work/hub\" DSH_CODEPUNK_INDEX=\"$work/hub/INDEX.yaml\" bash -c 'printf \"projects: [{{{ bad\\n\" > \"\$DSH_CODEPUNK_INDEX\"; bash plans/dsh-codepunk-link.sh index'" \
  1 "解析失败"

fresh
check_rc "M11 evidence-verify 缺参数 → 2" "bash plans/evidence-verify.sh" 2 "用法"
check_rc "M12 acceptance-verify 缺参数 → 2" "bash plans/acceptance-verify.sh" 2 "用法"

fresh; mkdir -p "$work/ro"; chmod 500 "$work/ro"
check_rc "M13 init 只读 HOME → 非零失败" "HOME=\"$work/ro\" bash plans/dsh-codepunk-init.sh" 2 "无法创建总库根"
chmod 700 "$work/ro" 2>/dev/null

echo "[M14 声明副本敏感度（双向：未改须一致 / 改适配路径须漂移）]"
# 语义模式需 js-yaml：由 DSH_APP_ROOT / DSH_ASAR 提供（用户环境契约，与 preset-compat 一致）
REAL_PATCH="${DSH_PROFILE_PATCH:-$REAL_HOME/.dsh/profiles/desktop/cordis.patch.yml}"
if [ -z "${DSH_APP_ROOT:-}${DSH_ASAR:-}" ]; then
  printf '  ℹ M14 跳过（未设 DSH_APP_ROOT/DSH_ASAR，无法进入语义核验模式）\n'
elif [ ! -f "$REAL_PATCH" ]; then
  printf '  ℹ M14 跳过（未找到 profile patch：%s）\n' "$REAL_PATCH"
else
  fresh; mkdir -p "$HOME/.dsh/profiles/desktop"
  cp "$REAL_PATCH" "$HOME/.dsh/profiles/desktop/cordis.patch.yml"
  check_rc "M14a 未篡改 → 一致" "node plans/preset-declare.mjs check" 0 "语义一致"
  python3 - "$HOME/.dsh/profiles/desktop/cordis.patch.yml" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
n = s.replace('../../.agent-presets/dsh-codepunk/skills/', '/tmp/evil-skills/')
if n == s:                      # 兜底：按 skills/ 片段做更宽松的替换
    n = s.replace("new URL('skills/'", "new URL('/tmp/evil-skills/'", 1)
open(p, 'w', encoding='utf-8').write(n)
PYEOF
  check_rc "M14b 改适配路径 → 漂移" "node plans/preset-declare.mjs check" 1 "漂移"
fi

echo "[M15 文档声称一致性（doc-consistency 存活）]"
fresh
python3 - "$work/cur/README.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
n = s.replace('15 指标', '99 指标', 1)
open(p, 'w', encoding='utf-8').write(n)
PYEOF
mutate "README 指标声称改为 99" "$work/cur/README.md" '99 指标'
check_rc "M15 改计数声称 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "评分指标"

echo "[M16 跨文件阈值一致（doc-consistency 第 7 类存活）]"
fresh
python3 - "$work/cur/skills/dsh-codepunk-workflow/references/artifacts.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
n = s.replace('exit_code=0', 'exit_code=1', 1)
open(p, 'w', encoding='utf-8').write(n)
PYEOF
mutate "证据门退出码改为 1" "$work/cur/skills/dsh-codepunk-workflow/references/artifacts.md" 'exit_code=1'
check_rc "M16 阈值不一 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "取值不一"

echo "[M17 日期形态与未来日期（doc-consistency 第 8 类存活）]"
fresh
python3 - "$work/cur/README.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s + '\n> 注入：实测日期 2099-01-01。\n')
PYEOF
mutate "注入未来日期" "$work/cur/README.md" '2099-01-01'
check_rc "M17 未来日期 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "未来日期: "

echo "[M18 编号引用可解析（doc-consistency 第 9 类存活）]"
fresh
python3 - "$work/cur/README.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s + '\n> 注入：参见 D999 决策。\n')
PYEOF
mutate "注入未登记 D 号" "$work/cur/README.md" 'D999'
check_rc "M18 未登记 D 号 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "D 未登记"

echo "[M19 章节级引用可解析（doc-consistency 第 10 类存活）]"
fresh
python3 - "$work/cur/skills/dsh-codepunk-workflow/references/artifacts.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
import re
open(p, 'w', encoding='utf-8').write(re.sub('记忆简报', '备忘摘要', s))
PYEOF
mutate "章节名全量改名" "$work/cur/skills/dsh-codepunk-workflow/references/artifacts.md" '备忘摘要'
check_rc "M19 章节名失效 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "章节名未找到"

echo "[M20 决策号语义相符（doc-consistency 第 11 类存活）]"
fresh
python3 - "$work/cur/skills/dsh-codepunk-workflow/benchmarks/adhd-workflow-analysis.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s.replace('D075（消息纪律）', 'D075（量子隧穿）', 1))
PYEOF
mutate "括注改无关词" "$work/cur/skills/dsh-codepunk-workflow/benchmarks/adhd-workflow-analysis.md" '量子隧穿'
check_rc "M20 括注与含义无关 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "疑似错配"

echo "[M21 状态取值合法性（doc-consistency 第 12 类存活）]"
fresh
python3 - "$work/cur/skills/dsh-codepunk-workflow/references/artifacts.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s.replace('status: planned', 'status: bogus_state', 1))
PYEOF
mutate "注入越界状态值" "$work/cur/skills/dsh-codepunk-workflow/references/artifacts.md" 'bogus_state'
check_rc "M21 状态越界 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "状态取值越界"

echo "[M22 死状态检测（doc-consistency 第 13 类存活）]"
fresh
python3 - "$work/cur/skills/dsh-codepunk-workflow/references/artifacts.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(
    s.replace('# drift_before', '# drift_before', 1).replace(
        'status: approved                   # draft', 'status: approved                   # draft_zz', 1))
PYEOF
mutate "注入 unsupported 状态值" "$work/cur/skills/dsh-codepunk-workflow/references/artifacts.md" 'draft_zz'
check_rc "M22 死状态 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "仅存在于模板注释"

echo "[M23 worktree 治理核验（verify-worktree.sh 存活）]"
fresh
# 真实夹具：主仓库（含一次提交）+ 独立散落根
wt_main="$work/wt/main"; wt_scan="$work/wt/scan"
rm -rf "$work/wt"; mkdir -p "$wt_main" "$wt_scan"
( cd "$wt_main" && git init -q . && git config user.email t@t && git config user.name t   && : > f.txt && git add f.txt && git commit -qm init ) >/dev/null 2>&1
# ① 基线：应为通过（散落根干净、列表仅主仓库）
check_rc "M23-a 基线通过（散落根干净）" \
  "SCAN_ROOT='$wt_scan' bash plans/verify-worktree.sh '$wt_main' --quiet" 0
# ② 分支 1：散落根出现 worktree → 必须判 FAIL
( cd "$wt_main" && git worktree add -q "$wt_scan/stray-room" -b stray >/dev/null 2>&1 )
check_rc "M23-b 检出散落 worktree → 失败" \
  "SCAN_ROOT='$wt_scan' bash plans/verify-worktree.sh '$wt_main' 2>&1" 1 "散落"
# ③ 分支 2：散落根换空目录 → 主仓库列表不干净必须判 FAIL
mkdir -p "$work/wt/empty"
check_rc "M23-c 主仓库列表不干净 → 失败" \
  "SCAN_ROOT='$work/wt/empty' bash plans/verify-worktree.sh '$wt_main' 2>&1" 1 "不干净"
# ④ 用法错：无参数且无 MAIN_REPO → 退出码 2
check_rc "M23-d 缺主仓库参数 → 用法错" \
  "env -u MAIN_REPO bash plans/verify-worktree.sh 2>&1" 2 "用法"

echo "[M129 登记残留（目录已删未 prune）须分列诊断（F275）]"
fresh
wt2_main="$work/wt2/main"; wt2_scan="$work/wt2/scan"
rm -rf "$work/wt2"; mkdir -p "$wt2_main" "$wt2_scan"
( cd "$wt2_main" && git init -q . && git config user.email t@t && git config user.name t && : > f.txt && \
  git add f.txt && git commit -qm init && git worktree add -q "$wt2_scan/wt-gone" -b gone ) >/dev/null 2>&1
rm -rf "$wt2_scan/wt-gone"
check_rc "M129-a 登记残留须点名「登记残留」" \
  "SCAN_ROOT='$wt2_scan' bash plans/verify-worktree.sh '$wt2_main' 2>&1" 1 "登记残留"
check_rc "M129-b 残留态须给出 prune 建议" \
  "SCAN_ROOT='$wt2_scan' bash plans/verify-worktree.sh '$wt2_main' 2>&1" 1 "worktree prune"
git -C "$wt2_main" worktree prune >/dev/null 2>&1
check_rc "M129-c prune 后恢复通过" \
  "SCAN_ROOT='$wt2_scan' bash plans/verify-worktree.sh '$wt2_main' --quiet" 0

echo "[M24 错误根路径 → 用法错（exit 2 契约）]"
fresh
mkdir -p "$work/wrongroot"
for script in preset-audit preset-score doc-consistency verify-battery; do
  check_rc "M24 错误根：$script" "bash plans/$script.sh '$work/wrongroot' 2>&1" 2 "不是本预设仓库"
done

echo "[M25 INDEX 语义/类型核验（link index 存活）]"
fresh
mkdir -p "$work/linkhome/.dsh-codepunk"
printf 'schema_version: 1\nprojects: 5\n' > "$work/linkhome/.dsh-codepunk/INDEX.yaml"
mutate "INDEX projects 为标量" "$work/linkhome/.dsh-codepunk/INDEX.yaml" 'projects: 5'
check_rc "M25 类型非法 INDEX → 失败" "HOME='$work/linkhome' bash plans/dsh-codepunk-link.sh index 2>&1" 1 "语义非法"
printf 'schema_version: 1\nprojects: {}\n' > "$work/linkhome/.dsh-codepunk/INDEX.yaml"
check_rc "M25 合法骨架 → 通过" "HOME='$work/linkhome' bash plans/dsh-codepunk-link.sh index 2>&1" 0 "校验通过"

echo "[M26 泄露防护门检测存活（leak-guard 命中必阻断）]"
# 背景：电池只跑通过路径（--staged/--tree/--history 3/3），**从不证明命中会阻断**——
#   匹配逻辑若坏仍显 3/3（F097「守护恒绿」类）。此处用沙箱 HOME 证明两条匹配链均存活。
fresh
mkdir -p "$SANDBOX/.dsh-codepunk"
: > "$SANDBOX/.dsh-codepunk/denylist.txt"          # 先清空禁词表
# ① 通用模式链（不依赖本地禁词）：绝对路径
# 触发串在运行时拼接：自检文件内不得出现字面量，否则本仓守卫（B10 硬编码绝对路径 / B11 泄露门）
# 会在副本内把自检文件自身判为违规（F131 实测：评分由 15/15 掉至 13 项）。
printf 'see /%s/%s/private/notes.md\n' 'Users' 'someone' > "$work/leak-generic.txt"
check_rc "M26-a 通用模式命中 → 阻断" \
  "bash plans/dsh-codepunk-leak-guard.sh --msg '$work/leak-generic.txt' 2>&1" 1 "[通用]"
# ② 邮箱形态
printf 'contact %s@%s now\n' 'x/y' 'example.com' > "$work/leak-mail.txt"
check_rc "M26-b 邮箱形态命中 → 阻断" \
  "bash plans/dsh-codepunk-leak-guard.sh --msg '$work/leak-mail.txt' 2>&1" 1 "[通用]"
# ③ 禁词链（本地词表）：命中须阻断
printf 'acme-topsecret\n' > "$SANDBOX/.dsh-codepunk/denylist.txt"
printf 'this mentions acme-topsecret inline\n' > "$work/leak-term.txt"
check_rc "M26-c 禁词命中 → 阻断" \
  "bash plans/dsh-codepunk-leak-guard.sh --msg '$work/leak-term.txt' 2>&1" 1 "[禁词]"
# ④ 干净内容 + 空词表 → 必须通过（防假阳性）
: > "$SANDBOX/.dsh-codepunk/denylist.txt"
printf 'clean text with no markers\n' > "$work/leak-clean.txt"
check_rc "M26-d 干净内容 → 通过" \
  "bash plans/dsh-codepunk-leak-guard.sh --msg '$work/leak-clean.txt' 2>&1" 0

echo "[M27 夹具字面量纪律（doc-consistency 第 14 类存活）]"
fresh
# 字面量同样运行时拼接（否则第 14 类会命中夹具自身——与 F131 同源）
printf 'see /%s/%s/private/x.txt\n' 'Users' 'zzz' >> "$work/cur/plans/checker-self-test.sh"
mutate "夹具注入绝对路径字面量" "$work/cur/plans/checker-self-test.sh" '/Users/'
check_rc "M27 夹具字面量 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "夹具含触发守卫的字面量"

echo "[M28 评分扣分可达性（代表性子集：证明扣分路径真的会触发）]"
# 背景（F133）：preset-score 有 **64** 个扣分点（F281：旧记 37/38 系未派生的陈旧数；派生= `grep -cE 'ded +[AB][0-9]+ +[0-9]+' plans/preset-score.sh`），此前仅 B10/B11 因一次事故被证明可达；
#   其余 35 个缺可达性证据——若某分支永不可达，15/15 可能就是恒绿假象。
#   此处对 6 个指标各注入一个定向缺陷，断言「评分不再是满分」且**命中该指标的具体理由**。
score_reason() {  # score_reason <标签> <变异命令> <变异后进行断言的文件> <变异模式> <期望理由片段>
  local label="$1" mut="$2" file="$3" pat="$4" want="$5"
  fresh
  eval "$mut"
  if [ "${MUT_GONE:-0}" = 1 ]; then mutate_gone "$label" "$file" "$pat"; else mutate "$label" "$file" "$pat"; fi
  local rc=0 out
  out="$( cd "$work/cur" && bash plans/preset-score.sh 2>&1 )" || rc=$?
  if [ "$rc" = 1 ] && printf '%s' "$out" | grep -q -- "$want"; then
    printf '  ✅ %s（评分降级且命中「%s」）\n' "$label" "$want"
  else
    printf '  ✗ %s（rc=%s，未命中「%s」）\n' "$label" "$rc" "$want"
    FAILED=1
  fi
}
echo "[M122 ps-validate 目录/不可读输入须判「未校验」而非恒真通过（F237）]"
check_rc "M122 目录参数 → ps-validate rc 2 且判「未校验」（非恒真通过）" "node plans/ps-validate.mjs plans/windows 2>&1" 2 "个文件未校验"

echo "[M121 F2 源副本缺失须报不同步（F235）]"
fresh
for f in "$work/cur"/plans/*.sh; do
  [ "$(basename "$f")" = preset-audit.sh ] || rm -f "$f"
done
rm -f "$work/cur"/plans/*.py "$work/cur"/plans/*.mjs
mutate_gone "删除除 preset-audit 外的源副本脚本" "$work/cur/plans/preset-score.sh" 'ded A1'
check_rc "M121 源副本缺失 → F2 报不同步（非恒真通过）" "bash plans/preset-audit.sh 2>&1" 1 "源副本缺失"

echo "[M126 凡「无法核验」情形须标注「无法核验≠通过」（F242）]"
fresh
python3 - "$work/cur/plans/doc-consistency.sh" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = '——无法核验≠通过（同 F180 口径）'
# 注意：本目标串随该标注文案变化而失效（同 M106/M124/M125 的陈旧陷阱）。
assert old in s, 'M126 变异目标串未找到'
open(p, 'w', encoding='utf-8').write(s.replace(old, '', 1))
PYEOF
check_rc "M126 移除「无法核验」标注 → 约定型模式守卫须报缺" "grep -q '未匹配到取值.*无法核验≠通过' plans/doc-consistency.sh" 1

echo "[M125 治理表 class 20 探针数须与实现一致（F241）]"
fresh
python3 - "$work/cur/skills/dsh-codepunk-workflow/references/skill-governance.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = '**19 条探针**'
# 注意：本目标串随 class 20 探针数变化而失效（同 M106/M124 的陈旧陷阱）——增删探针时须同步此处。
assert old in s, 'M125 变异目标串未找到'
open(p, 'w', encoding='utf-8').write(s.replace(old, '**9 条探针**', 1))
PYEOF
check_rc "M125 篡改治理表探针数声称 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "治理表探针数"

echo "[M124 README 电池项数声称须与实现一致（F240）]"
fresh
python3 - "$work/cur/README.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = '完整验证电池（**11 项**'
# 注意：本目标串随「验证电池项数」变化而失效（同 M106 的陈旧陷阱）——改动 verify-battery.sh 项数时须同步此处。
assert old in s, 'M124 变异目标串未找到'
open(p, 'w', encoding='utf-8').write(s.replace(old, '完整验证电池（**12 项**', 1))
PYEOF
check_rc "M124 篡改电池项数声称 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "验证电池项数"

echo "[M123 坏根须给友好提示、不得泄漏 cd 原始错误（F239）]"
fresh
python3 - "$work/cur/plans/verify-battery.sh" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = 'cd "$ROOT" 2>/dev/null || { echo "✗ 预设根不存在: $ROOT"; exit 2; }'
assert old in s, 'M123 变异目标串未找到'
open(p, 'w', encoding='utf-8').write(s.replace(old, 'cd "$ROOT" 2>/dev/null || exit 2'))
PYEOF
check_rc "M123 battery 坏根缺提示 → class 20 须失败（非恒真通过）" "bash plans/doc-consistency.sh 2>&1" 1 "缺友好提示"

echo "[M120 class 21 缺配置须判「无法核验」且不得抛 Traceback（F234）]"
fresh
rm -f "$work/cur/agent.cordis.yml"
mutate_gone "删除 agent.cordis.yml（class 21 用）" "$work/cur/agent.cordis.yml" 'tool-subagent-squad-lead'
check_rc "M120 缺配置 → class 21 判无法核验（非假通过）" "bash plans/doc-consistency.sh 2>&1" 1 "无法核验：agent.cordis.yml 缺失"
check_no_match "M120 不得抛原始 Traceback（卫生规则）" "bash plans/doc-consistency.sh 2>&1" "Traceback"

echo "[M119 B10 空 .gitattributes 须扣分（F233）]"
MUT_GONE=1
score_reason "M119 B10 .gitattributes 为空" \
  ": > '$work/cur/.gitattributes'" \
  "$work/cur/.gitattributes" 'eol=lf' '换行策略名存实亡'
MUT_GONE=0

echo "[M118 A7 缺配置须判「无法核验」（F232）]"
fresh
rm -f "$work/cur/agent.cordis.yml"
mutate_gone "删除 agent.cordis.yml" "$work/cur/agent.cordis.yml" 'tool-subagent-squad-lead'
check_rc "M118 缺配置 → A7 判无法核验（非恒真通过）" "bash plans/preset-audit.sh 2>&1" 1 "A7 配置不变量违规: agent.cordis.yml 缺失"

echo "[M117 class 5 空脚本输入须判「无法核验」（F231）]"
fresh
for f in "$work/cur"/plans/*.sh; do
  [ "$(basename "$f")" = doc-consistency.sh ] || rm -f "$f"
done
rm -f "$work/cur"/plans/*.py "$work/cur"/plans/*.mjs
mutate_gone "删除除检查器外的全部脚本" "$work/cur/plans/preset-score.sh" 'ded A1'
check_rc "M117 无可检脚本 → class 5 判无法核验（非恒真通过）" "bash plans/doc-consistency.sh 2>&1" 1 "plans 下无可检脚本"

echo "[M116 class 18 空 ps1 输入须判「无法核验」（F230）]"
fresh
rm -f "$work/cur"/plans/windows/*.ps1
mutate_gone "删除全部 ps1 文件" "$work/cur/plans/windows/dsh-codepunk-link.ps1" 'param('
check_rc "M116 无 ps1 → class 18 判无法核验（非恒真通过）" "bash plans/doc-consistency.sh 2>&1" 1 "pwsh 钩子语法无法核验"

echo "[M114/M115 audit A2 与 D3 正检可达（F229）]"
fresh
sed -i.bak 's/边界：/边界=/g' "$work/cur/agent.cordis.yml"
mutate "persona 维度词「边界：」全部改名" "$work/cur/agent.cordis.yml" '边界='
check_rc "M114 缺岗位维度 → A2 报 FAIL 0/11" "bash plans/preset-audit.sh 2>&1" 1 "A2 FAIL 0/11"
fresh
printf '\n> 探针：见 plans/preset-score.sh:123 的实现。\n' >> "$work/cur/README.md"
mutate "README 注入裸行号引用" "$work/cur/README.md" 'preset-score.sh:123'
check_rc "M115 裸行号引用 → D3 报缺符号名" "bash plans/preset-audit.sh 2>&1" 1 "D3 行号引用缺符号名"

echo "[M112/M113 score A 组 A1/A3 扣分可达（F228）]"
score_reason "M112 score A1 SKILL 缺阶段" \
  "sed -i.bak 's/需求确认/需求核定/g' '$work/cur/skills/dsh-codepunk-workflow/SKILL.md'" \
  "$work/cur/skills/dsh-codepunk-workflow/SKILL.md" '需求核定' 'SKILL 缺阶段'
score_reason "M113 score A3 README 基准声称不符" \
  "sed -i.bak -E '/^  benchmarks\\//s/[0-9]+ 篇/99 篇/' '$work/cur/README.md'" \
  "$work/cur/README.md" '99 篇' 'README 声称基准'

score_reason "M28-a B7 缺 roles.md" \
  "rm -f '$work/cur/skills/dsh-codepunk-workflow/references/roles.md'" \
  "$work/cur/plans/preset-score.sh" 'B7' '缺 references/roles.md'
score_reason "M28-b B8 bash 语法错" \
  "printf 'if true; then\n' >> '$work/cur/plans/verify-worktree.sh'" \
  "$work/cur/plans/verify-worktree.sh" 'if true; then' 'bash -n 失败'
score_reason "M28-c B10 缺 .gitattributes" \
  "rm -f '$work/cur/.gitattributes'" \
  "$work/cur/plans/preset-score.sh" 'B10' '.gitattributes'
MUT_GONE=1
score_reason "M28-d B12 README 缺节" \
  "sed -i.bak '/^## 快速开始/d' '$work/cur/README.md'" \
  "$work/cur/README.md" '## 快速开始' 'README 缺节'
MUT_GONE=1
score_reason "M28-e B13 SKILL 缺硬规则 R 行" \
  "sed -i.bak '/^| R9 /d' '$work/cur/skills/dsh-codepunk-workflow/SKILL.md'" \
  "$work/cur/skills/dsh-codepunk-workflow/SKILL.md" 'R9' '缺硬规则'
MUT_GONE=0
score_reason "M28-f B14 .DS_Store 杂散" \
  "printf 'dsstore-marker\n' > '$work/cur/.DS_Store'" \
  "$work/cur/.DS_Store" 'dsstore-marker' 'DS_Store'

echo "[M29 评分扣分可达性（第二批：B6/B7/B10/B11/B12/B14）]"
# 约定同 M28：注入定向缺陷 → 断言「不再满分」且**命中该指标的具体扣分理由**
MUT_GONE=1
score_reason "M29-a B6 roles.md 失 run-lead 术语" \
  "sed -i.bak 's/run-lead/主责/g' '$work/cur/skills/dsh-codepunk-workflow/references/roles.md'" \
  "$work/cur/skills/dsh-codepunk-workflow/references/roles.md" 'run-lead' 'roles.md 未使用 run-lead 术语'
score_reason "M29-a2 B6 SKILL 单侧失别名（反向分支）" \
  "sed -i.bak 's/run-lead/主责/g' '$work/cur/skills/dsh-codepunk-workflow/SKILL.md'" \
  "$work/cur/skills/dsh-codepunk-workflow/SKILL.md" 'run-lead' 'SKILL 未引入 run-lead 术语'
MUT_GONE=0
score_reason "M29-b B7 岗位人设不足 9" \
  "sed -i.bak 's/tool-subagent-/tool-x-/g' '$work/cur/agent.cordis.yml'" \
  "$work/cur/agent.cordis.yml" 'tool-x-' '岗位人设仅'
MUT_GONE=1
score_reason "M29-c B10 Windows 脚本不足 4" \
  "rm -f '$work/cur/plans/windows/dsh-codepunk-link.ps1' '$work/cur/plans/windows/dsh-codepunk-home.ps1'" \
  "$work/cur/plans/windows" 'dsh-codepunk-link.ps1' 'Windows 脚本仅'
score_reason "M29-d B11 禁词留本地未文档化" \
  "sed -i.bak 's/denylist.txt/DENYWORDFILE/g' '$work/cur/skills/dsh-codepunk-workflow/references/file-hygiene.md'" \
  "$work/cur/skills/dsh-codepunk-workflow/references/file-hygiene.md" 'denylist.txt' '留本地'
MUT_GONE=0
score_reason "M29-e B12 SKILL 无分节导航" \
  "sed -i.bak -e 's/^## /##x /' -e 's/^### 1\\.1/###x 1.1/' '$work/cur/skills/dsh-codepunk-workflow/SKILL.md'" \
  "$work/cur/skills/dsh-codepunk-workflow/SKILL.md" '##x ' 'SKILL 无分节导航'
# B14-a：hub 与仓库不同步（沙箱 hub 内追加标记；测完立刻还原，避免污染后续断言）
MUT_GONE=0
score_reason "M29-f B14 plans↔scripts 不同步" \
  "cp '$SANDBOX/.dsh-codepunk/scripts/preset-audit.sh' '$SANDBOX/preset-audit.sh.orig' && printf '# drift-marker\\n' >> '$SANDBOX/.dsh-codepunk/scripts/preset-audit.sh'" \
  "$SANDBOX/.dsh-codepunk/scripts/preset-audit.sh" 'drift-marker' 'plans↔scripts 不同步'
cp "$SANDBOX/preset-audit.sh.orig" "$SANDBOX/.dsh-codepunk/scripts/preset-audit.sh" 2>/dev/null || true
score_reason "M29-g B14 LICENSE 未跟踪" \
  "git -C '$work/cur' rm --cached -q LICENSE" \
  "$work/cur/plans/preset-score.sh" 'B14' '未跟踪发布必备文件'
echo "[M30 评分扣分可达性（第三批：B6/B7/B9/B12/B13/B14/B15）]"
S="$work/cur/skills/dsh-codepunk-workflow/SKILL.md"
R="$work/cur/skills/dsh-codepunk-workflow/references"
SC="$work/cur/plans/preset-score.sh"
MUT_GONE=1
score_reason "M30-a B6 SKILL 未说明工具正式位" \
  "sed -i.bak 's#\\.dsh-codepunk/scripts/#SCRIPTS-DIR#g' \"$S\"" \
  "$S" '\\.dsh-codepunk/scripts/' 'SKILL 未说明工具正式位'
score_reason "M30-b B7 缺 standard.md" \
  "rm -f \"$R/standard.md\"" \
  "$R/standard.md" 'D0' '缺 references/standard.md'
score_reason "M30-c B7 缺 learned-skills.md" \
  "rm -f \"$R/learned-skills.md\"" \
  "$R/learned-skills.md" 'D0' '缺 references/learned-skills.md'
score_reason "M30-d B9 缺维护公约" \
  "sed -i.bak 's/维护公约/维护约定/g' '$work/cur/README.md' '$work/cur/CONTRIBUTING.md'" \
  "$work/cur/CONTRIBUTING.md" '维护公约' '缺维护公约'
score_reason "M30-e B9 缺平台对等公约" \
  "sed -i.bak 's/平台对等/平台对齐/g' '$work/cur/CONTRIBUTING.md'" \
  "$work/cur/CONTRIBUTING.md" '平台对等' '缺平台对等公约'
score_reason "M30-f B9 缺 PR 门槛清单" \
  "sed -i.bak -e 's/提交前检查清单/清单甲/' -e 's/提 PR 的门槛/门槛乙/' '$work/cur/CONTRIBUTING.md'" \
  "$work/cur/CONTRIBUTING.md" '提交前检查清单' '缺 PR 门槛清单'
score_reason "M30-g B9 决策表无废弃态标记" \
  "sed -i.bak -E -e 's/已被[^|]*反驳/标记甲/g' -e 's/⚠废弃/标记乙/g' -e 's/作废/标记丙/g' \"$R/standard.md\"" \
  "$R/standard.md" '⚠废弃' '无废弃态标记机制'
MUT_GONE=0
score_reason "M30-h B13 缺 thresholdRatio 阈值" \
  "sed -i.bak 's/thresholdRatio: 0.6/thresholdRatio: 0.9/' '$work/cur/agent.cordis.yml'" \
  "$work/cur/agent.cordis.yml" 'thresholdRatio: 0.9' '缺 thresholdRatio'
MUT_GONE=0
score_reason "M30-i B13 约束强度词丢失" \
  "sed -i.bak -E 's/MUST|绝不|禁止/约束词/g' \"$S\"" \
  "$S" '约束词' '约束强度词丢失'
MUT_GONE=0
score_reason "M30-j B14 工作区未跟踪项" \
  "printf '#!/bin/sh\\n' > '$work/cur/plans/zzz-probe.sh'" \
  "$work/cur/plans/zzz-probe.sh" '#!/bin/sh' '未跟踪项'
MUT_GONE=1
score_reason "M30-k B15 learned-skills 缺版本列" \
  "sed -i.bak -E 's/版本|version/VER/g' \"$R/learned-skills.md\"" \
  "$R/learned-skills.md" '版本|version' 'learned-skills 缺版本列'
score_reason "M30-l B15 缺 skill 升级/废弃机制" \
  "sed -i.bak -E 's/升级|废弃/变更/g' \"$R/skill-governance.md\"" \
  "$R/skill-governance.md" '升级|废弃' 'skill 升级/废弃机制'
score_reason "M30-m B15 SKILL 未说明知识库布局" \
  "sed -i.bak 's/knowledge/KB/g' \"$S\"" \
  "$S" 'knowledge' 'SKILL 未说明知识库布局'
score_reason "M30-n B15 无决策登记路径" \
  "sed -i.bak -E 's/D0[0-9][0-9]/DX/g' \"$R/standard.md\"" \
  "$R/standard.md" 'D0[0-9][0-9]' '无决策登记路径'
echo "[M31 阶段引用可解析（doc-consistency 第 15 类，双向）]"
fresh
E6="⑥"   # ⑥（避免在自检内写死易混淆字符，运行时构造）
python3 - "$work/cur" <<'PYEOF'
import glob, os, re, sys
cur = sys.argv[1]
mark = chr(0x2465)                      # ⑥
refs = ['skills/dsh-codepunk-workflow/SKILL.md', 'README.md', 'preset.yml'] + [
    f for f in glob.glob(os.path.join(cur, 'skills/dsh-codepunk-workflow/references/*.md'))
    if not f.endswith('stages.md')]
hits = 0
for rel in refs:
    p = rel if os.path.isabs(rel) else os.path.join(cur, rel)
    if not os.path.isfile(p):
        continue
    t = open(p, encoding='utf-8').read()
    if mark in t:
        open(p, 'w', encoding='utf-8').write(t.replace(mark, '六'))
        hits += 1
print('stripped', hits, 'files')
PYEOF
mutate_gone "抹掉 ⑥ 外部引用（造孤立阶段）" "$work/cur/README.md" "⑥"
check_rc "M31-a 孤立阶段 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "孤立阶段"
fresh
python3 - "$work/cur/skills/dsh-codepunk-workflow/references/stages.md" <<'PYEOF'
import sys
p = sys.argv[1]
mark = chr(0x2465)
t = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(t.replace('## ' + mark, '## 六'))
PYEOF
mutate_gone "删 ⑥ 的定义标题" "$work/cur/skills/dsh-codepunk-workflow/references/stages.md" "^## ⑥"
check_rc "M31-b 悬空引用 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "悬空引用"
echo "[M32 自检期望串特异性（doc-consistency 第 16 类存活）]"
fresh
python3 - "$work/cur/plans/checker-self-test.sh" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
# 把 M17 的特异性期望改回与小节标题同名（模拟「仅凭标题即通过」的脆弱断言）
open(p, 'w', encoding='utf-8').write(s.replace('1 "未来日期: "', '1 "未来日期"', 1))
PYEOF
mutate "断言期望串回退为标题同名" "$work/cur/plans/checker-self-test.sh" '1 "未来日期"'
check_rc "M32 期望串与标题同名 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "自检期望串特异性不足"
echo "[M33 移植对等性（doc-consistency 第 17 类存活）]"
fresh
sed -i.bak 's/xox\[baprs\]-/xoo-[baprs]-/' "$work/cur/plans/windows/dsh-codepunk-leak-guard.ps1"
mutate_gone "抹掉 ps1 侧通用模式签名 xox" "$work/cur/plans/windows/dsh-codepunk-leak-guard.ps1" 'xox\[baprs\]-'
check_rc "M33 移植对等性缺口 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "移植对等性缺口"
echo "[M34 通用模式命中不得回显原文（F141 回归）]"
fresh
# 凭据形态在运行时拼接：自检文件与夹具都不得含字面量（否则本仓守卫会命中夹具自身）
python3 - "$work/leak-token.txt" <<'PYEOF'
import sys
tok = 'sk-' + 'A' * 28
open(sys.argv[1], 'w', encoding='utf-8').write('leaked ' + tok + ' end\n')
PYEOF
check_rc "M34-a 通用命中 → 阻断" \
  "HOME='$SANDBOX' bash plans/dsh-codepunk-leak-guard.sh --msg '$work/leak-token.txt' 2>&1" 1 "[通用]"
check_no_match "M34-b 输出不得回显凭据原文" \
  "HOME='$SANDBOX' bash plans/dsh-codepunk-leak-guard.sh --msg '$work/leak-token.txt' 2>&1" \
  "AAAAAAAAAAAAAAAAAAAAAAAAAAAA"
echo "[M35 pwsh 钩子参数语法（doc-consistency 第 18 类存活）]"
fresh
printf 'pwsh -NoProfile -File x.ps1 -Msg "$1"\n' >> "$work/cur/plans/windows/dsh-codepunk-leak-guard.ps1"
mutate "注入 PS 不支持的位置参数语法" "$work/cur/plans/windows/dsh-codepunk-leak-guard.ps1" '\$1'
check_rc "M35 PS 位置参数语法 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "位置参数语法"
echo "[M36 硬规则覆盖自推导（F143 回归：R15 亦须受检）]"
MUT_GONE=1
score_reason "M36 删 R15 → 扣分（旧版覆盖不到）" \
  "sed -i.bak '/^| R15 |/d' '$work/cur/skills/dsh-codepunk-workflow/SKILL.md'" \
  "$work/cur/skills/dsh-codepunk-workflow/SKILL.md" '^\| R15 \|' '缺硬规则 R15'
MUT_GONE=0
echo "[M37 硬规则命名空间洁净（doc-consistency 第 19 类存活）]"
fresh
printf '\n> 轮次引用误写为 R999 形式\n' >> "$work/cur/skills/dsh-codepunk-workflow/references/skill-governance.md"
mutate "注入 R### 同形引用" "$work/cur/skills/dsh-codepunk-workflow/references/skill-governance.md" 'R999'
check_rc "M37 R### 同形引用 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "与硬规则同形"
echo "[M38 退出码契约实测（doc-consistency 第 20 类存活）]"
fresh
python3 - "$work/cur/plans/ps-validate.mjs" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s.replace('process.exit(missing ? 2 : (failed ? 1 : 0));',
                                               'process.exit(failed ? 1 : 0);'))
PYEOF
mutate_gone "缺文件分支退回 rc 1" "$work/cur/plans/ps-validate.mjs" "missing \? 2"
# F180：只用「不得假通过」这一性质断言 —— 真 HOME（探针可核验→报漂移）与缺依赖环境
#   （探针无法核验→报环境缺口）下**都成立**；原「要求 rc=1」写法在缺依赖环境会误判。
check_no_match "M38 变异后不得声称「15 条探针」全通过（F180 假通过防护）" "bash plans/doc-consistency.sh 2>&1" "15 条探针"
echo "[M39 跨文件阈值唯一性（doc-consistency 第 7 类扩展存活）]"
fresh
python3 - "$work/cur/plans/preset-score.sh" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s.replace('32768', '32769'))
PYEOF
mutate "体积预算改为 32769" "$work/cur/plans/preset-score.sh" '32769'
check_rc "M39 阈值不一致 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "SKILL 体积上限"
echo "[M40 岗位数一致性（doc-consistency 第 21 类存活）]"
fresh
printf '\n> 现行：13 岗位已全 continuable。\n' >> "$work/cur/skills/dsh-codepunk-workflow/references/model-routing.md"
mutate "注入无标记的 13 岗位现在时声称" "$work/cur/skills/dsh-codepunk-workflow/references/model-routing.md" '13 岗位已全'
check_rc "M40 岗位数过度声称 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "岗位数声称问题"
echo "[M41 矩阵覆盖（doc-consistency 第 22 类存活）]"
fresh
sed -i.bak 's/第 21 类/第 二一类/' "$work/cur/skills/dsh-codepunk-workflow/references/skill-governance.md"
mutate_gone "抹掉矩阵中的类 21 登记" "$work/cur/skills/dsh-codepunk-workflow/references/skill-governance.md" '第 21 类'
check_rc "M41 矩阵缺登记 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "矩阵缺登记"
echo "[M42 简报检索日（doc-consistency 第 23 类存活）]"
fresh
sed -i.bak '/^> retrieved_at/d' "$work/cur/skills/dsh-codepunk-workflow/benchmarks/diagram-design-analysis.md"
mutate_gone "抹掉简报 retrieved_at" "$work/cur/skills/dsh-codepunk-workflow/benchmarks/diagram-design-analysis.md" '^> retrieved_at'
check_rc "M42 简报缺检索日 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "简报缺检索日"
echo "[M43 运行型脚本须声明退出码（doc-consistency 第 5 类扩展存活）]"
fresh
python3 - "$work/cur/plans/verify-worktree.sh" <<'PYEOF'
import sys
p = sys.argv[1]
lines = open(p, encoding='utf-8').read().split('\n')
out = [l for l in lines if not l.startswith('# 退出码')]
open(p, 'w', encoding='utf-8').write('\n'.join(out))
PYEOF
mutate_gone "抹掉 verify-worktree 的退出码声明" "$work/cur/plans/verify-worktree.sh" '^# 退出码'
check_rc "M43 运行型脚本缺声明 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "缺退出码声明"
echo "[M44 功能开关对等（doc-consistency 第 17 类扩展存活）]"
fresh
python3 - "$work/cur/plans/windows/dsh-codepunk-leak-guard.ps1" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = s.replace("[Alias('h')][switch]$Help,", '', 1).replace("[switch]$Help,", '', 1)
open(p, 'w', encoding='utf-8').write(s)
PYEOF
mutate_gone "抹掉 leak-guard.ps1 的 Help 开关" "$work/cur/plans/windows/dsh-codepunk-leak-guard.ps1" '[switch]$Help'
check_rc "M44 开关不对等 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "移植对等性缺口"
echo "[M45 电池项数计数声称（doc-consistency 第 1 类 F162 修复存活）]"
fresh
sed -i.bak 's/14 项独立验证/99 项独立验证/' "$work/cur/README.md"
check_rc "M45 电池项数声称漂移 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "电池项数 声称不一致"
echo "[M46 references 计数标签绑定（doc-consistency 第 1 类 F163 修复存活）]"
fresh
sed -i.bak -E "/^  references\//s/[0-9]+ 篇/99 篇/" "$work/cur/README.md"
mutate "README references 篇数声称改为 99（按标签行派生）" "$work/cur/README.md" '99 篇'
check_rc "M46 references 篇数声称漂移 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "references 实际"
echo "[M47 多值声称一致（doc-consistency 第 1 类 F164 修复存活）]"
fresh
python3 - "$work/cur/README.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
i = s.find('15 指标')
j = s.find('15 指标', i + 1)
if j > 0:
    s = s[:j] + '77 指标' + s[j + len('15 指标'):]
open(p, 'w', encoding='utf-8').write(s)
PYEOF
check_rc "M47 同一声称多值漂移 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "评分指标 声称不一致"
echo "[M48 退出码集合对等（doc-consistency 第 17 类 F165 修复存活）]"
fresh
sed -i.bak 's/exit 2/exit 1/' "$work/cur/plans/windows/dsh-codepunk-init.ps1"
check_rc "M48 ps1 缺退出码 2 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "缺退出码 2"
echo "[M49 用法须列出 param 开关（doc-consistency 第 17 类 F166 修复存活）]"
fresh
python3 - "$work/cur/plans/windows/dsh-codepunk-leak-guard.ps1" <<'PYEOF'
import sys
p = sys.argv[1]
lines = open(p, encoding='utf-8').read().split('\n')
out = [l for l in lines if '显式指定扫索引' not in l]
open(p, 'w', encoding='utf-8').write('\n'.join(out))
PYEOF
mutate_gone "抹掉用法中的 -Staged 说明行" "$work/cur/plans/windows/dsh-codepunk-leak-guard.ps1" '显式指定扫索引'
check_rc "M49 用法未列开关 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "用法未列 -Staged"
echo "[M50 init 骨架形态可校验（F169：生成器≠校验器的修复存活）]"
fresh
mkdir -p "$work/linkhome/.dsh-codepunk"
printf 'schema_version: 1\nprojects: []\nlast_updated: null\n' > "$work/linkhome/.dsh-codepunk/INDEX.yaml"
check_rc "M50 空列表骨架 → 通过（修复后）" "HOME='$work/linkhome' bash plans/dsh-codepunk-link.sh index 2>&1" 0 "校验通过"
python3 - "$work/cur/plans/dsh-codepunk-link.sh" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = s.replace("proj.nil? || proj.is_a?(Hash) || proj.is_a?(Array)", "proj.nil? || proj.is_a?(Hash)", 1)
s = s.replace('(typeof d.projects!=="object"||d.projects===null)',
              '(typeof d.projects!=="object"||Array.isArray(d.projects)||d.projects===null)', 1)
open(p, 'w', encoding='utf-8').write(s)
PYEOF
mutate_gone "退回 F169 修复（重新拒绝条目序列）" "$work/cur/plans/dsh-codepunk-link.sh" 'proj.is_a?(Array)'
check_rc "M50 退回修复后 → 空列表骨架被拒" "HOME='$work/linkhome' bash plans/dsh-codepunk-link.sh index 2>&1" 1 "须为映射"
echo "[M51 声明包装字段漂移（F170：check 增比包装的修复存活）]"
fresh
if [ -z "${DSH_APP_ROOT:-}" ] || [ ! -d "${DSH_APP_ROOT:-/nonexistent}" ]; then
  # F259：此处原调用**未定义助手** `pass`（实测 stderr: `line 1005: pass: command not found`）⇒
  #   与本脚本 F191 守卫所针对的「调用不存在助手」属同类缺陷（该守卫仅扫描 `check*` 调用点，漏掉此处）。
  #   按本套件既有跳过口径改用 printf（同 M14 的 `  ℹ … 跳过（…）` 风格）。
  printf '  ℹ M51 跳过（未设 DSH_APP_ROOT，无法做语义比对；属环境受限）\n'
else
  : > "$work/patch51.yml"
  node plans/preset-declare.mjs apply --patch "$work/patch51.yml" --append >/dev/null 2>&1 || true
  python3 - "$work/patch51.yml" "$work/patch51t.yml" <<'PYEOF'
import sys
s, d = sys.argv[1], sys.argv[2]
t = open(s, encoding='utf-8').read()
open(d, 'w', encoding='utf-8').write(t.replace("'@deepseek-ai/dsh-agent-preset'", "'@deepseek-ai/dsh-agent-preset-x'", 1))
PYEOF
  mutate "篡改包装顶层 name" "$work/patch51t.yml" '@deepseek-ai/dsh-agent-preset-x'
  check_rc "M51 包装 name 漂移 → check 报漂移" "node plans/preset-declare.mjs check --patch '$work/patch51t.yml' 2>&1" 1 "声明包装漂移"
fi
echo "[M138 声明包装 config.order 漂移（F325：check 增比 order 的修复存活）]"
fresh
if [ -z "${DSH_APP_ROOT:-}" ] || [ ! -d "${DSH_APP_ROOT:-/nonexistent}" ]; then
  printf '  ℹ M138 跳过（未设 DSH_APP_ROOT，无法做语义比对；属环境受限）\n'
else
  : > "$work/patch138.yml"
  node plans/preset-declare.mjs apply --patch "$work/patch138.yml" --append >/dev/null 2>&1 || true
  python3 - "$work/patch138.yml" "$work/patch138t.yml" <<'PYEOF'
import sys
s, d = sys.argv[1], sys.argv[2]
t = open(s, encoding='utf-8').read()
open(d, 'w', encoding='utf-8').write(t.replace('        order: 5', '        order: 9', 1))
PYEOF
  mutate "篡改包装 config.order" "$work/patch138t.yml" 'order: 9'
  check_rc "M138 包装 order 漂移 → check 报漂移" "node plans/preset-declare.mjs check --patch '$work/patch138t.yml' 2>&1" 1 "config.order"
fi
echo "[M139 包装块内注释不得误报缺失（F326：固定 8 行窗口假红）]"
fresh
if [ -z "${DSH_APP_ROOT:-}" ] || [ ! -d "${DSH_APP_ROOT:-/nonexistent}" ]; then
  printf '  ℹ M139 跳过（未设 DSH_APP_ROOT，无法做语义比对；属环境受限）\n'
else
  : > "$work/patch139.yml"
  node plans/preset-declare.mjs apply --patch "$work/patch139.yml" --append >/dev/null 2>&1 || true
  python3 - "$work/patch139.yml" "$work/patch139c.yml" <<'PYEOF'
import sys
s, d = sys.argv[1], sys.argv[2]
L = open(s, encoding='utf-8').read().split('\n')
i = next(k for k, l in enumerate(L) if l.strip() == 'config:')
ind = L[i][:len(L[i]) - len(L[i].lstrip())]
L[i + 1:i + 1] = [ind + '# 块内注释（语义不变）', ind + '# 第二行', ind + '# 第三行', ind + '# 第四行']
open(d, 'w', encoding='utf-8').write('\n'.join(L))
PYEOF
  mutate "包装块内插入注释行" "$work/patch139c.yml" '块内注释（语义不变）'
  check_rc "M139 块内注释 → 不得误报 config.order 缺失" "node plans/preset-declare.mjs check --patch '$work/patch139c.yml' 2>&1" 0 "语义一致"
fi
echo "[M140 docs/ 内引用不存在的 plans 脚本（F327：工具存在性域扩展的修复存活）]"
fresh
printf '\n见 `plans/no-such-script.sh`。\n' >> "$work/cur/docs/faq.md"
mutate "docs 内引用不存在的 plans 脚本" "$work/cur/docs/faq.md" 'plans/no-such-script.sh'
check_rc "M140 docs 内死引用 → 第 4 类报缺脚本" "bash plans/doc-consistency.sh 2>&1" 1 "文档提到但不存在的脚本"
echo "[M141 allow 名单连字符工具名不得静默漏检（F329：提取字符类收窄致假通过）]"
fresh
if [ -z "${DSH_APP_ROOT:-}" ] || [ ! -d "${DSH_APP_ROOT:-/nonexistent}" ]; then
  printf '  ℹ M141 跳过（未设 DSH_APP_ROOT，无法核验安装真实性；属环境受限）\n'
else
  cat > "$work/inject141.py" <<'PYEOF'
import io, sys
p, name = sys.argv[1], sys.argv[2]
L = io.open(p, encoding='utf-8').read().split('\n')
ai = next(i for i, l in enumerate(L) if '&role-allow' in l)
ii = next(i for i, l in enumerate(L) if 'allow:' in l and '!!js' in l and i != ai)
def add(line):
    s = line.rstrip(); tail = ''
    if s.endswith('"'):
        s, tail = s[:-1].rstrip(), '"'
    core = s[:-1].rstrip()
    core = core + (',' if core.endswith(("'", '"')) else '')
    return core + "'%s']" % name + tail
L[ai], L[ii] = add(L[ai]), add(L[ii])
io.open(p, 'w', encoding='utf-8').write('\n'.join(L))
PYEOF
  python3 "$work/inject141.py" "$work/cur/agent.cordis.yml" 'no-such-tool-zz'
  mutate "锚点与内联同时注入不存在的连字符工具名" "$work/cur/agent.cordis.yml" 'no-such-tool-zz'
  check_rc "M141 连字符未知名 → compat 检查 4 报无注册来源" \
    "DSH_APP_ROOT=\"$DSH_APP_ROOT\" python3 plans/preset-compat.py . 2>&1" 1 "无注册来源"
fi
echo "[M52 accepted_by 流式数组（F171 修复存活）]"
fresh
mkdir -p "$work/acc"
printf 'task_id: task-a\naccepted_by: [squad-lead]\naccepted_at: 2026-10-06\n' > "$work/acc/flow.yaml"
check_rc "M52 流式数组 + 独立签收 → 通过" "bash plans/acceptance-verify.sh '$work/acc/flow.yaml' task-b 2>&1" 0 "verdict=PASS"
python3 - "$work/cur/plans/acceptance-verify.sh" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
old = "scalar_form = re.search(r'^accepted_by:[ " + chr(92) + "t]*(?!" + chr(92) + chr(91) + ")" + chr(92) + "S', src, re.M)"
new = "scalar_form = re.search(r'^accepted_by:[ " + chr(92) + "t]*" + chr(92) + "S', src, re.M)"
assert old in s, "锚点未找到"
open(p, "w", encoding="utf-8").write(s.replace(old, new, 1))
PYEOF
mutate_gone "退回 F171（流式数组不再豁免）" "$work/cur/plans/acceptance-verify.sh" "(\?!' || true"
check_rc "M52 退回修复后 → 流式数组被误判为标量" "bash plans/acceptance-verify.sh '$work/acc/flow.yaml' task-b 2>&1" 1 "标量"
echo "[M53 品牌卫生健康场景不误判（F172：grep -c 两行 的修复存活）]"
fresh
check_rc "M53 健康场景 → A5 判为「零旧名」" "OLD_NAME=NoSuchBrandZzz999 bash plans/preset-audit.sh 2>&1" 1 "A5 零旧名"
python3 - "$work/cur/plans/preset-audit.sh" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = 'agent.cordis.yml 2>/dev/null || true'
new = 'agent.cordis.yml 2>/dev/null || echo 0'
if old not in s:
    print('ANCHOR-MISSING')
else:
    open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
    print('MUTATED')
PYEOF
mutate "退回 F172（恢复 || echo 0）" "$work/cur/plans/preset-audit.sh" 'echo 0'
check_no_match "M53 退回修复后 → 健康场景不再判「零旧名」" "OLD_NAME=NoSuchBrandZzz999 bash plans/preset-audit.sh 2>&1" "A5 零旧名"

echo
if [ "$MUTFAIL" != 0 ]; then echo "✗ 自检失败：有变异未生效（自检脚本问题）" >&2; exit 2; fi
echo "[M81 BSD 专有 sed -i '' 须被扣分（F186 另半存活）]"
fresh
python3 - "$work/cur/plans/preset-audit.sh" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s + "\nsed -i '' 's/a/b/' f.txt\n")
print('MUTATED')
PYEOF
check_rc "M81 注入 sed -i '' → B10 报 BSD 专有未兜底" "bash plans/preset-score.sh 2>&1" 1 "sed -i"

echo "[M80 macOS 专用 stat -f%z 须被扣分（F186 修复存活）]"
fresh
python3 - "$work/cur/plans/preset-audit.sh" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s + '\nSZ=$(stat -f%z "$0")\n')
print('MUTATED')
PYEOF
check_rc "M80 注入 stat -f%z → B10 报 BSD 专有未兜底" "bash plans/preset-score.sh 2>&1" 1 "stat -f%z"

echo "[M79 A1 跳过分支不得报 PASS（F184 修复存活）]"
fresh
check_contains "M79 A1 无 ruby/node 时须报 FAIL（无法核验≠通过）" "grep -n 'A1 ' plans/preset-audit.sh" 'report "$FAIL" "A1 无法核验'

echo "[M78 class 17 对数不得硬编码（F183 修复存活）]"
fresh
# 精确断言：结论行必须由派生变量构造（而非写死数字）；不可用「全文不得出现某数字」——
#   那会误伤文档说明（我首版即如此，被自检如实拦下）。
check_contains "M78 class 17 结论行的对数由派生变量构造" "grep -n 关键守卫关键词 plans/doc-consistency.sh" "PAIRS_CN"

echo "[M77 battery 自检项不得硬编码变异数（F182 修复存活）]"
fresh
check_no_match "M77 battery 不得再出现硬编码「6 项变异」" "grep -n 存活自检 plans/verify-battery.sh" "6 项变异"

echo "[M76 无校验器时语法行不得计入 ps1（F181 修复存活）]"
fresh
# F181：必须带 `DSH_CODEPUNK_SKIP_SELFTEST=1`（仓库既有递归防护）——否则本变异会在 battery
#   内再跑自检、自检又跑本变异 → 递归（首版即因此超时，属我的设计错误）。
check_no_match "M76 无校验器时语法行不得声明 ps1 已通过（F181 修复存活）" "DSH_CODEPUNK_SKIP_SELFTEST=1 PWSH_VALIDATOR=/nonexistent/none.mjs bash plans/verify-battery.sh 2>&1" ".ps1）通过"

echo "[M75 ps1 工作树行尾非 CRLF（doc-consistency class17 子项存活）]"
fresh
python3 - "$work/cur/plans/windows/dsh-codepunk-link.ps1" <<'PYEOF'
import sys
p = sys.argv[1]
b = open(p, 'rb').read()
open(p, 'wb').write(b.replace(b'\r\n', b'\n'))
print('MUTATED')
PYEOF
check_rc "M75 ps1 被改为 LF → 报行尾非 CRLF" "bash plans/doc-consistency.sh 2>&1" 1 "行尾非 CRLF"

echo "[M73 score B14 未跟踪杂散（存活）]"
fresh
python3 - "$work/cur/plans/zz-m73-stray.sh" <<'PYEOF'
import sys
open(sys.argv[1], 'w', encoding='utf-8').write('stray\n')
print('MUTATED')
PYEOF
check_rc "M73 造未跟踪文件 → B14 报杂散" "bash plans/preset-score.sh 2>&1" 1 "未跟踪项"

echo "[M74 score B14 plans↔总库不同步（存活，假 HOME）]"
fresh
python3 - "$work/fakehome" <<'PYEOF'
import os, shutil, sys
fh = sys.argv[1]
dst = os.path.join(fh, '.dsh-codepunk', 'scripts')
os.makedirs(dst, exist_ok=True)
src = 'plans'
for f in os.listdir(src):
    if f.endswith('.sh'):
        shutil.copy(os.path.join(src, f), os.path.join(dst, f))
# 制造不同步：改动副本内总库中的一个脚本
p = os.path.join(dst, 'preset-audit.sh')
s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s + '\n# stale\n')
print('MUTATED')
PYEOF
check_rc "M74 总库脚本过期 → B14 报不同步" "HOME='$work/fakehome' bash plans/preset-score.sh 2>&1" 1 "不同步"

echo "[M71 score A4 决策号重复（存活）]"
fresh
python3 - "$work/cur/skills/dsh-codepunk-workflow/references/standard.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
dup = [l for l in s.split('\n') if l.startswith('| D075 ')]
open(p, 'w', encoding='utf-8').write(s + '\n' + (dup[0] if dup else '| D075 | 重复注入 |') + '\n')
print('MUTATED')
PYEOF
check_rc "M71 复制 D075 行 → A4 报决策号重复" "bash plans/preset-score.sh 2>&1" 1 "决策号重复"

echo "[M72 score B6 术语单侧（存活）]"
fresh
python3 - "$work/cur/skills/dsh-codepunk-workflow/SKILL.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
n = s.count('run-lead')
open(p, 'w', encoding='utf-8').write(s.replace('run-lead', 'lead'))
print('MUTATED' if n else 'ANCHOR-MISSING')
PYEOF
check_rc "M72 SKILL 去掉 run-lead 术语 → B6 报单侧使用" "bash plans/preset-score.sh 2>&1" 1 "run-lead"

echo "[M68 score A2 占位残留（存活）]"
fresh
python3 - "$work/cur/skills/dsh-codepunk-workflow/references/roles.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s + '\n待补：本条说明尚未撰写。\n')
print('MUTATED')
PYEOF
check_rc "M68 注入占位残留 → A2 报占位" "bash plans/preset-score.sh 2>&1" 1 "占位残留"

echo "[M69 score B11 凭据形态（存活，载荷运行时拼接）]"
fresh
python3 - "$work/cur/skills/dsh-codepunk-workflow/references/knowledge.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
tok = 'gh' + 'p_' + ('A' * 24)
open(p, 'w', encoding='utf-8').write(s + '\n示例：' + tok + '\n')
print('MUTATED')
PYEOF
check_rc "M69 注入凭据形态 → B11 报凭据命中" "bash plans/preset-score.sh 2>&1" 1 "凭据形态命中"

echo "[M70 score B13 硬规则缺号（存活；保持最大号 R15 不变）]"
fresh
python3 - "$work/cur/skills/dsh-codepunk-workflow/SKILL.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = '| R7 |'
if old not in s:
    print('ANCHOR-MISSING')
else:
    open(p, 'w', encoding='utf-8').write(s.replace(old, '| R07 |', 1))
    print('MUTATED')
PYEOF
check_rc "M70 R7 编号被改 → B13 报缺硬规则 R7" "bash plans/preset-score.sh 2>&1" 1 "SKILL 缺硬规则 R7"

echo "[M65 score B8 bash 语法错误（存活）]"
fresh
python3 - "$work/cur/plans/preset-audit.sh" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s + '\nif [ 1 -eq 1 ]; then echo broken\n')
print('MUTATED')
PYEOF
check_rc "M65 注入未闭合 if → B8 报 bash -n 失败" "bash plans/preset-score.sh 2>&1" 1 "bash -n 失败"

echo "[M66 score B9 缺维护公约（存活）]"
fresh
python3 - "$work/cur/README.md" "$work/cur/CONTRIBUTING.md" <<'PYEOF'
import sys
for p in sys.argv[1:]:
    try:
        s = open(p, encoding='utf-8').read()
    except FileNotFoundError:
        continue
    open(p, 'w', encoding='utf-8').write(s.replace('维护公约', '维护约定'))
print('MUTATED')
PYEOF
check_rc "M66 移除「维护公约」→ B9 报缺维护公约" "bash plans/preset-score.sh 2>&1" 1 "维护公约"

echo "[M67 score B10 缺 .gitattributes（存活）]"
fresh
python3 - "$work/cur/.gitattributes" <<'PYEOF'
import os, sys
os.remove(sys.argv[1])
print('MUTATED')
PYEOF
check_rc "M67 删 .gitattributes → B10 报缺换行策略" "bash plans/preset-score.sh 2>&1" 1 "缺 .gitattributes"

echo "[M62 score B7 缺 references 文件（存活）]"
fresh
python3 - "$work/cur/skills/dsh-codepunk-workflow/references/roles.md" <<'PYEOF'
import os, sys
p = sys.argv[1]
os.remove(p)
print('MUTATED')
PYEOF
check_rc "M62 删 roles.md → B7 报缺文件" "bash plans/preset-score.sh 2>&1" 1 "缺 references/roles.md"

echo "[M63 score B12 README 缺必备节（存活）]"
fresh
python3 - "$work/cur/README.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = '## 定位'
if old not in s:
    print('ANCHOR-MISSING')
else:
    open(p, 'w', encoding='utf-8').write(s.replace(old, '## 概览', 1))
    print('MUTATED')
PYEOF
check_rc "M63 README 缺「定位」节 → B12 报缺节" "bash plans/preset-score.sh 2>&1" 1 "README 缺节"

echo "[M64 score B15 learned-skills 缺版本列（存活）]"
fresh
python3 - "$work/cur/skills/dsh-codepunk-workflow/references/learned-skills.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s2 = s.replace('版本', '版次').replace('version', 'ver')
open(p, 'w', encoding='utf-8').write(s2)
print('MUTATED' if s2 != s else 'ANCHOR-MISSING')
PYEOF
check_rc "M64 learned-skills 无版本列 → B15 报缺版本列" "bash plans/preset-score.sh 2>&1" 1 "learned-skills 缺版本列"

echo "[M59 品牌旧名残留（preset-audit B5 存活，需 OLD_NAME 门控）]"
fresh
python3 - "$work/cur/README.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s + '\nZZProbeName\n')
print('MUTATED')
PYEOF
check_rc "M59 注入旧名 → B5 报旧名残留" "OLD_NAME=ZZProbeName bash plans/preset-audit.sh 2>&1" 1 "旧名残留"

echo "[M60 str_replace 残留（preset-audit A3 存活）]"
fresh
python3 - "$work/cur/agent.cordis.yml" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s + '\n# str_replace 残留注入\n')
print('MUTATED')
PYEOF
check_rc "M60 注入 str_replace → A3 报残留" "bash plans/preset-audit.sh 2>&1" 1 "A3 str_replace"

echo "[M61 YAML 解析失败（preset-audit A1 存活）]"
fresh
python3 - "$work/cur/agent.cordis.yml" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s + '\nbad_unclosed: [1, 2\n')
print('MUTATED')
PYEOF
check_rc "M61 破坏 YAML → A1 报解析失败" "bash plans/preset-audit.sh 2>&1" 1 "A1 YAML 解析失败"

echo "[M57 SKILL 体积超限（preset-audit B1 存活）]"
fresh
python3 - "$work/cur/skills/dsh-codepunk-workflow/SKILL.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
open(p, 'w', encoding='utf-8').write(s + ('\n<!-- pad -->' * 900) + '\n')
print('MUTATED')
PYEOF
check_rc "M57 SKILL 超 32768B → B1 报超限" "bash plans/preset-audit.sh 2>&1" 1 "B1 SKILL"

echo "[M58 README 节数不足（preset-audit E2 存活）]"
fresh
python3 - "$work/cur/README.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
lines = s.split('\n')
kept, n = [], 0
for l in lines:
    if l.startswith('## '):
        n += 1
        if n > 4:
            l = '# ' + l[3:]
    kept.append(l)
open(p, 'w', encoding='utf-8').write('\n'.join(kept))
print('MUTATED')
PYEOF
check_rc "M58 README 仅 4 节 → E2 报 <7" "bash plans/preset-audit.sh 2>&1" 1 "E2 README"

echo "[M55 阶段口径不一致（doc-consistency 第 2 类存活）]"
fresh
python3 - "$work/cur/skills/dsh-codepunk-workflow/references/stages.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = '## \u2465'
if old not in s:
    print('ANCHOR-MISSING')
else:
    open(p, 'w', encoding='utf-8').write(s.replace(old, '## \u516d', 1))
    print('MUTATED')
PYEOF
check_rc "M55 阶段号被改 → 第 2 类报口径不一" "bash plans/doc-consistency.sh 2>&1" 1 "阶段口径不一"

echo "[M56 文档提到不存在的脚本（doc-consistency 第 4 类存活）]"
fresh
python3 - "$work/cur/README.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
s = s.replace('## 目录结构', '## 目录结构\n\n`plans/nonexistent-m56.sh`\n', 1) if '## 目录结构' in s else s + '\n`plans/nonexistent-m56.sh`\n'
open(p, 'w', encoding='utf-8').write(s)
print('MUTATED')
PYEOF
check_rc "M56 引用不存在的 plans 脚本 → 第 4 类报缺脚本" "bash plans/doc-consistency.sh 2>&1" 1 "不存在"

echo "[M54 编号引用可解析（doc-consistency 第 9 类存活）]"
fresh
python3 - "$work/cur/skills/dsh-codepunk-workflow/benchmarks/anti-hallucination.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = '支撑决策号：'
if old not in s:
    print('ANCHOR-MISSING')
else:
    open(p, 'w', encoding='utf-8').write(s.replace(old, old + 'D045 ', 1))
    print('MUTATED')
PYEOF
# 说明：本条只设**前向**断言——反向（退回修复后不报）在非 ASCII 串上做锚点移除不可靠，
#   且「D 未登记」字样由第 9 类产出，脆弱反向断言会误判（同类先例：M26 只做存活断言）。
check_rc "M54 注入未登记决策号 → 第 9 类报错" "bash plans/doc-consistency.sh 2>&1" 1 "D 未登记"

# F191：覆盖自检——**所有** `check*` 调用点必须使用**已定义**的断言助手。
#   起因：M78/M79 曾引用不存在的 `check_contains` → 断言静默空转（`command not found`）而自检仍报「通过」。
#   备选设计（「调用点数 vs 实际执行数」）经对照实验**否决**：本 harness 内含循环调用，`ASSERT_N` 恒 ≥ 调用点数
#   （健康仓库亦然）→ 该判据在此处**永不成立**。故改判「调用名是否属于已定义的助手集合」——直接且可证伪。
UNKNOWN_HELPERS=$(grep -oE '^[[:space:]]*check[a-z_]*' "$0" 2>/dev/null | tr -d ' ' | sort -u \
                  | grep -vxE 'check|check_rc|check_no_match|check_contains' || true)
if [ -n "$UNKNOWN_HELPERS" ]; then
  echo "✗ 自检引用了未定义的断言助手：$(printf '%s' "$UNKNOWN_HELPERS" | tr '\n' ' ')（变异会静默空转）" >&2
  exit 1
fi
echo "[M127 硬规则号重复须扣分（F263：R 号重复覆盖缺口）]"
# F264：本变异的**首版**用了**相对路径**（`>> skills/…`）⇒ `score_reason` 的 `eval "$mut"` 不以沙箱为 cwd，
#   后果有二：① 变异写进**真仓库**的 SKILL.md（污染：`\| R9 \|` 计 2、`git status` 现 ` M`）；
#   ② 沙箱内无变异 ⇒ 断言 rc=0 ⇒ M127 恒失败（整轮 rc=1）。既有变异一律用 `'$work/cur/…'`（见 M28-e/M125）。
score_reason "M127 SKILL 追加重复 R9 行" \
  "printf '| R9 | 探针：重复 R 号（含义不同） | 探针 |\n' >> '$work/cur/skills/dsh-codepunk-workflow/SKILL.md'" \
  "$work/cur/skills/dsh-codepunk-workflow/SKILL.md" '^\| R9 ' '硬规则号重复'

echo "[M128 伪造同构根不得判「兼容」（F267：安装真实性判据）]"
fresh
mkdir -p "$work/cur/node_modules/@deepseek-ai/fake-pkg/lib" && printf 'export const x = 1;\n' > "$work/cur/node_modules/@deepseek-ai/fake-pkg/lib/index.js"
check_rc "M128 伪造根（无 dsh 产品标记）→ compat rc 2 且报「无法核验安装真实性」" \
  "DSH_APP_ROOT=\"$work/cur\" python3 plans/preset-compat.py ." 2 "无法核验安装真实性"

echo "[M130 Markdown 表格列数一致（doc-consistency 第 24 类存活）]"
fresh
# 变异：追加一个「数据行单元格数 > 表头」的表格。GFM 规范下多余单元格被**渲染器忽略** ⇒ 该内容在
#   任何渲染面上**静默丢失**（F295 实证：仓内 10 行，含契约级附注）。守护须报出，否则等于没写。
printf '\n| 甲 | 乙 | 丙 |\n| --- | --- | --- |\n| 1 | 2 | 3 | 注入多余单元格 |\n' \
  >> "$work/cur/skills/dsh-codepunk-workflow/references/standard.md"
mutate "追加超列表格行" "$work/cur/skills/dsh-codepunk-workflow/references/standard.md" '注入多余单元格'
check_rc "M130 表格行超列 → doc-consistency 失败" "bash plans/doc-consistency.sh 2>&1" 1 "表格行单元格数超过表头"

echo "[M131 表格结构断表（表头↔分隔行列数不等）须报（F296：断表后表体渲染为字面文本）]"
fresh
# 变异：追加一个**表头 3 列 / 分隔行 2 列**的表格。GFM 要求两者列数相符，否则整表不成立 ⇒ 表体
#   会以字面管道文本呈现（实证：learned-skills.md:8 表头 5 vs 分隔行 4 ⇒ 整表失效）。
printf '\n| 甲 | 乙 | 丙 |\n| --- | --- |\n| 1 | 2 | 3 |\n' \
  >> "$work/cur/skills/dsh-codepunk-workflow/references/standard.md"
mutate "追加表头与分隔行列数不等的表格" "$work/cur/skills/dsh-codepunk-workflow/references/standard.md" '甲'
check_rc "M131 断表 → doc-consistency 失败" "bash plans/doc-consistency.sh 2>&1" 1 "表格结构异常"

echo "[M132 非 git 工作区下类 8 须回退核验（F299：原实现 git ls-files 静默返空 ⇒ 空转却报「无未来日期」）]"
fresh
# 变异：删掉 .git 使 `git ls-files` 失败，并注入未来日期。修复前该场景 rc=0 且输出「✅ 无未来日期」（假绿灯）；
#   修复后应回退文件系统遍历并把未来日期报出。
rm -rf "$work/cur/.git"
printf '\n日期形态示例：2099-01-01。\n' >> "$work/cur/README.md"
mutate "非 git 工作区 + 注入未来日期" "$work/cur/README.md" '2099-01-01'
check_rc "M132 非 git 回退核验 → 未来日期须报" "bash plans/doc-consistency.sh 2>&1" 1 "2099-01-01"

echo "[M133 声明包装语义等价改写不得误报（F305：旧实现以文本正则/切片比 config.id 与 name，YAML 等价加引号即假红）]"
fresh
if [ -z "${DSH_APP_ROOT:-}" ] || [ ! -d "${DSH_APP_ROOT:-/nonexistent}" ]; then
  printf '  ℹ M133 跳过（未设 DSH_APP_ROOT，无法做语义比对；属环境受限）\n'
else
  : > "$work/patch133.yml"
  ( cd "$work/cur" && node plans/preset-declare.mjs apply --patch "$work/patch133.yml" --append >/dev/null 2>&1 ) || true
  python3 - "$work/patch133.yml" "$work/patch133e.yml" <<'PYEOF'
import sys
s, d = sys.argv[1], sys.argv[2]
t = open(s, encoding='utf-8').read()
open(d, 'w', encoding='utf-8').write(t.replace("\n        id: dsh-codepunk\n", "\n        id: \"dsh-codepunk\"\n", 1))
PYEOF
  mutate "包装 config.id 加引号（YAML 语义等价）" "$work/patch133e.yml" 'id: "dsh-codepunk"'
  check_rc "M133 等价改写不得误报" "node plans/preset-declare.mjs check --patch '$work/patch133e.yml' 2>&1" 0 "语义一致"
fi

echo "[M134 未跟踪探针命名物须被写盘纪律门捕获（G1 仓库残留）]"
fresh
# 变异：在沙箱副本内落**未跟踪**的探针命名物（未跟踪 + 不在 .git/ 内）。旧口径若只看 `git ls-files`，
#   这类落盘即漏检——写盘纪律契约要求「含未跟踪文件」一并计入。
printf '#!/usr/bin/env bash\necho probe\n' > "$work/cur/probe-r1.sh"
mutate "未跟踪探针 probe-r1.sh" "$work/cur/probe-r1.sh" 'echo probe'
check_rc "M134 未跟踪 probe-r1.sh → rc 1 且报「残留」" "bash plans/write-scope-check.sh --repo '$work/cur'" 1 "残留"

echo "[M135 备份后缀残留须被写盘纪律门捕获（G1 仓库残留）]"
fresh
# 变异：`plans/` 内落 `*.bak` 备份物（黑名单后缀之一）。
mkdir -p "$work/cur/plans"
printf 'x = 1\n' > "$work/cur/plans/foo.py.bak"
mutate "备份后缀 plans/foo.py.bak" "$work/cur/plans/foo.py.bak" '^x = 1$'
check_rc "M135 plans/foo.py.bak → rc 1 且报「残留」" "bash plans/write-scope-check.sh --repo '$work/cur'" 1 "残留"

echo "[M136 豁免登记须被机械采信（--exempt-from：命中降级 INFO，不判 FAIL）]"
fresh
# 变异：仓库内落**未跟踪**探针命名物（G1 必命中）+ 造运行根 README 夹具，把该路径登记进
#   `write_scope.exempt:`。守护 MUST 采信登记（降级 INFO 且不判 FAIL），否则 R17 的豁免机制形同虚设。
#   断言的两种模式一律显式加 `--home`：写盘门在**未给模式参数**时默认同时扫系统临时目录，
#   而宿主 /tmp 常有他人遗留 ⇒ 默认模式 rc 恒为 1，断言会与守护本身无关地失败（环境耦合）。
printf '#!/usr/bin/env bash\necho ok\n' > "$work/cur/probe-ok.sh"
{
  printf '# M136 夹具：运行根 README.md 的 write_scope 段（R17）\n'
  printf 'write_scope:\n  run_id: run-m136\n  cleanup_status: clean\n'
  printf '  exempt:                                # 豁免登记：真实交付物不属临时物\n'
  printf '    - path: probe-ok.sh\n'
} > "$work/README136.md"
mutate "未跟踪 probe-ok.sh" "$work/cur/probe-ok.sh" 'echo ok'
mutate "豁免夹具 write_scope.exempt" "$work/README136.md" 'path: probe-ok.sh'
check_rc "M136 带 --exempt-from（登记被采信）⇒ rc 0 且含「豁免」" \
  "bash plans/write-scope-check.sh --repo '$work/cur' --home --exempt-from '$work/README136.md'" 0 "豁免"
check_rc "M136 对照：不带 --exempt-from ⇒ rc 1 且报「残留」" \
  "bash plans/write-scope-check.sh --repo '$work/cur' --home" 1 "残留"
# F306 finding-1 存活变异：登记项为命中路径的**祖先目录**（父目录粒度）时同样必须降级 INFO——
#   旧实现把前缀判据写反（`case "$e" in "$hit"/*`），四种父目录写法全部漏判，且与该门 usage 和
#   README 的「登记项为命中路径的相等项或祖先目录」自相矛盾。此组断言**必须**与 `mutate` 配对：
#   先证变异落地，再断言 rc/关键词（否则变异未生效时断言恒绿 = 守护空转）。
#   夹具须**只留一个**命中项：上一段的 `probe-ok.sh` 未登记，若留着则 rc 恒为 1，本段断言会
#   与「父目录判据」无关地失败（假红），故先移除它。
rm -f "$work/cur/probe-ok.sh"
mkdir -p "$work/cur/plans"
printf 'x = 1\n' > "$work/cur/plans/keep-me.bak"
{
  printf '# M136 夹具：父目录粒度登记（登记项 = 命中路径的祖先目录）\n'
  printf 'write_scope:\n  run_id: run-m136b\n  cleanup_status: pending\n'
  printf '  exempt:                                # 豁免登记：交付物所在目录\n'
  printf '    - path: plans\n'
} > "$work/README136b.md"
mutate "父目录粒度登记（exempt: plans）" "$work/README136b.md" 'path: plans'
mutate "计划目录内备份物 plans/keep-me.bak" "$work/cur/plans/keep-me.bak" '^x = 1$'
check_rc "M136 父目录登记 plans（祖先目录）⇒ rc 0 且含「豁免」" \
  "bash plans/write-scope-check.sh --repo '$work/cur' --home --exempt-from '$work/README136b.md'" 0 "豁免"
check_rc "M136 父目录对照：同夹具不带 --exempt-from ⇒ rc 1 且报「残留」" \
  "bash plans/write-scope-check.sh --repo '$work/cur' --home" 1 "残留"

echo "[M137 G3 归属收窄：契约命名空间残留判红、他人同形条目降级 INFO（不改判，不影响退出码）]"
fresh
# 变异：在**沙箱** TMPDIR 顶层造本契约命名空间条目（`dsh-codepunk-` 前缀，即 §一.3 允许的
#   /tmp/dsh-codepunk-<run>-<step>/ 形态）⇒ G3 MUST 判 FAIL；
#   对照：造**非**契约命名空间的同形条目（`probe-*`）⇒ MUST 降级 INFO（rc 0，输出「归属不明」）。
#   两条断言一律显式 `--tmp` 且把 TMPDIR 指向沙箱根——默认模式还会扫宿主 /tmp，
#   与宿主遗留耦合（他人残留会让断言与守护本身无关地失败）。
mkdir -p "$work/tmp137/dsh-codepunk-r601-probe"
printf 'x = 1\n' > "$work/tmp137/dsh-codepunk-r601-probe/probe.py"
mutate "契约命名空间残留（轮次 601）" "$work/tmp137/dsh-codepunk-r601-probe/probe.py" '^x = 1$'
check_rc "M137 契约命名空间残留 ⇒ rc 1 且报「G3 临时目录残留」" \
  "TMPDIR='$work/tmp137' bash plans/write-scope-check.sh --repo '$work/cur' --tmp" 1 "G3 临时目录残留"
rm -rf "$work/tmp137/dsh-codepunk-r601-probe"
printf '#!/usr/bin/env bash\necho foreign\n' > "$work/tmp137/probe-foreign-x.sh"
mutate "非契约命名空间同形条目 probe-foreign-x.sh" "$work/tmp137/probe-foreign-x.sh" 'echo foreign'
check_rc "M137 对照：非契约命名空间同形条目 ⇒ rc 0 且含「归属不明」" \
  "TMPDIR='$work/tmp137' bash plans/write-scope-check.sh --repo '$work/cur' --tmp" 0 "归属不明"
# M142（F331）：自签判据须**不区分大小写**——交付方 task-a 的签收方写 Task-A MUST 仍判自签。
#   红证（退回旧实现）：区分大小写的子串包含 ⇒ 该夹具 verdict=PASS（自签被改大小写绕过）。
mkdir -p "$work/acc142"
printf 'task_id: task-a\naccepted_by:\n  - "Task-A"\naccepted_at: 2026-10-07T10:00:00+07:00\n' > "$work/acc142/case.yaml"
mutate "自签签收方改大小写 Task-A（F331 修复存活）" "$work/acc142/case.yaml" 'Task-A'
check_rc "M142 自签改大小写 → 仍判自签" \
  "bash plans/acceptance-verify.sh '$work/acc142/case.yaml' task-a 2>&1" 1 "自签"
# M142 对照：真正的独立签收方（大小写无关的不同 id）MUST 仍通过（防误报）。
printf 'task_id: task-a\naccepted_by:\n  - "docs-lead@task-b"\naccepted_at: 2026-10-07T10:00:00+07:00\n' > "$work/acc142/indep.yaml"
mutate "独立签收方 docs-lead@task-b" "$work/acc142/indep.yaml" 'docs-lead@task-b'
check_rc "M142 对照：独立签收方 ⇒ 通过（不误报）" \
  "bash plans/acceptance-verify.sh '$work/acc142/indep.yaml' task-a 2>&1" 0 "verdict=PASS"
# M143（F332）：缺交付方 task_id MUST 判 rc=2 并显式说明「无法核验」——不得打印 PASS 声称已校验独立性。
mkdir -p "$work/acc143"
printf 'task_id: task-a\naccepted_by:\n  - "task-a"\naccepted_at: 2026-10-07T10:00:00+07:00\n' > "$work/acc143/self.yaml"
mutate "自签夹具（缺交付方场景）" "$work/acc143/self.yaml" '"task-a"'
check_rc "M143 缺交付方 → rc 2 且报无法核验" \
  "bash plans/acceptance-verify.sh '$work/acc143/self.yaml' 2>&1" 2 "未提供交付方"

# M144（F334）：Makefile 的根推导 MUST 在**含空格路径**下仍成立——否则配方 `cd "$(ROOT)"` 被截断、rc=2。
#   红证（退回旧式 `$(dir $(abspath $(lastword $(MAKEFILE_LIST))))`）：`make -n gates` 打印的 cd 目标只剩路径首词。
mkdir -p "$work/space dir"
cp Makefile "$work/space dir/"
mutate "Makefile 根推导（含空格路径，F334 修复存活）" "$work/space dir/Makefile" '^ROOT := '
# 判据用**路径后缀**而非绝对前缀：macOS 上 `$TMPDIR` 常经 `/var` 符号链接，`pwd` 归一化为
#   `/private/var/...`，绝对前缀比对会因绑定路径差异误红（本轮实测）。
check_rc "M144 含空格路径下 make -n gates 的 cd 目标须为完整路径" \
  "make -C '$work/space dir' -n gates 2>&1 | grep -qF '/space dir\" || exit 2' && echo M144-OK" 0 "M144-OK"

# M145（F335）：无 git 环境（无 `.git`）下 class 17 的 ps1 行尾子项 MUST **回退文件系统字节核验**，
#   不得跳过——原实现跳过却仍 rc=0 且收尾「无硬性不一致（24 类检查）」＝环境导致的假绿灯。
echo "[M145 class 17 ps1 行尾在无 git 环境下须回退核验（F335）]"
fresh_nogit
python3 - "$work/cur/plans/windows/dsh-codepunk-home.ps1" <<'PYEOF'
import io, sys
p = sys.argv[1]
b = io.open(p, 'rb').read()
c = b.replace(b'\r\n', b'\n')
if c == b:
    raise SystemExit('变异未落地：目标文件本无 CRLF')   # 自检自身问题，不得静默（不用 sys.exit(N)，避免与退出码契约混淆）
io.open(p, 'wb').write(c)
PYEOF
mutate_gone "ps1 行尾 CRLF 被抹为 LF（无 git 环境）" "$work/cur/plans/windows/dsh-codepunk-home.ps1" "$(printf '\r')"
check_rc "M145 无 git 环境 ps1 裸 LF → rc 1 且由回退核验报出" \
  "bash plans/doc-consistency.sh 2>&1" 1 "文件系统字节核验"
# 对照：同一沙箱内恢复 CRLF 后，回退分支须判合格（防「回退分支恒报错」的空转守护）
python3 - "$work/cur/plans/windows/dsh-codepunk-home.ps1" <<'PYEOF'
import io, sys
p = sys.argv[1]
b = io.open(p, 'rb').read()
c = b.replace(b'\n', b'\r\n').replace(b'\r\r\n', b'\r\n')
io.open(p, 'wb').write(c)
PYEOF
check_contains "M145 对照：恢复 CRLF 后回退核验判合格（非恒真报错）" \
  "bash plans/doc-consistency.sh 2>&1" "ps1 行尾均为 CRLF（文件系统字节核验）"

# M146（F336）：class 5「运行型脚本 MUST 声明退出码」的豁免 MUST NOT 由**散文**触发——
#   旧实现 `grep -qE '\bsource\b'` 使任何含「source」一词的 .sh 被当库脚本豁免（doc-consistency.sh
#   因自身规则文本自我豁免；verify-battery.sh 因注释含「source 它」豁免；link.sh 为运行型 CLI 却豁免）。
#   注入：一个新 .sh，注释里含「source」一词、有显式 exit、**无**退出码声明 ⇒ 必须报缺声明。
echo "[M146 运行型脚本缺退出码声明不得被注释里的 source 一词豁免（F336）]"
fresh
mkdir -p "$work/cur/plans"
cat > "$work/cur/plans/zz-src-probe.sh" <<'SHEOF'
#!/usr/bin/env bash
# 说明：本文件仅为自检夹具，注释里提到 source 一词（用于验证豁免不再由散文触发）。
echo zz-src-probe
exit 2
SHEOF
chmod 755 "$work/cur/plans/zz-src-probe.sh"
mutate "注入无退出码声明且注释含 source 的运行型脚本" "$work/cur/plans/zz-src-probe.sh" "zz-src-probe"
check_rc "M146 注释含 source 的运行型脚本 → class 5 报缺退出码声明" \
  "bash plans/doc-consistency.sh 2>&1" 1 "运行型脚本缺退出码声明"
# 对照：同一夹具补上退出码声明后 MUST 不再报（防「新判据把带声明的脚本也误报」）
python3 - "$work/cur/plans/zz-src-probe.sh" <<'PYEOF'
import io, sys
p = sys.argv[1]
lines = io.open(p, encoding='utf-8').read().split('\n')
lines.insert(2, '# 退出码: 0=成功; 2=用法/环境错误')
io.open(p, 'w', encoding='utf-8').write('\n'.join(lines))
PYEOF
mutate "对照：为夹具补上退出码声明" "$work/cur/plans/zz-src-probe.sh" "退出码: 0=成功; 2=用法/环境错误"
check_contains "M146 对照：补上声明后 class 5 判合格（非恒真报错）" \
  "bash plans/doc-consistency.sh 2>&1" "运行型脚本均声明了退出码"

# M147（F338）：`docs/**` 的计数声称 MUST 与实现派生值一致——开源规格化引入 docs/ 后，
#   其计数不在任何门禁域（class 1 只扫 README），曾长期声称「137 项变异」而实现已 146。
echo "[M147 docs/ 计数声称陈旧须被 class 1 扩域后捕获（F338）]"
fresh
python3 - "$work/cur/docs/development.md" <<'PYEOF'
import io, re, sys
p = sys.argv[1]
t = io.open(p, encoding='utf-8').read()
# 计数无关：匹配「<数字> 项变异」的**任意**取值再改坏（写死目标数会随计数增长静默不落地——F300 教训）
n = re.subn(r'(?<![0-9])[0-9]+(?= 项变异)', '999', t, count=1)
if n[1] != 1:
    raise SystemExit('变异未落地：docs/development.md 未找到「<数字> 项变异」')
io.open(p, 'w', encoding='utf-8').write(n[0])
PYEOF
mutate "把 docs/development.md 的变异项数改为 999" "$work/cur/docs/development.md" "999 项变异"
check_rc "M147 docs/ 陈旧计数 → class 1 扩域判失败" \
  "bash plans/doc-consistency.sh 2>&1" 1 "docs/ 计数声称陈旧"

# M148（F339）：门禁的树遍历 MUST NOT 跟随符号链接——`glob('**/*', recursive=True)` 默认跟随，
#   检出内含链接环（自引用目录/指向祖先的链接）时无限递归、门禁**永不返回**（实测 rc=124，无判定行）。
#   变异＝沙箱内造自引用链接环；断言＝门禁仍**限时返回**且判定通过（124/超时即失败）。
echo "[M148 符号链接环不得使门禁无限递归（F339）]"
fresh
ln -s . "$work/cur/loop_self" && ln -s ../cur "$work/cur/loop_up"
[ -L "$work/cur/loop_self" ] || { echo "  ✗ M148 变异未落地：链接环未创建"; MUTFAIL=1; }
check_rc "M148 链接环下 doc-consistency 仍限时返回且通过（不得 rc=124）" \
  "timeout 90 bash plans/doc-consistency.sh 2>&1" 0 "无硬性不一致"

if [ "$FAILED" = 0 ]; then echo "✔ 自检通过：全部变异均被对应检查项捕获"; exit 0; fi
echo "✗ 自检失败：存在「注入缺陷却未被对应检查项捕获」的守护——疑似空转，请排查" >&2
exit 1
