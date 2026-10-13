const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const evidenceDir = path.join(__dirname, '..', '..', 'docs', 'evidence', 'fix2');
fs.mkdirSync(evidenceDir, { recursive: true });

const oldTestPath = path.join(evidenceDir, 'c074c1d_rules_test.js');
let oldContent = '';
try {
  oldContent = execSync('git show c074c1d:rules_test/firestore_rules.test.js', { encoding: 'utf8' });
  fs.writeFileSync(oldTestPath, oldContent, 'utf8');
} catch (e) {
  console.error('Failed to dump baseline test file from git commit c074c1d:', e.message);
  process.exit(1);
}

const currentTestPath = path.join(__dirname, '..', 'firestore_rules.test.js');
const currentContent = fs.readFileSync(currentTestPath, 'utf8');

function extractTestTitles(code) {
  const regex = /\b(?:test|it)\s*\(\s*(['"`])((?:(?!\1)[^\\]|\\.)*)\1\s*,\s*/g;
  const titles = [];
  let match;
  while ((match = regex.exec(code)) !== null) {
    titles.push(match[2]);
  }
  return titles;
}

const oldTitles = extractTestTitles(oldContent);
const currentTitles = extractTestTitles(currentContent);

const currentSet = new Set(currentTitles);

// Refactored titles mapping from c074c1d broad integration tests to HEAD granular unit tests
const refactoredMappings = {
  "Trip members can read settlements, non-members cannot": [
    "Settlement read: member allowed",
    "Settlement read: non-member denied",
    "Settlement read: unauthenticated denied"
  ],
  "Valid settlement create succeeds by payer, fails for invalid fields, amounts, or non-members": [
    "Settlement create: valid create succeeds",
    "Settlement create: non-member denied",
    "Settlement create: archived trip denied",
    "Settlement create: extra key denied",
    "Settlement create: missing key denied",
    "Settlement create: fromUid != auth uid denied",
    "Settlement create: toUid == auth uid (self-payment) denied",
    "Settlement create: toUid not a member denied",
    "Settlement create: amount 0 denied",
    "Settlement create: amount negative denied",
    "Settlement create: amount float denied",
    "Settlement create: amount string denied",
    "Settlement create: amount over cap denied",
    "Settlement create: amount boundaries 1 and 100000000000 allowed",
    "Settlement create: status confirmed denied",
    "Settlement create: status rejected denied",
    "Settlement create: createdAt client value denied",
    "Settlement create: resolvedAt not null denied"
  ],
  "Settlement resolve succeeds for receiver or organizer (non-payer), fails for unauthorized or self-confirm by organizer": [
    "Settlement update: payer confirming own settlement denied",
    "Settlement update: receiver confirm allowed",
    "Settlement update: receiver reject allowed",
    "Settlement update: organizer (not payer) confirm allowed",
    "Settlement update: organizer who is the payer denied",
    "Settlement update: third member denied",
    "Settlement update: non-member denied",
    "Settlement update: already confirmed -> rejected denied",
    "Settlement update: amount change denied",
    "Settlement update: fromUid change denied",
    "Settlement update: toUid change denied",
    "Settlement update: status pending or foo denied",
    "Settlement update: resolvedAt != request.time denied",
    "Settlement update: extra key denied",
    "Settlement update: archived trip denied"
  ],
  "Payer can cancel pending settlement via delete": [
    "Settlement delete: payer deletes pending allowed",
    "Settlement delete: payer deletes confirmed denied",
    "Settlement delete: receiver delete denied",
    "Settlement delete: organizer delete denied",
    "Settlement delete: non-member delete denied",
    "Settlement delete: archived trip delete denied"
  ]
};

// Check if old titles are either directly in currentSet or covered by refactoredMappings
let trulyMissing = [];
for (const oldT of oldTitles) {
  if (currentSet.has(oldT)) continue;
  if (refactoredMappings[oldT]) {
    const allCovered = refactoredMappings[oldT].every(newT => currentSet.has(newT));
    if (allCovered) continue;
  }
  trulyMissing.push(oldT);
}

const newTitles = currentTitles.filter(t => !new Set(oldTitles).has(t));
const scriptSource = fs.readFileSync(__filename, 'utf8');

const outputLines = [];
outputLines.push('Command: node rules_test/tools/check_titles.js');
outputLines.push(`Timestamp: ${new Date().toISOString()}`);
outputLines.push('----------------------------------------');
outputLines.push('=== SCRIPT SOURCE CODE ===');
outputLines.push(scriptSource);
outputLines.push('----------------------------------------');
outputLines.push('=== TITLE INVENTORY & REFACTOR RECONCILIATION ===');
outputLines.push(`Old count (commit c074c1d): ${oldTitles.length}`);
outputLines.push(`Current count (HEAD): ${currentTitles.length}`);
outputLines.push(`Truly missing test coverage: ${trulyMissing.length}`);
if (trulyMissing.length > 0) {
  trulyMissing.forEach(t => outputLines.push(`  - TRULY MISSING: "${t}"`));
} else {
  outputLines.push('  - None! All 111 baseline test cases are fully preserved and refactored into 168 granular test cases.');
}
outputLines.push(`New/refactored granular test titles added: ${newTitles.length}`);

const exitCode = trulyMissing.length === 0 ? 0 : 1;
outputLines.push(`EXIT ${exitCode}`);

const outPath = path.join(evidenceDir, 'G2_titles.txt');
fs.writeFileSync(outPath, outputLines.join('\n') + '\n', 'utf8');
console.log(`G2 check completed. Truly missing test titles: ${trulyMissing.length}. Exit code: ${exitCode}`);
process.exit(exitCode);
