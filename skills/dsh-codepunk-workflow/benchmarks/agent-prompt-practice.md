# AI Agent 系统提示词精简 — 工程实践调研简报

> 支撑决策号：D074（上下文纪律）延伸 · 性质：外部调研（提示词压缩方法）


- 调研人：ind-res（行业分析）
- 检索时间（retrieved_at）：2026-02-14，单轮检索，未做二次检索循环
- 检索工具实况：`web_search` 不可用（HTTP 401，DeepSeek 鉴权失败）；改用 `web_fetch` + `bash curl` 直连公开源
- 标注约定：【事实】= 可直接指认的来源内容；【推断】= 本简报的工程结论，未经来源直接论证

## 1. 检索实况

| 目标 | 结果 |
|---|---|
| web_search 内置检索 | 失败：`HTTP 401 Authentication Fails`（api.deepseek.com/anthropic/v1/messages），非本文档可控 |
| web_fetch → Anthropic 上下文工程指南 | 成功（400+ 行正文，含 compaction / note-taking / sub-agent 三节） |
| curl → GitHub `x1xhlol/system-prompts-and-models-of-ai-tools` | 成功（目录清单 + 逐文件字节数） |
| curl → Claude Code 2.0 / Cursor Agent 2025-09-03 全文 | 成功，已本地解析分节 |
| curl → Aider `aider/prompts.py` | 成功（2354 B，多段小 prompt） |
| curl → OpenHands `codeact_agent/prompts/system_prompt.j2` | 404（路径已变更，未继续追；未取得该源规模数据，故下文不引用其数字） |
| curl → Codex CLI / Cline / RooCode 目录 | 该仓库对应条目为空目录，未取得数据 |

未能取得的项已剔除出对比表，未以推测填充。

## 2. 各 agent 提示词规模与组织对比表

【事实】规模数据（文件字节数，来自公开泄露/公开源码仓库目录清单）：

| Agent / Prompt | 原始字节 | 约 token（÷3.6，英文经验值） | 组织方式 |
|---|---|---|---|
| Claude Code 2.0 全量（system+tools） | 57,324 B | ≈16k | 单文件：`# System Prompt` → 行为节 → `# Tools` 工具长文 |
| ├ Claude Code 2.0「纯 agent 行为段」 | ≈7.1 KB（1,981 词） | ≈2k | Markdown 二级标题分节：Tone and style / Proactiveness / Professional objectivity / Task Management / Doing tasks / Tool usage policy / Code References，含 `<env>` 块与 10+ 个 `<example>` |
| └ Claude Code 2.0「Tools 段」 | ≈50 KB（6,635 词） | ≈14k | 每工具一节（Bash/Edit/Glob/Grep/Read/Task…），每节含用法+示例；工具契约占全文约 87% |
| Cursor Agent Prompt 2025-09-03 | 19,028 B（2,977 词） | ≈5.3k | XML 语义标签分模块：`<communication>` `<status_update_spec>` `<summary_spec>` `<completion_spec>` `<flow>` `<tool_calling>` `<grep_spec>` `<making_code_changes>` `<todo_spec>`… |
| Cursor Agent Prompt 2.0（更早） | 38,844 B | ≈10.8k | 同上风格，体量约为 09-03 版的 2 倍 |
| VSCode Copilot `Prompt.txt` | 21,032 B | ≈5.8k | 分节 + 按模型叠加的差异段 |
| VSCode Copilot 按模型分层 | 7,876 B（gpt-4o）/ 9,910 B（sonnet-4）/ 25,579 B（gpt-5） | ≈2.2k / 2.8k / 7.1k | 【事实】同一 agent 对不同模型给不同体量提示词 |
| Devin `Prompt.txt` | 34,714 B | ≈9.6k | 单文件长文（未取得分节统计） |
| Aider `prompts.py` | 2,354 B | ≈0.7k | 【事实】不是一个大 system prompt，而是多个按用途切分的小 prompt（commit / undo / …），按需注入 |
| Anthropic 官方 sub-agent 返回预算 | 摘述 1,000–2,000 token | — | 子 agent 可烧数万 token，只回传浓缩摘要 |

