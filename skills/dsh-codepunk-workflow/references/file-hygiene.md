# 工作房卫生契约（references/file-hygiene.md）

> dsh-codepunk 防「临时文件/残留」机制（D079）。骨架借鉴 alexzheng-unzen/agent-housekeeping（MIT）+ davila7/claude-code-templates（MIT）+ SoloDawn RB-37 强制门闩思路 + Claude Code 官方 tmp/清扫机制。溯源：`benchmarks/file-hygiene-skill.md`（19 来源）。
> 定位：**防产生（开工契约）+ 及时清理（收尾自查）+ 强制门闩（解散前置）** 三层。

## 一、开工卫生契约（小组开工必读，七条硬规则）

1. **状态文件不进工程目录**：`.lock`/`.pid`/`.heartbeat` 等运行时状态只写 `$TMPDIR/dsh-codepunk/<task-id>/` 或工作房临时目录，**绝不出现在工程目录/总库项目目录**。
2. **不主动造文档/脚手架**：未要求则不建 README/说明书/样板目录；产出物只进简报声明的产出路径。
3. **不越权重构**：只做简报要求的改动；「顺手优化/顺带清理」即越界（D076 同源）。
4. **生成前查重**：任何 artifact 先 glob 查重——「编辑优先于新建」，防重复生成。
5. **临时写入集中化**：探索性/演示性文件一律 `$TMPDIR/dsh-codepunk/<task-id>/`，session 结束必删；工作房内禁止散落探索文件。
6. **工程侧忽略约定（MUST）**：开工首件事——核对工程根 `.gitignore`，**必须忽略本流程的工程域产物**：
   - `rooms/`（S 规模在工程根内的封闭工作房）——未忽略会让本地记录进入工程提交历史；
   - worktree 落点建在**工程父目录**（仓库外），无需忽略；
   - 同时**清除历史旧名条目**（若 `.gitignore` 残留旧系统名目录，一并删除，避免死规则误导）。
   核对命令：`git -C <工程根> check-ignore -v rooms` 有输出即已忽略；无输出则补一行 `rooms/`。
7. **推送前泄露防护（MUST）**：凡提交/推送前跑一次泄露防护门（`plans/dsh-codepunk-leak-guard.sh`）：
   - 默认扫索引（`--staged`，作 pre-commit）；`--history` 扫近 20 提交（作 pre-push）；`--install-hook` 一键装 pre-push 钩子；
   - **禁词留本地**（`~/.dsh-codepunk/denylist.txt` 或 `DSH_CODEPUNK_DENYLIST`），公开仓库的守卫脚本本身不得含私人词；
   - 命中即阻断（退出码 1）；`--no-verify` 绕过须在交接包留痕说明。
   - 为何必需：`git push --force` **不会删除服务端旧对象**，旧提交仍可经公开 Events API 枚举 SHA 后 raw 直链读取——唯一可靠的事后补救是删除并重建仓库。

## 二、收尾残留自查清单（交接包必填节）

| # | 检查项 | 命令/做法 |
|---|---|---|
| 1 | git 工作区（工作树）状态 | `git status` —— 无意外 untracked/modified |
| 2 | 未跟踪文件 | `git status --porcelain` untracked 清单核对（产出物 vs 残留） |
| 3 | 临时目录 | `ls $TMPDIR/dsh-codepunk/<task-id>/` 应空或已删 |
| 4 | 怪异目录/文件 | 工作房内散落 `.log`/`.bak`/`~` 后缀/编号副本 |
| 5 | 重复 artifacts | 产出文件 glob 对照清单，无重复生成 |
| 6 | .lock 泄漏 | 工程/总库目录无 `.lock`/`.pid` 残留 |
| 7 | 工程侧忽略 | `git -C <工程根> check-ignore -v rooms` 有输出（工程域产物已被忽略） |

发现残留 → **报告（不擅删）**：报告模板 = 位置 + 内容摘要 + 建议（删 `/ 留 / 移 $TMPDIR/dsh-codepunk/state/`）；删除动作由主会话 run-lead 巡检 + 工程主责确认后执行（T4 原则）。

## 三、强制门闩（D079，SoloDawn RB-37 思路）

