# 标号总表（references/standard.md）

本栏目的 `Pxx` / `D0xx` 是流程**内部稳定标签**：用于跨文档引用而不重复正文。
它们不是外部规范的编号 —— 本文件是它们的**唯一权威释义**。

## 阶段号（P01–P17，预留号段，只登记在用项）

| 标号 | 含义 | 正文位置 |
|---|---|---|
| P01 | ① 需求确认 | SKILL.md §2 ① |
| P02–P04 | ② 规划与组队（分块 / 简报 / 用工） | SKILL.md §2 ② |
| P05–P06 | ③ 多小组并行开发 | SKILL.md §2 ③ |
| P06（复用） | ⑥ 再规划入口（♻️） | SKILL.md §2 ⑥ |
| P07 | ④ 巡检与交接（并覆盖 ⑤ 解散的开头） | SKILL.md §2 ④ / §2 ⑤ |
| P10 | ⑤′ 合并门（串行） | SKILL.md §2 ⑤′ |
| P11 | 记忆简报（文档小组 → 工程主责） | references/artifacts.md「记忆简报」 |
| P14 | 强制解散（外因超时 / 失败，先保存 WIP） | SKILL.md §5 失败处理 |
| P16 | ⑤ 解散与评分（人事） | SKILL.md §2 ⑤ / references/knowledge.md 评分公式 |

> 编号按语义复用（如 P06 既指并行开发也指再规划入口），**以正文位置为准**，
> 不在正文之外单独定义流程。未登记号段即预留，不暗示存在。

## 决策号（D0xx）

| 标号 | 一句话含义 | 出处 |
|---|---|---|
| D024 | 并行软上限：S=1 / M=3 / L=6（max_awake 8） | SKILL.md §2 ③ |
| D031 | 双门闩齐即自动开工，不必再等人工点头 | SKILL.md §2 ③ |
| D034 | goal active 前 `product_acceptance[]` 必须非空 | SKILL.md §2 ① / artifacts.md |
| D035 | sponsor 通道与 goal 终裁/确认记时归工程主责（`user_confirmed_at`） | SKILL.md §2 ① / agent.cordis.yml |
| D038 | 需求变更只走 `change_orders`（proposed→applied→closed） | SKILL.md §3 R6 / artifacts.md |
| D065 | sponsor 可随时投喂信息，按类分诊并入 | SKILL.md §2 ① |
| D066 | goal 自动续行/自动递送：create 即 armed、idle 自动唤醒消化排队消息、resume/fork 后需 resume 重武装、maxGoalRounds 为轮次预算 | SKILL.md §0.1 / R10 |
| D067 | checkpoint 断点续行：progress/handoff/evidence/工作房即可重放状态，中断后从最近断点精确续行，不整轮重来（借鉴 LangGraph durable execution） | SKILL.md §2 ③ |
| D068 | 门禁即显式节点 + 双侧 guardrail：双门闩/审查门/合并门入口验输入、出口验输出，不合格回退不滑入下一阶段（借鉴 crewAI Flow / ADK tool confirmation，开源基准） | SKILL.md §2 ④ |
| D069 | schema 强约束：evidence/acceptance 结构生成期保证机器可校验，校验不合格直接回退（借鉴 outlines / agentskills） | references/artifacts.md evidence.yaml 段内说明 |
| D070 | 硬信号驱动评分-再规划 + 经验→skill 沉淀回路：评分/再规划以证据文件事实为准，经验模板沉淀至 knowledge/lessons/（借鉴 CAMEL / ChatDev / graphify） | references/knowledge.md「硬信号驱动评分-再规划」 |
| D071 | 委托契约：每席显式声明「单轮受控输出 vs 多轮任务」，双侧 guardrail 校验（借鉴 ADK Task API / Swarm handoff） | references/roles.md「委托契约」 |
| D072 | 总库语义：运行根统一存 `~/.dsh-codepunk/projects/<id>/`，工程目录保持纯净；开工三件事（resolve → source dsh-codepunk-home.sh → 建运行根） | SKILL.md §1 |
| D073 | worktree 生命周期回收：合并完成即 `worktree remove --force + prune`（分支 refs 保留审计）；goal complete 前 MUST 核验 `worktree list` 仅主仓库（环境终态整洁是验收项） | SKILL.md §2 ⑤′ P10.5 / §2 ⑥.4 |
| D074 | 上下文纪律：证据只回 command+exit_code+log_ref（拒绝整段 stdout）；子代理汇报 ≤1500 token 摘要；主会话每轮压缩旧巡检记录防上下文堆积（借鉴 Anthropic 上下文工程） | SKILL.md §2 ④ / agent.cordis.yml 三席人设 |