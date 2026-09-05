# 调研简报：AI Agent 文件卫生 / 残留治理 Skill 与最佳实践

> 支撑决策号：D079（文件卫生）

> 委托方痛点：dsh-codepunk 多智能体工作中产生备份文件、探索性文件、/tmp 残留、未清理 scaffold、重复 artifacts、worktree 残留。
> 目标：找到「防产生」+「及时清理」双管齐下的可落地机制。
> 撰写：ind-res（调研小组）· 2026-08-25T21:45Z（本地 2026-08-26 05:45）

---

## 0. 检索窗口 / 渠道（透明声明）

- **渠道：全程 curl 直连 GitHub REST API / raw.githubusercontent / 官方文档 llms.txt**。`web_search` 与 `web_fetch` 工具在本会话不可用（web_search API key 无效；web_fetch 无可用 provider），故全部改用 curl，可复现。
- 检索对象：GitHub 仓库全树（git/trees API）、仓库元数据（star/license）、SKILL.md / 文档 raw 全文、Claude Code 官方文档全集（llms-full.txt 8.0MB）、agentskills.io 规范站（llms.txt + llms-full.txt）。
- **局限**：GitHub code-search（按内容搜代码）需认证 token，未使用；只做了仓库级检索 + 树级文件名/关键词过滤，可能漏掉「文件名不含关键词」的清洗类 skill；agentskills.io 的 `skill-creation/best-practices.md` 抓取失败（SSL 断连，重试失败），其规范侧卫生条款未能核实。
- 检索时间窗：2026-08-25T21:30Z – 21:45Z。所有 URL 的 retrieved_at 均为此窗口。

---

## 1. 定位结论（有没有现成 skill？哪个最好？）

### 1.1 「通用文件残留清理 skill」在主流生态中基本是空白
【事实】对 5 个生态旗舰仓库做全树关键词过滤（clean/tidy/housekeep/hygiene/scratch/junk/stale/backup…）：

| 仓库 | star | 全树文件数 | 清理/卫生类 skill？ |
|---|---|---|---|
| anthropics/skills | 171.5k | 417 | ❌ 无（仅 pptx/clean.py 等技能内部脚本） |
| obra/superpowers | ~20k | 195 | ❌ 无 |
| VoltAgent/voltagent | 10.4k | 2881 | ❌ 无（仅 1 个无关的 defer-cleanup 工具测试） |
| openai/codex 官方 AGENTS.md | — | — | ❌ 规范文档无临时文件/卫生条款（grep 零命中） |
| agentskills.io 官方规范站 | — | llms-full 93KB | ❌ 全站文档无 cleanup 类条款，且该站是静态文档站（无 skill 目录页，sitemap 仅 9 页） |

来源：https://api.github.com/repos/anthropics/skills/git/trees/main?recursive=1 ；https://api.github.com/repos/obra/superpowers/git/trees/main?recursive=1 ；https://api.github.com/repos/VoltAgent/voltagent/git/trees/main?recursive=1 ；https://raw.githubusercontent.com/openai/codex/main/AGENTS.md ；https://agentskills.io/llms-full.txt

【推断】「防文件残留」在主流生态中被视为**引擎/流程职责而非 skill 职责**（见 1.3 官方机制），且 Anthropic/OpenAI 都不提供清理类官方技能，故没有「高 star 现成即用」的通用清理 skill。

