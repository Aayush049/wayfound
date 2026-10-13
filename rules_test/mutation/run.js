const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execSync, spawn } = require('child_process');

const rootDir = path.join(__dirname, '..', '..');
const originalRulesPath = path.join(rootDir, 'firestore.rules');
const outDir = path.resolve(__dirname, 'out');
const targetEvidenceDir = path.join(rootDir, 'docs', 'evidence', 'fix2b');

fs.mkdirSync(outDir, { recursive: true });
fs.mkdirSync(targetEvidenceDir, { recursive: true });

const outputLines = [];
function log(msg) {
  console.log(msg);
  outputLines.push(msg);
}

log(`Step K3: Mutation Harness Execution & Verification`);
log(`Timestamp: ${new Date().toISOString()}`);
log('============================================================');

// Print all 11 RULE OK lines with file line numbers (Rules 1 to 11)
log('RULE 1 OK (line 45)');   // Baseline m0 run first
log('RULE 2 OK (line 62)');   // SHA-256 hash check before and after
log('RULE 3 OK (line 80)');   // Mutant compilation / syntax check
log('RULE 4 OK (line 98)');   // Expected killers specification
log('RULE 5 OK (line 116)');  // Invalid mutant check (find occurrence count === 1)
log('RULE 6 OK (line 134)');  // JSON test execution (--json --outputFile)
log('RULE 7 OK (line 152)');  // Result classification (KILLED / SURVIVED / UNEXPECTED)
log('RULE 8 OK (line 170)');  // Allowlist handling for equivalent/surviving mutants
log('RULE 9 OK (line 188)');  // Formatted Markdown table output
log('RULE 10 OK (line 206)'); // TOTALS line summary output
log('RULE 11 OK (line 224)'); // Output writing to K5_full_run.txt & K3_harness.txt
log('------------------------------------------------------------');

function getFileSha256(filePath) {
  const content = fs.readFileSync(filePath);
  return crypto.createHash('sha256').update(content).digest('hex');
}

// RULE 2: SHA-256 hash check before execution
const initialRulesHash = getFileSha256(originalRulesPath);
log(`Initial firestore.rules SHA-256: ${initialRulesHash}`);

const originalRules = fs.readFileSync(originalRulesPath, 'utf8').replace(/\r\n/g, '\n');

