const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { execSync } = require('child_process');

const rootDir = path.join(__dirname, '..', '..');
const originalRulesPath = path.join(rootDir, 'firestore.rules');
const outDir = path.resolve(__dirname, 'out');

if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}

function getFileSha256(filePath) {
  const content = fs.readFileSync(filePath);
  return crypto.createHash('sha256').update(content).digest('hex');
}

const initialRulesHash = getFileSha256(originalRulesPath);
const originalRules = fs.readFileSync(originalRulesPath, 'utf8').replace(/\r\n/g, '\n');

const mutants = [
  {
    id: 'm0',
    description: 'BASELINE CONTROL (unchanged firestore.rules)',
    isBaseline: true,
    expectedKillers: [],
    custom: (rules) => rules,
  },
  {
    id: 'm1',
    description: 'member/signed-in checks on vote writes',
    find: `          allow create, update: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)`,
    replace: `          allow create, update: if isSignedIn()\n            && uid == request.auth.uid`,
    expectedKillers: ['Proof 1: Signed-out and non-member vote write denied'],
  },
  {
    id: 'm2',
    description: 'value in {1,-1}',
    find: `\n            && (request.resource.data.value == 1 || request.resource.data.value == -1)`,
    replace: ``,
    expectedKillers: ['Proof 2: Vote value 2 and 0 denied on create with unchanged counters', 'Denied vote transactions: unmatched counters, wrong deltas, invalid vote values, extra keys'],
  },
  {
    id: 'm3',
    description: 'value != previous value',
    find: `\n            && (request.method == 'create' || request.resource.data.value != resource.data.value)`,
    replace: ``,
    expectedKillers: ['Proof 3: Re-vote with same value denied', 'Denied vote transactions: unmatched counters, wrong deltas, invalid vote values, extra keys'],
  },
  {
    id: 'm4a',
    description: 'archived check on vote create/update',
    find: `          allow create, update: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)\n            && isTripNotArchived(tripId)`,
    replace: `          allow create, update: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)`,
    expectedKillers: ['Proof 4: Vote create, vote delete, and suggestion counter update on archived trip denied'],
  },
  {
    id: 'm4b',
    description: 'archived check on vote delete',
    find: `          allow delete: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)\n            && isTripNotArchived(tripId)`,
    replace: `          allow delete: if isSignedIn()\n            && uid == request.auth.uid\n            && isTripMember(tripId)`,
    expectedKillers: ['Proof 4: Vote create, vote delete, and suggestion counter update on archived trip denied'],
  },
  {
    id: 'm4c',
    description: 'archived check on suggestion counter update',
    find: `        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripNotArchived(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['upCount', 'downCount'])`,
    replace: `        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['upCount', 'downCount'])`,
    expectedKillers: ['Proof 4: Vote create, vote delete, and suggestion counter update on archived trip denied'],
  },
  {
    id: 'm5',
    description: 'vote read owner check (uid == auth uid)',
    find: `allow get, list: if isSignedIn() && uid == request.auth.uid && isTripMember(tripId);`,
    replace: `allow get, list: if isSignedIn() && isTripMember(tripId);`,
    expectedKillers: ['Votes read permissions: owner can read own vote, other member cannot read owner vote', 'Proof 5: Signed-out, non-member and other-member reads of vote document denied'],
  },
  {
    id: 'm5b',
    description: 'vote read member check',
    find: `allow get, list: if isSignedIn() && uid == request.auth.uid && isTripMember(tripId);`,
    replace: `allow get, list: if isSignedIn() && uid == request.auth.uid;`,
    expectedKillers: ['Proof 5: Signed-out, non-member and other-member reads of vote document denied'],
  },
  {
    id: 'm6',
    description: 'content-update hasOnly key restriction',
    find: `\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['title', 'note', 'estimatedCost', 'category'])`,
    replace: ``,
    expectedKillers: ['Proof 6a: Content update changing createdAt denied', 'Proof 6b: Content update changing authorId denied', 'Proof 6c: Content update changing status denied', 'Proof 6d: Content update changing dayIndex denied', 'Proof 6e: Content update changing order denied', 'Content edit: author and organizer succeed; non-author member denied; forbidden field edits denied'],
  },
  {
    id: 'm7a',
    description: 'delete author-or-organizer check',
    find: `\n          && (resource.data.authorId == request.auth.uid || isTripOrganizer(tripId));`,
    replace: `;`,
    expectedKillers: ['Suggestion delete: author and organizer succeed, other member denied'],
  },
  {
    id: 'm7b',
    description: 'delete member check',
    find: `        allow delete: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripNotArchived(tripId)\n          && (resource.data.authorId == request.auth.uid || isTripOrganizer(tripId));`,
    replace: `        allow delete: if isSignedIn()\n          && isTripNotArchived(tripId)\n          && (resource.data.authorId == request.auth.uid || isTripOrganizer(tripId));`,
    expectedKillers: ['Proof 7: Suggestion delete denied for non-member and signed-out user'],
  },
  {
    id: 'm8a',
    description: 'suggestion-side before != after and delta lines together',
    find: `\n          && getVoteBeforeVal(database, tripId, sid, request.auth.uid) != getVoteAfterVal(database, tripId, sid, request.auth.uid)\n          && request.resource.data.upCount == resource.data.upCount + getUpDelta(getVoteBeforeVal(database, tripId, sid, request.auth.uid), getVoteAfterVal(database, tripId, sid, request.auth.uid))\n          && request.resource.data.downCount == resource.data.downCount + getDownDelta(getVoteBeforeVal(database, tripId, sid, request.auth.uid), getVoteAfterVal(database, tripId, sid, request.auth.uid));`,
    replace: `;`,
    expectedKillers: ['Proof 8a: Plain suggestion counter update with NO vote change denied'],
  },
  {
    id: 'm8b',
    description: 'vote-side mirror delta lines together',
    find: `\n            && getAfter(/databases/$(database)/documents/trips/$(tripId)/suggestions/$(sid)).data.upCount == get(/databases/$(database)/documents/trips/$(tripId)/suggestions/$(sid)).data.upCount + getUpDelta(getVoteBeforeVal(database, tripId, sid, uid), request.resource.data.value)\n            && getAfter(/databases/$(database)/documents/trips/$(tripId)/suggestions/$(sid)).data.downCount == get(/databases/$(database)/documents/trips/$(tripId)/suggestions/$(sid)).data.downCount + getDownDelta(getVoteBeforeVal(database, tripId, sid, uid), request.resource.data.value);`,
    replace: `;`,
    expectedKillers: ['Proof 8b: Vote write with NO matching counter change denied'],
  },
  {
    id: 'm9',
    description: 'hasAll(resource.data.memberIds) check on trip join',
    find: `\n        && request.resource.data.memberIds.hasAll(resource.data.memberIds)`,
    replace: ``,
    expectedKillers: ['Join DENIED when caller pads memberIds with duplicate existing member to drop another member ([B, B, C] or [A, A, C])'],
  },
  {
    id: 'm10',
    description: 'users createdAt == request.time',
    find: `\n        && request.resource.data.createdAt == request.time;`,
    replace: `;`,
    expectedKillers: ['users create DENIED when createdAt is a client Date (not request.time)'],
  },
  {
    id: 'm11',
    description: 'organizer check on scheduling branch',
    find: `        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripOrganizer(tripId)\n          && isTripNotArchived(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'dayIndex', 'order'])`,
    replace: `        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripNotArchived(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'dayIndex', 'order'])`,
    expectedKillers: ['Scheduling denied for plain member, non-organizer author, non-member, signed out, archived trip'],
  },
  {
    id: 'm12',
    description: 'archived check on scheduling',
    find: `        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripOrganizer(tripId)\n          && isTripNotArchived(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'dayIndex', 'order'])`,
    replace: `        allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripOrganizer(tripId)\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'dayIndex', 'order'])`,
    expectedKillers: ['Scheduling denied for plain member, non-organizer author, non-member, signed out, archived trip'],
  },
  {
    id: 'm13',
    description: 'dayIndex upper bound',
    find: `\n              && request.resource.data.dayIndex <= (get(/databases/$(database)/documents/trips/$(tripId)).data.endDate.toMillis() - get(/databases/$(database)/documents/trips/$(tripId)).data.startDate.toMillis() + 43200000) / 86400000`,
    replace: ``,
    expectedKillers: ['Denied scheduling for invalid dayIndex, order, status values, coherence, and extra/mixed keys'],
  },
  {
    id: 'm14',
    description: 'status/dayIndex/order coherence',
    find: `\n          && (\n            (request.resource.data.status == 'pending' && request.resource.data.dayIndex == null && request.resource.data.order == null)\n            ||\n            (\n              request.resource.data.status == 'scheduled'\n              && request.resource.data.dayIndex is int\n              && request.resource.data.dayIndex >= 0\n              && request.resource.data.dayIndex <= (get(/databases/$(database)/documents/trips/$(tripId)).data.endDate.toMillis() - get(/databases/$(database)/documents/trips/$(tripId)).data.startDate.toMillis() + 43200000) / 86400000\n              && request.resource.data.order is int\n              && request.resource.data.order >= 0\n              && request.resource.data.order <= 10000\n            )\n          );`,
    replace: `;`,
    expectedKillers: ['Denied scheduling for invalid dayIndex, order, status values, coherence, and extra/mixed keys'],
  },
  {
    id: 'm15',
    description: 'hasOnly key restriction on scheduling',
    find: `\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['status', 'dayIndex', 'order'])`,
    replace: ``,
    expectedKillers: ['Denied scheduling for invalid dayIndex, order, status values, coherence, and extra/mixed keys'],
  },
  {
    id: 'm16',
    description: 'integer type checks',
    find: `\n              && request.resource.data.dayIndex is int\n              && request.resource.data.dayIndex >= 0\n              && request.resource.data.dayIndex <= (get(/databases/$(database)/documents/trips/$(tripId)).data.endDate.toMillis() - get(/databases/$(database)/documents/trips/$(tripId)).data.startDate.toMillis() + 43200000) / 86400000\n              && request.resource.data.order is int`,
    replace: `\n              && request.resource.data.dayIndex >= 0\n              && request.resource.data.dayIndex <= (get(/databases/$(database)/documents/trips/$(tripId)).data.endDate.toMillis() - get(/databases/$(database)/documents/trips/$(tripId)).data.startDate.toMillis() + 43200000) / 86400000`,
    expectedKillers: ['Denied scheduling for invalid dayIndex, order, status values, coherence, and extra/mixed keys'],
  },
  {
    id: 'm17',
    description: 'day bound without tolerance (+43200000)',
    custom: (rules) => {
      const newExpr = `(get(/databases/$(database)/documents/trips/$(tripId)).data.endDate.toMillis() - get(/databases/$(database)/documents/trips/$(tripId)).data.startDate.toMillis() + 43200000) / 86400000`;
      const oldExpr = `(get(/databases/$(database)/documents/trips/$(tripId)).data.endDate.toMillis() - get(/databases/$(database)/documents/trips/$(tripId)).data.startDate.toMillis()) / 86400000`;
      if (rules.split(newExpr).length - 1 !== 1) {
        throw new Error('m17: new expression not found exactly once');
      }
      return rules.replace(newExpr, oldExpr);
    },
    expectedKillers: ['Day bound tolerance: diff 47 hours (spring-forward) allows 2, denies 3', 'Day bound tolerance: diff 49 hours (fall-back) allows 2, denies 3'],
  },
  {
    id: 'm18',
    description: 'expense read member check',
    find: `      match /expenses/{expenseId} {\n        allow get, list: if isSignedIn() && isTripMember(tripId);`,
    replace: `      match /expenses/{expenseId} {\n        allow get, list: if isSignedIn();`,
    expectedKillers: ['Read: member succeeds; non-member and signed out denied'],
  },
  {
    id: 'm20',
    description: 'expense createdBy == caller check',
    find: `\n          && request.resource.data.createdBy == request.auth.uid`,
    replace: ``,
    expectedKillers: ['Create denied when createdBy is not the caller'],
  },
  {
    id: 'm21',
    description: 'expense create exact key sets (hasAll & hasOnly)',
    find: `\n          && request.resource.data.keys().hasAll(['amount', 'description', 'paidBy', 'participantIds', 'createdBy', 'date', 'createdAt'])\n          && request.resource.data.keys().hasOnly(['amount', 'description', 'paidBy', 'participantIds', 'createdBy', 'date', 'createdAt'])`,
    replace: ``,
    expectedKillers: ['Create denied for extra key or missing key'],
  },
  {
    id: 'm22',
    description: 'expense create amount validation',
    find: `request.resource.data.createdBy == request.auth.uid\n          && request.resource.data.amount is int && request.resource.data.amount >= 1 && request.resource.data.amount <= 100000000000`,
    replace: `request.resource.data.createdBy == request.auth.uid`,
    expectedKillers: ['Create denied for invalid amount (0, negative, float, string, over cap)'],
  },
  {
    id: 'm23',
    description: 'expense create description validation',
    find: `request.resource.data.createdBy == request.auth.uid\n          && request.resource.data.amount is int && request.resource.data.amount >= 1 && request.resource.data.amount <= 100000000000\n          && request.resource.data.description is string && request.resource.data.description.size() >= 1 && request.resource.data.description.size() <= 100`,
    replace: `request.resource.data.createdBy == request.auth.uid\n          && request.resource.data.amount is int && request.resource.data.amount >= 1 && request.resource.data.amount <= 100000000000`,
    expectedKillers: ['Create denied for invalid description (empty, >100 chars, non-string)'],
  },
  {
    id: 'm24',
    description: 'expense create paidBy member check',
    find: `request.resource.data.createdBy == request.auth.uid\n          && request.resource.data.amount is int && request.resource.data.amount >= 1 && request.resource.data.amount <= 100000000000\n          && request.resource.data.description is string && request.resource.data.description.size() >= 1 && request.resource.data.description.size() <= 100\n          && request.resource.data.paidBy is string && (request.resource.data.paidBy in get(/databases/$(database)/documents/trips/$(tripId)).data.memberIds)`,
    replace: `request.resource.data.createdBy == request.auth.uid\n          && request.resource.data.amount is int && request.resource.data.amount >= 1 && request.resource.data.amount <= 100000000000\n          && request.resource.data.description is string && request.resource.data.description.size() >= 1 && request.resource.data.description.size() <= 100`,
    expectedKillers: ['Create denied for invalid paidBy (not a member, non-string)'],
  },
  {
    id: 'm25',
    description: 'expense create participantIds member subset check',
    find: `request.resource.data.createdBy == request.auth.uid\n          && request.resource.data.amount is int && request.resource.data.amount >= 1 && request.resource.data.amount <= 100000000000\n          && request.resource.data.description is string && request.resource.data.description.size() >= 1 && request.resource.data.description.size() <= 100\n          && request.resource.data.paidBy is string && (request.resource.data.paidBy in get(/databases/$(database)/documents/trips/$(tripId)).data.memberIds)\n          && request.resource.data.participantIds is list\n          && request.resource.data.participantIds.size() >= 1 && request.resource.data.participantIds.size() <= 15\n          && get(/databases/$(database)/documents/trips/$(tripId)).data.memberIds.hasAll(request.resource.data.participantIds)`,
    replace: `request.resource.data.createdBy == request.auth.uid\n          && request.resource.data.amount is int && request.resource.data.amount >= 1 && request.resource.data.amount <= 100000000000\n          && request.resource.data.description is string && request.resource.data.description.size() >= 1 && request.resource.data.description.size() <= 100\n          && request.resource.data.paidBy is string && (request.resource.data.paidBy in get(/databases/$(database)/documents/trips/$(tripId)).data.memberIds)\n          && request.resource.data.participantIds is list\n          && request.resource.data.participantIds.size() >= 1 && request.resource.data.participantIds.size() <= 15`,
    expectedKillers: ['Create denied for invalid participantIds (empty, 16 elements, non-member, duplicates, non-list, non-strings)'],
  },
  {
    id: 'm26',
    description: 'expense create participantIds distinct check',
    find: `request.resource.data.createdBy == request.auth.uid\n          && request.resource.data.amount is int && request.resource.data.amount >= 1 && request.resource.data.amount <= 100000000000\n          && request.resource.data.description is string && request.resource.data.description.size() >= 1 && request.resource.data.description.size() <= 100\n          && request.resource.data.paidBy is string && (request.resource.data.paidBy in get(/databases/$(database)/documents/trips/$(tripId)).data.memberIds)\n          && request.resource.data.participantIds is list\n          && request.resource.data.participantIds.size() >= 1 && request.resource.data.participantIds.size() <= 15\n          && get(/databases/$(database)/documents/trips/$(tripId)).data.memberIds.hasAll(request.resource.data.participantIds)\n          && request.resource.data.participantIds.toSet().size() == request.resource.data.participantIds.size()`,
    replace: `request.resource.data.createdBy == request.auth.uid\n          && request.resource.data.amount is int && request.resource.data.amount >= 1 && request.resource.data.amount <= 100000000000\n          && request.resource.data.description is string && request.resource.data.description.size() >= 1 && request.resource.data.description.size() <= 100\n          && request.resource.data.paidBy is string && (request.resource.data.paidBy in get(/databases/$(database)/documents/trips/$(tripId)).data.memberIds)\n          && request.resource.data.participantIds is list\n          && request.resource.data.participantIds.size() >= 1 && request.resource.data.participantIds.size() <= 15\n          && get(/databases/$(database)/documents/trips/$(tripId)).data.memberIds.hasAll(request.resource.data.participantIds)`,
    expectedKillers: ['Create denied for invalid participantIds (empty, 16 elements, non-member, duplicates, non-list, non-strings)'],
  },
  {
    id: 'm27',
    description: 'expense create participantIds size bounds (1 to 15)',
    find: `request.resource.data.createdBy == request.auth.uid\n          && request.resource.data.amount is int && request.resource.data.amount >= 1 && request.resource.data.amount <= 100000000000\n          && request.resource.data.description is string && request.resource.data.description.size() >= 1 && request.resource.data.description.size() <= 100\n          && request.resource.data.paidBy is string && (request.resource.data.paidBy in get(/databases/$(database)/documents/trips/$(tripId)).data.memberIds)\n          && request.resource.data.participantIds is list\n          && request.resource.data.participantIds.size() >= 1 && request.resource.data.participantIds.size() <= 15`,
    replace: `request.resource.data.createdBy == request.auth.uid\n          && request.resource.data.amount is int && request.resource.data.amount >= 1 && request.resource.data.amount <= 100000000000\n          && request.resource.data.description is string && request.resource.data.description.size() >= 1 && request.resource.data.description.size() <= 100\n          && request.resource.data.paidBy is string && (request.resource.data.paidBy in get(/databases/$(database)/documents/trips/$(tripId)).data.memberIds)\n          && request.resource.data.participantIds is list`,
    expectedKillers: ['Create denied for invalid participantIds (empty, 16 elements, non-member, duplicates, non-list, non-strings)'],
  },
  {
    id: 'm28',
    description: 'expense update creator-or-organizer check',
    find: `\n          && (resource.data.createdBy == request.auth.uid || isTripOrganizer(tripId))\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['amount', 'description', 'paidBy', 'participantIds', 'date'])`,
    replace: `\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['amount', 'description', 'paidBy', 'participantIds', 'date'])`,
    expectedKillers: ['Update: creator and organizer succeed; other member and non-member denied'],
  },
  {
    id: 'm29',
    description: 'expense delete creator-or-organizer check',
    find: `        allow delete: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripNotArchived(tripId)\n          && (resource.data.createdBy == request.auth.uid || isTripOrganizer(tripId));`,
    replace: `        allow delete: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripNotArchived(tripId);`,
    expectedKillers: ['Delete: creator and organizer succeed; other member, non-member, signed out, and archived denied'],
  },
  {
    id: 'm30',
    description: 'expense create archived check',
    find: `match /expenses/{expenseId} {\n        allow get, list: if isSignedIn() && isTripMember(tripId);\n\n        allow create: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripNotArchived(tripId)`,
    replace: `match /expenses/{expenseId} {\n        allow get, list: if isSignedIn() && isTripMember(tripId);\n\n        allow create: if isSignedIn()\n          && isTripMember(tripId)`,
    expectedKillers: ['Create denied on archived trip'],
  },
  {
    id: 'm31',
    description: 'expense update archived check',
    find: `allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripNotArchived(tripId)\n          && (resource.data.createdBy == request.auth.uid || isTripOrganizer(tripId))\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['amount', 'description', 'paidBy', 'participantIds', 'date'])`,
    replace: `allow update: if isSignedIn()\n          && isTripMember(tripId)\n          && (resource.data.createdBy == request.auth.uid || isTripOrganizer(tripId))\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['amount', 'description', 'paidBy', 'participantIds', 'date'])`,
    expectedKillers: ['Update denied on archived trip'],
  },
  {
    id: 'm32',
    description: 'expense delete archived check',
    find: `        allow delete: if isSignedIn()\n          && isTripMember(tripId)\n          && isTripNotArchived(tripId)\n          && (resource.data.createdBy == request.auth.uid || isTripOrganizer(tripId));`,
    replace: `        allow delete: if isSignedIn()\n          && isTripMember(tripId)\n          && (resource.data.createdBy == request.auth.uid || isTripOrganizer(tripId));`,
    expectedKillers: ['Delete: creator and organizer succeed; other member, non-member, signed out, and archived denied'],
  },
  {
    id: 'm33',
    description: 'expense update affectedKeys hasOnly restriction',
    find: `\n          && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['amount', 'description', 'paidBy', 'participantIds', 'date'])\n          && request.resource.data.amount is int`,
    replace: `\n          && request.resource.data.amount is int`,
    expectedKillers: ['Update denied when changing createdBy or createdAt'],
  },
  {
    id: 'm34',
    description: 'expense create createdAt == request.time check',
    find: `\n          && request.resource.data.date is timestamp\n          && request.resource.data.createdAt == request.time;`,
    replace: `\n          && request.resource.data.date is timestamp;`,
    expectedKillers: ['Create denied when date is not a timestamp or createdAt is a client date'],
  },
  {
    id: 'm35',
    description: 'expense create date timestamp type check',
    find: `\n          && request.resource.data.date is timestamp\n          && request.resource.data.createdAt == request.time;`,
    replace: `\n          && request.resource.data.createdAt == request.time;`,
    expectedKillers: ['Create denied when date is not a timestamp or createdAt is a client date'],
  },
  // Phase 6 specific mutants m53..m61
      {
    id: 'm53',
    description: 'leave rule drop memberIds.size() == memberCount check',
    find: `\n        && request.resource.data.memberIds.size() == request.resource.data.memberCount\n        && request.resource.data.memberIds.toSet().size() == request.resource.data.memberCount`,
    replace: `\n        && request.resource.data.memberIds.toSet().size() == request.resource.data.memberCount`,
    expectedKillers: [
      'memberCount unchanged while dropping UID denied',
      'memberCount decreased by 2 while dropping 1 UID denied',
      'a) memberIds [A,B,C]->[A,A,C], memberCount 3->2, B leaves (denied)',
      'b) [A,B]->[A,A], count 2->1, B leaves (denied)',
      'c) [A,B,C]->[A,C,C], count 3->2, B removed by organizer (denied)'
    ],
  },
  {
    id: 'm54',
    description: 'leave rule drop memberIds.toSet().size() == memberCount check',
    find: `\n        && request.resource.data.memberIds.toSet().size() == request.resource.data.memberCount\n        && resource.data.archived == false`,
    replace: `\n        && resource.data.archived == false`,
    expectedKillers: [
      'a) memberIds [A,B,C]->[A,A,C], memberCount 3->2, B leaves (denied)',
      'c) [A,B,C]->[A,C,C], count 3->2, B removed by organizer (denied)',
      'b) [A,B]->[A,A], count 2->1, B leaves (denied)',
      'Padding attack denial - cannot add uid while removing'
    ],
  },
  {
    id: 'm55',
    description: 'drop status == active from join update rule',
    find: `\n        && getAfter(/databases/$(database)/documents/trips/$(tripId)/members/$(request.auth.uid)).data.status == 'active';`,
    replace: `;`,
    expectedKillers: ['Rejoin by previously left member denied directly through memberIds update'],
  },
  {
    id: 'm56',
    description: 'settlement update allows payer to confirm own settlement',
    find: `\n          && (request.auth.uid == resource.data.toUid || (isTripOrganizer(tripId) && resource.data.fromUid != request.auth.uid));`,
    replace: `\n          && (request.auth.uid == resource.data.toUid || request.auth.uid == resource.data.fromUid || (isTripOrganizer(tripId) && resource.data.fromUid != request.auth.uid));`,
    expectedKillers: ['Settlement update: payer confirming own settlement denied'],
  },
  {
    id: 'm57',
    description: 'settlement delete allows non-payer',
    find: `\n          && request.auth.uid == resource.data.fromUid`,
    replace: ``,
    expectedKillers: ['Settlement delete: receiver delete denied', 'Settlement delete: organizer delete denied', 'Settlement delete: non-member delete denied'],
  },
  {
    id: 'm58',
    description: 'leave rule drops archived == false',
    find: `\n        && resource.data.archived == false\n        && existsAfter(/databases/$(database)/documents/trips/$(tripId)/members/$(resource.data.memberIds.removeAll(request.resource.data.memberIds)[0]))`,
    replace: `\n        && existsAfter(/databases/$(database)/documents/trips/$(tripId)/members/$(resource.data.memberIds.removeAll(request.resource.data.memberIds)[0]))`,
    expectedKillers: ['Cannot leave/remove from archived trip'],
  },
  {
    id: 'm59',
    description: 'leave rule drops existsAfter member doc check',
    find: `\n        && existsAfter(/databases/$(database)/documents/trips/$(tripId)/members/$(resource.data.memberIds.removeAll(request.resource.data.memberIds)[0]))\n        && getAfter(/databases/$(database)/documents/trips/$(tripId)/members/$(resource.data.memberIds.removeAll(request.resource.data.memberIds)[0])).data.status == 'left'`,
    replace: `\n        && getAfter(/databases/$(database)/documents/trips/$(tripId)/members/$(resource.data.memberIds.removeAll(request.resource.data.memberIds)[0])).data.status == 'left'`,
    expectedKillers: ['Batch missing members status doc write denied', 'Marking status "left" WITHOUT removing uid from memberIds is denied'],
  },
  {
    id: 'm60',
    description: 'leave rule drops status == left check',
    find: `\n        && getAfter(/databases/$(database)/documents/trips/$(tripId)/members/$(resource.data.memberIds.removeAll(request.resource.data.memberIds)[0])).data.status == 'left'\n        && getAfter(/databases/$(database)/documents/trips/$(tripId)/members/$(resource.data.memberIds.removeAll(request.resource.data.memberIds)[0])).data.diff(get(/databases/$(database)/documents/trips/$(tripId)/members/$(resource.data.memberIds.removeAll(request.resource.data.memberIds)[0])).data).affectedKeys().hasOnly(['status']);`,
    replace: `\n        && getAfter(/databases/$(database)/documents/trips/$(tripId)/members/$(resource.data.memberIds.removeAll(request.resource.data.memberIds)[0])).data.diff(get(/databases/$(database)/documents/trips/$(tripId)/members/$(resource.data.memberIds.removeAll(request.resource.data.memberIds)[0])).data).affectedKeys().hasOnly(['status']);`,
    expectedKillers: ['Member status updated to something other than left denied', 'Member doc update with fields other than status denied'],
  },
  {
    id: 'm61',
    description: 'leave rule drops organizer self-removal protection',
    find: `\n        && !(resource.data.memberIds.removeAll(request.resource.data.memberIds)[0] == resource.data.organizerId && resource.data.memberIds.removeAll(request.resource.data.memberIds)[0] == request.auth.uid)`,
    replace: ``,
    expectedKillers: ['Cannot remove the organizer (including organizer leaving)', 'Organizer self-removal denied'],
  }
];

