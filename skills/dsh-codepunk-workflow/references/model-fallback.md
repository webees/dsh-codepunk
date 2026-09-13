# 模型统一与回退机制（references/model-fallback.md）

> D089 完整展开。**D090 修正其「继承主进程」主张**：实测孩子**不继承**主会话模型，须显式 `agentOptions`（双要件见 standard.md D090）。回退链部分仍有效。
> 目的：①全链路（主进程 + 13 岗位）统一单一模型路由，消除「子代理与主进程用不同模型」的分裂；②主模型失败时按链回退，不中断流程。
> 背景：harness（dsh-llm / agent-loop）**无原生 provider fallback**——回退须由流程纪律层实现（run-lead 认知 + 工具层重试后切换）。

## 一、模型统一（全链路一致，杜绝分裂）

- **原则（D090）**：子代理**必须显式声明模型**——agent.cordis.yml 各派遣岗位配置
  `agentOptions: {provider: <PROVIDER>, model: <MODEL>}` + `backgroundMode: continuable`。
  （实测：删除声明后孩子**不继承**主会话模型，落产品默认模型。）
- **单一事实源**：主会话用 settings `agent-default-model`；子代理用 `agentOptions` 显式声明同一路由——**部署方需保证两者指向一致**。
- **为何显式而非继承**：继承路径不经父会话 options，子代理会落到产品默认模型（可能与主会话完全不同），是模型分裂的根因。
- **改配置生效条件**：改 agent.cordis.yml 或 settings 后**须重启 DSH Desktop**（运行中进程与已建会话持有旧快照）。

## 二、回退链（模板，部署方按实际环境填写）

| 级 | provider（settings 名） | 模型 | 探针状态 | 适用 |
|---|---|---|---|---|
| **主** | `<PRIMARY>` | `<MODEL>` | 未测/✅/❌ | 默认路由 |
| **备 1** | `<BACKUP-1>` | `<MODEL>` | 未测/✅/❌ | 主路由持续失败时优先试 |
| **备 2** | `<LOCAL-FALLBACK>`（本地端点，可选） | `<MODEL>` | 未测/✅/❌ | 云端均失败时兜底 |
| （可扩展） | … | … | … | … |

> **探针纪律（切换前优先测已配置模型）**：回退切换前先跑最小探针验证目标模型可用（见 §五 命令），**只切到 verified 的模型**；探针结果每次实测后更新本表（标日期）。

## 三、回退触发与执行（run-lead 纪律）

1. **触发条件**（满足其一，且持续失败、重试无用）：
   - 同一 provider 连续 ≥3 次 `RATE_LIMIT` / `TIMEOUT` / `TRANSPORT`
   - `QUOTA`（额度/余额耗尽）——`mode: always` 已排除瞬时抖动，但仍持续失败
   - 「模型名不存在」类**永久错误**（`mode: always` 下会死循环——此时**主动回退优于空等**）
2. **执行**：
   - run-lead 认知到持续失败 → 切换主路由（settings `agent-default-model.provider/model`）到下一位
   - 同步更新子代理 `agentOptions`（保持主/子一致）
   - 记录：回退事件入 `errors/YYYY-MM-DD.md`（时间 / 原 provider / 新 provider / 失败码）
3. **回退后**：验证新路由可用（一次小请求），再继续流程。

## 四、与既有机制的关系

| 机制 | 关系 |
|---|---|
| retryPolicy（mode: always） | 叠加：先无限重试（吸收瞬时抖动），持续失败再回退（避免永久错误空等） |
| D086 限流自适应 | 协同：429 降并发后仍失败 → 触发回退 |
| D078 模型路由 | 承接分档纪律（只用 flash 档禁 pro/max 类高成本档） |
| settings 重启要求 | 回退切换需重启 DSH Desktop 生效——文档小组在 run 状态记录标注 |

## 五、执行要点

- **探针测试命令（切换前 MUST 先验）**：
  ```bash
  curl -sS -m 20 -X POST "<BASE_URL>/chat/completions" \
    -H "Authorization: Bearer <KEY>" -H "Content-Type: application/json" \
    -d '{"model":"<MODEL>","messages":[{"role":"user","content":"ping"}],"max_tokens":5}'
  ```
  ✅ 响应含 `choices` → 可用；含 `error` → 记 code/message 到 §二 探针列。
- **主/子同源**：settings `agent-default-model` 与各岗位 `agentOptions` 指向同一 provider/model。
- 回退是**run-lead 裁决动作**：识别持续失败 → 切换 → 验证 → 记录。
