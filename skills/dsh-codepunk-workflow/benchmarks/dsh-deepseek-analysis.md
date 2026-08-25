# dsh-deepseek 组件深度分析 + 利用规划输入

> 调研小组（ind-res）简报 · 归属域：预设 meta 调研（benchmarks/）· 交付对象：工程主责（run-lead）
> 检索完成于：2026-08-25T20:50Z（UTC）
> 下文每条结论标注【事实】/【推断】；来源见 §0 清单，URL 附于各条。

---

## 0. 检索窗口与渠道（透明注明）

- **检索窗口**：2026-08-25（UTC），单轮集中调研。
- **渠道与工变更**：`web_search` 工具因 API key 无效**全部失败**（`Authentication Fails`）→ 依任务预案转 **curl 直连**，全部渠道逐条验证 https 200 后取数：
  1. npm registry（`registry.npmjs.org`）：包元数据/dist-tags/依赖 —— 全渠道有效。
  2. GitHub API（`api.github.com`，匿名配额 60/h，实际剩余 51）—— 仓库/目录/releases 有效；**`issues` 与 `search/issues` 均返回空 `[]`**（见 §6）。
  3. GitHub Discussions HTML（`github.com/.../discussions`）—— 列表页有效。
  4. 官方 API 文档 `api-docs.deepseek.com`（`/guides/thinking_mode`、`/quick_start/pricing`）—— 有效（302→200）。
  5. **本地源码**：`git clone --depth 1 https://github.com/deepseek-ai/deepseek-harness.git`（master @ 2026-08-25）到 `/tmp/dsh-repo` 后 grep/read —— 作为源码级一手事实源。注意：本机 DSH Desktop checkout（`app.asar.unpacked`）是 `dsh-plugin-desktop@2.0.2` 外壳（anywhere-labs/deepseek-harness-desktop），**不是**主仓库，仅用于对照外壳组装，未作为组件事实源。