function main() {
  const results = [];
  let baselineFailed = false;
  let anyError = false;
  let anyUnexpected = false;
  let anyUnallowlistedSurvivor = false;

  console.log('Starting Mutation Runner against ambient emulator...\n');

  for (const mut of mutants) {
    if (mut.isBaseline) continue;
    if (!mut.custom) {
      const count = originalRules.split(mut.find).length - 1;
      if (count !== 1) {
        console.error(`INVALID: Mutant ${mut.id} (${mut.description}) find string matches ${count} times (expected exactly 1).`);
        anyError = true;
      }
    }
  }
  if (anyError) {
    console.error('Aborting due to INVALID mutant definitions.');
    process.exit(1);
  }

  for (const mut of mutants) {
    let mutantRules;
    try {
      if (mut.custom) {
        mutantRules = mut.custom(originalRules);
      } else {
        mutantRules = originalRules.replace(mut.find, mut.replace);
      }
    } catch (e) {
      console.error(`ERROR: Mutant ${mut.id} generation failed: ${e.message}`);
      results.push({ id: mut.id, description: mut.description, status: 'ERROR', killedBy: '-', collateral: '-' });
      anyError = true;
      continue;
    }

    if (!mut.isBaseline && mutantRules === originalRules) {
      console.error(`ERROR: Mutant ${mut.id} is identical to original rules.`);
      results.push({ id: mut.id, description: mut.description, status: 'ERROR', killedBy: '-', collateral: '-' });
      anyError = true;
      continue;
    }

    const mutantPath = path.resolve(outDir, `${mut.id}.rules`);
    fs.writeFileSync(mutantPath, mutantRules, 'utf8');

    console.log(`Running mutant [${mut.id}]: ${mut.description}...`);

    let suiteJson = null;
    let suiteError = false;

    try {
      execSync(
        `node node_modules/jest/bin/jest.js firestore_rules.test.js --runInBand --forceExit --json --outputFile=mutation_run.json`,
        {
          cwd: path.join(rootDir, 'rules_test'),
          env: { ...process.env, RULES_PATH: mutantPath },
          encoding: 'utf8',
          stdio: 'ignore',
        }
      );
    } catch (err) {
      // test failures cause jest exit != 0, which is expected when mutants are killed
    }

    const jsonResultPath = path.join(rootDir, 'rules_test', 'mutation_run.json');
    if (fs.existsSync(jsonResultPath)) {
      try {
        suiteJson = JSON.parse(fs.readFileSync(jsonResultPath, 'utf8'));
      } catch (e) {
        suiteError = true;
      }
    } else {
      suiteError = true;
    }

    if (suiteError || !suiteJson) {
      console.error(`  -> ERROR: Test suite crashed or failed to compile for mutant ${mut.id}.`);
      results.push({ id: mut.id, description: mut.description, status: 'ERROR', killedBy: 'Suite Crash / Compile Error', collateral: '-' });
      anyError = true;
      continue;
    }

    const failedTitles = [];
    suiteJson.testResults.forEach(tr => {
      tr.assertionResults.forEach(ar => {
        if (ar.status === 'failed') {
          failedTitles.push(ar.title);
        }
      });
    });

    if (mut.isBaseline) {
      if (failedTitles.length > 0) {
        baselineFailed = true;
        console.error(`  -> ERROR: BASELINE CONTROL (m0) FAILED! (${failedTitles.length} failures)`);
        results.push({ id: mut.id, description: mut.description, status: 'BASELINE_FAILED', killedBy: '-', collateral: '-' });
      } else {
        console.log(`  -> BASELINE CONTROL PASSED (0 failures).`);
        results.push({ id: mut.id, description: mut.description, status: 'PASSED', killedBy: '-', collateral: '-' });
      }
      continue;
    }

    const expectedSet = new Set(mut.expectedKillers || []);
    const actualKillers = failedTitles.filter(t => expectedSet.has(t));
    const collateral = failedTitles.filter(t => !expectedSet.has(t));

    let status = 'SURVIVED';
    let killedByStr = '-';
    let collateralStr = '-';

    if (actualKillers.length > 0) {
      status = 'KILLED';
      killedByStr = actualKillers.join('; ');
      if (collateral.length > 0) {
        collateralStr = collateral.join('; ');
      }
      console.log(`  -> KILLED by expected test(s): ${actualKillers.join(', ')}`);
    } else if (collateral.length > 0) {
      status = 'UNEXPECTED';
      collateralStr = collateral.join('; ');
      console.log(`  -> UNEXPECTED FAILURE: ${collateral.join(', ')}`);
      anyUnexpected = true;
    } else {
      status = 'SURVIVED (UNALLOWLISTED)';
      console.log(`  -> SURVIVED (UNALLOWLISTED)!`);
      anyUnallowlistedSurvivor = true;
    }

    results.push({
      id: mut.id,
      description: mut.description,
      status,
      killedBy: killedByStr,
      collateral: collateralStr,
    });
  }

  const finalRulesHash = getFileSha256(originalRulesPath);
  if (initialRulesHash !== finalRulesHash) {
    console.error('FATAL: firestore.rules hash changed during mutation run!');
    process.exit(1);
  }

  if (baselineFailed) {
    console.error('FATAL: Baseline m0 failed.');
    process.exit(1);
  }

  console.log('\n================================ MUTATION SUMMARY TABLE ================================');
  console.log('| ID | Description | Status | Killed-By | Collateral |');
  console.log('|---|---|---|---|---|');
  for (const r of results) {
    console.log(`| ${r.id} | ${r.description} | ${r.status} | ${r.killedBy} | ${r.collateral} |`);
  }
  console.log('=======================================================================================\n');

  const total = results.filter(r => r.id !== 'm0').length;
  const killed = results.filter(r => r.status === 'KILLED').length;
  const survivedUnallowlisted = results.filter(r => r.status.includes('UNALLOWLISTED')).length;
  const invalid = results.filter(r => r.status === 'INVALID').length;
  const errorCount = results.filter(r => r.status === 'ERROR').length;
  const unexpected = results.filter(r => r.status === 'UNEXPECTED').length;

  console.log(`Total Mutants: ${total}`);
  console.log(`Killed: ${killed}`);
  console.log(`Survived (Unallowlisted): ${survivedUnallowlisted}`);
  console.log(`Invalid: ${invalid}`);
  console.log(`Error: ${errorCount}`);
  console.log(`Unexpected: ${unexpected}`);

  const finalExit = (baselineFailed || anyError || anyUnexpected || anyUnallowlistedSurvivor || survivedUnallowlisted > 0) ? 1 : 0;
  console.log(`EXIT CODE: ${finalExit}`);
  process.exit(finalExit);
}

main();
