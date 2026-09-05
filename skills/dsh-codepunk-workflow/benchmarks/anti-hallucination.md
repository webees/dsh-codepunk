# 开发方向避免 LLM 幻觉：成因、技术栈与 skill/工具调研简报

> 支撑决策号：D077（反幻觉）

> 委托方：run-lead（dsh-codepunk 六阶段多智能体开发流程预设 · 防幻觉纪律强化）
> 调研岗：ind-res（唯一联网岗）
> 检索窗口：2026-08-26 03:24（UTC+7）；全部 URL 之 retrieved_at = 2026-08-26
> 检索方式透明说明：本会话 `web_search`（api key 无效，Authentication Fails）/`web_fetch` 通道不可用，已全部改用 **curl 直连**：arXiv API（export.arxiv.org，元数据+摘要一核验）、Anthropic 官方站（docs/engineering）、OpenAI cookbook（GitHub raw）、GitHub REST API 与 raw.githubusercontent。若 `curl` 也失败则：anthropic.com/engineering 之 `reducing-hallucinations*` 两篇旧工程文已从 sitemap 消失（404，疑似下线，未纳入）；openai.com/index/planning-for-ai-agents 返回 403、Codex 官方 best-practices 页 404/连接失败（未纳入，不以记忆转述其内容）。
> 证据标注：【事实】= 来源页可直接核对；【推断】= 基于事实对 dsh-codepunk 的映射/推导。
> ⚠️ 边界声明：以下为机制/纪律借鉴，不代码抄袭；具体落地须经 run-lead 审定后由文档小组写入正式规范，ind-res 不代替决策。

---

## 0. 一页速览

- **幻觉不是单一故障**：成因分四类——知识缺陷、上下文误用/冲突、解码采样、验证缺失；业界共识是「token 生成瞬间无法根治，只能靠架构与流程在输出前后拦截修复」【事实】（SoloDawn 明言，见 §1）。
- **官方防幻觉三件套**（Anthropic 文档）：允许说「我不知道」、事实断言用直接引文接地、用引文验证并**找不到引文就撤回主张**【事实】。
- **最强可落地纪律**：Claude Code 官方「**给 agent 一个能运行的检查**」（tests/build/screenshot），让「完成」变成可执行验证而不仅是观感【事实】。
- **多智能体场景**：独立子代理交叉核对（debate/交叉验证）+ 全程证据链 + 不可变审计日志，是目前防幻觉工程化的主要方向【事实/推断】。

---

## 1. 幻觉成因清单

| # | 成因类别 | 细分 | 来源（论文/文档级） |
|---|---|---|---|
| 1 | **知识缺陷（intrinsic）** | 训练语料错漏/过时、模型参数化记忆不完整 → 表达「知识库外」的内容 | Ji et al. 2022「Survey of Hallucination in NLG」arXiv:2202.03629；Huang et al.「A Survey on Hallucination in LLMs」arXiv:2311.05232【事实】 |
| 2 | **上下文误用与知识冲突（extrinsic）** | ① context-memory：上下文与参数记忆冲突；② inter-context：多段上下文互相冲突；③ intra-memory：记忆内部不一致。噪声/矛盾信息环境下 LLM 信任度下降 | 「Knowledge Conflicts for LLMs: A Survey」arXiv:2403.08319（摘要明列三类冲突）【事实】 |
| 3 | **解码/采样的非确定性** | 贪婪解码单个推理路径；采样引入概率性错误分支 | Self-Consistency arXiv:2203.11171、SelfCheckGPT arXiv:2303.08896（「采样多路径，不一致即信号」的前提正是单路径可错）【事实】 |
| 4 | **推理跳步与验证缺失** | 表面流畅但逻辑链有洞；无验证环节时把「看起来对」当「就是对的」 | Chain-of-Verification arXiv:2309.11495（先起草→规划核查问题→独立作答→终稿）；Anthropic docs「Reduce hallucinations」Advanced techniques【事实】 |
| 5 | **诱因放大** | 用户施压/请求过载/「包装成确定事实」的推断 | Buddhist-method skill 的 Upekkhā 原则（用户压力下屈服）；Linghun「不把没有证据的推断包装成确定事实」【事实】 |

