# 产物文件模板（references/artifacts.md）

运行目录：`~/.dsh-codepunk/projects/<project_id>/runs/<run_id>/`（总库语义 D072），知识库：`~/.dsh-codepunk/projects/<project_id>/knowledge/`。所有 YAML 用 UTF-8，字段名保持稳定以便知识库聚合与跨轮复用。

## goal.yaml（①，sponsor 确认后 active）

```yaml
run_id: run-2026-0001
title: "<目标一句话>"
kind: delivery          # delivery | self_evolve
status: active          # 状态机：intake → draft → active ⇄ blocked → completed | cancelled；回边 draft→intake（P01 驳回）、blocked→active（仅 run-lead 在阻塞消除后置回，须记 blocker 与解除依据）、cancelled（仅 sponsor 触发，run-lead 记原因）
scale: S                # S | M | L（并行上限 S=1 / M=3 / L=6；本预设自律上限，非平台字段）
success_criteria:
  - "<可验证的成功标准>"
non_goals:
  - "<明确不做>"
constraints:
  - "<约束>"
product_acceptance:     # D034：active 前 MUST 非空（验收口径=要什么）
  - "<产品验收口径>"
acceptance:             # 验收方式（怎么验证；与 product_acceptance 互补，非重复）
  - "<验收方式>"
open_questions: []      # 非空则 MUST NOT active
assumptions: []
user_confirmed_at: "2026-08-13T12:00:00Z"   # sponsor 确认时刻（run-lead 记录，D035）
created_at: "…"
```

> goal 状态机：`intake → draft → active ⇄ blocked → completed | cancelled`；
> `blocked`（外部阻塞/halt）时 MUST NOT 新 spawn。
> **`cancelled` 的主体与条件**：仅当**发起人撤回/需求作废**时，由 run-lead 在 `goal.yaml` 记 `status: cancelled` + 时刻与缘由；**平台 goal 动作集只有 `edit/pause/resume/complete/blocked`——无 `cancel`**，故取消**不在平台侧置态**，只在本文件留痕并停止续行（与「`blocked` 须人类发起解除」同源：终止权归人类）。

## plan_draft.md（① 需求草案；与 `goal.yaml` 同批产出）

落项目根 `~/.dsh-codepunk/projects/<project_id>/plan_draft.md`（与 `goal.yaml` 同级，见 §1.2）。**字段模板**（未覆盖项 MUST 显式标记，不得静默省略）：

```yaml
title: <一句话转述的诉求（不改写范围）>
sponsor_intent: <发起人原话要点；与 title 不同时以本节为准>
scope_in: [<纳入范围项>]
scope_out: [<明确排除项>]
assumptions: [<未确认但按默认推进的假设——sponsor 可否决>]      # 标记：assumption
open_questions: [<必须由发起人回答才能进 ② 的问题>]              # 标记：open_question
acceptance_draft: [<验收口径草案；active 时并入 goal.yaml 的 product_acceptance[]>]
risks: [<已知风险与外部依赖>]
```

> 硬约束：`open_questions` 非空 或 `acceptance_draft` 空 ⇒ MUST NOT 进 ②（D034）；`active` 前须经发起人确认并记 `goal.yaml` 的 `user_confirmed_at`（D035）。

## chunks.yaml（②）

```yaml
chunks:
  - id: chunk-a
    title: "<模块名>"
    write_paths: ["src/a/**"]      # 默认互斥；共享文件须 owner_chunk
    read_paths: ["src/shared/**"]
    depends_on: []                 # 或 ["chunk-b"]；无依赖或依赖 done → ready
    acceptance: ["<该块验收>"]
    owner_chunk: null              # 共享文件的所有者 chunk
    status: planned                # planned → ready → in_progress → testing → handoff → done
```

**迁移主体与触发条件（单点权威，`chunks.yaml` 是唯一的进度板）**——除首末两条外，以下三条此前无归属，现明确为 **run-lead 观测到事件后写**（状态文件只由 run-lead 写）：

| 迁移 | 主体 | 触发条件（可观测） |
| --- | --- | --- |
| `planned → ready` | run-lead | 依赖已满足（无 `depends_on` 或依赖项均 `done`） |
| `ready → in_progress` | run-lead | **派发该 chunk 的实现三角时**（双门闩齐、三席已 spawn） |
| `in_progress → testing` | run-lead | 收到 engineer 交付（工作房 `artifact_index.md`/`evidence.yaml` 落盘、`git diff` 非空）且 sdet 已开工验收 |
| `testing → handoff` | run-lead | sdet 验收通过并产出交接包（`handoff/` 齐、审查门过） |
| `handoff → done` | run-lead | 接收方签收后置 done（**两处齐**：`chunks.yaml` chunk 态 + `agents.yaml` 席位态，见 SKILL ⑤） |


