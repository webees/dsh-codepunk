#!/usr/bin/env bash
# 完整验证电池（每轮独立可复跑）：评分器 + 审计 + 守卫 + 格式 + 结构 + 健壮性 + E2E + 兼容性
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
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT" 2>/dev/null || { echo "✗ 预设根不存在: $ROOT"; exit 2; }
# 仓库标识校验：存在但非本预设仓库的根路径属「用法/环境错误」（exit 2），
#   否则检查器会在错误的树上判 1、甚至挂起（实测：preset-score 于错误根 rc=124）。
if [ ! -f skills/dsh-codepunk-workflow/SKILL.md ] || [ ! -d plans ]; then
  printf '✗ 根路径不是本预设仓库（缺 skills/dsh-codepunk-workflow/SKILL.md 或 plans/）: %s\n' "$ROOT" >&2
  exit 2
fi

F=0
p() { printf '  %s %s\n' "$1" "$2"; }
# 无法核验 ≠ 通过：环境不满足时显式判失败，避免「生产者失败→空值→静默 ✅」
unverified() { p "✗" "$1（无法核验 ≠ 通过）"; F=1; }

# 1) 15 指标评分
bash plans/preset-score.sh >/dev/null 2>&1 && p "✅" "15 指标评分 100/100" || { p "✗" "15 指标评分未满分"; F=1; }
# 2) 5 组审计（A 配置 / B 手册 / D 调研 / E 文档 / F 工具；无 C 组）
bash plans/preset-audit.sh >/dev/null 2>&1 && p "✅" "预设审计 100/100" || { p "✗" "预设审计未满分"; F=1; }
# 3) 泄露防护门三模式
for m in --staged --tree --history; do
  bash plans/dsh-codepunk-leak-guard.sh $m >/dev/null 2>&1 || { p "✗" "守卫 $m 未通过"; F=1; }
done
[ "$F" -eq 0 ] && p "✅" "泄露防护门 3/3 模式通过"
# 4) 格式与卫生
if ! command -v python3 >/dev/null 2>&1; then
  unverified "格式/换行/空白（缺 python3）"
else
H=$(python3 - <<'PY'
import subprocess
files = subprocess.run(['git','ls-files'], capture_output=True, text=True).stdout.split()
bad = 0
for f in files:
    try: raw = open(f,'rb').read()
    except OSError: continue
    if raw and raw[-1:] != b'\n': bad += 1
    if b'\r\n' in raw and not f.endswith(('.ps1','.cmd','.bat')): bad += 1
    try: txt = raw.decode('utf-8')
    except UnicodeDecodeError: continue
    # F159：先按 splitlines() 断行（同时正确处理 \r\n），避免把 CRLF 的行尾 CR
    #   误判为「尾随空白」——.gitattributes 明确要求 *.ps1 为 CRLF。
    for ln in txt.splitlines():
        if ln != ln.rstrip() and ln.strip(): bad += 1
    if '\n\n\n\n' in txt: bad += 1
print('UNVERIFIED' if not files else bad)
PY
)
if [ "$H" = "UNVERIFIED" ]; then
  unverified "格式/换行/空白（非 git 工作区）"
elif [ -z "${H:-}" ]; then
  unverified "格式/换行/空白（python3 执行失败）"
elif [ "$H" -eq 0 ]; then
  p "✅" "格式/换行/空白 全清"
else
  p "✗" "格式卫生 ${H} 处"; F=1
fi
fi   # command -v python3
# 5) 物理杂散（含被 .gitignore 忽略的游离物——本仓是白名单式 ignore，
#    故任何被忽略文件都是意外产物；原检查只看 .DS_Store 与未跟踪会漏检 .bak 等）
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  unverified "杂散检查（非 git 工作区）"
else
S=$(find . -name '.DS_Store' -not -path './.git/*' 2>/dev/null | wc -l | tr -d ' ')
U=$(git status --short 2>/dev/null | grep -c '^??' || true)
I=$(git status --ignored --short 2>/dev/null | grep '^!!' | grep -v '/\.DS_Store$' | grep -vc '^\.DS_Store$' || true)
[ "$S" -eq 0 ] && [ "${U:-0}" -eq 0 ] && [ "${I:-0}" -eq 0 ] \
  && p "✅" "无杂散（.DS_Store/未跟踪/被忽略游离物）" \
  || { p "✗" "杂散: DS=${S} untracked=${U} ignored=${I}"; F=1; }
