# 维护与巡检

本文面向**长期维护者与运营者**：日常巡检节奏、禁词表与泄露防护、镜像与模式归一、门禁复跑时机、升级后的兼容核验。

## 1. 巡检节奏

| 时机 | 动作 | 产物 |
|---|---|---|
| 进程启动（新会话/恢复会话） | 启动自检：`list_agents(scope=descendants)` 列实测态 → 对照登记表找中断席 → 读断点续行 | 运行根 `README.md` 登记表、`agents.yaml` |
| 运行中每 5 轮 | 定时巡检：同一「查 → 比 → 续 → 写」闭环 | `agents.yaml` 刷新 |
| 收到失败 / 中断结算通知 | 加跑一次巡检 | 同上 |
| 每次交接前 | 交接材料齐全性 + 证据新鲜度 + diff 写集核验 | `handoff/`、`evidence.yaml` |
| 每次合并前 | 写盘纪律门 + 证据门 + 审查门 + 合并门留痕 | `approvals/merge.yaml` |
| 每月 | 技能复检：检测外部源变化、评审升级、维护技能档案 | 升级评估 + `benchmarks/` 更新 |

### 1.1 巡检闭环（MUST）

1. **查**：`list_agents` 取实测态（工具语义：一次性子代理不列出；`scope` 仅 `children` / `descendants`；深度大于 1 的条目只接受 `interrupt_agent`）。
2. **比**：与运行根 `README.md` 的 spawn 登记表、`agents.yaml` 清单逐行对照，找出 `expected: active` 但已非 running 的中断席。
3. **续**：读该席工作房的 `progress/`、`handoff/`、`evidence.yaml` 定位断点，`send_message` 精确续行——不重跑整轮、不重复 spawn。
4. **写**：写回 `agents.yaml` 的 `status` / `last_seen` / `last_checkpoint_at` / `note`，并刷新 `updated_at`；`status: done` 的席跳过。

> 硬规则 R12：结算通知是**事件提醒**，可滞后于实况。巡检与交接前 MUST 以交付目录 mtime、证据落盘时刻、`git` 实况复核，不得据通知断言当前状态。

## 2. 禁词表与泄露防护

### 2.1 禁词表（本地维护，不进仓）

| # | 来源 | 优先级 |
|---|---|---|
| 1 | 环境变量 `DSH_CODEPUNK_DENYLIST`（分隔符 `:` `,` 空格或换行） | 最高 |
| 2 | `~/.dsh-codepunk/denylist.txt`（每行一词，`#` 开头为注释） | 次之 |
| 3 | 仓库内自建 `.leak-denylist`（仅当已确认内容可公开） | 最低 |

维护要点：**禁词只改本地文件，不改仓库脚本**——守卫自身若含私人词，它自己就是泄露源。仓库内只保留**通用模式**（绝对路径、私网地址、凭据形态、邮箱）。新增私人词后，`bash plans/dsh-codepunk-leak-guard.sh --list` 可脱敏查看已载入的禁词。

### 2.2 泄露防护门三模式与三钩子

| 用法 | 扫描对象 | 适用 |
|---|---|---|
| `bash plans/dsh-codepunk-leak-guard.sh`（≡ `--staged`） | `git diff --cached` 索引 | pre-commit |
| `bash plans/dsh-codepunk-leak-guard.sh --tree` | 工作树全部**跟踪**文件 | 提交前全量复查 |
| `bash plans/dsh-codepunk-leak-guard.sh --history` | 近 20 提交的提交信息与新增行 | pre-push |
| `bash plans/dsh-codepunk-leak-guard.sh --msg <file>` | 指定提交信息文件 | commit-msg |
| `bash plans/dsh-codepunk-leak-guard.sh --install-hook` | 安装 pre-commit / pre-push / commit-msg 三钩子 | 一次性 |
| `bash plans/dsh-codepunk-leak-guard.sh --list` | 只打印已载入禁词（脱敏） | 排障 |

退出码 0 通过 / 1 命中阻断 / 2 用法或环境错误。用 `--no-verify` 绕过须留痕说明。

> 事故背景：`git push --force` 只移动分支指针，服务端旧对象仍可能经公开接口枚举 SHA 后直链读取——唯一可靠补救是删库重建。故泄露门须在**推送前**拦截，而非事后补救。

