'use strict';
// Mutation harness v3. Written by the project architect. DO NOT EDIT. Run: node rules_test/mutation/harness_v3.js
const fs = require('fs'), path = require('path'), cp = require('child_process'), crypto = require('crypto');
const ROOT = path.resolve(__dirname, '..', '..');
const RULES = path.join(ROOT, 'firestore.rules');
const OUTDIR = path.join(__dirname, 'out_v3');
const WORK = path.join(__dirname, 'out_v3');
const MAXFAIL = 40; // a genuine single-condition mutant never fails more than this many tests
const sha = (b) => crypto.createHash('sha256').update(b).digest('hex');

const REQUIRED = [];
['m1', 'm2', 'm3', 'm4a', 'm4b', 'm4c', 'm5', 'm5b', 'm6', 'm7a', 'm7b', 'm8a', 'm8b', 'm9', 'm10', 'm11', 'm12', 'm13', 'm14', 'm15', 'm16', 'm17', 'm18'].forEach((x) => REQUIRED.push(x));
for (let i = 20; i <= 61; i++) REQUIRED.push('m' + i);

function flat(j) {
  const out = [];
  for (const f of (j && j.testResults) || []) for (const a of f.assertionResults || []) out.push({ title: a.title, status: a.status, ancestors: a.ancestorTitles || [] });
  return out;
}
function classify(m, r, base) {
  if (!r || !r.j) return { status: 'ERROR', note: 'no jest json produced', failed: [] };
  const tests = flat(r.j);
  const failed = tests.filter((t) => t.status === 'failed').map((t) => t.title);
  if (tests.length < base.total) return { status: 'ERROR', note: 'only ' + tests.length + '/' + base.total + ' tests executed', failed };
  if (failed.length > MAXFAIL) return { status: 'ERROR', note: failed.length + ' failures (> ' + MAXFAIL + '): suite broken, not a kill', failed };
  const killers = failed.filter((t) => m.expectedKillers.includes(t));
  if (killers.length) return { status: 'KILLED', killers, failed };
  if (failed.length) return { status: 'UNEXPECTED', note: 'failed only in non-expected tests', failed };
  return { status: 'SURVIVED', failed };
}

if (process.argv.includes('--selftest')) {
  const mk = (n, bad) => ({ testResults: [{ assertionResults: Array.from({ length: n }, (_, i) => ({ title: 't' + i, status: bad.includes(i) ? 'failed' : 'passed', ancestorTitles: ['d'] })) }] });
  const base = { total: 100 }, m = { expectedKillers: ['t3'] };
  const eq = (a, b, n) => { if (a !== b) { console.log('SELFTEST FAIL ' + n + ': ' + a + ' != ' + b); process.exit(1); } };
  eq(classify(m, { j: mk(100, []) }, base).status, 'SURVIVED', 'survived');
  eq(classify(m, { j: mk(100, [3]) }, base).status, 'KILLED', 'killed');
  eq(classify(m, { j: mk(100, [7]) }, base).status, 'UNEXPECTED', 'unexpected');
  eq(classify(m, { j: mk(100, Array.from({ length: 60 }, (_, i) => i)) }, base).status, 'ERROR', 'broad failure is not a kill');
  eq(classify(m, { j: mk(50, [3]) }, base).status, 'ERROR', 'fewer tests');
  eq(classify(m, { j: null }, base).status, 'ERROR', 'null json');
  console.log('SELFTEST OK');
  process.exit(0);
}

fs.mkdirSync(OUTDIR, { recursive: true });
fs.mkdirSync(WORK, { recursive: true });
const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const logf = path.join(OUTDIR, 'RUN_' + stamp + '.txt');
const log = (s) => { console.log(s); fs.appendFileSync(logf, s + '\n'); };
let counter = 0;

let firestorePort = 8092;
try {
  const fb = JSON.parse(fs.readFileSync(path.join(ROOT, 'firebase.json'), 'utf8'));
  if (fb.emulators && fb.emulators.firestore && fb.emulators.firestore.port) {
    firestorePort = fb.emulators.firestore.port;
  }
} catch (e) {}

