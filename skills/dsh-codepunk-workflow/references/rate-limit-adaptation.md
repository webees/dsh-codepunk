# 限流自适应调度（references/rate-limit-adaptation.md）

> D086 完整展开。目的：run-lead 在 spawn 子代理时自动检测 429 RATE_LIMIT 模式，动态调整并发与调度策略，降低限流中断概率。基于 api.b.ai 网关实测（并行 ≥3 子代理触发 429）。

## 一、自动发现（run-lead 识别限流模式）

| 信号 | 判定 | 级别 |
|---|---|---|
| 子代理结算通知含 `RATE_LIMIT` 或 `HTTP 429` | **限流事件** | 触发降并发 |
| 连续 ≥2 个子代理同时 429 | **限流模式** | 触发全批次降级 |
| 子代理首次请求即 400（`reasoning_content passback`） | passback 断裂 | 修复 context 或降 thinking |
| 子代理运行中进程 kill（会话未 flush） | harness/资源问题 | 非限流，走常规重试 |

## 二、自动调整（三档）

| 档位 | 触发条件 | 调整动作 |
|---|---|---|
| **L1 温和** | 单子代理 429 | 下一批 spawn 降并发（≤2/批）+ 批次间隔 10s；保留原退避策略 |
| **L2 严格** | 连续 ≥2 子代理 429 | 暂停 spawn→改为**串行**+ 每 spawn 前确认前一个已 complete；批量任务标记 `off-peak` 延后 |
| **L3 降级** | L2 后仍 429 | 暂停该轮调度，切换备选 provider（若有）；通知 sponsor（你）确认是否继续 |

## 三、自我学习（限流历史）

```
429 事件 → 记入 errors/YYYY-MM-DD.md（时间戳+并行数+子代理数+恢复时点）
        → knowledge/lessons/rate-limit-history.yaml（汇总表：日期/工程/并行数/429 次/恢复策略）
        → 下次 spawn 前先读历史：若今日已有 ≥2 次 429 → 直接启用 L2
```

## 四、与既有机制的关系

| 机制 | 关系 |
|---|---|
| D077 反幻觉 | 互补（限流不是幻觉，但错误识别互通） |
| R12 结算通知辨识 | 增强：R12 管「结算通知可能滞后」，D086 管「结算含 429 → 降并发」 |
| retryPolicy（normal） | 叠加：retry 兜底单次失败，D086 预防批量失败 |
| D078 成本/错峰 | 协同：错峰标记复用 D078 错峰调度机制 |
| D083 技能治理 | 限流热数据可沉淀入 knowledge/lessons/ 供 D083 月度复检 |

## 五、执行要点

- D086 是**流程纪律**（人设/流程层面），非代码自动（不改 harness）
- run-lead 每次 spawn 前自我提问：「上批是否 429？→ 本批降并发」—写入 squad-lead 巡检 check
- 限流历史文件路径：`~/.dsh-codepunk/projects/<project_id>/knowledge/lessons/rate-limit-history.yaml`