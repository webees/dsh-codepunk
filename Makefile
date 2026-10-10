# ======
# dsh-codepunk —— 工程化入口（Makefile）
# ------
# 用途：把「门禁 / 存活自检 / 验证电池 / 写盘纪律 / 兼容核验 / 脚本镜像」收成单一本地入口；
#   本文件只做**编排**，判据全部在 plans/ 内。
#
# 与 CI 的关系（实测口径，勿推断）：CI **不调用** `make`——`.github/workflows/ci.yml`
#   的四个作业各自直接调 `plans/` 脚本（并有本文件没有的步骤：`bash -n`、`python3 -m
#   py_compile`、shellcheck、可执行位与移植性扫描）。因此：
#   · `make gates` 与 CI 的「门禁回归」**不等价**（前者＝doc-consistency + preset-audit +
#     preset-score + leak-guard；后者＝`verify-battery.sh` 全量电池）；
#   · 个别目标实参也窄于 CI：`make write-scope` 用 `--repo . --tmp`，CI 另用**假 HOME**
#     加 `--home`（可捕获写进主目录的散落物）⇒ 本地绿不等于 CI 绿，**以 CI 结论为准**
#     （见 `CONTRIBUTING.md` §5.2 与 `docs/development.md`）。
#   目标是把 CI 的判据在本地复跑，不是让两者共享入口；若日后要收敛为单一入口，
#   须同步改造 ci.yml 各作业与 `doc-consistency.sh` 第 7 类的 CI 门禁表判据。
#
# 约定：
#   · 每个目标先切到本 Makefile 所在目录 ⇒ 支持 `make -C <dir>` 与任意 cwd 调用；
#   · 目标失败即以非零退出码收场（调用方直接取 rc，不做二次解释）；
#   · 运行产物只落本仓 tmp/ 与 logs/（两者均已在 .gitignore 内），仓库保持纯净。
#
# 可移植性约定（重要）：**不使用 `.ONESHELL`**。它是 GNU make ≥ 3.82 的特性，
#   而 macOS 自带 /usr/bin/make 为 3.81，会**静默忽略**它 ⇒ 多行配方被逐行当作独立
#   shell 执行，`if …; then` 之类跨行构造直接语法错误（实测：`make compat` 报
#   `/bin/bash: -c: line 1: syntax error: unexpected end of file`，rc=2）。
#   本文件改用「行尾反斜杠续行」把每个目标的整段逻辑交给**同一个** shell ——
#   该写法在 make 3.81 与 4.x 上语义一致，无需版本分支。
#
# 目标一览见 `make` 或 `make help`。
# ======

SHELL := /bin/bash
.DEFAULT_GOAL := help

# 仓库根：由本 Makefile 所在目录反推（不写死任何平台路径；macOS/Linux 同构）。
# F334：原式 `$(dir $(abspath $(lastword $(MAKEFILE_LIST))))` 在**路径含空格**时失效——Make 函数按
#   空白分词，`$(dir …)` 只取到结果的首个词 ⇒ ROOT 被截断，配方 `cd "$(ROOT)"` 失败并 rc=2
#   （实测：把本仓克隆到 `…/克隆 空格 é` 后 `make gates` 报
#   `cd: /Users/…/r612 . é: No such file or directory`、`make: *** [gates] Error 2`），
#   而同一路径下四道门禁直调 rc 全 0 ⇒ 入口在受支持路径下不可用。
#   改用 shell 求根：`$(CURDIR)` 由 make 归一化（`make -C <dir>` 会先 chdir），路径只在 shell 层
#   以引号出现，不经 Make 函数分词；配方内所有 `$(ROOT)` 均已加引号。
ROOT := $(shell cd "$(CURDIR)" && pwd)
# 脚本运行期正式位：总库 scripts/ 镜像目录（preset-audit F2 与 preset-score B14 对照此处）
# F328：总库位置 MUST 采纳文档化变量 DSH_CODEPUNK_HOME（plans/dsh-codepunk-home.sh 导出），
#   未设时才回退 `$HOME/.dsh-codepunk`——否则自定义总库位置的用户 make mirror 会写错位置。
HUB_ROOT := $(if $(DSH_CODEPUNK_HOME),$(DSH_CODEPUNK_HOME),$(HOME)/.dsh-codepunk)
HUB := $(HUB_ROOT)/scripts
# 仓库内临时目录（.gitignore 已忽略；正式临时物按写盘纪律应落总库 tmp/，见 references/file-hygiene.md §六）
RUN_TMP := $(ROOT)/tmp
# 总库临时目录（各轮沙箱落点；clean 亦须清理此处，否则「以为已清而实际未清」）
HUB_TMP := $(HUB_ROOT)/tmp

