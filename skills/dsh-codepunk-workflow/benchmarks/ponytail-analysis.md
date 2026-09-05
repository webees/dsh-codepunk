# ponytail（DietrichGebert/ponytail）深度分析简报

> 支撑决策号：D081（YAGNI 产出纪律）

> 归属域：dsh-codepunk 预设 meta 调研（R13）｜产出：ind-res（调研小组）
> 检索时间：2026-08-28T22:52:27Z（UTC）｜通道：curl 直连 GitHub REST API + raw.githubusercontent.com（web 通道对 API/raw 高频抓取不高效，故直连；全程透明）
> 前置关联：`agent-skills-open-source-benchmark.md`（高 star 生态）已列为 agent-skills 样板；本简报为**产出/建筑纪律**维度拆解，与既有的 `caveman-analysis.md`（D076 来源，**表述层** token 经济）形成**表述/产出**姊妹对，供工程主责审核后下发。

---

## 0. 抓取与元数据

| 项 | 值 |
|---|---|
| 仓库 | https://github.com/DietrichGebert/ponytail（owner 实际大小写 `DietrichGebert`） |
| stars / forks | **115,300** / 6,306（open_issues 178；watchers 同 stars） |
| 描述 | "Makes your AI agent think like the laziest senior dev in the room. The best code is the code you never wrote." |
| 语言 / license | JavaScript（主体 hooks/scripts）／**纯 MIT（单轨）**——全仓含 hooks/scripts/skills 皆 MIT |
| 关键时间 | created 2026-06-12；pushed_at 2026-08-07T21:44:01Z；updated_at 2026-08-28T22:50:18Z（仍活跃） |
| homepage | https://ponytail.dev/ |
| topics | agent-skills, ai-agents, claude, claude-code, cursor-rules, llm, prompt-engineering, **yagni** |
| 抓取量 | 文件树 212 节点（truncated=false）；正文本体抓取 19 个文件全部 200（0 失败）：README.md、AGENTS.md、`.agents/rules/ponytail.md`、`.cursor/rules/ponytail.mdc`、6 个 `skills/*/SKILL.md`、`docs/agent-portability.md`、`docs/platform-native.md`、`benchmarks/README.md`、`examples/README.md`、`ponytail-mcp/README.md`、`hooks/{ponytail-runtime,subagent,activate}.js`、`examples/email-validation.md`（后者未抓取，见引用留痕） |
| 404/私有/空 | 无。仓库公开、单轨 MIT、全路径可读；无 BSL 等 source-available 限制 |

---

## 1. 仓库定位（一句话 + 核心机制）

**定位一句话**：让 agent **"不写不该写的代码"**——一个纯 MIT 的 YAGNI 产出纪律 skill 族，背后是一套"先理解、再逐级减码、省不删安全"的**可执行阶梯**，靠 20+ agent 的薄适配器分发，是全生态 star 高达 11.5k、且**用诚实基准抵消营销夸大**的极简开发范式。

核心机制是「**lazy senior dev（懒而高效，非懒而疏忽）**」的一组**显式规则**，比含糊的"保持简洁"可审计得多：

1. **七级递减阶梯（The Ladder）**——写码前停在第一个成立的档位：
   ```
   1. 需要写吗？(YAGNI)      → 不需要：跳过
   2. 本仓已有？              → 复用 helper/util/pattern，别重写
   3. 标准库有吗？            → 用 stdlib
   4. 平台原生有吗？          → `<input type="date">` 优于 picker 库
   5. 已装依赖能解吗？        → 用它，别为新需求装新依赖
   6. 能一行吗？              → 一行
   7. 然后才：写最小可用代码
   ```
   关键双约束：**阶梯在理解问题之后跑，而非替代理解**（"read fully, then be lazy"）；**两档都成立取高一档后继续**（reflex, not research project）。
