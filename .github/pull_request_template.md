<!--
PR 模板：四段式——变更类型 / 关联 issue / 核对清单 / 合并方式。
核对清单里的每一条都对应一个可复跑的命令或门禁，请如实勾选：未验证的功能不得声明完成。
-->

## 变更类型

- [ ] `feat` 新功能
- [ ] `fix` 缺陷修复
- [ ] `docs` 文档
- [ ] `ci` 构建 / CI / 门禁
- [ ] `refactor` 重构（行为不变）
- [ ] `chore` 杂务（依赖、配置、清理）
- [ ] `test` 测试

## 变更摘要

<!-- 一到三条：改了什么、为什么改（动机比改动更重要）。 -->

## 关联 issue

<!-- 用 `Closes #123` / `Refs #123` 形式；无关联 issue 时写「无（原因：…）」。 -->

Closes #

## 核对清单

- [ ] `bash plans/preset-audit.sh` 本地退出码 rc=0（100 分制审计全项达标）
- [ ] `bash plans/preset-score.sh` 本地退出码 rc=0（16 指标全满分）
- [ ] `bash plans/checker-self-test.sh` 本地退出码 rc=0，且末行含「自检通过」
- [ ] `bash plans/doc-consistency.sh` 本地退出码 rc=0，且输出含「无硬性不一致」
- [ ] 文档与计数已同步：README / SKILL / references 中出现的篇数、项数、分组数、规则上限等声称值，与实际文件一致
- [ ] 无私人信息：无本机绝对路径、无凭据、无私人词（`bash plans/dsh-codepunk-leak-guard.sh --tree` 通过）
- [ ] 工作区无临时物残留（`bash plans/write-scope-check.sh --repo . --home --tmp` 通过）
- [ ] 新增顶层文件已在 `.gitignore` 白名单登记（默认拒绝策略，否则静默不入库）
- [ ] 已在本地跑通上述命令并保留原始输出（贴关键片段或说明获取方式）

## 合并方式

- [ ] 本 PR 声明以 **merge commit** 合并（仓库策略只允许 merge commit，由 `plans/github-setup.sh` 应用到 main 分支保护）
- [ ] 目标是 `main` 分支，且四个必需状态检查（门禁回归 / 存活自检 / 跨平台可移植 / 文档一致性）全绿

## 影响面与回滚

<!-- 影响哪些脚本、哪些下游流程；出问题时如何回滚（revert 哪个提交即可）。 -->
