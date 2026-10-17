# Wayfound

> Collaborative group trip planning and shared expense settlements made simple.

![Flutter](https://img.shields.io/badge/Flutter-3.47.7-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.13.5-0175C2?logo=dart)
![Firebase](https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore-FFCA28?logo=firebase&logoColor=black)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20Web-3DDC84?logo=android&logoColor=white)
![Status](https://img.shields.io/badge/Version-1.0.0-success)

---

## Overview

Planning a trip with friends usually turns into a chaotic mess of scattered group chats, lost activity suggestions, and stressful post-vacation expense calculations.

**Wayfound** brings everything your travel group needs into one unified mobile app:
- **Collaborate on ideas**: Pitch places to visit, restaurants to try, or places to stay, and let the group vote.
- **Build the schedule**: Turn popular suggestions into a cohesive day-by-day itinerary with intuitive drag-and-drop ordering.
- **Track shared expenses**: Log who paid for what and automatically split costs among participants without penny-rounding errors.
- **Settle debts transparently**: See exactly who owes whom at any moment, settle up with a two-step confirmation flow, and archive completed journeys.

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

## Tech Stack

| Layer | Technology | Description |
|---|---|---|
| **Frontend** | [Flutter](https://flutter.dev) (Dart 3) | Cross-platform mobile framework |
| **State Management** | [Riverpod](https://riverpod.dev) | Compile-safe, reactive state management |
| **Navigation** | [GoRouter](https://pub.dev/packages/go_router) | Declarative routing with authentication guards |
| **Backend & Database** | [Cloud Firestore](https://firebase.google.com) | Real-time cloud database with security rules |
| **Authentication** | [Firebase Auth](https://firebase.google.com) | Secure email/password and Google Sign-In |
| **Local Storage** | [Shared Preferences](https://pub.dev/packages/shared_preferences) | Theme preferences (Light / Dark mode) |

---

## Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev) (Flutter 3.47.7, Dart SDK constraint `^3.13.0`)
- [Android Studio](https://developer.android.com/studio) with Android SDK
- A [Firebase](https://firebase.google.com) project

### Installation

1. **Clone the repository**:
   ```bash
   git clone https://github.com/Aayush049/wayfound.git
   cd wayfound
   ```

2. **Install Flutter packages**:
   ```bash
   flutter pub get
   ```

3. **Connect Firebase**:
   - Create a project in the [Firebase Console](https://console.firebase.google.com).
   - Add an Android app with package name `com.ayush.wayfound`.
   - Enable **Email/Password** and **Google** sign-in methods under Authentication.
   - Create a **Cloud Firestore** database.
   - Run the FlutterFire CLI or download your `google-services.json` into `android/app/`:
     ```bash
     dart pub global activate flutterfire_cli
     flutterfire configure
     ```
   - Deploy the project security rules:
     ```bash
     firebase deploy --only firestore:rules
     ```

4. **Run the app**:
   ```bash
   flutter run
   ```

---

## Running on the Web

To run the application locally in Google Chrome:

```bash
flutter run -d chrome
```

---

## Building a Release APK

To compile an optimized release APK for Android devices:

```bash
flutter build apk --release --split-per-abi
```

The compiled APKs will be generated in:
```text
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

---

## Building for the Web

To compile an optimized production web build:

```bash
flutter build web --release
```

The output files will be generated in `build/web/`.

---

## Deploying to Firebase Hosting

To host the web application on Firebase:

1. Select your target Firebase project:
   ```bash
   firebase use <your-project-id>
   ```

2. Deploy the web build artifacts:
   ```bash
   firebase deploy --only hosting
   ```

> **Note on Authentication:** Google Sign-In on the web requires your Firebase Hosting domain (or custom domain) to be listed under **Authentication** > **Settings** > **Authorized domains** in the Firebase Console. Local development on `localhost` is authorized by default.

---

## Automated Testing

Wayfound includes an extensive automated test suite covering unit math, widget rendering, navigation guards, and accessibility overflow testing:

```bash
# Run all Flutter tests
flutter test

# Run tests with verbose expanded output
flutter test --reporter expanded
```

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
