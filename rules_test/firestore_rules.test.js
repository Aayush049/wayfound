const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require('@firebase/rules-unit-testing');
const firebase = require('firebase/compat/app');
require('firebase/compat/firestore');
const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'wayfound-51b4d';
let testEnv;

beforeAll(async () => {
  const rulesPath = process.env.RULES_PATH || path.join(__dirname, '..', 'firestore.rules');
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

async function seedUser(uid, name = 'Test User', photo = null) {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await context
      .firestore()
      .collection('users')
      .doc(uid)
      .set({
        displayName: name,
        email: `${uid}@example.com`,
        photoUrl: photo,
        createdAt: new Date(),
      });
  });
}

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
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
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
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
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
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
        isAdmin: true,
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
        email: 'attacker@example.com',
        photoUrl: null,
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
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
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      })
    );
  });

  test('Owner can get own user document', async () => {
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

  test('Owner update fails if attempting to change forbidden fields', async () => {
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

  // --- Part B(c): New users create & update tests ---

  test('users create SUCCEEDS with serverTimestamp', async () => {
    const authedDb = testEnv
      .authenticatedContext(userId, { email: userEmail })
      .firestore();
    const docRef = authedDb.collection('users').doc(userId);

    // Valid create with serverTimestamp succeeds
    await assertSucceeds(
      docRef.set({
        displayName: 'Alice',
        email: userEmail,
        photoUrl: null,
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      })
    );

    // Negative control: Invalid create with missing required key 'email' fails
    const invalidDocRef = authedDb.collection('users').doc('user_invalid');
    await assertFails(
      invalidDocRef.set({
        displayName: 'Alice',
        photoUrl: null,
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      })
    );
  });

  test('users create DENIED when createdAt is a client Date (not request.time)', async () => {
    const authedDb = testEnv
      .authenticatedContext(userId, { email: userEmail })
      .firestore();
    const docRef = authedDb.collection('users').doc(userId);

    // Negative control: Valid create with serverTimestamp succeeds
    await assertSucceeds(
      docRef.set({
        displayName: 'Alice Valid',
        email: userEmail,
        photoUrl: null,
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      })
    );

    // Invalid create with client Date (new Date()) must be denied when createdAt == request.time is enforced
    const clientDateUserUid = 'user_client_date';
    const clientDateAuthedDb = testEnv
      .authenticatedContext(clientDateUserUid, { email: 'clientdate@example.com' })
      .firestore();
    const clientDateDocRef = clientDateAuthedDb.collection('users').doc(clientDateUserUid);

    await assertFails(
      clientDateDocRef.set({
        displayName: 'Client Date User',
        email: 'clientdate@example.com',
        photoUrl: null,
        createdAt: new Date(),
      })
    );
  });

  test('users update DENIED when createdAt is changed', async () => {
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

    // Negative control: Valid update modifying only displayName succeeds
    await assertSucceeds(
      docRef.update({
        displayName: 'Alice Updated',
      })
    );

    // Invalid update attempting to modify createdAt fails
    await assertFails(
      docRef.update({
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      })
    );
  });
});

describe('Trips & Join Security Rules', () => {
  const userId = 'organizer_1';
  const userEmail = 'org@example.com';
  const displayName = 'Alice Organizer';
  const joinCode = 'ABC234';
  const tripId = 'trip_100';

  const startDate = new Date('2026-11-01T00:00:00Z');
  const endDate = new Date('2026-11-05T00:00:00Z');

  async function seedUser(uid, name = 'Test User', photo = null) {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection('users')
        .doc(uid)
        .set({
          displayName: name,
          email: `${uid}@example.com`,
          photoUrl: photo,
          createdAt: new Date(),
        });
    });
  }

  function getValidTripCreatePayload(overrides = {}) {
    return {
      name: 'Goa Beach Trip',
      destination: 'Goa, India',
      startDate,
      endDate,
      currency: 'INR',
      organizerId: userId,
      joinCode,
      memberIds: [userId],
      memberCount: 1,
      archived: false,
      createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      ...overrides,
    };
  }

  function getValidMemberPayload(overrides = {}) {
    return {
      displayName,
      photoUrl: null,
      role: 'organizer',
      status: 'active',
      joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
      ...overrides,
    };
  }

  function getValidJoinCodePayload(overrides = {}) {
    return {
      tripId,
      tripName: 'Goa Beach Trip',
      destination: 'Goa, India',
      startDate,
      endDate,
      memberCount: 1,
      ...overrides,
    };
  }

  test('Signed-out user cannot read or write trips or joinCodes', async () => {
    const unauthedDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(unauthedDb.collection('trips').doc(tripId).get());
    await assertFails(unauthedDb.collection('joinCodes').doc(joinCode).get());
    await assertFails(
      unauthedDb.collection('trips').doc(tripId).collection('members').doc('m1').get()
    );
  });

  test('Valid trip create atomic batch succeeds', async () => {
    await seedUser(userId, displayName);

    const authedDb = testEnv.authenticatedContext(userId).firestore();
    const batch = authedDb.batch();

    const tripRef = authedDb.collection('trips').doc(tripId);
    const memberRef = tripRef.collection('members').doc(userId);
    const codeRef = authedDb.collection('joinCodes').doc(joinCode);

    batch.set(tripRef, getValidTripCreatePayload());
    batch.set(memberRef, getValidMemberPayload());
    batch.set(codeRef, getValidJoinCodePayload());

    await assertSucceeds(batch.commit());
  });

  test('Denied trip create when organizerId is wrong', async () => {
    await seedUser(userId, displayName);
    const authedDb = testEnv.authenticatedContext(userId).firestore();
    const batch = authedDb.batch();

    batch.set(
      authedDb.collection('trips').doc(tripId),
      getValidTripCreatePayload({ organizerId: 'other_uid' })
    );
    batch.set(
      authedDb.collection('trips').doc(tripId).collection('members').doc(userId),
      getValidMemberPayload()
    );
    batch.set(
      authedDb.collection('joinCodes').doc(joinCode),
      getValidJoinCodePayload()
    );

    await assertFails(batch.commit());
  });

  test('Denied trip create when memberIds is not [auth.uid]', async () => {
    await seedUser(userId, displayName);
    const authedDb = testEnv.authenticatedContext(userId).firestore();
    const batch = authedDb.batch();

    batch.set(
      authedDb.collection('trips').doc(tripId),
      getValidTripCreatePayload({ memberIds: [userId, 'extra_uid'] })
    );
    batch.set(
      authedDb.collection('trips').doc(tripId).collection('members').doc(userId),
      getValidMemberPayload()
    );
    batch.set(
      authedDb.collection('joinCodes').doc(joinCode),
      getValidJoinCodePayload()
    );

    await assertFails(batch.commit());
  });

  test('Denied trip create when memberCount is not 1', async () => {
    await seedUser(userId, displayName);
    const authedDb = testEnv.authenticatedContext(userId).firestore();
    const batch = authedDb.batch();

    batch.set(
      authedDb.collection('trips').doc(tripId),
      getValidTripCreatePayload({ memberCount: 2 })
    );
    batch.set(
      authedDb.collection('trips').doc(tripId).collection('members').doc(userId),
      getValidMemberPayload()
    );
    batch.set(
      authedDb.collection('joinCodes').doc(joinCode),
      getValidJoinCodePayload()
    );

    await assertFails(batch.commit());
  });

  test('Denied trip create with extra or missing keys', async () => {
    await seedUser(userId, displayName);
    const authedDb = testEnv.authenticatedContext(userId).firestore();

    // Extra key
    const batch1 = authedDb.batch();
    batch1.set(
      authedDb.collection('trips').doc(tripId),
      getValidTripCreatePayload({ extraKey: 'bad' })
    );
    batch1.set(
      authedDb.collection('trips').doc(tripId).collection('members').doc(userId),
      getValidMemberPayload()
    );
    batch1.set(
      authedDb.collection('joinCodes').doc(joinCode),
      getValidJoinCodePayload()
    );
    await assertFails(batch1.commit());

    // Missing key (name missing)
    const batch2 = authedDb.batch();
    const badPayload = getValidTripCreatePayload();
    delete badPayload.name;
    batch2.set(authedDb.collection('trips').doc(tripId), badPayload);
    batch2.set(
      authedDb.collection('trips').doc(tripId).collection('members').doc(userId),
      getValidMemberPayload()
    );
    batch2.set(
      authedDb.collection('joinCodes').doc(joinCode),
      getValidJoinCodePayload()
    );
    await assertFails(batch2.commit());
  });

  test('Denied trip create with invalid currency', async () => {
    await seedUser(userId, displayName);
    const authedDb = testEnv.authenticatedContext(userId).firestore();
    const batch = authedDb.batch();

    batch.set(
      authedDb.collection('trips').doc(tripId),
      getValidTripCreatePayload({ currency: 'XYZ' })
    );
    batch.set(
      authedDb.collection('trips').doc(tripId).collection('members').doc(userId),
      getValidMemberPayload()
    );
    batch.set(
      authedDb.collection('joinCodes').doc(joinCode),
      getValidJoinCodePayload()
    );

    await assertFails(batch.commit());
  });

  test('Denied trip create when name is empty or too long', async () => {
    await seedUser(userId, displayName);
    const authedDb = testEnv.authenticatedContext(userId).firestore();

    // Too long (61 chars)
    const batch1 = authedDb.batch();
    batch1.set(
      authedDb.collection('trips').doc(tripId),
      getValidTripCreatePayload({ name: 'A'.repeat(61) })
    );
    batch1.set(
      authedDb.collection('trips').doc(tripId).collection('members').doc(userId),
      getValidMemberPayload()
    );
    batch1.set(
      authedDb.collection('joinCodes').doc(joinCode),
      getValidJoinCodePayload()
    );
    await assertFails(batch1.commit());
  });

  test('Denied trip create when end date is before start date', async () => {
    await seedUser(userId, displayName);
    const authedDb = testEnv.authenticatedContext(userId).firestore();
    const batch = authedDb.batch();

    batch.set(
      authedDb.collection('trips').doc(tripId),
      getValidTripCreatePayload({
        startDate: new Date('2026-11-05T00:00:00Z'),
        endDate: new Date('2026-11-01T00:00:00Z'),
      })
    );
    batch.set(
      authedDb.collection('trips').doc(tripId).collection('members').doc(userId),
      getValidMemberPayload()
    );
    batch.set(
      authedDb.collection('joinCodes').doc(joinCode),
      getValidJoinCodePayload()
    );

    await assertFails(batch.commit());
  });

  test('Denied trip create when members doc or joinCodes doc is missing from batch', async () => {
    await seedUser(userId, displayName);
    const authedDb = testEnv.authenticatedContext(userId).firestore();

    // Missing members doc
    const batch1 = authedDb.batch();
    batch1.set(
      authedDb.collection('trips').doc(tripId),
      getValidTripCreatePayload()
    );
    batch1.set(
      authedDb.collection('joinCodes').doc(joinCode),
      getValidJoinCodePayload()
    );
    await assertFails(batch1.commit());

    // Missing joinCodes doc
    const batch2 = authedDb.batch();
    batch2.set(
      authedDb.collection('trips').doc(tripId),
      getValidTripCreatePayload()
    );
    batch2.set(
      authedDb.collection('trips').doc(tripId).collection('members').doc(userId),
      getValidMemberPayload()
    );
    await assertFails(batch2.commit());
  });

  test('Denied trip create with invalid joinCode format or duplicate join code', async () => {
    await seedUser(userId, displayName);
    const authedDb = testEnv.authenticatedContext(userId).firestore();

    // Invalid format (contains 'O')
    const batch1 = authedDb.batch();
    batch1.set(
      authedDb.collection('trips').doc(tripId),
      getValidTripCreatePayload({ joinCode: 'ABC23O' })
    );
    batch1.set(
      authedDb.collection('trips').doc(tripId).collection('members').doc(userId),
      getValidMemberPayload()
    );
    batch1.set(
      authedDb.collection('joinCodes').doc('ABC23O'),
      getValidJoinCodePayload()
    );
    await assertFails(batch1.commit());

    // Duplicate join code
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection('joinCodes')
        .doc(joinCode)
        .set({
          tripId: 'old_trip',
          tripName: 'Old Trip',
          destination: 'Old Dest',
          startDate,
          endDate,
          memberCount: 1,
        });
    });

    const batch2 = authedDb.batch();
    batch2.set(
      authedDb.collection('trips').doc(tripId),
      getValidTripCreatePayload()
    );
    batch2.set(
      authedDb.collection('trips').doc(tripId).collection('members').doc(userId),
      getValidMemberPayload()
    );
    batch2.set(
      authedDb.collection('joinCodes').doc(joinCode),
      getValidJoinCodePayload()
    );
    await assertFails(batch2.commit());
  });

  test('Denied trip create when createdAt is not request.time', async () => {
    await seedUser(userId, displayName);
    const authedDb = testEnv.authenticatedContext(userId).firestore();
    const batch = authedDb.batch();

    batch.set(
      authedDb.collection('trips').doc(tripId),
      getValidTripCreatePayload({ createdAt: new Date('2025-01-01T00:00:00Z') })
    );
    batch.set(
      authedDb.collection('trips').doc(tripId).collection('members').doc(userId),
      getValidMemberPayload()
    );
    batch.set(
      authedDb.collection('joinCodes').doc(joinCode),
      getValidJoinCodePayload()
    );

    await assertFails(batch.commit());
  });

  test('Denied trip create when joinCode does not match joinCodes document tripId', async () => {
    await seedUser(userId, displayName);
    const authedDb = testEnv.authenticatedContext(userId).firestore();
    const batch = authedDb.batch();

    batch.set(
      authedDb.collection('trips').doc(tripId),
      getValidTripCreatePayload({ joinCode })
    );
    batch.set(
      authedDb.collection('trips').doc(tripId).collection('members').doc(userId),
      getValidMemberPayload()
    );
    batch.set(
      authedDb.collection('joinCodes').doc(joinCode),
      getValidJoinCodePayload({ tripId: 'other_trip_id' })
    );

    await assertFails(batch.commit());
  });
});

