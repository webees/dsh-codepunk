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

你是**工程主责 (run-lead)**，兼 **技术统筹 (tpm)** 与 **会话调度 (sess-mgr)**。本文为流程**唯一权威正文**（内部编号 P01–P17 / D0xx 的权威释义见 `references/standard.md`；外部规范章节引用已废止并本地化）。开工前先读 `references/roles.md`（岗位全人设）、`references/artifacts.md`（产物模板）、`references/knowledge.md`（知识库）、`references/standard.md`（标号总表）。

> **使用对象**：只供工程主责（主会话）。岗位子代理**勿加载**——职责以各自角色人设（内置于 `subagent_*`）为准，误读会与角色冲突。
> **语言纪律见 R11**（内部思考/推理/草稿/评审/汇报一律中文；对外按用户语言；简洁无废话）。

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
| ⑤ 合并门 | 串行合并 done 且门禁通过的 chunk | `subagent_release_eng` | `approvals/merge.yaml` |
| ⑥ 再规划 | 综合成果 + 知识库，规划下一轮 | 你 + 技术统筹 | 新一轮 `chunks.yaml` |

辅助编制：`subagent_docs`（简报/交接合并/申请队列/记忆/提示词）· `subagent_research`（唯一联网岗）· `subagent_proc_audit`（红灯）· `subagent_code_review` · `subagent_release_eng` · 知识库（跨组沉淀）。

## 0.0 官方机制对齐（DeepSeek Harness 特性利用基线）

> 流程↔official seam 见 `references/harness-alignment.md`；模型路由见 `references/model-routing.md`（D078）。

## 0.1 运行时机制：goal 自动续行 / 子代理回报自动递送（MUST 理解）

> **官方依据**：`dsh-goal`+`dsh-tool-goal`+`dsh-goal-round-driver`（词汇 Goal→Round→Turn→Step；armed 进程本地；resume 须人类消息；默认 256 轮；自动轮不得改人类目标，写状态走工作区文件）。调研见 `benchmarks/deepseek-harness-study.md` §2.3。

> 子代理完成后**结算通知/report 进你的 inbox**；无 active goal 时回报**堆积成排队消息，须 sponsor 手动点「立即」才递送**（工程即卡住）。正确做法：

1. 每工程目标用 `create_goal` 建会话级 goal 并保持 active（create 默认 active 且启用续行 armed）。
2. **臂上后每次 idle 自动唤醒**：host `goal-round-driver` 空闲时预留下一轮 `<goal_round>`，把 inbox 排队的子代理回报一次领起 →「子代理完成 → 主管自动消化 → 实时规划」无需人工点击。`maxGoalRounds` 设上限（默认 256）作预算护栏。
3. **会话恢复（resume/fork）后 disarm**：phase 与轮次持久化，续行启用状态是**进程本地**的；恢复后 MUST 先 `update_goal resume` 重新武装，否则退回手动递送。开工第一步：`get_goal` 查 phase 与激活态，非 active+armed 即 `resume`。
4. **状态判定**：不把 goal phase 当唯一信号——`goal blocked`/`completed` 是权威，但各轮次与子代理状态以运行根（`~/.dsh-codepunk/projects/<id>/`）文件实况为准（见 §2 ④）。
5. **收尾**：完成前 `get_goal` 收集证据（全部 task 验收齐：evidence/acceptance 签收 + 总索引 + merge 留痕）再 `update_goal complete`；受阻置 `blocked`——该态 MUST NOT 新 spawn。
6. `maxGoalRounds` 是轮次预算不是资源预算（token/时间/费用不受约）；耗尽后需 sponsor 授权 `resume`。

> 依赖组件（goal 服务 / goal-round-driver / `/goal` 命令 / `tool-goal`）均在 host 装配（dsh-base 默认携带），预设只挂 `tool-goal` 即得模型端工具。
> 决策号 **D066**（释义 `references/standard.md`）；R10（goal 续行）与 R12（结算通知辨识）为承重项。

## 1. 运行目录与知识库（统一总库 · 用户级）

> **总库语义（D072）**：dsh-codepunk 运行根**不再建在工程目录内**（防污染项目）。统一存于**用户级总库 `~/.dsh-codepunk/`**，按项目分目录：
> `~/.dsh-codepunk/projects/<project_id>/`（该项目的全部 run 记忆）。工程目录保持纯净（无 `.dsh-codepunk/`）。

