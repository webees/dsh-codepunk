# dsh-codepunk

**运行于 DeepSeek Harness 的多智能体开发流程预设**——主会话担任工程主责并编排岗位子代理，把工程从需求推进到交付：**六阶段闭环、证据驱动、可审计、可恢复、持续进化**。

[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![DeepSeek Harness](https://img.shields.io/badge/DeepSeek%20Harness-2.0.17-blue.svg)](skills/dsh-codepunk-workflow/references/harness-alignment.md)
[![Gates](https://img.shields.io/badge/quality%20gates-doc--consistency%20rc%3D0%20%C2%B7%20score%2015%2F15-brightgreen.svg)](plans/verify-battery.sh)
[![Merge flow](https://img.shields.io/badge/merge%20flow-PR%20%2B%20merge%20commit%20%C2%B7%20no%20direct%20push-blueviolet.svg)](CONTRIBUTING.md)

## 目录

- [定位](#定位)
- [不适合什么](#不适合什么)
- [快速开始](#快速开始)
- [流程总览（六阶段闭环）](#流程总览六阶段闭环)
- [核心机制](#核心机制)
- [质量门禁与自检](#质量门禁与自检)
- [平台支持](#平台支持)
- [目录结构](#目录结构)
- [文档索引](#文档索引)
- [参与共建](#参与共建)
- [许可与安全](#许可与安全)

---

## 定位

**dsh-codepunk** 是一套「把 AI 开发过程机械化」的多智能体流程预设：主会话是**工程主责（run-lead）· 技术统筹（tpm）· 会话调度（sess-mgr）**，它不联网、不写业务代码，而是派出固定岗位的**子代理**，以公文驱动（简报 → 交接包 → 证据 → 签收）推进工程。

适合的场景：

1. **需求到交付要留痕的工程**：每个 chunk 走「规划 → 招聘 → 并行开发 → 审查门 → 交接签收 → 合并门」，每一步都有可机械核验的产物。
2. **多任务可并行、又需要隔离**：每个 task 一个三人小组，在独立封闭工作房推进，互相不污染。
3. **长时间、跨会话的推进**：goal 自动续行让子代理回报自动递送主管，断点可恢复，客户端重启不丢进度。
4. **要持续变好的流程**：评分与知识库跨组沉淀，下一轮按硬信号重新招聘与规划。
5. **想参照一套已落地的多智能体工程规范**：硬规则、检查器矩阵、防幻觉与反循环纪律都在仓内可读。

角色一览（完整人设与写域见 [references/roles.md](skills/dsh-codepunk-workflow/references/roles.md)）：

| 席层 | 岗位 | 说明 |
|---|---|---|
| 主会话 | 工程主责 run-lead · 技术统筹 tpm · 会话调度 sess-mgr | 编排、门禁、终裁；不联网、不写业务码 |
| 实现三角 | 小队主责 squad-lead · 软件开发 engineer · 测试验证 sdet | 每 task 一组，真招聘，独立工作房并行 |
| 职能岗 | 产品策划 · 行业分析（唯一联网）· 软件架构 · 代码勘察 · 人才主责 · 文档主责 · 知识库 | 需求澄清、分块、招聘、简报与归档 |
| 门禁岗 | 代码审查 code-review · 发布执行 release-eng · 流程审计 proc-audit | 审查门、合并门、红灯上报 |

## 不适合什么

1. **不适合当一键脚手架**：它编排的是「流程与席位」，不是某个技术栈的代码模板；业务代码由你的工程仓库承担。
2. **不适合单点小改**：改一行文案、修一个错别字，直接改更快——本流程的门禁与证据成本高于收益。
3. **不适合无人监督的高风险操作**：破坏性操作、预算越界走人在环熔断；生产发布与密钥管理不在本预设职责内。
4. **不适合需要沙箱安全的场景**：画布工具权限是机械强制的（`restrict` 真移除工具），但**文件写集是约定强制**（人设自律 + 审查门 `diff ⊆ write_paths` + 工作房隔离），不是安全沙箱。
5. **不适合把它当作官方产品**：本预设是社区流程方案，随 DeepSeek Harness 版本演进，兼容性以仓库内实测记录为准。

## 快速开始

前置：DeepSeek Harness（本仓实测应用版本 2.0.17，兼容核验见 [references/harness-alignment.md](skills/dsh-codepunk-workflow/references/harness-alignment.md)）；macOS 或 Linux 用 bash 工具链，Windows 用 pwsh（见「平台支持」）。

**第一步：把预设源文件落位**（唯一权威副本；完整安装说明见 [docs/deployment.md](docs/deployment.md)）：

```bash
mkdir -p "$HOME/.dsh/.agent-presets/dsh-codepunk" && cp -R agent.cordis.yml preset.yml skills "$HOME/.dsh/.agent-presets/dsh-codepunk/"
```

**第二步：生成 preset 声明并注入 profile patch**（DeepSeek Harness 自 0.1.7 起不再扫描 `~/.dsh/.agent-presets/<id>/`，必须以声明行注入，否则会话恢复时报 `Unknown agent preset: dsh-codepunk`）：

```bash
# 首次安装追加声明块（自动备份）；已安装过改用不带 --append 的 apply
DSH_PROFILE_PATCH=~/.dsh/profiles/desktop/cordis.patch.yml node plans/preset-declare.mjs apply --append
node plans/preset-declare.mjs check   # 校验内联副本未漂移（漂移即非零退出并列出差异）
```

声明在**进程启动时读取**，改动后需重启 DeepSeek Harness 生效。

**第三步：同步工具脚本到总库正式位**（运行期执行的是总库副本，升级预设后必做）：

```bash
bash plans/dsh-codepunk-init.sh          # 幂等：同步到 ~/.dsh-codepunk/scripts/
bash plans/dsh-codepunk-init.sh --check  # 只检查缺失/过期，不写盘
```

**第四步：注册工程并装载总库路径常量**：

```bash
dsh-codepunk-link register <工程根> <project_id>   # 首次：登记工程 ↔ 总库项目
dsh-codepunk-link resolve <工程根>                 # 之后：解析出 project_id 与总库托管路径
source ~/.dsh-codepunk/dsh-codepunk-home.sh        # 导出 DSH_CODEPUNK_HOME / PROJECTS / INDEX
```

**第五步：开工**——主会话加载 `dsh-codepunk-workflow` skill 后逐阶段推进。开工五件事（每次新 run 或新会话都必须做，细则见 `skills/dsh-codepunk-workflow/references/stages.md`）：

1. **关联项目**：`dsh-codepunk-link resolve <工程根路径>`；未注册先 `register`。
2. **装载路径常量**：`source ~/.dsh-codepunk/dsh-codepunk-home.sh`。
3. **建运行根**：在总库内建 `projects/<project_id>/runs/<run_id>/`；**工程目录保持纯净**（运行状态一律不落工程仓库）。运行根 `README.md` 必带 `write_scope:` 写盘台账段。
4. **启动自检与子代理恢复**：列出可续聊子代理，与 spawn 登记表逐行比对，找出中断席并读断点续行（不重跑整轮）。
5. **定时巡检与状态清单**：按「查 → 比 → 续 → 写」闭环刷新 `agents.yaml`，防中断席长期失联。

自证环境（三条命令应全绿，退出码契约见下表）：

```bash
bash plans/preset-score.sh        # 15 指标评分：期望 15/15 全满分
bash plans/preset-audit.sh        # 5 组 rubric 审计：期望 总分 100/100
bash plans/verify-battery.sh      # 完整验证电池：单命令复跑全部验证
```

---

## 流程总览（六阶段闭环）

| # | 阶段 | 工作 | 关键产物 |
|---|---|---|---|
| 1️⃣ | **需求确认** | 工程主责主持对话，产品策划澄清口径，行业分析实时检索；与用户逐项确认后置 active | `goal.yaml`（用户确认后 active） |
| 2️⃣ | **规划与组队** | 分块 → 文档小组组装简报 → 人才主责真招聘三人小组 → **双门闩**批准后开工 | `chunks.yaml` · `brief/` · `staffing/` |
| 3️⃣ | **多小组并行开发** | 每 task 一组三人小组，在独立封闭工作房并行推进；并行上限 S≤1 / M≤3 / L≤6 | 各工作房交付 · `progress/` |
| 4️⃣ | **巡检与交接** | 小队主责组织闭环；证据门 → 代码审查门（`diff ⊆ write_paths`）→ 交接包齐全 → 接收方签收 | `reviews/` · `handoff/` · `acceptance.yaml` |
| 5️⃣ | **解散与评分** | 签收后各组就地解散，按 evidence/status/handoff/ack/retries 等硬信号评分沉淀；**后段为串行合并门** | `scores.yaml` · `approvals/merge.yaml` |
| 6️⃣ | **再规划** | 综合各组成果、评分与知识库，修订招聘标准与提示词 → 重新招聘 → 执行 | 新一轮 `chunks.yaml` |

```mermaid
flowchart LR
  A["① 需求确认"] --> B["② 规划与组队"]
  B --> C["③ 并行开发"]
  C --> D["④ 巡检与交接"]
  D --> E["⑤ 解散与评分"]
  E --> F["⑤ 后段·合并门"]
  F --> G["⑥ 再规划"]
  G --> B
```

阶段逐步动作（派遣对象、产物字段、门禁细节）见 `skills/dsh-codepunk-workflow/references/stages.md`；产物字段见 [references/artifacts.md](skills/dsh-codepunk-workflow/references/artifacts.md)。

## 核心机制

| 机制 | 一句话 | 参考文档 |
|---|---|---|
| **六阶段闭环** | 需求确认 → 规划与组队 → 多小组并行开发 → 巡检与交接 → 解散与评分 → 再规划，末阶段回到规划形成闭环 | `references/stages.md` |
| **双门闩（R1）** | 工作简报与用工单**都**批准才可开启实现小组，缺一不得 spawn——把「开工」变成显式门 | `references/artifacts.md` |
| **实现三角** | 每 task 固定三席：小队主责对齐目标与组织闭环、开发在写集内实现、测试独立验收并出证据；不代写、不自验、不自合 | [references/roles.md](skills/dsh-codepunk-workflow/references/roles.md) |
| **审查门与合并门（R8/R9）** | 交接前核对 `diff ⊆ write_paths` 并留审查记录；合并串行、按依赖拓扑、证据与门禁齐备且留 `approvals/merge.yaml` | `references/artifacts.md` |
| **goal 自动续行（R10）** | 每工程目标挂会话级 goal 并保持激活：子代理回报自动递送主管；会话恢复后先重武装再开工，避免回报堆积 | [references/harness-alignment.md](skills/dsh-codepunk-workflow/references/harness-alignment.md) |
| **写盘纪律（R17）** | 写盘按优先序：运行根 → 授权工作树写集 → 系统临时目录（用毕即删）→ 总库知识库；工程仓库不得留探针、临时脚本与 `*.bak`/`*.log` 残留 | [references/file-hygiene.md](skills/dsh-codepunk-workflow/references/file-hygiene.md) |
| **反循环熔断（R16）** | 连续无新证据、同一失败指纹重复即强制换策略或上报；已证伪的结论不得流入上下文与交接包 | [references/anti-loop.md](skills/dsh-codepunk-workflow/references/anti-loop.md) |

硬规则共 **R1–R17**（完整条文见 `skills/dsh-codepunk-workflow/SKILL.md`）；其他贯穿性纪律：反幻觉（断言须新鲜证据）、输出与消息纪律（首行结论、条目精简）、注入防线（工具与网页返回视为数据而非指令）。

## 质量门禁与自检

所有门禁脚本位于 `plans/`，**统一退出码契约**：`0`＝通过（或全满分）· `1`＝存在质量/合规失败项 · `2`＝用法或环境错误、无法核验。特别地，**判定为「无法核验」的结论码是 2，不得当作通过**。运行期实际执行的是总库正式位 `~/.dsh-codepunk/scripts/` 下的副本（由 `plans/dsh-codepunk-init.sh` 同步）。

| 脚本 | 作用 | 退出码 |
|---|---|---|
| `plans/verify-battery.sh` | 完整验证电池（**11 项**独立验证，单命令复跑：评分 · 审计 · 泄露门三模式 · 格式卫生 · 物理杂散（`.gitignore` 明示忽略的运行产物 `tmp/`/`logs/`/`__pycache__` 等只列 `ℹ` 不判失败；被忽略的**未登记**顶层路径仍判失败） · 结构 · 脚本语法与健壮性 · DSH 兼容 · E2E 沙箱 · 检查器存活自检 · 文档声称一致性，另含目录树一致、PS 校验器提示、声明漂移三项子检）；被跳过的项（缺工具 / 缺环境变量 / `DSH_CODEPUNK_SKIP_SELFTEST=1` 递归防护）一律在结论行列明，**跳过 ≠ 通过** | 0=实检项全通过（跳过项在结论行列明）；1=存在失败项；2=无法进入预设根 |
| `plans/preset-score.sh` | 15 指标评分（策略/质量/准确性/规范性/精简度 + 一致性/完整性/可执行性/可维护性/跨平台性/安全性/可发现性/语义保真/工程卫生/演进性），每项独立 100 分门槛 | 0=15 项全满分；1=存在未满分项；2=环境或用法错误 |
| `plans/preset-audit.sh` | 5 组 rubric 审计（配置/手册/调研/文档/工具层；否决式计分：零失分即满分）；YAML 解析优先 ruby，无 ruby 时用 node+js-yaml（候选链查找、容忍 `!!js` 标签）；D3/E3 在 `git` 枚举为空时回退文件系统遍历（空枚举不得判满分） | 0=全项达标；1=存在失分项；2=预设根不存在 |
| `plans/doc-consistency.sh` | 文档「声称 ↔ 实现」一致性核对（27 类：计数声称 · 阶段口径 · 工具存在性 · 退出码契约 · 编号可解析 · 章节引用 · 退出码实测 · 表格列数 · 制品生成器一致 · 外部输入变量记载等） | 0=一致；1=存在不一致；2=环境或用法错误 |
| `plans/checker-self-test.sh` | 检查器存活自检（变异测试）：沙箱副本内注入 **186 项**已知缺陷，断言对应检查项必须报错——专治「守护空转」 | 0=通过（结论行据实报「捕获 N/M 项 + 跳过 K 项（跳过 ≠ 通过）」）；1=有守护未捕获；2=环境或自检问题 |
| `plans/preset-declare.mjs` | preset 声明块生成与校验（`emit` / `check` / `apply`；源 `agent.cordis.yml` ↔ profile patch 内联副本语义比对） | 0=一致或成功；1=确认漂移；2=环境或参数错误 |
| `plans/preset-compat.py` | 组合与当前 DeepSeek Harness 安装的兼容核验（插件包存在 · 配置键被接受 · group 隔离与锚点顺序 · allow 名单一致性） | 0=兼容；1=存在不兼容项；2=无法定位 DSH 安装 |
| `plans/evidence-verify.sh <evidence.yaml> [交付目录]` | 证据机械校验（防假通过门）：`task_id` · `command` · `exit_code=0` · `log_ref` 齐备且位于交付目录内（绝对路径与 `..`/符号链接逃逸判 FAIL）+ 证据 `id` 去重 + 时间序（`validated_at` 须晚于交付目录 mtime） | 0=通过（verdict=PASS）；1=未过；2=用法或文件缺失 |
| `plans/acceptance-verify.sh <acceptance.yaml> <交付方 task_id>` | 签收机械校验：`task_id` · `accepted_by[]` · `accepted_at` 齐备 + 签收独立性（自签一律不合规，**比较不区分大小写**；缺交付方 ⇒ 无法核验 ≠ 通过） | 0=合规；1=不合规；2=用法或文件缺失、或未提供交付方 |
| `plans/write-scope-check.sh [--repo <路径>] [--home] [--tmp] [--home-all] [--run-root <运行根>]` | 写盘纪律门：仓库残留（含未跟踪文件）· 主目录顶层散落 · 临时目录双根残留；`--exempt-from` 读运行根豁免登记；`--run-root` 核验运行根 README 的 `write_scope:` 台账段（5 键 + `cleanup_status ∈ {clean,pending}`，交接门与合并门的前置读数）；扫描工具缺失（PATH 无 `find`）⇒ 显式失败，不静默通过 | 0=通过；1=发现越界或台账不合规；2=无法核验或用法错误（含缺 `find`、`--run-root` 目录或 README 缺失） |
| `plans/patrol-check.sh --run-root <运行根> [--ledger <台账>] [--max-gap N]` | 巡检名册字段契约门：运行根 `agents.yaml` 的 `patrol_log` 逐条核验——`round`/`at`/`note` 齐备（字段缺失或值为空即报）· `round` 唯一且为整数 · 给 `--ledger` 时每个巡检轮次在台账中有对应行 · 升序排序后相邻轮次间隔 ≤ `--max-gap`（默认 5）。行级解析，不依赖 YAML 库 | 0=全部合规；1=发现契约违规（逐条列出条目与原因）；2=用法或环境错误（缺 `--run-root`、运行根或 `agents.yaml` 不存在、缺必需工具） |
| `plans/hook-write-scope.py`（钩子执行体；配置 `plans/hooks/hooks.json`，条目 `hooks-write-scope`） | **写盘护栏拦截层**（PreToolUse 命令钩子，本预设已声明）：`write`/`edit` 取 `file_path`、`bash`/`pwsh` 按命令文本启发式抽取写入目标；默认 `deny` 黑名单阻断（系统路径 / 凭据目录 / `~/.dsh/profiles/**` / 主目录顶层散落文件），`DSH_CODEPUNK_HOOK_MODE=strict` 为白名单放行（预设仓库根 / `~/.dsh-codepunk/**` / `${TMPDIR}` 与 `/tmp` / 会话 cwd）；启发式拦网、非沙箱，与 `write-scope-check.sh` 并列 | 0=放行（含无法判定目标）；2=阻断（stderr 即理由，回给模型）；**脚本异常退出 / 解释器缺失 / 超时 / 配置坏掉 ⇒ 产品不设 decision ⇒ 同样放行（失败开放，F369）**，故本层是尽力而为、MUST 与事后机械门 `write-scope-check.sh` 并列 |
| `plans/dsh-codepunk-leak-guard.sh --tree` | 泄露防护门：禁词与敏感形态留在本地，推送前守卫；`--install-hook` 安装 pre-commit · pre-push · commit-msg 钩子；三种模式均自证 `git` 可用且**真的扫到了文件**（零扫描不判「通过」） | 0=通过（报告「已扫描 N 个跟踪文件」）；1=命中并阻断；2=用法或环境错误、**无法核验**（含 `git` 行为异常、tree 模式扫描零文件） |
| `plans/fidelity-gate.py snapshot` / `verify` | 语义保护闸：改文件前存快照、改后逐项比对（**14 类**：编号 · 约束词 · 阈值 · 路径 · 工具名 · 代码标识 · 文件名 · 全大写常量 · URL · 证据标记 · 日期等），防压缩丢语义 | 0=零丢失；1=检出丢失；2=缺参数或未知模式、无快照 |
| `plans/verify-worktree.sh [主仓库路径] [--quiet]`（散落根解析顺序：`SCAN_ROOT` > `DSH_CODEPUNK_WORKTREES`（总库 `worktrees/`，即文档化落点）> `DESKTOP` > 桌面候选；全部不存在则跳过该项扫描并 WARN。仅与本主仓库共享 git 目录的散落 worktree 判失败，散落根内其它 git 仓库只报 INFO） | 工作房（worktree）落点纪律核验：散落目录与登记残留对照，给回收建议 | 0=全部通过；1=存在失败项；2=用法或环境错误 |
| `plans/github-setup.sh [--dry-run] [--repo <owner/name>]` | GitHub 仓库治理幂等应用（仓库元数据、合并方式与 `main` 分支保护） | 0=全部应用并校验通过；1=未完全应用或校验不符；2=环境或用法错误 |
| `plans/git-merge-flow.sh` | 特性分支流程助手（建分支 → 提交 → 推送 → 开 PR → 合并提交 → 删分支，合并方式固定为 merge commit） | 0=成功；1=业务前置不满足；2=用法或环境错误 |

补充说明：

1. `bash plans/verify-battery.sh [预设根]` 一次跑完 14 项独立验证（11 主检 + 3 子检），根参数默认取脚本上级目录；DSH 相关可选检查由环境变量开启：`DSH_APP_ROOT`（解包 app 目录）、`DSH_ASAR`（旧 asar 路径）、`DSH_PROFILE_PATCH`（profile patch 路径）。
2. **无法核验 ≠ 通过**：环境缺口（缺校验器、非 git 工作区等）会以 `⚠`／`ℹ` 显式标注，绝不静默变绿。
3. 门禁脚本自身也被检查：`checker-self-test.sh` 用变异注入验证「检查项真的会失败」，避免守护空转。

### PowerShell 校验（可选）

`preset-score.sh` 与 `verify-battery.sh` 的 PowerShell 语法项需要校验器，缺失时跳过并明确提示（不判失败）。启用方式（约 17MB，仅本机工具目录，不随仓库分发）：

```bash
mkdir -p ~/.dsh-codepunk/tools && cd ~/.dsh-codepunk/tools
npm init -y && npm i tree-sitter tree-sitter-powershell
node ps-validate.mjs <预设根>/plans/windows/*.ps1   # 校验器本体在 plans/ps-validate.mjs
```

也可用环境变量指向自备实现：`PWSH_VALIDATOR=/path/to/validate.mjs`。

## 平台支持

| 平台 | Agent shell | 工具脚本 | 说明 |
|---|---|---|---|
| macOS | bash | `plans/*.sh` | 开箱可用（bash 3.2+ 与 BSD 工具链） |
| Linux | bash | `plans/*.sh` | 可用（GNU 工具链；脚本内已做 BSD/GNU 自适应） |
| Windows | pwsh | `plans/windows/*.ps1` | 预设在该平台禁用 bash 工具、启用 pwsh 工具；从仓内跑一次初始化脚本即把 `.ps1` 同步到总库 |

两套实现语义等价（关联解析三态路由、索引字段约定、退出码一致）。Windows 侧当前覆盖**总库初始化 · 工程关联 · 泄露防护门 · 路径常量**四个核心脚本，其余核验类脚本经 Git Bash 或 WSL 调用。

输出标记约定：Windows 侧刻意以 ASCII `v` / `x` 代替 POSIX 侧的 `✓` / `✗`，以减少控制台编码差异带来的风险，**请勿顺手统一**；退出码约定两栈一致。换行策略见 `.gitattributes`：仓库内统一 LF，`.ps1` 检出为 CRLF。

## 目录结构

```text
.github/                            # 协作模板与 CI 配置（issue 模板、PR 模板、工作流）
  ISSUE_TEMPLATE/
    bug_report.yml
    config.yml
    feature_request.yml
  workflows/
    ci.yml
    codeql.yml
    dependabot-auto-merge.yml
    release.yml
    scorecard.yml
  CODEOWNERS
  dependabot.yml
  pull_request_template.md
  release_note_template.md
docs/                               # 面向使用者的专题文档（见「文档索引」）
  adr/
    0001-record-architecture-decisions.md
  architecture.md
  deployment.md
  development.md
  documentation-policy.md
  faq.md
  licensing.md
  maintenance.md
  naming-conventions.md
plans/                              # 工具脚本源副本（运行期正式位在总库 scripts/）
  hooks/                            # 拦截层钩子配置（Claude Code 兼容；由 hooks 桥读取）
    hooks.json                      # PreToolUse 钩子：write/edit/bash/pwsh → 写盘护栏脚本
  windows/                          # Windows 原生（PowerShell）等价实现
    dsh-codepunk-home.ps1           # 共享路径常量（点源载入）
    dsh-codepunk-init.ps1           # 总库骨架与脚本同步
    dsh-codepunk-leak-guard.ps1     # 泄露防护门
    dsh-codepunk-link.ps1           # 工程与总库关联解析
  acceptance-verify.sh              # 签收机械校验器
  checker-self-test.sh              # 检查器存活自检（变异测试）
  doc-consistency.sh                # 文档声称与实现一致性核对
  dsh-codepunk-home.sh              # 共享路径常量（source 载入）
  dsh-codepunk-init.sh              # 总库骨架幂等初始化与脚本同步
  dsh-codepunk-leak-guard.sh        # 泄露防护门（推送前守卫）
  dsh-codepunk-link.sh              # 工程与总库关联解析
  evidence-verify.sh                # 证据机械校验器
  fidelity-gate.py                  # 语义保护闸（快照与比对）
  git-merge-flow.sh                 # 特性分支流程助手（分支到合并提交）
  github-setup.sh                   # GitHub 仓库治理幂等应用
  hook-write-scope.py               # 写盘护栏钩子（PreToolUse：deny/strict 两模式）
  patrol-check.sh                   # 巡检名册字段契约门（运行根 agents.yaml 的 patrol_log）
  preset-audit.sh                   # 5 组 rubric 质量审计
  preset-compat.py                  # 组合与 DSH 安装兼容核验
  preset-declare.mjs                # preset 声明块生成与校验
  preset-score.sh                   # 15 指标评分器
  ps-validate.mjs                   # PowerShell 语法校验器（可选依赖）
  verify-battery.sh                 # 完整验证电池：单命令复跑全部验证
  verify-worktree.sh                # 工作房落点纪律核验
  write-scope-check.sh              # 写盘纪律门
skills/
  dsh-codepunk-workflow/            # 流程 playbook（skill）
    SKILL.md                        # 流程权威正文（六阶段 + 硬规则 R1–R17）
.editorconfig
.gitattributes                      # 换行策略：仓库内 LF，.ps1 检出 CRLF
.gitignore                          # 白名单式忽略（运行状态一律不入仓）
.pre-commit-config.yaml
agent.cordis.yml                    # 组合：persona + 工具 + realm（预设的权威定义）
CHANGELOG.md
CODE_OF_CONDUCT.md
CONTRIBUTING.md                     # 贡献指南（面向贡献者）
GOVERNANCE.md
LICENSE                             # 许可（MIT）
Makefile
preset.yml                          # 预设描述（名册展示用元数据）
README.md                           # 本说明（面向使用者）
SECURITY.md
SUPPORT.md
```

按需层（随工艺增长，见 `skills/dsh-codepunk-workflow/`）：

```text
  benchmarks/                       # 基准调研 19 篇（决策依据与实战取证）
  references/                       # 按需参考 19 篇（岗位、产物、阶段、纪律、兼容）
```

用户级总库 `~/.dsh-codepunk/`：`INDEX.yaml`（工程注册表）、`dsh-codepunk-home.sh`（路径常量）、`scripts/`（运行期脚本正式位）、`projects/<id>/`（各工程全部 run 记忆与知识库）。**工程目录始终保持纯净**——运行状态、记忆与知识库全在总库内。

## 文档索引

仓库内文档按三层组织：**首页**（本文件）、**专题文档**（`docs/`）、**流程参考**（`skills/dsh-codepunk-workflow/references/`）。

| 文档 | 面向 | 内容 |
|---|---|---|
| `README.md` | 使用者 | 定位、快速开始、机制概览、门禁、目录与索引 |
| `CONTRIBUTING.md` | 贡献者 | 维护公约、提 PR 门槛、提交信息约定、提交前检查清单 |
| `SECURITY.md` | 使用者与安全研究者 | 漏洞报告渠道、支持范围、披露流程 |
| `CHANGELOG.md` | 使用者 | 版本演进与破坏性变更记录 |
| `docs/` 专题文档（9 篇） | 使用者 | `architecture.md`（六阶段与门禁的架构说明）· `deployment.md`（安装、部署与升级）· `development.md`（开发环境与改码流程）· `documentation-policy.md`（文档规范与机械门覆盖）· `faq.md`（常见问题与排障）· `maintenance.md`（日常维护与兼容核验）· `naming-conventions.md`（命名约定）· `licensing.md`（许可与公开性）· `adr/0001-record-architecture-decisions.md`（架构决策记录） |
| `skills/dsh-codepunk-workflow/SKILL.md` | 主会话（工程主责） | 流程权威正文：六阶段步骤与硬规则全文 |
| `skills/dsh-codepunk-workflow/references/` | 主会话与岗位席 | 按需参考手册：`stages.md` · `roles.md` · `artifacts.md` · `knowledge.md` · `standard.md`（编号释义）· `file-hygiene.md` · `anti-loop.md` · `output-discipline.md` · `harness-alignment.md` · `skill-governance.md` 等 |
| `skills/dsh-codepunk-workflow/benchmarks/` | 维护者 | 决策号来源与外部基准调研（含检索日与出处） |

## 参与共建

流程：**特性分支 → Pull Request → 合并提交（merge commit）**。`main` 受保护，**不接受直接推送**；每处改动都要在 PR 描述或提交信息里说明目的、影响面与验证方式。

1. 从 `main` 切出特性分支，例如 `git switch -c feat/your-topic`。
2. 按 `CONTRIBUTING.md` 的**维护公约要点**改动，重点是**平台对等（MUST）**：`plans/*.sh` 与 `plans/windows/*.ps1` 是同一套工具的两份实现，改动任一侧必须同步另一侧同等语义（命令名、参数、退出码、输出格式一致）。
3. 提交前逐项过**提交前检查清单**，并本地跑一遍门禁：`bash plans/verify-battery.sh`（或至少 `bash plans/doc-consistency.sh` 与 `bash plans/preset-score.sh`）。
4. 提交信息沿用仓内约定的 Conventional-Commits 风格、**正文用中文**，并写清验证命令与结果。
5. 开 PR：描述里给出改动目的、影响面、验证证据；CI 与审查通过后以**合并提交**并入 `main`（保留完整历史，便于追溯）。
6. 涉及行为变更时同步更新 `README.md` 与 `CHANGELOG.md`——文档与实现的一致性由 `plans/doc-consistency.sh` 机械核验。

完整门槛与清单见 [CONTRIBUTING.md](CONTRIBUTING.md)。

## 许可与安全

- **许可**：MIT，见 [LICENSE](LICENSE)。
- **安全**：漏洞报告渠道与披露流程见 `SECURITY.md`；本仓自身的泄露防护门为 `plans/dsh-codepunk-leak-guard.sh`（禁词与敏感形态留在本地，推送前阻断）。
- **变更日志**：版本演进与破坏性变更见 `CHANGELOG.md`。
- **兼容性声明**：本预设随 DeepSeek Harness 演进；应用版本兼容核验与破坏性变更适配记录见 `skills/dsh-codepunk-workflow/references/harness-alignment.md`。

## 维护公约（改动前必读）

1. **Host / Agent 平面边界**：服务注册不进本预设；需要 `isolate` realm 的行必须放在带 `isolate:` 的 group 内。
2. **逐岗 allow 白名单锚点**：每岗 `toolFilter.allow` 收敛为单一 YAML 锚点（调研岗唯一例外，内联追加检索工具）。allow 是「全关只放行」列表，未列入的工具一律不可见；新增岗位或工具须同步锚点，且只能列当前实例已挂载的全局工具名。
3. **强制层级要分清**：画布工具权限是机械强制（`restrict` 真移除工具）；文件写集是**约定强制为主**（人设自律 + 审查门 `diff ⊆ write_paths` + 工作房隔离），另有**拦截层**机械拦网 `plans/hook-write-scope.py`（PreToolUse 钩子，启发式、非沙箱，见 `references/file-hygiene.md` §八）与**事后**扫描门 `plans/write-scope-check.sh`；两者都不等价于沙箱。
4. **编号可解析**：内部编号一律以 `skills/dsh-codepunk-workflow/references/standard.md` 为唯一释义，禁止引入该文件之外的编号引用。
5. **文件归宿**：预设自身的资料（开源基准、流程改进）存 `skills/dsh-codepunk-workflow/benchmarks/`，绝不写入任何工程目录；各 run 的 `research/briefs/` 只放该工程业务调研。接收子代理产出时复核归属域与实际落位一致。
6. **官方版本漂移监控**：DeepSeek Harness 仍是开发者预览，机制变更对照 `references/harness-alignment.md` 的对齐表执行。
7. **新增插件行的路径解析**：一律用 `!!js` + `baseUrl`（预设根）解析相对路径，照 `skill-filesystem` 的写法；钩子/声明类条目改动后须**重启 DSH Desktop** 生效（声明与钩子配置均在进程启动时读取）。
