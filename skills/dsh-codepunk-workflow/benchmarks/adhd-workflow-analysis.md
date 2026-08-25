# i-have-adhd（ayghri/i-have-adhd）调研简报：ADHD 友好输出的提示词工程基准

> 委托方：run-lead（dsh-codepunk 六阶段多智能体开发流程，benchmarks/ 基准对照）
> 调研岗：ind-res（唯一联网岗）
> 检索窗口：2026-08-26 02:17（UTC+7）
> 检索方式：本会话 web_search/web_fetch 通道不可用，按惯例改用 **curl 直连 GitHub REST API**（仓库元数据/文件树/提交记录）与 **raw.githubusercontent 官方 raw 正文**（全量文件抓取，56 个 blob 逐一落盘核对）核实。所有 URL 均为真实官方地址；star/时间取 GitHub API 实况值。每条结论标注【事实】（来源可核对）或【推断】（基于可靠知识的推导）。

---

## 0. 仓库元数据快照【事实】

来源：https://api.github.com/repos/ayghri/i-have-adhd （retrieved_at=2026-08-26）

| 字段 | 值 |
|---|---|
| 全名 | ayghri/i-have-adhd |
| 描述 | "A skill to stop your coding agent from burying the answer. ADHD-friendly output." |
| star / fork | **24,208** / 1,544（公开，非 fork） |
| 语言 | Python（主为 eval/测试工具脚本） |
| license | **MIT**（spdx_id: MIT） |
| topics | adhd, claude-code-plugin, claude-skills, developer-tools, productivity |
| created_at / pushed_at / updated_at | 2026-05-13 / 2026-08-21 / 2026-08-25 |
| open_issues / 默认分支 | 21 / main |
| 仓库形态 | 技能+插件多平台发行包（无 CI 失败迹象，含 tests/ + evals/ 全套验证） |

最近提交（https://api.github.com/repos/ayghri/i-have-adhd/commits?per_page=10 ，retrieved_at=2026-08-26）显示活跃：8-21 合并 AI Agora 讨论路由（PR #128）、8-18~19 SessionStart hook 超时修复（PR #123）与 docs/contributing 体系建立（PR #121）。**仓库在快速迭代期，机制均为现行版本（main@b42a45a）。**

---

## 1. 仓库是什么【事实】

**定位一句话：一个把"编码 agent 的输出"塑造成 ADHD 读者可立即行动格式的技能（skill）/插件（plugin），10 条响应规则 + 跨 9 个编码助手平台的注入机制 + 一套评分门禁的评测体系；不是任务管理/待办工具，而是"发送端输出纪律"。**

- 解决什么问题：LLM 编码助手把答案埋在"背景交代、多方案罗列、寒暄收尾"里（README 的 Before 示例），ADHD 读者缺少工作记忆去"挖答案"。【事实】（README.md，retrieved_at=2026-08-26）
- 目标用户：ADHD 开发者；但 README 明确 "No ADHD diagnosis needed!"——输出塑形对所有人降低认知摩擦。【事实】（README.md）
- 理论基础溯源（README Credits）："Loosely based on *The Adult ADHD Tool Kit* by J. Russell Ramsay and Anthony L. Rostain. Adapted for how an LLM should respond, not how a human should organize their day."——**刻意把人类自助书改编为 LLM 输出契约**。【事实】（README.md）
- 使用形态关键词：action-first / 编号步骤 / 状态回放 / 抑制离题 / 具体时间估计 / 让进展可见 / 无寒暄。【事实】（README.md "The rules" 10 条 + SKILL.md）

## 2. 文件树与结构【事实】

来源：https://api.github.com/repos/ayghri/i-have-adhd/git/trees/main?recursive=1 （retrieved_at=2026-08-26，79 条目 / 56 blob，全文 raw 落盘 /tmp/adhd-repo 逐一核对）

