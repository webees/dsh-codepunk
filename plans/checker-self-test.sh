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
# 用法: checker-self-test.sh [预设根] [--coverage-echo（仅打印结论行，测试钩子）| --lock-echo（取得并发锁后立即退出，测试钩子）]
# 退出码: 0=通过（结论行据实报「捕获 N/M 项 + 跳过 K 项（跳过 ≠ 通过）」）；1=存在未被捕获的变异（守护失效或空转）；2=环境或自检问题（含：同一预设根上已有另一次自检在运行——并发自检会互相污染 ⇒ 见下方并发互斥块）；3=夹具锚点缺失（仅出现在**夹具子进程**的返回值上：M47/M212 的派生锚未命中时以 rc=3 表示「夹具无法落地」，由 MUTFAIL 门转为 1 —— 见 D120）
# 环境变量: DSH_CODEPUNK_ECHO_TOTAL / DSH_CODEPUNK_ECHO_SKIPPED（配合 `--coverage-echo` 注入结论行计数，
#   供永久变异 M171 秒级断言）· DSH_CODEPUNK_SKIP_SELFTEST=1（递归防护：已在自检上下文内时立即退出）
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
# F361（本轮巡检实测）：本脚本原无 `-h`/`--help` 分支 ⇒ `-h` 被当预设根（报「预设根无效: -h」），
#   而本脚本的 M149 变异自述「`-h`/`--help` 约定……第 20 类探针 MUST 覆盖全部实现者」——
#   自身却是缺口（自相矛盾）。现补上。
SKIPPED=0      # F374：**跳过**计数（环境受限而未执行的变异）——结论行 MUST 据实报告覆盖
# F406（环境前提预检，与 F404/F405 同族）：本套件多处变异经 `node plans/preset-declare.mjs` /
#   `node plans/ps-validate.mjs` 施加与断言。缺 `node` 时这些断言以 **rc=127** 收场并报
#   「变异未生效（…自检自身问题，非守护问题）」⇒ 触发终局 MUTFAIL 门 ⇒ 整轮**假失败**，
#   且诊断把操作者引向「自检脚本问题」而非「环境缺 node」（误导）。
#   实测（R646 首跑日志 logs/selftest-r646.log）：持久 shell 重置后 PATH 不含 /opt/homebrew/bin
#   ⇒ M51 / M138 / M139 三条 ‼ + rc=127 + 终局 `✗ 自检失败：有变异未生效`。
#   ⇒ 显式预检，缺失即判 rc=2 并给出真实原因（无法核验 ≠ 通过；缺依赖不是守护缺陷）。
#   注：预检 MUST 在 `-h`/`--coverage-echo` 等**无副作用钩子之后**（帮助与钩子不得要求 node，
#   否则 doc-consistency 第 5 类的退出码契约 `-h ⇒ rc=0` 会漂移——实测本预检放在参数处理之前时该门即报
#   `退出码契约漂移 → checker-self-test -h(rc=2,want=0)`）。
has_deps() {
  for _t in node python3 bash; do
    command -v "$_t" >/dev/null 2>&1 || return 1
  done
  return 0
}
# F374 配套：跳过节统一走本助手（计数 + 统一措辞）；`跳过 ≠ 通过` 防止读者把跳过当已验证。
skip() { SKIPPED=$((SKIPPED + 1)); case "$1" in *"跳过 ≠ 通过"*) printf '  ℹ %s\n' "$1" ;; *) printf '  ℹ %s（跳过 ≠ 通过）\n' "$1" ;; esac; }
# F374：结论行实现（主路径与 `--coverage-echo` 测试钩子**共用**，避免钩子测的是另一份逻辑）。
coverage_line() { # 总数 跳过数
  if [ "${2:-0}" -gt 0 ]; then
    echo "✔ 自检通过：捕获 $(( $1 - $2 ))/$1 项变异；跳过 $2 项（跳过 ≠ 通过）"
  else
    echo "✔ 自检通过：全部变异均被对应检查项捕获（$1/$1）"
  fi
}
case "${1:-}" in
  -h|--help) sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  # F374 测试钩子：只打印结论行（同一 coverage_line 实现），供永久变异 M171 秒级断言。
  --coverage-echo)
    _tm=$(grep -oE 'M[0-9]+' "$0" | sort -u | wc -l | tr -d ' ')
    coverage_line "${DSH_CODEPUNK_ECHO_TOTAL:-$_tm}" "${DSH_CODEPUNK_ECHO_SKIPPED:-0}"
    exit 0 ;;
  # F410 测试钩子：**不在此处退出** —— 该钩子的意义是「走完锁获取路径」，故只登记意图，
  #   真正的退出点放在并发互斥块之后（见下）。
  --lock-echo) LOCK_ECHO=1; shift ;;
esac
SRC="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
[ -d "$SRC/plans" ] || { echo "✗ 预设根无效: $SRC" >&2; exit 2; }
# F406 环境前提预检（见上方注释）：放在帮助/钩子之后、真正执行变异之前。
if ! has_deps; then
  for _t in node python3 bash; do
    command -v "$_t" >/dev/null 2>&1 || printf '✗ 缺少自检依赖 %s ⇒ 无法核验 ≠ 通过（环境缺依赖，非守护缺陷；请把其所在目录加入 PATH）\n' "$_t" >&2
  done
  exit 2
fi
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

# ── 并发互斥（F410）──────────────────────────────────────────────────────────
#   为什么 MUST：本套件把 **${SRC}（调用方给出的预设根，通常是真仓库）** 当**可写共享资源**使用 ——
#   M189 的密封探针 `$SRC/.seal-probe-m189` 直接写入源树，`fresh()` 又整树复制 `$SRC` 到沙箱 ⇒
#   同一 `$SRC` 上并行两次自检会互相观察对方的探针、半成品副本与瞬时改动。
#   实证（本仓 R648）：一次与另一次自检重叠的运行产出 rc=1 的**幻影失败**（M194 三条断言拿到
#   doc-consistency rc=2，而不是期望的 1/0），而同一配置的**三次单跑**均为 195/195 rc=0 ⇒
#   结论不可复现、无法归因（「不可复现 ≠ 通过」的同族问题）。
#   锁：键＝`$SRC` 解析后的绝对路径（cksum 取整），落 `${TMPDIR:-/tmp}`；持锁者写 pid 文件；
#   持有者存活 ⇒ 拒绝启动（rc=2）；pid 不存在（陈旧锁）⇒ 接管并继续；退出时由 EXIT trap 释放。
LOCK_DIR=""
# 锁键 MUST 两侧口径一致：调用方给的路径可能是符号链接形态（macOS 上 /var、/tmp 均指向 /private/…），
# 而子实例由 `pwd` 得到的是**物理路径** ⇒ 直接对原始字符串取 cksum 会让父子算出不同键、互斥静默失效
# （实证 R648：M196-a 的子实例因键不匹配而**放行**，转而跑完整套件、挂满 CPU）。故统一取 `pwd -P`。
lock_key_for() {   # 参数：预设根目录 ⇒ 锁键（纯数字）；失败返回 1
  local d k
  d=$(cd "$1" 2>/dev/null && pwd -P) || return 1
  k=$(printf '%s' "$d" | cksum 2>/dev/null | awk '{print $1}' 2>/dev/null)
  case "$k" in ''|*[!0-9]*) return 1 ;; esac
  printf '%s' "$k"
}
lock_acquire() {
  local lock pid alive=0 key
  key=$(lock_key_for "$SRC") || {
    printf '✗ 无法派生并发锁键（预设根不可进入，或缺 cksum/awk）⇒ 无法核验 ≠ 通过（rc=2）\n' >&2
    return 2
  }
  lock="${TMPDIR:-/tmp}/cst-lock-$key"
  if mkdir "$lock" 2>/dev/null; then
    LOCK_DIR="$lock"          # 只在**自己持有**时才登记，供 EXIT trap 释放（拒绝路径 MUST NOT 登记）
    printf '%s\n' "$$" > "$lock/pid" 2>/dev/null
    return 0
  fi
  pid=$(cat "$lock/pid" 2>/dev/null || true)
  case "$pid" in ''|*[!0-9]*) pid=0 ;; esac
  if [ "$pid" -gt 0 ]; then
    if command -v ps >/dev/null 2>&1; then
      ps -p "$pid" >/dev/null 2>&1 && alive=1
    else
      alive=1   # 无法判定持有者是否存活 ⇒ 按持有处理（无法核验 ≠ 通过）
    fi
  fi
  # F410 守护：持有者存活即拒绝
  if [ "$alive" = 1 ]; then
    printf '✗ 另一次自检正在运行（同一预设根 %s，pid %s）⇒ 并发自检会互相污染、结论不可归因（无法核验 ≠ 通过，rc=2）\n' \
      "$SRC" "$pid" >&2
    printf '  处置：等待该实例结束（或确认其 pid 已不存在）后重跑。\n' >&2
    return 2
  fi
  printf '  ℹ 接管陈旧锁（%s，原 pid %s 已不存在）\n' "$lock" "${pid:-未知}" >&2
  LOCK_DIR="$lock"
  printf '%s\n' "$$" > "$lock/pid" 2>/dev/null
  return 0
}
lock_release() { [ -n "${LOCK_DIR:-}" ] && rm -rf "$LOCK_DIR" 2>/dev/null; return 0; }

lock_acquire || exit 2
trap 'lock_release; rm -rf "$work"' EXIT

# F410 测试钩子：走完锁获取路径后立即退出（供永久变异 M196 秒级断言；不做任何其它副作用）
if [ "${LOCK_ECHO:-0}" = 1 ]; then
  printf '锁已取得：src=%s lock=%s\n' "$SRC" "$LOCK_DIR"
  exit 0
fi

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

# F397（本轮巡检实测）：变异 MUST 作用于 `$work/cur`（沙箱副本）——裸相对路径（如 `plans/x.sh`）在主 shell
#   下解析到**源树**，会把「删除型变异」真的施加于仓库文件（本轮实测：M188-c 的裸 `sed -i.bak` 删掉
#   `plans/write-scope-check.sh` 的判据 h 实现，紧随的 `rm -f …bak` 又抹掉备份 ⇒ 源树静默退化，
#   仅因 hub 镜像留有副本才可无损恢复）。为此本脚本自带**源树密封判据**：开工前取指纹，收尾比对。
src_fingerprint() {  # 源树指纹：状态（含被 .gitignore 匹配的项）+ 未暂存差异 + 已暂存差异
  # 注：本仓 .gitignore 以 `*` 兜底白名单，故**未跟踪探针文件也属被忽略项** ⇒ 须显式带 `--ignored=matching`，
  #   否则密封判据对「在源树落一个未跟踪文件」这类改动完全无感（实测：漏判）。排除两类运行产物误报。
  ( cd "$SRC" && { git status --porcelain=v1 2>/dev/null
                   git status --porcelain=v1 --ignored=matching 2>/dev/null | grep -vE '__pycache__|\.DS_Store'
                   git diff 2>/dev/null; git diff --cached 2>/dev/null; } \
      | git hash-object --stdin 2>/dev/null )
}
seal_check() {  # 0=源树未被本脚本改动；1=已改动（自检自身问题）
  [ "$(src_fingerprint)" = "$SRC_FP_BEFORE" ]
}
SRC_FP_BEFORE="$(src_fingerprint)"