.PHONY: help gates selftest battery write-scope compat mirror ps-validate clean

help:
	@printf '%s\n' 'dsh-codepunk 工程化入口 —— 用法: make <目标>'
	@printf '%s\n' '' '  help         列出全部目标（默认目标）'
	@printf '%s\n' '  gates        四道门禁: doc-consistency + preset-audit + preset-score + leak-guard'
	@printf '%s\n' '  selftest     检查器存活自检（变异测试；较慢，约 350 s）'
	@printf '%s\n' '  battery      完整验证电池（单命令复跑全部验证）'
	@printf '%s\n' '  write-scope  写盘纪律门（--repo . --tmp）'
	@printf '%s\n' '  compat       组合 ↔ DSH 安装兼容核验（需 DSH_APP_ROOT 或 DSH_ASAR）'
	@printf '%s\n' '  mirror       把 plans/*.sh 与 plans/*.py 安装到总库并逐文件 cmp -s 校验'
	@printf '%s\n' '  ps-validate  PowerShell 校验器依赖安装 + ps-validate.mjs 语法校验（CI 两作业共用配方）'
	@printf '%s\n' '  clean        清理仓库临时目录与总库临时目录（tmp/；不动总库 tools/）'
	@printf '%s\n' '' '例: make gates' '    make compat DSH_APP_ROOT=<解包后的 app 目录>'

# ── 门禁：文档一致性 + 预设审计 + 16 指标评分 + 泄露防护 ────────────────────
gates:
	cd "$(ROOT)" || exit 2; \
	rc=0; \
	for s in doc-consistency preset-audit preset-score; do \
	  printf '\n── gates: %s.sh ──\n' "$$s"; \
	  bash "plans/$$s.sh" || { printf '✗ gates: %s.sh rc=%s\n' "$$s" "$$?"; rc=1; }; \
	done; \
	printf '\n── gates: dsh-codepunk-leak-guard.sh --tree ──\n'; \
	bash plans/dsh-codepunk-leak-guard.sh --tree || { printf '✗ gates: leak-guard rc=%s\n' "$$?"; rc=1; }; \
	if [ "$$rc" -eq 0 ]; then echo 'gates: 四门禁全部通过'; else echo 'gates: 存在失败项（见上）'; fi; \
	exit $$rc

# ── 检查器存活自检（变异测试）──────────────────────────────────────────────
selftest:
	cd "$(ROOT)" || exit 2; \
	printf '── selftest: plans/checker-self-test.sh（变异测试，约 350 s）──\n'; \
	bash plans/checker-self-test.sh

# ── 完整验证电池 ───────────────────────────────────────────────────────────
battery:
	cd "$(ROOT)" || exit 2; \
	printf '── battery: plans/verify-battery.sh ──\n'; \
	bash plans/verify-battery.sh

# ── 写盘纪律门 ─────────────────────────────────────────────────────────────
write-scope:
	cd "$(ROOT)" || exit 2; \
	printf '── write-scope: plans/write-scope-check.sh --repo . --tmp ──\n'; \
	bash plans/write-scope-check.sh --repo . --tmp