- 「残留自查通过」= 小组解散/交接的**前置条件**，与双门闩/审查门并列：交接包缺自查结果 → 整包打回（同 D077 证据门控）。
- 终态清理 check 是**流程硬项**，非 agent 自觉项。

## 四、巡检工具与周期（**主会话 run-lead 巡检**执行）

1. **git clean 演练制度**：巡检先 `git clean -nd` 干跑（列出 backup/探索/scaffold/tmp 待删），人工确认后 `-fd`；未授权禁止 `git clean -f/-fd`、`reset --hard`、`stash drop`（破坏性拦截，T9）。
2. **worktree 清理双判定**：`git branch --merged` + squash-merge 空 diff 判定（davila7 worktree-cleanup）；跳过有未提交/未推送工作的 worktree（T8）；运行时 `git worktree lock` 防并发误删；`worktrees/` 与产出目录进 .gitignore。
3. **7 天保洁 loop**：陈旧分支/孤儿 worktree → 先 salvage 有价值未合并工作到 issue/新分支 → 再删（davila7 repo-cleanup-loop）；有停止条件。
4. **保留期清扫**：临时/演示数据 7 天保留（**主会话 run-lead 巡检**执行清扫，不依赖各 agent 自觉；措辞统一：流程中无「主会话 run-lead 巡检」席位，巡检是 run-lead 的职责）。

## 五、契约精简原则

卫生规则控制在本文件规模（5 硬规则 + 1 自查清单 + 1 报告模板 + 巡检工具集 + 1 写盘白名单），配 IMPORTANT 强调；规则膨胀会导致 agent 忽略（Claude Code best-practices——少而硬）。

## 六、写盘白名单与越界判据（MUST）

> 本节点是写盘纪律的**判据权威**（承重 R17；机械门 `plans/write-scope-check.sh`）。**与 §一/§二 冲突时以本节点为准**：§一.1、§一.5 的临时落点 `$TMPDIR/dsh-codepunk/<task-id>/` 属**次选**，首选已改为运行根 `logs/`、`tmp/<run_id>/<step>/`；§二 自查表第 3 项同按本节点口径核验。定位：防产生（开工契约）+ 就高落点（白名单优先序）+ 机械判据（越界即缺陷）三层。

### 6.1 白名单（按优先序，MUST 就高不就低）

| 序 | 落点 | 用途 | 备注 |
|---|---|---|---|
| 1 | `~/.dsh-codepunk/projects/<project_id>/runs/<run_id>/` | 探针脚本、日志、临时脚本、夹具、沙箱副本 | **首选**；子目录 `logs/`、`tmp/<run_id>/<step>/` |
| 2 | `~/.dsh-codepunk/worktrees/<task_id>/…` | 该任务的实现物 | 仅限简报声明的 `write_paths` |
| 3 | `${TMPDIR:-/tmp}/dsh-codepunk-<run_id>-<step>/` | 运行根不可写时的临时落点 | **次选**；用毕即删，不得留裸文件 |
| 4 | `~/.dsh-codepunk/projects/<project_id>/knowledge/` | 结论性知识 | `research/`、`decisions/`、`hr/`、`lessons/` |

### 6.2 黑名单（严禁）

- 工程仓库工作树内的临时/探针命名物：`probe-*`、`patch-*`、`tmp*`、`*.bak`、`*.orig`、`*.rej`、`*.log`、`*.tmp`、`*~`、`__pycache__/`、`*.pyc`（最后两项为 Python 字节码缓存：在仓库内 import 本仓 `plans/*.py` 即生成，`plans/write-scope-check.sh` 的 G1 与电池的杂散检查都会判失败）。
- `$HOME` 顶层散落脚本/文档/数据（`~/xxx.sh`、`~/xxx.py`、`~/note.md` 等）。
- 系统目录内自建物：`/usr`、`/opt`、`/etc`、`/Library`、`/Applications`。
- 在工程目录（预设/项目仓库）内建**沙箱副本** ⇒ 改落运行根或 `$TMPDIR`。

### 6.3 命名与台账

