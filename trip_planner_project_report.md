# Wayfound: Project Planning Report

*Wayfound is a collaborative trip planner for groups.*

**Stack:** Flutter (Dart) + Firebase  |  **Level:** Intermediate  |  **Prepared:** October 4, 2026 (Updated: October 6, 2026)
**Status:** Milestone 0, Milestone 1, Milestone 2, Milestone 3, Milestone 4 & Milestone 5 complete (Phase 0 setup, Phase 1 auth, Phase 2 trips, Phase 3 suggestions & voting, Phase 4 itinerary, Phase 5 expenses & balances finished)

---

## 1. Overview

### 1.1 Purpose
Wayfound is a shared mobile app where a group plans a trip together: members suggest places and activities, vote on them, the organizer turns winners into a day-by-day itinerary, and the group tracks expenses and settles up fairly.

### 1.2 Problem
Group trip planning is scattered across chats, spreadsheets and screenshots. Ideas get buried, decisions drag, everyone holds a different version of the plan, and money gets awkward afterward.

### 1.3 Users
- **Groups of 3 to 15 people** (friends, family, colleagues)
- **Organizer:** carries the planning load, wants fewer chasing messages
- **Member:** wants to suggest, vote and see the plan without friction

### 1.4 Non-goals (version 1)
Booking flights/hotels, public or social trip sharing, AI itinerary generation, payment processing, offline-first sync, multi-currency trips.

### 1.5 Success criteria
A group can create a trip, agree on an itinerary by voting, log expenses, and see exactly who owes whom, with every change appearing live on every member's device.

---

## 2. Decisions Log

| Area | Decision |
|---|---|
| App name | Wayfound |
| Platform | Android only for now (Kotlin); other platforms can be added later |
| Visual theme | Ocean Blue + Teal palette, light and dark modes (Section 14) |
| Palette gaps | Filled with derived colours (Section 14.5) |
| Logo | Supplied in `assets/images/logo.png` |
| Theme switching | System / Light / Dark; quick toggle button plus settings selector (`SegmentedButton`); saved on device |
| Group size | Up to 15 members per trip |
| Sign-in | Email/password and Google via Firebase Authentication; persistent session; photos from Google only (no Storage upload in v1) |
| Itinerary placement | Organizer only |
| Suggestion edit/delete | Author and organizer |
| Expense split | Equal split only (v1) |
| Join method | Short typed code only (no share links) |
| Currency | One per trip, set at creation |
| Join enforcement | Security Rules only; no Cloud Functions |
| Leaving a trip | Only when balance is zero; organizer can always remove |
| Settling | Payer marks paid, receiver confirms; only confirmed settlements count |
| Trip deletion | Archive instead of delete |
| State management | Riverpod (3.x AsyncNotifier) |
| Navigation | go_router with auth redirect (`/welcome`, `/sign-in`, `/sign-up`, `/home`, `/settings`) |
| Folder structure | Feature-first |

---

## 3. Features and Scope

### 3.1 Must-have (version 1)
- **Accounts:** sign up, log in, log out; display name and optional photo (photos imported automatically from Google sign-in; no file upload or Firebase Storage in v1)
- **Trips:** create (name, destination, dates, currency); join by code; "My Trips" list; roles organizer/member
- **Suggestions:** title, note, estimated cost, category (food, sightseeing, stay, transport); one up/down vote per member; live counts
- **Itinerary:** organizer assigns suggestions to a day and order; day-by-day live view
- **Expenses:** amount, payer, participants, description, date; equal split
- **Balances and settlements:** computed balances, minimal suggested payments, mark-as-paid and confirm flow
- **Theming:** light and dark themes from the Ocean Blue + Teal palette, with a theme-change button (Section 14)

### 3.2 Nice-to-have (version 2)
Push notifications, comments on suggestions, photos, shared packing checklist, unequal splits, map view, multiple currencies, PDF export.

---

## 4. Roles and Permissions

| Action | Organizer | Member | Non-member |
|---|---|---|---|
| Read trip data | Yes | Yes | No |
| Edit trip details | Yes | No | No |
| Archive trip | Yes | No | No |
| Add suggestion | Yes | Yes | No |
| Edit/delete suggestion | Yes | Own only | No |
| Vote | Own vote | Own vote | No |
| Schedule suggestion | Yes | No | No |
| Add expense | Yes | Yes | No |
| Edit/delete expense | Yes | Own only | No |
| Create settlement ("I paid") | Yes | Yes (as payer) | No |
| Confirm/reject settlement | Yes (also on behalf of others) | Receiver only | No |
| Remove member | Yes | No | No |
| Join | n/a | n/a | Yes, under join conditions |

---

## 5. User Flows and Screens

### 5.1 Flows
- **A. Getting started:** Welcome (`/welcome`), Sign In (`/sign-in`), Sign Up (`/sign-up`), Home (`/home`). Empty Home offers stacked centered actions ("Create a Trip" primary filled and "Join with Code" secondary outlined), plus expandable FAB menu ("Create Trip" and "Join Trip").
- **B. Create:** form, trip created with user as organizer, invite screen shows the code.
- **C. Join:** enter code, preview (name, destination, member count), confirm. Full trips show "trip is full".
- **D. Plan:** Trip Dashboard with tabs Suggestions, Itinerary, Expenses, Members. Add suggestions, vote; organizer schedules.
- **E. Money:** add expense; Balances view lists net positions and suggested payments; mark paid / confirm received.

### 5.2 Screen inventory

| # | Screen | Route | Purpose |
|---|---|---|---|
| 1 | Welcome | `/welcome` | Entry point for unauthenticated users |
| 2 | Sign In | `/sign-in` | Email/password and Google login |
| 3 | Sign Up | `/sign-up` | Create account with display name, email, password, confirm |
| 4 | Home (My Trips) | `/home` | Trip list, expandable FAB menu (Create/Join), empty state dual actions, theme toggle, avatar button to Settings |
| 5 | Create Trip | `/trip/create` | Name, destination, dates, currency |
| 6 | Join Trip | `/trip/join` | Code entry, preview, confirm |
| 7 | Trip Dashboard | `/trip/:id` | Container with four tabs |
| 8 | Suggestions tab | `/trip/:id/suggestions` | List with vote controls |
| 9 | Add/Edit Suggestion | `/trip/:id/suggestions/add`, `/trip/:id/suggestions/:sid/edit` | Title, note, cost, category (pushed on top of dashboard) |
| 10 | Itinerary tab | `/trip/:id/itinerary` | Day-by-day confirmed plan with organizer day assignment, drag-to-reorder, and pending suggestions sheet |
| 11 | Expenses tab | `/trip/:id/expenses` | Expense list plus Balances view |
| 12 | Add Expense | `/trip/:id/expenses/add` | Amount, payer, participants, description |
| 13 | Members tab | `/trip/:id/members` | Members, invite code, remove (organizer) |
| 14 | Profile / Settings | `/settings` | Avatar/initials, display name edit, theme selector (`SegmentedButton`), sign out |

### 5.3 Edge cases to design for
Trip full; invalid join code; member leaves (history kept, marked "left"); trip archived; empty states on every tab; loading and error states on every stream-based screen; leaving blocked while balance is nonzero.

---

## 6. Data Model (Cloud Firestore)

### 6.1 Structure
```
users/{uid}
trips/{tripId}
  members/{uid}
  suggestions/{suggestionId}
    votes/{uid}
  expenses/{expenseId}
  settlements/{settlementId}
joinCodes/{code}
```

### 6.2 Document fields

