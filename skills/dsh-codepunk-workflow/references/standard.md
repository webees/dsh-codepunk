# 标号总表（references/standard.md）

本栏目的 `Pxx` / `D0xx` 是流程**内部稳定标签**：用于跨文档引用而不重复正文。
它们不是外部规范的编号 —— 本文件是它们的**唯一权威释义**。

## 阶段号（P01–P17，预留号段，只登记在用项）

| 标号 | 含义 | 正文位置 |
|---|---|---|
| P01 | ① 需求确认 | SKILL.md §2 ① |
| P02–P04 | ② 规划与组队（分块 / 简报 / 用工） | SKILL.md §2 ② |
| P05–P06 | ③ 多小组并行开发 | SKILL.md §2 ③ |
| P06（复用） | ⑥ 再规划入口（♻️） | SKILL.md §2 ⑥ |
| P07 | ④ 巡检与交接（并覆盖 ⑤ 解散的开头） | SKILL.md §2 ④ / §2 ⑤ |
| P10 | ⑤ 后段·合并门（串行） | SKILL.md §2 ⑤ |
| P11 | 记忆简报（文档小组 → 工程主责） | references/artifacts.md「记忆简报」 |
| P14 | 强制解散（外因超时 / 失败，先保存 WIP） | SKILL.md §5 失败处理 |
| P16 | ⑤ 解散与评分（人事） | SKILL.md §2 ⑤ / references/knowledge.md 评分公式 |

> 编号按语义复用（如 P06 既指并行开发也指再规划入口），**以正文位置为准**，
> 不在正文之外单独定义流程。未登记号段即预留，不暗示存在。

## 决策号（D0xx，预留号段，只登记在用项）

> 与阶段号同理：号段不连续（历史演进中部分号未启用或已合并），**缺号不代表遗漏**；
> 判定引用是否有效只看本表是否登记该号。新增决策必须先在此登记，再在其它文件引用。

