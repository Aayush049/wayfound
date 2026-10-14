const fs = require('fs'), path = require('path'), cp = require('child_process'), crypto = require('crypto');
const root = path.join(__dirname, '..', '..');
const dir = path.join(root, 'docs', 'evidence', 'fix2b');
const out = [];
let missing = 0;
const log = (s) => { out.push(s); console.log(s); };
const rules = Array.from({ length: 11 }, (_, i) => new RegExp('RULE ' + (i + 1) + ' OK'));
const need = {
  'K0_lost_work.txt': [/^(FOUND|NOT FOUND):/m],
  'K1_structure.txt': [/TOP-LEVEL DESCRIBES:/, /MAX DEPTH: 1/, /REAL FILE: PASS/, /NESTED COPY: FAIL/, /TESTS: \d+ PASSED: \d+ FAILED: 0/],
  'K2_baseline.txt': [/ROOT CAUSE:/, /MODE: (persistent\+clear|fresh-per-mutant)/, /RUN 1: PASS/, /RUN 2: PASS/, /RUN 3: PASS/, /RUN 4: PASS/, /RUN 5: PASS/],
  'K3_harness.txt': rules,
  'K4_mutants.txt': [/^m\d+[a-z]? \| line \d+ \| reconstructed=(true|false) \| killers=/m],
  'K5_full_run.txt': [/BASELINE CONTROL PASSED/, /^TOTALS killed=\d+ survived_allowlisted=\d+ survived_not_allowlisted=0 invalid=0 error=0 unexpected=0 total=\d+/m, /HARNESS EXIT 0/],
  'K6_access.txt': [/RAW/, /DISTINCT/],
  'K6_settlement_clause.txt': [/SETTLEMENT UPDATE CLAUSE: (IDENTICAL|DIFFERS)/],
  'K7_final.txt': [/RULES DIFF EXIT 0/, /FC5F7525EBD47AD927DAC5A55132810A9589FD74CDC75E2AD87EFD4233440443/i],
  'V_verify.txt': [/EXIT 0\s*$/],
};
for (const [file, pats] of Object.entries(need)) {
  const p = path.join(dir, file);
  log('=== ' + file + ' ===');
  if (!fs.existsSync(p)) { log('MISSING FILE'); missing++; continue; }
  const txt = fs.readFileSync(p, 'utf8');
  const lines = txt.split(/\r?\n/);
  log('lines=' + lines.length + ' bytes=' + Buffer.byteLength(txt));
  const last = lines.filter((l) => l.trim()).slice(-1)[0] || '';
  log('last line: ' + last);
  if (!/^EXIT \d+/.test(last.trim()) && !/HARNESS EXIT/.test(last)) { log('MISSING: file does not end with an EXIT line'); missing++; }
  for (const re of pats) {
    const m = txt.split(/\r?\n/).find((l) => re.test(l));
    if (m) log('OK   ' + re + ' -> ' + m.slice(0, 300)); else { log('MISSING marker ' + re); missing++; }
  }
}
// mutant counts
const k4 = path.join(dir, 'K4_mutants.txt');
const k5 = path.join(dir, 'K5_full_run.txt');
const k4n = fs.existsSync(k4) ? (fs.readFileSync(k4, 'utf8').match(/^m\d+[a-z]? \| line /gm) || []).length : -1;
const tot = fs.existsSync(k5) ? (fs.readFileSync(k5, 'utf8').match(/^TOTALS .*total=(\d+)/m) || [])[1] : null;
const runjs = path.join(root, 'rules_test', 'mutation', 'run.js');
const defined = fs.existsSync(runjs) ? (fs.readFileSync(runjs, 'utf8').match(/id:\s*['"]m\d+[a-z]?['"]/g) || []).length : -1;
log('=== COUNTS ===');
log('K4 mutant lines=' + k4n + ' | K5 TOTALS total=' + tot + ' | id: entries in run.js=' + defined);
if (String(k4n) !== String(tot)) { log('MISSING: K4 count != K5 total'); missing++; }
log('=== K5 last 12 lines ===');
if (fs.existsSync(k5)) log(fs.readFileSync(k5, 'utf8').split(/\r?\n/).slice(-12).join('\n'));
log('=== REPO STATE ===');
const sh = (c) => { try { return cp.execSync(c, { cwd: root, encoding: 'utf8' }); } catch (e) { return 'ERR ' + e.message; } };
log(sh('git status -sb'));
log(sh('git log --oneline -12'));
log('firestore.rules sha256 = ' + crypto.createHash('sha256').update(fs.readFileSync(path.join(root, 'firestore.rules'))).digest('hex'));
log('=== RESULT ===');
log('MISSING COUNT = ' + missing);
fs.writeFileSync(path.join(dir, 'SUMMARY_MECHANICAL.txt'), out.join('\n') + '\n');
process.exit(missing ? 1 : 0);