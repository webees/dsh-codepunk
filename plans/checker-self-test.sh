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
# 背景（F133）：preset-score 有 37 个扣分点，此前仅 B10/B11 因一次事故被证明可达；
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
  "$work/cur/README.md" '快速开始' 'README 缺节'
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
sed -i.bak 's/×18 篇/×99 篇/' "$work/cur/README.md"
check_rc "M46 references 篇数声称漂移 → doc-consistency 失败" "bash plans/doc-consistency.sh" 1 "references 实际 18"
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
  pass "M51 跳过（未设 DSH_APP_ROOT，无法做语义比对；属环境受限）"
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

if [ "$FAILED" = 0 ]; then echo "✔ 自检通过：全部变异均被对应检查项捕获"; exit 0; fi
echo "✗ 自检失败：存在「注入缺陷却未被对应检查项捕获」的守护——疑似空转，请排查" >&2
exit 1
