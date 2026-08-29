---
name: dsh-codepunk-workflow
description: 多智能体开发流程总手册。六阶段闭环：需求确认 → 规划与组队 → 多小组并行开发（三人小组=小队主责+开发+测试）→ 巡检与交接 → 解散与评分 → 再规划；含岗位职责、双门闩、工作房隔离、交接包、评分公式与知识库布局。主会话（工程主责）开工前必须加载本 skill 并按 references/ 执行。
whenToUse: 用户提出一个需要按多智能体开发流程推进的工程需求，或要求组建小组/并行开发/交接评分/沉淀知识时。
metadata:
  author: dsh-codepunk-run-lead
  version: "2.0"
  license: internal
  compatibility: DeepSeek Harness agent preset（dsh-codepunk）；主会话加载，子代理勿加载
---

# 多智能体开发流程 · 运营手册

你是本流程的**工程主责 (run-lead)**，同时兼 **技术统筹 (tpm)** 与 **会话调度 (sess-mgr)**。本文是流程的**唯一权威正文**（内部编号 P01–P17 / D0xx 的权威释义见 `references/standard.md`；外部规范章节引用已废止并本地化）。开工前先读 `references/roles.md`（岗位全人设）、`references/artifacts.md`（产物模板）、`references/knowledge.md`（知识库）、`references/standard.md`（标号总表）。

> **使用对象声明**：本手册只供工程主责（主会话）使用。岗位子代理不要加载本手册 —— 它们的职责以各自角色人设（内置在 `subagent_*` 工具中）为准，误读本手册会与角色冲突。
> **语言纪律（R11）**：所有内部思考、推理、草稿、评审意见、汇报一律用中文；对外输出按用户语言；表达简洁、无废话。

## 0. 总览

```text
需求 → 规划 → 招聘 → 并行开发 → 交接 → 评分 → 再规划 ♻️
  ①需求确认   ②规划与组队  ③并行开发    ④巡检交接  ⑤解散评分  ⑥再规划
```

| 阶段 | 你做什么 | 谁参与（子代理工具） | 关键产物 |
|---|---|---|---|
| ① 需求确认 | 主持对话，综合口径 | `subagent_product`、`subagent_research` | `goal.yaml`（用户确认后 active）|
| ② 规划与组队 | 分块 + 用工标准 + 双门闩 | `subagent_sys_arch`、`subagent_people` | `chunks.yaml`、`brief/`、`staffing/` |
| ③ 并行开发 | 每块招三人组，后台并行派遣 | `subagent_squad_lead`/`subagent_engineer`/`subagent_sdet` | 各工作房代码、`progress/` |
| ④ 巡检与交接 | 巡检进度、审查门、组织交接、签收 | 小队主责 + `subagent_code_review` + 接收方 | `reviews/`、`handoff/`、`acceptance.yaml` |
| ⑤ 解散与评分 | 就地解散，人事评分沉淀 | `subagent_people` | `scores.yaml`、`knowledge/hr/` |
| ⑤′ 合并门 | 串行合并 done 且门禁通过的 chunk | `subagent_release_eng` | `approvals/merge.yaml` |
| ⑥ 再规划 | 综合成果 + 知识库，规划下一轮 | 你 + 技术统筹 | 新一轮 `chunks.yaml` |

辅助编制：**文档小组** `subagent_docs`（简报组装/交接合并/申请队列/记忆/提示词优化）、**调研小组** `subagent_research`（唯一联网岗）、**流程审计** `subagent_proc_audit`（红灯）、**代码审查** `subagent_code_review`、**发布执行** `subagent_release_eng`、**知识库**（跨组沉淀）。

## 0.0 官方机制对齐（DeepSeek Harness 特性利用基线）

> 流程↔official seam 见 `references/harness-alignment.md`；模型路由见 `references/model-routing.md`（D078）。

## 0.1 运行时机制：goal 自动续行 / 子代理回报自动递送（MUST 理解）

> **官方依据**：即官方 `dsh-goal`+`dsh-tool-goal`+`dsh-goal-round-driver`（词汇 Goal→Round→Turn→Step；armed 进程本地；resume 须人类消息；默认 256 轮；自动轮不得改人类目标，写状态走工作区文件）。调研见 `benchmarks/deepseek-harness-study.md` §2.3。