- 探针脚本 `logs/probe-r<轮次>-<用途>.sh`；补丁脚本 `logs/patch-r<轮次>-<用途>.py`。
- 临时产物 `tmp/<run_id>/<step>/`；沙箱根 `~/.dsh-codepunk/tmp/<run_id>-<step>/`。
- **命名空间契约（MUST）**：临时物 MUST 落在 `/tmp/dsh-codepunk-<run_id>-<step>/` 这类**契约命名空间**内（等价于运行根 `logs/`、`tmp/<run_id>/<step>/`）。裸落的 `probe-*`、`patch-*`、轮次号 `r`+两位数字型条目一律视为**归属不明**——门禁无法归属，且他人同名物会干扰判读；**归属降级只适用于临时根顶层（§6.4 G3）**：同一批命名出现在工程工作树（G1）或 `$HOME` 顶层（G2）时一律判 FAIL，不降级（判据见 §6.4 G1/G2/G3）。
- 台账 = 运行根 `README.md` 的 `write_scope:` 段（模板见 `references/artifacts.md`），一行一件：路径 + 用途 + 清理状态。

### 6.4 清理要求与越界判据（机械门）

- **越界即缺陷**：命中 §6.2 任一黑名单即缺陷，MUST **当轮**清理（不留待下轮/交接前）并在台账把该项标为已清；未清理不得进入交接门与合并门（同 §三 门闩）。
- 三组判据 G1/G2/G3 逐条对应机械门实现，命名口径同 §6.3；退出码统一见本节末。
- **G1 仓库工作树残留**：工程工作树内（**含未跟踪文件**，排除 `.git/`）命中 §6.2 黑名单命名——`probe-*`、`patch-*`、`tmp*`、`*.bak`、`*.orig`、`*.rej`、`*.log`、`*.tmp`、`*~` 等 ⇒ **FAIL（exit 1）**。
- **G2 主目录散落**：`$HOME` 顶层（`maxdepth 1`）命中 `dsh-codepunk*`、`probe-*`、`patch-*`、**轮次号**（`r` + 两位数字起，正则 `r[0-9][0-9]`）⇒ **FAIL（exit 1）**；轮次号与预设/探针前缀同列，均属本流程命名空间，**不适用** G3 的归属降级。`--home-all` 额外列出的通用脚本/文档类仅 INFO，不判 FAIL。
- **G3 临时目录残留**（临时根顶层；**归属语义**）：扫描 `${TMPDIR:-/tmp}` 与 `/tmp` **两个根**——契约允许临时物落 `$TMPDIR` 或 `/tmp/dsh-codepunk-<run_id>-<step>/`，只扫一根会漏检；二者解析为**同一目录**时按真实路径去重、**只扫一次**。
  - **判 FAIL（exit 1）**：条目名以 **`dsh-codepunk-`** 开头者——即 §6.1 第 3 项允许的 `/tmp/dsh-codepunk-<run_id>-<step>/` 契约命名空间未被清理。
  - **降级 INFO（不影响退出码）**：其他同形条目（轮次号 `r`+两位数字、`probe-*`、`patch-*`，但不以 `dsh-codepunk-` 开头）⇒ 输出 `ℹ G3 归属不明（非本契约命名空间，不改判）：<绝对路径>` 加**计数行**；如确属本工程，须清理或用 `--exempt-from <运行根 README.md>` 登记。
  - **为何不一律判红**：临时根顶层常有**他人**遗留且持续新增的同形条目，一律判红会使本机默认模式恒红并**归因错误**（把他人残留记到本工程头上）。
- **豁免（`--exempt-from <文件>`，缺省不启用）**：读取登记文件的 `write_scope:` 段 `exempt:` 列表（约定为运行根 `README.md`）；命中路径与登记项**相等**、或**为其子路径**（登记项是命中路径的祖先目录，如登记 `plans` 覆盖 `plans/keep-me.bak`）者降级 **INFO**（列出但不判 FAIL）。登记文件不存在或不可读 ⇒ **exit 2**（无法核验 ≠ 通过）。
- 不变：G1 与 G2 仍按 §6.2 命名口径**一律判 FAIL**，不适用上述归属降级。
- 实现：`plans/write-scope-check.sh`（正式位 `~/.dsh-codepunk/scripts/`）——**退出码：0 通过 / 1 发现越界 / 2 无法核验或用法错**；结论码为 2 时不得当作通过（无法核验 ≠ 通过）。

### 6.5 宿主执行陷阱（本机实测，MUST）