## 3. 镜像与模式归一

| 项 | 规则 | 校验命令 |
|---|---|---|
| 脚本镜像 | 仓内 `plans/*.{sh,py,mjs}` 与 `plans/windows/*.ps1` → 总库正式位 `~/.dsh-codepunk/scripts/` | `bash plans/dsh-codepunk-init.sh --check` |
| 模式归一 | 总库脚本模式统一 **755**（可执行 + 可读）；内容一致但模式漂移时同样修正 | 同上 |
| 文档模式 | 仓库内 `.md` 用 **644**（不可执行） | `ls -l docs/ README.md` |
| 声明副本 | profile patch 内联副本由源生成，勿手改 | `node plans/preset-declare.mjs check` |
| 工作树 | 合并完成后回收：确认已并入主干且无未提交独有改动 → `git worktree remove --force` → `git worktree prune`（破坏性操作，前置未满足不得强删） | `git worktree list` |

模式归一的动因：源文件模式若为 644，`chmod +x` 分支永不触及，会让总库脚本不可执行而 init 仍报成功；故改为**按规范模式 755 归一**（仅与 755 不同才改，保持幂等）。

## 4. 门禁复跑时机与耗时

| 场景 | 复跑对象 | 参考耗时 |
|---|---|---|
| 改任意文档 | `bash plans/doc-consistency.sh` | 秒级 |
| 改检查项 / 变异 | `bash plans/checker-self-test.sh` | 约 350 s 量级 |
| 提交前 | `bash plans/dsh-codepunk-leak-guard.sh --history` | 秒级 |
| 改脚本 / 组合 | `bash plans/verify-battery.sh`（含全部子检） | 约 245 s 量级 |
| DSH 升级后 | `python3 plans/preset-compat.py` + `node plans/preset-declare.mjs check` + 电池 | 见上 |

> 耗时数字是**参考量级**（随机器与负载浮动），本仓未把它写进任何判据或阈值；不得据其做超时断言。重型扫描易在负载峰值下超时，宜先自评成本、只跑一次并缓存结果，或改后台作业运行。

## 5. DSH 升级后的维护动作

1. **取版本**：应用版本 `plutil -extract CFBundleShortVersionString raw "<DSH 应用包>/Contents/Info.plist"`；CLI / 包版本 `dsh --version`（两套编号互不推断）。
2. **设环境变量**：`DSH_APP_ROOT`（解包 app 目录）/ `DSH_ASAR`（旧 asar 布局）/ `DSH_PROFILE_PATCH`（profile patch 路径）。本仓不硬编码任何平台路径。
3. **兼容核验**：`python3 plans/preset-compat.py` 的七项检查须全通过（含锚点顺序与 allow 名单一致性）。
4. **验声明漂移**：`node plans/preset-declare.mjs check`；漂移即 `apply` 重写副本。
5. **跑电池**：`bash plans/verify-battery.sh`，重点看 DSH 兼容性与结构项。
6. **对照变更表**：`references/harness-alignment.md`（已适配项与两套布局）；机制级变更对照 `benchmarks/deepseek-harness-study.md` 对齐表。
7. **重启生效**：插件配置在进程启动时读取，改配置后须重启 DSH Desktop（新开对话不重读）。

## 6. 知识库与记忆维护

| 层级 | 内容 | 过期处置 |
|---|---|---|
| L0 热 | 常驻速记与指针 | 失效即改指针 |
| L1 工作 | 本 run 的阶段产物与结论 | run 收官后抽经验、异步下沉 |
| L2 参考 | 跨 run 知识与档案 | 三态流转：`active` → `stale` → `archived`（已废弃归档） |

- 入库存前**先质检**：来源与 TTL 须标注；条目应自包含并带 refs 互链；不合格条目挡下不入库，不得以「先存后补」方式污染知识库。
- 记忆写入须做 canary 与不可见文本检测（防通过隐藏文本注入）。
- 文档小组维护 `knowledge/handoffs/` 归档与 `knowledge/prompts/` 提示词优化留痕。

## 7. 依赖更新与 PR 自动化

