# 高 star「AI Agent Skills / 技能型」开源项目与 skill 生态调研简报

> 支撑决策号：D068（门禁）/ D069（schema）/ D070（评分）

> 委托方：run-lead（dsh-codepunk 六阶段多智能体开发流程预设 · skill 层强化）
> 调研岗：ind-res（唯一联网岗）
> 检索窗口：2026-08-19（UTC+7）
> 检索方式透明说明：本会话 `web_search`/`web_fetch` 通道不可用（`web_search` 返回 api key 无效，与上次同况），已改用 **curl 直连 GitHub REST API**（repos 一手 star 元数据）+ **raw.githubusercontent 官方 README/SKILL.md**（一手机制说明）+ **agentskills.io 官方规范文档（.md 端点）** 核实。所有 URL 均为真实官方地址；star 数取 GitHub API 实况值（2026-08-19），非第三方转引。每条结论标注【事实】（来源可核对）或【推断】（基于事实的推导/映射）。
>
> ⚠️ 边界声明：以下项目仅作**机制/规范/流程借鉴**，不代码抄袭；涉及 dsh-codepunk 的具体改造落地须经 run-lead 审定后由文档小组写入正式规范，ind-res 不代替决策。

---

## 0. 项目/skill 清单表

| 项目 | 仓库 URL | star(约) | 定位 | 核心机制一句话 |
|---|---|---|---|---|
| obra/superpowers | https://github.com/obra/superpowers | 273,914 | 基于可组合 skill 的完整软件工程方法 | 触发式流程 skill 链（brainstorm→plan→subagent 开发→review→收尾）+ **writing-skills 元 skill 与 drill 评测**
| anthropics/skills | https://github.com/anthropics/skills | 170,382 | Anthropic 官方 Agent Skills 示例/文档 skill 库 | 每 skill 自含 SKILL.md（frontmatter+指令）+ scripts/references；文档 skill(docx/pdf/pptx/xlsx) 生产级 | 
| anthropics/claude-code | https://github.com/anthropics/claude-code | 141,956 | 终端 agentic 编码工具（skill 上下文载体） | skill/agents 动态装载；Plugin marketplace 发布/安装
| affaan-m/ECC | https://github.com/affaan-m/ECC | 241,049 | agent harness 性能优化系统（skill/hooks/config） | 以可组合 skill + 规则约束 harness 行为、防 token 浪费
| nextlevelbuilder/ui-ux-pro-max-skill | https://github.com/nextlevelbuilder/ui-ux-pro-max-skill | 118,070 | UI/UX 设计智能单 skill 示例 | 单 SKILL.md 封装设计智能（示范"高价值单 skill"形态）
| Graphify-Labs/graphify | https://github.com/graphify-labs/graphify | 108,091 | 把代码库+文档转成 agent 可用 skill 知识 | 从仓库现有内容自动生成 skill/agents 知识
| JuliusBrussee/caveman | https://github.com/JuliusBrussee/caveman | 99,107 | 极致 token 经济的 skill 风格 | 窄描述+精简指令，示范"省 token"式 skill 写法
| OpenHands/OpenHands | https://github.com/OpenHands/OpenHands | 84,457 | 开源 AI 软件开发 agent | 以 "microagents"（.openhands/ markdown 上下文注入）实现技能化
| ComposioHQ/awesome-claude-skills | https://github.com/ComposioHQ/awesome-claude-skills | 72,780 | Claude Skills 精选目录 | 聚合官方/社区 skill，按工具与场景分类
| hesreallyhim/awesome-claude-code | https://github.com/hesreallyhim/awesome-claude-code | 52,597 | Claude Code 资源精选 | CLAUDE.md/skills/subagents/插件等最佳实践清单
| VoltAgent/awesome-agent-skills | https://github.com/VoltAgent/awesome-agent-skills | 30,532 | 1497+ 真实 team skill 精选集 | **手选非 AI 生成** + Skill Quality Standards + 贡献门槛
| microsoft/semantic-kernel | https://github.com/microsoft/semantic-kernel | 28,463 | 企业级 agent 编排框架 | 以 "plug-ins/skills"（skprompt.txt）为技能单元 + Agent Framework
| VoltAgent/awesome-claude-code-subagents | https://github.com/VoltAgent/awesome-claude-code-subagents | 24,456 | 158+ Claude Code subagents 集合 | 按领域分类的 .claude/agents 模板库（10 类）
| Skyvern-AI/skyvern | https://github.com/Skyvern-AI/skyvern | 22,786 | 浏览器自动化 agent | 自然语言→浏览器工作流（workflow 型，非 frontmatter skill） |
| UfoMiao/zcf | https://github.com/UfoMiao/zcf | 6,078 | 零配置 Claude Code/Codex 代码流初始化 | 交互式装配 CLAUDE.md/工作流/MCP/技能模板 |
| anthropics/claude-agent-sdk | https://github.com/anthropics/claude-agent-sdk-typescript | 1,705 | agent 开发 SDK | subagent task 通知含 total_tokens/duration（skill eval 取数） |

