# Diagram Design（cathrynlavery/diagram-design）深度分析简报

> 归属域：dsh-codepunk 预设 meta 调研（R13）｜产出：ind-res（调研小组）
> 检索时间：2026-08-29T17:49:00Z（UTC）｜通道：curl 直连 GitHub REST API + raw.githubusercontent.com（web 通道不可用，直连透明；两次 SSL 抖动重试当场补回）
> 前置关联：本简报为 dsh-codepunk 文档小组（`subagent_docs`）的**图表化能力**调研，与既有的 `ponytail-analysis.md`（产出纪律）、`caveman-analysis.md`（表述层 token 经济）形成**表述/产出/视觉**三姊妹。供工程主责审核后下发文档小组。

---

## 0. 抓取与元数据

| 项 | 值 |
|---|---|
| 仓库 | https://github.com/cathrynlavery/diagram-design |
| stars / forks | **28,542** / 1,802（open_issues 31；updated_at 2026-08-29T17:42:37Z 仍活跃） |
| 描述 | "38 editorial diagram types for Claude Code, Codex, and Pi. Self-contained HTML + SVG. No shadows. No Mermaid slop." |
| 语言 / license | HTML（主体为 SVG+HTML 模板 + Python 工具链）／**MIT（单轨）** |
| 关键时间 | 无明显单一 created_at 展示（大量 ADR 覆盖 2026-08），版本 2.6 |
| 主页 | https://cathrynlavery.github.io/diagram-design/ |
| topics | agent-skills, claude-code, codex, data-visualization, diagrams, drawio, mermaid, svg |
| 抓取量 | 文件树 455 节点（含 424 个文件 / 31 个目录）；正文本体抓取 **28 个 .md 文件 + 8 个 ADR + LICENSE** 全部成功（2 次 SSL 抖动重试补回）；`skills/` 内 39 个 type-*.md 全量下载 28 个、余 11 个因超时未全部拉取但非关键；核心 SKILL.md（39KB）、README.md（41KB）、style-guide.md（8.7KB）、semantic-patterns.md（10KB）、animation.md（12KB）、output-spec.md（14KB）、profiles.md（14KB）、onboarding.md（14KB）全部完整 |
| 404/私有/空 | 无。仓库公开、MIT 单轨、全路径可读；`docs/adr/0002-semantic-patterns-do-not-expand-the-taxonomy.md` 在 `raw.githubusercontent.com` 上按文件名 `0002-semantic-patterns-do-not-expand-the-taxonomy.md` 读取成功（未含 `-` 后段则 404，经确认存在） |

---

## 1. 仓库定位（一句话 + 核心机制/设计思想）

**定位一句话**：**一套 39 种编辑品质图表的 AI agent skill，让 LLM 生成"设计师看不上的"专业级 SVG 图表，而非草稿质感——精确到像素级的 SVG 坐标系、4px 网格、语义角色色彩系统，且完全无 Mermaid/无阴影/无通用圆角盒。**

核心机制是 **"语义先行 + 布局分离"** 的双轴设计系统：

1. **语义模式（Semantic Patterns）→ 视觉类型（Visual Types）分离**：行为（队列、策略追踪、信任边界）走语义模式路由到最近的视觉类型布局；纯布局走 39 个类型直接选。**一个模式不创建新类型，一个新类型必须有全新的布局语法才被接纳**（ADR 0002 原则）。
2. **渐进式加载（Progressive Disclosure）**：`SKILL.md` 路由行为 → 语义模式 / 类型参考 / 动画参考按需加载，不做全量唤起。启动时 agent 只看到 skill name + description；请求匹配后才加载对应文件（ADR 0004 强制 40KB cap）。
3. **单源品牌皮肤（Single Source of Truth Tokens）**：所有颜色、字体、间距通过 `style-guide.md` 的语义角色（`paper`/`ink`/`accent`/`muted`/`soft` 等）集中管理，类型参考文件从不内联 hex 值。支持 URL 自动提取品牌 + 多客户端 profile 隔离。
4. **4px 网格硬规则 + 几何验证**：所有坐标、尺寸、间距必须为 4 的倍数（非强制则判 AI 生成味）。标签位置被 `verify-geometry.py` 几何门禁捕获（ADR 0005），避免标签被后续节点覆盖。
5. **静态优先 + 可选动效**：默认输出是单文件无 JS 的 HTML。动效仅在显式请求时启用，`reveal` 是唯一允许的自动播放模式（ADR 0003），且必须通过硬编码的、审计过的 pinned controller（ADR 0001）。
6. **导入降级四轴（Format × Size × Detail × Audience）**：draw.io 或 Mermaid 导入时走四维参数化——格式、尺寸、详细程度、受众——每个轴独立控制输出形态，而非简单转换（output-spec.md）。