以下为本机宿主层的执行陷阱（中性表述，不含本机绝对路径）。违反即按执行纪律缺陷处理，与 §6.2 越界同属「当轮清理/当轮改正」范围。

1. **禁内联喂解释器、禁内联方括号 glob**：内联 heredoc 喂解释器（形如 `python3 - <<'PY'`）与内联方括号 glob（形如 `probe-[^/]*`）会触发宿主侧挂起（约 300 秒超时并重置持久 shell，无副作用）。MUST 改用**脚本文件**执行——脚本落运行根 `logs/`，命名按 §6.3。
2. **`/tmp` 视图按调用易失**：同一 shell 调用内创建的长跑日志，跨调用可能消失。长跑日志 MUST 落总库运行根 `~/.dsh-codepunk/projects/<project_id>/runs/<run_id>/logs/`，不得只落临时目录。
3. **重型扫描易超时**：全量枚举、多轮门禁在负载峰值下易超时。MUST 先自评成本、只做一次并缓存结果，或交后台作业（`nohup … & disown`），并在简报或交接包声明预计耗时。

## 七、宿主层强制（可选启用，宿主 cwd/tmp 粒度）

> **定位：辅助层，不是主力。** 宿主（DSH Desktop）确有机械写盘强制，但粒度只能到「会话 cwd + 系统临时区」，且**本机当前未生效**（运行时策略为完全访问）。证据全部来自本机源码只读调研：`~/.dsh-codepunk/projects/dsh-codepunk/runs/run-audit-50/knowledge/write-scope-mechanisms.md`（轮次 601，194 行，含逐条证据行号）。
> 下文路径简写同调研文件：`APP` = `<DSH 安装根>`（macOS 桌面版即应用程序包内的 `Contents/Resources/app`）；`PKG` = `<DSH 安装根>/node_modules/@deepseek-ai`；`PROF` = `~/.dsh/profiles/desktop`（用户 DSH 配置根）；`PRESET` = `~/.dsh/.agent-presets/dsh-codepunk`（本预设仓库）。

### 7.1 词汇与可写白名单（宿主事实）

- **沙箱三值封闭词汇**：`read-only` / `workspace-write` / `danger-full-access`，定义于 `PKG/dsh-sandbox-policy/lib/index.js` 的 `const SANDBOX_MODES = [ "read-only", "workspace-write", "danger-full-access" ]`（DSH 2.0.17 实测于 `:26-30`；**行号随产品版本漂移**——旧稿写 `:35-39`，2.0.17 起该区间已是 `setSandboxMode` 的 JSDoc，故核验一律按符号名检索：`grep -n 'SANDBOX_MODES' <该文件>`），运行时会校验取值；策略插件仅两个配置键（`mode` 默认 `read-only`、`workspaceRoot` 默认 `process.cwd()`，见 `PKG/dsh-sandbox-policy/README.zh.md:47-48` 与 schema `PKG/dsh-sandbox-policy/lib/index.js:97-104`），**无 `allowWrite`/`writePaths`/`denyWrite` 类扩展**。
- **宿主可写白名单仅三处**：会话 cwd（不可变）、`/tmp`、`os.tmpdir()`——推导函数 `PKG/dsh-sandbox/lib/index.js:166-174` 的 `writableRoots()`：`if (policy.mode !== "workspace-write") return []; return [...new Set([policy.workspaceRoot, "/tmp", tmpdir()].map(canonicalPath))]`；`read-only` 下白名单为空集。
- **越界由宿主直接拒绝**：文件侧抛结构化错误，关键错误串 **`FS_SANDBOX_DENIED`**（`PKG/dsh-fs-sandbox/lib/index.js:157-164`）；bash/pwsh 与文件系统两族共用同一策略（`PKG/dsh-base/cordis.patch.yml:226-243`、`:518-519`）。
- **审批只挡升权，不挡常规写**：`workspace-write` 内的正常写不触发审批；模型须用 `sandbox_permissions` + `justification` 重试一次更宽模式，经 `ask` 审批（`PKG/dsh-tool-fs/lib/index.js:1111-1147`）；应答者缺失即拒绝式关闭（`PKG/dsh-user-approval/README.zh.md:36,46`）。