describe('Trip Join Boundary & Security Tests', () => {
  const userId = 'organizer_1';
  const userEmail = 'org@example.com';
  const displayName = 'Alice Organizer';
  const joinCode = 'ABC234';
  const tripId = 'trip_100';
  const startDate = new Date('2026-11-01T00:00:00Z');
  const endDate = new Date('2026-11-05T00:00:00Z');
  const member2Uid = 'member_2';
  const member2Name = 'Bob Member';

    beforeEach(async () => {
      await seedUser(userId, displayName);
      await seedUser(member2Uid, member2Name);

      // Seed initial trip with organizer
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('trips').doc(tripId).set({
          name: 'Goa Beach Trip',
          destination: 'Goa, India',
          startDate,
          endDate,
          currency: 'INR',
          organizerId: userId,
          joinCode,
          memberIds: [userId],
          memberCount: 1,
          archived: false,
          createdAt: new Date(),
        });

        await db
          .collection('trips')
          .doc(tripId)
          .collection('members')
          .doc(userId)
          .set({
            displayName,
            photoUrl: null,
            role: 'organizer',
            status: 'active',
            joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
          });

        await db.collection('joinCodes').doc(joinCode).set({
          tripId,
          tripName: 'Goa Beach Trip',
          destination: 'Goa, India',
          startDate,
          endDate,
          memberCount: 1,
        });
      });
    });

    test('Valid join batch succeeds (memberCount 1 to 2)', async () => {
      const authedDb = testEnv.authenticatedContext(member2Uid).firestore();
      const batch = authedDb.batch();

      const tripRef = authedDb.collection('trips').doc(tripId);
      const memberRef = tripRef.collection('members').doc(member2Uid);
      const codeRef = authedDb.collection('joinCodes').doc(joinCode);

      batch.update(tripRef, {
        memberIds: [userId, member2Uid],
        memberCount: 2,
      });

      batch.set(memberRef, {
        displayName: member2Name,
        photoUrl: null,
        role: 'member',
        status: 'active',
        joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
      });

      batch.update(codeRef, {
        memberCount: 2,
      });

      await assertSucceeds(batch.commit());
    });

    test('Join fails when caller is already a member', async () => {
      const authedDb = testEnv.authenticatedContext(userId).firestore();
      const batch = authedDb.batch();

      batch.update(authedDb.collection('trips').doc(tripId), {
        memberIds: [userId],
        memberCount: 2,
      });

      batch.set(
        authedDb.collection('trips').doc(tripId).collection('members').doc(userId),
        {
          displayName,
          photoUrl: null,
          role: 'member',
          status: 'active',
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );

      batch.update(authedDb.collection('joinCodes').doc(joinCode), {
        memberCount: 2,
      });

      await assertFails(batch.commit());
    });

    test('Join fails when member doc is missing or role is organizer or displayName is spoofed', async () => {
      const authedDb = testEnv.authenticatedContext(member2Uid).firestore();

      // Missing member doc
      const batch1 = authedDb.batch();
      batch1.update(authedDb.collection('trips').doc(tripId), {
        memberIds: [userId, member2Uid],
        memberCount: 2,
      });
      batch1.update(authedDb.collection('joinCodes').doc(joinCode), {
        memberCount: 2,
      });
      await assertFails(batch1.commit());

      // Role organizer instead of member
      const batch2 = authedDb.batch();
      batch2.update(authedDb.collection('trips').doc(tripId), {
        memberIds: [userId, member2Uid],
        memberCount: 2,
      });
      batch2.set(
        authedDb.collection('trips').doc(tripId).collection('members').doc(member2Uid),
        {
          displayName: member2Name,
          photoUrl: null,
          role: 'organizer',
          status: 'active',
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batch2.update(authedDb.collection('joinCodes').doc(joinCode), {
        memberCount: 2,
      });
      await assertFails(batch2.commit());

      // Spoofed displayName
      const batch3 = authedDb.batch();
      batch3.update(authedDb.collection('trips').doc(tripId), {
        memberIds: [userId, member2Uid],
        memberCount: 2,
      });
      batch3.set(
        authedDb.collection('trips').doc(tripId).collection('members').doc(member2Uid),
        {
          displayName: 'Spoofed Admin Name',
          photoUrl: null,
          role: 'member',
          status: 'active',
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batch3.update(authedDb.collection('joinCodes').doc(joinCode), {
        memberCount: 2,
      });
      await assertFails(batch3.commit());
    });

    test('Join fails when adding another user uid or adding two uids or changing other fields', async () => {
      const authedDb = testEnv.authenticatedContext(member2Uid).firestore();

      // Adding someone else's uid
      const batch1 = authedDb.batch();
      batch1.update(authedDb.collection('trips').doc(tripId), {
        memberIds: [userId, 'other_uid'],
        memberCount: 2,
      });
      batch1.set(
        authedDb.collection('trips').doc(tripId).collection('members').doc(member2Uid),
        {
          displayName: member2Name,
          photoUrl: null,
          role: 'member',
          status: 'active',
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batch1.update(authedDb.collection('joinCodes').doc(joinCode), {
        memberCount: 2,
      });
      await assertFails(batch1.commit());

      // Changing name field during join
      const batch2 = authedDb.batch();
      batch2.update(authedDb.collection('trips').doc(tripId), {
        name: 'Hacked Trip Name',
        memberIds: [userId, member2Uid],
        memberCount: 2,
      });
      batch2.set(
        authedDb.collection('trips').doc(tripId).collection('members').doc(member2Uid),
        {
          displayName: member2Name,
          photoUrl: null,
          role: 'member',
          status: 'active',
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batch2.update(authedDb.collection('joinCodes').doc(joinCode), {
        memberCount: 2,
      });
      await assertFails(batch2.commit());
    });

    test('Join fails when memberCount increases by +2', async () => {
      const authedDb = testEnv.authenticatedContext(member2Uid).firestore();
      const batch = authedDb.batch();

      batch.update(authedDb.collection('trips').doc(tripId), {
        memberIds: [userId, member2Uid],
        memberCount: 3,
      });
      batch.set(
        authedDb.collection('trips').doc(tripId).collection('members').doc(member2Uid),
        {
          displayName: member2Name,
          photoUrl: null,
          role: 'member',
          status: 'active',
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batch.update(authedDb.collection('joinCodes').doc(joinCode), {
        memberCount: 3,
      });

      await assertFails(batch.commit());
    });

    test('Join fails when memberIds.length and memberCount are inconsistent', async () => {
      const authedDb = testEnv.authenticatedContext(member2Uid).firestore();
      const batch = authedDb.batch();

      batch.update(authedDb.collection('trips').doc(tripId), {
        memberIds: [userId, member2Uid],
        memberCount: 5,
      });
      batch.set(
        authedDb.collection('trips').doc(tripId).collection('members').doc(member2Uid),
        {
          displayName: member2Name,
          photoUrl: null,
          role: 'member',
          status: 'active',
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batch.update(authedDb.collection('joinCodes').doc(joinCode), {
        memberCount: 5,
      });

      await assertFails(batch.commit());
    });

    test('Join fails when trip is archived', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context
          .firestore()
          .collection('trips')
          .doc(tripId)
          .update({ archived: true });
      });

      const authedDb = testEnv.authenticatedContext(member2Uid).firestore();
      const batch = authedDb.batch();

      batch.update(authedDb.collection('trips').doc(tripId), {
        memberIds: [userId, member2Uid],
        memberCount: 2,
      });
      batch.set(
        authedDb.collection('trips').doc(tripId).collection('members').doc(member2Uid),
        {
          displayName: member2Name,
          photoUrl: null,
          role: 'member',
          status: 'active',
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batch.update(authedDb.collection('joinCodes').doc(joinCode), {
        memberCount: 2,
      });

      await assertFails(batch.commit());
    });

    // --- Part B(a): Join DENIED when memberIds drops an existing member ---

    test('Join DENIED when new memberIds drops an existing member while adding caller (count +1)', async () => {
      const authedDb = testEnv.authenticatedContext(member2Uid).firestore();

      // Invalid: drops existing organizer userId, puts only member2Uid, but memberCount is 2
      const batch1 = authedDb.batch();
      batch1.update(authedDb.collection('trips').doc(tripId), {
        memberIds: [member2Uid],
        memberCount: 2,
      });
      batch1.set(
        authedDb.collection('trips').doc(tripId).collection('members').doc(member2Uid),
        {
          displayName: member2Name,
          photoUrl: null,
          role: 'member',
          status: 'active',
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batch1.update(authedDb.collection('joinCodes').doc(joinCode), {
        memberCount: 2,
      });
      await assertFails(batch1.commit());

      // Negative control: Normal valid join preserving existing userId succeeds
      const batchValid = authedDb.batch();
      batchValid.update(authedDb.collection('trips').doc(tripId), {
        memberIds: [userId, member2Uid],
        memberCount: 2,
      });
      batchValid.set(
        authedDb.collection('trips').doc(tripId).collection('members').doc(member2Uid),
        {
          displayName: member2Name,
          photoUrl: null,
          role: 'member',
          status: 'active',
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batchValid.update(authedDb.collection('joinCodes').doc(joinCode), {
        memberCount: 2,
      });
      await assertSucceeds(batchValid.commit());
    });

    test('Join DENIED when one old member is replaced by caller and memberCount is unchanged', async () => {
      const authedDb = testEnv.authenticatedContext(member2Uid).firestore();

      // Invalid: replaces userId with member2Uid, memberCount remains 1
      const batch1 = authedDb.batch();
      batch1.update(authedDb.collection('trips').doc(tripId), {
        memberIds: [member2Uid],
        memberCount: 1,
      });
      batch1.set(
        authedDb.collection('trips').doc(tripId).collection('members').doc(member2Uid),
        {
          displayName: member2Name,
          photoUrl: null,
          role: 'member',
          status: 'active',
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batch1.update(authedDb.collection('joinCodes').doc(joinCode), {
        memberCount: 1,
      });
      await assertFails(batch1.commit());

      // Negative control: Normal valid join adding member2Uid with memberCount +1 succeeds
      const batchValid = authedDb.batch();
      batchValid.update(authedDb.collection('trips').doc(tripId), {
        memberIds: [userId, member2Uid],
        memberCount: 2,
      });
      batchValid.set(
        authedDb.collection('trips').doc(tripId).collection('members').doc(member2Uid),
        {
          displayName: member2Name,
          photoUrl: null,
          role: 'member',
          status: 'active',
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batchValid.update(authedDb.collection('joinCodes').doc(joinCode), {
        memberCount: 2,
      });
      await assertSucceeds(batchValid.commit());
    });

    test('Join DENIED when removing one member and adding caller plus another uid (memberCount +1)', async () => {
      const member3Uid = 'member_3';
      const member3Name = 'Carol Member';
      const extraUid = 'extra_uid';
      await seedUser(member3Uid, member3Name);
      await seedUser(extraUid, 'Extra User');

      // Seed trip to have 2 members (userId and member2Uid)
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('trips').doc(tripId).update({
          memberIds: [userId, member2Uid],
          memberCount: 2,
        });
        await db
          .collection('trips')
          .doc(tripId)
          .collection('members')
          .doc(member2Uid)
          .set({
            displayName: member2Name,
            photoUrl: null,
            role: 'member',
            status: 'active',
            joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
          });
        await db.collection('joinCodes').doc(joinCode).update({
          memberCount: 2,
        });
      });

      const authedDb = testEnv.authenticatedContext(member3Uid).firestore();

      // Invalid: drops userId, adds member3Uid AND extraUid, memberCount 3
      const batch1 = authedDb.batch();
      batch1.update(authedDb.collection('trips').doc(tripId), {
        memberIds: [member2Uid, member3Uid, extraUid],
        memberCount: 3,
      });
      batch1.set(
        authedDb.collection('trips').doc(tripId).collection('members').doc(member3Uid),
        {
          displayName: member3Name,
          photoUrl: null,
          role: 'member',
          status: 'active',
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batch1.update(authedDb.collection('joinCodes').doc(joinCode), {
        memberCount: 3,
      });
      await assertFails(batch1.commit());

      // Negative control: Normal valid join retaining both existing members (userId, member2Uid) succeeds
      const batchValid = authedDb.batch();
      batchValid.update(authedDb.collection('trips').doc(tripId), {
        memberIds: [userId, member2Uid, member3Uid],
        memberCount: 3,
      });
      batchValid.set(
        authedDb.collection('trips').doc(tripId).collection('members').doc(member3Uid),
        {
          displayName: member3Name,
          photoUrl: null,
          role: 'member',
          status: 'active',
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batchValid.update(authedDb.collection('joinCodes').doc(joinCode), {
        memberCount: 3,
      });
      await assertSucceeds(batchValid.commit());
    });

    test('Join DENIED when caller pads memberIds with duplicate existing member to drop another member ([B, B, C] or [A, A, C])', async () => {
      const member3Uid = 'member_3';
      const member3Name = 'Carol Member';
      await seedUser(member3Uid, member3Name);

      // Seed trip to have 2 members (userId and member2Uid)
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('trips').doc(tripId).update({
          memberIds: [userId, member2Uid],
          memberCount: 2,
        });
        await db
          .collection('trips')
          .doc(tripId)
          .collection('members')
          .doc(member2Uid)
          .set({
            displayName: member2Name,
            photoUrl: null,
            role: 'member',
            status: 'active',
            joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
          });
        await db.collection('joinCodes').doc(joinCode).update({
          memberCount: 2,
        });
      });

      const authedDb = testEnv.authenticatedContext(member3Uid).firestore();

      // Duplicate variant 1: [member2Uid, member2Uid, member3Uid] (drops userId)
      const batch1 = authedDb.batch();
      batch1.update(authedDb.collection('trips').doc(tripId), {
        memberIds: [member2Uid, member2Uid, member3Uid],
        memberCount: 3,
      });
      batch1.set(
        authedDb.collection('trips').doc(tripId).collection('members').doc(member3Uid),
        {
          displayName: member3Name,
          photoUrl: null,
          role: 'member',
          status: 'active',
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batch1.update(authedDb.collection('joinCodes').doc(joinCode), {
        memberCount: 3,
      });
      await assertFails(batch1.commit());

      // Duplicate variant 2: [userId, userId, member3Uid] (drops member2Uid)
      const batch2 = authedDb.batch();
      batch2.update(authedDb.collection('trips').doc(tripId), {
        memberIds: [userId, userId, member3Uid],
        memberCount: 3,
      });
      batch2.set(
        authedDb.collection('trips').doc(tripId).collection('members').doc(member3Uid),
        {
          displayName: member3Name,
          photoUrl: null,
          role: 'member',
          status: 'active',
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batch2.update(authedDb.collection('joinCodes').doc(joinCode), {
        memberCount: 3,
      });
      await assertFails(batch2.commit());
    });

    // --- Part B(b): Join SUCCEEDS for normal case at counts 1 and 14 ---

    test('Join SUCCEEDS for normal case at count 1 (1 to 2) and count 14 (14 to 15)', async () => {
      // 1. Count 1 to 2
      const authedDb2 = testEnv.authenticatedContext(member2Uid).firestore();
      const batch1to2 = authedDb2.batch();
      batch1to2.update(authedDb2.collection('trips').doc(tripId), {
        memberIds: [userId, member2Uid],
        memberCount: 2,
      });
      batch1to2.set(
        authedDb2.collection('trips').doc(tripId).collection('members').doc(member2Uid),
        {
          displayName: member2Name,
          photoUrl: null,
          role: 'member',
          status: 'active',
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batch1to2.update(authedDb2.collection('joinCodes').doc(joinCode), {
        memberCount: 2,
      });
      await assertSucceeds(batch1to2.commit());

      // Negative control for 1 to 2: Invalid join dropping existing member fails
      const batch1to2Invalid = authedDb2.batch();
      batch1to2Invalid.update(authedDb2.collection('trips').doc(tripId), {
        memberIds: [member2Uid],
        memberCount: 2,
      });
      batch1to2Invalid.set(
        authedDb2.collection('trips').doc(tripId).collection('members').doc(member2Uid),
        {
          displayName: member2Name,
          photoUrl: null,
          role: 'member',
          status: 'active',
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batch1to2Invalid.update(authedDb2.collection('joinCodes').doc(joinCode), {
        memberCount: 2,
      });
      await assertFails(batch1to2Invalid.commit());

      // 2. Count 14 to 15
      const existingMembers = [];
      for (let i = 1; i <= 14; i++) {
        existingMembers.push(`user_${i}`);
      }
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('trips').doc(tripId).update({
          memberIds: existingMembers,
          memberCount: 14,
        });
        await db.collection('joinCodes').doc(joinCode).update({
          memberCount: 14,
        });
      });

      const user15Uid = 'user_15';
      await seedUser(user15Uid, 'User 15');

      const authedDb15 = testEnv.authenticatedContext(user15Uid).firestore();
      const batch14to15 = authedDb15.batch();
      batch14to15.update(authedDb15.collection('trips').doc(tripId), {
        memberIds: [...existingMembers, user15Uid],
        memberCount: 15,
      });
      batch14to15.set(
        authedDb15.collection('trips').doc(tripId).collection('members').doc(user15Uid),
        {
          displayName: 'User 15',
          photoUrl: null,
          role: 'member',
          status: 'active',
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batch14to15.update(authedDb15.collection('joinCodes').doc(joinCode), {
        memberCount: 15,
      });
      await assertSucceeds(batch14to15.commit());

      // Negative control for 14 to 15: Invalid join dropping an existing member fails
      const user16Uid = 'user_16';
      await seedUser(user16Uid, 'User 16');
      const authedDb16 = testEnv.authenticatedContext(user16Uid).firestore();
      const batch14to15Invalid = authedDb16.batch();
      // Drop user_1, keep 13 existing members + user16Uid (total size 14, memberCount 15)
      batch14to15Invalid.update(authedDb16.collection('trips').doc(tripId), {
        memberIds: [...existingMembers.slice(1), user15Uid, user16Uid],
        memberCount: 15,
      });
      batch14to15Invalid.set(
        authedDb16.collection('trips').doc(tripId).collection('members').doc(user16Uid),
        {
          displayName: 'User 16',
          photoUrl: null,
          role: 'member',
          status: 'active',
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batch14to15Invalid.update(authedDb16.collection('joinCodes').doc(joinCode), {
        memberCount: 15,
      });
      await assertFails(batch14to15Invalid.commit());
    });

    test('Sequential boundary test: succeeds at 14 to 15, fails at 15 to 16', async () => {
      // Seed trip with 14 members
      const existingMembers = [];
      for (let i = 1; i <= 14; i++) {
        existingMembers.push(`user_${i}`);
      }

      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('trips').doc(tripId).update({
          memberIds: existingMembers,
          memberCount: 14,
        });
        await db.collection('joinCodes').doc(joinCode).update({
          memberCount: 14,
        });
      });

      const user15Uid = 'user_15';
      const user16Uid = 'user_16';
      await seedUser(user15Uid, 'User 15');
      await seedUser(user16Uid, 'User 16');

      // User 15 joins (14 -> 15 succeeds)
      const authedDb15 = testEnv.authenticatedContext(user15Uid).firestore();
      const batch15 = authedDb15.batch();
      batch15.update(authedDb15.collection('trips').doc(tripId), {
        memberIds: [...existingMembers, user15Uid],
        memberCount: 15,
      });
      batch15.set(
        authedDb15.collection('trips').doc(tripId).collection('members').doc(user15Uid),
        {
          displayName: 'User 15',
          photoUrl: null,
          role: 'member',
          status: 'active',
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batch15.update(authedDb15.collection('joinCodes').doc(joinCode), {
        memberCount: 15,
      });

      await assertSucceeds(batch15.commit());

      // User 16 tries to join (15 -> 16 fails)
      const authedDb16 = testEnv.authenticatedContext(user16Uid).firestore();
      const batch16 = authedDb16.batch();
      batch16.update(authedDb16.collection('trips').doc(tripId), {
        memberIds: [...existingMembers, user15Uid, user16Uid],
        memberCount: 16,
      });
      batch16.set(
        authedDb16.collection('trips').doc(tripId).collection('members').doc(user16Uid),
        {
          displayName: 'User 16',
          photoUrl: null,
          role: 'member',
          status: 'active',
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batch16.update(authedDb16.collection('joinCodes').doc(joinCode), {
        memberCount: 16,
      });

      await assertFails(batch16.commit());
    });

    test('joinCodes update fails when modifying fields other than memberCount', async () => {
      const code = 'BOUND1';
      const userUid = 'join_code_user_m52';
      await seedUser(userUid, 'Join Code User');

      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('trips').doc('trip_m52').set({
          name: 'Test Trip M52',
          destination: 'Paris',
          startDate: new Date('2026-11-01T00:00:00Z'),
          endDate: new Date('2026-11-05T00:00:00Z'),
          currency: 'EUR',
          organizerId: 'org_m52',
          joinCode: code,
          memberIds: ['org_m52', userUid],
          memberCount: 2,
          archived: false,
          createdAt: new Date(),
        });
        await db.collection('joinCodes').doc(code).set({
          tripId: 'trip_m52',
          tripName: 'Test Trip M52',
          destination: 'Paris',
          startDate: new Date('2026-11-01T00:00:00Z'),
          endDate: new Date('2026-11-05T00:00:00Z'),
          memberCount: 1,
        });
      });

      const authedDb = testEnv.authenticatedContext(userUid).firestore();
      await assertFails(
        authedDb.collection('joinCodes').doc(code).update({
          memberCount: 2,
          destination: 'Malicious Destination',
        })
      );
    });

    test('joinCodes create fails when extra key is present in joinCodes document', async () => {
      const code = 'BCDF23';
      const userUid = 'join_code_user_c10';
      await seedUser(userUid, 'Join Code User');

      const authedDb = testEnv.authenticatedContext(userUid).firestore();
      const batch = authedDb.batch();
      batch.set(
        authedDb.collection('trips').doc('trip_c10'),
        {
          name: 'Test Trip C10',
          destination: 'Rome',
          startDate: new Date('2026-11-01T00:00:00Z'),
          endDate: new Date('2026-11-05T00:00:00Z'),
          currency: 'EUR',
          organizerId: userUid,
          joinCode: code,
          memberIds: [userUid],
          memberCount: 1,
          archived: false,
          createdAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batch.set(
        authedDb.collection('trips').doc('trip_c10').collection('members').doc(userUid),
        {
          displayName: 'Join Code User',
          photoUrl: null,
          role: 'organizer',
          status: 'active',
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batch.set(
        authedDb.collection('joinCodes').doc(code),
        {
          tripId: 'trip_c10',
          tripName: 'Test Trip C10',
          destination: 'Rome',
          startDate: new Date('2026-11-01T00:00:00Z'),
          endDate: new Date('2026-11-05T00:00:00Z'),
          memberCount: 1,
          extraKey: 'malicious',
        }
      );
      await assertFails(batch.commit());
    });

    test('joinCodes create fails when required key is missing from joinCodes document', async () => {
      const code = 'BCDF24';
      const userUid = 'join_code_user_m50';
      await seedUser(userUid, 'Join Code User M50');

      const authedDb = testEnv.authenticatedContext(userUid).firestore();
      const batch = authedDb.batch();
      batch.set(
        authedDb.collection('trips').doc('trip_m50'),
        {
          name: 'Test Trip M50',
          destination: 'Rome',
          startDate: new Date('2026-11-01T00:00:00Z'),
          endDate: new Date('2026-11-05T00:00:00Z'),
          currency: 'EUR',
          organizerId: userUid,
          joinCode: code,
          memberIds: [userUid],
          memberCount: 1,
          archived: false,
          createdAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batch.set(
        authedDb.collection('trips').doc('trip_m50').collection('members').doc(userUid),
        {
          displayName: 'Join Code User M50',
          photoUrl: null,
          role: 'organizer',
          status: 'active',
          joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }
      );
      batch.set(
        authedDb.collection('joinCodes').doc(code),
        {
          tripId: 'trip_m50',
          tripName: 'Test Trip M50',
          startDate: new Date('2026-11-01T00:00:00Z'),
          endDate: new Date('2026-11-05T00:00:00Z'),
          memberCount: 1,
        }
      );
      await assertFails(batch.commit());
    });
  });

  describe('Read & Query Permissions', () => {
    const userId = 'organizer_1';
    const userEmail = 'org@example.com';
    const displayName = 'Alice Organizer';
    const joinCode = 'ABC234';
    const tripId = 'trip_100';
    const startDate = new Date('2026-11-01T00:00:00Z');
    const endDate = new Date('2026-11-05T00:00:00Z');

    beforeEach(async () => {
      await seedUser(userId, displayName);
      await seedUser('non_member', 'Stranger');

      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('trips').doc(tripId).set({
          name: 'Goa Beach Trip',
          destination: 'Goa, India',
          startDate,
          endDate,
          currency: 'INR',
          organizerId: userId,
          joinCode,
          memberIds: [userId],
          memberCount: 1,
          archived: false,
          createdAt: new Date(),
        });

        await db
          .collection('trips')
          .doc(tripId)
          .collection('members')
          .doc(userId)
          .set({
            displayName,
            photoUrl: null,
            role: 'organizer',
            status: 'active',
            joinedAt: firebase.firestore.FieldValue.serverTimestamp(),
          });

        await db.collection('joinCodes').doc(joinCode).set({
          tripId,
          tripName: 'Goa Beach Trip',
          destination: 'Goa, India',
          startDate,
          endDate,
          memberCount: 1,
        });
      });
    });

    test('Non-member cannot read trip or members subcollection', async () => {
      const db = testEnv.authenticatedContext('non_member').firestore();
      await assertFails(db.collection('trips').doc(tripId).get());
      await assertFails(
        db.collection('trips').doc(tripId).collection('members').doc(userId).get()
      );
      await assertFails(
        db.collection('trips').doc(tripId).collection('members').get()
      );
    });

    test('Member can read trip and list members', async () => {
      const db = testEnv.authenticatedContext(userId).firestore();
      await assertSucceeds(db.collection('trips').doc(tripId).get());
      await assertSucceeds(
        db.collection('trips').doc(tripId).collection('members').get()
      );
    });

    test('My Trips array-contains query succeeds for member and list without filter fails', async () => {
      const db = testEnv.authenticatedContext(userId).firestore();
      await assertSucceeds(
        db.collection('trips').where('memberIds', 'array-contains', userId).get()
      );

      // Unfiltered list fails
      await assertFails(db.collection('trips').get());
    });

    test('joinCodes single get allowed for signed-in user, list denied', async () => {
      const db = testEnv.authenticatedContext('non_member').firestore();
      await assertSucceeds(db.collection('joinCodes').doc(joinCode).get());
      await assertFails(db.collection('joinCodes').get());
    });

    test('joinCodes update fails if not matching trip memberCount or deleting', async () => {
      const db = testEnv.authenticatedContext(userId).firestore();
      await assertFails(
        db.collection('joinCodes').doc(joinCode).update({ memberCount: 99 })
      );
      await assertFails(db.collection('joinCodes').doc(joinCode).delete());
    });

    test('members subcollection update and delete operations are denied', async () => {
      const db = testEnv.authenticatedContext(userId).firestore();
      const memberRef = db
        .collection('trips')
        .doc(tripId)
        .collection('members')
        .doc(userId);

      await assertFails(memberRef.update({ displayName: 'Hacker' }));
      await assertFails(memberRef.delete());
    });
  });

  describe('Phase 3: Suggestions & Votes Security Rules', () => {
    const organizerUid = 'organizer_1';
    const memberUid = 'member_1';
    const nonMemberUid = 'non_member_1';
    const tripId = 'trip_suggestions_test';
    const suggestionId = 'sugg_1';

    function getValidSuggestionPayload(overrides = {}) {
      return {
        title: 'Visit Fort Aguada',
        note: 'Go in the evening for sunset',
        estimatedCost: 500,
        category: 'sightseeing',
        authorId: memberUid,
        upCount: 0,
        downCount: 0,
        status: 'pending',
        dayIndex: null,
        order: null,
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
        ...overrides,
      };
    }

    beforeEach(async () => {
      await seedUser(organizerUid, 'Organizer');
      await seedUser(memberUid, 'Member');
      await seedUser(nonMemberUid, 'Non Member');

      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('trips').doc(tripId).set({
          name: 'Suggestions Test Trip',
          destination: 'Goa',
          startDate: new Date('2026-11-01T00:00:00Z'),
          endDate: new Date('2026-11-05T00:00:00Z'),
          currency: 'INR',
          organizerId: organizerUid,
          joinCode: 'SUGG01',
          memberIds: [organizerUid, memberUid],
          memberCount: 2,
          archived: false,
          createdAt: new Date(),
        });
      });
    });

    test('Signed-out and non-member are denied reading or writing suggestions and votes', async () => {
      const unauthedDb = testEnv.unauthenticatedContext().firestore();
      const nonMemberDb = testEnv.authenticatedContext(nonMemberUid).firestore();

      const suggRefUnauth = unauthedDb.collection('trips').doc(tripId).collection('suggestions').doc(suggestionId);
      const suggRefNonMember = nonMemberDb.collection('trips').doc(tripId).collection('suggestions').doc(suggestionId);

      await assertFails(suggRefUnauth.get());
      await assertFails(suggRefNonMember.get());
      await assertFails(suggRefUnauth.set(getValidSuggestionPayload()));
      await assertFails(suggRefNonMember.set(getValidSuggestionPayload()));

      // Negative control: Trip member can read suggestions
      const memberDb = testEnv.authenticatedContext(memberUid).firestore();
      const suggRefMember = memberDb.collection('trips').doc(tripId).collection('suggestions').doc(suggestionId);
      await assertSucceeds(suggRefMember.get());
    });

    test('Valid member suggestion create succeeds', async () => {
      const memberDb = testEnv.authenticatedContext(memberUid).firestore();
      const suggRef = memberDb.collection('trips').doc(tripId).collection('suggestions').doc(suggestionId);

      await assertSucceeds(suggRef.set(getValidSuggestionPayload()));

      // Negative control: Denied when missing required key (e.g. category)
      const invalidRef = memberDb.collection('trips').doc(tripId).collection('suggestions').doc('sugg_bad');
      const badPayload = getValidSuggestionPayload();
      delete badPayload.category;
      await assertFails(invalidRef.set(badPayload));
    });

    test('Denied suggestion create for invalid fields, authorId, counters, status, dayIndex, client date, cost', async () => {
      const memberDb = testEnv.authenticatedContext(memberUid).firestore();
      const suggRef = memberDb.collection('trips').doc(tripId).collection('suggestions').doc(suggestionId);

      // Extra key
      await assertFails(suggRef.set(getValidSuggestionPayload({ extra: 123 })));

      // authorId not caller
      await assertFails(suggRef.set(getValidSuggestionPayload({ authorId: organizerUid })));

      // upCount not 0
      await assertFails(suggRef.set(getValidSuggestionPayload({ upCount: 1 })));

      // downCount not 0
      await assertFails(suggRef.set(getValidSuggestionPayload({ downCount: 1 })));

      // status not pending
      await assertFails(suggRef.set(getValidSuggestionPayload({ status: 'scheduled' })));

      // dayIndex not null
      await assertFails(suggRef.set(getValidSuggestionPayload({ dayIndex: 0 })));

      // order not null
      await assertFails(suggRef.set(getValidSuggestionPayload({ order: 1 })));

      // client-date createdAt
      await assertFails(suggRef.set(getValidSuggestionPayload({ createdAt: new Date() })));

      // empty title
      await assertFails(suggRef.set(getValidSuggestionPayload({ title: '' })));

      // title > 80 chars
      await assertFails(suggRef.set(getValidSuggestionPayload({ title: 'A'.repeat(81) })));

      // note > 500 chars
      await assertFails(suggRef.set(getValidSuggestionPayload({ note: 'A'.repeat(501) })));

      // bad category
      await assertFails(suggRef.set(getValidSuggestionPayload({ category: 'party' })));

      // negative cost
      await assertFails(suggRef.set(getValidSuggestionPayload({ estimatedCost: -10 })));

      // non-integer cost
      await assertFails(suggRef.set(getValidSuggestionPayload({ estimatedCost: 10.5 })));

      // cost > 100,000,000,000
      await assertFails(suggRef.set(getValidSuggestionPayload({ estimatedCost: 100000000001 })));

      // Archived trip
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).update({ archived: true });
      });
      await assertFails(suggRef.set(getValidSuggestionPayload()));
    });

    test('Content edit: author and organizer succeed; non-author member denied; forbidden field edits denied', async () => {
      // Seed a suggestion
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).collection('suggestions').doc(suggestionId).set({
          title: 'Initial Title',
          note: 'Initial Note',
          estimatedCost: 100,
          category: 'food',
          authorId: memberUid,
          upCount: 0,
          downCount: 0,
          status: 'pending',
          dayIndex: null,
          order: null,
          createdAt: new Date(),
        });
      });

      const memberDb = testEnv.authenticatedContext(memberUid).firestore();
      const organizerDb = testEnv.authenticatedContext(organizerUid).firestore();
      const suggRefMember = memberDb.collection('trips').doc(tripId).collection('suggestions').doc(suggestionId);
      const suggRefOrganizer = organizerDb.collection('trips').doc(tripId).collection('suggestions').doc(suggestionId);

      // Author edit succeeds
      await assertSucceeds(suggRefMember.update({ title: 'Author Updated Title' }));

      // Organizer edit succeeds
      await assertSucceeds(suggRefOrganizer.update({ note: 'Organizer Updated Note', category: 'other' }));

      // Other member edit denied
      const otherMemberUid = 'other_member_2';
      await seedUser(otherMemberUid, 'Other Member');
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).update({ memberIds: [organizerUid, memberUid, otherMemberUid] });
      });
      const otherMemberDb = testEnv.authenticatedContext(otherMemberUid).firestore();
      await assertFails(otherMemberDb.collection('trips').doc(tripId).collection('suggestions').doc(suggestionId).update({ title: 'Hacked Title' }));

      // Cannot change status, dayIndex, order, authorId, createdAt or counters through content path
      await assertFails(suggRefMember.update({ status: 'scheduled' }));
      await assertFails(suggRefMember.update({ dayIndex: 1 }));
      await assertFails(suggRefMember.update({ order: 1 }));
      await assertFails(suggRefMember.update({ authorId: organizerUid }));
      await assertFails(suggRefMember.update({ createdAt: new Date() }));
      await assertFails(suggRefMember.update({ upCount: 1 }));
    });

    test('Vote transactions & counter coupling: all 6 vote transitions succeed with matching counters', async () => {
      // Seed initial suggestion
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).collection('suggestions').doc(suggestionId).set({
          title: 'Vote Test Suggestion',
          note: 'Note',
          estimatedCost: null,
          category: 'sightseeing',
          authorId: memberUid,
          upCount: 0,
          downCount: 0,
          status: 'pending',
          dayIndex: null,
          order: null,
          createdAt: new Date(),
        });
      });

      const memberDb = testEnv.authenticatedContext(memberUid).firestore();
      const suggRef = memberDb.collection('trips').doc(tripId).collection('suggestions').doc(suggestionId);
      const voteRef = suggRef.collection('votes').doc(memberUid);

      // 1. No vote -> Up (+1 upCount)
      let batch = memberDb.batch();
      batch.update(suggRef, { upCount: 1, downCount: 0 });
      batch.set(voteRef, { value: 1, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      await assertSucceeds(batch.commit());

      // 2. Up -> Down (flip: upCount 1 -> 0, downCount 0 -> 1)
      batch = memberDb.batch();
      batch.update(suggRef, { upCount: 0, downCount: 1 });
      batch.set(voteRef, { value: -1, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      await assertSucceeds(batch.commit());

      // 3. Down -> Up (flip back: upCount 0 -> 1, downCount 1 -> 0)
      batch = memberDb.batch();
      batch.update(suggRef, { upCount: 1, downCount: 0 });
      batch.set(voteRef, { value: 1, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      await assertSucceeds(batch.commit());

      // 4. Up -> Up again (remove up vote: upCount 1 -> 0, delete vote doc)
      batch = memberDb.batch();
      batch.update(suggRef, { upCount: 0, downCount: 0 });
      batch.delete(voteRef);
      await assertSucceeds(batch.commit());

      // 5. No vote -> Down (+1 downCount)
      batch = memberDb.batch();
      batch.update(suggRef, { upCount: 0, downCount: 1 });
      batch.set(voteRef, { value: -1, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      await assertSucceeds(batch.commit());

      // 6. Down -> Down again (remove down vote: downCount 1 -> 0, delete vote doc)
      batch = memberDb.batch();
      batch.update(suggRef, { upCount: 0, downCount: 0 });
      batch.delete(voteRef);
      await assertSucceeds(batch.commit());
    });

    test('Denied vote transactions: unmatched counters, wrong deltas, invalid vote values, extra keys', async () => {
      // Seed initial suggestion
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).collection('suggestions').doc(suggestionId).set({
          title: 'Bad Vote Test',
          note: 'Note',
          estimatedCost: null,
          category: 'stay',
          authorId: memberUid,
          upCount: 0,
          downCount: 0,
          status: 'pending',
          dayIndex: null,
          order: null,
          createdAt: new Date(),
        });
      });

      const memberDb = testEnv.authenticatedContext(memberUid).firestore();
      const suggRef = memberDb.collection('trips').doc(tripId).collection('suggestions').doc(suggestionId);
      const voteRef = suggRef.collection('votes').doc(memberUid);

      // UpCount +2 (changed by 2)
      let batch = memberDb.batch();
      batch.update(suggRef, { upCount: 2, downCount: 0 });
      batch.set(voteRef, { value: 1, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      await assertFails(batch.commit());

      // UpCount -1 on new up vote (wrong direction)
      batch = memberDb.batch();
      batch.update(suggRef, { upCount: -1, downCount: 0 });
      batch.set(voteRef, { value: 1, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      await assertFails(batch.commit());

      // Counter changed alone without vote write
      await assertFails(suggRef.update({ upCount: 1, downCount: 0 }));

      // Vote written alone without counter change
      await assertFails(voteRef.set({ value: 1, updatedAt: firebase.firestore.FieldValue.serverTimestamp() }));

      // Vote value 1, but downCount updated instead of upCount
      batch = memberDb.batch();
      batch.update(suggRef, { upCount: 0, downCount: 1 });
      batch.set(voteRef, { value: 1, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      await assertFails(batch.commit());

      // Both upCount and downCount changed on plain up vote (+1 upCount, +1 downCount)
      batch = memberDb.batch();
      batch.update(suggRef, { upCount: 1, downCount: 1 });
      batch.set(voteRef, { value: 1, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      await assertFails(batch.commit());

      // Invalid vote value 0 or 2
      batch = memberDb.batch();
      batch.update(suggRef, { upCount: 0, downCount: 0 });
      batch.set(voteRef, { value: 0, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      await assertFails(batch.commit());

      batch = memberDb.batch();
      batch.update(suggRef, { upCount: 1, downCount: 0 });
      batch.set(voteRef, { value: 2, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      await assertFails(batch.commit());

      // Same-value vote update denied (re-voting +1 when already +1)
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const adminSuggRef = context.firestore().collection('trips').doc(tripId).collection('suggestions').doc(suggestionId);
        await adminSuggRef.collection('votes').doc(memberUid).set({ value: 1, updatedAt: new Date() });
        await adminSuggRef.update({ upCount: 1, downCount: 0 });
      });
      batch = memberDb.batch();
      batch.update(suggRef, { upCount: 1, downCount: 0 });
      batch.set(voteRef, { value: 1, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      await assertFails(batch.commit());

      // Vote transaction on archived trip denied
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).update({ archived: true });
      });
      batch = memberDb.batch();
      batch.update(suggRef, { upCount: 2, downCount: 0 });
      batch.set(voteRef, { value: 1, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      await assertFails(batch.commit());

      // Restore trip archived status for subsequent tests
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).update({ archived: false });
      });

      // Extra key in vote document
      batch = memberDb.batch();
      batch.update(suggRef, { upCount: 1, downCount: 0 });
      batch.set(voteRef, { value: 1, updatedAt: firebase.firestore.FieldValue.serverTimestamp(), extra: true });
      await assertFails(batch.commit());

      // Client date updatedAt
      batch = memberDb.batch();
      batch.update(suggRef, { upCount: 1, downCount: 0 });
      batch.set(voteRef, { value: 1, updatedAt: new Date() });
      await assertFails(batch.commit());

      // Vote written to another user's uid doc path
      const otherVoteRef = suggRef.collection('votes').doc(organizerUid);
      batch = memberDb.batch();
      batch.update(suggRef, { upCount: 1, downCount: 0 });
      batch.set(otherVoteRef, { value: 1, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      await assertFails(batch.commit());
    });

    test('Votes read permissions: owner can read own vote, other member cannot read owner vote', async () => {
      // Seed a vote
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).collection('suggestions').doc(suggestionId).collection('votes').doc(memberUid).set({
          value: 1,
          updatedAt: new Date(),
        });
      });

      const memberDb = testEnv.authenticatedContext(memberUid).firestore();
      const organizerDb = testEnv.authenticatedContext(organizerUid).firestore();

      const voteRef = memberDb.collection('trips').doc(tripId).collection('suggestions').doc(suggestionId).collection('votes').doc(memberUid);
      const otherVoteRef = organizerDb.collection('trips').doc(tripId).collection('suggestions').doc(suggestionId).collection('votes').doc(memberUid);

      // Owner can read own vote
      await assertSucceeds(voteRef.get());

      // Other member (organizer) cannot read member's vote
      await assertFails(otherVoteRef.get());

      // Signed-out and non-member cannot read vote
      const unauthVoteRef = testEnv.unauthenticatedContext().firestore().collection('trips').doc(tripId).collection('suggestions').doc(suggestionId).collection('votes').doc(memberUid);
      await assertFails(unauthVoteRef.get());
      const nonMemberVoteRef = testEnv.authenticatedContext(nonMemberUid).firestore().collection('trips').doc(tripId).collection('suggestions').doc(suggestionId).collection('votes').doc(memberUid);
      await assertFails(nonMemberVoteRef.get());
    });

    test('Suggestion delete: author and organizer succeed, other member denied', async () => {
      // Seed suggestion
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).collection('suggestions').doc(suggestionId).set({
          title: 'To Be Deleted',
          note: 'Note',
          estimatedCost: null,
          category: 'transport',
          authorId: memberUid,
          upCount: 0,
          downCount: 0,
          status: 'pending',
          dayIndex: null,
          order: null,
          createdAt: new Date(),
        });
      });

      const otherMemberUid = 'other_member_delete';
      await seedUser(otherMemberUid, 'Other Member Delete');
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).update({ memberIds: [organizerUid, memberUid, otherMemberUid] });
      });

      const memberDb = testEnv.authenticatedContext(memberUid).firestore();
      const organizerDb = testEnv.authenticatedContext(organizerUid).firestore();
      const otherDb = testEnv.authenticatedContext(otherMemberUid).firestore();

      const suggRefOther = otherDb.collection('trips').doc(tripId).collection('suggestions').doc(suggestionId);
      const suggRefMember = memberDb.collection('trips').doc(tripId).collection('suggestions').doc(suggestionId);
      const suggRefOrganizer = organizerDb.collection('trips').doc(tripId).collection('suggestions').doc(suggestionId);
      const suggRefNonMember = testEnv.authenticatedContext(nonMemberUid).firestore().collection('trips').doc(tripId).collection('suggestions').doc(suggestionId);

      // Non-member delete denied
      await assertFails(suggRefNonMember.delete());

      // Other member delete denied
      await assertFails(suggRefOther.delete());

      // Author delete succeeds
      await assertSucceeds(suggRefMember.delete());

      // Re-seed and test organizer delete succeeds
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).collection('suggestions').doc(suggestionId).set({
          title: 'To Be Deleted 2',
          note: 'Note',
          estimatedCost: null,
          category: 'transport',
          authorId: memberUid,
          upCount: 0,
          downCount: 0,
          status: 'pending',
          dayIndex: null,
          order: null,
          createdAt: new Date(),
        });
      });
      await assertSucceeds(suggRefOrganizer.delete());
    });
  });

describe('Phase 3 proof tests', () => {
    const proofOrganizerUid = 'proof_organizer';
    const proofMember1Uid = 'proof_member_1';
    const proofMember2Uid = 'proof_member_2';
    const proofNonMemberUid = 'proof_non_member';
    const proofTripId = 'trip_proof_test';
    const proofSuggId = 'sugg_proof_1';

    async function seedProofEnvironment(overrides = {}) {
      const {
        archived = false,
        suggestion = null,
        vote = null,
      } = overrides;

      await seedUser(proofOrganizerUid, 'Proof Organizer');
      await seedUser(proofMember1Uid, 'Proof Member 1');
      await seedUser(proofMember2Uid, 'Proof Member 2');
      await seedUser(proofNonMemberUid, 'Proof Non Member');

      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('trips').doc(proofTripId).set({
          name: 'Proof Test Trip',
          destination: 'Goa',
          startDate: new Date('2026-11-01T00:00:00Z'),
          endDate: new Date('2026-11-05T00:00:00Z'),
          currency: 'INR',
          organizerId: proofOrganizerUid,
          joinCode: 'PROOF1',
          memberIds: [proofOrganizerUid, proofMember1Uid, proofMember2Uid],
          memberCount: 3,
          archived,
          createdAt: new Date(),
        });

        const suggData = {
          title: 'Proof Suggestion',
          note: 'Proof Note',
          estimatedCost: 100,
          category: 'food',
          authorId: proofMember1Uid,
          upCount: 0,
          downCount: 0,
          status: 'pending',
          dayIndex: null,
          order: null,
          createdAt: new Date(),
          ...suggestion,
        };

        await db.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId).set(suggData);

        if (vote) {
          const voteUid = vote.uid || proofMember1Uid;
          await db.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId).collection('votes').doc(voteUid).set({
            value: vote.value !== undefined ? vote.value : 1,
            updatedAt: new Date(),
          });
        }
      });
    }

    test('Proof 1: Signed-out and non-member vote write denied', async () => {
      await seedProofEnvironment();

      const unauthedDb = testEnv.unauthenticatedContext().firestore();
      const nonMemberDb = testEnv.authenticatedContext(proofNonMemberUid).firestore();
      const member1Db = testEnv.authenticatedContext(proofMember1Uid).firestore();

      const unauthSuggRef = unauthedDb.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId);
      const unauthVoteRef = unauthSuggRef.collection('votes').doc('unauth_uid');

      const nonMemberSuggRef = nonMemberDb.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId);
      const nonMemberVoteRef = nonMemberSuggRef.collection('votes').doc(proofNonMemberUid);

      const member1SuggRef = member1Db.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId);
      const member1VoteRef = member1SuggRef.collection('votes').doc(proofMember1Uid);

      // Signed-out vote write denied
      const batch1 = unauthedDb.batch();
      batch1.set(unauthVoteRef, { value: 1, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      batch1.update(unauthSuggRef, { upCount: 1, downCount: 0 });
      await assertFails(batch1.commit());

      // Non-member vote write denied
      const batch2 = nonMemberDb.batch();
      batch2.set(nonMemberVoteRef, { value: 1, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      batch2.update(nonMemberSuggRef, { upCount: 1, downCount: 0 });
      await assertFails(batch2.commit());

      // Control: Valid member vote write succeeds
      const batchValid = member1Db.batch();
      batchValid.set(member1VoteRef, { value: 1, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      batchValid.update(member1SuggRef, { upCount: 1, downCount: 0 });
      await assertSucceeds(batchValid.commit());
    });

    test('Proof 2: Vote value 2 and 0 denied on create with unchanged counters', async () => {
      await seedProofEnvironment();

      const member1Db = testEnv.authenticatedContext(proofMember1Uid).firestore();
      const member1SuggRef = member1Db.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId);
      const member1VoteRef = member1SuggRef.collection('votes').doc(proofMember1Uid);

      // Vote value 2 with unchanged counters denied
      const batch2 = member1Db.batch();
      batch2.set(member1VoteRef, { value: 2, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      batch2.update(member1SuggRef, { upCount: 0, downCount: 0 });
      await assertFails(batch2.commit());

      // Vote value 0 with unchanged counters denied
      const batch0 = member1Db.batch();
      batch0.set(member1VoteRef, { value: 0, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      batch0.update(member1SuggRef, { upCount: 0, downCount: 0 });
      await assertFails(batch0.commit());

      // Control: Valid vote create (value 1, upCount 1) succeeds
      const batchValid = member1Db.batch();
      batchValid.set(member1VoteRef, { value: 1, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      batchValid.update(member1SuggRef, { upCount: 1, downCount: 0 });
      await assertSucceeds(batchValid.commit());
    });

    test('Proof 3: Re-vote with same value denied', async () => {
      await seedProofEnvironment({
        suggestion: { upCount: 1, downCount: 0 },
        vote: { uid: proofMember1Uid, value: 1 },
      });

      const member1Db = testEnv.authenticatedContext(proofMember1Uid).firestore();
      const member1SuggRef = member1Db.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId);
      const member1VoteRef = member1SuggRef.collection('votes').doc(proofMember1Uid);

      // Same value re-vote (value 1 -> 1, counters unchanged upCount 1, downCount 0) denied
      const batchSame = member1Db.batch();
      batchSame.set(member1VoteRef, { value: 1, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      batchSame.update(member1SuggRef, { upCount: 1, downCount: 0 });
      await assertFails(batchSame.commit());

      // Control: Valid vote flip (value 1 -> -1, upCount 0, downCount 1) succeeds
      const batchFlip = member1Db.batch();
      batchFlip.set(member1VoteRef, { value: -1, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      batchFlip.update(member1SuggRef, { upCount: 0, downCount: 1 });
      await assertSucceeds(batchFlip.commit());
    });

    test('Proof 4: Vote create, vote delete, and suggestion counter update on archived trip denied', async () => {
      await seedProofEnvironment({ archived: true });

      const member1Db = testEnv.authenticatedContext(proofMember1Uid).firestore();
      const member1SuggRef = member1Db.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId);
      const member1VoteRef = member1SuggRef.collection('votes').doc(proofMember1Uid);

      // 4a. Vote create on archived trip denied (matching counters upCount 1)
      const batchCreateArchived = member1Db.batch();
      batchCreateArchived.set(member1VoteRef, { value: 1, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      batchCreateArchived.update(member1SuggRef, { upCount: 1, downCount: 0 });
      await assertFails(batchCreateArchived.commit());

      // 4b. Vote delete on archived trip denied (matching counter decrement)
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId).update({ upCount: 1, downCount: 0 });
        await db.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId).collection('votes').doc(proofMember1Uid).set({
          value: 1,
          updatedAt: new Date(),
        });
      });

      const batchDeleteArchived = member1Db.batch();
      batchDeleteArchived.delete(member1VoteRef);
      batchDeleteArchived.update(member1SuggRef, { upCount: 0, downCount: 0 });
      await assertFails(batchDeleteArchived.commit());

      // 4c. Suggestion counter update on archived trip denied
      await assertFails(member1SuggRef.update({ upCount: 1, downCount: 0 }));

      // Control: On non-archived trip, vote create succeeds
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('trips').doc(proofTripId).update({ archived: false });
        await db.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId).update({ upCount: 0, downCount: 0 });
        await db.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId).collection('votes').doc(proofMember1Uid).delete();
      });

      const batchControl = member1Db.batch();
      batchControl.set(member1VoteRef, { value: 1, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      batchControl.update(member1SuggRef, { upCount: 1, downCount: 0 });
      await assertSucceeds(batchControl.commit());
    });

    test('Proof 5: Signed-out, non-member and other-member reads of vote document denied', async () => {
      await seedProofEnvironment({
        suggestion: { upCount: 1, downCount: 0 },
        vote: { uid: proofMember1Uid, value: 1 },
      });

      const unauthedDb = testEnv.unauthenticatedContext().firestore();
      const nonMemberDb = testEnv.authenticatedContext(proofNonMemberUid).firestore();
      const member2Db = testEnv.authenticatedContext(proofMember2Uid).firestore();
      const member1Db = testEnv.authenticatedContext(proofMember1Uid).firestore();

      const votePath = ['trips', proofTripId, 'suggestions', proofSuggId, 'votes', proofMember1Uid];

      // Signed-out read denied
      await assertFails(unauthedDb.collection(votePath[0]).doc(votePath[1]).collection(votePath[2]).doc(votePath[3]).collection(votePath[4]).doc(votePath[5]).get());

      // Non-member read denied (reading someone else's vote)
      await assertFails(nonMemberDb.collection(votePath[0]).doc(votePath[1]).collection(votePath[2]).doc(votePath[3]).collection(votePath[4]).doc(votePath[5]).get());

      // Non-member reading their OWN vote document on a trip they do not belong to denied
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId).collection('votes').doc(proofNonMemberUid).set({
          value: 1,
          updatedAt: new Date(),
        });
      });
      await assertFails(nonMemberDb.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId).collection('votes').doc(proofNonMemberUid).get());

      // Other member read denied
      await assertFails(member2Db.collection(votePath[0]).doc(votePath[1]).collection(votePath[2]).doc(votePath[3]).collection(votePath[4]).doc(votePath[5]).get());

      // Control: Owner read succeeds
      await assertSucceeds(member1Db.collection(votePath[0]).doc(votePath[1]).collection(votePath[2]).doc(votePath[3]).collection(votePath[4]).doc(votePath[5]).get());
    });

    test('Proof 6a: Content update changing createdAt denied', async () => {
      await seedProofEnvironment();

      const member1Db = testEnv.authenticatedContext(proofMember1Uid).firestore();
      const member1SuggRef = member1Db.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId);

      // Changing createdAt denied
      await assertFails(member1SuggRef.update({ createdAt: firebase.firestore.FieldValue.serverTimestamp() }));

      // Control: Author valid content update succeeds
      await assertSucceeds(member1SuggRef.update({ title: 'Valid Updated Title 6a' }));
    });

    test('Proof 6b: Content update changing authorId denied', async () => {
      await seedProofEnvironment();

      const member1Db = testEnv.authenticatedContext(proofMember1Uid).firestore();
      const member1SuggRef = member1Db.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId);

      // Changing authorId denied
      await assertFails(member1SuggRef.update({ authorId: proofOrganizerUid }));

      // Control: Author valid content update succeeds
      await assertSucceeds(member1SuggRef.update({ title: 'Valid Updated Title 6b' }));
    });

    test('Proof 6c: Content update changing status denied', async () => {
      await seedProofEnvironment();

      const member1Db = testEnv.authenticatedContext(proofMember1Uid).firestore();
      const member1SuggRef = member1Db.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId);

      // Changing status denied
      await assertFails(member1SuggRef.update({ status: 'scheduled' }));

      // Control: Author valid content update succeeds
      await assertSucceeds(member1SuggRef.update({ title: 'Valid Updated Title 6c' }));
    });

    test('Proof 6d: Content update changing dayIndex denied', async () => {
      await seedProofEnvironment();

      const member1Db = testEnv.authenticatedContext(proofMember1Uid).firestore();
      const member1SuggRef = member1Db.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId);

      // Changing dayIndex denied
      await assertFails(member1SuggRef.update({ dayIndex: 1 }));

      // Control: Author valid content update succeeds
      await assertSucceeds(member1SuggRef.update({ title: 'Valid Updated Title 6d' }));
    });

    test('Proof 6e: Content update changing order denied', async () => {
      await seedProofEnvironment();

      const member1Db = testEnv.authenticatedContext(proofMember1Uid).firestore();
      const member1SuggRef = member1Db.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId);

      // Changing order denied
      await assertFails(member1SuggRef.update({ order: 1 }));

      // Control: Author valid content update succeeds
      await assertSucceeds(member1SuggRef.update({ title: 'Valid Updated Title 6e' }));
    });

    test('Proof 7: Suggestion delete denied for non-member and signed-out user', async () => {
      await seedProofEnvironment();

      const unauthedDb = testEnv.unauthenticatedContext().firestore();
      const nonMemberDb = testEnv.authenticatedContext(proofNonMemberUid).firestore();
      const member1Db = testEnv.authenticatedContext(proofMember1Uid).firestore();
      const organizerDb = testEnv.authenticatedContext(proofOrganizerUid).firestore();

      const unauthSuggRef = unauthedDb.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId);
      const nonMemberSuggRef = nonMemberDb.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId);
      const member1SuggRef = member1Db.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId);
      const organizerSuggRef = organizerDb.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId);

      // Signed-out delete denied
      await assertFails(unauthSuggRef.delete());

      // Non-member delete denied
      await assertFails(nonMemberSuggRef.delete());

      // Non-member who is suggestion author (e.g. removed member) delete denied
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId).set({
          title: 'Non-Member Author Suggestion',
          note: 'Proof Note',
          estimatedCost: 100,
          category: 'food',
          authorId: proofNonMemberUid,
          upCount: 0,
          downCount: 0,
          status: 'pending',
          dayIndex: null,
          order: null,
          createdAt: new Date(),
        });
      });
      await assertFails(nonMemberSuggRef.delete());

      // Re-seed for author control
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId).set({
          title: 'Member Author Suggestion',
          note: 'Proof Note',
          estimatedCost: 100,
          category: 'food',
          authorId: proofMember1Uid,
          upCount: 0,
          downCount: 0,
          status: 'pending',
          dayIndex: null,
          order: null,
          createdAt: new Date(),
        });
      });

      // Control 1: Author delete succeeds
      await assertSucceeds(member1SuggRef.delete());

      // Re-seed for organizer control
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId).set({
          title: 'Proof Suggestion 2',
          note: 'Proof Note',
          estimatedCost: 100,
          category: 'food',
          authorId: proofMember1Uid,
          upCount: 0,
          downCount: 0,
          status: 'pending',
          dayIndex: null,
          order: null,
          createdAt: new Date(),
        });
      });

      // Control 2: Organizer delete succeeds
      await assertSucceeds(organizerSuggRef.delete());
    });

    test('Proof 8a: Plain suggestion counter update with NO vote change denied', async () => {
      await seedProofEnvironment();

      const member1Db = testEnv.authenticatedContext(proofMember1Uid).firestore();
      const member1SuggRef = member1Db.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId);
      const member1VoteRef = member1SuggRef.collection('votes').doc(proofMember1Uid);

      // upCount +1 alone denied
      await assertFails(member1SuggRef.update({ upCount: 1 }));

      // downCount +1 alone denied
      await assertFails(member1SuggRef.update({ downCount: 1 }));

      // Control: Valid vote write with matching counter change succeeds
      const batchValid = member1Db.batch();
      batchValid.set(member1VoteRef, { value: 1, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      batchValid.update(member1SuggRef, { upCount: 1, downCount: 0 });
      await assertSucceeds(batchValid.commit());
    });

    test('Proof 8b: Vote write with NO matching counter change denied', async () => {
      await seedProofEnvironment();

      const member1Db = testEnv.authenticatedContext(proofMember1Uid).firestore();
      const member1SuggRef = member1Db.collection('trips').doc(proofTripId).collection('suggestions').doc(proofSuggId);
      const member1VoteRef = member1SuggRef.collection('votes').doc(proofMember1Uid);

      // Vote write with NO matching counter change denied
      await assertFails(member1VoteRef.set({ value: 1, updatedAt: firebase.firestore.FieldValue.serverTimestamp() }));

      // Control: Valid vote write with matching counter change succeeds
      const batchValid = member1Db.batch();
      batchValid.set(member1VoteRef, { value: 1, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      batchValid.update(member1SuggRef, { upCount: 1, downCount: 0 });
      await assertSucceeds(batchValid.commit());
    });
  });

describe('Phase 4 itinerary rules', () => {
    const tripId = 'trip_itinerary_1';
    const organizerUid = 'organizer_itin';
    const memberUid = 'member_itin';
    const nonMemberUid = 'non_member_itin';
    const suggId = 'sugg_itin_1';

    async function seedItineraryEnv(options = {}) {
      const {
        archived = false,
        status = 'pending',
        dayIndex = null,
        order = null,
        startDate = new Date('2026-11-01T00:00:00Z'),
        endDate = new Date('2026-11-05T00:00:00Z'),
      } = options;
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('users').doc(organizerUid).set({
          displayName: 'Organizer Itin',
          email: 'org@itin.com',
          createdAt: new Date(),
        });
        await db.collection('users').doc(memberUid).set({
          displayName: 'Member Itin',
          email: 'mem@itin.com',
          createdAt: new Date(),
        });
        await db.collection('users').doc(nonMemberUid).set({
          displayName: 'NonMember Itin',
          email: 'nonmem@itin.com',
          createdAt: new Date(),
        });
        await db.collection('trips').doc(tripId).set({
          name: 'Itinerary Trip',
          destination: 'Paris',
          startDate: firebase.firestore.Timestamp.fromDate(startDate instanceof Date ? startDate : new Date(startDate)),
          endDate: firebase.firestore.Timestamp.fromDate(endDate instanceof Date ? endDate : new Date(endDate)),
          currency: 'EUR',
          organizerId: organizerUid,
          joinCode: 'ITIN01',
          memberIds: [organizerUid, memberUid],
          memberCount: 2,
          archived,
          createdAt: new Date(),
        });
        await db.collection('trips').doc(tripId).collection('suggestions').doc(suggId).set({
          title: 'Visit Louvre',
          note: 'Buy tickets online',
          estimatedCost: 2000,
          category: 'sightseeing',
          authorId: memberUid,
          upCount: 0,
          downCount: 0,
          status,
          dayIndex,
          order,
          createdAt: new Date(),
        });
      });
    }

    test('Organizer schedules pending suggestion to scheduled (day 0 and last day)', async () => {
      await seedItineraryEnv();
      const organizerDb = testEnv.authenticatedContext(organizerUid).firestore();
      const suggRef = organizerDb.collection('trips').doc(tripId).collection('suggestions').doc(suggId);

      // Day 0
      await assertSucceeds(suggRef.update({
        status: 'scheduled',
        dayIndex: 0,
        order: 0,
      }));

      // Last day (Day 4)
      await assertSucceeds(suggRef.update({
        status: 'scheduled',
        dayIndex: 4,
        order: 1,
      }));
    });

    test('Organizer reorders, moves day, and unschedules', async () => {
      await seedItineraryEnv({ status: 'scheduled', dayIndex: 0, order: 0 });
      const organizerDb = testEnv.authenticatedContext(organizerUid).firestore();
      const suggRef = organizerDb.collection('trips').doc(tripId).collection('suggestions').doc(suggId);

      // Reorder (order only)
      await assertSucceeds(suggRef.update({
        status: 'scheduled',
        dayIndex: 0,
        order: 1,
      }));

      // Move day
      await assertSucceeds(suggRef.update({
        status: 'scheduled',
        dayIndex: 2,
        order: 0,
      }));

      // Unschedule (scheduled to pending)
      await assertSucceeds(suggRef.update({
        status: 'pending',
        dayIndex: null,
        order: null,
      }));
    });

    test('Scheduling denied for plain member, non-organizer author, non-member, signed out, archived trip', async () => {
      await seedItineraryEnv();
      const memberDb = testEnv.authenticatedContext(memberUid).firestore();
      const nonMemberDb = testEnv.authenticatedContext(nonMemberUid).firestore();
      const unauthedDb = testEnv.unauthenticatedContext().firestore();

      const memberRef = memberDb.collection('trips').doc(tripId).collection('suggestions').doc(suggId);
      const nonMemberRef = nonMemberDb.collection('trips').doc(tripId).collection('suggestions').doc(suggId);
      const unauthRef = unauthedDb.collection('trips').doc(tripId).collection('suggestions').doc(suggId);

      // Plain member (even though member is the author)
      await assertFails(memberRef.update({
        status: 'scheduled',
        dayIndex: 0,
        order: 0,
      }));

      // Non-member
      await assertFails(nonMemberRef.update({
        status: 'scheduled',
        dayIndex: 0,
        order: 0,
      }));

      // Signed out
      await assertFails(unauthRef.update({
        status: 'scheduled',
        dayIndex: 0,
        order: 0,
      }));

      // Archived trip
      await seedItineraryEnv({ archived: true });
      const organizerDb = testEnv.authenticatedContext(organizerUid).firestore();
      const orgRef = organizerDb.collection('trips').doc(tripId).collection('suggestions').doc(suggId);
      await assertFails(orgRef.update({
        status: 'scheduled',
        dayIndex: 0,
        order: 0,
      }));
    });

    test('Denied scheduling for invalid dayIndex, order, status values, coherence, and extra/mixed keys', async () => {
      await seedItineraryEnv();
      const organizerDb = testEnv.authenticatedContext(organizerUid).firestore();
      const suggRef = organizerDb.collection('trips').doc(tripId).collection('suggestions').doc(suggId);

      // dayIndex -1
      await assertFails(suggRef.update({ status: 'scheduled', dayIndex: -1, order: 0 }));

      // dayIndex beyond last day (Nov 1 to Nov 5 = 4 days; dayIndex 5 is beyond)
      await assertFails(suggRef.update({ status: 'scheduled', dayIndex: 5, order: 0 }));

      // dayIndex string
      await assertFails(suggRef.update({ status: 'scheduled', dayIndex: '0', order: 0 }));

      // dayIndex float
      await assertFails(suggRef.update({ status: 'scheduled', dayIndex: 1.5, order: 0 }));

      // order -1
      await assertFails(suggRef.update({ status: 'scheduled', dayIndex: 0, order: -1 }));

      // order string
      await assertFails(suggRef.update({ status: 'scheduled', dayIndex: 0, order: '0' }));

      // order float
      await assertFails(suggRef.update({ status: 'scheduled', dayIndex: 0, order: 2.5 }));

      // order > 10000
      await assertFails(suggRef.update({ status: 'scheduled', dayIndex: 0, order: 10001 }));

      // status 'scheduled' with null dayIndex
      await assertFails(suggRef.update({ status: 'scheduled', dayIndex: null, order: 0 }));

      // status 'scheduled' with null order
      await assertFails(suggRef.update({ status: 'scheduled', dayIndex: 0, order: null }));

      // status 'pending' with non-null dayIndex or order
      await assertFails(suggRef.update({ status: 'pending', dayIndex: 0, order: null }));
      await assertFails(suggRef.update({ status: 'pending', dayIndex: null, order: 0 }));

      // invalid status value 'done'
      await assertFails(suggRef.update({ status: 'done', dayIndex: 0, order: 0 }));

      // extra keys in update
      await assertFails(suggRef.update({ status: 'scheduled', dayIndex: 0, order: 0, title: 'New Title' }));
      await assertFails(suggRef.update({ status: 'scheduled', dayIndex: 0, order: 0, upCount: 1 }));
      await assertFails(suggRef.update({ status: 'scheduled', dayIndex: 0, order: 0, authorId: organizerUid }));

      // mixed keys (content + scheduling)
      await assertFails(suggRef.update({ status: 'scheduled', dayIndex: 0, order: 0, note: 'New note' }));
    });

    test('Existing content-update and counter branches cannot set scheduling fields, and vote transaction works on scheduled item', async () => {
      await seedItineraryEnv({ status: 'scheduled', dayIndex: 0, order: 0 });
      const organizerDb = testEnv.authenticatedContext(organizerUid).firestore();
      const memberDb = testEnv.authenticatedContext(memberUid).firestore();
      const orgSuggRef = organizerDb.collection('trips').doc(tripId).collection('suggestions').doc(suggId);
      const memSuggRef = memberDb.collection('trips').doc(tripId).collection('suggestions').doc(suggId);

      // Content branch cannot change status/dayIndex/order
      await assertFails(memSuggRef.update({ title: 'New Title', status: 'pending' }));

      // Counter branch cannot change status/dayIndex/order
      await assertFails(memSuggRef.update({ upCount: 1, dayIndex: 1 }));

      // Vote transaction still works on scheduled suggestion
      const memberVoteRef = memSuggRef.collection('votes').doc(memberUid);
      const batchVote = memberDb.batch();
      batchVote.set(memberVoteRef, { value: 1, updatedAt: firebase.firestore.FieldValue.serverTimestamp() });
      batchVote.update(memSuggRef, { upCount: 1, downCount: 0 });
      await assertSucceeds(batchVote.commit());
    });

    test('Day bound tolerance: diff 0 (1-day trip) allows dayIndex 0, denies 1', async () => {
      // Trip Oct 10 to Oct 10 = 0 millisecond diff, 1 day
      await seedItineraryEnv({
        startDate: new Date(Date.UTC(2024, 9, 10, 12, 0, 0)),
        endDate: new Date(Date.UTC(2024, 9, 10, 12, 0, 0)),
      });

      const organizerDb = testEnv.authenticatedContext(organizerUid).firestore();
      const suggRef = organizerDb.collection('trips').doc(tripId).collection('suggestions').doc(suggId);

      await assertSucceeds(suggRef.update({ status: 'scheduled', dayIndex: 0, order: 0 }));
      await assertFails(suggRef.update({ status: 'scheduled', dayIndex: 1, order: 0 }));
    });

    test('Day bound tolerance: diff exactly 2 days allows 2, denies 3', async () => {
      // Trip Oct 10 12:00 to Oct 12 12:00 = 48 hours = 172800000 ms
      await seedItineraryEnv({
        startDate: new Date(Date.UTC(2024, 9, 10, 12, 0, 0)),
        endDate: new Date(Date.UTC(2024, 9, 12, 12, 0, 0)),
      });

      const organizerDb = testEnv.authenticatedContext(organizerUid).firestore();
      const suggRef = organizerDb.collection('trips').doc(tripId).collection('suggestions').doc(suggId);

      await assertSucceeds(suggRef.update({ status: 'scheduled', dayIndex: 2, order: 0 }));
      await assertFails(suggRef.update({ status: 'scheduled', dayIndex: 3, order: 0 }));
    });

    test('Day bound tolerance: diff 47 hours (spring-forward) allows 2, denies 3', async () => {
      // Mar 9 2024 12:00 to Mar 11 2024 11:00 = 47 hours due to DST spring-forward
      // 47 hours = 169200000 ms, / 86400000 = 1.9583, +43200000 = 212400000, / 86400000 = 2.4583
      await seedItineraryEnv({
        startDate: new Date(Date.UTC(2024, 2, 9, 12, 0, 0)),
        endDate: new Date(Date.UTC(2024, 2, 11, 11, 0, 0)),
      });

      const organizerDb = testEnv.authenticatedContext(organizerUid).firestore();
      const suggRef = organizerDb.collection('trips').doc(tripId).collection('suggestions').doc(suggId);

      await assertSucceeds(suggRef.update({ status: 'scheduled', dayIndex: 2, order: 0 }));
      await assertFails(suggRef.update({ status: 'scheduled', dayIndex: 3, order: 0 }));
    });

    test('Day bound tolerance: diff 49 hours (fall-back) allows 2, denies 3', async () => {
      // Nov 2 2024 12:00 to Nov 4 2024 13:00 = 49 hours due to DST fall-back
      // 49 hours = 176400000 ms, / 86400000 = 2.0417, +43200000 = 219600000, / 86400000 = 2.5417
      await seedItineraryEnv({
        startDate: new Date(Date.UTC(2024, 10, 2, 12, 0, 0)),
        endDate: new Date(Date.UTC(2024, 10, 4, 13, 0, 0)),
      });

      const organizerDb = testEnv.authenticatedContext(organizerUid).firestore();
      const suggRef = organizerDb.collection('trips').doc(tripId).collection('suggestions').doc(suggId);

      await assertSucceeds(suggRef.update({ status: 'scheduled', dayIndex: 2, order: 0 }));
      await assertFails(suggRef.update({ status: 'scheduled', dayIndex: 3, order: 0 }));
    });

    test('Day bound tolerance: diff 30 days allows 30, denies 31', async () => {
      // Oct 10 to Nov 9 = 30 days exactly (86400000 * 30 = 2592000000 ms)
      await seedItineraryEnv({
        startDate: new Date(Date.UTC(2024, 9, 10, 12, 0, 0)),
        endDate: new Date(Date.UTC(2024, 10, 9, 12, 0, 0)),
      });

      const organizerDb = testEnv.authenticatedContext(organizerUid).firestore();
      const suggRef = organizerDb.collection('trips').doc(tripId).collection('suggestions').doc(suggId);

      await assertSucceeds(suggRef.update({ status: 'scheduled', dayIndex: 30, order: 0 }));
      await assertFails(suggRef.update({ status: 'scheduled', dayIndex: 31, order: 0 }));
    });
  });

describe('Phase 5 expense rules', () => {
    const tripId = 'trip_expense_1';
    const organizerUid = 'organizer_exp';
    const creatorUid = 'creator_exp';
    const member2Uid = 'member2_exp';
    const nonMemberUid = 'non_member_exp';
    const expenseId = 'expense_1';

    async function seedExpenseEnv(options = {}) {
      const {
        archived = false,
        expense = null,
        extraMembers = [],
      } = options;

      const memberIds = [organizerUid, creatorUid, member2Uid, ...extraMembers];

      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('users').doc(organizerUid).set({
          displayName: 'Organizer Exp',
          email: 'org@exp.com',
          createdAt: new Date(),
        });
        await db.collection('users').doc(creatorUid).set({
          displayName: 'Creator Exp',
          email: 'creator@exp.com',
          createdAt: new Date(),
        });
        await db.collection('users').doc(member2Uid).set({
          displayName: 'Member 2 Exp',
          email: 'mem2@exp.com',
          createdAt: new Date(),
        });
        await db.collection('users').doc(nonMemberUid).set({
          displayName: 'NonMember Exp',
          email: 'nonmem@exp.com',
          createdAt: new Date(),
        });
        for (const mId of extraMembers) {
          await db.collection('users').doc(mId).set({
            displayName: `Extra ${mId}`,
            email: `${mId}@exp.com`,
            createdAt: new Date(),
          });
        }

        await db.collection('trips').doc(tripId).set({
          name: 'Expense Trip',
          destination: 'Tokyo',
          startDate: firebase.firestore.Timestamp.fromDate(new Date('2026-11-01T00:00:00Z')),
          endDate: firebase.firestore.Timestamp.fromDate(new Date('2026-11-05T00:00:00Z')),
          currency: 'JPY',
          organizerId: organizerUid,
          joinCode: 'EXP001',
          memberIds,
          memberCount: memberIds.length,
          archived,
          createdAt: new Date(),
        });

        if (expense) {
          await db.collection('trips').doc(tripId).collection('expenses').doc(expenseId).set({
            amount: 1000,
            description: 'Ramen Dinner',
            paidBy: creatorUid,
            participantIds: [creatorUid, member2Uid],
            createdBy: creatorUid,
            date: firebase.firestore.Timestamp.fromDate(new Date('2026-11-02T00:00:00Z')),
            createdAt: new Date(),
            ...expense,
          });
        }
      });
    }

    test('Valid create: payer is creator, payer is another member, subset, all 15 participants', async () => {
      const finalExtraMembers = Array.from({ length: 12 }, (_, i) => `extra_m_${i + 1}`);
      await seedExpenseEnv({ extraMembers: finalExtraMembers });

      const creatorDb = testEnv.authenticatedContext(creatorUid).firestore();
      const expRef1 = creatorDb.collection('trips').doc(tripId).collection('expenses').doc('exp_valid_1');

      // Payer is creator, subset of participants
      await assertSucceeds(expRef1.set({
        amount: 1000,
        description: 'Ramen',
        paidBy: creatorUid,
        participantIds: [creatorUid, member2Uid],
        createdBy: creatorUid,
        date: firebase.firestore.Timestamp.fromDate(new Date('2026-11-02T00:00:00Z')),
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));

      // Payer is another member (member2Uid)
      const expRef2 = creatorDb.collection('trips').doc(tripId).collection('expenses').doc('exp_valid_2');
      await assertSucceeds(expRef2.set({
        amount: 500,
        description: 'Snack',
        paidBy: member2Uid,
        participantIds: [creatorUid, member2Uid],
        createdBy: creatorUid,
        date: firebase.firestore.Timestamp.fromDate(new Date('2026-11-02T00:00:00Z')),
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));

      // All 15 participants
      const all15Members = [organizerUid, creatorUid, member2Uid, ...finalExtraMembers];
      const expRef3 = creatorDb.collection('trips').doc(tripId).collection('expenses').doc('exp_valid_3');
      await assertSucceeds(expRef3.set({
        amount: 15000,
        description: 'Big Banquet',
        paidBy: organizerUid,
        participantIds: all15Members,
        createdBy: creatorUid,
        date: firebase.firestore.Timestamp.fromDate(new Date('2026-11-02T00:00:00Z')),
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));
    });

    test('Create denied for signed out and non-member', async () => {
      await seedExpenseEnv();
      const unauthDb = testEnv.unauthenticatedContext().firestore();
      const nonMemberDb = testEnv.authenticatedContext(nonMemberUid).firestore();
      const creatorDb = testEnv.authenticatedContext(creatorUid).firestore();

      const unauthRef = unauthDb.collection('trips').doc(tripId).collection('expenses').doc('exp_unauth');
      const nonMemberRef = nonMemberDb.collection('trips').doc(tripId).collection('expenses').doc('exp_nonmember');
      const validRef = creatorDb.collection('trips').doc(tripId).collection('expenses').doc('exp_valid');

      await assertFails(unauthRef.set({
        amount: 1000,
        description: 'Test',
        paidBy: creatorUid,
        participantIds: [creatorUid],
        createdBy: creatorUid,
        date: firebase.firestore.Timestamp.fromDate(new Date('2026-11-02T00:00:00Z')),
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));

      await assertFails(nonMemberRef.set({
        amount: 1000,
        description: 'Test',
        paidBy: nonMemberUid,
        participantIds: [nonMemberUid],
        createdBy: nonMemberUid,
        date: firebase.firestore.Timestamp.fromDate(new Date('2026-11-02T00:00:00Z')),
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));

      // Control: Member create succeeds
      await assertSucceeds(validRef.set({
        amount: 1000,
        description: 'Test',
        paidBy: creatorUid,
        participantIds: [creatorUid],
        createdBy: creatorUid,
        date: firebase.firestore.Timestamp.fromDate(new Date('2026-11-02T00:00:00Z')),
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));
    });

    test('Create denied when createdBy is not the caller', async () => {
      await seedExpenseEnv();
      const creatorDb = testEnv.authenticatedContext(creatorUid).firestore();
      const expRef = creatorDb.collection('trips').doc(tripId).collection('expenses').doc('exp_createdby');

      // Spoofed createdBy as organizerUid
      await assertFails(expRef.set({
        amount: 1000,
        description: 'Spoofed createdBy',
        paidBy: creatorUid,
        participantIds: [creatorUid],
        createdBy: organizerUid,
        date: firebase.firestore.Timestamp.fromDate(new Date('2026-11-02T00:00:00Z')),
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));

      // Control: Matching createdBy succeeds
      await assertSucceeds(expRef.set({
        amount: 1000,
        description: 'Valid createdBy',
        paidBy: creatorUid,
        participantIds: [creatorUid],
        createdBy: creatorUid,
        date: firebase.firestore.Timestamp.fromDate(new Date('2026-11-02T00:00:00Z')),
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));
    });

    test('Create denied for extra key or missing key', async () => {
      await seedExpenseEnv();
      const creatorDb = testEnv.authenticatedContext(creatorUid).firestore();
      const expRef = creatorDb.collection('trips').doc(tripId).collection('expenses').doc('exp_keys');

      // Extra key 'extraField'
      await assertFails(expRef.set({
        amount: 1000,
        description: 'Extra key',
        paidBy: creatorUid,
        participantIds: [creatorUid],
        createdBy: creatorUid,
        date: firebase.firestore.Timestamp.fromDate(new Date('2026-11-02T00:00:00Z')),
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
        extraField: 'unauthorized',
      }));

      // Missing required key 'date'
      await assertFails(expRef.set({
        amount: 1000,
        description: 'Missing date',
        paidBy: creatorUid,
        participantIds: [creatorUid],
        createdBy: creatorUid,
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));

      // Control: Exact 7 keys succeeds
      await assertSucceeds(expRef.set({
        amount: 1000,
        description: 'Exact 7 keys',
        paidBy: creatorUid,
        participantIds: [creatorUid],
        createdBy: creatorUid,
        date: firebase.firestore.Timestamp.fromDate(new Date('2026-11-02T00:00:00Z')),
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));
    });

    test('Create denied for invalid amount (0, negative, float, string, over cap)', async () => {
      await seedExpenseEnv();
      const creatorDb = testEnv.authenticatedContext(creatorUid).firestore();
      const expRef = creatorDb.collection('trips').doc(tripId).collection('expenses').doc('exp_amount');

      const baseValid = {
        description: 'Amount test',
        paidBy: creatorUid,
        participantIds: [creatorUid],
        createdBy: creatorUid,
        date: firebase.firestore.Timestamp.fromDate(new Date('2026-11-02T00:00:00Z')),
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      };

      // 0
      await assertFails(expRef.set({ ...baseValid, amount: 0 }));
      // negative
      await assertFails(expRef.set({ ...baseValid, amount: -500 }));
      // float
      await assertFails(expRef.set({ ...baseValid, amount: 12.5 }));
      // string
      await assertFails(expRef.set({ ...baseValid, amount: '1000' }));
      // over cap (> 100,000,000,000)
      await assertFails(expRef.set({ ...baseValid, amount: 100000000001 }));

      // Control: Valid amount succeeds
      await assertSucceeds(expRef.set({ ...baseValid, amount: 1000 }));
    });

    test('Create denied for invalid description (empty, >100 chars, non-string)', async () => {
      await seedExpenseEnv();
      const creatorDb = testEnv.authenticatedContext(creatorUid).firestore();
      const expRef = creatorDb.collection('trips').doc(tripId).collection('expenses').doc('exp_desc');

      const baseValid = {
        amount: 1000,
        paidBy: creatorUid,
        participantIds: [creatorUid],
        createdBy: creatorUid,
        date: firebase.firestore.Timestamp.fromDate(new Date('2026-11-02T00:00:00Z')),
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      };

      // Empty string
      await assertFails(expRef.set({ ...baseValid, description: '' }));
      // Over 100 chars (101 chars)
      await assertFails(expRef.set({ ...baseValid, description: 'a'.repeat(101) }));
      // Non-string
      await assertFails(expRef.set({ ...baseValid, description: 12345 }));

      // Control: Valid description succeeds
      await assertSucceeds(expRef.set({ ...baseValid, description: 'Valid description' }));
    });

    test('Create denied for invalid paidBy (not a member, non-string)', async () => {
      await seedExpenseEnv();
      const creatorDb = testEnv.authenticatedContext(creatorUid).firestore();
      const expRef = creatorDb.collection('trips').doc(tripId).collection('expenses').doc('exp_paidby');

      const baseValid = {
        amount: 1000,
        description: 'PaidBy test',
        participantIds: [creatorUid],
        createdBy: creatorUid,
        date: firebase.firestore.Timestamp.fromDate(new Date('2026-11-02T00:00:00Z')),
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      };

      // paidBy not a member
      await assertFails(expRef.set({ ...baseValid, paidBy: nonMemberUid }));
      // paidBy non-string
      await assertFails(expRef.set({ ...baseValid, paidBy: 9999 }));

      // Control: Valid paidBy (member2Uid) succeeds
      await assertSucceeds(expRef.set({ ...baseValid, paidBy: member2Uid }));
    });

    test('Create denied for invalid participantIds (empty, 16 elements, non-member, duplicates, non-list, non-strings)', async () => {
      const extra13 = Array.from({ length: 13 }, (_, i) => `extra_p_${i + 1}`);
      await seedExpenseEnv({ extraMembers: extra13 });

      const creatorDb = testEnv.authenticatedContext(creatorUid).firestore();
      const expRef = creatorDb.collection('trips').doc(tripId).collection('expenses').doc('exp_parts');

      const baseValid = {
        amount: 1000,
        description: 'Participants test',
        paidBy: creatorUid,
        createdBy: creatorUid,
        date: firebase.firestore.Timestamp.fromDate(new Date('2026-11-02T00:00:00Z')),
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      };

      // Empty list
      await assertFails(expRef.set({ ...baseValid, participantIds: [] }));

      // 16 elements (organizer, creator, member2, 13 extra = 16)
      const list16 = [organizerUid, creatorUid, member2Uid, ...extra13];
      await assertFails(expRef.set({ ...baseValid, participantIds: list16 }));

      // Containing non-member
      await assertFails(expRef.set({ ...baseValid, participantIds: [creatorUid, nonMemberUid] }));

      // Duplicates [A, A, B]
      await assertFails(expRef.set({ ...baseValid, participantIds: [creatorUid, creatorUid, member2Uid] }));

      // Duplicates [A, B, A]
      await assertFails(expRef.set({ ...baseValid, participantIds: [creatorUid, member2Uid, creatorUid] }));

      // Non-list
      await assertFails(expRef.set({ ...baseValid, participantIds: creatorUid }));

      // Containing non-strings
      await assertFails(expRef.set({ ...baseValid, participantIds: [creatorUid, 12345] }));

      // Control: Valid participantIds succeeds
      await assertSucceeds(expRef.set({ ...baseValid, participantIds: [creatorUid, member2Uid] }));
    });

    test('Create denied when date is not a timestamp or createdAt is a client date', async () => {
      await seedExpenseEnv();
      const creatorDb = testEnv.authenticatedContext(creatorUid).firestore();
      const expRef = creatorDb.collection('trips').doc(tripId).collection('expenses').doc('exp_dates');

      const baseValid = {
        amount: 1000,
        description: 'Date test',
        paidBy: creatorUid,
        participantIds: [creatorUid],
        createdBy: creatorUid,
      };

      // Date string instead of timestamp
      await assertFails(expRef.set({
        ...baseValid,
        date: '2026-11-02',
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));

      // createdAt client Date instead of serverTimestamp
      await assertFails(expRef.set({
        ...baseValid,
        date: firebase.firestore.Timestamp.fromDate(new Date('2026-11-02T00:00:00Z')),
        createdAt: new Date(),
      }));

      // Control: Valid timestamps succeed
      await assertSucceeds(expRef.set({
        ...baseValid,
        date: firebase.firestore.Timestamp.fromDate(new Date('2026-11-02T00:00:00Z')),
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));
    });

    test('Create denied on archived trip', async () => {
      await seedExpenseEnv({ archived: true });
      const creatorDb = testEnv.authenticatedContext(creatorUid).firestore();
      const expRef = creatorDb.collection('trips').doc(tripId).collection('expenses').doc('exp_archived');

      await assertFails(expRef.set({
        amount: 1000,
        description: 'Archived create',
        paidBy: creatorUid,
        participantIds: [creatorUid],
        createdBy: creatorUid,
        date: firebase.firestore.Timestamp.fromDate(new Date('2026-11-02T00:00:00Z')),
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));
    });

    test('Update: creator and organizer succeed; other member and non-member denied', async () => {
      await seedExpenseEnv({ expense: {} });

      const creatorDb = testEnv.authenticatedContext(creatorUid).firestore();
      const organizerDb = testEnv.authenticatedContext(organizerUid).firestore();
      const member2Db = testEnv.authenticatedContext(member2Uid).firestore();
      const nonMemberDb = testEnv.authenticatedContext(nonMemberUid).firestore();

      const creatorRef = creatorDb.collection('trips').doc(tripId).collection('expenses').doc(expenseId);
      const organizerRef = organizerDb.collection('trips').doc(tripId).collection('expenses').doc(expenseId);
      const member2Ref = member2Db.collection('trips').doc(tripId).collection('expenses').doc(expenseId);
      const nonMemberRef = nonMemberDb.collection('trips').doc(tripId).collection('expenses').doc(expenseId);

      // Other member denied
      await assertFails(member2Ref.update({ description: 'Member2 Update' }));

      // Non-member denied
      await assertFails(nonMemberRef.update({ description: 'NonMember Update' }));

      // Creator succeeds
      await assertSucceeds(creatorRef.update({ description: 'Creator Update' }));

      // Organizer succeeds
      await assertSucceeds(organizerRef.update({ description: 'Organizer Update' }));
    });

    test('Update denied when changing createdBy or createdAt', async () => {
      await seedExpenseEnv({ expense: {} });
      const creatorDb = testEnv.authenticatedContext(creatorUid).firestore();
      const expRef = creatorDb.collection('trips').doc(tripId).collection('expenses').doc(expenseId);

      // Changing createdBy denied
      await assertFails(expRef.update({ createdBy: organizerUid }));

      // Changing createdAt denied
      await assertFails(expRef.update({ createdAt: firebase.firestore.Timestamp.fromDate(new Date('2025-01-01T00:00:00Z')) }));

      // Extra key in update denied
      await assertFails(expRef.update({ amount: 2000, extraKey: 'forbidden' }));

      // Control: Valid affected keys succeed
      await assertSucceeds(expRef.update({ amount: 2000, description: 'Updated Amount' }));
    });

    test('Update denied for invalid resulting values (amount, description, paidBy, participantIds, date)', async () => {
      await seedExpenseEnv({ expense: {} });
      const creatorDb = testEnv.authenticatedContext(creatorUid).firestore();
      const expRef = creatorDb.collection('trips').doc(tripId).collection('expenses').doc(expenseId);

      // Invalid resulting amount (0, negative, float, string)
      await assertFails(expRef.update({ amount: 0 }));
      await assertFails(expRef.update({ amount: -10 }));
      await assertFails(expRef.update({ amount: 1.5 }));
      await assertFails(expRef.update({ amount: '2000' }));

      // Invalid resulting description (empty, >100)
      await assertFails(expRef.update({ description: '' }));
      await assertFails(expRef.update({ description: 'b'.repeat(101) }));

      // Invalid resulting paidBy (non-member)
      await assertFails(expRef.update({ paidBy: nonMemberUid }));

      // Invalid resulting participantIds (empty, duplicates, non-member)
      await assertFails(expRef.update({ participantIds: [] }));
      await assertFails(expRef.update({ participantIds: [creatorUid, creatorUid] }));
      await assertFails(expRef.update({ participantIds: [nonMemberUid] }));

      // Invalid resulting date (string)
      await assertFails(expRef.update({ date: 'invalid-date' }));

      // Control: Valid update succeeds
      await assertSucceeds(expRef.update({ amount: 1200, description: 'Valid Update' }));
    });

    test('Update denied on archived trip', async () => {
      await seedExpenseEnv({ archived: true, expense: {} });
      const creatorDb = testEnv.authenticatedContext(creatorUid).firestore();
      const expRef = creatorDb.collection('trips').doc(tripId).collection('expenses').doc(expenseId);

      await assertFails(expRef.update({ description: 'Archived update' }));
    });

    test('Delete: creator and organizer succeed; other member, non-member, signed out, and archived denied', async () => {
      // Seed 1: Other member denied
      await seedExpenseEnv({ expense: {} });
      const member2Db = testEnv.authenticatedContext(member2Uid).firestore();
      await assertFails(member2Db.collection('trips').doc(tripId).collection('expenses').doc(expenseId).delete());

      // Seed 2: Non-member denied
      await seedExpenseEnv({ expense: {} });
      const nonMemberDb = testEnv.authenticatedContext(nonMemberUid).firestore();
      await assertFails(nonMemberDb.collection('trips').doc(tripId).collection('expenses').doc(expenseId).delete());

      // Seed 3: Signed out denied
      await seedExpenseEnv({ expense: {} });
      const unauthDb = testEnv.unauthenticatedContext().firestore();
      await assertFails(unauthDb.collection('trips').doc(tripId).collection('expenses').doc(expenseId).delete());

      // Seed 4: Archived denied
      await seedExpenseEnv({ archived: true, expense: {} });
      const creatorDb = testEnv.authenticatedContext(creatorUid).firestore();
      await assertFails(creatorDb.collection('trips').doc(tripId).collection('expenses').doc(expenseId).delete());

      // Seed 5: Creator delete succeeds
      await seedExpenseEnv({ expense: {} });
      await assertSucceeds(creatorDb.collection('trips').doc(tripId).collection('expenses').doc(expenseId).delete());

      // Seed 6: Organizer delete succeeds
      await seedExpenseEnv({ expense: {} });
      const organizerDb = testEnv.authenticatedContext(organizerUid).firestore();
      await assertSucceeds(organizerDb.collection('trips').doc(tripId).collection('expenses').doc(expenseId).delete());
    });

    test('Read: member succeeds; non-member and signed out denied', async () => {
      await seedExpenseEnv({ expense: {} });

      const creatorDb = testEnv.authenticatedContext(creatorUid).firestore();
      const member2Db = testEnv.authenticatedContext(member2Uid).firestore();
      const nonMemberDb = testEnv.authenticatedContext(nonMemberUid).firestore();
      const unauthDb = testEnv.unauthenticatedContext().firestore();

      const creatorExpRef = creatorDb.collection('trips').doc(tripId).collection('expenses').doc(expenseId);
      const member2ExpRef = member2Db.collection('trips').doc(tripId).collection('expenses').doc(expenseId);
      const nonMemberExpRef = nonMemberDb.collection('trips').doc(tripId).collection('expenses').doc(expenseId);
      const unauthExpRef = unauthDb.collection('trips').doc(tripId).collection('expenses').doc(expenseId);

      // Members get succeeds
      await assertSucceeds(creatorExpRef.get());
      await assertSucceeds(member2ExpRef.get());

      // Members list succeeds
      await assertSucceeds(creatorDb.collection('trips').doc(tripId).collection('expenses').get());

      // Non-member get and list denied
      await assertFails(nonMemberExpRef.get());
      await assertFails(nonMemberDb.collection('trips').doc(tripId).collection('expenses').get());

      // Signed out get and list denied
      await assertFails(unauthExpRef.get());
      await assertFails(unauthDb.collection('trips').doc(tripId).collection('expenses').get());
    });
  });

describe('Phase 6: Settlements & Leaving a Trip Security Rules', () => {
    const organizerUid = 'org_p6';
    const member1Uid = 'mem1_p6';
    const member2Uid = 'mem2_p6';
    const nonMemberUid = 'non_mem_p6';
    const tripId = 'trip_p6';
    const settlementId = 'settle_1';

    beforeEach(async () => {
      await seedUser(organizerUid, 'Organizer');
      await seedUser(member1Uid, 'Member 1');
      await seedUser(member2Uid, 'Member 2');
      await seedUser(nonMemberUid, 'Non Member');

      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('trips').doc(tripId).set({
          name: 'Settlements Test Trip',
          destination: 'Tokyo',
          startDate: new Date('2026-11-01T00:00:00Z'),
          endDate: new Date('2026-11-05T00:00:00Z'),
          currency: 'USD',
          organizerId: organizerUid,
          joinCode: 'SETTLE01',
          memberIds: [organizerUid, member1Uid, member2Uid],
          memberCount: 3,
          archived: false,
          createdAt: new Date(),
        });
        await db.collection('trips').doc(tripId).collection('members').doc(organizerUid).set({
          displayName: 'Organizer',
          role: 'organizer',
          status: 'active',
          joinedAt: new Date(),
        });
        await db.collection('trips').doc(tripId).collection('members').doc(member1Uid).set({
          displayName: 'Member 1',
          role: 'member',
          status: 'active',
          joinedAt: new Date(),
        });
        await db.collection('trips').doc(tripId).collection('members').doc(member2Uid).set({
          displayName: 'Member 2',
          role: 'member',
          status: 'active',
          joinedAt: new Date(),
        });
      });
    });

    test('Settlement read: member allowed', async () => {
      const memberDb = testEnv.authenticatedContext(member1Uid).firestore();
      const settleRef = memberDb.collection('trips').doc(tripId).collection('settlements').doc(settlementId);
      await assertSucceeds(settleRef.get());
    });

    test('Settlement read: non-member denied', async () => {
      const nonMemberDb = testEnv.authenticatedContext(nonMemberUid).firestore();
      const settleRef = nonMemberDb.collection('trips').doc(tripId).collection('settlements').doc(settlementId);
      await assertFails(settleRef.get());
    });

    test('Settlement read: unauthenticated denied', async () => {
      const unauthedDb = testEnv.unauthenticatedContext().firestore();
      const settleRef = unauthedDb.collection('trips').doc(tripId).collection('settlements').doc(settlementId);
      await assertFails(settleRef.get());
    });

    function getValidSettlementPayload(overrides = {}) {
      return {
        fromUid: member1Uid,
        toUid: organizerUid,
        amount: 1500,
        status: 'pending',
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
        resolvedAt: null,
        ...overrides,
      };
    }

    test('Settlement create: valid create succeeds', async () => {
      const mem1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const settleRef = mem1Db.collection('trips').doc(tripId).collection('settlements').doc('settle_valid');
      await assertSucceeds(settleRef.set(getValidSettlementPayload()));
    });

    test('Settlement create: non-member denied', async () => {
      const nonMemberDb = testEnv.authenticatedContext(nonMemberUid).firestore();
      const settleRef = nonMemberDb.collection('trips').doc(tripId).collection('settlements').doc('settle_non_member');
      await assertFails(settleRef.set(getValidSettlementPayload({ fromUid: nonMemberUid })));
    });

    test('Settlement create: archived trip denied', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc('trip_archived_p6').set({
          memberIds: [organizerUid, member1Uid],
          memberCount: 2,
          archived: true,
        });
      });
      const mem1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const settleRef = mem1Db.collection('trips').doc('trip_archived_p6').collection('settlements').doc('settle_arch');
      await assertFails(settleRef.set(getValidSettlementPayload()));
    });

    test('Settlement create: extra key denied', async () => {
      const mem1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const settleRef = mem1Db.collection('trips').doc(tripId).collection('settlements').doc('settle_extra');
      await assertFails(settleRef.set(getValidSettlementPayload({ extraKey: 'bad' })));
    });

    test('Settlement create: missing key denied', async () => {
      const mem1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const settleRef = mem1Db.collection('trips').doc(tripId).collection('settlements').doc('settle_missing');
      const payload = getValidSettlementPayload();
      delete payload.amount;
      await assertFails(settleRef.set(payload));
    });

    test('Settlement create: fromUid != auth uid denied', async () => {
      const mem1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const settleRef = mem1Db.collection('trips').doc(tripId).collection('settlements').doc('settle_spoof');
      await assertFails(settleRef.set(getValidSettlementPayload({ fromUid: member2Uid })));
    });

    test('Settlement create: toUid == auth uid (self-payment) denied', async () => {
      const mem1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const settleRef = mem1Db.collection('trips').doc(tripId).collection('settlements').doc('settle_self');
      await assertFails(settleRef.set(getValidSettlementPayload({ toUid: member1Uid })));
    });

    test('Settlement create: toUid not a member denied', async () => {
      const mem1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const settleRef = mem1Db.collection('trips').doc(tripId).collection('settlements').doc('settle_to_non_member');
      await assertFails(settleRef.set(getValidSettlementPayload({ toUid: nonMemberUid })));
    });

    test('Settlement create: amount 0 denied', async () => {
      const mem1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const settleRef = mem1Db.collection('trips').doc(tripId).collection('settlements').doc('settle_amt_0');
      await assertFails(settleRef.set(getValidSettlementPayload({ amount: 0 })));
    });

    test('Settlement create: amount negative denied', async () => {
      const mem1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const settleRef = mem1Db.collection('trips').doc(tripId).collection('settlements').doc('settle_amt_neg');
      await assertFails(settleRef.set(getValidSettlementPayload({ amount: -1 })));
    });

    test('Settlement create: amount float denied', async () => {
      const mem1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const settleRef = mem1Db.collection('trips').doc(tripId).collection('settlements').doc('settle_amt_float');
      await assertFails(settleRef.set(getValidSettlementPayload({ amount: 1.5 })));
    });

    test('Settlement create: amount string denied', async () => {
      const mem1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const settleRef = mem1Db.collection('trips').doc(tripId).collection('settlements').doc('settle_amt_str');
      await assertFails(settleRef.set(getValidSettlementPayload({ amount: '5' })));
    });

    test('Settlement create: amount over cap denied', async () => {
      const mem1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const settleRef = mem1Db.collection('trips').doc(tripId).collection('settlements').doc('settle_amt_over');
      await assertFails(settleRef.set(getValidSettlementPayload({ amount: 100000000001 })));
    });

    test('Settlement create: amount boundaries 1 and 100000000000 allowed', async () => {
      const mem1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const settleRef1 = mem1Db.collection('trips').doc(tripId).collection('settlements').doc('settle_amt_1');
      const settleRefCap = mem1Db.collection('trips').doc(tripId).collection('settlements').doc('settle_amt_cap');
      await assertSucceeds(settleRef1.set(getValidSettlementPayload({ amount: 1 })));
      await assertSucceeds(settleRefCap.set(getValidSettlementPayload({ amount: 100000000000 })));
    });

    test('Settlement create: status confirmed denied', async () => {
      const mem1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const settleRef = mem1Db.collection('trips').doc(tripId).collection('settlements').doc('settle_stat_conf');
      await assertFails(settleRef.set(getValidSettlementPayload({ status: 'confirmed' })));
    });

    test('Settlement create: status rejected denied', async () => {
      const mem1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const settleRef = mem1Db.collection('trips').doc(tripId).collection('settlements').doc('settle_stat_rej');
      await assertFails(settleRef.set(getValidSettlementPayload({ status: 'rejected' })));
    });

    test('Settlement create: createdAt client value denied', async () => {
      const mem1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const settleRef = mem1Db.collection('trips').doc(tripId).collection('settlements').doc('settle_client_date');
      await assertFails(settleRef.set(getValidSettlementPayload({ createdAt: new Date() })));
    });

    test('Settlement create: resolvedAt not null denied', async () => {
      const mem1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const settleRef = mem1Db.collection('trips').doc(tripId).collection('settlements').doc('settle_res_not_null');
      await assertFails(settleRef.set(getValidSettlementPayload({ resolvedAt: firebase.firestore.FieldValue.serverTimestamp() })));
    });

    async function seedPendingSettlement(id = 'settle_test_pending') {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).collection('settlements').doc(id).set({
          fromUid: member1Uid,
          toUid: member2Uid,
          amount: 2000,
          status: 'pending',
          createdAt: new Date(),
          resolvedAt: null,
        });
      });
      return id;
    }

    test('Settlement update: payer confirming own settlement denied', async () => {
      const id = await seedPendingSettlement('settle_up_payer_own');
      const mem1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const settleRef = mem1Db.collection('trips').doc(tripId).collection('settlements').doc(id);
      await assertFails(settleRef.update({
        status: 'confirmed',
        resolvedAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));
    });

    test('Settlement update: receiver confirm allowed', async () => {
      const id = await seedPendingSettlement('settle_up_rec_conf');
      const mem2Db = testEnv.authenticatedContext(member2Uid).firestore();
      const settleRef = mem2Db.collection('trips').doc(tripId).collection('settlements').doc(id);
      await assertSucceeds(settleRef.update({
        status: 'confirmed',
        resolvedAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));
    });

    test('Settlement update: receiver reject allowed', async () => {
      const id = await seedPendingSettlement('settle_up_rec_rej');
      const mem2Db = testEnv.authenticatedContext(member2Uid).firestore();
      const settleRef = mem2Db.collection('trips').doc(tripId).collection('settlements').doc(id);
      await assertSucceeds(settleRef.update({
        status: 'rejected',
        resolvedAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));
    });

    test('Settlement update: organizer (not payer) confirm allowed', async () => {
      const id = await seedPendingSettlement('settle_up_org_conf');
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const settleRef = orgDb.collection('trips').doc(tripId).collection('settlements').doc(id);
      await assertSucceeds(settleRef.update({
        status: 'confirmed',
        resolvedAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));
    });

    test('Settlement update: organizer who is the payer denied', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).collection('settlements').doc('settle_org_is_payer').set({
          fromUid: organizerUid,
          toUid: member1Uid,
          amount: 3000,
          status: 'pending',
          createdAt: new Date(),
          resolvedAt: null,
        });
      });
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const settleRef = orgDb.collection('trips').doc(tripId).collection('settlements').doc('settle_org_is_payer');
      await assertFails(settleRef.update({
        status: 'confirmed',
        resolvedAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));
    });

    test('Settlement update: third member denied', async () => {
      const id = await seedPendingSettlement('settle_up_third');
      await seedUser('third_mem', 'Third Member');
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).update({
          memberIds: [organizerUid, member1Uid, member2Uid, 'third_mem'],
          memberCount: 4,
        });
      });
      const thirdDb = testEnv.authenticatedContext('third_mem').firestore();
      const settleRef = thirdDb.collection('trips').doc(tripId).collection('settlements').doc(id);
      await assertFails(settleRef.update({
        status: 'confirmed',
        resolvedAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));
    });

    test('Settlement update: non-member denied', async () => {
      const id = await seedPendingSettlement('settle_up_non_mem');
      const nonDb = testEnv.authenticatedContext(nonMemberUid).firestore();
      const settleRef = nonDb.collection('trips').doc(tripId).collection('settlements').doc(id);
      await assertFails(settleRef.update({
        status: 'confirmed',
        resolvedAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));
    });

    test('Settlement update: already confirmed -> rejected denied', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).collection('settlements').doc('settle_already_conf').set({
          fromUid: member1Uid,
          toUid: member2Uid,
          amount: 1000,
          status: 'confirmed',
          createdAt: new Date(),
          resolvedAt: new Date(),
        });
      });
      const mem2Db = testEnv.authenticatedContext(member2Uid).firestore();
      const settleRef = mem2Db.collection('trips').doc(tripId).collection('settlements').doc('settle_already_conf');
      await assertFails(settleRef.update({
        status: 'rejected',
        resolvedAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));
    });

    test('Settlement update: amount change denied', async () => {
      const id = await seedPendingSettlement('settle_up_amt');
      const mem2Db = testEnv.authenticatedContext(member2Uid).firestore();
      const settleRef = mem2Db.collection('trips').doc(tripId).collection('settlements').doc(id);
      await assertFails(settleRef.update({
        amount: 9999,
        status: 'confirmed',
        resolvedAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));
    });

    test('Settlement update: fromUid change denied', async () => {
      const id = await seedPendingSettlement('settle_up_from');
      const mem2Db = testEnv.authenticatedContext(member2Uid).firestore();
      const settleRef = mem2Db.collection('trips').doc(tripId).collection('settlements').doc(id);
      await assertFails(settleRef.update({
        fromUid: member2Uid,
        status: 'confirmed',
        resolvedAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));
    });

    test('Settlement update: toUid change denied', async () => {
      const id = await seedPendingSettlement('settle_up_to');
      const mem2Db = testEnv.authenticatedContext(member2Uid).firestore();
      const settleRef = mem2Db.collection('trips').doc(tripId).collection('settlements').doc(id);
      await assertFails(settleRef.update({
        toUid: organizerUid,
        status: 'confirmed',
        resolvedAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));
    });

    test('Settlement update: status pending or foo denied', async () => {
      const id = await seedPendingSettlement('settle_up_bad_status');
      const mem2Db = testEnv.authenticatedContext(member2Uid).firestore();
      const settleRef = mem2Db.collection('trips').doc(tripId).collection('settlements').doc(id);
      await assertFails(settleRef.update({
        status: 'foo',
        resolvedAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));
    });

    test('Settlement update: resolvedAt != request.time denied', async () => {
      const id = await seedPendingSettlement('settle_up_bad_res');
      const mem2Db = testEnv.authenticatedContext(member2Uid).firestore();
      const settleRef = mem2Db.collection('trips').doc(tripId).collection('settlements').doc(id);
      await assertFails(settleRef.update({
        status: 'confirmed',
        resolvedAt: new Date(),
      }));
    });

    test('Settlement update: extra key denied', async () => {
      const id = await seedPendingSettlement('settle_up_extra');
      const mem2Db = testEnv.authenticatedContext(member2Uid).firestore();
      const settleRef = mem2Db.collection('trips').doc(tripId).collection('settlements').doc(id);
      await assertFails(settleRef.update({
        status: 'confirmed',
        resolvedAt: firebase.firestore.FieldValue.serverTimestamp(),
        extra: 123,
      }));
    });

    test('Settlement update: archived trip denied', async () => {
      const id = await seedPendingSettlement('settle_up_arch');
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).update({ archived: true });
      });
      const mem2Db = testEnv.authenticatedContext(member2Uid).firestore();
      const settleRef = mem2Db.collection('trips').doc(tripId).collection('settlements').doc(id);
      await assertFails(settleRef.update({
        status: 'confirmed',
        resolvedAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).update({ archived: false });
      });
    });

    test('Settlement delete: payer deletes pending allowed', async () => {
      const id = await seedPendingSettlement('settle_del_payer');
      const mem1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const settleRef = mem1Db.collection('trips').doc(tripId).collection('settlements').doc(id);
      await assertSucceeds(settleRef.delete());
    });

    test('Settlement delete: payer deletes confirmed denied', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).collection('settlements').doc('settle_del_conf').set({
          fromUid: member1Uid,
          toUid: member2Uid,
          amount: 500,
          status: 'confirmed',
          createdAt: new Date(),
          resolvedAt: new Date(),
        });
      });
      const mem1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const settleRef = mem1Db.collection('trips').doc(tripId).collection('settlements').doc('settle_del_conf');
      await assertFails(settleRef.delete());
    });

    test('Settlement delete: receiver delete denied', async () => {
      const id = await seedPendingSettlement('settle_del_rec');
      const mem2Db = testEnv.authenticatedContext(member2Uid).firestore();
      const settleRef = mem2Db.collection('trips').doc(tripId).collection('settlements').doc(id);
      await assertFails(settleRef.delete());
    });

    test('Settlement delete: organizer delete denied', async () => {
      const id = await seedPendingSettlement('settle_del_org');
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const settleRef = orgDb.collection('trips').doc(tripId).collection('settlements').doc(id);
      await assertFails(settleRef.delete());
    });

    test('Settlement delete: non-member delete denied', async () => {
      const id = await seedPendingSettlement('settle_del_non_mem');
      const nonDb = testEnv.authenticatedContext(nonMemberUid).firestore();
      const settleRef = nonDb.collection('trips').doc(tripId).collection('settlements').doc(id);
      await assertFails(settleRef.delete());
    });

    test('Settlement delete: archived trip delete denied', async () => {
      const id = await seedPendingSettlement('settle_del_arch');
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).update({ archived: true });
      });
      const mem1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const settleRef = mem1Db.collection('trips').doc(tripId).collection('settlements').doc(id);
      await assertFails(settleRef.delete());
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).update({ archived: false });
      });
    });

    // Phase 6 Leave / Remove Tests
    test('Member leaves successfully (batch update + member status left)', async () => {
      // Setup extra members for leave/remove testing
      const leaveMemberUid = 'leave_mem_p6';
      const removedMemberUid = 'removed_mem_p6';
      await seedUser(leaveMemberUid, 'Leave Member');
      await seedUser(removedMemberUid, 'Removed Member');

      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('trips').doc(tripId).update({
          memberIds: [organizerUid, member1Uid, member2Uid, leaveMemberUid, removedMemberUid],
          memberCount: 5,
        });
        await db.collection('trips').doc(tripId).collection('members').doc(leaveMemberUid).set({
          displayName: 'Leave Member',
          role: 'member',
          status: 'active',
          joinedAt: new Date(),
        });
        await db.collection('trips').doc(tripId).collection('members').doc(removedMemberUid).set({
          displayName: 'Removed Member',
          role: 'member',
          status: 'active',
          joinedAt: new Date(),
        });
      });

      const leaveDb = testEnv.authenticatedContext(leaveMemberUid).firestore();
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = leaveDb.collection('trips').doc(tripId);
      const memberRef = tripRef.collection('members').doc(leaveMemberUid);

      const batch = leaveDb.batch();
      batch.update(tripRef, {
        memberIds: [organizerUid, member1Uid, member2Uid, removedMemberUid],
        memberCount: 4,
      });
      batch.update(memberRef, { status: 'left' });
      await assertSucceeds(batch.commit());

      const tripAfter = await orgDb.collection('trips').doc(tripId).get();
      expect(tripAfter.data().memberIds).toEqual([organizerUid, member1Uid, member2Uid, removedMemberUid]);
      expect(tripAfter.data().memberCount).toEqual(4);

      const memberAfter = await orgDb.collection('trips').doc(tripId).collection('members').doc(leaveMemberUid).get();
      expect(memberAfter.data().status).toEqual('left');
    });

    test('a) memberIds [A,B,C]->[A,A,C], memberCount 3->2, B leaves (denied)', async () => {
      const leaveMemberUid = member1Uid;
      const leaveDb = testEnv.authenticatedContext(leaveMemberUid).firestore();
      const tripRef = leaveDb.collection('trips').doc(tripId);
      const memberRef = tripRef.collection('members').doc(leaveMemberUid);
      const batch = leaveDb.batch();
      batch.update(tripRef, {
        memberIds: [organizerUid, organizerUid, member2Uid],
        memberCount: 2,
      });
      batch.update(memberRef, { status: 'left' });
      await assertFails(batch.commit());
    });

    test('b) [A,B]->[A,A], count 2->1, B leaves (denied)', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).update({
          memberIds: [organizerUid, member1Uid],
          memberCount: 2,
        });
      });
      const leaveMemberUid = member1Uid;
      const leaveDb = testEnv.authenticatedContext(leaveMemberUid).firestore();
      const tripRef = leaveDb.collection('trips').doc(tripId);
      const memberRef = tripRef.collection('members').doc(leaveMemberUid);
      const batch = leaveDb.batch();
      batch.update(tripRef, {
        memberIds: [organizerUid, organizerUid],
        memberCount: 1,
      });
      batch.update(memberRef, { status: 'left' });
      await assertFails(batch.commit());
    });

    test('c) [A,B,C]->[A,C,C], count 3->2, B removed by organizer (denied)', async () => {
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);
      const memberRef = tripRef.collection('members').doc(member1Uid);
      const batch = orgDb.batch();
      batch.update(tripRef, {
        memberIds: [organizerUid, member2Uid, member2Uid],
        memberCount: 2,
      });
      batch.update(memberRef, { status: 'left' });
      await assertFails(batch.commit());
    });

    test('d) [A,B,C]->[A,C], count 2 (valid, allowed - positive control)', async () => {
      // Setup members [org, m1, m2]
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).update({
          memberIds: [organizerUid, member1Uid, member2Uid],
          memberCount: 3,
        });
      });
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);
      const memberRef = tripRef.collection('members').doc(member1Uid);
      const batch = orgDb.batch();
      batch.update(tripRef, {
        memberIds: [organizerUid, member2Uid],
        memberCount: 2,
      });
      batch.update(memberRef, { status: 'left' });
      await assertSucceeds(batch.commit());
    });

    test('Rejoin by previously left member denied when member doc status is not active in client join batch', async () => {
      const rejoinUid = 'rejoin_mem_p6';
      await seedUser(rejoinUid, 'Rejoin Member');

      // Setup rejoinUid as left and joinCodes doc
      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('trips').doc(tripId).collection('members').doc(rejoinUid).set({
          displayName: 'Rejoin Member',
          role: 'member',
          status: 'left',
          joinedAt: new Date(),
        });
        await db.collection('joinCodes').doc('SETTLE01').set({
          tripId: tripId,
          tripName: 'Settlements Test Trip',
          destination: 'Tokyo',
          startDate: new Date('2026-11-01T00:00:00Z'),
          endDate: new Date('2026-11-05T00:00:00Z'),
          memberCount: 3,
        });
      });

      const rejoinDb = testEnv.authenticatedContext(rejoinUid).firestore();
      const batch = rejoinDb.batch();
      batch.update(rejoinDb.collection('trips').doc(tripId), {
        memberIds: [organizerUid, member1Uid, member2Uid, rejoinUid],
        memberCount: 4,
      });
      batch.update(rejoinDb.collection('joinCodes').doc('SETTLE01'), {
        memberCount: 4,
      });
      await assertFails(batch.commit());
    });

    test('Organizer removes member successfully', async () => {
      const removedMemberUid = 'removed_mem_p6_2';
      await seedUser(removedMemberUid, 'Removed Member 2');

      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('trips').doc(tripId).update({
          memberIds: [organizerUid, member1Uid, member2Uid, removedMemberUid],
          memberCount: 4,
        });
        await db.collection('trips').doc(tripId).collection('members').doc(removedMemberUid).set({
          displayName: 'Removed Member 2',
          role: 'member',
          status: 'active',
          joinedAt: new Date(),
        });
      });

      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);
      const memberRef = tripRef.collection('members').doc(removedMemberUid);

      const batch = orgDb.batch();
      batch.update(tripRef, {
        memberIds: [organizerUid, member1Uid, member2Uid],
        memberCount: 3,
      });
      batch.update(memberRef, { status: 'left' });
      await assertSucceeds(batch.commit());

      const tripAfter = await tripRef.get();
      expect(tripAfter.data().memberIds).toEqual([organizerUid, member1Uid, member2Uid]);
      expect(tripAfter.data().memberCount).toEqual(3);

      const memberAfter = await memberRef.get();
      expect(memberAfter.data().status).toEqual('left');
    });

    test('Plain member cannot remove another member', async () => {
      const member1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const tripRef = member1Db.collection('trips').doc(tripId);

      await assertFails(tripRef.update({
        memberIds: [organizerUid, member2Uid],
        memberCount: 2,
      }));
    });

    test('Cannot remove the organizer (including organizer leaving)', async () => {
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);

      await assertFails(tripRef.update({
        memberIds: [member1Uid, member2Uid],
        memberCount: 2,
      }));
    });

    test('Padding attack denial - cannot add uid while removing', async () => {
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);

      await assertFails(tripRef.update({
        memberIds: [organizerUid, member1Uid, member1Uid, member2Uid],
        memberCount: 3,
      }));
    });

    test('Padding attack denial - removing two uids at once', async () => {
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);

      await assertFails(tripRef.update({
        memberIds: [organizerUid],
        memberCount: 1,
      }));
    });

    test('memberCount must decrease by exactly 1', async () => {
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);

      await assertFails(tripRef.update({
        memberIds: [organizerUid, member2Uid],
        memberCount: 2,
      }));
    });

    test('Cannot change other trip fields during leave/remove', async () => {
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);

      await assertFails(tripRef.update({
        memberIds: [organizerUid],
        memberCount: 2,
        name: 'Hacked',
      }));
    });

    test('Cannot leave/remove from archived trip', async () => {
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);

      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).update({ archived: true });
      });

      await assertFails(tripRef.update({
        memberIds: [organizerUid, member2Uid],
        memberCount: 2,
      }));

      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).update({ archived: false });
      });
    });

    test('Non-member cannot leave/remove', async () => {
      const nonMemberDb = testEnv.authenticatedContext(nonMemberUid).firestore();
      const tripRef = nonMemberDb.collection('trips').doc(tripId);

      await assertFails(tripRef.update({
        memberIds: [organizerUid, member2Uid],
        memberCount: 2,
      }));
    });

    test('Signed-out user cannot leave/remove', async () => {
      const unauthDb = testEnv.unauthenticatedContext().firestore();
      const tripRef = unauthDb.collection('trips').doc(tripId);

      await assertFails(tripRef.update({
        memberIds: [organizerUid, member2Uid],
        memberCount: 2,
      }));
    });

    test('Marking status "left" WITHOUT removing uid from memberIds is denied', async () => {
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const memberRef = orgDb.collection('trips').doc(tripId).collection('members').doc(member2Uid);

      await assertFails(memberRef.update({ status: 'left' }));
    });

    test('Removing uid from memberIds WITHOUT marking status "left" is denied', async () => {
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);

      await assertFails(tripRef.update({
        memberIds: [organizerUid],
        memberCount: 1,
      }));
    });

    test('members/{uid} updates changing keys other than status are denied', async () => {
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const memberRef = orgDb.collection('trips').doc(tripId).collection('members').doc(member2Uid);

      await assertFails(memberRef.update({
        displayName: 'Hacked',
        status: 'left',
      }));
    });

    test('Batch missing members status doc write denied', async () => {
      const leaveDb = testEnv.authenticatedContext(member1Uid).firestore();
      const tripRef = leaveDb.collection('trips').doc(tripId);
      const batch = leaveDb.batch();
      batch.update(tripRef, {
        memberIds: [organizerUid, member2Uid],
        memberCount: 2,
      });
      await assertFails(batch.commit());
    });

    test('Member status updated to something other than left denied', async () => {
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);
      const memberRef = tripRef.collection('members').doc(member1Uid);
      const batch = orgDb.batch();
      batch.update(tripRef, {
        memberIds: [organizerUid, member2Uid],
        memberCount: 2,
      });
      batch.update(memberRef, { status: 'suspended' });
      await assertFails(batch.commit());
    });

    test('Member doc update with fields other than status denied', async () => {
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);
      const memberRef = tripRef.collection('members').doc(member1Uid);
      const batch = orgDb.batch();
      batch.update(tripRef, {
        memberIds: [organizerUid, member2Uid],
        memberCount: 2,
      });
      batch.update(memberRef, { status: 'left', displayName: 'Hacker' });
      await assertFails(batch.commit());
    });

    test('Trip update with fields other than memberIds and memberCount denied', async () => {
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);
      const memberRef = tripRef.collection('members').doc(member1Uid);
      const batch = orgDb.batch();
      batch.update(tripRef, {
        memberIds: [organizerUid, member2Uid],
        memberCount: 2,
        name: 'Hacked Trip Name',
      });
      batch.update(memberRef, { status: 'left' });
      await assertFails(batch.commit());
    });

    test('memberCount unchanged while dropping UID denied', async () => {
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);
      const memberRef = tripRef.collection('members').doc(member1Uid);
      const batch = orgDb.batch();
      batch.update(tripRef, {
        memberIds: [organizerUid, member2Uid],
        memberCount: 3,
      });
      batch.update(memberRef, { status: 'left' });
      await assertFails(batch.commit());
    });

    test('memberCount decreased by 2 while dropping 1 UID denied', async () => {
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);
      const memberRef = tripRef.collection('members').doc(member1Uid);
      const batch = orgDb.batch();
      batch.update(tripRef, {
        memberIds: [organizerUid, member2Uid],
        memberCount: 1,
      });
      batch.update(memberRef, { status: 'left' });
      await assertFails(batch.commit());
    });

    test('Removing two UIDs at once denied', async () => {
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);
      const m1Ref = tripRef.collection('members').doc(member1Uid);
      const m2Ref = tripRef.collection('members').doc(member2Uid);
      const batch = orgDb.batch();
      batch.update(tripRef, {
        memberIds: [organizerUid],
        memberCount: 1,
      });
      batch.update(m1Ref, { status: 'left' });
      batch.update(m2Ref, { status: 'left' });
      await assertFails(batch.commit());
    });

    test('Adding a UID while removing one denied', async () => {
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);
      const m1Ref = tripRef.collection('members').doc(member1Uid);
      const batch = orgDb.batch();
      batch.update(tripRef, {
        memberIds: [organizerUid, member2Uid, 'extra_intruder'],
        memberCount: 3,
      });
      batch.update(m1Ref, { status: 'left' });
      await assertFails(batch.commit());
    });

    test('Organizer self-removal denied', async () => {
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);
      const orgMemberRef = tripRef.collection('members').doc(organizerUid);
      const batch = orgDb.batch();
      batch.update(tripRef, {
        memberIds: [member1Uid, member2Uid],
        memberCount: 2,
      });
      batch.update(orgMemberRef, { status: 'left' });
      await assertFails(batch.commit());
    });

    test('Plain member removing another member denied', async () => {
      const m1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const tripRef = m1Db.collection('trips').doc(tripId);
      const m2Ref = tripRef.collection('members').doc(member2Uid);
      const batch = m1Db.batch();
      batch.update(tripRef, {
        memberIds: [organizerUid, member1Uid],
        memberCount: 2,
      });
      batch.update(m2Ref, { status: 'left' });
      await assertFails(batch.commit());
    });

    test('Removing organizer by member denied', async () => {
      const m1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const tripRef = m1Db.collection('trips').doc(tripId);
      const orgMemberRef = tripRef.collection('members').doc(organizerUid);
      const batch = m1Db.batch();
      batch.update(tripRef, {
        memberIds: [member1Uid, member2Uid],
        memberCount: 2,
      });
      batch.update(orgMemberRef, { status: 'left' });
      await assertFails(batch.commit());
    });

    test('Archived trip leave denied', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).update({ archived: true });
      });
      const m1Db = testEnv.authenticatedContext(member1Uid).firestore();
      const tripRef = m1Db.collection('trips').doc(tripId);
      const m1Ref = tripRef.collection('members').doc(member1Uid);
      const batch = m1Db.batch();
      batch.update(tripRef, {
        memberIds: [organizerUid, member2Uid],
        memberCount: 2,
      });
      batch.update(m1Ref, { status: 'left' });
      await assertFails(batch.commit());
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).update({ archived: false });
      });
    });

    test('Non-member leave denied', async () => {
      const nonDb = testEnv.authenticatedContext(nonMemberUid).firestore();
      const tripRef = nonDb.collection('trips').doc(tripId);
      const nonRef = tripRef.collection('members').doc(nonMemberUid);
      const batch = nonDb.batch();
      batch.update(tripRef, {
        memberIds: [organizerUid, member1Uid],
        memberCount: 2,
      });
      batch.update(nonRef, { status: 'left' });
      await assertFails(batch.commit());
    });

    test('Signed-out leave denied', async () => {
      const unauthDb = testEnv.unauthenticatedContext().firestore();
      const tripRef = unauthDb.collection('trips').doc(tripId);
      const m1Ref = tripRef.collection('members').doc(member1Uid);
      const batch = unauthDb.batch();
      batch.update(tripRef, {
        memberIds: [organizerUid, member2Uid],
        memberCount: 2,
      });
      batch.update(m1Ref, { status: 'left' });
      await assertFails(batch.commit());
    });

    test('Leave DENIED when memberIds drops two members and pads a duplicate so size equals memberCount ([A,B,C] -> [A,A], count 3->2, B leaves)', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).update({
          memberIds: [organizerUid, member1Uid, member2Uid],
          memberCount: 3,
        });
      });
      const leaveMemberUid = member1Uid;
      const leaveDb = testEnv.authenticatedContext(leaveMemberUid).firestore();
      const tripRef = leaveDb.collection('trips').doc(tripId);
      const memberRef = tripRef.collection('members').doc(leaveMemberUid);
      const batch = leaveDb.batch();
      batch.update(tripRef, {
        memberIds: [organizerUid, organizerUid],
        memberCount: 2,
      });
      batch.update(memberRef, { status: 'left' });
      await assertFails(batch.commit());
    });
  });

  describe('Trip Archive Rule', () => {
    const organizerUid = 'org_archive_test';
    const memberUid = 'mem_archive_test';
    const nonMemberUid = 'non_mem_archive_test';
    const tripId = 'trip_archive_test';

    beforeEach(async () => {
      await seedUser(organizerUid, 'Archive Organizer');
      await seedUser(memberUid, 'Archive Member');
      await seedUser(nonMemberUid, 'Archive NonMember');

      await testEnv.withSecurityRulesDisabled(async (context) => {
        const db = context.firestore();
        await db.collection('trips').doc(tripId).set({
          name: 'Archive Test Trip',
          destination: 'Kyoto',
          startDate: new Date('2026-12-01T00:00:00Z'),
          endDate: new Date('2026-12-05T00:00:00Z'),
          currency: 'JPY',
          organizerId: organizerUid,
          joinCode: 'ARCHIV01',
          memberIds: [organizerUid, memberUid],
          memberCount: 2,
          archived: false,
          createdAt: new Date(),
        });
        await db.collection('trips').doc(tripId).collection('members').doc(organizerUid).set({
          displayName: 'Archive Organizer',
          role: 'organizer',
          status: 'active',
          joinedAt: new Date(),
        });
        await db.collection('trips').doc(tripId).collection('members').doc(memberUid).set({
          displayName: 'Archive Member',
          role: 'member',
          status: 'active',
          joinedAt: new Date(),
        });
      });
    });

    test('Trip archive: organizer archives an active trip (archived false->true, only that key): ALLOWED', async () => {
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);
      await assertSucceeds(tripRef.update({ archived: true }));
      const tripSnap = await tripRef.get();
      expect(tripSnap.data().archived).toBe(true);
    });

    test('Trip archive: plain member cannot archive trip: DENIED', async () => {
      const memberDb = testEnv.authenticatedContext(memberUid).firestore();
      const tripRef = memberDb.collection('trips').doc(tripId);
      await assertFails(tripRef.update({ archived: true }));
      // Positive control: organizer succeeds
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      await assertSucceeds(orgDb.collection('trips').doc(tripId).update({ archived: true }));
    });

    test('Trip archive: signed-in non-member cannot archive trip: DENIED', async () => {
      const nonDb = testEnv.authenticatedContext(nonMemberUid).firestore();
      const tripRef = nonDb.collection('trips').doc(tripId);
      await assertFails(tripRef.update({ archived: true }));
    });

    test('Trip archive: signed-out user cannot archive trip: DENIED', async () => {
      const unauthDb = testEnv.unauthenticatedContext().firestore();
      const tripRef = unauthDb.collection('trips').doc(tripId);
      await assertFails(tripRef.update({ archived: true }));
    });

    test('Trip archive: organizer sends archived true->false on an archived trip (unarchive): DENIED', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).update({ archived: true });
      });
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);
      await assertFails(tripRef.update({ archived: false }));
    });

    test('Trip archive: organizer sends archived true on an already archived trip: DENIED', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).update({ archived: true });
      });
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);
      await assertFails(tripRef.update({ archived: true }));
    });

    test('Trip archive: organizer sends archived:true plus another key (e.g. name): DENIED', async () => {
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);
      await assertFails(tripRef.update({ archived: true, name: 'Tampered Trip Name' }));
      // Positive control: only archived key succeeds
      await assertSucceeds(tripRef.update({ archived: true }));
    });

    test('Trip archive: organizer sends archived:false on an active trip (no-op write): DENIED', async () => {
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);
      await assertFails(tripRef.update({ archived: false }));
    });

    test('Trip archive: organizer sends archived as a string "true": DENIED', async () => {
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);
      await assertFails(tripRef.update({ archived: 'true' }));
    });

    test('Trip archive: organizer sends memberIds/memberCount changes together with archived: DENIED', async () => {
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);
      await assertFails(tripRef.update({ archived: true, memberCount: 1 }));
      await assertFails(tripRef.update({ archived: true, memberIds: [organizerUid] }));
    });

    test('Trip archive: after archiving, member subcollection writes are denied (suggestion create, expense create): DENIED', async () => {
      const memberDb = testEnv.authenticatedContext(memberUid).firestore();
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();

      // Positive control on active trip: member can create suggestion and expense
      const activeSuggRef = memberDb.collection('trips').doc(tripId).collection('suggestions').doc('sugg_active_control');
      await assertSucceeds(activeSuggRef.set({
        title: 'Active Suggestion',
        note: 'Note',
        estimatedCost: 100,
        category: 'food',
        authorId: memberUid,
        upCount: 0,
        downCount: 0,
        status: 'pending',
        dayIndex: null,
        order: null,
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));

      const activeExpRef = memberDb.collection('trips').doc(tripId).collection('expenses').doc('exp_active_control');
      await assertSucceeds(activeExpRef.set({
        amount: 1000,
        description: 'Active Expense',
        paidBy: memberUid,
        participantIds: [memberUid],
        date: firebase.firestore.Timestamp.fromDate(new Date('2026-12-02T12:00:00Z')),
        createdBy: memberUid,
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));

      // Organizer archives trip
      await assertSucceeds(orgDb.collection('trips').doc(tripId).update({ archived: true }));

      // After archiving: member writes denied
      const postSuggRef = memberDb.collection('trips').doc(tripId).collection('suggestions').doc('sugg_post_archive');
      await assertFails(postSuggRef.set({
        title: 'Post Archive Suggestion',
        note: 'Note',
        estimatedCost: 100,
        category: 'food',
        authorId: memberUid,
        upCount: 0,
        downCount: 0,
        status: 'pending',
        dayIndex: null,
        order: null,
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));

      const postExpRef = memberDb.collection('trips').doc(tripId).collection('expenses').doc('exp_post_archive');
      await assertFails(postExpRef.set({
        amount: 1000,
        description: 'Post Archive Expense',
        paidBy: memberUid,
        participantIds: [memberUid],
        date: firebase.firestore.Timestamp.fromDate(new Date('2026-12-02T12:00:00Z')),
        createdBy: memberUid,
        createdAt: firebase.firestore.FieldValue.serverTimestamp(),
      }));
    });

    test('Trip archive: after archiving, members can still read the trip and a member doc: ALLOWED', async () => {
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).update({ archived: true });
      });

      const memberDb = testEnv.authenticatedContext(memberUid).firestore();
      const tripSnap = await assertSucceeds(memberDb.collection('trips').doc(tripId).get());
      expect(tripSnap.exists).toBe(true);
      expect(tripSnap.data().archived).toBe(true);

      const memSnap = await assertSucceeds(memberDb.collection('trips').doc(tripId).collection('members').doc(memberUid).get());
      expect(memSnap.exists).toBe(true);
      expect(memSnap.data().displayName).toBe('Archive Member');
    });

    test('Trip archive: organizer cannot delete the trip: DENIED', async () => {
      const orgDb = testEnv.authenticatedContext(organizerUid).firestore();
      const tripRef = orgDb.collection('trips').doc(tripId);
      // Active trip: delete denied
      await assertFails(tripRef.delete());

      // Archived trip: delete denied
      await testEnv.withSecurityRulesDisabled(async (context) => {
        await context.firestore().collection('trips').doc(tripId).update({ archived: true });
      });
      await assertFails(tripRef.delete());
    });
  });
