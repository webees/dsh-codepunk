# 工作房卫生契约（references/file-hygiene.md）

> dsh-codepunk 防「临时文件/残留」机制（D079）。骨架借鉴 alexzheng-unzen/agent-housekeeping（MIT）+ davila7/claude-code-templates（MIT）+ SoloDawn RB-37 强制门闩思路 + Claude Code 官方 tmp/清扫机制。溯源：`benchmarks/file-hygiene-skill.md`（19 来源）。
> 定位：**防产生（开工契约）+ 及时清理（收尾自查）+ 强制门闩（解散前置）** 三层。

## 一、开工卫生契约（小组开工必读，五条硬规则）

1. **状态文件不进工程目录**：`.lock`/`.pid`/`.heartbeat` 等运行时状态只写 `$TMPDIR/dsh-codepunk/<task-id>/` 或工作房临时目录，**绝不出现在工程目录/总库项目目录**。
2. **不主动造文档/脚手架**：未要求则不建 README/说明书/样板目录；产出物只进简报声明的产出路径。
3. **不越权重构**：只做简报要求的改动；「顺手优化/顺带清理」即越界（D076 同源）。
4. **生成前查重**：任何 artifact 先 glob 查重——「编辑优先于新建」，防重复生成。
5. **临时写入集中化**：探索性/演示性文件一律 `$TMPDIR/dsh-codepunk/<task-id>/`，session 结束必删；工作房内禁止散落探索文件。

## 二、收尾残留自查清单（交接包必填节）

| # | 检查项 | 命令/做法 |
|---|---|---|
| 1 | 工作区状态 | `git status` —— 无意外 untracked/modified |
| 2 | 未跟踪文件 | `git status --porcelain` untracked 清单核对（产出物 vs 残留） |
| 3 | 临时目录 | `ls $TMPDIR/dsh-codepunk/<task-id>/` 应空或已删 |
| 4 | 怪异目录/文件 | 工作房内散落 `.log`/`.bak`/`~` 后缀/编号副本 |
| 5 | 重复 artifacts | 产出文件 glob 对照清单，无重复生成 |
| 6 | .lock 泄漏 | 工程/总库目录无 `.lock`/`.pid` 残留 |

发现残留 → **报告（不擅删）**：报告模板 = 位置 + 内容摘要 + 建议（删 `/ 留 / 移 $TMPDIR/dsh-codepunk/state/`）；删除动作由巡检岗 + 工程主责确认后执行（T4 原则）。

## 三、强制门闩（D079，SoloDawn RB-37 思路）

- 「残留自查通过」= 小组解散/交接的**前置条件**，与双门闩/审查门并列：交接包缺自查结果 → 整包打回（同 D077 证据门控）。
- 终态清理 check 是**流程硬项**，非 agent 自觉项。

## 四、巡检工具与周期（巡检岗执行）

1. **git clean 演练制度**：巡检先 `git clean -nd` 干跑（列出 backup/探索/scaffold/tmp 待删），人工确认后 `-fd`；未授权禁止 `git clean -f/-fd`、`reset --hard`、`stash drop`（破坏性拦截，T9）。
2. **worktree 清理双判定**：`git branch --merged` + squash-merge 空 diff 判定（davila7 worktree-cleanup）；跳过有未提交/未推送工作的 worktree（T8）；运行时 `git worktree lock` 防并发误删；`worktrees/` 与产出目录进 .gitignore。
3. **7 天保洁 loop**：陈旧分支/孤儿 worktree → 先 salvage 有价值未合并工作到 issue/新分支 → 再删（davila7 repo-cleanup-loop）；有停止条件。
4. **保留期清扫**：临时/演示数据 7 天保留（巡检岗执行清扫，不依赖各 agent 自觉）。

## 五、契约精简原则

卫生规则控制在本文件规模（5 硬规则 + 1 自查清单 + 1 报告模板 + 巡检工具集），配 IMPORTANT 强调；规则膨胀会导致 agent 忽略（Claude Code best-practices——少而硬）。