function getListeningPids(port) {
  try {
    const out = cp.spawnSync('cmd.exe', ['/c', 'netstat -ano -p tcp | findstr LISTENING | findstr :' + port], { encoding: 'utf8', timeout: 5000 });
    const pids = new Set();
    for (const line of (out.stdout || '').split('\n')) {
      const parts = line.trim().split(/\s+/);
      if (parts.length >= 5 && parts[1].endsWith(':' + port) && parts[3] === 'LISTENING') {
        const pid = parseInt(parts[4], 10);
        if (pid > 0) pids.add(pid);
      }
    }
    return Array.from(pids);
  } catch (e) {
    return [];
  }
}

function getProcessDetails(pid) {
  try {
    const psCmd = 'Get-CimInstance Win32_Process -Filter "ProcessId = ' + pid + '" | Select-Object Name, CommandLine, @{N=\'CreationDate\';E={$_.CreationDate.ToString(\'o\')}} | ConvertTo-Json -Compress';
    const out = cp.spawnSync('powershell', ['-NoProfile', '-Command', psCmd], { encoding: 'utf8', timeout: 10000 });
    if (out.status === 0 && out.stdout.trim()) {
      return JSON.parse(out.stdout.trim());
    }
  } catch (e) {}
  return null;
}

function waitPortFree(port, maxMs) {
  const start = Date.now();
  const script = 'const net=require("net"),s=net.createServer();s.once("error",()=>process.exit(1));s.once("listening",()=>{s.close(()=>process.exit(0))});s.listen(' + port + ',"127.0.0.1");';
  while (Date.now() - start < maxMs) {
    const res = cp.spawnSync(process.execPath, ['-e', script], { encoding: 'utf8', timeout: 5000 });
    if (res.status === 0) return true;
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1000);
  }
  return false;
}

function ensureInitialPortFree() {
  if (process.platform !== 'win32') return;
  const pids = getListeningPids(firestorePort);
  for (const pid of pids) {
    const info = getProcessDetails(pid);
    if (pid === 30872 && info && info.Name && info.Name.toLowerCase() === 'java.exe' && typeof info.CommandLine === 'string' && info.CommandLine.includes('cloud-firestore-emulator')) {
      log('[ORPHAN KILL DIAGNOSIS EXCEPTION] pid=' + pid + ' name=' + info.Name + ' created=' + info.CreationDate + ' cmd=' + info.CommandLine.slice(0, 120));
      cp.spawnSync('taskkill', ['/PID', String(pid), '/T', '/F']);
      if (!waitPortFree(firestorePort, 30000)) {
        finish(1, 'FATAL: port ' + firestorePort + ' still busy 30s after terminating diagnosis orphan PID ' + pid);
      }
    } else {
      finish(1, 'FATAL: port ' + firestorePort + ' is busy before first suite. Owning process: ' + JSON.stringify(info));
    }
  }
}

function runSuite(label, rulesPath) {
  const out = path.join(WORK, label + '_' + stamp + '_' + (++counter) + '.json').replace(/\\/g, '/');
  const cmd = 'firebase emulators:exec --only firestore "npm --prefix rules_test test -- --json --outputFile=' + out + '"';
  const suiteStartTimeMs = Date.now();
  const r = cp.spawnSync(cmd, { cwd: ROOT, shell: true, env: Object.assign({}, process.env, { RULES_PATH: rulesPath }), encoding: 'utf8', maxBuffer: 1 << 28, timeout: 900000 });

  if (process.platform === 'win32') {
    const pids = getListeningPids(firestorePort);
    for (const pid of pids) {
      const info = getProcessDetails(pid);
      if (!info) {
        finish(1, 'FATAL: unable to get details for PID ' + pid + ' listening on port ' + firestorePort + ' after ' + label);
      }
      const isJava = info.Name && info.Name.toLowerCase() === 'java.exe';
      const hasCmd = typeof info.CommandLine === 'string' && info.CommandLine.includes('cloud-firestore-emulator');
      const creationMs = new Date(info.CreationDate).getTime();
      const isNewer = creationMs >= suiteStartTimeMs - 2000;
      if (isJava && hasCmd && isNewer) {
        log('[ORPHAN KILL] suite=' + label + ' pid=' + pid + ' name=' + info.Name + ' created=' + info.CreationDate + ' cmd=' + info.CommandLine.slice(0, 120));
        cp.spawnSync('taskkill', ['/PID', String(pid), '/T', '/F']);
      } else {
        finish(1, 'FATAL: PID ' + pid + ' on port ' + firestorePort + ' failed kill criteria after ' + label + ': ' + JSON.stringify(info));
      }
    }
    if (!waitPortFree(firestorePort, 30000)) {
      finish(1, 'FATAL: port ' + firestorePort + ' still busy 30s after cleanup for ' + label);
    }
  }

  let j = null;
  try { j = JSON.parse(fs.readFileSync(out, 'utf8')); } catch (e) { j = null; }
  return { status: r.status, j };
}