| 文件 | 大小 | 用途 |
|---|---|---|
| `skills/i-have-adhd/SKILL.md` | 6.8KB | **唯一事实源**：10 条规则 + Persistence + 例外 + Pre-send check（AGENTS.md 指定 canonical） |
| `.cursor/skills/i-have-adhd/SKILL.md` | 6.8KB | Cursor 镜像（实测与 canonical **完全一致**，diff 为空） |
| `AGENTS.md` | 5.1KB | 仓库的地图文档：agent 协作本仓库的规则（AI Agora 讨论区、provenance 披露、验证命令） |
| `README.md` | 3.3KB | 定位 + Before/After 对照 + 10 条速览 |
| `GEMINI.md` | 0.3KB | Gemini 入口：@import SKILL.md |
| `INSTALL.md` | 20.8KB | 9 平台安装/验证/更新/卸载/always-on（Antigravity/Claude Code/Codex/Gemini/Copilot/Hermes/OpenCode/Pi/OMP 等） |
| `hooks/hooks.json` + `always-on.mjs/.sh/.ps1` | — | Claude Code/Codex SessionStart 钩子：flag opt-in 注入全文（三语言实现，失败恒 exit 0） |
| `extensions/i-have-adhd.ts` | 6.1KB | Pi 编码 agent 扩展：注入一次、双向状态标记、compact 重注入、session 持久 |
| `extensions/context-compat.ts` | 1.7KB | 上下文探测容错降级（检测失败→按"未注入"安全重注入） |
| `.opencode/plugins/i-have-adhd.mjs` + `command/i-have-adhd.md` | 3.2KB | OpenCode system prompt transform 每轮注入 |
| `.claude-plugin/ .codex-plugin/ .agents/ kimi/qwen/gemini/opencode.json` | — | 各平台 manifest（版本 0.2.0 对齐） |
| `evals/cases.jsonl` + `rubric.md` + `README.md` + `scripts/run_evals.py` | — | **双条件 A/B 评测**：盲评 + 五维加权 + 发布门禁 + 费用预算 |
| `AGENTS.md`/`CONTRIBUTING.md`/`.github/pull_request_template.md` | — | 多智能体协作治理：authorship 三分类披露、安全红线、兼容性检查表 |
| `tests/`（test_always_on_hooks.py 等 5 个） | — | hook 跨平台一致性、eval 工具、plugin 加载的单元测试 |

---

## 3. 核心机制（文件逐条归纳 + 原文摘录）

### 3.1 SKILL.md —— 认知模型 + 10 规则 + 例外治理 + 发送前检查 【事实】

**认知前提（"What ADHD changes about reading"，5 条推导规则的事实基础）：**

> 1. Working memory is small. Anything not on screen is forgotten. Do not ask the reader to "keep in mind X."
> 2. Knowing the answer is not doing the answer. The friction between "got it" and "done it" is where work dies.
> 3. Starting is the hardest step. The first action must be obvious, small, and doable now.
> 4. Time estimates feel uniform. "A bit of work" and "a few hours" register the same. Vague estimates fail.
> 5. Dopamine is scarce. Visible progress matters. Buried wins do not register.

**10 条规则（核心句摘录）：**

1. **Lead with the next action** —— "The first line is something the reader can do. Not context. Not a plan. The action."（若答案是命令/路径/片段，它排第一。）
2. **Number multi-step tasks** —— "Each step is one bounded action. No step contains 'and then' twice." + 精简原则："A short path finished beats a complete path abandoned."
3. **End with one concrete next action** —— "name ONE thing the reader can do in under two minutes. Even 'open the file' counts."（原文示例：Bad "Hope that helps." / Good "Next: run `npm test` and paste the first failing line."）
4. **Suppress tangents** —— 第二个问题先完成第一个再作为"Separately:"提出；"A question that comes up mid-work is not a tangent: answer it yourself if you can and fold the result in."
5. **Restate state every turn** —— "The reader cannot hold 'we are on step 3 of 5' between messages." + **工具替叙事条款**："If the harness has a task or plan tool, use it for multi-step work: one item per step, one in progress at a time. **The checklist does the restating; do not also narrate the full plan as prose.**"
6. **Give specific time estimates** —— 具体单位（分钟/下午），禁 "some work"。
7. **Make completed work visible** —— 用可验证的成果句（"Login now works with magic links. Try: `npm run dev`"）。
8. **Matter-of-fact errors** —— 禁 "Uh oh"/"There seems to be a problem"；格式 = 位置 + 期望/实际 + 原因 + 修复。
9. **Cap lists at 5 items** —— 超出拆 "do now vs later" 或 "must vs nice-to-have"。"Five items ranked beats ten unranked."
10. **No preamble, no recap, no closing pleasantries** —— 禁开放句（"Great question"/"Let me..."/"Sure!"）、禁完成后的复述、禁收尾寒暄；"Start with the answer. End when the answer is done."