# mutate <描述> <文件> <grep 模式>：确认变异**真的落盘**——否则自检会误报「守护未捕获」
# F415（本轮实测）：模式串 MUST 用 `--` 与 grep 选项分隔。旧实现 `grep -qE "$pat" "$f"` 在
#   模式串以 `-` 开头时（例：`-lt 1 ]; then`）被 grep 当作**选项**解析 ⇒ 命令报用法错误、
#   匹配恒失败 ⇒ 打印「‼ 变异未生效」并把整轮自检判为失败（假失败，且诊断指向「自检脚本问题」）。
mutate() {
  local desc="$1" f="$2" pat="$3"
  if ! grep -qE -- "$pat" "$f" 2>/dev/null; then
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

# zhcount <文件> <前缀>：取「<前缀>+中文数字+项检查」里的当前中文数字并 +1（取不到或越界则输出空）。
# 动机（F362，与 M106 的 F298 同族）：变异夹具若**硬编码**被测文案里的计数（如「七项检查」），
#   计数一旦合法增长（本轮实测：`preset-compat.py` 头部由七项→八项），变异即未落地 ⇒ MUTFAIL
#   触发第 1148 行**提前 exit 2**，其后全部变异（含 M164）**根本不再执行**——「自检夹具自身脆弱」
#   被误报成「自检失败」。此处改为按模式取当前值再递增，使夹具不随计数增长而陈旧。
zhcount() {
  python3 - "$1" "$2" <<'PYEOF'
import re, sys
t = open(sys.argv[1], encoding='utf-8').read()
m = re.search(re.escape(sys.argv[2]) + r'([一二三四五六七八九十]+)项检查', t)
if not m:
    print(''); raise SystemExit(0)
n = '一二三四五六七八九十'
i = n.index(m.group(1)[-1])
print('' if i + 1 >= len(n) else n[i + 1])
PYEOF
}

echo "[M110 class 3 术语咨询须「检出但不计失败」（F227）]"
fresh
printf '\n> 探针：本行裸用工作区一词。\n' >> "$work/cur/skills/dsh-codepunk-workflow/SKILL.md"
mutate "SKILL 注入裸用「工作区」" "$work/cur/skills/dsh-codepunk-workflow/SKILL.md" '裸用工作区一词'
check_rc "M110 注入术语问题 → 仍须 rc 0（不计失败）" "bash plans/doc-consistency.sh" 0 ""
check_contains "M110 术语咨询须真的检出（特异提示行出现）" "bash plans/doc-consistency.sh 2>&1" "裸用「工作区」"

echo "[M111 class 6 头部自称项数须「提示但不计失败」（F227）]"
fresh
# F362：变异目标串按**当前**计数派生（`zhcount`），不再硬编码「七项检查」——否则计数合法增长后
#   变异未落地 ⇒ MUTFAIL ⇒ 提前 exit 2（其后变异全不执行）。断言串同样按派生值拼接。
M111_NEXT="$(zhcount "$work/cur/plans/preset-compat.py" '')"
[ -n "$M111_NEXT" ] || { printf '  ‼ M111 变异目标串未取到（preset-compat 头部计数文案已变）\n' >&2; MUTFAIL=1; }
M111_NEW="$(printf '%s项检查' "$M111_NEXT")"
python3 - "$work/cur/plans/preset-compat.py" "$M111_NEW" <<'PYEOF'
import re, sys
p, new = sys.argv[1], sys.argv[2]
s = open(p, encoding='utf-8').read()
n = re.sub(r'[一二三四五六七八九十]+项检查', new, s, count=1)
assert n != s, 'M111 变异目标串未找到（preset-compat 头部计数文案已变）'
open(p, 'w', encoding='utf-8').write(n)
PYEOF
mutate "preset-compat 头部自称改为${M111_NEW}" "$work/cur/plans/preset-compat.py" "$M111_NEW"
check_rc "M111 注入头部自称项数 → 仍须 rc 0（不计失败）" "bash plans/doc-consistency.sh" 0 ""
check_contains "M111 头部自称项数须真的提示（特异提示行出现）" "bash plans/doc-consistency.sh 2>&1" "头部称「${M111_NEW}」"

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
# F399：原断言为 `grep -c F215 == 2` / `grep -c F216 == 1`（**计数式**）——新增一处正当的关联注释即断，
#   与 F300 家族同病（计数式断言随实现演进静默腐化：本轮在 preset-score 注释里引用 F216 先例即触发
#   「✗ M102 score 含 F216 缺口声明（未含「1」）」）。改为**下界**断言：既保留「两路径各自标注」的强度，
#   又不再因合法新增提及而误判。
check_rc "M102 score 含 F215 说明（下界 ≥2：双路径各自标注）" "test \"\$(grep -c F215 plans/preset-score.sh)\" -ge 2" 0
check_rc "M102 score 含 F216 缺口声明（下界 ≥1）" "test \"\$(grep -c F216 plans/preset-score.sh)\" -ge 1" 0

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

echo "[M92 A5 成段重复扣分可达（16 指标全覆盖收口）]"
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
# F370：夹具 MUST 由**源**在沙箱内生成（`apply --append --patch <沙箱文件>`），不得指向用户平面
#   实况补丁——否则「源前进而用户未 apply」这一**正常开发态**下本断言假红（实测：源 19 条 / 副本 17 条
#   ⇒ rc=1「漂移」），且 CI 无该文件 ⇒ 整族退化为「ℹ 跳过」（跳过 ≠ 通过）。
FIX_PATCH="$work/prof/cordis.patch.yml"
if [ -z "${DSH_APP_ROOT:-}${DSH_ASAR:-}" ]; then
  skip 'M14 跳过（未设 DSH_APP_ROOT/DSH_ASAR，无法进入语义核验模式）'
elif ! command -v node >/dev/null 2>&1; then
  skip 'M14 跳过（缺 node）'
else
  fresh; mkdir -p "$work/prof"; : > "$FIX_PATCH"
  check_rc "M14a 由源生成副本 → 一致（自足夹具，不依赖用户平面）" \
    "node plans/preset-declare.mjs apply --append --patch \"$FIX_PATCH\" >/dev/null && node plans/preset-declare.mjs check --patch \"$FIX_PATCH\"" 0 "语义一致"
  python3 - "$FIX_PATCH" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
n = s.replace('../../.agent-presets/dsh-codepunk/skills/', '/tmp/evil-skills/')
if n == s:                      # 兜底：按 skills/ 片段做更宽松的替换
    n = s.replace("new URL('skills/'", "new URL('/tmp/evil-skills/'", 1)
open(p, 'w', encoding='utf-8').write(n)
PYEOF
  check_rc "M14b 改适配路径 → 漂移" "node plans/preset-declare.mjs check --patch \"$FIX_PATCH\"" 1 "漂移"
fi

echo "[M15 文档声称一致性（doc-consistency 存活）]"
fresh
python3 - "$work/cur/README.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
n = s.replace('16 指标', '99 指标', 1)
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
# 会在副本内把自检文件自身判为违规（F131 实测：评分由满分掉至 13 项）。
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
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
# 计数无关（F300 类陷阱）：不再硬编码探针数，按模式替换首个「**N 条探针**」。
s2, n = re.subn(r'\*\*[0-9]+ 条探针\*\*', '**9 条探针**', s, count=1)
assert n == 1, 'M125 变异目标未找到（治理表探针数声称形态已变）'
open(p, 'w', encoding='utf-8').write(s2)
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
import re, sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
# F432：锚点 MUST 从实况派生 —— 此前写死 '15 指标'，评分项数改成 16 后夹具整体静默失效
#   （两处 find 都返回 -1，README 一字未改，doc-consistency 反而 rc=0），即守护被无声拔掉。
hits = list(re.finditer(r'[0-9]+ 指标', s))
if len(hits) < 2:
    sys.exit(3)
m = hits[1]
open(p, 'w', encoding='utf-8').write(s[:m.start()] + '77 指标' + s[m.end():])
PYEOF
_m47_rc=$?
if [ "$_m47_rc" != 0 ] || ! grep -q '77 指标' "$work/cur/README.md"; then
  echo "  ‼ M47 夹具未落地（锚点缺失或未改到，rc=${_m47_rc}）" >&2; MUTFAIL=1
fi
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
  skip 'M51 跳过（未设 DSH_APP_ROOT，无法做语义比对；属环境受限）'
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
  skip 'M138 跳过（未设 DSH_APP_ROOT，无法做语义比对；属环境受限）'
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
  skip 'M139 跳过（未设 DSH_APP_ROOT，无法做语义比对；属环境受限）'
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
  skip 'M141 跳过（未设 DSH_APP_ROOT，无法核验安装真实性；属环境受限）'
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
  skip 'M133 跳过（未设 DSH_APP_ROOT，无法做语义比对；属环境受限）'
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
# F364：G1 命名黑名单须覆盖 Python 字节码缓存（目录本身即命中；`.pyc` 亦命中）。
mkdir -p "$work/cur/plans/__pycache__"
printf 'x = 1\n' > "$work/cur/plans/__pycache__/mod"
mutate "字节码缓存目录 plans/__pycache__" "$work/cur/plans/__pycache__/mod" '^x = 1$'
check_rc "M135-b plans/__pycache__ 残留 → rc 1 且报「残留」" "bash plans/write-scope-check.sh --repo '$work/cur'" 1 "残留"

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

# M149（F342）：`-h/--help` 约定只对**实现者**成立，且第 20 类探针 MUST 覆盖全部实现者——
#   修复前探针集只有 6 条（漏掉 init/git-merge-flow/github-setup/write-scope-check），
#   这 4 个脚本的 `-h` 回归不可见（实测：变异后旧探针集仍报 rc=0「19 条探针」「✔ 无硬性不一致」）。
echo "[M149 -h 约定探针须覆盖全部实现者（F342）]"
fresh
python3 - "$work/cur/plans/write-scope-check.sh" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
# F379：变异锚点 MUST 只依赖**被守护的分支形态**，不得依赖易碎常量（原锚点写死了 `-h` 的
#   行区间 `2,44p`；本轮把用法块由 44 行扩到 50 行后变异即不落地，自检因「变异未生效」整轮变红）。
old = "    -h|--help)  sed -n '"
new = "    -h|--help)  exit 2  # M149-MUT -- sed -n '"
assert old in s, 'M149 变异目标行未找到'
open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
PYEOF
mutate "write-scope-check.sh 的 -h 分支改为 exit 2" "$work/cur/plans/write-scope-check.sh" 'M149-MUT'
check_rc "M149 实现者的 -h 回归 → doc-consistency 须报退出码契约漂移" \
  "bash plans/doc-consistency.sh 2>&1" 1 "退出码契约漂移"

# M150（F344）：制品「字段模板见 `references/artifacts.md`」的声称 MUST 在 artifacts.md 有对应小节——
#   实测：SKILL 的 `plan_draft.md` 曾指向 artifacts.md，而后者只在运行根树状图里出现该名（字段契约悬空）。
echo "[M150 制品字段模板声称须有对应小节（F344）]"
fresh
python3 - "$work/cur/skills/dsh-codepunk-workflow/references/artifacts.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = '## plan_draft.md（① 需求草案；与 `goal.yaml` 同批产出）'
new = '## 需求草案（①；与 `goal.yaml` 同批产出）'
assert old in s, 'M150 变异目标行未找到'
open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
PYEOF
mutate "artifacts.md 的 plan_draft.md 小节标题改名" \
  "$work/cur/skills/dsh-codepunk-workflow/references/artifacts.md" '## 需求草案（①；与 `goal.yaml` 同批产出）'
check_rc "M150 制品字段模板悬空 → doc-consistency 须报章节级引用问题" \
  "bash plans/doc-consistency.sh 2>&1" 1 "制品字段模板悬空"

# M151（F345）：散落根判据收窄 + 默认根解析——只有**与本主仓库共享 git 目录**的散落 worktree
#   判 FAIL；散落根内的无关仓库（别人的项目 / 主仓的克隆）只报 INFO。实测：旧实现把桌面上的
#   无关仓库一律判 FAIL（本机 6 个无关项目被误报），而文档化落点从不被扫描。
echo "[M151 散落根判据收窄与默认根解析（F345）]"
fresh
wt2_main="$work/wt2/main"; wt2_scan="$work/wt2/scan"
rm -rf "$work/wt2"; mkdir -p "$wt2_main" "$wt2_scan"
( cd "$wt2_main" && git init -q . && git config user.email t@t && git config user.name t \
  && : > f.txt && git add f.txt && git commit -qm init ) >/dev/null 2>&1
# ① 散落根内的无关仓库（与主仓库无共享 git 目录）⇒ 不得判 FAIL，须报 INFO
( cd "$wt2_scan" && mkdir -p unrelated-proj && cd unrelated-proj \
  && git init -q . && git config user.email t@t && git config user.name t \
  && : > u.txt && git add u.txt && git commit -qm x ) >/dev/null 2>&1
check_rc "M151-a 散落根内无关仓库 → 只报 INFO 不判 FAIL" \
  "SCAN_ROOT='$wt2_scan' bash plans/verify-worktree.sh '$wt2_main' 2>&1" 0 "不计 FAIL"
# ② 主仓库的克隆（非 worktree）⇒ 同样只报 INFO
( git clone -q "$wt2_main" "$wt2_scan/clone-of-main" ) >/dev/null 2>&1
check_rc "M151-b 主仓库克隆（非 worktree）→ 只报 INFO" \
  "SCAN_ROOT='$wt2_scan' bash plans/verify-worktree.sh '$wt2_main' 2>&1" 0 "不计 FAIL"
# ③ 真散落 worktree（共享 git 目录）⇒ 必须判 FAIL
( cd "$wt2_main" && git worktree add -q "$wt2_scan/stray-room" -b stray2 ) >/dev/null 2>&1
check_rc "M151-c 本主仓库的散落 worktree → 失败" \
  "SCAN_ROOT='$wt2_scan' bash plans/verify-worktree.sh '$wt2_main' 2>&1" 1 "散落 worktree"
# ④ 默认根解析：未设 SCAN_ROOT 时 DSH_CODEPUNK_WORKTREES（总库 worktrees）优先于桌面候选
#   （先摘掉 ③ 的登记，否则第 2 项「列表干净」会把退出码抬到 1，掩盖默认根解析的断言）
( cd "$wt2_main" && git worktree remove --force "$wt2_scan/stray-room" ) >/dev/null 2>&1
mkdir -p "$work/wt2/hubwt"
check_rc "M151-d 未设 SCAN_ROOT → 优先扫 DSH_CODEPUNK_WORKTREES" \
  "env -u SCAN_ROOT DSH_CODEPUNK_WORKTREES='$work/wt2/hubwt' bash plans/verify-worktree.sh '$wt2_main' 2>&1" 0 "扫描 .*hubwt"

# M152（F346）：INDEX 顶格块序列项（`projects:` 与 `- project_id:` 同列——迁移/早期写入器形态，
#   合法 YAML）不得被结构守卫当成「未知顶层键」；追加 MUST 沿用既有缩进风格，否则追加的
#   缩进条目成为映射值下的嵌套序列 ⇒ 真实解析器判非法 YAML、写入被回滚（实测：真总库
#   24 条目顶格 ⇒ index/register 双双 rc=1，登记功能整体失效，且提示「从备份恢复」为误导）。
echo "[M152 INDEX 顶格序列项容忍与缩进风格保持（F346）]"
fresh
f346_hub="$work/f346/hub"; rm -rf "$work/f346"
mkdir -p "$f346_hub/projects/demo" "$f346_hub/proj-src/demo" "$f346_hub/proj-src/demo2"
{
  printf -- '---\nschema_version: 1\nprojects:\n'
  printf -- '- project_id: demo\n'
  printf -- '  project_root: "%s/proj-src/demo"\n' "$f346_hub"
  printf -- '  dsh_codepunk_path: "%s/projects/demo"\n' "$f346_hub"
  printf -- "  migrated_at: '2026-08-24T08:00:00Z'\n  source: migration-report\n"
  printf -- 'last_updated: 2026-10-07 13:01:10.000000000 +07:00\n'
} > "$f346_hub/INDEX.yaml"
mutate "顶格序列项夹具" "$f346_hub/INDEX.yaml" '^- project_id: demo'
F346_ENV="DSH_CODEPUNK_HOME='$f346_hub' DSH_CODEPUNK_INDEX='$f346_hub/INDEX.yaml'"
check_rc "M152-a 顶格 INDEX → index 通过" \
  "$F346_ENV bash plans/dsh-codepunk-link.sh index 2>&1" 0 "1 ok, 0 fail"
check_rc "M152-b 顶格 INDEX → register 成功（写入后校验通过）" \
  "$F346_ENV bash plans/dsh-codepunk-link.sh register -y '$f346_hub/proj-src/demo2' demo2 2>&1" 0 "已注册"
check_rc "M152-c 追加沿用顶格风格（无缩进）" \
  "grep -cE '^- project_id: demo2' '$f346_hub/INDEX.yaml'" 0
check_rc "M152-d 追加后条目齐、无空悬" \
  "$F346_ENV bash plans/dsh-codepunk-link.sh index 2>&1" 0 "2 ok, 0 fail"
printf -- 'foo: bar\n' >> "$f346_hub/INDEX.yaml"
mutate "真未知顶层键夹具" "$f346_hub/INDEX.yaml" '^foo: bar'
check_rc "M152-e 真未知顶层键仍失败（不放过真错）" \
  "$F346_ENV bash plans/dsh-codepunk-link.sh index 2>&1" 1 "未知顶层键"

# M153（F347）：分支保护必需检查名失配（ruleset 按上下文名匹配 ⇒ 改名后该检查永不出现、PR 永久阻塞）。
# 变异在**副本**内改 `.github/workflows/ci.yml` 的作业名；子断言 b 覆盖文档侧漏提。
echo "[M153 分支保护必需检查名一致性（F347）]"
fresh
sed -i.bak -E 's/^    name: 门禁回归$/    name: 门禁回归-v2/' "$work/cur/.github/workflows/ci.yml"
rm -f "$work/cur/.github/workflows/ci.yml.bak"
mutate "ci.yml 作业名改名（模拟重构）" "$work/cur/.github/workflows/ci.yml" '^    name: 门禁回归-v2$'
check_rc "M153-a 作业改名 → doc-consistency 失败（缺/多同时报出）" \
  "bash plans/doc-consistency.sh 2>&1" 1 "必需检查名不一致"
sed -i.bak 's/检查名由/检查名定义自/' "$work/cur/docs/maintenance.md"
rm -f "$work/cur/docs/maintenance.md.bak"
mutate "docs/maintenance.md 抹掉检查名提及" "$work/cur/docs/maintenance.md" '检查名定义自'
check_no_match "M153-b 文档漏提检查名 → 不得仍报「必需检查名一致」" \
  "bash plans/doc-consistency.sh 2>&1" "必需检查名一致（脚本"

# M154（F348）：证据门 log_ref 的**交付目录包含性**——旧实现用 os.path.isfile 直通 ⇒
#   `log_ref: /etc/hosts`、`../<交付目录外>`、指向交付目录外的符号链接**均 verdict=PASS**（②③ 对本次交付不成立）。
echo "[M154 证据门 log_ref 包含性（F348）]"
f348_d="$work/f348/deliv"
mkdir -p "$f348_d/logs" "$work/f348"
printf 'inside log\n' > "$f348_d/logs/ok.log"
printf 'outside log\n' > "$work/f348/outside.log"
printf 'task_id: t\ndelivered_at: "2026-10-07T10:00:00+07:00"\nvalidated_at: "2099-01-01T00:00:00+07:00"\nevidence:\n  - id: EV-1\n    command: "bash plans/doc-consistency.sh"\n    exit_code: 0\n    log_ref: "../outside.log"\n' > "$f348_d/evidence.yaml"
mutate "交付目录外的 log_ref 夹具（.. 逃逸）" "$f348_d/evidence.yaml" 'log_ref: "../outside.log"'
check_rc "M154-a log_ref 逃出交付目录 → FAIL（旧实现 PASS）" \
  "bash plans/evidence-verify.sh '$f348_d/evidence.yaml' '$f348_d' 2>&1" 1 "指向交付目录之外"
printf 'task_id: t\ndelivered_at: "2026-10-07T10:00:00+07:00"\nvalidated_at: "2099-01-01T00:00:00+07:00"\nevidence:\n  - id: EV-1\n    command: "bash plans/doc-consistency.sh"\n    exit_code: 0\n    log_ref: "logs/ok.log"\n' > "$f348_d/evidence.yaml"
check_rc "M154-b 交付目录内的 log_ref → PASS（不误伤正常证据）" \
  "bash plans/evidence-verify.sh '$f348_d/evidence.yaml' '$f348_d' 2>&1" 0 "verdict=PASS"
sed -i.bak 's/指向交付目录之外/（判据已移除）/' "$work/cur/plans/evidence-verify.sh"
rm -f "$work/cur/plans/evidence-verify.sh.bak"
mutate "副本内移除包含性判据的提示串" "$work/cur/plans/evidence-verify.sh" '（判据已移除）'
check_no_match "M154-c 判据被移除后不得仍报「指向交付目录之外」（断言非空转）" \
  "bash plans/evidence-verify.sh '$f348_d/evidence.yaml' '$f348_d' 2>&1" "指向交付目录之外"

# M155（F349）：preset-declare.mjs 的**根结构前置校验**与**写后自校验/降级拒答**——旧实现只校验
#   「输入能否解析」：根为映射的补丁被追加 `- insert:` 项后顶层混用映射与序列 ⇒ 产出**非法 YAML**，
#   却仍打印「✅ 生效」并提示重启 DSH（operator 拿到坏补丁）；含 `...` 的补丁追加后成多文档同理。
echo "[M155 声明应用：不兼容根结构与不可解析产物须拒答（F349）]"
f349_d="$work/f349"
mkdir -p "$f349_d"
printf 'plugins:\n  - name: "@deepseek-ai/dsh-agent-preset"\n    config:\n      id: preset-other\n      order: 9\n' > "$f349_d/map.yml"
printf -- '- id: other-plugin\n...\n' > "$f349_d/doc.yml"
printf -- '- id: other-plugin\n  config:\n    a: 1\n' > "$f349_d/ok.yml"
check_rc "M155-a 根为映射 → 拒答（根节点不是序列）" \
  "node plans/preset-declare.mjs apply --patch '$f349_d/map.yml' --append 2>&1" 2 "根节点不是序列"
check_contains "M155-b 前置校验不改动文件（声明块数须为 0）" \
  "grep -c 'id: preset-dsh-codepunk' '$f349_d/map.yml' || true" "0"
check_contains "M155-b2 前置校验不留备份（备份数须为 0）" \
  "ls '$f349_d/map.yml'.bak-* 2>/dev/null | wc -l | tr -d ' '" "0"
check_rc "M155-c 含文档分隔符 → 拒答或回滚（无法核验 ≠ 通过）" \
  "node plans/preset-declare.mjs apply --patch '$f349_d/doc.yml' --append 2>&1" 2 "无法核验 ≠ 通过"
check_contains "M155-d 拒答后不留半成品（声明块数须为 0）" \
  "grep -c 'id: preset-dsh-codepunk' '$f349_d/doc.yml' || true" "0"
check_rc "M155-e 序列根正常路径不回归" \
  "node plans/preset-declare.mjs apply --patch '$f349_d/ok.yml' --append 2>&1" 0 "追加声明块"
sed -i.bak 's/根节点不是序列/根节点形态不符/' "$work/cur/plans/preset-declare.mjs"
rm -f "$work/cur/plans/preset-declare.mjs.bak"
mutate_gone "preset-declare 抹掉根结构判据消息" "$work/cur/plans/preset-declare.mjs" '根节点不是序列'
check_no_match "M155-f 判据移除 → 不得再报「根节点不是序列」（断言非空转）" \
  "node plans/preset-declare.mjs apply --patch '$f349_d/map.yml' --append 2>&1" "根节点不是序列"

echo "[M156 电池跳过项不得计入「满分」（F350）]"
# F370：电池的第 8b 项（声明副本漂移）读 `$DSH_PROFILE_PATCH`，默认指向用户平面实况补丁 ⇒
#   用户未 apply 时该项 ✗、F=1、结论行变「存在失败项」，于是「跳过 ≠ 通过」永不出现（M156-a 假红）。
#   此处同样注入**由源生成的沙箱夹具**，使本断言只取决于「跳过项与结论行的关系」这一被检语义。
if [ -z "${DSH_APP_ROOT:-}${DSH_ASAR:-}" ] || ! command -v node >/dev/null 2>&1; then
  skip 'M156 跳过（缺 node 或 DSH_APP_ROOT/DSH_ASAR——声明漂移项无法进入语义模式）'
else
fresh; mkdir -p "$work/prof"
BAT_PATCH="$work/prof/battery-patch.yml"; : > "$BAT_PATCH"
( cd "$work/cur" && node plans/preset-declare.mjs apply --append --patch "$BAT_PATCH" >/dev/null 2>&1 ) || \
  printf '  ‼ M156 夹具生成失败（自检自身问题）\n' >&2
check_rc "M156-a 跳过模式结论行须列出跳过项且不称满分" \
  "DSH_PROFILE_PATCH=\"$BAT_PATCH\" DSH_CODEPUNK_SKIP_SELFTEST=1 bash plans/verify-battery.sh 2>&1" 0 "跳过 ≠ 通过"
check_no_match "M156-a2 跳过模式不得出现「全部通过（满分）」" \
  "DSH_PROFILE_PATCH=\"$BAT_PATCH\" DSH_CODEPUNK_SKIP_SELFTEST=1 bash plans/verify-battery.sh 2>&1" "全部通过（满分）"
sed -i.bak 's/跳过 ≠ 通过/（标注已移除）/' "$work/cur/plans/verify-battery.sh"
rm -f "$work/cur/plans/verify-battery.sh.bak"
mutate "电池结论行的跳过标注被抹掉" "$work/cur/plans/verify-battery.sh" '（标注已移除）'
check_no_match "M156-b 标注被抹掉 → 不得再报「跳过 ≠ 通过」（断言非空转）" \
  "DSH_PROFILE_PATCH=\"$BAT_PATCH\" DSH_CODEPUNK_SKIP_SELFTEST=1 bash plans/verify-battery.sh 2>&1" "跳过 ≠ 通过"
fi

# ---------------------------------------------------------------------------
# M157 / M158：**无 ruby 主机**上的 YAML 解析路径（F351 / F352 / F353）
#   本仓默认走 ruby（Psych）；node 回退分支只在**没有 ruby 的主机**上生效，而自检环境
#   通常有 ruby ⇒ 该分支长期**不可达**（这正是它带缺陷存在多轮的原因）。故此处用「工具农场」
#   （/usr/bin 与 /bin 全量符号链接，**减去 ruby**，再补 git/node/python3 的真实路径）模拟
#   无 ruby 主机，并用**桩 js-yaml**（`DEFAULT_SCHEMA.extend`/`Type`/`load`，按环境变量
#   返回不同结构）验证：①候选链解析 ②`!!js` 容忍 schema ③解析结果的类型判定（Date 属标量）。
#   桩目录经 `DSH_CODEPUNK_TOOLS` 显式提供 ⇒ 不受真实 `~/.dsh-codepunk/tools` 内容影响。
# ---------------------------------------------------------------------------
echo "[M157 无 ruby 主机的 A1 解析路径（F351）]"
farm_noruby="$work/farm-noruby"
mkdir -p "$farm_noruby"
for _d in /usr/bin /bin; do
  for _s in "$_d"/*; do
    _b="${_s##*/}"
    [ "$_b" = ruby ] && continue
    [ -e "$farm_noruby/$_b" ] || ln -s "$_s" "$farm_noruby/$_b" 2>/dev/null
  done
done
for _t in git node python3; do
  _rp="$(command -v "$_t" 2>/dev/null || true)"
  [ -n "$_rp" ] && ln -sf "$_rp" "$farm_noruby/$_t" 2>/dev/null
done
m157_tools="$work/m157tools/node_modules/js-yaml"
mkdir -p "$m157_tools" "$work/m157empty" "$work/m157home"
printf '%s\n' '{"name":"js-yaml","main":"index.js"}' > "$work/m157tools/node_modules/js-yaml/package.json"
printf '%s\n' 'module.exports={DEFAULT_SCHEMA:{extend:function(){return module.exports.DEFAULT_SCHEMA;}},Type:function(){},load:function(){if(process.env.STUB_INDEX==="bad")return {schema_version:"1",projects:{},last_updated:{a:1}};if(process.env.STUB_INDEX)return {schema_version:"1",projects:{},last_updated:new Date()};if(process.env.STUB_A1==="bad")return [{name:""}];var a=[],i;for(i=0;i<17;i++)a.push({name:"role"+i});return a;}};' \
  > "$m157_tools/index.js"
if [ ! -x "$farm_noruby/bash" ] || [ ! -e "$farm_noruby/node" ]; then
  skip 'M157/M158 跳过：本机无法构造「有 node 但无 ruby」的 PATH 农场'
else
  check_rc "M157-a 无 ruby + 候选链内有 js-yaml ⇒ A1 报「解析 OK」（修复前：解析失败）" \
    "PATH='$farm_noruby' DSH_CODEPUNK_TOOLS='$work/m157tools' bash plans/preset-audit.sh 2>&1 | grep -qF 'A1 解析 OK'" 0
  check_rc "M157-b 无 ruby + 无 js-yaml ⇒ 报「无法核验」而非「解析失败」" \
    "env -u DSH_APP_ROOT -u DSH_ASAR HOME='$work/m157home' DSH_CODEPUNK_TOOLS='$work/m157empty' PATH='$farm_noruby' bash plans/preset-audit.sh 2>&1 | grep -qF 'A1 无法核验（有 node 但候选链内未找到 js-yaml'" 0
  check_no_match "M157-b2 不得把环境缺口报成「A1 YAML 解析失败」" \
    "env -u DSH_APP_ROOT -u DSH_ASAR HOME='$work/m157home' DSH_CODEPUNK_TOOLS='$work/m157empty' PATH='$farm_noruby' bash plans/preset-audit.sh 2>&1" "A1 YAML 解析失败"
  check_rc "M157-c 桩返回非法结构 ⇒ 真损坏仍报「解析失败」（判据未被放宽）" \
    "STUB_A1=bad PATH='$farm_noruby' DSH_CODEPUNK_TOOLS='$work/m157tools' bash plans/preset-audit.sh 2>&1 | grep -qF 'A1 YAML 解析失败'" 0
  sed -i.bak 's/有 node 但候选链内未找到 js-yaml/（候选链判据已移除）/' "$work/cur/plans/preset-audit.sh"
  rm -f "$work/cur/plans/preset-audit.sh.bak"
  mutate_gone "preset-audit 抹掉候选链判据消息" "$work/cur/plans/preset-audit.sh" '有 node 但候选链内未找到 js-yaml'
  check_no_match "M157-d 判据移除 → 不得再报该消息（断言非空转）" \
    "env -u DSH_APP_ROOT -u DSH_ASAR HOME='$work/m157home' DSH_CODEPUNK_TOOLS='$work/m157empty' PATH='$farm_noruby' bash plans/preset-audit.sh 2>&1" "有 node 但候选链内未找到 js-yaml"
