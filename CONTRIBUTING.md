# CONTRIBUTING · dsh-codepunk 贡献指南

本文件面向有意为本仓库提交改动（PR / patch / issue 附补丁）的贡献者，说明：仓库是什么、目录结构、改动必须遵守的维护公约，以及提 PR 前必须满足的门槛。全文以仓库当前实况为准；改动前请先对照 `README.md` 与 `skills/dsh-codepunk-workflow/SKILL.md` 的最新表述。

## 仓库是什么

dsh-codepunk 是一份**多智能体开发流程预设**：基于 DeepSeek Harness 以「六阶段闭环」（需求确认 → 规划与组队 → 并行开发 → 巡检交接 → 解散评分 → 再规划）编排一组固定角色子代理，通过公文驱动（简报 / 交接包 / 证据 / 签收）把工程从需求推进到交付。

预设的承重机制包括：**双门闩**（简报批准 ∧ 用工批准方可开工）、**实现三角**（每 task = 小队主责 + 开发 + 测试）、**审查门 / 合并门**、**goal 自动续行**、以及**用户级总库**（运行状态统一存放于 `~/.dsh-codepunk/projects/<id>/`，工程目录保持纯净）。

本仓库不是普通代码库：核心交付物是**流程正文与岗位人设**（skill 文档与组合配置），对它们的改动必须保持流程语义自洽与编号可解析。

## 目录结构

```text
agent.cordis.yml                    # AGENT-PLANE 组合：persona + 工具 + realm（权威岗位配置）
preset.yml                          # 预设描述（roster 展示）
README.md                           # 项目总说明（向使用者）
CONTRIBUTING.md                     # 本文件（向贡献者）
plans/                              # 工具脚本
  dsh-codepunk-init.sh              # 总库骨架幂等初始化
  dsh-codepunk-link.sh              # 项目↔总库记忆关联解析（resolve/index/register）
  dsh-codepunk-migrate.sh           # 工程内旧运行数据 → 总库迁移工具（scan/migrate/rollback）
  verify-worktree.sh                # worktree 落点纪律核验
skills/dsh-codepunk-workflow/       # 流程 playbook（skill）
  SKILL.md                          # 流程唯一权威正文（六阶段 + 硬规则 R1–R14 + D 决策号）
  references/roles.md               # 岗位人设与派遣模板
  references/artifacts.md           # 产物文件模板（goal/chunks/brief/handoff/evidence）
  references/knowledge.md           # 知识库布局 + 评分公式 + 聚合格式
  references/standard.md            # 编号（P01–P17 / D0xx）唯一权威释义
  benchmarks/                       # 开源基准调研（多智能体编排 / agent-skills）
```

> 目录结构若有变动，`README.md` 的「目录结构」段必须同步更新。

## 如何改：维护公约要点

对任何文件动手前，先读 `README.md` 末尾「维护公约（改动前必读）」与 `skills/dsh-codepunk-workflow/SKILL.md`。以下四点是硬约束：

1. **Host/Agent 平面边界**：服务注册（bash-sandbox、fs 服务、goal 服务、任务注册表等 host 平面组件）不进本预设；需要 `isolate` realm 的行必须放在带 `isolate:` 的 group 内。改组合前对照 `editing-cordis-compositions` skill。
2. **逐岗 allow 白名单锚点**：每岗 `toolFilter.allow` 收敛为单一 YAML 锚点 `&role-allow`；调研岗是唯一例外，内联追加 `web_search, web_fetch`。allow 是「全关只放行」列表，未列入的工具一律不可见；**只能列本机已挂载的全局工具名**（未挂载会让 spawn 时 `tools.restrict()` 直接 throw）；`report` 是延续子代理注册在自身层的汇报工具，**切勿列入 allow**。
3. **编号可解析**：`Pxx` / `D0xx` 一律以 `references/standard.md` 为唯一释义；禁止引入该文件之外的任何外部编号引用。变更涉及编号时，先改 `standard.md` 登记，再引用。
4. **文件归宿（R13/R14）**：关于预设本身的调研 / 基准 / 优化资料写本预设 `skills/dsh-codepunk-workflow/benchmarks/`，**绝不写进任何工程目录**；接收子代理产出时核对「内容归属域 vs 实际落位」一致，错位立即移出并 grep 核销引用。

## 提 PR 的门槛

提交 PR 前，以下四条逐项自检，任一不过即应回修：

1. **无说明即不改 README.md 之外**：除 `README.md` 外，仓库不存在「顺手改一下、无需说明」的文件——任何非 README 改动都必须在 PR 描述 / commit message 中说明目的、影响面与验证方式；README 自身改动也不得破坏其与仓库实况的一致性（命令、路径、目录结构、编号引用逐一对齐）
2. **零旧名残留（核心发布内容）**：README、plans 脚本、组合配置、skill 文档不得残留历史旧系统名及其目录名 / 变量名 / 路径变体；提交前用 `git grep -rni 'p\[i\]code' -- .` 自检须 0 命中（拆写+转义，避开字面自命中）（git grep 只扫跟踪文件，自然排除本地运行工件目录与未跟踪文件）
3. **agent.cordis.yml 必须过 entryListSchema 校验**：组合须通过形状检查（顶层为列表、每行有 `name`、group 递归）+ `entryListSchema`（含 `!!js` 表达式）解析；格式 / 语义错误会标记为 broken roster row，必须修复后才能合入
4. **skill 文档须过结构检查**：`SKILL.md` 六阶段闭环与硬规则编号须与 `references/standard.md` 一致；`references/`（roles/artifacts/knowledge/standard）四件齐、结构完整，代码块 / 表格闭合，新增引用有对应释义

## 提交前检查清单

- [ ] 改动仅限必要文件，diff 清晰、commit message 说明充分
- [ ] `git grep -rni 'p\[i\]code' -- .` 0 命中（跟踪内容；含目录名 / 变量名变体）
- [ ] `agent.cordis.yml` 过 entryListSchema 校验，无 broken roster row
- [ ] skill 文档通过结构检查；编号引用与 `references/standard.md` 一致
- [ ] 目录结构 / 命令 / 路径有变动时，`README.md` 已同步
- [ ] 预设自身资料落在 `benchmarks/`，未写进任何工程目录（R13/R14）