**Persistence（会话级持久，显式开关）：**

> These rules apply to every response for the rest of the session... They do not expire after a few turns and they do not lapse when the topic changes. If you are unsure whether they still apply, they do. Turn them off only when the reader says "stop adhd mode" or "normal mode".

**When to break the rules（例外清单即规则治理）——6 类违约条款：**

1. 用户要 "explain/walk me through" → 全量输出，但仍有 header 供扫读；2. 破坏性动作（rm -rf/force push/迁移/删表）→ 先确认，"Safety wins over brevity"；3. **调试螺旋**：连续三轮 "still broken" → 停止改代码，"Name the assumption that might be wrong. Ask one diagnostic question."；4. 真实歧义 → 一句澄清胜于猜+重写；5. 规则与任务冲突 → 任务胜、形状保留；6. 规则与 harness 冲突 → system prompt 权重大于本 skill，"the constraint wins, the shape stays"。

**Pre-send check（出口校验）：**

> Before sending, delete: 1. The first sentence if it announces what you are about to do. 2. The last sentence if it asks "anything else?" or recaps... 3. Any "by the way" sidebar. 4. Any hedging adverb adding no information ("perhaps," "might," "could possibly"). Keep a hedge that carries real uncertainty; deleting it manufactures confidence. 5. Any idiom or figurative phrase... Then verify: if the reader reads only the first line and the last line, do they know (a) what to do next, and (b) what just happened?

### 3.2 机制层 —— 注入一次、双标记状态、compact 重注入 【事实】

- `hooks/hooks.json`：SessionStart 钩子，matcher `startup|resume|clear|compact`，command 经 `CLAUDE_PLUGIN_ROOT` 定位 always-on.mjs。【事实】
- `hooks/always-on.mjs`（Node 主实现，sh/ps1 为 POSIX/Windows 兜底）：**flag opt-in**——仅当 `~/.claude/.i-have-adhd-always`（`$CLAUDE_CONFIG_DIR`）存在才注入；注入内容 = SKILL.md 全文**去 frontmatter**；任何失败 `process.exit(0)` "Never block session start"。三语言实现有 `tests/test_always_on_hooks.py` 验证行为一致。【事实】
- `extensions/i-have-adhd.ts`（Pi agent）含三项精细机制：【事实】
  - **注入一次、不重复注入**：`rulesAreInContext` 用 `latestMarkerIsActive`(RULES_MESSAGE_TYPE vs DISABLED_MESSAGE_TYPE) 判定——"Only the newest marker counts: a later 'disabled' notice cancels an earlier ruleset"；已注入则不再塞第二份。
  - **compact/resume 后重注入**：`session_compact → syncContext`，"compaction drops summarized entries so the ruleset has to be injected again"。
  - **状态持久化**：mode（enabled/disabled）以 custom entry 写进 session branch（`getSavedState`），跨 session 恢复；UI 状态栏 "● ADHD ON"。
- `.opencode/plugins/i-have-adhd.mjs`：OpenCode 无 hook，用 `experimental.chat.system.transform` **每轮把规则集追加进 system prompt**（flag 存在时）。【事实】
- `GEMINI.md`：Gemini 用 `@./skills/i-have-adhd/SKILL.md` 导入语法，5 行文件即完整适配。【事实】
- **单一事实源制度**：`AGENTS.md` 规定 "Change `skills/i-have-adhd/SKILL.md` first... then synchronize the `.cursor` mirror"；CONTRIBUTING.md 给出同步命令并强制 `cmp` 核对。【事实】

### 3.3 评测体系 —— 双条件 A/B、五维加权、盲评、发布门禁 【事实】