| Path | Fields |
|---|---|
| `users/{uid}` | displayName, photoUrl (nullable), email, createdAt (server timestamp) |
| `trips/{tripId}` | name, destination, startDate, endDate, currency, organizerId, joinCode, memberIds (array, max 15), memberCount, archived, createdAt |
| `trips/.../members/{uid}` | displayName, photoUrl, role (organizer/member), status (active/left), joinedAt |
| `trips/.../suggestions/{id}` | title, note, estimatedCost, category, authorId, upCount, downCount, status (pending/scheduled), dayIndex, order, createdAt |
| `.../suggestions/{id}/votes/{uid}` | value (+1/-1), updatedAt |
| `trips/.../expenses/{id}` | amount, description, paidBy, participantIds, createdBy, date, createdAt |
| `trips/.../settlements/{id}` | fromUid, toUid, amount, status (pending/confirmed/rejected), createdAt, resolvedAt |
| `joinCodes/{code}` | tripId |

### 6.3 Design choices and reasons
1. **Itinerary is not a collection.** A scheduled item is a suggestion with `status = scheduled`, `dayIndex` and `order`. Less data to keep in sync.
2. **Money is stored as integers** in the smallest currency unit (e.g. 12550 for 125.50), avoiding floating-point errors.
3. **Balances are computed, never stored.** They cannot drift out of sync with expenses. Only confirmed settlements change balances; pending settlements do not affect balances.
4. **Vote documents use the voter's uid as ID**, which enforces one vote per person.
5. **Vote counters are stored** on the suggestion and updated in a transaction, so lists do not read every vote.
6. **`memberIds` on the trip** makes "my trips" a single `array-contains` query and keeps rules simple.
7. **Member names are copied into `members/`** for fast display; name changes may lag (acceptable).
8. **`joinCodes` exists** because a non-member cannot query `trips`; they look up the code, get the trip ID, then join.
9. **Leaving and removal** executes in a single batch removing the uid from `memberIds`, decrementing `memberCount` by 1, and updating `members/{uid}.status = 'left'`. Historical expenses and votes are preserved; left members remain visible in balances marked "(left)". Expenses involving a left member cannot be edited. No rejoin in v1 (rejoining a left member is denied by security rules).

---

## 7. Security Rules Plan

### 7.1 Helper checks
**isSignedIn**, **isMember** (uid in trip `memberIds`), **isOrganizer** (uid equals `organizerId`), **isOwner(userId)** (`request.auth.uid == userId`). Nearly every rule combines these with an author/creator check.

### 7.2 Users collection rules
- `get`: allowed only by owner (`request.auth.uid == userId`).
- `list` and `delete`: denied for everyone.
- `create`: allowed by owner with exact keys `['displayName', 'photoUrl', 'email', 'createdAt']`, `email` matching `request.auth.token.email`, `displayName` string length between 1 and 50 chars, `createdAt` equal to `request.time` (strictly enforced; client timestamp alternative removed).
- `update`: allowed by owner changing ONLY `displayName` or `photoUrl`, with same name length validation.

### 7.3 Join rule
Flow: the user reads `joinCodes/{code}` (single get allowed for signed-in users; **listing blocked**), then sends one batched write.

A non-member may update a trip only if:
- only `memberIds` and `memberCount` change
- `memberIds` retains all existing members (`request.resource.data.memberIds.hasAll(resource.data.memberIds)`)
- exactly one uid is added, and it is the caller's own
- `memberCount` is currently below 15
- `memberCount` increases by exactly 1

### 7.4 Other rules
- **Votes:** document ID must equal caller uid; value must be +1 or -1.
- **Counters:** any member may change `upCount`/`downCount` by at most 1 and nothing else in that update.
- **Suggestions:** authors change only title, note, cost, category; only the organizer changes `status`, `dayIndex`, `order`. Updates are strictly validated with `diff(resource.data).affectedKeys().hasOnly(['status', 'dayIndex', 'order'])`, integer checks, trip date range bounds `dayIndex <= (endDate.toMillis() - startDate.toMillis() + 43200000) / 86400000` (rounding form tolerating 23h or 25h DST days), order bounds `[0, 10000]`, and coherence validation (`pending` requires null `dayIndex`/`order`; `scheduled` requires non-null integer `dayIndex`/`order`).
- **Document Access Margin (Scheduling Path):** The scheduling security rule executes 4 `get()` calls on the parent trip document (`isTripMember`, `isTripOrganizer`, `isTripNotArchived`, and date range bound). Margin under 20 limit is 16 document access calls.
- **Expenses:** creator or organizer may edit/delete; `createdBy` must equal caller on create. Expenses involving a left member cannot be edited.
- **Settlements:** create only as payer (`fromUid == request.auth.uid`, status `pending`); only the receiver (or organizer when not the payer) may set `confirmed` or `rejected`; payer may delete own pending; amount, `fromUid`, and `toUid` are immutable after creation.
- **Leaving and Member Removal:** atomic batch removing caller from `memberIds`, decrementing `memberCount` by 1, and updating `members/{uid}.status = left`. Organizer cannot leave and cannot be removed; organizer can remove any active member. Left members cannot rejoin (rejoining a left member is denied by rules: member document must either not exist or status must not be 'left').
- **Archiving:** organizer sets `archived = true`; archived trips are read-only for everyone.

### 7.5 Known limitations & Counter Integrity
- Stored vote counters (`upCount`, `downCount`) are protected by `getAfter` rules requiring exact correlation with atomic vote document changes. Plain counter updates without matching vote transitions are strictly denied.
- Short join codes could in theory be brute-forced; plan Firebase App Check as a later hardening step.
- Subcollections are not removed when a trip document is deleted, which is why trips are archived rather than deleted.
- **No Archive UI in v1:** Trips support the `archived` boolean in security rules, but no client UI exists to trigger archiving in v1.
- **No Rejoin in v1:** Once a member leaves or is removed, they cannot rejoin the trip; rules explicitly deny join if the member doc status is 'left'.
- **No Organizer Transfer in v1:** The trip organizer cannot leave the trip and cannot transfer the organizer role to another member in v1.
- **Client-Side Leave Eligibility:** The check requiring zero balance and zero pending settlements before leaving is enforced client-side in `checkLeaveEligibility`; security rules enforce membership shape and status transitions, not monetary balances.
- **Left Member Doc Read:** A user who has left a trip no longer belongs to `memberIds`, so they cannot read their own previous member document.
- **BalancesView Layout:** In Session P6-S3c, `lib/features/expenses/presentation/balances_view.dart` was refactored from nested ListViews to Column-based structures with re-laid-out suggested payment tiles to prevent scroll conflicts.
- **MarkAsPaidSheet Keyboard on Small Screens:** The sheet sets `isScrollControlled: true` (as documented in `docs/evidence/p6s4/S1_sheet.txt`), but keyboard behavior on physical compact screens requires device verification.
- **Release SHA-1 and App Check Pending:** Release SHA-1 and Firebase App Check remain pending before production app store release.
- **Add to Itinerary on Suggestions Pending:** Direct 1-tap "Add to itinerary" shortcut from the suggestions list remains a backlog item.

---

## 8. Key Logic

### 8.1 Voting (single transaction: read vote, write vote, adjust counters)

| Before | Action | Result |
|---|---|---|
| No vote | Up | Create +1; upCount +1 |
| No vote | Down | Create -1; downCount +1 |
| Up | Down | Set -1; upCount -1, downCount +1 |
| Down | Up | Set +1; downCount -1, upCount +1 |
| Up | Up again | Delete vote; upCount -1 |
| Down | Down again | Delete vote; downCount -1 |

Score = upCount - downCount. Sort by score descending; ties broken by oldest first.

### 8.2 Equal split
Amount in minor units divided by participant count. Leftover units go one each to the first few participants in a fixed order (sorted by uid), so shares always sum exactly (1000 among 3 gives 334, 333, 333).

### 8.3 Balances
Start all at zero. For each expense: payer gets **+amount**, each participant gets **-share**. For each **confirmed** settlement: payer (`fromUid`) gets **+amount**, receiver (`toUid`) gets **-amount**. Positive means owed money; negative means owes. All balances must sum to zero (use as a sanity check). Pending settlements do not affect balances. Left members stay in balances marked "(left)".

