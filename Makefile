# ============================================================================
# dsh-codepunk —— 工程化入口（Makefile）
# ----------------------------------------------------------------------------
# 用途：把「门禁 / 存活自检 / 验证电池 / 写盘纪律 / 兼容核验 / 脚本镜像」收成单一入口，
#   本地与 CI（Ubuntu）用同一条命令复跑；本文件只做**编排**，判据全部在 plans/ 内。
#
# 约定：
#   · 每个目标先切到本 Makefile 所在目录 ⇒ 支持 `make -C <dir>` 与任意 cwd 调用；
#   · 目标失败即以非零退出码收场（CI 直接取 rc，不做二次解释）；
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
# ============================================================================

SHELL := /bin/bash
.DEFAULT_GOAL := help

# 仓库根：由本 Makefile 的绝对路径反推（不写死任何平台路径；macOS/Linux 同构）
ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
# 脚本运行期正式位：总库 scripts/ 镜像目录（preset-audit F2 与 preset-score B14 对照此处）
HUB := $(HOME)/.dsh-codepunk/scripts
# 本仓运行根（临时产物）
RUN_TMP := $(ROOT)/tmp

.PHONY: help gates selftest battery write-scope compat mirror clean

help:
	@printf '%s\n' 'dsh-codepunk 工程化入口 —— 用法: make <目标>'
	@printf '%s\n' '' '  help         列出全部目标（默认目标）'
	@printf '%s\n' '  gates        四道门禁: doc-consistency + preset-audit + preset-score + leak-guard'
	@printf '%s\n' '  selftest     检查器存活自检（变异测试；较慢，约 350 s）'
	@printf '%s\n' '  battery      完整验证电池（单命令复跑全部验证）'
	@printf '%s\n' '  write-scope  写盘纪律门（--repo . --tmp）'
	@printf '%s\n' '  compat       组合 ↔ DSH 安装兼容核验（需 DSH_APP_ROOT 或 DSH_ASAR）'
	@printf '%s\n' '  mirror       把 plans/*.sh 与 plans/*.py 安装到总库并逐文件 cmp -s 校验'
	@printf '%s\n' '  clean        清理本仓运行根 tmp/'
	@printf '%s\n' '' '例: make gates' '    make compat DSH_APP_ROOT=<解包后的 app 目录>'

# ── 门禁：文档一致性 + 预设审计 + 15 指标评分 + 泄露防护 ────────────────────
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

# ── 清理本仓运行根 tmp/ ────────────────────────────────────────────────────
clean:
	rm -rf -- "$(RUN_TMP)"; \
	printf '已清理运行根 tmp/: %s\n' "$(RUN_TMP)"