*star 数据来源：GitHub REST API `repos/{owner}/{repo}`，retrieved_at=2026-08-19；ECC/graphify/caveman/ui-ux 等为检索中发现的同类高 star 项目。【事实】*

> 注：题目中提到的 claude-flow（smtg-ai）与 dolphin-flow 仓库已不可寻（GitHub 404，疑似迁移/改名/归档），**未纳入**；punkpeye/awesome-claude-skills 已 404，其生态位置由 ComposioHQ/awesome-claude-skills 与 VoltAgent 承接。Skyvern 不含 frontmatter 式 skill，仅作"工作流自动化"对照，非 skill 规范来源。

---

## 1. Anthropic 官方：anthropics/skills + agentskills.io 规范（skill 生态事实标准）

**定位/核心机制【事实】**（README + https://agentskills.io/specification + agentskills.io/llms.txt，retrieved_at=2026-08-19）：
- 官方对 Agent Skills 的统一定义，由 **agentskills.io（Agent Skills 开放标准）** 承载，anthropics/skills 为示例实现。
- **目录结构规定**：`skill-name/{SKILL.md(必需), scripts/(可执行), references/(按需文档), assets/(模板/资源)}`。
- **SKILL.md 格式**：YAML frontmatter + Markdown 正文。frontmatter 字段契约：
  - `name`（必填，≤64 字符，小写字母数字+连字符，**必须与父目录同名**）
  - `description`（必填，≤1024 字符，写清"做什么+何时用"，含触发关键词）
  - `license`（可选）、`compatibility`（可选，≤500 字符，环境要求）、`metadata`（可选，任意键值映射，官方建议放 author/version 等）、`allowed-tools`（可选，实验性，预授权工具白名单）。
- **渐进披露（Progressive Disclosure）三层加载**：① 元数据 name+description（约 100 token，全部 skill 启动即载）→ ② SKILL.md 正文（≤5000 token 建议，激活时载）→ ③ scripts/references/assets 按需载。官方建议 SKILL.md **<500 行**，长内容移到 references/，且给出**触发读取条件**（"Read X if Y"）而非笼统 "see references"。
- **文件引用**：用相对路径、保持在 SKILL.md 一层之内、避免深层引用链。
- **校验工具**：`skills-ref validate ./my-skill`（agentskills/agentskills 仓库）检查 frontmatter 与命名。
- 文档型 skill（docx/pdf/pptx/xlsx）为生产级：SKILL.md 内嵌 "Gotchas" 段落（打破合理假设的坑）+ Follow-up 引用 FORMS.md/REFERENCE.md + scripts/（如 soffice 渲染验证）。

**优点【事实/推断】**：a) 规范统一且契约清晰（字段约束、命名、路径），跨客户端可移植；b) 渐进披露是**省上下文**的显式机制；c) 提供官方校验器与 eval 方法（evals.json + description 触发器评测，见下）。