---

## 2. 文件逐条归纳 + 关键原文摘录

### 2.1 根级文档

| 文件 | 内容 | 关键摘录 |
|---|---|---|
| `README.md` | 项目首页；39 种类型图网格；安装指南（Claude Code / Codex / Factory Droid / Pi）；品牌 onboarding 流程；draw.io/Mermaid 导入；架构说明；贡献指南 | "No Figma. No generic rounded boxes. No 30-minute color-picking sessions." — "The highest-quality move is usually deletion." — "Target density: 4/10." |
| `SKILL.md` | 技能核心指令（39KB，40KB 硬上限）：哲学、选型指南、设计系统、SVG 原语、布局与间距、预输出清单、模板与变体、导入输出规格 | "Every node represents a distinct idea. Two nodes that always travel together are one node." — "Coral is editorial, not a flag. 1–2 focal nodes per diagram." — 含**9 大类 49 项 taste gate 清单** |
| `LICENSE` | MIT | "The MIT License (MIT) — Copyright (c) 2025 Cathryn Lavery" — 全仓 MIT，无附加限制 |
| `CONTRIBUTING.md` | 贡献指南、验证门禁、CI 流程 | — |
| `CODE_OF_CONDUCT.md` | 社区行为准则 | — |
| `SECURITY.md` | 安全报告渠道 | — |
| `THIRD_PARTY_LICENSES.md` | Tabler Icons 等第三方组件许可 | — |
| `.maintainer-policy.json` | 维护者策略 | — |

### 2.2 核心技能参考（`skills/diagram-design/references/`）

| 文件 | 内容 | 关键摘录 |
|---|---|---|
| `style-guide.md` | 语义角色表（10 个角色，light/dark 双值）+ 字体栈 + 节点类型→配色表 + 自定义皮肤约束 | "Every token is referred to by semantic role, not by its hex value." — "Mono is for technical content only — never as a blanket 'dev' font." — "Paper is warm-neutral, not pure white." |
| `semantic-patterns.md` | 7 种语义模式：Fan-in queue / Stage framework / Unstructured input / Paired policy traces / Secure paved road / Governance catalog / Compensating security layers | "Semantic patterns describe what a system does; the 39 visual types describe how information is arranged." — 每个模式含触发条件、所需原语、复杂度预算、反模式、静态回退、最近视觉类型 |
| `animation.md` | 4 种动效模式（none / reveal / step / loop）+ 8 条静态优先增强合约 + 8 种语义原语 | "Animation explains a complete static diagram; it never supplies missing meaning." — "8 steps, 12 marked items, 2 simultaneous items" |
| `output-spec.md` | 导入输出的四轴规格（Format / Size / Detail / Audience）+ 类型 ramp 表 + 降级阶梯 + 受众示例 + 非拉丁文字处理 | "The point isn't conversion, it's fitting the output to where it's going." — Same source, three different diagrams. |
| `profiles.md` | 客户端 profile 机制：`~/.diagram-design/profiles/<slug>.md`，项目 marker `profile: <slug>` 直接读取，非拷贝 | "Marker-first direct reads are what make two parallel workspaces with different clients safe." |
| `onboarding.md` | 品牌 onboarding 三步流程：URL / Skill / Folder 三种来源 | "Takes about 60 seconds." — 含品牌 fidelity receipt 要求 |
| 39 个 `type-*.md` | 每种视觉类型规范：最佳用途、布局约定、复杂度预算、反模式、SVG 原语、示例列表 | 每个类型文件 1–30KB，含类型特定布局数学（如 Loop 的参数化几何） |

### 2.3 ADR（`docs/adr/`）

