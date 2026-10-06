#!/usr/bin/env python3
"""语义保护闸：极致压缩的防丢失闸门。

用法（在目标仓库根执行）：
  python3 fidelity-gate.py snapshot   # 压缩前：提取保护区 token 快照
  python3 fidelity-gate.py verify     # 压缩后：逐项比对，缺失即失败

退出码：0=通过；1=失配或丢失（比对失败）；2=用法或环境错误（缺快照、坏参数、无法写入快照）

快照位置：$DSH_CODEPUNK_FIDELITY_SNAP（默认 ${DSH_CODEPUNK_HOME:-~/.dsh-codepunk}/.fidelity/<repo 短哈希>.json —— 按仓库隔离，
          同仓跨进程稳定、异仓互不覆盖；写入不跟随符号链接）
主动删除文件属预期变更时，删除后重跑 snapshot 刷新基线（勿在未刷新时 verify）。

受检文件范围（F205 文档化）：仅扫描 **.md / .yml / .sh / .ps1** 四类文件（见 scan 过滤器），且以工作区实际存在的文件为准；其它扩展名（如 .py/.json/.txt）内的「保护区」内容**不在本闸守护范围**。
保护区（绝不压缩）——与 D076「保护清单」一致：
  D0xx / R## / P## 编号 | 约束词（MUST / MUST NOT / 禁止 / 绝不 / 不得 / 必须）
  数值与阈值（含小数、百分比、时间、尺寸） | 路径（/ 或 ~ 开头、相对路径）
  工具名（subagent_* / job_* / *_goal / *_write / web_search / web_fetch / read_image /
         exit_plan_mode / ask_user_question / list_agents / send_message / interrupt_agent 等；
         刻意不含 read/write/edit/glob/grep/skill 等散文常用词，避免告警泛滥）
  代码标识（反引号内全部内容） | 全大写常量 | 文件名
  URL（http/https） | 证据标记（【事实】/【推断】/【未获取到】…） | 日期（YYYY-MM-DD / YYYY-MM）
  star 数（表格中的 `N stars` / `N★` 形态）
  —— 以上与实现 `PATTERNS` 的 14 类一一对应。
"""
# F198：非 UTF-8 locale 下 python 的 stdout 编码随 locale（如 ISO-8859-15）→ 输出中文结论会抛
#   `UnicodeEncodeError: 'charmap' codec can't encode`，把「本应清晰降级」变成**崩溃**并破坏退出码契约
#   （实证：`preset-compat.py` 直接调用时 rc 0 → 1；`fidelity-gate.py verify` 由 2 → 1）。
#   故进程内固定 stdout/stderr 为 UTF-8（与仓内全 UTF-8 内容一致）；reconfigure 仅 3.7+ 可用，缺失则忽略。
try:
    import sys as _sys
    for _s in (_sys.stdout, _sys.stderr):
        try:
            _s.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            pass
except Exception:
    pass

import re, sys, json, subprocess, os

import hashlib as _hashlib
import os as _os


def _repo_ident():
    """仓库身份：git 顶层目录，退化到当前工作目录（保证同仓跨进程稳定、异仓互不覆盖）。"""
    try:
        r = subprocess.run(['git', 'rev-parse', '--show-toplevel'],
                           capture_output=True, text=True, timeout=5)
        if r.returncode == 0 and r.stdout.strip():
            return r.stdout.strip()
    except Exception:
        pass
    return _os.getcwd()


def _default_snap():
    """默认基线路径：总库下 .fidelity/<repo 短哈希>.json。

    原先默认 $TMPDIR/dsh-codepunk-fidelity.json 有两个真实问题：
    ① 固定名 → 多项目/多 run 并发互相覆盖基线，verify 会拿错基准（假 PASS/假 FAIL）；
    ② 位于世界可写目录 → 可预测名可被符号链接劫持（CWE-377）。
    改后同仓跨进程仍稳定（snapshot→verify 两段式不受影响），异仓彼此隔离。
    """
    hub = _os.environ.get('DSH_CODEPUNK_HOME') or _os.path.join(_os.path.expanduser('~'), '.dsh-codepunk')
    h = _hashlib.sha256(_repo_ident().encode('utf-8')).hexdigest()[:12]
    return _os.path.join(hub, '.fidelity', f'{h}.json')