function finish(code, extra) {
  if (extra) log(extra);
  log('RULES SHA256 AFTER  = ' + sha(fs.readFileSync(RULES)));
  log('HARNESS EXIT ' + code);
  process.exit(code);
}

const rulesBefore = fs.readFileSync(RULES);
const rulesText = rulesBefore.toString('utf8');
log('HARNESS FILE SHA256 (LF-normalised) = ' + sha(fs.readFileSync(__filename, 'utf8').replace(/\r\n/g, '\n')));
log('RULES SHA256 BEFORE = ' + sha(rulesBefore));
log('node ' + process.version + ' | started ' + new Date().toISOString());

const mpath = path.join(__dirname, 'mutants.json');
const epath = path.join(__dirname, 'equivalent.json');
if (!fs.existsSync(mpath)) finish(1, 'FATAL: rules_test/mutation/mutants.json missing');
const mutants = JSON.parse(fs.readFileSync(mpath, 'utf8'));
const equivalent = fs.existsSync(epath) ? JSON.parse(fs.readFileSync(epath, 'utf8')) : {};

// ---- static validation (no emulator) ----
const ids = mutants.map((m) => m.id);
const missingReq = REQUIRED.filter((x) => !ids.includes(x));
const dup = ids.filter((x, i) => ids.indexOf(x) !== i);
let bad = 0;
for (const m of mutants) {
  const why = [];
  if (!m.id || !m.description || typeof m.find !== 'string' || typeof m.replace !== 'string') why.push('missing id/description/find/replace');
  else {
    const n = rulesText.split(m.find).length - 1;
    if (n !== 1) why.push('find occurs ' + n + ' times (must be exactly 1)');
    if (m.find === m.replace) why.push('replace equals find');
  }
  if (!Array.isArray(m.expectedKillers) || m.expectedKillers.length === 0 || m.expectedKillers.some((k) => typeof k !== 'string' || k.length < 12 || k === 'expected')) why.push('expectedKillers must be real, exact test titles');
  if (typeof m.reconstructed !== 'boolean') why.push('reconstructed must be true/false');
  if (why.length) { bad++; m.invalid = why.join('; '); log('INVALID ' + m.id + ': ' + m.invalid); }
}
log('required ids = ' + REQUIRED.length + ' | defined = ' + mutants.length + ' | missing required = ' + (missingReq.length ? missingReq.join(',') : 'none') + ' | duplicates = ' + (dup.length ? dup.join(',') : 'none'));
if (missingReq.length || dup.length) finish(1, 'FATAL: mutant set incomplete or duplicated');

// ---- baseline twice ----
ensureInitialPortFree();
const copy = path.join(WORK, 'm0.rules');
fs.writeFileSync(copy, rulesBefore);
if (sha(fs.readFileSync(copy)) !== sha(rulesBefore)) finish(1, 'FATAL: m0 copy differs from original');
let base = null;
for (const label of ['m0a', 'm0b']) {
  const r = runSuite(label, copy);
  const tests = flat(r.j), failed = tests.filter((t) => t.status === 'failed');
  const passed = tests.filter((t) => t.status === 'passed').length;
  log('BASELINE ' + label + ': total=' + tests.length + ' passed=' + passed + ' failed=' + failed.length + ' exit=' + r.status);
  if (!r.j || tests.length < 100 || failed.length || passed !== tests.length) finish(1, 'FATAL: baseline ' + label + ' is not fully green. Failing: ' + failed.slice(0, 10).map((t) => t.title).join(' | '));
  base = { total: tests.length, titles: new Set(tests.map((t) => t.title)), depthOk: tests.every((t) => t.ancestors.length === 1) };
}
log('BASELINE CONTROL PASSED (twice): ' + base.total + ' tests, all describes top-level = ' + base.depthOk);
if (!base.depthOk) finish(1, 'FATAL: some tests are nested (ancestorTitles.length != 1)');