fi

echo "[M158 无 ruby 主机的 INDEX 语义类型判定（F352 / F353）]"
if [ ! -x "$farm_noruby/bash" ] || [ ! -e "$farm_noruby/node" ]; then
  skip 'M158 跳过：同 M157 的环境前提不成立'
else
  mkdir -p "$work/m158"
  printf 'schema_version: "1"\nprojects: {}\nlast_updated: "2026-10-08T00:00:00+07:00"\n' > "$work/m158/INDEX.yaml"
  # 桩 js-yaml 解析出的 `last_updated` 为 **Date**（真 js-yaml 默认 schema 的行为）：ruby 侧
  # 同样给 Time，而 ruby 判据是 `is_a?(Hash)/is_a?(Array)` ⇒ Date 属标量，不得判非法。
  check_no_match "M158-a 无 ruby：解析出的 Date 不得被判「须为标量」（F353 假红）" \
    "STUB_INDEX=date PATH='$farm_noruby' DSH_CODEPUNK_TOOLS='$work/m157tools' DSH_CODEPUNK_INDEX='$work/m158/INDEX.yaml' bash plans/dsh-codepunk-link.sh index 2>&1" "last_updated 须为标量"
  check_rc "M158-b 无 ruby：真非法（映射）仍报「INDEX 语义非法」" \
    "STUB_INDEX=bad PATH='$farm_noruby' DSH_CODEPUNK_TOOLS='$work/m157tools' DSH_CODEPUNK_INDEX='$work/m158/INDEX.yaml' bash plans/dsh-codepunk-link.sh index 2>&1 | grep -qF 'last_updated 须为标量'" 0
  # 变异须保持 JS 语法（直接删 `!(o instanceof Date)` 会留下 `&&;` ⇒ 语法错，判据以另一种方式消失）
  sed -i.bak 's/!(o instanceof Date)/true/' "$work/cur/plans/dsh-codepunk-link.sh"
  rm -f "$work/cur/plans/dsh-codepunk-link.sh.bak"
  mutate_gone "link 的 isPlain 去掉 Date 豁免" "$work/cur/plans/dsh-codepunk-link.sh" '!\(o instanceof Date\)'
  check_rc "M158-c 去掉 Date 豁免 → Date 被误判（断言非空转）" \
    "STUB_INDEX=date PATH='$farm_noruby' DSH_CODEPUNK_TOOLS='$work/m157tools' DSH_CODEPUNK_INDEX='$work/m158/INDEX.yaml' bash plans/dsh-codepunk-link.sh index 2>&1 | grep -qF 'last_updated 须为标量'" 0
fi

echo "[M159 必需检查的「文档声称 ↔ 作业实际执行」（F354）]"
# 守护点：doc-consistency.sh 的「CI 门禁表」子项。CONTRIBUTING 的门禁表若给出可执行等价命令，
# 该命令必须真被对应作业执行；声称覆盖 Windows 侧则作业段内须有 ps1 路径；指向电池项则电池须有该项。
# 本机可跑（纯文本判据，无外部依赖）。
fresh
sed -i.bak 's#\*\*不核验\*\* sh↔ps1 平台对等#POSIX 与 Windows 两侧实现的对等性#' "$work/cur/CONTRIBUTING.md"
rm -f "$work/cur/CONTRIBUTING.md.bak"
mutate "M159-a 门禁表声称覆盖 Windows 侧对等（旧文案）" \
  "$work/cur/CONTRIBUTING.md" 'POSIX 与 Windows 两侧实现的对等性'
check_rc "M159-a 旧声称须被报出" \
  "bash plans/doc-consistency.sh 2>&1 | grep -qF 'CI 门禁表与实现不符'" 0
check_rc "M159-a2 旧声称须给出具体不一致点" \
  "bash plans/doc-consistency.sh 2>&1 | grep -qF '声称覆盖 Windows 侧，而作业 portability 段内无任何 ps1 路径'" 0

fresh
sed -i.bak 's#`bash plans/doc-consistency.sh`#`bash plans/no-such-check.sh`#' "$work/cur/CONTRIBUTING.md"
rm -f "$work/cur/CONTRIBUTING.md.bak"
mutate "M159-b 门禁表等价命令改为不存在的脚本" \
  "$work/cur/CONTRIBUTING.md" 'plans/no-such-check\.sh'
check_rc "M159-b 不存在的等价命令须被报出" \
  "bash plans/doc-consistency.sh 2>&1 | grep -qF '等价命令 plans/no-such-check.sh 不存在'" 0

fresh
sed -i.bak 's#的 B10 跨平台性 |#的 B10 跨平台性；另见 `bash plans/verify-battery.sh` 的「跨平台」项 |#' "$work/cur/CONTRIBUTING.md"
rm -f "$work/cur/CONTRIBUTING.md.bak"
mutate "M159-c 门禁表指向电池不存在的项" \
  "$work/cur/CONTRIBUTING.md" '另见 `bash plans/verify-battery\.sh` 的「跨平台」项'
check_rc "M159-c 电池不存在的项须被报出" \
  "bash plans/doc-consistency.sh 2>&1 | grep -qF '指向电池的「跨平台」项'" 0

fresh
sed -i.bak 's/CI 门禁表与实现不符/（判据已移除）/' "$work/cur/plans/doc-consistency.sh"
rm -f "$work/cur/plans/doc-consistency.sh.bak"
mutate "M159-d 抹掉 F354 判据的消息串" \
  "$work/cur/plans/doc-consistency.sh" '（判据已移除）'
sed -i.bak 's#的 B10 跨平台性 |#的 B10 跨平台性；另见 `bash plans/verify-battery.sh` 的「跨平台」项 |#' "$work/cur/CONTRIBUTING.md"
rm -f "$work/cur/CONTRIBUTING.md.bak"
check_no_match "M159-d 判据被抹掉 → 不得再报该消息（断言非空转）" \
  "bash plans/doc-consistency.sh 2>&1" "CI 门禁表与实现不符"

echo "[M160 Dependabot 声明 ↔ 仓库与治理脚本（本轮巡检实测）]"
# 守护点：doc-consistency.sh 第 7 类的 Dependabot 子项。声明的生态须有对应清单（否则条目恒不产出 PR）、
# labels 引用的标签须由 plans/github-setup.sh 幂等创建（否则字段静默失效）、维护文档的生态清单须与声明一致。
# 本机可跑（纯文本判据，无外部依赖）。
fresh
printf '  - package-ecosystem: pip\n' >> "$work/cur/.github/dependabot.yml"
mutate "M160-a 重新声明 pip 生态（仓库无 pip 清单）" \
  "$work/cur/.github/dependabot.yml" 'package-ecosystem: pip'
check_rc "M160-a 声明生态无清单须被报出" \
  "bash plans/doc-consistency.sh 2>&1 | grep -qF '声明生态 pip 但仓库无对应清单'" 0

fresh
sed -i.bak 's/^      - dependencies$/      - deps-not-governed/' "$work/cur/.github/dependabot.yml"
rm -f "$work/cur/.github/dependabot.yml.bak"
mutate "M160-b labels 引用治理脚本未创建的标签" \
  "$work/cur/.github/dependabot.yml" 'deps-not-governed'
check_rc "M160-b 未受治理的标签须被报出" \
  "bash plans/doc-consistency.sh 2>&1 | grep -qF '未被 plans/github-setup.sh 创建'" 0

fresh
sed -i.bak 's/github-actions/gh-actions/' "$work/cur/docs/maintenance.md"
rm -f "$work/cur/docs/maintenance.md.bak"
mutate "M160-c 维护文档的生态清单与声明不符" \
  "$work/cur/docs/maintenance.md" 'gh-actions'
check_rc "M160-c 文档未提及声明生态须被报出" \
  "bash plans/doc-consistency.sh 2>&1 | grep -qF '未提及声明的生态'" 0

fresh
sed -i.bak 's#Dependabot 配置与仓库/治理脚本不符#（判据已移除）#' "$work/cur/plans/doc-consistency.sh"
rm -f "$work/cur/plans/doc-consistency.sh.bak"
mutate "M160-d 抹掉 Dependabot 判据的消息串" \
  "$work/cur/plans/doc-consistency.sh" '（判据已移除）'
printf '  - package-ecosystem: pip\n' >> "$work/cur/.github/dependabot.yml"
check_no_match "M160-d 判据被抹掉 → 不得再报该消息（断言非空转）" \
  "bash plans/doc-consistency.sh 2>&1" "Dependabot 配置与仓库/治理脚本不符"

echo "[M161 运行型脚本 MUST 实现 -h/--help（doc-consistency 第 20 类静态子项，本轮巡检实测）]"
# 守护点：探针表是人工枚举，新增脚本极易漏挂（本轮实测 4 个实现者不在表内）；静态子项以源码为准。
fresh
sed -i.bak 's/^  -h|--help) sed -n/  --no-such-flag) sed -n/' "$work/cur/plans/evidence-verify.sh"
rm -f "$work/cur/plans/evidence-verify.sh.bak"
mutate "M161-a 抹掉 evidence-verify 的 -h 分支" \
  "$work/cur/plans/evidence-verify.sh" '\-\-no-such-flag\)'
check_rc "M161-a 缺 -h 实现须被报出" \
  "bash plans/doc-consistency.sh 2>&1 | grep -qF '未实现 -h/--help 用法约定: evidence-verify.sh'" 0
fresh
check_rc "M161-b 干净副本不得报该缺口（断言非空转）" \
  "bash plans/doc-consistency.sh 2>&1 | grep -qF '未实现 -h/--help 用法约定'" 1

echo "[M162 INDEX 骨架模板单一来源（doc-consistency 第 25 类，本轮巡检实测）]"
# 守护点：link.sh 与 init.sh 是同一制品（总库 INDEX.yaml 骨架）的两处生成器，
#   且 init 见文件已存在即跳过 ⇒ 模板不一致时终态取决于「谁先建文件」（F360 实证）。
fresh
sed -i.bak 's/^# dsh-codepunk 统一总库 · 全局注册表 INDEX.yaml（骨架模板，init 内置）$/# 骨架模板（变异版）/' \
  "$work/cur/plans/dsh-codepunk-init.sh"
rm -f "$work/cur/plans/dsh-codepunk-init.sh.bak"
mutate "M162-a init 侧骨架头被变异" \
  "$work/cur/plans/dsh-codepunk-init.sh" '骨架模板（变异版）'
check_rc "M162-a 骨架漂移须被报出" \
  "bash plans/doc-consistency.sh 2>&1 | grep -qF 'INDEX 骨架模板漂移'" 0
fresh
check_rc "M162-b 干净副本须报单一来源（断言非空转）" \
  "bash plans/doc-consistency.sh 2>&1 | grep -qF 'INDEX 骨架模板单一来源'" 0

echo "[M163 外部输入变量须被记载（doc-consistency 第 5 类子项，本轮巡检实测）]"
# 守护点：未在本文件赋值、或写成 `${VAR:-默认}` 的覆盖开关 MUST 被记载（任一 .md 或头部注释块）。
# 夹具注意：变量名与 `${…:-…}` 形态 MUST 在运行期拼出——若把该形态逐字写在**本文件**里，
# 守护会把它当成本文件（`plans/checker-self-test.sh`）的一处「未记载覆盖开关」而误报（实测：
# 逐字写法使干净副本 rc=1、M163-b 失败），属夹具自伤而非守护缺陷。
fresh
m163_var=ZZZ_UNDOCUMENTED_OVERRIDE
printf '\n# 注入：未记载的覆盖开关\n: "${%s:-x}"\n' "$m163_var" >> "$work/cur/plans/git-merge-flow.sh"
mutate "M163-a 注入未记载的环境变量覆盖" \
  "$work/cur/plans/git-merge-flow.sh" 'ZZZ_UNDOCUMENTED_OVERRIDE'
check_rc "M163-a 未记载变量须被报出" \
  "bash plans/doc-consistency.sh 2>&1 | grep -qF '外部输入变量未被记载'" 0
check_rc "M163-a2 须列出变量名与位置" \
  "bash plans/doc-consistency.sh 2>&1 | grep -qF 'ZZZ_UNDOCUMENTED_OVERRIDE'" 0
fresh
check_rc "M163-b 干净副本须报均被记载（断言非空转）" \
  "bash plans/doc-consistency.sh 2>&1 | grep -qF '外部输入变量均被记载'" 0

echo "[M164 写盘护栏拦截层（hooks）行为契约（轮次 628 接入实测）]"
# 守护点：`plans/hook-write-scope.py`（PreToolUse 命令钩子；配置 `plans/hooks/hooks.json`，
#   条目 `agent.cordis.yml` 的 `hooks-write-scope`）。三条断言：
#   a) denylist 路径作 `write.file_path` ⇒ **退出码 2** 且 stderr 含**规则名**（阻断语义 + 理由可读）；
#   b) 预设仓库内路径 ⇒ **退出码 0**（放行集不被误拦）；
#   c) 非空转：抹掉阻断分支（`return EXIT_BLOCK` → `return EXIT_ALLOW`）后，a 的规则名**不得再出现**
#      ——若仍出现，说明断言命中的是别处的回显而非真实阻断路径（守卫空转）。
# 夹具纪律（类 14）：denylist 路径与规则名一律**运行时拼接**，不在本文件写出可被本仓守卫命中的字面量；
#   载荷经 `--fixture <文件>` 传入（避免管道，且 hook 自身以 `-h` 作帮助开关）。
fresh
m164_home="$work/cur/.m164home"
m164_dir="$(printf '%s%s' '.' 'ssh')"
m164_name="$(printf '%s_%s' 'id' 'ed25519')"
mkdir -p "$m164_home/$m164_dir"
m164_path="$m164_home/$m164_dir/$m164_name"
printf '{"session_id":"m164","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"write","tool_input":{"file_path":"%s"}}' \
  "$work/cur" "$m164_path" > "$work/cur/m164-deny.json"
printf '{"session_id":"m164","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"write","tool_input":{"file_path":"%s"}}' \
  "$work/cur" "$work/cur/plans/hook-write-scope.py" > "$work/cur/m164-allow.json"
m164_rule="$(printf '%s%s' '凭据' '目录')"
check_rc "M164-a denylist 路径须阻断（rc=2）" \
  "HOME='$m164_home' python3 plans/hook-write-scope.py --fixture m164-deny.json 2>&1" 2 "$m164_rule"
mutate "M164-a 断言依赖的规则名确在 hook 源码内" \
  "$work/cur/plans/hook-write-scope.py" "$m164_rule"
check_rc "M164-b 预设仓库内路径须放行（rc=0）" \
  "HOME='$m164_home' python3 plans/hook-write-scope.py --fixture m164-allow.json 2>&1" 0
# F367（本轮巡检实测）：黑名单比对曾有两条**静默绕过**（未命中即放行，无任何提示）——
#   d) `//etc/hosts`：POSIX 归一（`posixpath.normpath`）**保留前导双斜杠** ⇒ 与根 `/etc` 的字面
#      前缀比对不成立，而 POSIX 平台上它就是 `/etc/hosts`（同一文件）；
#   e) 大小写变体 `/ETC/hosts`：macOS 默认卷（APFS/HFS+）不区分大小写 ⇒ 同一文件。
#   两者现已归一（折叠前导多斜杠 + 不敏感平台比对折叠），并**写进契约 §8.3/§8.4**。
#   位置纪律：本段 MUST 排在下方 `fresh` + M164-c 变异**之前**——M164-c 会把阻断分支抹掉，
#   排在它之后的断言实际运行在「阻断已失效」的副本里（首版即因此假红，见自纠记录）。
m164_sys="$(printf '/%s/%s' '' 'etc/hosts')"                       # ⇒ //etc/hosts
printf '{"session_id":"m164d","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"write","tool_input":{"file_path":"%s"}}' \
  "$work/cur" "$m164_sys" > "$work/cur/m164-slash.json"
m164_rule_sys="$(printf '%s%s' '系统' '路径')"
check_rc "M164-d 前导双斜杠路径须阻断（rc=2，F367）" \
  "HOME='$m164_home' python3 plans/hook-write-scope.py --fixture m164-slash.json 2>&1" 2 "$m164_rule_sys"
# 大小写变体只在**大小写不敏感平台**成立（linux 上 `/ETC/hosts` 确是另一个路径，护栏按设计放行）
case "$(uname -s)" in
  Darwin|MINGW*|MSYS*|CYGWIN*)
    m164_up="$(printf '/%s/%s' 'ETC' 'hosts')"
    printf '{"session_id":"m164e","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"write","tool_input":{"file_path":"%s"}}' \
      "$work/cur" "$m164_up" > "$work/cur/m164-case.json"
    check_rc "M164-e 大小写变体路径须阻断（rc=2，F367，不敏感卷）" \
      "HOME='$m164_home' python3 plans/hook-write-scope.py --fixture m164-case.json 2>&1" 2 "$m164_rule_sys"
    ;;
  *)
    echo "  ℹ M164-e 跳过（大小写敏感平台：该路径确为另一文件，护栏按设计放行）——跳过 ≠ 通过"
    ;;
esac
fresh
sed -i.bak 's/^            return EXIT_BLOCK$/            return EXIT_ALLOW/' "$work/cur/plans/hook-write-scope.py"
rm -f "$work/cur/plans/hook-write-scope.py.bak"
mutate_gone "M164-c 阻断分支已被抹掉（源码内不再有 return EXIT_BLOCK）" \
  "$work/cur/plans/hook-write-scope.py" 'return EXIT_BLOCK'
check_no_match "M164-c 阻断分支被抹掉 → 不得再命中该规则名（断言非空转）" \
  "HOME='$m164_home' python3 plans/hook-write-scope.py --fixture m164-deny.json 2>&1" "$m164_rule"

# ── M165：emit 管道完整性（F362：`process.exit` 丢弃管道缓冲致输出截断）──────
if command -v node >/dev/null 2>&1; then
  fresh
  # 源填充至 >64 KiB（管道缓冲），确保截断可被观测（不依赖当前源体积）
  i=0
  while [ "$i" -lt 2000 ]; do printf '# filler %s\n' "$i"; i=$((i + 1)); done >> "$work/cur/agent.cordis.yml"
  m165_cmd='a=$(node plans/preset-declare.mjs emit | wc -c); node plans/preset-declare.mjs emit > "$work/m165.yml"; b=$(wc -c < "$work/m165.yml"); if [ "$a" = "$b" ]; then echo "PIPE_OK a=$a"; else echo "✗ emit 管道截断 a=$a b=$b"; exit 1; fi'
  check_rc "M165-a emit 管道输出须与文件重定向等长" "$m165_cmd" 0 "PIPE_OK"
  m165_before=$(grep -c 'process.stdout.write' "$work/cur/plans/preset-declare.mjs" || true)
  sed -i.bak 's/writeSync(1, renderBlock/process.stdout.write(renderBlock/' "$work/cur/plans/preset-declare.mjs"
  m165_after=$(grep -c 'process.stdout.write' "$work/cur/plans/preset-declare.mjs" || true)
  if [ "$m165_after" -gt "$m165_before" ]; then
    echo "  · M165-b 变异落地（process.stdout.write ${m165_before} → ${m165_after}）"
  else
    printf '  ‼ 变异未生效（M165-b：emit 退回异步写）——自检自身问题，非守护问题\n' >&2
    MUTFAIL=1
  fi
  check_rc "M165-b 管道截断须被检出" "$m165_cmd" 1 "管道截断"
else
  echo "  ℹ M165 跳过（缺 node）——跳过 ≠ 通过"
fi