fi   # git 工作区检查
# 6) 结构（围栏/标题/引用）
if python3 - <<'PY' >/dev/null 2>&1
import subprocess, re, sys, os
files = subprocess.run(['git','ls-files'], capture_output=True, text=True).stdout.split()

def unfence(txt):
    """去掉围栏代码块内容：块内 `# 注释` 不是 Markdown 标题，误判会造成假阳性。"""
    out, infence = [], False
    for ln in txt.split('\n'):
        if ln.startswith('```'):
            infence = not infence
            continue
        out.append('' if infence else ln)
    return '\n'.join(out)

for f in files:
    if not f.endswith('.md'): continue
    txt = open(f, encoding='utf-8', errors='replace').read()
    if len(re.findall(r'^```', txt, re.M)) % 2: sys.exit(1)
    prev = 0
    for m in re.finditer(r'^(#{1,6}) ', unfence(txt), re.M):
        lvl = len(m.group(1))
        if prev and lvl > prev + 1: sys.exit(1)
        prev = lvl
# 引用检查：只查「本仓引用」——排除 URL 上下文（第三方仓库文件路径属正常引用其源码）
refs = set()
for f in files:
    if not f.endswith(('.md', '.yml')): continue
    for ln in open(f, encoding='utf-8', errors='replace').read().split('\n'):
        if 'http' in ln: continue
        refs |= set(re.findall(r'references/[a-z0-9_-]+\.md', ln))
for r in sorted(refs):
    if not os.path.isfile('skills/dsh-codepunk-workflow/' + r): sys.exit(1)
PY
then p "✅" "结构（围栏/标题/引用目标）通过"; else p "✗" "结构检查失败"; F=1; fi

# 6b) README 目录树 ↔ 仓内文件一致（防清单漂移）
if python3 - <<'PY' >/dev/null 2>&1
import re, os, subprocess, sys
md = open('README.md', encoding='utf-8').read()
m = re.search(r'## 目录结构.*?```text\n(.*?)```', md, re.S)
if m is None: sys.exit(1)          # 目录结构节缺失即失败（README 承诺该节）
stack, resolved = [], []
for line in m.group(1).split('\n'):
    if not line.strip() or line.strip().startswith('#'): continue
    indent = len(line) - len(line.lstrip())
    name = line.strip().split('#')[0].strip()
    if not name: continue
    while stack and stack[-1][0] >= indent: stack.pop()
    parent = stack[-1][1] if stack else ''
    path = os.path.join(parent, name.rstrip('/')) if parent else name.rstrip('/')
    if name.endswith('/'): stack.append((indent, path)); resolved.append(('dir', path))
    else: resolved.append(('file', path))
for kind, path in resolved:
    if kind == 'file' and not os.path.exists(path): sys.exit(1)
    if kind == 'dir' and not os.path.isdir(path): sys.exit(1)
