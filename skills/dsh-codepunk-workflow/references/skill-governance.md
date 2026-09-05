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

## 五、实施规划（当前已应用技能全景，30 条全接线）

| 决策号 | 技能 | 来源 | 应用位置 | 版本 |
|---|---|---|---|---|
| D024 | 并行软上限：S=1 / M=3 / L=6（max_awake 8） | 流程设计 | SKILL §2 ③ | v1.0 |
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

## 六、文档小组职责（技能治理执行者）

1. **月度技能复检**：检测外部源变化（§3.1 触发器），写升级评估交 run-lead 审定
2. **技能档案维护**：benchmarks/references/learned-skills 三件套的持续更新
3. **提示词优化**：应用效果反馈 → 修订岗位人设中的技能条款
4. **升级留痕**：版本标记 + 升级历史，确保可追溯

> 技能治理是**持续回路**而非一次性：每次新技能应用都走「调研→审定→应用→升级」完整流程，且**必须先文档化再应用**（本文件 §二 三件套 MUST）。