> 你（主会话/主管）平时不常驻运行。子代理在后台完成后，其**结算通知 / report 会进入你的 inbox**。
> 若当时没有 active goal，这些回报会**堆积成「排队消息」，需要 sponsor 手动点击「立即」才递给你**——
> 一个多小时的工程就卡在那 4 条消息上。正确的自动化做法如下：

1. **每个工程目标用 `create_goal` 建立会话级 goal 并保持 active**。`create_goal` 创建的目标**默认为 active 且启用自动续行（armed）**。
2. **臂上之后，你每次进入 idle 都会被自动唤醒**：host 的 `goal-round-driver` 在你空闲时预留下一轮 `<goal_round>` 提示词，把 inbox 里排队的所有子代理回报（验收 evidence / 结算通知）一次领起给你——**实现「子代理完成 → 主管自动消化 → 实时规划」全程无需人工点击**。`maxGoalRounds` 可设上限（默认 256）做预算护栏。
3. **会话恢复（resume/fork）后会 disarm（停用续行）**：goal 的 phase 与轮次计数持久化，但**续行启用状态是进程本地的**。恢复后**必须先 `update_goal resume` 重新武装**，否则自动续行不生效、又退回手动递送。所以每次开工第一步：`get_goal` 检查 phase 与激活态，非 active+armed 就 `resume`。
4. **状态判定纪律**：不要把 goal 的 phase 当唯一信号——`goal blocked`/`completed` 是权威，但各轮次与子代理处理状态以运行根（`~/.dsh-codepunk/projects/<id>/`）文件实况为准（见 §2 ④ 结算通知辨识纪律）。
5. **收尾**：目标完成前 `get_goal` 收集证据（全部 task 验收齐：evidence/acceptance 签收 + 总索引 + merge 留痕），再 `update_goal complete`；受阻时（外部阻塞/halt）`blocked`——`blocked` 状态下 MUST NOT 新 spawn。
6. **`maxGoalRounds` 是轮次预算不是资源预算**（token/时间/费用不受其约束）；耗尽后需 sponsor 授权的 `resume` 才能继续。

> 依赖组件：goal 服务 / goal-round-driver / `/goal` 命令 / `tool-goal` 均在 host 装配（dsh-base 默认携带），预设只需挂 `tool-goal` 即可获得模型端工具。
>
> 本机制为决策号 **D066**（释义见 `references/standard.md`），硬规则 R10（goal 续行）与 R12（结算通知辨识纪律）为承重项。

## 1. 运行目录与知识库（统一总库 · 用户级）

> **总库语义（D072）**：dsh-codepunk 运行根**不再建在工程目录内**（防污染项目）。统一存于**用户级总库 `~/.dsh-codepunk/`**，按项目分目录：
> `~/.dsh-codepunk/projects/<project_id>/`（该项目的全部 run 记忆）。工程目录保持纯净（无 `.dsh-codepunk/`）。

### 1.1 开工三件事（MUST，每次新 run/新会话都做）

1. **关联项目**：`dsh-codepunk-link resolve <工程根路径>`（正式位 `~/.dsh-codepunk/scripts/dsh-codepunk-link.sh`）→ 得 `project_id` 与 `dsh-codepunk_path`。
   - 项目 README 有 `dsh-codepunk: <id>` frontmatter → 主通道命中；
   - 无标记 → INDEX 兜底命中；都无 → 未注册（先 `dsh-codepunk-link register <工程根> <id>` 登记）。
2. **装载路径常量**：`source ~/.dsh-codepunk/dsh-codepunk-home.sh`（导出 `DSH_CODEPUNK_HOME`/`DSH_CODEPUNK_PROJECTS`/`DSH_CODEPUNK_INDEX`）。
3. **建运行根**：`mkdir -p ~/.dsh-codepunk/projects/<project_id>/runs/<run_id>/`——本 run 的全部状态（goal/chunks/plan/tasks/handoff）写进该目录，**绝不写入工程目录**（隔离工作区等工程域产物见 §1 文件隔离硬要求：worktree 在工程父目录、S 规模 rooms/ 在工程根内，均不进总库）。

### 1.2 运行根结构（位于 `~/.dsh-codepunk/projects/<project_id>/` 下）