- `evals/cases.jsonl`：14 个用例，覆盖 direct-answer / agent-autonomy / debugging / explanation / **safety（破坏性命令、医疗边界）** / ambiguity / progress（"step 3 of 5" 场景）/ user-preference（要详细解释时不得为简洁牺牲细节）/ casual（感谢时不得硬造任务）/ planning 等维度，每个用例带 risk 分级与逐条 criteria。
- `evals/rubric.md`：**盲评**（"Judge responses blind: label them A/B/C without exposing the condition name"）+ 五维加权 —— Correctness 35% / **Autonomy 25%**（"Agent performs agent-owned work and does not push avoidable work to the user"）/ Actionability 20% / Safety 10% / Concision 10%；`blocker: true` 条件；**发布门禁**：无 blocker + correctness/safety 各不劣于 baseline 0.1 + 加权分高于 baseline + 竞争性声明须同 cases/models/trials/rubric。
- `evals/README.md` 工程细节：【事实】
  - 双条件同口径：candidate 与 baseline 注入同一 skill 文件，task prompt 完全一致，trials/budget 相同。
  - **评测环境隔离**："`--setting-sources ""` for Claude... without it, user-level plugins, hooks, memory, and output styles leak into every condition"——并自曝最尖锐案例："This repo's own always-on flag... would inject the full i-have-adhd ruleset into the baseline condition and make the comparison measure the skill against itself."
  - 成本护栏：runner 报美元成本、budget 控制、无计费 provider 拒绝（`--allow-unmetered` 除外）；运行可恢复（已完成 (case,trial,condition,runner) 行跳过）。
- `scripts/run_evals.py`：WEIGHTS 常量与 `release_gate` 判定硬编码在脚本里（`candidate weighted score <= baseline` 记为未过门）。【事实】

### 3.4 多智能体协作治理（CONTRIBUTING + PR 模板）【事实】

- **Authorship 三分类强制披露**：human / autonomous agent-authored / hybrid，需写明 agent 工具+模型版本、human 实际审了什么、已知局限；"Do not call generated work human-authored... when it was only reviewed by the same agent that produced it."
- 安全红线：技能文本不得指示读取凭据/改全局配置/绕过破坏性动作确认/静默装软件/伪造医疗陈述（"imply that this skill diagnoses ADHD"）。
- PR 模板含 Target/Author/Workflow 三组标签 + 安全 side-effect 检查表 + "最终责任"勾选（human 对全 diff 负责）。
- `AGENTS.md` 的 AI Agora 制度：agent 可读任意 issue/PR，但**只能评论自己 author 的 PR**；评论他人 issue 须带 `AI Agora` 标签（当前 #127）；每条评论一个提案、区分 observation/inference、引证据、不重复前人评论。

---

## 4. 亮点与独特价值（对「AI 助手辅助工作效率」的可迁移思想）

1. **输出塑形而非任务管理**【推断】：全仓库不做提醒/清单/番茄钟，只做"回答长什么样"——零运行时状态、零自建记忆，接入成本 = 一段注入文本。对 dsh-codepunk 这种重流程编排者，输出塑形是**可与流程正交叠加的薄层**，不冲突。
2. **认知模型先行的规则设计**【事实】：10 条规则全部从 5 条 ADHD 阅读事实推出（working memory small → 状态回放；knowing≠doing → action-first；dopamine scarce → 让成果可见）——规则可论证、可追溯，不是口号。
3. **规则 + 例外 + 出口校验的三段式**【事实】：硬规则、6 类违约条款、Pre-send check（发前删 5 类 + 首末行双读验证）。尤其"首行+末行能否回答 what to do next / what just happened"是一个**可自动化、可评分的检查标准**。
4. **工具替叙事**【事实】：规则 5 主动要求 "checklist does the restating; do not also narrate the full plan as prose"——把状态回放的责任转移给结构化工具，防止人机双写。与上下文工程同族。
5. **注入一次 + 双标记状态机**【事实】：不每轮重复注入规则（省钱省 token、防规则叠层扰动），用"RULES-marker vs DISABLED-marker 谁最新"做幂等开关，compact/resume 后自动重注入——**这是上下文生命周期管理的最佳实践细节**。
6. **把提示词质量工程化**【事实】：A/B 双条件 + 盲评 + 五维加权 + 预算 + release gate + 运行可恢复。其中"**隔离评测环境防自污染**"（自己的 always-on flag 会污染基线）是被多数项目忽略的洞察。
7. **多平台发行模式**【事实】：一份 canonical SKILL.md → 9 个平台适配（hook/extension/command/system-transform/@import 各平台原语不同，行为契约一致）——"单一事实源 + 适配点管理"。
8. **agent 协作治理**【事实】：provenance 强制披露 + AI Agora 讨论区 + "agent 不得评论非本人 PR"——对开放 agent 协作仓库的边界设计。

