# Agent 长期记忆 / 知识管理机制调研简报

> 支撑决策号：D085（知识库记忆）

> 委托方：run-lead（dsh-codepunk 多智能体开发流程，已具 knowledge/ 知识库布局 + D083 技能治理）
> 调研岗：ind-res（唯一联网岗）
> 检索窗口：2026-08-30（UTC+7）
> 检索方式：**curl 直连 GitHub REST API**（`search/repositories` 按 stars 排序抓元数据 + `repos/{owner}/{repo}` 抓仓库详情 + `repos/{owner}/{repo}/readme` 抓官方 README），一手来源，无第三方转引。每条结论标注【事实】（README/API 可核对）或【推断】（基于可靠知识的推导）。star 数取 GitHub API 实况值。

---

## 0. 检索渠道与过滤逻辑

- 关键词：`agent memory` / `llm memory` / `agent knowledge base` / `RAG agent skill` / `mem0 agent memory` / `LLM memory layer`（`search/repositories?q=...&sort=stars&order=desc`）。
- 过滤：去掉泛 agent harness（deer-flow/ruflo/nanobot 等"记忆只是子模块"）与数据库底层（tidb 等），聚焦**记忆/知识管理层本身**。
- 精选 TOP 5 + 2 补充：star 高 + 机制直接对口 dsh-codepunk 的 knowledge/ 运营场景。

| 项目 | 仓库 URL | star（retrieved 2026-08-30） | 定位 | 核心机制一句话 |
|---|---|---|---|---|
| Mem0 | https://github.com/mem0ai/mem0 | 64,318 | 通用记忆层（Agent Memory Layer） | 多级记忆（User/Session/Agent）+ 单趟 ADD-only 提取 + 实体链接 + 多信号融合检索 + 时序推理 |
| OpenHuman | https://github.com/tinyhumansai/openhuman | 38,841 | local-first 个人 AI 大脑 | 评分 Memory Tree 压缩成 Markdown 树存 SQLite + Obsidian Wiki 镜像 + auto-fetch 20 分钟持续喂脑 + TokenJuice 压缩 |
| OpenViking | https://github.com/volcengine/OpenViking | 34,282 | 自进化 Context Database | `viking://` 虚拟文件系统统一 记忆/知识/技能 三类上下文；L0/L1/L2 三级加载；会话提交后异步抽经验入长期记忆 |
| Letta（MemGPT） | https://github.com/letta-ai/letta | 24,485 | 有状态 agent 平台 | self-editing memory（内省/心跳/内存压力触发改写）+ 会话记忆可跨设备云同步 |
| Agent_Memory_Techniques | https://github.com/NirDiamant/Agent_Memory_Techniques | 940 | 30 个可运行 notebook 的教学仓库 | 六族记忆技术全覆盖（短期/长期/认知架构/检索/框架/生产），含横向对比矩阵 |
| Basic Memory | https://github.com/basicmachines-co/basic-memory | 3,801 | MCP 原生本地知识管理 | Markdown 即知识库（人机同写）+ 知识图谱/wikilinks + 语义搜索（可选 cross-encoder 重排），供 Claude/Codex/Cursor 共用 |
| SAG | https://github.com/Zleap-AI/SAG | 2,435 | 新 SOTA RAG 架构（替代 RAG+GraphRAG） | chunk→event（完整语义单元）+ 多 entity 索引 + 查询期动态超边（SQL join 扩展），增量写入天然友好 |

*star 来源：GitHub REST API `repos/{owner}/{repo}`，retrieved_at=2026-08-30。【事实】*

---

## 1. Mem0 — `mem0ai/mem0`（64,318★，Apache-2.0）【最相关】

**定位【事实】**（README，retrieved_at=2026-08-30）：AI agent 通用记忆层，"remembers user preferences, adapts, continuously learns"。

**核心机制【事实】**：
- **多级记忆**：User / Session / Agent 三级状态，按 `user_id` / `agent_id` 过滤检索。
- **2026-04 新算法（ADD-only 单趟提取）**：一次 LLM 调用完成提取，**只新增不覆盖（nothing is overwritten）**；agent 确认过的行为类事实也被平等存储。
- **Entity linking**：实体抽取 + 嵌入 + 跨记忆链接，用于检索加权。
- **Multi-signal retrieval**：语义 + BM25 关键词 + 实体匹配并行打分后融合；top_200 检索预算、单趟非 agentic 循环。
- **Temporal Reasoning**：时间感知检索，按"当前状态 / 过去事件 / 未来计划"排序对应时间实例。
- 性能（managed platform，OSS 方向性相似）：LoCoMo 92.5 / LongMemEval 94.4 / BEAM(1M) 64.1，token 6.8–7.0K。评估框架 `mem0ai/memory-benchmarks` 开源可复现。
- 已提供 **Agent Skills**（`npx skills add` 可装进 Claude Code/Codex/Cursor），reference skills（常驻）+ pipeline skills（按需执行）。

