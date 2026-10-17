# Wayfound - Version 2 Starting Point

## 1. Baseline
- **Product Name:** Wayfound (Collaborative group trip planner)
- **Application ID:** `com.ayush.wayfound` (Android, Kotlin)
- **Application Version:** `1.0.0+1` (from `pubspec.yaml`)
- **Repository URL:** `https://github.com/Aayush049/wayfound.git`
- **Main Commit:** `e3e50bd2342251b3fafe408de92b555da5d58628`
- **First Commit Date:** October 4, 2026 (13 elapsed calendar days to v1 completion)
- **Flutter SDK:** Flutter 3.47.7 (Channel stable)
- **Dart SDK:** Dart 3.13.5 (pubspec environment constraint: `sdk: ^3.13.0`)
- **Flutter Test Suite:** 357 passed (0 failed, 0 skipped, exit code 0)
- **Firestore Security Rules Tests:** 185 passed (185 total unit tests in Jest)
- **Security Rules Mutation Suite:** 81 mutants evaluated (70 killed, 11 allowlisted equivalents)
- **Firestore Security Rules SHA-256:** `6D13FEAE51D0E6FD56911FC8AEEF895C8706763CF147BDD311FBC6933AA31DA6`
- **Current Development Status:** Version 1 build complete; Web platform added; release packaging pending

## 2. Repo Map
- `android/`: Native Android platform Gradle project, manifest definitions, and app icons
  - `android/app/src/main/AndroidManifest.xml`: Primary application manifest and intent filters
  - `android/app/build.gradle`: Android application build configuration and SDK version settings
- `assets/`: Static image and brand assets bundled with the mobile application
  - `assets/images/logo.png`: Wayfound primary brand logo
- `docs/version_1/`: Canonical documentation, working report, evidence artifacts, and tools
  - `docs/version_1/wayfound_v1_working_report.md`: Version 1 comprehensive working report
  - `docs/version_1/v2_starting_point.md`: Version 2 engineering roadmap and repository baseline
  - `docs/version_1/evidence/`: Preserved raw execution evidence from test and quality gates
  - `docs/version_1/tools/count.js`: Flutter test breakdown counting utility
- `lib/`: Flutter Dart application codebase structured with feature-first architecture
  - `lib/app/`: Application-level bootstrapping, theme tokens, and declarative router
    - `lib/app/main.dart`: Entry point configuring Firebase and Riverpod ProviderScope
    - `lib/app/router.dart`: Declarative GoRouter routing tree with auth state redirects
    - `lib/app/theme/`: Material 3 Ocean Blue and Teal color scheme and theme notifier
  - `lib/core/`: Common domain logic, integer currency utilities, and shared presentation widgets
    - `lib/core/money.dart`: Minor unit currency parsing and formatting functions
    - `lib/core/errors/`: App-level failure definitions and user-facing error message mappers
    - `lib/core/widgets/`: Reusable loading indicators, error views, and buttons
  - `lib/features/auth/`: Firebase user authentication, create-once profile document, and settings UI
  - `lib/features/trips/`: Trip creation, join code resolution, trip dashboard shell, and members tab
  - `lib/features/suggestions/`: Suggestions CRUD, atomic vote transactions, and suggestion cards
  - `lib/features/itinerary/`: Day-by-day itinerary sections, drag reordering, and day picker sheet
  - `lib/features/expenses/`: Expenses CRUD, equal integer split calculation, and balances view
  - `lib/features/settlements/`: Two-step settlements (record/confirm/reject), and leave eligibility
- `rules_test/`: Cloud Firestore security rules Jest test suite, mutant fixtures, and test runners
  - `rules_test/firestore_rules.test.js`: 185 security rules unit test cases against Firestore emulator
  - `rules_test/mutation/mutants.json`: Complete catalog of 81 CEL security rules mutations
  - `rules_test/mutation/equivalent.json`: Documentation of 11 allowlisted equivalent mutants
  - `rules_test/mutation/harness_v3.js`: Automated mutation test harness with orphan cleanup
- `test/`: Flutter unit, widget, provider, repository, and router integration test suites
- `web/`: Flutter web platform runner, HTML host file, web app manifest, and icons

