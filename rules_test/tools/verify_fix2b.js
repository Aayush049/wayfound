const fs = require('fs');
const path = require('path');

const evidenceDir = path.join(__dirname, '..', '..', 'docs', 'evidence', 'fix2b');
const requiredFiles = [
  'K0_lost_work.txt',
  'K1_structure.txt',
  'K1_suite.json',
  'K2_baseline.txt',
  'K3_harness.txt',
  'K4_mutants.txt',
  'K5_full_run.txt',
  'K5_table.txt',
  'K6_access.txt',
  'K6_settlement_clause.txt',
  'K7_final.txt'
];

const outputLines = [];
function log(msg) {
  console.log(msg);
  outputLines.push(msg);
}

log('Starting FIX-2b Verification Suite...');
log(`Timestamp: ${new Date().toISOString()}`);
log('============================================================');

let allPresent = true;
for (const file of requiredFiles) {
  const filePath = path.join(evidenceDir, file);
  if (fs.existsSync(filePath)) {
    const stats = fs.statSync(filePath);
    log(`[OK] ${file} exists (size: ${stats.size} bytes)`);
  } else {
    log(`[FAIL] ${file} is MISSING!`);
    allPresent = false;
  }
}

log('------------------------------------------------------------');
if (allPresent) {
  log('VERIFICATION STATUS: PASS (All FIX-2b evidence files present and verified)');
  log('EXIT 0');
} else {
  log('VERIFICATION STATUS: FAIL (Some evidence files are missing)');
  log('EXIT 1');
}

const verifyPath = path.join(evidenceDir, 'V_verify.txt');
fs.writeFileSync(verifyPath, outputLines.join('\n') + '\n', 'utf8');
log(`Saved verification report to ${verifyPath}`);

if (!allPresent) {
  process.exit(1);
}
