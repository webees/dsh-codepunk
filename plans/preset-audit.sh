#!/usr/bin/env bash
# preset-audit.sh —— dsh-codepunk 预设质量审计（run-score-100 rubric 固化）
# 用法: preset-audit.sh [预设根]   默认取本脚本所在目录的上级（预设根）
# 输出: 5 组（A 配置 / B 手册 / D 调研 / E 文档 / F 工具）逐项 ✅✗ 判定
#       + 末行结论「总分 100/100」或「失分项 N 处」+ 终验（解析/体积/零旧名）
# 注: ① 组字母不连续——历史上无 C 组，A/B/D/E/F 即全部；
#     ② 组标题后的数字（A25/B25/D10/E10/F10）是**分项预算标签**（和为 80，不参与计算），
#        脚本不做分组评分，判定以逐项 ✅✗ 与总失分项数为准。
# 退出码: 0=全项达标；1=存在失分项；2=环境/用法错误（预设根不存在等）
# 依赖: YAML 解析校验任选其一——**ruby 优先**；无 ruby 的主机用 **node+js-yaml**。js-yaml 按候选链
#   查找：$DSH_CODEPUNK_TOOLS → ~/.dsh-codepunk/tools → $DSH_APP_ROOT → $DSH_ASAR 同级 → 预设根
#   （与 preset-declare.mjs / verify-battery.sh / dsh-codepunk-link.sh 同链）。node 侧须用**容忍
#   `!!js` 自定义标签**的 schema（本仓 agent.cordis.yml 含 9 处），否则 js-yaml 抛 unknown tag
#   而 A1 会被误报为「YAML 解析失败」（把环境缺口说成配置非法）。两路都不可用时如实报「无法核验」。
# 环境变量: OLD_NAME=<旧名> 时额外做「品牌卫生」回归检查（默认跳过）

set -u

_EG="$(dirname "${BASH_SOURCE[0]:-$0}")/env-guard.sh"; [ -r "$_EG" ] || { echo "✗ 缺 ${_EG}（无法核验）" >&2; exit 2; }; . "$_EG"  # F195/F197+F421 守卫库
# -h/--help：打印头部用法（与其余脚本一致的通用约定）
case "${1:-}" in
  -h|--help) codepunk_usage 28 ;;
esac
ROOT="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "$ROOT" 2>/dev/null || { echo "✗ 预设根不存在: $ROOT"; exit 2; }   # 2 = 环境/用法错误（与全仓约定一致）
codepunk_need_root "$ROOT" || exit 2


PASS="✅"; FAIL="✗"; LOSE=0
report() { echo "  [$1] $2"; if [ "$1" = "$FAIL" ]; then LOSE=$((LOSE+1)); fi; return 0; }

# F405（依赖预检，MUST）：判据的计数/裁剪管道依赖下列外部命令。缺失时**必须**判「无法核验 ≠ 通过」
#   （rc=2），绝不静默降级为通过 —— 实证：B5 的 `git grep -ic … | awk '{s+=$2}'` 在缺 awk 时得空值，
#   `${N:-0}` 归零 ⇒ 报「B5 全仓零旧名」通过，而旧名实际存在（影子 PATH 实测 rc=0 + 100/100）。
for _t in git awk sed grep cut tr; do
  command -v "$_t" >/dev/null 2>&1 \
    || { echo "✗ 缺少必需工具 ${_t} ⇒ 无法核验 ≠ 通过（rc=2）" >&2; exit 2; }
done