# ── M166：未来日期判据须容忍时区偏移（F365：CI 为 UTC 时钟，作者本地「今天」被判未来 ⇒ 合法 PR 假红）──
if command -v python3 >/dev/null 2>&1; then
  fresh
  # 用**相对当前 UTC 日期**派生边界，避免硬编码日期随时间失效（F300 家族教训）
  m166_d1=$(python3 -c "import datetime;print((datetime.datetime.now(datetime.timezone.utc).date()+datetime.timedelta(days=1)).isoformat())")
  m166_d2=$(python3 -c "import datetime;print((datetime.datetime.now(datetime.timezone.utc).date()+datetime.timedelta(days=2)).isoformat())")
  m166_f="$work/cur/skills/dsh-codepunk-workflow/references/standard.md"
  cp "$m166_f" "$work/m166.orig"
  printf '\n<!-- 时区边界探针 %s -->\n' "$m166_d1" >> "$m166_f"
  mutate "M166-a 注入 UTC 今天 +1 天（时区偏移内的合法日期）" "$m166_f" "$m166_d1"
  check_rc "M166-a 时区偏移内的日期不得判未来" "TZ=UTC bash plans/doc-consistency.sh 2>&1" 0 "无未来日期"
  cp "$work/m166.orig" "$m166_f"
  printf '\n<!-- 时区边界探针 %s -->\n' "$m166_d2" >> "$m166_f"
  mutate "M166-b 注入 UTC 今天 +2 天（真实未来日期）" "$m166_f" "$m166_d2"
  check_rc "M166-b 超出容忍上限的日期须报未来" "TZ=UTC bash plans/doc-consistency.sh 2>&1" 1 "未来日期: "
else
  echo "  ℹ M166 跳过（缺 python3）——跳过 ≠ 通过"
fi

# ── M167：用法约定的**域**含非 shell 入口（F366：`.py`/`.mjs` 此前整体不在第 20 类）────
# 守护点：`doc-consistency.sh` 第 20 类静态子项（`for f in plans/*.sh plans/*.py plans/*.mjs`）。
#   变异＝抹掉 `plans/ps-validate.mjs` 的 `-h` 字面量（`.mjs` 入口：旧域 `plans/*.sh` 看不见它）
#   ⇒ 该子项须报出，且探针表里的 `ps-validate -h` 也会漂移（两条 `bad` 同时给出，rc=1）。
if command -v node >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  fresh
  m167_cmd="bash plans/doc-consistency.sh"
  check_rc "M167-a 基线：域内全部入口有 -h 分支（rc=0）" "$m167_cmd" 0 "无硬性不一致"
  # M167-c：帮助**不得依赖可选依赖**（CI 实测：`ps-validate.mjs` 未装 tree-sitter 时旧位置先
  #   `exit 2` ⇒ 本机 rc=0、CI rc=2；帮助分支 MUST 排在依赖解析之前）。用无 node_modules 的 HOME 造境。
  check_rc "M167-c 帮助不依赖可选依赖（无依赖的 HOME 下 -h 仍 rc=0）" \
    "HOME='$work/cur/.m167empty' node plans/ps-validate.mjs -h" 0 "用法: node ps-validate.mjs"
  m167_before=$(grep -c -- "'-h'" "$work/cur/plans/ps-validate.mjs" || true)
  # 变异锚点＝**字面量本身**（`'-h'` → `'-x'`），不绑变量名：首版锚定 `files.includes('-h')`，
  #   而该分支提升到依赖解析之前时变量已改名 `argvFiles` ⇒ sed 不落地（MUTFAIL 报「1 → 1」）。
  sed -i.bak "s/'-h'/'-x'/" "$work/cur/plans/ps-validate.mjs"
  m167_after=$(grep -c -- "'-h'" "$work/cur/plans/ps-validate.mjs" || true)
  mutate "M167-b 变异落地（ps-validate.mjs 的 '-h' 字面量 ${m167_before} → ${m167_after}）" \
    "$work/cur/plans/ps-validate.mjs" "'-x'"
  check_rc "M167-b 非 shell 入口缺 -h 分支须被第 20 类捕获（rc=1）" "$m167_cmd" 1 \
    "运行型入口未实现 -h/--help 用法约定"
else
  echo "  ℹ M167 跳过（缺 node 或 python3）——跳过 ≠ 通过"
fi

# ── M168：钩子配置（产品启动时经 `configPath` 读取）须有门禁守护（F368）──────────────
# 守护点：`doc-consistency.sh` 第 7 类子项「钩子配置完整性」。
#   实测（加守护前）：把 `plans/hooks/hooks.json` 截断为非法 JSON、或把命令路径改成不存在的文件，
#   doc·audit·score·preset-compat·write-scope **五个门禁全绿**且零处提到 hooks ⇒ 拦截层静默消失
#   而无任何红灯（产品侧只有一条 `logger.warn(… — no hooks registered)`）。
#   断言顺序纪律：同一变异的断言 MUST 排在其 `fresh` 之前（否则跑在已变异副本上）。
if command -v python3 >/dev/null 2>&1; then
  fresh
  check_rc "M168-a 基线：钩子配置完整（rc=0）" "bash plans/doc-consistency.sh" 0 "钩子配置完整"
  printf '{\n  "hooks": {\n    "PreToolUse": [ { "matcher": "write|edit",\n' > "$work/cur/plans/hooks/hooks.json"
  mutate "M168-b 变异落地（hooks.json 截断为非法 JSON）" "$work/cur/plans/hooks/hooks.json" '"hooks"'
  check_rc "M168-b 钩子配置非法 JSON 须被捕获（rc=1）" "bash plans/doc-consistency.sh" 1 "不是合法 JSON"
  fresh
  sed -i.bak 's/hook-write-scope\.py/hook-write-scope-TYPO.py/' "$work/cur/plans/hooks/hooks.json"
  mutate "M168-c 变异落地（命令路径改指不存在的文件）" "$work/cur/plans/hooks/hooks.json" 'TYPO'
  check_rc "M168-c 命令引用的仓库内文件不存在须被捕获（rc=1）" "bash plans/doc-consistency.sh" 1 \
    "命令引用的仓库内文件不存在"
  fresh
  sed -i.bak 's/"python3 /"python9 /' "$work/cur/plans/hooks/hooks.json"
  mutate "M168-d 变异落地（解释器改指不存在的命令）" "$work/cur/plans/hooks/hooks.json" 'python9'
  check_rc "M168-d 解释器不在 PATH 须被捕获（rc=1，失败开放须红灯）" "bash plans/doc-consistency.sh" 1 \
    "不在 PATH"
else
  echo "  ℹ M168 跳过（缺 python3）——跳过 ≠ 通过"
fi

# ── M169：扫描工具缺失时写盘纪律门 MUST 显式失败（F372）──────────────────────
#   机理：G1/G2/G3 经 `find … 2>/dev/null` 的**进程替换**取列表 ⇒ `find` 不在 PATH 时列表为空、
#   三项均判「无残留」⇒ rc=0 假绿（与本文件头部契约「2=无法核验」冲突）。
#   断言：a) 完好版 + 无 find 的 PATH ⇒ rc=2 含「缺少必需工具 find」；
#        b) 删掉该预检守护后同环境 ⇒ rc=0「写盘纪律门：通过」（证明假绿确由缺守护造成）。
mkdir -p "$work/bin-nofind"
for _t in bash sh git grep sed awk python3 mktemp stat sort uniq wc tr head tail basename dirname ls cat chmod cmp install locale; do
  _p="$(command -v "$_t" 2>/dev/null)" || continue
  [ -n "$_p" ] && ln -sf "$_p" "$work/bin-nofind/$_t"
done
if [ -x "$work/bin-nofind/bash" ] && [ ! -e "$work/bin-nofind/find" ]; then
  fresh
  check_rc "M169-a 扫描工具缺失（PATH 无 find）须 rc=2（无法核验 ≠ 通过）" \
    "env -i PATH=\"$work/bin-nofind\" HOME=\"$HOME\" \"$work/bin-nofind/bash\" plans/write-scope-check.sh --repo ." 2 \
    "缺少必需工具 find"
  fresh
  sed -i.bak '/缺少必需工具 find ⇒ 无法扫描仓库/d; /find 不可用（预检执行失败）/d' "$work/cur/plans/write-scope-check.sh"
  mutate_gone "M169-b 删除型变异（移除 find 预检守护）" "$work/cur/plans/write-scope-check.sh" '缺少必需工具 find ⇒ 无法扫描仓库'
  check_rc "M169-b 移除守护后同环境须复现假绿 rc=0（证明守护非空转）" \
    "env -i PATH=\"$work/bin-nofind\" HOME=\"$HOME\" \"$work/bin-nofind/bash\" plans/write-scope-check.sh --repo ." 0 \
    "写盘纪律门：通过"
else
  echo "  ℹ M169 跳过（无法构造无 find 的影子 PATH）——跳过 ≠ 通过"
fi

# M170（F373）：doc 类数声称陈旧须被第 1 类的派生核验捕获（`doc-consistency.sh` 同行「N 类」）。
#   变异按**地址**（`/doc-consistency/`）改写，不与具体数字绑定 ⇒ 将来类数变化不会让变异静默失效
#   （F300 教训）；另有断言证明**序数**写法（`doc-consistency.sh 第 10 类`）不被误当类数声称 —— 该假阳性
#   在实现迭代中实测出现过（docs/documentation-policy.md 报 10 处）。
fresh
check_no_match "M170-c 基线：序数写法（第 N 类）不得被当作类数声称" "bash plans/doc-consistency.sh" "doc 类数声称陈旧"
sed -i.bak -E '/doc-consistency/ s/(\*\*)?[0-9]+ 类(\*\*|：)/**99 类**/' "$work/cur/docs/architecture.md"
mutate "M170-a 篡改 docs/architecture.md 的 doc 类数声称（→ 99 类）" "$work/cur/docs/architecture.md" '99 类'
check_rc "M170-a doc 类数声称陈旧 → 须报错（证明守护非空转）" "bash plans/doc-consistency.sh" 1 "doc 类数声称陈旧"
fresh
check_rc "M170-b 基线：doc 类数声称与实现一致" "bash plans/doc-consistency.sh" 0 "doc 类数声称与实现一致"

echo "[M172 派生计数表「当前实况」列须与实现一致（F375）]"
fresh
sed -i.bak -E '/^\| 变异项数 \|/ s/\| [0-9]+（M1–M[0-9]+） \|/| 99（M1–M99） |/' "$work/cur/docs/development.md"
mutate "M172-a 篡改派生计数表的变异项数实况（→ 99）" "$work/cur/docs/development.md" '99（M1–M99）'
check_rc "M172-a 派生计数表实况陈旧 → 须报错（证明守护非空转）" "bash plans/doc-consistency.sh" 1 "派生计数表实况陈旧"
fresh
check_rc "M172-b 基线：派生计数表实况与实现一致" "bash plans/doc-consistency.sh" 0 "派生计数表实况与实现一致"

echo "[M171 自检结论须据实报告覆盖（F374）]"
# 快速路径：`--coverage-echo` 复用主路径的 `coverage_line`，秒级断言，不跑整轮（整轮约 5 分钟）。
check_rc "M171-a 有跳过时结论须报「捕获 N/M … 跳过 K（跳过 ≠ 通过）」" \
  "DSH_CODEPUNK_ECHO_SKIPPED=3 bash plans/checker-self-test.sh --coverage-echo" 0 "跳过 3 项（跳过 ≠ 通过）"
check_no_match "M171-b 有跳过时不得称「全部变异均被对应检查项捕获」" \
  "DSH_CODEPUNK_ECHO_SKIPPED=3 bash plans/checker-self-test.sh --coverage-echo" "全部变异均被对应检查项捕获"
check_rc "M171-c 无跳过时结论保持「全部变异均被对应检查项捕获」" \
  "bash plans/checker-self-test.sh --coverage-echo" 0 "全部变异均被对应检查项捕获"
fresh
# 变异标记须**唯一**：本脚本别处已有 `if false; then`，用裸串做落地断言会假通过（实测 grep -c = 3）。
sed -i.bak 's/if \[ "${2:-0}" -gt 0 \]; then/if false; then  # F374-COV-MUT/' "$work/cur/plans/checker-self-test.sh"
mutate "M171-d 变异（覆盖分支恒假）" "$work/cur/plans/checker-self-test.sh" 'F374-COV-MUT'
check_rc "M171-d 覆盖分支被破坏后同命令须复现旧文案（证明分支非空转）" \
  "DSH_CODEPUNK_ECHO_SKIPPED=3 bash plans/checker-self-test.sh --coverage-echo" 0 "全部变异均被对应检查项捕获"

echo "[M173 运行根 write_scope 台账段（R17/F377）]"
# 契约：references/artifacts.md §1.3 —— 运行根 README MUST 含 `write_scope:` 段（5 键：
#   run_id / allowed_prefixes / created / cleanup_status / exempt），且 `cleanup_status: clean`
#   是交接门与合并门的前置读数。夹具全部在沙箱内自建 ⇒ 不依赖本席真实运行根。
fresh
RR1="$work/rr-noblock"
mkdir -p "$RR1"
printf '# 运行根（夹具）\n\n## 说明\n\n本夹具**故意不含** write_scope 段。\n' > "$RR1/README.md"
check_rc "M173-a 运行根 README 缺 write_scope 段 → 须 rc=1（R17 MUST）" \
  "bash plans/write-scope-check.sh --run-root \"$RR1\"" 1 "缺 write_scope: 段"
RR2="$work/rr-ok"
mkdir -p "$RR2"
{
  printf '# 运行根（夹具）\n\n```yaml\n'
  printf 'write_scope:\n'
  printf '  run_id: run-fixture\n'
  printf '  allowed_prefixes:\n    - "logs/"\n'
  printf '  created:\n    - "logs/x"\n'
  printf '  cleanup_status: clean\n'
  printf '  exempt: []\n'
  printf '```\n'
} > "$RR2/README.md"
check_rc "M173-b write_scope 段 5 键齐备 → 须 rc=0" \
  "bash plans/write-scope-check.sh --run-root \"$RR2\"" 0 "write_scope 段 5 键齐备"
RR3="$work/rr-misskey"
mkdir -p "$RR3"
grep -v '^  exempt:' "$RR2/README.md" > "$RR3/README.md"
check_rc "M173-c 段缺键（exempt）→ 须 rc=1 报缺键" \
  "bash plans/write-scope-check.sh --run-root \"$RR3\"" 1 "write_scope 段缺键"
check_rc "M173-d 运行根目录不存在 → 须 rc=2（无法核验 ≠ 通过）" \
  "bash plans/write-scope-check.sh --run-root \"$work/no-such-run-root\"" 2 "运行根不存在"
fresh
# 非空转证明：删掉「缺键判据」那一行 ⇒ 同 c 夹具须不再报缺键（rc=0）。
# 注：直接**删除**该行会让 `for` 循环体为空 ⇒ 语法错（实测 rc=2）；故改为把 grep 判据换成 `true`，
#   循环体仍合法、MISS 永不置位 —— 等价于「键校验失效」。
sed -i.bak 's|grep -qE "^\[\[:space:\]\]+\${k}:"|true  # F377-KEYS-MUT|' "$work/cur/plans/write-scope-check.sh"
mutate "M173-e 变异（缺键判据失效）" "$work/cur/plans/write-scope-check.sh" 'F377-KEYS-MUT'
check_rc "M173-e 缺键判据被移除后同夹具须复现 rc=0（证明键校验非空转）" \
  "bash plans/write-scope-check.sh --run-root \"$RR3\"" 0 "write_scope 段 5 键齐备"

echo "[M174 声明写入的**原子性**（F380：就地截断写 vs 临时文件 + rename）]"
# 契约：`plans/preset-declare.mjs` 的 apply 写用户平面 profile 补丁时 MUST 原子替换
#   （写同目录临时文件后 rename），且 MUST 保留原文件权限位。
#   判据用**可确定观测的不变量**：原子替换会更换目录项 ⇒ 目标 inode 必变；就地写 inode 不变。
#   （非空转证明见 b：把 rename 换成 copyFileSync 后就地覆盖 ⇒ inode 不变 ⇒ 断言失败。）
if command -v node >/dev/null 2>&1; then
  fresh
  m174_p="$work/m174.yml"
  : > "$m174_p"                                  # apply --append 要求目标文件已存在（空文件=首次安装）
  node plans/preset-declare.mjs apply --append --patch "$m174_p" >/dev/null 2>&1
  sed -i.bak 's/order: 5/order: 6/' "$m174_p"; rm -f "$m174_p.bak"      # 迫使下一次 apply 真的重写
  m174_inode_before=$(ls -i "$m174_p" | awk '{print $1}')
  m174_mode_before=$(ls -l "$m174_p" | awk '{print $1}')
  m174_cmd='a=$(ls -i "$work/m174.yml" | awk "{print \$1}"); '
  m174_cmd="$m174_cmd"'(cd "$work/cur" && node plans/preset-declare.mjs apply --patch "$work/m174.yml" >/dev/null); '
  m174_cmd="$m174_cmd"'b=$(ls -i "$work/m174.yml" | awk "{print \$1}"); '
  m174_cmd="$m174_cmd"'m=$(ls -l "$work/m174.yml" | awk "{print \$1}"); '
  m174_cmd="$m174_cmd"'if [ "$a" != "$b" ] && [ "$m" = "$m174_mode0" ]; then '
  m174_cmd="$m174_cmd"'echo "ATOMIC_OK inode $a -> $b mode $m"; else '
  m174_cmd="$m174_cmd"'echo "✗ 非原子写（inode ${a} -> ${b}）或权限漂移（${m}）"; exit 1; fi'
  m174_mode0="$m174_mode_before"
  check_rc "M174-a apply 须原子替换（inode 变更）且保留权限位" "$m174_cmd" 0 "ATOMIC_OK"
  m174_hits=$(grep -c 'renameSync(tmp, PATCH)' "$work/cur/plans/preset-declare.mjs" || true)
  sed -i.bak 's/renameSync(tmp, PATCH);/copyFileSync(tmp, PATCH);/' "$work/cur/plans/preset-declare.mjs"
  rm -f "$work/cur/plans/preset-declare.mjs.bak"
  mutate_gone "M174-b 原子替换已被替换为就地覆盖（源码内不再有 renameSync(tmp, PATCH)）" \
    "$work/cur/plans/preset-declare.mjs" 'renameSync(tmp, PATCH)'
  check_rc "M174-b 就地覆盖后同命令须复现 inode 不变（证明断言非空转）" "$m174_cmd" 1 "非原子写"
else
  skip "M174 跳过（缺 node：无法演示 apply 的写入语义）"
fi

echo "[M175 hooks 覆盖清单：\`sed -i\` 全族与 \`perl -i\`（F381）]"
# 契约：references/file-hygiene.md §8.3「覆盖」列明 `sed -i` 全族（含 `-i.bak`/`-i''`/`--in-place`）
#   与 `perl -i`、重定向 `>|`。判据：这些形态写 denylist 路径必须被阻断（rc=2 且含规则名）。
#   夹具纪律（类 14）：denylist 路径与规则名一律运行时拼接，不在本文件写出可命中的字面量。
m175_rule="$(printf '%s%s' '系统' '路径')"
m175_sys="$(printf '/%s/%s' 'etc' 'hosts')"
fresh
printf '{"session_id":"m175","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"bash","tool_input":{"command":"sed -i.bak \\"s/a/b/\\" %s"}}' \
  "$work/cur" "$m175_sys" > "$work/cur/m175-sed.json"
check_rc "M175-a \`sed -i.bak\` 形态须阻断（rc=2）" \
  "python3 plans/hook-write-scope.py --fixture m175-sed.json 2>&1" 2 "$m175_rule"
printf '{"session_id":"m175","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"bash","tool_input":{"command":"perl -i -pe \\"s/a/b/\\" %s"}}' \
  "$work/cur" "$m175_sys" > "$work/cur/m175-perl.json"
check_rc "M175-a2 \`perl -i\` 形态须阻断（rc=2，此前未覆盖）" \
  "python3 plans/hook-write-scope.py --fixture m175-perl.json 2>&1" 2 "$m175_rule"
python3 - "$work/cur/plans/hook-write-scope.py" <<'PYEOF'
import io, sys
p = sys.argv[1]
t = io.open(p, encoding='utf-8').read()
old = r'(?P<suf>[^\s]*)'
n = t.count(old)
assert n >= 1, '锚点未找到（变异不可靠）'
io.open(p, 'w', encoding='utf-8').write(t.replace(old, r'(?P<suf>[A-Za-z]*)'))
print('  · M175-b 变异落地（%d 处后缀判据收窄为字母）' % n)
PYEOF
mutate "M175-b 变异（把 \`-i\` 后缀判据收窄回字母）" \
  "$work/cur/plans/hook-write-scope.py" 'P<suf>\[A-Za-z\]\*'
check_no_match "M175-b 后缀判据收窄后 \`sed -i.bak\` 不得再被阻断（证明该覆盖非空转）" \
  "python3 plans/hook-write-scope.py --fixture m175-sed.json 2>&1" "$m175_rule"

echo "[M176 巡检名册字段契约（F382：每条须齐备 \`round\`/\`at\`/\`note\`）]"
# 契约：references/artifacts.md 的 D095/D099 要求运行根 `agents.yaml` 的 `patrol_log` 每条齐备
#   `round`/`at`/`note`（旧形态 `{round, checked, result}` 缺 at/note 却无任何机械门）。
#   判据实现：plans/patrol-check.sh --run-root（字段齐备 / 唯一 / 间隔 ≤ N）。
fresh
m176_rr="$work/runroot"
mkdir -p "$m176_rr"
cat > "$m176_rr/agents.yaml" <<'YAML'
run_id: run-m176
patrol_every_n_rounds: 5
patrol_log:
  - round: 10
    at: "2026-10-08T00:00:00Z"
    note: "巡检：夹具 A（list_agents ⇒ 无中断席）"
  - round: 15
    at: "2026-10-08T00:05:00Z"
    note: "巡检：夹具 B（list_agents ⇒ 无中断席）"
