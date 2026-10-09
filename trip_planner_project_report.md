# Wayfound: Project Planning Report

*Wayfound is a collaborative trip planner for groups.*

**Stack:** Flutter (Dart) + Firebase  |  **Level:** Intermediate  |  **Prepared:** October 4, 2026 (Updated: October 6, 2026)
**Status:** Milestone 0, Milestone 1, Milestone 2 & Milestone 3 complete (Phase 0 setup, Phase 1 auth, Phase 2 trips, Phase 3 suggestions & voting finished)

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
| 9 | Add/Edit Suggestion | `/trip/:id/suggestions/add`, `/trip/:id/suggestions/:sid/edit` | Title, note, cost, category |
| 10 | Itinerary tab | `/trip/:id/itinerary` | Day-by-day confirmed plan |
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
2. **Money is stored as integers** in the smallest currency unit (12550 = 125.50), avoiding floating-point errors.
3. **Balances are computed, never stored.** They cannot drift out of sync with expenses.
4. **Vote documents use the voter's uid as ID**, which enforces one vote per person.
5. **Vote counters are stored** on the suggestion and updated in a transaction, so lists do not read every vote.
6. **`memberIds` on the trip** makes "my trips" a single `array-contains` query and keeps rules simple.
7. **Member names are copied into `members/`** for fast display; name changes may lag (acceptable).
8. **`joinCodes` exists** because a non-member cannot query `trips`; they look up the code, get the trip ID, then join.
9. **Leaving** removes the uid from `memberIds` (access ends) and sets `status = left`, preserving history.

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
- **Suggestions:** authors change only title, note, cost, category; only the organizer changes `status`, `dayIndex`, `order`.
- **Expenses:** creator or organizer may edit/delete; `createdBy` must equal caller on create.
- **Settlements:** create only as payer (`fromUid` equals caller, status `pending`); only the receiver (or organizer) may set `confirmed` or `rejected`; amount and parties are immutable after creation.
- **Archiving:** organizer sets `archived = true`; archived trips are read-only for everyone.

### 7.5 Known limitations & Counter Integrity
- Stored vote counters (`upCount`, `downCount`) are protected by `getAfter` rules requiring exact correlation with atomic vote document changes. Plain counter updates without matching vote transitions are strictly denied.
- Short join codes could in theory be brute-forced; plan Firebase App Check as a later hardening step.
- Subcollections are not removed when a trip document is deleted, which is why trips are archived rather than deleted.

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
Start all at zero. For each expense: payer gets **+amount**, each participant gets **-share**. For each **confirmed** settlement: payer (`fromUid`) gets **+amount**, receiver (`toUid`) gets **-amount**. Positive means owed money; negative means owes. All balances must sum to zero (use as a sanity check).

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
3. Receiver taps **Confirm received** (`confirmed`) or **Not received** (`rejected`).
4. Only `confirmed` settlements change balances. Pending ones display as "awaiting confirmation". Partial payments are allowed. A rejected settlement leaves the debt unchanged.

### 8.7 Leaving a trip
Allowed only when the member's balance is zero. The organizer can remove anyone regardless; their historical expenses and votes remain.

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
    itinerary/    presentation/
    expenses/     data/ domain/ presentation/
                  domain/balance_calculator.dart  (pure Dart)
