# Wayfound: Project Planning Report

*Wayfound is a collaborative trip planner for groups.*

**Stack:** Flutter (Dart) + Firebase  |  **Level:** Intermediate  |  **Prepared:** October 4, 2026
**Status:** Milestone 0 complete (Phase 0 setup finished)

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
| Logo | To be supplied later |
| Theme switching | System / Light / Dark; quick toggle button plus settings selector; saved on device |
| Group size | Up to 15 members per trip |
| Sign-in | Email/password and Google via Firebase Authentication |
| Itinerary placement | Organizer only |
| Suggestion edit/delete | Author and organizer |
| Expense split | Equal split only (v1) |
| Join method | Short typed code only (no share links) |
| Currency | One per trip, set at creation |
| Join enforcement | Security Rules only; no Cloud Functions |
| Leaving a trip | Only when balance is zero; organizer can always remove |
| Settling | Payer marks paid, receiver confirms; only confirmed settlements count |
| Trip deletion | Archive instead of delete |
| State management | Riverpod |
| Navigation | go_router |
| Folder structure | Feature-first |

---

## 3. Features and Scope

### 3.1 Must-have (version 1)
- **Accounts:** sign up, log in, log out; display name and optional photo
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
- **A. Getting started:** Welcome, sign in (email/Google), Home. Empty Home offers "Create trip" and "Join with code".
- **B. Create:** form, trip created with user as organizer, invite screen shows the code.
- **C. Join:** enter code, preview (name, destination, member count), confirm. Full trips show "trip is full".
- **D. Plan:** Trip Dashboard with tabs Suggestions, Itinerary, Expenses, Members. Add suggestions, vote; organizer schedules.
- **E. Money:** add expense; Balances view lists net positions and suggested payments; mark paid / confirm received.

### 5.2 Screen inventory

| # | Screen | Purpose |
|---|---|---|
| 1 | Welcome / Sign in | Login and sign-up |
| 2 | Home (My Trips) | Trip list, create/join entry, theme toggle button |
| 3 | Create Trip | Name, destination, dates, currency |
| 4 | Join Trip | Code entry, preview, confirm |
| 5 | Trip Dashboard | Container with four tabs |
| 6 | Suggestions tab | List with vote controls |
| 7 | Add/Edit Suggestion | Title, note, cost, category |
| 8 | Itinerary tab | Day-by-day confirmed plan |
| 9 | Expenses tab | Expense list plus Balances view |
| 10 | Add Expense | Amount, payer, participants, description |
| 11 | Members tab | Members, invite code, remove (organizer) |
| 12 | Profile / Settings | Name, photo, theme selector (System/Light/Dark), sign out |

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
| `users/{uid}` | displayName, photoUrl, email, createdAt |
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

### 6.4 Queries and indexes

| Screen | Query | Index |
|---|---|---|
| My Trips | `memberIds array-contains uid`, order by startDate | Composite |
| Suggestions | order by score or createdAt | Single field |
| Itinerary | `status == scheduled`, order by dayIndex, order | Composite |
| Expenses | order by date | Single field |
| Join | get `joinCodes/{code}` | None |

Firestore reports the exact composite index needed (with a creation link) the first time a query runs.

---

## 7. Security Rules Plan

### 7.1 Helper checks
**isSignedIn**, **isMember** (uid in trip `memberIds`), **isOrganizer** (uid equals `organizerId`). Nearly every rule combines these with an author/creator check.

### 7.2 Join rule (the hardest one)
Flow: the user reads `joinCodes/{code}` (single get allowed for signed-in users; **listing blocked**), then sends one batched write.

A non-member may update a trip only if:
- only `memberIds` and `memberCount` change
- exactly one uid is added, and it is the caller's own
- `memberCount` is currently below 15
- `memberCount` increases by exactly 1

The new `members/{uid}` document is allowed only if the document ID equals the caller's uid, role is `member`, and (via the post-write state of the batch) the trip's `memberIds` contains the caller.

Concurrent joins at 14 members: writes to one document serialize, so the second is checked against the updated count and rejected.