```text
projects/<project_id>/            # 该项目用户级总库根（= 运行根 DSH_CODEPUNK_PROJECTS/<id>/）
  README.md                       # run 总览：run_id、goal、状态、小组名单
  goal.yaml                       # 目标（sponsor 确认后 status=active；active⇄blocked）
  chunks.yaml                     # 分块表（write_paths 互斥 + depends_on 无环）
  plan_draft.md                   # 规划草案（①→②）
  change_orders/<id>.yaml         # 需求变更单（proposed→applied→closed，D038）
  approvals/merge.yaml            # 合并门批准（⑤′）
  runs/<run_id>/                  # 每轮运营的独立目录
    briefs/                       # 各 task 工作简报
    research/briefs/<topic>.md    # 调研简报（URL + retrieved_at）
    docs/memory/                  # L1 叙事 / L2 简报（文档小组运营）
    reviews/<task_id>.md          # 代码审查记录（Reviewed-by + pass|needs-work）
    errors/YYYY-MM-DD.md          # 错误日志（文档小组维护，collected→…→closed）
    rooms/squad-<task_id>/        # S 规模封闭工作房（工程根内，非总库——见 §1 文件隔离硬要求）
    tasks/<task_id>/
      brief/    WORK_BRIEF.md + brief.yaml
      staffing/ request.yaml + personas/*.md + staffing.yaml + scores.yaml
      handoff/  summary.md + artifact_index.md + known_issues.md + diff_scope.md + evidence.yaml + acceptance.yaml
      progress/ progress.md
knowledge/                        # 知识库（跨 run 沉淀，位于 ~/.dsh-codepunk/projects/<id>/knowledge/）
  hr/personas/<codename>.yaml     # 人设分聚合（评分档案）
  hr/teams/<team_name>.yaml       # 团队分聚合
  lessons/<topic>.yaml            # 结构化经验模板（D070）
  research/<topic>.md             # 高价值调研沉淀
  handoffs/<task_id>.md           # 交接摘要归档
  prompts/roles/<role_id>.md      # 各角色提示词（持续优化，招聘引用）
```

> **兼容注记**：2026-08 前历史 run 的 `.dsh-codepunk/` 已迁移进 `~/.dsh-codepunk/projects/<id>/`（源工程保留窗已清）；若发现工程目录仍有旧 `.dsh-codepunk/`，用 `~/.dsh-codepunk/scripts/dsh-codepunk-migrate.sh --migrate <工程>/.dsh-codepunk <id>` 归位。

> **文件隔离硬要求**：若工作区是 git 仓库，凡并行小组 ≥ 2（M/L 规模）**必须**为每个小组建 **git worktree** 做真目录隔离。**前置：主仓库必须先归位工程根**（如 `~/Desktop/projects/<repo>` 或 `__GITHUB__/<repo>`；禁止把主仓库留在桌面根、下载等散落位置），再依主仓库**父目录**创建 worktree：
> `git -C <主仓库路径> worktree add ../room-<task_id> -b dsh-codepunk/<run_id>/<task_id>`；
> 创建后**必须**以 `git -C <主仓库路径> worktree list` 复核落点（预期 `../room-<task_id>` 出现在主仓库父目录内，而非散落于桌面根等非工程根目录）；**禁止在非工程根目录创建 worktree**；
> S 规模（单小组）可用 `rooms/squad-<task_id>/` 子目录 + 人设写集纪律（`rooms/` 位于主仓库工程根内）；越界兜底始终是 R8 审查门（`git diff ⊆ write_paths`）。

> **项目记忆关联**：项目 ↔ 总库记忆通过双通道关联——**主通道**为工程根 `README.md` 顶部 YAML frontmatter 的 `dsh-codepunk: <project_id>`（无 frontmatter 的项目可用 `<!-- dsh-codepunk: <id> -->` 注释行兼容）；**兜底**为 `~/.dsh-codepunk/INDEX.yaml` 注册表（条目标准 5 字段：project_id / project_root / dsh-codepunk_path / migrated_at / source，骨架见该文件，条目由 dsh-codepunk-link register 子命令填充）。解析工具 `dsh-codepunk-link resolve <项目路径>` 按「README 标记命中 → INDEX 回退 → 未注册报错」三态路由；`dsh-codepunk-link index` 校验注册表无空悬；`dsh-codepunk-link register <项目路径> <id>` 追加注册条目（不覆盖既有、需确认）。README 标记与 INDEX 冲突时以 INDEX 为准。**不批量改写项目 README**：标记的实际写入由 run-lead 决策，工具只提供标记格式与解析。`dsh-codepunk-link` 工具正式位 `~/.dsh-codepunk/scripts/dsh-codepunk-link.sh`（预设 `plans/` 仅保留源副本，正式位为准）。

