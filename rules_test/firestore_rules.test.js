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

describe('Users Collection Security Rules', () => {
  const userId = 'user_123';
  const userEmail = 'user123@example.com';

  test('Signed-out user cannot read or write user documents', async () => {
    const unauthedDb = testEnv.unauthenticatedContext().firestore();
    const docRef = unauthedDb.collection('users').doc(userId);

    await assertFails(docRef.get());
    await assertFails(
      docRef.set({
        displayName: 'Alice',
        email: userEmail,
        createdAt: new Date(),
      })
    );
  });

  test('Owner can create user document with valid fields', async () => {
    const authedDb = testEnv
      .authenticatedContext(userId, { email: userEmail })
      .firestore();
    const docRef = authedDb.collection('users').doc(userId);

    await assertSucceeds(
      docRef.set({
        displayName: 'Alice',
        email: userEmail,
        photoUrl: 'https://example.com/photo.jpg',
        createdAt: new Date(),
      })
    );
  });

  test('Owner cannot create user document with extra keys', async () => {
    const authedDb = testEnv
      .authenticatedContext(userId, { email: userEmail })
      .firestore();
    const docRef = authedDb.collection('users').doc(userId);

    await assertFails(
      docRef.set({
        displayName: 'Alice',
        email: userEmail,
        photoUrl: null,
        createdAt: new Date(),
        isAdmin: true, // Extra forbidden key
      })
    );
  });

  test('Owner cannot create user document with missing required keys', async () => {
    const authedDb = testEnv
      .authenticatedContext(userId, { email: userEmail })
      .firestore();
    const docRef = authedDb.collection('users').doc(userId);

    await assertFails(
      docRef.set({
        displayName: 'Alice',
        // missing email and createdAt
      })
    );
  });

  test('Owner cannot create user document with wrong email', async () => {
    const authedDb = testEnv
      .authenticatedContext(userId, { email: userEmail })
      .firestore();
    const docRef = authedDb.collection('users').doc(userId);

    await assertFails(
      docRef.set({
        displayName: 'Alice',
        email: 'attacker@example.com', // wrong email
        photoUrl: null,
        createdAt: new Date(),
      })
    );
  });

  test('Owner cannot create user document with wrong uid in path', async () => {
    const authedDb = testEnv
      .authenticatedContext(userId, { email: userEmail })
      .firestore();
    const docRef = authedDb.collection('users').doc('other_user_id');

    await assertFails(
      docRef.set({
        displayName: 'Alice',
        email: userEmail,
        photoUrl: null,
        createdAt: new Date(),
      })
    );
  });

  test('Owner can get own user document', async () => {
    // Seed initial document as admin
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection('users')
        .doc(userId)
        .set({
          displayName: 'Alice',
          email: userEmail,
          photoUrl: null,
          createdAt: new Date(),
        });
    });

    const authedDb = testEnv
      .authenticatedContext(userId, { email: userEmail })
      .firestore();
    const docRef = authedDb.collection('users').doc(userId);

    await assertSucceeds(docRef.get());
  });

  test('Owner list and delete operations are denied', async () => {
    const authedDb = testEnv
      .authenticatedContext(userId, { email: userEmail })
      .firestore();

    await assertFails(authedDb.collection('users').get());
    await assertFails(authedDb.collection('users').doc(userId).delete());
  });

  test('Owner can update displayName and photoUrl', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection('users')
        .doc(userId)
        .set({
          displayName: 'Alice',
          email: userEmail,
          photoUrl: null,
          createdAt: new Date(),
        });
    });

    const authedDb = testEnv
      .authenticatedContext(userId, { email: userEmail })
      .firestore();
    const docRef = authedDb.collection('users').doc(userId);

    await assertSucceeds(
      docRef.update({
        displayName: 'Alice Updated',
        photoUrl: 'https://example.com/new_photo.jpg',
      })
    );
  });

  test('Owner update fails if attempting to change forbidden fields (e.g. email)', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection('users')
        .doc(userId)
        .set({
          displayName: 'Alice',
          email: userEmail,
          photoUrl: null,
          createdAt: new Date(),
        });
    });

    const authedDb = testEnv
      .authenticatedContext(userId, { email: userEmail })
      .firestore();
    const docRef = authedDb.collection('users').doc(userId);

    await assertFails(
      docRef.update({
        email: 'new_email@example.com',
      })
    );
  });

  test('Other user cannot read or update another user document', async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection('users')
        .doc(userId)
        .set({
          displayName: 'Alice',
          email: userEmail,
          photoUrl: null,
          createdAt: new Date(),
        });
    });

    const otherDb = testEnv
      .authenticatedContext('other_user', { email: 'other@example.com' })
      .firestore();
    const docRef = otherDb.collection('users').doc(userId);

    await assertFails(docRef.get());
    await assertFails(
      docRef.update({
        displayName: 'Hacked Name',
      })
    );
  });
});

describe('Trips Collection Baseline Rules', () => {
  test('Signed-in user cannot read or write trips collection', async () => {
    const authedDb = testEnv.authenticatedContext('user_123').firestore();
    const docRef = authedDb.collection('trips').doc('trip_1');

    await assertFails(docRef.get());
    await assertFails(docRef.set({ name: 'Trip' }));
  });
});