seats: []
YAML
check_rc "M176-a 合规名册须通过（rc=0）" \
  "bash plans/patrol-check.sh --run-root \"$m176_rr\"" 0 "巡检名册合规"
sed -i.bak '/^    at: /d' "$m176_rr/agents.yaml"; rm -f "$m176_rr/agents.yaml.bak"
mutate_gone "M176-b 删除型变异落地（夹具内 \`at\` 字段已消失）" "$m176_rr/agents.yaml" '^    at: '
check_rc "M176-b 缺 \`at\` 须被报出（rc=1）" \
  "bash plans/patrol-check.sh --run-root \"$m176_rr\"" 1 "缺 at"
# 非空转证明：把「缺 at」判据行短路（`[ -n \"\$v_at\" ]` → `true`）⇒ 同一夹具不得再报该消息。
sed -i.bak 's|\[ -n "\$v_at" \]|true  # F382-MUT|' "$work/cur/plans/patrol-check.sh"
rm -f "$work/cur/plans/patrol-check.sh.bak"
mutate "M176-c 变异（缺 at 判据被短路）" "$work/cur/plans/patrol-check.sh" 'F382-MUT'
check_no_match "M176-c 判据短路后不得再报「缺 at」（证明该判据非空转）" \
  "bash plans/patrol-check.sh --run-root \"$m176_rr\"" "缺 at"

echo "[M177 hooks 真实路径归一（F383：/etc 与 /private/etc、符号链接同文件须同判）]"
# 契约：references/file-hygiene.md §8.2 的黑名单是**文件**级承诺（系统路径不得由工具写入）。
#   macOS 的 `/etc` 是 `/private/etc` 的符号链接（实测同一 inode）⇒ 只做字面前缀比对时，
#   等价写法（`/private/etc/hosts`、指向该文件的符号链接）静默放行。判据：符号链接指向黑名单
#   文件时必须阻断（跨平台成立，不依赖 /private）。夹具纪律（类 14）：路径与规则名运行时拼接。
m177_rule="$(printf '%s%s' '系统' '路径')"
m177_sys="$(printf '/%s/%s' 'etc' 'hosts')"
fresh
m177_lnk="$work/lnk-system-path"
ln -sf "$m177_sys" "$m177_lnk" 2>/dev/null
if [ -L "$m177_lnk" ]; then
  printf '{"session_id":"m177","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"write","tool_input":{"file_path":"%s"}}' \
    "$work/cur" "$m177_lnk" > "$work/cur/m177-link.json"
  check_rc "M177-a 符号链接指向黑名单文件须阻断（rc=2，真实路径归一）" \
    "python3 plans/hook-write-scope.py --fixture m177-link.json 2>&1" 2 "$m177_rule"
  sed -i.bak 's|return case_fold(os.path.realpath(s))|return case_fold(s)  # F383-MUT|' "$work/cur/plans/hook-write-scope.py"
  rm -f "$work/cur/plans/hook-write-scope.py.bak"
  mutate "M177-b 变异（realpath 归一被移除）" "$work/cur/plans/hook-write-scope.py" 'F383-MUT'
  check_rc "M177-b 移除归一后同一夹具须复现放行（rc=0，证明该判据非空转）" \
    "python3 plans/hook-write-scope.py --fixture m177-link.json 2>&1" 0 ""
else
  skip "M177 夹具未能建立符号链接"
fi

echo "[M178 命令实参不得顶替路径（F384：chmod/truncate/chown 族须取到真目标）]"
# 契约：file-hygiene.md §8.3 列明覆盖 `chmod`/`chown`/`truncate`/`rm` 等写命令。判据：这些命令的
#   首位位置参数若是**实参**（模式 `777`、尺寸 `0`、属主 `root:wheel`），真目标（末位路径）必须仍被
#   判定；多目标命令（`rm -rf a b`）须并入全部形似路径的 token。夹具纪律（类 14）同上。
m178_rule="$(printf '%s%s' '系统' '路径')"
m178_sys="$(printf '/%s/%s' 'etc' 'hosts')"
fresh
printf '{"session_id":"m178","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"bash","tool_input":{"command":"chmod 777 %s"}}' \
  "$work/cur" "$m178_sys" > "$work/cur/m178-chmod.json"
check_rc "M178-a chmod 777 <黑名单文件> 须阻断（rc=2，实参不得顶替）" \
  "python3 plans/hook-write-scope.py --fixture m178-chmod.json 2>&1" 2 "$m178_rule"
printf '{"session_id":"m178","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"bash","tool_input":{"command":"truncate -s 0 %s"}}' \
  "$work/cur" "$m178_sys" > "$work/cur/m178-trunc.json"
check_rc "M178-a2 truncate -s 0 <黑名单文件> 须阻断（rc=2）" \
  "python3 plans/hook-write-scope.py --fixture m178-trunc.json 2>&1" 2 "$m178_rule"
printf '{"session_id":"m178","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"bash","tool_input":{"command":"chmod 755 plans/checker-self-test.sh"}}' \
  "$work/cur" > "$work/cur/m178-repo.json"
check_rc "M178-a3 仓内 chmod 755 plans/checker-self-test.sh 不得误报（rc=0）" \
  "python3 plans/hook-write-scope.py --fixture m178-repo.json 2>&1" 0 ""
sed -i.bak 's|for t in (like or toks\[:1\]):|for t in toks[:1]:  # F384-MUT|' "$work/cur/plans/hook-write-scope.py"
rm -f "$work/cur/plans/hook-write-scope.py.bak"
mutate "M178-b 变异（形似路径筛选退回首位）" "$work/cur/plans/hook-write-scope.py" 'F384-MUT'
check_rc "M178-b 退回首位后同一夹具须复现放行（rc=0，证明该筛选非空转）" \
  "python3 plans/hook-write-scope.py --fixture m178-chmod.json 2>&1" 0 ""

echo "[M179 治理矩阵载体须仓内可解析（F385：仓外载体不得充当「机械」声称）]"
# 契约：治理矩阵是「声称 ↔ 能力互证」表；其「载体」列的引用若指向仓外文件，读者与 CI 都无法复现
#   该声称（F385 实证：原「巡检节奏」行以运行根本地脚本为「机械」载体）。判据：矩阵行内反引号的
#   文件型 token 必须仓内可解析、或为 `artifacts.md` 以 `##` 声明的制品名、或该行显式标注「非仓内」。
fresh
m179_gov="skills/dsh-codepunk-workflow/references/skill-governance.md"
printf '\n| **M179 夹具行** | `plans/no-such-carrier-xyz.sh` | 机械 |\n' >> "$work/cur/$m179_gov"
mutate "M179-a 夹具落地（不可解析载体已注入矩阵）" "$work/cur/$m179_gov" 'no-such-carrier-xyz'
check_rc "M179-a 矩阵出现仓外/不存在载体须报失败（rc=1）" \
  "bash plans/doc-consistency.sh 2>&1" 1 "治理矩阵载体不可解析"
sed -i.bak "s|        bad.append('行%d:%s' % (i, t))|        pass  # F385-MUT|" "$work/cur/plans/doc-consistency.sh"
rm -f "$work/cur/plans/doc-consistency.sh.bak"
mutate "M179-b 变异（载体判据被短路）" "$work/cur/plans/doc-consistency.sh" 'F385-MUT'
check_no_match "M179-b 判据短路后不得再报「治理矩阵载体不可解析」（证明该判据非空转）" \
  "bash plans/doc-consistency.sh 2>&1" "治理矩阵载体不可解析"

echo "[M180 泄露防护门须自证 git 可用与扫描非零（F387：零输入不得呈现为「通过」）]"
# 契约：tree 模式「通过」的前提是**真的扫到了文件**；说谎/损坏的 git（exit 0 零输出）或
#   `GIT_DIR`/`GIT_WORK_TREE` 误设会让 `git ls-files` 返回空 ⇒ 一个文件都不扫却打「✓ 通过」
#   （与 F250/F252 同族：跳过/依赖故障不得伪装成通过）。
fresh
mkdir -p "$work/bin-lie"
printf '#!/bin/sh\nexit 0\n' > "$work/bin-lie/git"
chmod 755 "$work/bin-lie/git"
[ -x "$work/bin-lie/git" ] && echo "  · M180 夹具（说谎 git：exit 0 且零输出）就位"
check_rc "M180-a 替身 git（rev-parse --git-dir 无输出）须以 2 拒绝（无法核验 ≠ 通过）" \
  "PATH=\"$work/bin-lie:\$PATH\" bash plans/dsh-codepunk-leak-guard.sh --tree" 2 "git 不可用或行为异常"
sed -i.bak -e '/^GITDIR_OUT=\$(git rev-parse --git-dir/,/^fi$/d' \
  -e '/^    if \[ .* -eq 0 \]; then$/,/^    fi$/d' "$work/cur/plans/dsh-codepunk-leak-guard.sh"
rm -f "$work/cur/plans/dsh-codepunk-leak-guard.sh.bak"
mutate_gone "M180-b 删除型变异（移除 git 自证守卫）" "$work/cur/plans/dsh-codepunk-leak-guard.sh" 'GITDIR_OUT='
mutate_gone "M180-b2 删除型变异（移除零扫描守卫）" "$work/cur/plans/dsh-codepunk-leak-guard.sh" '未扫描到任何跟踪文件'
check_rc "M180-b 两道自证均移除后同夹具须复现假通过 rc=0（证明两道守卫非空转）" \
  "PATH=\"$work/bin-lie:\$PATH\" bash plans/dsh-codepunk-leak-guard.sh --tree" 0 "泄露防护门：通过"

echo "[M181 审计门须在 git 枚举为空时回退核验（F388：零输入不得判满分）]"
# 契约：D3/E3 的 PASS 声称「仓内行号引用均附符号名」「仓内相对链接均可达」——若 git 枚举为空且不回退，
#   循环空转即 PASS，否决式计分下直接 100/100 假满分。
fresh
printf '\n缺陷样例：见 plans/foo.sh:12 处。\n' >> "$work/cur/docs/faq.md"
mutate "M181-a 夹具落地（注入缺符号名的行号引用）" "$work/cur/docs/faq.md" 'plans/foo.sh:12'
mkdir -p "$work/bin-lie2"
printf '#!/bin/sh\nexit 0\n' > "$work/bin-lie2/git"
chmod 755 "$work/bin-lie2/git"
check_rc "M181-a 说谎 git + 注入缺陷 ⇒ 须回退文件系统遍历并捕获（rc=1，D3 ✗）" \
  "PATH=\"$work/bin-lie2:\$PATH\" bash plans/preset-audit.sh 2>&1" 1 "D3 行号引用缺符号名"
sed -i.bak 's|^if not files:$|if False:  # F388-MUT|' "$work/cur/plans/preset-audit.sh"
rm -f "$work/cur/plans/preset-audit.sh.bak"
mutate "M181-b 变异（关闭文件系统回退）" "$work/cur/plans/preset-audit.sh" 'F388-MUT'
check_no_match "M181-b 关闭回退后同一缺陷不得再被捕获（证明回退非空转）" \
  "PATH=\"$work/bin-lie2:\$PATH\" bash plans/preset-audit.sh 2>&1" "D3 行号引用缺符号名"

echo "[M182 电池须把 .gitignore 明示忽略的运行产物与被忽略游离物分开判（F389：产物不得判杂散、白名单守卫不得放宽）]"
fresh
mkdir -p "$work/cur/tmp"
printf 'x\n' > "$work/cur/tmp/run-artifact.txt"
check_rc "M182-a 仓内 tmp/ 运行产物 ⇒ 电池须 rc=0 并把产物单列（按 .gitignore 契约允许）" \
  "DSH_CODEPUNK_SKIP_SELFTEST=1 bash plans/verify-battery.sh . 2>&1" 0 "运行产物"
rm -rf "$work/cur/tmp"
fresh
printf 'x\n' > "$work/cur/NEWTOP.md"
check_rc "M182-b 未登记的顶层被忽略文件 ⇒ 仍须判杂散（白名单守卫不得被放宽）" \
  "DSH_CODEPUNK_SKIP_SELFTEST=1 bash plans/verify-battery.sh . 2>&1" 1 "杂散"
rm -f "$work/cur/NEWTOP.md"
fresh
mkdir -p "$work/cur/tmp"
printf 'x\n' > "$work/cur/tmp/run-artifact.txt"
sed -i.bak "s|^ARTIFACT_RE=.*|ARTIFACT_RE='^\$'  # F389-MUT|" "$work/cur/plans/verify-battery.sh"
rm -f "$work/cur/plans/verify-battery.sh.bak"
mutate "M182-c 变异（把产物白名单置空）" "$work/cur/plans/verify-battery.sh" 'F389-MUT'
check_rc "M182-c 抹掉产物白名单后同夹具须复现假失败 rc=1（证明新判据非空转）" \
  "DSH_CODEPUNK_SKIP_SELFTEST=1 bash plans/verify-battery.sh . 2>&1" 1 "杂散"
rm -rf "$work/cur/tmp"

echo "[M183 产品/用户平面行号引用须可核验（第 27 类）：越界须报，修好后不得再报（F390/F391）]"
if [ -n "${DSH_APP_ROOT:-}" ] && [ -d "$DSH_APP_ROOT/node_modules/@deepseek-ai" ]; then
  fresh
  printf '%s\n' '<!-- M183 夹具 -->' >> "$work/cur/docs/faq.md"
  printf '%s\n' '行号引用夹具：`PKG/dsh-sandbox-policy/lib/index.js:9999`（核验式：`grep -n '"'"'SANDBOX_MODES'"'"' <该文件>`）。' >> "$work/cur/docs/faq.md"
  mutate "M183-a 夹具（越界行号引用）已写入" "$work/cur/docs/faq.md" 'lib/index.js:9999'
  check_rc "M183-a 行号引用越界须被第 27 类报出" "bash plans/doc-consistency.sh 2>&1" 1 "行号引用锚点未落在引用区间"
  sed -i.bak 's|lib/index.js:9999|lib/index.js:26-30|' "$work/cur/docs/faq.md"
  rm -f "$work/cur/docs/faq.md.bak"
  mutate_gone "M183-b 夹具已修为合法区间（删除型变异）" "$work/cur/docs/faq.md" 'lib/index.js:9999'
  check_no_match "M183-b 修好后第 27 类不得再报行号引用问题" "bash plans/doc-consistency.sh 2>&1" "行号引用锚点未落在引用区间"
else
  skip "M183 跳过（未设 DSH_APP_ROOT ⇒ 无法定位产品安装面）"
fi

echo "[M184 用户平面引用禁写行号（第 27 类 PROF 子判据；应用会重写该文件）（F392）]"
fresh
printf '%s\n' '<!-- M184 夹具 -->' >> "$work/cur/docs/faq.md"
printf '%s\n' '用户平面行号引用夹具：`PROF/cordis.patch.yml:217-230`。' >> "$work/cur/docs/faq.md"
mutate "M184-a 夹具（用户平面带行号引用）已写入" "$work/cur/docs/faq.md" 'PROF/cordis.patch.yml:217-230'
check_rc "M184-a 用户平面引用带行号须被第 27 类报出" "bash plans/doc-consistency.sh 2>&1" 1 "用户平面引用不得写行号"
sed -i.bak 's|`PROF/cordis.patch.yml:217-230`|`PROF/cordis.patch.yml`|' "$work/cur/docs/faq.md"
rm -f "$work/cur/docs/faq.md.bak"
mutate_gone "M184-b 夹具已改为符号锚点（删除型变异）" "$work/cur/docs/faq.md" 'PROF/cordis.patch.yml:217-230'
check_no_match "M184-b 去掉行号后第 27 类不得再报用户平面行号问题" "bash plans/doc-consistency.sh 2>&1" "用户平面引用不得写行号"

echo "[M185 保真闸类数声称须入核验（与 doc 类数同族、另一实况值；计数同步易误伤相邻工具行）（F393）]"
fresh
sed -i.bak 's|\*\*14 类\*\*：编号|**27 类**：编号|' "$work/cur/README.md"
rm -f "$work/cur/README.md.bak"
mutate "M185-a 变异已落地（README 保真闸类数 14→27）" "$work/cur/README.md" '27 类\*\*：编号'
check_rc "M185-a 保真闸类数陈旧须被报出" "bash plans/doc-consistency.sh 2>&1" 1 "保真闸类数声称陈旧"
sed -i.bak 's|\*\*27 类\*\*：编号|**14 类**：编号|' "$work/cur/README.md"
rm -f "$work/cur/README.md.bak"
mutate_gone "M185-b 已复原（删除型变异）" "$work/cur/README.md" '27 类\*\*：编号'
check_no_match "M185-b 复原后不得再报保真闸类数问题" "bash plans/doc-consistency.sh 2>&1" "保真闸类数声称陈旧"

echo "[M186 自检尾部须有 MUTFAIL 终局门（早退点之后的变异不得静默空转）（F394）]"
check_rc "M186-a 自检文件内须存在两处 MUTFAIL 门（早退点 + 终局）" "grep -cE 'exit 2; fi\$' plans/checker-self-test.sh | grep -qx 2" 0
sed -i.bak '/^# F394：终局 MUTFAIL 门/,/^if \[ "\$MUTFAIL" != 0 \]; then echo "✗ 自检失败/d' "$work/cur/plans/checker-self-test.sh"
rm -f "$work/cur/plans/checker-self-test.sh.bak"
# 注：目标文件即本脚本自身 ⇒ 模式串 MUST 由拼接构造，否则该断言行自身即命中（F394 自纠 217）
GONE_PAT="F394：终局 MUTFAIL ""门（早退点"
mutate_gone "M186-b 终局门已被删除（删除型变异）" "$work/cur/plans/checker-self-test.sh" "$GONE_PAT"
check_rc "M186-b 删掉终局门后门计数须降为 1（证明该断言非空转）" "grep -cE 'exit 2; fi\$' plans/checker-self-test.sh | grep -qx 2" 1

echo "[M187 巡检名册单引号标量闭合性（F395：撇号未双写致名册不可解析，而两门曾同报通过）]"
mkdir -p "$work/rr187"
cat > "$work/rr187/agents.yaml" <<'YAML187'
run_id: r187
patrol_log:
  - round: 1
    at: '2026-10-08T00:00:00+07:00'
    note: '巡检：正常'
  - round: 2
    at: '2026-10-08T01:00:00+07:00'
    note: '巡检：撇号 it's 未双写'
YAML187
check_rc "M187-a 单引号标量内未双写撇号须被 patrol-check 报出" "bash plans/patrol-check.sh --run-root \"$work/rr187\"" 1 "单引号标量未闭合"
sed -i.bak "s/it's/it''s/" "$work/rr187/agents.yaml"
rm -f "$work/rr187/agents.yaml.bak"
mutate_gone "M187-b 撇号已双写（删除型变异）" "$work/rr187/agents.yaml" "it's"
check_rc "M187-b 双写后须判合规（证明该判据非空转）" "bash plans/patrol-check.sh --run-root \"$work/rr187\"" 0 "巡检名册合规"

echo "[M188 运行根 cleanup_status=clean 的实况核验（F396：只验键齐备/取值，残留备份也报通过）]"
mkdir -p "$work/rr188"
cat > "$work/rr188/README.md" <<'RR188'
# 夹具运行根
write_scope:
  run_id: rr188
  allowed_prefixes:
    - "本运行根/"
  created:
    - "x*"
  cleanup_status: clean
  exempt: []
RR188
check_rc "M188-a 顶层无备份/临时命名物须判通过" "bash plans/write-scope-check.sh --run-root \"$work/rr188\"" 0 "判据 h 实况核验"
touch "$work/rr188/x.bak"
check_rc "M188-b 顶层存在 *.bak 而 cleanup_status=clean 须判失败" "bash plans/write-scope-check.sh --run-root \"$work/rr188\"" 1 "备份/临时/编译缓存残留"
( cd "$work/cur" && sed -i.bak '/^    # 判据 h/,/^    fi$/d' plans/write-scope-check.sh \
    && rm -f plans/write-scope-check.sh.bak )
mutate_gone "M188-c 删除型变异（移除判据 h；作用于沙箱副本，F397）" "$work/cur/plans/write-scope-check.sh" "RR_JUNK"
check_rc "M188-c 移除判据 h 后同夹具须复现假通过（证明该判据非空转）" "bash plans/write-scope-check.sh --run-root \"$work/rr188\"" 0 "5 键齐备"