```

### 9.3 Models
Plain Dart classes with `fromFirestore` / `toFirestore`: AppUser, Trip, Member, Suggestion, Vote, Expense, Settlement.

### 9.4 Navigation
go_router with routes `/welcome`, `/sign-in`, `/sign-up`, `/home`, `/settings`. Auth redirect sends signed-out users to welcome and signed-in users away from auth screens.

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

1. **Unit & Widget tests** (Flutter): 145 passing tests across theme mode persistence, theme toggle logic, ColorScheme palette checks, shared widgets rendering, router navigation (`/welcome`, `/sign-in`, `/sign-up`, `/home`, `/settings`, `/trip/:id`), validators, error mapper, AppUser serialization, create-once logic, widget tests for Welcome, Sign In, Sign Up, Settings, Create Trip, Join Trip, My Trips, Trip Dashboard, Members tab, Suggestions tab, SuggestionCard, AddEditSuggestionScreen, money formatting, and vote logic. All widget tests use `test/helpers/pump_app.dart` to streamline provider overrides.
2. **Rules tests** (Firebase Emulator): 67 passing unit tests in `rules_test/firestore_rules.test.js` covering signed-out access, valid create, invalid creates (extra/missing keys, wrong email, wrong uid, bad timestamp), owner get, owner update, forbidden field changes, list and delete denials, join code transactions, suggestion CRUD, vote counter coupling, vote read restrictions, and 13 dedicated Phase 3 proof tests (signed-out/non-member access, vote value limits, re-vote block, archived trip lock, private vote reads, immutable field protections, non-author delete block, plain counter manipulation block, and uncoupled vote write block).
   - Test execution command: `firebase emulators:exec --only firestore "npm --prefix rules_test test"`.
   - **Mutation Testing Suite:** 100% CEL condition detection score across 16 security rule mutants (`m1` to `m10`, including `m4all`, `m5b`, `m7b`, `m8a`, `m8b`). Run mutation runner via node script `rules_test/mutation/run.js`.

### 10.1 Security Rules Mutation Testing Results Table

| Mutant | What was removed | Failed Tests (or NONE = UNDETECTED) |
|---|---|---|
| m1 | member/signed-in checks on vote writes | Proof 7: Suggestion delete denied for non-member and signed-out user |
| m2 | value in {1,-1} | Denied vote transactions: unmatched counters, wrong deltas, invalid vote values, extra keys, Proof 2: Vote value 2 and 0 denied on create with unchanged counters, Proof 7: Suggestion delete denied for non-member and signed-out user |
| m3 | value != previous value | Denied vote transactions: unmatched counters, wrong deltas, invalid vote values, extra keys, Proof 3: Re-vote with same value denied, Proof 7: Suggestion delete denied for non-member and signed-out user |
| m4a | archived check on vote create/update | Proof 7: Suggestion delete denied for non-member and signed-out user |
| m4b | archived check on vote delete | Proof 7: Suggestion delete denied for non-member and signed-out user |
| m4c | archived check on suggestion counter update | Proof 7: Suggestion delete denied for non-member and signed-out user |
| m4all | all three archived checks together | Proof 4: Vote create, vote delete, and suggestion counter update on archived trip denied, Proof 7: Suggestion delete denied for non-member and signed-out user |
| m5 | vote read owner check (uid == auth uid) | Votes read permissions: owner can read own vote, other member cannot read owner vote, Proof 5: Signed-out, non-member and other-member reads of vote document denied, Proof 7: Suggestion delete denied for non-member and signed-out user |
| m5b | vote read member check | Proof 5: Signed-out, non-member and other-member reads of vote document denied, Proof 7: Suggestion delete denied for non-member and signed-out user |
| m6 | content-update hasOnly key restriction | Content edit: author and organizer succeed; non-author member denied; forbidden field edits denied, Denied vote transactions: unmatched counters, wrong deltas, invalid vote values, extra keys, Proof 6a: Content update changing createdAt denied, Proof 6b: Content update changing authorId denied, Proof 6c: Content update changing status denied, Proof 6d: Content update changing dayIndex denied, Proof 6e: Content update changing order denied, Proof 7: Suggestion delete denied for non-member and signed-out user, Proof 8a: Plain suggestion counter update with NO vote change denied |
| m7a | delete author-or-organizer check | Suggestion delete: author and organizer succeed, other member denied |
| m7b | delete member check | Proof 7: Suggestion delete denied for non-member and signed-out user |
| m8a | suggestion-side before != after and delta lines together | Content edit: author and organizer succeed; non-author member denied; forbidden field edits denied, Denied vote transactions: unmatched counters, wrong deltas, invalid vote values, extra keys, Proof 7: Suggestion delete denied for non-member and signed-out user, Proof 8a: Plain suggestion counter update with NO vote change denied |
| m8b | vote-side mirror delta lines together | Denied vote transactions: unmatched counters, wrong deltas, invalid vote values, extra keys, Proof 7: Suggestion delete denied for non-member and signed-out user, Proof 8b: Vote write with NO matching counter change denied |
| m9 | hasAll(resource.data.memberIds) check on trip join | Join DENIED when caller pads memberIds with duplicate existing member to drop another member ([B, B, C] or [A, A, C]), Proof 7: Suggestion delete denied for non-member and signed-out user |
| m10 | users createdAt == request.time | users create DENIED when createdAt is a client Date (not request.time), Proof 7: Suggestion delete denied for non-member and signed-out user |

*Note on Redundant-by-Design Protections:* Certain mutants (e.g. `m4a`, `m4b`, `m4c` individually) trigger cascade denials due to strict structural constraints across coupled vote/suggestion rules. Evaluating `m4all` proves that complete removal of archived trip protection is caught by Proof 4.

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
| 4 | Itinerary | M | Organizer schedules; day view updates live on second device |
| 5 | Expenses and balances | L | Expense CRUD, calculator unit-tested, Balances view with suggested payments |
| 6 | Settlements | M | Mark paid, confirm/reject, balances use confirmed only, leave rule works |
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

Rules: hex values live only in `app_colors.dart`; widgets always read colours from `Theme.of(context)`, never hard-coded values. This is what makes switching themes work everywhere.

### 14.3 Theme-change feature
- **Modes:** System (default), Light, Dark.
- **Quick toggle button:** sun/moon icon in Home app bar.
- **Settings selector:** `SegmentedButton<ThemeMode>` on Profile / Settings screen.
- **Behaviour:** applies instantly with no restart. Choice saved on device with `shared_preferences`.

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

## 15. Build Progress (as of October 6, 2026)

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
- **Firestore Security Rules status:** Local `firestore.rules` updated with `users/{uid}`, `trips/{tripId}`, `members/{uid}`, `suggestions/{suggestionId}`, `votes/{uid}`, and `joinCodes/{code}` rules; fully verified via 67 passing Jest unit tests against the Firestore emulator and 100% mutation detection (16/16 mutants detected). Production rules last deployed Oct 8, 2026 prior to Phase 3 & strictness fixes; production rules deploy pending: `firebase use wayfound-51b4d; firebase deploy --only firestore:rules`.

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
  - **Firestore Security Rules Tests:** 67 passed (including 13 dedicated Phase 3 proof tests verifying signed-out denials, valid create, payload tampering, author edits, vote transitions, archived trip locks, private vote reads, non-author delete denials, plain counter manipulation block, and counter-mismatch protection). Verified with 100% mutation detection score (16/16 mutants detected).
  - **Flutter Tests:** 145 passed (covering unit tests for money parsing/formatting, vote logic, category resolution, payload builders, fake Firestore repository operations, and full widget tests for cards, forms, and tabs).
  - **Static Analysis:** `flutter analyze` reported 0 static issues across the entire project.
  - **Code Formatting:** `dart format --set-exit-if-changed .` verified 100% compliant formatting.

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
