# 高 star 多智能体编排/框架开源项目调研简报

> 支撑决策号：D067（编排机制）/ D068（门禁）/ D069（schema）/ D070（评分）/ D071（委托）

> 委托方：run-lead（dsh-codepunk 六阶段多智能体开发流程基准对照）
> 调研岗：ind-res（唯一联网岗）
> 检索窗口：2026-08-19（UTC+7）
> 检索方式说明：本会话 `web_search`/`web_fetch` 通道不可用（API key 失效 / 无可用 provider），已改用 **curl 直连 GitHub API**（一手仓库元数据）与 **raw.githubusercontent 官方 README**（一手机制说明）核实。所有 URL 均为真实官方地址；star 数取 GitHub API 实况值，非第三方转引。每条结论标注【事实】（来源可核对）或【推断】（基于可靠知识的推导）。

---

## 0. 项目对比表

| 项目 | 仓库 URL | star(约) | 定位 | 核心机制一句话 |
|---|---|---|---|---|
| MetaGPT | https://github.com/FoundationAgents/MetaGPT | 69,892 | 软件公司 SOP 化多角色流水线 | `Code=SOP(Team)`，PM/架构/工程/QA 以**产出物文档**为中间介质串行衔接 |
| AutoGen | https://github.com/microsoft/autogen | 60,507 | 多智能体对话/编排框架 | Core/AgentChat/Extensions 分层，GroupChat 发言者仲裁 + human-in-the-loop（**2026 已进维护模式**） |
| crewAI | https://github.com/crewAIInc/crewAI | 57,301 | 角色化 Crews + 事件驱动 Flows | 自主协作 Crew + 确定性 Flow 状态机；hierarchical manager 委托+结果验证 |
| agno（原 phidata） | https://github.com/agno-agi/agno | 41,776 | 自托管 agent 平台 | session/memory/~/.dsh-codepunk/projects/<id>/knowledge/traces 全存自有库，JWT-RBAC，学习回路 |
| LangGraph | https://github.com/langchain-ai/langgraph | 40,001 | 低层图编排框架 | 图 nodes/edges + **持久化 checkpoint（durable execution）** + interrupts(HITL) + 长短双记忆 |
| ChatDev | https://github.com/OpenBMB/ChatDev | 34,034 | 瀑布流虚拟软件公司 | CEO/CTO/Programmer 专项讨论会，ChatChain 配置化 Phase 序列；经验共学习 ECL/IER、MacNet DAG（2.0 转型 zero-code 平台） |
| graphiti | https://github.com/getzep/graphiti | 30,080 | 时序上下文图谱记忆层 | 实体/事实(triplet)/episodes 溯源 + 时间有效性窗口，增量更新避免全量重算 |
| smolagents | https://github.com/huggingface/smolagents | 28,875 | 轻量 agent 库 | **code-as-action**（用代码表达动作而非 JSON tool call），核心逻辑 ~1000 行，沙箱执行 |
| OpenAI Agents SDK | https://github.com/openai/openai-agents-python | 28,761 | 生产级多 agent 工作流 | Agents(instructions+tools+guardrails+handoffs)、Sessions、Tracing、HITL、agents-as-tools |
| openai/swarm | https://github.com/openai/swarm | 21,910 | 轻量编排（教育性，已退役） | Agent + **handoff 交接原语** + context_variables，函数错误回灌让 agent 自愈，max_turns 护栏 |
| Google ADK | https://github.com/google/adk-python | 21,186 | 代码优先 agent 工具包 | Workflow 图引擎（routing/fan-out/retry/state/HITL）+ **Task API 结构化委托** + 工具确认(HITL) |
| CAMEL | https://github.com/camel-ai/camel | 17,606 | 角色扮演/研究框架 | role-playing + stateful memory + 可验证奖励驱动演化（scaling laws of agents） |
| dottxt-ai/outlines | https://github.com/dottxt-ai/outlines | 15,647 | 结构化输出引擎 | **生成期保证** JSON schema/regex/grammar，而非生成后解析修复 |

*star 数据来源：GitHub REST API `repos/{owner}/{repo}`，retrieved_at=2026-08-19。【事实】*

---

## 1. Microsoft AutoGen — `microsoft/autogen`（60,507★）