2. **根因修复**：bug 报告给的是症状。改码前 grep 该函数**所有 caller**，在共享函数里修一次（一个 guard 的 diff < 每个 caller 各一个 guard）；只修 ticket 点名路径会让兄弟 caller 仍坏着。
3. **故意简化要留痕**：砍掉真角落（global lock、O(n²)、naive heuristic）时用 `ponytail:` 注释命名**天花板 + 升级路径**——诚实标注，不为省而撒谎。
4. **Not-lazy 保护清单（绝不简化）**：理解问题本身、trust boundary 校验、防数据丢失的错误处理、安全、可访问性、**硬件校准**（clock drifts/sensor reads off——platform 从不是 spec 理想）、用户明确要求。用户坚持完整版 → 直接建，不再争论。
5. **检查纪律（YAGNI 应用于测试）**：非平凡逻辑留**一个有可跑性**的检查（assert 版 demo/`__main__` 自检或一个小的 `test_*.py`）；**no frameworks, no fixtures, no per-function suites**；平凡一行无需测试。
6. **输出契约**：`code first, then at most 3 short lines: skipped: [X], add when [Y].`——"解释比代码长就删解释"；用户要的完整报告/走读仍给全文（规则只禁**未被请求的**散文）。
7. **强度分级**：lite（命名更懒替代，用户选）/ full（默认，梯子强制）/ ultra（YAGNI 极端，删除优先）；默认 full，持久直到显式关闭或会话结束。

**实测口径（诚实数字，明显区别于营销）**：README 用**agentic** 基准（真实 Claude Code 会话改真实 FastAPI+React 仓，按 git diff 计分，12 个 feature ticket、Haiku 4.5、n=4）给出 LOC **−54%**（平均）/ 最高 −94%（date-picker 场景）、token −22%、cost −20%、time −27%、**safety 100%**；对照臂 caveman（terse-prose 控制）LOC −20% 但 token/cost/time 反而**升**；"YAGNI + one-liners"裸提示 −33% 但 safety 掉到 **95%**。README **明言**："The rule was never 'fewest tokens'. It is write only what the task needs, and never cut validation/error handling/security/accessibility." 并**诚实纠正**早期单发基准的 80–94% 夸大（issue #126——裸模型基线凑散文充数），给出 3 个**第三方独立基准**链接（注明"数字归他们、可能漂移、是佐证非官方"）。

---

## 2. 文件逐条归纳 + 关键原文摘录

### 2.1 根级文档
| 文件 | 内容 | 关键摘录 |
|---|---|---|
| `README.md` | 产品首页；基准表；20+ agent 安装矩阵；命令表；FAQ；MIT | "You know him. Long ponytail... You show him fifty lines; he looks at them, says nothing, and replaces them with one."；"ponytail keeps every safety guard while a bare 'write one-liners' prompt drops one."；"Lazy about the solution, never about reading."；"`<input type="date">` over `<!-- ponytail: browser has one -->`" |
| `AGENTS.md` | 全 agent 自动发现的紧凑 always-on 指令 | 见 §1 阶梯 + 根因 + 规则 + Not-lazy 清单（与 `.agents/rules/ponytail.md` 同文，32 行）；"(Yes, this file also applies to agents working on the ponytail repo itself. Especially to them.)" |
| `LICENSE` | MIT | "The shortest license that works."（README 语） |
| `benchmarks/README.md` | 三臂/三模型/五任务，10 runs/格，median；召回方法；量纲说明 | "Code LOC counted from fenced code blocks; tokens/cost/latency straight from API."；correctness 作**gate**（"a broken one-liner that scores great on LOC will fail on correctness"）；"These are generation numbers, not a session-cost promise." |
| `docs/platform-native.md` | **平台原生替换速查表**（HTML/CSS/JS/Swift/Node/Python/DB 六层） | "Before reaching for a package, scan here."；"Platform team spends years solving the problem. Package author wraps it. You install the wrapper. Wrapper goes unmaintained. You debug the wrapper. Skip the wrapper."；"When the native solution is genuinely insufficient, the library earns its place. Install it then, not before." |
| `docs/agent-portability.md` | **单核心 + 多薄适配器**分发表 | "The skills in `skills/` hold the core behavior; host-specific files are adapters."；"**Adapter Rule**: keep adapters thin. When a host supports skills or hooks, point it at the existing `skills/` and `hooks/` files. When a host only supports project instructions, keep its copied rule text aligned with `AGENTS.md`." |