### 7.2 声明层级（谁能改、改的是哪一层）

> **行号引用规则（MUST）**：本节所有 `<文件>:<行号>` 均为**定位辅助**，其有效性绑定当时的 DSH 与用户平面版本。
> 引用 MUST 同时给出**符号名检索式**；核验与引用一律以符号名检索为准，行号仅作快速跳转。
> 依据：本轮巡检实测 3 处漂移（`SANDBOX_MODES` 由 `:35-39` → `:26-30`；用户平面 `permission` 区块由 `:168-181` → `:216-229`；
> `defaultPreset` 由 `:181` → `:229`）——产品升级或用户平面编辑后行号必然失准，而**声称内容本身仍成立**，故漂移不会被内容类检查捕获。

| 层级 | 落点（文件:行号） | 效果与范围 |
|---|---|---|
| 部署平面 | `PKG/dsh-base/cordis.patch.yml:229-233` | `mode: !!js process.env.DSH_PERMISSION_MODE ?? 'workspace-write'`；`workspaceRoot: !!js process.cwd()`；环境变量同时决定沙箱模式与审批策略（`:232`、`:248`）；影响所有新会话 |
| 用户平面 | `PROF/cordis.patch.yml:216-229` | id 定向覆盖层（语法自述见 `:1-4`：top-level YAML array of loader patch entries，允许 `!!js`）；声明 `permission` 预设表与 `defaultPreset`；对**新会话**机械生效。**核验方式**：`grep -n 'id: permission' <该文件>`（行号随用户平面编辑漂移——2026-10 实测该区块已从旧稿所记 `:168-181` 移至 `:216-229`） |
| 会话级 | `PKG/dsh-sandbox-policy/lib/index.js:40` 的 `setSandboxMode()` | `function setSandboxMode(session, mode) { session.append("sandbox/mode", { mode }); }`；用户入口为 `/permission` 命令或 UI 控件（`PKG/dsh-permission-presets/README.zh.md:50`）；只影响当前会话，重启后按事件回放保留 |
| 解析优先级 | `PKG/dsh-sandbox-policy/lib/index.js:141-146` 的 `resolve()` | `request.mode ?? overrideOf(session) ?? defaultMode`；工作根恒取会话不可变 cwd（`session?.header.cwd`）；预设平面不宜作强制点（`PRESET/agent.cordis.yml:6` 自述沙箱归宿主平面） |

**本机现状（MUST 知悉）**：用户平面 `PROF/cordis.patch.yml:229` 的 `defaultPreset: danger-full-access`（核验式：`grep -n 'defaultPreset' <该文件>`）⇒ **本会话无任何宿主写盘限制**，与运行时上下文自述一致（「Current DSH file policy: danger-full-access. The DSH file sandbox does not restrict file modifications by available operations.」）。故 §6.1 白名单与 §6.4 机械门当前**是唯一在岗的写盘约束**。

### 7.3 可直接照抄的启用片段（**须重启 DSH Desktop 生效**）

方案甲（推荐：用户平面一处改动，对新会话机械生效）。把 `PROF/cordis.patch.yml` 第 168-181 行的 `permission` 项改为：

```yaml
- id: permission
  name: "@deepseek-ai/dsh-permission-presets"
  config:
    presets:
      read-only:
        sandbox: read-only
        approval: ask
      workspace-write:
        sandbox: workspace-write
        approval: ask
    defaultPreset: workspace-write
```

要点：① 表内不得保留 `custom`/`auto` 名称，且 `defaultPreset` 必须指向表内项，否则插件加载即报错（`PKG/dsh-permission-presets/lib/index.js:175-184`）；② 出厂预设表**不含** `read-only`（`PKG/dsh-permission-presets/lib/index.js:143-156`），本机 profile 自行补入，收敛时须显式保留；③ 删掉 `danger-full-access` 行不会关闭升权通道——升权阶梯是 `dsh-sandbox` 内封闭表（`read-only` 可升两级，`workspace-write` 只能升到 `danger-full-access`），仍须经 `ask` 审批，这是唯一的人类闸口。

方案乙（可选加固：部署平面）。在部署环境设 `DSH_PERMISSION_MODE=workspace-write`，使 bundle 层默认值也不再是宽值（依据 `PKG/dsh-base/cordis.patch.yml:232,248`）。

