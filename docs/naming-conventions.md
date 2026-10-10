# 命名与编号规范

本文规定仓库内**文件、目录、编号、岗位标识与分支**的命名口径。命名一致性是可机械校验的，也是文档可追溯的前提。

## 1. 文件与目录命名

通用规则：文件名一律**全小写 ASCII**，词间用连字符 `-`；不用下划线、驼峰、空格或中文名；扩展名表意（`.sh` / `.py` / `.mjs` / `.ps1` / `.md` / `.yaml` / `.yml`）。

| 类别 | 形态 | 示例 | 说明 |
|---|---|---|---|
| POSIX 工具脚本 | `plans/<主题>.sh` | `doc-consistency.sh`、`write-scope-check.sh` | 高级 set 选项与退出码契约齐备 |
| Python 工具 | `plans/<主题>.py` | `fidelity-gate.py`、`preset-compat.py` | 需结构化解析（YAML / AST / 语义比对）时选用 |
| Node 工具 | `plans/<主题>.mjs` | `preset-declare.mjs`、`ps-validate.mjs` | 需 Node 语义或生态依赖时选用 |
| Windows 等价实现 | `plans/windows/<同名>.ps1` | `dsh-codepunk-home.ps1` | 与 POSIX 侧命令名、参数、退出码一一对应 |
| 按需细则 | `skills/dsh-codepunk-workflow/references/<名词>.md` | `roles.md`、`artifacts.md`、`standard.md` | 单一名词或名词短语；由 SKILL 按需加载 |
| 调研档案 | `skills/dsh-codepunk-workflow/benchmarks/<来源或主题>.md` | `deepseek-harness-study.md`、`caveman-analysis.md` | 外部来源分析或机制调研 |
| 开发与架构文档 | `docs/<主题>.md` | `architecture.md`、`deployment.md` | 本套文档 |
| 架构决策记录 | `docs/adr/<四位数序号>-<短标题>.md` | `0001-record-architecture-decisions.md` | 序号自增、不复用、不跳号 |
| 探针脚本 | `<运行根>/logs/probe-r<轮次>-<用途>.sh` | `probe-r42-locale.sh` | 落运行根，不落工程工作树 |
| 补丁脚本 | `<运行根>/logs/patch-r<轮次>-<用途>.py` | `patch-r42-fix-paths.py` | 同上 |

运行根自身的固定命名（位于总库内，不属于仓库）：

```text
~/.dsh-codepunk/projects/<project_id>/
  logs/                     # 证据（本 run 的原始输出；D131 下运行根无任何登记文件）
  goal.yaml  chunks.yaml  plan_draft.md
  change_orders/<id>.yaml   # 需求变更单
  approvals/merge.yaml      # 合并门批准
  runs/<run_id>/
    tasks/<task_id>/{brief,staffing,handoff,progress}/
    reviews/  errors/YYYY-MM-DD.md  docs/memory/  logs/  tmp/<run_id>/<step>/
    agents.yaml             # 子代理状态清单
```

## 2. 编号体系

| 族 | 形态 | 唯一释义 | 机械校验 |
|---|---|---|---|
| 阶段号 | `P01`–`P17` | `references/standard.md` 阶段号段 | 须落在已声明范围或 span 内（`doc-consistency.sh` 第 9 类） |
| 决策号 | `D0xx` | `references/standard.md` 决策登记表 | 逐条登记，未登记即红（第 9 类） |
| 硬规则 | `R1`–`R17` | `SKILL.md` §3 硬规则表 | 禁「R 加三位及以上数字」写法（第 19 类） |
| 变异号 | `M1`–`M149` | `plans/checker-self-test.sh` 变异表 | 计数与 README 声称同步（第 1 类） |
| 检查类号 | `[1]`–`[24]` | `plans/doc-consistency.sh` 的类段输出 | 每个类须在治理矩阵中登记（第 22 类） |
| 发现编号 | `Fnnn` | `references/skill-governance.md` 溯源表 | 提交信息尾部附注 |
| 轮次 | 「轮次 N」 | 会话/审计轮次的中文写法 | 禁止与硬规则同形的三位写法 |

使用纪律：

1. **引用硬规则写 `R` 加一或两位数字**（如 R17）；**引用轮次一律写「轮次 N」**——形如 `R` 加三位数字的写法会被机械门判红，因为它与硬规则号同形，读者无法区分。
2. **新增编号先登记再引用**：新决策登记进 `standard.md`，新阶段先占号再使用；禁止引入 `standard.md` 之外的编号族。
3. **变异号顺延**：新增变异取下一个未用整数，并同步 README 的计数声称（详见 [development.md](development.md) §6）。
4. **计数一律派生**，不手写：