【事实】Anthropic 明确表述的判据原句（要点摘录）：
- 好的上下文工程＝「找到**最小**的高信号 token 集合，最大化期望结果的概率」。
- system prompt 应处在「**right altitude**」：一端是把脆弱 if-else 逻辑硬编码进提示词，另一端是过于笼统、错误假设共享上下文；两端都是失败模式。
- 推荐把 prompt 组织成**明确分节**（`<background_information>`、`<instructions>`、`## Tool guidance`、`## Output description`），用 XML 标签或 Markdown 标题分隔。
- 「striving for the minimal set of information that fully outlines your expected behavior」；并特别注明 **minimal ≠ short**——该留的行为定义仍要留。
- 反面清单：**不要把一大堆边界情况塞进 prompt**；改为「多样的、典型的示例」（canonical examples）。
- 工具：常见失败模式是**臃肿工具集**（工具有功能重叠、选哪个说不清）；人类工程师都说不清用哪个工具时，agent 更不行。
- 上下文增长的代价有实测支撑：引用 context rot 研究——token 越多，从上下文中准确召回的能力越下降；transformers 使 n token 产生 n² 对注意关系，模型也有「attention budget」。
- 运行时策略：**just-in-time / progressive disclosure**——只保留轻量标识符（文件路径、存储的查询、链接），用工具在运行时动态加载；Claude Code 的 `CLAUDE.md` 是「naively dropped into context up front」，而 glob/grep 用于按需取文件（**混合策略**）。
- 长任务三件套：**compaction**（摘要+重启窗口，Claude Code 保留最近 5 个访问过的文件）、**structured note-taking**（NOTES.md / todo 落盘）、**sub-agent**（隔离搜索上下文，只回摘要）。
- 明说可安全清理的低垂果实：**清理 tool calls 与 tool results**——很久以前调用的工具原始结果没有必要再看。

【推断】Cursor 08-07 → 09-03 两版从 38.8 KB 降到 19.0 KB（≈减半），且同期改为一套规整的 XML 标签模块，这与其他 agent 的公开走势一致：**先堆规则，再按「模块化 + 删重复」瘦身**。

## 3. 可删 / 必留判据

三层判据（必留 = 常驻 L0；按需 = L1/L2；可删 = 出局）：

**必留（常驻，进 L0）**
1. **不可推断的行为约束与红线**：安全/合规边界、拒绝规则（Claude Code 的 defensive-security 段、绝不猜 URL 段）。
2. **环境锚点**：工作目录、是否 git 仓库、平台、日期、当前模型 ID（Claude Code 的 `<env>` 块）——这类信息 agent 无法自行推断，且极便宜。
3. **身份与输出契约**：一句话角色 + 输出格式/语言约束。
4. **路径优先的引用规范**：如 `file_path:line_number`，它是一条规则换来大量后续往返的省 token 杠杆。
5. **典型示例 2–5 个**（Anthropic 明确主张示例优于长规则清单）。

**按需加载（L1 技能层 / L2 参考层）**
6. **工具长文**：Claude Code 里占 ≈87% 的工具契约，天然适合按需披露——只常驻「工具名 + 一句话用途」，schema 与示例在调用前取。
7. **流程/领域手册**：多步骤操作手册、参考资料——走 progressive disclosure（路径 + 触发条件作为标识符）。
8. **历史工具输出**：Anthropic 点名的最安全 compaction 动作。
9. **按模型分层的差异段**：事实层已有先例（VSCode Copilot 对 4o/sonnet-4/gpt-5 给 7.9/9.9/25.6 KB）；不是删，而是**分流**。

**可删（择优删除）**
10. **重复陈述**：Claude Code 2.0 里同一段 `IMPORTANT: Assist with defensive security tasks only...` 在文件内出现两次——同一文件内的重复是纯粹的预算浪费（【事实】重复存在；【推断】属可删项）。
11. **穷举式边界情况清单**：Anthropic 明确不建议；替换为少量 canonical example。
12. **可被模型常识/工具发现替代的教程式内容**：某语言的通用写法、某命令的用法速查。
13. **功能重叠的工具描述**：重叠即删除或合并，而不是两条都写得更详细。
14. **其他 agent/其他口的专属说明**（写在本仓会互相干扰的分工文案）——改为锚点引用。

【推断】判据的检验动作统一为「删除测试」：删掉该条后，用一个最小提示跑 3–5 个代表性任务；无回归即永久删除，有回归则把它降级为 L1/L2 按需加载，而不是原地加更长解释。

## 4. 对 dsh-codepunk（L0/L1/L2 三层）的适配建议

