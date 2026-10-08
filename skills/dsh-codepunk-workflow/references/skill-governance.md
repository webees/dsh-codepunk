# 技能治理与升级机制（references/skill-governance.md）

> D083 完整展开。**目的**：所有从外部学习/整理的 skill 规范文档化存储，且具备**可追踪、可升级、可废弃**的迭代机制——确保 dsh-codepunk 持续吸收外部最佳实践而不失权威性。

## 一、技能生命周期（四态）

```text
调研（ind-res 联网） → 审定（run-lead） → 应用（落地入册） → 升级（复检迭代）→ 废弃（过时移除）
```

| 阶段 | 动作 | 产物 | 责任人 |
|---|---|---|---|
| **调研** | 联网抓取外部 skill/仓库，提炼机制 | `benchmarks/<topic>-analysis.md`（URL+retrieved_at+事实/推断） | 调研岗 ind-res |
| **审定** | run-lead 判定适配性（价值/风险/license/与既有关系） | 决策：应用 or 拒绝 | run-lead |
| **应用** | 落成人设/流程/细则文件 + 登记决策号 | `references/<topic>.md` + standard.md 登记 + 岗位人设 | run-lead |
| **升级** | 定期复检外部源变化 → 评估是否同步 | 版本核对记录 + 增量更新 | 文档小组 |
| **废弃** | 机制过时/被替代 → 移除或归档 | 归档标记 + learned-skills 更新 | run-lead |

## 二、技能文档化存储（三件套，MUST）

每项学到的技能必须同时落三处：

1. **调研简报** `benchmarks/<topic>-analysis.md`：来源、机制、适配点、license、检索留痕（URL + retrieved_at + 事实/推断标注）
2. **应用细则** `references/<topic>.md`：落地规则（人设/流程/产物模板可引用）
3. **溯源总表** `references/learned-skills.md`：决策号、学到什么、来源仓库、应用位置

> 铁律：**无简报不应用、无细则不引用、无溯源不登记**——三项缺一不可。

## 三、技能升级机制

### 3.1 升级触发点（外部源变化检测）

| 触发器 | 检测方式 | 响应 |
|---|---|---|
| 外部源 major 更新（star 激增/功能换代） | 文档小组定期（每月）`git ls-remote` / GitHub API 对比 | 重抓 README+SKILL.md diff，评估增量 |
| 外部源废弃/下架 | API 404/README 清空 | 评估 dsh 依赖该技能的条款 → 保留 or 移除 |
| 新同类技能出现（更优） | 调研岗生态扫描（如 VoltAgent 目录） | 对比替代 → 决定迁移 |
| 项目实践反馈（技能应用效果不佳） | proc-audit 巡检红灯 / 文档小组运行观察 | 回退或修订细则 |

### 3.2 升级流程（增量，不重写）

```text
1. 文档小组检测外部源变化 → 写升级评估（新机制/收益/风险/兼容）
2. run-lead 审定：采纳 / 部分采纳 / 拒绝
3. 采纳 → 增量更新 references/<topic>.md + standard.md 决策号释义 + learned-skills 溯源
4. 校验（解析/体积/零旧名）→ 推送
5. 更新技能版本标记（见 §四）
```

### 3.3 废弃流程

```text
1. 触发：机制过时/被替代/与新版 harness 冲突
2. 评估影响面（SKILL 引用/岗位人设/产物模板）
3. run-lead 裁决 → 移除引用 + 细则文件标「已废弃 YYYY-MM-DD，原因」+ learned-skills 更新
4. 决策号保留（历史权威），新增不重用
```

## 四、技能版本标记

- `learned-skills.md` 每行溯源加**技能版本**：`v1.0（应用日期）`；升级后 `v1.1（更新内容摘要）`。
- 升级历史追加在该技能行下（缩进列表），不覆盖旧记录（可追溯演进）。
- SKILL.md §7 引用加「（当前 vX.Y）」标注最新。

> **当前状态与向前适用（2026-10-05 实测）**：本节三项**尚未落实到位**，记录在此以便对齐——
> ① `learned-skills.md` 现有 32 行溯源**均带版本号但无一附「（应用日期）」**（历史行缺日期数据，
> 不回溯编造；新增行 MUST 按格式补日期）；
> ② 唯一升级行 `D096`（`v1.1`）**未附升级历史/摘要**（其行下无缩进列表；后续升级 MUST 追加，
> 不覆盖旧记录）；
> ③ SKILL.md §7 的逐条「（当前 vX.Y）」标注**尚未加入**（新增引用时随行补注）。
> 本节仍是 MUST——上述仅为存量欠账清单，不得以现状为格式范例。

## 五、实施规划（当前已应用技能全景）