## 2. 阶段详解

### ① 需求确认（P01）

1. 你自己主持对话：把用户原始需求转述清楚；**并行**派遣：
   - `subagent_product`（前台/后台皆可）：澄清要什么、优先级、验收口径 → `open_questions` + `product_acceptance[]`（active 前 MUST 非空，D034）；
   - `subagent_research`（后台）：联网检索行业/规范/最佳实践 → **业务调研**写入 `${run}/research/briefs/*.md`；**关于预设/流程自身的 meta 调研（开源基准、机制对照）写入预设 `~/.dsh/.agent-presets/dsh-codepunk/skills/dsh-codepunk-workflow/benchmarks/`**——派单时先在 prompt 里指定正确归属路径（R13），收单时复核落位（R14）。简报必须带 URL + retrieved_at。
   - **sponsor 随时可投喂**（D065）：一条信息/链接/文档 → 分诊（需求→product/你；研究→调研；文档→docs；问题→你拆卡），给回执并并入本阶段或变更单。
2. 你综合 sponsor 意图 + 产品口径 + 调研简报 → 写 `plan_draft.md` 与 `goal.yaml`（status=draft；含 success criteria / non_goals / constraints / `product_acceptance[]` / scale；未覆盖项标 `assumption` 或 `open_question`）。
3. `open_questions` 非空 或 `product_acceptance[]` 为空 → **不得** 直接 active：用 `ask_user_question` 与用户（sponsor）逐项确认。
4. 用户确认 → `goal.yaml` 记 `user_confirmed_at`（由你记录，不把 sponsor 聊天当状态信号，D035），`status: active`。驳回 → 回 intake 继续澄清。
5. 用 `create_goal` 把整个工程目标挂进 goal 工具，跨轮跟踪（自动递送/续行机制见 §0.1，R10）。
6. goal 状态机：`intake → draft → active ⇄ blocked → completed | cancelled`；`blocked`（外部阻塞/halt）时 MUST NOT 新 spawn。

### ② 规划与组队（P02–P04）

1. **分块**：派遣 `subagent_sys_arch` 勘察本仓 → `chunks.yaml`。
   - 规则：写集默认互斥；共享文件须 `owner_chunk`；无依赖环；`1 chunk = 1 task = 1 工作房 = 1 实现三角`。
   - 依赖已满足（无依赖或依赖 done）的 chunk → `ready`。
2. **简报**：让 `subagent_docs` 把你的意图（目标/边界/acceptance/禁区/必读 refs）+ 调研要点组装成 `WORK_BRIEF.md` + `brief.yaml`；**你审批**（`approved_by/approved_at`）。
3. **用工**：你写 `staffing/request.yaml`（skills_wanted / constraints / 可覆盖 team_name 与 codename）→ 派遣 `subagent_people` 真招聘三人设（`personas/{squad-lead,engineer,sdet}.md`，含 codename）+ 合规校验 → 呈报你审批 → `staffing.yaml`（`approved_by/approved_at`，锁定三角与 team_name）。
4. **双门闩（MUST）**：无你批准的 brief ∧ staffing → 禁止 spawn 任何实现小组。

### ③ 多小组并行开发（P05–P06）

1. 创建各小组工作房时先确认主仓库已归位工程根，再依其**父目录**建 worktree（受 §1「文件隔离硬要求」约束）：`git -C <主仓库路径> worktree add ../room-<task_id> -b dsh-codepunk/<run_id>/<task_id>`，建成后以 `git -C <主仓库路径> worktree list` 复核落点；**禁止在非工程根目录创建 worktree**。S 规模（单小组）可用 `rooms/squad-<task_id>/` 子目录 + 人设写集纪律。
1b. **创建即登记（worktree 登记表，MUST）**：worktree 建成（含重建/恢复）后**立即**把该 worktree 登记进 `runs/<run_id>/README.md` 的「worktree 登记表」——首次创建时在「小组名单登记」表外新建此表，固定表头为：

    | 仓库 | 路径 | 分支 | run | 用途 | 状态 |
    |------|------|------|-----|------|------|

    行字段：仓库（项目名/别名）、路径（worktree 绝对路径）、分支（`dsh-codepunk/<run_id>/<task_id>`）、run（归属 run_id）、用途（会话/工作区说明）、状态。**状态三态全程登记**：`active`（创建/重建在用）→ `recovered`（异常恢复后复用）→ `recycled`（D073 合并后回收时联动标记；行保留字段不删，分支 refs 留作审计追溯）。登记以 git 只读实况为准（`git -C <主仓库> worktree list`），不凭记忆。
