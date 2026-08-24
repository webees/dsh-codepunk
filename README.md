# dsh-codepunk · 多智能体开发流程预设

**dsh-codepunk** 是运行于 DeepSeek Harness 的多智能体开发流程预设：以**六阶段闭环**编排一组固定角色子代理，将工程从需求推进到交付——并行、可审计、持续进化。

主会话兼任 **工程主责（run-lead）· 技术统筹（tpm）· 会话调度（sess-mgr）** 三席，不联网、不写业务码；派遣**实现三角**与**职能岗**子代理，以公文驱动（简报 → 交接包 → 证据 → 签收）推进工程。工程目录零污染，运行状态统一存于用户级总库 `~/.dsh-codepunk/`（总库语义）。

---

## 流程总览（六阶段闭环）

| # | 阶段 | 工作 | 参与 | 关键产物 |
|---|---|---|---|---|
| 1️⃣ | **需求确认** | 用户提需求 → 工程主责主持对话，产品策划澄清口径，调研小组实时联网检索 → 与用户逐项确认后 active | 工程主责 · 产品策划 · 调研小组 | `goal.yaml`（用户确认后 active） |
| 2️⃣ | **规划与组队** | 工程主责定研发计划与用人标准 → 文档小组组简报 → 人才主责真招聘三人小组 → 双门闩批准后开工 | 工程主责 · 技术统筹 · 文档小组 · 人才主责 · 软件架构 | `chunks.yaml` · `brief/` · `staffing/` |
| 3️⃣ | **多小组并行开发** | 每 task 一组三人小组（小队主责+开发+测试），在独立封闭工作房并行推进、互不干扰；并行上限按 scale（S≤1 / M≤3 / L≤6） | 实现三角（每 task 一组） | 各工作房交付 · `progress/` |
| 4️⃣ | **巡检与交接** | 小队主责巡检本组进度、组织闭环；审查门核验 diff ⊆ 写集；交接包齐全后接收方签收 | 小队主责 · 代码审查 · 接收方 | `handoff/` · `acceptance.yaml` |
| 5️⃣ | **解散与评分** | 签收后各组就地解散，人事单元按证据/状态/交接等硬信号评分沉淀 | 人才主责 | `scores.yaml` · 人事档案 |
| 6️⃣ | **再规划** | 工程主责+技术统筹综合各组成果、评分与知识库，规划新一轮 → 重新招聘 → 执行 | 工程主责 · 技术统筹 | 新一轮 `chunks.yaml` |

```text
需求 → 规划 → 招聘 → 并行开发 → 交接 → 评分 → 再规划 ♻️
```

> 阶段 ⑤ 附**合并门**：串行合并、按依赖拓扑逐个进行；evidence+门禁齐并经 `approvals/merge.yaml` 批准，未完成不合并。

---

## 编制结构

### 实现三角（每 task 一组，真招聘）

| 席位 | 职责 | 边界 |
|---|---|---|
| 🎯 **小队主责** squad-lead | 对齐目标、拆解步骤、组织闭环、巡检进度、组织交接 | 不代写业务代码主体、不代验收 |
| 🛠 **开发** engineer | 在写集内实现、产出清晰交付与清单 | 只改写集、不得自行合并主干 |
| 🧪 **测试** sdet | 按 acceptance 验收、产出证据，不合格打回 | 只跑允许命令、不伪造证据 |

### 职能岗 / 辅助编制

| 岗位 | 职责 |
|---|---|
| 📚 **文档小组** docs | 组装/校对/下发工作简报；汇总合并交接信息、统一口径、防信息孤岛；归档记忆、优化角色提示词 |
| 🔍 **调研小组** research | 配合需求对话联网检索资料、协助数据整理；资料经工程主责审核后精准下发（**唯一联网岗**） |
| 🗄 **知识库** knowledge | 沉淀评分/交接/调研成果跨组复用，为招聘、规划、提示词优化提供依据 |
| 产品策划 pm / 软件架构 sys-arch | 需求澄清与验收口径 / 勘察分块与写集依赖 |
| 人才主责 people / 流程审计 proc-audit / 代码审查 code-review / 发布执行 release-eng | 招聘与评分 / 合规红灯 / 审查门 / 串行合并门 |

---

## 质量控制

- **双门闩（R1）**：工作简报批准 ∧ 用工批准，缺一不得开启实现组。
- **审查门（R8）**：交接/合并前 diff ⊆ 写集 + 审查清单 + 审查记录；L/高风险强制独立代码审查。
- **合并门（R9）**：串行合并、按拓扑、证据+门禁齐、`approvals/merge.yaml`；未完成不合并。
- **文件纪律（R13/R14）**：内容归什么域就写什么域——预设自身的调研/基准进 `benchmarks/`，工程业务进总库项目目录；接收产出时复核归属域与实际落位一致，防漂移传播。
- **goal 自动续行（R10）**：create 即 armed，子代理完成 → 主管自动消化 → 实时规划；resume/fork 后需 `update_goal resume` 重武装。

