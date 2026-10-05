# dsh-codepunk · 多智能体开发流程预设

## 定位

**dsh-codepunk** 是运行于 DeepSeek Harness 的多智能体开发流程预设（官方「创造模式」产品形态：user preset + skill + 团队编排三层）：以**六阶段闭环**编排一组固定角色子代理，将工程从需求推进到交付——并行、可审计、持续进化；goal 自动续行 / skill 渐进披露 / subagent / sandbox-approval 均基于官方机制（见 benchmarks/deepseek-harness-study.md）。

主会话兼任 **工程主责（run-lead）· 技术统筹（tpm）· 会话调度（sess-mgr）** 三席，不联网、不写业务码；派遣**实现三角**与**职能岗**子代理，以公文驱动（简报 → 交接包 → 证据 → 签收）推进工程。工程目录零污染，运行状态统一存于用户级总库 `~/.dsh-codepunk/`（总库语义）。

---

## 流程总览（六阶段闭环）

| # | 阶段 | 工作 | 参与 | 关键产物 |
|---|---|---|---|---|
| 1️⃣ | **需求确认** | 用户提需求 → 工程主责主持对话，产品策划澄清口径，行业分析实时联网检索 → 与用户逐项确认后 active | 工程主责 · 产品策划 · 行业分析 | `goal.yaml`（用户确认后 active） |
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

每个 task 由「实现三角」落地交付，由「职能岗」提供支撑；岗位以 emoji 统一标识，职责与边界对齐表述。

### 实现三角（每 task 一组，真招聘）

| 席位 | 职责 | 边界 |
|---|---|---|
| 🎯 小队主责 squad-lead | 对齐目标 · 拆解步骤 · 组织闭环 · 巡检进度 · 组织交接 | 不代写业务代码主体 · 不代验收 |
| 🛠 开发 engineer | 在写集内实现 · 产出清晰交付与清单 | 只改写集 · 不得自行合并主干 |
| 🧪 测试 sdet | 按 acceptance 验收 · 产出证据 · 不合格打回 | 只跑允许命令 · 不伪造证据 |

### 职能岗 / 辅助编制

| 岗位 | 职责 |
|---|---|
| 📚 文档小组 docs | 组装/校对/下发简报 · 汇总交接统一口径 · 归档记忆 · 优化角色提示词 |
| 🔍 行业分析 ind-res | 配合需求对话联网检索 · 协助数据整理 · 资料经工程主责审核后下发（**唯一联网岗**） |
| 🗄 知识库 knowledge | 沉淀评分/交接/调研成果 · 为招聘、规划、提示词优化提供依据 |
| 💡 产品策划 pm | 需求澄清 · 验收口径 · 质量与优先级把关 |
| 🏗 软件架构 sys-arch | 勘察分块 · 写集与依赖设计 |
| 🔎 代码勘察 scout | 仓库勘察 · 模块与依赖盘点（供分块用） |
| 👥 人才主责 people | 真招聘三人小组 · 解散评分沉淀 |
| 🚦 流程审计 proc-audit | 对照流程查合规 · 偏离即红灯上报 |
| 🧐 代码审查 code-review | 审查门：diff 合规 · acceptance 符合 · 缺陷拦回 |
| 🚀 发布执行 release-eng | 合并门：串行合并 · 拓扑排序 · 门禁齐备放行 |

---

## 质量控制

- **双门闩（R1）**：工作简报批准 ∧ 用工批准，缺一不得开启实现组。
- **审查门（R8）**：交接/合并前 diff ⊆ 写集 + 审查清单 + 审查记录；L/高风险强制独立代码审查。
- **合并门（R9）**：串行合并、按拓扑、证据+门禁齐、`approvals/merge.yaml`；未完成不合并。
- **文件纪律（R13/R14）**：内容归什么域就写什么域——预设自身的调研/基准进 `benchmarks/`，工程业务进总库项目目录；接收产出时复核归属域与实际落位一致，防漂移传播。
- **goal 自动续行（R10）**：create 即 armed，子代理完成 → 主管自动消化 → 实时规划；resume/fork 后需 `update_goal resume` 重武装。

---

