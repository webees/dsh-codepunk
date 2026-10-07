# 部署指南

本文面向**部署方**（在自己的 DeepSeek Harness 实例上安装、升级或迁移本预设的团队）。使用者视角的流程说明见 [architecture.md](architecture.md)，日常运维见 [maintenance.md](maintenance.md)。

## 1. 前置条件

| 项 | 要求 | 说明 |
|---|---|---|
| DSH 版本 | ≥ 0.1.7 的注册模型 | 0.1.7 起 `dsh-agent-preset-registry` **不再扫描**预设目录，自定义预设必须经声明行注入 profile |
| 实测基线 | 应用 2.0.17 / CLI 包 0.2.0-rc.2 | 两套版本号独立，勿互相推断；取值命令见 §6 |
| node | 用于 `preset-declare.mjs`（生成 / 校验声明块） | 缺 js-yaml 时 `check` 降级为行内容比对；`apply` 在降级模式仍拒答不兼容根结构（按首个有效行做文本判定）与含 `---`/`...` 文档分隔符的补丁 |
| python3 | 用于兼容核验与多数门禁 | 缺失时相关检查报「无法核验」，不得当作通过 |
| 平台 | macOS / Linux（bash）/ Windows（pwsh） | Windows 侧经 `plans/windows/*.ps1` 覆盖核心脚本 |

## 2. 安装步骤

```bash
# ① 落位源文件（唯一权威）
DST="$HOME/.dsh/.agent-presets/dsh-codepunk"
mkdir -p "$DST"
cp -R agent.cordis.yml preset.yml skills "$DST/"

# ② 生成声明块并注入 profile patch（首次安装：--append，自动备份）
DSH_PROFILE_PATCH="$HOME/.dsh/profiles/<profile>/cordis.patch.yml" \
  node plans/preset-declare.mjs apply --append

# ②-b 同步工具脚本到总库正式位（运行期用的是总库副本）
bash plans/dsh-codepunk-init.sh

# ③ 校验内联副本未漂移
node plans/preset-declare.mjs check

# ④ 兼容核验
python3 plans/preset-compat.py
```

顺序要点：

1. **先落位、再声明**：声明块由源文件生成，源不存在时无法生成。
2. **已安装过的情形**：源改动后用 `node plans/preset-declare.mjs apply`（不带 `--append`）以源重写内联副本，自动备份。
3. **工具脚本不随预设复制**：`plans/` 是源副本，运行期执行的是总库正式位 `~/.dsh-codepunk/scripts/`；每次拉取新版本都要跑一次 `dsh-codepunk-init.sh`。从总库自身的副本运行只会提示「请改用仓内副本」。
4. **生效方式**：声明在**进程启动时读取**，改动后须**重启 DSH Desktop**；新开对话不重读插件配置。

## 3. `preset-declare.mjs` 三个子命令

| 子命令 | 作用 | 参数 | 退出码 |
|---|---|---|---|
| `emit` | 打印声明块（不写盘），供人工检查或手工注入 | `[--id <id>] [--order N] [--root <dir>]` | 0 成功 / 2 参数错误 |
| `check` | 语义比对源 ↔ 副本，列出差异路径 | `[--patch <profile-patch>] [--id <id>]` | 0 一致 / 1 确认漂移 / 2 参数错误或无法判定 |
| `apply` | 用源重写副本（自动备份） | `[--patch <profile-patch>] [--id <id>] [--order N] [--append]` | 0 成功 / 1 漂移未处理（或写盘失败）/ 2 参数或环境错误 |

补充语义：

- **默认 patch 路径**：取 `$DSH_PROFILE_PATCH`，其次 `~/.dsh/profiles/desktop/cordis.patch.yml`。
- **依赖发现顺序**（不硬编码平台路径）：`$DSH_CODEPUNK_TOOLS` → `~/.dsh-codepunk/tools` → `$DSH_APP_ROOT` → `$DSH_ASAR` 同级 → 当前目录；找不到 js-yaml 时 `check` 退化为行内容比对（仍能捕获增删改，但报不出精确路径）。
- **重复声明**：同一 `id` 在 patch 内出现多处时，`check` / `apply` 一律以退出码 2 拒绝并提示人工保留一处。
- **唯一必要适配**：内联后 `customSkillDirs` 的 `baseUrl` 指向 profile 目录，须改写为回到预设目录的相对路径；生成时自动加、比对时自动归一——**这是设计行为，不是漂移**。

## 4. `preset.yml` 的语义

`preset.yml` 承载**可选的展示元数据**：`name`（标识）、`description`（roster 中展示的描述）、`order`（排序）。三者均可选；它**不改变运行时行为**，也不参与组合解析。省略它不影响挂载；缺失 `agent.cordis.yml` 或 `skills/` 才会导致预设不可用。

## 5. 部署方自配项（**不得进仓**）

| 项 | 归属 | 说明 |
|---|---|---|
| provider / model 路由 | **部署方本地配置** | 本仓不再硬编码 provider / 模型取值——公开预设不宜内置私有取值。现行口径：子代理默认**继承父会话实时路由**，`agentOptions` 仅在需**覆盖**时声明；外部后端（codex / claude-code）不套本表 |
| 私有 provider 端点与凭据 | 部署方本地配置 | 端点、密钥、私有模型名一律本地声明，**禁止提交进仓库** |
| 权限与沙箱预设 | **人类环境决策** | profile 的 `permission` 预设表与 `defaultPreset` 影响本机所有会话；预设与子代理 MUST NOT 擅自修改，只能以「建议 + 片段 + 影响面 + 生效方式」四件套提交人类裁定 |
| 禁词表 | 部署方本地文件 | `~/.dsh-codepunk/denylist.txt`（每行一词，`#` 为注释）；守卫脚本本身不含私人词 |
| 项目注册表 | 总库 | `~/.dsh-codepunk/INDEX.yaml` 与各工程 README 的 `dsh-codepunk: <project_id>` 关联；冲突以 INDEX 为准 |