## 3. How to Run Everything
- **Install dependencies:** `flutter pub get`
- **Run Dart code formatter check:** `dart format --output=none --set-exit-if-changed lib test`
- **Run Dart static analyzer:** `flutter analyze`
- **Run full Flutter test suite:** `flutter test --reporter expanded`
- **Run security rules unit tests:** `firebase emulators:exec --only firestore "npm --prefix rules_test test"`
- **Run mutation harness:** `node rules_test/mutation/harness_v3.js`
- **Mutation harness output directory:** `rules_test/mutation/out_v3` (local scratch files; git-ignored)
- **Run application on Android emulator:** `flutter run --dart-define=USE_EMULATORS=true`
- **Run application on physical Android phone:**
  - Forward emulator ports over ADB: `adb reverse tcp:9099 tcp:9099 ; adb reverse tcp:8092 tcp:8092`
  - Launch app: `flutter run --dart-define=USE_EMULATORS=true --dart-define=EMULATOR_HOST=127.0.0.1`
- **Run application locally on Web:** `flutter run -d chrome`
- **Compile release APK build:** `flutter build apk --release --split-per-abi`
- **Compile release Web build:** `flutter build web --release`

## 4. Security-Critical Files and Rule-Change Procedure
- **Security-critical files:** `firestore.rules`, `rules_test/firestore_rules.test.js`, `rules_test/mutation/mutants.json`, `rules_test/mutation/equivalent.json`, `rules_test/mutation/harness_v3.js`
- **Rule-change procedure:**
  1. Modify security rules inside `firestore.rules`.
  2. Add targeted unit tests in `rules_test/firestore_rules.test.js` to cover new authorization branches.
  3. Add corresponding negative mutant definitions to `rules_test/mutation/mutants.json`.
  4. Run the mutation harness: `node rules_test/mutation/harness_v3.js`. Verified baseline expectation is 81 mutants: 70 killed and 11 allowlisted (`m1`, `m4a`, `m4b`, `m4c`, `m49`, `m50`, `m51`, `m54`, `m58`, `m59`, `m66`).
  5. Check `git status` to verify no scratch files leak outside `rules_test/mutation/out_v3`.
  6. Re-verify the SHA-256 hash of `firestore.rules`.
  7. Manual production deployment: The user deploys to Firebase via `firebase use wayfound-51b4d` followed by `firebase deploy --only firestore:rules`. Claude Code / AI assistant never deploys to production.

## 5. Working Agreements for AI-Assisted Sessions
- **Branch isolation:** Develop on phase or fix branches (`phase-X/...` or `fix/...`); never commit feature code directly on `main`.
- **Commit discipline:** Use logical, focused commits with standard conventional prefixes (`feat`, `fix`, `test`, `docs`, `chore`, `refactor`).
- **Standardized handoff:** Provide session handoffs in chat following the fixed 14-field format under 70 lines.
- **Evidence-based verification:** Every factual claim must be backed by raw tool command output executed in the active session.
- **Upload economy:** Emit only the chat handoff and at most one compact summary artifact; no redundant report files on disk.
- **Non-destructive operations:** Never use destructive git commands (`git clean`, `git reset --hard`, `git push --force`) or destructive file deletions.

## 6. Decisions That Constrain v2
- **One-way trip archive:** Trip archiving is one-way in v1 (`archived: false -> true`); all subcollection mutations are rejected once archived; no unarchive UI or rule exists.
- **Permanent leave policy:** Members who leave or are removed cannot rejoin with the join code; rules explicitly deny membership if `members/{uid}.status == 'left'`.
- **Minor unit integer money:** Currency values are stored strictly as integers in minor units (cents/paise), using deterministic UID-sorted remainder distribution for equal splits to prevent floating-point rounding errors.
- **Server rules enforce read-only:** Security rules reject any subcollection writes on archived trips at the database layer.
- **Archived trip ordering:** Archived trips are displayed on Home after active trips under an Archived header with an Archived chip.
- **Join code preview limitation:** `joinCodes/{code}` does not store trip archive state, and non-members cannot read `trips/{tripId}` prior to joining; dedicated archived join messaging requires a rules and schema backfill.
- **Web URL strategy:** The web platform uses the default hash URL routing strategy (`/#/welcome`, `/#/home`); path URL strategy without hashes requires custom server rewrites on hosting environments.
- **Service worker caching:** Firebase Hosting deploys may serve cached assets until a hard refresh or background service worker update completes; critical entry points use `no-cache` headers.
- **iOS platform:** iOS platform is currently out of scope and not configured or supported (`ios/` does not exist in the repository).
- **Lockfile discipline:** `pubspec.lock` is version-controlled and must not change unless dependencies are upgraded deliberately (`flutter create` commands can silently trigger unconstrained dependency re-resolution); use `flutter pub get --enforce-lockfile` to detect accidental changes.