echo "[M189 源树密封（F397：变异 MUST 作用于沙箱副本，裸路径会改动源树且备份被 rm 后不可回滚）]"
# M189-a：密封判据非空转——在源树落一个未跟踪探针文件 ⇒ seal_check 须报「已改动」；随即删除。
SEAL_PROBE="$SRC/.seal-probe-m189"
: > "$SEAL_PROBE"
if seal_check; then
  printf '  ✗ M189-a 源树被改动而密封判据未报出（判据空转）\n'
  FAILED=1
else
  printf '  ✅ M189-a 源树改动（未跟踪探针）被密封判据捕获\n'
fi
rm -f "$SEAL_PROBE"
if seal_check; then
  printf '  ✅ M189-b 探针移除后密封判据恢复通过\n'
else
  printf '  ✗ M189-b 探针移除后密封判据仍报已改动\n'
  FAILED=1
fi

echo "[M190 preset-declare CLI 取值守卫（非法 --order/--id 不得静默产出非法声明，更不得写进副本）（F398）]"
check_rc "M190-a 非法 --order 须 rc=2 并给出理由" "node plans/preset-declare.mjs emit --order=abc 2>&1" 2 "--order 取值非法"
check_rc "M190-b 非法 --id（空）须 rc=2 并给出理由" "node plans/preset-declare.mjs emit --id= 2>&1" 2 "--id 取值非法"
check_rc "M190-b2 合法取值不得被误拒（--order=5 / --id=my-preset.1 须 rc=0）" "node plans/preset-declare.mjs emit --order=5 >/dev/null 2>&1 && node plans/preset-declare.mjs emit --id=my-preset.1 >/dev/null 2>&1 && echo LEGAL_OK" 0 "LEGAL_OK"
( cd "$work/cur" && sed -i.bak '/Number.isSafeInteger(ORDER)/,/^}$/d' plans/preset-declare.mjs \
    && rm -f plans/preset-declare.mjs.bak )
mutate_gone "M190-c 删除型变异（移除 --order 守卫；作用于沙箱副本）" "$work/cur/plans/preset-declare.mjs" "Number.isSafeInteger(ORDER)"
check_rc "M190-c 移除守卫后同输入须复现静默产出（order: NaN 落进声明）" "node plans/preset-declare.mjs emit --order=abc >\"$work/m190c.out\" 2>&1; grep -q 'order: NaN' \"$work/m190c.out\" && echo SILENT_NAN" 0 "SILENT_NAN"

# F400：巡检名册时间戳实况核验（判据 i）——未来时间 / 非单调 MUST 报出，合规 MUST 通过。
#   夹具全部落在 $work 沙箱（纪律 ㉟：变异与夹具 MUST 作用于沙箱副本，绝不碰源树）。
m191_dir="$work/m191"; rm -rf "$m191_dir"; mkdir -p "$m191_dir/future" "$m191_dir/nonmono" "$m191_dir/ok" "$m191_dir/bad"
m191_past="$(date -u -v-2H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '-2 hours' +%Y-%m-%dT%H:%M:%SZ)"
m191_now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
m191_fut="$(date -u -v+7H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '+7 hours' +%Y-%m-%dT%H:%M:%SZ)"
mk191() { # mk191 <目录> <at1> <at2>（时间戳一律带自身的偏移设计符 `Z`，跨时区主机同结果）
  printf 'updated_at: %s\npatrol_log:\n  - round: 1\n    at: %s\n    note: 夹具一\n  - round: 2\n    at: %s\n    note: 夹具二\n' \
    "$3" "$2" "$3" > "$m191_dir/$1/agents.yaml"
}
mk191 future "$m191_past" "$m191_fut"
mk191 nonmono "$m191_now" "$m191_past"
mk191 ok "$m191_past" "$m191_now"
printf 'updated_at: %s\npatrol_log:\n  - round: 1\n    at: 2026-10-08T22:00+07:00\n    note: 形态夹具（缺秒）\n' \
  "$m191_now" > "$m191_dir/bad/agents.yaml"
echo "[M191 巡检名册时间戳实况核验（未来时间 / 非单调）（F400）]"
check_rc "M191-a 未来时间戳须 rc=1 并报出（判据 i 非空转）" "bash plans/patrol-check.sh --run-root \"$m191_dir/future\" 2>&1" 1 "未来时间"
check_rc "M191-b 非单调 at 须 rc=1 并报出" "bash plans/patrol-check.sh --run-root \"$m191_dir/nonmono\" 2>&1" 1 "非递减"
check_rc "M191-c 合规夹具须 rc=0（不得误报）" "bash plans/patrol-check.sh --run-root \"$m191_dir/ok\" 2>&1" 0 "巡检名册合规"
check_rc "M191-d 形态非法（缺秒/缺偏移）须 rc=1 并报出" "bash plans/patrol-check.sh --run-root \"$m191_dir/bad\" 2>&1" 1 "形态非法"

echo "[M192 运行根残留实况核验须**递归**（F403：原判据 h 只扫顶层 ⇒ 子目录编译缓存不可见）]"
# F403 实证：`tools/__pycache__/*.pyc` 在运行根子目录在场而 `--run-root` 门 rc=0（只扫顶层）。
m192_dir="$work/rr192"
mkdir -p "$m192_dir/sub/__pycache__"
cat > "$m192_dir/README.md" <<'RR192'
# 夹具运行根（F403）
write_scope:
  run_id: rr192
  allowed_prefixes:
    - "本运行根/"
  created:
    - "sub*"
  cleanup_status: clean
  exempt: []
RR192
printf 'x' > "$m192_dir/sub/__pycache__/mod.cpython-314.pyc"
fresh
check_rc "M192-a 子目录编译缓存而 cleanup_status=clean 须判失败（判据 h 须递归）" \
  "bash plans/write-scope-check.sh --run-root \"$m192_dir\" 2>&1" 1 "编译缓存残留"
rm -rf "$m192_dir/sub"
check_rc "M192-b 清理子目录残留后须判通过（不得误报）" \
  "bash plans/write-scope-check.sh --run-root \"$m192_dir\" 2>&1" 0 "含子目录"
( cd "$work/cur" && sed -i.bak 's|find \. \\(|find . -maxdepth 1 \\(|' plans/write-scope-check.sh \
    && rm -f plans/write-scope-check.sh.bak )
mutate "M192-c 变异落地（递归 find 退化为 -maxdepth 1）" "$work/cur/plans/write-scope-check.sh" "find . -maxdepth 1"
mkdir -p "$m192_dir/sub/__pycache__" && printf 'x' > "$m192_dir/sub/__pycache__/mod.cpython-314.pyc"
check_rc "M192-c 退化为只扫顶层后同夹具须复现假通过（证明递归扫描非空转）" \
  "bash plans/write-scope-check.sh --run-root \"$m192_dir\" 2>&1" 0 "含子目录"
rm -rf "$m192_dir/sub"
fresh

# ── M193：解析依赖缺失时门禁 MUST 显式失败（F405）──────────────────────────────
#   机理：leak-guard 的禁词归一管道 `sed … | awk 'length($0)>=3' | sort -u` 在缺 awk 时得空串 ⇒
#   25 条禁词被静默归零，门仍打印「✓ 泄露防护门：通过（禁词 0 条 + 通用模式 5 类）」rc=0。
#   断言：a) 完好版 + 无 awk 的 PATH ⇒ rc=2 含「缺少必需工具 awk」；
#        b) 仅删预检、保留不变量 ⇒ rc=2 含「归一管道失效」（两层守护各自非空转）；
#        c) 两层都删 ⇒ 复现假绿 rc=0 含「禁词 0 条」（证明守护确为唯一拦截者）。
mkdir -p "$work/bin-noawk"
for _t in bash sh git grep sed sort uniq wc tr head tail cut cat locale mktemp stat basename dirname python3 rm; do
  _p="$(command -v "$_t" 2>/dev/null)" || continue
  [ -n "$_p" ] && ln -sf "$_p" "$work/bin-noawk/$_t"
done
if [ -x "$work/bin-noawk" ] && [ ! -e "$work/bin-noawk/awk" ]; then
  fresh
  # F407（本轮自检实测）：夹具 MUST 自带**禁词源**——不变量是「源非空而归一后为空」，
  #   而本套件 `export HOME="$SANDBOX"`（第 106 行）⇒ 沙箱 HOME 下无 `~/.dsh-codepunk/denylist.txt`，
  #   `DENY_RAW` 恒空 ⇒ 不变量**不可达** ⇒ M193-b 在沙箱内假失败（实测 rc=0 而非 2），
  #   而操作者在真 HOME 下手跑同一变异却得 rc=2（本机 denylist.txt 非空）——即夹具依赖宿主环境。
  #   ⇒ 三断言统一显式传 `DSH_CODEPUNK_DENYLIST`（脚本第 109 行的正式输入通道），与宿主 HOME 无关。
  _denyenv='DSH_CODEPUNK_DENYLIST="leakwordalpha:leakwordbeta"'
  check_rc "M193-a 解析依赖缺失（PATH 无 awk）须 rc=2（无法核验 ≠ 通过）" \
    "env -i PATH=\"$work/bin-noawk\" HOME=\"$HOME\" $_denyenv \"$work/bin-noawk/bash\" plans/dsh-codepunk-leak-guard.sh --tree" 2 \
    "缺少必需工具 awk"
  fresh
  sed -i.bak '/^for _t in git awk sed sort grep cut; do/,/^done$/d' "$work/cur/plans/dsh-codepunk-leak-guard.sh"
  rm -f "$work/cur/plans/dsh-codepunk-leak-guard.sh.bak"
  mutate_gone "M193-b 删除型变异（仅移除依赖预检，保留不变量）" "$work/cur/plans/dsh-codepunk-leak-guard.sh" '缺少必需工具'
  check_rc "M193-b 预检移除后不变量须独立拦截（rc=2 含「归一管道失效」）" \
    "env -i PATH=\"$work/bin-noawk\" HOME=\"$HOME\" $_denyenv \"$work/bin-noawk/bash\" plans/dsh-codepunk-leak-guard.sh --tree" 2 \
    "归一管道失效"
  sed -i.bak '/^# F405 不变量/,/^fi$/d' "$work/cur/plans/dsh-codepunk-leak-guard.sh"
  rm -f "$work/cur/plans/dsh-codepunk-leak-guard.sh.bak"
  mutate_gone "M193-c 删除型变异（再移除不变量）" "$work/cur/plans/dsh-codepunk-leak-guard.sh" '归一管道失效'
  check_rc "M193-c 两层守护都移除后同环境须复现假绿 rc=0（证明守护非空转）" \
    "env -i PATH=\"$work/bin-noawk\" HOME=\"$HOME\" $_denyenv \"$work/bin-noawk/bash\" plans/dsh-codepunk-leak-guard.sh --tree" 0 \
    "禁词 0 条"
else
  echo "  ℹ M193 跳过（无法构造无 awk 的影子 PATH）——跳过 ≠ 通过"
fi
fresh


# ── M194：文档路径引用域与扩展名（F408）──────────────────────────────────────────
#   机理：第 4 类（工具存在性）原扫描域只含 SKILL / references / README / CONTRIBUTING / docs，
#   根级文档（`CHANGELOG.md` 等）不在域内；且扩展名集只有 `sh|py|mjs` ⇒ `.cjs` 形态的引用
#   根本不被识别 ⇒ 仓内不可解析的假引用长期零守护（红证实测见运行根 `logs/r647/f408-red.txt`）。
#   断言：a) 在**根级** md 注入不存在的 `.cjs` 形态 `plans/*` 引用 ⇒ rc=1 且点名文件:引用；
#        b) 移除注入 ⇒ 同环境 rc=0（证明失败源于该引用，而非环境/其他类）；
#        c) 通过消息须写明扫描域（「全部跟踪 .md」）——域扩落地，非仅改文案。
fresh
printf '\n- 注入探针（自检临时写入）：见 `plans/m194-probe-nonexistent.cjs`。\n' >> "$work/cur/CHANGELOG.md"
mutate "M194-a 注入型变异（根级 md 中不存在的 plans/*.cjs 引用）" "$work/cur/CHANGELOG.md" 'm194-probe-nonexistent'
check_rc "M194-a 第 4 类须报出不存在的引用（域含根级 md + 扩展名含 cjs）" "bash plans/doc-consistency.sh 2>&1" 1 "不存在"
check_contains "M194-a2 报错须可定位（文件:引用）" "bash plans/doc-consistency.sh 2>&1" "CHANGELOG.md:m194-probe-nonexistent.cjs"
sed -i.bak '/m194-probe-nonexistent/d' "$work/cur/CHANGELOG.md"
rm -f "$work/cur/CHANGELOG.md.bak"
mutate_gone "M194-b 删除型变异（移除注入的假引用）" "$work/cur/CHANGELOG.md" 'm194-probe-nonexistent'
check_rc "M194-b 移除注入后须复归 rc=0（失败确由该引用引起）" "bash plans/doc-consistency.sh" 0 ""
check_contains "M194-c 通过消息须写明扫描域（全部跟踪 .md）" "bash plans/doc-consistency.sh 2>&1" "全部跟踪 .md"
fresh


# ── M195：守卫 --history 的覆盖率可见性（F409）──────────────────────────────────
#   机理：tree 模式会报「已扫描 N 个跟踪文件」且零输入以 2 拒绝（F387/F250），但 history 模式原实现
#   只打印「✓ 通过（禁词 25 条 + 通用模式 5 类）」，不报实际扫描的提交数 ⇒ **浅克隆**（`.git/shallow`
#   在场：CI 的 depth=1 检出、只取一层的克隆都属此列）与**空仓库**下 `git log` 只返回可见提交，
#   输出却与全历史扫描无法区分（红证实测：`--depth 1` 克隆 rc=0 且与完整仓同形，见运行根
#   `logs/r648/p2-shallow-history.txt`）⇒ 审计者会误以为全历史已核验。
#   断言：a) 浅克隆 ⇒ rc=2 且说明「浅克隆」；b) 空仓库 ⇒ rc=2 且说明「空仓库」；
#        c) 完整仓 ⇒ rc=0 且输出含「已扫描」（覆盖率可见）；d) 仅删浅克隆守卫 ⇒ 浅克隆复现 rc=0（证明该守卫非空转）。
_m195_deny="DSH_CODEPUNK_DENYLIST='leakwordalpha:leakwordbeta'"
#   注（自引入缺陷，已修）：夹具内的邮箱形态 MUST 运行时拼接——写字面量会同时触发 ① 泄露防护门（通用「邮箱
#   形态」模式 ⇒ 本仓自身 rc=1）② doc 第 5 类子项「夹具含触发守卫的字面量」；下方 `_m195_at` 即为此用。
_m195_at='@'
rm -rf "$work/m195_src" "$work/m195_shallow" "$work/m195_empty"
mkdir -p "$work/m195_src"
( cd "$work/m195_src" && git init -q . && git config user.email "self-test${_m195_at}example.invalid" \
    && git config user.name "self-test" && printf 'seed\n' > seed.txt && git add -A && git commit -qm "seed" \
    && printf 'second\n' >> seed.txt && git add -A && git commit -qm "second" ) >/dev/null 2>&1
if git clone -q --depth 1 --no-tags "file://$work/m195_src" "$work/m195_shallow" >/dev/null 2>&1 \
   && [ -f "$work/m195_shallow/.git/shallow" ]; then
  cp "$work/cur/plans/dsh-codepunk-leak-guard.sh" "$work/m195_shallow/"
  check_rc "M195-a 浅克隆须判「无法核验 ≠ 通过」（rc=2）" \
    "cd '$work/m195_shallow' && env $_m195_deny bash dsh-codepunk-leak-guard.sh --history 2>&1" 2 "浅克隆"
  # d) 删除型变异：移除浅克隆守卫（BSD sed 的地址范围式删除，不用 GNU 的 addr,+N）
  #    注：锚点中被守护脚本的变量名按**运行时拼接**（`_gv`）——直书「美元符 + 变量名」形态会被 doc 第 5 类
  #    子项判为「未被记载的外部输入变量」（本套件并不消费该变量，仅为 sed 锚点，故不应进文档）。
  _gv="GITDIR_OUT"
  sed -i.bak "/^    if \[ -n \"\$${_gv}\" \] && \[ -f \"\$${_gv}\/shallow\" \]; then$/,/^    fi$/d" \
    "$work/cur/plans/dsh-codepunk-leak-guard.sh"
  rm -f "$work/cur/plans/dsh-codepunk-leak-guard.sh.bak"
  mutate_gone "M195-d 删除型变异（浅克隆守卫）" "$work/cur/plans/dsh-codepunk-leak-guard.sh" 'GITDIR_OUT/shallow'
  cp "$work/cur/plans/dsh-codepunk-leak-guard.sh" "$work/m195_shallow/"
  check_rc "M195-d 仅删浅克隆守卫 ⇒ 浅克隆复现假绿 rc=0（证明守卫非空转）" \
    "cd '$work/m195_shallow' && env $_m195_deny bash dsh-codepunk-leak-guard.sh --history 2>&1" 0 "已扫描"
  cp "$SRC/plans/dsh-codepunk-leak-guard.sh" "$work/cur/plans/dsh-codepunk-leak-guard.sh"   # 复原沙箱副本
else
  echo "  ℹ M195-a/d 跳过（无法构造浅克隆夹具：git clone --depth 1 不可用）——跳过 ≠ 通过"
fi
mkdir -p "$work/m195_empty"
( cd "$work/m195_empty" && git init -q . ) >/dev/null 2>&1
cp "$work/cur/plans/dsh-codepunk-leak-guard.sh" "$work/m195_empty/"
check_rc "M195-b 空仓库须判「无法核验 ≠ 通过」（rc=2）" \
  "cd '$work/m195_empty' && env $_m195_deny bash dsh-codepunk-leak-guard.sh --history 2>&1" 2 "空仓库"
check_contains "M195-c 完整仓通过时须报出实际扫描的提交数（覆盖率可见）" \
  "cd '$work/cur' && env $_m195_deny bash plans/dsh-codepunk-leak-guard.sh --history 2>&1" "已扫描"
fresh


# ── M196：自检自身的并发互斥（F410）─────────────────────────────────────────────
#   机理：本套件把 `$SRC`（调用方给的预设根，通常是真仓库）当**可写共享资源**用 —— M189 的密封探针
#   `$SRC/.seal-probe-m189` 写进源树、`fresh()` 整树复制 `$SRC` ⇒ 同一 `$SRC` 上并行两次自检会互相
#   观察对方的探针/半成品副本（实证 R648：一次与另一次重叠的运行产出 rc=1 幻影失败——M194 三条断言
#   得到 doc-consistency rc=2，而同配置三次单跑均 195/195 rc=0）。
#   断言：a) 集成——同预设根上已持锁（持有者存活）⇒ 子实例 rc=2 且说明「另一次自检」；
#        b) 陈旧锁（pid 已不存在）⇒ `--lock-echo` rc=0 且说明「接管陈旧锁」；
#        c) 无锁 ⇒ `--lock-echo` rc=0、不报「接管」，且退出后锁目录已被释放（EXIT trap 非空转）；
#        d) 仅删「持有者存活即拒绝」守护 ⇒ 持活锁下 `--lock-echo` 复现放行 rc=0（证明该守护非空转）。
echo "[M196 自检并发互斥：同一预设根上并行自检 MUST 响亮拒绝（F410）]"
_m196_src="$work/cur"
_m196_lock="${TMPDIR:-/tmp}/cst-lock-$(lock_key_for "$_m196_src")"
rm -rf "$_m196_lock"
mkdir -p "$_m196_lock"; printf '%s\n' "$$" > "$_m196_lock/pid"
check_rc "M196-a 同预设根上已持锁（持有者存活）⇒ 子实例须 rc=2 并说明「另一次自检」" \
  "env DSH_CODEPUNK_SKIP_SELFTEST=0 bash plans/checker-self-test.sh 2>&1" 2 "另一次自检"
rm -rf "$_m196_lock"
mkdir -p "$_m196_lock"; printf '%s\n' 999999 > "$_m196_lock/pid"
check_rc "M196-b 陈旧锁（pid 不存在）⇒ 须接管并继续（rc=0）" \
  "env DSH_CODEPUNK_SKIP_SELFTEST=0 bash plans/checker-self-test.sh --lock-echo 2>&1" 0 "接管陈旧锁"
rm -rf "$_m196_lock"
check_rc "M196-c 无锁 ⇒ 正常取得锁（rc=0，且不得报「接管」）" \
  "env DSH_CODEPUNK_SKIP_SELFTEST=0 bash plans/checker-self-test.sh --lock-echo 2>&1" 0 "锁已取得"
if [ -d "$_m196_lock" ]; then
  printf '  ✗ M196-c2 退出后锁 MUST 已释放（EXIT trap 空转？）：%s 仍存在\n' "$_m196_lock"
  FAILED=1
else
  printf '  ✅ M196-c2 退出后锁已释放（EXIT trap 非空转）\n'