### 2.2 skills/（核心指令族，全部 MIT，也是全仓行为单源）
| 文件 | 定位 | 关键原文/摘要 |
|---|---|---|
| `skills/ponytail/SKILL.md`（120 行，~6.6KB） | **主技能全文**（行为唯一单源） | §1 全量；Persistence："ACTIVE EVERY RESPONSE. No drift back to over-building."；Boundaries："Ponytail governs what you build, not how you talk (pair with Caveman for terse prose)."；"The shortest path to done is the right path." |
| `skills/ponytail-review/SKILL.md` | **面向 over-engineering 的 diff 审查**（只找该删的） | 输出契约 `L<line>: <tag> <what>. <replacement>.`；五 tag：`delete:`/`stdlib:`/`native:`/`yagni:`/`shrink:`；结尾唯一指标 `net: -<N> lines possible.`；无物可删 `Lean already. Ship.`；范围声明"correctness/security/perf 明确出局，转正常 review"；"The diff's best outcome is getting shorter." |
| `skills/ponytail-audit/SKILL.md` | **全仓 over-engineering 审计**（review 的 repo-wide 版） | 同五 tag；Hunt 清单（deps stdlib 已带、单实现接口、单产物工厂、仅委派 wrapper、单导出文件、死 flag/config）；输出 `net: -<N> lines, -<M> deps possible.`；one-shot，不改代码 |
| `skills/ponytail-debt/SKILL.md` | **把 `ponytail:` 注释收集成债务台账** | `grep -rnE '(#|//) ?ponytail:' .`（skip node_modules/.git/build）；每行 `<file>:<line>, <what>. ceiling: <limit>. upgrade: <trigger>.`；**无 upgrade path 的标 `no-trigger`**（"那些会悄悄腐烂"）；结尾 `<N> markers, <M> with no trigger.` |
| `skills/ponytail-gain/SKILL.md` | 基准收益计分板（ASCII 条） | **Honesty boundary：** "NEVER print a per-repo savings number... the unbuilt version was never written, so there is no real baseline to subtract from in a live repo."；one-shot，不改模式 |
| `skills/ponytail-help/SKILL.md` | 命令速查 | 模式/关闭语/默认模式解析（env > config > full） |

### 2.3 hooks/（跨 host 注入 + 多智能体纪律注入）
| 文件 | 定位 | 关键原文/摘要 |
|---|---|---|
| `hooks/ponytail-subagent.js` | **Claude Code SubagentStart hook——让 Task 子代理也带纪律** | "SessionStart context is parent-thread only and never reaches subagents, so without this every Task-spawned agent runs ponytail-unaware (issue #252)."；缺 mode/off → inject none；`PONYTAIL_SUBAGENT_MATCHER` 正则按 `agent_type` **选择注入**（`explore|general` 或 `^general$`）；**fail-open**：坏正则/读不到 type/stdin 出错/超时都注入，保证"scoping never silently drops the persona" |
| `hooks/ponytail-runtime.js` | 模式读/写 + 各宿主输出格式适配（Claude/Codex/Copilot/Qoder） | `writeHookOutput` 依据 isCopilot/isCodex/isQoder 分支吐不同 JSON（Copilot `additionalContext`、Codex `systemMessage PONYTAIL:<MODE>`、Claude SubagentStart 需 `hookSpecificOutput` JSON 否则 context 被丢）；`.ponytail-active` 状态文件作 mode 旗标 |
| `hooks/ponytail-activate.js` | 会话启动激活 + 默认模式 | 每 session 激活当前 mode 并注入 ruleset |
| `hooks/claude-codex-hooks.json` | 宿主 hook 清单 | 事件名映射 |

