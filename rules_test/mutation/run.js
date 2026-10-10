const fs = require('fs');
const path = require('path');
const net = require('net');
const { execSync } = require('child_process');

const rootDir = path.join(__dirname, '..', '..');
const originalRulesPath = path.join(rootDir, 'firestore.rules');
const outDir = path.resolve(__dirname, 'out');

if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}

// Normalize CRLF to LF for reliable substring matching
const originalRules = fs.readFileSync(originalRulesPath, 'utf8').replace(/\r\n/g, '\n');

const mutations = [
  {
    name: 'm0',
    description: 'BASELINE CONTROL (unchanged firestore.rules)',
    isBaseline: true,
    relevantTarget: 'Yes (0 failures expected)',
    custom: (rules) => rules,
  },
  {
    name: 'm1',
    description: 'member/signed-in checks on vote writes',
    relevantTarget: 'No (Overlaps with suggestion member check; proven by m1all)',
    find: `          allow create, update: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)`,
    replace: `          allow create, update: if isSignedIn()\n            && uid == request.auth.uid`,
  },
  {
    name: 'm1all',
    description: 'member checks on vote writes AND suggestion updates together',
    relevantTarget: 'Yes (Proof 1: Signed-out and non-member vote write denied)',
    custom: (rules) => {
      let r = rules;
      const t1 = `          allow create, update: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)`;
      const r1 = `          allow create, update: if isSignedIn()\n            && uid == request.auth.uid`;
      const t2 = `        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripNotArchived(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['upCount', 'downCount'])`;
      const r2 = `        allow update: if isSignedIn()\n          && isTripNotArchived(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['upCount', 'downCount'])`;

      if (r.split(t1).length - 1 !== 1) throw new Error('m1all t1 not found exactly once');
      if (r.split(t2).length - 1 !== 1) throw new Error('m1all t2 not found exactly once');

      return r.replace(t1, r1).replace(t2, r2);
    }
  },
  {
    name: 'm2',
    description: 'value in {1,-1}',
    relevantTarget: 'Yes (Proof 2 & Denied vote transactions)',
    find: `\n            && (request.resource.data.value == 1 || request.resource.data.value == -1)`,
    replace: ``,
  },
  {
    name: 'm3',
    description: 'value != previous value',
    relevantTarget: 'Yes (Proof 3 & Denied vote transactions)',
    find: `\n            && (request.method == 'create' || request.resource.data.value != resource.data.value)`,
    replace: ``,
  },
  {
    name: 'm4a',
    description: 'archived check on vote create/update',
    relevantTarget: 'No (Overlaps with suggestion archived check; proven by m4all)',
    find: `          allow create, update: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)\n            && isTripNotArchived(tripId)`,
    replace: `          allow create, update: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)`,
  },
  {
    name: 'm4b',
    description: 'archived check on vote delete',
    relevantTarget: 'No (Overlaps with suggestion archived check; proven by m4all)',
    find: `          allow delete: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)\n            && isTripNotArchived(tripId)`,
    replace: `          allow delete: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)`,
  },
  {
    name: 'm4c',
    description: 'archived check on suggestion counter update',
    relevantTarget: 'No (Overlaps with vote archived check; proven by m4all)',
    find: `        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripNotArchived(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['upCount', 'downCount'])`,
    replace: `        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['upCount', 'downCount'])`,
  },
  {
    name: 'm4all',
    description: 'all three archived checks together',
    relevantTarget: 'Yes (Proof 4: Vote create, vote delete, and suggestion counter update on archived trip denied)',
    custom: (rules) => {
      let r = rules;
      const t1 = `          allow create, update: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)\n            && isTripNotArchived(tripId)`;
      const r1 = `          allow create, update: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)`;
      const t2 = `          allow delete: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)\n            && isTripNotArchived(tripId)`;
      const r2 = `          allow delete: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)`;
      const t3 = `        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripNotArchived(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['upCount', 'downCount'])`;
      const r3 = `        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['upCount', 'downCount'])`;

      if (r.split(t1).length - 1 !== 1) throw new Error('m4all t1 not found exactly once');
      if (r.split(t2).length - 1 !== 1) throw new Error('m4all t2 not found exactly once');
      if (r.split(t3).length - 1 !== 1) throw new Error('m4all t3 not found exactly once');

      return r.replace(t1, r1).replace(t2, r2).replace(t3, r3);
    }
  },
  {
    name: 'm5',
    description: 'vote read owner check (uid == auth uid)',
    relevantTarget: 'Yes (Votes read permissions & Proof 5)',
    find: `allow get, list: if isSignedIn() && uid == request.auth.uid && isTripMember(tripId);`,
    replace: `allow get, list: if isSignedIn() && isTripMember(tripId);`,
  },
  {
    name: 'm5b',
    description: 'vote read member check',
    relevantTarget: 'Yes (Proof 5: Signed-out, non-member and other-member reads of vote document denied)',
    find: `allow get, list: if isSignedIn() && uid == request.auth.uid && isTripMember(tripId);`,
    replace: `allow get, list: if isSignedIn() && uid == request.auth.uid;`,
  },
  {
    name: 'm6',
    description: 'content-update hasOnly key restriction',
    relevantTarget: 'Yes (Proof 6a-6e & Content edit)',
    find: `\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['title', 'note', 'estimatedCost', 'category'])`,
    replace: ``,
  },
  {
    name: 'm7a',
    description: 'delete author-or-organizer check',
    relevantTarget: 'Yes (Suggestion delete: author and organizer succeed, other member denied)',
    find: `\n          && (resource.data.authorId == request.auth.uid || isTripOrganizer(tripId));`,
    replace: `;`,
  },
  {
    name: 'm7b',
    description: 'delete member check',
    relevantTarget: 'Yes (Proof 7: Suggestion delete denied for non-member and signed-out user)',
    find: `        allow delete: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripNotArchived(tripId)\n          && (resource.data.authorId == request.auth.uid || isTripOrganizer(tripId));`,
    replace: `        allow delete: if isSignedIn()\n          && isTripNotArchived(tripId)\n          && (resource.data.authorId == request.auth.uid || isTripOrganizer(tripId));`,
  },
  {
    name: 'm8a',
    description: 'suggestion-side before != after and delta lines together',
    relevantTarget: 'Yes (Proof 8a: Plain suggestion counter update with NO vote change denied)',
    find: `\n          && getVoteBeforeVal(database, tripId, sid, request.auth.uid) != getVoteAfterVal(database, tripId, sid, request.auth.uid)\n          && request.resource.data.upCount == resource.data.upCount + getUpDelta(getVoteBeforeVal(database, tripId, sid, request.auth.uid), getVoteAfterVal(database, tripId, sid, request.auth.uid))\n          && request.resource.data.downCount == resource.data.downCount + getDownDelta(getVoteBeforeVal(database, tripId, sid, request.auth.uid), getVoteAfterVal(database, tripId, sid, request.auth.uid));`,
    replace: `;`,
  },
  {
    name: 'm8b',
    description: 'vote-side mirror delta lines together',
    relevantTarget: 'Yes (Proof 8b: Vote write with NO matching counter change denied)',
    find: `\n            && getAfter(/databases/$(database)/documents/trips/$(tripId)/suggestions/$(sid)).data.upCount == get(/databases/$(database)/documents/trips/$(tripId)/suggestions/$(sid)).data.upCount + getUpDelta(getVoteBeforeVal(database, tripId, sid, uid), request.resource.data.value)\n            && getAfter(/databases/$(database)/documents/trips/$(tripId)/suggestions/$(sid)).data.downCount == get(/databases/$(database)/documents/trips/$(tripId)/suggestions/$(sid)).data.downCount + getDownDelta(getVoteBeforeVal(database, tripId, sid, uid), request.resource.data.value);`,
    replace: `;`,
  },
  {
    name: 'm9',
    description: 'hasAll(resource.data.memberIds) check on trip join',
    relevantTarget: 'Yes (Join DENIED duplicate member padding)',
    find: `\n        && request.resource.data.memberIds.hasAll(resource.data.memberIds)`,
    replace: ``,
  },
  {
    name: 'm10',
    description: 'users createdAt == request.time',
    relevantTarget: 'Yes (users create DENIED when createdAt is a client Date)',
    find: `\n        && request.resource.data.createdAt == request.time;`,
    replace: `;`,
  },
  {
    name: 'm11',
    description: 'organizer check on scheduling branch',
    relevantTarget: 'Yes (Scheduling denied for plain member)',
    find: `        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripOrganizer(tripId)\n          && isTripNotArchived(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'dayIndex', 'order'])`,
    replace: `        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripNotArchived(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'dayIndex', 'order'])`,
  },
  {
    name: 'm12',
    description: 'archived check on scheduling',
    relevantTarget: 'Yes (Scheduling denied for archived trip)',
    find: `        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripOrganizer(tripId)\n          && isTripNotArchived(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'dayIndex', 'order'])`,
    replace: `        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripOrganizer(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'dayIndex', 'order'])`,
  },
  {
    name: 'm13',
    description: 'dayIndex upper bound',
    relevantTarget: 'Yes (Denied scheduling for dayIndex beyond last day)',
    find: `\n              && request.resource.data.dayIndex <= (get(/databases/$(database)/documents/trips/$(tripId)).data.endDate.toMillis() - get(/databases/$(database)/documents/trips/$(tripId)).data.startDate.toMillis()) / 86400000`,
    replace: ``,
  },
  {
    name: 'm14',
    description: 'status/dayIndex/order coherence',
    relevantTarget: 'Yes (Denied scheduling for status pending with dayIndex or order)',
    find: `\n          && (\n            (request.resource.data.status == 'pending' && request.resource.data.dayIndex == null && request.resource.data.order == null)\n            ||\n            (\n              request.resource.data.status == 'scheduled'\n              && request.resource.data.dayIndex is int\n              && request.resource.data.dayIndex >= 0\n              && request.resource.data.dayIndex <= (get(/databases/$(database)/documents/trips/$(tripId)).data.endDate.toMillis() - get(/databases/$(database)/documents/trips/$(tripId)).data.startDate.toMillis()) / 86400000\n              && request.resource.data.order is int\n              && request.resource.data.order >= 0\n              && request.resource.data.order <= 10000\n            )\n          );`,
    replace: `;`,
  },
  {
    name: 'm15',
    description: 'hasOnly key restriction on scheduling',
    relevantTarget: 'Yes (Denied scheduling for extra/mixed keys)',
    find: `\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'dayIndex', 'order'])`,
    replace: ``,
  },
  {
    name: 'm16',
    description: 'integer type checks',
    relevantTarget: 'Yes (Denied scheduling for dayIndex float or order float)',
    find: `\n              && request.resource.data.dayIndex is int\n              && request.resource.data.dayIndex >= 0\n              && request.resource.data.dayIndex <= (get(/databases/$(database)/documents/trips/$(tripId)).data.endDate.toMillis() - get(/databases/$(database)/documents/trips/$(tripId)).data.startDate.toMillis()) / 86400000\n              && request.resource.data.order is int`,
    replace: `\n              && request.resource.data.dayIndex >= 0\n              && request.resource.data.dayIndex <= (get(/databases/$(database)/documents/trips/$(tripId)).data.endDate.toMillis() - get(/databases/$(database)/documents/trips/$(tripId)).data.startDate.toMillis()) / 86400000`,
  },
  {
    name: 'm17',
    description: 'day bound without tolerance (+43200000)',
    relevantTarget: 'Yes (Day bound tolerance tests would fail without tolerance)',
    custom: (rules) => {
      // Restore the old expression without tolerance for the dayIndex upper bound
      // The new expression is: (end - start + 43200000) / 86400000
      // The old expression is: (end - start) / 86400000
      const newExpr = `(get(/databases/$(database)/documents/trips/$(tripId)).data.endDate.toMillis() - get(/databases/$(database)/documents/trips/$(tripId)).data.startDate.toMillis() + 43200000) / 86400000`;
      const oldExpr = `(get(/databases/$(database)/documents/trips/$(tripId)).data.endDate.toMillis() - get(/databases/$(database)/documents/trips/$(tripId)).data.startDate.toMillis()) / 86400000`;

      if (rules.split(newExpr).length - 1 !== 1) {
        throw new Error('m17: new expression (with tolerance) not found exactly once');
      }
      return rules.replace(newExpr, oldExpr);
    },
  }
];

