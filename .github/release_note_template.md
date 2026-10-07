<!--
Release 正文模板。
用途：`plans/` 之外的发布流程（.github/workflows/release.yml）在 CHANGELOG.md 缺版本段时，
以此模板生成骨架正文；平时也可作为撰写 CHANGELOG 版本段的骨架。

用法：把 `vX.Y.Z` 换成实际版本号，逐段填实；不适用的段落写「无」而不要删——留白与「无」在审阅时含义不同。
-->

## 变更摘要

<!-- 面向使用者：这个版本带来什么。每条一行，动词开头，说结果不说过程。 -->

- 新增：
- 修复：
- 变更：

## 兼容性

<!-- 破坏性变更必须在此点名并给出迁移动作；没有就写「无破坏性变更」。 -->

- 破坏性变更：无
- 需要的最低 DSH 版本：
- 受影响的平台：（macOS / Linux / Windows，注明差异）

## 升级步骤

```sh
# 1. 取到新版本
git -C <预设仓> fetch --tags && git -C <预设仓> checkout vX.Y.Z

# 2. 重建本地总库（同步 plans/ → ~/.dsh-codepunk/scripts）
bash plans/dsh-codepunk-init.sh

# 3. 自证（全部 rc=0 才算升级到位）
bash plans/preset-audit.sh
bash plans/preset-score.sh
```

## 门禁状态

<!-- 发布当时的门禁结论：四个必需状态检查 + 关键脚本的退出码。退出码语义：0=通过 · 1=失败 · 2=无法核验。 -->

- 门禁回归：rc=0
- 存活自检：rc=0
- 跨平台可移植：rc=0
- 文档一致性：rc=0
- 完整差异：见本页底部的 compare 链接
