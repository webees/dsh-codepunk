# 技能治理与升级机制（references/skill-governance.md）

> D083 完整展开。**目的**：所有从外部学习/整理的 skill 规范文档化存储，且具备**可追踪、可升级、可废弃**的迭代机制——确保 dsh-codepunk 持续吸收外部最佳实践而不失权威性。

## 一、技能生命周期（四态）

```text
调研（ind-res 联网） → 审定（run-lead） → 应用（落地入册） → 升级（复检迭代）→ 废弃（过时移除）
```

| 阶段 | 动作 | 产物 | 责任人 |
|---|---|---|---|
| **调研** | 联网抓取外部 skill/仓库，提炼机制 | `benchmarks/<topic>-analysis.md`（URL+retrieved_at+事实/推断） | 调研岗 ind-res |
| **审定** | run-lead 判定适配性（价值/风险/license/与既有关系） | 决策：应用 or 拒绝 | run-lead |
| **应用** | 落成人设/流程/细则文件 + 登记决策号 | `references/<topic>.md` + standard.md 登记 + 岗位人设 | run-lead |
| **升级** | 定期复检外部源变化 → 评估是否同步 | 版本核对记录 + 增量更新 | 文档小组 |
| **废弃** | 机制过时/被替代 → 移除或归档 | 归档标记 + learned-skills 更新 | run-lead |

## 二、技能文档化存储（三件套，MUST）

每项学到的技能必须同时落三处：

1. **调研简报** `benchmarks/<topic>-analysis.md`：来源、机制、适配点、license、检索留痕（URL + retrieved_at + 事实/推断标注）
2. **应用细则** `references/<topic>.md`：落地规则（人设/流程/产物模板可引用）
3. **溯源总表** `references/learned-skills.md`：决策号、学到什么、来源仓库、应用位置

> 铁律：**无简报不应用、无细则不引用、无溯源不登记**——三项缺一不可。

## 三、技能升级机制

### 3.1 升级触发点（外部源变化检测）

| 触发器 | 检测方式 | 响应 |
|---|---|---|
| 外部源 major 更新（star 激增/功能换代） | 文档小组定期（每月）`git ls-remote` / GitHub API 对比 | 重抓 README+SKILL.md diff，评估增量 |
| 外部源废弃/下架 | API 404/README 清空 | 评估 dsh 依赖该技能的条款 → 保留 or 移除 |
| 新同类技能出现（更优） | 调研岗生态扫描（如 VoltAgent 目录） | 对比替代 → 决定迁移 |
| 项目实践反馈（技能应用效果不佳） | proc-audit 巡检红灯 / 文档小组运行观察 | 回退或修订细则 |

### 3.2 升级流程（增量，不重写）

```text
1. 文档小组检测外部源变化 → 写升级评估（新机制/收益/风险/兼容）
2. run-lead 审定：采纳 / 部分采纳 / 拒绝
3. 采纳 → 增量更新 references/<topic>.md + standard.md 决策号释义 + learned-skills 溯源
4. 校验（解析/体积/零旧名）→ 推送
5. 更新技能版本标记（见 §四）
```

### 3.3 废弃流程

```text
1. 触发：机制过时/被替代/与新版 harness 冲突
2. 评估影响面（SKILL 引用/岗位人设/产物模板）
3. run-lead 裁决 → 移除引用 + 细则文件标「已废弃 YYYY-MM-DD，原因」+ learned-skills 更新
4. 决策号保留（历史权威），新增不重用
```

## 四、技能版本标记

- `learned-skills.md` 每行溯源加**技能版本**：`v1.0（应用日期）`；升级后 `v1.1（更新内容摘要）`。
- 升级历史追加在该技能行下（缩进列表），不覆盖旧记录（可追溯演进）。
- SKILL.md §7 引用加「（当前 vX.Y）」标注最新。

> **当前状态与向前适用（2026-10-05 实测）**：本节三项**尚未落实到位**，记录在此以便对齐——
> ① `learned-skills.md` 现有 32 行溯源**均带版本号但无一附「（应用日期）」**（历史行缺日期数据，
> 不回溯编造；新增行 MUST 按格式补日期）；
> ② 唯一升级行 `D096`（`v1.1`）**未附升级历史/摘要**（其行下无缩进列表；后续升级 MUST 追加，
> 不覆盖旧记录）；
> ③ SKILL.md §7 的逐条「（当前 vX.Y）」标注**尚未加入**（新增引用时随行补注）。
> 本节仍是 MUST——上述仅为存量欠账清单，不得以现状为格式范例。

## 五、实施规划（当前已应用技能全景）

> 本表为**全景清单**（当前 34 行，随表维护）——标题与正文**不写死条数**，避免与表格/`learned-skills.md`/`standard.md` 的实际条数漂移（历史教训：曾写「30 条」而表格已有 34 行）。