**对 dsh-codepunk-workflow 的可借鉴/可直接利用点【推断】**：
1. **把 dsh-codepunk-workflow 对齐该目录契约**：SKILL.md（frontmatter+正文）+ references/（已具备）+ scripts/（现阶段可空）。frontmatter 补 `metadata.version/licenses/author`。
2. **渐进披露迁移长内容**：现有 workload 长手册主体可压到 <500 行/≤5000 token，把六阶段细节、岗位卡、评分公式、交接包 schema 移入 references/，并在正文写"遇到 X 阶段→读 references/stage-X.md"，控主会话 token。
3. **description 触发器化**（进阶）：描述写"何时调此 skill"而非"它做什么"，防过度/欠触发。

---

## 2. obra/superpowers（273,914★，与 dsh-codepunk 同构度最高的"skill 即方法论"范例）

**定位/核心机制【事实】**（README + skills/writing-skills/SKILL.md + skills/using-superpowers/SKILL.md，retrieved_at=2026-08-19）：
- 把整个软件开发流程**物化为一组可自动触发的流程 skill 链**：`using-superpowers`（会话启动注入的引导）→ `brainstorming` → `using-git-worktrees` → `writing-plans` → `subagent-driven-development`/`executing-plans` → `test-driven-development` → `requesting-code-review` → `finishing-a-development-branch`。
- **引导 skill**：`using-superpowers` 规定"**动作前必先查 skill**"，并列反理性化 Red Flags 表（"这简单""先探索代码库"等借口逐一驳斥）。
- **元 skill `writing-skills`**：把"写 skill"定义为 **TDD 应用到文档**（"NO SKILL WITHOUT A FAILING TEST FIRST"）；含 Skill Discovery Optimization（描述=触发条件、动词首命名、token 预算：常用 skill <200 词）、Skill 类型（Technique/Pattern/Reference）、Cross-Reference 用 `REQUIRED SUB-SKILL: superpowers:xxx` 显式标记（**禁用 @ 强载**，省上下文）、防"按描述抄工作流而跳过正文"的 SDO 陷阱。
- **评测配套**：`superpowers-evals`（prime-radiant-inc）drill eval harness，对 skill 做基线（无 skill 失败）→ 有 skill 合规 → 堵漏洞的压力场景测试。
- 发布链：Claude Code / Codex / Cursor / GitHub Copilot CLI / Gemini CLI 等 via plugin marketplace；官方不建议社区加新 skill（维护门槛极高）。

**优点【事实/推断】**：a) 流程作 skill 化 + 自动触发，正是 dsh-codepunk"公文驱动六阶段"的对标形态；b) writing-skills 元 skill 提供一套**可复制的 skill 作者规范与 reviewer 门槛**；c) eval 用"Wehen agent 无 skill 会失败"证明 skill 价值——把 skill 质量变成可验证。

**对 dsh-codepunk 的可借鉴【推断】**
1. **把六阶段关键词拆成流程子 skill + 一个引导 skill**：dsh-codepunk-workflow 作为总入口（对应 using-superpowers），stage/角色拆为子 skill，正文用 `REQUIRED: 请先读 dsh-codepunk:stage-<n>-xxx` 交叉引用。
2. **写一个 `dsh-codepunk-writing-skills` 元 skill**：把"如何给 dsh-codepunk 写/改 skill"沉淀为内部 authoring 规范（frontmatter 格式、body 结构、SDO、token 预算、测试要求），供实现岗与文档岗复用。
3. **skill 质量门引入"无测试不合并"的铁律**：每个 skill 变更附一个最小触发/输出测试（见 §B-c），未过不得进索引。

---

## 3. skill 集合/发现：VoltAgent、ComposioHQ、hesreallyhim（catalog 爆炸的对策样本）

**定位/核心机制【事实】**（README，retrieved_at=2026-08-19）：
- **VoltAgent/awesome-agent-skills（30,532★）**：1497+ "官方 team 发布 + 社区手选" skill 清单，**明确"非 AI 批量生成、手选、质量优先于数量"**；附 **Skill Quality Standards**：描述第三人称+具体关键词；渐进披露（元数据<100 token、正文<500 行）；**禁用绝对路径**（$HOME/$PROJECT_ROOT）；工具最小声明（避免 `tools:["*"]`）。贡献门槛：**不接收 3 小时前刚创建的新手 skill**，只收社区采用过的 skill。
- **ComposioHQ/awesome-claude-skills（72,780★）**：按工具与场景聚合 Claude Skills 精选目录。
- **hesreallyhim/awesome-claude-code（52,597★）**：Claude Code 最佳实践精选（CLAUDE.md/skills/subagents/插件）。