### 7.3 Other rules
- **Votes:** document ID must equal caller uid; value must be +1 or -1.
- **Counters:** any member may change `upCount`/`downCount` by at most 1 and nothing else in that update.
- **Suggestions:** authors change only title, note, cost, category; only the organizer changes `status`, `dayIndex`, `order`.
- **Expenses:** creator or organizer may edit/delete; `createdBy` must equal caller on create.
- **Settlements:** create only as payer (`fromUid` equals caller, status `pending`); only the receiver (or organizer) may set `confirmed` or `rejected`; amount and parties are immutable after creation.
- **Archiving:** organizer sets `archived = true`; archived trips are read-only for everyone.

### 7.4 Known limitations
- Stored vote counters can be tampered with by a determined member, since rules cannot fully verify the arithmetic without server code. Accepted for a friend-group app.
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

### 9.2 Folder layout
```
lib/
  main.dart
  app/            router.dart (go_router + auth redirect)
  app/theme/      app_colors.dart, app_theme.dart, theme_provider.dart
  core/           firebase_providers.dart, money.dart, widgets/
  features/
    auth/         data/ presentation/
    trips/        data/ domain/ presentation/
    suggestions/  data/ domain/ presentation/
    itinerary/    presentation/   (filtered view of suggestions)
    expenses/     data/ domain/ presentation/
                  domain/balance_calculator.dart  (pure Dart)
```

### 9.3 Models
Plain Dart classes with `fromFirestore` / `toFirestore`: Trip, Member, Suggestion, Vote, Expense, Settlement. Code generation is optional.

### 9.4 Navigation
go_router with routes such as `/`, `/trip/:id`, `/trip/:id/expenses/add`. Auth redirect sends signed-out users to sign-in. A shell route hosts the four dashboard tabs.

### 9.5 Packages

| Purpose | Package |
|---|---|
| Firebase setup | firebase_core |
| Login | firebase_auth, google_sign_in |
| Database | cloud_firestore |
| State | flutter_riverpod |
| Navigation | go_router |
| Formatting | intl |
| Theme persistence | shared_preferences |
| v2 | firebase_messaging, firebase_app_check, firebase_storage |

### 9.6 Tooling
FlutterFire CLI for per-platform config. Firebase Emulator Suite (Firestore, Auth, Rules) for safe local testing.

---

## 10. Testing Plan

1. **Unit & Widget tests** (Flutter): theme mode persistence, theme toggle logic, ColorScheme palette checks, shared widgets rendering, router navigation, and app shell build tests (`flutter test`).
2. **Rules tests** (Firebase Emulator): baseline deny-all test harness in `rules_test/` using `@firebase/rules-unit-testing`. Run with `firebase emulators:exec --only firestore "npm --prefix rules_test test"`.
3. **Manual two-account tests** at each milestone (organizer plus member), ideally on two devices/emulators.
4. **Theme checks:** view every screen in light and dark mode, and confirm the chosen theme survives an app restart.

### Rule test cases to include
- Non-member cannot read trip, suggestions or expenses
- Join succeeds with count 14; fails at 15
- Join fails if two uids are added, or someone else's uid is added, or other fields change
- Member cannot schedule a suggestion; organizer can
- Member cannot write another user's vote
- Payer cannot confirm own settlement; receiver can
- Archived trip rejects writes

---

## 11. Build Plan

| # | Milestone | Effort | Done when |
|---|---|---|---|
| 0 | Setup | S | **DONE** — App runs, connects to Firebase, emulators work, router and shared widgets exist; light and dark themes built from palette; theme provider in place |
| 1 | Auth | S-M | Email and Google sign-in, persistent session, `users` doc, redirect works; theme selector in Settings works |
| 2 | Trips and joining | L | Create, list, join by code, Members tab; join rule tested; quick theme toggle on Home |
| 3 | Suggestions and voting | M-L | CRUD, vote transaction (all six cases), sorting, rules enforced |
| 4 | Itinerary | M | Organizer schedules; day view updates live on second device |
| 5 | Expenses and balances | L | Expense CRUD, calculator unit-tested, Balances view with suggested payments |
| 6 | Settlements | M | Mark paid, confirm/reject, balances use confirmed only, leave rule works |
| 7 | Hardening and polish | M | Rules tests complete, archive trip, all states handled, UI polish |
| 8 | Version 2 extras | varies | Notifications, comments, photos, packing list, unequal splits |