### 1.2 最对口的现成 skill：`alexzheng-unzen/agent-housekeeping`（新仓库，质量最高）
【事实】GitHub 搜索 `housekeeping agent skill` 命中 5 个仓库，其中唯一直面本主题的是 **agent-housekeeping**：专为「agent 自己」写的行为约束 skill——五条硬红线（违者=bug）+ 软规则 + 结束前自查清单 + 触发式清理报告。MIT 许可，SKILL.md 双语（中/英）。仓库仅 3 文件（README/SKILL/LICENSE），0 star（2026-08 新建）。
- 仓库与全文：https://raw.githubusercontent.com/alexzheng-unzen/agent-housekeeping/main/SKILL.md ；README：https://raw.githubusercontent.com/alexzheng-unzen/agent-housekeeping/main/README.md
- 其五条硬规则：① 禁止路径字符串拼接/对 mkdir 传绝对路径（真实事故：产生「路径形状」的垃圾目录）；② 运行时状态文件（.status/.lock/.pid/.heartbeat）绝不写进项目/家目录，必须进 `~/.<tool>/` 或 `/tmp`；③ 未经要求不创建任何 *.md 文档；④ 未经要求不创建脚手架（tests/、dist/、*.spec、legacy/、__pycache__）；⑤ 不越权重构/不写没有调用方的抽象。
- 其软规则/自查：每次编辑后 `git status` 即查即删；结束 session 前必跑自查清单（.lock 泄漏、未要求文档、编辑 >10 文件红旗、只读目录触碰）；发现问题**报告用户、不擅自删除**；项目 AGENTS.md > 本 skill > agent 默认行为。

【推断】这是「防产生」+「终态自查」最完整的最小可复用模板，直接可改造为 dsh-codepunk 的卫生契约；「报告不擅删」原则天然适配 dsh-codepunk 的巡检岗角色。

### 1.3 「及时清理」的现成机制：官方引擎能力 + davila7 命令集
【事实】
- **Claude Code 官方已把「及时清理」内建为引擎机制**（文档全集有据）：
  - per-session 专用临时目录 `~/.claude/jobs/<id>/tmp/`（环境变量 `CLAUDE_JOB_DIR`），写入免权限、session 删除时移除 —— https://code.claude.com/docs/llms-full.txt（line 1357-1359 段落）
  - 保留期自动清扫 `cleanupPeriodDays`（默认 30 天，最小 1），覆盖 transcripts/tasks/shell-snapshots/backups 与**孤儿 worktree** —— 同上（line 13356 段）
  - worktree 生命周期自动管理：交互退出时检查（有改动/untracked/新 commit 则保留并询问），subagent 用完无改动即自动删除，有改动留至定期 sweep；sweep 跳过仍有未提交/未推送工作的 worktree；agent 运行时 `git worktree lock` 防并发误删；建议 `.claude/worktrees/` 进 .gitignore —— https://code.claude.com/docs/en/worktrees.md
  - auto mode 拦截破坏性 git 命令（`git reset --hard` / `git checkout -- .` / `git clean -fd` / `git stash drop`）除非用户明确要求丢弃本地工作 —— changelog line 5130（https://code.claude.com/docs/llms-full.txt）
  - Agent Teams：子 agent 共享目录 session 结束自动清理（v2.1.178 起）—— llms-full line 359
- **davila7/claude-code-templates（MIT，30.4k★，社区命令/循环集）** 提供最完整的 git 保洁命令族：
  - `worktree-cleanup`：dry-run 支持；`git branch --merged` + squash-merge 空 diff 双判定；主仓校验（不能在 worktree 里清理 worktree）→ https://raw.githubusercontent.com/davila7/claude-code-templates/main/cli-tool/components/commands/git-workflow/worktree-cleanup.md
  - `repo-cleanup-loop`（engineering loop，7 天周期）：陈旧分支/废弃 PR → 先 salvage 有价值工作到 issue/新分支 → 再删除，配套停止条件 → https://raw.githubusercontent.com/davila7/claude-code-templates/main/cli-tool/components/loops/engineering/repo-cleanup-loop.md
  - 另有 `clean-branches` / `cleanup-cache` / `branch-cleanup`