for (const m of mutants) if (!m.invalid) { const miss = m.expectedKillers.filter((k) => !base.titles.has(k)); if (miss.length) { m.invalid = 'expectedKillers not in suite: ' + miss.join(' | '); bad++; log('INVALID ' + m.id + ': ' + m.invalid); } }

// ---- canaries: prove the RULES_PATH override is really used and broken rules are not counted as kills ----
const allowAll = path.join(WORK, 'canary_allow_all.rules');
fs.writeFileSync(allowAll, "rules_version = '2';\nservice cloud.firestore { match /databases/{d}/documents { match /{document=**} { allow read, write: if true; } } }\n");
const c1 = runSuite('canary_allow_all', allowAll);
const c1f = flat(c1.j).filter((t) => t.status === 'failed').length;
log('CANARY allow-all rules: failed=' + c1f + ' (must be >= 20)');
if (c1f < 20) finish(1, 'FATAL: RULES_PATH override is not used by the test suite (allow-all rules did not break the denial tests)');
const syn = path.join(WORK, 'canary_syntax.rules');
fs.writeFileSync(syn, rulesText + '\nTHIS IS NOT VALID RULES (\n');
const c2 = runSuite('canary_syntax', syn);
const c2c = classify({ expectedKillers: ['x'] }, c2, base);
log('CANARY syntax-error rules: classified ' + c2c.status + ' (must be ERROR)');
if (c2c.status !== 'ERROR') finish(1, 'FATAL: a broken rules file was not classified ERROR');

// ---- mutants ----
const rows = [];
for (const m of mutants) {
  if (m.invalid) { rows.push({ m, status: 'INVALID', note: m.invalid }); continue; }
  const idx = rulesText.indexOf(m.find);
  const line = rulesText.slice(0, idx).split('\n').length;
  const mutated = rulesText.replace(m.find, () => m.replace);
  if (mutated === rulesText) { rows.push({ m, status: 'INVALID', note: 'mutation changed nothing', line }); continue; }
  const file = path.join(WORK, m.id + '.rules');
  fs.writeFileSync(file, mutated);
  let res = classify(m, runSuite(m.id, file), base);
  if (res.status === 'ERROR') { log('  retrying ' + m.id + ' once after ERROR: ' + res.note); res = classify(m, runSuite(m.id + '_retry', file), base); }
  if (res.status === 'SURVIVED' && typeof equivalent[m.id] === 'string' && equivalent[m.id].length >= 80) res.status = 'SURVIVED_ALLOWLISTED';
  rows.push(Object.assign({ m, line }, res));
  log('[' + m.id + '] line ' + line + ' | ' + res.status + ' | failed=' + (res.failed || []).length + ' | killers=' + (res.killers || []).join(' ; ') + (res.note ? ' | ' + res.note : ''));
}

log('');
log('| id | description | rules line | reconstructed | status | failed tests | killed by |');
for (const r of rows) log('| ' + r.m.id + ' | ' + r.m.description + ' | ' + (r.line || '-') + ' | ' + r.m.reconstructed + ' | ' + r.status + ' | ' + (r.failed || []).length + ' | ' + (r.killers || []).join(' ; ') + ' |');
const c = (s) => rows.filter((r) => r.status === s).length;
log('TOTALS killed=' + c('KILLED') + ' survived_allowlisted=' + c('SURVIVED_ALLOWLISTED') + ' survived_not_allowlisted=' + c('SURVIVED') + ' invalid=' + c('INVALID') + ' error=' + c('ERROR') + ' unexpected=' + c('UNEXPECTED') + ' total=' + rows.length + ' required=' + REQUIRED.length + ' reconstructed=' + rows.filter((r) => r.m.reconstructed).length);
const same = sha(fs.readFileSync(RULES)) === sha(rulesBefore);
const ok = same && !c('SURVIVED') && !c('INVALID') && !c('ERROR') && !c('UNEXPECTED');
finish(ok ? 0 : 1, same ? null : 'FATAL: firestore.rules changed during the run');