**Habit per milestone:** write rules, build repository and provider, build screen, test with two accounts.

**Why this order:** auth underpins every rule; membership underpins every permission (and is the riskiest piece, so it comes early); itinerary reuses suggestions; settlements need balances.

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

| Purpose | Light | Dark |
|---|---|---|
| Primary | #1565C0 | #64B5F6 |
| Primary Dark | #0D47A1 | #42A5F5 |
| Primary Light | #42A5F5 | #90CAF9 (derived) |
| Primary Container | #D6E8FA (derived) | #0D3B66 |
| Secondary | #00897B | #4DB6AC |
| Secondary Dark | #00695C | #00897B |
| Secondary Light | #4DB6AC | #80CBC4 (derived) |
| Secondary Container | #D3EFEB (derived) | #064E47 |
| Background | #F5F9FC | #0B1220 |
| Surface | #FFFFFF | #111C2E |
| Surface Variant | #E8F0F7 | #1B2A3D |
| Primary Text | #172B4D | #F1F5F9 |
| Secondary Text | #667085 | #A8B3C2 |
| Divider / Border | #D9E2EC | #2A3A4D |
| Success | #2E7D32 | #66BB6A |
| Warning | #F59E0B | #FFCA55 |
| Error | #D32F2F | #EF6C6C |

### 14.2 Mapping to Flutter (Material 3)

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
- **Quick toggle button:** a sun/moon icon in the Home app bar. It flips to the opposite of the theme currently showing (so it also works when the mode is System).
- **Settings selector:** a three-option control (System / Light / Dark) on the Profile / Settings screen.
- **Behaviour:** applies instantly with no restart. The choice is saved on the device with `shared_preferences` and loaded at startup before the first frame, so there is no flash of the wrong theme. It also works before sign-in.
- **State:** a Riverpod notifier holds the `ThemeMode`; `MaterialApp.router` receives `theme`, `darkTheme` and `themeMode`.
- **Not in version 1:** syncing the choice to the account across devices (would add a `themeMode` field on `users/{uid}` and a matching rule). Listed as a version 2 option.

### 14.4 Usage guidance
- Ocean Blue for navigation and main actions; Teal for selected states, vote highlights and confirmed settlements.
- Balances: owed = Success, owes = Error, always with a +/- sign or label so colour is never the only signal.
- Pending settlements use Warning. Amber on white has low text contrast, so use it for icons and badges with a text label, not as a text colour.
- Check the contrast of every text and background pair in both modes before finalizing screens.

### 14.5 Derived colours (palette gaps filled)
The supplied palette had no text/icon colours for use on top of brand colours and no light-mode containers. These were derived to match the palette and aim for WCAG AA contrast (4.5:1 for body text). All derived colors and the StatusColors ThemeExtension are fully implemented in `lib/app/theme/app_colors.dart` and `lib/app/theme/app_theme.dart`.

| Role | Light | Dark | Used for |
|---|---|---|---|
| On Primary | #FFFFFF | #0B1220 | Text/icons on primary buttons and bars |
| On Primary Container | #0D47A1 | #CFE6FB | Text/icons on primary containers |
| On Secondary | #FFFFFF | #0B1220 | Text/icons on teal fills |
| On Secondary Container | #00695C | #CDEFEA | Text/icons on teal containers |
| On Error | #FFFFFF | #0B1220 | Text on error fills |
| On Success | #FFFFFF | #0B1220 | Text on success fills |
| On Warning | #172B4D | #0B1220 | Text on warning fills |
| Disabled | #98A2B3 | #5B6B80 | Disabled controls and text |
| Focus ring | #1565C0 | #64B5F6 | Same as Primary |

