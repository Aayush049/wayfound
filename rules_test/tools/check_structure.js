const fs = require('fs');
const path = require('path');

const testFile = path.join(__dirname, '..', 'firestore_rules.test.js');
const content = fs.readFileSync(testFile, 'utf8');

const lines = content.split('\n');
let depth = 0;
const results = [];

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  const trimmed = line.trim();
  if (trimmed.startsWith('describe(')) {
    results.push({ depth: depth + 1, line: i + 1, text: trimmed });
    depth++;
  } else if (trimmed === '});' || trimmed === '})') {
    if (depth > 0) depth--;
  }
}

console.log('Describe nesting structure:');
results.forEach(r => {
  console.log(`Depth ${r.depth} (Line ${r.line}): ${r.text}`);
});

const outDir = path.join(__dirname, '..', '..', 'docs', 'evidence', 'fix1');
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, '05_structure.txt'), results.map(r => `Depth ${r.depth} (Line ${r.line}): ${r.text}`).join('\n') + '\n');
console.log('Saved structure to docs/evidence/fix1/05_structure.txt');
