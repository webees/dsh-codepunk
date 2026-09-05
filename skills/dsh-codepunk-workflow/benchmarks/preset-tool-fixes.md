# 预设工具修正台账（meta · 只放预设/流程自身的缺陷与修复）

> 归属域：本文件属**预设/流程自身**资料（R13），不得出现在任何工程的 run 目录里。
> 工程业务取证请写各自 `projects/<id>/runs/<run>/research/briefs/`。
> **性质**：缺陷修复台账（F-xxx 编号），非决策号调研——不占 D 系列，供 D083 月度复检引用。

## F-001 · dsh-codepunk-link register 把工程目录写成总库路径（2026-09-05，sectest-rebuild run 中发现）

- 症状：`register -y <工程根> <id>` 追加的条目写 `dsh-codepunk_path: <工程根>`；
  随后 `resolve <工程根>` 返回的 `dsh-codepunk_path` 即工程目录本身。
- 危害：违反 D072（总库语义）。run-lead 若照返回值建运行根，会把 goal/chunks/handoff/评分台账
  **全部写进工程目录**，正是该决策要防的工程污染；且 `index` 校验对这类条目直接判 `缺dsh-codepunk_path`
  （字段名连字符 vs 下划线不一致，调用方 `_entry_get "$row" dsh_codepunk_path` 读不到）。
- 根因（两处）：
  1. `cmd_register` 的字段名用 `dsh-codepunk_path`（连字符），而 `cmd_resolve`/`cmd_index` 的调用方
     按 `dsh_codepunk_path`（下划线）取值 → 只有骨架注释用连字符，读写两侧拼写不统一；
  2. 旧注释「dsh-codepunk_path 默认 = project_root（夹具/未迁移托管位）」是与 D072 冲突的历史裁决。
- 修复（正式位 `~/.dsh-codepunk/scripts/dsh-codepunk-link.sh`，已同步预设源副本 `plans/`）：
  1. `_entry_get`：`dsh_codepunk_path` / `dsh-codepunk_path` / `dsh-codepunk` 三种拼写互为回退（读旧条目不炸）；
  2. `cmd_register`：改写 `dsh_codepunk_path: $DSH_CODEPUNK_HOME/projects/<id>`，并 `mkdir -p` 该总库目录。
- 验证（隔离环境，不污染真实 INDEX）：临时 `DSH_CODEPUNK_HOME` + 骨架 INDEX →
  `register -y` → 条目字段为总库路径、目录真实存在、`resolve` 返回总库路径、`index` 判 `1 ok, 0 fail`。
- 回归观察：修复后真实 `index` 由 `10 ok, 2 fail` 变 `12 ok, 0 fail`；但 `wcdb-key`、
  `air724ug-fw-extract` 两条**历史条目**的 `dsh-codepunk_path` 仍指向工程目录
  （`/Users/x/Desktop/__GITHUB__/webees@wcdb-key`、`/Users/x/Downloads/其他`），
  因校验只看"路径存在"而显示 ok。**属跨项目数据，本 run 不代改**，留待各自 run 的 run-lead 归位。
- 遗留建议（未做，需 sponsor 决策）：`index` 校验宜加一条硬规则——
  `dsh_codepunk_path` 必须以 `$DSH_CODEPUNK_HOME/projects/` 开头，否则判 FAIL，
  否则同类污染会静默通过。

## F-002 · 全岗位子代理起不来：deepseek-official 路由的上游已停用该裸型号名（2026-09-05，sectest-rebuild run）

- 症状：`subagent_squad_lead/engineer/sdet/proc_audit/code_review` 与通用 `subagent` 一律
  `Error: subagent run failed`；harness 内部上下文（`coordinator`、`skill-catalog`）持续重试并报
  `Model 'deepseek-v4-flash' is not available. Supported models: openai/gpt-5.6-luna,
  upstage/solar-pro4, z-ai/glm-5.3-flash, deepseek/deepseek-v4-flash, mimo/mimo-v2.5`。
- 根因链（逐环实测，非推断）：
  1. `settings.yaml` 的 `llm-deepseek.baseURL = http://127.0.0.1:3457/v1`；
  2. 该端口由 **`/Users/x/.local/bin/freebuff-proxy`**（PID 46237）监听；
  3. `curl http://127.0.0.1:3457/v1/models` 只返回 4 个**带前缀**型号，且
     `deepseek/deepseek-v4-flash` = `available:false, status:region_limited`
     （`mimo/mimo-v2.5` 是唯一 `available:true`）；
  4. 而 `llm-deepseek.models` 与预设 agentOptions 用的都是**裸名** `deepseek-v4-flash` → 上游直接拒。
     ⇒ 改型号名为前缀也救不回来（上游 region_limited），**必须换 provider**。