| 项 | 现状 | 说明 |
|---|---|---|
| 更新来源 | Dependabot（`.github/dependabot.yml`） | 每周一巡检 `github-actions` 生态；**只声明仓库真实存在的生态**——仓库无任何 pip 清单（`plans/*.py` 仅用标准库），故不声明 `pip`：声明而无对应清单的条目恒不产出 PR，属静默空转（`doc-consistency.sh` 第 7 类机械核验「声明 ↔ 清单」） |
| 依赖 PR 标签 | `labels: [dependencies]` | 由 `plans/github-setup.sh` 幂等创建（与 `automerge` 同一模式）：标签不存在时该字段静默失效，故治理脚本须覆盖 `dependabot.yml` 引用的每个标签（`doc-consistency.sh` 第 7 类机械核验） |
| 分组策略 | minor/patch 归组为单个 PR；major 单独成 PR | 降噪，同时让破坏性变更逐个可评 |
| 自动合并 | 已启用（`.github/workflows/dependabot-auto-merge.yml`） | 触发事件含 `opened`/`synchronize`/`reopened`/`ready_for_review`/`labeled`；条件＝PR 作者为 `dependabot[bot]`，**或** PR 带 `automerge` 标签（该标签由 `plans/github-setup.sh` 幂等创建，仓库设置 `allow_auto_merge=true` 同由其治理） |
| 合并口径 | 仅 `--merge`（合并提交） | 与仓库设置一致（squash / rebase 已关闭，main 受 ruleset 保护） |
| 生效前提 | 4 项必需检查全绿（strict）：门禁回归 / 存活自检 / 跨平台可移植 / 文档一致性 | 检查名由 `.github/workflows/ci.yml` 各作业的 `name` 定义，须与 `plans/github-setup.sh` 的 `CHECK_CONTEXTS` 逐字一致；ruleset 按上下文名匹配，**改名会让该检查永不出现、PR 永久阻塞**（`doc-consistency.sh` 第 7 类机械守护）。基线变化时 GitHub 先更新分支并重跑检查，再自动合并 |
| 两条路径 | ① `mergeStateStatus=CLEAN` ⇒ 工作流直接合并；② 否则武装自动合并 | 实测：对已 clean 的 PR 调 `enablePullRequestAutoMerge` 会被 GitHub 拒绝（`Pull request is in clean status`）；武装成功后若立即可合并，GitHub 会当场合并而 `autoMergeRequest` 变 null ⇒ 自证判据取「已武装 **或** 已合并」 |

- 存活自检的**覆盖**：CI 环境无产品安装、也不设 `DSH_APP_ROOT` ⇒ 依赖产品安装的变异族（声明副本比对、`-h` 用法探针等）自动**跳过**；结论行据实报「捕获 N/M 项 + 跳过 K 项（跳过 ≠ 通过）」，不会把跳过说成通过（F374）。本地设 `DSH_APP_ROOT` 后复跑可获得完整覆盖。
- 人工介入点：需要评估的 major 变更——去掉 `automerge` 标签或直接关闭 PR 即可阻止自动合并；已武装的自动合并可用 `gh pr merge --disable-auto <PR>` 撤回。
- 自动化工作流用 `pull_request_target` 触发（基线上下文、可写令牌），**不检出、不执行 PR 内容**，因此不引入代码注入面；这是 Dependabot 触发的 `pull_request` 工作流只有只读令牌所必需的写法。

## 8. 故障处置速查

| 现象 | 首查 | 处置 |
|---|---|---|
| 门禁红且不在自己改动范围 | `git status` / `git diff --name-only` | 定位归属并交回对应席，不代改 |
| 某项报「无法核验」 | 缺运行时或依赖 | 补环境后重跑；不得当作通过 |
| 总库脚本行为与仓内不一致 | 镜像未同步 | 跑 `bash plans/dsh-codepunk-init.sh` |
| 工作树残留 | `git worktree list` | 按回收流程清理（先验已并入主干） |
| 临时目录残留 | `bash plans/write-scope-check.sh --tmp` | 清理本契约命名空间产物；他项走豁免登记 |
| 提交被泄露门拦截 | 列出命中行（脱敏） | 改内容或登记豁免；绕过须留痕 |
| 子代理失联 | `list_agents` | 按巡检闭环定位断点续行 |

相关文档：[architecture.md](architecture.md)（架构与门禁体系）· [development.md](development.md)（开发与计数同步）· [deployment.md](deployment.md)（部署与安装）· [documentation-policy.md](documentation-policy.md)（文档规范）