### 8.4 Settle-up (minimal payments)
Repeat: take the largest debtor and largest creditor; the debtor pays the smaller of the two amounts; update both; stop when all are zero. Produces at most (people - 1) payments. Recomputed on every change, so suggestions stay correct.

### 8.5 Worked example
Asha pays 900 for dinner (split 3 ways); Ravi pays 300 for a cab (split 3 ways).
- Dinner: Asha +600, Ravi -300, Sam -300
- Cab: Ravi +200, Asha -100, Sam -100
- **Net: Asha +500, Ravi -100, Sam -400**
- **Settle-up: Sam pays Asha 400; Ravi pays Asha 100**

### 8.6 Knowing someone has paid
The app cannot see real money moving. It uses a two-step record:
1. Payer pays outside the app (cash, transfer, any payment app).
2. Payer taps **Mark as paid**, creating a `pending` settlement.
3. Receiver, or organizer when not the payer, taps **Confirm received** (`confirmed`) or **Not received** (`rejected`). Payer may delete own pending settlement.
4. Only `confirmed` settlements change balances. Pending ones display as "awaiting confirmation". Partial payments are allowed. A rejected settlement leaves the debt unchanged.

### 8.7 Leaving a trip
Allowed only when the member's balance is zero and there are no pending settlements involving the member (client-enforced via `checkLeaveEligibility`). The organizer cannot leave and has no transfer in v1. The organizer can remove any member anytime; their historical expenses and votes remain. Leave and member removal execute as a single atomic batch (`memberIds`, `memberCount`, and `members/{uid}.status = left`). Rejoining after leaving is denied by rules; the app displays the refusal message. Left members stay in balances marked "(left)", and expenses involving a left member cannot be edited.

### 8.8 Calendar Day Computation
Trip days and itinerary dates are calculated strictly using UTC calendar arithmetic (`DateTime.utc(year, month, day)`). `tripDays(startDate, endDate)` computes total inclusive days from UTC midnight timestamps, completely avoiding daylight savings (23-hour or 25-hour days) and local time-zone shifts. `dayDate(startDate, dayIndex)` derives the exact calendar date for a given index by adding days in UTC space. All calculations depend solely on year, month, and day calendar fields regardless of local time of day.

---

## 9. Flutter Architecture

### 9.1 Layers
**Repositories** are the only code that touches Firebase. **Providers** (Riverpod) expose streams and actions. **Screens** only watch providers. Firestore streams map to `StreamProvider`; loading/error/data handled with `AsyncValue`.
All user profile data shown in the UI (display name, avatar initials, photo URL) comes from the live `users/{uid}` document stream provider (`appUserProvider`), not directly from `FirebaseAuth.currentUser`, ensuring instant UI updates across screens when profile details change.

### 9.2 Folder layout
```
lib/
  main.dart
  app/            router.dart (go_router + auth redirect)
  app/theme/      app_colors.dart, app_theme.dart, theme_provider.dart
  core/           firebase_providers.dart, money.dart, widgets/
  features/
    auth/         data/ domain/ presentation/
                  domain/app_user.dart, auth_validators.dart
    trips/        data/ domain/ presentation/
    suggestions/  data/ domain/ presentation/
    itinerary/    data/ domain/ presentation/
                  domain/itinerary_item_update.dart
    expenses/     data/ domain/ presentation/
                  domain/balance_calculator.dart  (pure Dart)
    settlements/  data/ domain/
```

Key implementation files:
- `lib/main.dart`
- `lib/app/router.dart`
- `lib/app/theme/app_colors.dart`
- `lib/app/theme/app_theme.dart`
- `lib/app/theme/theme_provider.dart`
- `lib/core/firebase_providers.dart`
- `lib/core/money.dart`
- `lib/features/auth/domain/app_user.dart`
- `lib/features/auth/domain/auth_validators.dart`
- `lib/features/itinerary/domain/itinerary_logic.dart`
- `lib/features/expenses/domain/balance_calculator.dart`
- `lib/features/settlements/data/settlement_repository.dart`
- `lib/features/settlements/data/settlements_providers.dart`
- `lib/features/settlements/domain/settlement.dart`
- `lib/features/settlements/domain/leave_eligibility.dart`

### 9.3 Models
Plain Dart classes with `fromFirestore` / `toFirestore`: AppUser, Trip, Member, Suggestion, Vote, Expense, Settlement.

### 9.4 Navigation
go_router with routes `/welcome`, `/sign-in`, `/sign-up`, `/home`, `/settings`. Auth redirect sends signed-out users to welcome and signed-in users away from auth screens. Navigation rule: Tab switching uses `context.go('/trip/:id/$tab')`. Form and detail screens (Add/Edit Suggestion, Create Trip, Join Trip) are pushed on top of the current screen using `context.push(...)` so saving or popping returns directly to the active tab. Parent `/trip/:id` redirect checks `state.uri.path` for exact matches (`/trip/$id` or `/trip/$id/`) to prevent subroute redirect collisions.

### 9.5 Packages

| Purpose | Package |
|---|---|
| Firebase setup | firebase_core |
| Login | firebase_auth, google_sign_in (7.x API) |
| Database | cloud_firestore |
| State | flutter_riverpod (3.x AsyncNotifier) |
| Navigation | go_router |
| Formatting | intl |
| Theme persistence | shared_preferences |
| Dev & Testing | fake_cloud_firestore, firebase_auth_mocks, google_sign_in_mocks, flutter_test |

---

## 10. Testing Plan

1. **Unit & Widget tests** (Flutter): 323 passing tests (verified in `docs/evidence/p6s3d/G_counts.txt`) with 0 analyzer issues and 0 format changes (`docs/evidence/p6s3d/G_analyze.txt`, `docs/evidence/p6s3d/G_format.txt`). Includes complete coverage across theme mode persistence, theme toggle logic, ColorScheme palette checks, shared widgets rendering, router navigation (`/welcome`, `/sign-in`, `/sign-up`, `/home`, `/settings`, `/trip/:id`, plus 7 real-router navigation widget tests in `test/add_suggestion_navigation_test.dart`), validators, error mapper, AppUser serialization, create-once logic, widget tests for Welcome, Sign In, Sign Up, Settings, Create Trip, Join Trip, My Trips, Trip Dashboard, Members tab, Suggestions tab, SuggestionCard, AddEditSuggestionScreen, money formatting, vote logic, itinerary domain models, itinerary repository derived providers, pending suggestions modal sheet, day picker sheet, itinerary day sections, drag-to-reorder, ItineraryTab UI states, 20 dedicated UTC trip days calendar arithmetic unit tests (`test/trip_days_test.dart`), and full Phase 6 settlement, leave eligibility, and responsive layout test suites (`test/settlements_widget_test.dart`, `test/settlements_repository_test.dart`, `test/leave_router_test.dart`, `test/settlements_overflow_test.dart`). Proof of test sensitivity is backed by 23 sabotage mutation proofs (SAB1 through SAB23) documented under `docs/evidence/p6s3b`, `docs/evidence/p6s3c`, and `docs/evidence/p6s3d`.
2. **Rules tests** (Firebase Emulator): 172 passing unit tests in `rules_test/firestore_rules.test.js` against unmodified `firestore.rules` (SHA-256 hash `FC5F7525EBD47AD927DAC5A55132810A9589FD74CDC75E2AD87EFD4233440443`). Test execution evidence recorded in `docs/evidence/phase6/03_rules_suite.txt` and `docs/evidence/fix2d/RUN_2026-10-15T08-20-19-461Z.txt`.
   - Test execution command: `firebase emulators:exec --only firestore "npm --prefix rules_test test"`.
   - **Mutation Testing Suite:** 75 mutants defined in `rules_test/mutation/mutants.json`. 75 mutants: 65 KILLED (55 individual mutants plus 10 combined mutants `c1`-`c10` that prove the allowlisted ones) and 10 SURVIVED_ALLOWLISTED (ids: `m1`, `m4a`, `m4b`, `m4c`, `m49`, `m50`, `m51`, `m54`, `m58`, `m59`, documented in `rules_test/mutation/equivalent.json`). Complete mutation harness execution is recorded in `docs/evidence/fix2d/RUN_2026-10-15T08-20-19-461Z.txt`.

