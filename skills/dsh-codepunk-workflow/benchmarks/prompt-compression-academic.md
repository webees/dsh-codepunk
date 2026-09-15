# 提示词压缩（Prompt Compression）：学术方法与工具实现调研简报

> 支撑决策号：D074（上下文纪律）延伸 · 性质：外部调研（提示词压缩方法）


- 调研人：ind-res（行业分析）｜接收方：工程主责（审核后转文档小组）
- 检索时间（retrieved_at）：2026-09-15T01:47Z（本地 2026-09-15 08:47 +07）
- 方法与工具条目数：7 项（LLMLingua / LongLLMLingua / LLMLingua-2 / AutoCompressor / 500xCompressor / Gist Tokens / ReadAgent-gist memory）
- 一句话结论：【推断】硬压缩（train-time、需改模型）不适合 agent 系统提示词；软压缩（训练无关、token 级抽取、可保护关键 token）才可落地，首选 LongLLMLingua 与 LLMLingua-2。

## 1. 检索实况（渠道 / 可达性）

| 渠道 | 结果 |
|---|---|
| 内置 `web_search` 工具 | **不可用**：`DeepSeek API error (HTTP 401): Authentication Fails`（provider 鉴权失败，非本任务可修） |
| `bash curl` → `https://arxiv.org/abs/<id>` | **可达**（HTTP 200），本次主要来源 |
| `bash curl` → `https://export.arxiv.org/api/query` | **部分不可达**：返回 `429 Rate exceeded`，故改用 abs 页面抓 meta |
| `bash curl` → `api.semanticscholar.org/graph/v1` | 首次搜索成功（AutoCompressor），后续 `429`，仅用于交叉验证 |
| `bash curl` → `html.duckduckgo.com` | **可达**，用于补全 arXiv ID |
| `bash curl` → `api.github.com/repos/*` | **可达**，用于工具活跃度与许可证核实 |

【事实】除 `web_search` 鉴权失败外，全部结论均来自 arXiv 摘要页 / GitHub API 的直接抓取，无二手转述。
【推断】arXiv 官方 API 429 属限流，非网络封锁；本机可直连 arXiv、GitHub、Semantic Scholar、DuckDuckGo。

## 2. 方法对比表