> 本表为**全景清单**（当前 34 行，随表维护）——标题与正文**不写死条数**，避免与表格/`learned-skills.md`/`standard.md` 的实际条数漂移（历史教训：曾写「30 条」而表格已有 34 行）。

| 决策号 | 技能 | 来源 | 应用位置 | 版本 |
|---|---|---|---|---|
| D024 | 并行软上限：S=1 / M=3 / L=6（本预设自律上限，非平台字段） | 流程设计 | SKILL §2 ③ | v1.0 |
| D031 | 双门闩齐即自动开工 | 流程设计 | SKILL §2 ③ | v1.0 |
| D034 | goal active 前 product_acceptance[] 非空 | 流程设计 | SKILL §2 ① / artifacts | v1.0 |
| D035 | sponsor 通道与 goal 终裁归工程主责 | 流程设计 | SKILL §2 ① / agent.cordis.yml | v1.0 |
| D038 | 需求变更只走 change_orders | 流程设计 | SKILL §3 R6 / artifacts | v1.0 |
| D065 | sponsor 随时投喂、分诊并入 | 流程设计 | SKILL §2 ① | v1.0 |
| D066 | goal 自动续行 | DSH 平台 | SKILL §0.1 | v1.0 |
| D067 | checkpoint 断点续行 | langgraph | SKILL §2③ | v1.0 |
| D068 | 门禁 guardrail | crewAI/ADK | SKILL §2④ | v1.0 |
| D069 | schema 强约束 | outlines/agentskills | artifacts + evidence-verify.sh | v1.0 |
| D070 | 硬信号评分 | CAMEL/ChatDev | knowledge.md | v1.0 |
| D071 | 委托契约 | ADK/Swarm | roles.md | v1.0 |
| D072 | 总库语义 | 自研 | SKILL §1 | v1.0 |
| D073 | worktree 生命周期 | 实战 | SKILL §2⑤ | v1.0 |
| D074 | 上下文纪律 | Anthropic | SKILL P07 + 人设 | v1.0 |
| D075 | 消息纪律 | i-have-adhd | SKILL P07 + 全员 | v1.0 |
| D076 | token 经济学 | caveman | SKILL P07 + 人设 | v1.0 |
| D077 | 反幻觉 | superpowers/Anthropic | SKILL P07 + sdet | v1.0 |
| D078 | 模型路由 | dsh-llm-deepseek | model-routing.md | v1.0 |
| D079 | 文件卫生 | agent-housekeeping | file-hygiene.md | v1.0 |
| D080 | 撰写标准 | 实战 | roles.md | v1.0 |
| D081 | 产出纪律 | ponytail | anti-overengineering.md | v1.0 |
| D082 | 文档配图 | diagram-design | diagram-guide.md + docs 人设 | v1.0 |
| D083 | 技能治理与升级 | 自研治理机制 | skill-governance.md / 文档小组 | v1.0 |
| D084 | 注入防护 | defender/SkillSpector/rebuff | prompt-injection-rules.md / 巡检 | v1.0 |
| D085 | 知识库记忆增强 | Mem0/OpenViking/Letta | memory-enhancement.md / knowledge | v1.0 |
| D086 | 限流自适应 | 实战经验 | rate-limit-adaptation.md / SKILL §③ | v1.0 |
| D087 | ⚠已废弃（D089 取代）岗位路由改道 | 实战 | model-routing.md §五 | v1.0 |
| D088 | 子代理可恢复性（continuable） | 实战 | agent.cordis.yml / preset-tool-fixes F-003 | v1.0 |
| D089 | 模型统一与回退 | 实战经验 | model-fallback.md / settings | v1.0 |
| D090 | 子代理路由双要件（agentOptions + continuable） | 实战经验 | agent.cordis.yml / model-routing.md | v1.0 |
| D094 | 启动自检与子代理恢复 | 实战需求 | SKILL §1.1 第 4 条 / stages.md §③ / agent.cordis.yml | v1.0 |
| D095 | 定时巡检与子代理状态清单 | 内部需求 | SKILL §1.1 第 5 条 / artifacts.md | v1.0 |
| D096 | 持久 shell 与工具调用超时 | DSH 2.0.12 | SKILL §4 / agent.cordis.yml | v1.1 |

## 六之前·检查器覆盖矩阵（哪类缺陷由谁负责）

> 目的：明确「机械把关 vs 人工把关」的边界，避免误以为有工具就万无一失。**空档列已如实标注**——
> 空档类缺陷只能靠人工逐条比对（历次审计中该类占比最高）。
> 「元检查」= 检查器自身的存活验证（防「守护空转」）。

