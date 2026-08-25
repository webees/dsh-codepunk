# DeepSeek Harness 深度调研简报（dsh-codepunk 特性利用基线）

> 调研岗：ind-res（行业分析）
> 检索窗口：2026-08-26 03:00–03:20（UTC+7）
> 归属：dsh-codepunk（预设 meta 调研，R13 归位 benchmarks/）
> 状态：交付工程主责（run-lead）审核；禁直接投递实现组

## 0. 检索窗口 / 渠道说明（透明披露）

| 渠道 | 结果 | 备注 |
|---|---|---|
| `web_search`（内置） | **认证失败 ×2**（"api key invalid"） | 全程不可用 |
| curl 直连 `api.github.com`（仓库/树元数据） | ✅ 成功 | 命中官方仓库，仓库元数据、目录树 |
| curl `raw.githubusercontent.com`（文档/设计笔记原文） | ✅ 成功 | 27+ 份文档与笔记原文 |
| curl `deepseek.com/harness`（官方主页） | ✅ 成功（302 跟随） | 中文主页文案可用 |
| curl `registry.npmjs.org`（npm 包元数据） | ✅ 成功 | `@deepseek-ai/dsh` 0.1.1-rc.2 |
| curl `github.com/.../discussions`（社区） | ✅ 部分 | 列表页 HTML 可解析出标题（含 1 条已知 Bug 讨论） |
| 本机 `/Applications/DSH Desktop.app/.../app.asar.unpacked/` | 检查点存在（build/lib/node_modules） | **仅作背景，未深入反编译**；本简报不引其内容为来源 |

**关键事实**：DeepSeek Harness 是**公开开源项目**（官方仓库 + MIT 协议 + 官网 + npm 发行），公开一手资料极其丰富，不存在「公开信息有限」的情况。以下内容全部来自官方仓库原文。

引文约定：`[F]` = 官方原文事实（可直接验证）；`[I]` = 本调研推断/跨源比对判断。所有检索均在 2026-08-26 完成，`retrieved_at` 统一记为 `2026-08-26`。

---

## 1. 定位结论（一句话 + 论据）

**DeepSeek Harness（`dsh`）是 DeepSeek AI 出品的开源 Agent Harness：以 Cordis 插件系统为内核的「一切皆插件」执行环境/agent runtime，官方定位为「Agent = Model + Harness」——模型之上提供工具、技能、会话、沙箱、存储、循环、调度、UI 等全部能力，开发者预览阶段（明确声明有兼容性破坏变更）。**

