#!/usr/bin/env node
/**
 * ps-validate.mjs —— PowerShell 语法校验器（tree-sitter-powershell）
 *
 * 用途：在无 pwsh 的机器上校验 .ps1 语法（preset-score.sh / verify-battery.sh 的 PS 项依赖它）。
 * 安装：mkdir -p ~/.dsh-codepunk/tools && cd ~/.dsh-codepunk/tools
 *       npm init -y && npm i tree-sitter tree-sitter-powershell
 *       把本文件放到该目录（或任意位置，用 PWSH_VALIDATOR 指向它）
 * 用法：node ps-validate.mjs <文件.ps1> [...]
 * 退出码：0=全部通过；1=存在语法错误
 */
import { readFileSync, existsSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

// 依赖解析：按序尝试 脚本目录 / 总库 tools / 当前目录（任一含 node_modules 即可）
const here = dirname(fileURLToPath(import.meta.url));
const home = process.env.HOME ?? '';
const cands = [
  here,
  join(home, '.dsh-codepunk', 'tools'),
  process.env.DSH_CODEPUNK_TOOLS ?? '',
  process.cwd(),
].filter(Boolean);

import { pathToFileURL } from 'node:url';

// 包为 ESM：先 require.resolve 取路径，再动态 import（require() 本体不可用）
let Parser, PS;
for (const base of cands) {
  if (!existsSync(join(base, 'node_modules'))) continue;
  try {
    const req = createRequire(join(base, 'noop.js'));
    const pPath = req.resolve('tree-sitter');
    const gPath = req.resolve('tree-sitter-powershell');
    const pMod = await import(pathToFileURL(pPath).href);
    const gMod = await import(pathToFileURL(gPath).href);
    Parser = pMod.default ?? pMod;
    PS = gMod.default ?? gMod;
    if (Parser && PS) break;
  } catch { Parser = PS = undefined; }
}
if (!Parser || !PS) {
  console.error('✗ 缺依赖（tree-sitter / tree-sitter-powershell）。安装：mkdir -p ~/.dsh-codepunk/tools && cd ~/.dsh-codepunk/tools && npm init -y && npm i tree-sitter tree-sitter-powershell');
  process.exit(2);
}

const parser = new Parser();
parser.setLanguage(PS.default ?? PS.default?.default ?? PS);

const files = process.argv.slice(2);
if (files.length === 0) {
  console.error('用法: node ps-validate.mjs <文件.ps1> [...]');
  process.exit(2);
}

let failed = 0;
for (const f of files) {
  let src;
  try { src = readFileSync(f, 'utf8'); }
  catch { console.log(`✗ ${f} — 读取失败`); failed++; continue; }
  const tree = parser.parse(src);
  const errs = [];
  const walk = (n) => {
    if (n.type === 'ERROR' || n.isMissing) {
      errs.push(`${n.type}${n.isMissing ? '(missing)' : ''} @ L${n.startPosition.row + 1}:${n.startPosition.column}`);
    }
    for (const c of n.children) walk(c);
  };
  walk(tree.rootNode);
  if (errs.length || tree.rootNode.hasError) {
    failed++;
    console.log(`✗ ${f.split('/').pop()} — ${errs.length} 处语法问题`);
    errs.slice(0, 5).forEach((e) => console.log(`    ${e}`));
  } else {
    console.log(`✓ ${f.split('/').pop()}  (${src.split('\n').length} 行)`);
  }
}
console.log(failed ? `\n❌ ${failed} 个文件有语法错误` : '\n✅ 全部 PS 脚本语法通过');
process.exit(failed ? 1 : 0);