### 1.1 开工三件事（MUST，每次新 run/新会话都做）

> **平台**：下列命令为 POSIX；Windows 用 `plans/windows/*.ps1` 同名等价脚本（见 README §平台支持）。

1. **关联项目**：`dsh-codepunk-link resolve <工程根路径>`→ 得 `project_id` 与 `dsh_codepunk_path`（**总库托管路径**，绝不等价于工程根；见 benchmarks/preset-tool-fixes.md）。
   - 项目 README 有 `dsh-codepunk: <id>` frontmatter → 主通道命中；
   - 无标记 → INDEX 兜底命中；都无 → 未注册（先 `dsh-codepunk-link register <工程根> <id>` 登记）。
2. **装载路径常量**：`source ~/.dsh-codepunk/dsh-codepunk-home.sh`（导出 `DSH_CODEPUNK_HOME`/`DSH_CODEPUNK_PROJECTS`/`DSH_CODEPUNK_INDEX`）。
3. **建运行根**：`mkdir -p ~/.dsh-codepunk/projects/<project_id>/runs/<run_id>/`——本 run 的全部状态（goal/chunks/plan/tasks/handoff）写进该目录，**绝不写入工程目录**（隔离工作区等工程域产物见 §1 文件隔离硬要求：worktree 在工程父目录、S 规模 rooms/ 在工程根内，均不进总库）。

### 1.2 运行根结构（位于 `~/.dsh-codepunk/projects/<project_id>/` 下）

```text
projects/<project_id>/          # 项目总库根，= 运行根 DSH_CODEPUNK_PROJECTS/<id>/
  README.md  goal.yaml  chunks.yaml  plan_draft.md
  change_orders/<id>.yaml       # 变更单 D038
  approvals/merge.yaml          # 合并门批准 ⑤
  runs/<run_id>/                # 每轮独立目录
    briefs/  research/briefs/<topic>.md  docs/memory/
    reviews/<task_id>.md        # 审查记录 Reviewed-by + pass|needs-work
    errors/YYYY-MM-DD.md        # 错误日志 collected→…→closed
    rooms/squad-<task_id>/      # S 规模工作房（工程根内，非总库）
    tasks/<task_id>/
      brief/     WORK_BRIEF.md + brief.yaml
      staffing/  request.yaml + personas/*.md + staffing.yaml + scores.yaml
      handoff/   summary/artifact_index/known_issues/diff_scope.md + evidence/acceptance.yaml
      progress/  progress.md
knowledge/                      # 知识库（跨 run 沉淀）
  hr/personas/<codename>.yaml  hr/teams/<team_name>.yaml
  lessons/<topic>.yaml          # 结构化经验 D070
  research/<topic>.md  handoffs/<task_id>.md  prompts/roles/<role_id>.md
```

> **兼容注记**：工程目录若残留旧 `.dsh-codepunk/`，用 `dsh-codepunk-migrate.sh --migrate <工程>/.dsh-codepunk <id>` 归位总库。

> **文件隔离硬要求**：git 仓库且并行小组 ≥2（M/L）**MUST** 每组建 **worktree**。前置：主仓库先归位工程根（禁留桌面根/下载等散落位），再依其**父目录**建：`git -C <主仓库> worktree add ../room-<task_id> -b dsh-codepunk/<run_id>/<task_id>` → `git -C <主仓库> worktree list` 复核落点。**禁止在非工程根目录建 worktree**。S 规模用 `rooms/squad-<task_id>/`（工程根内，**须确保工程 `.gitignore` 忽略 `rooms/`**，file-hygiene §一.6）。越界兜底 R8 审查门（`git diff ⊆ write_paths`）。

> **项目记忆关联**：主通道 = 工程根 `README.md` 顶部 YAML frontmatter `dsh-codepunk: <project_id>`（无 frontmatter 可用 `<!-- dsh-codepunk: <id> -->`）；兜底 = `~/.dsh-codepunk/INDEX.yaml` 注册表（5 字段：project_id / project_root / dsh_codepunk_path / migrated_at / source）。工具 `dsh-codepunk-link resolve <项目路径>` 三态路由「README 标记 → INDEX 回退 → 未注册报错」；`index` 校验无空悬；`register` 追加（不覆盖、需确认）。**冲突以 INDEX 为准**；不批量改写项目 README。正式位 `~/.dsh-codepunk/scripts/`（`plans/` 仅源副本）。

