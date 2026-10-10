# 许可与来源

本文说明本仓库的**开源许可、与上游 DeepSeek Harness 的关系、第三方借鉴来源，以及内容公开性要求**。任何再分发、二次开发或对外引用都建议先读本文。

## 1. 本仓许可

本仓库以 **MIT 许可**发布，许可全文的**唯一声明源**是仓库根目录 [`LICENSE`](../LICENSE)：本文不逐字复制其正文——同一文本存两处会随年份、署名或许可措辞变化而漂移（D129）。要点如下。

要点：

| 项 | 说明 |
|---|---|
| 允许 | 商用、修改、再分发、私有使用、再许可（须保留版权与许可声明） |
| 要求 | 保留版权声明与许可声明；无担保 |
| 范围 | 整仓统一 MIT，不逐文件加许可头；`skills/`、`plans/`、文档同属本仓著作权 |
| 例外 | 引用的上游包名、配置键属**接口引用**，不构成本仓著作权的一部分（见 §2） |

## 2. 与上游 DeepSeek Harness 的关系

| 问题 | 回答 |
|---|---|
| 本仓是 DSH 的一部分吗？ | **不是**。本仓是一份**独立预设**（user preset + skill + 团队编排），由第三方在 DSH 之上组建 |
| 含上游代码吗？ | **不含**。仓库内无上游源码；`agent.cordis.yml` 中出现的是官方插件**包名与配置键**，属接口引用 |
| 依赖上游什么？ | 官方机制：goal 自动续行、子代理、workflow、skill 装载、沙箱与审批、上下文压缩等（对照表见 `references/harness-alignment.md`） |
| 上游稳定性 | DeepSeek Harness 为 developer preview，官方承诺 breaking changes；本仓已适配三项（注册表不再扫描预设目录、`app.asar` → 解包 `app/`、`dsh-workflow-worker-thread` 并入 `@deepseek-ai/dsh-workflow-ptc`） |
| 版本口径 | **两套编号独立**：应用版本（`CFBundleShortVersionString`）与 CLI / 包版本（`dsh --version`）。核验前各自取值，勿互相推断 |
| 许可证关系 | 上游许可不覆盖本仓内容，本仓 MIT 也不覆盖上游；两者互不派生 |

升级后的兼容核验流程见 [deployment.md](deployment.md) §9 与 [maintenance.md](maintenance.md) §5。

## 3. 第三方借鉴来源

本仓的机制设计**系统性借鉴了公开项目的机制思想，无代码抄袭**；逐条溯源见 `skills/dsh-codepunk-workflow/references/learned-skills.md`，技能治理的三件套（简报 / 细则 / 溯源）见 `references/skill-governance.md`。

| 来源 | 许可 | 本仓借鉴的机制 | 档案 |
|---|---|---|---|
| cathrynlavery/diagram-design | MIT | 文档配图规范（4px 网格、语义配色、静态优先） | `references/diagram-guide.md` |
| juliusbrussee/caveman | MIT | token 经济学（禁自造缩写、保护清单逐字保留） | `benchmarks/caveman-analysis.md` |
| ayghri/i-have-adhd | MIT | 消息层纪律（首行结论、编号上限、禁寒暄） | `benchmarks/adhd-workflow-analysis.md` |
| ponytail | MIT | 产出纪律（YAGNI 七级递减阶梯、根因修复、简化留痕） | `benchmarks/ponytail-analysis.md` |
| agent-housekeeping 等文件卫生方案 | MIT | 开工卫生契约、收尾残留自查、强制门闩 | `references/file-hygiene.md` |
| defender / SkillSpector / rebuff / arc_pi | Apache-2.0 / CC-BY | 注入防护与技能供应链注册门、PIT 分类法 | `references/prompt-injection-rules.md` |
| Mem0 / OpenViking / Letta | 仅机制思想引用 | 知识库三级化、记忆过期三态、多信号检索 | `references/memory-enhancement.md` |
| LangGraph / crewAI / ADK / CAMEL / ChatDev | 仅机制思想引用（未单独建档） | durable execution / 门禁双侧 guardrail / 硬信号评分 / 经验沉淀 | `references/learned-skills.md` |

> 表中「仅机制思想引用」者**未收录任何代码**，也未随仓库分发其产物；据此做升级决策前应先补调研简报。

## 4. 贡献者与署名

| 项 | 内容 |
|---|---|
| 版权行 | `Copyright (c) 2026 dsh-codepunk contributors`（以 `LICENSE` 为准） |
| 项目发起与维护者 | **webees**（仓库提交历史中的主要作者） |
| 技能元数据 | `SKILL.md` frontmatter 的 `author` 字段标识维护主体（当前为流程主责席位标识） |
| 贡献方式 | 见 `CONTRIBUTING.md`：主题分支 + 约定式提交（正文中文、附验证方式）+ 提交前清单 |

新增贡献者与署名变更以提交历史为准，不在文档内逐一维护——避免两处清单各自漂移。

## 5. 内容公开性要求（零私人化信息）

本仓为**公开仓库**，内容须满足：

1. **禁私人化信息**：真实姓名、邮箱、私网地址、内部主机名、凭据形态、私有 provider / 模型取值、本机绝对路径一律不得出现。
2. **禁词留本地**：守卫脚本不得含私人词（否则守卫自身即泄露源）。禁词从环境变量 `DSH_CODEPUNK_DENYLIST`、`~/.dsh-codepunk/denylist.txt`、仓库内自建 `.leak-denylist` 按序载入；只有通用模式进仓库。
3. **推送前拦截**：`plans/dsh-codepunk-leak-guard.sh` 三模式覆盖索引（pre-commit）、工作树（`--tree`）、提交信息与新增行（`--history`，pre-push），并提供 `--install-hook` 一键装三钩子。
4. **历史不可逆**：`git push --force` 只移动分支指针，服务端旧对象仍可能被枚举并直链读取——一旦泄露，唯一可靠补救是**删库重建**。故务必在推送前拦截，而非事后补救。
5. **中性写法**：文档中的位置一律写 `<DSH 安装根>`、`<profile>`、`~/.dsh-codepunk/...`、`<project_id>`、`<run_id>` 等占位表达；需要指向具体位置时写「取环境变量 X」。

## 6. 使用与再分发注意

| 场景 | 注意 |
|---|---|
| 自用部署 | 需自备 DSH 实例，并在**本地**配置 provider / 模型（本仓不内置私有取值） |
| 二次开发 | 保留 MIT 声明；改动流程语义时同步 `references/standard.md` 编号登记与治理矩阵 |
| 对外分发 | 不得夹带本地禁词表、私有 profile 片段或本机路径；分发前跑 `--tree` 与 `--history` |
| 品牌 | DeepSeek Harness 等名称与标识归其权利人所有；本仓仅以名称指代上游机制 |
| 引用本仓 | 建议同时引用 `README.md` 与 `references/harness-alignment.md`，以便读者对齐机制来源 |

相关文档：[architecture.md](architecture.md)（结构总览）· [documentation-policy.md](documentation-policy.md)（文档规范）· [maintenance.md](maintenance.md)（禁词表与泄露防护运维）· [deployment.md](deployment.md)（部署与本地配置边界）