> RAGTruth arXiv:2401.00396 实测量级：**接了 RAG 仍会产生与检索内容矛盾/无支撑的表述**——证明「有检索 ≠ 无幻觉」，接地必须显式化【事实】。
> 最新综合综述「LLMs Hallucination: A Comprehensive Survey」arXiv:2510.06265（2025-10，仅核验元数据未深读正文，供延伸）。

---

## 2. 防幻觉技术清单

### 2.1 证据锚定 / RAG 接地（grounding & citation）

| 技巧 | 来源 | 适用 | 对 dsh-codepunk 落地建议 |
|---|---|---|---|
| 事实断言用**直接引文**接地（长文档先摘引文再作答；>20k tokens 场景） | Anthropic docs: Reduce hallucinations【事实】 | 需求确认/巡检读交接文档时 | 【推断】六阶段所有「引用他人结论」的汇报（summary/progress/known_issues）改为「引文+出处」格式，禁止只凭印象转述工作房文档 |
| **引文验证 + 找不到引文即撤回主张** | Anthropic docs【事实】；research-mode skill 三约束之「每条主张必须引用，无来源主张自动作废」【事实】 | 交接包、评分评语 | 【推断】在 D075 消息纪律上叠加「无出处事实主张 = 无效声明」，写入提交/交接检查单 |
| 检索→粘贴**真实文本片段**到上下文（而非让模型凭记忆复述） | Anthropic: Effective context engineering for AI agents【事实】 | 需要外部事实的巡检/规划 | 【推断】巡检主会话只粘贴被引用文件的关键片段供核对，与 D074「拒绝整段 stdout」互补：D074 控量，本条控真 |
| 子代理独立检索 + Lead 汇总 + **专用 CitationAgent 归因** | Anthropic: Multi-agent research system（subagent 独立 web search→interleaved thinking→CitationAgent 标注引用位置）【事实】 | 多小组并行检索类任务 | 【推断】若某阶段允许联网调研，结论须附来源位置标注；与「交接包 artifact_index.md」合并为「结论→证据文件→行号」链 |
| 无引用来源时不编造，回退「未找到」 | research-mode 来源级联：本地文件→搜索 snippet→全文→学者API，逐级降级【事实】 | 事实查询型任务 | 【推断】证据缺失时输出「未证实+缺证据路径」，而非编一个「常见做法」 |

### 2.2 自我核查（self-verification / reflection）

| 技巧 | 来源 | 适用 | 对 dsh-codepunk 落地建议 |
|---|---|---|---|
| Chain-of-Verification：起草→规划核查问题→**独立**回答→终稿 | arXiv:2309.11495（CoVe，Meta）【事实】 | 需求确认阶段的规格陈述 | 【推断】需求规格产出后加一步「自查问答：每条规格是否可被现有材料回答」，不可答即退回澄清 |
| 采样一致性：多采样取多数/一致性为真信号（Self-Consistency / SelfCheckGPT） | arXiv:2203.11171 / 2303.08896（黑盒、零资源、无需外部库）【事实】 | 验收结论、评分 | 【推断】对「sdet evidence pass」等高危结论可做 2-3 次独立采样比对，不一致即标黄复查；成本低、无需接入外部事实库 |
| Self-Refine / Reflexion 迭代反馈与失败记忆 | arXiv:2303.17651；2303.11366（语言反馈入 episodic memory）【事实】 | 长任务漂移 | 【推断】复盘阶段（评分公式）把「失败教训」显式写入下次任务记忆，与 Linghun「受控记忆 candidate-first 确认流」（防未经确认事实进长记忆）配套【事实】 |
| ⚠️ **纯内在自我纠错并不可靠**：无外部反馈/工具时自纠错无效甚至变差 | arXiv:2310.01798「LLMs Cannot Self-Correct Reasoning Yet」【事实】 | 所有自查环节 | 【推断】自查只作第一道，不作为完成依据；任何「修正」必须绑定可验证证据（命令/测试/来源），否则不采信——这正是「sdet 证据 pass ≠ 可解散」的学理支撑 |