| 决策号 | 技能 | 来源 | 应用位置 | 版本 |
|---|---|---|---|---|
| D024 | 并行软上限：S=1 / M=3 / L=6（本预设自律上限，非平台字段） | 流程设计 | SKILL §2 ③ | v1.0 |
| D031 | 双门闩齐即自动开工 | 流程设计 | SKILL §2 ③ | v1.0 |
| D034 | goal active 前 product_acceptance[] 非空 | 流程设计 | SKILL §2 ① / artifacts | v1.0 |
| D035 | sponsor 通道与 goal 终裁归工程主责 | 流程设计 | SKILL §2 ① / agent.cordis.yml | v1.0 |
| D038 | 需求变更只走 change_orders | 流程设计 | SKILL §3 R6 / artifacts | v1.0 |
| D065 | sponsor 随时投喂、分诊并入 | 流程设计 | SKILL §2 ① | v1.0 |
| D066 | goal 自动续行 | DSH 平台 | SKILL §0.1 | v1.0 |
| D067 | checkpoint 断点续行 | langgraph | SKILL §2③ | v1.0 |
| D068 | 门禁 guardrail | crewAI/ADK | SKILL §2④ | v1.0 |
| D069 | schema 强约束 | outlines/agentskills | artifacts + evidence-verify.sh | v1.0 |
| D070 | 硬信号评分 | CAMEL/ChatDev | knowledge.md | v1.0 |
| D071 | 委托契约 | ADK/Swarm | roles.md | v1.0 |
| D072 | 总库语义 | 自研 | SKILL §1 | v1.0 |
| D073 | worktree 生命周期 | 实战 | SKILL §2⑤ | v1.0 |
| D074 | 上下文纪律 | Anthropic | SKILL P07 + 人设 | v1.0 |
| D075 | 消息纪律 | i-have-adhd | SKILL P07 + 全员 | v1.0 |
| D076 | token 经济学 | caveman | SKILL P07 + 人设 | v1.0 |
| D077 | 反幻觉 | superpowers/Anthropic | SKILL P07 + sdet | v1.0 |
| D078 | 模型路由 | dsh-llm-deepseek | model-routing.md | v1.0 |
| D079 | 文件卫生 | agent-housekeeping | file-hygiene.md | v1.0 |
| D080 | 撰写标准 | 实战 | roles.md | v1.0 |
| D081 | 产出纪律 | ponytail | anti-overengineering.md | v1.0 |
| D082 | 文档配图 | diagram-design | diagram-guide.md + docs 人设 | v1.0 |
| D083 | 技能治理与升级 | 自研治理机制 | skill-governance.md / 文档小组 | v1.0 |
| D084 | 注入防护 | defender/SkillSpector/rebuff | prompt-injection-rules.md / 巡检 | v1.0 |
| D085 | 知识库记忆增强 | Mem0/OpenViking/Letta | memory-enhancement.md / knowledge | v1.0 |
| D086 | 限流自适应 | 实战经验 | rate-limit-adaptation.md / SKILL §③ | v1.0 |
| D087 | ⚠已废弃（D089 取代）岗位路由改道 | 实战 | model-routing.md §五 | v1.0 |
| D088 | 子代理可恢复性（continuable） | 实战 | agent.cordis.yml / preset-tool-fixes F-003 | v1.0 |
| D089 | 模型统一与回退 | 实战经验 | model-fallback.md / settings | v1.0 |
| D090 | 子代理路由双要件（agentOptions + continuable） | 实战经验 | agent.cordis.yml / model-routing.md | v1.0 |
| D094 | 启动自检与子代理恢复 | 实战需求 | SKILL §1.1 第 4 条 / stages.md §③ / agent.cordis.yml | v1.0 |
| D095 | 定时巡检与子代理状态清单 | 内部需求 | SKILL §1.1 第 5 条 / artifacts.md | v1.0 |
| D096 | 持久 shell 与工具调用超时 | DSH 2.0.12 | SKILL §4 / agent.cordis.yml | v1.1 |

## 六之前·检查器覆盖矩阵（哪类缺陷由谁负责）

> 目的：明确「机械把关 vs 人工把关」的边界，避免误以为有工具就万无一失。**空档列已如实标注**——
> 空档类缺陷只能靠人工逐条比对（历次审计中该类占比最高）。
> 「元检查」= 检查器自身的存活验证（防「守护空转」）。