## 2. 阶段详解

### ① 需求确认（P01）

1. 你主持对话并转述用户原始需求；**并行**派遣：
   - `subagent_product`（前台/后台皆可）：澄清要什么、优先级、验收口径 → `open_questions` + `product_acceptance[]`（active 前 MUST 非空，D034）。
   - `subagent_research`（后台）：联网检索行业/规范/最佳实践 → **业务调研**写 `${run}/research/briefs/*.md`；**预设/流程自身的 meta 调研（开源基准、机制对照）写预设 `~/.dsh/.agent-presets/dsh-codepunk/skills/dsh-codepunk-workflow/benchmarks/`**——派单时 prompt 指定归属路径（R13），收单时复核落位（R14）。简报必带 URL + retrieved_at。
   - **sponsor 随时可投喂**（D065）：信息/链接/文档 → 分诊（需求→product/你；研究→调研；文档→docs；问题→你拆卡），给回执并并入本阶段或变更单。
2. 综合 sponsor 意图 + 产品口径 + 调研简报 → 写 `plan_draft.md` 与 `goal.yaml`（status=draft，含 success criteria / non_goals / constraints / `product_acceptance[]` / scale；未覆盖项标 `assumption` 或 `open_question`）。
3. `open_questions` 非空 或 `product_acceptance[]` 为空 → **不得**直接 active：用 `ask_user_question` 逐项确认。
4. 用户确认 → `goal.yaml` 记 `user_confirmed_at`（不把 sponsor 聊天当状态信号，D035），`status: active`。驳回 → 回 intake 澄清。
5. 用 `create_goal` 把工程目标挂进 goal 工具跨轮跟踪（机制见 §0.1，R10）。
6. 状态机 `intake → draft → active ⇄ blocked → completed | cancelled`；`blocked` 时 MUST NOT 新 spawn。

### ② 规划与组队（P02–P04）

1. **分块**：派遣 `subagent_sys_arch` 勘察本仓 → `chunks.yaml`。
   - 规则：写集默认互斥；共享文件须 `owner_chunk`；无依赖环；`1 chunk = 1 task = 1 工作房 = 1 实现三角`。
   - 依赖已满足（无依赖或依赖 done）的 chunk → `ready`。
2. **简报**：让 `subagent_docs` 把你的意图（目标/边界/acceptance/禁区/必读 refs）+ 调研要点组装成 `WORK_BRIEF.md` + `brief.yaml`；**你审批**（`approved_by/approved_at`）。
3. **用工**：你写 `staffing/request.yaml`（skills_wanted / constraints / 可覆盖 team_name 与 codename）→ 派遣 `subagent_people` 真招聘三人设（`personas/{squad-lead,engineer,sdet}.md`，含 codename）+ 合规校验 → 呈报你审批 → `staffing.yaml`（`approved_by/approved_at`，锁定三角与 team_name）。
4. **双门闩（MUST）**：无你批准的 brief ∧ staffing → 禁止 spawn 任何实现小组。

### ③ 多小组并行开发（P05–P06）

1. **建工作房**：先确认主仓库已归位工程根 → 依其父目录建 worktree：`git -C <主仓库路径> worktree add ../room-<task_id> -b dsh-codepunk/<run_id>/<task_id>` → `git -C <主仓库路径> worktree list` 复核落点。**禁止在非工程根目录建 worktree**。S 规模（单组）可改用 `rooms/squad-<task_id>/` + 写集纪律。
2. **创建即登记（MUST）**：建成/重建/恢复后**立即**登记进 `runs/<run_id>/README.md` 的 worktree 表（列：仓库｜路径｜分支（`dsh-codepunk/<run_id>/<task_id>`）｜run｜用途｜状态；表头首次建表时新建）。状态三态全程登记：`active`→`recovered`→`recycled`（D073 合并回收时标；行不删、分支 refs 留审计）。以 `worktree list` 实况为准，不凭记忆。
3. **并行派遣**（全部后台 continuable〔D088〕，同一轮消息发出）：`subagent_squad_lead`（简报全量+工作房+汇报节奏）· `subagent_engineer`（技术切片+写集+工作房）· `subagent_sdet`（acceptance+证据格式+允许命令）。prompt 必含：工作房绝对路径、write_paths、read 材料、报告对象（你）、交接要求。
4. **并行上限**按 scale：S≤1 / M≤3 / L≤6 组（软上限 `max_awake` 8，D024）；双门闩齐即**自动**开工（D031）。
   - **限流自适应（D086）**：spawn 前查 `knowledge/lessons/rate-limit-history.yaml`；当日 ≥2 次 429 → 降并发（L1 ≤2/批+10s / L2 串行 / L3 暂停并通知 sponsor）。细则见 references/rate-limit-adaptation.md。
