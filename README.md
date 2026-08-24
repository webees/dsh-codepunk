# dsh-codepunk · 多智能体开发流程

**dsh-codepunk** 是一个基于 DeepSeek Harness 的多智能体开发流程预设：以**六阶段闭环**编排一组固定角色子代理，将工程从需求推进到交付——并行、可审计、持续进化。

主会话担任 **工程主责（run-lead）+ 技术统筹（tpm）+ 会话调度（sess-mgr）**，派遣**实现三角**与**职能岗**子代理，通过公文驱动（简报/交接包/证据/签收）完成工程目标；工程目录零污染，运行状态统一存于用户级总库。

---

## 流程总览（六阶段闭环）

| # | 阶段 | 工作 | 参与 | 关键产物 |
|---|---|---|---|---|
| 1️⃣ | **需求确认** | 用户提需求 → 工程主责主持对话，产品策划协助澄清，行业分析实时联网查资料 → 与用户确认工程项 | 工程主责 · 产品策划 · 调研小组 | `goal.yaml`（用户确认后 active） |
| 2️⃣ | **规划与组队** | 工程主责定研发计划 + 用人标准 → 人才主责按任务真招聘三人小组 → 双批准后开工 | 工程主责 · 技术统筹 · 人才主责 · 软件架构 | `chunks.yaml` · `brief/` · `staffing/` |
| 3️⃣ | **多小组并行开发** | 每个三人小组 = 小队主责 + 开发 + 测试；一工程可同时组建多组并行推进不同模块，互不干扰；每组在独立封闭工作房独立开发、独立交接 | 实现三角（每 task 一组） | 各工作房代码 · `progress/` |
| 4️⃣ | **巡检与交接** | 小队主责巡检本组进度、组织闭环、完成交接包，接收方签收 | 小队主责 · 代码审查 · 接收方 | `handoff/` · `acceptance.yaml` |
| 5️⃣ | **解散与评分** | 交接完成各组就地解散，人事单元对每个小组分别评分沉淀 | 人才主责 | `scores.yaml` · 人事档案 |
| 6️⃣ | **再规划** | 工程主责 + 技术统筹综合各组成果规划新一轮 → 重新招聘 → 执行 | 工程主责 · 技术统筹 | 新一轮 `chunks.yaml` |

```text
需求 → 规划 → 招聘 → 并行开发 → 交接 → 评分 → 再规划 ♻️
```

---

## 编制结构

### 实现三角（每 task 一组，真招聘）

| 席位 | 职责 | 边界 |
|---|---|---|
| 🎯 小队主责 squad-lead | 对齐目标、拆解步骤、组织闭环、巡检进度、组织交接 | 不代写代码主体、不代验收 |
| 🛠 开发 engineer | 在写集内实现、产出清晰提交与交付清单 | 只改写集、不得合并主干 |
| 🧪 测试 sdet | 按 acceptance 验收、产出证据，不合格打回 | 只跑允许命令、不伪造证据 |

### 职能岗 / 辅助编制

| 岗位 | 职责 |
|---|---|
| 📚 **文档小组** docs | 统一组装、校对、下发各小组工作简报与资料包；汇总合并多组交接信息、输出统一口径、避免信息孤岛；归档记忆、持续优化各角色提示词 |
| 🔍 **调研小组** research | 主动配合需求对话、联网检索技术资料；协助数据整理与校对、为规划提供依据；资料经工程主责审核后精准下发（**唯一联网岗**） |
| 🗄 **知识库** knowledge | 沉淀每组评分、交接、调研成果，跨组复用；让后续招聘、规划、提示词优化有据可依、持续进化 |
| 产品策划 pm / 软件架构 sys-arch | 需求澄清与验收口径 / 勘察分块与写集依赖 |
| 人才主责 people / 流程审计 proc-audit / 代码审查 code-review / 发布执行 release-eng | 招聘与评分 / 合规红灯 / 审查门 / 串行合并门 |

---

## 质量控制

- **双门闩（R1）**：工作简报批准 ∧ 用工批准，缺一不得 spawn 实现组。
- **审查门（R8）**：交接/合并前 diff ⊆ write_paths + CHECKLIST + 审查记录；L/高风险强制独立 code-review。
- **合并门（R9）**：串行合并、按拓扑、evidence+门禁齐、`approvals/merge.yaml`；未 done 不合并。
- **文件纪律（R13/R14）**：内容归什么域就写什么域——预设 meta 资料进 `benchmarks/`，工程业务进总库项目目录；接收产出时核对归属域与实际落位一致，防漂移。
- **goal 自动续行（R10）**：create 即 armed，子代理完成 → 主管自动消化 → 实时规划；resume/fork 后需 resume 重武装。

---

## 快速开始

### 安装 / 挂载

目录名（放入后）即 preset id。任一部署可用根下放本地作者预设：