### 2.3 事实校验工具（搜索确认 / 代码执行 / 测试驱动）

| 技巧 | 来源 | 适用 | 对 dsh-codepunk 落地建议 |
|---|---|---|---|
| **给 agent 一个能运行的检查**：tests/build/screenshot，让「完成」=验证通过而非观感 | Anthropic: Claude Code best practices（"Give Claude a way to verify its work"）【事实】 | 全流程完成断言 | 【推断】把「完成声称」从语言承诺改为「有命令输出背书」：与 sdet evidence.yaml（command+exit_code+log_ref）直接对齐，建议上升为六阶段通用完成门，不止 sdet |
| **完成前验证 Iron Law**：未在本消息内运行验证命令，不得声称通过；「应该/大概/看起来」=红旗 | superpowers: verification-before-completion（"NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE"；拒绝借口表 8 条）【事实】 | 白名单拒词、消息纪律 | 【推断】在 D075 或巡检检查单加入禁用词表：「should work / probably / seems / looks done」触发证据回放；「agent 报告成功」必须独立核 VCS diff 等物证 |
| 代码执行验证：把动作写成可执行代码而非 JSON 叙述（CodeAct） | arXiv:2402.01030【事实】 | 开发执行层 | 【推断】命令输出日志（log_ref）留工作房可回放可复跑，防「口头声称已执行」；D074 已覆盖控量，此处补「可复跑性」 |
| 测试真实性检查：防「没写测试/假测试/空测试」 | SoloDawn 三质量门内置 test-authenticity checks【事实】 | 测试岗交付 | 【推断】sdet 证据除 exit_code=0 外，检查测试是否真实断言（防空壳绿）；评分公式可加「测试非空壳」评分项 |
| 外部事实用实时工具确认（web 搜索 skill、终端命令） | ReAct arXiv:2210.03629（推理与工具交替）【事实】；browser-search skill（SearXNG 搜索）【事实】 | 涉及外部实时事实的所有环节 | 【推断】「说不确定」不等于「不查」：先查工具再决定说不知道还是给证据 |

### 2.4 不确定性表达

| 技巧 | 来源 | 适用 | 对 dsh-codepunk 落地建议 |
|---|---|---|---|
| **允许说「我不知道」**：显式授权模型承认不确定，可大幅减少编造 | Anthropic docs: Reduce hallucinations（Basic strategies 第一条）【事实】；research-mode 约束一【事实】 | 全局 | 【推断】在 D075 语言纪律中把「我不知道」列为合法输出，且与「保留承载真实不确定性的 hedge」复用同一规则（SKILL.md §2④ 已留口子），落地为显式白名单而非例外 |
| 用语言表达校准过的不确定性（"90% confident" 而非空泛承诺）| arXiv:2205.14334（GPT-3 可学得自然语言置信度且校准良好）【事实】 | 评分、规划决断 | 【推断】评分公式的定性评语增加「置信度」字段；低置信不得记为 high 分 |
| clarity-gate 认识论检查：**主张是否被恰当限定**（"我们的方法超过 X"（无证据）≠事实错误，但=未加限定的断言，拒绝入知识库） | frmoretto/clarity-gate（RAG 摄入前门：Accuracy check 之外补 Epistemic check）【事实】 | 交接文档写入、知识沉淀 | 【推断】交接包/known_issues 写入时过「限定性检查」：带数据或方法来源的断言允许入库，裸断言标注为「未证实主张」并随证据补录后转正 |

### 2.5 输出契约（拒绝编造 / 结构化）

| 技巧 | 来源 | 适用 | 对 dsh-codepunk 落地建议 |
|---|---|---|---|
| 公开承诺「不编造来源」，无来源即「不知道」 | Anthropic docs【事实】；research-mode【事实】 | 弱项区（高虚构风险任务） | 【推断】对「引用权限偏好/工具能力/历史记录」类问题预设 canned 回应（"我没有该记录/无法确认"），替代默认编造 |
| 输出结构约束：指标先拆成**可量化可判定**项再评估（truthfulness/relevance 太虚，拆成知识准确性+相关性+一致性等可打分维度） | OpenAI cookbook: Developing hallucination guardrails（eval set → 拆解 truth 成可测量指标 → 先进模型做护栏 → few-shot 校准 → precision/recall 度量）【事实】 | 评分公式、验收标准 | 【推断】评分公式的每项验收标准写「可判定条件」而非形容词；对高价值交付可加独立「护栏评审」（第二个模型按指标清单复核） |