| 缺陷类别 | 负责检查项 | 方式 |
|---|---|---|
| 组合/岗位不变量（缺 persona、非 continuable、disabled、缺 toolFilter） | `preset-audit` A7 | 机械 |
| YAML 可解析 / 条目形状 | `preset-audit` A1 · `preset-compat` 配置键项 | 机械 |
| 组合 ↔ DSH 兼容（包存在/键接受/隔离/锚点/allow 名单） | `preset-compat`（7 项） | 机械 |
| 源 ↔ profile 副本漂移 | `preset-declare check`（语义）+ `verify-battery` 8b | 机械 |
| 脚本语法（`.sh`/`.ps1`/`.py`/`.mjs` 四类） | `verify-battery` 7 | 机械 |
| 路径/脚本引用存在性（含 references 内、markdown 死链） | `preset-score` A2 · `preset-audit` E3 | 机械 |
| 编号一致性（D/P/R 定义与引用、重复号） | `preset-audit` B7/D1/D3 · `preset-score` | 机械 |
| 编号引用**可解析**（D 须逐条登记；P 须落在声明范围/span 内） | `doc-consistency.sh` 第 9 类 | 机械 |
| 章节级引用**可解析**（对 `references/<文件>.md` 的「章节名」引用、限定式 `§N`） | `doc-consistency.sh` 第 10 类 | 机械 |
| benchmarks **支撑决策号语义**（括注短名 ↔ 登记含义的 2-gram 重叠） | `doc-consistency.sh` 第 11 类 | 机械 |
| **状态机自洽**（`status:`/`expected:` 取值须落在已声明集合内；集合自模板注释自动采集） | `doc-consistency.sh` 第 12 类 | 机械 |
| **死状态**（模板声明的每个状态值 MUST 在**正文**被步骤引用，否则无主体/无触发条件） | `doc-consistency.sh` 第 13 类 | 机械 |
| **评分扣分可达性**（37 个扣分点须有「注入定向缺陷 → 该指标降级且命中其理由」的证据；当前已证：**B6–B15 全 10 项指标、34 条扣分分支**（M28 六条 + M29 八条 + M30 十四条；余 B14 两条与 B13 逐条 R 行属同族已证），其余按需补） | 自检 `M28`–`M30` | 机械 |
| **部分流程自洽**（阶段引用可解析：悬空引用／孤立阶段——矩阵空档已机械化） | `doc-consistency.sh` 第 15 类（双向负向验证通过） | 机械 |
| **夹具字面量纪律**（自检夹具不得含触发本仓守卫的字面量：用户目录绝对路径／邮箱形态／私网地址；须运行时拼接，否则副本内评分与泄露门会命中夹具自身） | `doc-consistency.sh` 第 14 类 | 机械 |
| 已登记的计数声称（15 指标 / 5 组 / 13 项电池 / 岗位数） | `preset-score` A3 · `preset-audit` B1 | 机械 |
| 泄露与品牌卫生 | `leak-guard`（3 模式 + 三钩子）· `preset-score` B5/B11 | 机械 |
| 格式/EOL/杂散/全角紧邻陷阱 | `verify-battery` 4/5 · `preset-audit` B1b | 机械 |
| 失败路径提示与退出码契约 | `checker-self-test` M10–M13 | 机械（变异） |
| **守护空转**（检查器因工具缺失/正则不兼容/空值判定而恒判 PASS） | **`checker-self-test`（15 断言）** | 元检查 |
| 跨文件同机制**阈值一致**（证据门 exit_code / 评分 base·clamp / retries / handoff 缺件 / 巡检周期 / 收口轮数） | `doc-consistency.sh` 第 7 类 | 机械 |
| benchmarks **间结论一致**（同一外部来源在不同简报中的机制描述是否矛盾） | 无（**实测不可机械化**：按来源聚合行内数字的扫描输出以 D 号/日期/无关量为主，无判据价值） | 人工：对跨 ≥2 简报的来源做**定向机制比对**（实测判据=同一来源的分许可/分组件表述须互补而非互斥，如 caveman 的 MIT 部分与 BSL 部分） |
| 文档**声称 ↔ 实现**（计数/阶段口径/工具存在性/退出码契约） | `doc-consistency.sh` 第 1–6 类 | 机械 |
| **术语一致性**（含「工作房」vs「工作区」消歧） | 无（**实测不可机械化**：简单抽取器在 498 条「**词**：」命中中产出的候选几乎全为散文引导词） | 人工：对**核心术语**（双门闩/工作房/写集/交接包/门禁/证据 verdict 等）逐条比对定义句，实测判据=同名术语的括号注与谓词表述一致 |
| **日期形态与未来日期**（须 ISO；「实测」不得标在未来） | `doc-consistency.sh` 第 8 类 | 机械 |
| **日期时效性**（文档内实测结论是否已过期） | 无 | 人工 |
| 需求/流程自洽（阶段归属、汇报链、责任席位是否有人） | 部分（A7/结构检查） | 半人工 |

## 六、文档小组职责（技能治理执行者）

1. **月度技能复检**：检测外部源变化（§3.1 触发器），写升级评估交 run-lead 审定
2. **技能档案维护**：benchmarks/references/learned-skills 三件套的持续更新
3. **提示词优化**：应用效果反馈 → 修订岗位人设中的技能条款
4. **升级留痕**：版本标记 + 升级历史，确保可追溯

> 技能治理是**持续回路**而非一次性：每次新技能应用都走「调研→审定→应用→升级」完整流程，且**必须先文档化再应用**（本文件 §二 三件套 MUST）。