### 10.1 Security Rules Mutation Testing Results Table

| Mutant | What was removed | Status | Exact Failed Tests / Killers | Relevant? |
|---|---|---|---|---|
| m1 | member/signed-in checks on vote writes | SURVIVED_ALLOWLISTED | Allowlisted equivalent (proved by combined mutant) | Allowlisted (redundant by design) |
| m2 | value in {1,-1} | KILLED | Denied vote transactions: unmatched counters, wrong deltas, invalid vote values, extra keys ; Proof 2: Vote value 2 and 0 denied on create with unchanged counters | Yes |
| m3 | value != previous value | KILLED | Denied vote transactions: unmatched counters, wrong deltas, invalid vote values, extra keys ; Proof 3: Re-vote with same value denied | Yes |
| m4a | archived check on vote create/update | SURVIVED_ALLOWLISTED | Allowlisted equivalent (proved by combined mutant) | Allowlisted (redundant by design) |
| m4b | archived check on vote delete | SURVIVED_ALLOWLISTED | Allowlisted equivalent (proved by combined mutant) | Allowlisted (redundant by design) |
| m4c | archived check on suggestion counter update | SURVIVED_ALLOWLISTED | Allowlisted equivalent (proved by combined mutant) | Allowlisted (redundant by design) |
| m5 | vote read owner check (uid == auth uid) | KILLED | Votes read permissions: owner can read own vote, other member cannot read owner vote ; Proof 5: Signed-out, non-member and other-member reads of vote document denied | Yes |
| m5b | vote read member check | KILLED | Proof 5: Signed-out, non-member and other-member reads of vote document denied | Yes |
| m6 | content-update hasOnly key restriction | KILLED | Content edit: author and organizer succeed; non-author member denied; forbidden field edits denied ; Proof 6a: Content update changing createdAt denied ; Proof 6b: Content update changing authorId denied ; Proof 6c: Content update changing status denied ; Proof 6d: Content update changing dayIndex denied ; Proof 6e: Content update changing order denied | Yes |
| m7a | delete author-or-organizer check | KILLED | Suggestion delete: author and organizer succeed, other member denied | Yes |
| m7b | delete member check | KILLED | Proof 7: Suggestion delete denied for non-member and signed-out user | Yes |
| m8a | suggestion-side before != after and delta lines together | KILLED | Proof 8a: Plain suggestion counter update with NO vote change denied | Yes |
| m8b | vote-side mirror delta lines together | KILLED | Proof 8b: Vote write with NO matching counter change denied | Yes |
| m9 | hasAll(resource.data.memberIds) check on trip join | KILLED | Join DENIED when caller pads memberIds with duplicate existing member to drop another member ([B, B, C] or [A, A, C]) | Yes |
| m10 | users createdAt == request.time | KILLED | users create DENIED when createdAt is a client Date (not request.time) | Yes |
| m11 | organizer check on scheduling branch | KILLED | Scheduling denied for plain member, non-organizer author, non-member, signed out, archived trip | Yes |
| m12 | archived check on scheduling | KILLED | Scheduling denied for plain member, non-organizer author, non-member, signed out, archived trip | Yes |
| m13 | dayIndex upper bound | KILLED | Denied scheduling for invalid dayIndex, order, status values, coherence, and extra/mixed keys | Yes |
| m14 | status/dayIndex/order coherence | KILLED | Denied scheduling for invalid dayIndex, order, status values, coherence, and extra/mixed keys | Yes |
| m15 | hasOnly key restriction on scheduling | KILLED | Denied scheduling for invalid dayIndex, order, status values, coherence, and extra/mixed keys | Yes |
| m16 | integer type checks | KILLED | Denied scheduling for invalid dayIndex, order, status values, coherence, and extra/mixed keys | Yes |
| m17 | day bound without tolerance (+43200000) | KILLED | Day bound tolerance: diff 47 hours (spring-forward) allows 2, denies 3 | Yes |
| m18 | expense read member check | KILLED | Read: member succeeds; non-member and signed out denied | Yes |
| m20 | expense createdBy == caller check | KILLED | Create denied when createdBy is not the caller | Yes |
| m21 | expense create exact key sets (hasAll & hasOnly) | KILLED | Create denied for extra key or missing key | Yes |
| m22 | expense create amount validation | KILLED | Create denied for invalid amount (0, negative, float, string, over cap) | Yes |
| m23 | expense create description validation | KILLED | Create denied for invalid description (empty, >100 chars, non-string) | Yes |
| m24 | expense create paidBy member check | KILLED | Create denied for invalid paidBy (not a member, non-string) | Yes |
| m25 | expense create participantIds member subset check | KILLED | Create denied for invalid participantIds (empty, 16 elements, non-member, duplicates, non-list, non-strings) | Yes |
| m26 | expense create participantIds distinct check | KILLED | Create denied for invalid participantIds (empty, 16 elements, non-member, duplicates, non-list, non-strings) | Yes |
| m27 | expense create participantIds size bounds (1 to 15) | KILLED | Create denied for invalid participantIds (empty, 16 elements, non-member, duplicates, non-list, non-strings) | Yes |
| m28 | expense update creator-or-organizer check | KILLED | Update: creator and organizer succeed; other member and non-member denied | Yes |
| m29 | expense delete creator-or-organizer check | KILLED | Delete: creator and organizer succeed; other member, non-member, signed out, and archived denied | Yes |
| m30 | expense create archived check | KILLED | Create denied on archived trip | Yes |
| m31 | expense update archived check | KILLED | Update denied on archived trip | Yes |
| m32 | expense delete archived check | KILLED | Delete: creator and organizer succeed; other member, non-member, signed out, and archived denied | Yes |
| m33 | expense update affectedKeys hasOnly restriction | KILLED | Update denied when changing createdBy or createdAt | Yes |
| m34 | expense create createdAt == request.time check | KILLED | Create denied when date is not a timestamp or createdAt is a client date | Yes |
| m35 | expense create date timestamp type check | KILLED | Create denied when date is not a timestamp or createdAt is a client date | Yes |
| m36 | settlement create amount lower bound check (amount >= 1) | KILLED | Settlement create: amount 0 denied ; Settlement create: amount negative denied | Yes |
| m37 | settlement create amount upper bound check (amount <= 100000000000) | KILLED | Settlement create: amount over cap denied | Yes |
| m38 | settlement create status pending check | KILLED | Settlement create: status confirmed denied ; Settlement create: status rejected denied | Yes |
| m39 | settlement create createdAt request.time check | KILLED | Settlement create: createdAt client value denied | Yes |
| m40 | settlement create resolvedAt null check | KILLED | Settlement create: resolvedAt not null denied | Yes |
| m41 | settlement update resource.data.status == pending check | KILLED | Settlement update: already confirmed -> rejected denied | Yes |
| m42 | settlement update affectedKeys status and resolvedAt only | KILLED | Settlement update: amount change denied ; Settlement update: extra key denied | Yes |
| m43 | settlement update status in confirmed or rejected | KILLED | Settlement update: status pending or foo denied | Yes |
| m44 | settlement update resolvedAt request.time check | KILLED | Settlement update: resolvedAt != request.time denied | Yes |
| m45 | settlement update toUid or non-payer organizer check | KILLED | Settlement update: payer confirming own settlement denied ; Settlement update: third member denied | Yes |
| m46 | settlement delete payer check (auth.uid == fromUid) | KILLED | Settlement delete: receiver delete denied ; Settlement delete: organizer delete denied ; Settlement delete: non-member delete denied | Yes |
| m47 | settlement delete pending status check | KILLED | Settlement delete: payer deletes confirmed denied | Yes |
| m48 | joinCodes get signedIn check | KILLED | Signed-out user cannot read or write trips or joinCodes | Yes |
| m49 | joinCodes create format check regex | SURVIVED_ALLOWLISTED | Allowlisted equivalent (proved by combined mutant) | Allowlisted (redundant by design) |
| m50 | joinCodes create keys hasAll check | SURVIVED_ALLOWLISTED | Allowlisted equivalent (proved by combined mutant) | Allowlisted (redundant by design) |
| m51 | joinCodes create memberCount 1 check | SURVIVED_ALLOWLISTED | Allowlisted equivalent (proved by combined mutant) | Allowlisted (redundant by design) |
| m52 | joinCodes update affectedKeys hasOnly memberCount | KILLED | joinCodes update fails when modifying fields other than memberCount | Yes |
| m53 | leave rule drop memberIds.size() == memberCount check | KILLED | a) memberIds [A,B,C]->[A,A,C], memberCount 3->2, B leaves (denied) | Yes |
| m54 | leave rule drop memberIds.toSet().size() == memberCount check | SURVIVED_ALLOWLISTED | Allowlisted equivalent (proved by combined mutant) | Allowlisted (redundant by design) |
| m55 | join rule drop getAfter status == active check | KILLED | Rejoin by previously left member denied when member doc status is not active in client join batch | Yes |
| m56 | settlement update allows payer to confirm own settlement | KILLED | Settlement update: payer confirming own settlement denied | Yes |
| m57 | settlement delete allows non-payer | KILLED | Settlement delete: receiver delete denied ; Settlement delete: organizer delete denied | Yes |
| m58 | leave rule drops archived == false check | SURVIVED_ALLOWLISTED | Allowlisted equivalent (proved by combined mutant) | Allowlisted (redundant by design) |
| m59 | leave rule drops existsAfter members status doc check | SURVIVED_ALLOWLISTED | Allowlisted equivalent (proved by combined mutant) | Allowlisted (redundant by design) |
| m60 | leave rule drops getAfter status == left check | KILLED | Plain member cannot remove another member ; memberCount must decrease by exactly 1 ; Batch missing members status doc write denied | Yes |
| m61 | leave rule drops organizer self-removal protection | KILLED | Organizer self-removal denied | Yes |
| c1 | combined: drops isTripMember on both suggestions and votes writes (proves m1) | KILLED | Proof 1: Signed-out and non-member vote write denied | Yes |
| c2 | combined: drops isTripNotArchived on both suggestions and votes create/update (proves m4a) | KILLED | Proof 4: Vote create, vote delete, and suggestion counter update on archived trip denied | Yes |
| c3 | combined: drops isTripNotArchived on both suggestions and votes delete (proves m4b) | KILLED | Proof 4: Vote create, vote delete, and suggestion counter update on archived trip denied | Yes |
| c4 | combined: drops isTripNotArchived on suggestion counter update and all vote writes (proves m4c) | KILLED | Proof 4: Vote create, vote delete, and suggestion counter update on archived trip denied | Yes |
| c5 | combined: drops memberCount==1 on both trip create and joinCodes create (proves m51) | KILLED | Denied trip create when memberCount is not 1 | Yes |
| c6 | combined: drops joinCode regex on both trip create and joinCodes create (proves m49) | KILLED | Denied trip create with invalid joinCode format or duplicate join code | Yes |
| c7 | combined: drops both size() and toSet().size() checks on trip leave (proves m54) | KILLED | b) [A,B]->[A,A], count 2->1, B leaves (denied) | Yes |
| c8 | combined: drops archived==false on trip leave and isTripNotArchived on member leave (proves m58) | KILLED | Archived trip leave denied | Yes |
| c9 | combined: drops existsAfter and getAfter status==left on trip leave (proves m59) | KILLED | Batch missing members status doc write denied | Yes |
| c10 | combined: drops hasAll and hasOnly on joinCodes create (proves m50) | KILLED | joinCodes create fails when extra key is present in joinCodes document | Yes |

