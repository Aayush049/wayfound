# Wayfound

Collaborative trip planning and shared expense settlements for groups.

![Flutter](https://img.shields.io/badge/Flutter-3.47.7-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.13.5-0175C2?logo=dart)
![Firebase](https://img.shields.io/badge/Firebase-Core%20%7C%20Auth%20%7C%20Firestore-FFCA28?logo=firebase&logoColor=black)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)
![Status](https://img.shields.io/badge/Status-v1.0.0-success)

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [How It Works](#how-it-works)
- [Tech Stack](#tech-stack)
- [Architecture](#architecture)
- [Data Model](#data-model)
- [Money Handling](#money-handling)
- [Security Model](#security-model)
- [Getting Started](#getting-started)
- [Testing](#testing)
- [Building a Release APK](#building-a-release-apk)
- [Project Status and Roadmap](#project-status-and-roadmap)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [Security Reporting](#security-reporting)
- [Licence](#licence)
- [Author and Acknowledgements](#author-and-acknowledgements)

## Overview

Planning group travel often fractures across chat channels, note apps, and spreadsheets. Itinerary ideas get buried, voting is scattered, and tracking shared expenses turns into post-vacation math disputes.

Wayfound solves this by providing travel groups with a single collaborative hub. Group members propose activities, vote on ideas, build a schedule day by day, record split expenses, and settle balances without manual calculations.

### Target Audience

Wayfound is designed for friends, families, colleagues, and travel groups organizing multi-day journeys who need coordinated itineraries and transparent expense tracking.

### Version 1 Scope

- Group trip creation with shareable alphanumeric invite codes
- Categorized suggestion boards with live member voting (+1 / -1)
- Day-by-day itinerary planning with drag-to-reorder scheduling
- Group expense recording with equal splits across selected participants
- Dynamic net balance calculation and simplified debt settlement generation
- Two-step settlement recording (payer initiates, receiver or organizer confirms)
- Member leave and remove workflows with balance-zero guards
- Permanent trip archiving with complete read-only enforcement across all tabs

### Non-Goals

The initial release focuses purely on core group coordination. The following capabilities are explicitly outside the scope of version 1:

- Flight, hotel, or rental car booking integrations
- In-app payment processing (Wayfound calculates and tracks settlements; money moves outside the app via cash or banking rails)
- Social discovery feeds or public trip profiles
- Automated or generative AI travel planning
- Multi-currency conversions or live exchange rate fetching (each trip uses a single chosen base currency)
- Offline-first bidirectional sync (requires an active network connection to Firestore)

## Features

### Accounts and Profiles

- Sign in and sign up with email and password credentials
- Google Sign-In integration
- Profile display name management
- Theme mode preference toggle (System, Light, Dark) persisted locally

### Trips and Invites

- Create a trip with title, destination, date range, and base currency
- Supported currencies: USD, EUR, GBP, JPY
- Unique 6-character alphanumeric join code generated upon creation
- Instant preview of trip destination and date range before joining

### Member Management

- Real-time active member rosters
- Role separation between Trip Organizer and Members
- Voluntary departure: members can leave if their net balance is zero with no pending settlements
- Organizer control: organizers can remove members at any time
- Audit retention: departed members remain marked as left in historical balances

### Suggestions and Voting

- Community ideas board categorized by Activity, Dining, Lodging, and Other
- Estimated cost fields for proposed ideas
- Live member voting with instant net score calculations
- Edit and delete permissions restricted to the author and the trip organizer

### Daily Itinerary

- Chronological day sections (Day 1 through Day N) based on trip dates
- Organizer scheduling: assign voted suggestions to specific days
- Organizer reordering: reorder scheduled items within a day using drag-and-drop handles
- Unschedule or remove items while keeping original ideas intact

### Expenses and Splits

- Record expenses with title, amount, payer, date, and participant checklist
- Equal split calculation with penny-remainder distribution to prevent truncation losses
- Live share preview showing each participant's exact allocation before saving
- Expense editing disabled if any participant has departed the trip

### Balances and Debt Settlements

- On-the-fly net balance calculation combining all expenses and confirmed settlements
- Automatic bipartite settlement minimization (debtor-to-creditor payment suggestions)
- Two-step payment logging: payer creates a pending payment; receiver or organizer confirms or rejects
- Payer cancellation for unconfirmed pending payments
- Complete settlement audit history

### Archiving

- One-way trip archive triggered by the trip organizer
- Persistent visual archive banners on dashboard and trip cards
- Complete write disablement across all tabs: buttons hidden, dialogs disabled, and server-side rules locked

## How It Works

1. **Create Trip**: The organizer creates a trip, picking the destination, travel dates, and base currency. Wayfound generates a shareable join code.
2. **Invite Members**: Friends enter the 6-character code on the Join screen, preview the trip details, and join with one tap.
3. **Brainstorm Ideas**: Any member posts suggestions with descriptions and estimated costs. Members vote on ideas to establish group consensus.
4. **Organize Itinerary**: The organizer selects high-voted suggestions, schedules them onto specific travel days, and drags items into sequential daily order.
5. **Log Expenses**: When purchases occur, the payer records the amount and selects which members participated. Wayfound calculates exact shares.
6. **Settle Balances**: The Balances view computes who owes whom. Debtors tap Mark as Paid to submit a pending settlement; creditors confirm receipt.
7. **Archive Trip**: When the vacation concludes, the organizer archives the trip, turning it into a permanent read-only journal.

## Tech Stack

| Component | Package / Technology | Version | Purpose |
|---|---|---|---|
| Framework | Flutter SDK | 3.47.7 (^3.13.0) | Cross-platform UI toolkit |
| Language | Dart SDK | 3.13.5 (^3.13.0) | Programming language |
| Database | cloud_firestore | ^6.10.0 | Cloud document storage and real-time streams |
| Authentication | firebase_auth | ^6.7.0 | User credential management and authentication |
| OAuth | google_sign_in | ^7.2.0 | Google identity authentication |
| State Management | flutter_riverpod | ^3.4.3 | Reactive, compile-safe dependency injection |
| Routing | go_router | ^18.0.2 | Declarative navigation with authentication guards |
| Preferences | shared_preferences | ^2.5.5 | Local key-value storage for UI theme mode |
| Formatting | intl | ^0.20.3 | Currency formatting and calendar date operations |
| Testing Mocks | fake_cloud_firestore | ^4.3.0 | In-memory Firestore simulation for tests |
| Auth Mocks | firebase_auth_mocks | ^0.15.2 | In-memory authentication simulation for tests |
| Icon Generator | flutter_launcher_icons | ^0.14.4 | Adaptive Android app launcher icon synthesis |

## Architecture

Wayfound follows a feature-first, layered architectural pattern. Each domain capability is organized into an independent feature package containing dedicated presentation, domain, and data layers.

```text
               +-------------------------------------+
               |         Presentation Layer          |
               |  (Widgets, Screens, State Notifiers)|
               +-------------------------------------+
                                  |
                                  v
               +-------------------------------------+
               |            Domain Layer             |
               |  (Entities, Models, Business Math)  |
               +-------------------------------------+
                                  |
                                  v
               +-------------------------------------+
               |             Data Layer              |
               |  (Repositories, Stream Providers)   |
               +-------------------------------------+
                                  |
                                  v
               +-------------------------------------+
               |        Cloud Firestore & Auth       |
               +-------------------------------------+
```

### Directory Structure

```text
lib/
├── app/
│   └── router.dart               # GoRouter route declarations and redirect guards
├── core/
│   ├── currency_formatters.dart  # Minor unit money parsing and localized formatting
│   ├── firebase_providers.dart   # Firebase app initialization and emulator toggles
│   ├── theme.dart                # Light and Dark ColorScheme definitions
│   └── widgets/                  # Shared UI components (loading, errors, buttons)
└── features/
    ├── auth/                     # Authentication, profiles, and app settings
    │   ├── data/                 # AuthRepository and auth stream providers
    │   ├── domain/               # AppUser domain entity model
    │   └── presentation/         # Welcome, SignIn, SignUp, and Settings screens
    ├── trips/                    # Trip lifecycle, invites, and members
    │   ├── data/                 # TripRepository and member stream providers
    │   ├── domain/               # Trip, Member, and JoinPreview models
    │   └── presentation/         # HomeScreen, CreateTrip, JoinTrip, MembersTab
    ├── suggestions/              # Group idea board and voting
    │   ├── data/                 # SuggestionRepository
    │   ├── domain/               # Suggestion and Vote models
    │   └── presentation/         # SuggestionsTab and AddEditSuggestionScreen
    ├── itinerary/                # Daily scheduling and reordering
    │   ├── data/                 # ItineraryRepository
    │   ├── domain/               # ItineraryItem model and calendar calculations
    │   └── presentation/         # ItineraryTab, DayPicker, PendingSuggestions
    ├── expenses/                 # Shared expense management and split tracking
    │   ├── data/                 # ExpenseRepository
    │   ├── domain/               # Expense, Split, and ExpenseCalculator
    │   └── presentation/         # ExpensesTab, AddEditExpense, BalancesView
    └── settlements/              # Payment confirmation and leave eligibility
        ├── data/                 # SettlementRepository
        ├── domain/               # Settlement model and LeaveEligibility checker
        └── presentation/         # MarkAsPaidSheet and settlement status chips
```

## Data Model

Wayfound structures data within Cloud Firestore using root collections for users, trips, and join codes, alongside scoped subcollections for trip-specific resources.

### Firestore Collections Overview

| Collection Path | Scope | Purpose |
|---|---|---|
| `/users/{uid}` | Root | User account metadata and display names |
| `/trips/{tripId}` | Root | Core trip documents with membership arrays |
| `/joinCodes/{code}` | Root | Public invite metadata mapping 6-character codes to trips |
| `/trips/{tripId}/members/{uid}` | Subcollection | Member status, roles, and join timestamps |
| `/trips/{tripId}/suggestions/{id}` | Subcollection | Group activity and dining suggestions |
| `/trips/{tripId}/suggestions/{id}/votes/{uid}` | Nested Subcollection | Individual member votes (-1, 0, +1) |
| `/trips/{tripId}/itinerary/{id}` | Subcollection | Scheduled daily itinerary items |
| `/trips/{tripId}/expenses/{id}` | Subcollection | Recorded expenses and participant splits |
| `/trips/{tripId}/settlements/{id}` | Subcollection | Two-step debt settlement payments |

### Document Field Specifications

#### `trips/{tripId}`
- `title` (String): Trip display name
- `destination` (String): Destination name
- `startDate` (Timestamp): Beginning of trip
- `endDate` (Timestamp): Conclusion of trip
- `currency` (String): Base currency code (`USD`, `EUR`, `GBP`, `JPY`)
- `organizerId` (String): UID of the creator
- `memberIds` (List<String>): UIDs of active participants (used for query filters)
- `memberCount` (int): Active participant count
- `archived` (bool): Read-only status flag
- `createdAt` (Timestamp): Creation timestamp

#### `joinCodes/{code}`
- `tripId` (String): Target trip ID
- `tripTitle` (String): Target trip title
- `destination` (String): Destination preview
- `startDate` (Timestamp): Trip start timestamp
- `endDate` (Timestamp): Trip end timestamp
- `currency` (String): Trip currency
- `organizerId` (String): Trip organizer UID
- `memberCount` (int): Current member count
- `createdAt` (Timestamp): Code generation timestamp

#### `trips/{tripId}/members/{uid}`
- `displayName` (String): Member name
- `email` (String): Member email
- `joinedAt` (Timestamp): Join timestamp
- `role` (String): `organizer` or `member`
- `status` (String): `active` or `left`

#### `trips/{tripId}/expenses/{expenseId}`
- `title` (String): Expense description
- `amount` (int): Total expense in integer minor units
- `currency` (String): Currency code
- `paidBy` (String): UID of payer
- `participantIds` (List<String>): UIDs of members sharing the cost
- `splitType` (String): `equal`
- `date` (Timestamp): Date expense occurred
- `createdAt` (Timestamp): Document creation timestamp

#### `trips/{tripId}/settlements/{settlementId}`
- `fromUid` (String): Payer UID
- `toUid` (String): Payee UID
- `amount` (int): Settlement amount in minor units
- `currency` (String): Currency code
- `status` (String): `pending`, `confirmed`, or `rejected`
- `createdAt` (Timestamp): Creation timestamp
- `resolvedAt` (Timestamp, optional): Resolution timestamp

## Money Handling

### Minor Unit Storage

All monetary figures are stored and processed strictly as integers in minor currency units (such as cents or yen). Floating-point values are never stored or accumulated, avoiding IEEE 754 precision errors.

- **USD, EUR, GBP**: 2 decimal places (Scale factor: 100). For example, $12.50 is stored as `1250`.
- **JPY**: 0 decimal places (Scale factor: 1). For example, ¥500 is stored as `500`.

### Equal Split Algorithm with Remainder Distribution

When dividing an expense among $N$ participants, integer division (`amount ~/ N`) yields a base share for each participant. Any remainder (`amount % N`) is distributed by adding 1 minor unit to the first participants in the list until the remainder is exhausted.

```text
Example: $10.00 split among 3 participants
- Total Minor Units: 1000
- Base Share: 1000 ~/ 3 = 333 cents ($3.33)
- Remainder: 1000 % 3 = 1 cent
- Distribution:
  * Participant 1: 334 cents ($3.34)
  * Participant 2: 333 cents ($3.33)
  * Participant 3: 333 cents ($3.33)
- Sum: 334 + 333 + 333 = 1000 cents ($10.00 exact)
```

### Dynamic Balance Calculation

Balances are never stored in database documents. Instead, net balances are computed in memory whenever expense or settlement streams emit updates:
1. Initialize each member's net balance at zero.
2. For every expense, credit the payer by the full amount and debit each participant by their computed share.
3. For every **confirmed** settlement, credit the payer (`fromUid`) and debit the receiver (`toUid`). Pending and rejected settlements are ignored.
4. Sum each member's net position.

### Debt Settlement Simplification

The app applies a greedy cash-flow reduction algorithm:
1. Identify all net debtors (balance < 0) and net creditors (balance > 0).
2. Pair the largest debtor with the largest creditor.
3. Form a suggested settlement for `min(|debt|, credit)`.
4. Update balances and repeat until all debts resolve to zero.

## Security Model

Wayfound enforces data integrity through server-side Cloud Firestore Security Rules (`firestore.rules`).

### Server-Enforced Invariants

- **Authentication**: All read and write requests require a signed-in user account.
- **Trip Isolation**: Users can only read trip documents and subcollections if their UID is present in the trip's `memberIds` array.
- **Archive Immutability**: All subcollection writes require the parent trip document to have `archived == false`. Once archived by the organizer, the trip becomes permanently read-only across all subcollections.
- **Organizer Protections**: Only the organizer can archive a trip. Unarchiving is denied by rules.
- **Member Departure**: Leaving or removing a member updates `memberIds`, decrements `memberCount`, and marks the member status doc as `left` in an atomic batch.
- **Expense Integrity**: Expenses cannot be updated or deleted if any participant has departed the trip, preserving historical financial auditability.
- **Settlement Lifecycle**: Payers can create pending settlements and delete their own unconfirmed settlements. Only the designated recipient (or non-payer organizer) can confirm or reject payments.

### Client-Side Validation Guards

- **Leave Balance Check**: The client verifies that a member has a zero net balance and no pending settlements before permitting them to initiate a trip departure.
- **Input Validation**: Text length bounds, date chronological order, and positive money input parsing.

## Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev) 3.47.7 (or compatible 3.13+ channel)
- [Dart SDK](https://dart.dev) 3.13.5
- Android Studio with Android SDK 37.0.0
- [Node.js](https://nodejs.org) v18 or higher (for Firebase Rules testing)
- [Firebase CLI](https://firebase.google.com)

### Installation

Clone the repository:

```bash
git clone https://github.com/Aayush049/wayfound.git
cd wayfound
```

Fetch Flutter dependencies:

```bash
flutter pub get
```

### Firebase Project Setup

Wayfound requires connection to your own Firebase project. Replace the repository configuration with your own project credentials:

1. Create a project in the [Firebase Console](https://console.firebase.google.com).
2. Add an Android app with package name `com.ayush.wayfound`.
3. In Authentication, enable **Email/Password** and **Google** providers.
4. In Cloud Firestore, create a database instance.
5. Install and execute the FlutterFire CLI to generate `lib/firebase_options.dart`:
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
6. Download your app's `google-services.json` from the Firebase Console and place it into `android/app/google-services.json`.
7. Deploy the repository security rules:
   ```bash
   firebase deploy --only firestore:rules
   ```

### Running the App

Start the app on an Android device or emulator:

```bash
flutter run
```

To run against local Firebase Emulators:

```bash
flutter run --dart-define=USE_EMULATORS=true
```

## Testing

Wayfound contains automated verification suites spanning unit tests, widget tests, navigation flows, and security rules.

### Running Flutter Tests

Execute the Flutter test suite:

```bash
flutter test
```

For verbose, expanded test progress output:

```bash
flutter test --reporter expanded
```

The Flutter test suite contains 353 passing automated tests (as of v1.0.0), covering:
- Authentication state, sign-in, sign-up, and profile flows
- Router guards and deep navigation transitions
- Date mathematics and UTC trip day arithmetic
- Money calculations, rounding distribution, and settlement generation
- Widget UI rendering, role-based visibility, and accessibility
- Overflow safety matrix tests across compact devices and accessibility font scales
- Read-only sweep verification on archived trips

### Running Firestore Security Rules Tests

The security rules test suite is written in Jest using the Firebase Rules Unit Testing library.

1. Ensure dependencies are installed in the test harness:
   ```bash
   npm --prefix rules_test install
   ```
2. Execute the test suite inside the Firebase Local Emulator:
   ```bash
   firebase emulators:exec --only firestore "npm --prefix rules_test test"
   ```

Note: Rules unit tests require the Firebase Local Emulator Suite running on port 8092.

## Building a Release APK

Wayfound can be compiled into an optimized release APK for distribution.

### Build Commands

To build an optimized split APK per CPU architecture:

```bash
flutter build apk --release --split-per-abi
```

To build a universal APK:

```bash
flutter build apk --release
```

To build an Android App Bundle (AAB):

```bash
flutter build appbundle --release
```

### Output Artifacts

Compiled installation binaries land under:
- **Universal APK**: `build/app/outputs/flutter-apk/app-release.apk`
- **Split APKs**: `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- **App Bundle**: `build/app/outputs/bundle/release/app-release.aab`

### Signing Configuration

By default, the Android Gradle build file (`android/app/build.gradle.kts`) signs release builds using debug keys for local verification.

For production releases, configure a production release keystore:
1. Generate an upload keystore with `keytool`.
2. Configure your signing credentials in Gradle according to official Android deployment guidelines.

## Project Status and Roadmap

### Milestone Delivery Status

Version 1.0.0 satisfies all planned core requirements:
- Account creation and authentication
- Trip lifecycle and invite codes
- Categorized suggestions and community voting
- Daily itinerary scheduling and reordering
- Expense logging and equal split remainder math
- Net balance calculation and two-step settlement tracking
- Safe member departure and removal workflows
- Complete trip archiving and read-only enforcement across all tabs

### Known Limitations

- **Archive One-Way**: Archiving is permanent in version 1; trips cannot be unarchived.
- **No Rejoin**: Members who leave a trip cannot rejoin the same trip in this version.
- **Refused Join Message**: Because non-members cannot read trip documents before joining, the refusal screen explains that a trip may be archived or the user may have left previously.
- **Single Currency**: Each trip operates under one chosen base currency without dynamic conversion.
- **Android Target**: Version 1 is configured and tested for Android devices.

### Post-v1 Considerations

The following concepts are under consideration for future updates:
- Push notifications for trip updates and payment requests
- Comment discussions on individual suggestions and itinerary items
- Receipt image attachments on expenses
- Shared packing lists and item assignment
- Unequal expense split options (percentages, shares, itemized costs)

## Troubleshooting

### 1. Firebase Options or Services Missing
- **Symptom**: App crashes on startup with initialization exceptions.
- **Fix**: Run `flutterfire configure` to generate `lib/firebase_options.dart` and confirm `android/app/google-services.json` is present.

### 2. Firestore Permission Denied
- **Symptom**: Queries return `permission-denied` errors when viewing trips or adding ideas.
- **Fix**: Deploy the project security rules using `firebase deploy --only firestore:rules`.

### 3. Rules Unit Tests Connection Refused
- **Symptom**: Running `npm test` fails with `ECONNREFUSED 127.0.0.1:8092`.
- **Fix**: Rules tests require the emulator. Use `firebase emulators:exec --only firestore "npm --prefix rules_test test"`.

### 4. Release APK Network Failure
- **Symptom**: Debug builds connect to Firebase, but release APKs cannot authenticate or load data.
- **Fix**: Ensure `<uses-permission android:name="android.permission.INTERNET"/>` is declared in `android/app/src/main/AndroidManifest.xml`.

### 5. Google Sign-In Error Code 10
- **Symptom**: Google Sign-In fails with `PlatformException(10)`.
- **Fix**: Register your app signing keystore certificate fingerprint in the Firebase Console under Android app settings.

### 6. App Install Failed Due to Signature Mismatch
- **Symptom**: `INSTALL_FAILED_UPDATE_INCOMPATIBLE` when installing a release APK over a debug build.
- **Fix**: Uninstall the existing debug version from the device before installing the signed release APK.

## Contributing

Contributions and issue reports are welcome. Please adhere to the following workflow:

1. Fork the repository on GitHub.
2. Create a topic branch from `main`:
   ```bash
   git checkout -b feat/your-improvement
   ```
3. Follow the Conventional Commits specification for commit messages:
   - `feat(scope): ...`
   - `fix(scope): ...`
   - `test(scope): ...`
   - `docs(scope): ...`
   - `chore(scope): ...`
4. Verify all automated tests and analysis pass cleanly:
   ```bash
   flutter analyze
   flutter test
   ```
5. If modifying `firestore.rules`, ensure the rules test suite runs and passes.
6. Open a Pull Request targeting `main`. Do not force-push to shared branches.

## Security Reporting

If you identify a security vulnerability, please do not disclose it publicly in an issue or forum. Report vulnerabilities privately using a GitHub Security Advisory on the repository:

https://github.com/Aayush049/wayfound

Alternatively, contact maintainer Aayush049 directly through their GitHub profile.

## Licence

No licence has been specified yet; all rights are reserved by the author until one is added.

## Author and Acknowledgements

Wayfound is authored and maintained by [Aayush049](https://github.com/Aayush049).

Acknowledgements:
- [Flutter](https://flutter.dev) and [Dart](https://dart.dev) teams at Google
- [Firebase](https://firebase.google.com) for real-time document storage and authentication
- [Riverpod](https://riverpod.dev) by Remi Rousselet for robust state management
- [go_router](https://pub.dev/packages/go_router) for declarative routing