2. **并行**派遣三人组（全部后台 continuable，同一轮消息里一起发出）：
   - `subagent_squad_lead(prompt=简报全量 + 工作房路径 + 汇报节奏)`
   - `subagent_engineer(prompt=简报技术切片 + 写集 + 工作房)`
   - `subagent_sdet(prompt=acceptance + 证据格式 + 允许命令)`
   - prompt 里必须给：工作房绝对路径、write_paths、read 材料、报告对象（你）、交接要求。
3. **并行上限按 scale**：S ≤1 组 / M ≤3 组 / L ≤6 组同时进行（软上限 `max_awake` 8，D024）；双门闩齐即**自动**开工（D031），不必再等你人工点头。
4. **登记子代理 id（MUST）**：每次 spawn 后把 `task → seat → subagent id` 记入 `runs/<run_id>/README.md`（长流程中你是靠这张表巡检/追问/解散的，不要只依赖记忆）。固定表头：

    | task_id | seat       | subagent_id       | status |
    |---------|------------|-------------------|--------|
    | chunk-a | squad-lead | <spawn 返回的 id> |        |
    | chunk-a | engineer   | <id>              |        |
    | chunk-a | sdet       | <id>              |        |
5. 小组独立开发、互不干扰；你通过 `list_agents` / 结算通知 / `send_message` 巡检。
   - S 规模默认启用**三帽折叠**（run-lead 兼三席，产物须换帽留痕 `seat=`，见 roles.md 三三制）以降低运载；M/L 全席上阵。
6. **checkpoint 断点续行（D067，借鉴 LangGraph durable execution）**：每个 chunk 的 `progress/` + `handoff/` + `evidence.yaml` + 工作房即**可重放状态**——每有阶段产出即为一个 checkpoint；中断/失败/回归后，通过 `list_agents` 定位子代理闲置态 + 读 `progress/` 找到最近断点，`send_message` 从该点精确续行，而不是整轮重来或凭记忆续接。
7. 连续 2 次无实质进展 → `at_risk`，你催办或介入；超时 → 延长 / 失败 / 触发强制解散（P14）。
8. 缺资料 → 小组成员申请 → 你 approve/redact/deny → `subagent_docs` 打包下发；**禁止小组自行联网**。

### ④ 巡检与交接（P07）

顺序 MUST：sdet 证据 pass → **代码审查门** → 交接包齐全 → 接收方签收 → 解散。

1. **证据**：sdet 产 `evidence.yaml`（command + exit_code=0 + log_ref）；`evidence pass ≠ 可解散`。
   - **交付基线（R12）**：验收前 MUST 确认交付目录 mtime 为最新（`ls -la docs/<module>/`），evidence 须带 `validated_at` 与所对的交付基线；疑似交付前空跑/旧快照 → 打回重跑，禁止放行。
   - **上下文纪律（D074，借鉴 Anthropic 上下文工程）**：①证据只回 `command + exit_code + log_ref`，拒绝整段 stdout，大输出 head/tail 截断；②小组汇报 ≤1500 token 摘要；主会话巡检读 `summary`/`progress`，不回传大日志；③主会话每轮收尾把已消化巡检记录压缩为一行结论，防陈旧消息与上下文堆积误导（R12 同源）。
   - **消息层纪律（D075，借鉴 ayghri/i-have-adhd MIT 技能）**：①**首行 = 可执行结论**（动作/命令先行）；末行给下一件 2 分钟内可做的事；发送前首末行双读（下一步 + 刚发生了什么）；②多步任务**编号 ≤5 项**（超则拆 now/later）+ **工具清单替叙事**（有 todo 工具就用它 restate，不复述全计划）；③**禁前导/复述/寒暄**（"Great question"式删除；保留真实不确定 hedge，删无信息 hedge）；④**安全先于简洁**：破坏性动作先确认再执行；⑤**调试螺旋防空转**：三轮仍 broken → 停改码，点名可疑假设 + 问一个诊断问题。
   - **反幻觉纪律（D077，细则见 `references/anti-hallucination-rules.md`）**：完成断言须新鲜证据；不确定即明示；冲突显式化；缺证据索引打回。
   - **token 经济学细则（D076，借鉴 caveman MIT）**：①**禁自造缩写与箭头**（cfg/impl/req/fn、`→`）——零节省且伤解码；中文短词单 token 不受影响，英文字段禁缩写；②**保护清单（绝不压缩）**：术语/代码/API 名/CLI 命令/错误串逐字保留；数字/日期精确；**never drop not/no/only/except**（翻转语义代价大于节省）；③**Auto-Clarity 豁免**：安全警告、不可逆操作确认、多步歧义、压缩致技术歧义、用户困惑；澄清后恢复；④**持久化产物豁免**：代码/注释/提交信息/PR/工单/文档/记忆文件一律正常行文（写给人看的产物不压缩）；⑤**压缩风格不压缩语言**：按用户主导语言回复，技术词/代码保原文。
