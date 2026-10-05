const {
  initializeTestEnvironment,
  assertFails,
} = require('@firebase/rules-unit-testing');
const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'wayfound-51b4d';
let testEnv;

beforeAll(async () => {
  const rulesPath = path.join(__dirname, '..', 'firestore.rules');
  const rules = fs.readFileSync(rulesPath, 'utf8');

  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules,
      host: '127.0.0.1',
      port: 8092,
    },
  });
});

afterAll(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

beforeEach(async () => {
  if (testEnv) {
    await testEnv.clearFirestore();
  }
});

describe('Baseline Deny-All Firestore Rules', () => {
  test('Signed-out user cannot read or write documents', async () => {
    const unauthedDb = testEnv.unauthenticatedContext().firestore();
    const docRef = unauthedDb.collection('test').doc('doc1');

    await assertFails(docRef.get());
    await assertFails(docRef.set({ name: 'test' }));
  });

  test('Signed-in user cannot read or write documents under deny-all', async () => {
    const authedDb = testEnv.authenticatedContext('user_123').firestore();
    const docRef = authedDb.collection('users').doc('user_123');

    await assertFails(docRef.get());
    await assertFails(docRef.set({ displayName: 'Alice' }));
  });
});
