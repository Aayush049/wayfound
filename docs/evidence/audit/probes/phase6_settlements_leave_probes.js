/**
 * Phase 6 Security Rules Probe Tests
 * Tests settlements and leave/remove rules evaluation
 * Run via: node probes_runner.js (emulator-based)
 */

const TEST_PROBES = {
  // === SETTLEMENTS CREATE PROBES ===

  settlementCreate: {
    description: 'Settlement create - valid payload from member',
    collection: 'trips/{tripId}/settlements',
    method: 'create',
    user: 'member1',
    validPayload: {
      fromUid: 'member1',
      toUid: 'member2',
      amount: 5000,
      status: 'pending',
      createdAt: 'request.time',
      resolvedAt: null
    },
    conditions: [
      'isSignedIn() - YES',
      'isTripMember(tripId) - YES',
      'isTripNotArchived(tripId) - YES',
      'request.resource.data.keys().hasAll([required]) - YES',
      'request.resource.data.keys().hasOnly([allowed]) - YES',
      'request.resource.data.fromUid == request.auth.uid - YES (member1 == member1)',
      'request.resource.data.toUid in memberIds - YES',
      'request.resource.data.toUid != request.auth.uid - YES',
      'request.resource.data.amount is int - YES',
      'request.resource.data.amount >= 1 && <= 100000000000 - YES',
      'request.resource.data.status == pending - YES',
      'request.resource.data.createdAt == request.time - YES',
      'request.resource.data.resolvedAt == null - YES'
    ],
    expectedResult: 'ALLOW'
  },

  settlementCreateNotMember: {
    description: 'Settlement create - non-member attempts',
    collection: 'trips/{tripId}/settlements',
    method: 'create',
    user: 'outsider',
    validPayload: {
      fromUid: 'outsider',
      toUid: 'member1',
      amount: 5000,
      status: 'pending',
      createdAt: 'request.time',
      resolvedAt: null
    },
    conditions: [
      'isSignedIn() - YES',
      'isTripMember(tripId) - NO (outsider not in memberIds)',
      'isTripNotArchived(tripId) - N/A (fails member check)'
    ],
    expectedResult: 'DENY'
  },

  settlementCreateSelfPayment: {
    description: 'Settlement create - paying self',
    collection: 'trips/{tripId}/settlements',
    method: 'create',
    user: 'member1',
    validPayload: {
      fromUid: 'member1',
      toUid: 'member1', // same person
      amount: 5000,
      status: 'pending',
      createdAt: 'request.time',
      resolvedAt: null
    },
    conditions: [
      'request.resource.data.toUid != request.auth.uid - NO (member1 == member1)'
    ],
    expectedResult: 'DENY'
  },

  settlementCreateUnauthorizedFrom: {
    description: 'Settlement create - fromUid mismatch',
    collection: 'trips/{tripId}/settlements',
    method: 'create',
    user: 'member1',
    validPayload: {
      fromUid: 'member2', // NOT the authenticated user
      toUid: 'member3',
      amount: 5000,
      status: 'pending',
      createdAt: 'request.time',
      resolvedAt: null
    },
    conditions: [
      'request.resource.data.fromUid == request.auth.uid - NO (member2 != member1)'
    ],
    expectedResult: 'DENY'
  },

  settlementCreateInvalidAmount: {
    description: 'Settlement create - invalid amount (0)',
    collection: 'trips/{tripId}/settlements',
    method: 'create',
    user: 'member1',
    validPayload: {
      fromUid: 'member1',
      toUid: 'member2',
      amount: 0, // invalid
      status: 'pending',
      createdAt: 'request.time',
      resolvedAt: null
    },
    conditions: [
      'request.resource.data.amount >= 1 - NO (0 < 1)'
    ],
    expectedResult: 'DENY'
  },

  settlementCreateInvalidStatus: {
    description: 'Settlement create - invalid status',
    collection: 'trips/{tripId}/settlements',
    method: 'create',
    user: 'member1',
    validPayload: {
      fromUid: 'member1',
      toUid: 'member2',
      amount: 5000,
      status: 'confirmed', // should be 'pending'
      createdAt: 'request.time',
      resolvedAt: null
    },
    conditions: [
      'request.resource.data.status == pending - NO (confirmed != pending)'
    ],
    expectedResult: 'DENY'
  },

  // === SETTLEMENTS UPDATE PROBES ===

  settlementUpdateRecipientConfirms: {
    description: 'Settlement update - recipient confirms',
    collection: 'trips/{tripId}/settlements',
    method: 'update',
    user: 'member2', // the toUid
    existingPayload: {
      fromUid: 'member1',
      toUid: 'member2',
      amount: 5000,
      status: 'pending',
      createdAt: 'timestamp',
      resolvedAt: null
    },
    updatePayload: {
      status: 'confirmed',
      resolvedAt: 'request.time'
    },
    conditions: [
      'isSignedIn() - YES',
      'isTripMember(tripId) - YES',
      'isTripNotArchived(tripId) - YES',
      'resource.data.status == pending - YES',
      'request.resource.data.diff(resource.data).affectedKeys().hasOnly([status, resolvedAt]) - YES',
      'request.resource.data.status in [confirmed, rejected] - YES',
      'request.resource.data.resolvedAt == request.time - YES',
      'request.auth.uid == resource.data.toUid - YES (member2 == member2)'
    ],
    expectedResult: 'ALLOW'
  },

  settlementUpdateOrganizerConfirms: {
    description: 'Settlement update - organizer confirms (not fromUid)',
    collection: 'trips/{tripId}/settlements',
    method: 'update',
    user: 'organizer',
    existingPayload: {
      fromUid: 'member1',
      toUid: 'member2',
      amount: 5000,
      status: 'pending',
      createdAt: 'timestamp',
      resolvedAt: null
    },
    updatePayload: {
      status: 'confirmed',
      resolvedAt: 'request.time'
    },
    conditions: [
      'request.auth.uid == resource.data.toUid - NO (organizer != member2)',
      'request.auth.uid == organizerId && resource.data.fromUid != request.auth.uid - YES'
    ],
    expectedResult: 'ALLOW'
  },

  settlementUpdateNonPartyDenied: {
    description: 'Settlement update - non-party member',
    collection: 'trips/{tripId}/settlements',
    method: 'update',
    user: 'member3', // neither fromUid nor toUid
    existingPayload: {
      fromUid: 'member1',
      toUid: 'member2',
      amount: 5000,
      status: 'pending',
      createdAt: 'timestamp',
      resolvedAt: null
    },
    updatePayload: {
      status: 'confirmed',
      resolvedAt: 'request.time'
    },
    conditions: [
      'request.auth.uid == resource.data.toUid - NO (member3 != member2)',
      'request.auth.uid == organizerId && fromUid != auth.uid - NO (member3 != organizer)'
    ],
    expectedResult: 'DENY'
  },

  settlementUpdateFromUidDenied: {
    description: 'Settlement update - fromUid cannot update',
    collection: 'trips/{tripId}/settlements',
    method: 'update',
    user: 'member1', // the fromUid
    existingPayload: {
      fromUid: 'member1',
      toUid: 'member2',
      amount: 5000,
      status: 'pending',
      createdAt: 'timestamp',
      resolvedAt: null
    },
    updatePayload: {
      status: 'confirmed',
      resolvedAt: 'request.time'
    },
    conditions: [
      'request.auth.uid == resource.data.toUid - NO (member1 != member2)',
      'request.auth.uid == organizerId && fromUid != auth.uid - NO (member1 == fromUid)'
    ],
    expectedResult: 'DENY'
  },

  settlementUpdateAlreadyResolved: {
    description: 'Settlement update - already resolved',
    collection: 'trips/{tripId}/settlements',
    method: 'update',
    user: 'member2',
    existingPayload: {
      fromUid: 'member1',
      toUid: 'member2',
      amount: 5000,
      status: 'confirmed', // already resolved
      createdAt: 'timestamp',
      resolvedAt: 'timestamp'
    },
    updatePayload: {
      status: 'rejected',
      resolvedAt: 'request.time'
    },
    conditions: [
      'resource.data.status == pending - NO (status == confirmed)'
    ],
    expectedResult: 'DENY'
  },

  // === SETTLEMENTS DELETE PROBES ===

  settlementDeleteCreator: {
    description: 'Settlement delete - creator can delete pending',
    collection: 'trips/{tripId}/settlements',
    method: 'delete',
    user: 'member1', // fromUid
    existingPayload: {
      fromUid: 'member1',
      toUid: 'member2',
      amount: 5000,
      status: 'pending',
      createdAt: 'timestamp',
      resolvedAt: null
    },
    conditions: [
      'isSignedIn() - YES',
      'isTripNotArchived(tripId) - YES',
      'request.auth.uid == resource.data.fromUid - YES',
      'resource.data.status == pending - YES'
    ],
    expectedResult: 'ALLOW'
  },

  settlementDeleteNonCreator: {
    description: 'Settlement delete - non-creator denied',
    collection: 'trips/{tripId}/settlements',
    method: 'delete',
    user: 'member2', // toUid, not fromUid
    existingPayload: {
      fromUid: 'member1',
      toUid: 'member2',
      amount: 5000,
      status: 'pending',
      createdAt: 'timestamp',
      resolvedAt: null
    },
    conditions: [
      'request.auth.uid == resource.data.fromUid - NO (member2 != member1)'
    ],
    expectedResult: 'DENY'
  },

  settlementDeleteResolved: {
    description: 'Settlement delete - cannot delete resolved',
    collection: 'trips/{tripId}/settlements',
    method: 'delete',
    user: 'member1',
    existingPayload: {
      fromUid: 'member1',
      toUid: 'member2',
      amount: 5000,
      status: 'confirmed',
      createdAt: 'timestamp',
      resolvedAt: 'timestamp'
    },
    conditions: [
      'resource.data.status == pending - NO (status == confirmed)'
    ],
    expectedResult: 'DENY'
  },

  // === LEAVE/REMOVE PROBES ===

  memberLeaveSelf: {
    description: 'Leave - member leaves themselves',
    collection: 'trips/{tripId}',
    method: 'update',
    user: 'member2', // the leaving member
    existingPayload: {
      memberIds: ['org', 'member1', 'member2', 'member3'],
      memberCount: 4,
      archived: false
    },
    updatePayload: {
      memberIds: ['org', 'member1', 'member3'],
      memberCount: 3
    },
    companionWrites: [
      'trips/{tripId}/members/{leavingMember}/status = left'
    ],
    conditions: [
      'isSignedIn() - YES',
      'resource.data.memberIds is list - YES',
      'resource.data.memberCount is number - YES',
      'affectedKeys().hasOnly([memberIds, memberCount]) - YES',
      'request.resource.data.memberCount == resource.data.memberCount - 1 - YES (3 == 4-1)',
      'resource.data.memberIds.size() == resource.data.memberCount - YES (4 == 4)',
      'removeAll(request.resource.data.memberIds).size() == 1 - YES',
      'removing member == request.auth.uid OR organizer == auth.uid - YES (member2 == member2)',
      '!(removing organizer AND removing self) - YES',
      'memberIds.toSet().size() == memberCount - YES',
      'archived == false - YES',
      'existsAfter(members/{removed}) - YES',
      'getAfter(members/{removed}).data.status == left - YES',
      'getAfter(members/{removed}).data.diff(...).affectedKeys().hasOnly([status]) - YES'
    ],
    documentAccessCalls: 4, // get trip, get member, exists member, get member
    expectedResult: 'ALLOW'
  },

  memberLeaveOrganizerRemoves: {
    description: 'Remove - organizer removes member',
    collection: 'trips/{tripId}',
    method: 'update',
    user: 'organizer',
    existingPayload: {
      memberIds: ['organizer', 'member1', 'member2', 'member3'],
      memberCount: 4,
      archived: false
    },
    updatePayload: {
      memberIds: ['organizer', 'member1', 'member3'],
      memberCount: 3
    },
    companionWrites: [
      'trips/{tripId}/members/{removedMember}/status = left'
    ],
    conditions: [
      'isSignedIn() - YES',
      'removing member == request.auth.uid OR organizer == auth.uid - YES (organizer == organizer)',
      '!(removing organizer AND removing self) - YES (removing member2, not organizer)'
    ],
    documentAccessCalls: 4,
    expectedResult: 'ALLOW'
  },

  memberRemoveSelfDenied: {
    description: 'Remove - member cannot remove another member',
    collection: 'trips/{tripId}',
    method: 'update',
    user: 'member1', // not organizer
    existingPayload: {
      memberIds: ['organizer', 'member1', 'member2', 'member3'],
      memberCount: 4,
      archived: false
    },
    updatePayload: {
      memberIds: ['organizer', 'member1', 'member3'],
      memberCount: 3
    },
    companionWrites: [
      'trips/{tripId}/members/{member2}/status = left'
    ],
    conditions: [
      'removing member == request.auth.uid OR organizer == auth.uid - NO (member2 != member1 && organizer != member1)'
    ],
    expectedResult: 'DENY'
  },

  memberLeaveOrganizerSelf: {
    description: 'Leave/Remove - cannot remove organizer',
    collection: 'trips/{tripId}',
    method: 'update',
    user: 'organizer',
    existingPayload: {
      memberIds: ['organizer', 'member1', 'member2'],
      memberCount: 3,
      archived: false
    },
    updatePayload: {
      memberIds: ['member1', 'member2'],
      memberCount: 2
    },
    companionWrites: [
      'trips/{tripId}/members/{organizer}/status = left'
    ],
    conditions: [
      '!(removing organizer AND removing self) - NO (organizer is removing self)'
    ],
    expectedResult: 'DENY'
  },

  memberLeaveArchivedTrip: {
    description: 'Leave - cannot leave archived trip',
    collection: 'trips/{tripId}',
    method: 'update',
    user: 'member2',
    existingPayload: {
      memberIds: ['organizer', 'member1', 'member2'],
      memberCount: 3,
      archived: true // archived
    },
    updatePayload: {
      memberIds: ['organizer', 'member1'],
      memberCount: 2
    },
    companionWrites: [
      'trips/{tripId}/members/{member2}/status = left'
    ],
    conditions: [
      'resource.data.archived == false - NO (archived == true)'
    ],
    expectedResult: 'DENY'
  },

  memberLeaveWithoutMemberDoc: {
    description: 'Leave - member document status not set to left',
    collection: 'trips/{tripId}',
    method: 'update',
    user: 'member2',
    existingPayload: {
      memberIds: ['organizer', 'member1', 'member2'],
      memberCount: 3,
      archived: false
    },
    updatePayload: {
      memberIds: ['organizer', 'member1'],
      memberCount: 2
    },
    // Missing: trips/{tripId}/members/{member2} status=left
    conditions: [
      'existsAfter(members/{member2}) - depends on setup',
      'getAfter(members/{member2}).data.status == left - depends on setup'
    ],
    expectedResult: 'CONDITIONAL - DENY if member doc not updated'
  },

  memberLeaveUnauthorizedFields: {
    description: 'Leave - cannot modify other fields',
    collection: 'trips/{tripId}',
    method: 'update',
    user: 'member2',
    existingPayload: {
      memberIds: ['organizer', 'member1', 'member2'],
      memberCount: 3,
      archived: false,
      name: 'Trip Name'
    },
    updatePayload: {
      memberIds: ['organizer', 'member1'],
      memberCount: 2,
      name: 'New Name' // unauthorized
    },
    conditions: [
      'affectedKeys().hasOnly([memberIds, memberCount]) - NO (name is extra)'
    ],
    expectedResult: 'DENY'
  },

  memberLeaveCountMismatch: {
    description: 'Leave - memberCount decrement mismatch',
    collection: 'trips/{tripId}',
    method: 'update',
    user: 'member2',
    existingPayload: {
      memberIds: ['organizer', 'member1', 'member2'],
      memberCount: 3,
      archived: false
    },
    updatePayload: {
      memberIds: ['organizer', 'member1'],
      memberCount: 2 // should be 2, let's say they try 1
    },
    conditions: [
      'request.resource.data.memberCount == resource.data.memberCount - 1 - depends'
    ],
    expectedResult: 'CONDITIONAL'
  }
};