## 6. 环境变量

| 变量 | 含义 | 用途 |
|---|---|---|
| `DSH_APP_ROOT` | 解包布局下的 app 目录 | 兼容核验、声明依赖发现 |
| `DSH_ASAR` | 旧版 `app.asar` 路径 | 兼容核验（2.0.10 仍为 asar，2.0.12 起解包为 `app/`） |
| `DSH_PROFILE_PATCH` | profile patch 路径 | 声明块注入与比对 |
| `DSH_CODEPUNK_TOOLS` | 本机工具目录（如 `tree-sitter` 校验器） | 依赖发现、PS 语法校验 |
| `DSH_CODEPUNK_HOME` | 总库根（默认 `~/.dsh-codepunk`） | 运行根、知识库、脚本正式位 |
| `DSH_PERMISSION_MODE` | 部署平面默认沙箱模式 | 可选加固；须重启并对新会话生效 |

版本取值命令（两套编号独立）：

```bash
plutil -extract CFBundleShortVersionString raw "<DSH 应用包>/Contents/Info.plist"   # 应用版本
dsh --version                                                                      # CLI / 包版本
```

## 7. 安装验收清单

| # | 检查 | 命令 | 期望 |
|---|---|---|---|
| 1 | 声明副本未漂移 | `node plans/preset-declare.mjs check` | 退出码 0 |
| 2 | 组合与安装兼容 | `python3 plans/preset-compat.py` | 退出码 0 |
| 3 | 工具脚本已同步 | `bash plans/dsh-codepunk-init.sh --check` | 退出码 0 |
| 4 | 总库骨架就绪 | `bash plans/dsh-codepunk-init.sh` | 生成 `projects/` `worktrees/` `scripts/` |
| 5 | 全量门禁 | `bash plans/verify-battery.sh` | 退出码 0（环境缺口项会显式标注） |
| 6 | 泄露防护 | `bash plans/dsh-codepunk-leak-guard.sh --tree` | 退出码 0 |
| 7 | 会话可见预设 | 重启 DSH Desktop 后新开会话，检查预设列表与岗位工具 | 无 broken roster row |

## 8. Windows 部署

```powershell
pwsh -File plans/windows/dsh-codepunk-init.ps1        # 同步 .ps1 到 %USERPROFILE%\.dsh-codepunk\scripts\
. "$HOME\.dsh-codepunk\dsh-codepunk-home.ps1"         # 装载路径常量
pwsh -File dsh-codepunk-init.ps1                      # 建总库骨架
pwsh -File dsh-codepunk-link.ps1 resolve <工程根>      # 关联项目
pwsh -File dsh-codepunk-leak-guard.ps1 -Tree          # 推送前守卫
```

Windows 侧当前覆盖 **home / init / link / leak-guard** 四个核心脚本，与 POSIX 侧语义等价、退出码一致；其余工具经 Git Bash 或 WSL 调用。仓库内换行统一 LF，`.ps1` 检出为 CRLF（由 `.gitattributes` 保证）。

## 9. 升级与回滚

```bash
git -C ~/.dsh/.agent-presets/dsh-codepunk pull      # ① 取新版本
node plans/preset-declare.mjs apply                 # ② 用源重写内联副本（自动备份）
node plans/preset-declare.mjs check                 # ③ 确认零漂移
bash plans/dsh-codepunk-init.sh                     # ④ 同步工具脚本到总库
python3 plans/preset-compat.py                      # ⑤ 兼容核验
# ⑥ 重启 DSH Desktop；新开会话
bash plans/verify-battery.sh                        # ⑦ 全量门禁
```

回滚：`apply` 每次写入前自动备份 profile patch；回到旧版本后用同一套命令重跑 ②–⑦ 即可。若升级引入破坏性变更，先查 `references/harness-alignment.md` 的变更表与 `benchmarks/deepseek-harness-study.md` 的机制对齐表，再决定是否回滚。

## 10. 常见部署问题

| 现象 | 原因 | 处置 |
|---|---|---|
| 会话恢复报 `Unknown agent preset` | 未注入声明行（注册表不扫描目录） | 按 §2 步骤 ② 注入并重启 |
| 声明 `check` 报漂移 | 源改了但未 `apply`，或有人手改了副本 | 跑 `apply` 重写副本；手改内容以源为准 |
| 改了脚本行为不变 | 总库副本未同步 | 跑 `bash plans/dsh-codepunk-init.sh` |
| `preset-compat.py` 返回 2 | 未设 `DSH_APP_ROOT` / `DSH_ASAR` | 按 §6 设环境变量后重跑 |
| 工具脚本不可执行 | 模式漂移（如被改成 644） | `init` 会把总库脚本模式归一为 755 |
| 新开会话仍是旧配置 | 插件配置在进程启动时读取 | 重启 DSH Desktop（新开对话无效） |
| roster 中出现 broken row | 组合形状或 `!!js` 解析失败 | 用 `entryListSchema` 校验并修复组合 |

相关文档：[architecture.md](architecture.md)（三层结构与宿主依赖）· [maintenance.md](maintenance.md)（升级后维护）· [licensing.md](licensing.md)（许可与公开性）· [faq.md](faq.md)（兼容核验问答）