### 2.4 平台适配器（薄层）
- `.agents/rules/ponytail.md`、`.cursor/rules/ponytail.mdc`、`.clinerules/ponytail.md`、`.qoder/rules/ponytail.md`、`.windsurf/rules/ponytail.md`、`.github/copilot-instructions.md`、`.kiro/steering/ponytail.md`：**同一规则文本的 2495→2620 字节拷贝**，供不同 agent 自动发现。
- `.claude-plugin/`、`.codex-plugin/`、`.github/plugin/`、`.grok-plugin/`、`.qoder-plugin/`、`.devin-plugin/`：各宿主 plugin manifest（指向 `skills/` 与 `hooks/`）。
- `.opencode/plugins/ponytail.mjs`、`pi-extension/index.js`、`ponytail-mcp/index.js`：库/服务器型注入（MCP 只暴露 `ponytail` prompt + `ponytail_instructions` tool，**声明"非 always-on 的替代，而是 MCP 主机唯一注入点是 prompt 菜单时的干净选项"**，见 issue #70）。
- `.openclaw/skills/*/SKILL.md`、`.opencode/command/*.md`、`commands/*.toml`：由 `skills/` 生成的同步副本（`scripts/build-openclaw-skills.js`，测试断言不陈旧）。
- `package.json`、`scripts/{check-rule-copies,check-versions,uninstall}.js`：单源对齐校验（`node scripts/check-rule-copies.js` 让多份规则文本保持一致）、版本校验、卸载清理。
- `benchmarks/` 完整 agentic 基准（`tasks.py`/`run.py`/`judge.py`/`correctness.js`）+ `examples/*.md` 原始模型 before/after 对照（email 75→3 LOC、debounce 116→10、React countdown 267→9）。

---

## 3. 对 dsh-codepunk 的适配点

> 标注：【事实】= 仓库原文/实测可证；【推断】= 由事实向 dsh-codepunk 的迁移判断，需工程主责审核。
> **核心判定**：dsh 既有 **D076（表述层 token 经济，借鉴 caveman）已覆盖"怎么说"**；ponytail 管的是**"写什么"（产出/建筑纪律）**——README 明文 "Caveman shrinks what the agent says; ponytail shrinks what it builds. Different halves, no overlap." 故 ponytail **不是 D076 的替代，而是其缺失的"产出维"**。

**建议 1（产出/建筑纪律——核心提案，建议新 D081）【推断·提案】**
【事实】七级阶梯 + "先理解再上阶梯" + 根因修复（grep 全部 caller 修共享函数一次）+ "shortest working diff wins **but only once you understand the problem**; smallest change in wrong place isn't lazy, it's a second bug"。
【推断】dsh 实现岗位（engineer）人设目前强在**边界/证据/门闩**，缺**产出规模**的显式契约。建议新增 **D081（YAGNI 产出阶梯 + 根因修复）**，作为 D076 的姊妹条（D076 表述层／D081 产出层），落点：engineer 人设"写码前先爬七级阶梯（需要吗→复用→stdlib→平台→已装依赖→一行→最小），先读后改"；修 bug 先 grep 全部 caller 找共同根因再一次性修复。**与六阶段**：主落③并行开发的 engineer 执行约束；**与双门闩（R1）**：正交——门闩管"能否开工"，D081 管"开工后怎么产出"，不冲突；**与 ⑥**：仅知识沉淀时引用，不改流程骨架。

**建议 2（可机器解析的 over-engineering 审查契约 → 增强 D068/D069 审查门）【事实→推断】**
【事实】ponytail-review 输出契约 `L<line>: <tag> <what>. <replacement>.` + 五 tag + 结尾 `net: -<N> lines possible.`；无物可删 `Lean already. Ship.`；**范围声明**：correctness/security/perf 明确出局、转正常 review。
【推断】dsh 审查门（D068 显式节点 + 审查记录 `reviews/<task_id>.md`）可引入 ponytail-review 的**最小 schema**：过 CHECKLIST 后追加一栏"over-engineering 发现（tag + net 行）"，把"是否过度设计"从主观开放问题变成**机器可解析字段**，与 D068 出口校验、D069 schema 强约束同向。审查者（squad-lead 或 `subagent_code_review`）自动补；为空则 `Lean already.`。给门禁多一个**客观维度**的轻量契约，不加重负担。