| 标号 | 一句话含义 | 出处 |
|---|---|---|
| D024 | 并行软上限：S=1 / M=3 / L=6（本预设自律上限，非平台字段） | SKILL.md §2 ③ |
| D031 | 双门闩齐即自动开工，不必再等人工点头 | SKILL.md §2 ③ |
| D034 | goal active 前 `product_acceptance[]` 必须非空 | SKILL.md §2 ① / artifacts.md |
| D035 | sponsor 通道与 goal 终裁/确认记时归工程主责（`user_confirmed_at`） | SKILL.md §2 ① / agent.cordis.yml |
| D038 | 需求变更只走 `change_orders`（proposed→applied→closed） | SKILL.md §3 R6 / artifacts.md |
| D065 | sponsor 可随时投喂信息，按类分诊并入 | SKILL.md §2 ① |
| D066 | goal 自动续行/自动递送：create 即 armed、idle 自动唤醒消化排队消息、resume/fork 后需 resume 重武装、maxGoalRounds 为轮次预算 | SKILL.md §0.1 / R10 |
| D067 | checkpoint 断点续行：progress/handoff/evidence/工作房即可重放状态，中断后从最近断点精确续行，不整轮重来（借鉴 LangGraph durable execution） | SKILL.md §2 ③ |
| D068 | 门禁即显式节点 + 双侧 guardrail：双门闩/审查门/合并门入口验输入、出口验输出，不合格回退不滑入下一阶段（借鉴 crewAI Flow / ADK tool confirmation，开源基准） | SKILL.md §2 ④ |
| D069 | schema 强约束：evidence/acceptance 结构生成期保证机器可校验，校验不合格直接回退（借鉴 outlines / agentskills） | references/artifacts.md evidence.yaml 段内说明 |
| D070 | 硬信号驱动评分-再规划 + 经验→skill 沉淀回路：评分/再规划以证据文件事实为准，经验模板沉淀至 knowledge/lessons/（借鉴 CAMEL / ChatDev / graphify） | references/knowledge.md「硬信号驱动评分-再规划」 |
| D071 | 委托契约：每席显式声明「单轮受控输出 vs 多轮任务」，双侧 guardrail 校验（借鉴 ADK Task API / Swarm handoff） | references/roles.md「委托契约」 |
| D072 | 总库语义：运行根统一存 `~/.dsh-codepunk/projects/<id>/`，工程目录保持纯净；开工五件事（resolve → source dsh-codepunk-home.sh → 建运行根〔含 ③′ 运行根 `README.md` 的 `write_scope:` 台账，R17〕→ 启动自检 D094 → 定时巡检 D095） | SKILL.md §1.1 |
| D073 | worktree 生命周期回收（**release-eng** 执行；run-lead 于 goal complete 前核验）：合并完成即 `worktree remove --force + prune`（分支 refs 保留审计）；goal complete 前 MUST 核验 `worktree list` 仅主仓库（环境终态整洁是验收项） | SKILL.md §2 ⑤ P10.5 / §2 ⑥.4 |
| D074 | 上下文纪律：证据只回 command+exit_code+log_ref（拒绝整段 stdout）；子代理汇报 ≤1500 token 摘要；主会话每轮压缩旧巡检记录防上下文堆积（借鉴 Anthropic 上下文工程） | SKILL.md §2 ④ / agent.cordis.yml 三席人设 |
| D075 | 消息层纪律：首行=可执行结论+首末行双读验证；多步编号≤5+工具清单替叙事；禁前导/复述/寒暄；安全先于简洁；调试螺旋防空转（借鉴 ayghri/i-have-adhd，MIT） | SKILL.md §2 ④ / benchmarks/adhd-workflow-analysis.md |
| D076 | token 经济学细则：禁自造缩写与箭头；保护清单逐字保留（术语/代码/数字/否定词）；Auto-Clarity 豁免场景；持久化产物完整行文；压缩风格不压缩语言（借鉴 juliusbrussee/caveman，MIT） | SKILL.md §2 ④ / benchmarks/caveman-analysis.md |
| D077 | 反幻觉纪律：完成断言须新鲜验证证据（Iron Law）；不确定即明示（不编造来源、无引文即撤回）；知识冲突显式化；证据门控交付；sdet 防空壳绿；多智能体交叉验证（借鉴 superpowers vbc / Anthropic 防幻觉，细则见 references/anti-hallucination-rules.md） | SKILL.md §2 ④ / references/anti-hallucination-rules.md |
| D078 | 模型路由与成本杠杆：全岗位统一 flash 档（现行型号见 **D087**，档位纪律承自 D080 禁 pro/max）；agentOptions 显式声明；错峰调度半价；cache 前缀稳定性优先；reasoning_tokens 可归因；maxTokens 自配防溢出（**声明口径 2026-10-05 更新**：路由默认继承父会话，`agentOptions` 仅在需覆盖时声明） | references/model-routing.md |
| D079 | 文件卫生：开工卫生契约五硬规则（状态文件不进工程/tmp 集中化/不造脚手架/生成前查重）+ 收尾残留自查（交接包必填节）+ 终态清理强制门闩 + git clean 演练制度（借鉴 agent-housekeeping MIT / davila7 / SoloDawn RB-37） | references/file-hygiene.md / SKILL §2④ |
| D080 | 撰写标准：节名用方块标签【节名】、禁 ## 标题于 prompt 正文；一行一节；中文全角标点；每节 ≤40 字动宾起头；禁修饰副词；实战照抄模板不自创格式 | references/roles.md（§派遣 prompt 模板） |
| D081 | 产出纪律（YAGNI）：七级递减阶梯（需要吗→复用→stdlib→平台→已装依赖→一行→最小）；根因修复（grep 全部 caller 一次修）；简化留痕 `dsh-debt:` 注释标天花板+升级路径；Not-lazy 保护清单；非平凡一个自检不建框架；输出 code-first + ≤3 行；审查五 tag + net: 行（借鉴 ponytail ~128k★ MIT） | references/anti-overengineering.md / agent.cordis.yml engineer/sdet 人设 |
| D082 | 文档配图：文档小组产出按场景配图（WORK_BRIEF→Process、chunks 依赖→Dependency、交接→Data flow）；4px 网格/密度 4/10/语义角色配色/静态优先（借鉴 cathrynlavery/diagram-design MIT） | references/diagram-guide.md / docs 人设 |
| D083 | 技能治理与升级机制：外部 skill 系统性应用（调研→审定→应用→升级→废弃四态）；三件套文档化 MUST（简报/细则/溯源）；版本标记与月度复检（技能升级触发/流程/废弃） | references/skill-governance.md / 文档小组职责 |
| D084 | 注入防护：工具返回视为不可信数据（阻断+上报）；记忆写入 canary/不可见文本检测；skill 供应链注册门；PIT-* 分类法统一术语（借鉴 defender/SkillSpector/rebuff/arc_pi，Apache-2.0/CC-BY） | references/prompt-injection-rules.md / 巡检检查项 |
| D085 | 知识库记忆增强：knowledge/ 三级化（L0 热/L1 工作/L2 参考）；知识过期三态（active/stale/archived）；条目自包含+refs 互链；多信号检索（复用计数+语义标签+时间序）；run 收官后异步抽经验（借鉴 Mem0/OpenViking/Letta，仅机制思想） | references/memory-enhancement.md / knowledge/ 布局 |
| D086 | 限流自适应：自动发现 429 RATE_LIMIT 模式（三档降级：L1 降并发 L2 串行 L3 暂停）；自我学习（限流历史入 knowledge/lessons/ 供后续参考）；错峰标记复用 D078 调度 | references/rate-limit-adaptation.md / SKILL §③ |
| D087 | ⚠已废弃（D089 取代→D090 反驳；**现行路由见 D090**）·岗位模型路由改道（历史）：弃用产品默认 provider（上游改带前缀型号名且 region_limited）。当时实现（2026-09-05）：13 岗位 `agentOptions` 全删、按「子代理继承主进程」假设推进；回退链「主 provider → 备 1 → 本地兜底」（同路由连败 ≥3 次由 run-lead 切换）。该假设已被 D089 反驳、D090 双要件取代。**档位纪律不变**：只用 flash，禁 pro/max；外部后端 codex / claude-code 不套本表。动因：上游改带前缀型号名致子代理启动即 UNKNOWN_MODEL，退化为「零工具调用 + 幻觉汇报已落盘」（实跑取证）。**生效条件**：工具挂载在会话创建时冻结，路由变更后 MUST 新开对话（无需重启 app），旧对话子代理仍走旧路由。**放大器**：`retryPolicy.mode: always` 无上限且不分错误类型，永久 400 被无限重试成死锁（现默认 always＋回退对冲，见 D089/D086）。回滚先跑最小探针验证 | agent.cordis.yml / references/model-routing.md §五 §六 |
| D088 | 子代理可恢复性：13 岗位全部 `backgroundMode: continuable`（外部后端 subagent_codex / subagent_claude_code 刻意保留 one-shot + enableRunInBackground:false）。动因=一次实跑：one-shot 记录被 429 打断后**无法续聊也无法分支**（平台只允许从已完成轮的最后一条消息分支），整轮取证报废、只能从零重跑，是评分循环返工的首要根因。配套纪律：评审轮一律用可持续会话，回报必须附 `git log`/`git status` 真实输出 | agent.cordis.yml / benchmarks/preset-tool-fixes.md F-003 |
| D089 | ⚠已被 D090 反驳（原依据「实测孩子不继承主模型」**已于 2026-10-05 反转**，见 D090 行注）·模型统一与回退机制：子代理全链路继承主进程模型（删除岗位 agentOptions 自声明）；三级回退链「主 provider → 备 1 → 本地兜底」；持续失败（≥3 次）run-lead 裁决切换（harness 无原生 fallback，流程层实现） | references/model-fallback.md / settings agent-default-model |
| D090 | 子代理路由与可恢复性双要件：**必须同时**显式 `agentOptions: {provider: <PROVIDER>, model: <MODEL>}` + `backgroundMode: continuable`（13 岗位全覆盖）。依据两条实测反驳：① 删 agentOptions 后孩子**不继承**主会话模型，而落**产品默认模型**；② one-shot 记录被 429 打断后既不能续聊也不能分支，整轮取证报废。`subagent_codex` / `subagent_claude_code` 为外部后端，两项均不适用。 （**前提已反转（2026-10-05 实测）**：现行构建下子代理**默认继承父会话实时路由**，故「必须显式 `agentOptions`」不再成立——`agentOptions` 仅在需覆盖时声明；仅 `backgroundMode: continuable` 部分仍必需（D088）。历史依据①「删 agentOptions 致不继承」属旧构建结论，②「one-shot 被 429 打断后不可续聊」仍成立。现行口径见 model-routing §现行事实）改 `agent.cordis.yml` **须重启 DSH Desktop** 生效（新开对话不重读插件配置，已实测否证） | agent.cordis.yml / references/model-routing.md §五 / benchmarks/preset-tool-fixes.md F-004；⚠ **前提已反转（2026-10-05 实测）**：0.2.0-rc.2 的 `resolveChildAgentOptions` 以父路由为基底（继承 provider/model/reasoningEffort/maxTokens，除非请求覆盖），故 agentOptions 由「必配」改为「按需偏离」；仅 `continuable` 部分仍必需（D088）。详见 references/model-routing.md §五
| D091 | 泄露防护门（推送前守卫）：**机制进仓库、禁词留本地**——守卫脚本自身不得含私人词（守卫即泄露源的教训）；禁词从 `~/.dsh-codepunk/denylist.txt` / 环境变量 / `.leak-denylist` 载入，通用模式（绝对路径/私网/凭据/邮箱）可进仓库。扫索引（pre-commit）/工作树/近 20 提交（pre-push），命中即阻断（退出码 1，`--no-verify` 绕过须留痕）。根因：`git push --force` 只移分支指针，服务端旧对象仍可经公开 Events API 枚举 SHA 后 raw 直链读取——唯一可靠补救是删库重建 | plans/dsh-codepunk-leak-guard.sh / references/file-hygiene.md §一.7 |
| D092 | 输出卫生：加粗必须配对（禁 3+ 连续星号）；禁 emoji 装饰与符号箭头；禁伪标题堆叠。动因：实测子代理输出 `**` 奇数（121 个）+ 连续 `****`，客户端 markdown 解析失败整段降级为源码显示 | references/output-discipline.md §输出卫生 / 全员 persona |
| D093 | 任务收口与子代理任务边界：①思考层禁复述执行意图；②单席超 100 轮未交付即上报请求拆分，禁无限续行空转；③大目标 MUST 拆分（单 chunk 50 轮内可收敛）；④**子代理 MUST NOT 承载循环型目标**（收敛到连续 N 轮/反复迭代到达标），此类目标由主会话按轮驱动，每轮只派单次可收敛任务 | references/output-discipline.md §任务收口与子代理任务边界 / SKILL R11、R15 / 全员 persona |
| D094 | 启动自检与子代理恢复：客户端意外关闭会中断子代理；主进程每次启动 MUST 执行「查（`list_agents(scope=descendants)` 列状态）→ 比（对照运行根 README 的 spawn 登记表，找登记 active 但已非 running 的中断席）→ 续（读工作房 `progress/`、`handoff/`、`evidence.yaml` 定位断点，`send_message` 精确续行，不重跑不重复 spawn）」。前置：子代理 MUST 为 `backgroundMode: continuable`（一次性子代理不可恢复，D088）；登记表 MUST 每 spawn 即写（否则无从比对） | SKILL §1.1 第 4 条 / references/stages.md §③ / agent.cordis.yml |
| D095 | 定时巡检与子代理状态清单：仅启动自检不够，新开对话与长任务中途周期性巡检防失联。独立 YAML 状态清单 `runs/<run_id>/agents.yaml`（模板见 `references/artifacts.md`），与 README 登记表双写一致，每次巡检后刷新。每次执行「查→比→续→写」闭环：`list_agents` 实测态 → 对清单找 `expected: active` 但非 running 的中断席 → 读断点 `send_message` 续行 → 写回 `status`/`last_seen`/`last_checkpoint_at`/`note`；`status: done` 跳过。节奏：启动一次 + 每 5 轮一次 + 失败结算加跑 | SKILL §1.1 第 5 条 / references/artifacts.md「子代理状态清单」 / references/stages.md §③ |
| D096 | 持久 shell 与工具调用超时：在 `persistent-shell` 隔离域内同挂 `dsh-terminal` + `dsh-terminal-bash` + `dsh-tool-bash-persistent`（Windows 同构 pwsh），由 scope 遮蔽 dsh-base 的全局 `tool-bash`/`tool-pwsh`，官方 minimal 同款接线；`timeoutMs` 300000，残留 TOOL_TIMEOUT 由调用方判超时重试或人工介入。`dsh-tool-call-timeout-policy` 全局生效不开单独配置——凡声明 `timeoutMs` 的工具超时自动返回 TOOL_TIMEOUT，run-lead 见之按 brief 重试或拆小任务（不静默丢） | SKILL §4 / agent.cordis.yml |
| D097 | 审计优化循环的机械化门：把「文档/配置/脚本/流程」的一致性检查尽量机械化，并以**存活自检**（注入缺陷 → 断言必须报错）保证检查不会静默失效；人工仅保留语义类判断。动因：164 轮循环中 4 次「守护静默变绿」（F097/F133→F134/F147/F148）**全部由负向探针在提交前抓出**；并沉淀「判据不得自证」（上界须外部、定义文件不算引用、期望串不得与标题同名、禁字面捕获） | references/skill-governance.md §新检查入库清单 / plans/verify-battery.sh |
| D098 | 写盘纪律三层强制（机械门 + 硬规则 + 岗位写域）：AI 只可写「运行根 / 授权工作树任务路径 / 系统临时目录（次选，用毕即删）/ 总库 `knowledge/`」；探针脚本 MUST 落运行根 `logs/`；严禁在工程仓库工作树、`$HOME` 顶层、系统目录落临时物，越界即缺陷且当轮清理（机械门 `plans/write-scope-check.sh`，exit 0 通过 / 1 越界 / 2 无法核验）；细则见 references/file-hygiene.md / references/roles.md | SKILL R17（写盘纪律）；references/file-hygiene.md §六；references/roles.md 各岗位写域 |
| D099 | 机器可读状态清单的写入约束：运行根 `agents.yaml` 等被机械解析的文件，写入后 MUST 用解析器回读校验（`ruby -ryaml -e 'YAML.load_file(...)'`）并比对关键字段长度；自由文本值内裸半角冒号加空格 ⇒ 语法错误（整文件不可解析），空格加半角井号 ⇒ 值被当注释静默截断（实证：同一条 `result` 源 536 字 → 解析 325 字），须改全角或加引号；**行存在 ≠ 可解析**，grep 不得充当校验 | references/artifacts.md §1.2 写入约束；skills/dsh-codepunk-workflow/references/file-hygiene.md §六 |
| D100 | 门禁的**解析依赖预检**（MUST）：判据的抽取/计数/归一管道依赖外部命令（`awk`/`sed`/`grep`/`cut`/`tr`/`cksum`/`mktemp` 等）时，缺失 MUST 判「无法核验 ≠ 通过」（rc=2 且说明缺哪个命令），**绝不静默降级为通过**；`command -v` 预检只覆盖「命令不存在」，故对「命令在但管道被改坏/被别名遮蔽」MUST 另加**不变量**断言（源非空而归一后为空 ⇒ rc=2）；诊断 MUST 指向真实原因（否则操作者会修错地方）。实证 F405 四实例：leak-guard 缺 awk ⇒ 25 条禁词静默归零仍报「通过（禁词 0 条）」；preset-audit B5 的 `git grep -ic … \| awk` 归零 ⇒ 报「全仓零旧名」；preset-score A2 的 `grep \| sed` 循环不执行 ⇒ 扣分项静默消失；verify-battery 的 `cksum \| awk` 双空值相等 ⇒ 报「E2E 未污染（校验和不变）」；同族诊断缺陷：write-scope-check `--run-root` 缺 awk 时报「缺 write_scope: 段」（保守但指向错误原因）；同族**环境前提**缺陷：自检缺 `node` 时 M51/M138/M139 以 rc=127 报「变异未生效」并触发终局 MUTFAIL 门 ⇒ 整轮假失败且诊断指向「自检脚本问题」（F406，已加自检依赖预检）；同族**夹具自足性**缺陷：自检 `export HOME="$SANDBOX"` 而变异夹具按真 `HOME` 预期 ⇒ 不变量在沙箱内不可达、结论随宿主漂移（F407，夹具改显式传 `DSH_CODEPUNK_DENYLIST`） | references/skill-governance.md 治理矩阵；plans/checker-self-test.sh M193；探针（运行根仓外）`tools/dep-matrix.py`（依赖缺失 × 门禁矩阵） |
| D101 | 文档中的路径引用形态（MUST）：仓库文档引用的**仓内**路径 MUST 真实存在（机械门 = `plans/doc-consistency.sh` 第 4 类，域＝**全部跟踪 `.md`**，扩展名 `sh\|py\|mjs\|cjs\|ps1`，非 git 工作区回退 `find`，空枚举判「无法核验 ≠ 通过」）；引用**仓外**产物（运行根工具/日志/名册等）时 MUST 显式标注「运行根（仓外）」且 MUST NOT 写成仓内形态（例如给仓外工具加 `plans/` 前缀）——否则公开仓读者不可解析，且门禁域或扩展名一旦漏项即长期零守护。实证 F408：`CHANGELOG.md` 曾把运行根回读工具写成 `plans/` 前缀 + `.cjs` 扩展名，而第 4 类域不含根级 md、扩展名集不含 `cjs` ⇒ 该假引用无门禁可见 | plans/doc-consistency.sh 第 4 类；plans/checker-self-test.sh M194 |
| D102 | 门禁的**覆盖率声明**（MUST）：凡「扫描 / 枚举 / 窗口」类判据（跟踪树、提交历史、名册清单）MUST 报出**实际处理数量**（文件数 / 提交数 / 条目数）；处理范围被环境截断时（浅克隆、空仓库、零枚举、替身 git）MUST 判「无法核验 ≠ 通过」（rc=2，并说明截断原因与处置），**绝不静默等同全量通过**；窗口之外未处理的部分 MUST 显式告知。实证 F409：`plans/dsh-codepunk-leak-guard.sh --history` 原只打「✓ 通过」而不报扫描提交数，浅克隆（`.git/shallow` 在场）与空仓库下扫描范围静默缩减、输出却与完整仓同形（同族对照：`tree` 模式早有「已扫描 N 个跟踪文件」+ 零输入 rc=2 ⇒ 同一门禁内两模式口径不一致） | plans/dsh-codepunk-leak-guard.sh（history 模式）；plans/checker-self-test.sh M195 |
| D103 | 重型检查器的**并发互斥**（MUST）：凡把调用方给出的路径当**可写共享资源**使用的检查器（向该路径写探针/夹具、整树复制该路径作沙箱、在其中生成中间产物）MUST 在同一资源上互斥，且判据必须是**响亮拒绝**而非静默降级：① 持锁者存活 ⇒ rc=2 并说明「另一次正在运行」与处置（并发会互相污染、结论不可归因）；② pid 已不存在（陈旧锁）⇒ 显式打印「接管陈旧锁」后继续（不得让崩溃残留永久阻塞）；③ 锁键无法派生（缺 `cksum`/`awk`，键非数字）⇒ rc=2（无法核验 ≠ 通过）；④ `ps` 缺失 ⇒ 按持有处理（fail-closed）；⑤ **拒绝路径 MUST NOT 登记释放**——否则退出钩子会误删他方锁；⑥ **不可复现 ≠ 通过**：同一配置单跑全绿、并行失败即为污染信号，须定位并发而非重跑碰运气。实证 F410：`plans/checker-self-test.sh` 把预设根当可写共享资源（密封探针写入源树、`fresh()` 整树复制）却无互斥 ⇒ 与另一次重叠的运行产出 rc=1 幻影失败（M194 三条断言拿到 doc-consistency 的 rc=2），同配置三次单跑均 195/195 rc=0 | plans/checker-self-test.sh 并发互斥块（锁键＝预设根 `cksum`，锁目录 `${TMPDIR:-/tmp}`，`--lock-echo` 钩子）；plans/checker-self-test.sh M196 |
| D104 | 机械门的**必需上下文缺失**（MUST）：判据依赖调用方给出的上下文（交付目录、名册、台账、运行根…）时，缺失 MUST 判「无法核验 ≠ 通过」（rc=2 且说明缺什么、怎么补），MUST NOT 把**环境缺口误归因为数据缺陷**；守卫 MUST 分两层（入口参数下限 + 使用点目录/文件存在性），且下游解析 MUST NOT 在缺上下文时断言「文件不存在」。实证 F412：`plans/evidence-verify.sh` 的交付目录原为可选，缺它时按**校验器自身 cwd** 解析 `log_ref` ⇒ rc=1「[ev1] log_ref 文件不存在: run.log」，而同份输出又打印「⑤ 时间序未检（未提供交付目录）」——同一份输出自相矛盾、且把「没给目录」说成「文件不存在」，读者会去查数据而不是补参数 | plans/evidence-verify.sh（参数下限 + `[ -d ]` 守卫 + python 侧纵深防御）；plans/checker-self-test.sh M197 |
| D105 | 文档**命令表用法形态**（MUST）：文档里出现的**位置式用法串**（`` `plans/X.sh <必填> [可选]` ``）其占位符**可选性 MUST 与脚本头部权威用法行逐位一致**——「必填写成可选」会让读者按文档执行必撞 rc=2，「可选写成必填」则夸大前置条件；仅占位符**名称**不同只记 ℹ（同义命名不判失败）；含 `--` 开关的提及属开关式形态，本判据不适用（须由各脚本 `-h`/README 承担）。实证 F413：`CONTRIBUTING.md` 三处与实现不符（evidence-verify 交付目录、acceptance-verify 交付方两处已必填而文档标可选；verify-battery 预设根实现可选而文档标必填），而第 4/5 类只覆盖路径存在性与退出码声明 ⇒ 用法形态长期零守护 | plans/doc-consistency.sh 第 28 类；plans/checker-self-test.sh M198 |
| D106 | 模式串的**选项分隔**（MUST）：把调用方/脚本给出的模式串交给 `grep`/`sed` 等命令时 MUST 用 `--` 与选项分隔（`grep -qE -- "$pat" "$f"`）——以 `-` 开头的模式串（例：`-lt 1 ]; then`）会被当作**选项**解析 ⇒ 命令报用法错误、匹配恒失败 ⇒ 判据把「注入已落地」误报为「未生效」（假失败，且诊断指向错误方向）。实证 F415：`plans/checker-self-test.sh` 的 `mutate` 助手缺 `--`，M197-d 的削弱型变异被判「变异未生效」并把整轮自检判失败，而同一模式串手工 `grep -qE -- …` 可正常匹配 | plans/checker-self-test.sh `mutate()`；plans/checker-self-test.sh M199 |
| D107 | 终局判据的**报告顺序**（MUST）：同一退出路径上有多条终局判据时，**因果更早者 MUST 先报**——上游前提被破坏（源树被并发改动、依赖缺失、上下文缺失）会让下游成批出现次生失败，若次生判据先报则真因被掩盖、排查被误导。实证 F416：源树在自检运行期间被并发改动 ⇒ `fresh()` 复制出语法损坏副本 ⇒ 28 条变异成批「退出码 2」，而源树密封判据排在 MUTFAIL 门之后 ⇒ 日志只给「有变异未生效（自检脚本问题）」，真因（本轮改动了源树）从未显示；且该判据自身的**锚点自引用**（判据代码里含同样的锚点串）会让行号比较失真 ⇒ 锚点 MUST 取**末次出现**并附**区间下限**（须落在文件尾部 N 行内） | plans/checker-self-test.sh 终局块（`seal_check` 先于 MUTFAIL 门）；plans/checker-self-test.sh M200 |
| 实测溯源（D093） | 47 个 10MB 以上异常会话共享同一循环型 goal（收敛到连续 5 轮），均为 dsh-codepunk 一级子代理；每会话收 400 余次自动续行、数百轮后 reasoning 退化为元话语循环；失败重派即复制该过程 | 实战取证 2026-09-15（—） |