## 工作简报（②，你签发）

`tasks/<task_id>/brief/WORK_BRIEF.md`：目标 / 边界 / acceptance / 禁区 / 必读 refs / 席位侧重。
`tasks/<task_id>/brief/brief.yaml`：

```yaml
task_id: task-chunk-a
status: approved                   # draft → in_review → approved（双门闩以 approved 为准）；变更后旧版 → superseded（作废，不得再据其开工）
approved_by: run-lead
approved_at: "…"
objective: "<一句话>"
acceptance: ["<列表>"]
forbidden: []
must_read_refs: ["tasks/chunk-a/brief/WORK_BRIEF.md"]
attachments: []
```

## 用工单（②，你 → 人事）

`tasks/<task_id>/staffing/request.yaml`：

```yaml
id: staff-req-001
task_id: task-chunk-a
from: run-lead
status: submitted                  # submitted → approved（招聘完成且编制锁定 staffing.yaml）| rejected（编制不可行：须回改 skills_wanted/constraints 或规模后重提）
                                     # 注：本预设为单操作者流程——**无 HR 中间审环节**，故不设 in_hr/run_lead_review（历史声明值已移除，见 F124）
skills_wanted: ["typescript", "testing"]
constraints: ["no network", "write_paths only"]
notes: ""
reuse_persona_ids: []
team_name: null                    # 可覆盖；缺省确定性生成
codename_overrides: {}             # 如 { engineer: "白泽" }
```

## 编制锁定（②，你批准后）

`tasks/<task_id>/staffing/staffing.yaml`：

```yaml
schema_version: "1"
task_id: task-chunk-a
status: approved
approved_by: run-lead
approved_at: "…"
team_name: "北辰"
triad:
  squad-lead: { role_template: squad-lead, agent_id: squad-lead@task-chunk-a, tool_profile: implement.squad-lead, persona_file: personas/squad-lead.md }
  engineer:  { role_template: engineer,  agent_id: engineer@task-chunk-a,  tool_profile: implement.engineer,  persona_file: personas/engineer.md }
  sdet:      { role_template: sdet,      agent_id: sdet@task-chunk-a,      tool_profile: implement.sdet,      persona_file: personas/sdet.md }
```

人设实例 `personas/*.md`：frontmatter（name/description/tool_profile/role_id/codename/vibe）+ 正文四节（Identity / Core Mission / Critical Rules / Success Metrics），覆盖 roles.md「人设必须覆盖的维度」全部维度。

## 交接包（④）

`tasks/<task_id>/handoff/`：

| 文件 | 主责 | 要点 |
|---|---|---|
| summary.md | squad-lead | 什么、怎么验证、遗留事项；必含 `retries: <回修次数>` 与固定标题 `## 残留自查`（D079） |
| artifact_index.md | engineer | 交付物清单（文件→用途） |
| known_issues.md | 三人 | 已知问题与后续建议 |
| diff_scope.md | squad-lead | diff ⊆ write_paths 的说明（审查门由 run-lead 核对） |
| evidence.yaml | sdet | 证据索引 |

`evidence.yaml`（sdet 产出；验收前 MUST 先确认交付目录 mtime 为最新，字段见下）：

```yaml
task_id: task-chunk-a
validated_at: "2026-08-19T07:30:00Z"        # MUST：验收执行时刻（用于判断是否基于最新交付）
delivery_baseline:                          # MUST：本次验收所对交付的基线（命令+结果，证明非空跑/旧快照）
  dir_mtime: "2026-08-19T07:12:46Z"         # 交付目录最近写入时刻（ls -la 实测）
  file_count: 5                             # 交付目录文件数
  check: "ls docs/chunk-a/ && stat -f '%Sm' docs/chunk-a"   # 复现命令
base_ref: "HEAD"                            # 验收对照的 git 基线
evidence:
  - id: ev-1
    command: "npm test -- chunk-a"
    exit_code: 0
    log_ref: "artifacts/test.log"
    signed_by: "sdet@task-chunk-a"
```