function freePort8092() {
  try {
    const out = execSync('netstat -ano | findstr 8092', { encoding: 'utf8' });
    const lines = out.split(/\r?\n/);
    for (const line of lines) {
      const parts = line.trim().split(/\s+/);
      const pid = parts[parts.length - 1];
      if (pid && /^\d+$/.test(pid) && pid !== '0') {
        try {
          execSync(`taskkill /F /PID ${pid}`, { stdio: 'ignore' });
        } catch (_) {}
      }
    }
  } catch (_) {}
}

function waitForPortFree(port, maxWaitMs = 10000) {
  return new Promise((resolve) => {
    const start = Date.now();
    const check = () => {
      const socket = new net.Socket();
      socket.setTimeout(300);
      socket.on('connect', () => {
        socket.destroy();
        if (Date.now() - start > maxWaitMs) {
          freePort8092();
          return resolve(false);
        }
        setTimeout(check, 500);
      });
      socket.on('error', () => {
        socket.destroy();
        resolve(true);
      });
      socket.on('timeout', () => {
        socket.destroy();
        resolve(true);
      });
      socket.connect(port, '127.0.0.1');
    };
    check();
  });
}

function parseFailedTests(output) {
  const cleanOutput = (output || '').replace(/\u001b\[[0-9;]*m/g, '');
  const failed = new Set();
  const lines = cleanOutput.split(/\r?\n/);
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed.startsWith('● ')) {
      const parts = trimmed.substring(2).split('›');
      const testName = parts[parts.length - 1].trim();
      if (testName && !testName.includes('beforeAll hook') && !testName.includes('afterAll hook')) {
        failed.add(testName);
      }
    } else if (trimmed.startsWith('✕ ') || trimmed.startsWith('× ')) {
      const testName = trimmed.replace(/^[✕×]\s+/, '').replace(/\s+\(\d+\s*ms\)$/, '').trim();
      if (testName && !testName.includes('beforeAll hook') && !testName.includes('afterAll hook')) {
        failed.add(testName);
      }
    }
  }
  return Array.from(failed);
}

