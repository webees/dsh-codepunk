# 提示词压缩 / 上下文优化 · 行业调研简报

> 调研小组 ind-res 出品 · 面向 dsh-codepunk 多智能体预设备料
> 检索时间：2026-08-26 02:50 (CST) / 2026-08-25T18:50Z，同一会话内分批抓取（retrieved_at 见来源表）
> 渠道说明：**web_search 认证失败（api key 无效），全部改由 curl 直连官方 docs / GitHub 一手来源抓取**，URL 均为实测可达（部分页面在新域名 docs.claude.com / developers.openai.com / learn.chatgpt.com）。
> 标注：【事实】= 来源原文明确陈述；【推断】= 调研者对 dsh-codepunk 的转译判断。

---

## 一、技巧清单

### 主题 1 · System prompt 精简

| # | 技巧 | 来源 | 适用场景 | 对 dsh-codepunk 的落地建议 |
|---|---|---|---|---|
| 1.1 | **最小指令集原则**：system prompt 只放「完整描述预期行为的必要信息」，minimal ≠ short；从最小 prompt 起步测试，按失败模式增补，而非一次写完 | [Anthropic Engineering blog「Effective context engineering for AI agents」(2025-09-29)](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) | 任何系统提示的设计期 | 【事实】主会话 persona 与 SKILL.md 应定期做「减仓」：删掉靠模型本能就能完成的描述。 【推断】1300 行手册中「通用智能体行为」类文字可迁入 references/ 或示例，只保留承重规则在正文。 |
| 1.2 | **示例优于规则枚举**：3–5 个精选、多样、贴合场景的 canonical examples（few-shot）比贴一整版 edge-case 规则更有效；「examples 是千言万语的图画」 | [同上](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)；[Anthropic prompting best practices](https://docs.claude.com/en/docs/build-with-claude/prompt-engineering/claude-prompting-best-practices)；[Google Gemini Prompting strategies](https://cloud.google.com/vertex-ai/generative-ai/docs/learn/prompts/prompt-design-strategies) | persona 行为准则、输出格式约束 | 【事实】规则条款若能用 1 个「正确示范 vs 错误示范」示例表达，应优先示例。 【推断】persona 的 8 个维度每人设留 1 条经典示例，可省大量限定性描述。 |
| 1.3 | **系统提示分区 + XML/标签**：`<instructions>` `<context>` `<input>` 或 Markdown 分区，降低歧义；格式本身的重要性随模型变强而下降 | [Anthropic prompting best practices](https://docs.claude.com/en/docs/build-with-claude/prompt-engineering/claude-prompting-best-practices)；[Context engineering blog](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) | 长提示的组织 | 【事实】SKILL.md 的 §/P/R/D 编号体系即此实践，保持即可；不追求过细 XML。 |
| 1.4 | **「恰当时机呈现」（right altitude）**：避免两端——硬编码脆弱的 if-else 逻辑式提示、与过度空泛假设共享上下文的提示 | [Context engineering blog](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) | 系统提示措辞 | 【事实】流程正文写「按钮/文件名的精确指令」还是「原则性启发」需按承重程度分级。 【推断】dsh-codepunk 的 D0xx 决策释义属承重，应保留；纯措辞建议移除。 |
| 1.5 | **角色一句话已够**：给 Claude 的角色设定，一句话即可影响行为基调 | [Anthropic prompting best practices](https://docs.claude.com/en/docs/build-with-claude/prompt-engineering/claude-prompting-best-practices) | persona 开场 | 【事实】persona 首段角色声明可极简，背景知识交予后续分区。 |
| 1.6 | **上下文引理**：给指令附加动机/背景（「将朗读给 TTS」）比只写禁令更有效，可减少复述性规则 | [同上](https://docs.claude.com/en/docs/build-with-claude/prompt-engineering/claude-prompting-best-practices) | 禁令类规则 | 【事实】「为什么」比「禁止什么」更省字且更稳。 【推断】「语言纪律 R11」等禁令可附一句动机，替代多轮反复强调。 |

### 主题 2 · 上下文窗口管理

| # | 技巧 | 来源 | 适用场景 | 对 dsh-codepunk 的落地建议 |
|---|---|---|---|---|
| 2.1 | **Context rot（上下文腐败）**：窗口内 token 越多，召回与长距推理越差（所有模型皆有，梯度退化非硬悬崖）；上下文须当「有限资源 + 注意力预算」管理 | [Anthropic Context windows 文档](https://docs.claude.com/en/docs/build-with-claude/context-windows)；[Context engineering blog](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) | 一切长流程 | 【事实】「更大窗口 ≠ 更好」；主会话与子代理都不应把历史无节制堆积。 【推断】goal 多轮自动续行时，主会话上下文会持续增长，主动修剪比扩容更优先。 |
| 2.2 | **Compaction（压缩/摘要续窗）**：临近上限时把历史送模型总结、以摘要重开窗口；Claude Code 自动触发，`/compact <instructions>` 可定向，`/clear` 任务间彻底重置 | [Claude Code best practices](https://docs.claude.com/en/docs/claude-code/best-practices)；[Context windows 文档](https://docs.claude.com/en/docs/build-with-claude/context-windows)；[Compaction blog 段](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) | 长对话接近上限 | 【事实】压缩提示词先调「召回」（不漏关键信息：已改文件、未解 bug、关键决策、测试命令），再提「精度」（剔除冗余）。 【推断】文档小组（L1/L2 记忆）即 dsh-codepunk 的 compaction 层，其摘要模板应显式声明「必须保留的字段清单」。 |
| 2.3 | **工具结果修剪（tool result clearing）**：老 tool_result 用完即清，是最轻量、最安全的压缩形式 | [Anthropic Manage tool context](https://platform.claude.com/docs/en/agents-and-tools/tool-use/manage-tool-context)；[Context editing 文档](https://platform.claude.com/docs/en/build-with-claude/context-editing) | 多工具多轮循环 | 【事实】Anthropic 官方将「修剪陈旧 tool_result」列为四手段之一并与搜索/缓存/批处理可组合。 【推断】dsh-codepunk 各小组的命令输出应默认 head/tail 截断 + 只回 `exit_code + log_ref`（当前 evidence 格式已符合）；主会话巡检时勿把大段日志带回 inbox。 |
| 2.4 | **上下文修剪（trimming）**：仅保留最近 N 轮 user turn（OpenAI 示例默认 8 轮），老的整轮丢弃 | [OpenAI Cookbook「Context Engineering – Short-Term Memory Management with Sessions」](https://developers.openai.com/cookbook/examples/agents_sdk/session_memory) | 会话历史控制 | 【事实】主流做法：最近几轮保持逐字保留、更早的压缩或丢弃。 【推断】goal-enabled 的自动递送场景可考虑每轮收尾时主会话主动压缩旧巡检记录。 |
| 2.5 | **子代理隔离上下文**：子代理在独立窗口里探索（可耗数万 token），只回 1,000–2,000 token 精炼摘要，主控保持干净 | [Context engineering blog](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)；[Claude Code best practices](https://docs.claude.com/en/docs/claude-code/best-practices#use-subagents-for-investigation) | 多智能体编排 | 【事实】dsh-codepunk 三人组即此模式：小队主责回到主会话的应是「工作简报（summary）」，工程细节留在工作房。 【推断】可把「摘要 ≤ 1000–2000 token」写进派遣 prompt 的硬性汇报节奏。 |
| 2.6 | **并发会话/上下文预算可见性**：Claude 新一代模型自带 context awareness（自动注入 token 预算与剩余量给模型）；API 侧用 token counting 预估算 | [Anthropic Context windows 文档](https://docs.claude.com/en/docs/build-with-claude/context-windows) | 长流程预算护栏 | 【事实】模型能感知剩余预算时自我管理能力更强。 【推断】主会话不应替模型数 token，改用 goal maxGoalRounds 与「文件实况」做外部护栏即可。 |

### 主题 3 · Progressive disclosure（渐进披露）

| # | 技巧 | 来源 | 适用场景 | 对 dsh-codepunk 的落地建议 |
|---|---|---|---|---|
| 3.1 | **Just-in-time 检索**：agent 只持轻量标识符（文件路径、查询、链接），运行时用工具把数据拉进上下文，而非一次性全量预处理 | [Context engineering blog](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) | 大代码库/大数据 | 【事实】Anthropic 明确命名 progressive disclosure：元数据→按需加载正文；Claude Code 用 CLAUDE.md 前置 + glob/grep 即时检索的混合模式。 【推断】SKILL.md 只在前置注入正文骨架，references/ 四个文件全部改为「按需读取」——与当前开关「按需加载 references」一致，应强化：正文内只留路径与一句话用途。 |
| 3.2 | **指令链分层（AGENTS.md 模式）**：全局（~/.codex/AGENTS.md）→ 仓库根 → 嵌套目录逐层合并，靠后覆盖靠前；**合并上限 32 KiB（project_doc_max_bytes），超限截断**；空文件跳过 | [OpenAI Codex「Custom instructions with AGENTS.md」](https://learn.chatgpt.com/docs/agent-configuration/agents-md) | 多层级指令组织 | 【事实】32 KiB 是行业对「单次注入指令」的实用硬上限；dsh-codepunk SKILL.md 现 27.7 KiB，已在红线内但余量小（剩余 ~15%）。 【推断】新增内容优先进 references/standard.md 等按需文件，正文保持 ≤ 30 KiB 安全区；若需再增承重规则，先做等价替换而非追加。 |
| 3.3 | **Manifest / 文件化上下文**：大内容放工作区文件（README.md / task.md / task 清单），prompt 只留行为与边界；manifest 提供紧凑地图 | [OpenAI Cookbook「Building Reliable Agents with Memory and Compaction」](https://developers.openai.com/cookbook/examples/agents_sdk/building_reliable_agents_memory_compaction) | 任务上下文分发 | 【事实】「长指令进文件、短指令进 prompt」是 OpenAI 官方推荐的 manifest 最佳实践。 【推断】主会话派单时 prompt 只给「目标 + 边界 + 文件路径」，全书内容给路径引用——即 DSH 的 brief 双文件模式，与其一致，勿把整份手册粘进每份派遣。 |
| 3.4 | **元数据即信号**：文件名、目录层级、时间戳本身就是高效上下文（test_utils.py 在 tests/ 与 src/ 含义不同） | [Context engineering blog](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) | 文件系统导航 | 【事实】命名与目录即元数据，不必额外描述。 【推断】工作房目录命名（rooms/squad-<task_id>）与分支命名（dsh-codepunk/<run>/<task>）已符合此规律，保持。 |

### 主题 4 · 指令压缩技术

| # | 技巧 | 来源 | 适用场景 | 对 dsh-codepunk 的落地建议 |
|---|---|---|---|---|
| 4.1 | **清晰直接 + 顺序编号**：指令用编号列表表述步骤，明确输出格式与约束；避免依赖模型从模糊措辞推断 | [Anthropic prompting best practices](https://docs.claude.com/en/docs/build-with-claude/prompt-engineering/claude-prompting-best-practices)；[OpenAI Prompt engineering](https://platform.openai.com/docs/guides/prompt-engineering) | 步骤型流程 | 【事实】现 SKILL.md 的阶段编号（①–⑥、P/R/D）即此实践。 【推断】可检查是否存在「多段话表达一个动作」的冗余，压缩为动词开头的祈使句。 |
| 4.2 | **澄清式追加优于罗列式禁令**：用「提供上下文/动机」取代对同一规则的多轮重复（模型从解释中泛化） | [同上](https://docs.claude.com/en/docs/build-with-claude/prompt-engineering/claude-prompting-best-practices) | 禁令收缩 | 【事实】与 1.6 同一原则。 【推断】「双门闩」「合并门」等承重规则保留一次显式表述 + 动机句，正文勿重复 3 处以上。 |
| 4.3 | **引文落地（ground in quotes）**：长文档任务先让模型摘引相关原文再干活，聚焦相关部分、忽略其余 | [同上](https://docs.claude.com/en/docs/build-with-claude/prompt-engineering/claude-prompting-best-practices) | 长文档审查 | 【事实】审查类任务（代码审查门、交接审查）让 sdet/审查者先引证据再下结论，可抑制幻觉式放行。 |
| 4.4 | **显式边界 + 关键词预算**：prompt 压缩学术工具以「token budget」显式给压缩目标 | [Microsoft LLMLingua 系（LLMLingua/LongLLMLingua/LLMLingua-2）](https://github.com/microsoft/LLMLingua) | RAG/长上下文推理 | 【事实】LongLLMLingua 用 1/4 token 提升 RAG 性能 21.4%（针对 lost-in-the-middle）。 【推断】dsh-codepunk 不做 API 层自动压缩（风险高、收益低于编排层修剪）；但「budget 思维」可借用：给主会话预设「每轮巡检汇报 ≤ 300 token」等显式配额。 |

### 主题 5 · Long-context 优化（上下文工程）

| # | 技巧 | 来源 | 适用场景 | 对 dsh-codepunk 的落地建议 |
|---|---|---|---|---|
| 5.1 | **长文档置顶、查询/指令放末尾**：大输入放 prompt 上部，query 放尾部，复杂多文档输入质量最高提升约 30% | [Anthropic prompting best practices（Long context prompting）](https://docs.claude.com/en/docs/build-with-claude/prompt-engineering/claude-prompting-best-practices) | 长 brief/长文档 | 【事实】文档结构与查询位置影响最终效果。 【推断】WORK_BRIEF.md 可将「必须做的事」（acceptance）置于文末，背景与材料置于文首。 |
| 5.2 | **知识库 = 结构化笔记（structured note-taking / agentic memory）**：笔记存上下文窗口之外，按需拉回；即 NOTES.md / claude-progress.txt 模式 | [Context engineering blog](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)；[Anthropic「Effective harnesses for long-running agents」(2025-11-26)](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents) | 跨会话长工程 | 【事实】Anthropic 长时 agent 方案 = initializer（init.sh + progress 日志 + 首提交）+ 每会话「增量推进 + 留干净状态」。 【推断】dsh-codepunk 的运行根 + progress/ + handoff/ 即此制：每 run 应有「初始器」视角，开工三件事应含「工作区状态快照」文件供后续会话速读。 |
| 5.3 | **Memory 与 Compaction 分工**：compaction 管单次长 run 的连续；memory 管跨 run 复用——**memory 存 workflow lessons，不存 case-specific facts** | [OpenAI Cookbook「Building Reliable Agents with Memory and Compaction」](https://developers.openai.com/cookbook/examples/agents_sdk/building_reliable_agents_memory_compaction) | 知识库设计 | 【事实】dsh-codepunk knowledge/handoffs/ 若沉淀任务结论而非流程经验，会偏离其定位。 【推断】知识库的 lessons/ 模板应强制「经验+可复用规则」字段，案例细节只作示例。 |
| 5.4 | **上下文环（context cycle）**：context engineering 是迭代过程——每轮推理前都在「curate 什么进窗口」；检索与工具是合理安排而非堆料 | [Context engineering blog](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) | 编排设计 | 【事实】「每轮都 curation」而非一次性配好。 【推断】主会话每轮 goal round 的下一步决策即是 curation——把「消息递送前先问要不要」写成显式检查项。 |
| 5.5 | **长上下文非万能**：等更大的窗口不能替代 curation；context pollution 在任意窗口都会发生 | [同上](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)；[Context windows 文档](https://docs.claude.com/en/docs/build-with-claude/context-windows) | 采购/选型决策 | 【事实】1M 窗口模型也已商用（Claude Opus 5 / Sonnet 5 等），但官方仍建议 curation。 【推断】dsh-codepunk 不必依赖大窗口升级解决堆积，优先修剪纪律。 |

### 主题 6 · token 优化工具与惯例

| # | 技巧 | 来源 | 适用场景 | 对 dsh-codepunk 的落地建议 |
|---|---|---|---|---|
| 6.1 | **Prompt 压缩库（决策参考）**：LLMLingua 系最高 20× 压缩率（GPT2-small 等小模型删冗余 token）；LLMLingua-2 任务无关压缩、3–6× 更快；已集成 LangChain/LlamaIndex/Prompt flow | [Microsoft/LLMLingua 仓库](https://github.com/microsoft/LLMLingua) | 高吞吐 API 层 | 【事实】自动 token 级压缩存在且有效，但面向 RAG 推理批量场景。 【推断】对 dsh-codepunk（编排层、语义承重）不引入：自动压缩可能损毁 D0xx 释义等关键语义；以结构修剪 + 手动摘要替代。 |
| 6.2 | **Prompt caching 省成本**：缓存稳定前缀（system prompt、工具定义）避免重复计费；缓存写有 25% markup，第二次命中即回本；**缓存不省窗口占用** | [Anthropic Manage tool context](https://platform.claude.com/docs/en/agents-and-tools/tool-use/manage-tool-context)；[Prompt caching 文档](https://platform.claude.com/docs/en/build-with-claude/prompt-caching)；[Google Gemini Context caching](https://cloud.google.com/vertex-ai/generative-ai/docs/learn/prompts/prompt-design-strategies) | 多轮/多请求场景 | 【事实】若平台层支持，稳定前缀（persona+手册）宜缓存；但缓存 ≠ 压缩。 【推断】dsh-codepunk 关注窗口占用，缓存仅作成本手段；编排上仍按 3.1–3.3 做披露控制。 |
| 6.3 | **工具集精简（minimal viable toolset）**：工具过多→决策歧义→上下文臃肿；工具应自包含、健壮、返回 token 高效的信息 | [Context engineering blog](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) | 工具注册 | 【事实】「人类工程师无法判定用哪个工具，agent 更不行」。 【推断】预设挂在平台层的工具列表不加戏：凡子代理能力已有覆盖的工具，不重复注册/不重复描述。 |
| 6.4 | **Token 意识惯例**：官方 key cap 例（AGENTS.md 32 KiB）；给子代理设「回报 token 预算」（OpenAI session cookbook 的 max_turns=8）；模型感知预算后自管理更好（context awareness） | [AGENTS.md 文档](https://learn.chatgpt.com/docs/agent-configuration/agents-md)；[Claude Code best practices](https://docs.claude.com/en/docs/claude-code/best-practices)；[Context windows 文档](https://docs.claude.com/en/docs/build-with-claude/context-windows) | 预算封顶 | 【事实】行业惯例普遍以「显式字节/token 上限 + 截断声明」管理注入量。 【推断】给主会话同样约束：SPA 消息、巡检回报、交接摘要都写「≤ N token」上限并让接收方知晓截断规则。 |
| 6.5 | **防过设计指令**：明确「clean up 临时文件」「avoid over-engineering，只做被要求的事」可显著减少 agent 自产上下文（冗余文件/抽象） | [Anthropic prompting best practices（Reduce file creation / Overeagerness）](https://docs.claude.com/en/docs/build-with-claude/prompt-engineering/claude-prompting-best-practices) | 编码类子代理 | 【事实】模型有自产临时文件的倾向，一句话防过设计可省。 【推断】engineer/sdet 派遣 prompt 加「不留临时文件、最小 diff」一句，与 write_paths 纪律互补。 |

---

## 二、TOP 落地清单（按对 dsh-codepunk 价值排序）

> 优先对应任务指定的四类：persona 承重规则压缩、SKILL.md 渐进披露、工具结果修剪、会话记忆策略。

1. **【事实】SKILL.md 渐进披露 + 32 KiB 预算红线**（3.1/3.2）：当前 SKILL.md 27.7 KiB、接近 Codex 同级硬上限 32 KiB。正文保持 ≤30 KiB 安全区；新增内容一律进 references/ 按需文件，正文只留路径与一句话用途；承重规则（R1–R14、门闩、合并门）保留，非承重描述迁出。
2. **【事实】子代理只回 1,000–2,000 token 摘要**（2.5）：把「汇报 ≤ 1,500 token + 明细留工作房」写进小队主责派遣提示词的汇报节律段；主会话巡检一律读 summary，不回传原始日志。
3. **【事实】工具结果修剪（tool result clearing）是官方最轻量压缩**（2.3）：小组命令输出默认 head/tail；evidence 保持 `command + exit_code + log_ref` 现状，拒绝整段 stdout 进入交接；主会话收消息前过滤大输出。
4. **【事实】Compaction 提示词先保召回再提精度**（2.2）：文档小组 L1/L2 记忆模板增加「必保留字段清单」（已改文件、未解 bug、关键决策、测试命令、acceptance 状态），压缩丢失关键上下文 = 流程事故。
5. **【事实】Memory 存 workflow lessons、不存 case facts**（5.3）：knowledge/handoffs/ 与 lessons/ 模板强制「经验+可复用规则」输出；单案结论只作示例素材，防止知识库被一次性事实撑爆（符合 R13 归属纪律）。
6. **【事实】长文档置顶、query 置末**（5.1）：WORK_BRIEF.md 把「必须做的事（acceptance）」放文末、「背景/材料」放文首；派遣 prompt 的「任务句」放最后一行，靠后覆盖靠前（AGENTS.md merge 语义同源）。
7. **【事实】示例精选 3–5 个胜过规则堆叠**（1.2/1.1）：persona 每维度若能用 1 对「示范/反例」表达，优先示例替换限定句；新增行为约束先问「能否用示例？」再写条款。
8. **【推断】防过设计与最小 diff 一句话**（6.5）：engineer/sdet 人设加「不留临时文件、只做直接要求的改动」，减少子代理自产上下文，与 write_paths/R8 互补。
9. **【推断】主会话自身防腐（goal 多轮累积）**（2.1/2.4）：goal 自动续行使主会话上下文持续增长；每轮收尾把「已消化巡检记录」压缩为一行结论，避免陈旧消息堆积误导（R12 同源）。
10. **【事实】不引入 API 层自动压缩**（6.1）：LLMLingua 系 libs 面向 RAG 高吞吐，规则/释义类提示被自动删 token 风险高；dsh-codepunk 用结构修剪 + 手动摘要替代，仅借鉴「显式 token/字节预算」思维（2.6/6.4）。
11. **【推断】派遣 prompt 只给「目标+边界+路径」**（3.3）：不在每份派遣里粘整本手册；brief/ 文件作 manifest，prompt 引路径——目前双文件模式已符，防逐步劣化为全文粘贴。
12. **【事实】混合检索腿：元数据信号优先**（3.4）：保留 worktree/分支/目录的语义化命名（rooms/squad-<task_id> 等），它是零成本上下文；新开 worktree 或目录时命名先想信号。

---

## 三、来源表（全部 curl 实测可达，retrieved_at = 2026-08-26 02:50 CST）

| # | 来源 | URL | 类型 |
|---|---|---|---|
| S1 | Anthropic Engineering：Effective context engineering for AI agents（2025-09-29） | https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents | 官方博客 |
| S2 | Anthropic Engineering：Effective harnesses for long-running agents（2025-11-26） | https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents | 官方博客 |
| S3 | Anthropic docs：Context windows | https://docs.claude.com/en/docs/build-with-claude/context-windows | 官方文档 |
| S4 | Anthropic docs：Claude prompting best practices | https://docs.claude.com/en/docs/build-with-claude/prompt-engineering/claude-prompting-best-practices | 官方文档 |
| S5 | Anthropic docs：Manage tool context | https://platform.claude.com/docs/en/agents-and-tools/tool-use/manage-tool-context | 官方文档 |
| S6 | Anthropic docs：Context editing | https://platform.claude.com/docs/en/build-with-claude/context-editing | 官方文档 |
| S7 | Anthropic docs：Claude Code best practices | https://docs.claude.com/en/docs/claude-code/best-practices | 官方文档 |
| S8 | OpenAI docs：Prompt engineering | https://platform.openai.com/docs/guides/prompt-engineering | 官方文档 |
| S9 | OpenAI docs：Building agents（track） | https://developers.openai.com/tracks/building-agents | 官方文档 |
| S10 | OpenAI Cookbook：Building Reliable Agents with Memory and Compaction | https://developers.openai.com/cookbook/examples/agents_sdk/building_reliable_agents_memory_compaction | 官方范例 |
| S11 | OpenAI Cookbook：Context Engineering – Short-Term Memory Management with Sessions | https://developers.openai.com/cookbook/examples/agents_sdk/session_memory | 官方范例 |
| S12 | OpenAI Codex docs：Custom instructions with AGENTS.md | https://learn.chatgpt.com/docs/agent-configuration/agents-md | 官方文档 |
| S13 | Microsoft：LLMLingua 仓库（LLMLingua / LongLLMLingua / LLMLingua-2） | https://github.com/microsoft/LLMLingua | 开源项目 |
| S14 | Google Cloud：Overview of prompting strategies（Gemini Enterprise Agent Platform，URL 仍为 vertex-ai 路径） | https://cloud.google.com/vertex-ai/generative-ai/docs/learn/prompts/prompt-design-strategies | 官方文档 |

**检索过程备注**：web_search 工具在本次会话认证失败（api key 无效），依预定预案全部改为 curl 直连官方一手来源；探测阶段发现 Anthropic 文档已迁至 docs.claude.com / platform.claude.com、OpenAI 文档已迁至 developers.openai.com / learn.chatgpt.com，上表 URL 均为最终实测 200 可达版本。抓取材料暂存 `/tmp/indres/`（原始 md/txt），供工程主责复核时查证。