| 缺陷类别 | 负责检查项 | 方式 |
|---|---|---|
| 组合/岗位不变量（缺 persona、非 continuable、disabled、缺 toolFilter） | `preset-audit` A7 | 机械 |
| YAML 可解析 / 条目形状 | `preset-audit` A1 · `preset-compat` 配置键项 | 机械 |
| 组合 ↔ DSH 兼容（包存在/键接受/隔离/锚点/allow 名单） | `preset-compat`（7 项） | 机械 |
| 源 ↔ profile 副本漂移 | `preset-declare check`（语义）+ `verify-battery` 8b | 机械 |
| 脚本语法（`.sh`/`.ps1`/`.py`/`.mjs` 四类） | `verify-battery` 7 | 机械 |
| 路径/脚本引用存在性（含 references 内、markdown 死链） | `preset-score` A2 · `preset-audit` E3 | 机械 |
| 编号一致性（D/P/R 定义与引用、重复号） | `preset-audit` B7/D1/D3 · `preset-score` | 机械 |
| 编号引用**可解析**（D 须逐条登记；P 须落在声明范围/span 内） | `doc-consistency.sh` 第 9 类 | 机械 |
| 章节级引用**可解析**（对 `references/<文件>.md` 的「章节名」引用、限定式 `§N`） | `doc-consistency.sh` 第 10 类 | 机械 |
| benchmarks **支撑决策号语义**（括注短名 ↔ 登记含义的 2-gram 重叠） | `doc-consistency.sh` 第 11 类 | 机械 |
| **状态机自洽**（`status:`/`expected:` 取值须落在已声明集合内；集合自模板注释自动采集） | `doc-consistency.sh` 第 12 类 | 机械 |
| **死状态**（模板声明的每个状态值 MUST 在**正文**被步骤引用，否则无主体/无触发条件） | `doc-consistency.sh` 第 13 类 | 机械 |
| **评分扣分可达性**（**64 个扣分点**须有「注入定向缺陷 → 该指标降级且命中其理由」的证据；当前已证：**B6–B15 全 10 项指标、34 条扣分分支**（M28 六条 + M29 八条 + M30 十四条；余 B14 两条与 B13 逐条 R 行属同族已证），其余按需补；**A4「硬规则号重复」由 M127 证明可达** ✅ ⇒ 已证 **35/64**；**计数须按派生值取**：`grep -cE 'ded +[AB][0-9]+ +[0-9]+' plans/preset-score.sh`（F281：旧值 37/38 系**未派生**的陈旧数，实测 64）） | 自检 `M28`–`M30`、`M127` | 机械 |
### 新检查入库清单（MUST，2026-10-05 由 F133/F134/F137/F138 导出）

新写检查项、变异夹具或断言时，**入库前**须逐条自问并留证：

1. **分支可达**：每个判定分支都要有一条**能命中它**的注入（F133/F134：B6 因绑定已废弃措辞而
   「扣分永不可达」；F137：第 15 类「孤立阶段」因把定义文件算作引用而**结构不可达**）。
2. **变异生效**：断言前确认变异**真的落盘**——插入型用模式存在、**删除/替换型**用 `mutate_gone`
   或「新值存在」确认（轮次 140 曾因误用而自检误报）。
3. **期望串特异**：`check_rc` 的期望串 MUST NOT 被被检脚本的**小节标题**包含，否则可能仅凭标题
   通过＝假通过（F138；轮次 131 实测；已由第 16 类机械把关）。
4. **夹具不自伤**：夹具不得含触发本仓守卫的字面量（绝对路径／邮箱／私网地址）——须运行时拼接
   （F131；已由第 14 类机械把关）。
5. **计数同步**：新增变异后同步 README 声明计数（第 1 类会当场报错，属预期）。
6. **双向留证**：负向探针须同时记录**变异生效**与**捕获**两个事实，且优先在**副本内**验证。
8. **判据不得空转**：阈值/取值类判据 MUST NOT 用**字面捕获**（如 `(32768)`——只能匹配自身

9. **原始文本可疑 ≠ 缺陷**：任何基于**原始文本匹配**的怀疑（如「同名 YAML 锚点被二次定义」、「该行含 X」），在判定前 MUST 用**真实解析器或运行时**复核 —— 注释、字符串与代码的界限由解析器决定，文本级匹配无法区分。轮次 168 实测：`&role-allow` 在 L437 的第二次出现实为**注释**，两个产品自带 YAML 库（`yaml`、`js-yaml`）解析后**仅 research 含 web**，与文档声称一致；若据原始文本即判缺陷，将产生误报。
   字面，永不报警）；须用**泛化捕获**（如 `(?:≤|超预算[ ]*)([0-9]{5})`），并在负向探针里
   改动**另一侧**的取值以证明「能察觉分歧」（F148 实证：字面捕获的条目负向探针未捕获）。