- 已做修复（预设侧）：`agent.cordis.yml` 全 13 个岗位（含通用 `subagent`/`subagent_fork`）
  显式 `provider: bai` + `model: qwen3.8-flash`（决策 **D087**，细则见 `references/model-routing.md §五`
  与 `references/standard.md`）。`subagent_codex`/`subagent_claude_code` 为外部后端，刻意未动。
- **生效障碍（重要）**：预设 agentOptions 在插件注册期解析并烘进子会话；
  实测三条证据——① 改完文件后新 spawn 的探针仍报 deepseek；
  ② 子会话 `request/header` 恒为 `deepseek-official/deepseek-v4-flash`；
  ③ 直接改 `~/.dsh/storages/session_projcache.json` 里 `contextTimeline.val.{provider,model}`
  后**数秒内被运行中进程的内存态回写覆盖**。
  ⇒ 已存在的子会话无法在进程内改道；须**新建会话或重启 DSH** 才会加载修好的预设。
- 不依赖重启的绕行（已验证可用）：`workflow` 脚本的 `agent(prompt, {provider:'bai', model:'qwen3.8-flash'})`
  支持逐次覆盖路由 → sectest-rebuild 的两轮独立评审（R2、D2）均由此产出，且明细可复核。
- 待办（需 sponsor 决策，本 run 不代改）：
  `llm-deepseek` 与 `freebuff` 两个 provider 目录里的裸名/前缀名不一致，且上游 region_limited——
  要么给 freebuff-proxy 配上游别名与放行区，要么把 `llm-deepseek.baseURL` 指回可用端点；
  否则任何仍指向 `deepseek-official` 的 harness 内部 agent 会持续重试空转。

## F-003 · one-shot 子代理被限流打断即整轮报废（2026-09-05，sectest-rebuild run）

- 症状：`subagent_code_review` 的扣分明细轮（D1 首试、R4 常驻尝试）中途 429 失败后，
  GUI 记录显示「一次性子代理记录 · 一次性任务不支持后续消息」，且「仅可从已完成轮次的最后一条消息分支」——
  失败轮没有已完成轮可分支 ⇒ **该轮工作不可恢复**，只能重新 spawn、从零取证。
- 影响：本 run 的评分循环因此重复消耗 3 次完整取证轮（D1 首试、R3 首试返回 null、R4 一次性）。
- 根因：预设 13 个岗位里 8 个 `backgroundMode: one-shot`（product/research/people/docs/
  proc-audit/sys_arch/code_review/release_eng）。one-shot 在网关抖动（本会话 llm-deepseek 上游
  region_limited + bai 配额）下等于"每轮都可能整轮作废"。
- 修复：`agent.cordis.yml` 全 13 岗位改 `continuable`（`subagent_codex`/`subagent_claude_code`
  为外部后端，保持 `enableRunInBackground: false` 不动）。YAML 已 ruby 校验通过。
- 生效障碍：同 F-002——agentOptions/backgroundMode 在插件注册期解析，**须新开对话或重启 DSH** 才生效。
- 未重启前的可用替代：① `workflow` 的 `agent(prompt, {provider,model})` 逐次显式路由（已验证可跑）；
  ② 通用 `subagent`（本就是 continuable）承担评审轮，失败后可 send_message 续跑。

## F-003 补充 · 跨预设范围（2026-09-05 sponsor 追加指令「所有 one-shot 子代理改为可对话」）

- 全量清点 `~/.dsh/.agent-presets/`（10 个预设）：只有 3 个预设带 subagent 岗位——
  dsh-codepunk 13 岗位、edu-team 11 岗位、standard-zh 4 岗位；其余 7 个预设无子代理岗位。
- 处置：
  - dsh-codepunk：13/13 已 continuable（本轮之前完成），`agentOptions` 已全部移除，子代理继承主进程路由；
  - edu-team：5 个岗位（mentor / expert / journal_editor / stats / peer_reviewer）由 one-shot 改 continuable，
    已 ruby YAML 校验，备份 `/tmp/edu-team.agent.bak`；
  - standard-zh：仅 2 个外部后端，无需改。
- **刻意不改的 4 处**：`subagent_codex` / `subagent_claude_code`（edu-team、standard-zh 各一对）。
  它们是外部 CLI 后端（`provider: codex` / `claude-code`，`enableRunInBackground: false`），
  不是 harness 内常驻会话，改 backgroundMode 既无意义也可能破坏其后端语义。
- 历史 one-shot 记录（会话缓存实测 122 条 one-shot / 5 条 continuable）**无法转为可对话**：
  其运行时对象已随轮次结束释放，且平台只允许从"已完成轮次的最后一条消息"分支；
  其中还含插件自有的 fire-and-forget 维护任务（如 `Mnemon idle checkpoint review`），本就不该可对话。
- 生效条件：`backgroundMode` 与 `agentOptions` 都在插件注册期解析 →
  **新开一次对话**即对 dsh-codepunk 岗位生效；改 `settings.yaml`（模型/retryPolicy）才需要重启 DSH Desktop。