**建议 3（`ponytail:` 简化标记 → 债务台账，增强 D079 残留自查）【事实→推断】**
【事实】故意简化（global lock/O(n²)/naive heuristic）用 `ponytail:` 注释命名天花板+升级路径；`ponytail-debt` 用同一 grep 收集成台账；**无 upgrade 的标 `no-trigger`**（"那些会悄悄腐烂"，防 later 变 never）。
【推断】dsh **D079 文件卫生**收尾"残留自查"目前防**残留物**（状态文件/脚手架/临时物），但**不防"有意的简化被遗忘成债"**。建议 handoff 交接包增"简化台账节"：engineer 把 `ponytail:`（或 `dsh-debt:`）注释的 ceiling/upgrade 汇总进 `known_issues.md` 或独立 debt 记录，巡检时用同一 grep 收集；**无 trigger 的打回补写**。这是对 D079 的**增量增强**（防"有意简化腐烂成债"），非重复，也不与 D079 现有五硬规则冲突。

**建议 4（非平凡逻辑留单一自检——YAGNI 版测试配额）【事实→推断】**
【事实】non-trivial logic（branch/loop/parser/money-security path）leaves **ONE runnable check**（assert 版 demo/`__main__` 自检或一个小 `test_*.py`）；**no frameworks, no fixtures, no per-function suites unless asked**；trivial one-liners need no test；"YAGNI applies to tests too"。
【推断】dsh 当前证据链（`evidence.yaml` + R12 交付基线 + D069）偏向"验证**已发生**"，但工程师**写码时**缺一个**最小自检配额**：非平凡逻辑至少一个 assert 自检，**不建框架/夹具/每函数套件**。这能平衡 sdet 与 engineer 的**测试开销**与"最小充分证明"（D070）。建议写入 engineer 人设 + handoff 交接的"自检"字段；与 `subagent_sdet` 的 evidence 端到端验证形成"写时自检 + 验后证据"双保险。注：需与 dsh 既有测试规范协调（若有），属"省而非糙"。

**建议 5（输出契约：code first + ≤3 行 skip/why——增强 D074/D075 汇报格式）【事实→推断】**
【事实】Output 契约：code first, then at most 3 short lines（what was skipped / when to add）；pattern `[code] → skipped: [X], add when [Y].`；"if the explanation is longer than the code, delete the explanation"。
【推断】dsh **D074（≤1500 token 摘要）+ D075（首行=结论）**缺一个**更具体的产出报告格式**。给 engineer/squad-lead 回报模板加"产物先行 + 至多 3 行：跳过什么/何时补"，与 D075 首行结论、D074 摘要配额**天然叠加、不冲突**。可作为 references/roles.md 回报模板的细化；⚠ 注意与 D075 第④条"安全先于简洁"协调——跳过/补时**属技术简化**，**不抛安全/可访问性**。

**建议 6（强度分级 lite/full/ultra → 产出档）【事实→推断】**
【事实】lite（命名更懒替代，用户选）/ full（默认梯子强制）/ ultra（YAGNI 极端，删除优先，同一口气挑战需求）；持久直到变更；默认 full。
【推断】dsh 实现岗位可引入**轻量产出档**（普通=full 默认、强约=ultra、保守=命名替代），与 D076 的表述分级（caveman 同款 lite/full/ultra）对齐。⚠ 低优先级：dsh 是多智能体中文流程，档位需克制（统一默认即可，避免为分级而分级），仅作为 P16/knowledge/prompts 的进阶选项，不作承重。

**建议 7（平台原生替换表 → 知识库/提示词优化沉淀）【事实→推断】**
【事实】`docs/platform-native.md` 给 HTML/CSS/JS/Swift/Node/Python/DB 六层"你以为要装库→平台已自带"映射表 + "Skip the wrapper" 模式 + "native insufficient 时才装，装就在那时"。
【推断】dsh 工程师/实现组可沉淀一份**面向本仓技术栈 + dsh 运行栈的**平台原生对照（最贴 JSON/TS、Web 平台与 Node 内置——dsh 是 DeepSeek Harness Node/JS 环境），放入 knowledge 或 references，供写码时"先查表再装依赖"。这是 ponytail 里**最可立即落地、低风险**的改进,直接服务"避免引入本不需的依赖"（D076 之外的产出面）。深实现组的招写码低理解成本。

