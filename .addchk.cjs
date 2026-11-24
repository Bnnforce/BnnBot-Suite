const fs = require('fs');
const f = 'scripts/check-release.mjs';
if (!fs.existsSync(f)) { console.log('❌ 没有 check-release.mjs（在 Bot/scripts 下）'); process.exit(1); }
let s = fs.readFileSync(f, 'utf8');
const OLD = `// ══ ③ 文档链接指向当前 tag ══`;
const NEW = `// ══ ②b 版本号单点真相（manifest 是唯一真相）══
function checkVersionSingleSource(manifest) {
  const v = String(manifest?.version || '');
  if (!v) return;
  const files = ['PROMPT.txt', 'README.md', 'INSTALL.md', 'checklist.md', 'AGENT.md'];
  let stale = [];
  for (const name of files) {
    const p = join(REPO, name);
    if (!existsSync(p)) continue;
    const s2 = readFileSync(p, 'utf8');
    const hits = [...s2.matchAll(/releases\\/download\\/(v[\\d.]+)\\//g)].map((m) => m[1]);
    const bad = [...new Set(hits)].filter((x) => x !== \`v\${v}\`);
    if (bad.length) stale.push(\`\${name}: \${bad.join(',')}\`);
  }
  if (stale.length) {
    rec('fail', '版本', '有文档的下载链接不是当前版本', stale.join(' | '));
    rec('warn', '版本', '修法：node scripts/sync-version.mjs');
  } else {
    rec('ok', '版本', \`所有文档统一指向 v\${v}\`);
  }
}

// ══ ③ 文档链接指向当前 tag ══`;
if (!s.includes(OLD)) { console.log('❌ 未匹配'); process.exit(1); }
s = s.replace(OLD, NEW);

// 调用点
s = s.replace(
  '  if (!asJson) console.log(\'\\n════ ③ 文档下载链接\');\n  checkDocs(manifest);',
  '  if (!asJson) console.log(\'\\n════ ②b 版本号单点真相\');\n  checkVersionSingleSource(manifest);\n\n  if (!asJson) console.log(\'\\n════ ③ 文档下载链接\');\n  checkDocs(manifest);'
);

fs.writeFileSync(f, s);
console.log('✅ check-release 已加版本单点检查');