**定位/核心机制【事实】**（README，retrieved_at=2026-08-19）：
- 分层设计：Core（消息传递、事件驱动、本地/分布式 runtime、跨 .NET/Python）、AgentChat（two-agent chat / GroupChat 等语义层）、Extensions（LLM 客户端/代码执行/MCP）。配套 AutoGen Studio（no-code GUI）与 AutoGen Bench（benchmark）。
- GroupChat：多发言者消息收敛于仲裁逻辑（speaker selection）与终止条件；Magentic-One 为 web 浏览/代码执行/文件处理的多面手团队。
- **⚠️ 时效重要项【事实】**：README 明确 AutoGen 已进入 **maintenance mode（维护模式）**，不再加新功能、社区管理；官方建议新项目迁移至 **Microsoft Agent Framework**（https://github.com/microsoft/agent-framework）。→ 借鉴其"机制思想"，不要基于 AutoGen 选型或抄码。

**优点【事实/推断】**：a) GroupChat 的发言者仲裁与终止条件是群聊防漂移的成熟设计；c) 分层抽象让高/低层 API 各得其位；b) 提供多个人类介入点（HITL）。

**对 dsh-codepunk 的可借鉴**【推断】：
1. 给每个 task/小组设**显式终止与预算条件**（如最大轮次/最大消息数），自治对话到点收敛，防止"聊飞"费 token —— 对应 dsh-codepunk 会话调度加护栏。
2. **分层抽象**：把 dsh-codepunk 拆成公文层/语义层/执行层，职责解耦。
- 适配注意：GroupChat 自由对话成本高且易发散，dsh-codepunk 已用结构化公文规避；只借鉴仲裁器与终止条件，不引入自由聊天。

---

## 2. langchain-ai/langgraph — `langchain-ai/langgraph`（40,001★，最高相关度）

**定位/核心机制【事实】**（README，retrieved_at=2026-08-19）：低层"图式编排"框架，构建长时运行、有状态的 agents。README 明列三类核心机制：
- **Durable execution（持久化执行）**：状态 checkpoint 持久化，故障后**自动从断点恢复**、长时间运行不丢进度。
- **Human-in-the-loop（interrupts）**：执行中任意点**检查并修改 agent 状态**后继续。
- **Comprehensive memory**：短期工作记忆 + 跨会话长期持久记忆。
- 底层受 Google Pregel / Apache Beam 启发（图节点+边执行），参考文档：https://docs.langchain.com/oss/python/langgraph/durable-execution 、/interrupts 、/memory 。
- （supervisor 路由/多 agent 模式属业内公认模式【推断】：locate by a supervisor LLM delegating tasks —— 未在本 README 出现，未做一手抓取，故标推断。）

**优点【事实/推断】**：a) checkpoint 是"可恢复长流程"标杆方案；b) interrupt-and-resume 是精细 HITL；c) 长短双记忆模型清晰；d) 配套 LangSmith 可观测（trace 执行路径、state 转换、runtime 指标）——README 明确提及。

**对 dsh-codepunk 的可借鉴**【推断】：
1. **中间产物 checkpoint 化 + 从断点续行**：dsh-codepunk 目前靠"交接包+订单消息"人工续跑；可把每个 chunk 的工作房+progress+evidence 建成**结构化、可重放的 check point**，配合 goal 自动续行实现"故障/中断后精确回到上次断点继续"，而不是整轮重来或凭记忆续接。
2. **可观测执行 trace**：为 stage/task/seat 记录执行路径与状态转换（谁做、产出、耗时、token），供巡检、评分、审计用（对应 LangSmith 思路）。
3. **interrupt-and-resume 式 HITL**：把双门闩/审查门升级为"可查看并微调中间状态后再从该点继续"，而非简单放行/打回。
- 适配注意：LangGraph 是编程框架（写图代码）；dsh-codepunk 是公文驱动的编排层，只借鉴"状态建模/持久化/可观测"三理念，勿照搬 API。supervisor 模式需 run-lead 审定后选型印证。

---

## 3. crewAI — `crewAIInc/crewAI`（57,301★）

