# 官方机制对齐表（references/harness-alignment.md）

> 本文为 SKILL.md §0（原 §0.0 官方机制对齐 + §0.1 goal 续行）的按需展开；SKILL 正文只留速记与指针（D074 预算纪律）。

> dsh-codepunk 不发明私有机制：每个流程概念都映射到 DeepSeek Harness 官方 seam。调研溯源：`benchmarks/deepseek-harness-study.md`（40+ 官方来源，2026-08-26）。升级 harness 或排障时先对照本表。

| dsh-codepunk 概念 | 官方机制（包/文档） | 备注 |
|---|---|---|
| goal 自动续行 / 结算自动递送 | `dsh-goal` + `dsh-tool-goal` + `dsh-goal-round-driver`（§0.1） | 词汇 Goal→Round→Turn→Step；armed 进程本地；resume 需人类消息 |
| skill playbook 渐进披露 | `dsh-skill` + `dsh-skill-filesystem` + `dsh-tool-skill` | preset 技能经组合 `skill-filesystem` baseUrl 装载（非目录扫描） |
| subagent 派遣/continuable | `dsh-subagent`（spawn/fork/ACP/codex/claude-code 五后端）+ `dsh-tool-subagent-*` | outputSchema/depthLimit/toolFilter/persona 静态声明 |
| 子代理生命周期（可追问 vs 一次性） | `dsh-subagent` 两条 API：`startContinuable()` → `mode: continuable`；`start()` → **写死** `mode: one-shot`（`lib/index.js:2613`） | 三条硬事实：① 岗位工具**后台**派遣才可 `send_message` 追问（预设 13 岗位已全 `backgroundMode: continuable`）；② `workflow` 的 `agent()` 与任何 `run_in_background: false` 调用都走 `start()` → 一次性，**预设改不动**；③ mode 在创建时写进 `subagent/descriptor` 事件落盘，**已存在的一次性记录无法追溯改造**。生效须重启 DSH Desktop（新开对话不重读插件配置）。④ `workflow` 的 `agent()` 亦**不接受 `toolFilter`/`persona`**（该路径无此参数），故其孩子**不经岗位白名单过滤**——只能靠编排脚本自身约束其行为（只读/限定目录），不得把明文授权或密钥注入其 prompt |
| 待迁移候选：team 编排 | `dsh-experimental-agent-team`（持久 mailbox + 任务 DAG blockedBy/writeScopes） | 与三人小组同构；实验性，writeScopes 为建议非锁 |
| 巡检/交接/合并流程固化 | `dsh-workflow`（JS 编排：agent/parallel/pipeline/phase + outputSchema） | 可选固化方案；worker 非安全边界 |
| 上下文纪律（D074） | `dsh-compaction`（pressure/overflow）+ `dsh-session-query-sqlite` + tool-result pruner | 「摘要即证据」官方对应机制 |
| 双门闩/审查门 权利谱系 | `dsh-sandbox`（3 模式阶梯升级）+ `dsh-user-approval`（ask/never，fail-closed） | 流程内审批 ≠ harness approval（两条独立路径） |
| sandbox 升级（危险操作） | bash `sandbox_permissions` + `justification` | 仅被拒时才请求一次批准；授权不持久 |
| report / 结算通知 | `dsh-tool-subagent-report` + `dsh-tool-subagent-control` | 结构化回报；子步骤不进父日志 |
| 后台任务 | `ctx.jobs` + `job_kill/job_list/job_output` | 与后台 bash 同机制 |
| checkpoints（工作区检查点） | 官方快照/断点机制 | D067 断点续行：progress/handoff/evidence 即重放状态，与官方 checkpoints 对齐（简述） |
| 目标命令（人类通道） | `dsh-command-goal`（`/goal` 设置或查看长任务目标） | 与 `dsh-tool-goal`（模型通道）配对；两者注入同一个 `goals` 服务 |
| 交付物声明 | `dsh-tool-present`（`present` 工具：把产出文件标记为最终交付） | 注入 `tools`/`fs`/`sessionProjections`；主会话用它汇总交付 |

## DSH 兼容核验（2.0.17，2026-10）

**2.0.17 三项破坏性变更**（均已适配并实测）：

