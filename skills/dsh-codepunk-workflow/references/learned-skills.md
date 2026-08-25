# 学到的技能总览（references/learned-skills.md）

> 本文件汇总 dsh-codepunk 在历次迭代中学到的全部外部技能/技巧及其落地决策号，作为「技能索引 + 溯源单」。与 `standard.md`（编号权威释义）互补：standard 管编号定义，本文件管「从哪学到什么、应用到哪」。
> 维护：文档小组在每次借鉴落地时追加一行；run-lead 审定。

## 技能清单（按决策号序）

| 决策号 | 学到什么（技能本质） | 来源（仓库/文档，License） | 应用到哪 |
|---|---|---|---|
| **D066** | goal 自动续行 / 子代理回报自动递送：create 即 armed、idle 自动唤醒、resume 重武装 | DSH 平台机制（源码排查） | SKILL §0.1 / R10 |
| **D067** | checkpoint 断点续行：progress/handoff/evidence 即重放状态，中断后从断点续行 | langchain langgraph（durable execution） | SKILL §2③ |
| **D068** | 门禁即显式节点 + 双侧 guardrail：入口验输入、出口验输出 | crewAI Flow / Google ADK（tool confirmation） | SKILL §2④ |
| **D069** | schema 强约束：evidence/acceptance 生成期机器可校验 | dottxt/outlines + agentskills.io | references/artifacts.md |
| **D070** | 硬信号驱动评分-再规划 + 经验→skill 沉淀回路 | CAMEL（verifiable rewards）/ ChatDev（经验共学习）/ graphify | references/knowledge.md |
| **D071** | 委托契约：单轮受控输出 vs 多轮任务 + 双侧 guardrail | Google ADK Task API / openai swarm handoff | references/roles.md |
| **D072** | 总库语义：运行根统一用户级总库，工程目录零污染 | 自研工作区治理（含迁移/回滚窗） | SKILL §1 / README |
| **D073** | worktree 生命周期：创建登记→回收→prune，分支 refs 留审计 | 实战教训（worktree 残留根因复盘） | SKILL §2⑤′/⑥ + knowledge/lessons/ |
| **D074** | 上下文纪律：证据只回引用、汇报≤1500 token、主会话防腐 | Anthropic 上下文工程（context rot/compaction/tool-result） | SKILL P07 + 三席人设 |
| **D075** | 消息层纪律：首行=结论、编号≤5、禁寒暄、调试螺旋防空转 | ayghri/i-have-adhd（ADHD 友好输出，MIT） | SKILL P07 + 全员人设 + R11 |
| **D076** | token 经济学：禁自造缩写/箭头、保护清单、Auto-Clarity 豁免、持久化产物完整行文 | juliusbrussee/caveman（极简输出，MIT） | SKILL P07 + R11 全员参考；sdet 终态拒绝线 / engineer 先取证后改码同源 |
| **D077** | 反幻觉纪律：完成断言须新鲜证据；不确定即明示；知识冲突显式化；防空壳绿；交叉验证 | superpowers vbc + Anthropic 防幻觉指南 + arXiv 综述 | SKILL P07 + sdet 人设 + references/anti-hallucination-rules.md |
| **D078** | 模型路由与成本工程：分岗位模型/thinking/错峰/cache | dsh-llm-deepseek（官方适配器，源码实证 agentOptions 覆盖） | references/model-routing.md |

## 技能类别图谱（方便按需查找）

### 运行时机制类
- **goal 自动续行 / 自动递送（D066）**：主管无人值守处理排队消息；resume/fork 后重武装
- **checkpoint 断点续行（D067）**：中断后从最近断点续行，不整轮重来
- **worktree 生命周期（D073）**：创建登记→回收→prune→分支审计

### 提示词/上下文类
- **上下文纪律（D074）**：证据只回引用、摘要预算、主会话防腐、32KiB 预算
- **消息层纪律（D075）**：首行=结论、首末行双读、编号≤5、禁寒暄
- **token 经济学（D076）**：禁缩写/箭头、保护清单、Auto-Clarity 豁免、持久化产物完整行文

### 流程/质量类
- 门禁双侧 guardrail（D068）、schema 强约束（D069）、委托契约（D071）、硬信号评分（D070）
- 总库语义（D072）、文件归宿纪律（R13/R14）、结算通知辨识（R12）

### 输出风格参考（不设决策号，供撰写参考）
- **ADHD 友好输出**（D075 源）：action-first、状态回放、可见进展
- **caveman 极简**（D076 源）：压缩风格不压缩语言、净负即关、诚实数字
- **Anthropic 上下文工程**（D074 源）：context rot、compaction 先保召回、工具结果修剪

## 溯源档案（benchmarks/）

| 简报 | 内容 |
|---|---|
| `benchmarks/multi-agent-open-source-benchmark.md` | 13 个多智能体编排框架对比（MetaGPT/AutoGen/LangGraph/crewAI…） |
| `benchmarks/agent-skills-open-source-benchmark.md` | agent-skills 生态：agentskills 规范 / superpowers / VoltAgent 质量门 |
| `benchmarks/prompt-context-compression.md` | 提示词压缩/上下文优化（14 个一手来源） |
| `benchmarks/adhd-workflow-analysis.md` | ayghri/i-have-adhd 输出纪律分析 |
| `benchmarks/caveman-analysis.md` | juliusbrussee/caveman 极简分析 |
| `benchmarks/deepseek-harness-study.md` | DeepSeek Harness 官方机制调研（§0.0 对齐表来源） |
| `benchmarks/anti-hallucination.md` | 防幻觉技术调研（D077 来源） |
| `benchmarks/dsh-deepseek-analysis.md` | dsh-llm-deepseek 适配器分析（模型路由/成本/thinking 规划输入） |
| `benchmarks/dsh-deepseek-realrun-projection.md` | 错峰节支/1M 承载/并发 429 离线实测算 |

## 应用原则（铁律）
1. **机制借鉴不抄码**：只借鉴思想/规则，不复制实现；MIT 来源保留 attribution。
2. **承重留正文、示例进 references**：SKILL.md ≤32 KiB（现约 29），新内容优先进按需文件。
3. **净负即关**：技巧若在某场景净增负担则退回（借鉴 caveman 诚实数字立场）。
4. **豁免先于精简**：安全/不可逆/持久化产物场景完整行文优先（Auto-Clarity）。