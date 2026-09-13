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
for f in files:
    if not f.endswith('.md'): continue
    txt = open(f, encoding='utf-8', errors='replace').read()
    if len(re.findall(r'^```', txt, re.M)) % 2: sys.exit(1)
    prev = 0
    for m in re.finditer(r'^(#{1,6}) ', txt, re.M):
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

# 8) DSH 兼容性
# DSH 兼容检查所需的 app.asar 位置：由 DSH_ASAR 指定（不硬编码任何平台路径）
ASAR="${DSH_ASAR:-}"
if [ -n "$ASAR" ] && [ -f "$ASAR" ]; then
  M=0
  for pkg in $(grep -oE "@deepseek-ai/(dsh-[a-z-]+)" agent.cordis.yml | sort -u); do
    grep -qaF "$pkg" "$ASAR" 2>/dev/null || M=$((M+1))
  done
  [ "$M" -eq 0 ] && p "✅" "DSH 兼容（24 包全在）" || { p "✗" "缺 ${M} 个包"; F=1; }
else
  p "ℹ" "DSH 兼容检查跳过（未设 DSH_ASAR；如需启用：DSH_ASAR=<app.asar 路径> bash plans/verify-battery.sh）"
fi
# 9) E2E 沙箱
T=$(mktemp -d)
( export DSH_CODEPUNK_HOME="$T/hub"
  bash plans/dsh-codepunk-init.sh >/dev/null 2>&1
  mkdir -p "$T/p" && printf -- '---\ndsh-codepunk: e2e\n---\n' > "$T/p/README.md"
  bash plans/dsh-codepunk-link.sh register -y "$T/p" e2e >/dev/null 2>&1
  bash plans/dsh-codepunk-link.sh resolve "$T/p" >/dev/null 2>&1
  ruby -ryaml -e "d=YAML.load_file('$T/hub/INDEX.yaml'); exit(d['projects'].is_a?(Array) && d['projects'].size==1 ? 0 : 1)" 2>/dev/null
) && p "✅" "E2E（init→register→resolve，YAML 合法）" || { p "✗" "E2E 失败"; F=1; }
rm -rf "$T"

echo
[ "$F" -eq 0 ] && { echo "  本轮：全部通过（满分）"; exit 0; } || { echo "  本轮：存在失败项"; exit 1; }