*Note on Redundant-by-Design Protections:* Certain mutants (e.g. `m4a`, `m4b`, `m4c` individually) trigger cascade denials due to strict structural constraints across coupled vote/suggestion rules. Evaluating combined mutants (e.g. `c1` through `c10`) proves that security protection holds across all coupled boundaries.

3. **Manual two-account tests** at each milestone (organizer plus member), ideally on two devices/emulators.
4. **Theme checks:** view every screen in light and dark mode, and confirm the chosen theme survives an app restart.

---

## 11. Build Plan

| # | Milestone | Effort | Done when |
|---|---|---|---|
| 0 | Setup | S | **DONE** — App runs, connects to Firebase, emulators work, router and shared widgets exist; light and dark themes built from palette; theme provider in place |
| 1 | Auth | S-M | **DONE** — Email and Google sign-in (7.x API), persistent session, create-once `users/{uid}` doc, auth redirect (`/welcome`, `/sign-in`, `/sign-up`, `/home`, `/settings`), theme selector in Settings (`SegmentedButton`), rules and tests implemented |
| 2 | Trips and joining | L | **DONE** — Create, list, join by code, Members tab; join rule tested; quick theme toggle on Home |
| 3 | Suggestions and voting | M-L | **DONE** — CRUD, vote transaction (all six cases), sorting, integer money representation, security rules and comprehensive test suites enforced |
| 4 | Itinerary | M | **DONE** — Day-by-day itinerary view, pending suggestions sheet sorted by score, day picker sheet, organizer drag-to-reorder within a day, item scheduling/unscheduling/moving between days, CEL security rules for organizer updates, integer checks, date range bounds, exact key restriction, and status coherence; all verified across 177 Flutter tests, 72 rules unit tests, and 17/17 security rule mutants. |
| 5 | Expenses and balances | L | **DONE** — Expense CRUD, calculator unit-tested, Balances view with suggested payments |
| 6 | Settlements | M | **IMPLEMENTED AND MERGED** — deployment of rules and two-account phone test PENDING |
| 7 | Hardening and polish | M | Rules tests complete, archive trip, all states handled, UI polish |
| 8 | Version 2 extras | varies | Notifications, comments, photos, packing list, unequal splits |

---

## 12. Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Join rule is subtle | Build and test it first, in Milestone 2, against the emulator |
| Vote transaction edge cases | Unit-test all six transitions |
| Split rounding errors | Integer money and deterministic remainder distribution |
| Rules and UI drift apart | Two-account testing every milestone |
| Counter tampering | Accepted; revisit with Cloud Functions if needed |
| Scope creep | Hold the version 2 list until Milestone 7 is done |

---

## 13. Version 2 Ideas
Push notifications for new suggestions and voting deadlines, comments on suggestions, photo attachments, shared packing checklist, unequal and percentage splits, map view, multi-currency with conversion, PDF export of itinerary and expense summary, App Check and Cloud Functions for stronger integrity.

---

## 14. Design System and Theme Switching

### 14.1 Palette: Ocean Blue + Teal
Ocean Blue is the main brand colour (navigation, primary actions). Teal is the secondary brand colour (highlights, selected states, positive interactions). Neutral surfaces stay dominant so trip information, destination imagery, expenses and itinerary content remain easy to scan. Dark mode is tuned for readability and contrast, not simply inverted.

### 14.2 Mapping to Flutter (Material 3)
Implemented in `lib/app/theme/app_colors.dart` and `lib/app/theme/app_theme.dart`.

