# 预设工具修正台账（meta · 只放预设/流程自身的缺陷与修复）

> 支撑决策号：D090（F-004 双要件实证来源）· 性质：缺陷修复台账（F-xxx 编号），非决策号调研，不占 D 系列；供 D083 月度复检引用。
> 归属域：本文件属**预设/流程自身**资料（R13），不得出现在任何工程的 run 目录里。
> 工程业务取证请写各自 `projects/<id>/runs/<run>/research/briefs/`。

## F-001 · dsh-codepunk-link register 把工程目录写成总库路径

- 症状：`register -y <工程根> <id>` 追加的条目写 `dsh-codepunk_path: <工程根>`；
  随后 `resolve <工程根>` 返回的 `dsh-codepunk_path` 即工程目录本身。
- 危害：违反 D072（总库语义）。run-lead 若照返回值建运行根，会把 goal/chunks/handoff/评分台账
  **全部写进工程目录**，正是该决策要防的工程污染；且 `index` 校验对这类条目判 `缺 dsh_codepunk_path`
  （字段名连字符 vs 下划线不一致，调用方 `_entry_get "$row" dsh_codepunk_path` 读不到）。
- 根因（两处）：
  1. `cmd_register` 的字段名用 `dsh-codepunk_path`（连字符），而 `cmd_resolve`/`cmd_index` 的调用方
     按 `dsh_codepunk_path`（下划线）取值 → 读写两侧拼写不统一；
  2. 旧注释「`dsh-codepunk_path` 默认 = project_root」是与 D072 冲突的历史裁决。
- 修复（正式位 `~/.dsh-codepunk/scripts/dsh-codepunk-link.sh`，已同步预设源副本 `plans/`）：
  1. `_entry_get`：`dsh_codepunk_path` / `dsh-codepunk_path` / `dsh-codepunk` 三种拼写互为回退（读旧条目不炸）；
  2. `cmd_register`：改写 `dsh_codepunk_path: $DSH_CODEPUNK_HOME/projects/<id>`，并 `mkdir -p` 该总库目录。
- 验证（隔离环境，不污染真实 INDEX）：临时 `DSH_CODEPUNK_HOME` + 骨架 INDEX →
  `register -y` → 条目字段为总库路径、目录真实存在、`resolve` 返回总库路径、`index` 判 `1 ok, 0 fail`。
- 遗留建议（未做，需 sponsor 决策）：`index` 校验宜加硬规则——
  `dsh_codepunk_path` 必须以 `$DSH_CODEPUNK_HOME/projects/` 开头，否则判 FAIL，
  否则同类污染会静默通过；历史条目的错误路径由各自 run 的 run-lead 归位。

## F-002 · 全岗位子代理起不来：provider 目录的型号命名与上游不一致

- 症状：多个岗位子代理与通用 `subagent` 一律 `Error: subagent run failed`；
  harness 内部上下文持续重试并报
  `Model '<裸名>' is not available. Supported models: <带前缀的型号名列表>`。
- 根因链（逐环实测，非推断）：
  1. `settings.yaml` 的 `llm-deepseek.baseURL` 指向一个**本地代理端点**；
  2. 该端点由本地代理进程监听；
  3. 该端点的 `/models` 只返回**带前缀**的型号名，且其中目标型号 `available: false`（上游区域限制）；
  4. 而 `llm-deepseek.models` 与预设 agentOptions 用的是**裸名** → 上游直接拒。
     ⇒ 改型号名为前缀也救不回来（上游区域限制），**必须换 provider**。
- 已做修复（预设侧）：各派遣岗位显式声明 `provider` + `model`（决策 D087/D090，
  细则见 `references/model-routing.md`）。外部后端（codex / claude-code）刻意未动。
- **生效障碍（重要）**：预设 `agentOptions` 在插件注册期解析并烘进子会话；
  实测三条证据——① 改完文件后新 spawn 的探针仍报旧模型；
  ② 子会话 `request/header` 恒为旧路由；
  ③ 直接改会话缓存文件里的 `provider/model` 后**数秒内被运行中进程内存态回写覆盖**。
  ⇒ 已存在的子会话无法在进程内改道；须**新建会话或重启 DSH** 才会加载修好的预设。
- 通用教训：**provider 目录登记的型号名必须与上游实际可用的命名口径一致**，
  否则任何指向该 provider 的 agent 会持续重试空转。

## F-003 · one-shot 子代理被限流打断即整轮报废

- 症状：one-shot 子代理在流控（429）失败后，GUI 记录显示
  「一次性子代理记录 · 不支持后续消息」，且「仅可从已完成轮次的最后一条消息分支」——
  失败轮没有已完成轮可分支 ⇒ **该轮工作不可恢复**，只能重新 spawn、从零取证。
- 影响：评分/取证循环因此重复消耗多轮完整工作。
- 根因：预设部分岗位 `backgroundMode: one-shot`。one-shot 在网关抖动下等于「每轮都可能整轮作废」。
- 修复：全部派遣岗位改 `continuable`（外部后端 provider 保持 `enableRunInBackground: false` 不动）。
- 生效障碍：同 F-002——`backgroundMode` 在插件注册期解析，**须新开对话或重启 DSH** 才生效。
- 未重启前的可用替代：① `workflow` 的 `agent(prompt, {provider, model})` 逐次显式路由；
  ② 通用 `subagent`（本就是 continuable）承担评审轮，失败后可 send_message 续跑。
- 历史 one-shot 记录**无法转为可对话**：其运行时对象已随轮次结束释放，
  且平台只允许从「已完成轮次的最后一条消息」分支。

## F-003 补充 · 跨预设范围（sponsor 追加指令「所有 one-shot 子代理改为可对话」）

- 清点 `~/.dsh/.agent-presets/` 下各预设的 subagent 岗位，仅带岗位的预设需处置。
- 处置：dsh-codepunk 及同类预设的岗位统一改 `continuable`（YAML 校验 + 备份）；
  仅含外部后端的预设无需改。
- **刻意不改**：`provider: codex` / `claude-code` 等外部 CLI 后端（`enableRunInBackground: false`）——
  它们不是 harness 内常驻会话，改 backgroundMode 既无意义也可能破坏后端语义。
- 生效条件：`backgroundMode` / `agentOptions` 均在插件注册期解析 →
  **新开一次对话**即生效；改 `settings.yaml`（模型 / retryPolicy）才需重启 DSH Desktop。

## F-004 · 「删 agentOptions 即继承主模型」被实测否证

- 假设被否证：曾把各岗位 `agentOptions` 全删，假设「子代理继承父模型」。实测否证：
  UI 注入的路由不在 `parent.options` 上，孩子落**产品默认**模型
  （descriptor 实证；`dsh-subagent/lib/index.js:780-781` 的继承链只在父 options 有值时生效）。
- 反证样本：能跑通的子代理，其 `request/header` 与显式声明一致——说明「能跑」来自**显式声明**，不来自继承。
- 修复（D090）：各岗位重新写入 `agentOptions: {provider, model}`，
  与 `backgroundMode: continuable` 并列为**双要件**（YAML 校验通过）。
- 附带事实：`workflow` 的 `agent()` 与 `run_in_background: false` 结构性一次性，
  记录不可续聊、历史不可追溯 ⇒ 需要「可续聊」就必须走 continuable 岗位工具，不能靠 workflow。
