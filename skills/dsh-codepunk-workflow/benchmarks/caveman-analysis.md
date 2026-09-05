# caveman（JuliusBrussee/caveman）深度分析简报

> 支撑决策号：D076（token 经济）

> 归属域：dsh-codepunk 预设 meta 调研（R13）｜产出：ind-res（调研小组）
> 检索时间：2026-08-25T19:29:20Z（UTC）｜通道：curl 直连 GitHub REST API + raw.githubusercontent.com（web 通道对本批量的 raw 抓取不高效，故直连；全程透明）
> 前置关联：`agent-skills-open-source-benchmark.md`（2026-08-19）已列为「极致 token 经济 skill 风格」高 star 样板，本简报为其深度拆解，供工程主责审核后下发。

---

## 0. 抓取与元数据

| 项 | 值 |
|---|---|
| 仓库 | https://github.com/JuliusBrussee/caveman（任务书写作 `juliusbrussee`，GitHub owner 实际大小写为 `JuliusBrussee`，同一仓库） |
| stars / forks | **100,905** / 5,859（watchers 同 100,905） |
| 描述 | "🪨 why use many token when few token do trick — Claude Code skill that cuts 65% of tokens by talking like caveman" |
| 语言 / license | Go（主体）/ **MIT + BSL-1.1 双轨**（GitHub 标注 "Other"/NOASSERTION） |
| 关键时间 | created 2026-04-04；pushed_at 2026-08-24T23:31:25Z；updated_at 2026-08-25T19:25:15Z（仍活跃） |
| homepage | https://caveman.so/（Caveman Cloud 商业侧） |
| 抓取量 | 文件树 1,000+ 节点；全量正文抓取 **184 个文件全部成功（0 失败）**：全部 .md/.txt/.toml、子代理预设、hooks 解析器、registry、打包产物 `dist/caveman.skill` |
| 404/私有/空 | 无。仓库公开，全部路径可读 |

## 1. 仓库定位（一句话 + 核心机制）

**定位一句话**：让 agent「少说（输出 token 节约，caveman 风格 skill，MIT）+ 少读（输入上下文压缩引擎 + 本地代理，BSL）」，已从单 skill 长成覆盖 30+ agent、含子代理预设、工作模式、MCP、浏览器扩展、云观测的完整生态——但**对他人可复用的核心仍是其 skill/提示词层的极简规则体系**。

核心机制是「**caveman 式极简**」的**一组显式、可审计的规则**，而非含糊的「简洁」：

1. **删除类**：冠词（a/an/the，中文不适用）、填充词（just/really/basically/actually/simply）、客套（sure/certainly/of course/happy to）、hedging（it might be worth…）、冗余连接（however/furthermore/additionally）。**片断句（fragments）可用**。短同义词替换（big 不 extensive；fix 不"implement a solution for"；use 不 utilize）。
2. **禁止类（token 经济学，关键）**：**绝不发明缩写**（cfg/impl/req/res/fn/auth）——tokenizer 拆分后与全词 token 数相同，"zero token saved, reader still decode"；**禁箭头 →**（自带 token 无节省）；**禁止为装 caveman 而加词**（"when it not" 比 "when not" 多一 token）；保持正确动词形式（"sees" 与 "see" 同 token，mangle 不省反伤可读）。
3. **保护类（绝不压缩）**：技术术语/代码块/API 名/CLI 命令/错误字符串**逐字保留**；数字、单位、日期精确；**never drop not/never/no/only/except**（翻转语义，代价大于任何 token 节省）。
4. **格式模式**：「`[thing] [action] [reason]. [next step].`」；无工具调用旁白（no tool-call narration）；无装饰表格/emoji；长错误日志除非被要求否则只引最短决定性一行。
5. **语言纪律**：**压缩风格，不压缩语言**——按用户主导语言回复，技术词/代码/commit 类型词（feat/fix…）保持原文不动。
6. **Auto-Clarity（安全豁免）**：下列场景**退出极简改正常行文**：安全警告、不可逆操作确认、多步序列片断易歧义、压缩本身造成技术歧义（如"migrate table drop column backup first"顺序不明）、用户困惑/重复提问；澄清后恢复。
7. **Boundaries（持久化豁免）**：代码、注释、提交信息、PR/issue/工单正文、文档、记忆文件、第三方消息一律**正常行文**——写给人看的产物不压缩。
8. **强度分级**：lite（去填充，完整句）/ full（默认，去冠词+片断）/ ultra（去连接词、一词尽意、每事实只说一次）/ wenyan-lite/full/ultra（文言文，80-90% 字符缩减）；模式持久直到显式关闭。

