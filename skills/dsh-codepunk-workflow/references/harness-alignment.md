# 官方机制对齐表（references/harness-alignment.md）

> 本文为 SKILL.md §0.0 的按需展开；SKILL 正文只留一句指引（D074 预算纪律）。

> dsh-codepunk 不发明私有机制：每个流程概念都映射到 DeepSeek Harness 官方 seam。调研溯源：`benchmarks/deepseek-harness-study.md`（40+ 官方来源，2026-08-26）。升级 harness 或排障时先对照本表。

| dsh-codepunk 概念 | 官方机制（包/文档） | 备注 |
|---|---|---|
| goal 自动续行 / 结算自动递送 | `dsh-goal` + `dsh-tool-goal` + `dsh-goal-round-driver`（§0.1） | 词汇 Goal→Round→Turn→Step；armed 进程本地；resume 需人类消息 |
| skill playbook 渐进披露 | `dsh-skill` + `dsh-skill-filesystem` + `dsh-tool-skill` | preset 技能经组合 `skill-filesystem` baseUrl 装载（非目录扫描） |
| subagent 派遣/continuable | `dsh-subagent`（spawn/fork/ACP/codex/claude-code 五后端）+ `dsh-tool-subagent-*` | outputSchema/depthLimit/toolFilter/persona 静态声明 |
| 待迁移候选：team 编排 | `dsh-experimental-agent-team`（持久 mailbox + 任务 DAG blockedBy/writeScopes） | 与三人小组同构；实验性，writeScopes 为建议非锁 |
| 巡检/交接/合并流程固化 | `dsh-workflow`（JS 编排：agent/parallel/pipeline/phase + outputSchema） | 可选固化方案；worker 非安全边界 |
| 上下文纪律（D074） | `dsh-compaction`（pressure/overflow）+ `dsh-session-query-sqlite` + tool-result pruner | 「摘要即证据」官方对应机制 |
| 双门闩/审查门 权利谱系 | `dsh-sandbox`（3 模式阶梯升级）+ `dsh-user-approval`（ask/never，fail-closed） | 流程内审批 ≠ harness approval（两条独立路径） |
| sandbox 升级（危险操作） | bash `sandbox_permissions` + `justification` | 仅被拒时才请求一次批准；授权不持久 |
| report / 结算通知 | `dsh-tool-subagent-report` + `dsh-tool-subagent-control` | 结构化回报；子步骤不进父日志 |
| 后台任务 | `ctx.jobs` + `job_kill/job_list/job_output` | 与后台 bash 同机制 |
| checkpoints（工作区检查点） | 官方快照/断点机制 | D067 断点续行：progress/handoff/evidence 即重放状态，与官方 checkpoints 对齐（简述） |