SNAP = _os.environ.get('DSH_CODEPUNK_FIDELITY_SNAP') or _default_snap()


def _write_snap(obj):
    """写基线：目录 0700、文件 O_NOFOLLOW（不跟随符号链接），避免被劫持改写他处文件。

    返回 None 表示成功；否则返回错误说明（调用方打印并退出 3）。
    """
    d = _os.path.dirname(SNAP)
    try:
        if d:
            _os.makedirs(d, mode=0o700, exist_ok=True)
            # makedirs 的 mode 只在新建时生效且受 umask 影响；已存在时显式收紧
            if (_os.stat(d).st_mode & 0o777) != 0o700:
                _os.chmod(d, 0o700)
        fd = _os.open(SNAP, _os.O_WRONLY | _os.O_CREAT | _os.O_TRUNC | getattr(_os, 'O_NOFOLLOW', 0), 0o600)
        with _os.fdopen(fd, 'w', encoding='utf-8') as fh:
            json.dump(obj, fh, ensure_ascii=False, indent=1)
    except OSError as e:
        hint = '（目标疑似符号链接，已按安全策略拒写；请删除该链接后重跑）' if e.errno == 62 else ''
        return f'{e.strerror or e}{hint}'
    return None

PATTERNS = {
    'D编号':  r'\bD0[0-9]{2}\b',
    'R编号':  r'\bR[0-9]{1,2}\b',
    'P编号':  r'\bP[0-9]{2}\b',
    '约束词':  r'\bMUST NOT\b|\bMUST\b|禁止|绝不|不得|必须',
    '阈值数值': r'\b\d+(?:\.\d+)?(?:KB|MB|KiB|MiB|B|%|s|ms|轮|次|处|条|项|个|人|天|小时|分钟)?\b',
    '路径':   r'(?:~|/)[A-Za-z0-9._/\-]+',
    # 工具名：只收**有区分度**的形态（带下划线或非常见英文词）。刻意不收 read/write/edit/
    # glob/grep/skill/bash/present —— 它们是散文常用词，纳入会让「丢失」告警泛滥；
    # 这些词作术语出现时通常带反引号，已由「代码标识」类覆盖（2026-10-05 逐类实测）。
    '工具名':  r'\b(?:subagent_[a-z_]+|subagent|job_[a-z]+|[a-z_]+_goal|[a-z_]+_write|web_search|web_fetch|read_image|exit_plan_mode|ask_user_question|list_agents|send_message|interrupt_agent|pwsh|ralph)\b',
    '代码标识': r'`[^`\n]+`',
    '文件名':  r'\b[A-Za-z0-9_\-]+\.(?:md|sh|ps1|yml|yaml|json)\b',
    '全大写常量': r'\b[A-Z][A-Z_]{3,}\b',
    'URL':   r'https?://[^\s\)\]\|<>\u3000-\u303f\uff00-\uffef]+',
    '证据标记': r'【(?:事实|推断|未获取到|已归档|缺失即缺失)[^】]*】',
    '日期':  r'\b20[0-9]{2}-[0-9]{2}-[0-9]{2}\b|\b20[0-9]{2}-[0-9]{2}\b',
    'star数': r'\b\d[\d,.]*\s*[★kK]?\s*(?:stars?|★)?\b(?=\s*\|)',
}


def extract(path):
    t = open(path, encoding='utf-8', errors='replace').read()
    out = {}
    for name, pat in PATTERNS.items():
        out[name] = sorted(set(re.findall(pat, t)))
    return out


def files():
    r = subprocess.run(['git', 'ls-files'], capture_output=True, text=True).stdout.split()
    return [f for f in r if f.endswith(('.md', '.yml', '.sh', '.ps1'))]


