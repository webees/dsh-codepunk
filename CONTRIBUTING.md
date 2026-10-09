# CONTRIBUTING · dsh-codepunk 贡献指南

本仓交付的不是普通应用代码，而是**多智能体流程正文与岗位人设**（skill 文档、组合配置、校验工具脚本）。一次看似局部的改动可能改变协作语义、编号释义或门禁强度，因此本仓对提交的**可解释性**与**可复跑验证**要求高于一般仓库：**没有验证方式的改动视为未完成**。

本文件是贡献者的唯一入口：环境准备 → 分支与提交 → PR 门禁与审查 → 发布。

| 想了解什么 | 去看 |
|---|---|
| 项目是什么、怎么安装与挂载 | `README.md` |
| 流程正文与硬规则（阶段、岗位、编号释义） | `skills/dsh-codepunk-workflow/SKILL.md` 及其 `references/` |
| 遇到问题怎么求助 | `SUPPORT.md` |
| 报告安全漏洞 | `SECURITY.md` |
| 社区行为规范 | `CODE_OF_CONDUCT.md` |
| 谁在决策、如何成为维护者 | `GOVERNANCE.md` |
| 版本与变更记录 | `CHANGELOG.md` |

---

## 1. 环境准备

### 1.1 运行时依赖

| 依赖 | 用途 | 备注 |
|---|---|---|
| bash | 运行 `plans/*.sh` 的全部工具与门禁 | macOS 3.2+ 与 Linux 均可；脚本内已做 BSD↔GNU 工具链自适应 |
| python3 | 一致性、兼容性、结构类校验器 | 只用标准库，不装第三方包 |
| node | `plans/*.mjs`（预设声明生成与校验、PowerShell 语法校验） | 只用标准库；语法校验的可选依赖 tree-sitter 见 README 的 PowerShell 校验一节 |
| pwsh | Windows 原生侧 `plans/windows/*.ps1` | PowerShell 7+；非 Windows 平台仅在校验 PS 脚本时需要 |
| git | 全部协作流程 | 部分判据依赖 `git ls-files`；在非 git 工作树下相应判据会明确报「无法核验」 |

缺依赖时本仓的口径是**无法核验 ≠ 通过**：相关判据以 `⚠` 显式列出并计入不一致，不会静默跳过，也不会被当作通过。

### 1.2 取得工作副本并跑一次基线

```bash
git clone https://github.com/webees/dsh-codepunk.git
cd dsh-codepunk
bash plans/verify-battery.sh      # 完整验证电池：首次进仓先确认基线为全绿
```

- 门禁默认以**当前工作目录的上一级**推断预设根，也可显式指定：`bash plans/verify-battery.sh [预设根]`。
- DSH 相关的可选判据由环境变量开启（`DSH_APP_ROOT` / `DSH_ASAR` / `DSH_PROFILE_PATCH`），未设时对应项按「无法核验」处理，不计为通过。
- 若你需要在 DSH 中**实际挂载**本预设（而不只是改文档），按 `README.md` 的快速开始执行三步：落位源文件 → `node plans/preset-declare.mjs apply` 注入 profile patch → `node plans/preset-declare.mjs check` 复核内联副本未漂移。预设声明在进程启动时读取，改动后须重启 DSH Desktop 生效。

### 1.3 可选工具（不影响门禁结论）

PowerShell 语法校验器需要额外依赖（约 17MB，仅本机工具目录，不随仓库分发）；缺失时对应判据**跳过并明确提示**，不判失败：

```bash
mkdir -p ~/.dsh-codepunk/tools && cd ~/.dsh-codepunk/tools
npm init -y && npm i tree-sitter tree-sitter-powershell
node ps-validate.mjs <预设根>/plans/windows/*.ps1
```

---

## 2. 分支模型

- `main` 是唯一长期分支且**受保护**：禁止直接推送、禁止强制推送（force push）、禁止删除。
- 一切改动先在**特性分支**上进行，前缀固定四类：

| 前缀 | 适用 | 示例 |
|---|---|---|
| `feat/` | 新增能力（岗位、阶段、门禁、工具） | `feat/doc-consistency` |
| `fix/` | 修复缺陷（含假绿、假红、静默空转） | `fix/leak-guard` |
| `docs/` | 仅文档（README、skill 正文、参考篇） | `docs/anti-loop` |
| `chore/` | 构建、脚本同步、仓库卫生、依赖 | `chore/gitignore` |

- 分支从**最新 `main`** 切出，保持短生命周期；合并后删除。
- 禁止在 `main` 上直接解决冲突：冲突在特性分支内合并最新 `main` 后解决。

