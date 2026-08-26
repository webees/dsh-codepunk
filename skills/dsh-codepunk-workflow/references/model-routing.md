# 角色分模型路由选型表（references/model-routing.md）

> dsh-deepseek（官方 `dsh-llm-deepseek` 适配器）能力落地方案。
> **用户决策（D080，2026-08-26）**：**全岗位只允许 `deepseek-v4-flash`，禁 pro**——agent.cordis.yml 已统一接线；pro 仅保留于调研记录，不作为任何岗位模型。**接入方式已源码实证**：`dsh-tool-subagent` Config schema 支持 `agentOptions: { provider, model, maxTokens }`（每岗可配）；子代理默认继承父模型、可被 agentOptions 显式覆盖（`dsh-subagent/lib/index.js:780-781`）。溯源：`benchmarks/dsh-deepseek-analysis.md`（10 一手来源）+ 本地源码核对（2026-08-26）。

## 一、岗位 × 模型路由表

| 岗位 | 建议模型 | thinking effort | 理由（成本/质量杠杆） |
|---|---|---|---|
| **sdet（验收）** | deepseek-v4-flash | 默认 | 统一 flash（用户决策，见下） |
| **squad-lead（调度）** | v4-flash | low | 巡检/汇报是信息整理，低档足够；省 token |
| **engineer（实现）** | v4-flash | low | 写集实现以执行验证为准（D077 Iron Law），thinking 非主杠杆 |
| **proc-audit（审计）** | v4-flash | 默认 | 统一 flash（用户决策） |
| **docs / research / people / product / sys-arch / code-review / release-eng** | v4-flash（默认继承） | 默认 | 职能岗以流程与文件为核心，flash 足够；深挖场景临时覆盖 |
| **vision 岗（若引入）** | v4-flash-vision-exp | 默认 | 仅该型号支持图像输入（Files API durable attachment） |

> 实施姿态：统一 flash（用户决策），agentOptions 显式声明 provider/model，不依赖隐式继承（D076 显式优于隐式）。**provider/model 名经 agentOptions 显式声明**，不依赖隐式继承（D076 显式优于隐式）。

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