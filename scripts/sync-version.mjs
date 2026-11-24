#!/usr/bin/env node
/**
 * sync-version — 把 manifest.json 的 version 同步到所有文档里的下载链接
 *
 * 为什么需要：版本号散落在 5 个文件十几处。手工改必漏 ——
 * 2026-11-24 就漏过：Release 发的是 v1.0.8，但三个文档还写着 v1.0.7。
 * 现在 manifest.json 是唯一真相，其余由本脚本同步。
 *
 * 用法：
 *   node scripts/sync-version.mjs              # 同步
 *   node scripts/sync-version.mjs --check      # 只检查，不一致退出码 1
 *   node scripts/sync-version.mjs --set 1.0.9  # 先改 manifest 再同步
 */
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = join(HERE, '..');
const MANIFEST = join(ROOT, 'manifest.json');

const args = process.argv.slice(2);
const CHECK = args.includes('--check');
const setIdx = args.indexOf('--set');

if (setIdx >= 0) {
  const next = String(args[setIdx + 1] || '').trim();
  if (!/^\d+\.\d+\.\d+$/.test(next)) {
    console.error(`❌ 版本号格式不对：${next}（要 x.y.z）`);
    process.exit(1);
  }
  const m = JSON.parse(readFileSync(MANIFEST, 'utf8'));
  m.version = next;
  m.updated = new Date().toISOString().slice(0, 10);
  writeFileSync(MANIFEST, JSON.stringify(m, null, 2) + '\n');
  console.log(`✅ manifest.version → ${next}`);
}

const manifest = JSON.parse(readFileSync(MANIFEST, 'utf8'));
const version = String(manifest.version || '').trim();
if (!version) {
  console.error('❌ manifest.json 没有 version');
  process.exit(1);
}

const FILES = ['PROMPT.txt', 'README.md', 'INSTALL.md', 'checklist.md', 'AGENT.md'];

let changed = 0;
const stale = [];

for (const name of FILES) {
  const p = join(ROOT, name);
  if (!existsSync(p)) continue;
  const before = readFileSync(p, 'utf8');
  const after = before.replace(/releases\/download\/v[\d.]+\//g, `releases/download/v${version}/`);
  if (after === before) continue;

  const olds = [...before.matchAll(/releases\/download\/(v[\d.]+)\//g)].map((m) => m[1]);
  const uniqueOlds = [...new Set(olds)].filter((v) => v !== `v${version}`);
  if (uniqueOlds.length) stale.push(`${name}: ${uniqueOlds.join(', ')} → v${version}`);

  changed += 1;
  if (CHECK) continue;
  writeFileSync(p, after);
  console.log(`  ✅ ${name} → v${version}`);
}

if (CHECK) {
  if (changed) {
    console.log(`\n❌ 有 ${changed} 个文件的下载链接不是 v${version}：`);
    for (const s of stale) console.log(`  · ${s}`);
    console.log('\n修法：node scripts/sync-version.mjs');
    process.exit(1);
  }
  console.log(`\n✅ 所有文档的下载链接都是 v${version}`);
  process.exit(0);
}

console.log(`\n结果：更新 ${changed} 个文件，统一到 v${version}`);