7. **文案自洽**：新检查的**消息文案**不得含 shell 元字符（反引号等会被双引号当命令替换）或**会被本检查自匹配的样例**（F145：消息里的三位 R 号被第 19 类自身命中）；改动消息后须同步所有断言期望串（F145 第三处：M37 期望串过时被自检当场抓出）。

| **部分流程自洽**（阶段引用可解析：悬空引用／孤立阶段——矩阵空档已机械化） | `doc-consistency.sh` 第 15 类（双向负向验证通过） | 机械 |
| **夹具字面量纪律**（自检夹具不得含触发本仓守卫的字面量：用户目录绝对路径／邮箱形态／私网地址；须运行时拼接，否则副本内评分与泄露门会命中夹具自身） | `doc-consistency.sh` 第 14 类 | 机械 |
| 已登记的计数声称（15 指标 / 5 组 / 14 项电池 / 岗位数 / 变异项数——域：`README.md` + `docs/**` 同族写法） | `preset-score` A3 · `preset-audit` B1 · `doc-consistency.sh` 第 1 类 | 机械 |
| 泄露与品牌卫生 | `leak-guard`（3 模式 + 三钩子）· `preset-score` B5/B11 | 机械 |
| 格式/EOL/杂散/全角紧邻陷阱 | `verify-battery` 4/5 · `preset-audit` B1b | 机械 |
| 失败路径提示与退出码契约 | `checker-self-test` M10–M13 | 机械（变异） |
| **守护空转**（检查器因工具缺失/正则不兼容/空值判定而恒判 PASS） | **`checker-self-test`（15 断言）** | 元检查 |
| 跨文件同机制**阈值一致**（证据门 exit_code / 评分 base·clamp / retries / handoff 缺件 / 巡检周期 / 收口轮数） | `doc-consistency.sh` 第 7 类 | 机械 |
| benchmarks **间结论一致**（同一外部来源在不同简报中的机制描述是否矛盾） | 无（**实测不可机械化**：按来源聚合行内数字的扫描输出以 D 号/日期/无关量为主，无判据价值） | 人工：对跨 ≥2 简报的来源做**定向机制比对**（实测判据=同一来源的分许可/分组件表述须互补而非互斥，如 caveman 的 MIT 部分与 BSL 部分） |
| 文档**声称 ↔ 实现**（计数/阶段口径/工具存在性/退出码契约） | `doc-consistency.sh` 第 1–6 类 | 机械 |
| **退出码契约实测**（用法/环境错误必须返回 2；**32 条探针**实跑 = 9 条用法/环境错 + 4 条坏根提示形状 + 19 条 `-h`〔域＝`plans/` 下全部可执行入口 `.sh`/`.py`/`.mjs`，纯 source 库除外〕；另有探针计数守卫防吞错，以及「每个运行型入口都 MUST 实现 `-h`/`--help`」的静态子项——F361 实证 4 个 `.sh` 实现者曾不在探针表内，F366 实证 4 个 `.py`/`.mjs` 入口曾**整体不在域内**） | `doc-consistency.sh` 第 20 类 | 机械 |
| **移植对等性**（4 对 sh↔ps1：关键词白名单 + leak-guard 通用模式签名双向对等；ps1 工作树行尾 CRLF 落地校验在**无 git 环境回退文件系统字节核验**——F335） | `doc-consistency.sh` 第 17 类 | 机械 |
| **pwsh 钩子参数语法**（Windows 侧生成钩子不得用 `$1` 等 PS 不支持的位置参数语法） | `doc-consistency.sh` 第 18 类 | 机械 |
| **硬规则命名空间洁净**（禁三位以上 R 号；轮次引用写「轮次 N」） | `doc-consistency.sh` 第 19 类 | 机械 |
| **岗位数一致性**（11 内建 + 2 外部后端；「13 岗位」须带历史/例外标记） | `doc-consistency.sh` 第 21 类 | 机械 |
| **矩阵覆盖**（每个检查类须在治理矩阵中登记，含「第 a–b 类」范围写法） | `doc-consistency.sh` 第 22 类 | 机械 |
| **钩子配置完整性**（产品启动时读取的 `plans/hooks/hooks.json`：JSON 可解析 · matcher/type/command 齐备 · 命令引用的仓库内文件存在 · **解释器在 PATH 内**——缺解释器时钩子起不来、产品不设 decision ⇒ 放行，属失败开放；F368 实证：坏配置下五个门禁全绿） | `doc-consistency.sh` 第 7 类子项（+ 存活自检 M168） | 机械 |
| **hooks 护栏路径归一**（`/etc`＝`/private/etc`＝符号链接＝大小写变体同判；F383 实证） | `plans/hook-write-scope.py` 的 `canon()` | 机械（M177） |
| **hooks 命令抽取取真目标**（`chmod 777`/`truncate -s 0`/`chown root:wheel` 的实参不得顶替路径；F384 实证） | `plans/hook-write-scope.py` 的 `looks_like_path()` | 机械（M178） |
| **零输入不得呈现为「通过」**（门禁的 PASS 前提是**真的扫到了输入**：替身/损坏的 `git`（退出码 0 零输出）或 `GIT_DIR` 误设时枚举为空 ⇒ 泄露防护门须退出码 2 并报「已扫描 N 个跟踪文件」；F387 实证：曾「一个文件不扫」仍打「✓ 通过」） | `plans/dsh-codepunk-leak-guard.sh` 的 git 自证 + 扫描计数（+ 存活自检 M180） | 机械 |
| **空枚举须回退核验**（`git ls-files` 为空时不得让循环空转判 PASS：审计门 D3「行号引用均附符号名」/E3「仓内相对链接均可达」改为文件系统遍历回退，遍历仍空则报「无法核验 ≠ 通过」；F388 实证：说谎 `git` 下曾给 100/100 假满分） | `plans/preset-audit.sh` 的 D3/E3 `if not files:` 回退（+ 存活自检 M181） | 机械 |
| **扫描工具缺失须显式失败**（`find` 不在 PATH 时进程替换为空、`2>/dev/null` 吞掉 `command not found` ⇒ 残留扫描全判「无残留」、`.DS_Store` 计数判 0；F372 实证：同一含残留沙箱在有/无 `find` 下 rc=1 → rc=0） | `write-scope-check.sh` 扫描工具预检 + `preset-score.sh` B14 + `verify-battery.sh` 杂散项（+ 存活自检 M169） | 机械 |
| **doc 类数声称与实现派生一致**（`doc-consistency.sh` 同行的「N 类」须等于类段数派生值；序数写法「第 N 类」剔除不误判；F373 实证：`docs/architecture.md` 长期写 24 类而实现 25） | `doc-consistency.sh` 第 1 类派生核验（+ 存活自检 M170） | 机械 |
| **存活自检的结论行须据实报告覆盖**（环境受限时若干变异只打印「跳过」而不执行，末行却称「全部变异均被对应检查项捕获」；F374 实证：设/未设 `DSH_APP_ROOT` 两次运行 ✅275 与 ✅270 而文案相同，CI 未设该变量 ⇒ 恒跳过该族） | `checker-self-test.sh` 结论行（`coverage_line` + `skip()` 计数；+ 存活自检 M171） | 机械 |
| **文档「派生计数口径」表的实况列须与派生值一致**（表内只写裸数字或「N（M1–MN）」，不在第 1 类「N 项…」族域内；F375 实证：`docs/development.md` §7 长期写 167/24 而实况 171/25） | `doc-consistency.sh` 第 1 类派生核验（按行标签；+ 存活自检 M172） | 机械 |
| **运行型脚本退出码声明**（`plans/*.{sh,py,mjs}` MUST 在头部声明退出码；豁免仅两类：`dsh-codepunk-home.sh` 特例、无任何显式退出调用者——F336 起**取消**「含 source 一词即豁免」的启发式；环境类失败返回 2——F146/F152 同源） | `doc-consistency.sh` 第 5 类分支 | 机械 |
| **简报检索日**（含 URL 的 benchmarks 须带 `retrieved_at`；不可考时显式标注依据） | `doc-consistency.sh` 第 23 类 | 机械 |
| **证据引用包含性**（`log_ref` 解析后须位于交付目录内；绝对路径 / `..` 逃逸 / 指向目录外的符号链接一律 FAIL——F348 实证） | `plans/evidence-verify.sh` ② + 存活变异 M154 | 机械 + 变异 |
| **运行根 `write_scope:` 台账段**（R17 的 `write_scope:` MUST；`cleanup_status` 为交接门/合并门前置读数） | `write-scope-check.sh --run-root`（F377 实证：散文形态下该读数不存在） | 机械 |
| **自检变异锚点的稳定性**（MUST 只依赖被守护的分支形态，不得锚定易碎常量） | `checker-self-test.sh` 的 M149 锚点（F379 实证：行区间常量 44→50 即致变异不落地） | 机械 |
| **巡检节奏（D095）**（间隔 ≤ 5 轮、轮次不重复、巡检轮次须在台账中有行） | `plans/patrol-check.sh`（第 20 类探针 `patrol-check -h` · 变异 `M176`；F378 实证：实测最大间隔 10 轮 + 重复轮次 601/602/609。F385 更正：原记的运行根便利脚本 `tools/patrol-cadence.py` **非仓内产物**，不得作为「机械」载体） | 机械 |
| **Markdown 表格列数一致与结构完整**（分隔行驱动识别：数据行单元格数不得超过表头；代码跨度内的竖线须转义为 `\|`；另判两条**断表**结构缺陷——表头↔分隔行列数不等、分隔行后紧跟空行；围栏按字符+长度配对、排除缩进代码块、支持引用块与无行首竖线表格——F295 实证 + F296/F297 加严） | `doc-consistency.sh` 第 24 类 | 机械 |
| **同一制品的多处生成器须一致**（总库 `INDEX.yaml` 骨架：`dsh-codepunk-link.sh` 与 `dsh-codepunk-init.sh` 两处 heredoc 模板须**逐字节一致**——否则终态内容取决于「谁先建文件」；F360 实证：link 原为 1 行头、init 为 11 行注释块；F386 更正：原写脚本简称（去掉 `dsh-codepunk-` 前缀）按名不可检索） | `doc-consistency.sh` 第 25 类 | 机械 |
| **治理矩阵载体可解析**（矩阵行内反引号的文件型引用须在仓内可解析，或为 `artifacts.md` 以 `##` 小节声明的制品名，或该行显式标注「非仓内」——F385 实证：原「巡检节奏」行以运行根本地脚本作为「机械」载体，仓内不可复现、CI 无法执行，且仓内已有等价门） | `doc-consistency.sh` 第 26 类 | 机械（变异 M179） |
| **外部输入变量须被记载**（未在本文件赋值、或写成 `${VAR:-默认}` 的覆盖开关 MUST 出现在任一 `.md` 或脚本**头部注释块**〔`#` 块 / `.py` docstring / `.mjs` JSDoc〕；F358 实证：`git-merge-flow.sh` 的 `PR_BODY` 曾只在实现里存在） | `doc-consistency.sh` 第 5 类子项 | 机械 |
| **声明写入的原子性**（`preset-declare.mjs apply` 写用户平面补丁 MUST 原子替换：同目录临时文件 + `renameSync`，并保留原权限位；就地 `writeFileSync` 先截断 ⇒ 并发读者可见 0 字节、SIGKILL 后留下不可用 profile，而写后自校验的回滚只在正常路径执行；F380 实证：5 ms 采样读到 size=0、受控 A/B 修复前 0 字节 / rc=2、修复后字节与权限不变 / rc=1） | `checker-self-test.sh` M174（以「inode 是否变更」为可确定观测的原子性不变量；2 断言） | 机械（变异） |
| **hooks 覆盖清单与实现同域**（`references/file-hygiene.md` §8.3 承诺的每种写盘形态 MUST 真被抽取器覆盖；F381 实证：只认「裸 `-i `」，`-i.bak`/`-i''`/`--in-place`/`--in-place=.bak`/`perl -i`/`>|` 静默放行） | `hook-write-scope.py` 抽取器 + `checker-self-test.sh` M175（3 断言） | 机械（变异） |
| **巡检名册字段契约（D095/D099）**（运行根 `agents.yaml` 的 `patrol_log` 每条 MUST 齐备 `round`/`at`/`note` 且非空，`round` 唯一且为整数，巡检轮次须在台账中有行，升序排序后相邻间隔 ≤ N〔默认 5〕；F382 实证：旧形态 `{round, checked, result}` 实测 34 条缺 `at`、35 条缺 `note`，而全仓无任何机械门检视该契约——`write-scope-check.sh --run-root` 只验 `write_scope:` 段） | `plans/patrol-check.sh --run-root` + 存活变异 `checker-self-test.sh` M176（3 断言：合规名册 rc=0 / 缺 `at` rc=1 / 判据短路后不得再报——证明非空转） | 机械（变异） |
| **术语一致性**（含「工作房」vs「工作区」消歧） | 无（**实测不可机械化**：简单抽取器在 498 条「**词**：」命中中产出的候选几乎全为散文引导词） | 人工：对**核心术语**（双门闩/工作房/写集/交接包/门禁/证据 verdict 等）逐条比对定义句，实测判据=同名术语的括号注与谓词表述一致 |
| **日期形态与未来日期**（须 ISO；「实测」不得标在未来；未来日期上限＝UTC 今天 +1 天以容忍时区偏移——CI 为 UTC 时钟，作者本机「今天」最多超前 UTC 一天，不设容忍则本地 00:00–07:00 产生的合法日期在 CI 上必红） | `doc-consistency.sh` 第 8 类 + `checker-self-test.sh` M166（注入 UTC 今天 +1 天须放行 / +2 天须报出） | 机械（变异） |
| **树遍历不得跟随符号链接**（门禁 MUST 限时返回：检出内含链接环时不得无限递归——`glob('**/*', recursive=True)` 默认跟随，实测 rc=124 无判定行；改用 `os.walk(followlinks=False)`） | `checker-self-test.sh` M148（沙箱内造链接环 ⇒ 断言限时返回且通过） | 机械（变异） |
| **坏输入不得假绿灯**（`preset-declare` 的补丁：含 NUL 的非文本、非空且不可被 YAML 解析 ⇒ `check`/`apply` 一律 rc=2；`apply --append` 曾把声明块追加进损坏文件并报「生效」） | `preset-declare.mjs` 头部守卫（F341） | 机械 |
| **制品字段模板声称可解析**（凡「`<制品>`（字段模板见 `references/artifacts.md`）」的声称，该制品名 MUST 在 `artifacts.md` 有 `##` 小节；F344 实证：`plan_draft.md` 的字段契约曾悬空，全文仅出现在运行根树状图） | `doc-consistency.sh` 第 10 类子项 | 机械（变异 M150） |
| **散落根判据与默认根解析**（`verify-worktree.sh`：只有与本主仓库共享 git 目录的散落 worktree 判 FAIL，散落根内其它 git 仓库只报 INFO；默认根顺序 `SCAN_ROOT` > `DSH_CODEPUNK_WORKTREES` > `DESKTOP` > 桌面候选。F345 实证：旧实现把开发机桌面上的无关仓库一律判 FAIL，而文档化落点从不被扫描） | `checker-self-test.sh` M151（四断言：无关仓库 ⇒ rc=0 且含「不计 FAIL」/ 主仓克隆 ⇒ 同上 / 真散落 worktree ⇒ rc=1 / 未设 `SCAN_ROOT` ⇒ 优先扫总库 `worktrees/`） | 机械（变异） |
| **INDEX 序列缩进风格容忍与保持**（`dsh-codepunk-link.sh`：`projects:` 下顶格序列项（`- project_id: …`）与 `---`/`...` 文档标记不得被当「未知顶层键」；追加条目沿用既有缩进，否则产出非法 YAML 被回滚；真未知顶层键仍失败。F346 实证：真总库 24 条目顶格 ⇒ `index`/`register` 双双 rc=1，登记链整体失效且提示「从备份恢复」为误导） | `checker-self-test.sh` M152（五断言：顶格 ⇒ `index` rc=0 / `register` rc=0 / 追加沿用顶格 / 追加后条目齐 / 真未知顶层键 ⇒ rc=1） | 机械（变异） |
| **分支保护必需检查名三方一致**（`plans/github-setup.sh` 的 `CHECK_CONTEXTS` ↔ `.github/workflows/ci.yml` 各作业 `name` ↔ `docs/maintenance.md` 的提及。ruleset 按上下文名匹配，改名后该检查永不出现 ⇒ PR 永久阻塞；F347 实证：四作业名各加 `-v2` 时四门禁仍全绿） | `doc-consistency.sh` 第 7 类子项 | 机械（变异 M153，两断言：改名 ⇒ rc=1 且缺/多同报；文档漏提 ⇒ 不得报「一致」） |
| **声明应用的根结构前提与产物可解析性**（`preset-declare.mjs`：profile patch 的根 MUST 为序列（`- id: …` / `- insert: …`）——根为映射时追加 `- insert:` 项会让顶层混用映射与序列 ⇒ 产出非法 YAML；写出后 MUST 用同一解析器复核产物，不合规则回滚并以 2 拒答；缺 js-yaml 的降级模式按首个有效行做文本判定，并对含 `---`/`...` 文档分隔符的补丁拒答。F349 实证：旧实现只校验「输入能否解析」，映射根补丁被追加后报「✅ 生效」而产物 `YAML_FAIL (14:1)`） | `checker-self-test.sh` M155（六断言：映射根 ⇒ rc=2 且文件与备份均未变 / 含 `...` ⇒ rc=2 且不留半成品 / 序列根 ⇒ rc=0 不回归 / 判据移除 ⇒ 不得再报该消息） | 机械（变异） |
| **电池结论行不得把跳过项计入「满分」**（`verify-battery.sh`：因缺工具（python3/node）、缺环境变量（`DSH_APP_ROOT`/`DSH_ASAR`/`js-yaml`）或自检递归防护开关 `DSH_CODEPUNK_SKIP_SELFTEST=1` 而跳过的项，MUST 在结论行列明且不得宣称「全部通过（满分）」——「跳过 ≠ 通过」，与 F181「未实际核验不得计入通过」同源。F350 实证：旧实现设该开关时仍打印「本轮：全部通过（满分）」且 rc=0） | `checker-self-test.sh` M156（三断言：跳过模式 rc=0 且含「跳过 ≠ 通过」/ 跳过模式不得含「全部通过（满分）」/ 跳过登记被短路 ⇒ 不得再报该标注） | 机械（变异） |
| **YAML 解析路径与自定义标签容忍**（无 ruby 主机须与 ruby 路径同结论：按候选链查找 js-yaml、容忍 `!!js` 标签、解析出的 Date 属标量；两路都不可用时报「无法核验」而非「解析失败」） | `checker-self-test.sh` M157（四断言）/ M158（三断言） | 机械（变异） |
| **必需检查的文档声称 ↔ 作业实际执行**（`CONTRIBUTING.md` 的 CI 门禁表：给出可执行等价命令者，该命令 MUST 真被对应作业执行；声称覆盖 Windows 侧则该作业段内 MUST 出现 ps1 路径；指向电池某项则电池项标题内 MUST 有该词。判据只看正向声称，纯路径提及（「近似项见 …」）不计。F354 实证：`跨平台可移植` 声称「Windows 两侧实现的对等性」并指向电池「跨平台项」，而该作业只扫 `plans/*.sh` 与可执行位、电池亦无此项 ⇒ 平台对等实为人工公约却看似有机械守护） | `doc-consistency.sh` 第 7 类子项 | 机械（变异 M159，四断言：旧文案 ⇒ rc=1 且逐条列出三处不符 / 等价命令不存在 ⇒ rc=1 / 指向电池不存在的项 ⇒ rc=1 / 判据移除 ⇒ 不得再报该消息） |
| **Dependabot 声明 ↔ 仓库与治理脚本**（声明的 `package-ecosystem` MUST 在仓库内有对应清单——声明而无清单的条目恒不产出 PR；`labels` 引用的标签 MUST 由 `plans/github-setup.sh` 幂等创建——标签不存在时该字段静默失效；`docs/maintenance.md` 的生态清单 MUST 与声明一致。本轮巡检实证：曾声明 `pip` 而仓库无任何 pip 清单且文档声称巡检该生态；`dependencies` 标签长期不存在而治理脚本只创建 `automerge`） | `doc-consistency.sh` 第 7 类子项 | 机械（变异 M160，四断言：注入无清单的生态 ⇒ rc=1 / 标签改为治理脚本未创建者 ⇒ rc=1 / 文档生态改名 ⇒ rc=1 / 判据移除 ⇒ 不得再报该消息） |
| **写盘护栏拦截层（hooks）行为契约**（`plans/hook-write-scope.py`：denylist 路径作 `write.file_path` ⇒ 退出码 2 且 stderr 含规则名；预设仓库内路径 ⇒ 退出码 0；抹掉阻断分支后该规则名不得再出现——防「护栏空转」。判据权威与层级关系见 `references/file-hygiene.md` §八） | `checker-self-test.sh` M164（三断言：denylist ⇒ rc=2 且含规则名 / 仓库内 ⇒ rc=0 / 抹掉阻断分支 ⇒ 不得再命中该串） | 机械（变异） |
| **声明生成器的输出完整性**（`plans/preset-declare.mjs emit` 在**管道**（`| cmd`、`$(...)`、子进程采集）下不得被截断——`process.stdout.write` + `process.exit` 会丢弃管道缓冲，截断产物仍是合法 YAML ⇒ 下游静默采用半截声明；F362 实证 65536 B vs 71493 B） | `preset-compat.py` 检查 8（管道字节数须等于文件重定向）+ `checker-self-test.sh` M165（两断言） | 机械（变异） |
| **工程化入口（Makefile）自述与 CI 关系**（头部声称「本地与 CI 用同一条命令复跑」——实测 CI 全文无 `make` 调用；`make gates` ≠ CI「门禁回归」；`make write-scope` 实参窄于 CI（缺假 HOME 的 `--home`）⇒ 本地绿不等于 CI 绿。已改为实测口径并写明「以 CI 结论为准」） | 无（自然语言声称，不可机械化） | 人工：改动 Makefile/ci.yml 任一侧时逐条比对入口与实参 |
| **日期时效性**（文档内实测结论是否已过期） | 无 | 人工 |
| 需求/流程自洽（阶段归属、汇报链、责任席位是否有人） | 部分（A7/结构检查） | 半人工 |

## 六、文档小组职责（技能治理执行者）

1. **月度技能复检**：检测外部源变化（§3.1 触发器），写升级评估交 run-lead 审定
2. **技能档案维护**：benchmarks/references/learned-skills 三件套的持续更新
3. **提示词优化**：应用效果反馈 → 修订岗位人设中的技能条款
4. **升级留痕**：版本标记 + 升级历史，确保可追溯

> 技能治理是**持续回路**而非一次性：每次新技能应用都走「调研→审定→应用→升级」完整流程，且**必须先文档化再应用**（本文件 §二 三件套 MUST）。