| # | 标题 | 关键决策 |
|---|---|---|
| 0001 | Static by default; one pinned controller for motion | 静态无 JS 输出默认；动效脚本必须字节匹配 `template-motion.html` |
| 0002 | Semantic patterns never expand the visual-type taxonomy | 行为与布局分离；语义模式不创建新类型 |
| 0003 | Reveal is the only sanctioned autoplay | `reveal` 可自动播放一次，永不复播 |
| 0004 | SKILL.md byte cap and the trigger-rich description | 40KB 硬上限；frontmatter 必须列出所有类型名 |
| 0005 | Label placement is verified geometrically | 标签位置由 `verify-geometry.py` 几何门禁（非人工审查） |
| 0006 | Client profiles use marker-first resolution | 多客户端 profile 通过 `~/.diagram-design/profiles/` + 项目 marker 隔离 |
| 0007 | Ten new layout grammars (28 → 38 visual types) | 10 个新类型的加入论证（每个都有全新布局语法） |
| 0008 | Native host manifests share one plugin root | 多 host 共享同一插件根，不复制技能文件 |

### 2.4 工具与脚本

| 目录 | 内容 |
|---|---|
| `commands/` | 5 个命令定义（export-diagram / import-drawio / import-mermaid / profile / doctor） |
| `prompts/` | 对应 Pi 的 4 个 prompt 模板 |
| `scripts/` | 20+ Python 脚本：验证/几何/布局/截图/自检/图例/图标构建 |
| `skills/diagram-design/scripts/` | 3 个打包脚本：drawio_extract.py / mermaid_extract.py / self_check.py |

---

## 3. 对 dsh-codepunk 文档小组的适配点

### 3.1 文档小组产出中可用 Diagram 的场景（【事实】/【推断】）

**【事实】** dsh-codepunk 六阶段流程（需求确认→规划组队→并行开发→巡检交接→解散评分→再规划）涉及多个角色、任务、依赖关系，天然的图表化需求。

| 场景 | 最佳 Diagram Design 类型 | 文档小组产出物 | 推导 |
|---|---|---|---|
| 六阶段流程总览 | **Flowchart** / **Process** | WORK_BRIEF.md 首页 | 【事实】这些类型专为"决策逻辑分支"和"多角色顺序流程"设计 |
| 分块依赖图（chunks.yaml 的 depends_on） | **Dependency graph** | 规划阶段 brief/ | 【事实】Dependency graph 专为"fan-in + 多父 + 环"设计，与 chunks.yaml 的 DAG 语义一致 |
| 岗位人设/团队结构 | **Org chart** / **Nested** | staffing/ | 【事实】Org chart 指定"human/agent/team ownership, reporting, routing, escalation" |
| 交接包数据流（谁→产出了什么→谁接收） | **Data flow** / **DP integration** | handoff/ | 【事实】Data flow 是"role-scoped pipeline steps"，DP integration 是"sources → core → consumers" |
| 知识库沉淀/经验学习路径 | **Loop（flywheel）** | knowledge/ | 【推断】Loop 的"hub + 6 stations"结构天然适合描述持续改进循环 |
| 项目时间线/里程碑 | **Timeline** | run 总览 README.md | 【事实】Timeline 为"events positioned in time"设计 |
| 错误/风险分层 | **Layer stack** | errors/ | 【事实】Layer stack 是"stacked abstractions" |
| 状态机（goal 状态转换） | **State machine** | goal.yaml 配套图示 | 【事实】State machine 为"states + transitions + guards"设计 |
| 工作房文件树/模块结构 | **Tree** | handoff/artifact_index.md | 【事实】Tree 是"parent → children relationships" |
| 评分信号/雷达图 | **Radar** / **Bar chart** | scores.yaml 配套 | 【事实】Radar 是"multi-axis comparison"，Bar 是"categorical comparison" |
| 用户旅程/文档小组使用流程 | **User journey** | docs/ | 【事实】Journey 为"stages, actions + sentiment"设计 |
| 安全策略/信任边界 | **Architecture** + **Secure paved road pattern** | 文档 | 【事实】Architecture 是"components + connections"，Secure paved road 为信任边界设计 |

### 3.2 可借鉴到文档小组人设/流程/产物模板的 8 条具体建议

1. **【建议】WORK_BRIEF 首页流程总览改用 Process 类型**（非 Markdown 罗列）
   - 依据：Process 类型专为"multi-actor sequential process with data handoffs"设计（type-process.md），比 bullet list 更适合表达六阶段跨角色交付。Signal 对比：视觉密度 4/10，消除"AI 生成的通用列表感"。
   - 可配：dark/light 双版本，嵌入文档 HTML 中，方便 sponsor 快速浏览。

2. **【建议】chunks.yaml 依赖关系配套 Dependency graph 图**
   - 依据：Dependency graph 的 fan-in badge + 循环标记 + 层排序与 dsh-codepunk 的 chunks.yaml DAG 完配（type-dependency.md）。"Fan-in badge"可直接显示"5 blocks depend on this"。
   - 保存为 `briefs/<chunks_id>-deps.html`，随 `brief.yaml` 一起审批。