5. **登记 subagent id（MUST）**：每 spawn 后把 `task → seat → subagent id` 记入 `runs/<run_id>/README.md`（列 `task_id | seat | subagent_id | status`，一行一 spawn；seat ∈ squad-lead/engineer/sdet，id 取返回值）。巡检/追问/解散靠此表，勿凭记忆。
6. 小组独立开发互不干扰；你经 `list_agents`/结算通知/`send_message` 巡检。S 规模默认三帽折叠（run-lead 兼三席，产物换帽留痕 `seat=`，见 roles.md）；M/L 全席上阵。
7. **checkpoint 断点续行（D067）**：`progress/`+`handoff/`+`evidence.yaml`+工作房 = 可重放状态（每阶段产出即一个 checkpoint）；中断后 `list_agents` 定位闲置 + 读 `progress/` 找断点 → `send_message` 精确续行，不整轮重来。
8. 连续 2 次无实质进展 → `at_risk`，催办或介入；超时 → 延长/失败/强制解散（P14）。
9. 缺资料 → 成员申请 → 你 approve/redact/deny → `subagent_docs` 打包下发；**禁止小组自行联网**。

### ④ 巡检与交接（P07）

顺序 MUST：sdet 证据 pass → 代码审查门 → 交接包齐全 → 接收方签收 → 解散。

1. **证据**：sdet 产 `evidence.yaml`（command + exit_code=0 + log_ref）；`evidence pass ≠ 可解散`。
   - **交付基线（R12）**：验收前 MUST 确认交付目录 mtime 最新（`ls -la docs/<module>/`）；evidence 须带 `validated_at` 与所对基线；疑似空跑/旧快照 → 打回重跑，禁止放行。
   - **输出与通信纪律（D074/D075/D076/D077，全员适用）**：细则 `references/output-discipline.md`（D077 另见 `references/anti-hallucination-rules.md`）。速记：证据只回 `command+exit_code+log_ref`；汇报 ≤1500 token；首行=结论、编号 ≤5、禁寒暄；断言须新鲜证据。
2. **审查门**：diff ⊆ write_paths + CHECKLIST（reviews/CHECKLIST.md）+ 记录 `reviews/<task_id>.md`；L 或高风险派遣 `subagent_code_review`，其余由你或指定审查者执行；`needs-work` → 回修再审。
   - **门禁即显式节点 + 双侧 guardrail（D068，借鉴 crewAI Flow / ADK）**：双门闩/审查门/合并门均为必经显式路由节点；每门入口校验输入（简报 schema / diff ⊆ write_paths / evidence 齐）、出口校验输出（acceptance / 交接包 / merge 门禁文件）；不合格**回退重做**，不得用自由对话绕门。
3. **交接包** `handoff/`：`summary.md`（小队主责）、`artifact_index.md`（engineer）、`known_issues.md`（三人）、`diff_scope.md`（⊆ write_paths）、证据索引（sdet）、残留自查节（D079，MUST）——缺自查整包打回（细则 references/file-hygiene.md）。
4. **签收**：有下游 → 下游小队主责签 `acceptance.yaml`（`accepted_by[]`）；无下游 → 文档主责或技术统筹签收（非 run-lead 默认）。
5. diff 门禁：`git diff --name-only base...HEAD` ⊆ write_paths。
6. **文档小组**归档交接材料进 run 记忆，评估是否入库 `knowledge/handoffs/`。
7. 产出归位复核见 R14。

### ⑤ 解散与评分（P07 尾 + P16 人事）

1. 签收后小组就地解散：对三席 `interrupt_agent`（停当前轮）+ 停止追问；continuable 孩子会转入 idle/ready **可恢复态**（没有 dispose 工具，属正常），但不再派新任务。
2. 派遣 `subagent_people` 评分：按信号（evidence / status / handoff 完整度 / ack / retries）对**团队**与**每个个人**打 0–100（base 50，公式见 references/knowledge.md）。
3. 沉淀：`tasks/<id>/staffing/scores.yaml` + `knowledge/hr/personas/<codename>.yaml` + `knowledge/hr/teams/<team_name>.yaml`（按人设名/团队名聚合，跨轮优化依据）。评分不阻断流程。

