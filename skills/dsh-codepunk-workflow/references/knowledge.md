# 知识库运营（references/knowledge.md）

知识库 = 跨 run / 跨组的沉淀，让后续招聘、规划、提示词优化有据可依。位置：`~/.dsh-codepunk/projects/<id>/knowledge/`。

## 布局

```text
knowledge/                        # 位于 ~/.dsh-codepunk/projects/<id>/knowledge/
  hr/personas/<codename>.yaml      # 按人设名聚合的历史评分（支持同一人设跨 task 优化）
  hr/teams/<team_name>.yaml        # 按团队名聚合的历史评分（支持团队组合优化）
  research/<topic>.md              # 高价值调研沉淀（来源 + TTL）
  handoffs/<task_id>.md            # 交接摘要归档（文档小组维护）
  prompts/roles/<role_id>.md       # 各角色提示词（持续优化；招聘/派遣时引用）
  lessons/<topic>.yaml             # 结构化经验模板（触发条件→坑→解法，D070）
```
> 记忆简报：run 内运营于 `runs/<run_id>/docs/memory/`，收官归档入本库（与 SKILL.md §1.2 一致）。

## 评分公式（0–100，base 50）

| 项 | 团队分与人设分共有 | 人设分额外（seat） |
|---|---|---|
| base | 50 | — |
| evidence | pass +30 / fail −30 / 缺失 −20 | engineer：pass +5；sdet：命令全绿 +5 或 fail −5 |
| status | dissolved +10 / failed −10 / cancelled −5 | squad-lead：dissolved +5 |
| handoff | 每缺 1 文件 −5 | — |
| ack | ≥1 个签收 +5 | — |
| retries | 每次 −5（上限 −10） | — |

团队分 = 公共项之和（clamp 0–100）；人设分 = 公共项 + seat 项（clamp 0–100）。
信号全部来自文件事实（evidence / task.status / handoff 缺文件数 / acceptance ack 数 / retries），无 LLM 参与。

## 聚合文件格式

`knowledge/hr/personas/<codename>.yaml`：

```yaml
codename: "白泽"
seat: engineer
records:
  - { task_id: task-chunk-a, score: 88, at: "…" }
summary: { count: 1, avg: 88, min: 88, max: 88 }
notes: []
```

`knowledge/hr/teams/<team_name>.yaml`：

```yaml
team_name: "北辰"
records:
  - { run_id: run-2026-0001, task_ids: [task-chunk-a], team_score: 85, at: "…" }
summary: { count: 1, avg: 85, min: 85, max: 85 }
personas: [{ codename: "白泽", seat: engineer }, …]
```

## 读写责任

| 内容 | 写 | 读 |
|---|---|---|
| 评分档案 | `subagent_people`（task 解散后，幂等） | 你（再规划）、招聘 |
| 交接归档 | `subagent_docs`（P07 后） | 你、下游小组 |
| 调研沉淀 | `subagent_docs`（工程主责点名或高价值） | 你、简报组装 |
| 审查记录 | `subagent_code_review` / 你（交接/合并后） | 你、发布门 |
| 提示词优化 | `subagent_docs`（评分/复盘驱动） | 招聘、派遣 |
| 记忆简报 | `subagent_docs`（L0→L1→L2） | 你（门禁/完成前） |

**实现三角 MUST NOT 直接维护知识库主索引**：只消费 brief / packet。

## 再规划如何用知识库（⑥）

1. 读 `knowledge/hr/teams/`：高分团队组合 → 复用其画像特征写用工标准；低分项 → 写入 constraints/禁区。
2. 读 `knowledge/hr/personas/`：高分 codename → 下次招聘 `reuse_persona_ids` 或直接引用；低分 → 修订该角色提示词（`knowledge/prompts/roles/<id>.md` 升版）。
3. 读 `knowledge/handoffs/` 与 `research/`：下一轮简报的 must_read_refs 与调研要点。
4. 更新 `chunks.yaml` 进入新一轮；每轮结束时把 Memory Brief 归档入 `knowledge/`（见「布局」注记）。

## 硬信号驱动评分-再规划（D070，借鉴 CAMEL verifiable rewards / ChatDev 经验共学习）

- **硬信号优先**：评分与再规划的输入以文件事实（evidence pass/fail、缺陷密度、回修次数、交接缺文件数、签收数）为主，不靠主管印象；这些信号由 `subagent_people` 从 evidence/handoff/acceptance 自动采集。
- **验收通过率进再规划**：下一轮分块/用工/提示词修订时，引用上轮 `acceptance pass 率 + 回修次数` 作为权重——高频回修的模块降并行度、加强 sdet 证据门；低回修的高分小组复用其画像。
- **结构化经验模板**：把高分小组的「回修教训 / 捷径经验」沉淀为 `knowledge/lessons/` 下的结构化条目（触发条件 → 常见坑 gotchas → 标准解法 → 关联 evidence），供后续小组检索，跨轮直接降错。
- **经验→skill 沉淀回路**（graphify / skill-creator 借鉴）：收官/再规划时，从高分交接包、回修教训、审查记录**提炼候选 skill/提示词草稿**（触发条件→步骤→坑 →解法），run-lead 审后入 `knowledge/prompts/` 或 skill 索引，不得直接入库未经审的草稿。

## 提示词优化闭环

评分 + 交接复盘 → 识别某角色高频失分（如 sdet 证据缺失）→ `subagent_docs` 修订 `knowledge/prompts/roles/<id>.md` → 下一次招聘/派遣引用新版本 → 再评分验证。**只允许尾部追加命名池**：codename / team_name 生成后不得改名，否则破坏评分档案聚合。