3. **【建议】handoff 交接包配 Data flow 图**
   - 依据：交接包涉及"谁产出了什么→谁接收→什么格式"，Data flow 的"role-scoped pipeline steps"语义（type-data-flow.md）准确表达。交接材料中 `summary.md` + `artifact_index.md` + `known_issues.md` 三件套可视为三个角色节点的输出。

4. **【建议】文档小组的"文档质量检查流程"用 Swimlane 表达**
   - 依据：Swimlane 是"cross-functional process with handoffs"（type-swimlane.md），适合表达文档主责→技术写作→文档质检 三角色的审核流转。

5. **【建议】知识库经验沉淀采用 Loop 图式**
   - 依据：Loop 的"hub + stations"结构（hub=共享记忆，stations=Capture→Research→Decide→Act→Measure→Learn）描述了"持续改进循环"（type-loop.md），与 dsh-codepunk 的"lessons → knowledge → 再规划"循环一致。

6. **【建议】文档小组的"第一印象"（first-run gate 机制）借鉴 Diagram Design 的做法**
   - 依据：SKILL.md §0 描述"first-time setup — style guide gate"——在首次使用品牌时暂停并询问用户是否要定制，而非默认输出。对应 dsh-codepunk 文档小组：首次进入项目时，应检查是否已有品牌风格/模板约定，而非直接输出默认模板。

7. **【建议】产物模板的"预输出清单（Taste Gate）"机制直接引入**
   - 依据：SKILL.md §9 的 49 项 taste gate 覆盖类型适配、删除测试、信号、技术、排版 5 个维度。文档小组可为每个产出物（简报/交接/记忆）设计类似 checklist，在签发前运行。模仿格式：`Type fit → Remove test → Signal → Technical → Typography`。

8. **【建议】多客户端 profile 模式（marker-first 隔离）用于跨项目文档风格管理**
   - 依据：`profiles.md` 设计了 marker-first 模式——项目根放 `.diagram-design` marker 直接读取 `~/.diagram-design/profiles/<slug>.md`，不互相覆盖。dsh-codepunk 文档小组可为不同项目/客户建立独立的文档风格 profile，通过项目 marker 隔离。

### 3.3 与既有 D074-D081 纪律的关系

| 纪律 | 关系 | 说明 |
|---|---|---|
| **D074 上下文纪律** | 增强 | Diagram Design 的"渐进式加载"（SKILL.md 只路由，类型参考按需拉取）与 D074 的"上下文物价"一致——不给 agent 塞它不需要的 39 个类型参考 |
| **D075 消息纪律** | 兼容 | Design 的 taste gate 清单式输出（"首行结论"→ 49 项逐条过）与 D075 的"首行可执行结论 + 编号≤5"方向一致，但 Design 更细粒度（49 项） |
| **D076 Token 经济学** | 增强 | Design 用 4px 网格硬规则 + 几何门禁替代人工排版检查，是"安全先于简洁"的视觉版——省人工审图 token |
| **D077 反幻觉纪律** | 兼容 | Design 的"不接受无验证的标签位置"（ADR 0005）与 D077 "完成断言须新鲜证据"精神一致——几何验证是硬证据 |
| **D078 模型路由** | 无直接关系 | D078 指角色分模型路由选型，与图表技能无直接关系 |
| **D079 工作房卫生** | 兼容 | Design 的"self_check.py"在产物上做自检，与 D079 的"防残留/清理自查"一致 |
| **D080** | 未在已加载 skill 中明确 | — |
| **D081 产出纪律（YAGNI）** | **强关联** | Design 的哲学核心"最高质量的移动通常是删除"与 D081 的 YAGNI 阶梯完全一致。"Every node earns its place."——4/10 密度目标就是视觉 YAGNI |

### 3.4 License 可复用性

**MIT 许可证**。全仓（含 `skills/`、`commands/`、`scripts/`、`docs/`）均 MIT：
- 可自由复制、修改、合并、发布、再许可
- 可嵌入 dsh-codepunk 预设的文档小组产出物
- 可改造为 dsh-codepunk 专用的图表化模板
- 唯一要求：保留原件版权声明
- 第三方图标：`scripts/vendor/icons/tabler/`（Tabler Icons，MIT）、`scripts/vendor/icons/simple/`（Simple Icons，CC0），各自许可独立