### 2.6 上下文约束（拒绝空上下文推断）

| 技巧 | 来源 | 适用 | 对 dsh-codepunk 落地建议 |
|---|---|---|---|
| **外部知识限制**：显式指令只用给定材料、不用通识 | Anthropic docs: Reduce hallucinations（External knowledge restriction）【事实】 | 需求确认、设计评审 | 【推断】把「基于材料而非通识」写成默认模式，材料缺口就报缺口，不以行业惯例脑补填补 |
| 上下文是**有限注意力预算**：检索性能随上下文变长而劣化；最小化上下文、循环精炼 | Anthropic: Effective context engineering【事实】 | 长任务/多轮 | 【推断】与 D074 一致，进一步把「每轮只留最新结论行」执行化（SKILL.md R12 同源），防止陈旧上下文参与推断 |
| 受控记忆：只有**确认过**的事实才能进入长期记忆；情绪/敏感/未证实内容不落地 | Linghun「受控记忆 candidate-first 确认流」【事实】；Reflexion episodic memory【事实】 | 知识库/交接沉淀 | 【推断】dsh-codepunk 知识库写入需「双人确认」或「证据文件背书」，防一次性推断被固化成长久规则 |

### 2.7 多智能体场景（交叉验证 / 证据链 / 审计）

| 技巧 | 来源 | 适用 | 对 dsh-codepunk 落地建议 |
|---|---|---|---|
| **多智能体辩论**：多实例提案+辩论多轮收敛，提升事实性与推理 | arXiv:2305.14325（Multiagent Debate，Du et al.）【事实】 | 高危结论（需求规格、验收） | 【推断】对最终交付结论做「红蓝对抗评审」：一个 agent 找毛病、一个 agent 找证据支撑，双方结论并列进评分材料 |
| 独立 agent 交叉检查：**Mentor+Executor** 双角色互查，汇报不互抄 | the-pair（Executor 执行 → Mentor 审阅+纠偏）【事实】 | 三人小组（主责+开发+测试）结构 | 【推断】把「测试-开发」双角色互证制度化：测试只认代码行为不认开发叙述——dsh 三人组天然适配，建议写入岗位卡 |
| 确定性编排 + 质量门阻塞前进 + **不可变审计日志**（每任务/门/决策留痕、可重放）| a5c-ai/babysitter（"Gates block progression until satisfied"，先过门再前进；journal 不可变）【事实】 | 六阶段流程引擎 | 【推断】巡检「双门闩」形式化为「门不过、不前进」的硬条件；决策留痕进评测日志，防「某轮谁说的」无法追责 |
| **证据门控交付**：证据不合格自动打回 | SoloDawn（90 分评分护栏，低于 90 自动返工）；perfectify（evidence-gated completion）与 odai（evidence-gated delivery），转引自 VoltAgent 目录【事实】 | 评分公式、交接验收 | 【推断】dsh-codepunk 已有「evidence pass ≠ 可解散」，可补「交接包缺证据索引=整包打回」的硬规则；评分公式加证据完整度权项 |
| 合流后验证生产健康（CI 绿 ≠ 上生产没问题） | garrytan/land-and-deploy（merge 后 verify production health），转引自 VoltAgent 目录【事实】 | 再规划/迭代 | 【推断】「完成」另加一层运行态验证（build/smoke 真跑），与 Claude Code 官方「check = tests/build/screenshot」一致 |

---

## 3. TOP 落地清单（按 dsh-codepunk 价值排序，10 条）

