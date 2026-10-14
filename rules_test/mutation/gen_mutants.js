const fs = require('fs');

const mutants = [
  {
    id: 'm1',
    description: 'member/signed-in checks on vote writes',
    find: "          allow create, update: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)",
    replace: "          allow create, update: if isSignedIn()\n            && uid == request.auth.uid",
    expectedKillers: [
      "Proof 1: Signed-out and non-member vote write denied",
      "Signed-out and non-member are denied reading or writing suggestions and votes"
    ],
    reconstructed: true
  },
  {
    id: 'm2',
    description: 'value in {1,-1}',
    find: "\n            && (request.resource.data.value == 1 || request.resource.data.value == -1)",
    replace: "",
    expectedKillers: [
      "Proof 2: Vote value 2 and 0 denied on create with unchanged counters",
      "Denied vote transactions: unmatched counters, wrong deltas, invalid vote values, extra keys"
    ],
    reconstructed: true
  },
  {
    id: 'm3',
    description: 'value != previous value',
    find: "\n            && (request.method == 'create' || request.resource.data.value != resource.data.value)",
    replace: "",
    expectedKillers: [
      "Proof 3: Re-vote with same value denied",
      "Denied vote transactions: unmatched counters, wrong deltas, invalid vote values, extra keys"
    ],
    reconstructed: true
  },
  {
    id: 'm4a',
    description: 'archived check on vote create/update',
    find: "          allow create, update: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)\n            && isTripNotArchived(tripId)",
    replace: "          allow create, update: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)",
    expectedKillers: [
      "Proof 4: Vote create, vote delete, and suggestion counter update on archived trip denied",
      "Archived trip leave denied"
    ],
    reconstructed: true
  },
  {
    id: 'm4b',
    description: 'archived check on vote delete',
    find: "          allow delete: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)\n            && isTripNotArchived(tripId)",
    replace: "          allow delete: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)",
    expectedKillers: [
      "Proof 4: Vote create, vote delete, and suggestion counter update on archived trip denied",
      "Archived trip leave denied"
    ],
    reconstructed: true
  },
  {
    id: 'm4c',
    description: 'archived check on suggestion counter update',
    find: "        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripNotArchived(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['upCount', 'downCount'])",
    replace: "        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['upCount', 'downCount'])",
    expectedKillers: [
      "Proof 4: Vote create, vote delete, and suggestion counter update on archived trip denied",
      "Archived trip leave denied"
    ],
    reconstructed: true
  },
  {
    id: 'm5',
    description: 'vote read owner check (uid == auth uid)',
    find: "allow get, list: if isSignedIn() && uid == request.auth.uid && isTripMember(tripId);",
    replace: "allow get, list: if isSignedIn() && isTripMember(tripId);",
    expectedKillers: [
      "Votes read permissions: owner can read own vote, other member cannot read owner vote",
      "Proof 5: Signed-out, non-member and other-member reads of vote document denied"
    ],
    reconstructed: true
  },
  {
    id: 'm5b',
    description: 'vote read member check',
    find: "match /votes/{uid} {\n          allow get, list: if isSignedIn() && uid == request.auth.uid && isTripMember(tripId);",
    replace: "match /votes/{uid} {\n          allow get, list: if isSignedIn() && uid == request.auth.uid;",
    expectedKillers: [
      "Votes read permissions: owner can read own vote, other member cannot read owner vote",
      "Proof 5: Signed-out, non-member and other-member reads of vote document denied"
    ],
    reconstructed: true
  },
  {
    id: 'm6',
    description: 'content-update hasOnly key restriction',
    find: "\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['title', 'note', 'estimatedCost', 'category'])",
    replace: "",
    expectedKillers: [
      "Proof 6a: Content update changing createdAt denied",
      "Proof 6b: Content update changing authorId denied",
      "Proof 6c: Content update changing status denied",
      "Proof 6d: Content update changing dayIndex denied",
      "Proof 6e: Content update changing order denied",
      "Content edit: author and organizer succeed; non-author member denied; forbidden field edits denied"
    ],
    reconstructed: true
  },
  {
    id: 'm7a',
    description: 'delete author-or-organizer check',
    find: "\n          && (resource.data.authorId == request.auth.uid || isTripOrganizer(tripId));",
    replace: ";",
    expectedKillers: [
      "Suggestion delete: author and organizer succeed, other member denied",
      "Delete: creator and organizer succeed; other member, non-member, signed out, and archived denied"
    ],
    reconstructed: true
  },
  {
    id: 'm7b',
    description: 'delete archived check',
    find: "        allow delete: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripNotArchived(tripId)",
    replace: "        allow delete: if isSignedIn()\n          && isTripMember(tripId)",
    expectedKillers: [
      "Proof 4: Vote create, vote delete, and suggestion counter update on archived trip denied",
      "Suggestion delete: author and organizer succeed, other member denied"
    ],
    reconstructed: true
  },
  {
    id: 'm8a',
    description: 'counter update upCount delta check',
    find: "          && request.resource.data.upCount == resource.data.upCount + getUpDelta(getVoteBeforeVal(database, tripId, sid, request.auth.uid), getVoteAfterVal(database, tripId, sid, request.auth.uid))",
    replace: "",
    expectedKillers: [
      "Proof 8b: Vote write with NO matching counter change denied",
      "Denied vote transactions: unmatched counters, wrong deltas, invalid vote values, extra keys"
    ],
    reconstructed: true
  },
  {
    id: 'm8b',
    description: 'counter update downCount delta check',
    find: "          && request.resource.data.downCount == resource.data.downCount + getDownDelta(getVoteBeforeVal(database, tripId, sid, request.auth.uid), getVoteAfterVal(database, tripId, sid, request.auth.uid))",
    replace: "",
    expectedKillers: [
      "Proof 8b: Vote write with NO matching counter change denied",
      "Denied vote transactions: unmatched counters, wrong deltas, invalid vote values, extra keys"
    ],
    reconstructed: true
  },
  {
    id: 'm9',
    description: 'hasAll(resource.data.memberIds) check on trip join',
    find: "\n        && request.resource.data.memberIds.hasAll(resource.data.memberIds)",
    replace: "",
    expectedKillers: [
      "Join DENIED when caller pads memberIds with duplicate existing member to drop another member ([B, B, C] or [A, A, C])",
      "Join DENIED when one old member is replaced by caller and memberCount is unchanged"
    ],
    reconstructed: true
  },
  {
    id: 'm10',
    description: 'users createdAt == request.time',
    find: "\n        && request.resource.data.createdAt == request.time;",
    replace: ";",
    expectedKillers: [
      "users create DENIED when createdAt is a client Date (not request.time)",
      "users update DENIED when createdAt is changed"
    ],
    reconstructed: true
  },
  {
    id: 'm11',
    description: 'organizer check on scheduling branch',
    find: "        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripOrganizer(tripId)\n          && isTripNotArchived(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'dayIndex', 'order'])",
    replace: "        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripNotArchived(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'dayIndex', 'order'])",
    expectedKillers: [
      "Scheduling denied for plain member, non-organizer author, non-member, signed out, archived trip",
      "Organizer reorders, moves day, and unschedules"
    ],
    reconstructed: true
  },
  {
    id: 'm12',
    description: 'scheduling archived check',
    find: "        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripOrganizer(tripId)\n          && isTripNotArchived(tripId)",
    replace: "        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripOrganizer(tripId)",
    expectedKillers: [
      "Scheduling denied for plain member, non-organizer author, non-member, signed out, archived trip",
      "Archived trip leave denied"
    ],
    reconstructed: true
  },
  {
    id: 'm13',
    description: 'dayIndex upper bound',
    find: "\n              && request.resource.data.dayIndex <= (get(/databases/$(database)/documents/trips/$(tripId)).data.endDate.toMillis() - get(/databases/$(database)/documents/trips/$(tripId)).data.startDate.toMillis() + 43200000) / 86400000",
    replace: "",
    expectedKillers: [
      "Denied scheduling for invalid dayIndex, order, status values, coherence, and extra/mixed keys",
      "Day bound tolerance"
    ],
    reconstructed: true
  },
  {
    id: 'm14',
    description: 'dayIndex lower bound',
    find: "\n              && request.resource.data.dayIndex >= 0",
    replace: "",
    expectedKillers: [
      "Denied scheduling for invalid dayIndex, order, status values, coherence, and extra/mixed keys"
    ],
    reconstructed: true
  },
  {
    id: 'm15',
    description: 'order lower bound',
    find: "\n              && request.resource.data.order >= 0",
    replace: "",
    expectedKillers: [
      "Denied scheduling for invalid dayIndex, order, status values, coherence, and extra/mixed keys"
    ],
    reconstructed: true
  },
  {
    id: 'm16',
    description: 'order upper bound',
    find: "\n              && request.resource.data.order <= 10000",
    replace: "",
    expectedKillers: [
      "Denied scheduling for invalid dayIndex, order, status values, coherence, and extra/mixed keys"
    ],
    reconstructed: true
  },
  {
    id: 'm17',
    description: 'status pending fields null check',
    find: "            (request.resource.data.status == 'pending' && request.resource.data.dayIndex == null && request.resource.data.order == null)",
    replace: "            (request.resource.data.status == 'pending')",
    expectedKillers: [
      "Denied scheduling for invalid dayIndex, order, status values, coherence, and extra/mixed keys"
    ],
    reconstructed: true
  },
  {
    id: 'm18',
    description: 'expense read member check',
    find: "      match /expenses/{expenseId} {\n        allow get, list: if isSignedIn() && isTripMember(tripId);",
    replace: "      match /expenses/{expenseId} {\n        allow get, list: if isSignedIn();",
    expectedKillers: [
      "Read: member succeeds; non-member and signed out denied",
      "Settlement read: member allowed"
    ],
    reconstructed: true
  },
  {
    id: 'm20',
    description: 'expense createdBy == caller check',
    find: "\n          && request.resource.data.createdBy == request.auth.uid",
    replace: "",
    expectedKillers: [
      "Create denied when createdBy is not the caller",
      "Settlement create: fromUid != auth uid denied"
    ],
    reconstructed: true
  },
  {
    id: 'm21',
    description: 'expense create exact key sets (hasAll & hasOnly)',
    find: "\n          && request.resource.data.keys().hasAll(['amount', 'description', 'paidBy', 'participantIds', 'createdBy', 'date', 'createdAt'])\n          && request.resource.data.keys().hasOnly(['amount', 'description', 'paidBy', 'participantIds', 'createdBy', 'date', 'createdAt'])",
    replace: "",
    expectedKillers: [
      "Create denied for extra key or missing key",
      "Create denied for invalid amount"
    ],
    reconstructed: true
  },
  {
    id: 'm22',
    description: 'expense amount lower bound',
    find: "\n          && request.resource.data.amount >= 1",
    replace: "",
    expectedKillers: [
      "Create denied for invalid amount"
    ],
    reconstructed: true
  },
  {
    id: 'm23',
    description: 'expense amount upper bound',
    find: "\n          && request.resource.data.amount <= 100000000000",
    replace: "",
    expectedKillers: [
      "Create denied for invalid amount"
    ],
    reconstructed: true
  },
  {
    id: 'm24',
    description: 'expense description string and size check',
    find: "\n          && request.resource.data.description is string && request.resource.data.description.size() >= 1 && request.resource.data.description.size() <= 100",
    replace: "",
    expectedKillers: [
      "Create denied for invalid description"
    ],
    reconstructed: true
  },
  {
    id: 'm25',
    description: 'expense paidBy member check',
    find: "\n          && request.resource.data.paidBy is string && (request.resource.data.paidBy in get(/databases/$(database)/documents/trips/$(tripId)).data.memberIds)",
    replace: "",
    expectedKillers: [
      "Create denied for invalid paidBy"
    ],
    reconstructed: true
  },
  {
    id: 'm26',
    description: 'expense participantIds list check',
    find: "\n          && request.resource.data.participantIds is list",
    replace: "",
    expectedKillers: [
      "Create denied for invalid participantIds"
    ],
    reconstructed: true
  },
  {
    id: 'm27',
    description: 'expense participantIds size bounds',
    find: "\n          && request.resource.data.participantIds.size() >= 1 && request.resource.data.participantIds.size() <= 15",
    replace: "",
    expectedKillers: [
      "Create denied for invalid participantIds size"
    ],
    reconstructed: true
  },
  {
    id: 'm28',
    description: 'expense update creator-or-organizer check',
    find: "\n          && (resource.data.createdBy == request.auth.uid || isTripOrganizer(tripId))\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['amount', 'description', 'paidBy', 'participantIds', 'date'])",
    replace: "\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['amount', 'description', 'paidBy', 'participantIds', 'date'])",
    expectedKillers: [
      "Update: creator and organizer succeed; other member and non-member denied",
      "Update denied when changing createdBy or createdAt"
    ],
    reconstructed: true
  },
  {
    id: 'm29',
    description: 'expense update archived check',
    find: '        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripNotArchived(tripId)',
    replace: '        allow update: if isSignedIn()\n          && isTripMember(tripId)',
    expectedKillers: [
      "Archived trip leave denied",
      "Update: creator and organizer succeed; other member and non-member denied"
    ],
    reconstructed: true
  },
  {
    id: 'm30',
    description: 'expense delete creator-or-organizer check',
    find: '        allow delete: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripNotArchived(tripId)\n          && (resource.data.createdBy == request.auth.uid || isTripOrganizer(tripId));',
    replace: '        allow delete: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripNotArchived(tripId);',
    expectedKillers: [
      "Delete: creator and organizer succeed; other member, non-member, signed out, and archived denied"
    ],
    reconstructed: true
  },
  {
    id: 'm31',
    description: 'settlement read member check',
    find: '      match /settlements/{settlementId} {\n        allow get, list: if isSignedIn() && isTripMember(tripId);',
    replace: '      match /settlements/{settlementId} {\n        allow get, list: if isSignedIn();',
    expectedKillers: [
      "Settlement read: member allowed",
      "Read: member succeeds; non-member and signed out denied"
    ],
    reconstructed: true
  },
  {
    id: 'm32',
    description: 'settlement create fromUid == auth.uid check',
    find: '\n          && request.resource.data.fromUid == request.auth.uid',
    replace: '',
    expectedKillers: [
      "Settlement create: fromUid != auth uid denied"
    ],
    reconstructed: true
  },
  {
    id: 'm33',
    description: 'settlement create toUid member check',
    find: '\n          && request.resource.data.toUid in get(/databases/$(database)/documents/trips/$(tripId)).data.memberIds',
    replace: '',
    expectedKillers: [
      "Settlement create: toUid not member denied"
    ],
    reconstructed: true
  },
  {
    id: 'm34',
    description: 'settlement create toUid != auth.uid check',
    find: '\n          && request.resource.data.toUid != request.auth.uid',
    replace: '',
    expectedKillers: [
      "Settlement create: toUid == fromUid denied"
    ],
    reconstructed: true
  },
  {
    id: 'm35',
    description: 'settlement create amount int check',
    find: '\n          && request.resource.data.amount is int',
    replace: '',
    expectedKillers: [
      "Settlement create: invalid amount denied"
    ],
    reconstructed: true
  },
  {
    id: 'm36',
    description: 'settlement create amount lower bound',
    find: '\n          && request.resource.data.amount >= 1',
    replace: '',
    expectedKillers: [
      "Settlement create: invalid amount denied"
    ],
    reconstructed: true
  },
  {
    id: 'm37',
    description: 'settlement create amount upper bound',
    find: '\n          && request.resource.data.amount <= 100000000000',
    replace: '',
    expectedKillers: [
      "Settlement create: invalid amount denied"
    ],
    reconstructed: true
  },
  {
    id: 'm38',
    description: 'settlement create status pending check',
    find: "\n          && request.resource.data.status == 'pending'",
    replace: '',
    expectedKillers: [
      "Settlement create: invalid status denied"
    ],
    reconstructed: true
  },
  {
    id: 'm39',
    description: 'settlement create createdAt request.time check',
    find: '\n          && request.resource.data.createdAt == request.time',
    replace: '',
    expectedKillers: [
      "Settlement create: invalid createdAt denied"
    ],
    reconstructed: true
  },
  {
    id: 'm40',
    description: 'settlement create resolvedAt null check',
    find: '\n          && request.resource.data.resolvedAt == null;',
    replace: ';',
    expectedKillers: [
      "Settlement create: resolvedAt not null denied"
    ],
    reconstructed: true
  },
  {
    id: 'm41',
    description: 'settlement update pending resource status check',
    find: "\n          && resource.data.status == 'pending'",
    replace: '',
    expectedKillers: [
      "Settlement update: already confirmed denied"
    ],
    reconstructed: true
  },
  {
    id: 'm42',
    description: 'settlement update affectedKeys check',
    find: "\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'resolvedAt'])",
    replace: '',
    expectedKillers: [
      "Settlement update: invalid affected keys denied"
    ],
    reconstructed: true
  },
  {
    id: 'm43',
    description: 'settlement update status in confirmed/rejected check',
    find: "\n          && request.resource.data.status in ['confirmed', 'rejected']",
    replace: '',
    expectedKillers: [
      "Settlement update: invalid status denied"
    ],
    reconstructed: true
  },
  {
    id: 'm44',
    description: 'settlement update resolvedAt request.time check',
    find: '\n          && request.resource.data.resolvedAt == request.time',
    replace: '',
    expectedKillers: [
      "Settlement update: invalid resolvedAt denied"
    ],
    reconstructed: true
  },
  {
    id: 'm45',
    description: 'settlement update authorization check (toUid or organizer)',
    find: "\n          && (request.auth.uid == resource.data.toUid || (isTripOrganizer(tripId) && resource.data.fromUid != request.auth.uid));",
    replace: ";",
    expectedKillers: [
      "Settlement update: third member denied",
      "Settlement update: payer confirming own settlement denied"
    ],
    reconstructed: true
  },
  {
    id: 'm46',
    description: 'settlement delete creator check',
    find: '\n          && request.auth.uid == resource.data.fromUid',
    replace: '',
    expectedKillers: [
      "Settlement delete: non-creator denied"
    ],
    reconstructed: true
  },
  {
    id: 'm47',
    description: 'settlement delete status pending check',
    find: "\n          && resource.data.status == 'pending';",
    replace: ';',
    expectedKillers: [
      "Settlement delete: non-pending denied"
    ],
    reconstructed: true
  },
  {
    id: 'm48',
    description: 'joinCodes get signedIn check',
    find: '      allow get: if isSignedIn();',
    replace: '      allow get: if true;',
    expectedKillers: [
      "joinCodes single get allowed for signed-in user, list denied"
    ],
    reconstructed: true
  },
  {
    id: 'm49',
    description: 'joinCodes create format check',
    find: "        && code.matches('^[A-HJKMNP-Z2-9]{6}$')",
    replace: '',
    expectedKillers: [
      "Denied trip create with invalid joinCode format or duplicate join code"
    ],
    reconstructed: true
  },
  {
    id: 'm50',
    description: 'joinCodes create hasAll keys check',
    find: "\n        && request.resource.data.keys().hasAll(['tripId', 'tripName', 'destination', 'startDate', 'endDate', 'memberCount'])",
    replace: '',
    expectedKillers: [
      "Denied trip create with extra or missing keys"
    ],
    reconstructed: true
  },
  {
    id: 'm51',
    description: 'joinCodes create memberCount 1 check',
    find: '\n        && request.resource.data.memberCount == 1',
    replace: '',
    expectedKillers: [
      "Denied trip create when memberCount is not 1"
    ],
    reconstructed: true
  },
  {
    id: 'm52',
    description: 'joinCodes update affectedKeys check',
    find: "      allow update: if isSignedIn()\n        && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['memberCount'])",
    replace: "      allow update: if isSignedIn()",
    expectedKillers: [
      "joinCodes update fails if not matching trip memberCount or deleting"
    ],
    reconstructed: true
  },
  {
    id: 'm53',
    description: 'leave rule drop memberIds.size() == memberCount check',
    find: "\n        && request.resource.data.memberIds.size() == request.resource.data.memberCount\n        && request.resource.data.memberIds.toSet().size() == request.resource.data.memberCount",
    replace: "\n        && request.resource.data.memberIds.toSet().size() == request.resource.data.memberCount",
    expectedKillers: [
      "memberCount unchanged while dropping UID denied",
      "memberCount decreased by 2 while dropping 1 UID denied",
      "a) memberIds [A,B,C]->[A,A,C]"
    ],
    reconstructed: true
  },
  {
    id: 'm54',
    description: 'leave rule memberCount decrement check',
    find: '\n        && request.resource.data.memberCount == resource.data.memberCount - 1',
    replace: '',
    expectedKillers: [
      "memberCount unchanged while dropping UID denied"
    ],
    reconstructed: true
  },
  {
    id: 'm55',
    description: 'drop status == active from join update rule',
    find: "\n        && getAfter(/databases/$(database)/documents/trips/$(tripId)/members/$(request.auth.uid)).data.status == 'active';",
    replace: ";",
    expectedKillers: [
      "Rejoin by previously left member denied directly through memberIds update",
      "Join fails when trip is archived"
    ],
    reconstructed: true
  },
  {
    id: 'm56',
    description: 'settlement update allows payer to confirm own settlement',
    find: "\n          && (request.auth.uid == resource.data.toUid || (isTripOrganizer(tripId) && resource.data.fromUid != request.auth.uid));",
    replace: "\n          && (request.auth.uid == resource.data.toUid || request.auth.uid == resource.data.fromUid || (isTripOrganizer(tripId) && resource.data.fromUid != request.auth.uid));",
    expectedKillers: [
      "Settlement update: payer confirming own settlement denied",
      "Settlement update: third member denied"
    ],
    reconstructed: true
  },
  {
    id: 'm57',
    description: 'join update memberCount limit check',
    find: '\n        && resource.data.memberCount < 15',
    replace: '',
    expectedKillers: [
      "Sequential boundary test: succeeds at 14 to 15, fails at 15 to 16"
    ],
    reconstructed: true
  },
  {
    id: 'm58',
    description: 'join update archived check',
    find: '\n        && resource.data.archived == false',
    replace: '',
    expectedKillers: [
      "Join fails when trip is archived"
    ],
    reconstructed: true
  },
  {
    id: 'm59',
    description: 'users update displayName size min check',
    find: '\n        && request.resource.data.displayName.size() >= 1',
    replace: '',
    expectedKillers: [
      "Owner update fails if attempting to change forbidden fields"
    ],
    reconstructed: true
  },
  {
    id: 'm60',
    description: 'users update displayName size max check',
    find: '\n        && request.resource.data.displayName.size() <= 50',
    replace: '',
    expectedKillers: [
      "Owner update fails if attempting to change forbidden fields"
    ],
    reconstructed: true
  },
  {
    id: 'm61',
    description: 'leave rule drops organizer self-removal protection',
    find: "\n        && !(resource.data.memberIds.removeAll(request.resource.data.memberIds)[0] == resource.data.organizerId && resource.data.memberIds.removeAll(request.resource.data.memberIds)[0] == request.auth.uid)",
    replace: "",
    expectedKillers: [
      "Cannot remove the organizer (including organizer leaving)",
      "Organizer self-removal denied"
    ],
    reconstructed: true
  }
];

fs.writeFileSync('D:\\VsCode\\wayfound\\rules_test\\mutation\\mutants.json', JSON.stringify(mutants, null, 2), 'utf8');
console.log('Successfully wrote mutants.json with', mutants.length, 'mutants.');