| 变更 | 实测结论 | 本仓适配 |
|---|---|---|
| 注册表不再扫描预设目录 | `dsh-agent-preset-registry` 的 `definitions` 只由声明方插件 `register()` 填充；`~/.dsh/.agent-presets/<id>/` 既不被扫描，也不接受 preset 路径。旧式目录预设的会话恢复报 `Unknown agent preset: <id>` | 以 `@deepseek-ai/dsh-agent-preset` 声明行注入 profile patch；生成与漂移校验见 `plans/preset-declare.mjs`（`emit`/`check`/`apply`） |
| `app.asar` → 解包 `app/` | 应用改为解包目录 `Contents/Resources/app/`，插件在 `app/node_modules/@deepseek-ai/`；凡指向 `app.asar/...` 的路径失效（实测：2.0.10 仍为 asar，2.0.12 起解包） | 所有依赖安装位置的检查改取环境变量：`DSH_APP_ROOT`（解包目录）/ `DSH_ASAR`（旧布局）/ `DSH_PROFILE_PATCH`；`verify-battery.sh` 两种布局都支持 |
| `dsh-workflow-worker-thread` 并入 | 该包名在 2.0.17 已不存在，保留旧名会让 preset 挂载失败 | 改用 `@deepseek-ai/dsh-workflow-ptc`（`id: workflow-ptc`） |

**组合双表示与漂移风险**：同一份组合存在于两处——`agent.cordis.yml`（源，权威）与 profile patch 内的 `plugins:` 内联副本（进程实读）。副本必须由源生成；唯一必要适配是 `customSkillDirs` 的 `baseUrl` 基准变化（内联后指向 profile 目录，须改写为回到预设目录的相对路径），`preset-declare.mjs` 生成时自动加、`check` 比对时自动归一。

```bash
node plans/preset-declare.mjs check     # 语义比对：漂移即 exit 1 并列出差异路径
node plans/preset-declare.mjs apply     # 用源重写副本（自动备份；首次安装加 --append）
python3 plans/preset-compat.py          # 组合↔DSH 安装兼容核验（需 DSH_APP_ROOT / DSH_ASAR）
```

## DSH 兼容核验（2.0.9，2026-09）

升级 DSH 后按本清单核对（每项都有对应命令，可复跑）：

| 检查项 | 方法 | 2.0.9 结果 |
|---|---|---|
| 插件包名存在 | 逐个在 `app.asar` 内检索 `@deepseek-ai/<pkg>` | ✅ 全部命中 |
| 条目结构合法 | 用 `entryListSchema`（= `js-yaml` JSON_SCHEMA + `!!js` 表达式标签）解析本文件 | ✅ 无缺 id/name |
| config 键受支持 | 取各插件的 `Config` schema 与本文件所用键比对 | ✅ 全部在 schema 内 |
| toolFilter 工具名有效 | 与各插件的工具注册名比对 | ✅ 14 个名字全部有效 |
| group 隔离齐全 | 服务行须落在带 `isolate` realm 的组内 | ✅ planning/compaction/delegation 三组齐 |
| 元数据格式 | `preset.yml` 支持 `name`/`description`/`order`（均可选） | ✅ 三项齐 |
| 官方能力对齐 | 与随包发布的 `presets/standard` 逐行对照 | ✅ 条目数、组、isolate 一致 |

**条目读取方式**（asar 为打包产物，需按头部偏移解包）：

```bash
# 头部：u32@0=4, u32@4=headerSize, u32@8=jsonSize；JSON 从偏移 16 起，文件数据从 8+headerSize 起
# 参考实现见本次核验脚本（读头部 → 括号配平定位 JSON → 按 offset/size 取文件）
```

**2.0.9 相对早期版本的新增能力**（本预设已纳入）：
- `dsh-command-goal`：人类 `/goal` 命令
- `dsh-tool-present`：交付物声明工具
- `dsh-tool-subagent` 新增 `modelSelectionSettings`（子代理模型选择 UI）——**未启用**：它要求 Host 提供 `dsh-tool-subagent/model-selection-settings` 服务，缺失会导致挂载报错；公开预设不宜引入该类硬依赖，部署方按需自开。
- `dsh-persona` 新增 `suffix`/`complete`/`includeRuntimeContext`（均为可选）

## §0.1 展开：goal 自动续行 / 子代理回报自动递送（MUST 理解）

> 本节是 SKILL.md §0.1 的完整详述（L1 按需层）：官方依据、机制逐步说明、依赖组件装配与决策号。SKILL 正文只留速记加指针（D074 预算纪律）。**本节约束与 SKILL 正文同等效力**；开工前或续行排障时按需读取。

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