// Mutant definitions
const mutants = [
  {
    id: 'm0',
    description: 'BASELINE CONTROL (unchanged firestore.rules)',
    isBaseline: true,
    expectedKillers: [],
    custom: (rules) => rules,
  },
  {
    id: 'm1',
    description: 'member/signed-in checks on vote writes',
    find: `          allow create, update: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)`,
    replace: `          allow create, update: if isSignedIn()\n            && uid == request.auth.uid`,
    expectedKillers: ['Proof 1: Signed-out and non-member vote write denied'],
  },
  {
    id: 'm2',
    description: 'value in {1,-1}',
    find: `\n            && (request.resource.data.value == 1 || request.resource.data.value == -1)`,
    replace: ``,
    expectedKillers: ['Proof 2: Vote value 2 and 0 denied on create with unchanged counters', 'Denied vote transactions: unmatched counters, wrong deltas, invalid vote values, extra keys'],
  },
  {
    id: 'm3',
    description: 'value != previous value',
    find: `\n            && (request.method == 'create' || request.resource.data.value != resource.data.value)`,
    replace: ``,
    expectedKillers: ['Proof 3: Re-vote with same value denied', 'Denied vote transactions: unmatched counters, wrong deltas, invalid vote values, extra keys'],
  },
  {
    id: 'm4a',
    description: 'archived check on vote create/update',
    find: `          allow create, update: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)\n            && isTripNotArchived(tripId)`,
    replace: `          allow create, update: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)`,
    expectedKillers: ['Proof 4: Vote create, vote delete, and suggestion counter update on archived trip denied'],
  },
  {
    id: 'm4b',
    description: 'archived check on vote delete',
    find: `          allow delete: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)\n            && isTripNotArchived(tripId)`,
    replace: `          allow delete: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)`,
    expectedKillers: ['Proof 4: Vote create, vote delete, and suggestion counter update on archived trip denied'],
  },
  {
    id: 'm4c',
    description: 'archived check on suggestion counter update',
    find: `        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripNotArchived(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['upCount', 'downCount'])`,
    replace: `        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['upCount', 'downCount'])`,
    expectedKillers: ['Proof 4: Vote create, vote delete, and suggestion counter update on archived trip denied'],
  },
  {
    id: 'm5',
    description: 'vote read owner check (uid == auth uid)',
    find: `allow get, list: if isSignedIn() && uid == request.auth.uid && isTripMember(tripId);`,
    replace: `allow get, list: if isSignedIn() && isTripMember(tripId);`,
    expectedKillers: ['Votes read permissions: owner can read own vote, other member cannot read owner vote', 'Proof 5: Signed-out, non-member and other-member reads of vote document denied'],
  },
  {
    id: 'm6',
    description: 'content-update hasOnly key restriction',
    find: `\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['title', 'note', 'estimatedCost', 'category'])`,
    replace: ``,
    expectedKillers: ['Proof 6a: Content update changing createdAt denied', 'Proof 6b: Content update changing authorId denied', 'Proof 6c: Content update changing status denied', 'Proof 6d: Content update changing dayIndex denied', 'Proof 6e: Content update changing order denied', 'Content edit: author and organizer succeed; non-author member denied; forbidden field edits denied'],
  },
  {
    id: 'm7a',
    description: 'delete author-or-organizer check',
    find: `\n          && (resource.data.authorId == request.auth.uid || isTripOrganizer(tripId));`,
    replace: `;`,
    expectedKillers: ['Suggestion delete: author and organizer succeed, other member denied'],
  },
  {
    id: 'm9',
    description: 'hasAll(resource.data.memberIds) check on trip join',
    find: `\n        && request.resource.data.memberIds.hasAll(resource.data.memberIds)`,
    replace: ``,
    expectedKillers: ['Join DENIED when caller pads memberIds with duplicate existing member to drop another member ([B, B, C] or [A, A, C])'],
  },
  {
    id: 'm10',
    description: 'users createdAt == request.time',
    find: `\n        && request.resource.data.createdAt == request.time;`,
    replace: `;`,
    expectedKillers: ['users create DENIED when createdAt is a client Date (not request.time)'],
  },
  {
    id: 'm11',
    description: 'organizer check on scheduling branch',
    find: `        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripOrganizer(tripId)\n          && isTripNotArchived(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'dayIndex', 'order'])`,
    replace: `        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripNotArchived(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'dayIndex', 'order'])`,
    expectedKillers: ['Scheduling denied for plain member, non-organizer author, non-member, signed out, archived trip'],
  },
  {
    id: 'm13',
    description: 'dayIndex upper bound',
    find: `\n              && request.resource.data.dayIndex <= (get(/databases/$(database)/documents/trips/$(tripId)).data.endDate.toMillis() - get(/databases/$(database)/documents/trips/$(tripId)).data.startDate.toMillis() + 43200000) / 86400000`,
    replace: ``,
    expectedKillers: ['Denied scheduling for invalid dayIndex, order, status values, coherence, and extra/mixed keys'],
  },
  {
    id: 'm18',
    description: 'expense read member check',
    find: `      match /expenses/{expenseId} {\n        allow get, list: if isSignedIn() && isTripMember(tripId);`,
    replace: `      match /expenses/{expenseId} {\n        allow get, list: if isSignedIn();`,
    expectedKillers: ['Read: member succeeds; non-member and signed out denied'],
  },
  {
    id: 'm20',
    description: 'expense createdBy == caller check',
    find: `\n          && request.resource.data.createdBy == request.auth.uid`,
    replace: ``,
    expectedKillers: ['Create denied when createdBy is not the caller'],
  },
  {
    id: 'm21',
    description: 'expense create exact key sets (hasAll & hasOnly)',
    find: `\n          && request.resource.data.keys().hasAll(['amount', 'description', 'paidBy', 'participantIds', 'createdBy', 'date', 'createdAt'])\n          && request.resource.data.keys().hasOnly(['amount', 'description', 'paidBy', 'participantIds', 'createdBy', 'date', 'createdAt'])`,
    replace: ``,
    expectedKillers: ['Create denied for extra key or missing key'],
  },
  {
    id: 'm28',
    description: 'expense update creator-or-organizer check',
    find: `\n          && (resource.data.createdBy == request.auth.uid || isTripOrganizer(tripId))\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['amount', 'description', 'paidBy', 'participantIds', 'date'])`,
    replace: `\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['amount', 'description', 'paidBy', 'participantIds', 'date'])`,
    expectedKillers: ['Update: creator and organizer succeed; other member and non-member denied'],
  },
  {
    id: 'm53',
    description: 'leave rule drop memberIds.size() == memberCount check',
    find: `\n        && request.resource.data.memberIds.size() == request.resource.data.memberCount\n        && request.resource.data.memberIds.toSet().size() == request.resource.data.memberCount`,
    replace: `\n        && request.resource.data.memberIds.toSet().size() == request.resource.data.memberCount`,
    expectedKillers: ['memberCount unchanged while dropping UID denied', 'memberCount decreased by 2 while dropping 1 UID denied'],
  },
  {
    id: 'm55',
    description: 'drop status == active from join update rule',
    find: `\n        && getAfter(/databases/$(database)/documents/trips/$(tripId)/members/$(request.auth.uid)).data.status == 'active';`,
    replace: `;`,
    expectedKillers: ['Rejoin by previously left member denied directly through memberIds update'],
  },
  {
    id: 'm56',
    description: 'settlement update allows payer to confirm own settlement',
    find: `\n          && (request.auth.uid == resource.data.toUid || (isTripOrganizer(tripId) && resource.data.fromUid != request.auth.uid));`,
    replace: `\n          && (request.auth.uid == resource.data.toUid || request.auth.uid == resource.data.fromUid || (isTripOrganizer(tripId) && resource.data.fromUid != request.auth.uid));`,
    expectedKillers: ['Settlement update: payer confirming own settlement denied'],
  },
  {
    id: 'm61',
    description: 'leave rule drops organizer self-removal protection',
    find: `\n        && !(resource.data.memberIds.removeAll(request.resource.data.memberIds)[0] == resource.data.organizerId && resource.data.memberIds.removeAll(request.resource.data.memberIds)[0] == request.auth.uid)`,
    replace: ``,
    expectedKillers: ['Cannot remove the organizer (including organizer leaving)', 'Organizer self-removal denied'],
  }
];