> **交付基线纪律（R12）**：若交付目录 mtime 早于 evidence 生成时刻（空跑/旧快照），或验收时交付尚未落盘，evidence 一律判为无效，**由工程主责（或证据门）打回 sdet** 基于最新交付重跑（sdet 为直接子会话，消息可直达）；禁止把「交付前空目录」的 FAIL/NOT_PASS 误当最终结论。

> **schema 强约束（D069，借鉴 outlines/agentskills）**：evidence.yaml / acceptance.yaml 的**结构必须在生成期保证可机器校验**——sdet 产出后先过结构校验（必填字段齐、类型对、exit_code∈{0,非0}、accepted_by 为数组），校验不合格直接回退，不经人工放行滑入下一阶段。证据即接口：交接/评分/审计/合并门一律以「结构合法 + 内容达标」双标准读取，杜绝靠自由文风或长上下文记忆判断。
> **机械校验器（D069 实现 · 防假通过门）**：`plans/evidence-verify.sh`（正式位 `~/.dsh-codepunk/scripts/evidence-verify.sh`）对 evidence.yaml 做机械断言——①`task_id` 必填、evidence `id` 唯一（D069 结构强约束）；②command 首词白名单且非描述性文本（自然语言/「详见」式引用即 FAIL）；③log_ref 文件真实存在**且位于交付目录内**（多前缀探测；绝对路径、`..` 逃逸、指向交付目录外的符号链接一律 FAIL——F348）；④exit_code **必须为 0**（非 0 即判 FAIL——非成功命令不得作为通过性证据）；⑤`validated_at` 晚于交付目录 mtime（R12 数值化；未提供交付目录时显式记为「未检」而非静默跳过）。sdet 产出后、release-eng 合并前 MUST 执行一次（如 run 状态：`bash ~/.dsh-codepunk/scripts/evidence-verify.sh runs/<id>/tasks/<tid>/handoff/evidence.yaml <task_dir>`）；verdict=FAIL 即整包打回。历史实证：能机械抓出「自然语言命令 + exit_code=0 + 照填 PASS」的伪证据。
>
> **ℹ 强制力边界（F221）**：模板中的 `signed_by`（evidence）与 `reviewed_at`（acceptance）属**人工留痕字段**，**不在上列机械断言之列**（全仓 `plans/` 无工具校验它们）——**勿据此认为已被门禁校验**。门禁强制集为：evidence = `task_id`/`id` 唯一/`command`/`log_ref`/`exit_code`/`validated_at`；acceptance = `task_id`/`accepted_by[]`/`accepted_at`（+ 不得自签 / run-lead 自签须记 `note`）。

`acceptance.yaml`（接收方签收；无此文件不得 dissolved；`accepted_by` 为数组。产出后 MUST 过 `plans/acceptance-verify.sh`（正式位 `~/.dsh-codepunk/scripts/`）——D069 的第二个 schema，机械断言：`task_id`/`accepted_by[]`/`accepted_at` 齐备、不得自签、run-lead 自签须在 `note` 记原因；verdict=FAIL 即回退）：

```yaml
task_id: task-chunk-a
accepted_by:
  - "squad-lead@task-chunk-b"       # 下游小队主责；无下游 → docs-lead（技术统筹由 run-lead 兼任，自签不构成独立签收）
accepted_at: "…"
note: ""
```

## 代码审查记录（④ 审查门）

`reviews/CHECKLIST.md`（审查清单，逐项打勾）：

```markdown
- [ ] diff ⊆ write_paths（无越写集）
- [ ] 符合简报 acceptance 与 DoD
- [ ] 无明显缺陷 / 安全隐患 / 文档缺失
- [ ] 证据(evidence)已附且通过
- [ ] 无阻塞级问题
```

`reviews/<task_id>.md`：

```markdown
# Review: <task_id>
reviewed_by: "<code-review | run-lead>"
reviewed_at: "…"
conclusion: pass             # pass | needs-work
checklist: [勾选项]
comments:
  - "<打回/放行意见>"
```

## 合并门（⑤ 后段，P10）

`approvals/merge.yaml`：

```yaml
run_id: run-2026-0001
chunk_ids: [chunk-a]         # 串行：一次一个（拓扑序）
status: approved             # proposed | approved | done | failed
approved_by: release-eng
approved_at: "…"
preconditions:
  evidence: true
  diff_within_write_paths: true
  review: true               # L/高风险：code-review（见 R8）
  merge_ack: run-lead
```