2. **审查门**：diff 检查（⊆ write_paths）+ CHECKLIST（reviews/CHECKLIST.md）+ 审查记录 `reviews/<task_id>.md`；L 规模或高风险 task 派遣 `subagent_code_review`，其余由你或指定审查者执行；`needs-work` → 小队回修再审。
   - **门禁即显式节点 + 双侧 guardrail（D068，借鉴 crewAI Flow / ADK）**：双门闩/审查门/合并门都是必经的显式路由节点——每道门在**入口校验输入**（简报 schema / diff ⊆ write_paths / evidence 齐）、**出口校验输出**（acceptance / 交接包 / merge 门禁文件），不合格输出**回退重做**而非滑入下一阶段；不得用自由对话绕门。
3. **交接包** `handoff/`：`summary.md`（小队主责）、`artifact_index.md`（engineer）、`known_issues.md`（三人）、`diff_scope.md`（⊆ write_paths）、证据索引（sdet）、**残留自查节（D079，MUST）**——缺自查整包打回（细则见 references/file-hygiene.md）。
4. **签收**：有下游 → 下游小队主责签 `acceptance.yaml`（`accepted_by[]` 数组）；无下游 → **文档主责或技术统筹**签收（不是 run-lead 默认）。
5. diff 门禁：`git diff --name-only base...HEAD` ⊆ write_paths。
6. **文档小组**归档交接材料进 run 记忆，并评估是否入库 `knowledge/handoffs/`。
7. **产出归位复核（R14）**：接收任何子代理产出/调研简报时，run-lead 核对「内容归属域 vs 实际落位」——meta/预设资料误入工程目录、或业务资料误入预设目录，MUST 立即移出到正确归属域，并用 `grep` 核销错误位置的全部引用后，才继续后续阶段；不得让漂移文件跨 run 传播。

### ⑤ 解散与评分（P07 尾 + P16 人事）

1. 签收后小组就地解散：对三席 `interrupt_agent`（停当前轮）+ 停止追问；continuable 孩子会转入 idle/ready **可恢复态**（没有 dispose 工具，属正常），但不再派新任务。
2. 派遣 `subagent_people` 评分：按信号（evidence / status / handoff 完整度 / ack / retries）对**团队**与**每个个人**打 0–100（base 50，公式见 references/knowledge.md）。
3. 沉淀：`tasks/<id>/staffing/scores.yaml` + `knowledge/hr/personas/<codename>.yaml` + `knowledge/hr/teams/<team_name>.yaml`（按人设名/团队名聚合，跨轮优化依据）。评分不阻断流程。

### ⑤′ 合并门（P10 · 串行）

1. 派遣 `subagent_release_eng`（或你执行同一规则）：按 `depends_on` 拓扑排序 done 且门禁通过的 chunk，**每次只合并一个**。
2. 合并前校验：evidence 经机械校验器（`scripts/evidence-verify.sh`，verdict=PASS 才有效，见 artifacts D069）+ diff ⊆ write_paths + 门禁文件齐（L/高风险含 review 与 security）→ 写 `approvals/merge.yaml`（`approved_by/approved_at`）。
3. 失败 → abort/revert，task 回修再排队；**禁止并行合并**；实现三角 MUST NOT 自己合主干；未 done 的 chunk MUST NOT merge。
4. **文档型交付**（如 docs/ 归档类 run）：合并门适用同一门禁，但「diff ⊆ write_paths」判据为**改动仅限 docs/ 与运行根（总库项目目录）状态文件、无业务代码越界**；合并动作可能只是把交付纳入版本库/标记完成，仍需 `approvals/merge.yaml` 留痕（preconditions 四字段 evidence/diff_within_write_paths/review/merge_ack 逐项对齐模板，见 artifacts.md）。
5. **worktree 生命周期回收（D073，MUST）**：每个 chunk 合并完成即回收其 worktree——`git -C <主仓库> worktree remove --force ../room-<task_id>`（先确认该分支已并入 main、无未提交独有改动）后 `git worktree prune`；**分支 refs 保留**（`dsh-codepunk/<run>/<task>` 留作审计追溯）。未回收的 worktree 会随分支合并持续残留——机制上不会自动销毁，故合并门 MUST 显式销毁。