**对 dsh-codepunk 的可借鉴**【推断】：
1. **ADD-only 不覆盖原则**：dsh-codepunk 的 `knowledge/lessons/` 与评分档案天然是追加式——明确禁止"改旧条"，新经验只新增带时间戳条目，配合时间感知检索取"当前生效值"。与现有"只允许尾部追加命名池"纪律同源，可显式扩展为"所有知识条目只追加不覆盖"。
2. **实体链接做检索加权**：dsh-codepunk 的 `knowledge/hr/teams/<name>.yaml` 可建立 codename↔seat↔task 的链接索引，检索高分团队时按实体命中加权（而不只是按文件名 grep）。
3. **多信号融合**：检索 `lessons/` 时不只靠关键词，可按"语义 + 关键词 + 已关联 evidence 数"融合排序，命中带证据多的经验优先。
4. **⚠️ 适配注意**：Mem0 是**服务/向量库形态**（需 LLM + embedding + 数据库），与 dsh-codepunk"纯 Markdown/YAML 文件事实、无 LLM 参与评分"的架构冲突——只借鉴机制思想，不引入外部记忆服务。

---

## 2. OpenViking — `volcengine/OpenViking`（34,282★，AGPL-3.0）【记忆分层与目录检索最对口】

**定位【事实】**（README，retrieved_at=2026-08-30）：开源 Context Database for AI Agents，统一存记忆（memories）/ 资源（resources）/ 技能（skills），以 `viking://` 虚拟文件系统呈现，agent 用 `ls`/`tree`/`find` 浏览而非黑盒向量查询。

**核心机制【事实】**：
- **三级内容分层（L0/L1/L2）**：写时处理为 L0 abstract（~100 token 快速相关判断）→ L1 overview（~2K token 结构/要点）→ L2 details（全文按需加载）；每个目录自带 L0/L1，不读全文即可判相关性。**按任务深度按需加载，省 token**。
- **目录递归检索（directory recursive retrieval）**：向量先定位最高分目录，再逐层下钻，结果带周边上下文整体返回；检索轨迹可回放调试（可观测检索）。
- **会话提交 → 异步抽经验**：session 提交后，后台把用户偏好与 agent 经验异步提取入长期记忆。
- 评测（0.3.22，LoCoMo + tau2-bench）：接入后 Claude Code 记忆准确率 57.21%→80.32%，输入 token 降 34.3–91.0%，查询延迟降 58.45–66.10%；tau2-bench 经验记忆使任务成功率 +6.87~+11.87pp。
- 商业版（SaaS / 自托管）与 OSS 并存，但 README 明确"**open-source edition is not crippled**"：AGPLv3 无 feature gate、无账号、无激活码。

**对 dsh-codepunk 的可借鉴**【推断】：
1. **L0/L1/L2 三级加载** → dsh-codepunk 的 `knowledge/` 与 `runs/<run_id>/docs/memory/` 简报天然可套：每条简报顶部一行 L0 摘要（相关判断用），正文 L1 结构，证据/交接包原文 L2 按需展开。与 D074「压缩先保召回」兼容：L1/L2 必须保留字段清单。
2. **目录递归检索** → `knowledge/` 现有 hr/research/handoffs/prompts/lessons 目录本身就是层次结构：检索可"先定位目录，再下钻到文件"，避免跨目录海量 hit。
3. **会话提交异步抽经验** → dsh-codepunk 已有「run 内运营 memory brief → 收官归档入 knowledge/」；可增强为**提交即异步触发经验抽取模板**（触发条件→坑→解法，D070 同源），不阻塞收官。
4. **⚠️ 适配注意**：OpenViking 是独立服务（需 Python 服务端 + 模型配置），引入成本高；dsh-codepunk 只借鉴其"目录分层 + 异步沉淀 + 可观测检索"的**组织思想**，不动用其运行时。

---

## 3. OpenHuman — `tinyhumansai/openhuman`（38,841★，GPL-3.0）【local-first 知识压缩 + 双脑分工】