方案丙（可选，彻底禁用写盘工具：宿主侧工具闸门；**轮次 628 起本预设已声明**，见 §八）。在 profile 追加 `hooks-claude-code` 行并配 `hooks.json` 中对 `Write`/`Edit`/`Bash` 的 `PreToolUse` command 钩子，退出码 2 即阻断该次调用（挂载点 `PKG/dsh-hooks-claude-code/lib/index.js:248-257`，拒绝文案 `Error: blocked by PreToolUse hook`，能力自述 `PKG/dsh-hooks-claude-code/README.zh.md:60,157`）。限制：随附所有 bundle 组合均未挂载钩子桥（全树 grep 无命中），且只运行 command 钩子（`http`/`mcp_tool`/`prompt`/`agent` handler 被跳过并告警，`PKG/dsh-hook-protocol/README.zh.md`）。片段全文见调研文件 §三 方案乙。
> **现状（轮次 628）**：本预设已按此方案落地**自有**钩子（预设平面，非用户平面）：`agent.cordis.yml` 的 `- id: hooks-write-scope` + `plans/hooks/hooks.json` + `plans/hook-write-scope.py`，机制、模式、覆盖与缺口见 §八。上段「随附 bundle 未挂载」仍属实——挂载的是**本预设自己声明**的条目。

**生效方式统一为「改配置 → 重启 DSH Desktop → 新会话按新值解析」**：三层都是加载期配置；会话内模式以 `sandbox/mode` 事件记录，重启后回放保留，故旧会话的既有模式不会因重启而自动收敛。

### 7.4 规则（MUST）

- 预设与子代理 **MUST NOT** 擅自修改用户平面的权限配置（`~/.dsh/profiles/**`）——那是**人类环境决策**：改它等于自行放宽或收紧本机**所有会话**的写盘边界，属越权变更环境。
- 如有变更建议，MUST 以「**建议 + 片段 + 影响面 + 生效方式**」四件套提交人类裁定，并记入台账（运行根 `README.md` 的 `write_scope:` 段）；未获裁定前 MUST NOT 落地，也 MUST NOT 以「试跑」名义临时改配置。
- MUST NOT 以「宿主沙箱会拦」为由省去 §六 纪律：本机现状该层未生效；即便启用，也只覆盖 cwd `/tmp` `os.tmpdir()` 三处，与 §6.1 的「运行根 + 授权工作树 + 知识库」口径**不等价**。

### 7.5 缺口清单（宿主层覆盖不到，各附影响）

| # | 缺口 | 影响 |
|---|---|---|
| 1 | 无多可写根；每个会话只有一个工作区根（`PKG/dsh-sandbox-policy/README.zh.md`「已知限制」节：额外可写根不属于 `SandboxExecutionPolicy`） | 无法同时授权「运行根 + 授权工作树 + 知识库」三处互异目录；§6.1 就高落点只能靠人设纪律与审查维持 |
| 2 | 不能禁写 `/tmp` 与 `os.tmpdir()`（`workspace-write` 语义上必然包含临时区） | 临时区散落物不会被告警或拦截；只能靠 §6.4 G3 机械门在收尾时发现 |
| 3 | cwd 覆盖 `$HOME` 时不拦 `$HOME` 顶层（白名单以 cwd 为根） | 若会话 cwd 为 `$HOME` 或其祖先，`$HOME` 顶层散落即在白名单内；§6.2 该禁令仍需人设加 G2 兜底 |
| 4 | 主会话无工具白名单配置键（`toolFilter` 仅对子代理生效，由 `PKG/dsh-subagent/lib/index.js:522` 的 `childCtx.tools.restrict()` 消费，schema 见 `PKG/dsh-tool-subagent/lib/index.js:265-268`） | 主会话不能经配置机械禁 `write`/`edit`/`bash`；可行替代是**只读子代理**（`allow` 列表去掉 `write`/`edit`/`bash`） |
| 5 | `read-only` 下 `bash` 仍可执行（只禁写）；产品无内置只读工具集或只读角色 | 只读模式不能防读外泄与派生进程；「只读」≠「无副作用」 |
| 6 | 网络与进程限制不在沙箱词汇内（`PKG/dsh-sandbox/README.zh.md`「已知限制」节：文件操作是完整的策略词汇） | 「禁联网」只能靠工具允许表移除 `web_search`/`web_fetch`；沙箱不构成网络闸门 |
| 7 | 宿主不认识「授权工作树 `write_paths`」 | `~/.dsh-codepunk/worktrees/...` 的写集隔离仍靠 git 加人设纪律加审查门，不是沙箱；跨工作房写不会被告警 |