// Document access call count analysis
const DOC_ACCESS_ANALYSIS = {
  leaveBatchWrite: {
    description: 'Leave batch operation document accesses',
    operations: [
      '1. get(/databases/$(database)/documents/trips/$(tripId)) - read current trip',
      '2. get(/databases/$(database)/documents/trips/$(tripId)).data.memberIds - implicit',
      '3. get(/databases/$(database)/documents/trips/$(tripId)).data.organizerId - implicit',
      '4. existsAfter(members/{leavingUid}) - check member doc exists',
      '5. getAfter(members/{leavingUid}) - read member doc after write',
      '6. getAfter(members/{leavingUid}).data.status - check status',
      '7. getAfter(members/{leavingUid}).data.diff(...).affectedKeys() - validate changes'
    ],
    totalReadCalls: '7 document reads (4 gets, 3 exists)',
    totalWriteCalls: '2 writes (trip update + member status update)',
    riskAssessment: 'Medium - Multiple document reads for validation'
  },
  settlementCreate: {
    description: 'Settlement create document accesses',
    operations: [
      '1. get(trips/{tripId}).data.memberIds - check membership',
      '2. get(trips/{tripId}).data.archived - check archived'
    ],
    totalReadCalls: '2 document reads',
    totalWriteCalls: '1 write (the settlement)',
    riskAssessment: 'Low - Minimal document access'
  },
  settlementUpdate: {
    description: 'Settlement update document accesses',
    operations: [
      '1. get(trips/{tripId}).data.memberIds - check membership',
      '2. get(trips/{tripId}).data.archived - check archived',
      '3. get(trips/{tripId}).data.organizerId - check organizer (for non-recipient)'
    ],
    totalReadCalls: '3 document reads',
    totalWriteCalls: '1 write (the settlement update)',
    riskAssessment: 'Low - Controlled by status check and party validation'
  }
};

module.exports = { TEST_PROBES, DOC_ACCESS_ANALYSIS };