| 方法 | 压缩率【事实，来源明述】 | 语义保真 / 下游质量 | 依赖 | 来源 |
|---|---|---|---|---|
| **LLMLingua**（EMNLP 2023） | "up to 20x compression with minimal performance loss"，在 GSM8K/BBH/ShareGPT/Arxiv-March23 上 | 粗到细压缩：budget controller 控语义完整度 + token 级迭代压缩 + 指令微调做分布对齐 | 需一个小 LM（GPT2-small / LLaMA-7B）做困惑度打分；**不改目标 LLM** | [arXiv 2310.05736](https://arxiv.org/abs/2310.05736) · [repo README](https://github.com/microsoft/LLMLingua) |
| **LongLLMLingua**（ACL 2024） | NaturalQuestions 上 ~**4x** 更少 token；LooGLE 上 **94.0%** 成本下降 | 【事实】NQ 上性能**提升至 +21.4%**（GPT-3.5-Turbo）；显式针对 "lost in the middle" 位置偏置 | 同上，训练无关；含文档重排 + 关键信息密度导向 | [arXiv 2310.06839](https://arxiv.org/abs/2310.06839) · [ACL 2024](https://aclanthology.org/2024.acl-long.91/) |
| **LLMLingua-2**（ACL 2024 Findings） | 【事实】比 LLMLingua **快 3x–6x**；task-agnostic、抽取式 | 把压缩建模为 **token 分类**问题，用 GPT-4 蒸馏数据训练，保真性（faithfulness）更强、跨域更稳 | BERT 级编码器（`microsoft/llmlingua-2-xlm-roberta-large-meetingbank`、`-bert-base-multilingual-cased-meetingbank`）；**不改目标 LLM** | [arXiv 2403.12968](https://arxiv.org/abs/2403.12968) · [ACL Findings](https://aclanthology.org/2024.findings-acl.57/) |
| **AutoCompressor**（EMNLP 2023） | 长上下文压成**定长 summary vectors**（软提示），训练序列长达 30,720 token | 【事实】在若干 in-context 任务上可匹敌未压缩基线 | **需微调模型**（OPT 系列）才能产生/读取 summary vectors | [arXiv 2305.14788](https://arxiv.org/abs/2305.14788) · [repo](https://github.com/princeton-nlp/AutoCompressors) |
| **500xCompressor**（ACL 2025 Main） | **6x–480x**，极端下压到 **1 个特殊 token**；仅增 **~0.3%** 参数 | 【事实】仅保留原能力的 **62.26–72.89%**；KV 值在高压缩比下优于 embedding | 预训练（Arxiv Corpus）+ 微调（ArxivQA）流程；声称原 LLM 无需再微调即可使用 | [arXiv 2408.03094](https://arxiv.org/abs/2408.03094) · [repo](https://github.com/ZongqianLi/500xCompressor) |
| **Gist Tokens / gisting**（NeurIPS 2023） | **最高 26x** 压缩；40% FLOPs 下降、4.2% wall-time 加速 | 【事实】"minimal loss in output quality"；gist token 可缓存复用 | **需改 Transformer attention mask 做指令微调**（LLaMA-7B / FLAN-T5-XXL） | [arXiv 2304.08467](https://arxiv.org/abs/2304.08467) |
| **ReadAgent gist memory**（Google, 2024） | 有效上下文长度 **20x**（gist memory + 原文回查） | 【事实】用提示系统把长文分 episode → 压成"要点记忆" → 需要细节时回查原文 | 纯 prompting，无额外训练；但依赖 agent 循环与回查动作 | [arXiv 2402.09727](https://arxiv.org/abs/2402.09727) |

### 关键事实补充
- 【事实】压缩的前提假设是自然语言冗余；LLMLingua 系列默认 **不改目标 LLM 权重**，属"软/训练无关"路线；AutoCompressor、gisting、500xCompressor 属"训练期压缩"路线。
- 【事实】LLMLingua 已被集成进 **LangChain / LlamaIndex / Prompt flow**（官方 README 明述），现成可用。
- 【事实】工具活跃度（GitHub API，retrieved_at 2026-09-15）：`microsoft/LLMLingua` 6655 stars、MIT、最后 push 2026-09-10；`princeton-nlp/AutoCompressors` 336 stars、无 license 字段、最后 push 2024-09-09；`ZongqianLi/500xCompressor` 64 stars、无 license、最后 push 2026-03-09。
- 【事实】长上下文模型的"中间遗忘"（lost in the middle）是位置偏置问题，见 [arXiv 2307.03172](https://arxiv.org/abs/2307.03172)；LongLLMLingua 显式以此为动机。
- 【推断】压缩率的数量级不可跨方法直接比较：LLMLingua 的 20x 面向 ICL/CoT 类长提示且允许质量损失；500xCompressor 的 480x 面向"整篇文档 → 单 token"，代价是能力仅存 62–73%。

## 3. 对 agent 系统提示词的适用性判定

判定基准：【推断】agent 系统提示词是"高信息密度 + 低冗余 + 语义敏感"文本（角色、硬约束、工具契约、输出格式），压缩错误的代价不是"答案变差"而是"行为越界/格式崩坏"。

| 方法 | 对 agent 系统提示词 | 理由 |
|---|---|---|
| LLMLingua-2 | **推荐**（首选） | 抽取式 token 分类，天然可加"不可删 token"保护；速度快（3–6x）、跨域稳；无训练依赖 |
| LongLLMLingua | **推荐**（RAG 注入内容首选） | 面向长检索内容 + 位置重排，直接治"中间遗忘"；但**不要**用它压系统提示词本体 |
| LLMLingua | 谨慎可用 | 需外部小 LM 打分，迭代压缩会改写措辞；在 CoT/ICL 上验证过，对"硬约束"语句风险未验证 |
| Gist Tokens | **不适用**（对现有模型） | 需改 attention mask 并微调目标模型；对闭源 API 模型不可行 |
| AutoCompressor | **不适用**（对现有模型） | 同前，且仓库已近两年未更新、无 license |
| 500xCompressor | **不适用**（对现有模型） | 需预训练+微调；能力仅存 62–73%，系统提示词不允许这种折损 |
| ReadAgent gist memory | 适用（架构级替代） | 不是"压提示词"，而是 agent 记忆架构：要点记忆 + 原文回查，适合长会话/长文档 agent |

【推断】边界结论：**"压检索进来的内容"与"压系统提示词本身"是两件事**——前者是收益/风险比良好的成熟工程（LongLLMLingua、LLMLingua-2）；后者建议改用人工精简、模块化按需加载、以及工具 schema 化，而不是统计式 token 删除。

## 4. 可落地项

1. 【推断→建议】RAG / 长文档注入路径接 **LongLLMLingua**（LlamaIndex `LongLLMLinguaPostprocessor` 现成节点后处理器），目标 2–4x token 下降并顺带缓解位置偏置。
2. 【推断→建议】通用文本压缩接 **LLMLingua-2**（`microsoft/llmlingua-2-xlm-roberta-large-meetingbank`），对系统提示词只做"白名单保护式"压缩：instruct、工具名、格式模板、禁止项标为不可压缩段。
3. 【推断→建议】系统提示词的压缩优先级：先做结构精简（去重复示例、合并同类约束）→ 再考虑按需加载（技能/工具按阶段注入）→ 最后才考虑 token 级压缩。
4. 【建议】任何压缩上线前做**行为回归测试**（工具调用正确率、格式合规率、越界率），而非仅看 token 数或困惑度；学术论文的指标（QA/GSM8K）不能直接代理 agent 行为质量。
5. 【建议】暂不引入需改模型权重的方案（gist / AutoCompressor / 500xCompressor），除非模型自研且有训练预算。

## 5. 来源 URL（附 retrieved_at）

| 来源 | URL | retrieved_at |
|---|---|---|
| LLMLingua（EMNLP 2023） | https://arxiv.org/abs/2310.05736 | 2026-09-15T01:44Z |
| LongLLMLingua（ACL 2024） | https://arxiv.org/abs/2310.06839 | 2026-09-15T01:44Z |
| LLMLingua-2（ACL 2024 Findings） | https://arxiv.org/abs/2403.12968 | 2026-09-15T01:44Z |
| AutoCompressor（EMNLP 2023） | https://arxiv.org/abs/2305.14788 | 2026-09-15T01:46Z |
| 500xCompressor（ACL 2025 Main） | https://arxiv.org/abs/2408.03094 | 2026-09-15T01:46Z |
| Gist Tokens（NeurIPS 2023） | https://arxiv.org/abs/2304.08467 | 2026-09-15T01:46Z |
| ReadAgent gist memory | https://arxiv.org/abs/2402.09727 | 2026-09-15T01:44Z |
| Lost in the Middle | https://arxiv.org/abs/2307.03172 | 2026-09-15T01:44Z |
| LLMLingua 官方仓库（README / 集成 / MIT） | https://github.com/microsoft/LLMLingua | 2026-09-15T01:45Z |
| AutoCompressors 仓库 | https://github.com/princeton-nlp/AutoCompressors | 2026-09-15T01:46Z |
| 500xCompressor 仓库 | https://github.com/ZongqianLi/500xCompressor | 2026-09-15T01:46Z |
| LongLLMLingua 论文页（ACL） | https://aclanthology.org/2024.acl-long.91/ | 2026-09-15T01:45Z |
| LLMLingua-2 论文页（ACL） | https://aclanthology.org/2024.findings-acl.57/ | 2026-09-15T01:45Z |

### 局限与未覆盖
- 【事实】内置 `web_search` 因 provider 401 全程不可用，检索依赖 curl 直连，未做多引擎交叉验证。
- 【事实】arXiv API 429 与 Semantic Scholar 429 导致部分条目（如 prompt compression 综述类论文）未纳入，方法集为 7 项而非穷举。
- 【事实】所有压缩率/保真数字均来自论文自述，本简报未复现实验。
