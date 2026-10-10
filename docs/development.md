# 开发指南

本文面向**本仓库的贡献者与维护者**：如何克隆、跑门禁、加检查项、同步计数、提交与合并。使用者视角的安装与部署见 [deployment.md](deployment.md)；流程语义见 [architecture.md](architecture.md)。

## 1. 环境前置

| 依赖 | 用途 | 缺失时的影响 |
|---|---|---|
| bash 3.2+ | 全部 `.sh` 门禁脚本（macOS 自带 `/bin/bash` 即可） | 无法跑门禁 |
| git | 工作树、索引相关检查（`git ls-files` 等） | 日期类、目录树类检查回退文件系统遍历（真核验，非跳过） |
| python3 | 多数判据的实现语言 | 相关检查报「无法核验」并按环境错误处理，**不得当作通过** |
| node | `.mjs` 工具（`preset-declare.mjs`、`ps-validate.mjs`） | 声明漂移校验不可用 |
| ruby 或 node | `agent.cordis.yml` 的 YAML 解析 | 组合解析类检查报「无法核验」 |

可选：PowerShell 语法校验器需 `tree-sitter` + `tree-sitter-powershell`（约 17 MB，装在 `~/.dsh-codepunk/tools`，不随仓库分发；缺失时该项跳过并明确提示，不判失败）。

脚本内已固定 UTF-8 locale：当 `locale charmap` 不是 UTF-8 且系统存在 UTF-8 locale 时自动 `export LC_ALL`。原因：C/POSIX 或 ISO-8859 系 locale 下 BSD 工具链逐字节处理，会**误报**一致性缺陷。手工复跑命令时请勿显式指定 `LC_ALL=C`。

**运行模式前置（`POSIXLY_CORRECT`）**：门禁脚本是 bash 脚本且使用 bash 扩展（进程替换 `< <(...)`）。若环境里设了 `POSIXLY_CORRECT=1`（或显式 `bash --posix`），bash 会进入 POSIX 模式：进程替换变成**语法错误**，退出码虽为 2 但输出里只有语法错误文本、没有保守措辞，于是上游会把「环境不支持」误归因为「脚本坏了」（实测：`preset-score` 报 `bash -n 失败`、`doc-consistency` 报「退出码契约漂移」）。因此 8 个门禁脚本（`doc-consistency` / `preset-audit` / `preset-score` / `dsh-codepunk-leak-guard` / `write-scope-check` / `verify-worktree` / `github-setup`）在**入口**检测该变量与 `set -o posix` 状态，命中即打印「POSIX 模式 ⇒ 无法核验 ≠ 通过」并 `exit 2`（无法核验 ≠ 通过）。要跑门禁就 `unset POSIXLY_CORRECT`。

## 2. 克隆与布局

```bash
git clone <仓库地址> ~/.dsh/.agent-presets/dsh-codepunk
cd ~/.dsh/.agent-presets/dsh-codepunk
git switch -c feat/<主题>          # 本仓按主题分支开发，不直接改主干
```

| 路径 | 内容 | 可否直接改 |
|---|---|---|
| `agent.cordis.yml` | AGENT-PLANE 组合（**权威源**） | 可以；改后须 `preset-declare.mjs apply` 并重启 DSH |
| `preset.yml` | 可选展示描述（`name` / `description` / `order`） | 可以 |
| `plans/` | 工具脚本源副本（16 个 `.sh` + 3 个 `.py` + 2 个 `.mjs`；其中 `dsh-codepunk-home.sh`、`env-guard.sh` 为纯 source 库，`plans/windows/` 4 个 `.ps1`） | 可以；改后须同步总库正式位 |
| `skills/dsh-codepunk-workflow/` | 流程手册 `SKILL.md` + `references/`（按需细则）+ `benchmarks/`（调研档案） | 可以 |
| `README.md` / `CONTRIBUTING.md` / `LICENSE` | 使用者向说明 / 贡献者向公约 / MIT 许可 | 可以 |
| `docs/` | 本套开发与架构文档 | 可以 |
| `~/.dsh-codepunk/**` | 运行期总库（运行根、知识库、脚本正式位） | **不是仓库内容**，勿在此改源 |

