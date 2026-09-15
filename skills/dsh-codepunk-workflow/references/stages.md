# 阶段详解（references/stages.md）

> 本文是 SKILL.md §2 的完整步骤展开（L1 按需层）：六阶段闭环 + 合并门的逐步动作、派遣对象、产物与门禁细节。SKILL 正文只留每阶段 3 至 5 条速记与指针（D074 预算纪律）。
> 读法：开工前读本文件对应阶段；编号（P01–P17）释义见 `references/standard.md`，产物字段见 `references/artifacts.md`，岗位人设见 `references/roles.md`。
> **约束强度与 SKILL 正文一致**：本文件内的 MUST / MUST NOT / 禁止 / 绝不 / 不得 与 SKILL 正文同等效力，不因下沉而降级。

## ① 需求确认（P01）

1. 你主持对话并转述用户原始需求；**并行**派遣：
   - `subagent_product`（前台/后台皆可）：澄清要什么、优先级、验收口径 → `open_questions` + `product_acceptance[]`（active 前 MUST 非空，D034）。
   - `subagent_research`（后台）：联网检索行业/规范/最佳实践 → **业务调研**写 `${run}/research/briefs/*.md`；**预设/流程自身的 meta 调研（开源基准、机制对照）写预设 `~/.dsh/.agent-presets/dsh-codepunk/skills/dsh-codepunk-workflow/benchmarks/`**——派单时 prompt 指定归属路径（R13），收单时复核落位（R14）。简报必带 URL + retrieved_at。
   - **sponsor 随时可投喂**（D065）：信息/链接/文档 → 分诊（需求→product/你；研究→调研；文档→docs；问题→你拆卡），给回执并并入本阶段或变更单。
2. 综合 sponsor 意图 + 产品口径 + 调研简报 → 写 `plan_draft.md` 与 `goal.yaml`（status=draft，含 success criteria / non_goals / constraints / `product_acceptance[]` / scale；未覆盖项标 `assumption` 或 `open_question`）。
3. `open_questions` 非空 或 `product_acceptance[]` 为空 → **不得**直接 active：用 `ask_user_question` 逐项确认。
4. 用户确认 → `goal.yaml` 记 `user_confirmed_at`（不把 sponsor 聊天当状态信号，D035），`status: active`。驳回 → 回 intake 澄清。
5. 用 `create_goal` 把工程目标挂进 goal 工具跨轮跟踪（机制见 §0.1，R10）。
6. 状态机 `intake → draft → active ⇄ blocked → completed | cancelled`；`blocked` 时 MUST NOT 新 spawn。

## ② 规划与组队（P02–P04）

1. **分块**：派遣 `subagent_sys_arch` 勘察本仓 → `chunks.yaml`。
   - 规则：写集默认互斥；共享文件须 `owner_chunk`；无依赖环；`1 chunk = 1 task = 1 工作房 = 1 实现三角`。
   - 依赖已满足（无依赖或依赖 done）的 chunk → `ready`。
2. **简报**：让 `subagent_docs` 把你的意图（目标/边界/acceptance/禁区/必读 refs）+ 调研要点组装成 `WORK_BRIEF.md` + `brief.yaml`；**你审批**（`approved_by/approved_at`）。
3. **用工**：你写 `staffing/request.yaml`（skills_wanted / constraints / 可覆盖 team_name 与 codename）→ 派遣 `subagent_people` 真招聘三人设（`personas/{squad-lead,engineer,sdet}.md`，含 codename）+ 合规校验 → 呈报你审批 → `staffing.yaml`（`approved_by/approved_at`，锁定三角与 team_name）。
4. **双门闩（MUST）**：无你批准的 brief ∧ staffing → 禁止 spawn 任何实现小组。

## ③ 多小组并行开发（P05–P06）

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

## ④ 巡检与交接（P07）

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

## ⑤ 解散与评分（P07 尾 + P16 人事）

1. 签收后小组就地解散：对三席 `interrupt_agent`（停当前轮）+ 停止追问；continuable 孩子会转入 idle/ready **可恢复态**（没有 dispose 工具，属正常），但不再派新任务。
2. 派遣 `subagent_people` 评分：按信号（evidence / status / handoff 完整度 / ack / retries）对**团队**与**每个个人**打 0–100（base 50，公式见 references/knowledge.md）。
3. 沉淀：`tasks/<id>/staffing/scores.yaml` + `knowledge/hr/personas/<codename>.yaml` + `knowledge/hr/teams/<team_name>.yaml`（按人设名/团队名聚合，跨轮优化依据）。评分不阻断流程。

## ⑤ 合并门（P10 · 串行）

1. 派遣 `subagent_release_eng`（或你按同规则执行）：按 `depends_on` 拓扑排序 done 且门禁通过的 chunk，**每次只合一个**。
2. 合并前校验：evidence 过机械校验器（`scripts/evidence-verify.sh`，verdict=PASS 才有效，见 artifacts D069）+ diff ⊆ write_paths + 门禁文件齐（L/高风险含 review 与 security）→ 写 `approvals/merge.yaml`（`approved_by/approved_at`）。
3. 失败 → abort/revert，task 回修再排队；**禁止并行合并**；实现三角 MUST NOT 自己合主干；未 done 的 chunk MUST NOT merge。
4. **文档型交付**（如 docs/ 归档类 run）：同一门禁；「diff ⊆ write_paths」判据为**改动仅限 docs/ 与运行根（总库项目目录）状态文件、无业务代码越界**；合并动作可能只是纳入版本库/标记完成，仍需 `approvals/merge.yaml` 留痕（preconditions 四字段 evidence/diff_within_write_paths/review/merge_ack 逐项对齐模板，见 artifacts.md）。
5. **worktree 回收（D073，MUST）**：每 chunk 合并完成即 `git -C <主仓库> worktree remove --force ../room-<task_id>`（先确认该分支已并入 main、无未提交独有改动）→ `git worktree prune`；**分支 refs 保留**（`dsh-codepunk/<run>/<task>` 留审计）。未回收会随合并持续残留（机制不自动销毁），故合并门 MUST 显式销毁。

## ⑥ 再规划（P06 → ♻️）

1. 综合各组结果、交接、评分、知识库 → 更新 `chunks.yaml`（新轮次）。
2. 修订招聘标准（引 `knowledge/hr/` 高分人像）与提示词（`knowledge/prompts/`）。
3. 重招 → 执行 → 至 goal acceptance 全满足 → 宣布完成（`update_goal complete` + `announce`）。
4. **收尾环境核验（MUST，goal complete 前）**：`git -C <主仓库> worktree list` 只含主仓库本身（或与显式保留清单一致）；残留 → 按 P10 第 5 条回收再 complete。**环境终态整洁是验收项**。
