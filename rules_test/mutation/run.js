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
    name: 'm1',
    description: 'member/signed-in checks on vote writes',
    find: `          allow create, update: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)`,
    replace: `          allow create, update: if isSignedIn()\n            && uid == request.auth.uid`,
  },
  {
    name: 'm2',
    description: 'value in {1,-1}',
    find: `\n            && (request.resource.data.value == 1 || request.resource.data.value == -1)`,
    replace: ``,
  },
  {
    name: 'm3',
    description: 'value != previous value',
    find: `\n            && (request.method == 'create' || request.resource.data.value != resource.data.value)`,
    replace: ``,
  },
  {
    name: 'm4a',
    description: 'archived check on vote create/update',
    find: `          allow create, update: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)\n            && isTripNotArchived(tripId)`,
    replace: `          allow create, update: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)`,
  },
  {
    name: 'm4b',
    description: 'archived check on vote delete',
    find: `          allow delete: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)\n            && isTripNotArchived(tripId)`,
    replace: `          allow delete: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)`,
  },
  {
    name: 'm4c',
    description: 'archived check on suggestion counter update',
    find: `        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripNotArchived(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['upCount', 'downCount'])`,
    replace: `        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['upCount', 'downCount'])`,
  },
  {
    name: 'm4all',
    description: 'all three archived checks together',
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
    find: `allow get, list: if isSignedIn() && uid == request.auth.uid && isTripMember(tripId);`,
    replace: `allow get, list: if isSignedIn() && isTripMember(tripId);`,
  },
  {
    name: 'm5b',
    description: 'vote read member check',
    find: `allow get, list: if isSignedIn() && uid == request.auth.uid && isTripMember(tripId);`,
    replace: `allow get, list: if isSignedIn() && uid == request.auth.uid;`,
  },
  {
    name: 'm6',
    description: 'content-update hasOnly key restriction',
    find: `\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['title', 'note', 'estimatedCost', 'category'])`,
    replace: ``,
  },
  {
    name: 'm7a',
    description: 'delete author-or-organizer check',
    find: `\n          && (resource.data.authorId == request.auth.uid || isTripOrganizer(tripId));`,
    replace: `;`,
  },
  {
    name: 'm7b',
    description: 'delete member check',
    find: `        allow delete: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripNotArchived(tripId)\n          && (resource.data.authorId == request.auth.uid || isTripOrganizer(tripId));`,
    replace: `        allow delete: if isSignedIn()\n          && isTripNotArchived(tripId)\n          && (resource.data.authorId == request.auth.uid || isTripOrganizer(tripId));`,
  },
  {
    name: 'm8a',
    description: 'suggestion-side before != after and delta lines together',
    find: `\n          && getVoteBeforeVal(database, tripId, sid, request.auth.uid) != getVoteAfterVal(database, tripId, sid, request.auth.uid)\n          && request.resource.data.upCount == resource.data.upCount + getUpDelta(getVoteBeforeVal(database, tripId, sid, request.auth.uid), getVoteAfterVal(database, tripId, sid, request.auth.uid))\n          && request.resource.data.downCount == resource.data.downCount + getDownDelta(getVoteBeforeVal(database, tripId, sid, request.auth.uid), getVoteAfterVal(database, tripId, sid, request.auth.uid));`,
    replace: `;`,
  },
  {
    name: 'm8b',
    description: 'vote-side mirror delta lines together',
    find: `\n            && getAfter(/databases/$(database)/documents/trips/$(tripId)/suggestions/$(sid)).data.upCount == get(/databases/$(database)/documents/trips/$(tripId)/suggestions/$(sid)).data.upCount + getUpDelta(getVoteBeforeVal(database, tripId, sid, uid), request.resource.data.value)\n            && getAfter(/databases/$(database)/documents/trips/$(tripId)/suggestions/$(sid)).data.downCount == get(/databases/$(database)/documents/trips/$(tripId)/suggestions/$(sid)).data.downCount + getDownDelta(getVoteBeforeVal(database, tripId, sid, uid), request.resource.data.value);`,
    replace: `;`,
  },
  {
    name: 'm9',
    description: 'hasAll(resource.data.memberIds) check on trip join',
    find: `\n        && request.resource.data.memberIds.hasAll(resource.data.memberIds)`,
    replace: ``,
  },
  {
    name: 'm10',
    description: 'users createdAt == request.time',
    find: `\n        && request.resource.data.createdAt == request.time;`,
    replace: `;`,
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
      if (testName && !testName.includes('beforeAll hook')) {
        failed.add(testName);
      }
    } else if (trimmed.startsWith('✕ ') || trimmed.startsWith('× ')) {
      const testName = trimmed.replace(/^[✕×]\s+/, '').replace(/\s+\(\d+\s*ms\)$/, '').trim();
      if (testName && !testName.includes('beforeAll hook')) {
        failed.add(testName);
      }
    }
  }
  return Array.from(failed);
}

async function main() {
  const results = [];
  let anyUndetected = false;

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

    if (mutantRules === originalRules) {
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

    results.push({
      mutant: mut.name,
      removed: mut.description,
      failedTests: detected ? failedTests : ['NONE = UNDETECTED'],
      detected,
    });

    if (!detected) {
      console.log(`  -> UNDETECTED!`);
      anyUndetected = true;
    } else {
      console.log(`  -> Detected by ${failedTests.length} test(s): ${failedTests.join('; ')}`);
    }
  }

  console.log('\n================================ MUTATION RESULTS TABLE ================================');
  console.log('| Mutant | What was removed | Failed Tests (or NONE = UNDETECTED) |');
  console.log('|---|---|---|');
  for (const r of results) {
    console.log(`| ${r.mutant} | ${r.removed} | ${r.failedTests.join(', ')} |`);
  }
  console.log('=======================================================================================\n');

  if (anyUndetected) {
    console.log('WARNING: Some mutants were UNDETECTED.');
  } else {
    console.log('SUCCESS: All mutants detected by the security rules test suite!');
  }
}

main();