## 3. 本地门禁怎么跑

按「由快到慢」排序，逐级加严：

| 命令 | 覆盖 | 退出码 |
|---|---|---|
| `bash -n plans/*.sh` | 全部 shell 脚本语法 | 0 通过 |
| `node plans/preset-declare.mjs check` | 源 ↔ profile 内联副本漂移 | 0 一致 / 1 漂移 / 2 参数或环境错误 |
| `bash plans/doc-consistency.sh` | 文档「声称 ↔ 实现」一致性 27 类 | 0 一致 / 1 不一致 / 2 环境或用法错误 |
| `bash plans/preset-audit.sh` | 5 组 rubric 审计 | 0 全达标 / 1 有失分 / 2 预设根不存在 |
| `bash plans/preset-score.sh` | 16 指标评分 | 0 全满分 / 1 有失分 / 2 环境或用法错误 |
| `bash plans/checker-self-test.sh` | 检查器存活自检（226 项变异） | 0 全部捕获 / 1 有未捕获 / 2 环境或自检问题 |
| `bash plans/verify-battery.sh` | 完整验证电池（11 项，一次跑完） | 0 全通过 / 1 有失败项 / 2 无法进入预设根 |
| `bash plans/dsh-codepunk-leak-guard.sh --history` | 泄露防护门（近 20 提交与新增行） | 0 通过 / 1 命中阻断 / 2 用法或环境错误 |

判读要点：

1. **红项先看归属**：仓内并行开发时，门禁红项可能来自其他席正在飞的改动。先 `git status` / `git diff --name-only` 定位文件，再判断是否属自己的改动范围。
2. **`ℹ` 是咨询不是失败**：`doc-consistency.sh` 明确区分「咨询 / 仅提示」与硬性不一致；凡属「无法核验」者必写「无法核验 ≠ 通过」，其输出**不得**当作绿灯。
3. **退出码 2 不通过**：2 表示环境或用法错误（或无法核验）。把它当作失败处理并补齐环境。
4. 重型门禁在负载峰值下易超时：先自评成本、只跑一次并缓存结果，或改后台作业运行。

## 4. 一轮一提交与合并流

本仓沿用 **Conventional-Commits 风格，正文中文**：

```text
<type>(<scope>): <中文动宾式一句话>

改了什么、为什么、影响面；验证方式（命令 + 结果）
```

| type | 适用 |
|---|---|
| `fix` | 缺陷修复 |
| `docs` | 文档改动 |
| `feat` | 新增能力 |
| `perf` | 性能相关 |
| `test` | 检查项 / 夹具 / 自检 |
| `chore` | 杂项维护 |

- `scope` 取受影响模块，如 `windows` / `tools` / `skill` / `audit` / `score` / `config` / `stages` / `roles` / `docs`。
- 涉及流程缺陷时，标题末尾附发现编号 `（Fnnn）`，与 `references/skill-governance.md` 的溯源对齐。
- **一轮一提交**：一次评审轮对应一个提交，正文写清验证方式；不要把无关改动混入同一提交。
- 合并门前置（预设流程口径）：证据过 `plans/evidence-verify.sh`（`verdict=PASS`）+ `diff ⊆ write_paths` + 门禁文件齐 + `approvals/merge.yaml` 批准；串行合并、按依赖拓扑逐个进行，**禁止并行合并**。
- 文档型交付同门禁：改动仅限 `docs/` 与运行根状态文件，仍须合并门留痕。

## 5. 镜像规则：仓内 `plans/*` → 总库正式位

**运行期实际执行的是总库副本**，不是仓内副本：

```bash
bash plans/dsh-codepunk-init.sh            # 幂等：同步 plans/*.{sh,py,mjs} 与 plans/windows/*.ps1 → ~/.dsh-codepunk/scripts/
bash plans/dsh-codepunk-init.sh --check    # 只断言不写盘；非零退出即需同步
```