# ── 组合 ↔ DSH 安装兼容核验 ────────────────────────────────────────────────
compat:
	cd "$(ROOT)" || exit 2; \
	command -v python3 >/dev/null 2>&1 || { printf '✗ 缺 python3（preset-compat 依赖）\n' >&2; exit 2; }; \
	if [ -z "$${DSH_APP_ROOT:-}" ] && [ -z "$${DSH_ASAR:-}" ]; then \
	  printf '提示: 未设置 DSH_APP_ROOT / DSH_ASAR —— preset-compat 无法定位 DSH 安装（按契约 rc=2）。\n      用法: make compat DSH_APP_ROOT=<解包后的 app 目录>\n            make compat DSH_ASAR=<旧布局 app.asar 路径>\n' >&2; \
	fi; \
	python3 plans/preset-compat.py "$(ROOT)"

# ── 脚本镜像：plans/ 源副本 → 总库 scripts/（安装后逐文件比对）─────────────
mirror:
	cd "$(ROOT)" || exit 2; \
	install -d "$(HUB)" || { printf '✗ 无法创建镜像目录: %s\n' "$(HUB)" >&2; exit 2; }; \
	rc=0; n=0; \
	for f in plans/*.sh plans/*.py; do \
	  b="$${f##*/}"; \
	  install -m 755 "$$f" "$(HUB)/$$b" || { printf '✗ 安装失败: %s\n' "$$f"; rc=1; continue; }; \
	  if cmp -s "$$f" "$(HUB)/$$b"; then n=$$((n + 1)); else printf '✗ 镜像不一致（cmp -s）: %s\n' "$$b"; rc=1; fi; \
	done; \
	printf '镜像: %s 个文件与源副本逐字节一致（install -m 755 + cmp -s）\n' "$$n"; \
	exit $$rc

# ── PowerShell 校验器依赖 + 语法校验（CI 两个作业共用同一配方）────────────────────────
# F454 实证：同三联行（`npm init` / `npm i tree-sitter…` / `node ps-validate.mjs …`）曾在 ci.yml
#   两个作业内逐字重复（同文件重复块 212 B ×2）⇒ 抽为本目标作**单一声明源**，CI 步骤退化为
#   `run: make ps-validate`。依赖落位＝总库 tools/（HUB_ROOT/tools），与原 CI 的
#   `$HOME/.dsh-codepunk/tools` 等价。
ps-validate:
	set -eu; cd "$(ROOT)" || exit 2; \
	command -v npm >/dev/null 2>&1 || { printf '✗ 缺 npm（PowerShell 校验器依赖安装）\n' >&2; exit 2; }; \
	command -v node >/dev/null 2>&1 || { printf '✗ 缺 node（ps-validate.mjs 依赖）\n' >&2; exit 2; }; \
	mkdir -p "$(HUB_ROOT)/tools" || exit 2; \
	cd "$(HUB_ROOT)/tools" || exit 2; \
	[ -f package.json ] || npm init -y >/dev/null; \
	npm i --no-audit --no-fund --loglevel=error tree-sitter tree-sitter-powershell || { \
	  printf '✗ 依赖安装失败 ⇒ 无法核验 ≠ 通过（F457：存量 %s/package.json 的锁定版本可致 npm ERESOLVE，\n  （原始 CI 三联行配方在同一存量目录同样 rc=1——实证见运行根 logs 目录））：\n    rm -rf "%s" && make ps-validate\n' "$(HUB_ROOT)/tools" "$(HUB_ROOT)/tools" >&2; exit 2; }; \
	node "$(ROOT)/plans/ps-validate.mjs" "$(ROOT)"/plans/windows/*.ps1

# ── 清理仓库临时目录与总库临时目录（tmp/；不动总库 tools/ 工具安装位）────────────────
clean:
	rm -rf -- "$(RUN_TMP)"; \
	printf '已清理仓库临时目录: %s\n' "$(RUN_TMP)"; \
	if [ -d "$(HUB_TMP)" ]; then \
	  rm -rf -- "$(HUB_TMP)"; \
	  printf '已清理总库临时目录: %s\n' "$(HUB_TMP)"; \
	else \
	  printf '总库临时目录不存在，跳过: %s\n' "$(HUB_TMP)"; \
	fi