**定位/核心机制【事实】**（README，retrieved_at=2026-08-19）：
- 双轨：**Crews**（角色化自主协作，适合灵活决策/动态交互）+ **Flows**（生产级事件驱动工作流，精确控制：带 state、branching、routing，`@start/@listen/@router` 装饰器、`or_/and_` 触发条件、`Flow[State]` 泛型状态）。
- **hierarchical process**：自动分配 manager 到 crew，通过**委托 + 结果验证**协调 planning/execution。
- 支持 human-in-the-loop；自带 **Tracing & Observability**（metrics/logs/traces）与统一控制面。

**优点【事实/推断】**：a) Flow 把"自主自治"与"确定性流程控制"分离——正是长流程兼顾灵活性/可控性的关键；c) hierarchical manager 的"委托派活→验证结果"与 dsh-codepunk 工程主责+三人三角高度同构；d) 生产级可观测。

**对 dsh-codepunk 的可借鉴**【推断】：
1. **把六阶段显式建模为带状态的 Flow/状态机**：阶段流转、分支、门禁（双门闩/审查门/合并门）作为显式节点与路由条件，而把"小组内协作"留给自主模式——Crew 自主、Flow 控流程的分工范式。
2. **manager 的"委托 + 结果验证"闭环**：工程主责派活后不止巡检，要用明确验证标准（acceptance evidence）核对结果质量再放行（现 sdet 证据门即雏形，可强化为 manager 显式验证步骤）。
- 适配注意：Crews 无固定流的鲁棒性靠提示词兜底，易不可控；dsh-codepunk 应"显式流程为主、自主协作为辅"，避免全面自治。

---

## 4. MetaGPT — `FoundationAgents/MetaGPT`（69,892★）

**定位/核心机制【事实】**（README，retrieved_at=2026-08-19）：
- 一行需求 → 用户故事/竞分/需求/数据结构/API/文档等**产出物**；内部为 PM / 架构师 / 项目经理 / 工程师角色。
- 核心哲学：**`Code = SOP(Team)`**——把标准作业程序(SOP)物化并应用于 LLM 团队；**产出物中间件**：agents 之间不是靠自由聊天，而是靠**落盘的结构化文档**衔接阶段。
- 配套 Data Interpreter、Researcher、Debate 等单/多智能体用例。

**优点【事实/推断】**：a) 产出物即接口，天然可审计、可复用、上下文可控；b) SOP 显式化让流水线可编排、可复制；对"质量/验收"：每阶段落产出物即质量检查锚点。

**对 dsh-codepunk 的可借鉴**【推断】：
1. **强化"产物即接口"并把产物结构 schema 化**：brief/evidence/handoff/acceptance 全部**绑定强 schema**（JSON Schema / Pydantic 式），让交接就是一次结构校验，避免自由文风歧义、也不依赖长上下文记忆。
2. **SOP 显式化为可配置阶段序列**：把六阶段编成可回放、可裁剪的编排（对应 ChatDev 的 Chain 配置化），方便不同规模(repo)复用与再规划。
- 适配注意：MetaGPT 是单线瀑布流（串行、前后角色），dsh-codepunk 是并行小组+串行合并门；借鉴"产物 schema 化 + SOP 显式化"，勿照搬串行拓扑。

---

## 5. OpenBMB/ChatDev — `OpenBMB/ChatDev`（34,034★）

**定位/核心机制【事实】**（README，retrieved_at=2026-08-19）：
- 1.0 为**虚拟软件公司**：CEO/CTO/Programmer 等以"专项讨论会"形式执行设计/编码/测试/文档全生命周期；流程由 **ChatChain 配置（Phase 序列）**控制，链形（瀑布流）拓扑。
- 研究亮点：**Experiential Co-Learning（ECL）/ Iterative Experience Refinement（IER）**——instructor+assistant 跨任务**累积捷径型经验**，减少重复错误、提升效率；**MacNet**（DAG 拓扑，支撑上千 agent、避免上下文超限）；**puppeteer**（RL 学习中央编排器动态激活排序 agents 降计算成本）。
- **Human-Agent-Interaction**：用户可扮演 reviewer 给 programmer 提修改建议；Docker 安全执行、git 模式。
- 2.0（2026-01 发布）转 zero-code 多 agent 编排平台。

**优点【事实/推断】**：b) Human reviewer 介入模式；c) **经验共学习**是"跨轮沉淀降错"的实证思路；a) Chain 配置化让流水线可编辑；根本机制贴合 dsh-codepunk 六阶段闭环。