- 升级预设后 **MUST** 跑一次同步，否则运行期仍是旧逻辑。
- 同步按升级语义覆盖总库副本，并把脚本模式**归一为 755**（内容一致但模式漂移时同样修）；`~/.dsh-codepunk/config.yaml` 与 `INDEX.yaml` 既有内容不被改写。
- 从总库自身的副本运行只会提示「请改用仓内副本」，不会自我复制。

## 6. 新增检查项与变异 M 号规则

新增变异（`checker-self-test.sh`）时，M 号**顺延取下一个未用整数**，并遵守「新检查入库清单」：

| # | 规则 | 说明 |
|---|---|---|
| 1 | 分支可达 | 每条判定分支都要有能命中它的注入；绑定已废弃措辞的判据属「扣分永不可达」 |
| 2 | 变异生效 | 断言前确认变异真落盘：插入型验模式存在，删除 / 替换型用「旧值已消失」或「新值存在」确认 |
| 3 | 期望串特异 | `check_rc` 的期望串 MUST NOT 被被检脚本的**小节标题**包含，否则可能仅凭标题通过＝假通过 |
| 4 | 夹具不自伤 | 夹具不得含触发本仓守卫的字面量（用户目录绝对路径 / 邮箱形态 / 私网地址），须运行时拼接 |
| 5 | 计数同步 | 新增变异后同步 README 的声明计数（第 1 类会当场报错，属预期行为） |
| 6 | 双向留证 | 负向探针须同时记录「变异生效」与「捕获」两个事实，优先在副本内验证 |
| 7 | 文案自洽 | 新检查的消息文案不得含 shell 元字符（反引号等会被双引号当命令替换）或会被本检查自匹配的样例；改文案后同步所有断言期望串 |
| 8 | 判据不得空转 | 阈值 / 取值类判据 MUST NOT 用字面捕获，须用泛化捕获，并在负向探针里改动**另一侧**取值以证明能察觉分歧 |
| 9 | 原始文本可疑 ≠ 缺陷 | 基于原始文本匹配的怀疑，判定前 MUST 用真实解析器或运行时复核（注释与字符串的界限由解析器决定） |

断言**按检查项名称核对，不只看退出码**——只看退出码会因「其它项恰好也在失败」而误判为「已捕获」。

## 7. 派生计数口径（禁手写数字）

一切计数声称**从实现侧派生**，不手写、不猜：

| 计数 | 派生命令 | 当前实况 |
|---|---|---|
| 变异项数 | `grep -oE 'M[0-9]+' plans/checker-self-test.sh \| sort -u \| wc -l` | 226（M1–M226） |
| 文档一致性类数 | `grep -cE '^echo "\[[0-9]+' plans/doc-consistency.sh` | 30 |
| 电池项数 | `grep -cE '^# [0-9]+\)' plans/verify-battery.sh` | 11 |
| 保真语义类数 | 用 `ast` 取 `plans/fidelity-gate.py` 中 `PATTERNS` 的键数 | 14 |

> 表格单元格内的竖线须写作 `\|`（上表首行即是）。派生值一旦变动，须同步 README 与该表；`doc-consistency.sh` 第 1 类会校验 README **每一处**声明的唯一性与实况相符，并按**行标签**校验本表「当前实况」列（变异项数 / 文档一致性类数 / 电池项数）与实现派生值一致（F375）。

### 7.1 内容卫生上限（垃圾与重复治理，机械核验）

下表是**被机械核验的上限**：`plans/preset-score.sh` 的 `B16` 直接解析本表数字并复算实况，超限即扣分（解析不到 ⇒ 「无法核验 ≠ 通过」）。与仓库内容无关的临时统计不得写在这里。