**实测口径（诚实数字，显著区别于营销）**：README 标注 10 例基准平均输出 token **−65%**（1214→294）；但 `docs/HONEST-NUMBERS.md` 明言：技能**只压输出 token**，输入/推理 token 不动，且每 turn 固定注入 ~1–1.5k 输入 token；已极简的工作负载可**净负**（issue #145/#506/#550 记录）；官方立场是「A/B 净负就关掉」，并自建三臂 eval（baseline / "Answer concisely." / skill）主张**诚实差量 = skill vs terse**，防把通用简洁误算作 skill 收益。

## 2. 文件逐条归纳 + 关键原文摘录

### 2.1 根级文档
| 文件 | 内容 | 关键摘录 |
|---|---|---|
| `README.md` | 产品首页；双产品（输入代理 BSL/输出 skill MIT）；10 例基准表；诚实数字警告 | "why use many token when few do trick"；"Original skill made agents say less. Caveman 2 makes them read less too."；"**Honest number warning.** The skill only shrinks **output** tokens… already-terse workloads can go net-negative." |
| `CLAUDE.md` | 维护者指令（单源文件表、hooks、eval、benchmark 纪律） | "Benchmark numbers from real runs… Never invent or round."；"Readability check before any README commit: would non-programmer understand + install within 60 seconds?"；单源文件表：`skills/caveman/SKILL.md` 是行为唯一编辑点 |
| `AGENTS.md` / `GEMINI.md` | 自动发现入口；路由声明；内联 `@./skills/...SKILL.md` 引用 | "Read `CLAUDE.md` before repository work." |
| `LICENSE` / `LICENSE.BSL` / `LICENSING.md` / `TRADEMARKS.md` | 双轨许可细则 + 商标政策 | 见 §4 license |
| `evals/README.md` | 三臂 eval 方法论 | "honest delta is **`<skill>` vs `__terse__`**… Comparing a skill to the no-system-prompt baseline conflates the skill with the generic terseness ask" |

