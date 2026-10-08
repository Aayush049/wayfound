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

  describe('Trip Join Boundary & Security Tests', () => {
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
  });

  describe('Read & Query Permissions', () => {
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
});