## 快速开始

### 安装 / 挂载（DSH ≥ 0.1.7）

`dsh-agent-preset-registry` 自 DSH 0.1.7 起**不再扫描** `~/.dsh/.agent-presets/<id>/`：注册表既不扫描目录，也不接受 preset 路径。自定义预设必须以 `@deepseek-ai/dsh-agent-preset` 声明行的形式注入 profile，否则引用该预设的会话恢复时报 `Unknown agent preset: dsh-codepunk`。

**① 落位源文件（唯一权威）**：

```bash
DST="$HOME/.dsh/.agent-presets/dsh-codepunk"
mkdir -p "$DST"
cp -R agent.cordis.yml preset.yml skills "$DST/"
```

**② 生成声明块并注入 profile patch**（`<profile>` 通常为 `desktop`）：

```bash
# 首次安装：把声明块追加进 profile patch（自动备份）
DSH_PROFILE_PATCH="$HOME/.dsh/profiles/<profile>/cordis.patch.yml" \
  node plans/preset-declare.mjs apply --append

# 已安装过：源改动后用源重写内联副本（自动备份）
node plans/preset-declare.mjs apply
```

**②-b 同步工具脚本到总库正式位**（升级预设后 MUST；运行期用的是总库副本）：

```bash
# 从仓内运行（幂等）：把 plans/*.{sh,py,mjs} 与 plans/windows/*.ps1 同步到 ~/.dsh-codepunk/scripts/
bash plans/dsh-codepunk-init.sh

# 只检查是否有缺失/过期（不写盘，非零退出即需同步）
bash plans/dsh-codepunk-init.sh --check
```

> 说明：总库副本是**运行期实际执行**的脚本（如 `~/.dsh-codepunk/scripts/evidence-verify.sh`），
> 故每次拉取新版本后都要跑一次上面的同步；从总库自身的副本运行只会提示「请改用仓内副本」，
> 不会自我复制。

**③ 校验内联副本未漂移**（改源后必须复跑；`verify-battery.sh` 已内置该项）：

```bash
node plans/preset-declare.mjs check    # 漂移即非零退出并列出差异路径
```

- 同一份组合存在两处表示：`agent.cordis.yml`（源，权威）与 profile patch 内的 `plugins:` 内联副本（进程实读）。**副本由源生成，勿手改**；两处一致性由 `preset-declare.mjs check` 语义比对保证。
- 内联副本有一处必要适配：`customSkillDirs` 的 `new URL('skills/', baseUrl)` 在 profile 上下文中 `baseUrl` 指向 profile 目录，须改写为回到预设目录的相对路径——`preset-declare.mjs` 生成时自动处理，`check` 比对时自动归一。
- 目录结构必须含 `agent.cordis.yml`（组合：persona + 工具 + realm）与 `skills/`（playbook）；`preset.yml` 为可选展示描述。
- `plans/` 工具脚本为源副本，不随预设复制；运行期装配与正式位（`~/.dsh-codepunk/scripts/`）见流程手册 `SKILL.md` §1.2。
- 声明在**进程启动时读取**，改动后须重启 DSH Desktop 生效。
- **解包布局**：DSH 2.0.10 仍为 `app.asar` 打包，2.0.12 起改为解包 `Contents/Resources/app/`（实测：2.0.10 可解析 asar 头部索引，2.0.12 起该文件不存在）。本仓所有依赖 DSH 安装位置的检查一律取环境变量（`DSH_APP_ROOT` 或 `DSH_ASAR`、`DSH_PROFILE_PATCH`），不硬编码任何平台路径，两种布局都支持。
- 挂载校验：`dsh-agent-presets` 对组合做形状检查（顶层列表 + 每行有 `name` + group 递归），并用 `entryListSchema`（含 `!!js`）解析；格式/语义错误会标记为 broken roster row。

### 运行引导（工程主责）