Notes:
- White on light Secondary (#00897B) is slightly under 4.5:1. For filled teal buttons that carry text, use Secondary Dark (#00695C) as the background; keep Secondary for icons, highlights and selected states.
- Warning fills take dark text in both modes, since white on amber is hard to read.
- Still not specified: typography, corner radius and elevation.

---

## 15. Build Progress (as of October 5, 2026)

### 15.1 Environment and project identity
- **IDE and device:** Android Studio; testing on a physical Android phone (CPH2603, Android 16)
- **Project:** `wayfound` at `D:\VsCode\wayfound`
- **Organization / app ID:** `com.ayush` / `com.ayush.wayfound` (Kotlin, Android only)
- **Known warning:** `flutter doctor` reports an unknown Android license status; deliberately ignored for now since builds succeed
- **Source control:** GitHub repository `wayfound` under the account Aayush049, with the project pushed

### 15.2 Firebase
- Firebase project **Wayfound** created (Analytics off)
- **Authentication:** Email/Password and Google providers enabled
- **Firestore:** `(default)` database created in **production mode** (locked until our rules are deployed)
- **FlutterFire configured** for Android: `lib/firebase_options.dart` and `android/app/google-services.json` generated
- **Initialization verified:** `main.dart` initializes Firebase and the app runs on the phone with no errors

### 15.3 Packages added
`firebase_core`, `firebase_auth`, `cloud_firestore`, `google_sign_in`, `flutter_riverpod`, `go_router`, `intl`, `shared_preferences`

### 15.4 Folder structure created
```
lib/
  app/theme/
  core/widgets/
  features/
    auth/          data/ presentation/
    trips/         data/ domain/ presentation/
    suggestions/   data/ domain/ presentation/
    itinerary/     presentation/
    expenses/      data/ domain/ presentation/
```
Settlements live inside the **expenses** feature.

### 15.5 Image assets prepared and registered in `pubspec.yaml`

| File | Location | Format | Purpose |
|---|---|---|---|
| `logo.png` | `assets/images/` | PNG, transparent | Welcome and sign-in screens |
| `google_logo.png` | `assets/images/` | PNG, transparent | "Continue with Google" button |
| `app_icon.png` | `assets/icons/` | PNG, 1024 x 1024, full-bleed Ocean Blue | Launcher icon |
| `app_icon_foreground.png` | `assets/icons/` | PNG, 1024 x 1024, transparent | Adaptive icon foreground |

### 15.6 Milestone 0 status

| Item | Status |
|---|---|
| Flutter project created and running on device | Done |
| Firebase project, Auth providers, Firestore | Done |
| App connected to Firebase and verified | Done |
| GitHub repository connected | Done |
| Remaining packages added | Done |
| Folder structure created | Done |
| Logo, icon and Google logo files prepared | Done |
| Register assets in `pubspec.yaml`; apply launcher icon | Done |
| Theme system (light/dark palette, theme provider, toggle) | Done |
| Router skeleton with placeholder screens | Done |
| Shared loading / error / empty widgets | Done |
| Firebase rules and emulator project files | Done |

### 15.7 How to Run & Test Emulators

#### Firebase Rules Baseline Test
The rules test harness is located in `rules_test/`. Run the deny-all baseline test against the Firestore emulator via:
```bash
firebase emulators:exec --only firestore "npm --prefix rules_test test"
```

#### Running Flutter App with Emulators
- **Android Emulator (Virtual Device):**
  ```bash
  flutter run --dart-define=USE_EMULATORS=true
  ```
  (Connects to `10.0.2.2:9099` for Auth and `10.0.2.2:8088` for Firestore).

- **Physical Android Phone:**
  First reverse the emulator ports via ADB:
  ```bash
  adb reverse tcp:9099 tcp:9099
  adb reverse tcp:8088 tcp:8088
  ```
  Then launch the app pointing to localhost (`127.0.0.1`):
  ```bash
  flutter run --dart-define=USE_EMULATORS=true --dart-define=EMULATOR_HOST=127.0.0.1
  ```

### 15.8 Follow-ups to remember
- **Milestone 1:** register the computer's SHA-1 fingerprint in Firebase so Google sign-in works on Android
- **Dark mode:** check the logo's contrast against the dark background; add a lighter `logo_dark.png` if needed
- **Rules:** Firestore baseline is deny-all; feature rules will be added alongside Milestones 1 to 3