- **SoloDawn（huanchong-99，312★）**：多智能体平台将「终态清理」设为**强制流程**（RB-37 规则：session 结束必须 `ProcessManager::cleanup_logical_session_home` / `cleanup_workspace`，否则泄漏带凭据临时目录）—— 平台级强制而非自觉行为 → https://api.github.com/repos/huanchong-99/SoloDawn/git/trees/main?recursive=1 + https://raw.githubusercontent.com/huanchong-99/SoloDawn/main/docs/quality/PRD-ai-editable-quality-rules.md
- `jasonkneen/housekeeping-skill`（3★）：方向不同——审计清理 `~/.claude` 配置目录（token 浪费、孤儿插件、缓存/日志/备份/临时文件），不针对项目残留；可作「agent 工具自身卫生」参考 → https://api.github.com/repos/jasonkneen/housekeeping-skill
- `wshobson/agents`（MIT，39.1k★）`codebase-cleanup` 插件：deps-audit/refactor-clean/tech-debt——代码质量型清理，非文件残留型，仅作生态佐证 → https://api.github.com/repos/wshobson/agents/contents/plugins/codebase-cleanup

【推断】对 dsh-codepunk 的最优路线 = **「借用官方引擎机制 + 移植 agent-housekeeping 规则 + davila7 命令族做巡检工具 + SoloDawn 式强制门闩」，而非等待/寻找一个现成的通用清理 skill（不存在）**。

---

## 2. 技巧清单（技巧 | 来源 | 适用场景 | 对 dsh-codepunk 的应用建议【事实/推断】）

| # | 技巧 | 来源 | 适用 | 对 dsh-codepunk 应用建议 |
|---|---|---|---|---|
| T1 | 五条硬规则防产生：禁路径拼接、状态文件不进项目目录、不主动建 md/脚手架、不越权重构（违者=bug） | agent-housekeeping SKILL.md | 所有 agent | 【事实】skill 原文如此。【推断】直接移植为「工作房卫生契约」，小组开工前必读；把「上游产出物必须先 glob 查重再生成」并入第四条防重复 artifacts |
| T2 | 状态文件（.lock/.pid/.heartbeat）只进 `~/.<tool>/` 或 /tmp，绝不出现在项目/家目录 | agent-housekeeping Rule 2 | 所有 agent | 【事实】同上。【推断】dsh 约定所有多智能体运行时文件写入 `$TMPDIR/dsh-codepunk/<task-id>/`，工作房内同规则 |
| T3 | 结束前自查清单：git status、怪异目录、.lock 泄漏、非要求文档、编辑文件数红旗（>10）、只读目录 | agent-housekeeping §5 | 终态检查 | 【事实】清单原文可用。【推断】并入 dsh-codepunk 交接包为「残留自查」必填节，与巡检双门闩联动 |
| T4 | 发现残留→报告用户/组长，不擅自删除；给建议（删/留/移到 ~/.<tool>/state/） | agent-housekeeping §6 | 多 agent 协作 | 【事实】skill 原文原则。【推断】与 dsh 巡检岗「只报告不擅改」一致；删除动作走巡检岗 + 工程主责确认 |
| T5 | 规则层级：项目 AGENTS.md > skill 默认 > agent 默认行为 | agent-housekeeping §7 | 规则冲突 | 【推断】dsh-codepunk 卫生契约定位为「默认层」，项目级覆盖优先，避免硬编码冲突 |
| T6 | per-session 专用临时目录（$CLAUDE_JOB_DIR/tmp，写入免权限，session 删除即清） | Claude Code 官方 claude-directory 文档 | 任何 agent | 【事实】官方机制。【推断】dsh 复刻为统一约定：临时写入只允许在工作房临时目录，session 结束必删；防 /tmp 随机残留 |
| T7 | 保留期自动清扫（cleanupPeriodDays，默认 30 天，覆盖日志/快照/孤儿 worktree） | Claude Code 官方（llms-full line 13356） | 长期仓库 | 【推断】dsh 工作房设统一清扫策略（如演示/临时数据 7 天），由巡检岗执行而非依赖每个 agent 自觉 |
| T8 | worktree 生命周期：退出检查、干净才删、sweep 跳过有未提交/未推送工作的、运行中 lock、.claude/worktrees/ 进 .gitignore | Claude Code worktrees.md | worktree 并发 | 【事实】官方机制。【推断】dsh 工作房=git worktree 且统一前缀（如 `dsh/*`），清理巡检照此执行 |
| T9 | 破坏性 git 命令防护：未要求丢弃本地工作时拦截 reset --hard / checkout -- . / clean -fd / stash drop | Claude Code changelog（llms-full line 5130） | 防误删 | 【事实】官方 auto mode 行为。【推断】dsh 用 hooks/规则复刻：未授权禁止 `git clean -f/-fd`、`reset --hard`；演练一律 `git clean -nd` |
| T10 | merged 判定双检：`git branch --merged` + squash-merge 空 diff 判定 | davila7 worktree-cleanup.md | 分支/worktree 清理 | 【事实】命令原文。【推断】巡检岗清理脚本直接采用，减少「看起来删干净实则残留」 |
| T11 | 周期性保洁 loop（7 天）：陈旧分支/PR → 先 salvage 到 issue → 再删；有停止条件 | davila7 repo-cleanup-loop.md | 长周期治理 | 【推断】dsh 巡检岗每周跑「分支/工作房保洁」，salvage 原则防止丢未合并工作 |
| T12 | 平台级强制终态清理（RB-37：session 结束强制 cleanup_workspace / cleanup_logical_session_home，否则泄漏凭据） | SoloDawn 质量规则文档 | 多智能体平台 | 【事实】SoloDawn 强制机制。【推断】dsh 把「终态清理 check」设为流程硬门闩（同现有双门闩），而非 agent 自觉项 |
| T13 | Agent Teams 共享目录 session 结束自动清理 | Claude Code Agent Teams 文档（llms-full line 359） | 多 agent 协作 | 【事实】官方机制。【推断】dsh 团队公共区（共享 scratch/目标目录）生命周期绑定小组会话，解散阶段自动清扫 |
| T14 | 规则要少而硬：CLAUDE.md 膨胀会导致 agent 忽略指令 | Claude Code best-practices（https://code.claude.com/docs/en/best-practices） | 纪律设计 | 【事实】官方 best-practices 原话。【推断】dsh 卫生契约限「少量硬规则 + IMPORTANT 强调」，避免「规则太多被忽略」的已知失效模式 |