论据（[F]，均取自官方仓库 `master` 分支与官网）：
- 根 README：`DeepSeek Harness (dsh) is an open-source agent harness developed by DeepSeek AI… everything is a plugin… powered by Cordis`。[README.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/README.md)
- 官网：「DeepSeek Harness 开发者预览版：一切皆插件」；「模型、工具、技能、会话、沙箱、存储、循环、调度、UI 等所有 Agent 能力均由插件组合而成，可以自由替换和灵活重组」。[https://deepseek.com/harness](https://deepseek.com/harness)
- 许可证 MIT、语言 TypeScript、~195k stars / ~22k forks、topics: `ai-agents, cordis, dsh, dsh-plugin`。[GitHub API 仓库元数据](https://api.github.com/repos/deepseek-ai/deepseek-harness)
- 安装通道：`npx @deepseek-ai/dsh web`（Web UI 默认 `http://127.0.0.1:3080`）或源码运行；npm latest = `0.1.1-rc.2`（登录 `rc` 前缀印证预览期）。[README.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/README.md)、[npm registry](https://registry.npmjs.org/@deepseek-ai%2Fdsh)
- 底层框架 Cordis 及其设计论文《A Programming Paradigm for Spatiotemporal Composability》。[README.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/README.md)、[cordiverse/cordis](https://github.com/cordiverse/cordis)、[cordiverse/paper](https://github.com/cordiverse/paper)

---

## 2. 能力特性清单（源 + 事实/推断标注）

### 2.1 架构与「一切皆插件」—【官方定义级】

| # | 特性 | 证据（URL + [F]/[I]） |
|---|---|---|
| A1 | **无特权核心**：模型适配器、工具库、会话日志、agent loop 本身都是插件，配置层即可替换/扩展任意能力；`dsh-base` 是每个 profile 的第一层（model adapters/tools/persistence/sandbox+approval policy/settings/credentials/telemetry） | [F] [docs/architecture.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/architecture.md) |
| A2 | **Profile/bundle 分层组合**：profile = 按序叠加的 bundle 树；`cordis.patch.yml` 可按行替换任意配置；`dsh --profile web --dump-config` 打印实际启动树 | [F] 同上 |
| A3 | **三重事件域**：session 事件（持久事实）/agent 事件（实况控制，`agent/*`）/capability 事件（策略与适配器，`fs/*`、`tools/*`、`telemetry/*`） | [F] 同上 |
| A4 | **「模型可见即已记录」不变量**：任何进入模型请求的内容必须可由仅追加会话日志重建（system prompt、思维链、工具调用与结果、子代理调度、上下文注入全记录）；Trajectory 视图按来源查看；resume/fork/检索/回放共享同一事件流 | [F] [docs/architecture.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/architecture.md)、[官网](https://deepseek.com/harness) |
| A5 | **Turn/Step 双层循环**：step = 一次模型请求+其工具调用；turn = 零或多个 step；`agent/pre-step`（waterfall，可改写/拒绝消息）、`agent/request-error`（错误恢复）等为扩展点 | [F] [docs/architecture.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/architecture.md)、[docs/agent-lifecycle.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/agent-lifecycle.md) |
| A6 | **Capability seam（能力缝）三件套**：Service Definition / Service Provider / Consumer；换 provider 即换整个产品面（fs 与 subprocess 共享同一执行世界，子代理 provider 同理） | [F] [docs/capability-seams.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/capability-seams.md) |
| A7 | **四种官方运行模式**：标准模式（文件编辑/Shell/网页检索/Skills/计划/目标/子代理/工作流）、PTC 模式（Code Mode SDK，用一个 TypeScript 程序组合多步工具调用）、极简模式（仅双工具：持久 bash + str_replace_editor）、**创造模式**（运行时检查 + 插件实验 + 自定义 agent preset 创作）→ dsh-codepunk 即「自定义 preset」这一类产品的官方先例 | [F] [官网](https://deepseek.com/harness) |
| A8 | **Agent preset 官方机制**：`dsh-agent-presets` 配置（`default` preset + `roots` 扫描优先级 + `PresetTrust: 'system' | 'user'`；user preset 由人或 agent 编写，与 shell 同信任）；preset 目录可含 `isolate` realm 服务行 → 单会话不同能力集 | [F] [docs/config-catalog.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/config-catalog.md)（`@deepseek-ai/dsh-agent-presets` 段） |
| A9 | **Cordis `--patch` overlay**：`dsh web --patch ./cordis.yml` 即可插入本地插件/工具，无需改源码 | [F] [docs/user/develop/basic/index.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/user/develop/basic/index.md) |

### 2.2 工具系统 —【官方事实】

- 官方工具目录（[docs/tool-catalog.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/tool-catalog.md) 全部 [F]）：`ask_user_question`、`run_code`（Code Mode）、`exit_plan_mode`、`bash`/`pwsh`（且各有持久 shell 变体）、`str_replace_editor`、fs 族 `read`/`write`/`edit`/`read_image`、fs-search 族 `glob`/`grep`、`terminal_*`（持久 PTY）、goal 族 `create_goal`/`get_goal`/`update_goal`、`schedule_create/delete/list`、`lsp`、`ralph`、`skill`、session-query 族（`session_event_*`/`session_search`/`session_trace`）、`subagent`、subagent-control 族 `interrupt_agent`/`list_agents`/`send_message`、`report`、jobs 族 `job_kill`/`job_list`/`job_output`、实验性 agent-team 族 `spawn_teammate`/`team_task_create`/`team_task_get`/`followup_task` 等。
- [F] 工具执行管线：`tools/pre-execute → execute → post-execute`（waterfall 扩展点）、并行工具调用、工具超时/结果保留库（design notes 2026-07-06/07-07/07-10 系列）。
- [F] dsh-codepunk 使用的 read/write/edit/glob/grep/read_image/bash/job_*/subagent/send_message/list_agents/interrupt_agent/create_goal/get_goal/update_goal/ask_user_question 等与本目录一一对应，**工具面完全对齐**。

### 2.3 Goal 机制（同会话续行，官方包名级确认）—【官方事实，最高价值】

来源：[harness-level-loop 设计笔记](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/feature/2026-07-16-harness-level-loop.md)（[F]）、[docs/subsystems/goal.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/subsystems/goal.md)、[docs/tool-catalog.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/tool-catalog.md)

- **词汇层级（官方）**：`Goal → Goal Round → Turn → Step`；一个 goal round = 一个为当前 goal 准入的续行轮（实现为一条 goal-sourced turn）；人类轮/无关轮不消耗 round 上限。
- **包拆分**：`@deepseek-ai/dsh-goal`（领域：GoalId、CAS GoalRef、GoalSnapshot、四态 `active/paused/blocked/complete`、GoalBlockReason、进程本地 GoalActivation、get/create/edit/pause/resume/complete/block/clear/disarm）、`dsh-tool-goal`（模型侧三工具，**变更类调用必须来自当前 live root-agent turn 的直接人类消息**）、`dsh-goal-round-driver`（round 准入/围栏/派发）、`dsh-command-goal`（`/goal` 人类命令）。
- **激活与持久化分离**：phase 持久（会话日志可回放、fork 继承前缀），`armed/disarmed` 进程本地、**永不持久化**；恢复会话不会自动续行，需人类消息（任意语言表达「继续/顺延」）后模型 `update_goal(action:'resume')` 重新 armed（[F] 与 dsh-codepunk R10 完全一致）。
- **上限**：`defaultMaxGoalRounds` 默认 256（只计 admitted rounds）；`blockedAfterConsecutiveRounds` 默认 3（机械下界）。[F]
- **局限（官方明示）**：无独立评估器（不复制 Claude Code 的 evaluator）、无聚合预算（仅轮数上限，不约束 token/费用/时间）、无持久自动运行器、无时间调度器、无 goal reflector；自动轮只能报 complete/blocked，**不能改人类目标**。[F]
- 设计血缘（官方自述）：Codex TUI `/goal` 形状（[链接到 Codex commit](https://github.com/openai/codex/blob/678157acaa819d5510adfe359abb5d0392cfe461/codex-rs/tui/src/chatwidget/slash_dispatch.rs)）、Claude Code goals（[文档](https://code.claude.com/docs/en/goal)）；「外部产品是参照物而非兼容目标」。[F]

### 2.4 Skill 系统 —【官方事实，与 dsh-codepunk 直接同构】

来源：[skill-system 设计笔记](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/feature/2026-07-05-skill-system.md)、[docs/subsystems/skills.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/subsystems/skills.md)（均 [F]）

- `@deepseek-ai/dsh-skill`（注册表 `ctx.skills`）+ `dsh-skill-filesystem`（本地 provider）+ `dsh-tool-skill`（durable 会话目录 + 模型侧 `skill({name})` 加载工具）。
- **渐进式披露**：目录只含 name+description（默认 cap 500 字），正文按需加载；目录以 user-role `<system-reminder>` 消息在首轮 `agent/pre-step` 注入。
- **扫描根优先级（first-wins）**：项目 `.dsh` → 项目 `.agents` → customSkillDirs → 用户 `.dsh` → 用户 `.agents`；用户 `.dsh/skills` 跳过 `.system`。[I] dsh-codepunk 的预设 skill 位于 `~/.dsh/.agent-presets/dsh-codepunk/skills/` → 需注意官方本地 provider 扫描根**不含 `.agent-presets`**（见 §4 建议 3）。
- 格式：`<name>/SKILL.md` 或 `<name>.md` + YAML frontmatter（`name`/`description` 必填；`whenToUse`/`metadata`/`disable-model-invocation`/`user-invocable` 可选）；输出 `<skill_content>`/`<skill_resources>`/`<skill_instructions>`（[F] 与本会话实际 skill 回显格式一致）。
- 对标（官方自述）：Codex、Claude Code、OpenCode、Kimi Code 均收敛到同一「发现元数据 + 按需全文」范式。

### 2.5 Plan mode —【官方事实】

来源：[plan 协作状态笔记](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/simplification/2026-07-22-plan-specific-collaboration-state.md)（[F]）

- `@deepseek-ai/dsh-plan-mode`：durable `plan/mode: {active}`（log-only、可 resume/fork 重建）；`/plan [message]`、`/plan off`（人类直退）、`exit_plan_mode`（模型侧）。
- **带评审的退出**：`exit_plan_mode` 要求 agent 在 active plan mode、提交非空且以标题开头的 markdown plan → 人审（Approve / Keep planning / 自由文本反馈），仅「纯 Approve」放行。
- plan mode 是协作姿态，**不是安全边界**（「模型忽略指引仍可变更，除非部署方另行配置 sandbox/approval/fs 策略」——官方原话）。
- 曾考虑把 sandbox/approval 折叠进 plan 状态的方案被官方否定（三轴独立）。[F]

### 2.6 Workflow（JS 编排）—【官方事实】

来源：[dynamic-workflows 设计笔记](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/feature/2026-07-05-dynamic-workflows.md)（[F]）

- `@deepseek-ai/dsh-workflow`（`ctx.workflowEngine` seam）+ worker-thread 引擎 `dsh-workflow-worker-thread`（每 run 一个 worker）+ `dsh-tool-workflow`（`workflow` 工具）。
- **Claude Code 兼容脚本契约**：`meta`（JSON：name/description/whenToUse/phases）+ JS body（顶层 await、返回 JSON）；运行时注入 `agent(prompt, options)`、`parallel(thunks)`、`pipeline(items, ...stages)`、`phase(title)`、`log(msg)`、`args`。
- 与 CC 的**有意分歧**：① hook 误用（未知选项/畸形参数/超上限）抛 `WorkflowError(fatal:true)` 且组合子重抛，不像 CC 那样把失败 null 化；② `args` 是 JSON 对象。
- **结构化输出基底**：`SubagentStartRequest.outputSchema` → 子代理强制 schema 校验提交（capture 工具 + 指令 + 强制注册，校验失败可重试、干净完成但未提交 = 错误）。
- **安全边界（重要）**：worker 线程与 vm 上下文**不是安全边界**（脚本可逃逸到 Node API）；沙箱化需独立进程/isolated-vm 引擎。脚本信任何模型 bash 权限。
- Deferred（官方）：后台收集、journaling+resume、saved/bundled workflows（`.deepseek/workflows/` 注册表）、嵌套 workflow、budget、`effort/isolation/agentType` 选项。
- 官网 PTC 模式 = Code Mode SDK（`run_code` 工具），是除 workflow 外的第二种「程序化组合多步工具」路径。

### 2.7 Subagent 分层 —【官方事实】

来源：[subagent seam 笔记](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/feature/2026-06-21-subagent-capability-seam.md)、[docs/subsystems/subagent.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/subsystems/subagent.md)（[F]）

- `ctx.subagents` = **named-provider 注册表**（可多实现共存）：`spawn-in-process`（fresh 子会话）、`fork-in-process`（父日志快照种子）、`acp`（ACP 客户端驱动外部进程）、`codex`/`claude-code`（**驱动官方 Codex / Claude Code 产品进程做一次性子代理**）。
- 可选能力（静态声明、不支持即 loud reject 绝不静默忽略）：`outputSchema`、`depthLimit`、`toolFilter`、`persona`。
- **continuable 子代理**（`prepareContinuable`）：交付后由 continuation 管理器经 AgentHandle 冷恢复；`dsh-tool-subagent-control`（interrupt_agent/list_agents/send_message）+ `dsh-tool-subagent-report`（report 结构化回报）。[I] 与 dsh-codepunk「结算通知→inbox→自动递送」同源。
- 隔离：in-process 子代理各有独立 Session；子步骤/工具调用**不写入父日志**，父日志只记 spawn 的 tool/call + tool/result。
- 后台委派走共享 `ctx.jobs` + `job_*` 工具（与后台 bash 同机制）。

### 2.8 Agent Teams（实验性·团队协调 seam）—【官方事实，与 dsh-codepunk 三人组同构】

来源：[docs/subsystems/agent-team.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/subsystems/agent-team.md)（[F]）

- `ctx.agentTeams`（`dsh-experimental-agent-team` + `dsh-experimental-tool-agent-team`）：Lead Session 为根，teammate = named continuable 直接子代理（context `fresh`/`fork`）。
- **持久 mailbox**（TeamMessageSnapshot，delivery `quiet|wakeup`，目标落盘才算送达、去重键含 sender/id）。
- **共享任务 DAG**（TeamTaskSnapshot：`revision` CAS、`blockedBy` 无环、`writeScopes` 为建议路径前缀非锁）→ 与 dsh-codepunk 的 chunks.yaml（write_paths 互斥 + depends_on 无环）几乎一一映射。
- 工具：`spawn_teammate`/`send_message`/`team_task_create`/`team_task_get`/`list_agents`/`interrupt_agent`/`followup_task`；服务含 `waitForChange(timeoutMs)`（10s–1h 等待变化）。

### 2.9 上下文 / Compaction —【官方事实】

来源：[compaction seam 笔记](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/feature/2026-06-18-compaction-capability-seam.md)（[F]）

- 包：`dsh-compaction`（接口：abstract `compactIfNeeded`/`compactNow`/`compactRegion`）+ `dsh-compaction-basic`（后端）+ `dsh-compaction-tool-result-pruner`（可选超大 tool/result 重写）+ `dsh-command-compact`（`/compact`）。
- 触发：`'pressure'`（每成功 step 后的下个 `agent/pre-step` 检查，阈值比 0.8 / 保留尾 0.16 / maxTokens 8192 / auto:true 默认）与 `'context-overflow'`（`agent/request-error` 强制压缩后编号重试轮）。
- 摘要以**单条 user/message**（`COMPACT_CHECKPOINT_SOURCE` + `surfaceOp replace`）落日志，`compaction/start…end` 锁 + 崩溃可检测孤儿；head-anchoring（自动 checkpoint 恒在头部）；tool-pairing balanced（不拆工具调用/结果对）。
- D074 的「evidence 只回 command+exit_code、拒绝整段 stdout」等上下文纪律在官方架构中对应的正是 session-query 工具族（`session_event_*`/`session_search`/`session_trace` 留痕检索）与 Trajectory 视图。

### 2.10 文件策略：Sandbox + Approval —【官方事实，与会话现况一字不差】

来源：[sandbox 笔记](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/feature/2026-07-06-sandbox.md)、[approval 笔记](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/feature/2026-07-06-approval-seam.md)（[F]）

- `@deepseek-ai/dsh-sandbox`：`SandboxMode` = `read-only | workspace-write | danger-full-access`（**仅文件效果**，不承诺网络/进程可见性）；`bash` 工具暴露配对字段 `sandbox_permissions` + `justification`。
- **阶梯升级（escalation）核心语义**：默认 workspace-write；**仅当沙箱真正拒绝某操作时**，模型才可请求一次用户批准并以更宽权一次重试；`allowed-once` 只放行那一次；拒绝/取消/unavailable 各自 fail-closed；授权**不持久化**。
- 运行时后端：bwrap（Linux）/ Seatbelt `sandbox-exec`（macOS，deprecated 但随附）/ 打包 Landlock launcher；Windows 链预留空 = fail-closed。
- `@deepseek-ai/dsh-user-approval`：`session/request_permission` + `approval/asked`/`approval/decided` 审计对；waterfall answerer；`policy: 'ask' | 'never'`（never = 无值守自动拒绝）；**无 answerer（headless/CI）默认 fail-closed**（[I] 与本会话「approval prompts disabled → 拒绝即终局」一致）。
- **approval 与 user-questions 是两条独立路径**：审批不走 `ask_user_question`（官方明确拒绝复用 elicitation seam）。[F]
- 官方 permission-presets 默认表：`workspace-write`（workspace-write + ask）、`danger-full-access`（danger-full-access + never）。[F] [config-catalog.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/config-catalog.md)

### 2.11 其他高相关能力

- **Jobs**：`ctx.jobs` + `job_kill/job_list/job_output`（后台任务统一收集机制，与 dsh-codepunk 用法一致）。[F] [docs/architecture.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/architecture.md)
- **调度**：`dsh-schedule` `schedule_create/delete/list`（时间调度被明确排除在 goal 之外，属独立能力）。[F] [docs/tool-catalog.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/tool-catalog.md)
- **Hooks**：`dsh-hooks-claude-code` / `dsh-hooks-codex`（把 CC/Codex 的 hook 事件桥接进 harness，含 `permissionDecision: ask`）。[F] [docs/config-catalog.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/config-catalog.md)
- **MCP**：`dsh-mcp-client`（MCP 客户端插件）。[F] 同上
- **Persistent terminal/PTY**：`dsh-tool-terminal`（`terminal_*`）。[F]
- **LSP**：`dsh-tool-lsp` / `dsh-lsp-stdio`。 [F]
- **Session query / telemetry**：`dsh-session-query-sqlite`、`dsh-session-telemetry-otel`；持久化 jsonl 与 sqlite 双后端。 [F]
- **Persona 段**：`dsh-persona` 配置渲染 `deployment:persona` prompt section（`{{…}}` 变量严格插值、`complete` 可压制其他段）→ dsh-codepunk 各岗位人设可考虑走官方 persona 通道而非纯文本注入。 [F] [config-catalog.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/config-catalog.md)
- **Fork**：`ctx.sessions.fork(source, boundary?, childSessionId?)`（活会话分叉）。[F] [docs/architecture.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/architecture.md)

### 2.12 与典型 harness 对比（官方一手视角）

来源均为 DSH 官方笔记自述（[F] 引用、[I] 判断）：

| 对照方 | DSH 官方叙述 | 依据 |
|---|---|---|
| Claude Code | ① dynamic workflows（脚本编排）是 CC 能力，DSH workflow 契约与之兼容并有 2 处有意分歧；② CC goals 的「goal vs 定时 loop」区分被采纳，但评价器（evaluator）**明确不复制**；③ 提供 `dsh-subagent-claude-code`（Agent SDK 驱动 CC 进程做子代理）+ `dsh-hooks-claude-code` hook 桥 | [dynamic-workflows](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/feature/2026-07-05-dynamic-workflows.md)、[harness-level-loop](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/feature/2026-07-16-harness-level-loop.md)、[subagent seam](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/feature/2026-06-21-subagent-capability-seam.md) |
| Codex | `/goal` TUI 形态是 DSH 人类侧 UX 参照（附 commit 锚点）；提供 `dsh-subagent-codex`（官方 Codex app-server 一次性子代理）+ `dsh-hooks-codex` hook 桥 | 同上 |
| Kimi Code / OpenCode | skill 渐进式披露五个产品收敛一致（官方列举） | [skill-system](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/feature/2026-07-05-skill-system.md) |
| Cursor | **官方资料无任何互操作/对比提及**（全树 grep 仅命中无关的 `cursor.ts` 游标文件） | [I] 全仓库目录树检索 |

### 2.13 已知限制与社区（官方 + 社区信号）

- [F] 根 README 原创声明：**Developer preview，明确会有兼容性破坏变更**；npm 版本 `0.1.1-rc.2` 佐证。[README.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/README.md)
- [F] goal：无独立评估器/无聚合预算/无持久自动运行器/无调度/无 reflector（见 2.3）。[harness-level-loop](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/feature/2026-07-16-harness-level-loop.md)
- [F] workflow：后台收集、journaling+resume、saved workflows、budget 等均 deferred；worker 线程非安全边界。[dynamic-workflows](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/feature/2026-07-05-dynamic-workflows.md)
- [F] sandbox：Windows 无沙箱后端（fail-closed）；Seatbelt 依赖 deprecated `sandbox-exec`；`allow_always` 持久授权未设计。[sandbox](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/feature/2026-07-06-sandbox.md)
- [F] skill：`context: fork`、parameter hints、per-skill tool 约束等字段不在已交付契约内。[skill-system](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/feature/2026-07-05-skill-system.md)
- [F] 社区通道：GitHub Discussions + Discord（README 提供）；[讨论区实际可见](https://github.com/deepseek-ai/deepseek-harness/discussions)（含置顶「Welcome/Plugin Category Guidelines」、中文飞书群，及一条真实 Bug 讨论：*[Bug] Subagents always fail with 400 "Reasoning is mandatory" when parent uses a thinking-…*）。[I] 该 Bug 讨论提示：**父会话启用思考模型时子代理请求可能触发 400**——dsh-codepunk 多智能体场景需验证此边界。[retrieved_at: 2026-08-26]

---

## 3. dsh-codepunk「充分利用建议」（按价值排序，共 11 条）

> [I] 以下为调研推断建议；落地决策权归工程主责。标注与官方机制号对应。

1. **把「dsh-codepunk 是官方创造模式/自定义 preset 的合法产品形态」写进预设自我认知与宣传口径**。官网明确「自定义 agent preset 创作」是第四种官方模式（A7），`~/.dsh/.agent-presets/dsh-codepunk` 正是 `PresetTrust: 'user'` 的官方形态（A8）。建议 1 合：① 引用官网为用户立信任；② 在各种 docs/references 中把 dsh-codepunk 定位为「user preset + workflow skill + 团队编排」三层，而非自造概念。[F] [官网](https://deepseek.com/harness)、[config-catalog.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/config-catalog.md)

2. **goal 机制（2.3）已被官方确认并与 dsh-codepunk R10 完全对齐——把 R10/D066 的措辞与官方词汇统一**（Goal→Goal Round→Turn→Step；armed/disarmed 进程本地；resume 需直接人类消息；默认 256 轮）。未来 dsh-codepunk 文档可直接引用官方 `dsh-goal`/`dsh-goal-round-driver` 包名，向用户解释「为什么必须 update_goal resume」。同时注意官方「自动轮不得修改人类目标、只能报 complete/blocked」——dsh-codepunk 的评分/人事等自动轮动作若需要写状态，应走工作区文件而非 goal 变更。[F] [harness-level-loop](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/feature/2026-07-16-harness-level-loop.md)

3. **验证 skill 扫描根，必要时向官方请求支持 `.agent-presets` 或采用 `customSkillDirs`**。官方本地 provider 扫描根为项目/用户 `.dsh` 与 `.agents`（2.4），**不含 `.agent-presets`**。当前 dsh-codepunk 的 `~/.dsh/.agent-presets/…/skills/` 能否被 harness 目录发现存在疑点（可能靠主技能装载机制而非官方扫描）。建议：实证检查后，要么把 preset skills 映射进官方根（如用户 `.dsh/skills` 或配置 customSkillDirs），要么把此差异列入长期待办。[F] [skill-system](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/feature/2026-07-05-skill-system.md)

4. **调研迁移到官方 Agent Teams seam（2.8）的可行性——它与 dsh-codepunk 三人小组同构度最高**。持久 mailbox、任务 DAG（CAS + blockedBy + writeScopes）、waitForChange、continuable teammates 覆盖了现预设手工用 subagent + 文件 state 拼装的大部分；若迁移，`chunks.yaml`/`progress/`/`handoff/` 可映射为官方 task/消息原语，减薄自研层。风险：实验性 API、`writeScopes` 是建议前缀非锁（与 R8 diff∈write_paths 的强制门禁互补）——可作为「候选迁移 + 双轨验证」立项。[F] [agent-team.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/subsystems/agent-team.md)

5. **利用官方 workflow（2.6）把「巡检/交接/合并」等固定流程固化为脚本**（`parallel`/`pipeline`/`phase` + outputSchema 结构化子结果），替代纯 prompt 驱动的编排；子代理结果强制 schema 校验，天然满足 evidence 结构化。注意官方 worker 非安全边界与「fatal 不静默」语义与预设 fail-fast 哲学一致。[F] [dynamic-workflows](https://github.com/deepseek-ai/deepseek-harness/blob/master/.agents/notes/implemented/feature/2026-07-05-dynamic-workflows.md)

6. **persona 段（2.11）值得实验**：官方 `deployment:persona` 用 `{{…}}` 变量严格插值且可 `complete` 化，可作为岗位人设注入的官方通道（对比现纯 prompt 文本注入），并注意其与 skill 正文的分工。[F] [config-catalog.md](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/config-catalog.md)

7. **Double-down 官方上下文/compaction 语义（2.9, 2.4）**：D074 的「摘要即证据、拒绝整段 stdout」在官方有对应机制（compaction checkpoint 摘要以用户消息落日志、session-query 工具族）；可在预设文档中把上下文纪律与官方「模型可见即已记录/Trajectory」对齐，提升用户信任。

8. **sandbox/approval 语义（2.10）与 dsh-codepunk「双门闩/审查门」在同一条权利谱系上**：官方 approval 与 user-questions 分离、无 answerer fail-closed、授权不持久——语义与预设「禁止小组自行联网/申请-批准」流程吻合；可在手册中说明「流程内审批 ≠ harness approval」以消歧义。

9. **把 subagent-control/report 与 jobs（2.7/2.11）行为写进巡检 SOP**：官方 `dsh-tool-subagent-report` 结构化回报 + `job_*` 后台收集是「结算通知递送」的对位机制；R12（结算通知滞后辨识）背后是「子步骤不进父日志、父日志只记 result」的官方隔离（2.7）——建议在 references/ 中写入官方依据，增强新用户理解。

10. **跟进已知 Bug 边界：父会话思考模型 + 子代理 400（2.13）**。官方讨论区有「子代理 400 Reasoning is mandatory」实证报告；dsh-codepunk 大量使用子代理 + 可能开启 thinking，建议预设默认提示工程主责验证该组合，并把结论纳入知识库/错误日志模板。[F] [discussions](https://github.com/deepseek-ai/deepseek-harness/discussions)

11. **建立「官方版本漂移监控」**（成本最低、收益长期）：项目处于 developer preview，breaking changes 是官方承诺（2.13）；建议在预设 planning 中加入轻量「版本核对」步骤（如每次大 run 前 `npm view @deepseek-ai/dsh version` + GitHub releases 扫描），并把本文档列为进一步调研的起点索引。

---

## 4. 未知 / 需验证项（不编造，如实列出）

1. **本机部署差异**：官方 Web UI 默认端口 3080，而本会话运行于 43120——本机 DSH Desktop 装配差异未深究（未反编译 app.asar）。Web UI 端口随安装形态变化的官方说明未检索到。
2. **`~/.dsh/.agent-presets/` 目录名**：官方 agent-presets 文档使用 `roots`/`USER_PRESET_DIR` 概念，但**未在本次检索文档中确认默认 preset 根路径是否就是 `.agent-presets`**（本机实测路径为该目录，[I] 推断为官方默认值，未获得文档级出处）。
3. **preset skills 发现性**：`skills/` 位于 `.agent-presets` 下是否被官方 skill provider 扫描（见建议 3），需实机验证。
4. **thinking 模型 × 子代理 400 问题**的影响面与修复状态（见建议 10）。
5. **Agent Teams 稳定性**：实验性（experimental 前缀）API 的兼容性与生产可性未定。[F] 官方即标记 experimental。
6. **goal 对「完成后立即评分/解散」等流程可否由自动轮完整驱动**：官方限定自动轮只报 complete/blocked，对 dsh-codepunk 自动评分链路的兼容性需实测（见建议 2）。
7. 未检索 GitHub Releases/CHANGELOG 时间线（本次聚焦文档与结构；版本漂移监控留作建议 11 的起点）。

---

## 5. 附：本次引用的核心官方 URL 清单（均已 retrieved_at 2026-08-26）

- 仓库：<https://github.com/deepseek-ai/deepseek-harness>（README / AGENTS.md / BENCHMARK.md / LICENSE=MIT）
- 官网：<https://deepseek.com/harness>
- npm：<https://registry.npmjs.org/@deepseek-ai%2Fdsh>（0.1.1-rc.2）
- 文档：docs/architecture.md、docs/agent-lifecycle.md、docs/capability-seams.md、docs/config-catalog.md、docs/tool-catalog.md、docs/glossary.md、docs/subsystems/{goal,subagent,skills,agent-team}.md、docs/user/guide/index.md、docs/user/develop/basic/index.md
- 设计笔记（.agents/notes/implemented/feature/）：2026-07-05-skill-system / dynamic-workflows、2026-06-18-compaction-capability-seam、2026-06-21-subagent-capability-seam、2026-07-06-sandbox / approval-seam、2026-07-16-harness-level-loop、2026-07-19-fresh-agent-ralph-workflow-tool、2026-07-22-plan-specific-collaboration-state、2026-07-24-agent-loop-observable-state-machine、2026-06-24-workspace-context、2026-06-29-todo-write-tool、2026-07-12-subagent-persona-tool-filter-and-depth、2026-07-08-background-subagent-tasks
- 生态：cordiverse/cordis、cordiverse/paper、code.claude.com/docs/en/workflows、code.claude.com/docs/en/goal、openai/codex（TUI /goal commit 678157a）、github.com/deepseek-ai/deepseek-harness/discussions

（完）