## 需求变更单（R6，D038）

`change_orders/<id>.yaml`：

```yaml
id: co-001
run_id: run-2026-0001
from: sponsor
status: proposed              # proposed → applied（变更已落地：同步 chunks.yaml 的 new_acceptance）→ closed（受影响 chunk 验收通过后闭单，记 closed_at）；未闭环不得 complete
affects_chunks: [chunk-b]
new_acceptance: ["<变更后验收>"]
user_ack_at: "…"
closed_at: null
```

## 评分档案（⑤，人事执行）

`tasks/<task_id>/staffing/scores.yaml`：

```yaml
task_id: task-chunk-a
scored_by: people-qa
note: ""
team_score: 85                       # 公共项之和（clamp 0–100）
team_breakdown: { base: 50, evidence: 30, status: 10, handoff: 0, ack: 5, retries: -10 }
persona_scores:                      # 人设分 = 公共项 + seat 项（clamp 0–100），seat 规则见 references/knowledge.md 评分公式
  - { codename: "白泽", seat: engineer,   score: 90, breakdown: { base: 50, evidence: 30, status: 10, handoff: 0, ack: 5, retries: -10 }, seat_rules: { engineer_evidence_pass: 5 } }
  - { codename: "远山", seat: squad-lead, score: 90, breakdown: { base: 50, evidence: 30, status: 10, handoff: 0, ack: 5, retries: -10 }, seat_rules: { squad_lead_dissolved: 5 } }
  - { codename: "玄鸟", seat: sdet,       score: 90, breakdown: { base: 50, evidence: 30, status: 10, handoff: 0, ack: 5, retries: -10 }, seat_rules: { sdet_commands_all_green: 5 } }
```

> seat 规则（见 references/knowledge.md 评分公式）：engineer evidence pass +5；sdet 命令全绿 +5 或 fail −5；squad-lead dissolved +5。
> 全部数值示例 = 公共项 85 + seat +5 = 90。

## 调研简报（①/资料申请）

`research/briefs/<topic>.md`：

```markdown
# <主题>
检索时间：2026-08-13T12:00:00Z
## 结论
- <结论>（事实/推断）[来源](url)
## 来源
- url + retrieved_at + 摘要
```

## 下发包（②/资料申请，文档小组）

`tasks/<id>/inbox/packet.md`：经你 approve/redact/deny 后的过滤资料；小组只读 packet + 当前 brief + 原读写集。

## 记忆简报（P11，文档小组 → 你）

`docs/memory/`：L0 各方产出 → 技术写作 L1 → 你批准后 L2；每 N 个 task closed（默认 3）给你一份 L2 增量；goal 完成前给完整 Memory Brief。

## 运行根结构（SKILL §1.2 下沉）

> 本节是 SKILL.md §1.2 的完整展开（L1 按需层）：总库运行根目录树、文件隔离硬要求、项目记忆关联。SKILL 正文只留速记与指针（D074 预算纪律）。**本节约束与 SKILL 正文同等效力**。

### 1.2 运行根结构（位于 `~/.dsh-codepunk/projects/<project_id>/` 下）

```text
projects/<project_id>/          # 项目总库根，= 运行根 DSH_CODEPUNK_PROJECTS/<id>/
  README.md  goal.yaml  chunks.yaml  plan_draft.md
  change_orders/<id>.yaml       # 变更单 D038
  approvals/merge.yaml          # 合并门批准（阶段 ⑤ 后段）
  runs/<run_id>/                # 每轮独立目录
    research/briefs/<topic>.md   # 调研简报（任务简报在 tasks/<task_id>/brief/，勿混）
    docs/memory/
    reviews/<task_id>.md        # 审查记录 Reviewed-by + pass|needs-work
    errors/YYYY-MM-DD.md        # 错误日志 collected→…→closed
    rooms/squad-<task_id>/      # S 规模工作房（工程根内，非总库）
    tasks/<task_id>/
      brief/     WORK_BRIEF.md + brief.yaml
      staffing/  request.yaml + personas/*.md + staffing.yaml + scores.yaml
      handoff/   summary.md + artifact_index.md + known_issues.md + diff_scope.md \
                 + evidence.yaml（sdet 证据索引）+ acceptance.yaml（接收方签收）
                 # 四个 md 与两个 yaml 均**直接位于 handoff/**（勿再套一层 evidence/）
      progress/  progress.md
knowledge/                      # 知识库（跨 run 沉淀）
  hr/personas/<codename>.yaml  hr/teams/<team_name>.yaml
  lessons/<topic>.yaml          # 结构化经验 D070
  research/<topic>.md  handoffs/<task_id>.md  prompts/roles/<role_id>.md
```