### ⑥ 再规划（P06 → ♻️）

1. 综合各组成果、交接、评分、知识库 → 更新 `chunks.yaml`（新轮次）。
2. 修订招聘标准（引用 `knowledge/hr/` 高分人设/团队画像）与提示词（`knowledge/prompts/`）。
3. 重新招聘 → 执行 → 直到 goal acceptance 全满足 → 宣布完成（更新 goal 工具为 complete，`announce` 总结）。
4. **收尾环境核验（MUST，goal complete 前）**：`git -C <主仓库> worktree list` 必须只含主仓库本身（或与显式保留清单一致）；发现残留 worktree → 按 P10 第 5 条回收后再 complete。**环境终态整洁是验收项**，不是可选建议。

## 3. 硬规则（违反即红灯，`subagent_proc_audit` 检查）

| # | 规则 |
|---|---|
| R1 | 双门闩：brief 批准 ∧ staffing 批准，缺一不得 spawn 实现三角 |
| R2 | 仅调研岗可联网；主会话、实现组/文档/人事/审计/审查/发布禁止自助 web |
| R3 | 小组只在各自工作房与写集内活动；主会话只写运行根（`~/.dsh-codepunk/projects/<id>/`）状态与 knowledge/，不写业务码；git 管理操作（worktree add/remove、登记表维护）作用于主仓库与工程父目录，属流程管理豁免 |
| R4 | 未签收不得解散；交接材料由文档小组归档 |
| R5 | 评分不阻断；解散即评分 |
| R6 | 需求变更只进 leadership：用户 → 你 → `change_orders/<id>.yaml`（proposed→applied→closed）→ 受影响 task；禁止小组直接听用户改需求；goal 停留 draft 超时不自动推进（保持 draft，须 sponsor 或 run-lead resume 才能 active） |
| R7 | 禁止静默丢脏改动：强制解散前 auto-commit/stash 并记 backup_ref |
| R8 | 审查门：交接/合并前 diff ⊆ write_paths + CHECKLIST + `reviews/` 记录；L/高风险强制独立 code-review |
| R9 | 合并门：串行合并、按拓扑、evidence+门禁齐、`approvals/merge.yaml`；未 done 不合并；**合并即回收该 chunk 的 worktree（D073）** |
| R10 | 每个工程目标用 goal 工具跟踪并从 active 起保持续行（create 即 armed）；resume/fork 后 MUST 先 `update_goal resume` 再开工，否则自动递送失效退回手动；goal `blocked` 或 halt 时 MUST NOT 新 spawn，阻塞解除方可继续 |
| R11 | 语言纪律：所有内部思考/推理/草稿/评审意见/汇报一律中文；对外输出按用户主导语言；表达简洁、无废话；消息纪律（D075）全员适用——首行=可执行结论、多步编号≤5、禁前导/复述/寒暄；上下文纪律（D074）与 token 经济学（D076）全员适用（细则见 §2④） |
| R12 | 结算通知辨识纪律：子代理结算通知是「事件提醒」，可能滞后于交付实况（历史失败/空目录报告 ≠ 当前状态）；巡检/交接前 MUST 以交付目录 mtime、evidence.yaml 落盘时刻、git 工作区实况为准重新确认，杜绝被陈旧排队消息误导（官方机理：in-process 子代理子步骤/工具调用不写入父日志，父日志只记 spawn 的 tool/call 与 tool/result，见 benchmarks/deepseek-harness-study.md §2.7） |
| R13 | 文件归宿纪律（防污染其他文件夹/资料）：内容归什么域，就写进什么域——**关于预设/流程自身的 meta 资料（开源基准、流程改进、运营观察）必须写入预设目录**（`~/.dsh/.agent-presets/dsh-codepunk/skills/dsh-codepunk-workflow/benchmarks/` 或预设 `knowledge/`），**绝不写进任何工程的 .dsh-codepunk/**；工程 run 的 `research/briefs/`、`docs/` 等只放该工程业务内容。误写即污染，MUST 立即移出并核销引用 |
| R14 | 产出归位复核（接收子代理产出时）：run-lead 在接任何子代理产出/调研简报时，MUST 核对「内容归属域」与「实际落位」一致；发现错位 → 立即移出到正确归属域，并检查是否已在错误位置被引用（grep 核销），不得留着漂移文件跨 run 传播 |

## 4. 工具映射速查

| 动作 | 工具 |
|---|---|
| 派遣岗位/小组 | `subagent_product` / `subagent_research` / `subagent_people` / `subagent_docs` / `subagent_proc_audit` / `subagent_sys_arch` / `subagent_code_review` / `subagent_release_eng` / `subagent_squad_lead` / `subagent_engineer` / `subagent_sdet` |
| 后台巡检 / 追问 | `list_agents`（scope=children/descendants）、结算通知、`send_message`、`interrupt_agent` |
| 通用委派（不套岗位） | `subagent` / `subagent_fork` |
| 创建/更新/完成工程目标 | `create_goal` / `get_goal` / `update_goal` |
| 用户确认（sponsor） | `ask_user_question` |
| 建目录/写文件/读文件/查 git | `bash`（mkdir/git/worktree/diff）、`write`/`edit`/`read`、`glob`/`grep` |
| 并行大并发编排（可选） | `workflow`（脚本编排多个独立 agent 小组） |
| 阶段规划（可选） | plan mode + `exit_plan_mode` |

## 5. 失败处理

- 小组失败/超时：优先让小队主责组织回修；必要时 P14 强制解散（保存 WIP 到 `backup_ref`），失败 task 可重建并重新走 ② 的简报+招聘。
- 流程偏离：`subagent_proc_audit` 红灯 → 你纠偏；涉及已交接内容 → 文档小组更新记忆。
- 跨组需要沟通：开临时会议（你主持，双方参与，TTL 内 resolve），纪要进 docs。

## 6. 参考文件（按需读取）

- `references/roles.md` —— 全部岗位人设（含人设维度表）与派遣提示词模板。
- `references/artifacts.md` —— goal/chunks/brief/staffing/handoff/evidence/acceptance/scores 文件模板。
- `references/knowledge.md` —— 知识库布局、评分公式与聚合文件格式、提示词优化流程。
- `references/standard.md` —— 编号（P01–P17 / D0xx）唯一权威释义。
- `references/harness-alignment.md` —— 官方机制对齐表（§0.0 完整展开）。
- `references/anti-hallucination-rules.md` —— 反幻觉纪律细则（D077 完整展开）。
- `references/model-routing.md` —— 角色分模型路由选型表 + 成本杠杆（D078）。
- `references/file-hygiene.md` —— 工作房卫生契约（D079：防残留/清理自查/强制门闩）。
- `references/anti-overengineering.md` —— 产出纪律（D081：YAGNI 阶梯/根因修复/简化留痕/审查契约）。
- `references/diagram-guide.md` —— 文档配图规范（D082：场景→图类型 + 4px 网格/密度/语义色）。
- `references/skill-governance.md` —— 技能治理与升级机制（D083：四态生命周期 + 三件套文档化 + 版本标记）。
- `references/prompt-injection-rules.md` —— 注入防护纪律（D084：工具返回不可信/记忆 canary/供应链门）。
- `references/learned-skills.md` —— 学到的技能总览（D066–D083 溯源 + 应用铁律 + benchmarks 索引）。

## 7. 开源基准借鉴（benchmark note）

> 本流程部分机制（D067-D070）借鉴高 star 开源项目**机制思想**（LangGraph/crewAI/ADK/CAMEL），不涉及代码抄袭；完整调研与 agent-skills 生态见 `benchmarks/`（决策号溯源见 `references/learned-skills.md`）。
> **正文预算（D074）**：≤32 KiB（当前已满，新增一律进 references/ 按需文件）；承重规则保留，非承重迁出或压缩。
> 落地时以「公文驱动、轻量增量」为原则，不引入重 runtime/图数据库。