| Palette role | Flutter target |
|---|---|
| Primary / Secondary | `ColorScheme.primary` / `ColorScheme.secondary` |
| Primary / Secondary Container (dark) | `primaryContainer` / `secondaryContainer` |
| Background | `scaffoldBackgroundColor` |
| Surface | `ColorScheme.surface` |
| Surface Variant | `surfaceContainerHighest` |
| Primary Text / Secondary Text | `onSurface` / `onSurfaceVariant` |
| Divider / Border | `outline` and `dividerColor` |
| Error | `ColorScheme.error` |
| Success, Warning | A `ThemeExtension` (Material has no slots for them) |

Rules: hex values live only in `lib/app/theme/app_colors.dart`; widgets always read colours from `Theme.of(context)`, never hard-coded values. This is what makes switching themes work everywhere.

### 14.3 Theme-change feature
- **Modes:** System (default), Light, Dark.
- **Quick toggle button:** sun/moon icon in Home app bar.
- **Settings selector:** `SegmentedButton<ThemeMode>` on Profile / Settings screen.
- **Behaviour:** applies instantly with no restart. Choice saved on device with shared_preferences.

### 14.4 Usage guidance
- Ocean Blue for navigation and main actions; Teal for selected states, vote highlights and confirmed settlements.
- Balances: owed = Success, owes = Error, always with a +/- sign or label so colour is never the only signal.
- Pending settlements use Warning. Amber on white has low text contrast, so use it for icons and badges with a text label, not as a text colour.
- Check the contrast of every text and background pair in both modes before finalizing screens.

### 14.5 Derived colours (palette gaps filled)
The supplied palette had no text/icon colours for use on top of brand colours and no light-mode containers. These were derived to match the palette and aim for WCAG AA contrast (4.5:1 for body text). Verify each pair with a contrast checker during Milestone 0.

| Role | Light | Dark | Used for |
|---|---|---|---|
| On Primary | #FFFFFF | #0B1220 | Text/icons on primary buttons and bars |
| On Primary Container | #0D47A1 | #CFE6FB | Text/icons on primary containers |
| On Secondary | #FFFFFF | #0B1220 | Text/icons on teal fills |
| On Secondary Container | #00695C | #CDEFEA | Text/icons on teal containers |
| On Error | #FFFFFF | #0B1220 | Text on error fills |
| On Success | #FFFFFF | #0B1220 | Text on success fills |

---

## 15. Build Progress (as of October 16, 2026)

### 15.1 Environment and project identity
- **IDE and device:** Android Studio; physical Android phone testing (CPH2603, Android 16)
- **Project:** `wayfound` at `D:\VsCode\wayfound`
- **Organization / app ID:** `com.ayush` / `com.ayush.wayfound` (Kotlin, Android only)
- **Source control:** GitHub repository `wayfound` under account Aayush049

### 15.2 Firebase
- Firebase project **Wayfound** (`wayfound-51b4d`) created
- **Authentication:** Email/Password and Google providers enabled
- **Firestore:** `(default)` database created in production mode
- **Google Sign-In SHA-1 status:** Debug SHA-1 (`56:88:48:82:1d:eb:27:9d:61:86:f0:08:c4:77:84:a2:75:10:40:95`) registered in Firebase Console; `android/app/google-services.json` updated with Android client (type 1) and Web client (type 3). Release SHA-1 still needed before a release build.
- **Firestore Security Rules status:** Local `firestore.rules` (SHA-256 hash `FC5F7525EBD47AD927DAC5A55132810A9589FD74CDC75E2AD87EFD4233440443`) includes complete rules for `users/{uid}`, `trips/{tripId}`, `members/{uid}`, `suggestions/{suggestionId}`, `votes/{uid}`, `expenses/{expenseId}`, `settlements/{settlementId}`, and `joinCodes/{code}`. Verified via 172 passing Jest unit tests against the Firestore emulator and 75-mutant mutation testing suite: 65 KILLED (55 individual mutants plus 10 combined mutants `c1`-`c10` that prove the allowlisted ones) and 10 SURVIVED_ALLOWLISTED (ids: `m1`, `m4a`, `m4b`, `m4c`, `m49`, `m50`, `m51`, `m54`, `m58`, `m59`). Deployment to production project `wayfound-51b4d` is PENDING manual execution: `firebase use wayfound-51b4d; firebase deploy --only firestore:rules`.

### 15.3 Milestone 1 Status
- Email/password sign-up, sign-in, sign-out implemented cleanly.
- Google Sign-In implemented using `google_sign_in` 7.x API (`authenticate()`, `idToken`).
- Create-once `users/{uid}` document logic implemented and tested.
- Auth-driven `go_router` redirects configured for `/welcome`, `/sign-in`, `/sign-up`, `/home`, `/settings`.
- Settings screen updated with profile display, display name editing, non-deprecated `SegmentedButton` theme selector, and sign-out confirmation dialog.
- Physical phone testing of Phase 1 identified and resolved two issues:
  1. Router refresh race on sign-in: fixed by binding `routerProvider` refreshNotifier to `authUserProvider` via `ref.listen`.
  2. Display name edit not refreshing UI: fixed by introducing `appUserProvider` (streaming live `users/{uid}` Firestore doc as single source of truth for display data), adding dialog saving state, error messages, and rollback on failure.
- Analyzer reports ZERO issues (`flutter analyze`).
- Unit, widget, and rules test suites written and verified. All widget tests pass after consolidating provider overrides.

---

### 15.5 Milestone 2 Status (Phase 2: Trips and Joining Completed)
- **Create Trip:** Form with name, destination, date range picker, required currency dropdown (`kSupportedCurrencies`), atomic Firestore batch create across `trips`, `trips/members`, and `joinCodes`, 5-attempt collision retry, and post-creation invite code dialog.
- **Join Trip:** 6-character code input with normalization, lookup preview card, member count and 15-member cap enforcement, already-member detection, and atomic batch join.
- **My Trips List & Sorting:** Client-side sorting without compound indexes: upcoming/ongoing trips (`endDate >= today`) sorted by `startDate` ascending; past trips sorted by `startDate` descending.
- **Trip Dashboard Shell:** AppBar displaying trip name & destination, back button to `/home`, TabBar with 4 tabs (`suggestions`, `itinerary`, `expenses`, `members`), and placeholder screens for future phases (`TEMP(phase-3/4/5)`).
- **Members Tab:** Prominent invite code box with clipboard copy button, live active members list with organizer badge and join date formatting.
- **Routing:** Deep linking configured in `GoRouter` with `/trip/create` and `/trip/join` registered before `/trip/:id` to prevent route param collision, and subroutes for tab navigation (`/trip/:id/members`, etc.).
- **Security Rules:** Strict atomic batched write rules for `trips/{tripId}`, `trips/{tripId}/members/{uid}`, and `joinCodes/{code}` enforcing required keys, server timestamps, 15-member limit, and member-only read access.
- **Verification:** All 46 Firestore Security Rules Jest unit tests passed, all 122 Flutter unit and widget tests passed (including Home expandable FAB menu and dual empty-state action widget tests), and `flutter analyze` reported 0 static issues.

---

