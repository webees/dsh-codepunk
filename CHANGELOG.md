# CHANGELOG · 更新日志

本仓遵循 [Keep a Changelog 1.1.0](https://keepachangelog.com/zh-CN/1.1.0/) 与[语义化版本 2.0.0](https://semver.org/lang/zh-CN/)。
**版本以 git tag 与本文件为唯一权威**（`preset.yml` 只承载展示元数据，不含版本字段）；发布流程见 `CONTRIBUTING.md`，治理与发布权限见 `GOVERNANCE.md`。

段内分类固定如下，不新增类别、不改变语义：

| 类别 | 用途 |
|---|---|
| 新增 Added | 对外可用的新能力、新文件、新门禁 |
| 变更 Changed | 既有行为的调整（含破坏性变更，须显式标注） |
| 弃用 Deprecated | 仍可用但计划移除的能力 |
| 移除 Removed | 已删除的能力或文件 |
| 修复 Fixed | 缺陷修复 |
| 安全 Security | 与安全相关的修复或加固（不含可利用细节） |

---

## [Unreleased]

### 修复
- **跨文件与同文件复制形态的判据声称被更正（F472）**：内容治理第 10 轮的变异 M225-b 与 D129、F470 条目曾把「许可正文被复制回文档」一律写成由 A5 精简度「成段重复」拦截，实测两种形态分属不同判据——把 `LICENSE` 正文复制回 `docs/licensing.md`（跨文件）命中的是 B16「跨文件重复行冗余 7173 字节 > 上限 7000」（上限已按 D118 棘轮，正好挡下被削减前的原值），只有同一文件内复制两份才由 A5「成段重复」命中（同时 B16 报 8214 字节）。修法：M225 夹具按份数参数化（`${_m225_copies:-1}`，1 份与 2 份各一条断言，并加「跨文件形态 MUST NOT 由成段重复代答」的反向断言），D129 与 F470 条目改为写明判据分工。实证：`logs/r663/i-m225-repro3.txt`（1 份 ⇒ B16 7173/7000，A5 满分）、`logs/r663/i-m225-repro4.txt`（2 份 ⇒ A5 成段重复 + B16 8214/7000）、`logs/r663/i-m225-repro2.txt`（HEAD 版文档已含正文再追加 ⇒ 仅 A5）。
- **依赖缺失矩阵把等效回退误判为假绿灯（F471）**：工位仪器 `tools/dep-matrix.py` 的判据是「脚本引用的命令被剥离后仍 rc=0 且无保守说明 ⇒ 假绿灯」，未考虑**同链替代**——本仓 `agent.cordis.yml` 的 YAML 解析本就是「ruby 优先、node+js-yaml 回退」（`plans/preset-audit.sh` 头部依赖说明），剥离 node 后走 ruby 分支得满分是**正当通过**，却被报为假绿灯（实测 2 处：`node × preset-audit.sh`、`node × preset-score.sh`）。修法：新增 `EQUIV`（node↔ruby）与 `equiv_ok()`，替代命令**在影子 PATH 可用且脚本确实引用它**时判「ℹ 等效回退（正当通过）」而非假绿灯，并新增 `--selftest`（4 用例：等效在场／未引用替代／替代不在 PATH／保守拒答）作为守护；复跑后「假绿灯 0 处（ℹ 等效回退 2 处）」。
- **用法打印的失败分支不可达且空用法静默通过（F466，自引入并修复）**：`codepunk_usage` 首版写成 `sed … | sed … || { 拒答 2 }` ⇒ 管道退出码只反映**末段** sed（首段 sed 打不开 `$0` 也照样 rc=0），失败分支**永不可达**；且行区间超出脚本长度时打印空用法后仍 `rc=0`——正是本仓反复立案的「静默假通过」形态（同族 F460）。实证：`bash -c '. ./env-guard.sh; codepunk_usage 3'` 输出 `sed: bash: No such file or directory` 但 `rc=0`、无任何保守措辞。修法：**先取文本再判空**（取文本失败、文本为空各自拒答 2），再经格式管道打印；M223-c/d 以「超界行区间」夹具守住该分支。
- **工位仪器把运行根产物、示例与占位当失效路径（F462，自引入并修复）**：`tools/registry-audit.py` 的 `changelog` 子命令判定「引用不存在」时只看**行内字面**「运行根」，而实况里的运行根引用多以文件名出现（`tools/junk-dup-scan.py`、`tools/ref-graph.py`、`tools/package.json` 等）⇒ 8 处假红 ⇒ 巡检读数失去可信度（假红与真红混在一起）。修法：语境词集合（运行根／总库／工位仪器）＋示例占位集合（示例／占位／形态／形如／伪路径／例如）＋实况根解析（本工具上一级目录＝运行根；`$DSH_CODEPUNK_HOME`＝总库，并回退 `tools/<名>` 子路径）⇒ rc=0「296 处引用 · 不存在 0 · ℹ 豁免 18（分类计数）」。
- **编号宽度判据把审计检查 ID 当缺陷号（F463，自引入并修复）**：`tools/registry-audit.py` 的 `fnumbers` 把 CHANGELOG 里的检查 ID（`F2`、`B5/D1/F2`）当两位缺陷号 ⇒ 该子命令 **rc=0 不可达**（永久红），与同文件下一行自述「检查 ID 不参与退出码」自相矛盾——永久红会被读者忽略（警报疲劳）。修法：宽度域收窄为**缺陷号槽位**（`（F<一位或两位>）`），槽位外的两位形态改记 ℹ；rc=0 恢复可达。
- **幂等判据把契约内的保守拒答当成非幂等（F464，自引入并修复）**：`tools/make-matrix.py` 的判据 G 要求两次运行都 `rc=0`，而 `make compat` 在未设 `DSH_APP_ROOT`／`DSH_ASAR` 时按契约 `rc=2` 保守拒答（`Makefile` 自带用法提示）⇒ 合格行为被报 ✗。修法：仅**两次行为不一致**才判 ✗；`rc=2` 归 ℹ「保守拒答（环境前提缺失，不算失败）」。
- **新增「条目前缀完整性」判据恒不触发（F460，自引入并修复）**：段标记原写成 `if _raw.startswith('## '): _sec = _raw.startswith('### ')` —— 以 `### ` 起头的行第 3 字符是 `#` 而非空格，**永不匹配** `'## '` ⇒ 段标记恒 `False`、`CHANGELOG.md` 全文件被跳过，判据零触发却报「列表条目前缀齐备」（自检 M222-a 首跑即捕获，证明该变异有效）。修法：段起改 `if _raw.startswith('### '): _sec = True`、段止改 `if _raw.startswith('## '): _sec = False`；合法行白名单扩为 `- ` / `* ` / `+ ` / 2–4 空格或制表符续行 / `> ` / `|` / `#` / 围栏 / 主题分隔线（`---`、`***`、`___`）——修前真实 `CHANGELOG.md:283` 的 `---` 会被误报。红绿证：注入态 rc=1 且点名 `CHANGELOG.md:22(：条目前缀丢失探针)`，真实态 rc=0。
- **依赖探针迁移漏一处（F461，自引入并修复）**：`plans/verify-battery.sh` 的「# 7) 脚本语法与健壮性」段前置探针 `if command -v python3 >/dev/null 2>&1; then` 未随本轮迁移入守卫库 ⇒ 内联形态实际 2 处、D126 的「至多 1 处」不成立（自检 M221-b 首跑即捕获）。修法：改 `if codepunk_have python3; then`；复扫内联形态 1 处（仅 M85 锚点）。
- **两处自检夹具与「被核验面」耦合而脆弱（F458）**
- **CHANGELOG 条目前缀丢失且无任何判据核验（F459）**：文档补丁在 4 条条目上把 `- **标题**：` 前缀丢掉（行首变成全角冒号）⇒ GFM 下渲染为上一列表项的**续段**，条目标题不可检索；而四门禁 + 全量自检 + 评分**全绿**——此前无任何判据核验 Markdown 列表条目形态。修法：恢复 4 处前缀（`F446`/`F443`/第 29 类/上限下调各 1 条）+ 文档门第 24 类新增「条目前缀完整性」子判据（`CHANGELOG.md` 的 `### …` 段内正文行 MUST 以 `- ` 起行或为 2 空格续行）+ 存活自检 **M222**（夹具注入无前缀行 ⇒ 须报；摘掉判定 ⇒ 不再报）。：① M212 的计数口径变更夹具只改 README 声称与 `preset-score.sh` 实况，未同步 `Makefile` 声称 ⇒ 本轮新增的 Makefile 计数声称域**正确地**报红，暴露夹具缺陷（口径整体变更 MUST 连带同步域内全部声称）；② M213 的重复行夹具（8 文件 ×3 行）只**勉强**越阈——本轮合法去重（F452/F453/F454）把全仓重复行总量从 12351 B 降到 9341 B 后，夹具总量 11798 B 掉到上限 12000 B 之下 ⇒ 断言空转假红。修法：M213 夹具改「行长 ×8 ≈ 936 B × 20 文件」（实况重复块 ≈18 KB / 重复行 ≈27 KB，余量 ≈15 KB），M212 夹具连带同步 `Makefile` 声称。
- **工位仪器只报重复块的「首处」行号（F451）**：多文件重复块在原报告里只有一个 `start` 字段，读者按同一行号到**另一文件**定位必然错位（本轮逐行核对即误读一次）⇒ `tools/junk-dup-scan.py` 现输出每一处出现的 `file:line`（JSON 增 `occ` 字段，报告行呈 `a.py:26 · b.py:32` 形态）。
- **同一段 F198 叙述在两处 python 工具逐字重复（F452）**：`plans/fidelity-gate.py` 与 `plans/preset-compat.py` 的 stdout-UTF-8 说明 4 行完全相同（跨文件重复块 231 B ×2）⇒ 两侧各压成 2 行并留指向（判据可报的重复块归零；两处同名代码片段 6 行低于判据字节门槛，作为「工具须独立可执行」记录）。
- **同一段 F388 叙述在同一文件内重复（F453）**：`plans/preset-audit.sh` 的 D3/E3 两处各有 5 行同文（同文件重复块 208 B ×2）⇒ 第二处改单行指向，同文件重复块归零。
- **CI 两个作业各含同一段 PowerShell 依赖三联行（F454）**：`ci.yml` 作业 1/2 的 `npm init` / `npm i tree-sitter …` / `node plans/ps-validate.mjs …` 逐字重复（212 B ×2，同文件重复块）⇒ 抽为 Makefile 的 `ps-validate` 目标作**单一声明源**，两个步骤变为 `run: make ps-validate`（依赖落位＝总库 `tools/`，与原 `$HOME/.dsh-codepunk/tools` 等价）。
- **Makefile 的指标计数声称陈旧且不在门禁域（F455）**：`Makefile` 声称「15 指标评分」而实况 16（`bash plans/preset-score.sh` ⇒ 16/16），四门禁全绿——计数声称域只到 README + `docs/**`（F327/F338/F425 同族）。修法：更正为 16，并把第 1 类的**域扩到 `Makefile`**（识别 `N 指标` 与 `N 项独立验证/一次跑完`，逐处比对实现值），新增存活变异 **M220**（夹具把 16 改成 15 ⇒ 须报；摘掉判定 ⇒ 不再报）。
- **新仪器把夹具输入与占位符当失效引用（F456）**：`tools/ref-graph.py`（本轮新增的脚本引用图仪器）把 `plans/checker-self-test.sh` 内**故意不存在**的 `plans/no-such-*.sh` 等**测试输入**、以及文档占位示例 `plans/X.sh`（D105 命令表用法形态）判为「悬空引用」，16 处全为假阳性 ⇒ 排除「夹具载体」与「占位形态」两类后真读数 0，仍保留「真悬空引用必被点名」的口径。
- **`make ps-validate` 在存量总库目录下失败且无提示（F457）**：总库 `tools/package.json` 若锁定 `tree-sitter@^0.22` 而 `tree-sitter-powershell@^0.26` 要求更高 peer，npm 报 ERESOLVE（实证：原始 CI 三联行配方在同一存量目录同样 rc=1，非抽取引入）⇒ 目标改为**失败即 rc=2 并给出可操作提示**（`rm -rf <总库>/tools && make ps-validate`）；洁净 HOME 下 rc=0、全部 PS 脚本语法通过。
- **空枚举被当作「无法核验」放弃了可核验项（F449）**：第 29 类原实现只在 `git ls-files` 退出码非 0 时回退文件系统遍历，**退出码 0 但空结果**（索引损坏 / 空索引）直接被判「无法核验 ≠ 通过」 ⇒ ① 放弃本可完成的核验；② 污染终局归因计数——实测 `GIT_INDEX_FILE=/nonexistent-advm` 下「无法核验」由 1 处变 2 处，连带 M205-a/M205-b 的归因断言口径漂移。修法：空结果与失败同路回退文件系统遍历做**真核验**（99 个文本文件照检），仍为空才判无法核验；新增存活自检 M219（a 回退生效 / b 摘掉回退 ⇒ 退回「文件枚举为空」，证明非空转）。
- **夹具自身制造 .editorconfig 违规（F450）**：M194 以 `printf` 追加注入行、再以 `sed -i.bak '/…/d'` 删除——删除后**文件尾部留下双换行**（实测复现：尾部 4 字节 `\x80\x82\n\n`）⇒ 触碰本轮新增的第 29 类，M194-b「移除注入后须复归 rc=0」变为 rc=1。修法：夹具改为**字节级还原**（注入前 `cp` 基准，删除阶段直接还原），断言语义不变。
- **`.editorconfig` 声明的形态规则长期零门禁（F446）**：`[*]` 节声明 `trim_trailing_whitespace` / `insert_final_newline` / `end_of_line=lf`（`[*.ps1]` 覆写 crlf / `[Makefile]` 覆写 tab），而仓内唯一相关门禁（文档门第 17 类）只核 `.ps1` 的 CRLF ⇒ 实测 `skills/dsh-codepunk-workflow/references/file-hygiene.md` 尾部为**两个换行**（违反 `insert_final_newline`）而**四门禁全绿、评分满分**。修法：删多余空行（35216 → 35215 字节）+ 文档门新增**第 29 类**（以声明为唯一依据，缺 python3 / 缺 `.editorconfig` / 枚举为空 ⇒ 「无法核验 ≠ 通过」rc=2，git 枚举不可用回退文件系统遍历真核验）+ 存活自检 M218。
- **工位仪器把声明外的项目当硬判（F447）**：`tools/content-junk-scan.py` v1 三处假阳性——把 CRLF 文件的 `\r` 判成行尾空白（4 个 `.ps1` 共 732 条）、把 `plans/patrol-check.sh` 里 sed/split 的**功能性制表符**判成缩进违规、把无声明上限的超长行当硬判。修法：按声明 EOL 先剥行尾 CR、制表符只在 `indent_style=space` 且**行首**缩进时计、无声明即降为 ℹ（A/B：`logs/r658/j1-junk.txt` 四类超阈 → `j2-junk.txt` 仅 1 类真实违反）。
- **样板校验在 4 个门禁里各写一遍（F443）**：`doc-consistency`/`preset-audit`/`preset-score`/`verify-battery` 各自内联同一段「根路径须为本预设仓库」校验（5 行 ×4），构成跨文件重复块（217 B ×3）与样板重复行（837 B）。修法：抽入 `plans/env-guard.sh` 的 `codepunk_need_root`（库内 1 处实现，消费方 `codepunk_need_root "$ROOT" || exit 2` 单行调用），错误根仍以 rc=2 拒答、消息不变。新增永久变异 **M217**（a：库函数对错误根返回 2 并点名；b：削弱库内 `return 2` ⇒ 不再点名；c/d：枚举器基线干净 ⇔ 摘掉调用点即点名该文件）。
- **装饰性分隔线是重复行冗余的最大单一来源（F444）**：纯规则行 81 行 + 含长横线注释行 36 行分布在 25 个文件（`# =====`/`# -----` 各 45 字符），跨文件重复行冗余合计约 3.7 KB，无任何语义。修法：纯规则行收敛为 `# ` + 6 字符、行内长横线压到 4 字符（按字节改写、保持行尾，`.ps1` 的 CRLF 不变），并以决策 **D124** 固定形态。

- **F441（medium，自引入，已修复，接入面）**：接入式用 `${BASH_SOURCE[0]%/*}` 推导库目录，在**裸文件名调用**（`cd scripts && bash dsh-codepunk-leak-guard.sh …`，此时 `BASH_SOURCE[0]` 无目录段）下**不剥离任何内容**，拼出 `脚本名/env-guard.sh` 伪路径 ⇒ 库就在同目录也报「缺库」（rc=2）。**实证**：浅克隆夹具补齐库后仍 rc=2（✗ 缺 dsh-codepunk-leak-guard.sh/env-guard.sh（无法核验））。修法：改用 `dirname "${BASH_SOURCE[0]:-$0}"`（裸名得 `.`）；新增 **M215-e/e2**（裸名调用须到达判据、MUST NOT 误报缺库）。
- **F440（medium，自引入，判据面）**：`docs/development.md` 的目录清单行把扩展名计数改成「17 个 `.sh`〔含 … 两个纯 source 库〕 + 3 个 `.py`」后，计数之间被插入括号散文 ⇒ 声称核验的 chain 正则失配，**该声称脱离核验面**，而门禁仍报「未出现 plans 扩展名计数声称」（假绿），连带把 `M209-a` 变异变成「锚点缺失」。修法：① 恢复紧邻链式形态（散文移到链后）；② 新增**目录行严格链**判据（MUST 由 `.sh` 计数起链——通用 chain 仅凭`.py` + `.mjs` 两段仍可成链）；③ 新增 **M216-a/b** 两态对照（插散文 ⇒ rc=1 点名「不可解析」；削弱判据 ⇒ 不再点名）。
- **F439（medium，自引入，夹具口径）**：抽库把「脚本自足」变成「脚本 + 同目录库」，而自检里**隔离单脚本**的既有夹具（M117/M121 删掉除被测脚本外的全部 `plans/*.sh`；M195 把门禁单独 `cp` 到浅克隆/空仓库目录；M210-c 把削弱副本放在`$work/m210/` 执行）都只提供那一个脚本 ⇒ 六条断言在到达被测判据前就因「缺库 rc=2」失败（首跑读到 M117/M121/M195-a/M195-b/M195-d/M210-c 全红，且被误当成「自检自身问题」）。修法：夹具侧**连带提供库**并注明「库是运行时单元的一部分」；纪律写入 D123 扩展。
- **F442（low，自引入，判据面）**：`plans/doc-consistency.sh` 第 5 类的**空输入哨兵**（F231：`plans` 下无可检脚本时判「无法核验 ≠ 通过」）以「`plans/*.sh *.py *.mjs` 中除 `doc-consistency.sh` 外还有文件」为触发条件，未排除纯 source 库 ⇒ 抽库后夹具里只要留下 `env-guard.sh`，哨兵**永不再触发**（实测 M117 从 ✅ 变 ✗）。修法：哨兵域与 CLI 入口域同口径排除 `env-guard.sh`、`dsh-codepunk-home.sh`（纯 source 库无 CLI/判据/退出码契约面）。
- **守卫抽库后靶点搬家、且缺库/未接入无守护（F437）**：把 locale 固定块与 POSIX 拒答块抽成 `plans/env-guard.sh` 后出现两处**守护面真空**——① 存活自检 M203-b 的**削弱靶点**写在内联守卫行上，抽库后该行不复存在，变异报「未生效」并把整轮自检判成「自检自身问题」（假失败）；② 当时**没有任何变异**覆盖「库缺失」与「消费方未接入」：删库或摘掉接入行即同时失去 locale 固定与 POSIX 拒答，而门禁仍全绿（静默降级）。修法：M203-b 改靶 `plans/env-guard.sh`；新增 **M214**（删库 ⇒ `doc-consistency`/`preset-score`/`leak-guard` 三条链路 rc=2 且点名「缺 plans/env-guard.sh」，证明不会静默跳过）与 **M215**（影子 `locale` 夹具确定性验证 F195 生效 + 机械枚举 `plans/*.sh` 断言全部接入，并给出「摘掉一个接入行 ⇒ 枚举器点名该文件」的削弱对照）；`plans/doc-consistency.sh` 的「运行型入口 MUST 实现 `-h`」判据域显式排除纯 source 库（`dsh-codepunk-home.sh` 之外新增 `env-guard.sh`），M203-a 的 POSIX 拒答域随之纳入原先未接入的 `plans/git-merge-flow.sh`（该脚本输出含中文，此前未固定 locale）。决策登记 **D123**。
- **首版接入行自身成为跨文件重复块（F438）**：15 个消费方的接入行 217 字符，与各文件内相同的 `set -u`/空行组成 3 行窗口，触发 B16 的**跨文件重复块**判据（2943 → 3890 字节，超过 §7.1 的 3800 上限）⇒ 抽库这一轮反而让重复度指标变差。修法：接入行缩短到 130 字符（最长 3 行窗口 ≈146 字符 < 200 的窗口下限，不再成块），重复块冗余回落到 **1102 字节**。
- **内容卫生仪器的上限与判据口径分裂（F433）**：工位仪器 `tools/junk-dup-scan.py` 的 `--max-kb` 缺省为**硬编码 200KB**，而判据 B16 的同一上限从 `docs/development.md` §7.1 解析（262144 字节）⇒ 同一文件（`plans/checker-self-test.sh` 223457 字节）在 B16 下合规、在仪器下报「超限文件 1 个」，仪器读数无法直接当回归基线。修法：新增 `docs_limits()` 从 §7.1 解析三项上限，三个阈值参数缺省 **0 = 派生**，正文首行标注阈值源；解析不到时单文件上限回退 256KB 并标注「无法核验 ≠ 通过」（与 D117 单一声明源一致）。
- **B16 重复度两条子判据无守护（F434）**：存活自检 M211 只覆盖单文件上限、溯源档案索引缺口、孤儿内容三条，**跨文件重复块**与**跨文件重复行**两条从未被注入缺陷 ⇒ 判据被删、阈值被误改或解析失效都不会被报出。新增变异 **M213**：同一 3 行块写入 8 个跟踪文件，`M213-a`/`M213-b` 断言两条子判据各自命中（夹具后重复块冗余 2943→7329 字节、重复行冗余 16569→24284 字节，双双越阈），`M213-c` 削弱对照证明扣分只来自 B16。
- **批量改写脚本抹掉 CRLF 行尾（F435）**：内容治理的压缩脚本以 Python 文本模式（universal newlines）读写，把 `plans/windows/*.ps1` 的行尾由 CRLF 抹成 LF，违反 `.gitattributes` 的 `*.ps1 text eol=crlf`；文档一致性门第 17 类子项当场报红「ps1 工作树行尾非 CRLF」，自检内层电池随之基线红。修法：按字节恢复 CRLF（`git ls-files --eol plans/windows/` 四个文件复现 `w/crlf`）；纪律见决策 **D121**（批量改写 MUST 保持字节形态；改文件后 MUST 跑四门禁全套——行尾与声称问题只在文档门可见）。

- **远端分支清理把「已完成」报成失败（F426）**：本仓 GitHub 侧 `delete_branch_on_merge=true`（由 `plans/github-setup.sh` 声明），合并即已在**服务端**删除 head 分支；`plans/git-merge-flow.sh merge` 随后仍无条件 `git push origin --delete` ⇒ 以 `remote ref does not exist` 失败，把**已经完成**的清理报成 `✗ 删除远端分支失败`（rc=1），并留下陈旧的**远端跟踪引用**——`git branch -r` 长期显示远端已不存在的分支（本轮实测残留 3 个，会被后续「远端仅 main」类核验读成历史态）。修法：先 `git ls-remote --heads origin <ref>` 探测远端引用是否仍在——仍在则删除，已不在则报「已不存在（服务端已删）」并 rc=0；随后 `git remote prune origin` 清理陈旧跟踪引用。新增永久变异 **M210**（a：远端仍在 ⇒ 删除成功；a2：清理后 MUST NOT 残留 `origin/<ref>`；b：幂等路径 rc=0 且不报失败；c：削弱＝恢复无条件删除 ⇒ 幂等场景复现 rc=1）。
- **副本漂移守护只覆盖一类扩展名（F423）**：`plans/preset-audit.sh` 组 F 的 F2 与 `plans/preset-score.sh` 的 B14 做「源副本 ↔ 总库正式位」**正向对照**时只遍历 `plans/*.sh`（+ Windows `.ps1`），而**反向对照**含 `.sh/.py/.mjs` ⇒ `.py`/`.mjs` 陈旧时正向判据恒绿。实测：`plans/preset-compat.py` 比总库副本多 9 行（F366 用法块未镜像）时，审计 `100/100`、评分 `15/15`、文档门 `rc=0`、全量自检 `rc=0` **全绿**，唯一线索是 `plans/dsh-codepunk-init.sh --check` 报「缺失/过期 1 个」。修法：两处正向对照域改为 `plans/*.sh plans/*.py plans/*.mjs`，与反向域同集合；新增永久变异 **M207**（陈旧 `.py`/`.mjs` ⇒ 审计 rc=1 含「F2 不同步」且评分扣 B14；削弱＝退回只含 `*.sh` ⇒ 两条断言消失）。红绿证：A 态两条判据各自命中（审计 1/1、评分 1/1），B 态同模式 0 命中。
- **漂移诊断不点名对象（F424）**：`plans/dsh-codepunk-init.sh --check` 只报「总库工具脚本缺失/过期 N 个（运行本体脚本同步）」，不指出**是哪个**文件 ⇒ 定位需手工遍历 23 个源副本逐项 `cmp`。修法：`install_scripts()` 逐项累积 `_stale_names`（`名称（缺失）`/`名称（过期）`）并入失败文案。新增永久变异 **M208**（假总库含陈旧 `preset-compat.py` ⇒ rc=1 且点名「preset-compat.py（过期）」；削弱＝删除该累积行 ⇒ 断言消失）。注：夹具 MUST 一并安装路径常量文件，否则 `init.sh` 在脚本同步前就以「路径常量文件缺失」退出。
- **派生计数声称无机械守护（F425）**：`docs/development.md` 声称 `plans/` 源副本的 `.sh`/`.py`/`.mjs` 计数为 **13/2/2**，实况 **16/3/2**（开源规格化后新增脚本从未被计数守护；文档一致性门第 1 类只识别变异项数/指标数等写法，派生计数表只认固定行标签）。修法：文档更正为 16/3/2，并在 `plans/doc-consistency.sh` 新增**扩展名计数声称**子项（`git ls-files -z` 派生实况，逐处比对「加号串联链」形态的行；`git` 枚举失败 ⇒ 「无法核验 ≠ 通过」）。新增永久变异 **M209**（文档回退为 13/2 ⇒ rc=1 含「扩展名计数声称陈旧」；削弱＝停用串联链正则 ⇒ 断言消失）。
- **判定的根可被宿主环境重定向（F422）**：`plans/doc-consistency.sh` 第 28 类用**未文档化**的 `DSH_CODEPUNK_REPO` 作仓库根覆盖（全仓唯一使用点，其余各类一律按 cwd），而沙箱自检**继承宿主值** ⇒ 判定被静默重定向到**真仓**：本轮实测宿主设了该变量时，M198-a/M198-b 变异断言**假红**（沙箱内注入的漂移从未被检视），M198-c 削弱断言**假绿**（「守护非空转」的证明失效 ⇒ 整轮自检结论不可信）。修法：第 28 类仓库根改为只由 `os.getcwd()` 决定（删除隐式可重定向根），并新增永久变异 **M206**（宿主变量指向真仓时仍须捕获沙箱漂移；削弱＝把隐式根加回 ⇒ 同一夹具下不再捕获）。
- **文件名含空白/引号即被静默漏检（F419）**：`plans/doc-consistency.sh` 第 4 类的文档清单取自 `git ls-files '*.md'` 后由**未加引号的列表变量**驱动 `for f in $MD_LIST` ⇒ 含空格/引号的文件名被拆成两个 token、`[ -f "$f" ]` 双双失败 ⇒ **该文档整篇不被扫描**（沙箱实证：把 `docs/documentation-policy.md` 改名为 `docs/advm probe 'quote'.md` 并注入失效引用 ⇒ 门禁 rc=0 **假绿**，注入的缺陷从未被点名）。同族 9 处（`plans/preset-audit.sh` 的 D3/E3、`plans/doc-consistency.sh` 第 8/27 类、`plans/preset-score.sh`、`plans/verify-battery.sh` ×3、`plans/fidelity-gate.py`）用 `stdout.split()` 分词 ⇒ python 打开半截路径抛异常 ⇒ 报「D3/E3 无法核验（python3 执行失败）」**错误归因**。修法：一律按 **NUL 记录**枚举（`git ls-files -z` + `split('\0')` 并过滤空串；shell 侧 `while IFS= read -r -d ''`，find 回退用 `-print0`）。永久变异 **M201**（含削弱反向断言）。
- **含 NUL 字节的文档让真实缺陷失去名字（F420）**：`grep -oE` 对含 NUL 的文件只输出 `Binary file … matches`，第 4 类把该提示当成**路径 token**，报出 `…:Binary …:file …:matches` 乱码，**真实失效引用名从未出现**（沙箱实证）。修法：改用 `grep -aoE`（二进制也按文本读）。永久变异 **M202**。
- **环境形态差异被误报为文档/代码缺陷（F421，三例）**：① `POSIXLY_CORRECT=1`（或 `bash --posix`）下进程替换 `< <(` 变语法错误（`plans/dsh-codepunk-leak-guard.sh`/`plans/github-setup.sh`/`plans/verify-worktree.sh`/`plans/write-scope-check.sh`），`plans/dsh-codepunk-link.sh` 的连字符函数名变非法标识符 ⇒ `plans/doc-consistency.sh` 报**假红**「退出码契约漂移 → link -h(rc=2,want=0)」、`plans/preset-score.sh` 报「B8 bash -n 失败」；② `HOME` 未设 ⇒ `plans/dsh-codepunk-init.sh -h` 因 `set -u` 崩在 `$HOME` ⇒ 被报成「init -h 退出码漂移」（帮助文本本不该依赖环境）；③ `GIT_INDEX_FILE` 错指 ⇒ 第 28 类走「无法核验」却计入不一致数 ⇒ 终局把**无法核验说成文档缺陷**。修法：8 个判定生产者加**POSIX 模式入口守卫**（rc=2 + 保守措辞，守卫 MUST 位于顶层）；`init.sh` 前置帮助分支 + `HOME` 未设显式 rc=2；`plans/doc-consistency.sh` 另计 `NUNVER` 并在终局区分归因（**退出码仍 1**，保守失败语义不变）。`docs/development.md` §1 增「运行模式前置（`POSIXLY_CORRECT`）」段（同时满足 F358 的外部输入变量须被记载）。永久变异 **M203/M204/M205**。
- **审计工具的五处口径缺陷（F418）**：运行根 `tools/registry-audit.py` 的五条判据把**正常内容**判成缺陷（假红），且一处**渲染出不存在的编号**：① `fnumbers` 的编号宽度域把**审计检查 ID**（`**F2 不同步**`、`B5/D1/F2`）当成两位形态缺陷号，还用 `F%03d` 渲染成 `F001,F002,F003,F010`——实际文本里并无这些号；② `matrix` 无法区分「仓内机械载体」与**历史/仓外提及**（F385/F344 的更正叙述 `非仓内：tools/patrol-cadence.py`、`非仓内：plan_draft.md`）⇒ 报「路径不存在」，另把模板跨度 `benchmarks/<topic>-analysis.md` 截断成 `-analysis.md`、把 `ledger.md.bak-r626` 截断成 `ledger.md`；③ `changelog` 的候选域缺 `.github/workflows`（`codeql.yml`/`release.yml`/`scorecard.yml` 全被误报）、不认短名（`init.sh`/`link.sh`）、把 `*.pyc` 与用户平面 `~/.dsh/…` 当仓内引用；④ `decisions` 把「缺号」与「仅登记处出现」判为违规——而 `standard.md` 明文声明「号段不连续……缺号不代表遗漏，判定引用只看本表是否登记」；⑤ `opts` 要求 README 字面写 `plans/<名>` 而 README 用**裸文件名**（`dsh-codepunk-home.sh`/`dsh-codepunk-link.sh`）。修法：宽度域收窄为 CHANGELOG 并显示**原文 token**；引入 `非仓内：` 标记与「运行根语境行」豁免（决策登记 `D108`）；扩展名后加边界断言（`(?![A-Za-z0-9._-])`）与 `<`/`*`/`~` 跨度跳过；`resolve()` 扩域 `.github`/`.github/workflows` 并支持 `dsh-codepunk-<名>` 短名前缀；`decisions` 的缺号与仅登记项改记 ℹ；`opts` 改按文件名可检索性判定。常驻回归 `registry-audit.py selftest`（9 条断言，含反向断言：该报的仍报），决策登记 `D109`。
- **探针工具的写盘型探针顺序污染后续读数（F417）**：运行根 `tools/exit-code-matrix.py` 首跑把 `plans/dsh-codepunk-init.sh` 判为「上下文缺失却报通过（rc=0）」——真因是探针**顺序**：该脚本**无参调用即执行安装（写盘）**，先把一次性假 HOME 装好，随后的 `--check` 探针自然 rc=0。修法：写盘型脚本的无参探针排最后且不作硬判（`NOARGS_WRITER`）、假 HOME 用完即删、信息性备注与硬性备注分离。修后 13/13 合格（`-h`=0、未知选项=2、上下文缺失=2、幂等、零副作用、假 HOME 残留 0）。

- **终局判据的报告顺序掩盖真因（F416）**：`plans/checker-self-test.sh` 的**源树密封判据**（F397）原排在**终局 MUTFAIL 门之后** ⇒ 当上游前提被破坏时（本轮实测：自检运行期间有人在源树里改脚本，`fresh()` 遂复制出**语法损坏**的副本 ⇒ 28 条变异成批「退出码 2」），日志只给「有变异未生效（自检脚本问题）」，真因（本轮改动了源树）从未显示，排查方向被误导。修法：**先判密封、再判变异落地**。永久变异 `M200`（两断言：密封判据行号早于 MUTFAIL 门 / 削换顺序后判据即报错，证明非空转）——该判据首跑即暴露自身的**锚点自引用**缺陷（判据代码里含同样的锚点串 ⇒ `head -1` 命中代码行、行号比较失真 ⇒ M200-b 假失败），故锚点改取**末次出现**并加**区间下限**（须落在文件尾部 120 行内）。决策登记 `D107`。

- **变异助手把以 `-` 开头的模式串当选项解析（F415）**：`plans/checker-self-test.sh` 的 `mutate()` 用 `grep -qE "$pat" "$f"`（缺 `--`）⇒ 模式串以 `-` 开头时（例：`-lt 1 ]; then`）被 grep 当作**选项**解析、命令报用法错误、匹配恒失败 ⇒ 判据把「注入已落地」误报为「‼ 变异未生效」并把整轮自检判失败（假失败，且诊断指向「自检脚本问题」）。实证：M197-d 的削弱型变异被误判，而同一模式串手工 `grep -qE -- …` 可正常匹配。修法：`grep -qE -- "$pat"`。永久变异 `M199`（两断言：以 `-` 开头的模式串可匹配 / 不存在的模式串仍须报「未生效」，证明判据非空转）。决策登记 `D106`。

- **文档命令表的用法形态与实现不符（F413，3 处）**：`CONTRIBUTING.md` 把 `plans/evidence-verify.sh` 的交付目录、`plans/acceptance-verify.sh` 的交付方写成**可选**（`[…]`），而两者实现早已必填（前者本轮 F412、后者 F332 已改）⇒ 读者按文档执行必撞 `rc=2`；另有一处反向：`plans/verify-battery.sh` 的预设根实现为**可选**而文档标必填。根因：`plans/doc-consistency.sh` 第 4 类只管「引用的路径是否存在」、第 5 类只管「退出码声明」，**用法形态**无任何门禁。修法：更正三处文档，并新增**第 28 类「命令表用法形态」**——以脚本头部用法行为权威，对文档中出现的**位置式用法串**（含 `<…>`/`[…]` 占位符且不含 `--` 开关）逐位比对占位符可选性（两向都报；仅名称差异只记 ℹ；开关式提及不适用）。永久变异 `M198`（三断言：注入「必填写成可选」⇒ 该门禁报错 / 注入「可选写成必填」⇒ 报错 / 削弱该类的失败分支后同一漂移不再被报，证明非空转）。决策登记 `D105`。

- **证据门的必需上下文缺失被误归因为数据缺陷（F412）**：`plans/evidence-verify.sh` 的交付目录原为**可选**（用法 `<evidence.yaml> [任务交付目录]`），缺它时 `log_ref` 按**校验器自身 cwd** 解析 ⇒ 报 `[ev1] log_ref 文件不存在: run.log`（`rc=1`），而同份输出又打印「⑤ 时间序未检（未提供交付目录）」——同一份输出自相矛盾，且把「没给目录」说成「文件不存在」，读者会去查数据而不是补参数。修法：交付目录改**必填**（缺参/目录不存在 ⇒ `rc=2` 并说明「无法核验 ≠ 通过」），并在解析侧加纵深防御（缺上下文只记「无法核验」，绝不断言文件不存在）。永久变异 `M197`（五断言，含「削弱后复现旧行为」）。决策登记 `D104`。

- **存活自检无并发互斥 ⇒ 并行自检互相污染、结论不可归因（F410）**：`plans/checker-self-test.sh` 把调用方给出的**预设根当可写共享资源**用（密封探针 `$SRC/.seal-probe-m189` 直接写入源树、`fresh()` 整树复制源根到沙箱），却没有任何互斥 ⇒ 同一预设根上并行两次自检会互相观察对方的探针与半成品副本。实测（本仓）：一次与另一次重叠的运行的**幻影失败** —— `M194` 的三条断言拿到 `doc-consistency.sh` 的 `rc=2` 而非期望的 `1/0`，而同配置**三次单跑**均 `195/195` `rc=0`，即该失败不可复现、污染无法归因（「不可复现 ≠ 通过」的同族问题）。修法：新增**并发互斥块**（键＝预设根绝对路径的 `cksum`；锁目录落在 `${TMPDIR:-/tmp}`；持锁者写 pid 文件）；持有者存活 ⇒ 以 `rc=2` 响亮拒绝并说明「另一次自检正在运行」；pid 已不存在（陈旧锁）⇒ 打印「接管陈旧锁」后继续；锁键无法派生（缺 `cksum`/`awk`）⇒ `rc=2`（无法核验 ≠ 通过）；`ps` 缺失时按持有处理（fail-closed）；**只有自己持有锁时才登记释放路径**，退出时由 EXIT trap 释放。新增测试钩子 `--lock-echo` 与永久变异 `M196` 四条断言（活锁拒绝 / 陈旧锁接管 / 退出后锁已释放 / 仅删「持有者存活即拒绝」守护 ⇒ 该守护复现放行，证明非空转）。

- **守卫 `--history` 模式的覆盖率不可见（F409）**：`tree` 模式会报「已扫描 N 个跟踪文件」且零输入以 2 拒绝（F387/F250），但 `--history` 原实现只打印「✓ 通过（禁词 25 条 + 通用模式 5 类）」，**不报实际扫描的提交数** ⇒ ① **浅克隆**（`.git/shallow` 在场：CI 的 depth=1 检出、只取一层的克隆都属此列）下 `git log` 只返回可见提交，输出却与全历史扫描**无法区分**（实测：`--depth 1` 克隆 rc=0 且与完整仓输出同形）；② 空仓库（0 提交）同样打「✓」。审计者因此会误以为全历史已核验。修法：先判 `.git/shallow` 与提交总数——浅克隆/空仓库一律「无法核验 ≠ 通过」（rc=2，并给出 `git fetch --unshallow` 处置），通过时打印实际扫描提交数与仓库总提交数（窗口外提交显式告知）。永久变异 M195（四条断言：浅克隆 ⇒ rc=2；空仓库 ⇒ rc=2；完整仓通过时输出含「已扫描」；仅删浅克隆守卫 ⇒ 浅克隆复现 rc=0）。
- **公开仓文档引用仓外工具时写成仓内形态（F408）**：`CHANGELOG.md` 曾把运行根（仓外）回读工具写成**仓内形态**（`plans/` 前缀 + 运行根工具名 `patrol-readback.cjs`）——本仓既无该文件、也无 `tools/` 目录，读者在克隆内**不可解析**，且与实况不符（运行根收口脚本调用的实为 `<运行根>/tools/patrol-readback.cjs`）。根因有二：① `doc-consistency.sh` 第 4 类（工具存在性）扫描域只含 SKILL / references / README / CONTRIBUTING / docs，`CHANGELOG.md` 等根级文档不在域内；② 该类的扩展名集只有 `sh|py|mjs`，`.cjs` 形态的引用**根本不被识别**（同一行的假引用因此长期零守护）。修法：域扩至**全部跟踪的 `.md`**（`git ls-files '*.md'`，非 git 工作区回退 `find`；空枚举判「无法核验 ≠ 通过」），扩展名集补 `cjs`/`ps1`，结论行写明域与来源；文本侧把仓外工具标注为「运行根（仓外）」并去掉伪仓内路径。永久变异 M194（三断言：在 `CHANGELOG.md` 注入不存在的 `plans/*` 引用 ⇒ rc=1 含「不存在」；恢复 ⇒ rc=0；域声明含「全部跟踪」字样）。
- **自检夹具依赖宿主 `HOME`（F407）**：M193 的三条断言按「沙箱口径」运行，而本套件 `export HOME="$SANDBOX"` ⇒ 沙箱 `HOME` 下无 `~/.dsh-codepunk/denylist.txt`，`DENY_RAW` 恒空 ⇒ leak-guard 的「归一管道失效」不变量**不可达** ⇒ M193-b 在沙箱内报 rc=0（假失败），而操作者在真 `HOME` 下手跑同一变异却得 rc=2——即夹具不自足、结论随宿主环境漂移。修法：三条断言统一显式传 `DSH_CODEPUNK_DENYLIST="leakwordalpha:leakwordbeta"`（脚本正式输入通道），与宿主 `HOME` 解耦。
- **自检缺 `node` 时假失败且诊断误导（F406）**：`plans/checker-self-test.sh` 的 M51/M138/M139（声明包装漂移）与 M14/M122/M190 经 `node plans/preset-declare.mjs` / `node plans/ps-validate.mjs` 施加与断言；缺 `node` 时它们以 **rc=127** 收场并打印「变异未生效（…自检自身问题，非守护问题）」⇒ 触发终局 MUTFAIL 门 ⇒ 整轮**假失败**，且把操作者引向「自检脚本问题」而非「环境缺 node」（实测日志：运行根 `logs/selftest-r646.log`，三条 ‼ + rc=127 + `✗ 自检失败：有变异未生效`）。修法：套件开头加**环境前提预检**（`node`/`python3`/`bash` 任一缺失 ⇒ rc=2 并给出真实原因「环境缺依赖，非守护缺陷」）。
- **门禁的解析依赖缺失时静默降级为通过（F405，4 处实例）**：判据的抽取/计数/归一管道依赖 `awk`/`sed` 等外部命令，缺失时得空值并被当作「零命中/零扣分/校验和不变」。实测（影子 PATH 只去掉一个命令，其余工具齐备；原始输出见运行根 `logs/r646/dep-matrix-awksed.txt`）：① `plans/dsh-codepunk-leak-guard.sh` 缺 `awk` ⇒ 25 条禁词**静默归零**仍打印「✓ 泄露防护门：通过（禁词 0 条 + 通用模式 5 类）」rc=0；② `plans/preset-audit.sh:189` 的 `git grep -ic … | awk` 得空 ⇒ `${N:-0}` 归零 ⇒ 报「B5 全仓零旧名」通过（旧名实际存在）；③ `plans/preset-score.sh:98` 的 `grep -hoE … | sed … | sort -u` 缺 `sed` ⇒ 循环体不执行、`BADCMD` 恒 0 ⇒ A2「引用了不存在的脚本」扣分项静默消失（rc=0 15/15）；④ `plans/verify-battery.sh` 的 `cksum … | awk` 缺 `awk` ⇒ `IDX_BEFORE`/`IDX_AFTER` 双空值相等 ⇒ 报「✅ E2E 未污染真实总库（INDEX 校验和不变）」。修法：四处各加 `command -v` **依赖预检**（缺失 ⇒ rc=2「无法核验 ≠ 通过」并说明缺哪个命令），leak-guard 另加**不变量**（禁词表源非空而归一后为空 ⇒ rc=2，覆盖「命令在但管道被改坏」）；`plans/write-scope-check.sh --run-root` 同族**诊断缺陷**一并修（缺 `awk` 时报「缺 write_scope: 段」，保守但把操作者引向错误方向 ⇒ 改为显式预检）。修后同环境矩阵 **假绿灯 0 处**（`logs/r646/dep-matrix-green-full.txt`）。永久变异 M193（三条断言：预检拦 / 仅删预检时不变量独立拦 / 两层都删则复现假绿 rc=0，证明两层守护均非空转）；常驻探针 `tools/dep-matrix.py`（依赖缺失 × 门禁矩阵）。
- **收口工具写后回读依赖缺失时半收口（F404）**：运行根（仓外）收口脚本 `tools/close-round.py` 在三个文件写盘**之后**才调用回读工具 `node tools/patrol-readback.cjs`（同属运行根，非本仓产物），且未预检 ⇒ PATH 无 `node` 时抛未捕获 `FileNotFoundError`、rc=1，而台账/运行根 README/`agents.yaml` **已写入**（实证：R645 收口时三行「已写」输出后紧跟 `FileNotFoundError: [Errno 2] No such file or directory: 'node'`）。修法：写前预检 `node`/`bash` 与 `plans/patrol-check.sh` 可达性 ⇒ 缺失即 rc=2「无法核验 ≠ 通过（写前中止，未写入任何文件）」；回读改绝对路径并加 `try/except` 兜底。常驻回归工具 `tools/close-round-selftest.py`（构造无 `node` 影子 PATH 与 old/new 两态夹具，断言 old：rc=1 + 回溯 + 三文件已写；new：rc=2 + 无回溯 + 零写入）。
- **运行根残留实况核验只覆盖顶层（`cleanup_status: clean` 在子目录层面不可核验）**：`plans/write-scope-check.sh --run-root` 的判据 h 原用 shell 通配只扫运行根**顶层**。实测（原始输出见运行根 `logs/r645-f403-red.out`、`logs/r645-f403-list.txt`）：运行根子目录存在 **77 处**黑名单残留（`tools/__pycache__/*.pyc`、`logs/**/*.bak`、`logs/**/*.orig`、`logs/pycache/**/*.pyc`）而门仍 **rc=0** 并打印「运行根顶层无备份/临时命名物」——`cleanup_status: clean` 的声称在子目录层面不成立。修法：判据 h 改为**递归**扫描（`find` 覆盖 `*.bak`/`*.bak-*`/`*~`/`*.orig`/`*.rej`/`*.tmp`/`*.swp`/`__pycache__`/`*.pyc`），命中即 FAIL 并报**计数 + 前 6 条**；缺 `find` ⇒ exit 2（无法核验 ≠ 通过）。运行根已按判据清理（残留 77 → 0，门 rc=0）。永久变异 M192（三条断言：子目录编译缓存 ⇒ rc=1 含「编译缓存残留」；清理后 ⇒ rc=0；把递归退化为 `-maxdepth 1` ⇒ 同夹具复现假通过，证明递归扫描非空转）。
- 修复自检夹具的**时区依赖**（F402）：巡检名册时间戳夹具原以主机本地时间拼接固定 `+07:00`，在 UTC 运行器上「未来时间」夹具并不位于未来 ⇒ `M191-a` 在 CI 必失败（本地 Asia/Bangkok 因巧合通过）。夹具改为 `date -u` + RFC 3339 的 `Z` 设计符，跨时区同结果（实测 `TZ=UTC` 与 `TZ=Asia/Bangkok` 四夹具 rc 集合一致）。
- **巡检名册时间戳可写未来时间（时间线不可复算）**：运行根 `agents.yaml` 的 `patrol_log` 条目与顶层 `updated_at` 此前无任何机械核验。实测（探针原始输出见运行根 `logs/r644/`）：`at` 与 `updated_at` 均被写成**次日** `2026-10-09T05:05:00+07:00`，而该轮实际落盘时刻为 `2026-10-08T22:02:37+07:00`（`ledger.md`/`agents.yaml` 的 mtime）——超前约 7 小时，`plans/patrol-check.sh` 与 `tools/patrol-readback.cjs` **仍报通过**，D094/D095 的巡检与续行判定却以时间为据。修法：`plans/patrol-check.sh` 新增判据 **i**——`at`/`updated_at` MUST 为 `YYYY-MM-DDThh:mm:ss±hh:mm` 形态、MUST NOT 晚于当前时刻（容差 `TS_TOL`，默认 120s）、巡检 `at` 按条目顺序 MUST 非递减（历史占位 `未记录…` 豁免）；epoch 换算用 awk 内置的 civil-date 算法，不依赖 GNU `date`。永久变异 M191（四条断言：未来时间 ⇒ rc=1 含「未来时间」；非单调 ⇒ rc=1 含「非递减」；合规夹具 ⇒ rc=0；缺秒的形态 ⇒ rc=1 含「形态非法」）。运行根的两处未来时间戳已按落盘实况更正。
- **声明生成器的 CLI 取值无校验（非法 `--order` / `--id` 静默写进副本）**：`plans/preset-declare.mjs` 的 `--order` 走 `Number(args.order ?? 5)`、`--id` 直接取用，二者无任何校验。实测（探针原始输出见运行根 `logs/r643/`）：`emit --order=abc` 与 `--order=--` ⇒ rc=0 且产出 **`order: NaN`**、`--order=2.5` ⇒ `order: 2.5`、`--id ''` ⇒ `- id: preset-`、`--id 'a b'` ⇒ `- id: preset-a b`；更严重的是 `apply --append --order=abc --patch <副本>` ⇒ rc=0「生效：重启 DSH Desktop」且副本内**确实写入** `order: NaN`（实测副本第 15 行），即部署方按文档操作即把不可用声明装进用户平面；`--id ''` 之后 `check` 还会报「存在 2 处声明：id: preset-」而自相矛盾。修法：`--id` 须匹配 `^[a-z0-9][a-z0-9._-]*$`、`--order` 须为**非负整数**（`Number.isSafeInteger`），否则 `die()` rc=2 并给出可用示例；**非法取值一律不写盘**（实测 apply 后副本 md5 未变、`order:` 行 0 处）。永久变异 M190（三条断言：非法 order/id ⇒ rc=2；合法取值不得误拒；删除守卫 ⇒ 复现 `order: NaN` 静默产出）。
- **评分器 A4 结构解析在缺环境时静默跳过（判据消失而不告知）**：`plans/preset-score.sh` 的 `PARSE="skip"` 分支既不扣分也不提示，而同类判据 F216（总库 INDEX schema）已明确「缺失即通过」须按失分并说明；且该处只认 `$HOME/.dsh-codepunk/tools/node_modules/js-yaml`（**本机该路径不存在**），不采纳 `verify-battery.sh` / `preset-declare.mjs` 都在用的 `$DSH_APP_ROOT/node_modules/js-yaml` 回退 ⇒ 同一套件内三工具口径不一。修法：① 新增 `YAML_DIR` 候选（总库 tools → `$DSH_APP_ROOT`），有 js-yaml 时 A4 真做语义解析（实测带 `DSH_APP_ROOT` 跑通、无 skip 提示）；② `PARSE=skip` 时显式输出「A4 结构解析无法核验（缺 ruby，且未找到 js-yaml…）——无法核验 ≠ 通过」。本轮以「同一命令在有无 ruby/js-yaml 两种环境下输出之差」做一次性反空转证明（未纳入永久变异：需构造无 ruby 环境并跑整轮评分，代价约 2×60 s，列入收敛证据包的「未纳入机械自检的新分支」）。**顺带**：`plans/checker-self-test.sh` 的 M102 断言原为计数式（`grep -c F215 == 2`、`grep -c F216 == 1`），本轮仅因在 `preset-score.sh` 里新增一处引用 F216 先例的注释就报「✗ M102 score 含 F216 缺口声明（未含「1」）」——计数式断言随合法演进静默腐化（同 F300 家族），已改为**下界**断言（F215 ≥2 保留「双路径各自标注」强度、F216 ≥1 为存在性）。
- **存活自检会改动源树（变异作用域越界，工作树静默退化）**：`plans/checker-self-test.sh` 的 M188-c 用**裸相对路径**在主 shell 执行 `sed -i.bak '/^    # 判据 h（F396）/,/^    fi$/d' plans/write-scope-check.sh`，而 `check_rc` 之外的变异并不在 `$work/cur` 沙箱内执行 ⇒ 该删除型变异真的施加于**仓库文件**（紧随的 `rm -f …bak` 又抹掉备份，无从回滚）。实测：一次自检后 `plans/write-scope-check.sh` 的判据 h 实现整段消失（`grep -c RR_JUNK` 由 4 变 0），CI 每跑一次「存活自检」就污染一次工作树；本轮仅因 hub 镜像 `~/.dsh-codepunk/scripts/` 留有副本才可无损恢复。修法：① M188-c 改为 `( cd "$work/cur" && sed … )` 并让 `mutate_gone` 指向沙箱副本；② 新增**源树密封判据** `src_fingerprint()`/`seal_check()`（开工取指纹＝`git status --porcelain`（含 `--ignored=matching`，因本仓 `.gitignore` 以 `*` 兜底、未跟踪探针亦属被忽略项）+ `git diff` + `git diff --cached` 的 `git hash-object`），收尾比对，差异即 `exit 2` 并报「本轮改动了源树」；③ 永久变异 M189 两条断言（在源树落一个未跟踪探针 ⇒ 密封判据须报已改动；探针移除后须恢复通过）。
- **运行根 `cleanup_status: clean` 无实况核验（残留备份也报通过）**：`plans/write-scope-check.sh --run-root` 原只验 `write_scope:` 段的 5 键齐备与取值合法，不核验实况；实测运行根顶层留着上一轮的 `ledger.md.bak-r626` 而该门 rc=0，而 `cleanup_status: clean` 是交接门与合并门的前置读数。新增**判据 h**：`clean` 时运行根顶层不得存在 `*.bak` / `*.bak-*` / `*~` / `*.orig` / `*.rej` / `*.tmp` / `*.swp`（用 shell 通配实现、不依赖 `find`，因为该分支在 `find` 预检之前执行），命中即 rc=1 并列出条目；运行根已清走该备份并补齐 `created` 顶层产物登记。永久变异 M188 三条断言（干净夹具 ⇒ rc=0；注入 `x.bak` ⇒ rc=1 含「备份/临时命名物」；删除判据 h ⇒ 复现假通过）。
- **巡检名册含撇号即整文件不可解析，而两个机械门同报通过**：运行根 `agents.yaml` 的自由文本值写成单引号标量（`note: '…'`）且内含撇号时，单引号标量未闭合 ⇒ js-yaml 报 `bad indentation of a mapping entry`、**解析器在该行中止**（其后条目全部不可读，D094/D095 的巡检与续行判定失效、D099 的「机器可读」声称同时不成立）；实测 `plans/patrol-check.sh` 报「✅ 巡检名册合规」、`plans/write-scope-check.sh --run-root` 报通过（**双门假绿灯**）。修法：`plans/patrol-check.sh` 新增判据 g（形如 `键: '…'` 的行内单引号个数须为偶数，撇号 MUST 双写为两个单引号）+ 写入约束补该规则 + 永久变异 M187（注入撇号 ⇒ rc=1 含「单引号标量未闭合」；双写后 ⇒ rc=0）。

- **产品/用户平面行号引用既漂移又无门禁（「行号引用规则（MUST）」不可核验）**：`skills/dsh-codepunk-workflow/references/file-hygiene.md` 的规则原写「引用 MUST 同时给出符号名检索式」，实测 13 处行号引用仅 3 处附检索式、且**该类声称无任何机械核验**（同 F294/F315/F327/F338/F347 家族）；本轮另证两处漂移——用户平面 `permission` 区块旧稿 `:216-229` 实况 `:217-230`、`defaultPreset` 旧稿 `:229` 实况 `:230`（两者**均带检索式**，按检索式可发现，但此前无门禁）——F390/F391 实证。已更正两处行号、把规则口径写实（MUST 给出可检索锚点，并明文列出第 27 类的机械核验范围：仅同行单处引用；有检索式者首命中须落在引用区间、无者反引号符号名须在区间内出现一次；缺安装面/目标不存在记无法核验不判失败），并**新增第 27 类机械门** + 永久变异 **M183**（两断言：越界引用须报；修好后不得再报）。

- **用户平面行号引用在同一轮内即失准（应用会重写该文件）**：上一段修复把用户平面 `permission` 区块的行号更正为 `:217-230`、`defaultPreset` 更正为 `:230`，但**合并后复跑**问出第四次漂移（`:205-218` / `:218`）——`~/.dsh/profiles/desktop/cordis.patch.yml` 的 mtime 与漂移同刻，即 **DSH Desktop 会自行重写用户平面**（模型目录等），故对用户平面写行号在结构上必然失准（merge 后 `main` 的文档门因此转红）——F392 实证。已把用户平面引用一律改为**符号锚点**（不写行号），并在第 27 类新增 `PROF/<路径>:<数字>` 子判据（一律判失败）+ 永久变异 **M184**（两断言）。
- **保真闸类数声称不在任何门禁域（计数同步会静默改错它）**：`plans/fidelity-gate.py` 的语义项类数（`PATTERNS` 键数＝14）与 `doc-consistency.sh` 的类数在文档里写法同形（「N 类」），此前只有 doc 类数入域；实测把 README 的保真闸「**14 类**」改成 27 类后，**四门禁仍全绿**（文档静默说谎）——F393 实证。已新增子判据（`fidelity-gate` 同行 `N 类` 须等于 `PATTERNS` 键数）+ 永久变异 **M185**（两断言）。
- **验证电池把 `.gitignore` 明示忽略的运行产物判为「杂散」**：`.gitignore:28-41` 明确忽略 `tmp/`、`logs/`、`node_modules/`、`__pycache__/`、`*.pyc`、`*.log`、`*.out`，`Makefile:21` 亦把仓内 `tmp/` 与 `logs/` 记为运行产物落点；但 `plans/verify-battery.sh` 的杂散项把**任何**被忽略项都当意外产物 ⇒ 按文档在 `plans/` 内跑门禁（生成 `plans/__pycache__`）或把产物落仓内 `tmp/` 后，本应在干净状态通过的电池 rc=1（`CONTRIBUTING` §5.1 清单第 1 项被阻塞；F389 实证：`tmp/`、`plans/__pycache__/`、`logs/` 三者各自触发 `✗ 杂散: DS=0 untracked=0 ignored=1`）。现把两类分开判：产物只列 `ℹ 已忽略的运行产物 N 项`，其余被忽略项（含**未登记**的顶层路径）仍判杂散。永久变异 **M182**（三断言：产物 ⇒ rc=0 且列出；未登记顶层文件 ⇒ 仍判杂散；抹掉产物白名单 ⇒ 复现假失败）。
- **泄露防护门把「零文件被扫描」呈现为「通过」**：`plans/dsh-codepunk-leak-guard.sh` 的三种模式都以 `git` 枚举文件；替身/损坏的 `git`（退出码 0 且零输出）或 `GIT_DIR`/`GIT_WORK_TREE` 误设时枚举为空，脚本**一个文件都不扫却打印「✓ 泄露防护门：通过（禁词 25 条 + 通用模式 5 类）」**（F387 实证）。已加两道自证：①`git rev-parse --git-dir` 无输出 ⇒ 退出码 2（「git 不可用或行为异常——无法核验 ≠ 通过」）；②tree 模式统计实际扫描数，为 0 ⇒ 退出码 2；非零时报告「ℹ 已扫描 N 个跟踪文件」。永久变异 **M180**。
- **审计门 D3/E3 在 git 枚举为空时空转判满分**：`plans/preset-audit.sh` 的「行号引用均附符号名」「仓内相对链接均可达」两项以 `git ls-files` 结果为空列表时循环空转 ⇒ 直接判 PASS，否决式计分下给出 **100/100 假满分**（F388 实证：说谎 `git` + 注入缺符号名的行号引用仍报 `[✅] D3`）。已加文件系统遍历回退（`os.walk`，遍历仍为空则报「无法核验 ≠ 通过」）。永久变异 **M181**。
- **治理矩阵以仓外脚本充当「机械」载体**：矩阵「巡检节奏（D095）」行原以运行根本地便利脚本 `tools/patrol-cadence.py` 为「机械」载体——该文件不在仓内、CI 无法执行、贡献者无法复现该声称，而仓内已有等价门。已把载体更正为 `plans/patrol-check.sh`（第 20 类探针 + 变异 `M176`），并**新增第 26 类机械门**（矩阵行内文件型引用须仓内可解析 / 为 `artifacts.md` 制品名 / 显式标注「非仓内」；F385 实证）+ 永久变异 **M179**。
- **矩阵内脚本简称按名不可检索**：F360 的「同一制品多处生成器须一致」行原写 `link.sh`/`init.sh`（仓内不存在该名，实为 `dsh-codepunk-link.sh`/`dsh-codepunk-init.sh`）⇒ 按名 grep 不可达（F386 实证，与 F292 同族）。已改为全名。
- **hooks 护栏路径未归一（等价写法绕过）**：`/etc/hosts` 被拦而 `/private/etc/hosts`（macOS 的 `/etc` 是它的符号链接，实测同一 inode）、`//etc`、大小写变体、指向黑名单文件的符号链接全部静默放行（F383 实证）。已改为判定前一律 `realpath` + 大小写折叠；覆盖矩阵 `file-hygiene.md` §8.2/§8.3 与 §8.3 局限第 2 条同步更正（仍不做硬链接 inode 归一）。永久变异 **M177**。
- **hooks 命令抽取取首位参数（实参顶替真目标）**：`chmod 777 <目标>`、`truncate -s 0 <目标>`、`chown root:wheel <目标>`、`rm -rf a <目标>` 的真目标从未被判定（取到的是模式 / 尺寸 / 属主等实参），`gtee` 亦不在写命令表（F384 实证：35 例矩阵漏检 5 例）。已改为并入**全部形似路径的 token**（回退首位）并补 `gtee`；矩阵重跑 MISSED=0 / FALSE_POSITIVE=0。永久变异 **M178**。
- **巡检名册的字段契约无机械门（缺字段的名册照样全绿）**：契约（`references/artifacts.md` 的 D095/D099）明文要求运行根 `agents.yaml` 的 `patrol_log` 每条齐备 `round`/`at`/`note`，而实况（F382 实证）50 条中 **34 条缺 `at`、35 条缺 `note`**（旧形态 `{round, checked, result}`），且全仓无任何门禁检视该契约——`plans/write-scope-check.sh --run-root` 只验 `write_scope:` 段。新增 `plans/patrol-check.sh --run-root <运行根> [--ledger <台账>] [--max-gap N]`（行级解析，不依赖 YAML 库）：字段齐备（缺失或值为空即报）· `round` 唯一且为整数 · 给了 `--ledger` 时每个巡检轮次须在台账中有行 · 升序排序后相邻间隔 ≤ N（默认 5）；退出码 0/1/2，环境缺口一律返回 2（无法核验 ≠ 通过）。永久变异 **M176**（3 断言：合规名册 rc=0 / 删 `at` 后 rc=1 报「缺 at」/ 判据短路后不得再报——证明该判据非空转）。
- **声明写入非原子（用户平面补丁可能被截断）**：`plans/preset-declare.mjs` 的 `apply` 原先就地对 profile 补丁 `writeFileSync`（先截断后写入）——实测并发读者能读到 **0 字节**（5 ms 采样命中中间态），进程被 SIGKILL 时文件停在截断态（`check` 报「profile patch 中找不到声明」），而写后自校验的回滚只在正常路径执行 ⇒ 产品下次启动读到不可用的 profile。现改为**原子替换**：写同目录临时文件 `${patch}.tmp-<pid>` 后 `renameSync`，并显式把原文件权限位复制到临时文件（rename 会换 inode）；异常时清理临时文件（崩溃可能留下惰性 `.tmp-*` 残留，产品不读它）。受控 A/B（同一处注入等量延时后 SIGKILL）：修复前目标 0 字节 / `check` rc=2，修复后目标字节数与权限不变 / `check` rc=1。永久变异 **M174**（2 断言，用「inode 是否变更」这一可确定观测的原子性不变量）。
- **hooks 覆盖清单对 `sed -i` 声称过宽**：契约（`references/file-hygiene.md` §8.3）承诺覆盖 `sed -i` 末位文件，而实现只认「裸 `-i `」形态——`-i.bak`、`-i''`、`--in-place`、`--in-place=.bak` 四种**等价且更常见**的拼法（BSD sed 要求 `-i` 带参数，macOS 上 `-i.bak` 才是常态）静默放行，`perl -i` 与重定向 `>|` 同样未覆盖。现 `plans/hook-write-scope.py` 覆盖 `sed -i` 全族、`perl -i` 与 `>|`，§8.3 同步改写。永久变异 **M175**（3 断言：`sed -i.bak` / `perl -i` 须阻断 + 后缀判据收窄后不得再阻断）。
- **运行根的 `write_scope:` 台账段只是散文、机械门无判据**：契约（`references/artifacts.md` §1.3）要求运行根 `README.md` MUST 含 `write_scope:` YAML 段（`run_id` / `allowed_prefixes` / `created` / `cleanup_status` / `exempt`），而该段长期只有散文形态、内容陈旧（`cleanup_status` 是交接门与合并门的前置读数，散文形态下该读数根本不存在）。`plans/write-scope-check.sh` 新增 `--run-root <运行根>` 模式（段缺失/缺键/取值非法 ⇒ exit 1；运行根或 README 缺失 ⇒ exit 2），并以夹具运行根守护（永久变异 M173，5 断言）。
- **自检变异锚定易碎常量**：M149 的变异锚点写死了 `-h` 分支的行区间常量（`sed -n '2,44p'`）——本轮把 `plans/write-scope-check.sh` 的用法块由 44 行扩到 50 行后，变异不再落地，整轮自检因「变异未生效」变红（虽为显式失败，但失败原因与守护无关）。锚点改为只依赖**被守护的分支形态**（`-h|--help)  sed -n '`），与行区间解耦。
- **巡检节奏无机械判据**：D095「每 N 轮巡检一次」此前只靠纪律执行，实测台账 632 轮内出现**最大间隔 10 轮**（超阈值 5）与**重复轮次**（601/602/609）。新增工具 `tools/patrol-cadence.py`（间隔 ≤ `--max-gap`、轮次不得重复、巡检轮次须在台账中有行；`--since N` 把历史违规列为信息、不改退出码），并据此把运行根 `agents.yaml` 的 `patrol_log` 去重合并（55 → 48 条，内容保留）与轮次值规范为裸整数。**注**：该脚本是**运行根本地便利工具，非仓内产物**；仓内等价机械门为 `plans/patrol-check.sh`（第 20 类探针 + 变异 `M176`，见治理矩阵「巡检节奏（D095）」行）。

- **扫描工具缺失时写盘纪律门静默放行**：`find` 不在 PATH 时，`plans/write-scope-check.sh` 四处 `done < <(find … 2>/dev/null)` 的进程替换为空、`command not found` 被 `2>/dev/null` 吞掉 ⇒ G1/G2/G3 全判「无残留」并 `exit 0`（同一含残留沙箱在有 `find` 时 rc=1）——与该脚本头部「2=无法核验」契约直接冲突；`preset-score` 与 `verify-battery` 的 `.DS_Store` 计数同族静默判 0。已加扫描工具预检（缺失 ⇒ `exit 2`，并输出「无法核验 ≠ 通过」）与缺失时的扣分/未核验分支；新增永久存活变异 M169（两断言：无 `find` 须 rc=2 / 移除守护后复现假绿，证明守护非空转）。
- **文档里的 doc 类数声称无门禁覆盖**：`docs/architecture.md` 声称 `plans/doc-consistency.sh` 一致性「24 类」，而实现已派生 25 类（新增第 24/25 类时该处未同步）——计数声称族此前只覆盖「N 项…」写法，不含类数。已在第 1 类末尾把类数声称纳入派生核验（域 README + `docs/**`；剔除「第 N 类」序数写法以免误判），新增永久存活变异 M170（三断言：序数不误判 / 陈旧须报错 / 基线一致）。
- **巡检名册的「可解析」自证用的是弱解析器**：运行根 `agents.yaml` 的写入约束（D099）原文只要求 `ruby -ryaml` 回读校验，而 Psych **不报重复键**——巡检写回把新条目插在上一轮条目的字段之前时，该轮条目丢失 `at`/`note`、上一轮条目出现两个 `at`/两个 `note`，Psych 静默取后者、`js-yaml` v4 则报 `duplicated mapping key` ⇒ 名册对严格解析器**不可读**而自证仍显示通过。已把约束升级为「MUST 用严格解析器（js-yaml，拒绝重复键）+ MUST 逐条核对字段归属」并写明两者差异与实测。
- **钩子配置（产品启动时读取）无任何门禁守护**：`plans/hooks/hooks.json` 由 `agent.cordis.yml` 的
  `hooks-write-scope` 条目经 `configPath` 在产品启动时读取，而把该文件**截断为非法 JSON**、或把命令
  路径改成**不存在的文件**时，`doc-consistency` · `preset-audit` · `preset-score` ·
  `preset-compat` · `write-scope-check` **五个门禁全绿**、输出零处提到 hooks ⇒ 拦截层静默消失而无
  红灯（产品侧只走 `logger.warn(` 一条分支，见 `dsh-hooks-claude-code/lib/index.js:139,145-146` 的「no hooks registered」）。
  已在 `plans/doc-consistency.sh` 第 7 类新增子项「钩子配置完整性」：JSON 可解析 · `matcher`/`type`/`command`
  齐备 · 命令内 `${CLAUDE_PLUGIN_ROOT}/<路径>` 在仓库内存在 · **解释器在 PATH 内**（缺失即红灯，给出
  「装解释器或移除该条目」的可行动作）；新增永久存活变异 M168（三断言）。
- **契约未记载「失败开放」**：钩子命令**无法启动**（解释器缺失、路径错）、脚本**异常退出**（非 0/2）
  或**超时**时，产品侧**不设 decision** ⇒ 该次调用照常放行，只在钩子记录里留 `stderrSummary`
  （`dsh-hook-protocol/lib/index.js:102-126`：仅 exit 2 设 `block`、exit 0 才解析结构化输出；runner 以
  `parseHookOutput(result.exitCode ?? void 0, …)` 收尾——基础设施层拒绝无退出码）。README 的退出码列与
  `references/file-hygiene.md` §8.3/§8.4 已补该条（缺口 7）与「`matcher` 为非锚定正则 ⇒ `todo_write`
  等含子串的工具名也会触发（缺口 8）」。
- **用法约定只覆盖 `.sh`，4 个非 shell 入口整体不在域内**：`plans/doc-consistency.sh` 第 20 类的
  静态子项写作 `for f in plans/*.sh`，探针表也只枚举 `.sh` ⇒ `fidelity-gate.py`、`preset-compat.py`、
  `preset-declare.mjs`、`ps-validate.mjs` 把 `-h` 当位置参数（rc=2，其中 `preset-compat.py` 报
  「组合文件不存在：`<仓库>/-h/agent.cordis.yml`」），而治理矩阵声称该检查「覆盖全部实现者」。
  已为四个入口补 `-h`/`--help` 分支（rc=0 + 用法），并把第 20 类的静态子项域扩为
  `plans/*.sh plans/*.py plans/*.mjs`（纯 source 库除外）、探针表补 4 条（27 → 31 条），
  新增永久存活变异（M167）。**补充**（CI 拦下）：`ps-validate.mjs` 的用法分支首版排在**依赖解析
  之后**，未装 tree-sitter 的机器（ubuntu CI）会先 `exit 2` ⇒ 同一约定本机 rc=0、CI rc=2；
  已把帮助分支提到依赖解析之前（帮助不依赖可选依赖），并加断言 M167-c 固化。
- **写盘护栏黑名单的两条静默绕过**：`plans/hook-write-scope.py` 的路径比对未做归一 ⇒
  ① `//etc/hosts`（`posixpath.normpath` 依 POSIX 保留前导双斜杠）与 ② 大小写变体
  `/ETC/hosts`、`/USERS/<名>/.ssh/id_ed25519`（macOS 默认卷不区分大小写）都**绕过黑名单且无任何提示**
  （既非阻断、也不属于契约里「无法判定 ⇒ 放行 + 明示」那一类）。已归一：POSIX 折叠前导多斜杠
  （Windows UNC 不折叠）、大小写不敏感平台（darwin/win32）比对双方折叠；契约 `§8.3/§8.4` 补记归一规则
  与条件性缺口，M164 增两条断言（M164-d/M164-e）。
- **`INDEX.yaml` 权限随执行顺序变化（同输入终态不一致）**：`plans/dsh-codepunk-link.sh` 写回总库索引时用
  `mktemp` + `mv`，而 macOS 的 `mktemp` 建文件即 0600 ⇒ `register` 跑在 `init` 之后会把 `INDEX.yaml`
  由 644 **降为 600**（同一输入、两种顺序终态权限不同）。已在写回前记录原 mode、`mv` 后按原 mode 复位
  （BSD `chmod` 无 `--reference`，故用 `stat -f '%Lp'` / `stat -c '%a'` 双回退）。
- **`INDEX.yaml` 骨架模板两处不一致（终态取决于谁先建文件）**：`plans/dsh-codepunk-link.sh` 自建索引时写
  1 行头注释，`plans/dsh-codepunk-init.sh` 写 11 行注释块，且 init 见文件已存在即跳过 ⇒ `init→register`
  与 `register→init` 两种顺序的终态注释头不同（非注释行一致）。已让 link 侧模板与 init 侧**逐字节一致**，
  并新增 `plans/doc-consistency.sh` **第 25 类**（同一制品的多处生成器须一致）+ 永久存活变异（M162）。
- **4 个运行型脚本未实现 `-h`/`--help`**：`acceptance-verify.sh`、`evidence-verify.sh`、
  `checker-self-test.sh`、`verify-battery.sh` 把 `-h` 当位置参数（报「文件不存在 / 预设根无效」），
  与全仓「实现者 MUST 返回 0 并打印头部用法」的约定不符（`checker-self-test.sh` 的 M149 甚至把该约定
  写进了变异夹具，自身却是缺口）。已补齐四个 `-h` 分支，并把第 20 类的探针表由 10 条 `-h` 扩到 14 条，
  同时新增静态子项「每个运行型脚本都 MUST 实现 `-h`」+ 永久存活变异（M161）。
- **`PR_BODY` 环境变量未记载**：`plans/git-merge-flow.sh` 的 `pr` 子命令支持 `PR_BODY` 覆盖 PR 正文
  （实测两次调用正文不同 ⇒ 变量真实生效），但脚本头部与文档零提及（违反 CONTRIBUTING「声称与实现
  是否同步」）。已记载于脚本头部，并新增 `plans/doc-consistency.sh` 第 5 类子项「外部输入变量须被记载」
  （任一 `.md` 或脚本头部注释块）+ 永久存活变异（M163）。
- **Dependabot 声明的生态无对应清单（静默空转）**：`.github/dependabot.yml` 声明 `pip` 生态，而仓库
  没有任何 pip 清单（`plans/*.py` 仅用标准库，`git ls-files` 无 requirements/pyproject/setup/Pipfile/lock），
  该条目**恒不产出 PR**；`docs/maintenance.md` 还声称「每周一巡检 `github-actions` 与 `pip` 两个生态」。
  已删除 pip 条目（只声明仓库真实存在的生态）并更正文档，新增 `plans/doc-consistency.sh` 第 7 类的
  Dependabot 子项（声明的生态须有对应清单；`labels` 引用的标签须由 `plans/github-setup.sh` 幂等创建；
  维护文档的生态清单须与声明一致）+ 永久存活变异（M160）。
- **Dependabot PR 标签 `dependencies` 不存在**：两条条目声明 `labels: [dependencies]`，而仓库标签集里
  没有该标签（同判据对 `automerge` 判存在）⇒ 该字段静默失效、5 个历史 Dependabot PR 的 labels 全为空。
  已按既有约定（自动化引用的标签由治理脚本创建）在 `plans/github-setup.sh` 增加幂等创建步骤（步骤 ⑤）。
- **`Makefile` 自述与 CI 关系不符**：头部称「本地与 CI（Ubuntu）用同一条命令复跑」，而 `.github/workflows/ci.yml`
  全文无 `make` 调用（四个作业各自直调 `plans/` 脚本，并有 Makefile 没有的步骤：`bash -n`、`py_compile`、
  shellcheck、可执行位与移植性扫描）；`make gates` 与 CI 的「门禁回归」也不等价，`make write-scope`
  实参窄于 CI（缺假 HOME 的 `--home`）。已改为实测口径的描述，并写明「以 CI 结论为准」。
- **CI 门禁表与实际执行不符**：`CONTRIBUTING.md` 的「CI 门禁」表把必需检查 `跨平台可移植` 描述为
  「POSIX 与 Windows 两侧实现的对等性」并指向 `verify-battery.sh` 的「跨平台项」——该作业实际只扫描
  `plans/*.sh` 的可执行代码（GNU/BSD 专有写法、CRLF、TAB 缩进）与可执行位，既不看 `plans/windows/*.ps1`，
  电池也没有「跨平台」项 ⇒ 平台对等实为人工公约，读者却以为有机械守护。已改为与实现相符的描述，并在
  `plans/doc-consistency.sh` 新增「必需检查的文档声称 ↔ 作业实际执行」子项 + 永久存活变异（M159）。
- **存活自检的结论行未计入「跳过」**：环境受限（缺 `DSH_APP_ROOT`/`node`/可构造的影子 PATH）时若干变异只打印 `ℹ … 跳过` 而不执行，末行却仍无条件写「✔ 自检通过：**全部变异**均被对应检查项捕获」（脚本内无跳过计数器）。实证：同一脚本设/未设 `DSH_APP_ROOT` 两次运行分别为 ✅275 与 ✅270，结论文案完全相同；CI（`.github/workflows/ci.yml`）未设该变量 ⇒ 恒跳过依赖产品安装的变异族却仍判通过。已加 `SKIPPED` 计数与统一 `skip()` 助手（12 处跳过节），结论行据实报「捕获 N/M 项 + 跳过 K 项（跳过 ≠ 通过）」，并新增 `--coverage-echo` 测试钩子（与主路径共用 `coverage_line`）+ 永久变异 M171（四断言，含「删除分支即复现旧文案」的非空转证明）。
- **文档「派生计数口径」表的实况列漂移且无门禁覆盖**：`docs/development.md` §7 表的「当前实况」列长期写「167（M1–M167）」与「24」，而实现已派生 171 项变异与 25 类检查——该类写法（裸数字 /「N（M1–MN）」）不在第 1 类「N 项…」族域内。已按**行标签**新增机械核验（变异项数 / 文档一致性类数 / 电池项数）+ 永久变异 M172（两断言）。

- **写盘纪律门漏检 Python 字节码缓存（`__pycache__`/`*.pyc`）**：`plans/write-scope-check.sh` 的 G1 仓库残留
  按**文件名模式**判定，黑名单未含字节码缓存 ⇒ 在仓库内 import 本仓 `plans/*.py`（本轮实测两次：
  `hook-write-scope.cpython-314.pyc`、`preset-compat.cpython-314.pyc`）生成的残留**对 G1 不可见**
  （`--repo .` 仍报「✓ 仓库残留：无」），而它会被 `plans/verify-battery.sh` 的杂散检查判失败 ⇒
  自检内层电池基线变红、失败原因与书写者无关。已把 `__pycache__`/`*.pyc` 纳入 G1 命名黑名单与
  §6.2 契约，并在永久存活变异 M135 增一条断言（`plans/__pycache__` 须被判残留）。
- **声明生成器的 `emit` 在管道下被截断（下游静默采用半截声明）**：`plans/preset-declare.mjs` 的 `emit`
  用 `process.stdout.write(...)` 紧接 `process.exit(0)`，而 Node 对**管道**是异步写、`exit` 会丢弃未刷出的
  缓冲 ⇒ `emit | wc -c` 得 65536（文件重定向为 71493），且**截断产物仍是合法 YAML 并含声明 id**，
  下游（`--patch` 叠加、部署脚本）会静默采用半截声明。已改为同步写 fd 1（`writeSync`），并新增
  永久存活变异 M165（断言管道字节数 = 文件重定向字节数）+ 组合核验检查 8 的同款断言。
- **阈值检查把 `base64` 当作评分基准值（假阳性）**：`plans/doc-consistency.sh` 第 7 类的「评分基准 base」
  正则 `base[：: ]*([0-9]+)` 允许零分隔符 ⇒ 正文中的 `base64` 被抽成基准值 64，与真值 50 冲突并报
  「评分基准 base 取值不一: 50,64,」⇒ 任何含该词的文档都无法通过门禁。已改为要求至少一个分隔符
  （`base[：: ]+([0-9]+)`）。
- **未来日期判据时区相关（合法内容在 CI 上必红）**：`plans/doc-consistency.sh` 第 8 类以 `date +%F`
  取「今天」并与文档日期做字符串比较，而 CI 运行器为 **UTC** 时钟：作者本机（UTC+7）「今天」在
  UTC 时钟下尚未到来 ⇒ 本地 00:00–07:00 产生的一切合法日期（如 `retrieved_at: 2026-10-08`）在 CI 上
  被判「未来日期」，**每个这样的 PR 的「文档一致性」作业都必然失败**（本轮实测：同一提交本机 rc=0、
  CI rc=1「未来日期: agent.cordis.yml:2026-10-08」）。已把上限改为 **UTC 今天 +1 天**（覆盖 UTC+14
  时区作者的本机今天；仍拦住远未来日期，例如 2099 年那类），并新增永久存活变异 M166（注入
  UTC 今天 +1 天须放行、+2 天须报出）。

- **溯源档案索引缺口与零引用孤儿内容（内容卫生治理首轮）**：`skills/dsh-codepunk-workflow/references/learned-skills.md`
  的「溯源档案（benchmarks/）」表登记 16 条并声称「16 篇」，而同类目录实有 **19 个 `.md`**；未登记者 3 篇，其中
  `benchmarks/dsh-latest-features.md`（约 19 KB，DSH 2.0.17 外部调研简报）**全仓零引用**——读者按索引找不全材料，
  且孤儿材料无人维护。已补齐 3 条登记、把篇数声称改为「19 篇 = 目录内全部 `.md`」，并由新增的评分判据 B16
  对「表内条数 = 目录篇数 = 声称篇数」与「零引用内容」做机械核验（后述）。
- **`CHANGELOG.md` 条目引用运行根路径（公开仓不可解析）**：此前一条修复记录把红绿证指向
  `logs/r652/…`（运行根路径，公开仓中不存在，且会给读者「文件丢失」的误导）。已改写为纯文字描述结论。
- **自检夹具越界写源树（F430）**：内容卫生变异 M211 的夹具用**相对路径**写入（自检工作目录即调用方目录），
  于是真的改动了工作树——删掉一行索引登记并留下一个 512 KB 探针文件；由源树密封判据（`seal_check()`，
  带 `git status --porcelain --ignored=matching`）拦下，该轮自检整体作废。已改为**绝对沙箱路径**
  `$work/cur` + 「沙箱根名为 cur」「沙箱根 ≠ 源树」断言 + 写后源树禁区断言，并把该纪律登记为 D119。
  同轮另一处夹具设计缺陷（夹具名的字面量写在被检查的自检文件里 ⇒ 判据正确地不判它为「零引用」，造成假失败）
  一并修正为**运行时拼接名称**；该假失败曾诱发一个不成立的缺陷假设，已用最小夹具证伪并完整回退，未登记为缺陷。

### 新增

- **写盘纪律三层强制（硬规则 R17）**：机械门 + 硬规则 + 岗位写域三者同时生效，规定 AI 写入的优先序——运行根 → 授权工作树内该任务的写集路径 → 系统临时目录（次选，用毕即删）→ 总库 `knowledge/`；探针脚本一律落运行根 `logs/`；越界即缺陷并当轮清理。细则见 `skills/dsh-codepunk-workflow/references/file-hygiene.md` 与 `references/roles.md`。
- **写盘纪律机械门 `plans/write-scope-check.sh`**：三类判定——仓库残留（含未跟踪文件）/ 主目录顶层散落 / 临时目录双根残留；判定只认本契约命名空间（`dsh-codepunk-` 前缀条目），同形他人条目降级为 `ℹ`「归属不明」且不改判；`--exempt-from` 读取运行根 `README.md` 的 `write_scope.exempt:` 登记并把登记项及其子路径降级为 INFO；退出码 `0` 通过 / `1` 发现越界 / `2` 无法核验或用法错。
- **反思考循环规范（硬规则 R16）**：连续 3 步无新证据、或同一失败指纹重复达 2 次时，必须换策略或上报，不得原样重试；被证伪的结论与失败轨迹只保留结论与已证伪路径。细则见 `skills/dsh-codepunk-workflow/references/anti-loop.md`。
- **文档一致性第 24 类检查**：Markdown 表格列数一致与结构完整——逐项判定表头与分隔行的列数一致性、分隔行后紧跟空行的断表、围栏长度与类型配对、缩进代码块、引用块内表格、无行首竖线的表格，以及代码跨度内未转义的竖线。
- **根目录社区健康文件**：新增 `SECURITY.md`（安全策略与漏洞报告）、`CODE_OF_CONDUCT.md`（Contributor Covenant 2.1 中文译本与执行后果）、`SUPPORT.md`（求助渠道与提问模板）、`GOVERNANCE.md`（角色、决策、变更流程、发布权限、维护者产生）、`CHANGELOG.md`（本文件）。
- **CI 工作流与仓库规则脚本**：新增 `.github/workflows/ci.yml`，含四个作业 `门禁回归` / `存活自检` / `跨平台可移植` / `文档一致性`；配套 `plans/github-setup.sh` 生成仓库 Ruleset（`main` 受保护：必须经 Pull Request、必须通过上述四项状态检查、禁止强制推送与直接推送）。
- **协作模板与工程化入口**：新增 `.github/` 协作配置（`CODEOWNERS`、Issue 模板、PR 模板、Release 说明模板、Dependabot 更新配置，以及 `codeql.yml`、`scorecard.yml`、`release.yml` 工作流）；新增 `Makefile` 工程化入口（`gates` / `battery` / `selftest` / `write-scope` / `compat` / `mirror` / `clean`）；新增 `.editorconfig` 与 `.pre-commit-config.yaml`；`.gitattributes` 与 `.gitignore` 随新文件同步更新白名单。
- **合并流脚本 `plans/git-merge-flow.sh`**：把「建分支 → 提交 → 推送 → 开 PR → 以合并提交落地 → 删分支」收成 `start` / `commit` / `pr` / `merge` / `status` 五个动作，其中 `merge` 在删除远端分支前先断言分支顶端确实是合并提交（父数为 2），断言失败即保留分支以便排查。
- **面向使用者的专题文档**：新增 `docs/` 目录（`architecture.md`、`development.md`、`deployment.md`、`documentation-policy.md`、`naming-conventions.md`、`maintenance.md`、`faq.md` 与 `docs/adr/` 决策记录目录），并与 `README.md` 的文档索引相互引用。
- **写盘护栏拦截层（hooks，本预设自有声明）**：接入 `@deepseek-ai/dsh-hooks-claude-code` 桥 + 新增 `plans/hook-write-scope.py`（PreToolUse 命令钩子，Python 3 标准库）与 `plans/hooks/hooks.json`（`matcher: write|edit|bash|pwsh`），`agent.cordis.yml` 新增 `- id: hooks-write-scope` 条目（`configPath`/`pluginRoot` 按 `!!js` + `baseUrl` 解析）。默认 `deny` 黑名单阻断（系统路径含 `/var` 但排除 `/var/folders`、凭据目录 `~/.ssh`/`~/.aws`/`~/.gnupg`、`~/.dsh/profiles/**`、主目录顶层散落文件），`DSH_CODEPUNK_HOOK_MODE=strict` 为白名单放行；**钩子退出码 2 即阻断该次工具调用，stderr 作理由回给模型**。定位为「宿主层沙箱 → 预设层三层纪律 → 拦截层 hooks」的最内一层**启发式**拦网（可被混淆绕过、非沙箱），与事后扫描门 `plans/write-scope-check.sh` 并列。层级关系、模式、覆盖与不覆盖、缺口清单见 `references/file-hygiene.md` §八。
- **运行时检视工具（只读）**：`agent.cordis.yml` 新增 `- id: tool-cordis`（`@deepseek-ai/dsh-tool-cordis`），注册 `cordis_inspect_list` / `cordis_inspect_query`——列出并查询 Host 与 Client 的 Inspect Provider（插件 Config schema、Tool schema、Slot 树等），供写插件/改配置前读精确接口；不能调用业务 Service、不能改运行时。两个工具名已加入共享白名单锚点 `&role-allow`（只读，对所有岗位安全；调研岗内联名单同步）。

- **内容卫生判据 B16（评分器第 16 项）**：`plans/preset-score.sh` 新增 `B16 内容卫生`，五项独立子判据——单文件字节上限、
  跨文件重复块冗余、跨文件重复行冗余、溯源档案索引缺口、零引用孤儿内容。**上限与阈值不在脚本里另立一套**：一律从
  `docs/development.md` §7.1 的「内容卫生上限」表解析（单一声明源，决策 D117；阈值只降不升，D118），
  解析不到即报「无法核验 ≠ 通过」并退出码 2；缺 `python3` 或 git 枚举失败同样按「无法核验」处理，绝不默认满分。
  永久存活变异 `M211`（三条命中断言 + 一条削弱对照）。
- **内容卫生上限表（`docs/development.md` §7.1）**：给出五项可机械核验的数值与口径（≥3 连续行、每行归一化 ≥10 字符、
  块 ≥200 字节；重复行按归一化 ≥40 字符计），既是判据 B16 的阈值来源，也是工位仪器（规模与重复度扫描、
  仓库卫生检查）的派生来源。
- **决策 D117 / D118 / D119**：规模与重复度上限的**单一声明源**、内容卫生阈值**只降不升**、
  自检夹具的**越界防线**（必须绝对沙箱路径 + 源树禁区断言）。三条均由本轮实测缺陷驱动登记。

### 变更
- **许可正文去重与重复行上限棘轮（F470）**：`docs/licensing.md` 曾逐字复制 MIT 正文 21 行（1133 字节，与根目录 `LICENSE` 完全重复），现改为只引用 `LICENSE`（唯一声明源，D129：同一文本存两处会随年份/署名/措辞漂移）；`docs/development.md` §7.1 的「跨文件重复行冗余」上限按 D118 只降不升由 12000 下调到 7000。复扫 `tools/junk-dup-scan.py`：重复行冗余 7173 → 6132 字节（83 → 68 行），重复块 220 字节不变。新增存活变异 M225（以既有 A5「成段重复」判据守护：夹具把许可正文复制回文档 ⇒ A5 须扣分且 rc=1；干净态 rc=0 且零「成段重复」，证明判据非空转）。
- **仓库根与依赖预检入库（D128 单一声明源，F467）**：4 个脚本各自 `cd "$(dirname …)/.." && pwd` 求仓库根、3 处内联依赖预检（`for _t in …; do command -v …`）与 10 处内联 `command -v node` 探针逐字重复 ⇒ 守卫库新增 `EG_ROOT` 与 `codepunk_need`，消费方改 `ROOT="${1:-${EG_ROOT:-}}"` 与单行 `codepunk_need <工具…>`，node 探针统一走 `codepunk_have node`（域内内联残留 0）；跨文件重复行冗余 7653 → 7173 字节（count 87 → 83），重复块与孤儿/超限/空白指标不变（内容治理第 9 轮）。
- **用法块打印入库（D127 单一声明源，F465）**：域内 5 个脚本各写一遍的 `-h`／`--help` 用法打印行（取第 2 行至第 28 行注释、去行首 `# `、退出 0）**逐字相同**（256 B ×5，是剩余跨文件重复行的最大单一行源）⇒ 收敛为守卫库 `plans/env-guard.sh` 的 `codepunk_usage <行区间>`，消费方改为单行分支（`-h|--help) codepunk_usage 28 ;;`），行区间**显式传参**（各脚本 28／27／30／18 并存）；参数非整数或越界保守拒答 rc=2。新增存活变异 M223（参数形态校验 ＋ 削弱后消息消失）。
- **依赖探针与核验缺口消息统一入库（D126 单一声明源）**：18 处内联 `command -v python3` / `command -v ruby` 与 3 处 python3 能力探针（presence + executability 两段）改为库调用 `codepunk_have` / `codepunk_need_py`（唯一探法源＝`plans/env-guard.sh`），仅保留 `preset-score.sh` 一处内联形态作为 M85 断言锚点；跨文件重复行冗余 9029 → 8167 字节。新增存活自检 **M221**（a 库探针 ≥20 处；b 内联形态 ≤1 处；c/d 夹具注入第二处内联形态与消息副本 ⇒ 判定式须转向，证明非空转）。
- **新增 `make ps-validate` 目标**：PowerShell 校验器依赖安装 + `ps-validate.mjs` 语法校验，本地与 CI 两个作业共用同一配方（F454）。
- **计数声称门域扩到 `Makefile`**：第 1 类现逐处比对 `Makefile` 内的「N 指标」与「N 项独立验证/一次跑完」（F455）。
- **第 29 类新增枚举回退**：`git ls-files` 失败**或空结果**都回退文件系统遍历（真核验，非跳过），仅当两条路径都取不到文件时才判「无法核验 ≠ 通过」（F449）。
- **第 29 类：`.editorconfig` 声明落地门**：`.editorconfig` 的四类形态声明（行尾空白 / 末尾单换行 / 换行形态 / 缩进制表符）纳入文档门机械核验，硬判项一律以**已声明**标准为依据（D125）。
- **内容卫生上限按 D118 再次下调**：跨文件重复块冗余 2200→**800**、跨文件重复行冗余 15000→**12000**（实况 451 / 9487）。
- **公共库新增根校验**：`plans/env-guard.sh` 增 `codepunk_need_root`，4 个门禁脚本由内联块改为单行调用（D124 ③）。

- **公共环境守卫抽为 `plans/env-guard.sh`（内容治理第 3 轮）**：15 个脚本各自内联的 locale 固定块（F195/F197）与 POSIX 拒答块（F421）是**同一份实现复制 13/9 遍**的结构性重复（约 2.6 KB）；现抽为 `plans/` 顶层的纯 source 库（23 行），消费方以单行自定位接入（`_EG="$(dirname "${BASH_SOURCE[0]:-$0}")/env-guard.sh"`，约 160 字符，仍短于重复块窗口下限），库不可读时 rc=2 保守拒答并点名缺失件。因库与既有 `dsh-codepunk-home.sh` 同域，镜像域、跨平台语法检查域与「源副本 ↔ 总库」双向对照自动覆盖。指标（工位仪器 `tools/junk-dup-scan.py`）：跟踪文件 101→**102**（新增库文件）、跨文件重复块冗余 2943→**1102**（块 4→3）、跨文件重复行冗余 16569→**13747**（行 108→103）；消费方净减 **130 行**、库 +23 行。仓库字节 1760796→1765968（+5172，来自本轮新增的决策登记与变更日志文本，非重复内容）。
- **§7.1 上限按「只降不升」再次下调（D118）**：跨文件重复块冗余 3800→**2200**、跨文件重复行冗余 18000→**15000**（对实况 1102 / 13747 留 1098 / 1253 字节余量），使本轮削减被机械锁定；评分门仍 16/16 全满分。
- **注释叙事与分隔线收敛（内容治理第 2 轮）**：12 个门禁脚本的 locale 叙述块、9 个脚本的 POSIX 叙述块由 4 行压成 1 行，81 行注释型分隔线（含 `.github/**` 与 `Makefile`）统一缩到 45 列。仓库字节 1764638→1754304（−10334）；跨文件重复块冗余 4851→2943 字节（块 7→4）、跨文件重复行冗余 21593→16569 字节（行 121→108）。受限的**结构性**冗余（locale 探测循环与 POSIX 守卫共 ~2.6 KB，需抽公共库）另立专轮处理。
- **§7.1 上限按「只降不升」下调（D118）**：跨文件重复块冗余 5120→**3800**、跨文件重复行冗余 23040→**18000**，使本轮削减被机械锁定（余量 857 / 1431 字节）；下调后评分门仍为 16/16 全满分。

- **`README.md` 重写为使用者向概览**：按「定位 → 快速开始 → 机制概览 → 门禁与命令表 → 平台支持 → 目录结构与文档索引」组织，并把目录清单收敛为本文件的唯一权威来源。
- **`CONTRIBUTING.md` 重写为完整贡献流程**：新增环境准备、分支模型（`feat/` `fix/` `docs/` `chore/`）、提交信息约定、合并方式、PR 门禁与审查要求、发布流程与开发命令速查；原「维护公约要点」保留为独立一节。
- **合并方式明确为合并提交**：一律通过 Pull Request 以**合并提交（merge commit，`--no-ff`）**并入 `main`，仓库设置仅保留「Create a merge commit」；禁止直接推送与强制推送。
- **发布流程文档化**：版本号按语义化版本判定，`CHANGELOG.md` 的 `Unreleased` 段在发布时落为版本段，由维护者打 tag `vX.Y.Z` 并在 GitHub Releases 发布（发布说明直接取自本文件，不另写一套）。
- **`agent.cordis.yml` 去除重复注释块**：同一份 5 行「子代理路由（DSH 0.2.0-rc.2 实测）」说明此前在文件中出现 **13 次**（首尾两行各有 13 份完全相同），既是约 4.5 KB 冗余，也意味着 13 份「改了其中一处」的漂移风险；现只在首个共享白名单锚点上方保留完整说明，其余 12 处改为一行指针（文件 710 → 662 行）。

### 修复

- **无 ruby 主机上 YAML 解析恒报「解析失败」（环境缺口被说成配置非法）**：`plans/preset-audit.sh` 的 A1 node 回退分支用 cwd 式 `require("js-yaml")`（不走 `preset-declare.mjs` / `verify-battery.sh` 的候选链）且用默认 schema，遇本仓 `agent.cordis.yml` 的 9 处 `!!js` 自定义标签抛 `unknown tag !<tag:yaml.org,2002:js>`（实测 84:50）——两者叠加使**无 ruby 的主机（Windows / 精简镜像）上 A1 恒红**（`2>/dev/null` 吞掉真实错误），而同一环境的 `preset-declare.mjs check` 却报「语义一致」。现改为：候选链查找 js-yaml + 容忍 `!!js` 的 schema；两路都不可用时报「A1 无法核验（有 node 但候选链内未找到 js-yaml）——无法核验 ≠ 通过」，真损坏仍报「YAML 解析失败」。`plans/dsh-codepunk-link.sh` 的两处 node 分支（INDEX 解析核验 / 语义核验）用同一候选链（新增 `_jy_dir()`）；其语义分支另修**类型判定与 ruby 口径不一致**——js-yaml 把 `last_updated: 2026-…` 解析成 **Date**，旧判据按 `typeof === "object"` 判为「非标量」⇒ 真实 INDEX 上假红「INDEX 语义非法：last_updated 须为标量」（ruby 的 Psych 给 Time，而 ruby 判据 `is_a?(Hash)/is_a?(Array)` 认定其属标量）。F351 / F352 / F353 实证（永久存活变异 M157、M158）。

- **验证电池的跳过项被计入「满分」**：设 `DSH_CODEPUNK_SKIP_SELFTEST=1`（自检递归防护开关），或环境缺 `DSH_APP_ROOT` / `js-yaml` 时，`plans/verify-battery.sh` 仍打印「本轮：全部通过（满分）」并以 0 退出——与本文件自身 F181 确立的「未实际核验的类型不得计入通过」相悖，操作者会把「未核验」读成「满分」。现改为**跳过登记**：因缺工具 / 缺环境变量 / 递归防护开关而跳过的项一律在结论行列明（「本轮：实检项全部通过（跳过 N 项未核验：…）——跳过 ≠ 通过」），仅当无跳过项时才打印「全部通过（满分）」；退出码契约不变（0 = 实检项全通过）。F350 实证（永久存活变异 M156）。
- **证据 `log_ref` 无交付目录包含性判据**：绝对路径（`/etc/hosts`）、`..` 逃逸与指向交付目录外的符号链接均得 `verdict=PASS`——「防假通过门」的 ②③ 对本次交付不成立。`plans/evidence-verify.sh` 增包含性判据（解析后须位于交付目录内）+ 永久存活变异 M154。
- **分支保护必需检查名无任何机械守护（改名即静默失配、PR 永久阻塞）**：`main` 的 ruleset 按**上下文名**匹配必需检查，名字来自 `.github/workflows/ci.yml` 各作业的 `name`，声明侧却在 `plans/github-setup.sh` 的 `CHECK_CONTEXTS`——两者无门禁比对。实测把四个作业名各加 `-v2` 后 `doc-consistency.sh` 仍 rc=0（四门禁全绿），而 ruleset 的必需检查将**永不出现** ⇒ 所有 PR 永久阻塞且无告警。现 `doc-consistency.sh` 第 7 类增子项：`CHECK_CONTEXTS` ↔ `ci.yml` 作业名 ↔ `docs/maintenance.md` 的提及三方一致；`docs/maintenance.md` 补名映射与改名后果说明。F347 实证（永久存活变异 M153）。

- **INDEX 顶格块序列被误判为非法，登记链在真实总库整体失效**：`plans/dsh-codepunk-link.sh` 的结构守卫把 `projects:` 下**顶格**书写的序列项（`- project_id: …`，YAML 允许序列与键同列——迁移与早期写入器产出的形态）当成「未知顶层键」，于是 `index` 报「结构非法」并建议「从备份恢复」（该文件其实可被 YAML 正常解析），`register` 追加被回滚。现两处守卫（`index` ① 与写入前 python 守卫）均容忍顶格序列项及 `---`/`...` 文档标记；追加条目**沿用既有缩进风格**（顶格索引继续写顶格），否则追加的缩进条目会成为映射值下的嵌套序列、被写入后校验判为非法 YAML 而回滚。真错（未知顶层键）仍失败（永久存活变异 M152，五断言）。
- **散落根判据把无关仓库判为失败，而文档化落点从不被扫描**：`plans/verify-worktree.sh` 的默认散落根只认桌面候选（`~/Desktop` / `~/桌面`），且目录直扫项对散落根内**任何** git 仓库一律判 FAIL——实测在开发机上把桌面里 6 个与本预设无关的仓库全部报为「散落 git 仓库/worktree」，检查永久失败；同时仓内文档化的 worktree 落点 `~/.dsh-codepunk/worktrees/<task_id>/` 从不进入扫描（漏检）。现默认根解析顺序改为 `SCAN_ROOT` > `DSH_CODEPUNK_WORKTREES`（总库 `worktrees/`）> `DESKTOP` > 桌面候选，且目录直扫项收窄为「仅与本主仓库共享 git 目录（`git rev-parse --git-common-dir`）的散落 worktree 判 FAIL，其它 git 仓库只报 INFO」（永久存活变异 M151，四断言）。`README.md` 门禁表的解析顺序与判据同步改写（原文声称「未设则跳过该项扫描」与实现不符）。
- **制品字段模板声称悬空**：`SKILL.md` 的 ① 阶段写明「产 `plan_draft.md` + `goal.yaml`（字段模板见 `references/artifacts.md`）」，但 `artifacts.md` 全文只在运行根树状图里出现过 `plan_draft.md` 一次——该制品的字段契约**无处可查**。现补 `## plan_draft.md（① 需求草案；与 goal.yaml 同批产出）` 小节（字段模板 + `assumption`/`open_question` 标记约定 + D034/D035 硬约束）。
- **制品字段模板声称无机械监督**：第 10 类原只校验 `references/<名称>.md「章节名」` 与限定式 `§N` 两类引用，「`<制品>`（字段模板见 `references/artifacts.md`）」这一族悬空时无告警。现第 10 类增子项：声称有字段模板的制品名 MUST 在 `artifacts.md` 有 `##` 小节（永久存活变异 M150）。
- **退出码声明要求可被注释散文规避**：`doc-consistency.sh` 第 5 类的库脚本豁免原为 `grep -qE '\bsource\b'`——任何含「source」一词的 `.sh` 一律豁免，注释与规则文本即可触发（`doc-consistency.sh` 因自身规则文本而**自我豁免**、`verify-battery.sh` 因注释含该词而豁免、`dsh-codepunk-link.sh` 为运行型 CLI 却因加载路径常量被豁免），致三者长期无头部退出码声明、`实现退出码 ⊆ 声明码集` 判据对其恒空转。现取消该启发式：豁免只剩 home 脚本特例与「无显式退出调用」，并为三个脚本补上头部退出码声明。
- **`docs/**` 计数声称无机械监督且已陈旧**：第 1 类的计数域原只到 README，开源规格化引入的 `docs/` 无任何计数守护 ⇒ `docs/development.md`、`docs/architecture.md`、`docs/naming-conventions.md` 长期声称「137 项变异（M1–M137）」而实现已 146。现将「实现派生量」的声称域扩到 `README.md` + `docs/**`（同实现值、同族写法，域与覆盖范围写在结论里），并同步更正上述计数。
- **兼容性文档的产品源码行号引用漂移**：`references/file-hygiene.md` 的 3 处引用按旧版本行号，实测已失准——`SANDBOX_MODES` 由 `:35-39` → `:26-30`、用户平面 `permission` 区块由 `:168-181` → `:216-229`、`defaultPreset` 由 `:181` → `:229`（声称内容仍成立，故内容类检查无法发现）。现更正行号，并新增「行号引用规则（MUST）」：引用一律附符号名检索式，核验以符号名检索为准。
- **依赖更新自动合并的两条路径与自证判据**：对已可合并（`mergeStateStatus=CLEAN`）的 PR 武装自动合并会被 GitHub 拒绝（`Pull request is in clean status`），而武装成功后若立即可合并，GitHub 会当场合并并使 `autoMergeRequest` 变 `null` ⇒ 原自证判据误报失败。现改为「已可合并即直接以合并提交入库；否则武装，命中该错误时回退直接合并」，自证判据取「已武装**或**已合并」。见 `.github/workflows/dependabot-auto-merge.yml`。
- **`automerge` 标签路径可用**：工作流触发事件补 `labeled`（此前打标签不会触发），并由 `plans/github-setup.sh` 幂等创建该标签（此前仓库中不存在）。
- **无 `.git` 环境下 ps1 行尾校验被跳过而整体仍报「无硬性不一致」**：`doc-consistency.sh` 第 17 类的 ps1 工作树行尾（`eol=crlf` 落地）子项原先在 git 不可用时只打印跳过说明却仍以 rc=0 收尾，环境缺陷可整体假绿灯；现改为回退**文件系统字节核验**（剥离合法 CRLF 后仍有裸 LF 即判不合格），并按类 8 口径打印「已核验，非跳过」。
- **门禁树遍历跟随符号链接致链接环下永不返回**：`doc-consistency.sh`（第 8 类回退遍历、第 24 类表格扫描）与 `preset-score.sh`（重复段扫描）原用 Python `glob('**/*', recursive=True)`——`**` 默认**跟随符号链接**，检出内含链接环（自引用目录、指向祖先的链接、构建产物链接农场）时无限递归，门禁挂死（实测 `timeout 60` ⇒ rc=124、无判定行），连带 `verify-battery.sh` 与 CI `门禁回归` 作业一并卡住。现改用 `os.walk(followlinks=False)` 并保持相对路径口径，新增存活自检 M148（沙箱内造链接环 ⇒ 断言限时返回且判定通过）。
- **用户文档未覆盖本仓自有选项**：`README.md` 门禁表列出 `write-scope-check.sh` 的全部选项，却对 `verify-worktree.sh`（散落根环境变量 `SCAN_ROOT`、`--quiet`）与 `github-setup.sh`（`--dry-run`）零说明，使用者在文档内无法发现这些开关（脚本头注属实现侧，不构成用户文档）。现补齐两行用法与退出码说明。
- **`preset-declare` 对损坏的 profile 补丁假绿灯**：`apply --append` 对**非空但不可解析**的 YAML（或含 NUL 的非文本）补丁仍报「✅ 生效：重启 DSH Desktop」并把声明块追加进去，随后 `check` 只比对块文本又报「✅ 语义一致」——生成与校验双绿灯而补丁实际无法加载。现加文件头守卫：含 NUL 字节 ⇒ rc=2（无法核验 ≠ 通过）；js-yaml 可用且内容非空时先整体解析，失败 ⇒ rc=2 并提示先修复或从备份重建；空补丁（首次安装）与合法补丁行为不变。
- **`make` 入口在含空格路径下不可用**：`Makefile` 的仓库根推导原用 `$(dir $(abspath $(lastword $(MAKEFILE_LIST))))`，Make 函数按空白分词 ⇒ 路径含空格时 `ROOT` 只取到首个词，配方 `cd "$(ROOT)"` 失败并 rc=2（克隆到 `…/克隆 空格 é` 后 `make gates` 报 `cd: …/r612 . é: No such file or directory`，而同一路径下四道门禁直调 rc 全 0）。现改为 `$(shell cd "$(CURDIR)" && pwd)`（直接调用与 `make -C <dir>` 均正确，路径只在 shell 层加引号出现）。
- **`-h/--help` 约定的声称与覆盖不一致**：第 20 类的 `-h` 探针只有 6 条（audit / score / doc-consistency / verify-worktree / link / leak-guard），而仓内实际实现该约定的脚本有 10 个——`dsh-codepunk-init.sh`、`git-merge-flow.sh`、`github-setup.sh`、`write-scope-check.sh` 的 `-h` 若回归，门禁仍报「19 条探针」「✔ 无硬性不一致」（实测：把这 4 个之一的 `-h` 分支改为 `exit 2`，旧探针集 rc=0、新探针集 rc=1「退出码契约漂移」）；脚本注释又把该约定写成「与其余脚本一致的通用约定」，与实际（8 个脚本未实现、按用法错误返回 2）不符。现把探针集扩到全部 10 个实现者（声明探针数 19 → 23，治理表同步），并把注释改写为精确规则：实现者 MUST 返回 0 并打印用法，未实现者按用法错误返回 2。
- **签收门自签判据不区分大小写**：`plans/acceptance-verify.sh` 原以区分大小写的子串判断「签收方是否为交付方」，交付方 `task-a` 的签收方写 `Task-A` 即判通过 ⇒ 自签可被改大小写绕过。现比较前统一去首尾空白并转小写。
- **签收门交付方参数改为必填**：该参原为可选，不传时独立性整段跳过却仍打印「PASS: 结构合法且签收独立」（声称已校验而实际未校验）。现缺交付方 ⇒ rc=2 并显式提示「无法核验 ≠ 通过」。
- **`preset-declare` 对不兼容根结构与不可解析产物的假绿灯**：`apply` 只校验「输入能否被解析」，不校验 profile patch 的**根结构**、也不复核**产物**——根为映射的合法补丁被 `--append` 追加 `- insert:` 项后，顶层同时含映射与序列 ⇒ 产出非法 YAML（`end of the stream or a document separator is expected (14:1)`），而工具仍打印「✅ 生效：重启 DSH Desktop」（按提示重启后产品读到的却是坏补丁）；含 `...` 文档结束符的序列补丁追加后成为多文档，同属此类。现加三层守卫：①根结构前置校验（根 MUST 为序列，空文件视为首次安装；缺 js-yaml 的降级模式按首个有效行做文本判定）⇒ 不符即 rc=2 且不改动文件、不留备份；②降级模式下对含 `---`/`...` 文档分隔符的补丁拒答（该模式无法复核产物）；③写出后用同一解析器复核产物，不合规则从备份回滚并以 rc=2 拒答。新增存活自检 M155（六断言）。
- **治理脚本覆盖自动合并能力**：`plans/github-setup.sh` 的仓库元数据期望、比对字段与请求体三处纳入 `allow_auto_merge=true`，最终回读新增该字段与标签校验（此前关闭该能力不会被脚本发现）。

---

## 版本比较链接

版本比较链使用 Keep a Changelog 的标准引用式写法，置于本文件**末尾**；在首个版本打 tag 之前不写死链接，避免死链。格式示例（`<` `>` 为占位符，替换为真实版本号后启用）：

```text
[Unreleased]: https://github.com/webees/dsh-codepunk/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/webees/dsh-codepunk/compare/v0.9.0...v1.0.0
[0.9.0]: https://github.com/webees/dsh-codepunk/releases/tag/v0.9.0
```

- `Unreleased` 段与**最新已发布版本**比较，段尾固定为 `...HEAD`；
- 相邻已发布版本之间用 `compare/<前一版本>...<本版本>`；
- 首个版本没有前驱版本可用，改用 `releases/tag/<版本>`。

版本段的标题形态固定为 `## [X.Y.Z] - <发布日期>`（日期为 ISO 形态）。在首次发布（打第一个 tag）之后，本文件须同时补上上面三条真实链接的定义。