---

## 3. 提交信息：Conventional Commits

```text
<type>(<scope>): <中文动宾式一句话>

<正文：改了什么、为什么改、影响面；验证方式（命令 + 观察到的结果）>
```

- `type` 取值：`feat` · `fix` · `docs` · `perf` · `test` · `chore`。
- `scope` 为受影响模块，例如 `windows` · `tools` · `skill` · `audit` · `score` · `config` · `stages` · `roles` · `write-scope`。
- **正文必须含验证方式**：跑了哪条命令、看到什么结果。只写「已测试」不算验证。
- 修复流程缺陷时，标题末尾附发现编号 `（Fnnn）`，与 `skills/dsh-codepunk-workflow/references/skill-governance.md` 的溯源表对齐。
- 标题与正文用中文；代码标识符、命令、路径保留英文原样。
- 一次提交只做一件事：不要把「顺手格式化」「顺手重命名」混进语义改动。

示例：

```text
fix(leak-guard): 禁词表存在但不可读时静默降为 0 条（假通过）

现象：禁词表权限异常时门禁仍报通过，私人词失去阻断能力。
改法：三态区分——不存在（正常）/ 可读（载入）/ 存在但不可读 ⇒ 响亮失败并返回 2。
验证：bash plans/dsh-codepunk-leak-guard.sh --tree 在只读禁词表下 rc=2 并输出处置建议；
      bash plans/verify-battery.sh 全绿（rc=0）。
```

---

## 4. 合并方式：一律 Pull Request + 合并提交

**唯一合法路径**：特性分支 → Pull Request → 审查通过 → **合并提交（merge commit，`git merge --no-ff`）** 并入 `main`。

- 仓库设置中**仅保留「Create a merge commit」**，关闭 `Squash and merge` 与 `Rebase and merge`——本仓需要保留分支拓扑，以便按工作轮次回溯「一次改动从哪来、和什么一起进来」。
- **禁止直接向 `main` 推送**（文档改动也不例外）；**禁止对 `main` 强制推送**。
- 合并前，特性分支必须已包含最新 `main`。
- 合并后删除远端特性分支。
- 唯一不经过 PR 的动作是**发布 tag** 的创建与推送（见第 6 节），且只有维护者可以做。

配套脚本把这条流程收成五个动作（`plans/git-merge-flow.sh`）：`start <分支名>`（从最新 `main` 建分支，脏工作区直接拒绝）、`commit "<type(scope): 摘要>"`（按 Conventional Commits 提交）、`pr <标题>`（推送并创建以 `main` 为基的 PR）、`merge <PR号>`（以合并提交落地，并断言分支顶端为合并提交）、`status`（当前分支 / 开着的 PR / `main` 合并提交数）。手工操作时请保持与脚本相同的顺序与断言。

---

## 5. PR 门禁与审查

本节即**提 PR 的门槛**：5.1 的**提交前检查清单**逐项通过，且 5.2 的门禁作业在 PR 上全绿，PR 才可进入合并流程。

### 5.1 提交前检查清单

PR 描述请按 `.github/pull_request_template.md` 逐项填写——该模板的核对清单与下面的自检项**同源**，模板更短，本节更全。以下命令均在仓库根执行。

- [ ] 全量门禁：`bash plans/verify-battery.sh` 退出码 0（一次跑完评分、审计、泄露门、结构、语法、端到端等全部验证）。合规运行产物（仓内 `tmp/`、`logs/`、`plans/__pycache__` 等 `.gitignore` 明示忽略者）只列 `ℹ` 信息行、**不判失败**；被忽略的**未登记**顶层路径仍判失败
- [ ] 预设审计：`bash plans/preset-audit.sh` 退出码 0（5 组 rubric 零失分）
- [ ] 指标评分：`bash plans/preset-score.sh` 退出码 0（15 指标全满分）
- [ ] 检查器存活自检：`bash plans/checker-self-test.sh` 退出码 0，且末行含「自检通过」（证明守护没有空转）
- [ ] 文档一致性：`bash plans/doc-consistency.sh` 退出码 0，且输出含「无硬性不一致」
- [ ] 写盘纪律：`bash plans/write-scope-check.sh --repo . --home --tmp` 退出码 0（无工程仓库残留、无主目录与临时目录散落）
- [ ] 无私人信息外泄：`bash plans/dsh-codepunk-leak-guard.sh --tree` 通过（禁词表留本地，见 `~/.dsh-codepunk/denylist.txt`）
- [ ] 变更与计数同步：命令、路径、目录结构、篇数、项数、分组数、硬规则上限等声称有变动时，同一提交内同步 `README.md`、`SKILL.md` 与 `references/` 对应处
- [ ] **新增顶层文件先登记入库白名单**：本仓 `.gitignore` 为默认拒绝（`*` 之后逐条 `!` 放行），未登记的顶层路径会**静默不入库**；提交前用 `git status` 与 `git check-ignore -v <路径>` 复核其确实可入库，并同步 `README.md` 的目录结构段（目录树与仓内跟踪文件不一致会被判失败）
- [ ] 平台对等：改了 `plans/windows/*.ps1` 就同步 `plans/*.sh`，反之亦然
- [ ] 编号可解析：`Pxx`、`D0xx` 引用只能来自 `skills/dsh-codepunk-workflow/references/standard.md` 的登记
- [ ] 变更范围最小：不含与本次目的无关的格式化、重命名、生成物
- [ ] 已在本地跑通上述命令并保留原始输出（PR 中贴关键片段，或说明获取方式）