| 指标 | 上限 | 口径 |
|---|---|---|
| 单文件字节 | 262144 | 逐个跟踪文件体积（超限者拆分或削减） |
| 跨文件重复块冗余 | 800 | ≥3 连续行、每行归一化后 ≥10 字符、块 ≥200 B 的重复块，按 (份数−1)×块字节 累计 |
| 跨文件重复行冗余 | 6500 | 归一化后 ≥40 字符且完全相同的行，按 (份数−1)×行字节 累计（D118 棘轮：许可正文一次跨文件复制即 6966 > 6500） |
| 孤儿内容 | 0 | 除白名单外，每个跟踪文件的文件名须在**其它**跟踪文件中出现 ≥1 次 |
| 溯源档案索引缺口 | 0 | `references/learned-skills.md` 的档案表条目数须等于 `benchmarks/` 目录内 `.md` 数，且「N 篇」声称相符 |

> **阈值只降不升（D118）**：削减落地后须同步下调本表数字，使收敛可见；需要上调时必须在决策登记表登记理由。收敛趋势的原始读数存运行根 `logs/`（工位仪器 `tools/junk-dup-scan.py`）。

## 8. README 计数声称同步

`README.md` 是使用者向的**计数权威宣称处**，下列声称必须与实现一致且**全文唯一**（同一数字在多处出现时，每处都会各自被校验）：

1. 质量工具表的项数：16 指标 / 5 组 / **11 项**电池 / **226 项**变异（M1–M226）/ **14 类**保真。
2. 计数口径文案中的示例（如「18 references」「16 benchmarks」一类声称）。
3. 硬规则上限、阶段数（六阶段）、岗位数（11 内建 + 2 外部后端；出现「13 岗位」须带历史或例外标记）。

改动目录结构段时另须注意：`verify-battery.sh` 会比对 **README 目录树 ↔ 仓内跟踪文件**，死条目与漏列都判失败。

## 9. 提交前检查清单

- [ ] 改动仅限必要文件，diff 清晰；非 `README.md` 改动在提交信息中说明目的、影响面与验证方式。
- [ ] `bash plans/doc-consistency.sh` 返回 0（或红项已定位归属）。
- [ ] `bash plans/checker-self-test.sh` 返回 0（新增检查项时必须）。
- [ ] `bash plans/dsh-codepunk-leak-guard.sh --history` 通过（禁词留在本地 `~/.dsh-codepunk/denylist.txt`，不进仓）。
- [ ] 改了 `plans/*.sh` 或 `plans/windows/*.ps1` → 两侧语义同步并各过语法校验。
- [ ] 改了 `agent.cordis.yml` → `node plans/preset-declare.mjs apply` 且 `check` 返回 0。
- [ ] 新增顶层文件 → 已在发布仓 `.gitignore` 白名单登记（默认拒绝策略，未登记会静默不入库）。
- [ ] 预设自身资料落在 `benchmarks/`，未写进任何工程目录。

## 10. 常见坑

| 现象 | 原因 | 处置 |
|---|---|---|
| 门禁报出莫须有的不一致 | 显式设了 C/POSIX 或非 UTF-8 locale | 取消显式设置，让脚本自行固定 UTF-8 |
| `plans/` 内跑门禁后出现杂散项 | 生成了 `plans/__pycache__/*.pyc` | 已被 `.gitignore` 反向忽略；勿提交 |
| 改了脚本但行为没变 | 运行期读的是总库副本 | 跑 `bash plans/dsh-codepunk-init.sh` 同步 |
| 改了组合但会话里没变 | 插件配置在进程启动时读取 | 重启 DSH Desktop（新开对话不重读） |
| `verify-battery.sh` 报「目录树与仓内文件不一致」 | README 目录结构段漏列或写了不存在的条目 | 同步 README 该段 |
| 某一项报「无法核验」 | 缺运行时或依赖 | 补齐环境后重跑；**不得当作通过** |

相关文档：[architecture.md](architecture.md)（架构）· [documentation-policy.md](documentation-policy.md)（文档规范）· [maintenance.md](maintenance.md)（巡检）· [naming-conventions.md](naming-conventions.md)（命名）
