# CHANGELOG · 更新日志

本仓遵循 [Keep a Changelog 1.1.0](https://keepachangelog.com/zh-CN/1.1.0/) 与[语义化版本 2.0.0](https://semver.org/lang/zh-CN/)。
**版本以 git tag 与本文件为唯一权威**（`preset.yml` 只承载展示元数据，不含版本字段）；发布流程见 `CONTRIBUTING.md`，治理与发布权限见 `GOVERNANCE.md`。

段内分类固定如下，不新增类别、不改变语义：

| 类别 | 用途 |
|---|---|
| 新增 Added | 对外可用的新能力、新文件、新门禁 |
| 变更 Changed | 既有行为的调整（含破坏性变更，须显式标注） |
| 弃用 Deprecated | 仍可用但计划移除的能力 |
| 移除 Removed | 已删除的能力或文件 |
| 修复 Fixed | 缺陷修复 |
| 安全 Security | 与安全相关的修复或加固（不含可利用细节） |

---

## [Unreleased]

### 新增

- **写盘纪律三层强制（硬规则 R17）**：机械门 + 硬规则 + 岗位写域三者同时生效，规定 AI 写入的优先序——运行根 → 授权工作树内该任务的写集路径 → 系统临时目录（次选，用毕即删）→ 总库 `knowledge/`；探针脚本一律落运行根 `logs/`；越界即缺陷并当轮清理。细则见 `skills/dsh-codepunk-workflow/references/file-hygiene.md` 与 `references/roles.md`。
- **写盘纪律机械门 `plans/write-scope-check.sh`**：三类判定——仓库残留（含未跟踪文件）/ 主目录顶层散落 / 临时目录双根残留；判定只认本契约命名空间（`dsh-codepunk-` 前缀条目），同形他人条目降级为 `ℹ`「归属不明」且不改判；`--exempt-from` 读取运行根 `README.md` 的 `write_scope.exempt:` 登记并把登记项及其子路径降级为 INFO；退出码 `0` 通过 / `1` 发现越界 / `2` 无法核验或用法错。
- **反思考循环规范（硬规则 R16）**：连续 3 步无新证据、或同一失败指纹重复达 2 次时，必须换策略或上报，不得原样重试；被证伪的结论与失败轨迹只保留结论与已证伪路径。细则见 `skills/dsh-codepunk-workflow/references/anti-loop.md`。
- **文档一致性第 24 类检查**：Markdown 表格列数一致与结构完整——逐项判定表头与分隔行的列数一致性、分隔行后紧跟空行的断表、围栏长度与类型配对、缩进代码块、引用块内表格、无行首竖线的表格，以及代码跨度内未转义的竖线。
- **根目录社区健康文件**：新增 `SECURITY.md`（安全策略与漏洞报告）、`CODE_OF_CONDUCT.md`（Contributor Covenant 2.1 中文译本与执行后果）、`SUPPORT.md`（求助渠道与提问模板）、`GOVERNANCE.md`（角色、决策、变更流程、发布权限、维护者产生）、`CHANGELOG.md`（本文件）。
- **CI 工作流与仓库规则脚本**：新增 `.github/workflows/ci.yml`，含四个作业 `门禁回归` / `存活自检` / `跨平台可移植` / `文档一致性`；配套 `plans/github-setup.sh` 生成仓库 Ruleset（`main` 受保护：必须经 Pull Request、必须通过上述四项状态检查、禁止强制推送与直接推送）。
- **协作模板与工程化入口**：新增 `.github/` 协作配置（`CODEOWNERS`、Issue 模板、PR 模板、Release 说明模板、Dependabot 更新配置，以及 `codeql.yml`、`scorecard.yml`、`release.yml` 工作流）；新增 `Makefile` 工程化入口（`gates` / `battery` / `selftest` / `write-scope` / `compat` / `mirror` / `clean`）；新增 `.editorconfig` 与 `.pre-commit-config.yaml`；`.gitattributes` 与 `.gitignore` 随新文件同步更新白名单。
- **合并流脚本 `plans/git-merge-flow.sh`**：把「建分支 → 提交 → 推送 → 开 PR → 以合并提交落地 → 删分支」收成 `start` / `commit` / `pr` / `merge` / `status` 五个动作，其中 `merge` 在删除远端分支前先断言分支顶端确实是合并提交（父数为 2），断言失败即保留分支以便排查。
- **面向使用者的专题文档**：新增 `docs/` 目录（`architecture.md`、`development.md`、`deployment.md`、`documentation-policy.md`、`naming-conventions.md`、`maintenance.md`、`faq.md` 与 `docs/adr/` 决策记录目录），并与 `README.md` 的文档索引相互引用。

### 变更

- **`README.md` 重写为使用者向概览**：按「定位 → 快速开始 → 机制概览 → 门禁与命令表 → 平台支持 → 目录结构与文档索引」组织，并把目录清单收敛为本文件的唯一权威来源。
- **`CONTRIBUTING.md` 重写为完整贡献流程**：新增环境准备、分支模型（`feat/` `fix/` `docs/` `chore/`）、提交信息约定、合并方式、PR 门禁与审查要求、发布流程与开发命令速查；原「维护公约要点」保留为独立一节。
- **合并方式明确为合并提交**：一律通过 Pull Request 以**合并提交（merge commit，`--no-ff`）**并入 `main`，仓库设置仅保留「Create a merge commit」；禁止直接推送与强制推送。
- **发布流程文档化**：版本号按语义化版本判定，`CHANGELOG.md` 的 `Unreleased` 段在发布时落为版本段，由维护者打 tag `vX.Y.Z` 并在 GitHub Releases 发布（发布说明直接取自本文件，不另写一套）。

### 修复

- **依赖更新自动合并的两条路径与自证判据**：对已可合并（`mergeStateStatus=CLEAN`）的 PR 武装自动合并会被 GitHub 拒绝（`Pull request is in clean status`），而武装成功后若立即可合并，GitHub 会当场合并并使 `autoMergeRequest` 变 `null` ⇒ 原自证判据误报失败。现改为「已可合并即直接以合并提交入库；否则武装，命中该错误时回退直接合并」，自证判据取「已武装**或**已合并」。见 `.github/workflows/dependabot-auto-merge.yml`。
- **`automerge` 标签路径可用**：工作流触发事件补 `labeled`（此前打标签不会触发），并由 `plans/github-setup.sh` 幂等创建该标签（此前仓库中不存在）。
- **无 `.git` 环境下 ps1 行尾校验被跳过而整体仍报「无硬性不一致」**：`doc-consistency.sh` 第 17 类的 ps1 工作树行尾（`eol=crlf` 落地）子项原先在 git 不可用时只打印跳过说明却仍以 rc=0 收尾，环境缺陷可整体假绿灯；现改为回退**文件系统字节核验**（剥离合法 CRLF 后仍有裸 LF 即判不合格），并按类 8 口径打印「已核验，非跳过」。
- **`make` 入口在含空格路径下不可用**：`Makefile` 的仓库根推导原用 `$(dir $(abspath $(lastword $(MAKEFILE_LIST))))`，Make 函数按空白分词 ⇒ 路径含空格时 `ROOT` 只取到首个词，配方 `cd "$(ROOT)"` 失败并 rc=2（克隆到 `…/克隆 空格 é` 后 `make gates` 报 `cd: …/r612 . é: No such file or directory`，而同一路径下四道门禁直调 rc 全 0）。现改为 `$(shell cd "$(CURDIR)" && pwd)`（直接调用与 `make -C <dir>` 均正确，路径只在 shell 层加引号出现）。
- **签收门自签判据不区分大小写**：`plans/acceptance-verify.sh` 原以区分大小写的子串判断「签收方是否为交付方」，交付方 `task-a` 的签收方写 `Task-A` 即判通过 ⇒ 自签可被改大小写绕过。现比较前统一去首尾空白并转小写。
- **签收门交付方参数改为必填**：该参原为可选，不传时独立性整段跳过却仍打印「PASS: 结构合法且签收独立」（声称已校验而实际未校验）。现缺交付方 ⇒ rc=2 并显式提示「无法核验 ≠ 通过」。
- **治理脚本覆盖自动合并能力**：`plans/github-setup.sh` 的仓库元数据期望、比对字段与请求体三处纳入 `allow_auto_merge=true`，最终回读新增该字段与标签校验（此前关闭该能力不会被脚本发现）。

---

## 版本比较链接

版本比较链使用 Keep a Changelog 的标准引用式写法，置于本文件**末尾**；在首个版本打 tag 之前不写死链接，避免死链。格式示例（`<` `>` 为占位符，替换为真实版本号后启用）：

```text
[Unreleased]: https://github.com/webees/dsh-codepunk/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/webees/dsh-codepunk/compare/v0.9.0...v1.0.0
[0.9.0]: https://github.com/webees/dsh-codepunk/releases/tag/v0.9.0
```

- `Unreleased` 段与**最新已发布版本**比较，段尾固定为 `...HEAD`；
- 相邻已发布版本之间用 `compare/<前一版本>...<本版本>`；
- 首个版本没有前驱版本可用，改用 `releases/tag/<版本>`。

版本段的标题形态固定为 `## [X.Y.Z] - <发布日期>`（日期为 ISO 形态）。在首次发布（打第一个 tag）之后，本文件须同时补上上面三条真实链接的定义。