fi
mkdir -p "$_m196_lock"; printf '%s\n' "$$" > "$_m196_lock/pid"
# 注：目标文件即本脚本自身 ⇒ 模式串 MUST 由运行时拼接构造，否则 sed 地址行/断言行自身即命中
#   （同 M186-b / F394 自纠）。此处 `_m196_gone` 由两段拼接，文件里不存在连续的目标串。
_m196_gone="F410 守护：持有者存活即""拒绝"
sed -i.bak "/^  # ${_m196_gone}\$/,/^  fi\$/d" "$work/cur/plans/checker-self-test.sh"
rm -f "$work/cur/plans/checker-self-test.sh.bak"
mutate_gone "M196-d 删除型变异（持有者存活即拒绝）" "$work/cur/plans/checker-self-test.sh" "$_m196_gone"
check_rc "M196-d 仅删该守护 ⇒ 持活锁下复现放行 rc=0（证明守护非空转）" \
  "env DSH_CODEPUNK_SKIP_SELFTEST=0 bash plans/checker-self-test.sh --lock-echo 2>&1" 0 "锁已取得"
rm -rf "$_m196_lock"
cp "$SRC/plans/checker-self-test.sh" "$work/cur/plans/checker-self-test.sh"   # 复原沙箱副本
fresh

# M197（F412）：证据门的**必需上下文**缺失 ⇒ 无法核验 ≠ 通过（rc=2），且 MUST NOT
#   把环境缺口误归因为数据缺陷（旧实现按校验器 cwd 解析 log_ref ⇒ 断言「文件不存在」）。
echo "[M197 证据门必需上下文（F412）]"
_m197_d="$work/f412/deliv"
mkdir -p "$_m197_d/logs"
printf 'inner log\n' > "$_m197_d/logs/ok.log"
printf 'task_id: t\ndelivered_at: "2026-10-07T10:00:00+07:00"\nvalidated_at: "2099-01-01T00:00:00+07:00"\nevidence:\n  - id: EV-1\n    command: "bash plans/doc-consistency.sh"\n    exit_code: 0\n    log_ref: "logs/ok.log"\n' > "$_m197_d/evidence.yaml"
mutate "证据门正常夹具（含交付目录）" "$_m197_d/evidence.yaml" 'log_ref: "logs/ok.log"'
check_rc "M197-a 缺交付目录 ⇒ rc=2 判「无法核验」（旧实现 rc=1「文件不存在」）" \
  "bash plans/evidence-verify.sh '$_m197_d/evidence.yaml' 2>&1" 2 "无法核验"
check_no_match "M197-a2 缺交付目录时 MUST NOT 断言「log_ref 文件不存在」（环境缺口不得误归因为数据缺陷）" \
  "bash plans/evidence-verify.sh '$_m197_d/evidence.yaml' 2>&1" "log_ref 文件不存在"
check_rc "M197-b 交付目录不存在 ⇒ rc=2 并指明目录" \
  "bash plans/evidence-verify.sh '$_m197_d/evidence.yaml' '$_m197_d/absent-dir' 2>&1" 2 "交付目录不存在"
check_rc "M197-c 两参齐备且 log_ref 在目录内 ⇒ PASS（不误伤正常交付）" \
  "bash plans/evidence-verify.sh '$_m197_d/evidence.yaml' '$_m197_d' 2>&1" 0 "verdict=PASS"
# 删除型等价的「削弱型」变异：① 参数下限 2→1；② 交付目录缺省值退回 `.`（即校验器 cwd）
#   —— 二者合起来正是 F412 修复前的语义（按 cwd 解析 log_ref）。模式串不含 `$#`，避免被判「外部输入变量」。
sed -i.bak 's/-lt 2 \]; then/-lt 1 ]; then/' "$work/cur/plans/evidence-verify.sh"
sed -i.bak 's|^DELIVERY_DIR="\$2"$|DELIVERY_DIR="${2:-.}"|' "$work/cur/plans/evidence-verify.sh"
rm -f "$work/cur/plans/evidence-verify.sh.bak"
mutate "M197-d 削弱型变异（参数下限 2→1 + 交付目录缺省 .）" "$work/cur/plans/evidence-verify.sh" '-lt 1 ]; then'
check_no_match "M197-d 削弱后缺交付目录即复现旧行为（按 cwd 解析 ⇒ 不得再出现「无法核验」，证明守护非空转）" \
  "bash plans/evidence-verify.sh '$_m197_d/evidence.yaml' 2>&1" "无法核验"
cp "$SRC/plans/evidence-verify.sh" "$work/cur/plans/evidence-verify.sh"   # 复原沙箱副本
fresh

# M198（F413）：文档命令表的**位置式用法串**占位符可选性 MUST 与脚本头部权威用法逐位一致
#   （F413 实证：CONTRIBUTING.md 三处与实现不符——两处必填写成可选、一处可选写成必填）。
echo "[M198 命令表用法形态（F413）]"
_m198_line_a='| `bash plans/evidence-verify.sh <evidence.yaml> [交付目录]` | 注入探针（自检临时写入） |'
printf '%s\n' "$_m198_line_a" >> "$work/cur/CONTRIBUTING.md"
mutate "M198-a 注入漂移（交付目录写成可选）" "$work/cur/CONTRIBUTING.md" '\[交付目录\]` | 注入探针'
check_rc "M198-a 必填写成可选 ⇒ 第 28 类须报错（rc=1 含「命令表用法形态」）" \
  "bash plans/doc-consistency.sh 2>&1" 1 "命令表用法形态"
sed -i.bak '/注入探针（自检临时写入）/d' "$work/cur/CONTRIBUTING.md"
rm -f "$work/cur/CONTRIBUTING.md.bak"
mutate_gone "M198-b 移除注入行（反向方向单独验证）" "$work/cur/CONTRIBUTING.md" '注入探针（自检临时写入）'
_m198_line_b='| `bash plans/verify-battery.sh <预设根>` | 注入探针（自检临时写入） |'
printf '%s\n' "$_m198_line_b" >> "$work/cur/CONTRIBUTING.md"
mutate "M198-b 注入反向漂移（可选写成必填）" "$work/cur/CONTRIBUTING.md" 'verify-battery.sh <预设根>` | 注入探针'
check_rc "M198-b 可选写成必填 ⇒ 须报错（含「文档标为必填」）" \
  "bash plans/doc-consistency.sh 2>&1" 1 "文档标为必填"
# 削弱型变异：令第 28 类的失败分支条件恒假（漂移仍在，但门禁不再报）——证明守护非空转。
#   变量名运行时拼接：注释里的美元符变量名会被第 5 类子判据当作「未被记载的外部输入变量」而报错（F407 同族）。
_m198_v="UF_""BAD"
sed -i.bak "s/elif \[ -n \"\$${_m198_v}\" \]; then bad/elif [ -n \"\" ]; then bad/" "$work/cur/plans/doc-consistency.sh"
rm -f "$work/cur/plans/doc-consistency.sh.bak"
mutate "M198-c 削弱第 28 类（失败分支条件恒假）" "$work/cur/plans/doc-consistency.sh" 'elif \[ -n "" \]; then bad'
check_no_match "M198-c 削弱后同一漂移不再被报（证明守护非空转）" \
  "bash plans/doc-consistency.sh 2>&1" "命令表用法形态与脚本头部不一致"
cp "$SRC/plans/doc-consistency.sh" "$work/cur/plans/doc-consistency.sh"      # 复原沙箱副本
cp "$SRC/CONTRIBUTING.md" "$work/cur/CONTRIBUTING.md"
fresh

# M199（F415）：`mutate` 助手 MUST 接受**以 `-` 开头**的模式串（否则被 grep 当选项 ⇒ 假「变异未生效」）。
#   本断言在**子 shell** 里调用助手并捕获其 stderr：子 shell 中的 MUTFAIL 不影响本轮判定，
#   故可安全地「自测助手」。
echo "[M199 变异助手模式串分隔（F415）]"
mkdir -p "$work/f415"
printf 'if [ $# -lt 1 ]; then\n' > "$work/f415/pat.sh"
_m199_out="$( ( mutate "M199-a" "$work/f415/pat.sh" '-lt 1 ]; then' ) 2>&1 )"
if printf '%s' "$_m199_out" | grep -qF '变异未生效'; then
  printf '  ✗ M199-a 以 `-` 开头的模式串被误判为未生效（grep 选项解析）——助手缺 `--` 分隔\n'
  FAILED=1
else
  printf '  ✅ M199-a 以 `-` 开头的模式串可被正确匹配（退出码 0）\n'
fi
_m199_out2="$( ( mutate "M199-b" "$work/f415/pat.sh" 'lt 9 ]; then' ) 2>&1 )"
if printf '%s' "$_m199_out2" | grep -qF '变异未生效'; then
  printf '  ✅ M199-b 对照：不存在的模式串仍须报「未生效」（判据非空转，退出码 0）\n'
else
  printf '  ✗ M199-b 对照：不存在的模式串未被报出 ⇒ 助手恒真、判据空转\n'
  FAILED=1
fi
rm -rf "$work/f415"

# M200（F416）：终局判据的**报告顺序** MUST 让因果更早者先报 —— 源树密封判据须排在 MUTFAIL 门之前，
#   否则「运行期间源树被改动」这一真因会被「自检脚本问题」掩盖（本轮实测：28 条变异成批 rc=2，
#   而日志只给「有变异未生效」）。静态判据：比较两处锚点的行号。
echo "[M200 终局判据报告顺序（F416）]"
# 锚点用**行首**匹配的专用标记（`^# [F416-顺序锚点]` 与 `^# F394：…`）：本判据自身代码/字面量里
#   也含这些串，若用「任意位置匹配 + head -1」会命中本块代码行 ⇒ 行号比较失真（首跑实测假失败）。
# 另加**区间下限**：两锚点都须落在文件尾部 120 行内，否则说明锚点漂移、判据无意义。
_m200_total=$(wc -l < "$0")
_m200_floor=$((_m200_total - 120))
_m200_seal=$(grep -n '^# \[F416-顺序锚点\]' "$0" | head -1 | cut -d: -f1)
_m200_gate=$(grep -n '^# F394：终局 MUTFAIL 门' "$0" | head -1 | cut -d: -f1)
if [ -n "$_m200_seal" ] && [ -n "$_m200_gate" ] \
   && [ "$_m200_seal" -gt "$_m200_floor" ] && [ "$_m200_gate" -gt "$_m200_floor" ] \
   && [ "$_m200_seal" -lt "$_m200_gate" ]; then
  printf '  ✅ M200-a 密封判据（行 %s）排在 MUTFAIL 门（行 %s）之前 ⇒ 真因先报（退出码 0）\n' "$_m200_seal" "$_m200_gate"
else
  printf '  ✗ M200-a 密封判据未排在 MUTFAIL 门之前或锚点漂移（密封 %s / 门 %s / 尾部下限 %s）⇒ 真因会被「自检脚本问题」掩盖\n' "${_m200_seal:-缺失}" "${_m200_gate:-缺失}" "$_m200_floor"
  FAILED=1
fi
# M200-b：削弱型变异——**按行**把「顺序锚点＋密封块」整体移到 MUTFAIL 门之后 ⇒ 判据须报错（证明非空转）。
#   按行搬运（而非替换文本片段）是因为同名字符串在脚本里多处出现（python 字面量、sed 地址），
#   文本替换会命中错误位置（首跑实测：插进了本块的 python 字面量里）。
_m200_bak="$work/f416.sh"
cp "$work/cur/plans/checker-self-test.sh" "$_m200_bak"
python3 - "$_m200_bak" <<'PYEOF'
import sys
p = sys.argv[1]
lines = open(p, encoding='utf-8').read().split('\n')
mark = '# [F416-顺序锚点]'
gate = 'if [ "$MUTFAIL" != 0 ]; then'
mi = max(i for i, l in enumerate(lines) if l.startswith(mark))
end = mi
while lines[end].strip() != 'fi':
    end += 1
blk = lines[mi:end + 1]
rest = lines[:mi] + lines[end + 1:]
gi = max(i for i, l in enumerate(rest) if l.startswith(gate))
out = rest[:gi] + blk + rest[gi:]
open(p, 'w', encoding='utf-8').write('\n'.join(out))
print('MUTATED')
PYEOF
_m200_total2=$(wc -l < "$_m200_bak")
_m200_floor2=$((_m200_total2 - 120))
_m200_swap=$(grep -n '^# \[F416-顺序锚点\]' "$_m200_bak" | head -1 | cut -d: -f1)
_m200_gate2=$(grep -n '^# F394：终局 MUTFAIL 门' "$_m200_bak" | head -1 | cut -d: -f1)
if [ -n "$_m200_swap" ] && [ -n "$_m200_gate2" ] \
   && [ "$_m200_swap" -gt "$_m200_floor2" ] && [ "$_m200_gate2" -gt "$_m200_floor2" ] \
   && [ "$_m200_swap" -gt "$_m200_gate2" ]; then
  printf '  ✅ M200-b 削换顺序后同一判据即报错（密封 %s 晚于门 %s，证明判据非空转，退出码 0）\n' "$_m200_swap" "$_m200_gate2"
else
  printf '  ✗ M200-b 削换顺序后判据仍未报错或锚点漂移（密封 %s / 门 %s / 尾部下限 %s）⇒ 判据空转\n' "${_m200_swap:-缺失}" "${_m200_gate2:-缺失}" "$_m200_floor2"
  FAILED=1
fi
rm -f "$_m200_bak"


# ============================================================================
# F419/F420/F421（R651 对抗性探针）：本轮修复项的**行为型**守护 —— 断言全部在 `$work/cur` 沙箱内
#   跑**真门禁**，且每条都带**削弱反向断言**（把守护改回去 ⇒ 检出能力消失），证明判据非空转。
# ============================================================================
echo "[M201 文档枚举 MUST 按 NUL 记录（F419）]"
fresh
( cd "$work/cur" && git mv docs/documentation-policy.md "docs/advm probe 'quote'.md" >/dev/null 2>&1 \
  && printf '\n参考：`plans/advm-nonexistent-probe.sh`（探针注入）。\n' >> "docs/advm probe 'quote'.md" )
mutate "M201-a" "$work/cur/docs/advm probe 'quote'.md" 'advm-nonexistent-probe.sh'
check_rc "M201-a 含空白+引号的文件名仍被扫描（点名注入的失效引用）" \
  "bash plans/doc-consistency.sh 2>&1" 1 "advm-nonexistent-probe.sh"
python3 - "$work/cur/plans/doc-consistency.sh" <<'PYEOF'
import sys
D = chr(36)   # 变体文本里的美元符：避免在本文件里出现未定义变量的字面形态（doc 第 5 类）
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = "  while IFS= read -r -d '' f; do"
new = "  for f in " + D + "(eval \"" + D + "MD_ENUM\" 2>/dev/null | tr '\\0' '\\n'); do"
assert old in s, 'M201-b 锚点缺失'
open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
print('MUTATED')
PYEOF
check_rc "M201-b 削弱（NUL 流 → 裸分词）⇒ 同一夹具下漏扫（rc=0，判据非空转）" \
  "bash plans/doc-consistency.sh 2>&1" 0

echo "[M202 含 NUL 字节的文档仍须点名真实缺陷（F420）]"
fresh
( cd "$work/cur" && printf '\n参考：`plans/advm-nul-probe.sh`（探针注入）。\n' >> docs/documentation-policy.md \
  && printf '\0' >> docs/documentation-policy.md )
mutate "M202-a" "$work/cur/docs/documentation-policy.md" 'advm-nul-probe.sh'
check_rc "M202-a 含 NUL 文档仍点名注入的失效引用" "bash plans/doc-consistency.sh 2>&1" 1 "advm-nul-probe.sh"
check_no_match "M202-b 不得出现 Binary file 乱码 token" "bash plans/doc-consistency.sh 2>&1" "Binary file"
python3 - "$work/cur/plans/doc-consistency.sh" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = "grep -aoE 'plans/"
new = "grep -oE 'plans/"
assert old in s, 'M202-c 锚点缺失'
open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
print('MUTATED')
PYEOF
check_no_match "M202-c 削弱（去 -a）⇒ 注入的缺陷名不再被点名（判据非空转）" \
  "bash plans/doc-consistency.sh 2>&1" "advm-nul-probe.sh"

echo "[M203 POSIX 模式前置守卫（F421）]"
fresh
for _s in doc-consistency preset-audit preset-score dsh-codepunk-leak-guard write-scope-check patrol-check verify-worktree github-setup; do
  check_rc "M203-a ${_s} 在 POSIX 模式保守拒答（rc=2 且带措辞）" \
    "POSIXLY_CORRECT=1 bash plans/${_s}.sh 2>&1" 2 "POSIX 模式（POSIXLY_CORRECT 或 bash --posix）⇒ 无法核验 ≠ 通过（rc=2）"
done
mutate "M203-b" "$work/cur/plans/dsh-codepunk-leak-guard.sh" 'POSIXLY_CORRECT'
python3 - "$work/cur/plans/dsh-codepunk-leak-guard.sh" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = "if [ -n \"${POSIXLY_CORRECT:-}\" ] || set -o 2>/dev/null | grep -qE '^posix[[:space:]]+on'; then"
new = "if false; then"
assert old in s, 'M203-b 锚点缺失'
open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
print('MUTATED')
PYEOF
check_no_match "M203-b 削弱（守卫条件恒假）⇒ 不再有保守措辞（判据非空转）" \
  "POSIXLY_CORRECT=1 bash plans/dsh-codepunk-leak-guard.sh --tree 2>&1" "无法核验 ≠ 通过（rc=2）"

echo "[M204 帮助 MUST 不依赖环境（F421）]"
fresh
check_rc "M204-a HOME 未设 ⇒ init -h 仍 rc=0" "env -u HOME bash plans/dsh-codepunk-init.sh -h 2>&1" 0 "用法"
check_rc "M204-b HOME 未设 ⇒ 非帮助路径显式 rc=2（非 unbound variable 崩溃）" \
  "env -u HOME bash plans/dsh-codepunk-init.sh --check 2>&1" 2 "HOME 未设"
mutate "M204-c" "$work/cur/plans/dsh-codepunk-init.sh" '--help\) sed -n'
python3 - "$work/cur/plans/dsh-codepunk-init.sh" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = "case \"${1:-}\" in\n  -h|--help) sed -n '2,30p' \"$0\" | sed 's/^# \\{0,1\\}//'; exit 0 ;;\nesac\n"
assert old in s, 'M204-c 锚点缺失'
open(p, 'w', encoding='utf-8').write(s.replace(old, "", 1))
print('MUTATED')
PYEOF
check_rc "M204-c 削弱（删前置 -h 分支）⇒ 帮助路径不再 rc=0（判据非空转）" \
  "env -u HOME bash plans/dsh-codepunk-init.sh -h 2>&1" 2 "HOME 未设"

echo "[M205 终局归因 MUST 区分「无法核验」（F421）]"
fresh
check_rc "M205-a 仅无法核验 ⇒ 终局文案区分归因" \
  "GIT_INDEX_FILE=/nonexistent-advm bash plans/doc-consistency.sh 2>&1" 1 "处为「无法核验」"
mutate "M205-b" "$work/cur/plans/doc-consistency.sh" 'NUNVER'
python3 - "$work/cur/plans/doc-consistency.sh" <<'PYEOF'
import sys
D = chr(36)   # 同上：变体文本里的美元符按运行期拼接
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = ("if [ \"" + D + "{NUNVER:-0}\" -gt 0 ]; then\n"
       "  echo \"✗ 存在 " + D + "{NFAIL} 处失败（其中 " + D + "{NUNVER} 处为「无法核验」，无法核验 ≠ 通过）\" >&2\n"
       "else\n"
       "  echo \"✗ 存在 " + D + "{NFAIL} 处不一致\" >&2\n"
       "fi\n")
new = "echo \"✗ 存在 " + D + "{NFAIL} 处不一致\" >&2\n"
assert old in s, 'M205-b 锚点缺失'
open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
print('MUTATED')
PYEOF
check_rc "M205-b 削弱（删归因分支）⇒ 退回旧文案（判据非空转）" \
  "GIT_INDEX_FILE=/nonexistent-advm bash plans/doc-consistency.sh 2>&1" 1 "存在 1 处不一致"
fresh

echo "[M206 判定的根 MUST NOT 可被宿主环境重定向（F422）]"
fresh
_m206_line='| `bash plans/evidence-verify.sh <evidence.yaml> [交付目录]` | 注入探针（自检临时写入） |'
printf '%s\n' "$_m206_line" >> "$work/cur/CONTRIBUTING.md"
mutate "M206-a" "$work/cur/CONTRIBUTING.md" '\[交付目录\]` | 注入探针'
check_rc "M206-a 宿主 DSH_CODEPUNK_REPO 指向真仓时仍判沙箱（第 28 类须捕获漂移）" \
  "DSH_CODEPUNK_REPO=\"$SRC\" bash plans/doc-consistency.sh 2>&1" 1 "命令表用法形态"