## 7. Prioritised v2 Backlog
1. **Dedicated archived join message:** Add `archived` field to `joinCodes` documents and backfill existing codes to allow join preview to show specific archived notices without permission errors.
2. **Rejoin after leaving:** Redesign join rules and member document state transitions to allow previously departed members to rejoin when eligible.
3. **Organizer role transfer:** Allow organizers to transfer the organizer role to an active member prior to leaving the trip.
4. **Unarchive trips:** Implement reversible trip archiving with corresponding security rules updates and read-only sweep reversibility.
5. **Add to itinerary shortcut:** Provide a 1-tap action directly on suggestion cards to schedule top suggestions into itinerary days without opening the bottom sheet.
6. **Phase 8 feature expansions:** Push notifications for voting deadlines, comments on suggestions, photo attachments, shared packing checklists, and unequal splits.

## 8. Evidence Index
| File | What It Proves | Regeneration Command |
|---|---|---|
| `docs/version_1/evidence/01_flutter_test_final.txt` | Full Flutter test suite passes (353 passed) | `flutter test --reporter expanded` |
| `docs/version_1/evidence/02_flutter_test_counts.txt` | Flutter test breakdown by test file (353 total) | `node docs/version_1/tools/count.js` |
| `docs/version_1/evidence/03_analyze_final.txt` | Dart static analysis clean with 0 issues | `flutter analyze` |
| `docs/version_1/evidence/04_format_final.txt` | Dart formatting complies with standard style | `dart format --output=none --set-exit-if-changed lib test` |
| `docs/version_1/evidence/05_rules_hash_final.txt` | Pristine SHA-256 hash of `firestore.rules` | `powershell -Command "(Get-FileHash firestore.rules -Algorithm SHA256).Hash"` |
| `docs/version_1/evidence/06_rules_tests_final.txt` | Firestore security rules emulator unit tests (185 passed) | `firebase emulators:exec --only firestore "npm --prefix rules_test test"` |
| `docs/version_1/evidence/07_mutation_harness_final.txt` | Mutation harness kills all 70 non-equivalent mutants | `node rules_test/mutation/harness_v3.js` |
| `docs/version_1/evidence/08_main_origin_verify_final.txt` | Local main commit equals origin/main commit | `git rev-parse HEAD main origin/main` |
| `docs/version_1/evidence/09_r1_release_audit_summary.txt` | Baseline release readiness findings | `git show release/r1-audit:docs/evidence/r1/UPLOAD_SUMMARY.txt` |
| `docs/version_1/evidence/equivalence/P1_real.txt` | Real rule evaluation for equivalence probe 1 | Probe test run |
| `docs/version_1/evidence/equivalence/P1_m54.txt` | Mutant m54 evaluation for equivalence probe 1 | Probe test run |
| `docs/version_1/evidence/equivalence/P2_real.txt` | Real rule evaluation for equivalence probe 2 | Probe test run |
| `docs/version_1/evidence/equivalence/P2_m50.txt` | Mutant m50 evaluation for equivalence probe 2 | Probe test run |

## 9. Legacy Tooling
- `rules_test/tools/run_k1.js`, `rules_test/tools/run_k2.js`, and `rules_test/mutation/run.js` are historical legacy scripts.
- They depend on past evidence paths that exist only in `D:\VsCode\wayfound_archive/`. They are not part of the supported workflow and must not be used for verification.

## 10. Open Questions
- **Software Licence:** An open-source or proprietary licence has not yet been selected.
- **Distribution Model:** Release packaging and distribution channels beyond direct sideload APKs (Google Play, F-Droid) are undecided.
- **Firebase App Check:** Production attestation provider (Play Integrity) and enforcement timeline remain pending.