**定位【事实】**（README，retrieved_at=2026-08-30）：personal AI "brain that builds a local-first memory of your world"；Memory Tree + Obsidian Wiki，无向量汤黑盒。

**核心机制【事实】**：
- **Memory Tree + Obsidian Wiki**：数据压缩为**带评分（scored）的 Markdown 树**存 SQLite，镜像为可打开编辑的 Obsidian vault；Karpathy LLM-Knowledgebase 路线。
- **TokenJuice**：工具输出在进模型前压缩，同信息最高省 80% token。
- **auto-fetch**：每 20 分钟把邮箱/日历/仓库/文档拉取压缩进记忆（"明天的上下文今早就有"）。
- **双脑分工（split brain）**：快速反射 agent 分流进站流量 + 深度推理核心委托 worker fleet（对应 dsh-codepunk 的会话调度/多小组并行）。
- 可选 agentmemory 后端代理，可与其他 coding agent（Claude Code/Cursor/Codex/OpenCode）共享同一持久记忆。
- 高亮对比：OpenClaw/Hermes 记忆靠 plugin 或 self-learning，OpenHuman 是"记忆树 + Obsidian vault"。

**对 dsh-codepunk 的可借鉴**【推断】：
1. **scored Markdown 树** → dsh-codepunk `knowledge/` 已是 YAML/Markdown 文件事实（评分全部来自文件事实），天然符合"可评分、可打开、可编辑"路线；可补充"每知识条目附带 freshness/复用计数"用于排序。
2. **TokenJuice 思想** → 与 dsh-codepunk 已有的 token 经济学（D076）+ 记忆简报压缩（D074）同向：交接包/evidence 在进上下文前先压缩，只保留字段清单。
3. **持续 auto-fetch** → dsh-codepunk 跨 run 复用：可借鉴"自动把上轮 handoffs/lessons 沉淀喂进下一轮简报 must_read_refs"（已有雏形，知识.md 再规划步骤 3），不必每轮人工点名。
4. **⚠️ 适配注意**：OpenHuman 是桌面应用 + 订阅（GPL-3.0 传染性），不引入其运行时；只借鉴"压缩为可编辑 Markdown 树 + 常驻喂脑"的组织模型。

---

## 4. Letta（MemGPT）— `letta-ai/letta`（24,485★，Apache-2.0）【self-editing 记忆架构参考】

**定位【事实】**（README，retrieved_at=2026-08-30）："Build stateful agents with memory that can learn and improve over time"；当前源码在 `letta-ai/letta-code`，本仓库为 landing page + 历史 V1 server（archive 分支）。

**核心机制【事实】**：
- self-editing memory 架构：**inner monologue（内省）+ heartbeat events（心跳）+ memory pressure（内存压力触发改写）**——记忆不写死，模型按压力信号主动改写记忆区。
- 会话记忆、身份、跨设备云同步（Letta Cloud）；桌面/web/Slack/Telegram/Discord 多通道。
- Agent SDK（TS）可嵌入应用。

**对 dsh-codepunk 的可借鉴**【推断】：
1. **memory pressure 触发改写** → dsh-codepunk `runs/<run_id>/docs/memory/` 简报可在"上下文预算超阈值"时触发 L0/L1 压缩（已有 D074/D076 雏形），可显式化为"压力阈值 → 触发降载"规则。
2. **inner monologue / heartbeat** → 与 dsh-codepunk 的 goal 自动续行、子代理回报递送同思路：定期自我核对进度并回报，而非静默。
3. **⚠️ 适配注意**：Letta 是完整 agent runtime，dsh-codepunk 不引入；只借鉴"记忆按压力主动改写 + 状态持久化"的理念。

---

## 5. Agent_Memory_Techniques — `NirDiamant/Agent_Memory_Techniques`（940★，Apache-2.0）【记忆技术全景教学，最佳机制字典】

**定位【事实】**（README，retrieved_at=2026-08-30）：30 个可运行 Jupyter notebook，覆盖"每种记忆技术"；六族：短期 / 长期 / 认知架构 / 检索 / 框架 / 生产。附决策树与横向对比矩阵（docs/comparison.md）。