---

## 5. 对 dsh-codepunk 的适配点（每条标注【事实】/【推断】）

> 对标基础：dsh-codepunk 已具备六阶段闭环、双门闩（R1）、上下文纪律 D074（证据只回 command+exit_code+log_ref、汇报 ≤1500 token、每轮压缩旧巡检）、goal 自动续行（R10/D066）、checkpoint 断点续行（D067）、门禁显式节点（D068）、文件归位纪律（R13/R14）。

**适配建议（按价值排序，具体到机制）：**

1. **【推断】把「首行 = 可执行结论」与「首末行双读验证」写入 persona 承重规则** —— 对三席人设（squad-lead/engineer/sdet）与全部岗位（product/research/docs/people/audit）的汇报模板加一条硬规则：第一行必须是结论/下一步动作（命令、路径、决策），禁止以背景句开头；发送前自检"首行+末行能否回答 what to do/ what just happened"。这与 D074 的 ≤1500 token 摘要、证据截断同属"发送端纪律"，互补不冲突；比 D074 多一条**位置约束**（结论必须出现在第一行，而非摘要内任意位置）。落实位：`references/roles.md` 人设维度表 + `references/artifacts.md` 简报模板头部。

2. **【推断】规则 5「Restate state every turn + 工具替叙事」喂给 goal 续行/巡检闭环** —— 子代理每轮汇报固定一行式进度回放（"Step N of M done: <已完成>。Next: <下一步>。"），恰好是主会话 D074 巡检压缩的输入格式；同时按 i-have-adhd 规则 5，主会话不再用散文复述 plan（goal.yaml/chunks.yaml 就是 checklist，由文件承担 restating）。与 D066（goal 自动递送）、D067（checkpoint 续行）**互补**：restate 让每封电文自含进度，减少主会话对 goal phase 的依赖，但 R12（以文件实况为准）仍为权威——不冲突。

3. **【事实】采用其「出入口双侧校验」三元组：注入检测（入口）→ 规则执行（执行）→ Pre-send check（出口）** —— 与 D068 门禁"入口验输入、出口验输出"同构，但 dsh 目前仅在正式门（双门闩/审查门/合并门）上做双侧校验；可将其下沉为**所有子代理消息的公共操作**：入口侧"是否已注入/是否在职责内"，出口侧"发前删 preamble/recap/寒暄"。机制上可参照 `latestMarkerIsActive` 的双标记状态机（RULES vs DISABLED）做会话级开关。落实位：`agent.cordis.yml` 公共人设段 + SKILL.md 正文短句。

4. **【推断】「When to break the rules」例外清单映射为角色违约条款** —— 三条直接可用：a) 调试螺旋 → dsh 现有"连续 2 次无实质进展 → at_risk 催办"可强化为 i-have-adhd 的"**停止改代码，先点名可能错误的前提假设，再问一个诊断问题**"（正好是 sdet/engineer 回修循环的防空转条款）；b) 破坏性动作先确认（Safety wins over brevity）与 R1/R6 的变更纪律同向；c) "规则 vs harness 冲突时 system prompt 胜、形状保留"——对应 dsh 子代理接受主会话调度命令的优先级声明。**互补**，无冲突。

5. **【事实】移植其 A/B 评测 + 五维加权 + release gate 到 persona/提示词变更流程** —— 这是 dsh 目前**缺失的环节**：现有 scores.yaml（⑤ 人事评分）评的是"人/团表现"，不评"提示词版本质量"。建议：对 `knowledge/prompts/roles/*.md` 或三席提示词的实质修改，跑 baseline vs candidate 双条件（14 用例中 7 个可直接复用：agent-autonomy、progress、error-report、destructive-action、real-ambiguity、partial-success、long-form-request），judge 盲评、budget 上限、release gate（加权分高于基线 + 正确性/安全性不劣 0.1）。**关键教训直接照搬**：评测环境必须隔离（`--setting-sources ""` 类机制），否则 dsh 的 R11 中文纪律/工作房习惯/D074 等"总在环境里"的规则会污染基线，测出"自己打败自己"。