1. **完成断言 = 新鲜验证证据**（价值：最高，堵住最大幻觉出口）：全流程采用 verification-before-completion 的 Iron Law——「本消息内未运行验证命令，不得声称通过」，把「应该/大概/看起来完成」列为红旗词；与 sdet evidence.yaml 合并为统一完成门。【事实：vbc；推断：映射】
2. **官方三件套入纪律**：「允许说不知道」+「事实用直接引文接地」+「找不到引文就撤回主张」——直接写入 D075 消息纪律与交接检查单。【事实：Anthropic docs】
3. **可运行检查替代观感**：「给 agent 一个能跑的 check（tests/build/screenshot）」作为「完成」判据，巡检主会话把「看得像做完了」升级为「命令输出说了算」。【事实：CCBP】
4. **证据门控交付硬化**：交接包缺证据索引（command+exit_code+log_ref）即整包打回；评分公式加证据完整度权项，90 分线以下自动返工（SoloDawn 同款）。【事实：SoloDawn；推断：映射】
5. **测试真实性检查**：sdet 除了 exit_code=0，检查测试是否真实断言（防空壳绿/假测试）——把「绿」从表面信号变成行为信号。【事实：SoloDawn test-authenticity checks；推断：映射】
6. **知识冲突显式化**：多段上下文/多 agent 结论冲突时，表层标「冲突点」而非悄悄选一个；需求确认与巡检阶段增加「材料是否互相矛盾」一问。【事实：arXiv:2403.08319；推断：映射】
7. **子代理交叉验证**：高危结论（需求规格、最终验收）走「红蓝对抗」——一个找毛病、一个找证据，评委并排出报告；three-person 小组（主责+开发+测试）互证不互抄。【事实：arXiv:2305.14325、the-pair；推断：映射】
8. **审计留痕**：门闩通过/证据签收/评分决策全部写不可变日志（谁、何时、依据哪个 log_ref），供再规划阶段复盘追溯。【事实：babysitter journal】
9. **受控记忆与事实分离**：知识库写入需证据背书或双人确认（candidate-first），未经确认的推断不得固化为规则；复盘失败经验显式入库防复发。【事实：Linghun；推断：映射】
10. **护栏评估指标化**：对高价值结论启用独立「护栏评审」（第二个模型 + 可量化指标清单），并建小 eval 集持续度量拦截精度（precision/recall），防护栏自己失效。【事实：OpenAI cookbook】

---

## 4. 已知限制

1. **无完全消除**：Anthropic 官方明言这些技术「significantly reduce, not eliminate」幻觉【事实】；SoloDawn 明言「模型 token 生成瞬间无法阻止幻觉，只能在流程内拦截修复」【事实】。dsh-codepunk 目标应为「可拦截、可追溯、可返工」，而非「零幻觉」。
2. **纯内在自查靠不住**：无外部反馈/工具时自纠错无效甚至反向恶化（arXiv:2310.01798）【事实】——一切自查必须绑定外部证据链。
3. **检索 ≠ 无幻觉**：RAG 环境下仍会产生与检索内容矛盾/无支撑的表述（RAGTruth arXiv:2401.00396）【事实】——接地与验证是两个独立环节，缺一不可。
4. **上下文长度劣化检索精度**：长上下文下模型事实检索/长程推理精度下降（Anthropic context engineering）【事实】——反面支持 D074/D075 的剪裁纪律，但意味着「上下文太长」本身是幻觉诱因，需持续压缩。
5. **来源缺口（已注明）**：Anthropic engineering 旧文《reducing-hallucinations*》已下线 404、OpenAI planning-for-ai-agents 403、Codex 官方 best-practices 页 404——本简报未转述其内容，明确列入检索失败；如需可后续用其它通道补查。
6. **本简报为外部机制调研**：具体规则文案、门闩阈值、评分权重均须 run-lead 审定后由文档小组落地，ind-res 不代替决策。

---

## 5. 来源清单（全部 retrieved_at = 2026-08-26；后附标注）