**对 dsh-codepunk 的可借鉴**【推断】：
1. **经验共学习落地到知识库**：把高分小组的"回修教训/捷径经验"沉淀为**结构化经验模板**（触发条件→常见坑→标准解法），供再规划与后续小组检索，直接降低重复缺陷（对应 ~/.dsh-codepunk/projects/<id>/knowledge/ 强化）。
2. **Human-Reviewer 介入点**：代码审查门可设计为"审查者以建议注入、不直接改码"的人际交互形态（现审查记录 reviews/ 已是雏形）。
- 适配注意：ChatDev 单线程串行；dsh-codepunk 并行小组需靠 depends_on 拓扑维持，借鉴"经验积累 + 审查介入 + 流程配置化"而非流水线形状。MacNet DAG 思路可作为多并行 chunk 的拓扑参考【事实→理念，推断】。

---

## 6. openai/swarm（21,910★，教育性已退役）/ openai/openai-agents-python（28,761★）

**Swarm 核心机制【事实】**（README，retrieved_at=2026-08-19）：
- 两个原语：**Agent**（instructions + tools）+ **handoff**（函数返回另一个 Agent 即移转控制权）；run() 循环：完成会话→执行工具→切换 Agent→更新 context_variables→无新调用返回。
- 交接时只替换 system prompt（handoff 进的新 Agent 人设），**保留 chat history**；共享上下文用 **context_variables**。
- **函数错误会回灌到对话**，让 Agent 自愈重试；`max_turns` 为成本/会话护栏；stateless（调用间不存状态）。
- **OpenAI 官方已用 Agents SDK 取代 Swarm**（README 顶部明确 Migration 建议）。

**OpenAI Agents SDK 核心机制【事实】**（README，retrieved_at=2026-08-19）：
- Agents（instructions+tools+**guardrails**+handoffs）、agents-as-tools、**Guardrails（输入/输出校验）**、**Human-in-the-loop**、**Sessions（自动对话历史管理）**、**Tracing（内置 run 追踪/调试/优化）**、SandboxAgent（容器内长时工作）。

**优点【事实/推断】**：b) Guardrails 在入口/出口强校验，防无效输出；c) handoff 是显式控制权交接协议，天然对应阶段交接；d) max_turns/sessions/tracing 都是工程落地护栏。

**对 dsh-codepunk 的可借鉴**【推断】：
1. **显式 handoff 协议 + 强校验（guardrails）**：把交接包形式化为"显式交接消息"，并在**输入(简报)与输出(证据/产出)两侧加 schema 校验**——不合格输出直接回退重做，而非进入下一阶段（呼应审查门+合并门）。
2. **Sessions/历史自动管理**：为每个工作房维护一段自动管理的运行上下文（类似 session），供续行与回滚。
- 适配注意：Swarm 无状态轻量（几千行）只适合学习；生产借 Agents SDK 思路。dsh-codepunk 借鉴"handoff 契约 + 双侧 guardrail"，勿学其无状态（dsh-codepunk 需要持久化）。

---

## 7. Google ADK — `google/adk-python`（21,186★）

**定位/核心机制【事实】**（README，retrieved_at=2026-08-19）：
- **Workflow Runtime**：图执行引擎，支持 routing、fan-out/fan-in、loops、retry、state management、dynamic nodes、**nested workflows**、HITL。
- **Task API**：结构化 agent 委托——multi-turn task、single-turn controlled output（**单轮受控输出**）、mixed delegation、HITL、task 可作为 workflow 节点。
- **Tool confirmation（HITL 工具闸）**：工具执行前强制显式确认与自定义输入；代码优先、跨模型。

**优点【事实/推断】**：a) fan-out/fan-in + retry 是并行编排模板；c) 结构化委托把"单轮受控输出 vs 多轮任务"两类协作契约显式化；b) 工具确认闸是精细 HITL。

**对 dsh-codepunk 的可借鉴**【推断】：
1. **区分两种委托契约**：define squad 三角的返回是"单轮受控输出"（如 sdet evidence 固定 schema）还是"多轮任务"（如 engineer 多轮写码）；契约明确可减少歧义、便于自动校验。
2. **对高风险动作加"工具确认闸"**：merge/发布/跨写集操作强制确认，对应双门闩与合并门，落到机制层（不只靠人设）。
3. **fan-out/fan-in 显式化**：多 chunk 并行派发→收敛合并的进程显式建模（贴合并行小组+串行合并门）。
- 适配注意：ADK 重工程化、面向部署；dsh-codepunk 借鉴委托契约与门控语义，不引入其 runtime。