1. 开工前**必须加载 `dsh-codepunk-workflow` skill** 并按 `SKILL.md` 执行。
2. **开工五件事**（SKILL.md §1.1）：
   ```bash
   dsh-codepunk-link resolve <工程根>            # ① 关联项目（未注册先 register）
   source ~/.dsh-codepunk/dsh-codepunk-home.sh   # ② 装载路径常量
   mkdir -p ~/.dsh-codepunk/projects/<id>/runs/<run_id>/   # ③ 建运行根（总库内）
   ```
   知识库位于总库对应项目目录；**工程目录保持纯净（零运行状态残留）**。
3. **开工第一步用 `create_goal` 建 active goal**（自动续行/自动递送）；resume/fork 后先 `get_goal` 检查激活态，非 armed 就 `update_goal resume` 重武装——否则子代理结算通知会堆积为排队消息、需手动递送。
4. 逐阶段推进；sponsor 确认一律走 `ask_user_question`（你 → 人类），不经子代理中转。

---

## 平台支持（macOS / Linux / Windows）

| 平台 | Agent shell | 工具脚本 | 说明 |
|---|---|---|---|
| macOS | bash | `plans/*.sh` | 开箱可用（bash 3.2+ / BSD 工具链） |
| Linux | bash | `plans/*.sh` | 可用（GNU 工具链；脚本内已做 BSD/GNU 自适应） |
| Windows | pwsh | `plans/windows/*.ps1` | 预设在该平台禁用 bash 工具、启用 pwsh 工具（与官方预设同款门控） |