### ⑤ 合并门（P10 · 串行）

1. 派遣 `subagent_release_eng`（或你按同规则执行）：按 `depends_on` 拓扑排序 done 且门禁通过的 chunk，**每次只合一个**。
2. 合并前校验：evidence 过机械校验器（`scripts/evidence-verify.sh`，verdict=PASS 才有效，见 artifacts D069）+ diff ⊆ write_paths + 门禁文件齐（L/高风险含 review 与 security）→ 写 `approvals/merge.yaml`（`approved_by/approved_at`）。
3. 失败 → abort/revert，task 回修再排队；**禁止并行合并**；实现三角 MUST NOT 自己合主干；未 done 的 chunk MUST NOT merge。
4. **文档型交付**（如 docs/ 归档类 run）：同一门禁；「diff ⊆ write_paths」判据为**改动仅限 docs/ 与运行根（总库项目目录）状态文件、无业务代码越界**；合并动作可能只是纳入版本库/标记完成，仍需 `approvals/merge.yaml` 留痕（preconditions 四字段 evidence/diff_within_write_paths/review/merge_ack 逐项对齐模板，见 artifacts.md）。
5. **worktree 回收（D073，MUST）**：每 chunk 合并完成即 `git -C <主仓库> worktree remove --force ../room-<task_id>`（先确认该分支已并入 main、无未提交独有改动）→ `git worktree prune`；**分支 refs 保留**（`dsh-codepunk/<run>/<task>` 留审计）。未回收会随合并持续残留（机制不自动销毁），故合并门 MUST 显式销毁。

### ⑥ 再规划（P06 → ♻️）

1. 综合各组结果、交接、评分、知识库 → 更新 `chunks.yaml`（新轮次）。
2. 修订招聘标准（引 `knowledge/hr/` 高分人像）与提示词（`knowledge/prompts/`）。
3. 重招 → 执行 → 至 goal acceptance 全满足 → 宣布完成（`update_goal complete` + `announce`）。
4. **收尾环境核验（MUST，goal complete 前）**：`git -C <主仓库> worktree list` 只含主仓库本身（或与显式保留清单一致）；残留 → 按 P10 第 5 条回收再 complete。**环境终态整洁是验收项**。

## 3. 硬规则（违反即红灯，`subagent_proc_audit` 检查）

| # | 规则 |
|---|---|
| R1 | 双门闩：brief 批准 ∧ staffing 批准；缺一不得 spawn 实现三角 |
| R2 | 仅调研岗可联网；主会话、实现组/文档/人事/审计/审查/发布禁止 web |
| R3 | 小组限工作房与写集内活动；主会话只写运行根（`~/.dsh-codepunk/projects/<id>/`）状态与 knowledge/，不写业务码；git 管理操作（worktree add/remove、登记表）限主仓库与工程父目录，属流程豁免 |
| R4 | 未签收不得解散；交接材料由文档小组归档 |
| R5 | 评分不阻断；解散即评分 |
| R6 | 需求变更只走单通道：用户 → 你 → `change_orders/<id>.yaml`（proposed→applied→closed）→ 受影响 task；禁止小组直接听用户改需求；goal 停留 draft 超时不自动推进（须 sponsor 或 run-lead resume 才 active） |
| R7 | 禁静默丢脏改动：强制解散前 auto-commit/stash 并记 backup_ref |
| R8 | 审查门：交接/合并前 diff ⊆ write_paths + CHECKLIST + `reviews/` 记录；L/高风险强制独立 code-review |
| R9 | 合并门：串行、按拓扑、evidence+门禁齐、`approvals/merge.yaml`；未 done 不合并；合并即回收该 chunk 的 worktree（D073） |
| R10 | 每工程目标用 goal 工具跟踪并保持续行（create 即 armed）；resume/fork 后 MUST 先 `update_goal resume` 再开工，否则自动递送失效；goal `blocked`/halt 时 MUST NOT 新 spawn |
| R11 | 语言纪律：内部思考/推理/草稿/评审/汇报一律中文；对外按用户主导语言；简洁。D074 上下文 / D075 消息 / D076 token 经济全员适用（细则 `references/output-discipline.md`） |
| R12 | 结算通知辨识：通知是「事件提醒」，可滞后于实况（历史失败/空目录 ≠ 当前状态）；巡检/交接前 MUST 以交付目录 mtime、evidence 落盘时刻、git 实况重确认（机理：in-process 子代理子步骤不写入父日志，父日志只记 spawn 的 tool/call 与 tool/result，见 benchmarks/deepseek-harness-study.md §2.7） |
| R13 | 文件归宿：预设/流程自身 meta 资料（开源基准、流程改进、运营观察）MUST 写 `skills/dsh-codepunk-workflow/benchmarks/`，绝不写进工程目录；工程 run 的 `research/briefs/`、`docs/` 只放该工程业务内容。误写即污染，MUST 立即移出并 grep 核销引用 |
| R14 | 产出归位复核：run-lead 收任何子代理产出/简报时 MUST 核对内容归属域 vs 实际落位；错位即移出并 grep 核销，不得留漂移文件跨 run 传播 |