### 15.7 Milestone 3 Status (Phase 3: Suggestions and Voting Completed)
- **Suggestion Models & Validation:** `Suggestion` domain model, `Vote` domain model, `SuggestionCategory` definitions with material icons and labels, strict field validators (`SuggestionValidators`), and exact key set payload builders (`SuggestionPayloadBuilders`).
- **Integer Money Utility:** Pure Dart helper (`lib/core/money.dart`) for parsing and formatting monetary amounts as minor unit integers (e.g. 12550 minor units = ₹125.50 / $125.50; 500 minor units = ¥500) supporting zero-decimal currencies (JPY) and 2-decimal currencies (INR, USD, EUR).
- **Atomic Vote Logic:** Pure function `computeVoteTransition` covering all 6 vote states (No Vote + Up, No Vote + Down, Up + Down, Down + Up, Up + Up again (delete), Down + Down again (delete)), preventing negative counts.
- **Firestore Repository & Transactions:** `SuggestionRepository` performing atomic `runTransaction` for vote casting (updating vote document and suggestion counters simultaneously), `watchSuggestions` stream, `watchMyVote` stream, `createSuggestion`, `updateSuggestion`, and `deleteSuggestion`.
- **Client-Side Sorting:** Suggestions list reactively sorted by `score` (`upCount - downCount`) descending, with ties broken by oldest `createdAt` timestamp first.
- **Presentation Components:**
  - `VoteButtons`: Upvote/downvote buttons meeting 48dp minimum touch targets, semantics, tooltips, and active highlight states.
  - `SuggestionCard`: Category chip, formatted cost, author display name, score badge, vote controls, and overflow edit/delete menu for author/organizer.
  - `SuggestionsTab`: Reactive stream view with loading, error retry, empty state ("No suggestions yet"), and floating action button.
  - `AddEditSuggestionScreen`: Form with category dropdown, title, optional note, optional cost input, prefilled initial data on edit, and back navigation to suggestions tab.
- **GoRouter Integration:** Registered subroutes `/trip/:id/suggestions/add` and `/trip/:id/suggestions/:sid/edit` under the `/trip/:id` route branch, cleanly navigating to add/edit forms and back to the suggestions tab.
- **Firestore Security Rules:** CEL security rules for `suggestions/{sid}` and `votes/{uid}` enforcing trip membership, caller ownership for updates, strict document structure, and atomic counter coupling where suggestion `upCount`/`downCount` updates must exactly match the vote document transition delta.
- **Comprehensive Verification:**
  - **Firestore Security Rules Tests:** 67 passed (including 13 dedicated Phase 3 proof tests verifying signed-out denials, valid create, payload tampering, author edits, vote transitions, archived trip locks, private vote reads, non-author delete denials, plain counter manipulation block, and counter-mismatch protection). Verified with all 16 mutants detected (16/16).
  - **Flutter Tests:** 152 passed (covering unit tests for money parsing/formatting, vote logic, category resolution, payload builders, fake Firestore repository operations, full widget tests for cards, forms, and tabs, plus 7 real-router navigation widget tests).
  - **Physical Device Navigation Fix:** Resolved Add Suggestion navigation bug on physical Android phone (CPH2603). Proven cause: parent route `/trip/:id` in `lib/app/router.dart` contained `redirect` logic checking `state.matchedLocation == '/trip/$id'`, which evaluated to true on subroute matching because GoRouter's matched location prefix during parent processing is `/trip/:id`. This continuously redirected subroutes (`/trip/:id/suggestions/add`) to `/trip/:id/members`. Fixed by matching exact `state.uri.path` and opening forms with `context.push`.
  - **Static Analysis:** `flutter analyze` reported 0 static issues across the entire project.
  - **Code Formatting:** `dart format --set-exit-if-changed .` reported 0 changed files.

---

### 15.8 Milestone 4 Status (Phase 4: Itinerary Completed)
- **Zero Schema Additions:** Itinerary items are represented solely by `status = 'scheduled'`, `dayIndex` (0-indexed integer), and `order` (0-indexed integer) on existing `suggestions/{id}` documents. Pending items retain `status = 'pending'`, `dayIndex = null`, and `order = null`.
- **Domain & Repository Architecture:** `ItineraryItemUpdate` domain class for client reorder item updates; single source of truth stream `suggestionsStreamProvider` driving derived reactive providers (`scheduledSuggestionsProvider`, `groupedItineraryProvider`, `pendingSuggestionsProvider`) without extra network calls or redundant Firestore listeners.
- **Presentation Components:**
  - `ItineraryItemTile`: Rendered with category avatar, title, optional note, formatted cost, and organizer popover menu (Move to Day, Unschedule). Non-organizer view omits action menu.
  - `DayPickerSheet`: Modal bottom sheet allowing organizers to reassign an itinerary item to any valid day in the trip (`Day 1 · Mon 12 Oct`, `Day 2 · Tue 13 Oct`, etc.).
  - `PendingSuggestionsSheet`: Modal bottom sheet listing unscheduled suggestions sorted by vote score descending, enabling organizers to quickly select and schedule top-voted ideas into specific days.
  - `ItineraryDaySection`: Per-day section rendering header with calendar date, activity count, optional "+ Add Suggestion" button for organizers, and interactive `ReorderableListView.builder` supporting drag-to-reorder within that day.
  - `ItineraryTab`: Main itinerary view organizing all trip days in sequence, showing empty state ("No itinerary items scheduled yet") when no items are scheduled, handling stream loading/error states, and reacting to realtime Firestore updates across devices.
- **Firestore Security Rules (CEL):** Added strict organizer-only scheduling rule for `suggestions/{id}` updates, validating:
  - Exact field diff restriction: `diff(resource.data).affectedKeys().hasOnly(['status', 'dayIndex', 'order'])`.
  - Date bounds: `dayIndex >= 0` and `dayIndex <= (endDate.toMillis() - startDate.toMillis()) / 86400000`.
  - Integer type assertions: `dayIndex is int` and `order is int`.
  - Status/dayIndex/order coherence: `status == 'pending'` requires `dayIndex` and `order` to be `null`; `status == 'scheduled'` requires `dayIndex` and `order` to be non-null integers.
- **Comprehensive Verification:**
  - **Firestore Security Rules Tests:** 72 passed (including 5 dedicated Phase 4 proof tests verifying non-organizer scheduling block, invalid day index block, key restriction enforcement, integer validation, and status/dayIndex/order coherence).
  - **Mutation Testing Suite:** all 17 mutants detected (17/17) across security rule mutants (`m0` baseline to `m16`), including Phase 4 mutants `m11` through `m16`.
  - **Flutter Tests:** 177 passed (including 25 Phase 4 unit and widget tests covering itinerary domain models, derived providers, day picker sheet, pending suggestions sheet, day sections, drag-to-reorder, and full `ItineraryTab` states).
  - **Static Analysis & Formatting:** `flutter analyze` reported 0 issues; `dart format .` reported 0 changed files.

---

### 15.9 Milestone 5 Status (Phase 5: Expenses and Balances Completed)
- **Expense Domain & Pure Integer Architecture:** Implemented `Expense` model, `ExpensePayloadBuilders` (7-key create payload, 5-key update payload), `ExpenseValidators`, pure integer equal split calculation (`splitEqually`) with deterministic UID-sorted remainder distribution, `computeBalances` (net balances per member summing strictly to 0), and `suggestSettlements` (greedy minimal payment suggestions pairing largest debtor and largest creditor, yielding at most N-1 payments).
- **Data Layer & Riverpod 3.x Reactive Streams:** `ExpenseRepository` for Firestore operations (`watchExpenses`, `createExpense`, `updateExpense`, `deleteExpense`, client-side date DESC sort) and derived Riverpod providers (`expensesStreamProvider`, `derivedMemberBalancesProvider`, `derivedSuggestedPaymentsProvider`, `derivedTotalTripSpentProvider`).
- **Presentation Components:**
  - `ExpenseCard`: Localized currency formatting in minor units, description, payer name, split count, date, tap action for split modal, overflow popover menu for creator/organizer with confirm-delete dialog.
  - `ExpenseSplitSheet`: Modal bottom sheet displaying individual calculated participant shares.
  - `BalancesView`: Summary card with total trip spent, caller's net position card ("You owe" / "You are owed" / "Settled"), list of member balances with explicit text status ("is owed" / "owes" / "settled"), suggested payments list, and "All Settled!" empty state.
  - `ExpensesTab`: Main tab view with `SegmentedButton` switching between Expenses and Balances views, FloatingActionButton for Add Expense, and archived trip read-only state handling.
  - `AddEditExpenseScreen`: Form with description input, decimal amount input, paidBy dropdown, participant checkboxes with Select All toggle, date picker, live share preview card, prefilled initial data on edit, and router integration (`/trip/:id/expenses/add`, `/trip/:id/expenses/:eid/edit`).