---

## 4. 引用留痕

| 来源 | URL | Retrieved At |
|---|---|---|
| 仓库首页 | https://github.com/cathrynlavery/diagram-design | 2026-08-29T17:49:00Z |
| 元数据 API | https://api.github.com/repos/cathrynlavery/diagram-design | 2026-08-29T17:49:00Z |
| 文件树 API | https://api.github.com/repos/cathrynlavery/diagram-design/git/trees/HEAD?recursive=1 | 2026-08-29T17:49:00Z |
| README.md | https://raw.githubusercontent.com/cathrynlavery/diagram-design/main/README.md | 2026-08-29T17:49:00Z |
| SKILL.md | https://raw.githubusercontent.com/cathrynlavery/diagram-design/main/skills/diagram-design/SKILL.md | 2026-08-29T17:49:00Z |
| LICENSE | https://raw.githubusercontent.com/cathrynlavery/diagram-design/main/LICENSE | 2026-08-29T17:49:00Z |
| style-guide.md | https://raw.githubusercontent.com/cathrynlavery/diagram-design/main/skills/diagram-design/references/style-guide.md | 2026-08-29T17:49:00Z |
| semantic-patterns.md | https://raw.githubusercontent.com/cathrynlavery/diagram-design/main/skills/diagram-design/references/semantic-patterns.md | 2026-08-29T17:49:00Z |
| animation.md | https://raw.githubusercontent.com/cathrynlavery/diagram-design/main/skills/diagram-design/references/animation.md | 2026-08-29T17:49:00Z |
| output-spec.md | https://raw.githubusercontent.com/cathrynlavery/diagram-design/main/skills/diagram-design/references/output-spec.md | 2026-08-29T17:49:00Z |
| profiles.md | https://raw.githubusercontent.com/cathrynlavery/diagram-design/main/skills/diagram-design/references/profiles.md | 2026-08-29T17:49:00Z |
| onboarding.md | https://raw.githubusercontent.com/cathrynlavery/diagram-design/main/skills/diagram-design/references/onboarding.md | 2026-08-29T17:49:00Z |
| ADR 0001 | https://raw.githubusercontent.com/cathrynlavery/diagram-design/main/docs/adr/0001-static-by-default-single-pinned-controller.md | 2026-08-29T17:49:00Z |
| ADR 0002 | https://raw.githubusercontent.com/cathrynlavery/diagram-design/main/docs/adr/0002-semantic-patterns-do-not-expand-the-taxonomy.md | 2026-08-29T17:49:00Z |
| ADR 0003 | https://raw.githubusercontent.com/cathrynlavery/diagram-design/main/docs/adr/0003-reveal-is-the-only-sanctioned-autoplay.md | 2026-08-29T17:49:00Z |
| ADR 0004 | https://raw.githubusercontent.com/cathrynlavery/diagram-design/main/docs/adr/0004-skill-md-byte-cap-and-trigger-rich-description.md | 2026-08-29T17:49:00Z |
| ADR 0005 | https://raw.githubusercontent.com/cathrynlavery/diagram-design/main/docs/adr/0005-label-geometry-is-verified.md | 2026-08-29T17:49:00Z |
| ADR 0006 | https://raw.githubusercontent.com/cathrynlavery/diagram-design/main/docs/adr/0006-client-profiles-and-marker-first-resolution.md | 2026-08-29T17:49:00Z |
| ADR 0007 | https://raw.githubusercontent.com/cathrynlavery/diagram-design/main/docs/adr/0007-new-layout-grammars.md | 2026-08-29T17:49:00Z |
| ADR 0008 | https://raw.githubusercontent.com/cathrynlavery/diagram-design/main/docs/adr/0008-native-host-manifests-share-one-plugin-root.md | 2026-08-29T17:49:00Z |
| type-dependency.md | https://raw.githubusercontent.com/cathrynlavery/diagram-design/main/skills/diagram-design/references/type-dependency.md | 2026-08-29T17:49:00Z |
| type-loop.md | https://raw.githubusercontent.com/cathrynlavery/diagram-design/main/skills/diagram-design/references/type-loop.md | 2026-08-29T17:49:00Z |
| type-sequence.md | https://raw.githubusercontent.com/cathrynlavery/diagram-design/main/skills/diagram-design/references/type-sequence.md | 2026-08-29T17:49:00Z |

---

*end of brief — 可据此向工程主责提交审核，审核通过后由文档小组结合具体场景落地。*