**优点【事实/推断】**：a) 手选+评审门槛对抗"目录膨胀/质量滑坡"，直指 skill 生态最大痛点；b) 结构化 Quality Standards 可直接抄作 dsh-codepunk 的 skill 入库 checklist；c) 分类目录（按领域/工具/stack）是"避免发现困难"的常见解法。

**对 dsh-codepunk 的可借鉴【推断】**
1. **为 dsh-codepunk skill 库建"入库门槛 checklist"**（借鉴 VoltAgent Quality Standards）：描述触发器化、正文<500 行、无绝对路径、依赖工具显式声明、附至少一个触发/验收用例；**新 skill 至少经一轮真实流程验证后方可入索引**（对应"不接收 3 小时前新 skill"）。
2. **建"skill 索引/目录"单一发现入口**：索引表 = 每个子 skill 的 name + 触发器描述 + 层级/依赖 + 版本，一行一个；由 run-lead 维护，防 catalog 爆炸与重复。（详见 §6 TOP-4）

---

## 4. 同类高 star 单 skill / 工具（参考"单 skill 形态"与"skilling 自动化"）

**定位/核心机制【事实】**（README+检索，retrieved_at=2026-08-19；部分为轻量核对，标推断）：
- **affaan-m/ECC（241,049★）**：harness 性能优化系统，把规则/惯例做成可组合 skill 约束 agent 行为（防 token 浪费、统一工作方式）。→ 借鉴【推断】：dsh-codepunk 可把"双门闩""证据门"等硬约束做进 skill 正文的 Red Flags 强约束段（anti-rationalization 表），而非仅靠人设。
- **caveman（99,107★）**：极端精简 skill 风格示范（窄描述+短正文省 token）。→ 借鉴【推断】：dsh-codepunk 常用子 skill 目标 <200 词，主体细节进 references/。
- **graphify（108,091★）**：从仓库现有内容（docs/schema/config）**自动生成 skill 知识**。→ 借鉴【推断】：dsh-codepunk 可在每轮收官/再规划时，从高分小组交接包/评分刺出**自动提炼候选 skill 草稿**，人审后入索引。
- **nextlevelbuilder/ui-ux-pro-max-skill（118,070★）**：单个高价值 skill 封装的示范（设计智能）。→ 借鉴【推断】：dsh-codepunk 可把"公文撰写规范/验收证据规范"做成高价值单 skill 供子代理按需加载。
- **OpenHands（84,457★）**：用 `.openhands/` microagents（markdown 上下文注入）实现技能化【推断，未取官方 microagents 文档原文，据已知机制】。
- **microsoft/semantic-kernel（28,463★）**：以 plug-ins/skills（skprompt.txt+config）为技能单元 + Agent Framework【事实：README 提及 plugins/agents】。
- **Skyvern（22,786★）**：浏览器自动化工作流（自然语言→步骤），非 skill 规范；对照参考"把重复流程模板化为可复用 workflow"【事实 README；机制推论标推断】。
- **UfoMiao/zcf（6,078★）**：零配置初始化 Claude Code/Codex 的工作流/技能装配工具（CLAUDE.md/工作流/MCP 模板）。→ 借鉴【推断】：dsh-codepunk 可提供"一条命令打全套 skill 模板"的脚手架/初始化脚本，降低接入成本。

---

## 5. B 部分核心结论：skill 内部机制/质量对比提炼（已在上文各小节展开，此处汇总）