---

## 8. CAMEL — `camel-ai/camel`（17,606★）

**定位/核心机制【事实】**（README，retrieved_at=2026-08-19）：
- 研究向 role-playing 多 agent 框架；设计原则：**Evolvability**（可由 RL + **可验证奖励(verifiable rewards)** 驱动演化）、**Scalability**（仿真百万级 agent）、**Statefulness**（agent 保持有状态记忆做多步交互）、**Code-as-Prompt**（代码本身清晰可读，人机皆可解释）。

**优点【事实/推断】**：b) 可验证奖励/信号驱动 agent 演化——把"质量信号"显式编码进优化回路；c) 有状态记忆支撑多步任务；工程可观测性一般【推断】。

**对 dsh-codepunk 的可借鉴**【推断】：
1. **可验证信号驱动再规划**：用 acceptance evidence 的通过率/缺陷密度作为显式反馈信号，注入评分与下一轮分块/招聘标准（呼应收官和再规划，把"验收结果"当强信号而非印象分）。
- 适配注意：CAMEL 面向仿真/研究；dsh-codepunk 借鉴"可验证信号→演化"闭环，取其思想不取仿真架构。

---

## 9. graphiti — `getzep/graphiti`（30,080★，记忆层参考）

**定位/核心机制【事实】**（README，retrieved_at=2026-08-19）：
- **时序上下文图谱**：Entities(节点)/Facts-relationships(triplet 边)/**Episodes(溯源，每个派生事实可回溯到原始数据)**/Custom Types(Pydantic)；每条事实带**有效性时间窗口**（何时为真、何时被取代）；**增量更新**避免全量重算；混合检索（semantic+keyword+graph traversal）。

**优点【事实/推断】**：c) 带时间戳与溯源的共享记忆，避免"记忆漂移/陈旧事实"；增量更新省成本。

**对 dsh-codepunk 的可借鉴**【推断】：
1. **知识库加"时间有效性 + 溯源"字段**：~/.dsh-codepunk/projects/<id>/knowledge/ 记忆条目标记"生效/失效时间"与"来源证据(file/evidence)"，再规划与参考时能识别陈旧结论；轻量采纳字段即可，不必引入图谱 DB。
2. **增量沉淀**：交接/评分后**增量**写入 knowledge（而非重写),降低维护与 token 成本。
- 适配注意：dsh-codepunk 是公文驱动，用"时间窗+溯源"结构化字段即可，无谓引入图数据库层。

---

## 10. 补充：smolagents / outlines / agno

**smolagents**（28,875★）【事实】：CodeAgent 用**代码**表达 agent 动作（code-as-action），非 JSON tool call——中间表示更紧凑、省 token、更精确；核心逻辑 ~1000 行（极简抽象）；执行走沙箱（E2B/Modal/Docker）。→ 借鉴【推断】：dsh-codepunk 可通过"代码作为 agent 中间语言/产出"来压 token 与提升产出执行精度；极简抽象提醒控制编排层复杂度。适配注意：单 agent 库，多 agent 编排需自建。

**outlines / dottxt-ai**（15,647★）【事实】：在**生成期**用 JSON schema / regex / grammar / Pydantic **保证**结构化输出，而非生成后解析修复。→ 借鉴【推断】：全部产出/证据文件（brief/evidence/handoff）以 schema 在生成期强约束，减少 parse 失败与无效重试，直接降成本、提验收通过率。

**agno**（41,776★）【事实】：自托管 agent 平台，session/memory/~/.dsh-codepunk/projects/<id>/knowledge/traces 全存自有数据库，JWT-RBAC 安全，learning loop（simulations + usage data）。→ 借鉴【推断】：工程落地上坚持自托管与数据掌控；traces/usage data 反向驱动优化。

---

## 11. 综合建议 TOP 清单（按对 dsh-codepunk 价值排序）

优先级侧重：**编排/状态持久化 > 质量回路 > 成本控制 > 可观测**。

