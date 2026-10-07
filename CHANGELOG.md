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

### 变更

- **`README.md` 重写为使用者向概览**：按「定位 → 快速开始 → 机制概览 → 门禁与命令表 → 平台支持 → 目录结构与文档索引」组织，并把目录清单收敛为本文件的唯一权威来源。
- **`CONTRIBUTING.md` 重写为完整贡献流程**：新增环境准备、分支模型（`feat/` `fix/` `docs/` `chore/`）、提交信息约定、合并方式、PR 门禁与审查要求、发布流程与开发命令速查；原「维护公约要点」保留为独立一节。
- **合并方式明确为合并提交**：一律通过 Pull Request 以**合并提交（merge commit，`--no-ff`）**并入 `main`，仓库设置仅保留「Create a merge commit」；禁止直接推送与强制推送。
- **发布流程文档化**：版本号按语义化版本判定，`CHANGELOG.md` 的 `Unreleased` 段在发布时落为版本段，由维护者打 tag `vX.Y.Z` 并在 GitHub Releases 发布（发布说明直接取自本文件，不另写一套）。

### 修复

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