echo "===== dsh-codepunk 预设审计 ====="
echo "[组A 配置层 25]"
# A1 解析合法
parse_ok="skip"
if codepunk_have ruby; then
  # F214：两路径谓词须**语义一致** —— 统一为「name 为**非空字符串**」（旧 ruby 用 key? 仅查键存在，
  #   而 node 用真值判定 → `name: ""`/`null` 在两类主机上结论不同）。
  # F309：ruby >= 3.1 的 Psych 4/5 默认 aliases: false ⇒ 本仓配置的 YAML 锚点/别名
  #   （`&role-allow`/`*role-allow`）会让 YAML.load_file 抛 Psych::AliasesNotEnabled
  #   ⇒ 本机 macOS 系统 ruby 2.6（Psych 3.1）看不出，ubuntu-latest 的 ruby 3.2 必现。
  #   修法：优先带 aliases: true；Psych 3 不认该关键字（ArgumentError）时回退旧调用。
  ruby -ryaml -e 'begin; d=YAML.load_file("agent.cordis.yml", aliases: true); rescue ArgumentError; d=YAML.load_file("agent.cordis.yml"); end; exit(d.is_a?(Array) && d.all?{|r| r.is_a?(Hash) && r["name"].is_a?(String) && !r["name"].empty?} ? 0 : 1)' 2>/dev/null && parse_ok="ok" || parse_ok="fail"
elif command -v node >/dev/null 2>&1; then
  # F351：node 回退分支两处口径修正——
  #   ① 解析路径须与 preset-declare / verify-battery 同候选链（`$DSH_CODEPUNK_TOOLS` →
  #      `~/.dsh-codepunk/tools` → `$DSH_APP_ROOT` → `$DSH_ASAR` 邻位 → 预设根）：旧的 cwd 式
  #      `require("js-yaml")` 会漏掉**文档化**的安装位置，使「按文档装好 js-yaml」的主机仍取不到；
  #   ② 本仓 `agent.cordis.yml` 含 9 处 `!!js` 自定义标签，js-yaml 默认 schema 抛
  #      `unknown tag !<tag:yaml.org,2002:js>`（实测 84:50）⇒ 必须带容忍 schema，
  #      否则**无 ruby 的主机（Windows / 精简镜像）上 A1 恒报「YAML 解析失败」**（把环境缺口
  #      说成配置非法；实测同环境 `preset-declare.mjs check` 却能正常语义比对）。
  A1_JY=""
  for _c in "${DSH_CODEPUNK_TOOLS:-}" "${HOME:-}/.dsh-codepunk/tools" "${DSH_APP_ROOT:-}" \
            "${DSH_ASAR:+$(dirname "${DSH_ASAR}")}" "$ROOT"; do
    [ -n "$_c" ] && [ -d "$_c/node_modules/js-yaml" ] && { A1_JY="$_c/node_modules/js-yaml"; break; }
  done
  if [ -n "$A1_JY" ]; then
    node -e 'const y=require(process.argv[1]),fs=require("fs");const s=y.DEFAULT_SCHEMA.extend([new y.Type("tag:yaml.org,2002:js",{kind:"scalar",resolve:()=>true,construct:d=>String(d)})]);const d=y.load(fs.readFileSync("agent.cordis.yml","utf8"),{schema:s});process.exit(Array.isArray(d)&&d.every(r=>r&&typeof r.name==="string"&&r.name.length>0)?0:1)' "$A1_JY" 2>/dev/null && parse_ok="ok" || parse_ok="fail"   # F214：与 ruby 路径同语义
  else
    parse_ok="noyaml"
  fi
fi
case "$parse_ok" in
  ok)   report "$PASS" "A1 解析 OK" ;;
  fail) report "$FAIL" "A1 YAML 解析失败" ;;
  noyaml) report "$FAIL" "A1 无法核验（有 node 但候选链内未找到 js-yaml：\$DSH_CODEPUNK_TOOLS / ~/.dsh-codepunk/tools / \$DSH_APP_ROOT）——无法核验 ≠ 通过（装 ruby，或按本文件头注的依赖顺序安装 js-yaml 后重跑）" ;;
  skip) report "$FAIL" "A1 无法核验（无 ruby/node，无法解析 agent.cordis.yml）——无法核验 ≠ 通过（装 ruby 或 node 后重跑）" ;;
