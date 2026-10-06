# LLM 代理长任务中的思考循环：成因与业界规避机制调研

- 检索日期（retrieved_at）: 2026-10-07
- 支撑决策号：无（外部机制调研简报，不绑定本仓决策号；本简报是反循环规范 `references/anti-loop.md` 的机制来源，出处见文末来源清单）
- 检索时区: Asia/Bangkok
- 调研范围: 外部公开资料（学术论文、框架官方文档、厂商工程博客、开源项目 issue 与社区工具）
- 资料性质说明: 本文区分「事实」（来源明确陈述）与「推断」（本席基于来源的推论），推断段落均标注「推断」。
- 使用限制: 本文只做外部调研，不含本仓实现方案；所有落地建议均为草案，需经工程主责审核后方可进入规范。

## 0. 结论摘要

1. 循环不是单一种故障，而是至少六类可分辨的行为模式，其共同判据是「无新证据的重复动作」；把「失败次数」当唯一护栏会漏掉「每步都成功但零进展」的停滞。
2. 业界已形成分层防线：模型侧提示规则（最弱、可被忽略）、运行时指纹检测（滑动窗口哈希）、预算与步数硬上限（最可靠但最晚触发）、状态外置与计划冻结（从源头减少循环诱因）、人在环熔断（最后兜底）。
3. 硬上限只保证「最终会停」，不保证「早停」：常见默认值（如 10 轮、60 轮）在真实故障中会白烧大量预算后才触发，必须与进展检测组合使用。
4. 上下文污染有量化证据：受污染重试会把每步错误率抬高，SWE-bench Verified 实测级联比约 7.1 倍，清空上下文后重试严格优于在污染上下文里重试。
5. 拦截不等于纠正：只阻断重复调用而不给结构化反馈，模型会停留在原推理循环或换一种同样重复的模式。

## 1. 现象分类

判据口径：以下六类的「可观察特征」均可在轨迹日志上机械判定，不依赖模型自述。

### 1.1 推理自重复（同一论证反复复述）