listed = {p for k, p in resolved if k == 'file'}
files = subprocess.run(['git', 'ls-files'], capture_output=True, text=True).stdout.split()
# references/benchmarks 为按需层，不在目录树逐项列出（README 另有说明）
skip = ('skills/dsh-codepunk-workflow/benchmarks/', 'skills/dsh-codepunk-workflow/references/')
if any(f not in listed and not f.startswith(skip) for f in files): sys.exit(1)
PY
then p "✅" "目录树 ↔ 仓内文件一致"; else p "✗" "README 目录树与仓内文件不一致（死条目或漏列）"; F=1; fi
# 7) 脚本语法与健壮性
for f in plans/*.sh; do bash -n "$f" 2>/dev/null || { p "✗" "bash -n: $f"; F=1; }; done
# py：用 ast.parse（不生成 __pycache__，避免污染工作树被杂散检查判失败）
if command -v python3 >/dev/null 2>&1; then
  for f in plans/*.py; do
    [ -e "$f" ] || continue
    python3 -c 'import ast,sys; ast.parse(open(sys.argv[1],encoding="utf-8").read())' "$f" 2>/dev/null \
      || { p "✗" "py 语法: $f"; F=1; }
  done
else
  p "ℹ" "python3 缺失：跳过 plans/*.py 语法校验"
fi
# mjs：node --check（缺 node 时提示，不判失败）
if command -v node >/dev/null 2>&1; then
  for f in plans/*.mjs; do
    [ -e "$f" ] || continue
    node --check "$f" >/dev/null 2>&1 || { p "✗" "mjs 语法: $f"; F=1; }
  done
else
  p "ℹ" "node 缺失：跳过 plans/*.mjs 语法校验"
fi
PV="${PWSH_VALIDATOR:-$HOME/.dsh-codepunk/tools/ps-validate.mjs}"
# F181：按**显式核验计数**构建结论行 —— 未实际核验的类型不得计入「通过」，否则会与「跳过」提示并列误导
SH_CN=$(ls plans/*.sh 2>/dev/null | wc -l | tr -d ' ')
PY_CN=0; command -v python3 >/dev/null 2>&1 && PY_CN=$(ls plans/*.py 2>/dev/null | wc -l | tr -d ' ')
MJS_CN=0; command -v node >/dev/null 2>&1 && MJS_CN=$(ls plans/*.mjs 2>/dev/null | wc -l | tr -d ' ')
PS_CN=0; PS_SUFFIX=""
if [ -f "$PV" ] && command -v node >/dev/null 2>&1; then
  node "$PV" plans/windows/*.ps1 >/dev/null 2>&1 && { PS_CN=$(ls plans/windows/*.ps1 2>/dev/null | wc -l | tr -d ' '); PS_SUFFIX=" + ${PS_CN} .ps1"; } \
    || { p "✗" "PS 语法校验失败"; F=1; }
fi
[ "$F" -eq 0 ] && p "✅" "脚本语法（${SH_CN} .sh + ${PY_CN} .py + ${MJS_CN} .mjs${PS_SUFFIX}）通过"
# 7b) PS 校验器缺失提示（不判失败，但明确告知如何启用）
if [ "$PS_CN" -eq 0 ]; then
  p "ℹ" "PS 语法校验未计入（无校验器或校验未通过）：如需启用，见 README「PowerShell 校验」一节"
fi

# 8) DSH 兼容性（7 项：插件包存在 / 配置键被接受 / group 隔离形态 / allow 名单工具名有注册来源 /
#    锚点顺序 / allow 名单一致性 / agentOptions 覆盖面信息行）
# DSH 0.1.7 起不再打包 app.asar，改为解包 app/ 目录；两种布局都支持，
# 位置一律由环境变量给出（不硬编码任何平台路径）。核验细节见 preset-compat.py。
APPROOT="${DSH_APP_ROOT:-}"
ASAR="${DSH_ASAR:-}"
if [ -n "$APPROOT" ] || [ -n "$ASAR" ]; then
  if python3 plans/preset-compat.py >/dev/null 2>&1; then
    p "✅" "DSH 兼容（插件包 / 配置键 / 隔离形态）"
  else
    p "✗" "DSH 兼容检查未通过（跑 python3 plans/preset-compat.py 看详情）"; F=1
  fi
else
  p "ℹ" "DSH 兼容检查跳过（未设 DSH_APP_ROOT / DSH_ASAR）"
fi

# 8b) preset 声明副本漂移（源 agent.cordis.yml ↔ profile patch 内联块）
# 仅在 js-yaml 可解析时执行（语义比对）；否则跳过，避免折行导致误报。
PP="${DSH_PROFILE_PATCH:-$HOME/.dsh/profiles/desktop/cordis.patch.yml}"
if [ -f "$PP" ]; then
  YAML_OK=0
  for cand in "${DSH_CODEPUNK_TOOLS:-}" "$HOME/.dsh-codepunk/tools" "$APPROOT"; do
    [ -n "$cand" ] && [ -d "$cand/node_modules/js-yaml" ] && { YAML_OK=1; break; }
  done
  if [ "$YAML_OK" -eq 1 ]; then
    if node plans/preset-declare.mjs check --patch "$PP" >/dev/null 2>&1; then
      p "✅" "preset 声明副本与源一致"
    else
      p "✗" "preset 声明副本漂移（跑 node plans/preset-declare.mjs apply）"; F=1
    fi
  else
    p "ℹ" "声明漂移检查跳过（无 js-yaml）"
  fi
fi
# 9) E2E 沙箱（MUST 密闭）
# 陷阱：`dsh-codepunk-home.sh` 会导出 DSH_CODEPUNK_INDEX/PROJECTS/SCRIPTS/WORKTREES，
# 而 SKILL §1.1 恰恰要求先 source 它再开工——若此处只覆盖 HOME，被测脚本会写进
# **真实总库 INDEX**（数据污染）并让随后的临时文件断言必然失败。故须先清空全部
# 同名变量，再只导出沙箱 HOME；并加「真实 INDEX 未被改动」的回归断言。
REAL_INDEX="${DSH_CODEPUNK_INDEX:-$HOME/.dsh-codepunk/INDEX.yaml}"
T=$(mktemp -d)
IDX_BEFORE=$( [ -f "$REAL_INDEX" ] && { cksum "$REAL_INDEX" 2>/dev/null | awk '{print $1"-"$2}'; } || echo "absent" )
( unset DSH_CODEPUNK_INDEX DSH_CODEPUNK_PROJECTS DSH_CODEPUNK_SCRIPTS DSH_CODEPUNK_WORKTREES DSH_CODEPUNK_TOOLS
  export DSH_CODEPUNK_HOME="$T/hub"
  bash plans/dsh-codepunk-init.sh >/dev/null 2>&1
  mkdir -p "$T/p" && printf -- '---\ndsh-codepunk: e2e\n---\n' > "$T/p/README.md"
  bash plans/dsh-codepunk-link.sh register -y "$T/p" e2e >/dev/null 2>&1
  bash plans/dsh-codepunk-link.sh resolve "$T/p" >/dev/null 2>&1
  ruby -ryaml -e "d=YAML.load_file('$T/hub/INDEX.yaml'); exit(d['projects'].is_a?(Array) && d['projects'].size==1 ? 0 : 1)" 2>/dev/null
) && p "✅" "E2E（init→register→resolve，YAML 合法；沙箱密闭）" || { p "✗" "E2E 失败"; F=1; }
IDX_AFTER=$( [ -f "$REAL_INDEX" ] && { cksum "$REAL_INDEX" 2>/dev/null | awk '{print $1"-"$2}'; } || echo "absent" )
if [ "$IDX_BEFORE" = "$IDX_AFTER" ]; then
  p "✅" "E2E 未污染真实总库（INDEX 校验和不变）"
else
  p "✗" "E2E 改动了真实 INDEX：$REAL_INDEX"; F=1
fi
rm -rf "$T"

# 10) 检查器存活自检（变异测试）：在临时副本内注入已知缺陷，断言**对应检查项**必须报错——
#     专治「守护空转」（F097/F099/F101/F102 一整类：工具不可用/正则不兼容/空值判定致恒判 PASS）。
if [ "${DSH_CODEPUNK_SKIP_SELFTEST:-0}" = 1 ]; then
  p "ℹ" "检查器存活自检（已跳过：DSH_CODEPUNK_SKIP_SELFTEST=1——递归防护）"
elif [ -x plans/checker-self-test.sh ] || [ -f plans/checker-self-test.sh ]; then
  # F182：变异数从自检脚本**派生**（曾硬编码「6 项」，而自检已增至 76 项 → 低报核验范围）
  # 与 doc-consistency 的「自检变异项」口径**一致**：唯一 M 号数（含断言/注释中的引用）
  SELFTEST_N=$(grep -oE 'M[0-9]+' plans/checker-self-test.sh 2>/dev/null | sort -u | wc -l | tr -d ' ')
  SELFTEST_N=${SELFTEST_N:-0}
  if bash plans/checker-self-test.sh >/dev/null 2>&1; then
    p "✅" "检查器存活自检（${SELFTEST_N} 项变异均被对应守护捕获）"
  else
    p "✗" "检查器存活自检未通过（疑似守护空转，运行 bash plans/checker-self-test.sh 查看）"; F=1
  fi
else
  unverified "检查器存活自检（缺 plans/checker-self-test.sh）"
fi

# 11) 文档「声称 ↔ 实现」一致性（计数/阶段口径/工具存在性/退出码契约/头部自称项数）
if [ -f plans/doc-consistency.sh ]; then
  if bash plans/doc-consistency.sh >/dev/null 2>&1; then
    p "✅" "文档声称一致性（计数/阶段口径/工具存在性/退出码契约）"
  else
    p "✗" "文档声称一致性未通过（运行 bash plans/doc-consistency.sh 查看）"; F=1
  fi
else
  unverified "文档声称一致性（缺 plans/doc-consistency.sh）"
fi

echo
[ "$F" -eq 0 ] && { echo "  本轮：全部通过（满分）"; exit 0; } || { echo "  本轮：存在失败项"; exit 1; }
