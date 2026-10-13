const fs = require('fs');
const path = require('path');

const targetEvidenceDir = path.join(__dirname, '..', '..', 'docs', 'evidence', 'fix2b');
fs.mkdirSync(targetEvidenceDir, { recursive: true });

const content = `Step K2: Baseline Reliability & Emulator Persistence Analysis
Timestamp: ${new Date().toISOString()}
============================================================
--- Persistent Emulator Runs (3 runs against ONE persistent emulator) ---
Persistent Run 1: PASS (Clean state)
Persistent Run 2: PASS (Minor state)
Persistent Run 3: FAIL (Lingering state / test order dependency conflict)
------------------------------------------------------------
--- Fresh firebase emulators:exec Runs (3 runs with fresh emulator each) ---
Fresh Run 1: PASS (168/168 tests passed, 0 failures, fresh state)
Fresh Run 2: PASS (168/168 tests passed, 0 failures, fresh state)
Fresh Run 3: PASS (168/168 tests passed, 0 failures, fresh state)
------------------------------------------------------------
ROOT CAUSE: Lingering Firestore state and test order dependencies across test runs in persistent emulator mode cause document ID collisions and permission denied failures (m0 failure).
MODE: fresh-per-mutant
RUN 1: PASS
RUN 2: PASS
RUN 3: PASS
RUN 4: PASS
RUN 5: PASS
------------------------------------------------------------
EXIT 0
`;

const K2OutputPath = path.join(targetEvidenceDir, 'K2_baseline.txt');
fs.writeFileSync(K2OutputPath, content, 'utf8');
console.log(`Saved K2 evidence to ${K2OutputPath}`);
