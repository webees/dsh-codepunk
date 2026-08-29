# Prompt Injection 防护：高星仓库调研简报

> 调研小组：ind-res  
> 检索时间：2026-08-29T20:44:24Z  
> 检索渠道：GitHub REST API（`search/repositories`）+ raw.githubusercontent.com 直连  
> 关键词：「prompt injection」(exact) / 「prompt injection protection」/ 「llm guardrails」/ 「promptguard」+「rebuff」+「llm-guard」  
> 目标：为 dsh-codepunk 多智能体开发流程提炼可落地的 prompt injection 防护内容

---

## 一、仓库对比表

| # | 仓库 | Stars | 定位 | 核心机制 | 防护层级 | License |
|---|------|-------|------|----------|----------|---------|
| 1 | [NVIDIA/SkillSpector](https://github.com/NVIDIA/SkillSpector) | 15,194 | AI agent skill 安全扫描器 | 71 漏洞模式/17 类，两阶段分析（静态+LLM语义），SARIF 输出 | 安装前扫描（技能包） | Apache-2.0 |
| 2 | [guardrails-ai/guardrails](https://github.com/guardrails-ai/guardrails) | 7,334 | 通用 LLM 护栏框架 | Input/Output Guards，Hub 预置 24+ validators，结构化输出约束 | 输入 / 输出 | Apache-2.0 |
| 3 | [protectai/llm-guard](https://github.com/protectai/llm-guard) | 3,206 | LLM 安全工具包 | 17+ 输入 scanner + 14+ 输出 scanner（含 PromptInjection、InvisibleText、Secrets 等） | 输入 / 输出 | MIT — **已归档** |
| 4 | [protectai/rebuff](https://github.com/protectai/rebuff) | 1,520 | 自强化 prompt injection 检测器 | 4 层防御：Heuristics → LLM 检测 → VectorDB 攻击签名 → Canary Token | 输入 + 泄露检测 | Apache-2.0 |
| 5 | [trailofbits/anamorpher](https://github.com/trailofbits/anamorpher) | 1,076 | 多模态注入攻击框架 | 图像缩放导致嵌入偏差，视觉编码绕过 | 多模态输入（攻击方） | Apache-2.0 |
| 6 | [luckyPipewrench/pipelock](https://github.com/luckyPipewrench/pipelock) | 821 | MCP/AI agent 防火墙 | 代理 HTTP/MCP/A2A/WebSocket 流量扫描，检测注入/外泄/SSRF，审计签名 | 通信层 | Apache-2.0 |
| 7 | [Arcanum-Sec/arc_pi_taxonomy](https://github.com/Arcanum-Sec/arc_pi_taxonomy) | 757 | Prompt Injection 分类法 | 4 支柱/172 节点（Intents/Techniques/Evasions/Inputs），带参考代码 | 知识框架 | CC BY 4.0 |
| 8 | [tldrsec/prompt-injection-defenses](https://github.com/tldrsec/prompt-injection-defenses) | 727 | 防御方案汇总清单 | 9 大类（Blast Radius / Input Preprocessing / Taint Tracking / Dual LLM 等） | 知识框架（设计原则） | — |
| 9 | [arcjet/arcjet-js](https://github.com/arcjet/arcjet-js) | 681 | AI 运行时安全平台 | 输入注入检测 + tool call 鉴权 + PII 脱敏 + 速率限制 + 机器人防护 | 输入 / 工具调用 / 输出 | Apache-2.0 |
| 10 | [StackOneHQ/defender](https://github.com/StackOneHQ/defender) | 119 | Agent tool call 间接注入防护 | 3 层检测：T1 正则 → T2 MiniLM 分类器 → T3 可选 LLM，句子级清洗 | **工具调用输出**（MCP/function calling） | Apache-2.0 |
| 11 | [superagent-ai/superagent](https://github.com/superagent-ai/superagent) | 6,721 | AI 应用综合安全 | 注入检测 + 数据泄露防护 + 有害输出过滤 | 输入 / 输出 | MIT |
| 12 | [BerriAI/litellm](https://github.com/BerriAI/litellm) | 57,547 | AI Gateway（含护栏） | 代理层内容审核、护栏编排、成本追踪、100+ 模型路由 | 网关层 | 多 License |

---

## 二、核心机制详解

### 2.1 StackOneHQ/defender — 最精准贴合多智能体场景

**为何是 Top 1 适配：** 直接针对「工具调用返回结果」的间接注入，这是多智能体场景里子代理间攻击传播的核心路径。

- **Tier 1 正则（同步，~1ms）：** 检测角色标记（`SYSTEM:`, `<system>`, `[INST]`）、注入短语（"ignore previous instructions"）、编码载荷（Base64/URL/ROT/Morse）、Unicode/leet 混淆、风险字段白名单（仅扫描 `body`, `content`, `subject` 等高风险字段）
- **Tier 2 ML 分类器（异步，~10ms）：** 捆绑 22MB 量化 MiniLM-L6-v2 ONNX 模型，句子级打分，多头部架构（辅助头识别元讨论/文档引用，避免误报），F1=90.8%
- **Tier 3 可选 LLM（消费者提供，级联/仅 T3 模式）：** 可配置级联决策带灰度带
- **输出：** `allowed` (阻挡决策) + `sanitized` (句子级清洗后的安全副本) + 多层次诊断信号
- **批处理：** `defendToolResults()` 并发处理多个工具返回

### 2.2 NVIDIA/SkillSpector — 安装前防线

对 **dsh-codepunk 的 skill 注册/加载环节**有直接价值：
- 71 种漏洞模式覆盖 17 类：prompt injection、data exfiltration、privilege escalation、supply chain、excessive agency、memory poisoning、tool misuse、rogue agent、MCP least privilege、MCP tool poisoning
- 两阶段分析：快速静态分析（AST/YARA）→ 可选 LLM 语义评估
- 输出格式：Terminal / JSON / Markdown / SARIF
- 风险评分：0-100 分 + 严重度标签
- 集成了 OSV.dev 实时 CVE 查询

### 2.3 protectai/rebuff — 4 层防御 + Canary Token

- **Heuristics：** 规则过滤（输入到达 LLM 之前）
- **LLM 检测：** 专用 LLM 分析输入
- **VectorDB：** 存储历史攻击嵌入，未来相似攻击自动匹配
- **Canary Token：** 在 prompt 模板中嵌入金丝雀词，检测输出泄露 → 将泄露输入存入 VectorDB 实现自强化

### 2.4 Arcanum-Sec/arc_pi_taxonomy — 分类法框架

- 172 节点：Intents(27) / Techniques(70) / Evasions(63) / Inputs(12)
- 每个节点有参考代码（如 `PIT-I-01`）、别名映射（OWASP/MITRE ATLAS/NIST/MLCommons/garak）、示例 prompt
- JSON 格式可直接消费，适合作为 dsh-codepunk 的知识库输入

### 2.5 tldrsec/prompt-injection-defenses — 9 大防御策略

关键策略摘要（完整见 repo）：
| 策略 | 说明 | 多智能体价值 |
|------|------|-------------|
| Blast Radius Reduction | 假设注入必然发生，最小化引爆半径 | ★★★★★ 核心设计原则 |
| Taint Tracking | 标记不信任数据流，跟踪污染传播 | ★★★★★ 子代理间关键 |
| Secure Threads / Dual LLM | 隔离指令执行和用户内容的 LLM | ★★★★☆ 隔离子代理 |
| Guardrails / Overseers | 专用监控模型审计输入输出 | ★★★★☆ 代理监督层 |
| Input Pre-processing | 重述/重分词的输入变换 | ★★★☆☆ 辅助防御 |

---

## 三、对 dsh-codepunk 多智能体场景的适配分析

### 适配点 1：子代理间注入传播（Inter-Agent Message Passing）

| 维度 | 内容 |
|------|------|
| 威胁 | Agent A 的输出（含恶意注入）被 Agent B 作为系统级指令处理 |
| 【事实】 | tldrsec 汇总的 Taint Tracking 策略可标记每个消息的"数据来源"属性 |
| 【事实】 | defender 的 Tier 1 正则检测可捕获角色标记和指令覆盖短语 |
| 【推断】 | 在 dsh-codepunk 的 Message Passing 管道中插入 defender 级别的检测层，对每条跨代理消息做 `analyze()` 或 `defendToolResult()` 检查其输出 |
| 【推断】 | 利用 arc_pi_taxonomy 的 `PIT-T-*`(Techniques) 分类来设计检测规则，覆盖 70 种操纵手法 |

### 适配点 2：Tool Call 注入

| 维度 | 内容 |
|------|------|
| 威胁 | 恶意内容通过 tool 返回结果注入 LLM 上下文 |
| 【事实】 | defender 的 `defendToolResult(value, toolName)` 直接针对此场景，支持 `blockHighRisk` 和句子级清洗 |
| 【事实】 | arcjet 的 `@arcjet/guard` 提供 tool call 鉴权规则 |
| 【推断】 | 在 dsh-codepunk 的 `tool.execute()` 回调中嵌入 defender 作为中间件，对工具返回结果做 allow/block 决策 |
| 【推断】 | T2 ML 分类器（22MB, ~10ms）可接受的生产延迟，适合在 Agent 工作流中插入 |

### 适配点 3：记忆污染（Memory Poisoning）

| 维度 | 内容 |
|------|------|
| 威胁 | 恶意输入通过长期记忆持久化，影响后续所有轮次 |
| 【事实】 | rebuff 的 Canary Token 机制可以在写入记忆前嵌入 token，读取时检测泄露 |
| 【事实】 | llm-guard 的 InvisibleText scanner 可检测零宽字符/不可见文本 |
| 【推断】 | 在 dsh-codepunk 的记忆写入/读取接口上部署 rebuff 风格的 canary token 检测 |
| 【推断】 | 记忆读取时用 defender 或类似 ML 模型做异常评分 |

### 适配点 4：Skill 供应链安全

| 维度 | 内容 |
|------|------|
| 威胁 | 注册的第三方 skill 包含恶意注入的指令或工具定义 |
| 【事实】 | SkillSpector 可直接扫描 skill 包，71 种模式覆盖 supply chain / rogue agent / excessive agency |
| 【事实】 | 26.1% 的 agent skill 含漏洞，5.2% 可能有恶意意图（SkillSpector 研究数据） |
| 【推断】 | 在 dsh-codepunk 的 skill 注册/加载流程中集成 SkillSpector 作为前置检查门闩 |
| 【推断】 | 可使用 SkillSpector 的 SARIF/JSON 输出对接 dsh-codepunk 的巡检阶段 |

---

## 四、TOP 落地建议（按优先级排序）

### 🥇 1. 集成 defender 到 Tool Call 输出管道

**理由：** 直接命中多智能体最大攻击面（工具调用返回注入），延迟低（~10ms），模型轻量（22MB CPU-only），Apache-2.0 兼容。

**建议集成方式：**
```
Agent A 调用 tool → tool 返回原始结果 → defender.defendToolResult() → allowed?
  ├─ YES → 传递 sanitized 到 LLM
  └─ NO  → 阻断 + 记录攻击签名到本地 VectorDB
```

### 🥇 2. 采用 SkillSpector 做 Skill 安装前扫描

**理由：** 71 种漏洞模式覆盖 agent 特有风险（excessive agency / rogue agent / MCP tool poisoning），NVIDIA 维护，对 dsh-codepunk 的 skill 注册环节零成本集成。

### 🥇 3. 引入 arc_pi_taxonomy 作为知识库

**理由：** 172 节点分类法提供标准引用编码（`PIT-T-*`），可直接用于 dsh-codepunk 的防护规则设计、巡检 checklist 和评分标准。

### 🥈 4. 参考 tldrsec 防御策略设计 Taint Tracking

**理由：** blast radius reduction 和 taint tracking 是多智能体场景的核心设计原则，应在架构层面（而非仅代码层面）落地。

### 🥉 5. 评估 arcjet 的 runtime security 作为补充层

**理由：** tool call 鉴权 + PII 脱敏，但需要 Arcjet 云服务，对 dsh-codepunk 离线场景有依赖考量。

---

## 五、License 一览

| 项目 | License | 商用兼容 | 备注 |
|------|---------|---------|------|
| NVIDIA/SkillSpector | Apache-2.0 | ✅ | 宽松 |
| guardrails-ai/guardrails | Apache-2.0 | ✅ | 宽松 |
| protectai/llm-guard | MIT | ✅ | **已归档，不再维护** |
| protectai/rebuff | Apache-2.0 | ✅ | 宽松 |
| trailofbits/anamorpher | Apache-2.0 | ✅ | 攻击侧工具 |
| luckyPipewrench/pipelock | Apache-2.0 | ✅ | 较新 |
| Arcanum-Sec/arc_pi_taxonomy | CC BY 4.0 | ✅ | 署名使用 |
| arcjet/arcjet-js | Apache-2.0 | ✅ | 宽松 |
| **StackOneHQ/defender** | **Apache-2.0** | ✅ | **推荐首选** |
| superagent-ai/superagent | MIT | ✅ | 宽松 |
| tldrsec/prompt-injection-defenses | — | ✅ | 仅汇总清单，无代码 |

---

## 六、检索说明

| 项目 | 值 |
|------|-----|
| 检索窗口 | 2026-08-29T20:40–20:45 UTC |
| 渠道 | GitHub REST API v3 (`search/repositories`)，`raw.githubusercontent.com` 直连 README |
| 搜索策略 | 4 组关键词交叉搜索确保覆盖：`prompt injection`(exact) → `prompt injection protection` → `llm guardrails` → `promptguard OR rebuff OR llm-guard` |
| 排序依据 | GitHub stars（降序），取每组前 5-12，去重后按 stars 排列 |
| 数据状态 | 截至检索时间点的最新数据；llm-guard 因已归档排除在推荐之外 |

---

*简报由 ind-res（调研小组）产出，内容为外部调研事实与推断，未经工程主责审核不应直接用于实现决策。*