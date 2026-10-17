# Wayfound

> Collaborative group trip planning and shared expense settlements made simple.

![Flutter](https://img.shields.io/badge/Flutter-3.47.7-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.13.5-0175C2?logo=dart)
![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore-FFCA28?logo=firebase&logoColor=black)
![Platform](https://img.shields.io/badge/Platform-Android%20(Release%20APK)%20%7C%20Web%20(Live)-3DDC84?logo=android&logoColor=white)
![Status](https://img.shields.io/badge/Version-1.0.0%20(Released)-success)

---

## Overview

Planning a trip with friends usually turns into a chaotic mess of scattered group chats, lost activity suggestions, and stressful post-vacation expense calculations.

**Wayfound** brings everything your travel group needs into one unified application:
- **Collaborate on ideas**: Pitch places to visit, restaurants to try, or places to stay, and let the group vote.
- **Build the schedule**: Turn popular suggestions into a cohesive day-by-day itinerary with intuitive drag-and-drop ordering.
- **Track shared expenses**: Log who paid for what and automatically split costs among participants without penny-rounding errors.
- **Settle debts transparently**: See exactly who owes whom at any moment, settle up with a two-step confirmation flow, and archive completed journeys.

---

## Table of Contents

- [Core Features](#core-features)
- [How It Works](#how-it-works)
- [Download and Install (Android)](#download-and-install-android)
- [Web Version](#web-version)
- [Tech Stack](#tech-stack)
- [Build from Source](#build-from-source)
  - [Prerequisites](#prerequisites)
  - [Clone and Setup](#clone-and-setup)
  - [Running in Development](#running-in-development)
  - [Android Release Signing Setup](#android-release-signing-setup)
  - [Compiling Release APKs](#compiling-release-apks)
  - [Building and Deploying the Web App](#building-and-deploying-the-web-app)
- [Automated Testing](#automated-testing)
- [Roadmap & Known Limitations](#roadmap--known-limitations)
- [Troubleshooting](#troubleshooting)
- [Licence](#licence)
- [Author](#author)

---

## Core Features

### Trips & Instant Invites
- **Trip Dashboard**: Create a trip with custom destinations, travel dates, and base currencies (INR, USD, EUR, GBP, AED, AUD, CAD, SGD, JPY, CHF).
- **6-Character Join Codes**: Share a short invite code with friends. Joining members can preview trip details before joining with one tap.
- **Member Roster**: View all active participants and their roles (Organizer vs. Member).

### Suggestions & Community Voting
- **Categorized Idea Boards**: Propose suggestions across Activity, Dining, Lodging, or Other categories with descriptions and estimated costs.
- **Up & Down Voting**: Every member can vote (+1 / -1) on ideas. Net scores update in real time to establish group consensus.
- **Direct Scheduling**: High-voted suggestions can be scheduled directly into the trip itinerary.

### Visual Daily Itinerary
- **Day-by-Day View**: Organized into sequential daily sections (Day 1, Day 2, etc.) matching your trip calendar.
- **Drag-to-Reorder**: Organizers can effortlessly drag and drop activities to rearrange the sequence of events within a day.
- **Flexible Management**: Move activities between days or unschedule them back to the suggestions board without losing details.

### Expense Tracking & Smart Splits
- **Quick Expense Logging**: Record purchases with the payer, total amount, date, and a checklist of participating members.
- **Penny-Accurate Splits**: Costs are split equally with penny-remainder distribution, ensuring the sum of all individual shares matches the receipt exactly.
- **Live Share Preview**: See each participant's calculated share in real time before saving.

### Balances & Two-Step Settlements
- **Dynamic Net Balances**: Balances are calculated on the fly by combining all expenses and confirmed payments.
- **Simplified Debt Payments**: Wayfound automatically computes the most efficient, minimal transactions required to settle all debts.
- **Two-Step Confirmation**:
  1. Debtor marks a payment as paid.
  2. Creditor (or organizer) reviews and confirms or rejects the settlement.
- **Safe Departures**: Members can leave a trip only once their net balance is completely settled, preserving financial peace of mind.

### Trip Archiving
- When a vacation wraps up, the organizer can archive the trip with one tap.
- Archiving locks all data into a permanent read-only digital journal across all tabs.

---

## How It Works

```text
  [1. Create Trip] ──> [2. Share Code] ──> [3. Pitch Ideas & Vote]
                                                    │
                                                    ▼
  [6. Archive Trip] <── [5. Settle Debts] <── [4. Schedule & Split]
```

1. **Create & Invite**: Start a trip and share your 6-character code with your travel crew.
2. **Brainstorm & Vote**: Suggest spots to visit and vote on group favorites.
3. **Plan the Days**: Schedule top-voted ideas onto specific days and drag to arrange your itinerary.
4. **Log Expenses**: Add shared costs as they happen. Wayfound tracks everyone's shares.
5. **Settle Up**: Check net balances, log payments, and confirm settlements.
6. **Keep the Memory**: Archive the finished trip for permanent read-only memories.

---

## Download and Install (Android)

The signed Android APK is the primary and recommended way to use Wayfound on mobile devices.

### 1. Download the APK
Download the universal release APK from the official GitHub Release:
- **Direct Download:** [Wayfound v1.0.0 Release](https://github.com/Aayush049/wayfound/releases/tag/v1.0.0)
- **Asset Name:** `wayfound-1.0.0-universal.apk` (~57 MB, compatible with all modern Android device architectures)

### 2. Install on Your Device
1. Open the downloaded `wayfound-1.0.0-universal.apk` file on your Android phone.
2. If prompted by Android security, enable **Install unknown apps** for your browser or file manager in Settings.
3. If Google Play Protect displays an unrecognised app alert, tap **More details**, then select **Install anyway**.
4. **Previous Builds Note:** If you previously installed a debug or test build signed with a different key, Android will block the installation due to signature mismatch. Uninstall any earlier version first before installing the release build. Your trip data is safely stored in the cloud and will restore immediately upon sign-in.

### 3. First-Use Walkthrough
1. **Launch App**: Open **Wayfound** from your home screen or app drawer.
2. **Sign In**: Tap **Continue with Google** or sign up with your email and password.
3. **Create a Trip**: Tap the **+** button on the Home screen, select **Create Trip**, enter a title, destination, dates, and base currency.
4. **Invite Friends**: Copy the generated 6-character join code shown on your trip dashboard.
5. **Collaborate**: When friends enter your join code, they instantly join the roster. Pitch ideas in Suggestions, vote on favorites, schedule the itinerary, log shared expenses, and settle balances seamlessly.

---

## Web Version

Wayfound is also available directly in the browser:

- **Live URL:** [https://wayfound-51b4d.web.app](https://wayfound-51b4d.web.app)
- **Hosting Platform:** Firebase Hosting with real-time Cloud Firestore synchronization and Firebase Authentication.
- **Layout Architecture:** The web app currently uses a centered, mobile-first responsive layout (compact `< 720px`, medium `720–1099px`, expanded `>= 1100px`). It provides full feature parity with real-time voting, itineraries, and expense settlement.
- **Future Redesign:** A dedicated multi-pane desktop experience (collapsible side navigation, side-by-side itinerary boards, and multi-column ledger tables) is planned for Version 2.0. The Android APK remains the recommended primary experience for travel.

---

## Tech Stack

| Layer | Technology | Description |
|---|---|---|
| **Frontend** | [Flutter](https://flutter.dev) (Dart 3) | Cross-platform mobile and web framework |
| **State Management** | [Riverpod](https://riverpod.dev) | Compile-safe, reactive state management |
| **Navigation** | [GoRouter](https://pub.dev/packages/go_router) | Declarative routing with URL reflection and auth guards |
| **Backend & Database** | [Cloud Firestore](https://firebase.google.com) | Real-time database with declarative security rules |
| **Authentication** | [Firebase Auth](https://firebase.google.com) | Email/password and Google Sign-In (Credential & Popup) |
| **Hosting** | [Firebase Hosting](https://firebase.google.com/docs/hosting) | Single-page application web hosting with cache control |
| **Local Storage** | [Shared Preferences](https://pub.dev/packages/shared_preferences) | Device-persistent theme settings (Light / Dark mode) |

---

## Build from Source

### Prerequisites
- [Flutter SDK](https://flutter.dev) (Version 3.47.7, Dart SDK constraint `^3.13.0`)
- [Android Studio](https://developer.android.com/studio) with Android SDK (API 34+)
- A [Firebase](https://firebase.google.com) project with Authentication and Cloud Firestore enabled

### Clone and Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Aayush049/wayfound.git
   cd wayfound
   ```

2. **Install Flutter packages with locked dependencies**:
   ```bash
   flutter pub get --enforce-lockfile
   ```

3. **Configure Firebase**:
   - Create a project in the [Firebase Console](https://console.firebase.google.com).
   - Add an Android app with package name `com.ayush.wayfound`.
   - Add a Web app under project settings.
   - Enable **Email/Password** and **Google** sign-in providers under Authentication.
   - Create a **Cloud Firestore** database.
   - Place your `google-services.json` file in `android/app/google-services.json`.
   - Deploy the project security rules:
     ```bash
     firebase deploy --only firestore:rules
     ```

### Running in Development

- **Run on connected Android device or emulator**:
  ```bash
  flutter run
  ```

- **Run locally in Google Chrome**:
  ```bash
  flutter run -d chrome
  ```

### Android Release Signing Setup

1. **Generate a release keystore** (replace with your desired secure keystore location):
   ```bash
   keytool -genkeypair -v -keystore <path-to-your-keystore>.jks -alias wayfound -keyalg RSA -keysize 2048 -validity 10000
   ```

2. **Configure `android/key.properties`**:
   Create a file named `android/key.properties` (this file is git-ignored and never committed to source control):
   ```properties
   storePassword=<your-store-password>
   keyPassword=<your-key-password>
   keyAlias=wayfound
   storeFile=<path-to-your-keystore>.jks
   ```

   *Note: If `android/key.properties` is omitted, the release build type automatically falls back to debug signing with a console build warning.*

3. **Register SHA Fingerprints in Firebase**:
   Display your keystore's fingerprints:
   ```bash
   keytool -list -v -keystore <path-to-your-keystore>.jks -alias wayfound
   ```
   Copy the SHA-1 and SHA-256 fingerprints, add them under **Your apps** > **com.ayush.wayfound** in the Firebase Console to enable Google Sign-In on release builds, and replace `android/app/google-services.json` with the updated configuration.

### Compiling Release APKs

- **Compile Universal Release APK**:
  ```bash
  flutter build apk --release
  ```
  Output file: `build/app/outputs/flutter-apk/app-release.apk`

- **Compile Split Release APKs** (generates smaller, architecture-specific APKs):
  ```bash
  flutter build apk --release --split-per-abi
  ```
  Output files:
  - `build/app/outputs/flutter-apk/app-arm64-v8a-release.apk` (modern 64-bit devices, ~21 MB)
  - `build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk` (32-bit legacy devices, ~19 MB)
  - `build/app/outputs/flutter-apk/app-x86_64-release.apk` (x86_64 emulators/devices, ~23 MB)

### Building and Deploying the Web App

1. **Compile optimized web release**:
   ```bash
   flutter build web --release
   ```
   Output files will be generated in `build/web/`.

2. **Deploy to Firebase Hosting**:
   ```bash
   firebase use <your-project-id>
   firebase deploy --only hosting
   ```

   *Note on Web Authentication:* Google Sign-In on the web requires your Firebase Hosting domain (or custom domain) to be listed under **Authentication** > **Settings** > **Authorized domains** in the Firebase Console. Local testing on `localhost` is authorized by default.

---

## Automated Testing

Wayfound includes an extensive automated test suite covering unit math, widget rendering, security rules validation, and responsive layouts:

```bash
# Run all Flutter tests
flutter test

# Run tests with verbose expanded output
flutter test --reporter expanded

# Run Firestore security rules unit tests (against emulator)
firebase emulators:exec --only firestore "npm --prefix rules_test test"

# Run mutation testing harness
node rules_test/mutation/harness_v3.js
```

---

## Roadmap & Known Limitations

### Roadmap (Version 2 Candidates)
- **Full Desktop Web Redesign**: Implement a dedicated desktop user experience with collapsible side navigation, split-pane suggestion and itinerary boards, and multi-column financial dashboards.
- **Rejoin Policy**: Design secure rules transitions allowing departing members to rejoin a trip when their balance is settled.
- **Organizer Role Transfer**: Enable trip organizers to hand off the organizer role to another member before leaving a trip.
- **Dedicated Archived Join Message**: Add an `archived` property to join codes so non-members previewing trips receive an explicit archive message.
- **Firebase App Check**: Integrate App Check with Play Integrity on Android and reCAPTCHA Enterprise on Web to prevent automated endpoint abuse.
- **Google Play Store Distribution**: Prepare Android App Bundle (`.aab`) packaging and Play Console compliance.
- **Direct Suggestion Scheduling**: Provide a 1-tap shortcut directly on suggestion cards to schedule activities into itinerary days.

### Known Limitations
- **Narrow Device Tab Truncation**: On narrow Android screens (such as 360px display widths), tab labels ("Suggestions", "Expenses") may truncate due to standard tab bar padding.
- **One-Way Trip Archiving**: Archiving locks trips into a permanent read-only journal; unarchiving is not supported in v1.
- **Permanent Departure**: Once a member leaves or is removed from a trip, security rules explicitly prevent rejoining with the invite code in v1.
- **Offline Cache Scope**: Offline support relies on Firestore local persistence; no custom offline conflict resolution or offline-first synchronization guarantees exist.
- **Major Firebase Packages Deferred**: Major upgrades (`cloud_firestore` 7, `firebase_auth` 7, `firebase_core` 5) are intentionally deferred in v1 to preserve stability.
- **iOS Platform**: iOS configuration is currently out of scope and not supported.

---

## Troubleshooting

- **Firebase Initialization Errors**: Ensure `lib/firebase_options.dart` and `android/app/google-services.json` are present with your Firebase project configuration.
- **Permission Denied in Firestore**: Ensure you deployed the project rules using `firebase deploy --only firestore:rules`.
- **Google Sign-In Error Code 10 (Android)**: Verify that your Android signing keystore certificate fingerprint (SHA-1 / SHA-256) is added to your Firebase project settings.
- **Release APK Network Access (Android)**: Ensure `<uses-permission android:name="android.permission.INTERNET"/>` is declared in `android/app/src/main/AndroidManifest.xml`.
- **Popup Blocked (Web)**: If Google Sign-In does not open on web browsers, verify that popups are not blocked by browser settings or extensions.
- **Unauthorized Domain Error (Web)**: If Google Sign-In fails with an unauthorized domain error on a deployed web build, add your hosting domain to Firebase Console under Authentication > Settings > Authorized domains.
- **Stale Cache After Deploy (Web)**: If previous versions appear after deployment, perform a hard browser refresh (Ctrl+F5 or Cmd+Shift+R) to allow the service worker cache to update.

---

## Licence

No licence has been specified yet; all rights are reserved by the author until one is added.

## Author

Wayfound is built by [Aayush049](https://github.com/Aayush049).