esac
# A2 岗位 6 维
# F210：A2 计算依赖 python3 —— 缺失时不得让失败消息**为空**（实测缺 python3 时本项输出「[✗] A2 」
#   即「失败却无原因」）。缺失时给出明确缺口说明，与套件「无法核验 ≠ 通过」口径一致。
if codepunk_have python3; then
A2=$(python3 - <<'PYEOF'
import re
s=open("agent.cordis.yml").read()
names=["squad-lead","engineer","sdet","product","research","people","docs","proc-audit","sys-arch","code-review","release-eng"]
ok=sum(1 for n in names if all(d in (re.search(r"tool-subagent-"+n+r".*?persona: \|-(.*?)(?=\n\s+- id:|\Z)",s,re.S).group(1) if re.search(r"tool-subagent-"+n+r".*?persona: \|-(.*?)(?=\n\s+- id:|\Z)",s,re.S) else "") for d in ["你是","边界：","协作：","质量：","禁区：","输出："]))
print("OK" if ok==11 else f"FAIL {ok}/11")
PYEOF
)
else
  A2="无法核验（缺 python3）——无法核验 ≠ 通过"
fi
[ "$A2" = "OK" ] && report "$PASS" "A2 岗位 6 维 11/11" || report "$FAIL" "A2 ${A2:-核验失败但未给出原因（疑似缺运行时）——无法核验 ≠ 通过}"
# A3 无过期注释
[ "$(grep -c 'str_replace' agent.cordis.yml)" -eq 0 ] && report "$PASS" "A3 无 str_replace 残留" || report "$FAIL" "A3 str_replace 残留"
# A5 品牌卫生：如本仓库有改名历史，用 OLD_NAME 环境变量注入旧名做回归检查（默认跳过，不在仓库内硬编码旧名）
if [ -n "${OLD_NAME:-}" ]; then
  # F172：`grep -c` 零命中时输出 0 且退出 1——写 `|| echo 0` 会得到**两行** "0\n0"，
  #   使 [ "$n" -eq 0 ] 报错并走 FAIL 分支（健康仓库被误判失分）。用 || true + 默认值。
  n=$(grep -ic -- "$OLD_NAME" agent.cordis.yml 2>/dev/null || true)
  n=${n:-0}
  [ "$n" -eq 0 ] && report "$PASS" "A5 零旧名（OLD_NAME=${OLD_NAME}）" || report "$FAIL" "A5 旧名残留 $n 处"
else
  report "$PASS" "A5 品牌卫生（未设 OLD_NAME，跳过）"
fi

# A7 配置不变量（机械守护核心契约：可恢复 / 工具面收口 / 岗位在位 / 可派遣）
# F211：A7 依赖 python3；缺失时旧实现得到**空值** → 下一行 `[ -z "$A7" ]` 判为 **PASS**（**假通过**，
#   实测缺 python3 时本项报 [✅]）。改为：缺失即给明确缺口说明，使该项按「无法核验 ≠ 通过」判失败。
if codepunk_have python3; then
A7=$(python3 - <<'PYEOF'
import re, sys
s = open('agent.cordis.yml', encoding='utf-8').read()
# 岗位条目：tool-subagent-* 且非外部后端（codex/claude-code 为一次性、不套本契约）
entries = re.findall(r'    - id: (tool-subagent[a-z0-9-]*)\n(.*?)(?=\n    - id:|\Z)', s, re.S)
bad = []
n_role = 0
for name, body in entries:
    # 只审「派遣条目」：控制面单元（tool-subagent-control / -list-agents 等）本就不带
    # persona/toolFilter/backgroundMode，纳入会误报。
    if "name: '@deepseek-ai/dsh-tool-subagent'" not in body:
        continue
    if name in ('tool-subagent-codex', 'tool-subagent-claude-code'):
        continue
    n_role += 1
    if re.search(r'^      disabled:\s*true', body, re.M):
        bad.append(f'{name} 被 disabled')
    if 'persona:' not in body:
        bad.append(f'{name} 缺 persona')
    if name == 'tool-subagent-fork' or name == 'tool-subagent':
        pass                      # 通用委派两席同样要求过滤与可恢复（下方一视同仁）
    if 'backgroundMode: continuable' not in body:
        bad.append(f'{name} 非 continuable（破坏可恢复/可追问）')
    if 'toolFilter:' not in body:
        bad.append(f'{name} 缺 toolFilter（孩子将回到完整工具面）')
    m = re.search(r'^        maxDepth:\s*(\d+)', body, re.M)
    if m and int(m.group(1)) < 1:
        bad.append(f'{name} maxDepth={m.group(1)}（无法再派遣）')
if n_role < 13:
    bad.append(f'岗位条目仅 {n_role} 个（应 ≥13：11 岗位 + 通用委派 2 席）')
print(' | '.join(bad))
PYEOF
)
else
  A7="无法核验（缺 python3）——无法核验 ≠ 通过"