### a) skill 规范（frontmatter 与加载触发）
- **规范事实标准 = agentskills.io**：`name`（=目录名，kebab-case，≤64）/ `description`（≤1024，做什么+何时用）/ `license` / `compatibility` / `metadata`（键值，建议 author/version）/ `allowed-tools`（实验性）。正文无格式限制，推荐 step-by-step + I/O 示例 + edge cases。【事实】
- **加载触发**：渐进披露——启动只载元数据（~100 token）→ 命中 description 时读正文 → 按需读 resources。description 是**唯一触发负担**。【事实】
- **触发可靠度**：agentskills 提供 trigger eval 方法（20 个 should/should-not + 每 query 跑 3 次算 trigger rate、train/validation 拆分防过拟合）与 `skill-creator` skill 自动化该循环。【事实】

### b) skill 分层与依赖
- 渐进披露=天然分层（元数据/正文/资源）。【事实】
- 交叉引用用**显式 `REQUIRED` 标记**替代路径/`@` 强载，避免上下文烧穿（superpowers writing-skills）。【事实】
- 流程 skill 优先于实现 skill：先定 approach 再执行（superpowers using-superpowers Skill Priority）。【事实】

### c) 质量与演进
- **"无失败测试不写 skill" 铁律**（superpowers）+ 结构化 evals（agentskills evals.json：prompt/expected_output/files；with_skill vs without_skill 基线、timing/tokens、assertions）。【事实】
- 版本演进：metadata.version + 基线快照回退（evaluating-skills 建议 snapshot 旧版作基线）。【事实】
- 社区贡献门槛：手选、拒收"3 小时新 skill"、Quality Standards checklist（VoltAgent）。【事实】

### d) 发现与检索（防 catalog 爆炸）
- 两种对策并存：**扁平小命名空间**（superpowers ~20 个、靠强 description 触发触达）vs **大目录分类**（VoltAgent 1497+ 按 stack/工具分类，配 Quality Standards 与门槛）。【事实】
- 索引/目录单一入口 + 描述触发器化是共同底线；共识是"**宁少而精**"。【推断】

### e) 对 dsh-codepunk-workflow 的"可直接利用点"（1-3 条）
1. **给 dsh-codepunk-workflow 及所有子 skill 补语义 frontmatter**（name/description/version/licenses/compatibility/metadata），对齐 agentskills.io 规范（可跑 `skills-ref` 校验），这是"更易写/更易发现"的地基。
2. **渐进披露重构**：SKILL.md 主体压缩 + references/ 按需（"读 stage-X 当进入 X 阶段"），直接控主会话 token。
3. **建 skill 索引 + 入库门槛 + eval 门**（见 TOP-4/5）。

---

## 6. 综合建议 TOP 清单（对 dsh-codepunk 价值排序，5-8 条可落地）

优先级侧重：**规范/发现 > 拆分/复用 > 质量/演进 > 触发成本**。

1. **skill 规范对齐 agentskills.io + 语义 frontmatter 强化**【事实标准→推断落地】
   - 为 dsh-codepunk-workflow 及其子 skill 补齐 `name/description`（触发器化："Use when …"、第三人称、不抄工作流）+ `metadata.version/author` + `compatibility`；用 `skills-ref validate` 做机器校验。
   - 价值：dsh-codepunk 是"主会话加载→编排子代理"，规范一致才能跨 run 复用与升级。适配注意：dsh-codepunk-workflow 是被主会话主动加载的，不是靠 description 自动触发——description 主要服务**人工/子代理检索**，写法可相应偏"检索友好"。

2. **渐进披露重构长手册**【事实方法→推断】
   - 把 SKILL.md 压到 <500 行/≤5000 token，六阶段细节/岗位卡/评分公式/交接包 schema 移到 references/，正文给触发读取条件。
   - 价值：主会话上下文管控，多代理并行时尤其省 token。适配注意：渐进而非推倒重写，先抽"评分公式/交接包"两个最重 references/ 试点。

3. **把六阶段拆成流程子 skill + 一个引导总 skill / REQUIRED 交叉引用**【superpowers 模式→推断】
   - dsh-codepunk-workflow 作总入口（对齐 using-superpowers 的 "动作前先查 skill" + Red Flags）；阶段/角色拆为子 skill，正文用 `REQUIRED: 读 dsh-codepunk:stage-xxx` 串。
   - 价值：更易维护、易复用、可单独测试，契合"再规划/裁剪阶段"。适配注意：**勿过度碎片化**——superpowers 也只 ~20 个；先拆高价值 2-4 个（评审门、评分、交接）。
   - 注：dsh-codepunk 现有的 reverse-skill（routes via MASTER-ROUTING 再开子 skill）已是"总入口+子 skill"先例，可推广【事实：本会话 skill 目录】。