### 7.6 收束

宿主层为**辅助**，预设层三层（R17 + 本文件 §六 + `plans/write-scope-check.sh`）为**主**；两者叠加时仍以运行根 `~/.dsh-codepunk/projects/<project_id>/runs/<run_id>/` 为唯一首选落点（§6.1 序 1）。宿主层是「可能多一道拦网」，不得被当作「已经安全」的理由；未启用时（本机现状）与启用后，§6.2 黑名单与 §6.4 越界判据一律照常执行。

## 八、拦截层（hooks）机械护栏（本预设已声明，轮次 628 接入）

> **定位：第三层机械拦网（最内一层）。** 层级关系：**宿主层沙箱**（§七；粒度到会话 cwd + 系统临时区，本机未生效）→ **预设层三层**（R17 人设纪律 + 本文件 §六 判据 + `plans/write-scope-check.sh` **事后**扫描）→ **拦截层 hooks**（本节；**事前**拦截单次工具调用）。
> 与 §六 的关系：§六 是**判据权威**（白名单优先序与 G1–G3 越界判据），本节是**同一批判据的执行器之一**——只拦「工具调用层」的写入，不新增判据、不放宽判据。

### 8.1 机制与启用方式

| 项 | 内容 |
|---|---|
| 钩子桥 | `@deepseek-ai/dsh-hooks-claude-code`（Claude Code 兼容命令钩子；产品挂载点 `tools/pre-execute`） |
| 预设条目 | `agent.cordis.yml` 的 `- id: hooks-write-scope`（config：`configPath` 指向 `plans/hooks/hooks.json`、`pluginRoot` 指向预设根、`defaultTimeoutMs: 10000`） |
| 钩子配置 | `plans/hooks/hooks.json`：`PreToolUse` + `matcher: "write\|edit\|bash\|pwsh"` + `type: command` + `python3 "${CLAUDE_PLUGIN_ROOT}/plans/hook-write-scope.py"` + `timeout: 10` |
| 执行体 | `plans/hook-write-scope.py`（Python 3 标准库；用法 `python3 plans/hook-write-scope.py -h`） |
| 阻断语义 | 钩子**退出码 2 ⇒ 阻断该次工具调用**，stderr 一行理由回给模型（含模式名、命中的规则名、绝对路径）；退出码 0 ⇒ 放行；其余码＝非阻断错误 |
| 生效方式 | 改 `agent.cordis.yml` 或 `hooks.json` 后**重启 DSH Desktop**（声明与钩子配置均在进程启动时读取）；**新会话**才按新值解析 |
| 依据（产品源码） | 阻断映射 `PKG/dsh-hook-protocol/lib/index.js` 的 `parseHookOutput`（`exitCode === 2 ⇒ decision = "block"`，`stderr` 作 `reason`）；桥侧 `PKG/dsh-hooks-claude-code/lib/index.js` 的 `tools/pre-execute` 处理器（`decision === "deny" ⇒ {kind:'deny', reason}`）、`Config` schema（`configPath` 必填）、`${CLAUDE_PLUGIN_ROOT}` 替换与 PreToolUse 载荷构造 |

### 8.2 两种模式

| 模式 | 开关 | 语义 |
|---|---|---|
| `deny`（默认） | 无（或 `DSH_CODEPUNK_HOOK_MODE=deny`） | **黑名单阻断**：命中即拦。集合 = §6.2 黑名单的可机械判定部分——系统路径（`/etc`、`/usr`、`/bin`、`/sbin`、`/System`、`/Library`、`/boot`、`/opt`；`/var` **排除** `/var/folders`，即 macOS `TMPDIR` 实际落点）· 凭据目录（`~/.ssh`、`~/.aws`、`~/.gnupg`）· 用户平面 DSH 配置（`~/.dsh/profiles/**`，对应 §7.4 硬规则）· **主目录顶层散落文件**（`$HOME/<名字>` 且非已有目录，对应 G2 判据） |
| `strict` | `DSH_CODEPUNK_HOOK_MODE=strict` | **白名单放行**：只许预设仓库根、`~/.dsh-codepunk/**`、`${TMPDIR}` 与 `/tmp`、**会话 cwd** 之下的写入，其余一律阻断；黑名单仍优先判定 |
| 取值非法 | 任意其它值 | 按 `deny` 处理并在 stderr 告警（fail-safe：异常输入不降级为放行） |