**建议 8（薄适配器分发 + 子代理纪律注入——对 dsh 预设架构的元借鉴）【事实→推断】**
【事实】`docs/agent-portability.md` Adapter Rule（**keep adapters thin**：宿主支持 skill/hook 就指向现有 `skills/`,`hooks/`，否则保持与 `AGENTS.md` 对齐）+ `scripts/check-rule-copies.js` 多副本一致性校验；`hooks/ponytail-subagent.js`：SessionStart 只在父线程，Task 子代理默认 unaware，需 SubagentStart hook 注入 ruleset + `PONYTAIL_SUBAGENT_MATCHER` 正则按 agent_type 选择注入、**fail-open 防 persona 静默丢失**。
【推断】两点元借鉴（架构层，非内容）：①dsh 预设的**单源对齐**（roles/standard/artifacts 多处互相引用）可引入"多副本一致性校验脚本"，把"对齐"从人工纪律升为 CI/流程门禁——但需注意 dsh 是中文文档、无编译时校验，可置于 `subagent_proc_audit` 红灯项；②dsh 主会话加载 SKILL.md 而岗位子代理**勿加载总手册**（SKILL.md 明示），这套"子代理按岗位带共享纪律、可正则选择注入、fail-open"正是把 **R2 禁联网/某纪律选择性注入子代理**精确落袋的参考。属 dsh 既有"机制思想借鉴、不涉及代码抄袭"基准（P07 note）之列，无 license 障碍。

### 3.1 与既有能力的关系判定

| 能力 | 关系 | 论证 |
|---|---|---|
| 六阶段 | 主落③并行开发（engineer 产出约束、审查契约），②简报/知识库可选 | 不改变流程骨架，仅在 engineer 执行与审查维度注入 |
| 双门闩（R1） | **正交，无冲突** | 门闩管"能否开工"，ponytail 管"开工后产出尺度/审查维度" |
| D074 上下文纪律 | **互补（强）** | D074 管"回传多少"，ponytail 输出契约管"产出的报告形态"，叠加不冲突 |
| D075 消息纪律 | **互补（中）** | D075 首行结论/编号≤5，ponytail code-first+3 行 skip 是其"产出版"；需与 D075④"安全先于简洁"协调 |
| D076 token 经济（caveman） | **姊妹互补，非替代** | README 明文 caveman 缩 prose、ponytail 缩 build、无重叠；ponytail 不新增 token 规则，补 D076 的**产出维** → 建议新 D081 |
| D068 门禁显式节点 | **互补** | ponytail-review/audit 的 schema 是 D068 出口校验的一种客观维度增强 |
| D069 schema 强约束 | **同向** | 五 tag + `net:` 行是典型机器可解析 schema 范式 |
| D079 文件卫生 | **互补（增量）** | ponytail-debt 债务台账增强 D079"残留自查"，防"有意的简化腐烂成债"而非仅防残留物 |
| D070 硬信号评分 | **互补** | ponytail-gain 的 honest-boundary（绝不打印 per-repo 节省）是 dsh 未来定量基准的诚实纪律 |
| R13/R14 文件归宿 | **无改动** | 本简报按 R13写入预设 benchmarks/；R14 复核落位 |

> 编号结论：D080 已被占用（用户决策记录，被 D078 引用）。故核心"产出纪律"提案建议用**新号 D081**（或作为 D076 姊妹条并入），交工程主责定夺；**不得与 D080 撞号**。

### 3.2 license 可复用性（重点）