4. **建"skill 索引 + 入库门槛"单一入口，防 catalog 爆炸**【VoltAgent 教训→推断】
   - run-lead 维护一份索引（name+触发描述+依赖+版本+负责人），新 skill 过 checklist（触发器化描述/正文<500 行/无绝对路径/附验收用例/经真实流程验证过）才入表。
   - 价值：发现与维护成本摊薄，避免重复；直接对应"更完善、更易发现、更多可复用"。适配注意：索引放 knowledge/ 或 briefs/ 侧，由文档小组落正。

5. **skill 引入 eval/质量门：无验证不合并**【agentskills evals + superpowers IRON LAW→推断】
   - 每个子 skill 变更附：2-3 个触发/输出用例（against with/without 基线），trigger 用 20 条 3 次的 trigger-rate 抽查；旧版快照作基线以支持回退。
   - 价值：把"skill 好不好用"从印象分变成可复核信号，喂给六阶段收官/再规划的质量反馈。适配注意：起步轻量（只对新增/大改跑 2-3 用例），勿在长流程里拖慢迭代。

6. **经验→skill 沉淀回路（graphify + skill-creator 思路）**【推断】
   - 收官/再规划时，从高分小组交接包、回修教训、审查记录**提炼候选子 skill 草稿**（触发条件→常见坑 gotchas→标准解法），run-lead 审后入索引；把"双门闩/证据门"等硬约束写进 Red Flags 强约束段。
   - 价值：跨 run 降缺陷、越用越强的知识资产（呼应 dsh-codepunk knowledge/ 强化）。

7. **写一个 `dsh-codepunk-writing-skills` 元 skill + 可复用文档 skill**【推断】
   - 把"如何给 dsh-codepunk 写/改 skill"沉淀为内部 authoring 规范并加载常态化（替代零散口头约定）；同时评估直接复用社区已验证的文档 skill（docx/pdf/pptx/xlsx）与 UI/设计 skill，避免重复造轮子。适配注意：复用需过入库门槛与 schema 对齐。

8. **环境/依赖显式声明 + 工具最小化**【事实标准→推断】
   - 为各子 skill 声明 `compatibility`（需要的运行时/网络/包）与 `allowed-tools` 白名单，杜绝"绝对路径/工具一把梭"，提升跨设备、跨 run 可移植性。

---

## 7. 事实与推断划分小结

- 【事实】：全部 star 数（GitHub REST API，2026-08-19）；agentskills.io 规范（frontmatter 契约、目录结构、渐进披露三层、evals.json、trigger eval、skills-ref）；anthropics/skills 文档型 skill 结构（gotchas/references/scripts）；superpowers 各 SKILL.md 原文与流程链、writing-skills 的 SDO/REQUIRED 交叉引用/token 预算/IRON LAW，superpowers-evals 存在；VoltAgent Quality Standards 与贡献门槛、1497+ 数量；OpenHands/SemanticKit/Skyvern/ZCF 等 README 所述定位；ECC/graphify/caveman/ui-ux 为检索实况的高 star 单 skill。
- 【推断】：各"对 dsh-codepunk 可借鉴改造"的具体落地形态、拆分粒度（2-4 个子 skill）、索引/门槛的细节、经验沉淀回路；OpenHands microagents 具体加载实现（Markdown 注入，据已知机制推定）；Skyvern"workflow 模板化可借鉴"的迁移。
- 【边界】claude-flow/dolphin-flow/punkpeye 仓库已 404，未纳入；OpenHands microagents 未取官方原文，故相关细节降级为推断。

> ⚠️ 本简报仅作机制/规范/流程借鉴参考；dsh-codepunk 具体改造须经 run-lead 审定后由文档小组写入正式规范。