**永远放行**（两模式一致）：预设仓库根 · `~/.dsh-codepunk/**` · `${TMPDIR}` 与 `/tmp` · `~/.dsh/.agent-presets/**`。
**无法判定写入目标时放行**并在 stderr 打一行「未能判定写入目标，按放行处理（护栏为启发式，不是证明）」——**不阻断**，因为误拦会打断正常作业，而判据本身给不出结论时「无法核验」不应伪装成「已阻断」。

### 8.3 覆盖与**不覆盖**（MUST 知悉）

- **覆盖**：`write` / `edit` 的 `file_path`（确定）；`bash` / `pwsh` 命令文本里的**可判定**写入目标——重定向（`>`、`>>`、`2>`）、`tee`/`cp`/`mv`/`install`/`touch`/`mkdir`/`rm`/`truncate`/`ln`/`rsync`/`chmod`/`chown` 的目标位、`sed -i` 末位文件、`dd of=…`，以及 PowerShell 写 cmdlet（`Set-Content`/`Add-Content`/`Out-File`/`New-Item`/`Remove-Item`/`Copy-Item`/`Move-Item`/`Rename-Item`/`Clear-Content`/`Tee-Object` 等）与 `-Path`/`-LiteralPath`/`-Destination`/`-FilePath`/`-OutFile` 具名参数。
- **不覆盖（启发式局限，护栏不是证明）**：
  1. **混淆写法规避**——变量拼接、`eval`、`$'\x2f'`、base64 解码后执行、经解释器间接写盘（`python3 -c "open('/etc/x','w')"`）、别名与函数重定义，一律可能绕过。
  2. **不做符号链接解析**——指向黑名单的链接按字面路径判定（`~/link-to-etc/x` 不会被拦）。
  3. **只拦工具调用层**——拦不住工具内派生进程的任意写；也不拦读、不拦网络、不拦进程。
  4. **非沙箱、非安全边界**——它是「就高落点纪律」的机械提醒，不是隔离机制；未命中 ≠ 合规。
- **与 G1–G3 的分工**：hooks 拦**事前单次调用**（`deny`/`strict` 集合见 §8.2），`plans/write-scope-check.sh` 扫**事后工作树/`$HOME` 顶层/临时根**（G1/G2/G3，命名口径与归属降级见 §6.4）。二者**判据同源**（§6.2/§6.4），但**覆盖面不等价**：hooks 看不到「非工具调用产生」的残留，机械门看不到「已被混淆绕过」的写入 ⇒ **必须并列**，任一在岗都不构成另一的替代。

### 8.4 本层缺口（与 §7.5 并列，各附影响）

| # | 缺口 | 影响 |
|---|---|---|
| 1 | 命令文本启发式可被混淆绕过（§8.3 之 1） | 恶意/无意的间接写入不会被拦；仍须靠 §6.4 机械门事后发现 + 审查门 |
| 2 | 不解析符号链接 | 经链接写黑名单落点不被拦；G1/G2 事后扫描亦按字面路径，二者同盲 |
| 3 | `matcher` 只覆盖 `write\|edit\|bash\|pwsh` | 其它写型工具（如自定义插件注册的写工具）不在拦截面内；新增写工具须同步 `plans/hooks/hooks.json` 的 matcher |
| 4 | 会话 cwd 之下的 `$HOME` 顶层例外（`$HOME` 即 cwd 时） | 同 §7.5 缺口 3：此时「顶层散落」判据以 cwd 为根，护栏不判该条；G2 兜底 |
| 5 | 只在新会话生效 | 已开着的会话在重启前不受新护栏约束（声明与钩子配置均为加载期读取） |