```bash
DST="$HOME/.dsh/.agent-presets/dsh-codepunk"
mkdir -p "$DST"
cp -R agent.cordis.yml preset.yml skills "$DST/"
```

- 目录结构必须含 `agent.cordis.yml`（组合）与 `skills/`（playbook）；`preset.yml` 为可选展示描述。
- Discovery 每次重读根目录，进程内修改无需重启即可见；会话/组合按 preset 名引用即挂载。
- 校验：`dsh-agent-presets` 对组合做形状检查（顶层列表 + 每行有 `name` + group 递归）并用 `entryListSchema`（含 `!!js`）解析；格式/语义错误会标记为 broken roster row。

### 运行引导（工程主责）

1. 开工前**必须加载 `dsh-codepunk-workflow` skill** 并按其执行；人设只兜底不加载时的硬规则。
2. **开工三件事**（SKILL.md §1.1）：
   ```bash
   dsh-codepunk-link resolve <工程根>            # ① 关联项目（未注册先 register）
   source ~/.dsh-codepunk/dsh-codepunk-home.sh   # ② 装载路径常量
   mkdir -p ~/.dsh-codepunk/projects/<id>/runs/<run_id>/   # ③ 建运行根（总库内）
   ```
   `knowledge/` 位于总库对应项目目录；**工程目录保持纯净（零运行状态残留）**。
3. **开工第一步 `create_goal` 建 active goal**（自动续行/自动递送）；resume/fork 后先 `get_goal` 检查、非 armed 就 `update_goal resume`——否则子代理结算通知会堆积成排队消息、需手动点击递送（机制见 SKILL.md §0.1 与 R10/R12）。
4. 逐阶段推进；所有 sponsor 确认走 `ask_user_question`（你 → 人类），不经过任何子代理。
5. 每个工程目标用 goal 工具（`create_goal` / `get_goal` / `update_goal`）编号跟踪。

---

## 目录结构

```text
agent.cordis.yml                    # AGENT-PLANE 组合：persona + 工具 + realm
preset.yml                          # 预设描述（roster 展示）
README.md                           # 本说明
plans/                              # 工具脚本（正式位 ~/.dsh-codepunk/scripts/）
  dsh-codepunk-link.sh              # 项目↔总库记忆关联解析（resolve/index/register）
  dsh-codepunk-migrate.sh           # 工程内旧运行数据 → 总库迁移工具（scan/migrate/rollback）
  dsh-codepunk-init.sh              # 总库骨架幂等初始化
  verify-worktree.sh                # worktree 落点纪律核验
skills/dsh-codepunk-workflow/       # 流程 playbook（skill）
  SKILL.md                          # 流程唯一权威正文（六阶段 + 硬规则 R1–R14 + D 决策号）
  references/roles.md               # 岗位人设与派遣模板
  references/artifacts.md           # 产物文件模板（goal/chunks/brief/…）
  references/knowledge.md           # 知识库布局 + 评分公式 + 聚合格式
  references/standard.md            # 编号（P01–P17 / D0xx）唯一权威释义
  benchmarks/                       # 开源基准调研（多智能体编排 / agent-skills）
```

---

## 维护公约（改动前必读）

- **Host/Agent 平面边界**：服务注册不进本预设；需要 `isolate` realm 的行必须放在带 `isolate:` 的 group 内。改之前对照 `editing-cordis-compositions` skill。
- **逐岗 allow 白名单锚点**：每岗 `toolFilter.allow` 收敛为单一 YAML 锚点 `&role-allow`（research 唯一例外，内联追加 `web_search, web_fetch`）。allow 是**全关只放行**列表，未列入的工具一律不可见。新增岗位/工具须同步锚点；**allow 只能列本机已挂载的全局工具名**——名字不存在会在 spawn 时随 `tools.restrict()` 直接 throw（fail-closed）。`report` 是延续子代理注册在自身层的汇报工具，不受过滤，**切勿列入 allow**。
- **画布工具权限是机械强制**（restrict 真移除工具）；**文件写集是约定强制**（人设自律 + R8 审查门 `git diff ⊆ write_paths` + worktree 隔离），不是沙箱。
- **编号可解析**：`Pxx`/`D0xx` 一律以 `references/standard.md` 为唯一释义；禁止引入该文件之外的任何外部编号引用。
- **文件归宿（R13）**：关于预设本身的调研/基准/优化资料存本预设 `skills/dsh-codepunk-workflow/benchmarks/`，**绝不写入任何工程目录**（运行根 `~/.dsh-codepunk/projects/<id>/runs/<n>/research/briefs/` 只放该工程业务调研）。
- **产出归位复核（R14）**：接收任何子代理产出/调研时，核对「内容归属域 vs 实际落位」一致；错位立即移出并 grep 核销引用，不让漂移文件跨 run 传播。