- **来源清单（S1–S10）**，retrieved_at 均为 2026-08-25：
  - S1 [npm @deepseek-ai/dsh-llm-deepseek](https://www.npmjs.com/package/@deepseek-ai/dsh-llm-deepseek) （registry 直查）
  - S2 [npm @deepseek-ai/dsh-llm](https://www.npmjs.com/package/@deepseek-ai/dsh-llm)
  - S3 [npm @deepseek-ai/dsh-llm-pi-ai](https://www.npmjs.com/package/@deepseek-ai/dsh-llm-pi-ai)
  - S4 [npm @deepseek-ai/dsh-base](https://www.npmjs.com/package/@deepseek-ai/dsh-base)
  - S5 [GitHub deepseek-ai/deepseek-harness](https://github.com/deepseek-ai/deepseek-harness)（仓库/README/releases/contents，含 `packages/llm/llm-deepseek` 全部源码）
  - S6 [官方文档 Thinking Mode](https://api-docs.deepseek.com/guides/thinking_mode/)
  - S7 [官方文档 Models & Pricing](https://api-docs.deepseek.com/quick_start/pricing)
  - S8 [官方文档 Configure models（providers 指南）](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/user/guide/providers.md)（本地 clone 读取）
  - S9 [LLM adapter 开发文档](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/user/develop/practice/llm-adapter.md)（本地 clone 读取）
  - S10 [GitHub Discussions 列表](https://github.com/deepseek-ai/deepseek-harness/discussions)

---

## 1. 定位结论（成分分析）

### 1.1 一句话定位

**【事实】** 任务所指「dsh-deepseek」在 npm/GitHub 上**不存在**名为 `@deepseek-ai/dsh-deepseek` 的发布物（registry 404，S1 直查）；其真实对应物是 DeepSeek Harness **LLM seam 的官方直连适配器插件 `@deepseek-ai/dsh-llm-deepseek`**（provider route `deepseek-official`）及其**设计孪生** `@deepseek-ai/dsh-llm-pi-ai`（catalog 内建 `deepseek` 路由）。一句话：**dsh-deepseek = 把 DeepSeek chat-completions API 翻译成 harness StreamChunk 协议的官方提供方适配器（Cordis 插件 + LlmAdapter 实现），dsh 开箱默认模型即由它提供（deepseek-v4-flash）。**

### 1.2 成分逐项清单

| 成分（npm 包） | 版本（dist-tags） | License | 职能（源码 desc / README） |
|---|---|---|---|
| `@deepseek-ai/dsh-llm-deepseek` | latest=0.0.1-rc.1，next=0.1.1-rc.2 | npm 记录 BSD-3-Clause；**master 源码 0.1.1-rc.2 为 MIT**（见 1.4 版本探针） | "DeepSeek chat-completions adapter for the DeepSeek Harness LLM seam"（S1/S5）；直连 fetch+SSE，OpenAI 兼容 wire |
| `@deepseek-ai/dsh-llm` | latest=0.0.1-rc.1 | BSD-3-Clause（S2） | Provider-neutral LLM 服务接口：`LlmRuntime`/`LlmAdapter`/`StreamChunk` 协议/错误税码（S5 `packages/llm/llm/README.md`） |
| `@deepseek-ai/dsh-llm-pi-ai` | latest=0.0.1-rc.1 | —（S3） | pi-ai 库背书的 DeepSeek 适配器（design-verification twin），catalog 路由名 `deepseek`；兼做多厂商/自建网关适配 |
| `@deepseek-ai/dsh-agent-default-model` | latest=0.1.0-rc.6 | —（S3 未单查） | 默认模型选择：`{provider, model, reasoningEffort?}`，settings 段 `agent-default-model`（S5 源码） |
| `@deepseek-ai/dsh`（主 CLI） | latest=0.1.1-rc.2 | MIT | "dsh CLI: profile boot, plugin management, and the browser UI alias"（registry 直查） |
| `@deepseek-ai/dsh-base`（profile bundle） | latest=0.0.1-rc.1，next=0.1.1-rc.2 | —（S4） | 每个 profile 的第一 patch 层，插入 base 插件行；**依赖表含全部 79 个 dsh-* 子包**（含上述四个） |

**【事实】** 组装关系（S4/S5）：主包 `dsh` → `dsh-base`（profile 装配）→ `packages/bundle/base/cordis.patch.yml`（装配清单）→ `llm`、`llm-deepseek`、`llm-pi-ai`（dormant）、`agent-default-model`、`agent-loop` 等。

### 1.3 组件内部构成（llm-deepseek 源码，S5）

- `src/adapter.ts`（666 行）—— `DeepSeekAdapter extends LlmAdapter`，**纯传输层**：fetch + `eventsource-parser` SSE → `StreamChunk`；每次操作经 thunk 重解析连接事实；credential 每个请求解析。
- `src/index.ts`（467 行）—— Cordis 插件契约（`name='llm-deepseek'`，`inject=['llm']`）；provider route 常量 `deepseek-official`；默认模型目录 `DEFAULT_MODELS`；配置 schema；settings 段安装。
- `src/types.ts`（178 行）—— wire 格式（OpenAI 兼容，**source of truth 声明为官方 deepsuite-docs：thinking_mode/tool_calls/create-chat-completion**）。
- `src/serialize.ts`/`translate.ts`/`sse.ts`/`file-store.ts`/`files-api.ts`/`upload-index.ts` —— wire 序列化、chunk 翻译（reasoning/工具调用/usage）、Files API 图像上传。
- `src/index.ts` 中 `DEFAULT_MODELS`（【事实】，S5）：

```ts
deepseek-v4-flash            // text-only，contextWindow: 1,000,000
deepseek-v4-pro              // text-only，contextWindow: 1,000,000
deepseek-v4-flash-vision-exp // text+image，Vision 实验版
```

- **组件默认常量**（【事实】，S5）：`DEFAULT_CONTEXT_WINDOW=1_000_000`、`DEFAULT_MAX_TOKENS=256_000`、`DEFAULT_STREAM_IDLE_TIMEOUT_MS=300_000`、`PUBLIC_BASE_URL='https://api.deepseek.com'`、默认 API key env `DEEPSEEK_API_KEY`。模型目录可自定义（`models:` 列表整体替换，`models: []` 则零广告，未列入目录的 model id **仍可直通**（advisory，非白名单）——【事实+设计注解】。

### 1.4 版本状态探针（【事实】，S1/S5/S7）

- master 最近 release：`dsh-v0.1.1-rc.2`（2026-08-21 发布，`prerelease=true`；此前全为 -rc.x）—— 整个 dsh 处于 **RC 制**。
- npm `dsh-llm-deepseek`：latest tag 停在 `0.0.1-rc.1`，next = `0.1.1-rc.2`；README（master）与 npm latest 存在**细节漂移**（npm license 字段 BSD-3-Clause vs master package.json MIT）→ 【推断】发布管道仍在追赶 master，安装时以 `next` 为准，license 以源码为准。
- 【事实】官方 README 原文：*"DeepSeek Harness is currently in **developer preview** and is iterating rapidly. **THERE WILL BE COMPATIBILITY-BREAKING CHANGES.**"*（S5 root README）。

---

## 2. 能力矩阵（模型接入能力）

### 2.1 官方模型事实（S7）

| 维度 | deepseek-v4-flash | deepseek-v4-pro | deepseek-v4-flash-vision-exp |
|---|---|---|---|
| 模型版本（官方 2026-08 快照） | DeepSeek-V4-Flash-0731 | DeepSeek-V4-Pro-0813 | DeepSeek-V4-Flash-Vision-Exp |
| BASE URL（OpenAI 格式） | `https://api.deepseek.com`（三款一致；Anthropic 格式 `/anthropic`，Responses API 亦支持） |
| Context Length | **1M** | **1M** | **1M** |
| Max Output | **384K** | **384K** | **384K** |
| Thinking Mode | 支持（非 thinking 与 thinking，**默认 thinking**） | 同 | 同 |
| Tool Calls | ✓ | ✓ | ✓ |
| Json Output / Responses API / Anthropic API | ✓ | ✓ | ✓ |
| Chat Prefix Completion（Beta） | ✓ | ✓ | ✓ |
| FIM Completion（Beta） | 仅非 thinking | 仅非 thinking | 不支持 |
| 图片输入 | ✗（文本） | ✗（文本） | ✓（按尺寸折算 token 计入输入） |
| 并发限制（官方） | 2500 | **500** | 2500 |

> 说明：`deepseek-chat` / `deepseek-reasoner` 等旧型号**不在当前官方目录**（S7 无此名；组件默认目录亦无）——【推断】为 V4 时代的旧标签；dsh 适配器因 "model 名即 wire 名、可直通" 设计，旧模型 id 仍可按自定义目录挂载。

### 2.2 官方定价（每 1M tokens，S7，2026-08-25 抓取）

| 项目 | v4-flash | v4-pro | v4-flash-vision-exp |
|---|---|---|---|
| 输入 cache hit，off-peak / peak | $0.007 / $0.014 | $0.022 / $0.044 | $0.007 / $0.014 |
| 输入 cache miss，off-peak / peak | $0.22 / $0.44 | $0.66 / $1.32 | $0.22 / $0.44 |
| 输出，off-peak / peak | $0.66 / $1.32 | $1.98 / $3.96 | $0.66 / $1.32 |

- 【事实】off-peak = peak 一半；**peak 时段**：周一至五 01:00–04:00 与 06:00–10:00 UTC（其余 off-peak）。
- 【推断】pro 全价约为 flash 的 **3 倍**（输入 3×、输出 3×）——角色分模型路由的成本差即在此。

### 2.3 适配器暴露的接入参数（【事实】，S5 index.ts Config + README）

- `apiKeyEnv`（默认 `DEEPSEEK_API_KEY`，经 credentials seam 或环境解析，**配置只存引用不存字面 key**）
- `baseURL`（config > `$DEEPSEEK_BASE_URL`(trusted env) > 公共端点）
- `thinking: 'enabled'|'disabled'`（部署级锁；disabled 时只允许 off effort）
- `reasoningEffort: 'off'|'low'|'high'|'max'`（**默认 high**；适配器暴露四档，官方 wire 三档 low/high/max 加 off→`thinking:{type:'disabled'}`）
- `maxTokens`（默认 256,000，显式请求值优先）、`defaultContextWindow`（1,000,000，未列目录模型回退）
- `models[]`（每模型可配 name/description/contextWindow/maxTokens/inputModalities/image*）
- `retryPolicy`（省略=normal 模式 5 次重试；`mode: normal|always` + backoff：initialDelayMs 500 / maxDelayMs 10000 / jitterRatio 0.1）
- 流控：`streamIdleTimeoutMs`（默认 5 分钟）、Files API 图像上限（128 MiB 请求文件 / 20 MiB 内联 base64 / 每请求 600 图等）

### 2.4 错误码矩阵（【事实】，S5 adapter.ts + README §Errors）

`AUTH`(401/403) / `QUOTA`(余额/配额耗尽识别) / `RATE_LIMIT`(429) / `CONTEXT_WINDOW_EXCEEDED`(400+上下文溢出识别) / `INVALID_REQUEST`(400/413) / `SERVER`(5xx) / `HTTP_<status>` / `TRANSPORT`（DNS/连接/TLS，命名端点）/ `TIMEOUT`（流空闲超时）/ `ABORTED` / `STREAM_CLOSED`（无 [DONE]）/ `MALFORMED_RESPONSE`（坏 JSON）/ `EMPTY_RESPONSE`（stop 无内容，默认重试）/ `UNSUPPORTED_REASONING_EFFORT`（网络 I/O 前拒绝）/ `MISSING_CREDENTIAL`、`INVALID_CREDENTIAL` / `UNKNOWN_MODEL`（pi-ai 侧）/ `DUPLICATE_ADAPTER`（重复注册 deepseek-official 抛错）。错误附带 `Retry-After`、`x-request-id`/`x-deepseek-request-id`。

---

## 3. 与 dsh 集成方式（model adapter seam 全链路）

### 3.1 seam 机制（【事实】，S2/S5/S9）

1. **接口层** `@deepseek-ai/dsh-llm`：`LlmAdapter` 抽象基类（唯一必实现 `stream()`），`ctx.llm`（`LlmRuntime`）注册表 + 单流调用 API。
2. **注册**：`ctx.llm.registerAdapter(['deepseek-official'], adapter)`（provider 独占，all-or-nothing）；`ctx.llm.registerConfigurableProviders([{provider:'deepseek-official', displayName:'DeepSeek', settingsNs:'llm-deepseek', settingsPath:[]}])` 声明可配置目录；事件 `llm/adapters-updated` 通知变更。
3. **流协议** `StreamChunk`：`block-start / text-delta / reasoning-delta / tool-call-delta / block-end / usage / finish`；`BlockAssembler` 组装为消息块（text/reasoning/image/tool-call/tool-result）。
4. **配置/密钥/附件三 seam**：`ctx.settings`（`llm-deepseek:` 段热更新，无需重启）、`ctx.credentials`（key 每次请求解析）、`ctx.attachments`（图像按需解析，缺席则拒绝图像输入）。
5. **新适配器**：子类化 `LlmAdapter` 即插即用（S9 教程 + 两个参考实现 llm-deepseek / llm-pi-ai）。

### 3.2 默认 profile 中的装配（【事实】，S5 `packages/bundle/base/cordis.patch.yml`）

```yaml
- id: agent-default-model
  config: { provider: deepseek-official, model: deepseek-v4-flash }   # 开箱默认模型
- id: llm-pi-ai                                                       # dormant：零路由挂载
- id: llm-deepseek                                                    # 无内联 config，全走 settings
- id: agent-loop
  config: { agents: [] }                                              # agent 由 profile/Web 注入
```

- 【事实】开箱即用路径 = **deepseek-official / deepseek-v4-flash**；Models 页（Settings→Models）写 `llm-pi-ai:` 设置段时 pi-ai 才激活多 provider（S8）。两 DeepSeek 路径可并存（route 名刻意区分：`deepseek-official` vs pi-ai catalog `deepseek`）。
- 【事实】示例（S9）：agent-loop 的 agent 可显式指定 `provider` + `model` —— `agents: [{id: main, provider: my-provider, model: my-model-v1}]`。→ **这是多智能体分模型路由的官方挂点**。

### 3.3 模型选择链（【事实】，S5）

`agent-default-model`（settings 段 `agent-default-model`，Web 模型选择器写入，`saveSelection()`）→ Agent 未显式指定时的默认 → AgentOptions（provider/model/maxTokens/reasoningEffort）→ `GenerateOptions` → `llm/stream`。会话一旦发过请求即锁定该会话自己的模型（S8）。

---

## 4. thinking 边界（机制 + 已知交互问题）

### 4.1 官方规则（【事实】，S6）

- thinking **默认启用**，默认 effort = **high**。
- 请求参数：顶层 `{"thinking":{"type":"enabled|disabled"}}` + `{"reasoning_effort":"low|high|max"}`（OpenAI 格式；Anthropic/Responses 格式并列存在）。
- effort 请求值→实际映射（v4-flash/v4-pro 一致）：`low→low`、`medium→high`、`high→high`、`xhigh→high`、`max→max`。
- **thinking 模式下 `temperature`/`top_p`/`presence_penalty`/`frequency_penalty` 不支持**（设置不报错但静默无效）→ 对依赖 temperature 调参的 agent 编排有含义。
- CoT 通过 `reasoning_content` 与 `content` 平级返回。
- **passback 规则（对工具型 agent 关键）**：
  - 无 `tools` 参数的多轮：中间 assistant 的 `reasoning_content` **不必**参与拼接（传了也被忽略）。
  - **带 `tools` 参数的多轮：`reasoning_content` 必须参与拼接并回传所有后续轮——哪怕该轮没做 tool call，否则 API 返回 400**。

### 4.2 适配器实现（【事实】，S5）

- 适配器 wire：top-level `thinking`（不在 extra_body）、`reasoning_effort`；`off` 序列化为 `thinking:{type:'disabled'}` 且**从不**发 `reasoning_effort:'off'`；`low/high/max` 原样序列化。
- 首个 thinking chunk 的 `reasoning_content:""` 被处理（不产生空 reasoning block）。
- **passback 实现为超配遵守**：每个携带 reasoning 的 assistant 轮都**逐字回传** `reasoning_content`（README：*"reasoning passback carries every reasoned turn's chain of thought into later requests"*）——无 400 风险（覆盖官方带 tools 的强要求），代价是每条 reasoning 都进后续输入（token 与 KV cache 影响，见 §4.4）。
- harness 呈现：`reasoning` content block + `reasoning-delta` chunk；usage 中 `reasoning_tokens`（`completion_tokens_details`）单列。
- `thinking:{type:'disabled'}` 为部署锁：配置非 off 的 effort 直接加载失败；`purpose:'session-title'` 请求强制 thinking off（标题生成预算留给可见文本）。
- 不支持的值在**网络 I/O 前**抛 `UNSUPPORTED_REASONING_EFFORT`。

### 4.3 与子代理（subagent）的交互（【事实】+【推断】，S5）

- 【事实】in-process 子代理（`subagent`/`child-agent.ts`）：child 的 AgentOptions **默认继承父 agent 的 provider/model/maxTokens**（`parent.options.provider/model` 透传），`agentOptions` 可显式覆盖（`continuation.ts: agentProvider = request.agentOptions?.provider ?? parent.options.provider`）。
- 【事实】子代理另有独立维度：`ctx.subagents.registerProvider()` 的 provider 体系（spawn/fork in-process、ACP 进程外、Claude Code/Codex 一次性 profile 驱动）——不由 ctx.llm 模型路由承载。
- 【推断】deepseek 母模型下，工具型子代理每轮带 tools → 全量 reasoning passback → 子代理多轮会话的 reasoning token 会随轮次持续放大输入（成本/延迟双敏感点），dsh-codepunk 巡检/研究岗长轮次会话应评估 thinking effort 档位与 `maxTokens` 预算。此点列入待验证 §7。

### 4.4 KV cache 与成本交互（【事实】，S5 README §Model Experience）

- 缓存命中与否由**前缀稳定性**决定：扩 prefix、模型路由变更、prompt/schema/历史/图片预算变化都从第一个变更 token 起失效；**reasoning passback 逐轮追加天然打破部分前缀**。
- cache hit 输入价比 cache miss 便宜约 30 倍（flash：$0.007 vs $0.22）→ 长会话缓存命中率是成本主杠杆。

---

## 5. 对 dsh-codepunk 的价值点（含子代理模型路由 / 评测 / 成本）

1. **子代理分模型路由的官方挂点已确认**：agent-loop 每 agent 可配 provider/model（S9），in-process 子代理默认继承父模型、可被 agentOptions 覆盖（S5）→ **规划阶段即可差异化**：sdet/巡检/规划用 deepseek-v4-pro（重推理，3× 价），engineer/会话标题用 v4-flash（低成本），vision 岗位用 vision-exp。
2. **成本工程三杠杆**：①型号差（pro:flash = 3:1，§2.2）；②thinking effort 按角色配（低价值岗 `off`/`low`，深挖岗 `max`——官方映射 high 档实际已到 xhigh，域内档位足够）；③**错峰调度**：peak 1.5h×2/工作日（01:00–04:00、06:00–10:00 UTC），批量/重跑任务可放 off-peak，价格直接减半。
3. **token 计量与评测可归因**：usage 三通道可编程读取——`prompt_tokens` 拆分 cache hit/miss（缓存命中率可观测）、`completion_tokens`、`reasoning_tokens` 单列（思维开销可单独核算）→ 评分公式/成本报告可量化"思考强度 vs 产出"。
4. **错误语义可编程（巡检/重试友好）**：稳定错误码 + `Retry-After` + request id → 巡检灯/结算通知可按 `RATE_LIMIT`/`QUOTA`/`CONTEXT_WINDOW_EXCEEDED` 分流处置，而不是吞掉重试；`x-deepseek-harness-compact` 头可把 compaction 流量与会话流量分开统计。
5. **1M context 支撑长会话多智能体**：组件默认 `defaultContextWindow=1M` + 官方 Max Output 384K → 长故事板/交接包/知识库上下文在一窗内可行；但注意组件不主动 clamp，部署需自配 `maxTokens` 匹配（§6）。
6. **双路径防锁定与降级**：`deepseek-official`（官方直连）+ pi-ai dormant（custom provider / 自建网关 / 多厂商）并存——官方断供或限流时切 pi-ai 网关不改 harness 语义；provider 名不可变（S8），切换走"新增→删除"而非改名。
7. **thinking 默认开=质量默认项**：官方默认 enabled/high，dsh 默认 effort high 且 thinking 是部署级配置——流程默认即深思考，一致性风险更低；需要快响应（如标题/轻量巡检）用 `purpose`/effort 显式降档（session-title 已强制 off）。
8. **评测/验收的稳定性来源**：`DeepSeekAdapter` 是 harness "first real LlmAdapter"，SSE 翻译与错误分类有完整 e2e 测试（`tests/`：adapter.spec/e2e、sse、files-api、translate）→ 模型侧行为回归风险低于生态第三方组件。

---

## 6. 限制与风险

- **【事实·高风险】developer preview**：官方明示 "THERE WILL BE COMPATIBILITY-BREAKING CHANGES"（S5）；release 全为 -rc.x；npm latest tag 落后 next（0.0.1-rc.1 vs 0.1.1-rc.2）且 license 元数据与源码漂移（BSD-3-Clause vs MIT）→ 依赖锁定 + 升级演练应成为流程常态。
- **【事实】GitHub Issues 为空**（API 返回 `[]`，S10 列表无 bug tracker 讨论）→ 已知问题只能信 README 的 Known Limitations 清单；社区反馈分散在 Discussions（有 thinking 相关插件帖如 "SuperBrain — Ultra thinking level for DeepSeek V4" #2867）。
- **【事实】官方明示限制（llm-deepseek README §Known Limitations）**：
  - `tool_choice` 未映射（MVP cut，与 pi-ai 孪生一致）；
  - raw `fetch`（无共享 HTTP 代理/拦截配置，TODO 注释在源码）；
  - 插件新增 content block 类型会被跳过（空 tool 输出以字面 `(no output)` 过线）；
  - 图片仅**输入侧 durable attachment**，外部 URL/assistant 图像输出不支持；
  - settings `models` 列表**整体替换** composition 列表（无按 key 合并）。
- **【事实】组件不 clamp context**：`maxTokens` 不自动对 `contextWindow` 收敛，部署必须自配兼容上限（README §maxTokens）。
- **【事实】thinking 模式采样参数失效**：temperature/top_p 等设置静默无效（S6）→ 若 dsh-codepunk 曾计划用 temperature 控制发散度，此路在 thinking 模式下不通。
- **【推断·中风险】**：pro 并发上限 500 且为多组并行主选时，峰值队可能与官方 Rate Limit 政策交互；错峰/重试策略（默认 5 次）需在真实负载下验证。
- **【推断】**：全量 reasoning passback（超配遵守）在长工具链会话中放大输入 token——成本与 cache 命中率双刃剑，需实测（§7）。

---

## 7. 待验证项（本简报未闭合，供工程主责派单或后续轮验证）

1. **agentOptions 覆盖的模型面精度**：tool-subagent 提示词/工件中配置 exact 字段名与作用域（agent-level vs run-level），确认 dsh-codepunk 三席分模型的可达性。
2. **reasoning passback 对 KV cache 的实际影响**：在长会话（≥50 轮工具型）实测 cache hit 率与输入 token 增长率，量化"thinking on 子代理"成本。
3. **pro 500 并发限制下的多组并行**：≤3 组（M 规模）并行是否触发 429，retryPolicy 默认参数是否足够。
4. **1M context 的真实承载**：全量历史 + reasoning passback + 工具结果下上下文水位与 `CONTEXT_WINDOW_EXCEEDED` 触发率；组件默认 1M 上限与官方一致但无 clamp。
5. **off-peak 错峰收益实测**：同工单在 peak/off-peak 双跑的成本差核对（官方声明 2×，需实际账单验证）。
6. **npm 安装态核对**：`npm i @deepseek-ai/dsh-llm-deepseek@next` 的 license/版本落点（npm latest 与源码漂移的收敛方向）。
7. **vision-exp 在流程内的可用场景**：若 dsh-codepunk 需要 UI/图表验收，验证 Files API 上传路径 + 图像 token 折算在真实会话中的表现。

---

## 附：方法与边界声明

- 本简报全部结论来自 S1–S10 一手源；`web_search` 不可用已在上文透明注明（§0）。
- 【推断】条目均标注理由；未做任何代码运行验证（仅静态阅读 master @ 2026-08-25），测试行为断言均源自仓库自带 spec/e2e 存在性，非本组执行结果。
- 未外泄任何未授权信息；本简报只交付工程主责审核，不下发实现组。