- **Firestore Security Rules (CEL):** Security rules for `trips/{tripId}/expenses/{expenseId}` enforcing membership, non-archived status, creator identity (`createdBy == request.auth.uid`), organizer/creator update & delete authority, exact key sets (`hasOnly` and `hasAll`), strict document types, range checks, and distinct participant UIDs (`toSet().size() == size()`). Document access count margin kept at max 5 calls (well below 20-call limit).
- **Comprehensive Verification:**
  - **Firestore Security Rules Tests:** 93 passed (including 16 dedicated Phase 5 tests covering valid create, signed-out/non-member denials, createdBy spoofing, key restrictions, amount bounds, description validation, paidBy membership, participantIds bounds/duplicates/membership, timestamp types, archived trip locks, creator/organizer update/delete permissions, and read permissions).
  - **Mutation Testing Suite:** all 36 mutants detected (36/36) across security rule mutants (`m0` baseline through `m35`), including all 18 Phase 5 mutants (`m18` through `m35`). Run via node `rules_test/mutation/run.js`.
  - **Flutter Tests:** 227 passed (all 227 tests passed across unit, repository, provider, widget, router, currency formatting, dark mode, and archived read-only tests).
  - **Static Analysis & Formatting:** `flutter analyze` reported 0 issues; `dart format .` reported 0 changed files.

---

---

### 15.10 Phase 5 UI Polish
SuggestionCard header: Category and Day chips wrap in Row 1 with the menu pinned top-right; Score badge on Row 2. Covered by layout tests at 320/360 dp with 1.3 text scale.

---

### 15.11 Milestone 6 Status (Phase 6: Settlements and Leaving Trips Implemented)
- **Phase 6 Scope & Architecture:**
  - **Two-Step Settlements:** Payer creates a pending settlement (`fromUid == auth.uid`, amount in minor units, status `pending`). The receiver, or trip organizer when not the payer, can confirm (`confirmed`) or reject (`rejected`). The payer may delete their own pending settlement.
  - **Computed Balances:** Balances are purely computed in memory by combining expenses and confirmed settlements; balances are never stored in Firestore. Only `confirmed` settlements adjust net balances; `pending` and `rejected` settlements do not alter balances.
  - **Zero-Balance Leave Enforcement:** Members can leave a trip only when their net balance is exactly zero and they have no pending settlements. This check is strictly enforced client-side via `checkLeaveEligibility` in `lib/features/settlements/domain/leave_eligibility.dart`.
  - **Organizer Controls:** The organizer cannot leave the trip and cannot transfer organizer status in v1. The organizer can remove any active member at any time.
  - **Atomic Leave/Remove Batch:** Leaving and member removal execute as a single atomic Firestore batch updating `memberIds` (removing the UID), decrementing `memberCount` by 1, and setting `trips/{tripId}/members/{uid}.status = 'left'`.
  - **No Rejoin in v1:** Rejoining after leaving is denied by Firestore security rules. Attempting to join with a join code displays a clean refusal message.
  - **Historical Integrity:** Members who left remain visible in balances marked "(left)" to preserve auditability. Expenses involving a left member cannot be edited.
- **Security Rules Verification:**
  - Rules file SHA-256 hash: `FC5F7525EBD47AD927DAC5A55132810A9589FD74CDC75E2AD87EFD4233440443`.
  - Firestore emulator suite: 172 tests passed (`docs/evidence/phase6/03_rules_suite.txt`, `docs/evidence/fix2d/RUN_2026-10-15T08-20-19-461Z.txt`).
  - Mutation harness: 75 mutants evaluated: 65 KILLED (55 individual mutants plus 10 combined mutants `c1`-`c10` that prove the allowlisted ones) and 10 SURVIVED_ALLOWLISTED (ids: `m1`, `m4a`, `m4b`, `m4c`, `m49`, `m50`, `m51`, `m54`, `m58`, `m59`). Full execution record in `docs/evidence/fix2d/RUN_2026-10-15T08-20-19-461Z.txt`.
- **Flutter Test Suite & Quality Gates:**
  - Total tests passing: 323 passed (recorded in `docs/evidence/p6s3d/G_counts.txt`, `docs/evidence/p6s3d/G_test.txt`).
  - Static analysis: `flutter analyze` clean with 0 issues (`docs/evidence/p6s3d/G_analyze.txt`).
  - Code formatting: `dart format` clean with 0 changed files (`docs/evidence/p6s3d/G_format.txt`).
  - Sabotage sensitivity proofs: 23 individual sabotage proofs (SAB1 through SAB23) verified against deliberate negative code mutations, with evidence recorded in `docs/evidence/p6s3b`, `docs/evidence/p6s3c`, and `docs/evidence/p6s3d`.
- **Known Limitations & Deferred Items:**
  - No archive-trip UI in v1.
  - No rejoin in v1.
  - No organizer transfer in v1.
  - Leave-eligibility check is client-side (security rules enforce membership shape and status doc transition, not monetary balance).
  - A left user cannot read their own member document after leaving.
  - `lib/features/expenses/presentation/balances_view.dart` layout changed in Session P6-S3c to use Column-based scroll structures and re-laid-out suggested payment tiles.
  - Mark-as-paid sheet keyboard behavior on small screens is unverified on physical hardware (it sets `isScrollControlled: true` as documented in `docs/evidence/p6s4/S1_sheet.txt`).
  - Production release SHA-1 registration and Firebase App Check are pending.
  - "Add to itinerary" shortcut on Suggestions tab is pending.
- **Manual Actions Required from User (PENDING):**
  - Deploy security rules: `firebase use wayfound-51b4d; firebase deploy --only firestore:rules` (marked PENDING).
  - Two-account phone test: Run phone verification covering payment creation, confirm/reject, leave, remove, rejoin refusal, and keyboard sheet layout (marked PENDING).

---

### 15.6 How to Run & Test Emulators

#### Firebase Rules Test Command
```bash
firebase emulators:exec --only firestore "npm --prefix rules_test test"
```

#### Running Flutter App with Emulators
- **Android Emulator:**
  ```bash
  flutter run --dart-define=USE_EMULATORS=true
  ```
- **Physical Android Phone:**
  First reverse emulator ports via ADB:
  ```bash
  adb reverse tcp:9099 tcp:9099
  adb reverse tcp:8092 tcp:8092
  ```
  Then launch pointing to localhost:
  ```bash
  flutter run --dart-define=USE_EMULATORS=true --dart-define=EMULATOR_HOST=127.0.0.1
  ```

---

## 16. Development Workflow

- **Branching:** one git branch per development phase (`phase-0/setup`, `phase-1/auth`, `phase-2/trips`, ...). `fix/` branches are explicitly allowed for cross-phase patches like test fixes. No direct feature development on `main`.
- **Commits:** logical, concise commit messages prefixed by type (`feat`, `fix`, `test`, `refactor`, `docs`, `chore`).
- **Phase Completion:** a phase branch is merged into `main` only when all phase requirements are complete, `flutter analyze` reports zero issues, and all tests pass.
- **Remote Synchronization:** after merging into `main`, push both `main` and the phase branch to origin, confirming local `main` equals `origin/main`.
- **Safety Rules & Safeguards:** Never execute destructive git or filesystem commands (`git clean`, `git reset --hard`, `git checkout .`, `git restore .`, `git stash drop`, `git branch -D`, `git push --force`, `rm -rf`, `del /s`) or modify `firestore.rules` during security rules testing sessions without explicit user approval and prior dry runs.
- **Documentation:** update `trip_planner_project_report.md` at the completion of each phase.