### 5.2 CI 门禁

每个 PR 必须通过 `.github/workflows/ci.yml` 的四个作业，任一为红即不得合并：

| 作业 | 覆盖内容 | 等价本地命令 |
|---|---|---|
| `门禁回归` | 完整验证电池：评分、审计、格式与卫生、结构性检查、脚本语法、端到端 | `bash plans/verify-battery.sh` |
| `存活自检` | 变异测试：注入已知缺陷，断言对应守护必须报错 | `bash plans/checker-self-test.sh` |
| `跨平台可移植` | `plans/*.sh` 的**可执行代码**内 GNU/BSD 专有写法（无兜底即失败）、CRLF、TAB 缩进、可执行位；**不核验** sh↔ps1 平台对等（那是 5.1 的人工 MUST；ps1 语法校验在 `门禁回归` 的电池第 7 项） | 无单命令等价（判据内联在 `ci.yml` 的静态扫描步骤）；近似项见 `plans/preset-score.sh` 的 B10 跨平台性 |
| `文档一致性` | 文档「声称 ↔ 实现」逐类核对 | `bash plans/doc-consistency.sh` |

本地跑绿不等于 CI 必绿（环境差异、行尾策略、可选依赖都会造成差异）：**以 CI 结论为准**，CI 红时先在本地复现，再改代码或判据，不要重跑碰运气。

### 5.3 审查要求

- 每个 PR **至少一次**非作者的审查批准；自审不算审查。
- **所有审查会话必须解决**（Resolve conversation）后才可合并；未回复的意见视为未解决。
- 审查归属由 `.github/CODEOWNERS` 声明：被指派为 code owner 的路径，其改动**必须**由对应 owner 批准。
- 审查者的四个关注点：
  1. **语义是否真的变了**——有没有引入判据恒真、假绿、假红或静默空转；
  2. **有没有「无法核验却判通过」**——缺依赖、缺输入、缺权限时是否响亮失败；
  3. **声称与实现是否同步**——文档、脚本头注释、退出码契约三者一致；
  4. **是否引入污染**——工程工作树内的运行状态、临时脚本、私人信息。
- 涉及 `agent.cordis.yml`、`SKILL.md`、门禁脚本的改动，以及影响多文件的流程变更，须**独立审查**：审查者逐项核对 diff，而不是只看 PR 描述。

### 5.4 常见退回原因

| 现象 | 为什么退回 |
|---|---|
| 只改文档未同步实现（或反之） | 声称与实现漂移，文档一致性判据会红 |
| 新增判据但没有对应的变异用例 | 无法证明新守护真的会报警，存在空转风险 |
| 判据在缺依赖时「跳过即通过」 | 违反本仓「无法核验 ≠ 通过」的口径 |
| 只修一侧平台实现 | 破坏 sh ↔ ps1 对等 |
| 提交里混入本机绝对路径、邮箱、内网地址 | 泄露防护门命中并阻断 |
| 把私人词写进仓库内的守卫脚本 | 守卫自身成为泄露源；禁词必须留在本地 |

---

## 6. 发布流程（SemVer）

