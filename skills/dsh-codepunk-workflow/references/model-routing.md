# 角色分模型路由选型表（references/model-routing.md）

> dsh-deepseek（官方 `dsh-llm-deepseek` 适配器）能力落地方案。
> **现行决策（D087，2026-09-05 二次修订，sponsor 指令）**：子代理**继承主进程** `bai / qwen3.8-flash`——
> 13 个岗位的 `agentOptions` 已全部删除（实测 `grep -c agentOptions agent.cordis.yml` = 0），不再逐岗写死路由；
> 回退链 bai→deepseek→mtplx，同一路由连续失败 ≥3 次由 run-lead 切换。
> 取代 D080（2026-08-26「全岗位只允许 deepseek-v4-flash，禁 pro」）——D080 的档位纪律（**只用 flash 档，禁 pro/max**）继续有效，
> 换的是 provider 与型号名。沿革与判据见本文 §五。
> **接入方式已源码实证**：`dsh-tool-subagent` Config schema 支持 `agentOptions: { provider, model, maxTokens }`（每岗可配）；
> 子代理默认继承父模型、可被 agentOptions 显式覆盖（`dsh-subagent/lib/index.js:780-781`）。
> 溯源：`benchmarks/dsh-deepseek-analysis.md`（10 一手来源）+ 本地源码核对（2026-08-26）+ sectest-rebuild run 实跑故障（2026-09-05）。

## 一、岗位 × 模型路由表

| 岗位 | 模型路由（D087 二次修订） | thinking effort | 理由（成本/质量杠杆） |
|---|---|---|---|
| **sdet（验收）** | 继承主进程（bai / qwen3.8-flash） | 默认 | 统一 flash 档（档位纪律承自 D080） |
| **squad-lead（调度）** | 继承主进程（bai / qwen3.8-flash） | low | 巡检/汇报是信息整理，低档足够；省 token |
| **engineer（实现）** | 继承主进程（bai / qwen3.8-flash） | low | 写集实现以执行验证为准（D077 Iron Law），thinking 非主杠杆 |
| **proc-audit（审计）** | 继承主进程（bai / qwen3.8-flash） | 默认 | 统一 flash 档 |
| **subagent / subagent_fork（通用）** | 继承主进程（bai / qwen3.8-flash） | 默认 | 显式声明，避免继承路径不确定 |
| **docs / research / people / product / sys-arch / code-review / release-eng** | 继承主进程（bai / qwen3.8-flash） | 默认 | 职能岗以流程与文件为核心，flash 足够；深挖场景临时覆盖 |
| **vision 岗（若引入）** | bai / deepseek-v4-flash-vision-exp | 默认 | 需图像输入时单独接线（尚未启用） |

> 实施姿态（二次修订）：**岗位不写 agentOptions，统一继承主进程路由**。理由：逐岗写死会在网关换 provider 时留下 13 处漂移点，
> 而本次故障恰恰是"写死的路由失效 + 进程不热加载"叠加所致。换模型只需改主会话一处。
> 例外：`subagent_codex` / `subagent_claude_code` 是外部后端（`provider: codex` / `claude-code`，`maxDepth: provider-managed`），
> 不套本表，也不得被改成 bai 路由。

## 二、成本杠杆纪律（D078，基于 dsh-deepseek 定价）

1. **thinking effort 按角色**：低价值/高频岗 `off|low`（巡检/标题/清单），深挖岗 `high|max`（验收/审计/复杂推理）；thinking 下 `temperature/top_p` **静默无效**——不要用采样参数调发散度。
2. **错峰调度**：peak 为工作日 01:00–04:00 与 06:00–10:00 UTC（价 2×）；批量/重跑/大会话放 off-peak 直接减半。执行：`runs/` 定时任务（dsh-schedule）或 run-lead 排程。
3. **KV cache 是主杠杆**：cache-hit 输入价 ≈ 1/30（flash $0.007 vs $0.22/1M）；**prefix 稳定性 > 一切**——避免频繁改 prompt/schema（每次从头失效）；reasoning passback 逐轮追加天然破前缀（长工具链会话留意）。
4. **token 归因可编程**：usage 三通道（prompt hit/miss + completion + `reasoning_tokens` 单列）——评分/成本报告按角色核算「思考强度 vs 产出」。
5. **1M context 不自动 clamp**：适配器校验正数但**不收敛**到 contextWindow；部署自配 `maxTokens`（默认 256k）防溢出（`CONTEXT_WINDOW_EXCEEDED` 有稳定错误码）。

## 三、已知限制（接线时勿踩）

- `tool_choice` 未映射（MVP cut）——不要依赖强制工具选择。
- 图片仅输入侧 durable attachment；外部 URL/assistant 图像输出不支持。
- `models:` 列表**整体替换**（无按 key 合并）；模型 id 未列入目录仍可直通（advisory）。
- developer preview：官方承诺 breaking changes；依赖锁定 + 升级演练常态（README 版本监控联动）。

## 四、待运行验证项（静态已核、运行/账单依赖）