**论文（arXiv API 核验元数据+摘要）**
- https://arxiv.org/abs/2311.05232 A Survey on Hallucination in LLMs（Huang et al., 2023-11）
- https://arxiv.org/abs/2202.03629 Survey of Hallucination in NLG（Ji et al., 2022-02）
- https://arxiv.org/abs/2403.08319 Knowledge Conflicts for LLMs: A Survey
- https://arxiv.org/abs/2507.22915 Theoretical Foundations and Mitigation of Hallucination in LLMs
- https://arxiv.org/abs/2510.06265 LLMs Hallucination: A Comprehensive Survey（仅核验元数据）
- https://arxiv.org/abs/2309.11495 Chain-of-Verification（CoVe）
- https://arxiv.org/abs/2303.08896 SelfCheckGPT
- https://arxiv.org/abs/2303.17651 Self-Refine
- https://arxiv.org/abs/2303.11366 Reflexion
- https://arxiv.org/abs/2310.01798 LLMs Cannot Self-Correct Reasoning Yet
- https://arxiv.org/abs/2305.14325 Multiagent Debate
- https://arxiv.org/abs/2203.11171 Self-Consistency
- https://arxiv.org/abs/2205.14334 Teaching Models to Express Their Uncertainty in Words
- https://arxiv.org/abs/2210.03629 ReAct
- https://arxiv.org/abs/2402.01030 Executable Code Actions（CodeAct）
- https://arxiv.org/abs/2406.04692 Mixture-of-Agents
- https://arxiv.org/abs/2309.15217 RAGAS（RAG 自动评估）
- https://arxiv.org/abs/2401.00396 RAGTruth（RAG 幻觉语料）

**官方指南/工程文（HTTP 200 直连确认）**
- https://docs.anthropic.com/en/docs/test-and-evaluate/strengthen-guardrails/reduce-hallucinations — Anthropic 防幻觉官方文档（I don't know / 直接引文 / 引文验证 / CoT 验证 / Best-of-N / 外部知识限制）
- https://www.anthropic.com/engineering/claude-code-best-practices — Claude Code 最佳实践（Give Claude a way to verify its work）
- https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents — 上下文工程（检索性能随长度劣化、最小化上下文）
- https://www.anthropic.com/engineering/multi-agent-research-system — 多智能体研究系统（subagent 独立检索 + CitationAgent）
- https://github.com/openai/openai-cookbook/blob/main/examples/Developing_hallucination_guardrails.ipynb — OpenAI 防幻觉护栏 cookbook（eval set→可量化指标→护栏模型→precision/recall）

**技能/工具生态（GitHub REST API star 实况 + raw README/SKILL.md）**
- https://github.com/obra/superpowers/tree/main/skills/verification-before-completion — 完成前验证 Iron Law（superpowers 子 skill）
- https://github.com/huanchong-99/SoloDawn（★312）— 31 规则 + 三层质量门（16/18/23）+ 90 分评分护栏 + 测试真实性检查
- https://github.com/a5c-ai/babysitter（★1734）— 确定性编排、质量门阻塞、breakpoint 人工批准、不可变 journal
- https://github.com/linghungegeg/Linghun（★442）— 证据优先（EvidenceSummary/完成度状态/代码事实检查/受控记忆 candidate-first）
- https://github.com/assafkip/research-mode（★148）— 防幻觉三约束 + 来源级联
- https://github.com/nai0om/buddhist-method（★194）— 六条认识论检查表（防模式匹配当事实等）
- https://github.com/timwuhaotian/the-pair（★358）— Mentor+Executor 双 agent 交叉检查
- https://github.com/frmoretto/clarity-gate — RAG 摄入前认识论验证（Epistemic check）
- https://github.com/Johell1NS/browser-search（★497）— agent 实时 web 搜索 skill（事实校验工具）
- https://github.com/VoltAgent/awesome-agent-skills — 目录转引：perfectify（evidence-gated completion）、odai（evidence-gated delivery）、brave/answers（web 接地）、land-and-deploy（部署后验证）

**检索失败记录**：anthropic.com/engineering/reducing-hallucinations（404，sitemap 已无条目）；anthropic.com/engineering/reducing-hallucinations-in-ai-agents（404）；openai.com/index/planning-for-ai-agents（403）；developer.openai.com 与 openai.github.io 之 codex best-practices（404）。