### 2.2 skills/（核心指令族，全部 MIT）
| 文件 | 定位 | 关键原文 |
|---|---|---|
| `skills/caveman/SKILL.md` | 主技能全文（90 行，~5KB）——行为唯一单源 | 见 §1 规则全量；Not/Yes 对比："Not: 'Sure! I'd be happy to help you with that…'"；"Yes: 'Bug in auth middleware. Token expiry check use `<` not `<=`. Fix:'"；"Never ADD word to sound caveman. Compression only style never grow output." |
| `skills/cavecrew/SKILL.md` | **子代理委派决策指南**（何时生 investigator/builder/reviewer） | "**if you'd want the subagent's output in 1/3 the tokens, pick cavecrew. If you'd want prose, pick vanilla.**"；"Subagent tool results get injected into main context verbatim… ~2k tokens of prose… same finding returns ~700 tokens." |
| `agents/cavecrew-investigator.md` | 只读定位子代理（haiku）| 输出契约 `path:line — symbol — ≤6 word note`；分组头 Defs/Refs/Callers/Tests/Imports/Sites；零命中 `No match.`；拒绝线："Asked to fix → `Read-only. Spawn cavecrew-builder.`" |
| `agents/cavecrew-builder.md` | 外科手术式 1-2 文件编辑子代理；**3+ 文件硬拒** | 回执 `path:line-range — change ≤10 words. verified: re-read OK|mismatch`；终态拒绝词："too-big: split <n>." / "needs-confirm: op <cmd>." / "ambiguous: ask …." / "regressed: revert …."；"Diff is the artifact. Receipt is the proof. No exploration story." |
| `agents/cavecrew-reviewer.md` | diff/文件审查子代理 | `path:line: 🚩severity: problem. fix.` + `totals: 1🔴 1🟡 1❓`；零发现 `No issues.`；"Review only what's in front of you. No 'while we're here'." |
| `skills/caveman-compress/SKILL.md` | 记忆文件（CLAUDE.md/todo/prefs）压缩为 caveman 格式省输入 token | 删除清单（冠词/填充/连接 fluff）与"Preserve EXACTLY"清单（代码块/URL/路径/命令/术语/数字/env 变量）；混合文件只压散文区；原文件备份到**树外**数据目录防自动重载 |
| `skills/caveman-commit/SKILL.md` | 压缩式 Conventional Commit（≤50 字 subject） | "**Why over what.**"；body 仅当 why 不明显/破坏性/迁移/回滚；禁 "This commit does X"、"As requested by…"、AI 署名 |
| `skills/caveman-review/SKILL.md` | 一行式评审评论 | `L42: 🔴 bug: user can be null after .find(). Add guard before .email.`；禁 "I noticed that…"/"Great work!"；安全/CVE 类、架构分歧、新手语境切正常段落 |
| `skills/caveman-help/SKILL.md` | 一屏速查卡 | 模式/技能/关闭语/语言规则/默认模式配置解析（env > config > full） |
| `skills/caveman-stats/SKILL.md` | 会话 token 实测（hook 注入，非模型自算） | "Est. rule overhead… default 1,250 tokens/turn"；净负时明说并建议关掉 |
| `skills/{caveman-setup,caveman-discover,caveman-learn,caveman-manage,caveman-optimize,caveman-explore,caveman-evidence-review}` | Caveman Cloud/引擎驱动族（读证据、不改动、consent-gated） | caveman-learn："You never claim a saving you have not measured, and you never make the agent dumber." |
| `skills/{investigate-first,lean-build,surgical-patch,safe-refactor,migration,verify-and-stop}/SKILL.md` | **token 纪律工作模式**（16-18 行骨干，故意不贴牌） | 见下 2.2 子节 |

**工作模式 skill 全文级要点**（每个都是「验证序列 + 最窄改动 + 显式停止条件」）：
- `investigate-first`：先取证后改码；区分症状与推断原因；假设按证据与证伪成本排序；"Do not edit until one credible mechanism explains evidence."
- `surgical-patch`：先复现失败；改**拥有错误行为的狭义层**；不动无关行为；"Stop when failure is fixed and regression proof passes."
- `lean-build`：可观察验收 + 显式 non-goals；"Omit modes, providers, config, extensibility, and polish unless acceptance needs them."
- `safe-refactor`：先定行为保持边界与验证再动结构；"Move one ownership boundary at a time."
- `migration`：先绘读者/写者/兼容窗口；前向+回滚双路径；"Sequence expand, migrate, verify, then contract."
- `verify-and-stop`：验收转最小充分证明集；"Stop immediately when acceptance proof is complete."；区分 pass/fail/unavailable/blocked 四态。

### 2.3 commands/、src/、dist/
- `commands/caveman.toml`（Codex/Gemini stub）：切换级别指令全文："Respond terse like smart caveman — drop articles, filler, pleasantries. Fragments OK. Technical terms exact."
- `src/rules/caveman-activate.md`：always-on 激活规则体（唯一单源，`caveman-init` 写进 Cursor/Windsurf/Cline/Copilot/AGENTS.md）——即 §1 规则 8 行的压缩版，含 sentinel "Respond terse like smart caveman"。
- `src/hooks/caveman-parse.js`：`/caveman` 解析器；`caveman-mode-tracker.js` 支持自然语言触发（"talk like caveman"/"stop caveman"）；`caveman-config.js` 提供安全写旗标（symlink 拒绝 + O_NOFOLLOW + 0600 + 原子 rename）。
- `dist/caveman.skill`：skills/caveman 的发行 ZIP（4.7KB）。