Windows 上从仓内运行一次 `pwsh -File plans/windows/dsh-codepunk-init.ps1` 即把 `.ps1` 同步到 `%USERPROFILE%\.dsh-codepunk\scripts\`（幂等；`-Check` 只报缺失/过期），随后以 pwsh 调用：

```powershell
. "$HOME\.dsh-codepunk\dsh-codepunk-home.ps1"        # 装载路径常量
pwsh -File dsh-codepunk-init.ps1                     # 建总库骨架
pwsh -File dsh-codepunk-link.ps1 resolve <工程根>     # 关联项目
pwsh -File dsh-codepunk-leak-guard.ps1 -Tree         # 推送前守卫
```

两套实现语义等价（resolve 三态路由、INDEX 字段约定、退出码一致）。Windows 版当前覆盖
**home / init / link / leak-guard** 四个核心脚本；`preset-audit`、`evidence-verify`、`acceptance-verify`、
`verify-worktree` 仍为 POSIX 版，Windows 上经 Git Bash 或 WSL 调用（属一次性迁移与运维场景，
非日常流程必需）。

换行策略见 `.gitattributes`：仓库内统一 LF，`.ps1` 检出为 CRLF。

## 质量工具（可复跑）

| 命令 | 作用 | 退出码 |
|---|---|---|
| `bash plans/preset-score.sh` | 15 指标评分（策略/质量/准确性/规范性/精简度 + 一致性/完整性/可执行性/可维护性/跨平台性/安全性/可发现性/语义保真/工程卫生/演进性），每项独立 100 分门槛 | 0=全满分；1=有失分项；2=环境/用法错误 |
| `bash plans/preset-audit.sh` | 5 组 100 分制审计（配置/手册/调研/文档/工具层） | 0=全达标；1=有失分项；2=预设根不存在 |
| `bash plans/verify-battery.sh` | 完整验证电池（评分+审计+守卫三模式+格式+杂散+结构+目录树一致+脚本语法+DSH 兼容+声明漂移+E2E 与总库无污染+检查器存活自检+文档声称一致性），14 项一次跑完 | 0=全通过；1=存在失败项；2=无法进入预设根 |
| `node plans/preset-declare.mjs check` | preset 声明副本漂移校验（源 `agent.cordis.yml` ↔ profile patch 内联块，语义比对） | 0=一致；1=确认漂移；2=参数错误，或缺 js-yaml 时「无法判定」（设 `DSH_APP_ROOT` 可启用语义核验）（缺 js-yaml 时降级比对） |
| `python3 plans/preset-compat.py` | 组合与当前 DSH 安装的兼容核验（插件包存在 / 配置键被插件接受 / group 隔离与锚点顺序 / allow 名单一致性） | 0=兼容；1=存在不兼容项；2=无法定位 DSH 安装 |
| `bash plans/evidence-verify.sh <evidence.yaml> <task_dir>` | 证据机械校验（D069 防假通过门）：`task_id`/`command`/`exit_code=0`/`log_ref` 齐备 + 证据 `id` 去重 + 时间序（乱序仅告警）；**verdict=PASS 才算过** | 0=通过（verdict=PASS）；1=未过；2=用法/文件缺失 |
| `bash plans/acceptance-verify.sh <acceptance.yaml> [交付方 task_id]` | 签收文件机械校验（D069）：`task_id`/`accepted_by[]`/`accepted_at` 齐备 + 签收独立性（不得自签；run-lead 自签须在 `note` 记原因） | 0=合规；1=不合规；2=用法/文件缺失 |
| `bash plans/doc-consistency.sh` | 文档**声称 ↔ 实现**一致性（计数声称 / 阶段口径 / 工具存在性 / 退出码契约 / 头部自称项数；术语项为咨询） | 0=一致；1=存在不一致；2=环境/用法错误 |
| `bash plans/checker-self-test.sh` | 检查器**存活自检**（变异测试）：沙箱副本内注入 **23 项**已知缺陷（M1–M23），断言**对应检查项**必须报错——专治「守护空转」 | 0=全部捕获；1=有守护未捕获；2=环境/自检问题 |
| `bash plans/dsh-codepunk-leak-guard.sh --tree` | 泄露防护门（禁词留本地；`--install-hook` 装 pre-commit + pre-push + commit-msg） | 0=通过；1=命中并阻断；2=用法/环境错误 |
| `python3 plans/fidelity-gate.py snapshot` / `verify` | 语义保护闸——改文件前存快照（编号/约束词/阈值/路径/工具名/代码标识），改后逐项比对 | 0=零丢失；1=检出丢失；2=缺参数/未知模式/无快照 |

`verify-battery.sh` 的参数：`bash plans/verify-battery.sh [预设根]`（默认取脚本上级目录）。
DSH 相关的可选检查由环境变量开启：`DSH_APP_ROOT`（DSH 解包 app 目录）、`DSH_ASAR`（旧版 asar 路径）、`DSH_PROFILE_PATCH`（profile patch 路径，默认 `~/.dsh/profiles/desktop/cordis.patch.yml`）。

## PowerShell 校验（可选）

`preset-score.sh` 与 `verify-battery.sh` 的 PS 语法项需校验器，缺失时**跳过并明确提示**（不判失败）。
启用方式（约 17MB，仅本机工具目录，不随仓库分发）：

```bash
mkdir -p ~/.dsh-codepunk/tools && cd ~/.dsh-codepunk/tools
npm init -y && npm i tree-sitter tree-sitter-powershell
# 校验器本体：plans/fidelity-gate.py 同目录另附 ps-validate.mjs（或用 PWSH_VALIDATOR 指向自备实现）
node ps-validate.mjs <预设根>/plans/windows/*.ps1
```

亦可用环境变量指向自备校验器：`PWSH_VALIDATOR=/path/to/validate.mjs`。

## 目录结构

```text
agent.cordis.yml                    # 组合：persona + 工具 + realm（AGENT-PLANE）
preset.yml                          # 预设描述（roster 展示）
README.md                           # 本说明（向使用者）
CONTRIBUTING.md                     # 贡献指南（向贡献者）
LICENSE                             # MIT
.gitattributes                      # 换行策略（仓库内 LF；.ps1 检出 CRLF）
.gitignore                          # 白名单式忽略（运行状态不入仓）
plans/                              # 工具脚本源副本（运行期正式位见 SKILL.md §1.2）
  dsh-codepunk-home.sh              # 共享路径常量（source 载入；init 会安装到总库根并前置 PATH）
  dsh-codepunk-link.sh              # 项目↔总库关联解析（resolve / index / register）
  dsh-codepunk-init.sh              # 总库骨架幂等初始化
  verify-worktree.sh                # worktree 落点纪律核验
  evidence-verify.sh                # 证据机械校验器（D069：防假通过门 S1）
  acceptance-verify.sh              # 签收机械校验器（D069：结构 + 签收独立性，S2）
  doc-consistency.sh                # 文档声称↔实现一致性（计数/阶段口径/工具存在性/退出码契约）
  checker-self-test.sh              # 检查器存活自检（变异测试：23 项注入缺陷（M1–M23）须被对应守护捕获）
  preset-audit.sh                   # 预设质量审计（5 组 rubric，100 分制）
  dsh-codepunk-leak-guard.sh        # 泄露防护门（D091：推送前守卫，禁词留本地）
  preset-score.sh                   # 15 指标评分器（策略/质量/准确性/规范性/精简度 + 10 项扩展）
  verify-battery.sh                 # 完整验证电池（12 项独立验证，单命令复跑）
  preset-declare.mjs                # preset 声明块生成/校验（emit / check / apply；DSH ≥0.1.7 注册模型）
  preset-compat.py                  # 组合↔DSH 安装兼容核验（插件包 / 配置键 / 隔离形态）
  fidelity-gate.py                  # 语义保护闸（压缩前快照 / 压缩后比对，防语义丢失）
  ps-validate.mjs                   # PowerShell 语法校验器（可选；依赖 tree-sitter，见「PowerShell 校验」节）
  windows/                          # Windows 原生（PowerShell）等价实现
    dsh-codepunk-home.ps1           # 共享路径常量（点源载入）
    dsh-codepunk-init.ps1           # 总库骨架（-Check 只断言）
    dsh-codepunk-link.ps1           # 关联解析（resolve / index / register）
    dsh-codepunk-leak-guard.ps1     # 泄露防护门（-Tree / -History / -InstallHook / -List）
skills/dsh-codepunk-workflow/       # 流程 playbook（skill）
  SKILL.md                          # 流程权威正文（六阶段 + 硬规则 R1–R15 + D 决策号）
  references/                       # 按需参考 ×18 篇（核心：roles/artifacts/knowledge/standard；逐篇见 SKILL §6）
  benchmarks/                       # 基准调研 ×16 篇（决策号来源与实战取证；逐篇清单见 references/learned-skills.md「溯源档案」）
```

用户级总库 `~/.dsh-codepunk/`：`INDEX.yaml`（项目注册表）、`dsh-codepunk-home.sh`（路径常量）、`projects/<id>/`（各项目全部 run 记忆与知识库）。

---

## 维护公约（改动前必读）

- **Host/Agent 平面边界**：服务注册不进本预设；需要 `isolate` realm 的行必须放在带 `isolate:` 的 group 内。改动前对照 `editing-cordis-compositions` skill。
- **逐岗 allow 白名单锚点**：每岗 `toolFilter.allow` 收敛为单一 YAML 锚点 `&role-allow`（调研岗唯一例外，内联追加 `web_search, web_fetch`）。allow 是**全关只放行**列表，未列入的工具一律不可见。新增岗位/工具须同步锚点；allow 只能列当前 DSH 实例已挂载的全局工具名——名字不存在会在 spawn 时随 `tools.restrict()` 直接 throw（fail-closed）。`report` 是延续子代理注册在自身层的汇报工具，不受过滤，**切勿列入 allow**。
- **画布工具权限是机械强制**（restrict 真移除工具）；**文件写集是约定强制**（人设自律 + 审查门 diff ⊆ 写集 + worktree 隔离），不是沙箱。
- **编号可解析**：`Pxx` / `D0xx` 一律以 `references/standard.md` 为唯一释义；禁止引入该文件之外的任何外部编号引用。
- **文件归宿（R13）**：预设自身的资料（开源基准、流程改进）存本预设 `skills/dsh-codepunk-workflow/benchmarks/`，绝不写入任何工程目录；各 run 的 `research/briefs/` 只放该工程业务调研。
- **产出归位复核（R14）**：接收子代理产出时核对内容归属域与实际落位一致；错位立即移出并核销引用，不让漂移文件跨 run 传播。
- **官方版本漂移监控**：DeepSeek Harness 为 developer preview（官方承诺 breaking changes）；每大 run 前 `npm view @deepseek-ai/dsh version` + 扫 GitHub releases，机制变更对照 `benchmarks/deepseek-harness-study.md` §0.0 对齐表。