1. **定版本号**：遵循[语义化版本](https://semver.org/lang/zh-CN/)——破坏性变更升 MAJOR，向后兼容的新增升 MINOR，向后兼容的修复升 PATCH；`0.y.z` 阶段（1.0 之前）的破坏性变更按 SemVer 约定升 MINOR。
2. **落版本段**：在 `CHANGELOG.md` 中把 `## [Unreleased]` 改写为 `## [X.Y.Z] - <发布日期>`，并在文件顶部补回空的 `## [Unreleased]` 段。
3. **合并**：把该 CHANGELOG 改动以 PR 合入 `main`，确认门禁与 CI 全绿。
4. **打 tag**：由维护者创建带注解的 tag 并推送。
   ```bash
   git tag -a vX.Y.Z -m "vX.Y.Z"
   git push origin vX.Y.Z
   ```
5. **发布 Release**：在 GitHub Releases 用该 tag 发布，正文直接取 `CHANGELOG.md` 对应版本段，不另写一套发布说明（两套说明必然漂移）。
6. **收尾**：确认 `Unreleased` 段为空且存在，下一个 PR 继续在它下面累积。

**版本权威**：版本以 **git tag 与 `CHANGELOG.md`** 为唯一权威；`preset.yml` 只承载展示元数据（`name` / `description` / `order`），不含版本字段，因此不需要为一次发布改动它。

**发布权限**：只有维护者可以打 tag 与发布 Release（维护者的定义与产生方式见 `GOVERNANCE.md`）。非维护者可以准备发布 PR，但不能执行发布动作。

---

## 7. 开发命令速查

**统一入口是 `make <目标>`**（`make help` 列出全部目标）：`gates`（四道门禁＝文档一致性 + 预设审计 + 指标评分 + 泄露防护门）、`battery`（完整验证电池）、`selftest`（存活自检，约 350 秒）、`write-scope`（写盘纪律门）、`compat`（组合 ↔ DSH 安装兼容核验，需 `DSH_APP_ROOT` 或 `DSH_ASAR`）、`mirror`（把脚本同步到总库正式位）、`clean`（清理本仓运行根）。下面的手工命令与这些目标等价，用于定位单点失败。

以下命令均在**仓库根**执行。`plans/` 是工具脚本的源副本，运行期正式位是用户级总库 `~/.dsh-codepunk/scripts/`（由 `plans/dsh-codepunk-init.sh` 幂等同步）。

### 7.1 提交前必跑

| 命令 | 作用 | 通过判据 |
|---|---|---|
| `bash plans/verify-battery.sh` | 完整验证电池（评分 / 审计 / 泄露门三模式 / 格式与卫生 / 物理杂散 / 结构 / 语法与健壮性 / DSH 兼容 / 端到端 / 存活自检 / 文档一致性） | 退出码 0 |
| `bash plans/checker-self-test.sh` | 检查器存活自检：沙箱内注入已知缺陷，断言对应检查项必须报错 | 退出码 0（全部被捕获） |
| `bash plans/doc-consistency.sh` | 文档「声称 ↔ 实现」逐类核对（计数、阶段口径、工具存在性、退出码契约、表格结构等） | 退出码 0 |
| `bash plans/write-scope-check.sh` | 写盘纪律门：仓库残留 / 主目录散落 / 临时目录残留 | 退出码 0 |
| `bash plans/dsh-codepunk-leak-guard.sh --tree` | 泄露防护门（通用形态 + 本地禁词） | 退出码 0 |

### 7.2 按需工具

| 命令 | 何时跑 |
|---|---|
| `bash plans/preset-score.sh` | 关心 15 指标得分与失分明细时 |
| `bash plans/preset-audit.sh` | 关心 5 组 rubric 审计结论时 |
| `bash plans/evidence-verify.sh <evidence.yaml> <交付目录>` | 校验子代理交付证据（防假通过）时 |
| `bash plans/acceptance-verify.sh <acceptance.yaml> <交付方 task_id>` | 校验签收文件（含签收独立性）时 |
| `bash plans/verify-worktree.sh` | 校验工作房（worktree）落点纪律时 |
| `bash plans/dsh-codepunk-init.sh [--check]` | 初始化总库骨架 / 检查脚本副本是否过期时 |
| `source plans/dsh-codepunk-home.sh` | 在会话中载入共享路径常量时 |
| `bash plans/dsh-codepunk-link.sh resolve <工程根>` | 项目与总库关联解析时 |
| `bash plans/git-merge-flow.sh <子命令>` | 走「分支 → PR → 合并提交」的完整落地流时（需 `gh` 且已登录） |
| `node plans/preset-declare.mjs check` | 改过 `agent.cordis.yml` 后核对内联副本未漂移时 |
| `python3 plans/preset-compat.py` | 核对组合与当前 DSH 安装是否兼容时 |
| `python3 plans/fidelity-gate.py snapshot` 与 `verify` | 大改文档前存语义快照、改后逐项比对时 |
| `node plans/ps-validate.mjs <预设根>/plans/windows/*.ps1` | 无 pwsh 时校验 PowerShell 语法（需可选依赖）时 |
| `pwsh -File plans/windows/dsh-codepunk-init.ps1` | Windows 侧同步脚本到总库时 |

退出码约定两栈一致：`0` 通过 · `1` 质量失败 · `2` 环境或用法错误。POSIX 侧标记为 `✓` / `✗` / `ℹ`，Windows 侧刻意使用 ASCII 的 `v` / `x`（Windows 控制台编码差异所致），**请勿「顺手统一」**。

---

## 8. 维护公约（改动前必读）

1. **Host/Agent 平面边界**：服务注册（bash-sandbox、文件服务、goal 服务、任务注册表等 host 平面组件）不进本预设；需要 `isolate` realm 的行必须放在带 `isolate:` 的 group 内。
2. **逐岗 allow 白名单**：每岗 `toolFilter.allow` 收敛为单一 YAML 锚点（调研岗是唯一例外，内联追加联网工具）。allow 是「全关只放行」列表，未列入的工具一律不可见，且**只能列当前 DSH 实例已挂载的全局工具名**；`report` 是子代理注册在自身层的汇报工具，切勿列入 allow。
3. **编号可解析**：`Pxx` / `D0xx` 一律以 `skills/dsh-codepunk-workflow/references/standard.md` 为唯一释义；新增编号先登记再引用，禁止引入该文件之外的外部编号。
4. **文件归宿**：关于预设自身的调研、基准与优化资料只写入 `skills/dsh-codepunk-workflow/benchmarks/`，绝不写进任何工程目录；接收外部产出时核对「内容归属域」与「实际落位」一致，错位立即移出并核销引用。

**平台对等（MUST）**：`plans/*.sh`（POSIX）与 `plans/windows/*.ps1`（Windows）是同一套工具的两份实现。改动任一侧必须同步另一侧的**同等语义**——命令名、参数、退出码、输出格式一致——且两侧都要过语法校验。

---

## 9. 文件主责与新增文件的前置动作

**文件与目录清单的唯一权威在 `README.md` 的「目录结构」段**：本文件不复述清单，只声明主责归属与新增文件必须附带的前置动作。

| 内容类别 | 载体 | 主责 | 变更附带动作 |
|---|---|---|---|
| 使用说明与概览 | `README.md` | 维护者 | 目录结构段与计数声称须在同一提交内同步 |
| 贡献者公约 | `CONTRIBUTING.md` | 维护者 | 与文档政策、开发指南保持一致，不复述目录清单 |
| 治理与社区健康 | `CODE_OF_CONDUCT.md`、`SECURITY.md`、`SUPPORT.md`、`GOVERNANCE.md` | 维护者 | 改变决策程序或披露口径时同步 `CHANGELOG.md` |
| 版本记录 | `CHANGELOG.md` | 发布者 | 发布时把 `Unreleased` 段落为版本段 |
| 专题文档与决策记录 | `docs/`、`docs/adr/` | 维护者 | 新增决策记录按 `GOVERNANCE.md` 的 ADR 约定 |
| 流程正文与按需细则 | `SKILL.md`、`references/` | 维护者 | 新增编号先在 `references/standard.md` 登记 |
| 工具脚本与平台实现 | `plans/`、`plans/windows/` | 维护者 | 两侧语义同步，并同步到总库正式位（`plans/dsh-codepunk-init.sh`） |
| 协作模板与 CI | `.github/` | 维护者 | 状态检查名变更须同步生成脚本 `plans/github-setup.sh` |

**新增顶层文件或目录的前置动作（缺一不可）**：

1. 在 `.gitignore` 白名单放行——本仓为默认拒绝式忽略，未登记的顶层路径会**静默不入库**；
2. 在 `README.md` 的「目录结构」段登记——`plans/verify-battery.sh` 会比对目录树与仓内跟踪文件，**死条目与漏列都判失败**；
3. 在 PR 描述中说明该文件或目录的归属层级（流程正文 / 按需细则 / 专题文档 / 公约），避免同一内容出现两处权威。

---

## 10. 许可与贡献授权

本仓以 **MIT** 许可发布，全文见 `LICENSE`。**提交即表示你同意以 MIT 许可发布你的贡献**，并确认你有权这样做（若贡献是在雇佣关系中完成，请确认已获得授权）。

若你的贡献引入第三方内容（脚本、文档片段、基准数据、代码片段），必须在 PR 描述中说明来源与许可，且不得与本仓的 MIT 许可冲突。无法确认许可来源的内容一律不收。