### 2.4 engine/、proxy/、docs/technical/（BSL 引擎侧，读结构）
- `engine/CLAUDE.md`/`AGENTS.md`：内容感知压缩引擎（detect→route→compress→ratio→CCR 恢复）；S0-S4 安全分级 **fail-closed**；结果永远标 `inferred`、从不 `verified`；「诚实不变量（correctness, not style）」。
- `docs/technical/architecture.md`：本地运行时 = 小进程集合（CLI/proxy/engine/MCP/mem/browse/shrink），"Each process owns one boundary so failure can fall back without inventing a result."

## 3. 对 dsh-codepunk 的适配点

> 标注：【事实】= 仓库原文/实测可证；【推断】= 由事实向 dsh-codepunk 的迁移判断，需工程主责审核。

**建议 1（子代理输出契约前置）【事实→推断】**
【事实】cavecrew 三个子代理的 persona 第一屏就是**结构化输出契约**（`path:line — symbol — note`、totals 行、verifiable receipt）+ **终态拒绝词**（too-big/needs-confirm/ambiguous/regressed/Read-only.）。
【推断】dsh 三人小组（squad-lead/engineer/sdet）的 persona 可增「输出契约 + 终态拒绝词」段：sdet 的证据回报除现有 `command+exit_code+log_ref` 外，补 `scope-too-big / needs-confirm / ambiguous / evidence-missing` 四态拒绝线，把「能力边界显式化」写进人设而非靠临场判断——减少空转轮次，呼应 D066/D067 的 checkpoint 语义（每轮产出恒可解析）。

**建议 2（Auto-Clarity 压缩豁免场景）【事实→推断】**
【事实】caveman 明列退出极简的场景：安全警告、不可逆操作、多步歧义、用户困惑；且 `Auto-Clarity` 从 SKILL.md 贯穿到三个子代理（"write normal English warning, then resume caveman"）。
【推断】dsh 消息纪律（D075「安全先于简洁」）可从"原则"升格为**显式场景表**：破坏性命令、迁移、删表、force push、跨 chunk 冲突等消息禁用精简模板、必须完整行文；危险操作后恢复简报级别。不产生冲突，是 D075 第④条的细化落地。

**建议 3（零节省缩写的 token 经济学）【事实→推断】**
【事实】caveman 明确禁用自造缩写（cfg/impl/req/res/fn）与箭头（→）：tokenizer 拆分后零节省且伤解码；"never invent new abbreviations (cfg/impl/req/res/fn) tokenizer split them same as full word: zero token saved, reader still decode."
【推断】dsh 的 R11/D075「禁前导/复述/寒暄」可加第 6 条「**禁自造缩写与箭头**」——中文语境注意：中文短词（如"工单/验收"）本身即单 token，不受影响；英文简报/evidence 字段禁用 cfg/impl 类缩写。这是对现有纪律的**增量细则**，非重复。

**建议 4（16-18 行工作模式 = 岗位级"验证序列+停止条件"）【事实→推断】**
【事实】investigate-first/surgical-patch/lean-build/safe-refactor/migration/verify-and-stop 六个模式每个都是 16-18 行骨干：先取证→最窄层改动→显式停止条件，"Stop when…"，"Omit…unless acceptance needs them"，"Separate observed symptom from inferred cause"。
【推断】dsh 各岗位 persona 的「工作流」小节可仿此精简为「验证序列 + 停止条件」两段（engineer：读→改→重读 verify→停；sdet：验收=最小充分证明→停；squad-lead：巡检只读 summary→停），并把"Stop when"写成人设硬约束而非软建议——与既有 references/roles.md 的三三制/交接职责互补，不重复。

**建议 5（诚实数字与"净负即关"的度量纪律）【事实→推断】**
【事实】HONEST-NUMBERS 明示：skill 每 turn 固定开销 ~1-1.5k 输入 token；实测记录三个净负案例（#145/#506/#550）；官方建议"A/B 净负就关掉"；evals 三臂法把差量锚在"vs 普通简洁指令"防作弊。
【推断】若 dsh 后续把 caveman 式规则引入预设（如简报 ≤N token），必须先定义**节省口径与回退条件**：对比基线是"无该规则"，而非"长篇模板"；超过固定开销时自动降级。此条呼应既有 `prompt-context-compression.md`（D074 来源），属机制验证而非内容照搬。

