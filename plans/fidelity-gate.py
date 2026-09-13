#!/usr/bin/env python3
"""语义保护闸：极致压缩的防丢失闸门。

用法（在目标仓库根执行）：
  python3 fidelity-gate.py snapshot   # 压缩前：提取保护区 token 快照
  python3 fidelity-gate.py verify     # 压缩后：逐项比对，缺失即失败

快照位置：$DSH_CODEPUNK_FIDELITY_SNAP（默认 $TMPDIR/dsh-codepunk-fidelity.json）
主动删除文件属预期变更时，删除后重跑 snapshot 刷新基线（勿在未刷新时 verify）。

保护区（绝不压缩）——与 D076「保护清单」一致：
  D0xx / R## / P## 编号 | MUST / MUST NOT / 禁止 / 绝不 / MUST 级约束词
  数值与阈值（含小数、百分比、时间、尺寸） | 路径（/ 或 ~ 开头、相对路径）
  工具名（subagent_* / job_* / *_goal / snake_case 标识）
  代码标识（反引号内全部内容） | 全大写常量 | 文件名
"""
import re, sys, json, subprocess, os

import os as _os
SNAP = _os.environ.get('DSH_CODEPUNK_FIDELITY_SNAP') \
    or _os.path.join(_os.environ.get('TMPDIR', '/tmp'), 'dsh-codepunk-fidelity.json')

PATTERNS = {
    'D编号':  r'\bD0[0-9]{2}\b',
    'R编号':  r'\bR[0-9]{1,2}\b',
    'P编号':  r'\bP[0-9]{2}\b',
    '约束词':  r'\bMUST NOT\b|\bMUST\b|禁止|绝不|不得|必须',
    '阈值数值': r'\b\d+(?:\.\d+)?(?:KB|MB|KiB|MiB|B|%|s|ms|轮|次|处|条|项|个|人|天|小时|分钟)?\b',
    '路径':   r'(?:~|/)[A-Za-z0-9._/\-]+',
    '工具名':  r'\b(?:subagent_[a-z_]+|job_[a-z]+|[a-z_]+_goal|[a-z_]+_write|create_goal|get_goal|update_goal|ask_user_question|list_agents|send_message|interrupt_agent)\b',
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


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else 'snapshot'
    if mode == 'snapshot':
        snap = {f: extract(f) for f in files()}
        os.makedirs(os.path.dirname(SNAP), exist_ok=True)
        json.dump(snap, open(SNAP, 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
        tot = sum(len(v) for d in snap.values() for v in d.values())
        print(f"✓ 快照已存：{len(snap)} 文件，{tot:,} 个受保护 token")
        print(f"  {SNAP}")
        return 0
    # verify
    if not os.path.exists(SNAP):
        print("✗ 无快照，先跑 snapshot")
        return 2
    snap = json.load(open(SNAP, encoding='utf-8'))
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
    print("✓ 保护闸通过：全部受保护 token 均在")
    return 0


if __name__ == '__main__':
    sys.exit(main())