| 项 | 状态 | 验证方案 |
|---|---|---|
| agentOptions 覆盖可达 | ✅ 源码实证（schema + child-agent 继承链） | — |
| reasoning passback 行为 | ✅ 源码实证（reasoning_content 逐字回传） | — |
| maxTokens clamp | ✅ 实证不 clamp（正数校验 + 默认 256k） | — |
| pro 500 并发 vs M 规模并行 | ⏳ 运行依赖 | 3 组并行实跑测 429 触发 + retryPolicy（默认 5 次） |
| off-peak 错峰收益 | ⏳ 账单依赖 | 同工单 peak/off-peak 双跑比对账单 |
| 1M context 真实承载 | ⏳ 运行依赖 | 长会话（≥50 轮工具型）观测水位 + CONTEXT_WINDOW_EXCEEDED 率 |
| vision-exp 流程落地 | ⏳ 场景依赖 | 有 UI/图表验收需求时验证 Files API 路径 |

## 五、决策沿革（为什么换掉 deepseek-official）

| 决策 | 日期 | 内容 | 状态 |
|---|---|---|---|
| D080 | 2026-08-26 | 全岗位 `deepseek-official / deepseek-v4-flash`，禁 pro | **已被 D087 取代**（档位纪律"只用 flash、禁 pro/max"仍有效） |
| D087 | 2026-09-05 | 全岗位 `bai / qwen3.8-flash`，13 个岗位显式接线 | 现行 |

**D087 触发事实**（sectest-rebuild run 实跑取证，非推测）：

1. 三席实现子代理与评审子代理启动即失败，报错
   `Model 'deepseek-v4-flash' is not available. Supported models: openai/gpt-5.6-luna, upstage/solar-pro4,
   z-ai/glm-5.3-flash, deepseek/deepseek-v4-flash, mimo/mimo-v2.5`
   —— 上游已改用**带前缀的型号名**，而 `llm-deepseek` 目录里登记的是裸名 `deepseek-v4-flash`。
2. 该 baseURL 为 `http://127.0.0.1:3457/v1`（本地代理）；同一 baseURL 的 `freebuff` provider
   已按前缀名登记（`deepseek/deepseek-v4-flash` 等），可作旁证。
3. 故障期间子代理会话日志显示每轮 `llm/retry` 16–21 次、**工具调用数 0**，
   却向主会话回报"已落盘/已 commit"——主会话用 `git log`/`reflog`/全盘 `find` 证伪。
   结论：**路由失效会让子代理退化成纯文本幻觉**，比慢更糟，必须显式修路由而非靠继承。
4. 主会话当时正跑在 `bai / qwen3.8-flash` 上且工作正常 → 选它作为全岗位统一路由，
   顺带消除"部分岗位显式、部分继承"的双轨不确定性。

**回滚条件**：若 `deepseek-official` 目录修正（裸名 ↔ 前缀名对齐）且实跑探针通过，
可把 13 处 agentOptions 改回；改回前必须先跑一次最小探针子代理验证，不接受"应该好了"。

## 六、生效条件与失效放大器（D087 落地补录，2026-09-06 实跑取证）

改完 `agent.cordis.yml` 不等于改完就生效。三条必须记住的机理：

1. **工具挂载在会话创建时冻结**（承重）。岗位子代理的 `agentOptions` 随父会话的工具实例一次性解析，
   之后**父会话派生的所有子代理都继承那份旧路由**，与磁盘上的预设文件无关。
   实测：22:50 改完预设 → 00:17 由旧会话（06:48 创建）派生的探针仍报 `deepseek-v4-flash`；
   而 00:30 新建会话派生的探针零错误通过。
   **结论：路由变更后必须新开对话**；旧对话（含其 goal、工作房、子代理）不可救，只能弃用。
   预设发现层本身是热读的（`dsh-agent-presets/discovery` 每次调用重读根目录），**不需要重启 app**。
2. **`retryPolicy.mode: always` 是放大器，不是保险**。`always` 无重试上限、且不区分错误类型
   （`dsh-llm/lib/index.js` 的 `alwaysPolicySchema` 只有 `mode` + `backoff`，没有 `retryableCodes`），
   于是 `INVALID_REQUEST`(400) 这类**永久性错误**会被无限重试：实测单轮 40+ 次、每次 30 秒，
   把一次配置错误放大成整轮死锁。`mode: normal` 才按 `retryableCodes`
   （默认 EMPTY_RESPONSE / RATE_LIMIT / SERVER / TIMEOUT / TRANSPORT）区分可恢复与永久。
   已把 `~/.dsh/settings.yaml` 的 `llm-deepseek.retryPolicy` 改为 `normal / maxRetries: 3 / 500ms→10s`。
3. **目录 id 必须与上游实况一致**。`llm-deepseek.models` 原登记裸名 `deepseek-v4-flash`，
   而 `:3457` 代理只认前缀名 → 已改为 `deepseek/deepseek-v4-flash`；
   上游未提供的 `deepseek-v4-pro` 与 `deepseek-v4-flash-vision-exp` 两条**注释留存**
   （留在目录里等于在模型选择器里埋一颗必炸的按钮）。
   注意 §三 那条"模型 id 未列入目录仍可直通（advisory）"：本地目录**不拦**未知 id，
   请求照发到上游，所以真正的报错来自上游 400，而不是本地校验。

**变更后自检（MUST，2 分钟内可做完）**：新开对话 → 派一个最小探针子代理（只让它 `echo` 一条命令、
明确禁止写文件）→ 探针回报无 `llm/retry` 且工具调用数 ≥1，才算路由真的换过来了。
探针回报"成功"但工作区无变化时，按 D077 反幻觉纪律以 `git log` / 目录 mtime 证伪，不接受叙述。