- **纯 MIT（单轨）**：全仓——`skills/`、`hooks/`、`scripts/`、`docs/`、`benchmarks/`——皆 MIT（GitHub API `license.spdx_id = MIT`）。**显著宽松于 caveman 的双轨**（caveman skill 层 MIT / engine 层 BSL-1.1;ponytail 无任何 source-available/商用限制）。
- **对 dsh-codepunk**：【事实】规则文本（各 SKILL.md、AGENTS.md、docs）与机制思想均 MIT，可直接借鉴/改写为 dsh 纪律，**须保留来源与版权声明**（MIT 要求 copies/substantial portions 附带许可声明——可在 references/learned-skills.md 溯源表加一行来源 URL + license 注记）；【事实】无 BSL 引擎代码可复制之虞，与 dsh 既有"机制思想借鉴、不涉及代码抄袭"基准（P07 note）一致；【推断】若未来直接引用其 SKILL.md 原文若干行做内置规则，把来源 URL + license 写入 comments 与 learned-skills.md。
- **商标**：ponytail 为项目名/意象（懒高级工程师），非注册商标强约束；dsh 借用其**规则思想**（YAGNI 阶梯/根因/留痕/检查）不构成商标使用，但**不得**在产品/预设名中冒充 ponytail 官方。

---

## 4. 引用留痕（全部 retrieved_at = 2026-08-28T22:52:27Z，除非另注）

- 仓库元数据：https://api.github.com/repos/dietrichgebert/ponytail
- 文件树：https://api.github.com/repos/dietrichgebert/ponytail/git/trees/HEAD?recursive=1
- raw 正文（base https://raw.githubusercontent.com/DietrichGebert/ponytail/main/）：
  - README.md、AGENTS.md、LICENSE、`.agents/rules/ponytail.md`、`.cursor/rules/ponytail.mdc`
  - skills/{ponytail,ponytail-review,ponytail-audit,ponytail-debt,ponytail-gain,ponytail-help}/SKILL.md
  - docs/{agent-portability,platform-native}.md、benchmarks/README.md、examples/README.md、ponytail-mcp/README.md
  - hooks/{ponytail-runtime,ponytail-subagent,ponytail-activate}.js
- 未抓取（元数据可见/非正文）：`examples/email-validation.md` 及 `benchmarks/agentic/tasks.py` 等（仅树内可见，未下载正文；示例 before/after LOC 已由 `examples/README.md` 表给出）、https://ponytail.dev/、https://star-history.com/#dietrichgebert/ponytail&Date
- 交叉引用（既有调研）：../benchmarks/caveman-analysis.md（D076 来源，表述层 token 经济）、../benchmarks/prompt-context-compression.md（D074）、../benchmarks/adhd-workflow-analysis.md（D075）、../benchmarks/file-hygiene-skill.md（D079 相关）

---

## 5. 结论摘要

1. 【事实】ponytail 是 ~128k star、**纯 MIT** 的 YAGNI 产出纪律 skill 族；可复用资产是**七级递减阶梯 + 根因修复 + 简化留痕 + Not-lazy 保护清单 + 单一自检 + 输出契约**这套显式可审计规则。
2. 【事实】核心检证（agentic 基准，fair 基线）：LOC −54%（最高 −94%）、token −22%、cost −20%、time −27%、**safety 100%**；裸"one-liner"提示 safety 掉至 95%。README **诚实纠正**单发夸大并挂 3 个第三方独立基准。
3. 【推断】对 dsh-codepunk 的 TOP 适配：①建议新 **D081（YAGNI 产出阶梯 + 根因修复，D076 的产出维姊妹条）**；②ponytail-review 五 tag/`net:` schema 增强 D068/D069 审查门；③`ponytail:` 简化标记→债务台账增强 D079；④单一自检配额（YAGNI 版测试）；⑤输出契约 code-first+≤3 行增强 D074/D075；⑥轻量产出档；⑦平台原生替换表（低风险快改）；⑧薄适配器分发 + 子代理纪律注入（dsh 预设结构的元借鉴）。
4. 【事实】与六阶段/双门闩无冲突；与 D074/D075/D068/D069/D079 **互补**；与 D076 为**表述/产出姊妹对**（README 明文无重叠）。
5. 【事实】license **纯 MIT**，全仓可借鉴（保留来源+版权声明），无 caveman 式 BSL 商用限制；核心编号避开已占用 D080，建议用 **D081**。