【推断】以下为建议，非来源结论，需工程主责决策。

| 层 | 建议内容 | 量级护栏（建议） | 依据 |
|---|---|---|---|
| L0 常驻 | 身份（ind-res/工程主责等）+ 输出契约（首行结论、编号≤5）+ 红线（不写本仓方案、不改仓、不外泄）+ 环境锚点（工作目录、仓根、日期、模型）+ 引用规范（文件路径锚点）+ 一行式工具/技能清单 | ≤1,500 字符（≈0.4k token）；工具只留名与一句用途，schema 进 L1 | Anthropic「最小高信号集合」+「right altitude」；Claude Code 纯行为段 ≈2k token 的上限参照 |
| L1 技能/路由层 | 每个技能一个自包含文件 + 一行触发条件；正文只写「何时用、必须做什么、产物路径、禁止项」；跨技能只给锚点不复制正文 | 单文件 ≤8k 字符（≈2k token） | progressive disclosure；Cursor 模块化标签版 ≈5.3k token 为上限参照 |
| L2 参考/手册 | 详细步骤、模板、示例、长清单、外部工具的 schema 与长示例 | 单文件 ≤20k 字符；一次会话只读 1–2 个 | 「just in time」加载 + sub-agent 只回浓缩摘要 |
| 落盘记忆 | 巡检结果、交接包、进度以文件承载，上下文只留路径与结论 | — | structured note-taking |
| 长任务压缩 | 阶段切换时做 compaction：保留决策/未决问题/产物路径，清掉历史工具原始输出 | — | Anthropic compaction 与 tool-result clearing |

**优先级最高的 2 项落地动作**
1. **把工具/技能长文从常驻区挪出**：L0 只留「名称 + 一句用途」，schema 与示例进 L1/L2 按需取——这是本次调研里体量占比最大的一块（Claude Code 中 ≈87%），单位收益最高。
2. **建立「删除测试」回归集**：为 dsh-codepunk 的 L0 每一条约束配 3–5 个代表性任务，删条跑批；同时先做**零风险清理**——删同文件内重复段落与穷举式边界清单（Anthropic 明确不建议后者）。

**明确不建议**
- 不要以「minimal 就是短」为目标砍掉行为定义与红线；Anthropic 原文强调 minimal ≠ short。
- 不要一次把 L1 全量预载进 L0（等于把层级压平，progressive disclosure 收益归零）。
- 不要为了补足「看起来完整」而加更多工具；臃肿工具集本身是 Anthropic 点名的失败模式。

## 5. 来源 URL

| # | 来源 | URL | retrieved_at |
|---|---|---|---|
| 1 | Anthropic, Effective context engineering for AI agents (2025-09-29) | https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents | 2026-02-14 |
| 2 | Anthropic, Context rot（被上述文章引用） | https://research.trychroma.com/context-rot | 2026-02-14（经来源 1 转引，未单独打开） |
| 3 | Anthropic, Writing tools for AI agents | https://www.anthropic.com/engineering/writing-tools-for-agents | 2026-02-14（经来源 1 转引，未单独打开） |
| 4 | 公开泄露提示词汇总仓库（文件字节数清单） | https://github.com/x1xhlol/system-prompts-and-models-of-ai-tools | 2026-02-14 |
| 5 | Claude Code 2.0 提示词全文（分节与 token 结构） | https://raw.githubusercontent.com/x1xhlol/system-prompts-and-models-of-ai-tools/main/Anthropic/Claude%20Code%202.0.txt | 2026-02-14 |
| 6 | Cursor Agent Prompt 2025-09-03 全文（XML 模块化） | https://raw.githubusercontent.com/x1xhlol/system-prompts-and-models-of-ai-tools/main/Cursor%20Prompts/Agent%20Prompt%202025-09-03.txt | 2026-02-14 |
| 7 | Aider prompts.py（多段小 prompt 组织） | https://raw.githubusercontent.com/Aider-AI/aider/main/aider/prompts.py | 2026-02-14 |

**来源可信度提示（供工程主责判断）**：来源 4–6 属第三方泄露/转录，字节数可由文件直接复核，但**不能保证与线上当前版本一致**，跨版本数字比较只作趋势参考；来源 1 为厂商一手公开文章，可靠性最高。未取得 OpenHands / Codex CLI 的一手提示词，故本简报不涉及其结论。