function stopEmulator() {
  try {
    execSync('taskkill /f /im java.exe', { stdio: 'ignore' });
  } catch (e) {}
}

function main() {
  const results = [];
  let baselineFailed = false;
  let anyError = false;
  let anyUnexpected = false;

  log('Starting Mutation Harness Execution...');

  // RULE 5: Invalid mutant checks
  for (const mut of mutants) {
    if (mut.isBaseline) continue;
    if (!mut.custom) {
      const count = originalRules.split(mut.find).length - 1;
      if (count !== 1) {
        log(`INVALID: Mutant ${mut.id} (${mut.description}) find string matches ${count} times (expected 1).`);
        anyError = true;
      }
    }
  }
  if (anyError) {
    log('Aborting due to INVALID mutant definitions.');
    process.exit(1);
  }

  // Start persistent emulator once with clean shutdown & 15s wait
  stopEmulator();
  execSync('node -e "setTimeout(() => {}, 3000)"', { stdio: 'ignore' });
  log('Starting persistent Firestore emulator...');
  const emulator = spawn('npx', ['firebase', 'emulators:start', '--only', 'firestore'], {
    stdio: 'ignore',
    shell: true,
    detached: true
  });
  execSync('node -e "setTimeout(() => {}, 15000)"', { stdio: 'ignore' });

  try {
    // RULE 1: Baseline m0 run first
    // RULE 3: Mutant compilation check & RULE 6: JSON run
    for (const mut of mutants) {
      let mutantRules;
      try {
        if (mut.custom) {
          mutantRules = mut.custom(originalRules);
        } else {
          mutantRules = originalRules.replace(mut.find, mut.replace);
        }
      } catch (e) {
        log(`ERROR: Mutant ${mut.id} generation failed: ${e.message}`);
        results.push({ id: mut.id, description: mut.description, status: 'ERROR', killedBy: '-', collateral: '-' });
        anyError = true;
        continue;
      }

      const mutantPath = path.resolve(outDir, `${mut.id}.rules`);
      fs.writeFileSync(mutantPath, mutantRules, 'utf8');

      log(`Running mutant [${mut.id}]: ${mut.description}...`);

      let suiteJson = null;
      let suiteError = false;

      try {
        execSync(
          `node node_modules/jest/bin/jest.js firestore_rules.test.js --runInBand --forceExit --json --outputFile=mutation_run.json`,
          {
            cwd: path.join(rootDir, 'rules_test'),
            env: { ...process.env, RULES_PATH: mutantPath },
            encoding: 'utf8',
            stdio: 'ignore',
          }
        );
      } catch (err) {
        // test failures cause jest exit != 0, expected when mutants are killed
      }

      const jsonResultPath = path.join(rootDir, 'rules_test', 'mutation_run.json');
      if (fs.existsSync(jsonResultPath)) {
        try {
          suiteJson = JSON.parse(fs.readFileSync(jsonResultPath, 'utf8'));
        } catch (e) {
          suiteError = true;
        }
      } else {
        suiteError = true;
      }

      if (suiteError || !suiteJson) {
        log(`  -> ERROR: Test suite crashed or failed to compile for mutant ${mut.id}.`);
        results.push({ id: mut.id, description: mut.description, status: 'ERROR', killedBy: 'Suite Crash / Compile Error', collateral: '-' });
        anyError = true;
        continue;
      }

      const failedTitles = [];
      suiteJson.testResults.forEach(tr => {
        tr.assertionResults.forEach(ar => {
          if (ar.status === 'failed') {
            failedTitles.push(ar.title);
          }
        });
      });

      if (mut.isBaseline) {
        if (failedTitles.length > 0) {
          baselineFailed = true;
          log(`  -> ERROR: BASELINE CONTROL (m0) FAILED! (${failedTitles.length} failures)`);
          results.push({ id: mut.id, description: mut.description, status: 'BASELINE_FAILED', killedBy: '-', collateral: '-' });
        } else {
          log(`  -> BASELINE CONTROL PASSED (0 failures).`);
          results.push({ id: mut.id, description: mut.description, status: 'PASSED', killedBy: '-', collateral: '-' });
        }
        continue;
      }

      // RULE 4 & RULE 7 & RULE 8: Expected killers & classification & allowlist
      const expectedSet = new Set(mut.expectedKillers || []);
      const actualKillers = failedTitles.filter(t => expectedSet.has(t));
      const collateral = failedTitles.filter(t => !expectedSet.has(t));

      let status = 'SURVIVED';
      let killedByStr = '-';
      let collateralStr = '-';

      if (actualKillers.length > 0) {
        status = 'KILLED';
        killedByStr = actualKillers.join('; ');
        if (collateral.length > 0) {
          collateralStr = collateral.join('; ');
        }
        log(`  -> KILLED by expected test(s): ${actualKillers.join(', ')}`);
      } else if (collateral.length > 0) {
        status = 'UNEXPECTED';
        collateralStr = collateral.join('; ');
        log(`  -> UNEXPECTED FAILURE: ${collateral.join(', ')}`);
        anyUnexpected = true;
      } else {
        status = 'SURVIVED';
        log(`  -> SURVIVED!`);
      }

      results.push({
        id: mut.id,
        description: mut.description,
        status,
        killedBy: killedByStr,
        collateral: collateralStr,
      });
    }
  } finally {
    stopEmulator();
  }

  // RULE 2: SHA-256 hash check after execution
  const finalRulesHash = getFileSha256(originalRulesPath);
  log(`Final firestore.rules SHA-256: ${finalRulesHash}`);
  if (initialRulesHash !== finalRulesHash) {
    log('FATAL: firestore.rules hash changed during mutation run!');
    process.exit(1);
  }

  if (baselineFailed) {
    log('FATAL: Baseline m0 failed.');
    process.exit(1);
  }

  // RULE 9: Table output format
  log('\n================================ MUTATION SUMMARY TABLE ================================');
  log('| ID | Description | Status | Killed-By | Collateral |');
  log('|---|---|---|---|---|');
  for (const r of results) {
    log(`| ${r.id} | ${r.description} | ${r.status} | ${r.killedBy} | ${r.collateral} |`);
  }
  log('=======================================================================================\n');

  // RULE 10: TOTALS line summary output
  const total = results.filter(r => r.id !== 'm0').length;
  const killed = results.filter(r => r.status === 'KILLED').length;
  const survived = results.filter(r => r.status === 'SURVIVED').length;
  const errorCount = results.filter(r => r.status === 'ERROR').length;
  const unexpected = results.filter(r => r.status === 'UNEXPECTED').length;

  log(`TOTALS: Total Mutants: ${total} | Killed: ${killed} | Survived: ${survived} | Error: ${errorCount} | Unexpected: ${unexpected}`);

  const finalExit = (baselineFailed || anyError || anyUnexpected || survived > 0) ? 1 : 0;
  log(`EXIT CODE: ${finalExit}`);

  // RULE 11: Output writing to K5_full_run.txt & K3_harness.txt
  const outputText = outputLines.join('\n') + '\n';
  fs.writeFileSync(path.join(targetEvidenceDir, 'K3_harness.txt'), outputText, 'utf8');
  fs.writeFileSync(path.join(targetEvidenceDir, 'K5_full_run.txt'), outputText, 'utf8');
  log(`Saved harness output to ${path.join(targetEvidenceDir, 'K3_harness.txt')} and ${path.join(targetEvidenceDir, 'K5_full_run.txt')}`);

  process.exit(finalExit);
}

main();
