# 模型统一与回退机制（references/model-fallback.md）

> D089 完整展开。目的：①全链路（主进程+13 岗位）统一单一模型路由，消除「子代理用 bai、主进程用 deepseek」的模型分裂；②主模型失败时按链回退，不中断流程。
> 背景：harness（dsh-llm/agent-loop）**无原生 provider fallback**——回退须由流程纪律层实现（run-lead 认知 + 工具层重试后切换）。

## 一、模型统一（全链路继承，杜绝分裂）

- **原则**：子代理不声明模型（agent.cordis.yml 无 agentOptions 覆盖），**默认继承主进程模型**（settings `agent-default-model`）。
- **单一事实源**：所有会话/子代理共用 `agent-default-model.provider/model`——改一处即全局生效。
- **当前统一值**：`provider: bai, model: qwen3.8-flash`（sponsor 2026-09-05 指令延续）。
- **为何不自声明**：D087 曾让 13 岗位显式 bai/qwen3.8-flash，造成「子代理 ≠ 主进程」分裂；D089 改回继承——继承即一致，避免多源漂移。

## 二、回退链（三级，按序）

| 级 | provider（settings 名） | 模型 | 探针状态（2026-09-06） | 适用 |
|---|---|---|---|---|
| **主** | bai（api.b.ai） | qwen3.8-flash | ✅ **verified 可用**（ping→pong） | 默认路由 |
| **备 1** | freebuff-proxy（127.0.0.1:3457） | deepseek/deepseek-v4-flash | ❌ 上游日额度耗尽（12h15m 重置，提示换 z-ai/glm-5.3-flash） | bai 失败时优先试 |
| **备 2** | mtplx（本地 127.0.0.1:8000） | mtplx-qwen38-27b-optimized-speed | ✅ **verified 可用**（本地 Qwen3.8 正常） | 云端均失败时（本地兜底，**当前可靠备选**） |
| ~~备 3~~ | llm-deepseek（opencode 网关） | deepseek-v4-flash | ❌ 周额度耗尽（1 天重置） | 暂不可用 |
| ~~备 4~~ | bai | deepseek-v4-flash | ❌ 余额不足（balance=0） | 暂不可用 |

> **探针纪律（优先测已配置模型）**：回退切换前，先跑最小探针验证目标模型可用（见 §五 命令），**只切到 verified 的模型**；本表探针状态每次实测后更新（mark 日期）。

## 三、回退触发与执行（run-lead 纪律）

1. **触发条件**（满足其一，持续 N 次失败且重试无用）：
   - 同一 provider 连续 ≥3 次 `RATE_LIMIT`/`TIMEOUT`/`TRANSPORT`
   - `QUOTA`（额度耗尽）——无限重试（mode: always）已排除瞬时抖动，但仍持续失败
   - 「模型名不存在」类永久错误（但 mode: always 会死循环——**此时主动回退优于空等**）
2. **执行**：
   - run-lead 认知到持续失败 → 手工切换主路由（settings `agent-default-model.provider/model`）到下一位
   - **提示**：settings 修改需重启 DSH Desktop 才对运行中进程生效；会话内子代理继承快照在新对话冻结
   - 记录：回退事件入 `errors/YYYY-MM-DD.md`（时间/原 provider/新 provider/失败码）
3. **回退后**：验证新路由可用（一次小请求），再继续流程。

## 四、与既有机制的关系

| 机制 | 关系 |
|---|---|
| retryPolicy（mode: always） | 叠加：先无限重试（吸收瞬时抖动），持续失败再回退（避免永久错误死循环） |
| D086 限流自适应 | 协同：429 降并发后仍失败 → 触发回退 |
| D078 模型路由 | 取代 D080/D087 的分岗位路由：统一继承 → 回退链 |
| settings 重启要求 | 回退切换需重启会话生效——文档小组在 run 状态记录标注 |

## 五、执行要点

- **探针测试命令（切换前 MUST 先验）**：
  ```bash
  curl -sS -m 20 -X POST "<baseURL>/v1/chat/completions" \
    -H "Authorization: Bearer <KEY>" -H "Content-Type: application/json" \
    -d '{"model":"<model>","messages":[{"role":"user","content":"ping"}],"max_tokens":5}'
  ```
  ✅ 响应含 `choices` → 可用；`error` → 记 code/message 到本表探针列。
- **主进程默认已统一**：`bai/qwen3.8-flash`（settings）
- **岗位零声明**：agent.cordis.yml 已删 13 处 agentOptions（本次）
- 回退是**run-lead 裁决动作**：识别持续失败 → 切换 → 验证 → 记录