**建议 6（持久化产物豁免 = 形式与内容分层）【事实→推断】**
【事实】Boundaries 规则：代码/注释/commit/PR/issue/文档/记忆文件写**正常行文**；压缩只作用于对话流。
【推断】dsh 已有隐含分层（小组口头汇报精简、产物如 brief/handoff/scores 完整行文），建议**显式写进纪律**：`progress/` 汇报可精简，`handoff/*.md`、`brief/`、`scores.yaml` 等正式产物禁止碎片化——防止 token 纪律从对话漂移污染交付物。与 D074「明细留工作房、向上只回摘要」方向一致，是边界澄清。

**建议 7（规则密度上限：SKILL.md 本身就是 token 设计）【事实→推断】**
【事实】主 SKILL.md 90 行/~5KB 承载全部规则；README（给人看）与 SKILL.md（给模型看）**分离**；"Preserve voice… Don't normalize."；单源文件表明确「行为唯一编辑点」。
【推断】dsh 子 skill 目标 <200 词（既有 agent-skills 调研建议）与 caveman 的 ~5KB 主规则密度并不矛盾：caveman 靠"规则密度 + 分级"而非篇幅控制注入成本。可作为 dsh 后续 skill 化的密度对标上限：承重规则留正文、解释/示例进 references（正文预算 D074 已执行）。

**建议 8（强度分级 + 语言保护）【事实→推断】**
【事实】lite→full→ultra 分级 + wenyan 中文模式；"Compress the style, not the language"——按用户语言回复，技术词逐字保留。
【推断】dsh 汇报可引入**轻量分级**：常规巡检=无填充完整句（lite）；长流程推进=允许片断（full）；正式评审/涉及语义细节=完整行文（Auto-Clarity）。中文语境下 wenyan 文言文模式**不建议**采用（token 化差异、可读性风险），仅保留其"语言保护"原则。

### 3.1 与 D074 / D075 的关系判定

| 纪律 | 关系 | 论证 |
|---|---|---|
| D074 上下文纪律（证据只回 command+exit_code+log_ref；汇报 ≤1500 token；明细留工作房） | **互补（强）** | 同构：cavecrew 输出契约即「最小机器可读产物回注主上下文，--60% 体积」的实证版；D074 缺的是**契约前置与终态拒绝词**——建议 1/4 补齐 |
| D075 消息纪律（首行=可执行结论；编号≤5；禁复述寒暄；安全先于简洁；防调试空转） | **互补（中强），无冲突** | caveman 的 Not/Yes 范式、无工具旁白、Auto-Clarity、净负即关，分别与 D075 的第①③④条同源；增量在建议 2/3 的「场景表 + 零节省缩写」细则；唯一分歧点：caveman 允许碎片句，dsh 全体中文纪律下建议限定于非正式汇报，无实冲突 |
| 与现有「语言纪律 R11」 | 重复项 | R11 已含「简洁、无废话、禁前导复述寒暄」；caveman 补充的是**量化依据**（为什么禁缩写/箭头）与**豁免边界**（持久化产物、安全场景），不新增规则位 |

### 3.2 license 可复用性（重点）

- **双轨许可**：`skills/`、`agents/`、`commands/`、`evals/`、SDK、CLI、contracts、provider catalog、extension shell、mem 薄客户端 = **MIT**（可自由复用、改写，须保留版权声明）；`engine/`、`proxy/`、`cacheengine/`、`rewriter/`、`browse/`、`mcp/`、`shrink/`、mem Go 核心、`shared/platform/` = **BSL-1.1**（source-available；Additional Use Grant 允许自用/自托管第一方流量含生产；第三方托管/托管/嵌入服务需商业许可；**2030-06-21 或各版本发布 4 年后转 Apache-2.0**）。
- **对 dsh-codepunk**：【事实】规则文本（SKILL.md/子代理 persona/工作模式）在 MIT 域，可直接借鉴改写为 dsh 纪律，须标注来源与保留版权声明（MIT 要求 copies/substantial portions 附带许可声明）；【事实】BSL 引擎代码不可复制，但 dsh-codepunk 现做法本就是「理念借鉴、不涉及代码抄袭」（benchmark note），无冲突；【推断】若未来 dsh 想直接引用其 SKILL.md 原文段落做内置规则，应把来源 URL + license 注记写入 references/standard.md 决策号出处（或 references/learned-skills.md 溯源表）。
- 商标： "Caveman" 属 Julius Brussee，dsh 使用其规则思想不构成商标使用，但**不得在产品名/预设名中冒充 Caveman 官方**。