---

## 3. TOP 落地清单（按价值排序，9 条）

1. **双门机制**：开工加载「卫生契约」（T1 五条硬规则，防产生）+ 收尾必跑「残留自查清单」（T3，及时清理）——两者都已有现成可复用文本（agent-housekeeping），是目前已知性价比最高的动作。【T1/T3】
2. **临时文件集中化**：所有 agent 的临时/探索写入统一收敛到 `$TMPDIR/dsh-codepunk/<task-id>/` 或工作房专用目录，**session 结束必删**；产出物只进预先声明的产出目录（对照官方 $CLAUDE_JOB_DIR/tmp 机制 T6）。【T6/T2】
3. **残留自查进交接包**：交接包增加必填节：`git status` 检查 + untracked 清单 + 临时目录清单 + 重复 artifacts 查重结果；发现残留→报告（T4 报告模板），删除由巡检岗执行。【T3/T4】
4. **worktree 纪律落地**：工作房=git worktree，统一前缀；`.claude/worktrees/` 与产出目录进 .gitignore；清理采用 merged+squash 双判定（T10），跳过有未提交/未推送工作的（T8）；agent 运行时 lock。【T8/T10】
5. **git clean 演练制度**：巡检时先 `git clean -nd` 干跑（backup/探索文件/scaffold/tmp 残留一览），人工确认后再 -fd；hooks 拦截未授权 `git clean -f/-fd`、`reset --hard`、`stash drop`（T9）。【T9】
6. **7 天保洁 loop**：巡检岗每周按 repo-cleanup-loop 模式：salvage 有价值未合并工作→issue/新分支→删除陈旧分支与孤儿 worktree，并核对保留期清扫（T7/T11）。【T11/T7】
7. **终态清理设为硬门闩**：把「残留自查通过」做成小组解散/交接的前置条件（SoloDawn RB-37 的强制思路 T12），与现有巡检双门闩并列。【T12/T3】
8. **防重复 artifacts**：生成任何产物前先 glob 查重（编辑优先于新建，agent-housekeeping 软规则），需求确认阶段显式声明「本次产出文件清单」。【T1】
9. **契约精简**：卫生规则控制在「5 硬规则 + 1 自查清单 + 1 报告模板」规模，配 IMPORTANT 强调，避免 CLAUDE.md 膨胀失效（T14）。【T14】