**对 dsh-codepunk 最具参考价值的机制条目**【事实，据其 30 技术表】：
- **09 Episodic Memory（情景记忆）**：存"完整交互 + 何时何地上下文" → 对应 dsh-codepunk 的 handoffs/交接摘要归档。
- **10 Semantic Memory（语义记忆）**：从交互中抽取通用事实独立存储 → 对应 knowledge/lessons/ 结构化经验。
- **11 Procedural Memory（程序性记忆）**：捕获"how-to"流程 → 对应 dsh-codepunk 的 prompts/roles 提示词 + skill 沉淀回路。
- **13 Hierarchical Memory Layers（分层记忆）**：hot/warm/cold 三级随老化升降 → 对应 L0/L1/L2 + knowledge/ 分级。
- **16 Self-Reflection Memory**：agent 回顾自身动作，记"什么有效"下次复用 → 对应评分/复盘驱动提示词优化闭环。
- **18 Temporal Memory / 19 Forgetting & Decay**：时间戳 + 时间加权检索；**主动遗忘（decay/访问计数/相关性剪枝）** → 直接对口"知识过期处理"。
- **22 Multi-Agent Shared Memory**：共享存储 + 消息传递 + 一致性协议 → 对应多小组并行开发的知识共享与工作房隔离。
- **24–27 框架实操（Graphiti/Mem0/Letta/Zep）**、**29 LoCoMo 基准**、**30 生产模式（TTL/sharding/GDPR/可观测）**。

**对 dsh-codepunk 的可借鉴**【推断】：
1. **该仓库是最佳"机制字典"**：run-lead 审定时可直接按条目查"某机制在 dsh-codepunk 对应哪里/如何落地"，比从论文读高效。
2. **Forgetting & Decay 明文化**：dsh-codepunk 现无显式知识过期策略（research/ 有 TTL 字段但未强制）；可借鉴"访问计数 + 时间衰减 + 相关剪枝"设计三态：长期保留（lessons）/ TTL 过期（research）/ 主动废弃（skill-governance §3.3 已具雏形）。
3. **⚠️ 适配注意**：多为教学 notebook（Python/向量库形态），不直接搬代码；用于校准 dsh-codepunk 已有机制的命名与归类。

---

## 6. 补充参考（低相关但可借鉴单项机制）

### 6.1 Basic Memory — `basicmachines-co/basic-memory`（3,801★，AGPL-3.0）
**定位【事实】**：MCP 原生、local-first、Markdown 即知识库（人机同写一个文件），AI 与人双向读写 + sync 保持同步；wikilinks 积累成知识图谱；语义搜索可选 cross-encoder 重排；工具带行为 hint（read-only/destructive/idempotent）供 agent 按需选工具。
**可借鉴【推断】**：a) **Markdown 即知识库 + 人机同写**与 dsh-codepunk `knowledge/` 纯文件形态完全同构；b) **工具行为 hint**（只读/破坏性/幂等标注）可引入交接包/命令清单，防 agent 误跑破坏性操作；c) 知识图谱由 wikilink 自然积累——dsh-codepunk 可用 `[[...]]` 或显式 refs 字段把 lessons↔handoffs↔research 互链。

### 6.2 SAG — `Zleap-AI/SAG`（2,435★，MIT）
**定位【事实】**：原创新 RAG 架构，chunk→event（完整语义单元）+ 多 entity 索引 + **查询期动态超边**（SQL join 扩展，不预建不全局维护），替代 RAG+GraphRAG 双系统；增量写入自然（新 chunk 只加自身 event/entities 不重算全局图）；HotpotQA/2WikiMultiHopQA/MuSiQue Recall@5 平均 90.07%，F1 72.96%。
**可借鉴【推断】**：**增量写入免重算**原则——dsh-codepunk 每轮新增 lessons/handoffs 时不需要重建全局索引，新条目自包含（触发条件+坑+解法+关联 evidence），检索按需 join；不引入其 SQL/向量运行时。

---

## 7. 机制横向对比（dsh-codepunk 视角）

