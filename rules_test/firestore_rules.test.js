const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
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

describe('Users Collection Rules', () => {
  test('Signed-out user cannot read or write user documents', async () => {
    const unauthedDb = testEnv.unauthenticatedContext().firestore();
    const docRef = unauthedDb.collection('users').doc('user_123');

    await assertFails(docRef.get());
    await assertFails(docRef.set({ displayName: 'Alice' }));
  });

  test('Signed-in user can read any user document', async () => {
    const authedDb = testEnv.authenticatedContext('user_abc').firestore();
    const docRef = authedDb.collection('users').doc('other_user');

    await assertSucceeds(docRef.get());
  });

  test('Signed-in user can write their own user document', async () => {
    const authedDb = testEnv.authenticatedContext('user_123').firestore();
    const docRef = authedDb.collection('users').doc('user_123');

    await assertSucceeds(docRef.set({ displayName: 'Alice', email: 'alice@test.com' }));
  });

  test('Signed-in user cannot write another user document', async () => {
    const authedDb = testEnv.authenticatedContext('user_abc').firestore();
    const docRef = authedDb.collection('users').doc('other_user');

    await assertFails(docRef.set({ displayName: 'Bob' }));
  });

  test('Signed-in user cannot create user document with wrong uid', async () => {
    const authedDb = testEnv.authenticatedContext('user_abc').firestore();
    const docRef = authedDb.collection('users').doc('wrong_user');

    await assertFails(docRef.set({ uid: 'wrong_user', displayName: 'Fake' }));
  });
});

describe('Trips Collection Rules (baseline deny-all)', () => {
  test('Signed-in user cannot read trips collection', async () => {
    const authedDb = testEnv.authenticatedContext('user_123').firestore();
    const docRef = authedDb.collection('trips').doc('trip_1');

    await assertFails(docRef.get());
  });

  test('Signed-in user cannot write trips collection', async () => {
    const authedDb = testEnv.authenticatedContext('user_123').firestore();
    const docRef = authedDb.collection('trips').doc('trip_1');

    await assertFails(docRef.set({ name: 'Trip' }));
  });
});