def usage():
    print("用法: fidelity-gate.py <snapshot|verify>")
    print("  snapshot  压缩/改写前：提取保护区 token 快照（写入 $DSH_CODEPUNK_FIDELITY_SNAP）")
    print("  verify    改写后：逐项比对快照，报告丢失的受保护 token（14 类：编号/约束词/阈值/路径/"
          "工具名/代码标识/文件名/全大写常量/URL/证据标记/日期/star 数）")
    print("退出码: 0=成功（verify 无丢失）· 1=verify 发现丢失 · 2=用法错误或无快照")


def main():
    if len(sys.argv) < 2:
        print("✗ 缺少模式参数（不再默认 snapshot：静默覆盖基线会让后续 verify 失去基准）")
        usage()
        return 2
    mode = sys.argv[1]
    if mode not in ('snapshot', 'verify'):
        print(f"✗ 未知模式: {mode}")
        usage()
        return 2
    if mode == 'snapshot':
        if os.path.exists(SNAP):
            print(f"  ⚠ 覆盖既有基线快照（原基准将被替换）: {SNAP}")
        snap = {f: extract(f) for f in files()}
        # SNAP 取相对文件名（无目录部分）时 dirname 为空串，makedirs('') 会抛异常
        _d = os.path.dirname(SNAP)
        if _d:
            os.makedirs(_d, exist_ok=True)
        err = _write_snap(snap)
        if err:
            print(f"✗ 快照写入失败: {SNAP}\n  {err}")
            return 3
        tot = sum(len(v) for d in snap.values() for v in d.values())
        print(f"✓ 快照已存：{len(snap)} 文件，{tot:,} 个受保护 token")
        print(f"  {SNAP}")
        return 0
    # verify
    if not os.path.exists(SNAP):
        print("✗ 无快照，先跑 snapshot")
        return 2
    try:
        with open(SNAP, encoding='utf-8') as _f:
            snap = json.load(_f)
    except (OSError, ValueError) as _e:
        # F207：快照损坏/不可读（截断、空文件、非法 JSON、权限）不得抛裸 Traceback——
        #   这与本文件文档的退出码契约一致（2=用法或环境错误），也与 F194/F198/F203 同族口径一致。
        print(f"✗ 快照损坏或不可读：{SNAP}（{type(_e).__name__}: {_e}）——请重跑 snapshot 重建基线", file=sys.stderr)
        sys.exit(2)
    missing = []
    for f, cats in snap.items():
        if not os.path.exists(f):
            missing.append((f, '整文件', '文件缺失'))
            continue
        now = extract(f)
        for cat, toks in cats.items():
            lost = [t for t in toks if t not in now.get(cat, [])]
            for t in lost:
                missing.append((f, cat, t))
    if missing:
        print(f"✗ 保护闸失败：丢失 {len(missing)} 个受保护 token")
        for f, cat, t in missing[:30]:
            print(f"   [{cat}] {f.split('/')[-1]}: {t}")
        return 1
    # F208/F249：空快照下 verify 会显示「✓ 全部受保护 token 均在」——这是**空真**（验证靠缺失）。
    #   F249 修正：原判据查 `snap.get("tokens")`，而写入侧（snapshot）产出的结构是
    #   `{文件名: {类别: [token…]}}`，**从不含 `tokens` 键** ⇒ 该提示对任何快照**恒发**
    #   （对 8,391 token/55 文件的快照也称「为空」），使真·空快照与假告警不可区分、F208 护栏实效为 0。
    #   现按写入侧口径统计 token 总数判空（与 snapshot 的 `tot` 口径一致）。
    if isinstance(snap, dict) and sum(len(toks) for cats in snap.values()
                                      for toks in (cats.values() if isinstance(cats, dict) else [])) == 0:
        print("  ℹ 快照为空（未捕获受保护 token）——若该仓确有编号/约束词，请检查 snapshot 是否漏扫；空快照下的「通过」不构成保护证明", file=sys.stderr)
    print("✓ 保护闸通过：全部受保护 token 均在")
    return 0


if __name__ == '__main__':
    sys.exit(main())
