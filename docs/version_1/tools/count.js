const fs = require('fs');

const jsonPath = process.argv[2] || 'docs/evidence/p7s2/G_test.json';
const outPath = process.argv[3] || 'docs/evidence/p7s2/G_counts.txt';

const lines = fs.readFileSync(jsonPath, 'utf8').split(/\r?\n/).filter(Boolean);

let total = 0;
let success = 0;
let failure = 0;

for (const line of lines) {
  try {
    const ev = JSON.parse(line);
    if (ev.type === 'testDone') {
      if (ev.hidden) continue;
      total++;
      if (ev.result === 'success') {
        success++;
      } else {
        failure++;
      }
    }
  } catch (e) {
    // skip non-json
  }
}

const out = `testDone ${total} success ${success} failure ${failure}\n`;
console.log(out.trim());
fs.writeFileSync(outPath, out, 'utf8');