- 可观察特征: 连续 N 轮推理文本高度相似（如语义相似度或 n-gram 重合度超阈值），且不产生新的工具调用或新证据；常伴随「Let me explain the changes I made…」这类总结性复述而不落到动作上。
- 典型触发条件: 无新外部证据可获取；任务目标本身模糊、缺少可判定的完成条件；解码层面退化为高似然重复；上一步失败但错误被归因为「表述不清」而非「方法不对」。
- 来源证据: SWE-agent issue 971 报告 agent 在第 9 步后反复输出变更说明、9 至 23 步不执行动作而空转，只能人工中止（[SWE-agent#971](https://github.com/SWE-agent/SWE-agent/issues/971)）；解码层面的重复退化有独立研究（[The Curious Case of Neural Text Degeneration](https://arxiv.org/html/1904.09751v2)、[Unlikelihood Training](https://ar5iv.labs.arxiv.org/html/1908.04319)）。

### 1.2 无进展重试（同一思路反复失败后仍重试）

- 可观察特征: 同一命令或同一工具以相同或近似参数连续失败，错误信息实质相同；重试间隔稳定；每轮消耗预算但不改变失败原因。
- 典型触发条件: 把系统性失败误判为偶发失败；缺少「失败两次即换策略」的强制规则；上下文里保留上次失败的错误推理链，使模型自我强化错误归因。
- 来源证据: hermes-agent 反馈「模型被拦后仍停留在原推理循环，或再次尝试同一调用再被拦，或转入另一种同样重复的模式」（[hermes-agent#41490](https://github.com/NousResearch/hermes-agent/issues/41490)）；上下文污染会抬高后续每步错误率（[arXiv:2605.08563](https://arxiv.org/html/2605.08563v1)）。

### 1.3 工具调用风暴（同参数重复调用）

- 可观察特征: 短时间内同一「工具名加序列化参数」指纹重复出现，次数远超任务所需；调用间隔稳定（如每 5 秒一次）；成功率 100%、错误率 0%。
- 典型触发条件: 工具返回空结果或返回「建议继续查找」这类鼓励性文本，模型据此判断需要再查一次；无重复检测、无步数上限、无心跳超时。
- 来源证据: opencode issue 45442 实测 364 次完全相同的 grep 调用（同 pattern、同 path），约 50 分钟、约 5 秒一次，消耗约 184k 输入 token、40k 输出 token、142M 缓存读取 token，父会话全程显示 running 无法察觉（[opencode#45442](https://github.com/anomalyco/opencode/issues/45442)）；社区库明确把「研究型代理重复同一 search 查询」列为首要场景（[tool-loop-guard](https://dev.to/mukundakatta/your-agent-is-calling-that-tool-again-tool-loop-guard-4n9c)）。

### 1.4 验证循环（反复确认已确认的事）

- 可观察特征: 反复执行同一验证动作（重跑测试、重读同一文件、再次请求确认），而验证结论未变化；或验证者与被验证者共享同一上下文，重复得到同一判断。
- 典型触发条件: 验证动作成本低且无缓存；完成判据不明确导致不敢宣布完成；多代理结构中验证者缺少独立证据源。
- 来源证据: MAST 失效分类把「任务验证」列为三大类之一，含「无验证或验证不完整」与「错误验证」两个模式（[arXiv:2503.13657](https://arxiv.org/abs/2503.13657)）；AutoGen 文档展示的「批评者批准才停」模式天然需要终止条件约束，否则反复确认（[AutoGen Termination](https://microsoft.github.io/autogen/stable/user-guide/agentchat-user-guide/tutorial/termination.html)）。

### 1.5 计划-执行纠缠（反复重规划而不执行）

- 可观察特征: 计划文本被反复输出或修订，版本数远多于实际执行步数；每一步都伴随一次新的规划调用；执行产物长期不变化。
- 典型触发条件: 规划者与执行者不分离，或执行者可以随意请求重规划；重规划触发条件过于敏感；计划缺乏冻结机制与完成判据。
- 来源证据: Agent Patterns Catalog 明确把「朴素的每次出错就重规划」列为抖动（thrash）反模式：代理重规划、失败、在新计划上再次重规划，始终没有进展（[Replan on Failure](https://www.agentpatternscatalog.org/patterns/replan-on-failure/)）；长期任务中的「纠缠上下文」会让局部错误在多个子任务间传播，使恢复成本高昂（[arXiv:2601.07577](https://arxiv.org/abs/2601.07577)）。

### 1.6 上下文污染循环（错误结论被反复引用放大）

- 可观察特征: 早先的错误结论或错误端点在后文被反复引用，成为后续决策前提；重试轨迹保留全部失败尝试；同一错误随轮次被复述并被当成事实。
- 典型触发条件: 失败尝试保留在上下文中并作为后续输入；缺少压缩、工具结果清理或干净重启机制；上下文接近窗口上限时发生截断。
- 来源证据: 受污染重启模型给出闭式结论，实测 SWE-bench Verified 上级联比约 7.1 倍，忽略污染会高估 pass@3 达 17.4 个百分点（98.6% 对 81.2%），而「清空上下文后再重试」严格减少所需尝试数（[arXiv:2605.08563](https://arxiv.org/html/2605.08563v1)）；Anthropic 指出上下文是有限资源、存在 context rot，长任务需压缩、结构化笔记与子代理隔离（[Effective context engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)）；另有反模式指出压缩会把硬约束逐轮稀释为软建议（[Guardrail Erosion Through Compaction](https://www.agentpatternscatalog.org/patterns/guardrail-erosion-through-compaction/)）。

## 2. 业界机制清单

评级口径（可迁移性）: 高 = 与本仓多代理工作流可直接对齐且实现成本低；中 = 需要改造运行时或引入新组件；低 = 与当前架构契合度有限或收益不确定。代价列只写副作用，不重复原理。

| 编号 | 机制名 | 原理 | 适用层 | 代价与副作用 | 可迁移性 |
| --- | --- | --- | --- | --- | --- |
| M1 | 进展预言机（progress oracle） | 定义一个与目标单调相关的分数（如测试通过率），每步观测其变化，分数不升即视为停滞 | 运行时 | 预言机必须廉价且无副作用，否则检测成本超过任务本身 | 高 |
| M2 | 动作指纹滑动窗口 | 对（工具名，规范化参数哈希）建滚动窗口，窗口内同指纹出现次数超阈值即触发 | 运行时 | 只识别结构相同调用，语义相似但参数不同的循环会漏检 | 高 |
| M3 | 类型化拒绝反馈 | 触发时返回结构化拒绝（错误码、模式、观测统计），迫使模型在下一轮消费该反馈 | 工具层 | 拒绝文案质量决定效果，劣质文案会让模型原地打转 | 高 |
| M4 | 渐进升级（警告到阻断） | 先注入系统提示警告，再建议换策略，仍重复则拒绝执行 | 运行时 | 升级阈值需调参，过激会打断合理重试 | 高 |
| M5 | 步数与迭代硬上限 | 对工具调用数或循环轮数设数值上限，命中即终止并返回最优部分结果 | 运行时 | 上限过高等于没设，过低会截断正当长任务 | 高 |
| M6 | 时间与预算上限 | 以挂钟时长、token 用量或费用为上限终止运行 | 运行时 | 只在预算耗尽时触发，属于兜底而非检测 | 高 |
| M7 | 停止谓词钩子 | 每步后运行程序化谓词，返回继续、成功停止或失败停止（含目标达成、预算耗尽、错误、停滞） | 运行时 | 谓词复杂度上升后本身可能出错，需要测试覆盖 | 高 |
| M8 | 相同失败两次即换策略 | 同一失败模式出现两次，强制要求更换手段，禁止第三次重试 | 提示层加运行时 | 对偶发失败且必然需要重试的场景会误伤 | 高 |
| M9 | 状态外置与执行状态账本 | 把运行状态确定性记录在模型外（观测过什么、改过什么、试过什么），每步前校验，有效结果复用、过期观测拒绝 | 运行时 | 失效规则需逐类资源手写，成本落在工程侧 | 高 |
| M10 | 结构化笔记与外部记忆 | 代理把进度、决策、未解问题写入外部文件，上下文重置后读回续做 | 提示层加工具层 | 笔记质量决定续做质量，缺乏维护会积累过期信息 | 高 |
| M11 | 压缩与工具结果清理 | 接近窗口上限时高保真总结并重开窗口，保留架构决策与未解问题，清理旧工具原始结果 | 运行时 | 过度压缩会丢失事后才显重要的细节，硬约束会被稀释 | 高 |
| M12 | 计划冻结与重规划触发器 | 计划先冻结执行，只有明确触发条件（工具报错、观测与假设矛盾、观察者异议）才回到规划者并附带失败上下文 | 编排层 | 触发过敏感导致重规划抖动，新旧计划兼容逻辑复杂 | 高 |
| M13 | 规划者与执行者分离 | 规划与执行使用不同角色与不同上下文作用域，执行者不得自行重规划 | 编排层 | 需要额外的编排结构与上下文隔离成本 | 中 |
| M14 | 检查清单驱动 | 把任务在编写期拆成有序可校验检查点，运行按到达的检查点计分，后续检查点以前序为门 | 评估层加编排层 | 每任务需人工维护检查点，清单过期比单一判定更差 | 中 |
| M15 | 自我批评轮次上限 | 限定自我反馈与精炼的轮数，避免在收益递减后继续空转 | 提示层 | 上限过紧会放弃仍可改进的输出 | 中 |
| M16 | 解码多样性强制 | 通过采样参数或候选多样化降低高似然重复 | 模型调用层 | 提升多样性可能牺牲正确性，需要任务级验证 | 低 |
| M17 | 停滞检测（输出哈希与进度指针） | 对关键产物取哈希、对进度指针取快照，哈希与指针连续不变即判停滞 | 运行时 | 产物天然不变的任务会误报，需要任务特定口径 | 中 |
| M18 | 人在环熔断 | 在风险边界暂停，要求人工批准或拒绝后再继续 | 编排层 | 审批疲劳会把批准变成橡皮图章，异步审批会阻塞循环 | 中 |
| M19 | 子代理上下文隔离 | 子代理在独立窗口工作，只回传精炼摘要，隔离失败轨迹 | 编排层 | 摘要会丢信息，子代理卡住时父会话若无法观测则难以止损 | 高 |
| M20 | 心跳与卡死可观测 | 父会话可见子代理最后活动时间与进展标记，可中止卡住的子代理 | 运行时 | 需要额外的运行时埋点与状态上报 | 高 |
| M21 | 工具白名单豁免 | 对轮询、状态检查这类天然重复的工具豁免循环判定 | 工具层 | 豁免范围过宽会留出循环通道 | 高 |
| M22 | 提示层反循环规则 | 在系统提示中写入「无新证据的重复动作视为空转」等硬性条款 | 提示层 | 纯提示规则是建议性的，模型在最卡的时候最容易忽略 | 中 |

补充事实（用于校准上述机制的真实默认值）：

- 步数上限: OpenAI Agents SDK 的 Runner 在 run、run_sync、run_streamed 三个入口都带 max_turns 参数，默认取常量 DEFAULT_MAX_TURNS，源码中该常量为 10；超限抛 MaxTurnsExceeded 异常，可通过 error_handlers 以 error_kind 为 max_turns 拦截；传 None 可关闭上限（[run.py](https://raw.githubusercontent.com/openai/openai-agents-python/main/src/agents/run.py)、[run_config.py](https://raw.githubusercontent.com/openai/openai-agents-python/main/src/agents/run_config.py)、[官方 ref](https://openai.github.io/openai-agents-python/ref/run/)）。
- 图递归上限: LangGraph 在到达停止条件前超过最大步数会抛 GRAPH_RECURSION_LIMIT，官方将其定性为常由无限循环引起（[LangGraph 错误页](https://docs.langchain.com/oss/python/langgraph/errors/GRAPH_RECURSION_LIMIT)）；社区提案把检测下沉到路由层，检查最近 3 条 AI 消息的工具调用，若语义相同则提前抛错（[langgraph#6889](https://github.com/langchain-ai/langgraph/pull/6889)，该提案状态为 closed 且未合并）。
- 终止条件族: AutoGen 提供 11 种内置终止条件，含最大消息数、最大 token 用量、超时、外部终止、函数调用终止、功能终止等，条件是接收消息增量序列的可调用对象，可用与或组合，每次运行后自动重置（[AutoGen Termination](https://microsoft.github.io/autogen/stable/user-guide/agentchat-user-guide/tutorial/termination.html)）；旧版还提供「同一发送者连续自动回复超阈值即终止」的参数（[AutoGen 0.2](https://microsoft.github.io/autogen/0.2/docs/tutorial/chat-termination/)）。
- 指纹去重实现细节: 以 SHA256（工具名加序列化参数）作签名并维护滑动窗口，模式含精确重复（默认阈值 3）、乒乓模式（两指纹交替）、全局熔断，升级路径为警告、回退建议、阻断，且为轮询类工具设豁免白名单（[hermes-agent#481](https://github.com/NousResearch/hermes-agent/issues/481)）；同类实现明确其边界：只检测结构完全相同的调用，「python」与「python programming language」不会触发（[tool-loop-guard](https://dev.to/mukundakatta/your-agent-is-calling-that-tool-again-tool-loop-guard-4n9c)）。
- 升级阶梯实现参考: 有运行时把「同策略重试上限」与「先提示后终止」做成夹逼关系，保证任何终止之前必先有一次提示（[tinyagents NoProgressTracker](https://docs.rs/tinyagents/latest/tinyagents/harness/no_progress/struct.NoProgressTracker.html)）；另有框架区分「按代理的工具指纹检测」与「会话级升级检测」（记录动作与进展标记并给出恢复动作建议，含无进展判定）（[PraisonAI 循环检测](https://praison.ai/docs/features/doom-loop-detection)）。
- 效果数据: 把执行状态确定性推导并替代原始轨迹放进提示，可使 SWE-bench Verified 全 500 例 Pass@1 从 56.2% 提升到 64.2%，总成本下降 28.9%（[Execution-State Ledger](https://www.agentpatternscatalog.org/patterns/execution-state-ledger/)）。
- 成本量级参考: 代理约消耗聊天交互 4 倍 token，多代理系统约 15 倍；token 用量单独解释某检索基准 80% 的性能方差（[Anthropic 多代理研究系统](https://www.anthropic.com/engineering/multi-agent-research-system)）。

## 3. 提示与规则层面的可执行条款草案

以下条款可直接抄入工程规范（角色卡、系统提示、门闩规则、交接包模板）。条款按「可机械判定」优先排序。

1. 同一失败模式出现 2 次，必须更换手段，不得重复第三次；第三次重试须在记录中说明与前两次的差异点，否则视为空转。
2. 每一步必须产出新证据（新文件内容、新命令输出、新测试结果、新外部来源）；无新证据的重复动作一律计为空转步。
3. 连续 3 步空转即触发自检：写出「当前假设、已证伪项、下一步不同做法」三行，然后继续；不得直接重试。
4. 同参数工具调用在同一任务内不得超过 2 次；第 3 次必须改变参数、改变工具或改变策略，并在输出中写明改变了什么。
5. 遇到循环立即退出当前思路重新开始：放弃当前方案，回到上一个有证据支撑的状态点，用不同方法重做，不得在坏路径上修补。
6. 计划一经确认即冻结；只有出现「工具报错、观测与计划假设矛盾、验证者明确反对」三类触发条件之一，才允许重规划，且重规划必须附带失败上下文。
7. 重规划次数上限为 2 次；达到上限仍无进展时，停止重规划，输出当前最优部分结果与阻塞点，升级给上层。
8. 验证动作必须可缓存：同一验证目标在输入未变化时复用上次结论，不得重复执行；重复验证须说明「自上次验证以来发生了什么变化」。
9. 自我批评与精炼轮次上限为 2 轮；第 2 轮后仍无实质改进，立即定稿并标注未解风险，不得继续打磨。
10. 禁止在上下文中引用已被证伪的结论；发现引用需立即标注「已证伪」并给出证伪证据，不得作为后续推理前提。
11. 上下文接近上限时先清理旧工具原始结果，再考虑压缩；压缩后必须复核硬约束（禁止项、授权边界）原文仍在且未被改写。
12. 卡住超过约定时长（如单步超过 10 分钟无新证据）必须上报，不得静默重试；上报内容含已试手段、失败证据、当前阻塞点。
13. 不得用「我已完成」替代可核验证据；声称完成必须同时给出验证命令与输出，或给出无法验证的明确理由。
14. 交接包中必须写明「已证伪的路径」，防止接手方重复已失败的尝试。

## 4. 可观测指标与阈值建议

指标口径均基于轨迹日志，可离线复算。

| 指标 | 定义 | 建议阈值 | 命中后的动作 |
| --- | --- | --- | --- |
| 工具调用指纹重复率 | 窗口内最高频指纹出现次数除以窗口长度 | 窗口 10 次内同指纹出现 3 次即告警 | 注入警告；第 4 次阻断该调用 |
| 乒乓比 | 窗口内两指纹交替轮数 | 交替 3 轮即告警 | 提示两者互斥，要求择一并说明依据 |
| 无新证据步数 | 连续未产生新证据的步数 | 连续 3 步告警，连续 5 步强制换策略 | 写自检三行或升级上层 |
| 进度指针变化 | 关键产物哈希或进度指针是否变化 | 连续 4 步无变化即判停滞 | 停止当前路径，回退到最近有效状态点 |
| 相同失败重复次数 | 同一失败指纹（命令加错误摘要）出现次数 | 2 次即强制换策略 | 禁止第三次相同重试 |
| 单位产出耗步数 | 完成一个子任务所用步数 | 超过该任务类型历史中位数的 2 倍即告警 | 暂停并复盘方法 |
| 重规划次数与执行步数比 | 重规划次数除以实际执行步数 | 比值大于 1 即判定计划执行纠缠 | 冻结计划，强制执行若干步后才允许重规划 |
| 验证动作重复率 | 同一验证目标在输入未变时被重复执行的比例 | 大于 0 即视为浪费 | 强制走验证缓存 |
| 预算消耗速率 | 单位时间内 token 或费用消耗 | 超过任务类型基线的 3 倍即告警 | 降级模型或请求人工确认 |
| 停滞预算 | 允许的空转步总量 | 建议设为总步数预算的 20% | 耗尽即安全停机并输出结构化诊断 |

阈值设定原则（推断）: 阈值应随任务类型分档，读操作与写操作分别设定；先以告警模式运行一段时间收集误报率，再切换到阻断模式。

## 5. 反例与局限

必要重复与循环的区分判据:

| 场景 | 是否必要重复 | 区分判据 |
| --- | --- | --- |
| 等待外部状态就绪的轮询 | 是 | 属于白名单工具，且状态指针在推进或时间窗口明确 |
| 并发失败后的重试 | 是 | 失败原因不同（错误指纹变化），或退避策略在变化 |
| 修复后重跑测试 | 是 | 被测输入已变化（代码或数据哈希变化） |
| 同一测试连续重跑且输入未变 | 否 | 输入哈希未变、结论未变 |
| 同一搜索词重复检索 | 否 | 参数指纹相同、结果集相同 |
| 参数逐步收窄的探索式检索 | 是 | 参数指纹不同、结果集有新增 |
| 同一命令在失败后原样重试 | 否 | 错误指纹相同且无策略变化 |
| 编译类长耗时命令的重复调用 | 视情况 | 需按工具设独立上限，不能套用统一阈值 |

已知局限与误杀风险:

1. 结构指纹会漏检语义相似的循环，例如同义改写参数的反复检索；反之若改用语义相似度，误报率上升且难以预测（[tool-loop-guard](https://dev.to/mukundakatta/your-agent-is-calling-that-tool-again-tool-loop-guard-4n9c)）。
2. 轮询、状态检查、长耗时编译天然重复，必须白名单豁免，否则循环检测本身成为故障源（[hermes-agent#481](https://github.com/NousResearch/hermes-agent/issues/481)）。
3. 硬上限只在预算耗尽后触发，属于止损不属于检测；上限过高等于没设（[Stop Agent Loops With a No-Progress Guard](https://viralruparel.com/blog/agent-loop-no-progress-detection-guard)、[Step Budget](https://www.agentpatternscatalog.org/patterns/step-budget/)）。
4. 进展预言机在探索性任务上难以定义；缺少预言机时只能用行为新颖性作代理指标，信号更弱（[Claude Lab 停滞检测](https://claudelab.net/en/articles/api-sdk/claude-agent-no-progress-stagnation-detection-action-fingerprint-guard)）。
5. 只阻断不反馈会失效：模型被拦后仍停留在原循环，需要结构化反馈与渐进干预（[hermes-agent#41490](https://github.com/NousResearch/hermes-agent/issues/41490)）。
6. 提示层规则是建议性的，模型最卡的时候最容易忽略，必须由运行时机制兜底（[Typed Tool-Loop Detector](https://www.agentpatternscatalog.org/patterns/typed-tool-loop-detector/)）。
7. 压缩会稀释硬约束，安全条款必须钉在不可压缩区域并逐轮重新注入（[Guardrail Erosion Through Compaction](https://www.agentpatternscatalog.org/patterns/guardrail-erosion-through-compaction/)）。
8. 检查清单存在被「刷分」的风险：代理可以只收集中间检查点而不真正完成任务；且清单需要随环境维护，过期清单比单一判定更差（[Checklist Partial Credit Scoring](https://www.agentpatternscatalog.org/patterns/checklist-partial-credit-scoring/)）。
9. 人在环会因审批疲劳退化为橡皮图章，且异步审批阻塞循环（[Human-in-the-Loop](https://www.agentpatternscatalog.org/patterns/human-in-the-loop/)）。
10. 多代理隔离虽能降低污染，但父会话若无法观测子代理状态，卡死会长时间无人发现（[opencode#45442](https://github.com/anomalyco/opencode/issues/45442)）。
11. 失效分类研究提示：步骤重复在受测多代理系统中出现率约 15.7%，未识别任务完成约 12.4%，属于高发而非边缘情况（[arXiv:2503.13657](https://arxiv.org/abs/2503.13657)）。

## 6. 来源清单（均于 2026-10-07 检索）

1. [Why Retrying Fails: Context Contamination in LLM Agent Pipelines](https://arxiv.org/html/2605.08563v1) — arXiv:2605.08563v1，2026-05-08，上下文污染重启模型与干净重启优势，含 SWE-bench Verified 实测。retrieved_at: 2026-10-07
2. [Building effective agents](https://www.anthropic.com/engineering/building-effective-agents) — Anthropic，2024-12-19，代理需每步取地面真值、需停止条件与护栏。retrieved_at: 2026-10-07
3. [Effective context engineering for AI agents](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) — Anthropic，2025-09-29，context rot、压缩、结构化笔记、子代理隔离。retrieved_at: 2026-10-07
4. [How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) — Anthropic，2025-06-13，长任务状态与误差累积、成本量级、评估维度。retrieved_at: 2026-10-07
5. [Termination — AutoGen](https://microsoft.github.io/autogen/stable/user-guide/agentchat-user-guide/tutorial/termination.html) — 11 种终止条件与组合方式。retrieved_at: 2026-10-07
6. [Terminating Conversations Between Agents — AutoGen 0.2](https://microsoft.github.io/autogen/0.2/docs/tutorial/chat-termination/) — 连续自动回复阈值终止。retrieved_at: 2026-10-07
7. [OpenAI Agents SDK run.py](https://raw.githubusercontent.com/openai/openai-agents-python/main/src/agents/run.py) 与 [run_config.py](https://raw.githubusercontent.com/openai/openai-agents-python/main/src/agents/run_config.py)、[官方 ref](https://openai.github.io/openai-agents-python/ref/run/) — max_turns 默认 10、超限抛 MaxTurnsExceeded、可关闭。retrieved_at: 2026-10-07
8. [GRAPH_RECURSION_LIMIT — LangChain 文档](https://docs.langchain.com/oss/python/langgraph/errors/GRAPH_RECURSION_LIMIT) — 图递归上限与无限循环定性。retrieved_at: 2026-10-07
9. [langgraph PR 6889](https://github.com/langchain-ai/langgraph/pull/6889) — 最近 3 条 AI 消息工具调用语义相同的提前检测提案（未合并）。retrieved_at: 2026-10-07
10. [hermes-agent issue 481](https://github.com/NousResearch/hermes-agent/issues/481) — SHA256 指纹加滑动窗口、精确重复与乒乓模式、警告到阻断升级、工具豁免。retrieved_at: 2026-10-07
11. [hermes-agent issue 41490](https://github.com/NousResearch/hermes-agent/issues/41490) — 拦截后缺少结构化反馈导致模型原地打转。retrieved_at: 2026-10-07
12. [opencode issue 45442](https://github.com/anomalyco/opencode/issues/45442) — 364 次相同调用约 50 分钟的真实事故与预算损失。retrieved_at: 2026-10-07
13. [SWE-agent issue 971](https://github.com/SWE-agent/SWE-agent/issues/971) — 反复复述而不执行动作的空转循环。retrieved_at: 2026-10-07
14. [tool-loop-guard 介绍](https://dev.to/mukundakatta/your-agent-is-calling-that-tool-again-tool-loop-guard-4n9c) — 结构指纹实现与漏检边界、轮询误杀。retrieved_at: 2026-10-07
15. [tinyagents NoProgressTracker](https://docs.rs/tinyagents/latest/tinyagents/harness/no_progress/struct.NoProgressTracker.html) — 无进展升级阶梯与先提示后终止的夹逼设计。retrieved_at: 2026-10-07
16. [PraisonAI 循环检测](https://praison.ai/docs/features/doom-loop-detection) — 按代理工具指纹检测与会话级升级检测双层结构。retrieved_at: 2026-10-07
17. [Claude Lab: 无进展停滞检测](https://claudelab.net/en/articles/api-sdk/claude-agent-no-progress-stagnation-detection-action-fingerprint-guard) — 成功但无进展的停滞、进展预言机、三种停滞形态。retrieved_at: 2026-10-07
18. [Why Do Multi-Agent LLM Systems Fail?](https://arxiv.org/abs/2503.13657) — MAST 失效分类，14 个模式 3 大类，含步骤重复与验证类失效的出现率。retrieved_at: 2026-10-07
19. [Beyond Entangled Planning](https://arxiv.org/abs/2601.07577) — 纠缠上下文导致局部错误传播、子任务解耦降低 token 消耗。retrieved_at: 2026-10-07
20. [Replan on Failure](https://www.agentpatternscatalog.org/patterns/replan-on-failure/) — 重规划触发条件与抖动反模式。retrieved_at: 2026-10-07
21. [Typed Tool-Loop Detector](https://www.agentpatternscatalog.org/patterns/typed-tool-loop-detector/) — 派发边界否决、五类模式与每工具上限、类型化拒绝。retrieved_at: 2026-10-07
22. [Step Budget](https://www.agentpatternscatalog.org/patterns/step-budget/) 与 [Unbounded Loop](https://www.agentpatternscatalog.org/patterns/unbounded-loop/) — 步数预算与无界循环反模式。retrieved_at: 2026-10-07
23. [Stop Hook](https://www.agentpatternscatalog.org/patterns/stop-hook/) — 每步后的程序化停止谓词，含停滞判定。retrieved_at: 2026-10-07
24. [Execution-State Ledger](https://www.agentpatternscatalog.org/patterns/execution-state-ledger/) — 执行状态外置的 Pass@1 与成本数据。retrieved_at: 2026-10-07
25. [Guardrail Erosion Through Compaction](https://www.agentpatternscatalog.org/patterns/guardrail-erosion-through-compaction/) — 压缩稀释硬约束与钉住条款的纠正。retrieved_at: 2026-10-07
26. [Human-in-the-Loop](https://www.agentpatternscatalog.org/patterns/human-in-the-loop/) — 审批疲劳与异步阻塞。retrieved_at: 2026-10-07
27. [Checklist Partial Credit Scoring](https://www.agentpatternscatalog.org/patterns/checklist-partial-credit-scoring/) — 检查点刷分风险与维护成本。retrieved_at: 2026-10-07
28. [Stop Agent Loops With a No-Progress Guard](https://viralruparel.com/blog/agent-loop-no-progress-detection-guard) — 硬上限只保证结束不保证早停。retrieved_at: 2026-10-07
29. [The Curious Case of Neural Text Degeneration](https://arxiv.org/html/1904.09751v2) 与 [Neural Text Degeneration with Unlikelihood Training](https://ar5iv.labs.arxiv.org/html/1908.04319) — 解码层重复退化的模型侧根因。retrieved_at: 2026-10-07
30. [Self-Refine](https://arxiv.org/html/2303.17651v2) — 自我反馈精炼范式，自我批评轮次上限的学术基础。retrieved_at: 2026-10-07
31. [Don't Build Multi-Agents](https://cognition.com/blog/dont-build-multi-agents) — 并行代理隐式决策冲突与上下文共享问题。retrieved_at: 2026-10-07
32. [ReAct: Synergizing Reasoning and Acting](https://arxiv.org/abs/2210.03629) — 推理与行动交替的基础范式。retrieved_at: 2026-10-07

## 7. 面向 dsh-codepunk 的优化建议（草案）

优先级从高到低；每条含问题、机制、落地位置建议、验收方式。落地位置只给建议指向，具体改动由工程主责决策。

1. 问题: 代理自述「在做」但连续多轮无新证据，属于最隐蔽也最高发的空转。机制: 无新证据步数计数加自检三行强制输出。落地位置建议: 岗位规则与交接包模板中的「每步须产出新证据」条款，巡检清单增加空转步计数项。验收方式: 人为构造一个无进展任务，代理在连续 3 步无新证据时必须输出自检三行，连续 5 步必须换策略或上报。
2. 问题: 同一命令或同一工具以相同参数反复失败后仍重试，白烧预算。机制: 相同失败指纹出现 2 次即强制换策略，第 3 次相同重试由运行时拒绝并返回结构化反馈。落地位置建议: 工具派发层加失败指纹计数与类型化拒绝。验收方式: 注入一个必然失败的命令，观察第 3 次相同调用被拒绝且返回含原因与替代建议的反馈。
3. 问题: 重复调用只被拦截却不改变模型行为，模型换一种方式继续重复。机制: 类型化拒绝反馈加渐进升级（警告、建议、阻断三段）。落地位置建议: 工具层拒绝文案模板与运行时升级阈值配置。验收方式: 被阻断后下一轮必须出现策略差异（参数、工具或方法三者至少一项变化），在轨迹中可机械核验。
4. 问题: 计划反复修订而不执行，计划与执行纠缠。机制: 计划冻结加重规划触发条件白名单，重规划次数上限 2 次。落地位置建议: 小队主责的计划模板与交接包字段。验收方式: 统计重规划次数与执行步数之比，超过 1 即判失败并复盘。
5. 问题: 失败尝试留在上下文中被反复引用放大。机制: 上下文压缩与工具结果清理，失败轨迹只保留结论与证伪证据；硬约束钉在不可压缩区域逐轮重注入。落地位置建议: 交接包与进度文件格式约定（进度记录只写结论与证伪项，不写全量日志）。验收方式: 抽查交接包，确认包含「已证伪路径」且不含被证伪结论的原始引用。
6. 问题: 子代理或后台任务卡死时无人察觉。机制: 心跳与最后活动时间上报加停滞预算，耗尽即安全停机并输出结构化诊断。落地位置建议: 运行时状态上报与巡检职责。验收方式: 构造卡死子代理，父会话在规定时间内能观测到并中止。
7. 问题: 硬上限设置不合理导致早停或晚停。机制: 分档步数预算（读操作与写操作分别设定）加停滞预算占总预算约两成的比例约束。落地位置建议: 任务模板中的预算字段。验收方式: 统计单位产出耗步数分布，验证正常任务不被截断且异常任务提前止损。
8. 问题: 循环检测误杀合理重复，例如轮询、并发重试、修复后重跑测试。机制: 工具白名单豁免加「输入哈希是否变化」判据，先告警模式运行再切换阻断。落地位置建议: 检测规则的豁免清单与灰度开关。验收方式: 用轮询与重跑测试两类正当场景回归，确认零误杀后再启用阻断。

## 8. 未决问题

1. 语义相似循环（同义改写参数的反复检索）在工程上尚无低成本可靠检测方案，现有库明确不做，属已知盲区。
2. 进展预言机在探索性任务上的定义方式缺少共识，本报告给出的代理指标（行为新颖性）信号强度未经量化验证。
3. 阈值建议基于来源中的工程经验与个别实测数据，未在本仓负载上校准，需要先以告警模式采集基线。
