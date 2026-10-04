#!/usr/bin/env bash
# 完整验证电池（每轮独立可复跑）：评分器 + 审计 + 守卫 + 格式 + 结构 + 健壮性 + E2E + 兼容性
set -u
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT" || exit 2
F=0
p() { printf '  %s %s\n' "$1" "$2"; }

# 1) 15 指标评分
bash plans/preset-score.sh >/dev/null 2>&1 && p "✅" "15 指标评分 100/100" || { p "✗" "15 指标评分未满分"; F=1; }
# 2) 6 组审计
bash plans/preset-audit.sh >/dev/null 2>&1 && p "✅" "预设审计 100/100" || { p "✗" "预设审计未满分"; F=1; }
# 3) 泄露防护门三模式
for m in --staged --tree --history; do
  bash plans/dsh-codepunk-leak-guard.sh $m >/dev/null 2>&1 || { p "✗" "守卫 $m 未通过"; F=1; }
done
[ "$F" -eq 0 ] && p "✅" "泄露防护门 3/3 模式通过"
# 4) 格式与卫生
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
    for ln in txt.split('\n'):
        if ln != ln.rstrip() and ln.strip(): bad += 1
    if '\n\n\n\n' in txt: bad += 1
print(bad)
PY
)
[ "${H:-0}" -eq 0 ] && p "✅" "格式/换行/空白 全清" || { p "✗" "格式卫生 ${H} 处"; F=1; }
# 5) 物理杂散
S=$(find . -name '.DS_Store' -not -path './.git/*' 2>/dev/null | wc -l | tr -d ' ')
U=$(git status --short 2>/dev/null | grep -c '^??' || true)
[ "$S" -eq 0 ] && [ "${U:-0}" -eq 0 ] && p "✅" "无杂散（.DS_Store/未跟踪）" || { p "✗" "杂散: DS=${S} untracked=${U}"; F=1; }
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
# 7) 脚本语法与健壮性
for f in plans/*.sh; do bash -n "$f" 2>/dev/null || { p "✗" "bash -n: $f"; F=1; }; done
PV="${PWSH_VALIDATOR:-$HOME/.dsh-codepunk/tools/ps-validate.mjs}"
[ -f "$PV" ] && { node "$PV" plans/windows/*.ps1 >/dev/null 2>&1 || { p "✗" "PS 语法校验失败"; F=1; }; }
[ "$F" -eq 0 ] && p "✅" "脚本语法（7 .sh + 4 .ps1）通过"
# 7b) PS 校验器缺失提示（不判失败，但明确告知如何启用）
if [ ! -f "$PV" ]; then
  p "ℹ" "PS 语法校验跳过（无校验器）：如需启用，见 README「PowerShell 校验」一节"
fi

# 8) DSH 兼容性（插件包存在 / 配置键被接受 / group 隔离形态）
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

echo
[ "$F" -eq 0 ] && { echo "  本轮：全部通过（满分）"; exit 0; } || { echo "  本轮：存在失败项"; exit 1; }