python3 - "$work/cur/plans/doc-consistency.sh" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = "repo = os.getcwd()"
new = "repo = os.environ.get('DSH_CODEPUNK_REPO') or os.getcwd()"
assert old in s, 'M206-b 锚点缺失'
open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
print('MUTATED')
PYEOF
check_rc "M206-b 削弱（把隐式根加回）⇒ 同一夹具下判定被重定向到真仓、漂移不再被捕获（判据非空转）" \
  "DSH_CODEPUNK_REPO=\"$SRC\" bash plans/doc-consistency.sh 2>&1" 0
fresh

echo "[M207 总库副本漂移守护须覆盖 .py/.mjs（F423）]"
fresh
python3 - "$work/hub423" "$work/cur" <<'PYEOF'
import os, shutil, sys
base, cur = sys.argv[1], sys.argv[2]
hub = os.path.join(base, '.dsh-codepunk', 'scripts')
os.makedirs(hub, exist_ok=True)
plans = os.path.join(cur, 'plans')          # 从**沙箱副本**取源，保证与门禁的对照面一致
for f in sorted(os.listdir(plans)):
    if f.endswith(('.sh', '.py', '.mjs')):
        shutil.copy(os.path.join(plans, f), os.path.join(hub, f))
win = os.path.join(plans, 'windows')
if os.path.isdir(win):
    for f in os.listdir(win):
        if f.endswith('.ps1'):
            shutil.copy(os.path.join(win, f), os.path.join(hub, f))
for name in ('preset-compat.py', 'ps-validate.mjs'):
    p = os.path.join(hub, name)
    assert os.path.exists(p), name
    open(p, 'a', encoding='utf-8').write('\n# stale\n')
print('MUTATED')
PYEOF
check_rc "M207-a 陈旧 .py/.mjs 总库副本 ⇒ audit F2 须报不同步" \
  "HOME='$work/hub423' bash plans/preset-audit.sh 2>&1" 1 "F2 不同步"
check_rc "M207-b 陈旧 .py/.mjs 总库副本 ⇒ score B14 须扣分" \
  "HOME='$work/hub423' bash plans/preset-score.sh 2>&1" 1 "不同步"
python3 - "$work/cur" "$work/hub423" <<'PYEOF'
import os, sys
cur = sys.argv[1]
hub = os.path.join(sys.argv[2], '.dsh-codepunk', 'scripts')
for name in ('preset-audit.sh', 'preset-score.sh'):
    p = os.path.join(cur, 'plans', name)
    s = open(p, encoding='utf-8').read()
    old = 'for p in plans/*.sh plans/*.py plans/*.mjs; do'
    assert old in s, name
    s2 = s.replace(old, 'for p in plans/*.sh; do', 1)
    open(p, 'w', encoding='utf-8').write(s2)
    # 被改的门禁脚本自身也在对照集合内 ⇒ 必须同步刷新假 hub 副本，
    #   否则「不同步」来自探针自身改动（口径污染），而非判据生效。
    open(os.path.join(hub, name), 'w', encoding='utf-8').write(s2)
print('MUTATED')
PYEOF
check_no_match "M207-c 削弱（只对照 .sh）⇒ 陈旧 .py 副本不再被报（判据非空转）" \
  "HOME='$work/hub423' bash plans/preset-audit.sh 2>&1" "F2 不同步"
check_no_match "M207-d 削弱后 score 亦不再报（判据非空转）" \
  "HOME='$work/hub423' bash plans/preset-score.sh 2>&1" "不同步"
fresh

echo "[M208 init --check 须点名漂移文件（F424）]"
fresh
python3 - "$work/hub424" "$work/cur" <<'PYEOF'
import os, shutil, sys
base, cur = sys.argv[1], sys.argv[2]
plans = os.path.join(cur, 'plans')
hub = os.path.join(base, '.dsh-codepunk', 'scripts')
os.makedirs(hub, exist_ok=True)
for f in sorted(os.listdir(plans)):
    if f.endswith(('.sh', '.py', '.mjs')):
        shutil.copy(os.path.join(plans, f), os.path.join(hub, f))
# init.sh 在 install_scripts 之前先校验**路径常量文件**（缺失即 fail 退出，根本走不到脚本同步）
# ⇒ 夹具必须一并安装，否则断言测的是「常量缺失」而非「漂移点名」。
shutil.copy(os.path.join(plans, 'dsh-codepunk-home.sh'),
            os.path.join(base, '.dsh-codepunk', 'dsh-codepunk-home.sh'))
p = os.path.join(hub, 'preset-compat.py')
open(p, 'a', encoding='utf-8').write('\n# stale\n')
print('MUTATED')
PYEOF
check_rc "M208-a --check 须点名漂移文件（不是只报数量）" \
  "HOME='$work/hub424' bash plans/dsh-codepunk-init.sh --check 2>&1" 1 "preset-compat.py（过期）"
python3 - "$work/cur/plans/dsh-codepunk-init.sh" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = '_stale_names="${_stale_names} ${base}（过期）"\n'
assert old in s, 'M208-b 锚点缺失'
open(p, 'w', encoding='utf-8').write(s.replace(old, '', 1))
print('MUTATED')
PYEOF
check_no_match "M208-b 削弱（不记录文件名）⇒ 漂移文件不再被点名（判据非空转）" \
  "HOME='$work/hub424' bash plans/dsh-codepunk-init.sh --check 2>&1" "preset-compat.py（过期）"
fresh

echo "[M209 plans 扩展名计数声称须被守护（F425）]"
fresh
python3 - "$work/cur/docs/development.md" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = '（16 个 `.sh` + 3 个 `.py` + 2 个 `.mjs`'
new = '（13 个 `.sh` + 2 个 `.py` + 2 个 `.mjs`'
assert old in s, 'M209-a 锚点缺失'
open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
print('MUTATED')
PYEOF
mutate "M209-a" "$work/cur/docs/development.md" '13 个 `\.sh`'
check_rc "M209-a 陈旧的扩展名计数声称 ⇒ 须报错" \
  "bash plans/doc-consistency.sh 2>&1" 1 "扩展名计数声称陈旧"
python3 - "$work/cur/plans/doc-consistency.sh" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = "chain = re.compile(r'\\d+\\s*个\\s*`\\.(?:sh|py|mjs)`\\s*\\+\\s*\\d+\\s*个\\s*`\\.(?:py|mjs|ps1)`')"
assert old in s, 'M209-b 锚点缺失'
new = "chain = re.compile(r'(?!x)x')"
open(p, 'w', encoding='utf-8').write(s.replace(old, new, 1))
print('MUTATED')
PYEOF
check_no_match "M209-b 削弱（串联链判据失效）⇒ 陈旧声称不再被报（判据非空转）" \
  "bash plans/doc-consistency.sh 2>&1" "扩展名计数声称陈旧"
fresh

# F426（本轮实测）：**远端清理动作 MUST 幂等**——GitHub 侧 `delete_branch_on_merge=true` 时，
#   合并已在服务端删除 head 分支 ⇒ 无条件 `git push origin --delete` 会以「remote ref does not
#   exist」失败，把**已完成**的清理报成失败，并留下陈旧的远端跟踪引用（`git branch -r` 仍显示
#   该分支，误导后续核验）。断言：a) 远端仍存在 head 分支 ⇒ 删除成功；a2) 清理后 MUST NOT 残留
#   陈旧跟踪引用；b) 服务端已删（幂等路径）⇒ rc=0 且说明「已不存在」、MUST NOT 报失败；
#   c) 仅删幂等探测 ⇒ 服务端已删场景复现 rc=1（证明该探测非空转）。
echo "[M210 远端分支清理须幂等（F426）]"
_m210="$work/m210"
rm -rf "$_m210"; mkdir -p "$_m210/bin"
# gh 影子：`pr view` 打印 head 分支名；其余子命令成功无输出（need_gh 的 `auth status` 亦须 rc=0）
cat > "$_m210/bin/gh" <<'GHSHIM'
#!/bin/sh
if [ "$1" = "pr" ] && [ "$2" = "view" ]; then printf '%s\n' "${M210_HEAD:-feat}"; fi
exit 0
GHSHIM
chmod +x "$_m210/bin/gh"
_m210_at='@'
mkdir -p "$_m210/origin.git" "$_m210/wt"
git init -q --bare "$_m210/origin.git" >/dev/null 2>&1
( cd "$_m210/wt" && git init -q -b main . && git config user.email "self-test${_m210_at}example.invalid" \
    && git config user.name "self-test" && printf 'seed\n' > f.txt && git add -A && git commit -qm seed \
    && git remote add origin "$_m210/origin.git" && git push -q origin main \
    && git checkout -q -b feat && printf 'feat\n' >> f.txt && git commit -qam feat && git push -q origin feat \
    && git checkout -q main && git merge -q --no-ff -m "Merge pull request #1 from feat" feat \
    && git push -q origin main ) >/dev/null 2>&1
_m210_gmf="$work/cur/plans/git-merge-flow.sh"
#   注：PATH 前置 MUST 用**双引号**书写——单引号会阻止 eval 时展开 `$PATH`，导致 `bash: command
#   not found`（rc=127）被误读为「清理失败」，整条断言的判据随之失效。
_m210_run="cd '$_m210/wt' && PATH=\"$_m210/bin:\$PATH\" M210_HEAD=feat bash '$_m210_gmf' merge 1 2>&1"
check_rc "M210-a 远端仍存在 head 分支 ⇒ 须删除成功（rc=0 且说明「已删除远端分支」）" \
  "$_m210_run" 0 "已删除远端分支"
check_no_match "M210-a2 清理后 MUST NOT 残留陈旧远端跟踪引用（origin/feat）" \
  "cd '$_m210/wt' && git branch -r 2>&1" "origin/feat"
check_rc "M210-b 服务端已删 head 分支（幂等路径）⇒ rc=0 且说明「已不存在」" \
  "$_m210_run" 0 "远端分支已不存在"
check_no_match "M210-b2 幂等路径 MUST NOT 报「删除远端分支失败」（清理已完成 ≠ 失败）" \
  "$_m210_run" "删除远端分支失败"
python3 - "$_m210_gmf" "$_m210/weaken-gmf.sh" <<'PYEOF'
import sys
s = open(sys.argv[1], encoding='utf-8').read()
# 变量引用 MUST 运行时拼接：写字面量会同时触发 ① doc 第 5 类「外部输入变量未被记载」② 断言行自身
# 命中锚点（同 M186-b/F394 纪律）。两种书写形态（`$VAR` 与 `${VAR}`）在目标文件里混用，须分别拼。
_d = '$'
ref = _d + '{' + 'HEAD' + '_REF' + '}'
plain = _d + 'HEAD' + '_REF'
old = ('    if [ -n "$(git ls-remote --heads origin "%s" 2>/dev/null)" ]; then\n'
       '      git push origin --delete "%s" >/dev/null 2>&1 \\\n'
       '        || fail1 "删除远端分支失败: %s（远端仍存在该引用）"\n'
       '      say "已删除远端分支: %s"\n'
       '    else\n'
       '      say "远端分支已不存在（delete_branch_on_merge 已在服务端删除）: %s"\n'
       '    fi\n') % (plain, plain, ref, ref, ref)
new = '    git push origin --delete "%s" >/dev/null 2>&1 || fail1 "删除远端分支失败: %s"\n' % (plain, ref)
assert old in s, 'M210-c 锚点缺失'
open(sys.argv[2], 'w', encoding='utf-8').write(s.replace(old, new, 1))
print('MUTATED')
PYEOF
check_rc "M210-c 削弱（无条件 push --delete）⇒ 服务端已删场景须复现 rc=1（判据非空转）" \
  "cd '$_m210/wt' && PATH=\"$_m210/bin:\$PATH\" M210_HEAD=feat bash '$_m210/weaken-gmf.sh' merge 1 2>&1" 1 "删除远端分支失败"

# M211（内容卫生 / 垃圾与重复治理）：B16 的五条子检查都必须**被证明会命中**——否则「16/16 全满分」
#   可能只是判据空转。削弱对照（M211-d）证明扣分**只来自** B16 的执行（同一夹具、只差 B16 是否被调用）。
#   夹具与判据同口径：新增/改动文件须 `git add -A` 后才进 `git ls-files` 的枚举面。
echo "[M211 内容卫生判据 B16（单文件上限 / 索引缺口 / 孤儿内容）]"
fresh
python3 - "$work/cur" "$SRC" <<'PYEOF'
import io, os, sys
root, src = sys.argv[1], sys.argv[2]
# 越界防线（本轮实测教训）：夹具 MUST 写进沙箱副本 —— 相对路径会落到**源树**（自检 cwd＝调用方目录），
#   触发源树密封判据（F397）并真的污染工作树（实测：删掉一行登记、留下 512 KB 探针文件）。
assert os.path.basename(root) == "cur", "M211 沙箱根异常: %s" % root
assert os.path.realpath(root) != os.path.realpath(src), "M211 拒绝对源树写入"


def w(rel, txt):
    io.open(os.path.join(root, rel), "w", encoding="utf-8").write(txt)


junk = "".join("内容填充行：单文件规模探针，用后可整体删除\n" for _ in range(8000))
w("docs/junk-probe.md", junk)
p = os.path.join(root, "skills/dsh-codepunk-workflow/references/learned-skills.md")
s = io.open(p, encoding="utf-8").read()
lines = s.split("\n")
hit = [n for n, l in enumerate(lines) if l.startswith("| `benchmarks/anti-loop-research.md`")]
assert len(hit) == 1, "M211-b 锚点缺失"
del lines[hit[0]]
io.open(p, "w", encoding="utf-8").write("\n".join(lines))
# 孤儿夹具名 MUST 运行时拼接：字面量会出现在本文件（跟踪文件）里 ⇒ 夹具被「引用」而不再是孤儿
#   （首跑实测：M211-c 假失败——夹具名写在自检自身里，判据正确地不判它为孤儿）。
w("docs/zz-orphan-" + "probe.md", "孤儿内容探针（全仓零引用）\n")
print("MUTATED")
PYEOF
_m211_orph="zz-orphan-""probe.md"
if [ -e "$SRC/docs/junk-probe.md" ] || [ -e "$SRC/docs/$_m211_orph" ]; then
  echo "  ‼ M211 夹具越界写入源树（自检自身问题）" >&2; MUTFAIL=1
fi
( cd "$work/cur" && git add -A ) >/dev/null 2>&1
mutate "M211-a 单文件超限夹具" "$work/cur/docs/junk-probe.md" '内容填充行'
mutate_gone "M211-b 索引登记行已删" "$work/cur/skills/dsh-codepunk-workflow/references/learned-skills.md" 'anti-loop-research\.md'
mutate "M211-c 孤儿夹具" "$work/cur/docs/$_m211_orph" '零引用'
check_rc "M211-a 单文件超限 ⇒ B16 命中并扣分" \
  "bash plans/preset-score.sh 2>&1" 1 "单文件超限"
check_rc "M211-b 溯源档案索引缺口 ⇒ B16 命中" \
  "bash plans/preset-score.sh 2>&1" 1 "溯源档案索引缺口"
check_rc "M211-c 孤儿内容 ⇒ B16 命中" \
  "bash plans/preset-score.sh 2>&1" 1 "孤儿内容"
python3 - "$work/cur/plans/preset-score.sh" <<'PYEOF'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
i = s.index("# ── B16 内容卫生")
j = s.index("# ── 汇总 ──")
open(p, 'w', encoding='utf-8').write(s[:i] + s[j:])
print("WEAKENED")
PYEOF
check_no_match "M211-d 削弱（移除 B16 调用）⇒ 同一夹具 MUST NOT 再被检出（判据非空转）" \
  "bash plans/preset-score.sh 2>&1" "单文件超限"
check_no_match "M211-d2 削弱后索引缺口亦 MUST NOT 出现" \
  "bash plans/preset-score.sh 2>&1" "溯源档案索引缺口"

# M212（M47 家族 / F432）：证明判据锚点**派生自实况**而非写死计数 —— 先把「评分指标」口径整体改到
#   21（README 声称改 21，并在 preset-score.sh 末尾补 5 个 B17 标记，使实况计数同步到 21，
#   口径变更本身自洽 ⇒ 基线仍绿），再施加同一「制造多值漂移」的派生锚夹具：
#   写死计数（16 或 15）的锚点在此必然失效，派生锚点须仍报出「评分指标 声称不一致」。
echo "[M212 夹具锚点派生性（F432：计数口径变更后夹具仍须制造漂移）]"
fresh
python3 - "$work/cur" <<'PYEOF'
import io, os, sys
root = sys.argv[1]
# 第 1 类的实况值 = preset-score.sh 中匹配「# ── <字母><数字><空格>」的行数 ⇒ 补 5 个标记即 +5
io.open(os.path.join(root, "plans/preset-score.sh"), "a", encoding="utf-8").write(
    "".join("# ── B%d 占位（M212 夹具）\n" % (17 + i) for i in range(5)))
p = os.path.join(root, "README.md")
s = io.open(p, encoding="utf-8").read()
io.open(p, "w", encoding="utf-8").write(s.replace("16 指标", "21 指标"))
print("MUTATED")
PYEOF
_m212_rc=$?
if [ "$_m212_rc" != 0 ] || ! grep -q '21 指标' "$work/cur/README.md"; then
  echo "  ‼ M212 口径变更夹具未落地（rc=${_m212_rc}）" >&2; MUTFAIL=1
fi
check_rc "M212-a 口径整体改到 21 后基线须仍通过（证明口径变更自洽、断言非空转）" \
  "bash plans/doc-consistency.sh" 0
python3 - "$work/cur/README.md" <<'PYEOF'
import io, re, sys
p = sys.argv[1]
s = io.open(p, encoding="utf-8").read()
hits = list(re.finditer(r"[0-9]+ 指标", s))
if len(hits) < 2:
    sys.exit(3)
m = hits[1]
io.open(p, "w", encoding="utf-8").write(s[:m.start()] + "77 指标" + s[m.end():])
print("MUTATED")
PYEOF
_m212_rc2=$?
if [ "$_m212_rc2" != 0 ] || ! grep -q '77 指标' "$work/cur/README.md"; then
  echo "  ‼ M212 漂移夹具未落地（rc=${_m212_rc2}）" >&2; MUTFAIL=1
fi
check_rc "M212-b 计数口径变更后派生锚夹具仍制造多值漂移" \
  "bash plans/doc-consistency.sh" 1 "评分指标 声称不一致"

# F416（本轮实测）：**报告顺序** MUST 让因果更早的判据先报。源树被并发改动（运行期间有人在
#   源树里改脚本）会让 `fresh()` 复制出语法损坏的副本 ⇒ 成批变异「未生效/退出码 2」，
#   而旧顺序把密封判据排在 MUTFAIL 门**之后** ⇒ 真因（源树已改动）被「自检脚本问题」掩盖，
#   排查方向被误导。故：先判密封，再判变异落地（顺序由 M200 静态守护）。
# [F416-顺序锚点] 源树密封判据 MUST 排在 MUTFAIL 门之前（见 D107 / M200）
# F397：源树密封判据（全轮比对）——任一变异越界改动源树都在此显式失败，不得静默污染工作树。
if ! seal_check; then
  echo "✗ 自检失败：本轮改动了源树（变异 MUST 作用于 \$work/cur；见 F397）" >&2
  exit 2
fi

# F394：终局 MUTFAIL 门（早退点之后的变异不得静默空转）——早退点在文件中部，其后新增的变异
#   若 `mutate`/`mutate_gone` 失败只打印 ‼ 而退出码仍 0（实证：M185-a 的模式串 `**27 类**：编号` 在
#   `grep -E` 下属非法重复算子 ⇒ 从未落地，却仍打印「✅ …」与「185/185 全捕获」）⇒ 必须在结论行之前再判一次。
#   注：M186-b 的删除型变异 MUST 用「起止两正则」的地址范围（BSD sed 不支持 GNU 的 `addr,+N`：
#   实测 `sed '/re/,+2d'` 在 macOS 上静默不删、计数仍为 2 ⇒ 该断言会假失败）。
if [ "$MUTFAIL" != 0 ]; then echo "✗ 自检失败：有变异未生效（自检脚本问题）" >&2; exit 2; fi

# F374：结论行 MUST 据实报告**覆盖**（捕获/总数 + 跳过数）——被环境跳过的变异未被执行，
#   不得与已验证的变异同列「全部捕获」（实证：设 `DSH_APP_ROOT` 时 7 项实跑、未设时同 7 项跳过，
#   而旧文案两次都写「全部变异均被对应检查项捕获」；CI 未设该变量 ⇒ CI 恒跳过该族）。
TOTAL_MUT=$(grep -oE 'M[0-9]+' "$0" | sort -u | wc -l | tr -d ' ')
if [ "$FAILED" = 0 ]; then coverage_line "$TOTAL_MUT" "$SKIPPED"; exit 0; fi
echo "✗ 自检失败：存在「注入缺陷却未被对应检查项捕获」的守护——疑似空转，请排查" >&2
exit 1