```bash
grep -oE 'M[0-9]+' plans/checker-self-test.sh | sort -u | wc -l   # 变异项数
grep -cE '^echo "\[[0-9]+' plans/doc-consistency.sh                # 文档一致性类数
grep -cE '^# [0-9]+\)' plans/verify-battery.sh                     # 电池项数
```

## 3. 岗位与人设命名

| 项 | 规则 | 示例 |
|---|---|---|
| 岗位标识 | 图标 + 中文名 + ID；人类可读处用图标 | `📚 文档小组 docs` |
| 规范 ID | 工具名、登记表、评分聚合一律用规范 ID | `docs-lead`、`ind-res`、`sys-arch` |
| 门户简称 | README 等门户表述用简称；同一文档内**不得混用**两种写法 | `docs`、`research` |
| codename（人设名） | 2 个汉字、表意、同一 run 内唯一；引用格式 `<codename>（<seat>@<task_id>）` | 衡策（squad-lead@chunk-a） |
| team_name | 2 个汉字、同一 run 内唯一 | 砺石 |
| 登记行 | `\| task_id \| 席位 \| codename \| subagent_id \| status \|` | 席位取 `squad-lead` / `engineer` / `sdet` |
| 席层 | `主会话` / `人类` / `主责` / `专员` / `实现` / `门禁` / `跨组` | 不使用 `L0`–`L5` 记号 |

图标使用边界：README、岗位表、run 记录、汇报表格**可用**；persona 正文、`SKILL.md` 正文、prompt 正文**禁用**（AI 读取处，且装饰性符号消耗常驻 token）。

## 4. 章节与引用写法

1. **章节名引用**：写作 `references/artifacts.md「交接包」` 或 `references/file-hygiene.md` §六——章节名须与目标文件中的标题字面一致，`§N` 须指向真实存在的标题（`doc-consistency.sh` 第 10 类校验）。
2. **跨文档链接**：用仓内相对链接（如 `../README.md`、`adr/0001-record-architecture-decisions.md`），不得指向不存在的路径（`preset-audit.sh` E3 校验死链）。
3. **占位符**：`<project_id>`、`<run_id>`、`<task_id>`、`<DSH 安装根>`、`<profile>`、`~/.dsh-codepunk/...`——一律中性写法，禁止本机绝对路径。
4. **表格**：表头与分隔行同时写全，列数一致；单元格内的竖线在代码跨度中须转义为 `\|`。
5. **日期**：`YYYY-MM-DD` 或 `YYYY-MM`，禁止中文年月日混写，禁止未来日期。

## 5. 分支与提交命名

| 对象 | 形态 | 示例 |
|---|---|---|
| 主题分支 | `<type>/<主题>` | `feat/open-source-hygiene`、`fix/locale-guard` |
| 工作房分支 | `dsh-codepunk/<run_id>/<task_id>` | `dsh-codepunk/run-7/chunk-a` |
| 工作房目录 | M/L 档 `../room-<task_id>` | `../room-chunk-a` |
| 提交标题 | `<type>(<scope>): <中文动宾式一句话>` | `fix(tools): 归一总库脚本模式为 755` |
| 提交正文 | 改了什么、为什么、影响面 + 验证方式（命令与结果） | — |
| 流程缺陷附注 | 标题末尾 `（Fnnn）` | — |

`type` 取值：`fix` / `docs` / `feat` / `perf` / `test` / `chore`；`scope` 取模块名，如 `windows` / `tools` / `skill` / `audit` / `score` / `config` / `stages` / `roles` / `docs`。

> 工作房落点在仓内有两处表述（`SKILL.md` §1.2 的 `../room-<task_id>` 与 `references/file-hygiene.md` §6.1 的 `~/.dsh-codepunk/worktrees/<task_id>/`）。命名规范性上二者都合规，**落点以简报声明的 `write_paths` 与 `git worktree list` 实况为准**。

## 6. 反例对照

| 反例 | 为什么不行 | 正确写法 |
|---|---|---|
| `DocConsistency.sh` | 驼峰与文件名规则冲突 | `doc-consistency.sh` |
| `docs/架构.md` | 中文文件名，跨平台与工具链风险 | `docs/architecture.md` |
| `probe-r42.sh`（落在工程工作树） | 运行期临时物污染工程仓库 | 落运行根 `logs/probe-r42-用途.sh` |
| `R` 加三位数字指代轮次 | 与硬规则号同形，机械门判红 | 轮次 N |
| `D099` 未登记即引用 | 编号不可解析 | 先登记 `standard.md` 再引用 |
| 表格数据行多一格 | GFM 下多余单元格被静默忽略 | 列数与表头严格一致 |
| `a \| b` 写在表格的普通文本里 | 会被误判为列分隔，破坏列数 | 表格内裸露竖线须转义为 `\|` |

相关文档：[documentation-policy.md](documentation-policy.md)（文档政策与禁止项）· [development.md](development.md)（派生计数与变异规则）· [architecture.md](architecture.md)（结构总览）
