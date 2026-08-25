# 产物文件模板（references/artifacts.md）

运行目录：`~/.dsh-codepunk/projects/<project_id>/runs/<run_id>/`（总库语义 D072），知识库：`~/.dsh-codepunk/projects/<project_id>/knowledge/`。所有 YAML 用 UTF-8，字段名保持稳定以便知识库聚合与跨轮复用。

## goal.yaml（①，sponsor 确认后 active）

```yaml
run_id: run-2026-0001
title: "<目标一句话>"
kind: delivery          # delivery | self_evolve
status: active          # intake | draft | active | blocked | completed | cancelled（状态机见 SKILL.md ①）
scale: S                # S | M | L（并行上限 S=1 / M=3 / L=6，软限 max_awake 8）
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

## 工作简报（②，你签发）

`tasks/<task_id>/brief/WORK_BRIEF.md`：目标 / 边界 / acceptance / 禁区 / 必读 refs / 席位侧重。
`tasks/<task_id>/brief/brief.yaml`：

```yaml
task_id: task-chunk-a
status: approved                   # draft | in_review | approved | superseded
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
status: submitted                  # submitted | in_hr | run_lead_review | approved | rejected
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
| summary.md | squad-lead | 做了什么、怎么验证、遗留事项 |
| artifact_index.md | engineer | 交付物清单（文件→用途） |
| known_issues.md | 三人 | 已知问题与后续建议 |
| diff_scope.md | lead/编排 | diff ⊆ write_paths 的说明 |
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

> **交付基线纪律（R12）**：若交付目录 mtime 早于 evidence 生成时刻（空跑/旧快照），或验收时交付尚未落盘，evidence 一律判为无效，打回 sdet 基于最新交付重跑；禁止把「交付前空目录」的 FAIL/NOT_PASS 误当最终结论。

> **schema 强约束（D069，借鉴 outlines/agentskills）**：evidence.yaml / acceptance.yaml 的**结构必须在生成期保证可机器校验**——sdet 产出后先过结构校验（必填字段齐、类型对、exit_code∈{0,非0}、accepted_by 为数组），校验不合格直接回退，不经人工放行滑入下一阶段。证据即接口：交接/评分/审计/合并门一律以「结构合法 + 内容达标」双标准读取，杜绝靠自由文风或长上下文记忆判断。
> **机械校验器（D069 实现 · 防假通过门）**：`plans/evidence-verify.sh`（正式位 `~/.dsh-codepunk/scripts/evidence-verify.sh`）对 evidence.yaml 做四条机械断言——①command 首词白名单且非描述性文本（自然语言/「详见」式引用即 FAIL）②log_ref 文件真实存在（多前缀探测）③exit_code 常见值 ④`validated_at` 晚于交付目录 mtime（R12 数值化）。sdet 产出后、release-eng 合并前 MUST 执行一次（如 run 状态：`bash ~/.dsh-codepunk/scripts/evidence-verify.sh runs/<id>/tasks/<tid>/handoff/evidence.yaml <task_dir>`）；verdict=FAIL 即整包打回。历史实证：能机械抓出「自然语言命令 + exit_code=0 + 照填 PASS」的伪证据。

`acceptance.yaml`（接收方签收；无此文件不得 dissolved；`accepted_by` 为数组）：

```yaml
task_id: task-chunk-a
accepted_by:
  - "squad-lead@task-chunk-b"       # 下游小队主责；无下游 → docs-lead 或 tpm（非 run-lead 默认）
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

## 合并门（⑤′，P10）

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
status: proposed              # proposed → applied → closed
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
