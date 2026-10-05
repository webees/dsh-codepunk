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
SRC="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
[ -d "$SRC/plans" ] || { echo "✗ 预设根无效: $SRC" >&2; exit 2; }
FAILED=0
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
check_rc() {
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

FW=$(printf '\357\274\210')   # 全角左括号：载荷用拼接构造，避免本脚本自身被 B1b 误判

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
check_rc "M13 init 只读 HOME → 非零失败" "HOME=\"$work/ro\" bash plans/dsh-codepunk-init.sh" 1 "无法创建总库根"
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
check_rc "M17 未来日期 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "未来日期"

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

echo
if [ "$MUTFAIL" != 0 ]; then echo "✗ 自检失败：有变异未生效（自检脚本问题）" >&2; exit 2; fi
if [ "$FAILED" = 0 ]; then echo "✔ 自检通过：全部变异均被对应检查项捕获"; exit 0; fi
echo "✗ 自检失败：存在「注入缺陷却未被对应检查项捕获」的守护——疑似空转，请排查" >&2
exit 1