## 4. 引用留痕（全部 retrieved_at = 2026-08-25T19:29:20Z，除非另注）

- 仓库元数据：https://api.github.com/repos/JuliusBrussee/caveman
- 文件树：https://api.github.com/repos/JuliusBrussee/caveman/git/trees/HEAD?recursive=1
- raw 正文（base https://raw.githubusercontent.com/JuliusBrussee/caveman/main/）：
  - README.md、CLAUDE.md、AGENTS.md、LICENSE、LICENSE.BSL、LICENSING.md、TRADEMARKS.md、evals/README.md、evals/prompts/en.txt
  - skills/caveman/SKILL.md、skills/caveman/README.md、skills/cavecrew/SKILL.md、skills/caveman-compress/SKILL.md、skills/caveman-commit/SKILL.md、skills/caveman-review/SKILL.md、skills/caveman-help/SKILL.md、skills/caveman-stats/SKILL.md、skills/{investigate-first,lean-build,surgical-patch,safe-refactor,migration,verify-and-stop}/SKILL.md、skills/{caveman-setup,caveman-discover,caveman-learn,caveman-manage,caveman-optimize,caveman-explore,caveman-evidence-review}/SKILL.md
  - agents/cavecrew-investigator.md、agents/cavecrew-builder.md、agents/cavecrew-reviewer.md
  - commands/caveman.toml、commands/caveman-init.md、src/rules/caveman-activate.md、src/hooks/caveman-parse.js、dist/caveman.skill
  - engine/CLAUDE.md、engine/AGENTS.md、docs/technical/architecture.md、docs/HONEST-NUMBERS.md
- 交叉引用（既有调研）：../benchmarks/agent-skills-open-source-benchmark.md（caveman 99,107★ 记录，retrieved_at=2026-08-19）、../benchmarks/prompt-context-compression.md（D074 来源）、../benchmarks/adhd-workflow-analysis.md（D075 来源）
- 未抓取（仅元数据可见）：https://caveman.so/、https://star-history.com/#JuliusBrussee/caveman&Date

## 5. 结论摘要

1. 【事实】caveman 是 10 万星、双轨许可（skill MIT / engine BSL-1.1）的「输出极简 + 输入压缩」生态；其可复用资产是**显式规则集**（删除/禁止/保护三清单 + Auto-Clarity 豁免 + 持久化边界 + 强度分级）。
2. 【事实】核心检证：输出 token 平均 −65%（README 基准表）；但只压输出、每 turn 固定 +1–1.5k 输入、已极简负载可净负（官方诚实声明）。
3. 【推断】对 dsh-codepunk 的 TOP 适配：①子代理输出契约+终态拒绝词（补 D074）；②Auto-Clarity 豁免场景表（补 D075④）；③禁自造缩写/箭头细则（补 R11/D075）；④16-18 行"验证序列+停止条件"工作模式（强化岗位人设）；⑤"净负即关"度量纪律（防为省而省）；⑥持久化产物豁免分层；⑦~5KB 规则密度对标；⑧轻量分级 + 语言保护（弃文言模式）。
4. 【事实】与 D074/D075 基本**互补、无冲突**；只与 R11「简洁」有一处覆盖关系（caveman 提供量化依据与豁免边界，不新增规则位）。
5. 【事实】license：规则文本 MIT 可直接借鉴改写（保留来源与版权声明）；引擎 BSL 仅作理念借鉴，与 dsh 既有基准做法一致。