6. **【推断】always-on flag 的 opt-in 哲学 → 新机制灰度引入模式** —— i-have-adhd 安装默认零行为改变，`touch ~/.claude/.i-have-adhd-always` 才激活，删除即还原。dsh 落地新 benchmark 机制时（如第 5 条的评测门禁、第 1 条的首行结论规则）应先以"flag/显式批准"灰度，不对存量 run 静默生效——与双门闩"批准才 spawn"同哲学，互为印证。

7. **【事实】Persistence 条款显式化进子代理人设** —— "These rules apply to every response for the rest of the session... If you are unsure whether they still apply, they do." 对应 dsh 子代理跨轮职责常驻：人设应显式声明"本角色职责跨轮有效、不随话题过期、不确定时仍适用，直到被替换/解散"，与 R10 goal 续行、三帽折叠（S 规模 rl 兼三席）的跨轮一致性互补；防止子代理因话题切换产生"轮次性失忆"。

8. **【推断】单一事实源 + 命令级镜像核对制度** —— i-have-adhd 用"canonical 先改 + cp + `cmp` 强制核对"管镜像。dsh 的 SKILL.md 正文（≤32KiB 预算）与 references/、benchmarks/ 之间同构：正文只留路径与一句话，镜像/派生文件靠命令核对（如 cmp/grep）而非口头承诺——印证现有 R13/R14 归位纪律的"核销引用"步骤，可补充"镜像一致性必须命令验证"一条。

**与已有能力的关系小结**：总体**高度互补、无实质冲突**。i-have-adhd 提供的是"输出/消息侧的纪律层"，dsh 已有的是"流程/状态侧的纪律层"，二者正交。唯一需注意的张力：i-have-adhd 的超简洁风格 vs dsh 证据可复核性——已被 D074（明细留工作房、只回 command+exit_code+log_ref）化解，异常时引用其"rule 5 任务胜、形状保留"原则裁决。**六阶段流程本身无需新增阶段**；适配落点是"所有角色公共的发送端纪律 + 提示词变更评测门禁"。

## 5.1 版权/许可评估【事实】

- LICENSE 为 **MIT**（Copyright (c) 2026 Ayoub Ghriss）：https://github.com/ayghri/i-have-adhd/blob/main/LICENSE （retrieved_at=2026-08-26）。**可自由使用/复制/修改/合并/发布/再许可/销售，含商用**，唯一义务：在所有副本或实质性部分保留版权声明与许可文本。
- MIT 许可文本明示覆盖 "this software and associated documentation files"——SKILL.md 规则文本、AGENTS.md/CONTRIBUTING.md 等文档均在许可范围内。【推断】规则思想与表达可被 dsh-codepunk 借鉴/改写；落地时**保留 attribution**：在引入文件（如 roles.md 或 benchmarks 索引）注明"输出纪律结构基于 ayghri/i-have-adhd（MIT, https://github.com/ayghri/i-have-adhd）"，并附 MIT 许可副本。这与 dsh 既有惯例（benchmark note：机制借鉴、不涉代码抄袭）一致。
- 【推断】规则本身（如"lead with next action"）属通用提示词工程思想，不受版权主张约束；但对**具体表达文本**（如 Pre-send check 的逐条措辞）的整段照抄仍需 MIT attribution。

---

## 6. 引用留痕

> 检索方式声明：本简报全部结论基于 **GitHub REST API + raw.githubusercontent 一手抓取**（web_search/web_fetch 通道本次不可用）。所有 URL 均为真实官方地址，retrieved_at 统一 = 2026-08-26 02:17（UTC+7）。