---

## 快速开始

### 安装 / 挂载

放入任一部署根即成为本地作者预设，目录名即 preset id：

```bash
DST="$HOME/.dsh/.agent-presets/dsh-codepunk"
mkdir -p "$DST"
cp -R agent.cordis.yml preset.yml skills "$DST/"
```

- 目录结构必须含 `agent.cordis.yml`（组合：persona + 工具 + realm）与 `skills/`（playbook）；`preset.yml` 为可选展示描述。
- Discovery 每次重读根目录，进程内修改即见；会话/组合按 preset 名引用即挂载。挂载校验：`dsh-agent-presets` 对组合做形状检查（顶层列表 + 每行有 `name` + group 递归），并用 `entryListSchema`（含 `!!js`）解析；格式/语义错误会标记为 broken roster row。

### 运行引导（工程主责）

1. 开工前**必须加载 `dsh-codepunk-workflow` skill** 并按 `SKILL.md` 执行。
2. **开工三件事**（SKILL.md §1.1）：
   ```bash
   dsh-codepunk-link resolve <工程根>            # ① 关联项目（未注册先 register）
   source ~/.dsh-codepunk/dsh-codepunk-home.sh   # ② 装载路径常量
   mkdir -p ~/.dsh-codepunk/projects/<id>/runs/<run_id>/   # ③ 建运行根（总库内）
   ```
   知识库位于总库对应项目目录；**工程目录保持纯净（零运行状态残留）**。
3. **开工第一步用 `create_goal` 建 active goal**（自动续行/自动递送）；resume/fork 后先 `get_goal` 检查激活态，非 armed 就 `update_goal resume` 重武装——否则子代理结算通知会堆积为排队消息、需手动递送。
4. 逐阶段推进；sponsor 确认一律走 `ask_user_question`（你 → 人类），不经子代理中转。

---

## 目录结构

```text
agent.cordis.yml                    # 组合：persona + 工具 + realm（AGENT-PLANE）
preset.yml                          # 预设描述（roster 展示）
README.md                           # 本说明
plans/                              # 工具脚本源副本与规划文档
  dsh-codepunk-link.sh              # 项目↔总库关联解析（resolve / index / register）
  dsh-codepunk-migrate.sh           # 工程内运行数据迁移工具（--scan / --migrate / --rollback）
  dsh-codepunk-init.sh              # 总库骨架幂等初始化
  verify-worktree.sh                # worktree 落点纪律核验
  workspace-refactor-chunks.yaml    # 工作区重构分块方案（规划文档）
  workspace-refactor-product.md     # 工作区重构需求纪要（规划文档）
skills/dsh-codepunk-workflow/       # 流程 playbook（skill）
  SKILL.md                          # 流程权威正文（六阶段 + 硬规则 R1–R14 + D 决策号）
  references/roles.md               # 岗位人设与派遣模板
  references/artifacts.md           # 产物文件模板（goal/chunks/brief/…）
  references/knowledge.md           # 知识库布局 + 评分公式 + 聚合格式
  references/standard.md            # 编号（P01–P17 / D0xx）唯一权威释义
  benchmarks/                       # 开源基准调研（多智能体编排 / agent-skills）
```

用户级总库 `~/.dsh-codepunk/`：`INDEX.yaml`（项目注册表）、`dsh-codepunk-home.sh`（路径常量）、`projects/<id>/`（各项目全部 run 记忆与知识库）。

---

## 维护公约（改动前必读）

- **Host/Agent 平面边界**：服务注册不进本预设；需要 `isolate` realm 的行必须放在带 `isolate:` 的 group 内。改动前对照 `editing-cordis-compositions` skill。
- **逐岗 allow 白名单锚点**：每岗 `toolFilter.allow` 收敛为单一 YAML 锚点 `&role-allow`（调研岗唯一例外，内联追加 `web_search, web_fetch`）。allow 是**全关只放行**列表，未列入的工具一律不可见。新增岗位/工具须同步锚点；allow 只能列本机已挂载的全局工具名——名字不存在会在 spawn 时随 `tools.restrict()` 直接 throw（fail-closed）。`report` 是延续子代理注册在自身层的汇报工具，不受过滤，**切勿列入 allow**。
- **画布工具权限是机械强制**（restrict 真移除工具）；**文件写集是约定强制**（人设自律 + 审查门 diff ⊆ 写集 + worktree 隔离），不是沙箱。
- **编号可解析**：`Pxx` / `D0xx` 一律以 `references/standard.md` 为唯一释义；禁止引入该文件之外的任何外部编号引用。
- **文件归宿（R13）**：预设自身的资料（开源基准、流程改进）存本预设 `skills/dsh-codepunk-workflow/benchmarks/`，绝不写入任何工程目录；各 run 的 `research/briefs/` 只放该工程业务调研。
- **产出归位复核（R14）**：接收子代理产出时核对内容归属域与实际落位一致；错位立即移出并核销引用，不让漂移文件跨 run 传播。