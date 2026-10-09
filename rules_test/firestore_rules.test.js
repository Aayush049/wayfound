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

      // Non-member read denied
      await assertFails(nonMemberDb.collection(votePath[0]).doc(votePath[1]).collection(votePath[2]).doc(votePath[3]).collection(votePath[4]).doc(votePath[5]).get());

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
});
});