| 结论/摘录 | 来源 URL | retrieved_at |
|---|---|---|
| 仓库元数据（star 24,208/fork 1,544/MIT/Python/时间线/topics） | https://api.github.com/repos/ayghri/i-have-adhd | 2026-08-26 |
| 文件树（79 条目/56 blob） | https://api.github.com/repos/ayghri/i-have-adhd/git/trees/main?recursive=1 | 2026-08-26 |
| 最近提交记录（#128/#123/#121） | https://api.github.com/repos/ayghri/i-have-adhd/commits?per_page=10 | 2026-08-26 |
| README 全文（定位/Before-After/10 条速览/Credits/license） | https://raw.githubusercontent.com/ayghri/i-have-adhd/main/README.md | 2026-08-26 |
| SKILL.md 全文（10 规则/Persistence/例外/Pre-send check） | https://raw.githubusercontent.com/ayghri/i-have-adhd/main/skills/i-have-adhd/SKILL.md | 2026-08-26 |
| AGENTS.md（仓库地图/单一事实源/AI Agora） | https://raw.githubusercontent.com/ayghri/i-have-adhd/main/AGENTS.md | 2026-08-26 |
| GEMINI.md（@import 入口） | https://raw.githubusercontent.com/ayghri/i-have-adhd/main/GEMINI.md | 2026-08-26 |
| INSTALL.md（9 平台安装/always-on 说明） | https://raw.githubusercontent.com/ayghri/i-have-adhd/main/INSTALL.md | 2026-08-26 |
| hooks.json / always-on.mjs（flag opt-in/SessionStart） | https://raw.githubusercontent.com/ayghri/i-have-adhd/main/hooks/hooks.json 、…/hooks/always-on.mjs | 2026-08-26 |
| extensions/i-have-adhd.ts（注入一次/双标记/compact 重注入） | https://raw.githubusercontent.com/ayghri/i-have-adhd/main/extensions/i-have-adhd.ts | 2026-08-26 |
| extensions/context-compat.ts（容错降级） | https://raw.githubusercontent.com/ayghri/i-have-adhd/main/extensions/context-compat.ts | 2026-08-26 |
| .opencode 插件/命令（system transform 注入） | https://raw.githubusercontent.com/ayghri/i-have-adhd/main/.opencode/plugins/i-have-adhd.mjs 、…/.opencode/command/i-have-adhd.md | 2026-08-26 |
| evals/cases.jsonl（14 用例含 safety/progress 场景） | https://raw.githubusercontent.com/ayghri/i-have-adhd/main/evals/cases.jsonl | 2026-08-26 |
| evals/rubric.md（五维权重/盲评/发布门禁） | https://raw.githubusercontent.com/ayghri/i-have-adhd/main/evals/rubric.md | 2026-08-26 |
| evals/README.md（隔离条件/预算/可恢复运行） | https://raw.githubusercontent.com/ayghri/i-have-adhd/main/evals/README.md | 2026-08-26 |
| scripts/run_evals.py（WEIGHTS/release_gate 逻辑） | https://raw.githubusercontent.com/ayghri/i-have-adhd/main/scripts/run_evals.py | 2026-08-26 |
| CONTRIBUTING.md（authorship/安全红线/验证要求） | https://raw.githubusercontent.com/ayghri/i-have-adhd/main/CONTRIBUTING.md | 2026-08-26 |
| .github/pull_request_template.md（provenance 强制披露） | https://raw.githubusercontent.com/ayghri/i-have-adhd/main/.github/pull_request_template.md | 2026-08-26 |
| LICENSE（MIT，Copyright 2026 Ayoub Ghriss） | https://raw.githubusercontent.com/ayghri/i-have-adhd/main/LICENSE | 2026-08-26 |
| 各平台 manifest（.claude-plugin/.codex-plugin/kimi/qwen/gemini） | https://raw.githubusercontent.com/ayghri/i-have-adhd/main/.codex-plugin/plugin.json （及各等价路径） | 2026-08-26 |
| SKILL 镜像一致性（diff 实测同一） | https://raw.githubusercontent.com/ayghri/i-have-adhd/main/.cursor/skills/i-have-adhd/SKILL.md | 2026-08-26 |

---

## 7. 附：方法与局限

- 抓取口径：tree API 全量 56 blob 逐一下载核对，无遗漏文件；两份 SKILL.md（canonical 与 cursor 镜像）diff 实测一致后才采信单一事实源判断。
- 局限【事实】：未运行仓库的 evals（需预算与模型凭据），评测体系结论基于脚本/文档静态分析；未读 logo.png（二进制）与 tests/ 全量断言细节（按需再取）。
- 本简报为外部调研，**未修改仓库任何文件**；适配决策权归工程主责（run-lead），落地方案由文档小组/工程主责审核后执行。