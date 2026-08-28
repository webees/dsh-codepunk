# 产出纪律：YAGNI 阶梯与根因修复（references/anti-overengineering.md）

> D081 完整展开。借鉴 DietrichGebert/ponytail（115k★，纯 MIT）——「让 agent 像最懒的高级工程师：最好的代码是没写的代码」。与 D076（表述层 token 经济）构成**表述/产出姊妹对**：D076 管「怎么说」，D081 管「写什么」。溯源：`benchmarks/ponytail-analysis.md`。

## 一、七级递减阶梯（写码前停在第一个成立的档位）

```
1. 需要写吗？(YAGNI)   → 不需要：跳过
2. 本仓已有？           → 复用 helper/util/pattern，别重写
3. 标准库有吗？         → 用 stdlib
4. 平台原生有吗？       → `<input type="date">` 优于日期选择器库
5. 已装依赖能解吗？     → 用它，别为新需求装新依赖
6. 能一行吗？           → 一行
7. 然后才：写最小可用代码
```

**双约束（MUST）**：
- 阶梯在**理解问题之后**跑，而非替代理解（"read fully, then be lazy"）——最小改动放错位置不是懒，是第二个 bug。
- 两档都成立取**更高档**（reflex，不逐档研究）。

## 二、根因修复（修 bug 先找共同根因）

- bug 报告给的是**症状**。改码前 grep 该函数**全部 caller**，在共享函数里修一次（一个 guard 的 diff < 每个 caller 各一个 guard）。
- 只修 ticket 点名路径会让兄弟 caller 仍坏着——root cause 优先。

## 三、简化留痕（故意简化要诚实标注）

砍掉真角落（global lock / O(n²) / naive heuristic）时用 `dsh-debt:` 注释命名**天花板 + 升级路径**：

```ts
// dsh-debt: debounce 用 setTimeout 简化。ceiling: 高并发连点。upgrade: 出现节流需求时换 rAF。
```

- **无 upgrade path 的标 `no-trigger`**（"那些会悄悄腐烂"——later 变 never）。
- 交接包 known_issues 增「简化台账」节：收集 `grep -rn "dsh-debt:"` 结果；**无 trigger 的打回补写**（D079 增量：防「有意简化腐烂成债」）。

## 四、Not-lazy 保护清单（绝不简化）

以下场景**禁止**套 YAGNI：理解问题本身、trust boundary 校验、防数据丢失的错误处理、安全、可访问性、硬件校准（clock drifts/sensor 读取偏差——平台从不是 spec 理想）、用户明确要求完整版（用户坚持 → 直接建，不再争论）。

> 红线：规则是「只写任务需要的」，**永不砍验证/错误处理/安全/可访问性**。bare one-liner 提示让 safety 掉到 95%，ponytail 保持 100%。

## 五、检查纪律（YAGNI 应用于测试）

- 非平凡逻辑（branch/loop/parser/money-security path）留**一个有可跑性**的检查：assert 版 demo / `__main__` 自检 / 一个小 `test_*.py`。
- **no frameworks, no fixtures, no per-function suites**（除非要求）；平凡一行无需测试。
- 与 sdet evidence（R12/D069）形成「写时自检 + 验后证据」双保险。

## 六、输出契约（回报格式）

`[code] → skipped: [X], add when [Y].` —— code 先行，然后至多 3 行（跳过了什么 / 何时补）。「解释比代码长就删解释」；用户要的完整报告/走读仍给全文（规则只禁**未被请求的**散文）。

## 七、审查契约（D068/D069 增强）

审查记录 `reviews/<task_id>.md` 追加「over-engineering 发现」栏，用五 tag + `net:` 行（机器可解析）：

```
L<line>: delete:|stdlib:|native:|yagni:|shrink: <what>. <replacement>.
net: -<N> lines possible.
无物可删 → Lean already. Ship.
```

范围声明：correctness/security/perf 明确出局（转正常 review）；审查只找「该删的」。

## 八、强度（轻量，非承重）

默认 full（阶梯强制）；强约 ultra（YAGNI 极端，删除优先）；保守 lite（命名替代）。多智能体中文流程默认 full 即可，不逐岗分级。