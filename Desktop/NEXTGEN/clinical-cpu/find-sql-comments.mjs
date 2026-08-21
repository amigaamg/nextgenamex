import { readFileSync, readdirSync, statSync } from 'node:fs';
import { join } from 'node:path';

const roots = ['src', 'server', 'test'];
const base = process.cwd();

function walk(dir, out) {
  for (const entry of readdirSync(dir)) {
    const full = join(dir, entry);
    const st = statSync(full);
    if (st.isDirectory()) {
      if (entry === 'node_modules') continue;
      walk(full, out);
    } else if (entry.endsWith('.ts') || entry.endsWith('.mts') || entry.endsWith('.tsx')) {
      out.push(full);
    }
  }
}

const files = [];
for (const r of roots) {
  const dir = join(base, r);
  if (statSync(dir, { throwIfNoEntry: false })) walk(dir, files);
}

let issues = 0;
for (const file of files) {
  const src = readFileSync(file, 'utf8');
  const lines = src.split('\n');
  let inTemplate = false;
  let lineStart = 0;
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    if (inTemplate) {
      if (line.includes('`')) {
        inTemplate = false;
        continue;
      }
      // check for a `//` comment inside SQL template
      const trimmed = line.trimStart();
      if (trimmed.startsWith('//')) {
        issues++;
        console.log(`${file}:${i + 1}  [TEMPLATE] ${trimmed}`);
      }
      continue;
    }
    // detect opening of a template literal that contains SQL
    const openIdx = line.indexOf('`');
    if (openIdx === -1) continue;
    // heuristics: template literal looks like SQL
    const pre = line.slice(0, openIdx);
    const rest = line.slice(openIdx + 1);
    if (/query(One)?\s*\(|FROM\s|SELECT|INSERT|UPDATE|WITH\s/i.test(pre) || /SELECT|FROM|INSERT|UPDATE|WITH/.test(rest)) {
      if (rest.includes('`')) continue; // single-line template
      inTemplate = true;
      // check the part after opening backtick on this line
      const trimmedRest = rest.trimStart();
      if (trimmedRest.startsWith('//')) {
        issues++;
        console.log(`${file}:${i + 1}  [TEMPLATE-OPEN] ${trimmedRest}`);
      }
    }
  }
}
console.log(`\nTotal SQL-template // comment issues: ${issues}`);