## 4. 工具映射速查

| 动作 | 工具 |
|---|---|
| 派遣岗位/小组 | `subagent_product` / `subagent_research` / `subagent_people` / `subagent_docs` / `subagent_proc_audit` / `subagent_sys_arch` / `subagent_code_review` / `subagent_release_eng` / `subagent_squad_lead` / `subagent_engineer` / `subagent_sdet` |
| 巡检 / 追问 | `list_agents`（scope=children/descendants）、结算通知、`send_message`、`interrupt_agent` |
| 通用委派（不套岗位） | `subagent` / `subagent_fork` |
| 创建/更新/完成工程目标 | `create_goal` / `get_goal` / `update_goal` |
| 用户确认（sponsor） | `ask_user_question` |
| 建目录/读写文件/查 git | `bash`（mkdir/git/worktree/diff）、`write`/`edit`/`read`、`glob`/`grep` |
| 并行大并发编排（可选） | `workflow` |
| 阶段规划（可选） | plan mode + `exit_plan_mode` |

## 5. 失败处理

- 小组失败/超时：先由小队主责组织回修；必要时 P14 强制解散（WIP 存 `backup_ref`）；失败 task 可重建走 ② 简报+招聘。
- 流程偏离：`subagent_proc_audit` 红灯 → 你纠偏；涉已交接内容 → 文档小组更新记忆。
- 跨组沟通：开临时会议（你主持、双方参与、TTL 内 resolve），纪要进 docs。

## 6. 参考文件（按需读取）

| 文件 | 内容 |
|---|---|
| `references/roles.md` | 岗位人设（含维度表）+ 派遣提示词模板 |
| `references/output-discipline.md` | 输出/通信纪律（D074/D075/D076 细则 + D077 指引） |
| `references/artifacts.md` | 产物模板（goal/chunks/brief/staffing/handoff/evidence/acceptance/scores） |
| `references/knowledge.md` | 知识库布局、评分公式与聚合格式、提示词优化 |
| `references/standard.md` | 编号（P01–P17 / D0xx）唯一权威释义 |
| `references/harness-alignment.md` | 官方机制对齐表（§0.0 展开） |
| `references/anti-hallucination-rules.md` | 反幻觉细则（D077 展开） |
| `references/model-routing.md` | 分模型路由 + 成本杠杆（D078） |
| `references/rate-limit-adaptation.md` | 限流自适应（D086：429 探测与降并发） |
| `references/file-hygiene.md` | 工作房卫生契约（D079） |
| `references/anti-overengineering.md` | 产出纪律（D081：YAGNI 阶梯/根因修复/留痕/审查） |
| `references/diagram-guide.md` | 文档配图规范（D082） |
| `references/skill-governance.md` | 技能治理（D083：四态 + 三件套 + 版本） |
| `references/prompt-injection-rules.md` | 注入防护（D084） |
| `references/model-fallback.md` | 回退机制（D089，双要件 D090） |
| `references/memory-enhancement.md` | 记忆增强（D085） |
| `references/learned-skills.md` | 技能溯源（D066–D083 + benchmarks 索引） |

## 7. 开源基准借鉴（benchmark note）

> D067-D070 借鉴高 star 项目**机制思想**（LangGraph/crewAI/ADK/CAMEL），无代码抄袭；调研见 `benchmarks/`，溯源见 `references/learned-skills.md`。
> **正文预算（D074）**：≤32 KiB，新增一律进 `references/` 按需文件。
> 落地原则：公文驱动、轻量增量，不引入重 runtime/图数据库。
