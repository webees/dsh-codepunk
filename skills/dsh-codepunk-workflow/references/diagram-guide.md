# 文档小组 Diagram 应用规范（references/diagram-guide.md）

> D082 完整展开。借鉴 cathrynlavery/diagram-design（MIT，39 种视觉类型）：语义模式与布局分离、4px 网格、几何门禁。溯源：`benchmarks/diagram-design-analysis.md`。
> 定位：**文档小组产出物按场景配图**——六阶段/依赖/交接/知识库用图表达，替代纯文本罗列，提升 sponsor 与团队可读性。

## 一、场景 → 图类型映射（文档小组产出）

| 文档小组产出 | 图类型 | 用途 |
|---|---|---|
| WORK_BRIEF 首页流程总览 | **Process** | 六阶段跨角色流转（数据交接可视化） |
| 规划 brief/依赖说明 | **Dependency graph** | chunks.yaml 的 depends_on（fan-in badge 显示依赖计数） |
| staffing/ 团队结构 | **Org chart** | 岗位归属/汇报/升级路线 |
| handoff/ 交接包 | **Data flow** | 谁产出→什么→谁接收（role-scoped pipeline） |
| knowledge/ 经验沉淀 | **Loop（flywheel）** | 持续改进循环（hub + 6 stations） |
| run 总览 README | **Timeline** | 里程碑/事件时间线 |
| errors/ 错误日志 | **Layer stack** | 错误/风险分层 |
| goal.yaml 配套 | **State machine** | 状态转换（active⇄blocked→completed） |
| artifact_index | **Tree** | 文件树/模块结构 |
| scores.yaml 配套 | **Radar / Bar** | 多轴对比/分类对比 |
| 架构/安全说明 | **Architecture** + Secure paved road | 组件连接/信任边界 |

## 二、设计铁律（4 条，借鉴 diagram-design 核心）

1. **语义与布局分离**：先定「行为模式」（队列/流程/依赖/信任边界）再选视觉类型；一个模式不创建新类型。
2. **4px 网格硬规则**：坐标/尺寸/间距必须为 4 的倍数（非 4 的倍数 = AI 生成味）。
3. **密度 4/10 + 单一焦点**：每图 1-2 个焦点节点；「每节点一个独立想法，总在一起的两个节点是同一个」。
4. **静态优先**：默认无 JS 静态图；动效仅显式请求时启用（reveal 允许，不复播）。

## 三、输出约定

- 默认**单文件 HTML（内联 SVG）**，嵌入文档可读；dark/light 双版本。
- 颜色走**语义角色**（paper/ink/accent/muted），不内联 hex；文档小组统一品牌皮肤。
- 工具：无重依赖——优先用 SVG 手写（4px 网格），必要时 draw.io/Mermaid 导入按四轴降级（Format×Size×Detail×Audience）。

## 四、质量检查（Taste Gate 精简版，5 维）

1. **布局**：4px 网格、对齐、无重叠标签（几何可验证）
2. **内容**：每节点一个想法、无冗余节点、密度 4/10
3. **颜色**：语义角色一致、焦点色 ≤2
4. **字体**：等宽仅技术内容、非「dev 字体」滥用
5. **语义**：图表达了文档想说的（流程/依赖/结构），不装饰

## 五、适用范围

- **必须配图**：WORK_BRIEF 首页（Process）、chunks 依赖（Dependency）、交接包（Data flow）——三处核心产出
- **建议配图**：知识库经验（Loop）、run 总览（Timeline）
- **可选**：其余（Org/Tree/Radar 等按需）

> 纪律：图是**辅助理解**，不替代文字验收；「最高质量的动作通常是删除」——图宁少勿滥。