| 维度 | Mem0 | OpenViking | OpenHuman | Letta | 对 dsh-codepunk 的启示 |
|---|---|---|---|---|---|
| 记忆分层 | User/Session/Agent 三级 | L0/L1/L2 三级加载 | Memory Tree（scored markdown） | self-editing memory | knowledge/ 目录即分层：L0=条目摘要，L1=结构，L2=证据原文 |
| 工作记忆（working） | session 过滤 | viking:// 会话 | per-thread goals | heartbeat/inner monologue | runs/<id>/docs/memory/ 简报 = working；收官归档 = 长期 |
| 情景记忆（episodic） | ADD-only 事实累积 | 会话提交异步抽经验 | 全量压缩进树 | 对话持久化 | handoffs/ 归档 + memory brief |
| 语义记忆（semantic） | entity linking | resources/ 语义化 | Obsidian vault 语义 | 记忆区改写 | lessons/ 结构化经验 + prompts/roles |
| 检索方式 | 语义+BM25+实体融合 | 目录递归检索（向量定位目录再下钻） | 评分树+图谱 | 压力触发改写 | 先定位目录再下钻；多信号融合排序 |
| 持久化 | 向量库+DB（服务） | viking:// FS + DB | SQLite + Obsidian | 云/本地 runtime | 纯 Markdown/YAML 文件事实（无需服务） |
| 知识过期 | Temporal reasoning 取当前值 | 目录按需更新 | auto-fetch 常新 | 压力改写 | 三态：保留/TTL/废弃（补 Forgetting & Decay） |
| 多智能体共享 | 按 agent_id 隔离 | viking://peers | A2A 加密编排 | 多通道 | 工作房隔离 + 共享 lessons/handoffs 读取 |
| License | Apache-2.0 | AGPL-3.0 | GPL-3.0 | Apache-2.0 | 只借鉴机制（无代码拷贝，License 风险低） |

---

## 8. TOP 落地建议（dsh-codepunk，按性价比排序）

> 均为【推断】适配方案，需 run-lead 审定后由文档小组落细则（D083 铁律：无简报不应用、无细则不引用、无溯源不登记）。

1. **知识条目三级化（借鉴 OpenViking L0/L1/L2）**：在 `knowledge/` 与 `runs/<id>/docs/memory/` 引入约定——每条记录首行 L0 一句话摘要（相关判断）、正文 L1 结构、evidence/handoff 原文 L2 按需展开。兼容 D074「压缩先保召回」（L1/L2 保留字段清单不丢关键项）。
2. **知识过期三态策略（借鉴 Forgetting & Decay + research/ 既有 TTL）**：`lessons/` 长期保留（复用计数驱动排序）、`research/` TTL 到期归档、`prompts/roles` 由评分/复盘驱动升版；废弃走 skill-governance §3.3。补一条"访问计数/复用计数"字段，检索排序时时间衰减 + 相关性融合。
3. **条目自包含 + 互链（借鉴 SAG 增量写入 + Basic Memory wikilink）**：每条 lessons/handoffs 自包含（触发条件+坑+解法+关联 evidence），新增不重算全局；用显式 refs/`[[...]]` 互链 lessons↔handoffs↔research，检索按链接扩展。
4. **多信号融合检索（借鉴 Mem0 Multi-signal）**：查 `lessons/` 与 `hr/` 时按"语义 + 关键词 + 已关联 evidence 数/复用次数"融合排序，带证据多的经验优先。
5. **异步经验抽取（借鉴 OpenViking 会话提交 + 现有收官归档）**：小组收官提交 memory brief 后，由 `subagent_docs` 异步套 D070 模板抽结构化经验入 `knowledge/lessons/`，不阻塞收官。
6. **机制字典挂靠（借鉴 Agent_Memory_Techniques）**：run-lead/文档小组审定时查其 30 技术表 + docs/comparison.md 做归类比对；可把其 taxonomy 映射表附入 learned-skills 溯源。

**不建议引入**：Mem0/OpenViking/OpenHuman/Letta 运行时（外部服务、向量库、订阅、AGPL/GPL 传染性）均与 dsh-codepunk"纯文件事实、无 LLM 参与评分、自托管预设"架构冲突——全部按**机制思想**吸收，零代码/零依赖拷贝。

---

## 9. License 汇总

| 仓库 | License（GitHub API，retrieved 2026-08-30） | 对 dsh-codepunk 影响 |
|---|---|---|
| mem0ai/mem0 | Apache-2.0 | 宽松，可参考实现 |
| letta-ai/letta | Apache-2.0 | 宽松，可参考实现 |
| NirDiamant/Agent_Memory_Techniques | Apache-2.0 | 宽松，可参考实现 |
| Zleap-AI/SAG | MIT | 最宽松 |
| volcengine/OpenViking | AGPL-3.0（OSS 主项目；crates/ov_cli 与 examples 为 Apache-2.0） | 传染性，仅思想借鉴 |
| tinyhumansai/openhuman | GPL-3.0 | 传染性，仅思想借鉴 |
| basicmachines-co/basic-memory | AGPL-3.0 | 传染性，仅思想借鉴 |

> 本次检索全部为【事实】级一手抓取（GitHub API + README），无第三方转引；所有 star 数、license、机制描述均可在对应 URL 复核。建议文档小组按 skill-governance §3.1 对 Mem0（算法迭代快）、OpenViking（0.3.x 早期）月度复检版本变化。