> **文件隔离硬要求**：git 仓库且并行小组 ≥2（M/L）**MUST** 每组建 **worktree**。前置：主仓库先归位工程根（禁留桌面根/下载等散落位），再依其**父目录**建：`git -C <主仓库> worktree add ../room-<task_id> -b dsh-codepunk/<run_id>/<task_id>` → `git -C <主仓库> worktree list` 复核落点。**禁止在非工程根目录建 worktree**。S 规模用 `rooms/squad-<task_id>/`（工程根内，**须确保工程 `.gitignore` 忽略 `rooms/`**，file-hygiene §一.6）。越界兜底 R8 审查门（`git diff ⊆ write_paths`）。

> **工程域例外（不属于总库）**：worktree 建在**工程父目录**（`../room-<task_id>`）、S 规模 `rooms/squad-<task_id>/` 在**工程根内**，两者均不进总库；总库只存本 run 状态（goal/chunks/plan/tasks/handoff）。
> **项目记忆关联**：主通道 = 工程根 `README.md` 顶部 YAML frontmatter `dsh-codepunk: <project_id>`（无 frontmatter 可用 `<!-- dsh-codepunk: <id> -->`）；兜底 = `~/.dsh-codepunk/INDEX.yaml` 注册表（5 字段：project_id / project_root / dsh_codepunk_path / migrated_at / source）。工具 `dsh-codepunk-link resolve <项目路径>` 三态路由「README 标记 → INDEX 回退 → 未注册报错」；`index` 校验无空悬；`register` 追加（不覆盖、需确认）。**冲突以 INDEX 为准**；不批量改写项目 README。正式位 `~/.dsh-codepunk/scripts/`（`plans/` 仅源副本）。

### 1.3 运行根 `README.md` 的 `write_scope:` 段（R17）

> 运行根 `README.md` 除 spawn 登记表外 MUST 含 `write_scope:` 段（写盘台账）：允许写入前缀清单 + 本轮已创建物清单 + 清理状态 + `exempt:` 豁免登记。机械门 `plans/write-scope-check.sh`（exit 0 通过 / 1 越界 / 2 无法核验）据此核验；越界即缺陷（判据与命名见 `references/file-hygiene.md`「写盘白名单与越界判据」）。

```yaml
write_scope:
  run_id: run-2026-0001
  allowed_prefixes:                      # 允许写入前缀（按优先序，R17：运行根 → 授权工作树 → 临时目录 → 总库）
    - "~/.dsh-codepunk/projects/<project_id>/runs/<run_id>/"
    - "~/.dsh-codepunk/worktrees/<task_id>/"          # 仅限该任务 write_paths
    - "${TMPDIR:-/tmp}/dsh-codepunk-<run_id>-<step>/" # 次选，用毕即删
    - "~/.dsh-codepunk/projects/<project_id>/knowledge/"
  created:                               # 本轮已创建物清单（一行一件：路径 + 用途 + 清理状态）
    - { path: "logs/probe-r<轮次>-<用途>.sh", purpose: "<用途>", cleaned: true }
    - { path: "tmp/<run_id>/<step>/", purpose: "<用途>", cleaned: false }
  cleanup_status: pending                # clean（本轮临时物已全清）| pending（有残留：须写残留清单与责任席）
  exempt:                                # 豁免登记：真实交付物不属临时物（每条须写理由）
    - { path: "skills/dsh-codepunk-workflow/references/file-hygiene.md", reason: "交付物，非临时物" }
```

> 口径：`cleanup_status: clean` 是交接门与合并门的**前置读数**；`pending` 不得进入交接/合并（同 D079 残留自查门闩）。台账行与实况不符（写 clean 而门禁判 FAIL）以机械门结论为准。

## 子代理状态清单（D095：启动自检 + 定时巡检用）

> 独立 YAML 状态清单（区别于 `runs/<run_id>/README.md` 里的人读登记表）。主进程每次启动 + 每 N 轮定时执行「查 → 比 → 续 → 写」闭环，并在每次巡检后更新本文件。文件名 `runs/<run_id>/agents.yaml`（与同目录 README 登记表双写一致）。