async function main() {
  const results = [];
  let anyUnexpectedUndetected = false;
  let baselineFailed = false;

  console.log('Starting Security Rules Mutation Runner...\n');

  // Verification pass
  for (const mut of mutations) {
    if (!mut.custom) {
      const count = originalRules.split(mut.find).length - 1;
      if (count !== 1) {
        console.error(`ERROR: Mutation ${mut.name} target substring found ${count} times (expected exactly 1).`);
        process.exit(1);
      }
    }
  }

  for (const mut of mutations) {
    freePort8092();
    await waitForPortFree(8092);
    await new Promise((r) => setTimeout(r, 1000));

    let mutantRules;
    if (mut.custom) {
      mutantRules = mut.custom(originalRules);
    } else {
      mutantRules = originalRules.replace(mut.find, mut.replace);
    }

    if (!mut.isBaseline && mutantRules === originalRules) {
      console.error(`ERROR: Mutant ${mut.name} is identical to original rules!`);
      process.exit(1);
    }

    const mutantPath = path.resolve(outDir, `${mut.name}.rules`);
    fs.writeFileSync(mutantPath, mutantRules, 'utf8');

    console.log(`Running mutant [${mut.name}]: ${mut.description}...`);

    let output = '';
    try {
      output = execSync(
        `npx firebase-tools emulators:exec --config firebase.json --only firestore "npm --prefix rules_test test"`,
        {
          cwd: rootDir,
          env: { ...process.env, RULES_PATH: mutantPath },
          encoding: 'utf8',
        }
      );
    } catch (err) {
      const stdout = err.stdout ? err.stdout.toString() : '';
      const stderr = err.stderr ? err.stderr.toString() : '';
      output = stdout + '\n' + stderr;
    }

    freePort8092();

    const failedTests = parseFailedTests(output);
    const detected = failedTests.length > 0;

    if (mut.isBaseline) {
      if (detected) {
        baselineFailed = true;
        console.error(`  -> ERROR: BASELINE CONTROL (m0) FAILED! (${failedTests.length} failing tests: ${failedTests.join('; ')})`);
      } else {
        console.log(`  -> BASELINE CONTROL PASSED (0 failing tests).`);
      }
      results.push({
        mutant: mut.name,
        removed: mut.description,
        failedTests: ['0 failing tests (PASSED)'],
        relevant: mut.relevantTarget,
        detected: true,
      });
    } else {
      results.push({
        mutant: mut.name,
        removed: mut.description,
        failedTests: detected ? failedTests : ['NONE = UNDETECTED (Overlapped)'],
        relevant: mut.relevantTarget,
        detected,
      });

      if (!detected) {
        if (mut.relevantTarget.startsWith('No')) {
          console.log(`  -> UNDETECTED (Expected overlap: ${mut.relevantTarget})`);
        } else {
          console.log(`  -> UNDETECTED! (UNEXPECTED)`);
          anyUnexpectedUndetected = true;
        }
      } else {
        console.log(`  -> Detected by ${failedTests.length} test(s): ${failedTests.join('; ')}`);
      }
    }
  }

  console.log('\n================================ MUTATION RESULTS TABLE ================================');
  console.log('| Mutant | What was removed | Exact Failed Tests | Relevant? |');
  console.log('|---|---|---|---|');
  for (const r of results) {
    console.log(`| ${r.mutant} | ${r.removed} | ${r.failedTests.join(', ')} | ${r.relevant} |`);
  }
  console.log('=======================================================================================\n');

  if (baselineFailed) {
    console.error('FATAL: Baseline control m0 failed! Exiting non-zero.');
    process.exit(1);
  }

  if (anyUnexpectedUndetected) {
    console.error('WARNING: Unexpected undetected mutants found!');
    process.exit(1);
  } else {
    console.log('SUCCESS: All mutations verified! Baseline m0 passed with 0 failures, all individual/combined protections verified.');
  }
}

main();