---

## 4. License / 复用性

| 素材 | License | 复用性 |
|---|---|---|
| agent-housekeeping | **MIT**（README 与 LICENSE 均注明，Copyright 2026 Alex Zheng）| 【事实】可直接 clone/改造为 dsh-codepunk 卫生 skill（MIT 允许） |
| davila7/claude-code-templates | MIT（30.4k★）| 【事实】worktree-cleanup / repo-cleanup-loop 命令可照抄改造 |
| wshobson/agents | MIT（39.1k★）| 【事实】仅生态佐证，复用价值低 |
| jasonkneen/housekeeping-skill | 无 SPDX license 字段 | 【事实】参考思路即可，不直接复用 |
| SoloDawn | NOASSERTION（自定义/未标准化）| 【事实】仅借鉴机制（强制终态清理），不从代码层面复刻 |
| anthropics/skills | 仓库无 LICENSE 文件 | 【事实】官方文档类引用性使用；未核 README 补充条款 |
| Claude Code 官方文档 / agentskills.io | 官方文档 | 【事实】机制说明引用性使用（已注明 URL），不受代码 license 约束 |

**复用路线建议**：以 agent-housekeeping（MIT）为骨架 → 并入 davila7 的 worktree-cleanup / repo-cleanup-loop 命令做巡检工具 → 参照官方引擎机制与 SoloDawn 强制门闩补「清理执行层」→ 产出 dsh-codepunk 卫生 skill。

---

## 附：来源清单（全部 retrieved_at = 2026-08-25T21:30–21:45Z）

1. https://raw.githubusercontent.com/alexzheng-unzen/agent-housekeeping/main/SKILL.md （全文）
2. https://raw.githubusercontent.com/alexzheng-unzen/agent-housekeeping/main/README.md
3. https://raw.githubusercontent.com/alexzheng-unzen/agent-housekeeping/main/LICENSE
4. https://api.github.com/repos/anthropics/skills/git/trees/main?recursive=1
5. https://api.github.com/repos/obra/superpowers/git/trees/main?recursive=1
6. https://api.github.com/repos/VoltAgent/voltagent/git/trees/main?recursive=1
7. https://api.github.com/repos/wshobson/agents/contents/plugins/codebase-cleanup
8. https://api.github.com/repos/jasonkneen/housekeeping-skill
9. https://raw.githubusercontent.com/jasonkneen/housekeeping-skill/main/SKILL.md
10. https://raw.githubusercontent.com/davila7/claude-code-templates/main/cli-tool/components/commands/git-workflow/worktree-cleanup.md
11. https://raw.githubusercontent.com/davila7/claude-code-templates/main/cli-tool/components/loops/engineering/repo-cleanup-loop.md
12. https://code.claude.com/docs/llms-full.txt （8.0MB 官方文档全集；引用行：359/1357-1359/5130/13356 等）
13. https://code.claude.com/docs/en/worktrees.md
14. https://code.claude.com/docs/en/best-practices
15. https://api.github.com/repos/huanchong-99/SoloDawn/git/trees/main?recursive=1
16. https://raw.githubusercontent.com/huanchong-99/SoloDawn/main/docs/quality/PRD-ai-editable-quality-rules.md （RB-37 强制终态清理）
17. https://raw.githubusercontent.com/openai/codex/main/AGENTS.md （无卫生条款，负面证据）
18. https://agentskills.io/llms-full.txt / https://agentskills.io/sitemap.xml （规范站无清理类内容）
19. GitHub 搜索接口 3 次：q=agent+skills+cleanup / q=housekeeping+agent+skill / q=SoloDawn

**检索局限备忘**：code-search 未用（需 token）；agentskills.io best-practices.md 抓取失败（SSL）；anthropics/skills 无 LICENSE 文件。