```yaml
# 子代理状态清单 agents.yaml（机器可读，状态唯一真源以运行中 list_agents 为准）
run_id: run-2026-0001
updated_at: "2026-09-18T00:00:00Z"   # 每次巡检后刷新
patrol_every_n_rounds: 5             # 定时巡检间隔（默认 5 轮，可按 run 规模调）
```

> **写入约束（MUST，D099）**：本文件是**机器可读**清单，写入后 MUST 立即用**严格解析器**回读校验：`node -e "require('<DSH 安装根>/node_modules/js-yaml').load(require('fs').readFileSync('<path>','utf8'))"` ——js-yaml v4 默认**拒绝重复键**，而 `ruby -ryaml`（Psych）**不报重复键**（实测：条目下同时存在两个 `at`/两个 `note` 时 Psych 静默取后者、js-yaml 报 `duplicated mapping key`）⇒ 巡检写回把新条目插在上一轮条目的字段之前这类错位，只有严格解析器能发现。另 MUST 逐条核对**字段归属**（每个 `round` 条目须齐备 `round`/`at`/`note`，不得把上一轮的字段留在新条目之下），并比对关键字段长度：自由文本值（`result` / `note`）若含裸半角冒号加空格 ⇒ YAML **语法错误**（整文件不可解析）；若含**空格 + 半角井号** ⇒ 该值被当作注释**静默截断**（实测：同一条 `result` 源 536 字，写入后仅解析出 325 字）。两者均须改用全角冒号 / 全角井号，或把值加引号。校验命令不得只做 grep——**行存在 ≠ 可解析**。

```yaml
policy:                              # 反循环策略段（细则见 references/anti-loop.md；无该段时按 SKILL R16 默认执行）
  no_new_evidence_steps: 3           # 连续 N 步无新证据 ⇒ 强制输出「当前假设/已证伪项/下一步不同做法」
  no_new_evidence_hard: 5            # 连续 N 步无新证据 ⇒ 换策略或上报，禁止原样重试
  same_failure_fingerprint: 2        # 同一失败指纹重复 N 次 ⇒ 换策略；第 3 次由派发层拒绝并回结构化反馈
  same_command_repeat: 3             # 同一命令重复 N 次 ⇒ 判为空转，改走后台或降规模
  step_timeout_s: 300                # 单步超时 ⇒ 转后台任务并降低扫描规模
  context_hygiene: conclusion-only   # 失败轨迹只写结论与已证伪路径；压缩后复核硬约束原文
seats:
  - task_id: chunk-a
    seat: squad-lead                 # squad-lead | engineer | sdet
    codename: 衡策                   # staffing.yaml 一致
    subagent_id: 6420f25a-0000-4000-8000-000000000000
    label: 衡枢-主责(配置层优化)      # 派单 description 原样
    status: active                   # active | done | interrupted | recovered | failed
    last_seen: running               # 最近一次 list_agents 的**工具可见**状态：running | inactive | 未在册
                                     # （该工具只列可续聊子代理；一次性子代理不列出）
    expected: active                 # 期望：active（有未完成交付）| done（已签收，可不清）
    progress_ref: tasks/chunk-a/progress/progress.md
    last_checkpoint_at: "2026-09-18T00:00:00Z"
    note: ""                         # 中断原因 / 续行记录
```

**字段语义**：`status` 为主进程维护的目标态，`last_seen` 为最近巡检的实测态；二者不一致（active 但 running 之外）即中断席。`expected: done` 的席跳过恢复。

**状态迁移主体与触发条件（单点权威；`status` 只由 run-lead 写）**——`interrupted`/`failed` 此前无归属：

| 迁移至 | 主体 | 触发条件（可观测） |
| --- | --- | --- |
| `active` | run-lead | 派发该席时（`创建即登记`，`subagent_id` 落盘） |
| `interrupted` | run-lead | 巡检查得 `expected: active` 而 `last_seen ∈ {inactive, 未在册}`（即中断席）；**同轮写 `last_seen`/`note`（中断原因）** |
| `recovered` | run-lead | 经授权唤醒（`send_message` 附断点摘要）后续行成功；登记 `note`＝断点与授权 |
| `done` | run-lead | 接收方签收后（**与 `chunks.yaml` 的 chunk 态同时置**，见 SKILL ⑤） |
| `failed` | run-lead | 该席不可恢复：连续回修仍不可用、或 `subagent_id` 已不可达而须重建（§5 失败处理）；**记 `note` 与重建去向** |
