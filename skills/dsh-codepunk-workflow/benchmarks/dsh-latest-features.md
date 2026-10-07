---
title: DSH 最新版本与预设作者可用配置面（外部调研简报）
retrieved_at: 2026-10-08
source_count: 25
---

> 支撑决策号：D095（定时巡检）延伸 · 性质：外部调研（DSH 2.0.17 产品特性与预设作者配置面）

# DSH 最新版本与预设作者可用配置面

结论先行：**DSH Desktop 2.0.17 即当前最新稳定版**（2026-09-29 发布，内置内核 `v0.2.0-rc.2`）；npm 上仅有一个更新的预发布标签 `0.2.1-alpha.1`（2026-10-03）。预设作者的配置面在 2.0.17 已完整可用：预设即「普通 Cordis 插件行 + `@deepseek-ai/dsh-agent-preset` 声明」，工具过滤、`backgroundMode`、`maxDepth`、`persona` 全部由 `tool-subagent` 的 schema 定义；新增可用面集中在 **hooks 桥（Claude Code / Codex `hooks.json`）**、**MCP 客户端**、**技能根与调用策略**、**沙箱策略声明**、**插件版本兼容豁免**。本简报只做外部事实提取，不含本仓方案。

## 一、版本与来源

| 项 | 事实 | 来源 | 可信度 |
|---|---|---|---|
| DSH 桌面版 | `2.0.17`（`v2.0.17`，2026-09-29T17:14:45Z）；同批另有 `v2.0.17-next`、`v2.0.17-beta.1` | [DSH Desktop v2.0.17 发行说明](https://github.com/anywhere-labs/deepseek-harness-desktop/releases/tag/v2.0.17) | 官方发行说明（社区维护仓库） |
| 桌面版性质 | 发行说明自述「DSH Desktop 是社区维护的开源项目，并非 DeepSeek 官方产品」；仓库已迁移至 `anywhere-labs/dsh-desktop` | [同上](https://github.com/anywhere-labs/deepseek-harness-desktop/releases/tag/v2.0.17) | 官方发行说明 |
| CLI 稳定版 | `@deepseek-ai/dsh` 最新 `0.2.0-rc.2`（2026-09-29T09:56:27Z）；`dist-tags` = latest/next 均 `0.2.0-rc.2` | [npm registry 元数据](https://registry.npmjs.org/@deepseek-ai/dsh) | 官方注册表 |
| 是否存在比 2.0.17 更新的桌面版 | **无**：`v2.0.17` 是 tags 列表首项（其后仅 `v2.0.17-next` / `v2.0.17-beta.1` 同源变体） | [仓库 tags](https://github.com/anywhere-labs/deepseek-harness-desktop/tags) | 官方发行说明 |
| 是否存在更新的内核 | 有且仅有一个：npm `alpha` 标签 `0.2.1-alpha.1`（2026-10-03T04:53:22Z）；对应 tag `dsh-v0.2.1-alpha.1` | [npm registry 元数据](https://registry.npmjs.org/@deepseek-ai/dsh)、[发行说明](https://github.com/deepseek-ai/deepseek-harness/releases/tag/dsh-v0.2.1-alpha.1) | 官方发行说明 |
| 内核版本序列 | `dsh-v0.1.0-rc.7` 起至 `dsh-v0.2.1-alpha.1` 共 26 个 tag；`0.2.0-rc.2` 为当前稳定 | [仓库 tags](https://github.com/deepseek-ai/deepseek-harness/tags) | 官方发行说明 |
| 2.0.17 相对 2.0.16 | 升级内核 `v0.2.0-rc.1 → v0.2.0-rc.2`；适配内置终端与 Desktop Profile 插件管理；支持用应用提供的 CLI 装卸插件与管理版本兼容例外 | [v2.0.17 发行说明](https://github.com/anywhere-labs/deepseek-harness-desktop/releases/tag/v2.0.17) | 官方发行说明 |
| 官方产品页 | 公开预览、开源、「一切皆插件」（Cordis 架构）、插件/技能/界面可扩展 | [DeepSeek Harness 官方页](https://www.deepseek.com/en/harness/) | 官方文档 |
| 第三方中文站 | 自述「独立的中文教程站」「非官方社区资源」；其安装页仍写 `0.1.1-rc.2`（**已过期**） | [dshbase 首页](https://www.dshbase.com/zh/)、[安装页](https://www.dshbase.com/zh/install/) | 第三方文章（版本信息不可用） |

## 二、特性表（预设作者面）

| 特性 | 作用 | 配置面（文件 · 键 · 取值） | 来源 | 可信度 |
|---|---|---|---|---|
| Agent 预设声明 | 用普通 Cordis YAML 声明一个预设的**子插件行**，会话按 id 选用；定义热加载，编辑只影响此后新建的 Agent | 组合文件（本预设 = `agent.cordis.yml`）中 `name: '@deepseek-ai/dsh-agent-preset'`，`config.id`（必填、会话保存的预设标识）、`config.plugins`（必填、子条目列表）、`name`/`description`/`order`（展示用） | [agent-preset README](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/preset/agent-preset/README.md) | 官方文档 |
| 预设注册表 | 部署默认预设、用户默认选择、修订保留；失败定义仍可见，已建 Agent 保留原组合 | `name: '@deepseek-ai/dsh-agent-preset-registry'`，`config.default`（必填）、`selectedDefault`（volatile，经 Settings 编辑） | [agent-preset-registry README](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/preset/agent-preset-registry/README.md) | 官方文档 |
| 预设安装形态 | 新预设/覆盖内置预设 = **bundle patch**（`insert` 一个 `agent-preset` 行，或按该行 id 打 patch），经 `plugin_manager` 装进 profile；创造模式可在对话中生成 | `$DSH_HOME/profiles/<name>/cordis.patch.yml` 或 `--patch` overlay | [同上](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/preset/agent-preset-registry/README.md) | 官方文档 |
| 已退役字段 | `modeSelectionEnabled` 已不再声明、不读不写；残留仅是无害字段 | profile patch 中该键 | [同上](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/preset/agent-preset-registry/README.md) | 官方文档 |
| 子代理工具 schema | 决定岗位子代理用哪个 provider、能否后台、深度上限、工具过滤 | `name: '@deepseek-ai/dsh-tool-subagent'`，`config.provider`、`toolName`、`modelSelectionSettings`、`enableRunInBackground`（默认 true）、`backgroundMode: 'one-shot' \| 'continuable'`、`agentOptions`、`persona`、`toolFilter.allow[] / deny[]`、`maxDepth: <非负整数> \| 'provider-managed'`（省略则读宿主设置，默认 1） | [tool-subagent 配置目录](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/config-catalog.md) | 官方文档 |
| 子代理 provider 家族 | 同进程新建 / 历史分叉 / 跨进程 ACP、Codex、Claude Code、DSH SDK | 各行 `provider` 取值：`spawn`、`fork`、`acp`、`codex`、`claude-code`、`dsh-sdk`（跨进程 provider 以独立 Bundle 装入 profile） | [subagent 组 README](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/subagent/README.md)、[subagent-codex README](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/subagent/subagent-codex/README.md) | 官方文档 |
| 子代理控制工具 | 向邻近智能体发消息、打断当前回合、按 id 列出可续行子代理 | `name: '@deepseek-ai/dsh-tool-subagent-control'`（`send_message` / `interrupt_agent`）与独立子条目 `'@deepseek-ai/dsh-tool-subagent-control/list-agents'` | [tool-subagent-control README](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/subagent/tool-subagent-control/README.md) | 官方文档 |
| Hooks 桥（Claude Code） | 直接复用既有 Claude Code `hooks.json`：可阻断提示词/工具调用（退出码 2，stderr 为理由）、请求确认、附加上下文；覆盖 `SessionStart`、`UserPromptSubmit`、`PreToolUse`、`PostToolUse`、`Stop` | 装入 `@deepseek-ai/dsh-hooks-claude-code`，`config.configPath`（hooks.json 或含 `hooks` 键的设置文件，进程级、相对路径按启动 cwd 解析）、`pluginRoot`、`projectDir`、`defaultTimeoutMs`（默认 600000）、`stderrSummaryMaxChars` | [hook-protocol README](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/hooks/hook-protocol/README.md)、[hooks 配置目录](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/config-catalog.md) | 官方文档 |
| Hooks 桥（Codex） | 同上，matcher 恒为**非锚定正则**；不提供「先询问」选项 | 装入 `@deepseek-ai/dsh-hooks-codex`，`configPath`、`model`、`defaultTimeoutMs`、`stderrSummaryMaxChars` | [同上](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/config-catalog.md) | 官方文档 |
| Hooks 边界 | 仅 `command` 型钩子会执行；`http`/`mcp_tool`/`prompt`/`agent` 型被跳过并告警；`updatedInput` 已解析但**不生效**；`continue: false` 只记录、**无运行级停机效果**；钩子失败不中断回合 | 无需额外键（协议级限制） | [hook-protocol README](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/hooks/hook-protocol/README.md) | 官方文档 |
| 技能根与调用策略 | 多来源技能目录合并；新增 `customSkillDirs` 可挂预设自带技能根；frontmatter 控制模型/用户可见性 | `name: '@deepseek-ai/dsh-skill-filesystem'`，`config.customSkillDirs[]`、`includeDefaultRoots`、`dshHome`、`agentsHome`、`watch*` 系列；`SKILL.md` frontmatter 键 `disable-model-invocation`、`user-invocable`（缺省均为 true） | [skill-filesystem 配置目录](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/config-catalog.md)、[skills 子系统](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/subsystems/skills.md) | 官方文档 |
| 技能本地发现优先级 | 项目根 = 最近含 `.git` 的祖先；`<project>/.dsh/skills`（rank 100）优先于 `<project>/.agents/skills`（rank 200）；**不支持** 递归 `**/SKILL.md`；名称须 kebab-case | 目录约定，无配置键 | [skills 子系统](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/subsystems/skills.md) | 官方文档 |
| MCP 服务器 | 接入外部 MCP 服务器，模型可调用其工具、读取资源与 instructions | 装入 `@deepseek-ai/dsh-mcp-client`，`config.transport: 'stdio' \| 'streamable-http'`、`serverName`（`[A-Za-z0-9_-]{1,32}`，工具名 `mcp__<serverName>__<rawName>`）、`command`/`args`/`env`/`cwd` 或 `url`/`headers`、`toolCallTimeoutMs`、`failOnStartupError`、`maxInstructionBytes`（默认 32768）、`reconnect.{enabled,initialDelayMs,maxDelayMs,maxAttempts}` | [mcp-client 配置目录](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/config-catalog.md)、[mcp 组 README](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/mcp/README.md) | 官方文档 |
| 沙箱策略声明 | 部署级沙箱默认（**fail-safe 为 `read-only`**）与无 cwd 时的回退根；运行器选择不在此处 | `name: '@deepseek-ai/dsh-sandbox-policy'`，`config.mode?: 'read-only' \| 'workspace-write' \| 'danger-full-access'`、`workspaceRoot?` | [sandbox-policy 配置目录](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/config-catalog.md)、[sandbox 组 README](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/sandbox/README.md) | 官方文档 |
| 配置层级 | 组合顺序：各 bundle patch（按 `dsh.profile.bundles`）→ profile `cordis.patch.yml` → `$DSH_HOME/cordis.patch.yml` → `--patch` overlay | `$DSH_HOME/profiles/<name>/package.json`（含 `dsh.profile` + `bundles`）、`cordis.patch.yml`、`$DSH_HOME/cordis.patch.yml` | [CLI README](https://github.com/deepseek-ai/deepseek-harness/blob/master/apps/cli/README.md) | 官方文档 |
| 配置检视 | 不启动即检视组合树与 schema；schema dump 有专门安全范围说明（面对不可信插件时须先读） | CLI：`--dump-default-config`、`--dump-config`、`--dump-config-schema` | [CLI README](https://github.com/deepseek-ai/deepseek-harness/blob/master/apps/cli/README.md) | 官方文档 |
| 插件版本兼容 | 安装与启动均校验插件声明的 DSH peer 范围；不兼容需显式确认的精确版本豁免 | CLI：`dsh plugin --profile <p> version-exemptions`、`allow-version <pkg@ver> --dsh-version <rt> --accept-risk`、`revoke-version ...` | [plugin-manager README](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/boot/plugin-manager/README.md) | 官方文档 |
| 桌面端内置 CLI | 菜单栏可安装并管理 `dsh` 命令与插件，无需另装 Node/pnpm（macOS/Windows） | 桌面菜单「Manage dsh command」 | [v0.2.0-rc.2 发行说明](https://github.com/deepseek-ai/deepseek-harness/releases/tag/dsh-v0.2.0-rc.2) | 官方发行说明 |
| 异步问答模式（实验） | 等待超时后 Agent 可继续独立工作，用户稍后回答 | 需**手动配置开启**（发行说明未给出键名） | [v0.2.0-rc.2 发行说明](https://github.com/deepseek-ai/deepseek-harness/releases/tag/dsh-v0.2.0-rc.2) | 官方发行说明 |
| Claude Code Mods 兼容层（实验） | 验证 Claude Code Mods API 大致是 DSH 插件的子集 | 发行说明未给配置面；npm 上未检索到对应包名 | [v0.2.1-alpha.1 发行说明](https://github.com/deepseek-ai/deepseek-harness/releases/tag/dsh-v0.2.1-alpha.1) | 官方发行说明（配置面未核验） |
| 定时提醒工具可用范围 | `schedule_*` 提醒工具按模式提供：**标准 / 创造 / PTC 可用，极简模式与子代理不可用**；自动化任务改为 Web 内置能力 | 预设组合中声明 `schedule_*` 工具行（standard/cordis/ptc 预设已声明）；旧实验 bundle 自动清理 | [v0.2.1-alpha.1 发行说明](https://github.com/deepseek-ai/deepseek-harness/releases/tag/dsh-v0.2.1-alpha.1)、[schedule bundle 退役指南](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/upgrade-guide/v0.2.0-rc.2/schedule-bundle-retired/guide.zh.md) | 官方发行说明 / 官方升级指南 |
| 移除项（破坏性） | `@deepseek-ai/dsh-invariants` 与所有 `<pkg>/invariant` 子路径导出被移除；引用它们的 `cordis.yml`/patch/overlay 无法加载 | 删除 `name` 为 `@deepseek-ai/dsh-invariants` 或以 `/invariant` 结尾的行，及 id 为 `invariants`/`session-invariant`/`agent-invariant`/`scope-invariant`/`agent-loop-invariant` 的 patch | [invariants 移除指南](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/upgrade-guide/v0.2.0-rc.2/remove-runtime-invariants/guide.zh.md) | 官方升级指南 |
| 子路径插件展示 | 子路径插件不再读 `<子路径>/package.json`；标题/描述改读 `locale/*.json` 的 `meta.title`/`meta.description`，图标改由 `./<sub>/icon` 导出 | 包 `exports` 与 `files`（仅影响导出子路径 `package.json` 的包作者） | [子路径清单指南](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/upgrade-guide/v0.2.0-rc.2/subpath-plugin-display-manifest/guide.zh.md) | 官方升级指南 |
| 账号登录错误码 | `SignInErrorCode` 新增 `no-response`（fetch 未返回 Response，含单次超时） | 客户端 `SignInAttemptView.errorCode` 的校验器需补该取值 | [账号错误码指南](https://github.com/deepseek-ai/deepseek-harness/blob/master/docs/upgrade-guide/v0.2.0-rc.2/account-sign-in-errors/guide.zh.md) | 官方升级指南 |
| 人设（persona） | 预设可覆盖部署级人设，或让 prefix 成为**唯一**系统提示词、关闭运行时上下文快照 | `name: '@deepseek-ai/dsh-persona'`，`config.prefix`（必填）、`suffix`（默认空串，**不继承**全局后缀）、`complete`（默认 false）、`includeRuntimeContext`（默认 true）；`{{…}}` 变量在渲染时解析 | [persona README](https://github.com/deepseek-ai/deepseek-harness/blob/master/packages/preset/persona/README.md) | 官方文档 |

## 三、对本预设（dsh-codepunk）的可用性

| 特性 | 判定 | 采用所需改动（文件 · 键） |
|---|---|---|
| 预设声明 / 注册表字段 | 可直接采用（**已用**） | 无。`agent.cordis.yml` 现有写法与 schema 一致 |
| `modeSelectionEnabled` 退役 | 可直接采用（**已符合**） | 无：本预设未使用该键，无需清理 |
| `tool-subagent` 全字段面 | 可直接采用 | 可选增强：`agent.cordis.yml` 各 `tool-subagent*` 行新增 `enableRunInBackground`、`modelSelectionSettings: true`（按宿主子代理模型选择）、或把 `maxDepth: 1` 改为 `'provider-managed'`（仅跨进程 provider） |
| `interrupt_agent` 工具 | **需改造（低成本）** | `agent.cordis.yml` 中 `tool-subagent-control` 行已挂载，`interrupt_agent` 随该插件提供；需在 `skills/dsh-codepunk-workflow`（解散/中断流程）与人设承重规则中写明「解散阶段用 `interrupt_agent` 而非仅 `send_message`」 |
| Hooks 桥（Claude Code / Codex） | **需改造（谨慎）** | 需在 **profile 层**（`$DSH_HOME/profiles/<name>/cordis.patch.yml`）新增 `@deepseek-ai/dsh-hooks-claude-code` 行并指 `configPath`；但门禁已由 `plans/*.sh` 机械守护，且钩子**无法硬停机、不能改写工具输入**，故只宜作补充提示，不宜替代门禁 |
| 技能 `customSkillDirs` | 可直接采用（**已用**） | 无。`agent.cordis.yml` 的 `skill-filesystem` 行已用 `customSkillDirs` 指向预设自带 `skills/` |
| 技能调用策略 frontmatter | 可直接采用 | `skills/dsh-codepunk-workflow/SKILL.md` frontmatter 可加 `user-invocable: false`（若只允许模型加载）等键；缺省 true，不改也安全 |
| MCP 客户端 | 不适用（当前形态） | 本预设为开源可复制预设，MCP 行需装在 **profile**（`cordis.patch.yml`）而非 `agent.cordis.yml`；若要随预设分发，须新增「安装时打 profile patch」的部署步骤（`docs/deployment.md`） |
| 沙箱策略声明 | 不适用 | 沙箱与审批栈属宿主平面（本预设注释已明示）；预设不应声明 `sandbox-policy` |
| 插件版本兼容 / 豁免 | 可直接采用 | 无代码改动；升级 DSH 后若插件被跳过，用 `dsh plugin --profile <p> version-exemptions` 排查，并写入 `docs/maintenance.md` 的升级检查项 |
| 配置检视与 schema dump | 可直接采用 | 无。建议把 `dsh --dump-config-schema` 作为预设升级自检步骤写入 `docs/development.md`（先读 schema-dump 安全说明） |
| `schedule_*` 工具范围收紧 | 需改造（认知项） | 在 `skills/dsh-codepunk-workflow` 中注明：**子代理内无定时提醒工具**，定时巡检只能由主会话声明与执行（与现有 D095 巡检纪律一致） |
| 破坏性移除（invariants / 子路径清单 / 登录错误码） | 不适用 | 本预设未引用 `dsh-invariants`、未导出子路径插件、不处理账号错误码 |
| 桌面端内置 CLI | 可直接采用 | 无文件改动；升级后可用菜单栏安装 `dsh` 命令，便于在应用外跑 `plans/` 门禁与 `--dump-config` |

## 四、未核验项清单

1. **`preset.yml`（`name`/`description`/`order`）无官方文档佐证**：官方仓库中检索到的预设形态是「组合行 + `agent-preset` 声明 + bundle patch」，未找到描述 `preset.yml` 展示元数据的官方页面 ⇒ 该文件的规范**无法核验**。
2. **2.0.17 之后是否有更新桌面版**：仅能确认 `anywhere-labs/deepseek-harness-desktop` 的 tags 以 `v2.0.17` 为最新（另有 `-next`/`-beta.1` 同源变体）；是否存在未打 tag 的更新渠道**无法核验**。
3. **Claude Code Mods 兼容层**：仅见 `v0.2.1-alpha.1` 发行说明一句话；npm 上未检索到对应包名，配置面**无法核验**。
4. **异步问答模式**：发行说明称「需要手动配置开启」但未给键名，键名与取值**无法核验**。
5. **各机制的引入版本号**：官方 changelog 只按发布批次列举用户可见变化，未逐机制标注引入版本；本简报中标为「已用/未用」的机制（hooks、MCP、persona 的 `complete`/`includeRuntimeContext` 等）**具体引入版本无法核验**。
6. **`dshbase.com` 教程内容**：属第三方非官方站点，其安装页版本信息已过期，不作为事实依据。
7. **`docs.deepseek.com` 类官方文档站**：本次检索未发现独立于 GitHub 仓库的官方文档站点 ⇒ 官方文档唯一可核验来源是 `github.com/deepseek-ai/deepseek-harness` 仓库内 Markdown。

检索时间：2026-10-08（Asia/Bangkok）；本简报所有 URL 均为本次实际访问。