1. **中间产物 checkpoint 化 + 从断点自动续行**【理念源自 LangGraph durable execution，推断】
   - 把每个 chunk 的工作房 + progress + evidence + 交接包建成**结构化、可重放的状态**，随 goal 自动续行实现"中断/失败后精确回断点继续"，替代靠人工读交接包续跑。
   - 适配注意：不要照搬 LangGraph API；用 dsh-codepunk 现有公文文件承载状态，补 schema 与版本/续行指针即可。

2. **产出物/证据全链 schema 强约束（生成期保证）**【理念源自 outlines + MetaGPT 产出物中间件，推断】
   - brief / evidence / handoff / acceptance / scores 全部绑定强 schema；sdet 证据落地即自动结构校验，不合格直接回退。降无效重试、降成本、提验收通过率。
   - 适配注意：为既有公文加 schema 是增量改造；先挑 evidence 与 acceptance 试点。

3. **六阶段显式状态机/Flow 化 + 门禁路由**【理念源自 crewAI Flow / ADK Workflow，推断】
   - 把阶段流转、分支、双门闩/审查门/合并门建模为显式节点与路由条件；小组内协作保持自主。可控性与灵活性分离。
   - 适配注意：避免过度工程，先给"合并门/审查门"这类高价值门建显式节点。

4. **结构化委托契约：受控输出 vs 多轮任务**【理念源自 ADK Task API / Swarm handoff，推断】
   - 明确 squad 三角每席的返回契约（sdet=单轮受控 evidence；engineer=多轮写码；squad-lead=受控交接摘要），并加输入(简报)/输出(证据)双侧 guardrail 校验。
   - 适配注意：先给 sdet 与交接作 schema 约束，成本最低见效快。

5. **human-in-the-loop 升级为"检查-修改-续行"**【理念源自 LangGraph interrupts / ADK tool confirmation，推断】
   - 双门闩/审查门/合并门处允许"查看并修改中间状态后再从该点继续"，而非简单放行/打回；高风险动作（merge/发布）加工具确认闸。
   - 适配注意：需在公文层记录"修改了哪个状态、谁改、何时"以可审计。

6. **可验证信号驱动分解-评分-再规划回路**【理念源自 CAMEL verifiable rewards / ChatDev 经验共学习，推断】
   - 用 acceptance 通过率、缺陷密度、回修次数等**硬信号**注入评分公式与下一轮分块/招聘标准；把高分小组"回修教训"沉淀为**结构化经验模板**进 ~/.dsh-codepunk/projects/<id>/knowledge/，跨轮降错。
   - 适配注意：信号需落 evidence 自动采集，避免依赖主管印象。

7. **执行路径可观测 / trace**【理念源自 LangSmith / crewAI tracing / OpenAI SDK tracing，推断】
   - 记录 stage/task/seat 的执行路径、状态转换、token 与耗时，构建巡检/评分/审计的统一视图；traces + usage 数据反向驱动流程优化。
   - 适配注意：轻量先做"关键节点打点"，不必上重系统。

8. **成本护栏：任务级 turn/run 上限 + 收敛条件**【理念源自 AutoGen 终止条件 / Swarm max_turns，推断】
   - 为每个 task 设 run/turn 预算，自治协作到点收敛；产物结构(schema)本身减少空转与冗余 token。goal maxGoalRounds 已在 Ⓐ 起到同类护栏，可下沉到 task 级。
   - 适配注意：护栏阈值需据实测(观测项 7)校准，防误伤长任务。

---

## 12. 事实与推断划分小结

- 【事实】：所有 star 数（GitHub API，2026-08-19）；各项目 README 明文所述机制（分层、GroupChat、checkpoint/HITL/记忆、Crews+Flows、Code=SOP、Chain/ECL/MacNet、handoff/context_variables、Task API/工具闸、code-as-action、结构化生成、时序图谱、自托管）；AutoGen 维护模式与迁移建议。
- 【推断】：各"对 dsh-codepunk 可借鉴改进"的具体落地形态、适配路径；LangGraph supervisor 多 agent 模式（业内公认，未在该 README 中当场核验）；对 dsh-codepunk 现状的映射判断。

> ⚠️ 边界声明：上述项目仅作**机制/思想借鉴参考**，dsh-codepunk 不应照抄其代码；涉及商业与架构理念，落地须经 run-lead 审定后由文档小组写入正式规范。
