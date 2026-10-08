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

### 变更

- **`README.md` 重写为使用者向概览**：按「定位 → 快速开始 → 机制概览 → 门禁与命令表 → 平台支持 → 目录结构与文档索引」组织，并把目录清单收敛为本文件的唯一权威来源。
- **`CONTRIBUTING.md` 重写为完整贡献流程**：新增环境准备、分支模型（`feat/` `fix/` `docs/` `chore/`）、提交信息约定、合并方式、PR 门禁与审查要求、发布流程与开发命令速查；原「维护公约要点」保留为独立一节。
- **合并方式明确为合并提交**：一律通过 Pull Request 以**合并提交（merge commit，`--no-ff`）**并入 `main`，仓库设置仅保留「Create a merge commit」；禁止直接推送与强制推送。
- **发布流程文档化**：版本号按语义化版本判定，`CHANGELOG.md` 的 `Unreleased` 段在发布时落为版本段，由维护者打 tag `vX.Y.Z` 并在 GitHub Releases 发布（发布说明直接取自本文件，不另写一套）。

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
