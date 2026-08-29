# 知识库记忆增强（references/memory-enhancement.md）

> D085 完整展开。借鉴 Mem0（ADD-only 检索/实体链接/多信号融合）、OpenViking（L0/L1/L2 三级加载）、Letta（self-editing memory）、OpenHuman（scored Markdown 树）。溯源：`benchmarks/agent-memory-management.md`。
> 定位：**增强 dsh-codepunk 现有 knowledge/ 布局**（不引入外部记忆服务，零代码拷贝），让经验沉淀更可检索、可过期、可复用。

## 一、记忆三级化（knowledge/ 布局增强）

现有 `knowledge/` 布局（hr/lessons/research/handoffs/prompts）引入 L0/L1/L2 层级语义：

| 层级 | 内容 | 对应目录 | 保留策略 |
|---|---|---|---|
| **L0 热记忆** | 当前 run 的临时经验/观察 | `runs/<id>/docs/memory/` | run 结束后归档或丢弃 |
| **L1 工作记忆** | 已验证的经验/教训（结构化） | `knowledge/lessons/` + `handoffs/` | 长期保留，有 triggered 升级 |
| **L2 参考记忆** | 高价值调研/评分档案/提示词 | `knowledge/research/` + `hr/` + `prompts/` | 评分驱动升版，废弃走 D083 §3.3 |

## 二、知识过期三态（补 D083 废弃流程）

| 状态 | 含义 | 标记 | 触发 |
|---|---|---|---|
| **active** | 当前有效 | 无标记 | 默认 |
| **stale** | 可能过时，需验证 | 加 `stale: YYYY-MM-DD` | 超 TTL（research=90d，prompts=180d） |
| **archived** | 已废弃，保留历史 | 移入 `knowledge/archived/` | run-lead 确认 |

> lessons/ 长期保留（无 TTL），仅当被替代时标记 archived。

## 三、条目自包含 + 互链

- 每条经验/教训/评分**自包含**（无需外部上下文即可理解）
- 引用其他条目用 `[ref:<id>]` 标记（如 `[ref:lesson-worktree-lifecycle]`），检索时展开
- 跨 run 引用通过 `run_id + 文件路径`（如 `run-fix-8p/lessons/worktree-lifecycle.yaml`）

## 四、多信号检索（知识库查询增强）

现有 `grep`/`find` 检索保持，增补：
- **复用计数**：`knowledge/` 条目被引用次数记入文件头（`refs: N`），高复用条目优先返回
- **语义标签**：每条头部加 `tags:` 字段（如 `tags: [worktree, lifecycle, D073]`），`grep -h tags: <topic>` 可快速定位
- **时间序**：`created_at` / `updated_at` 字段，检索时可按时间排序

## 五、run 收官后异步抽经验

run complete 后，run-lead / 文档小组执行：
1. 扫描 `runs/<id>/docs/memory/` 与 `tasks/*/handoff/known_issues.md`
2. 按 D070 模板提取可复用经验 → 写入 `knowledge/lessons/<topic>.yaml`
3. 高分人设/团队评分 → 写入 `knowledge/hr/`（已有）
4. 过时/重复条目 → 标记 stale 或 archived

## 六、与既有纪律的关系

| 纪律 | 关系 |
|---|---|
| D074 上下文 | 互补：L0/L1/L2 与上下文预算（≤1500 token）一致 |
| D079 文件卫生 | 无冲突：记忆文件在 knowledge/，非工作房临时文件 |
| D083 技能治理 | 增强：知识过期三态复用 D083 废弃流程 |
| D070 硬信号评分 | 互补：评分驱动经验升版 |