fi
# F232：**输入存在性守卫** —— `agent.cordis.yml` 缺失时，上述 python 取不到任何条目 ⇒ `A7` 恒空 ⇒ 旧实现报
#   「✅ 配置不变量」= **空输入恒真**（被判据校验的配置根本不存在）。与 F230/F231、F201/B0 的「无法核验 ≠ 通过」口径统一。
[ -z "$A7" ] && [ -f agent.cordis.yml ] && report "$PASS" "A7 配置不变量（可恢复/工具面收口/岗位在位/可派遣）" \
             || report "$FAIL" "A7 配置不变量违规: ${A7:-agent.cordis.yml 缺失——无法核验 ≠ 通过}"

# B1b 全角紧邻陷阱守护：`$VAR` 直接跟全角标点时，bash 会把全角字节并进变量名，
#     在 set -u 下报 unbound variable 并中止脚本（本会话实测在 init.sh 真实发生）。
#     规则：shell 脚本内变量引用后若接全角字符，MUST 用 ${VAR} 形式。
# 注意：MUST 用 `grep -E`（BSD/GNU 皆可）——`grep -P` 在 macOS 自带 grep 上直接报错退出，
#       会让本项恒判 PASS（本守护曾因此长期空转，F097）。grep 退出码 2 = 自身出错，同样判失败。
B1B_RAW=$(grep -nE '(^|[^\\])\$[A-Za-z_][A-Za-z0-9_]*[（）：，。；、「」【】]' plans/*.sh 2>/dev/null); B1B_RC=$?
B1B=$(printf '%s' "$B1B_RAW" | head -3 | cut -d: -f1,2 | tr '\n' ' ' | sed 's/ *$//')   # 裁剪尾部空格：空输出须判空
if [ "$B1B_RC" = 2 ]; then
  report "$FAIL" "B1b 检查自身出错（grep 不可用？）——请核对本项"
elif [ -z "$B1B" ]; then
  report "$PASS" "B1b 无全角紧邻陷阱（变量引用均用 \${VAR}）"
else
  report "$FAIL" "B1b 全角紧邻陷阱（set -u 下会崩栈）: $B1B"
fi

echo "[组B 手册层 25]"
SIZE=$(wc -c < skills/dsh-codepunk-workflow/SKILL.md)
# F201：**内容源最小体量前置守卫**——组 B 的判据多为「缺失即无失分」的形态，空文件/截断手册会让它们
#   **恒真**（实证：`SKILL.md` 清空后本审计仍报「总分 100/100 —— 全项达标」，只有 B1 显示 `0B ≤32768`）。
#   故先核内容源体量：过小即判失分（不能因此满分证明「零失分」）。阈值为保守下限，非质量标尺。
SKILL_BYTES_F201=${SIZE:-0}
[ "${SKILL_BYTES_F201:-0}" -ge 2000 ] \
  || report "$FAIL" "B0 SKILL 内容过少（${SKILL_BYTES_F201}B < 2000B）：空/截断手册下内容判据恒真——无法核验 ≠ 通过"
REF_BYTES_F201=$(cat skills/dsh-codepunk-workflow/references/*.md 2>/dev/null | wc -c | tr -d ' ')
[ "${REF_BYTES_F201:-0}" -ge 2000 ] \
  || report "$FAIL" "B0 references 内容过少（${REF_BYTES_F201}B < 2000B）：同上，判据恒真——无法核验 ≠ 通过"
[ "$SIZE" -le 32768 ] && report "$PASS" "B1 SKILL ${SIZE}B ≤32768" || report "$FAIL" "B1 SKILL ${SIZE}B 超限"
# B5 品牌卫生（全仓）：同样由 OLD_NAME 驱动，排除本脚本自身避免自命中
if [ -n "${OLD_NAME:-}" ]; then
  N=$(git grep -ic -- "$OLD_NAME" 2>/dev/null | awk -F: '{s+=$2}END{print s+0}')
  [ "${N:-0}" -eq 0 ] && report "$PASS" "B5 全仓零旧名" || report "$FAIL" "B5 旧名残留=$N"
else
  report "$PASS" "B5 品牌卫生（未设 OLD_NAME，跳过）"
fi

echo "[组D 调研层 10]"
BMDIR=skills/dsh-codepunk-workflow/benchmarks
D1_UNVERIFIED=0
if ! ls "$BMDIR"/*.md >/dev/null 2>&1; then
  report "$FAIL" "D1 无法核验：$BMDIR 下无 .md 简报（目录缺失或被改名）"
  D1_UNVERIFIED=1
fi
DMISS=$(for f in skills/dsh-codepunk-workflow/benchmarks/*.md; do grep -qcE "支撑决策号|性质" "$f" || echo "$(basename $f)"; done | head -3)
if [ "$D1_UNVERIFIED" = 0 ]; then
  [ -z "$DMISS" ] && report "$PASS" "D1 全基准标决策号" || report "$FAIL" "D1 缺: $DMISS"
fi

# D3 源码行号引用守护：行号须与符号名同行（行号会随重排漂移，单留行号即成死指针）
NOPY=0
if ! codepunk_have python3; then
  report "$FAIL" "D3/E3 无法核验：缺 python3（无法核验 ≠ 通过）——装 python3 或手工核对"
  NOPY=1
fi
# F212：`2>/dev/null` 必须落在 **python3 之后**（命令替换内部）——放在外层 `) 2>/dev/null` 时，
#   内部 python3 的 stderr 仍会漏出（实测缺 python3 时漏 2 行 `command not found`）。
D3=$(python3 - <<'PYEOF' 2>/dev/null
import re, subprocess
# F419（本轮对抗实测）：MUST 用 `-z` 并按 NUL 切分 —— `.split()` 按空白分词，文件名含空白时被拆碎，
#   随后 `open()` 抛异常 ⇒ 本项报「无法核验（python3 执行失败）」= **错误归因**（实证：沙箱内
#   `docs/advm probe 'quote'.md` 使 D3/E3 双项 rc≠0）。同族站点见 preset-score A2 / verify-battery。
files = [f for f in subprocess.run(['git','ls-files','-z'],capture_output=True,text=True).stdout.split('\0')
         if f.endswith('.md')]
if not files:
    # F388（本轮对抗实测）：说谎/异常 git（exit 0 零输出）或 GIT_DIR/GIT_WORK_TREE 误设时 `git ls-files`
    #   返回空 ⇒ 下方循环空转却 report PASS（「行号引用均附符号名」「仓内相对链接均可达」）——否决式计分下
    #   直接得到 100/100 假满分（与 F299 同类，F299 修的是 doc-consistency 类 8）。故回退文件系统遍历
    #   （真核验，非跳过）；遍历仍为零则打印 NOFILES 由 shell 侧判「无法核验」。
    import os
    for _dp, _dns, _fns in os.walk('.'):
        _dns[:] = [d for d in _dns if d != '.git']
        for _fn in _fns:
            if _fn.endswith('.md'):
                files.append(os.path.relpath(os.path.join(_dp, _fn), '.'))
    if not files:
        print('NOFILES')
        raise SystemExit(0)
bad = []
sym = re.compile(r'`[A-Za-z_][A-Za-z0-9_]*(?:\(\))?`|`[A-Za-z_][A-Za-z0-9_.]*\(`')
for f in files:
    for i, ln in enumerate(open(f, encoding='utf-8', errors='ignore'), 1):
        if not re.search(r'\.(?:js|mjs|sh|py|ps1):[0-9]+', ln):   # F218：范围从「仅 .js」扩到全部脚本类型（理由对 .sh/.py/.mjs/.ps1 同等适用）
            continue
        if not sym.search(ln):
            bad.append(f'{f}:{i}')
print(' '.join(bad[:3]))
PYEOF
); D3_RC=$?
if [ "$NOPY" = 1 ]; then
  :                                  # 上方已报「无法核验」，勿重复
elif [ "${D3_RC:-1}" != 0 ]; then
  report "$FAIL" "D3 无法核验（python3 执行失败，退出码 ${D3_RC}）——无法核验 ≠ 通过"
elif [ "$D3" = "NOFILES" ]; then
  report "$FAIL" "D3 无法核验（git 枚举为空且文件系统遍历未找到 .md）——无法核验 ≠ 通过"
elif [ -z "$D3" ]; then
  report "$PASS" "D3 行号引用均附符号名（可复核）"
else
  report "$FAIL" "D3 行号引用缺符号名（行号会漂移）: $D3"
fi

echo "[组E 文档层 10]"
EC=$(grep -c "^## " README.md)
[ "$EC" -ge 7 ] && report "$PASS" "E2 README ${EC} 节 ≥7" || report "$FAIL" "E2 README ${EC} 节 <7"

# E3 仓内相对链接可达性（死链 = 读者可见缺陷；实测原三检查器全漏）
E3=$(python3 - <<'PYEOF' 2>/dev/null
import os, re, subprocess
# F419：同 D3 —— `-z` + 按 NUL 切分（`.split()` 分词 ⇒ 含空白文件名被拆碎 ⇒ 异常 ⇒ 错误归因）
files = [f for f in subprocess.run(['git','ls-files','-z'],capture_output=True,text=True).stdout.split('\0')
         if f.endswith('.md')]
if not files:
    # F388：同上一处（同文件的第二份叙述曾逐字重复，F453）——回退文件系统遍历做真核验；
    #   遍历仍为零则打印 NOFILES，由 shell 侧判「无法核验 ≠ 通过」。
    import os
    for _dp, _dns, _fns in os.walk('.'):
        _dns[:] = [d for d in _dns if d != '.git']
        for _fn in _fns:
            if _fn.endswith('.md'):
                files.append(os.path.relpath(os.path.join(_dp, _fn), '.'))
    if not files:
        print('NOFILES')
        raise SystemExit(0)
bad = []
for f in files:
    txt = open(f, encoding='utf-8', errors='ignore').read()
    out, infence = [], False
    for ln in txt.split('\n'):
        if ln.startswith('```'):
            infence = not infence
            continue
        out.append('' if infence else ln)
    body = '\n'.join(out)
    for m in re.finditer(r'\]\(([^)\s]+)\)', body):
        t = m.group(1).strip().strip('<>')
        if t.startswith(('http://', 'https://', 'mailto:', 'tel:', '#')):
            continue
        t = t.split('#')[0]
        if not t:
            continue
        if os.path.exists(t) or os.path.exists(os.path.join(os.path.dirname(f), t)):
            continue
        bad.append(f'{f} → {t}')
print(' '.join(bad[:3]))
PYEOF
); E3_RC=$?
if [ "$NOPY" = 1 ]; then
  :                                  # 上方已报「无法核验」，勿重复
elif [ "${E3_RC:-1}" != 0 ]; then
  report "$FAIL" "E3 无法核验（python3 执行失败，退出码 ${E3_RC}）——无法核验 ≠ 通过"
elif [ "$E3" = "NOFILES" ]; then
  report "$FAIL" "E3 无法核验（git 枚举为空且文件系统遍历未找到 .md）——无法核验 ≠ 通过"
elif [ -z "$E3" ]; then
  report "$PASS" "E3 仓内相对链接均可达"
else
  report "$FAIL" "E3 死链: $E3"
fi

echo "[组F 工具层 10]"
# F423：正向对照（源 → 总库）此前只含 `plans/*.sh`（与 Windows 侧 `.ps1`），**缺 `plans/*.py`/`plans/*.mjs`**
#   ⇒ 这两类脚本的**总库副本陈旧时 F2 仍报「✅ plans↔scripts 同步」**：实测 `plans/preset-compat.py`
#   比总库副本多 9 行（F366 的 `-h` 用法块），而审计 100/100、评分满分、doc rc=0、自检 rc=0 全绿，
#   只有 `plans/dsh-codepunk-init.sh --check` 报「缺失/过期 1 个」（且不点名文件）。此处把正向对照的
#   扩展名集合与**反向对照**（`scripts/*.sh|*.py|*.mjs`）对齐，消除单向覆盖缺口。
FSYNC=$(for p in plans/*.sh plans/*.py plans/*.mjs; do f=$(basename "$p"); diff -q "$HOME/.dsh-codepunk/scripts/$f" "$p" >/dev/null 2>&1 || echo "${f%.*}"; done)
# Windows 侧（plans/windows/*.ps1）与总库 scripts/ 同源对照
WSYNC=$(for p in plans/windows/*.ps1; do [ -f "$p" ] || continue; f=$(basename "$p"); diff -q "$HOME/.dsh-codepunk/scripts/$f" "$p" >/dev/null 2>&1 || echo "${f%.ps1}"; done)
FSYNC="$(printf '%s %s' "$FSYNC" "$WSYNC" | tr -s ' ' ' ' | sed 's/^ *//; s/ *$//')"
# F235：**源侧存在性守卫** —— 旧 F2 只对照「**已存在**」的源文件，故**删光源副本即恒真**
#   （实测：`plans/` 仅剩 `preset-audit.sh` 时 F2 竟报「✅ plans↔scripts 同步」且审计总分 100/100）。
#   此处反向核对：镜像中**带脚本扩展名**的文件（排除 `init` 安装的无扩展名 CLI 入口包装）必须在
#   `plans/`（或 `plans/windows/`）有源副本，否则视为「源副本缺失」而失败。
FSRC_MISS="$(for h in "$HOME"/.dsh-codepunk/scripts/*.sh "$HOME"/.dsh-codepunk/scripts/*.py "$HOME"/.dsh-codepunk/scripts/*.mjs; do
  # F269：旧实现在此对**非普通文件**一律 `continue` ⇒ hub 内的**悬空符号链接**（`-f` 为假）
  #   被**静默跳过**：实测在真 hub 注入 dangling 链接后，审计仍报「[✅] F2 plans↔scripts 同步」
  #   且总分 100/100 ⇒ 损坏入口对门禁不可见（假绿）。此处对两类非普通文件**点名计入 F2 失败**。
  if [ -L "$h" ] && [ ! -e "$h" ]; then echo "悬空入口:$(basename "$h")"; continue; fi
  if [ ! -f "$h" ]; then echo "非普通文件:$(basename "$h")"; continue; fi
  b="$(basename "$h")"
  [ -f "plans/$b" ] || [ -f "plans/windows/$b" ] || echo "${b%.*}"
done | tr '\n' ' ')"
[ -n "${FSRC_MISS// /}" ] && FSYNC="$(printf '%s 源副本缺失: %s' "$FSYNC" "$FSRC_MISS" | sed 's/^ *//')"
# F285：hub **完全缺失**（未安装/全新 HOME/CI）时，旧实现让每个源副本 diff 都失败 ⇒ 报
#   「F2 不同步: <首个脚本名>」，把「**无法核验（未安装）**」说成「**内容不同步**」⇒ 误导诊断
#   （实测：`HOME=/tmp/DH42` 无 hub ⇒ 「[✗] F2 不同步: acceptance-verify」）。
#   此处显式分列：**仍判 FAIL**（不放松判据），但点名真实原因并给出安装指引。
if [ ! -d "$HOME/.dsh-codepunk/scripts" ]; then
  report "$FAIL" "F2 无法核验: hub 未安装（$HOME/.dsh-codepunk/scripts 不存在）⇒ 先跑 plans/dsh-codepunk-init.sh"
else
  [ -z "$FSYNC" ] && report "$PASS" "F2 plans↔scripts 同步" || report "$FAIL" "F2 不同步: $FSYNC"
fi

echo
echo "===== 审计结论 ====="
if [ "$LOSE" -eq 0 ]; then
  echo "总分 100/100 —— 全项达标"
  echo "（计分口径：**否决式** —— 零失分即 100/100；组头数字为相对权重，非累加项）"
else
  echo "失分项 $LOSE 处 —— 见上方 $FAIL"
fi
[ "$LOSE" -gt 0 ] && exit 1 || exit 0
