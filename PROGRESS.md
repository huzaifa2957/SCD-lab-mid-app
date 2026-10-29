# StudentNest – Progress

_Last updated: 2026-10-28_

## Status
All 7 phases are **code-complete**. `flutter analyze` reports no issues, `flutter test` passes (6/6), `flutter build web` succeeds, and the Firestore rules are deployed.
The app was running in Chrome at http://localhost:5555 (`flutter run -d chrome --web-port 5555`). The seeder ran successfully with the real security rules active.
README.md is written: run steps, demo accounts, 5-minute demo script and the user-story mapping.
**Not done yet:** a hands-on click-through of the UI (only a code review was done) and the Android emulator run.

## Done

### Setup
- Project at `C:\Users\hp\Desktop\studentnest` (`--org com.studentnest`, platforms: android, web).
- `flutterfire configure` generated `lib/firebase_options.dart` (web + android apps registered) and `android/app/google-services.json`.
- Packages: firebase_core 5, firebase_auth 7, cloud_firestore 7, provider, **google_fonts ^8** (v9 is incompatible because it moved to the `material_ui` TextTheme), image_picker, flutter_map 8, latlong2, fl_chart, intl, uuid.
- `firebase.json` (firestore section), `.firebaserc`, `firestore.rules`, and `firestore.indexes.json` (empty: no composite indexes are needed).
- Assets: 12 Unsplash room photos in `assets/images/rooms/`, plus a generated demo student ID and selfie in `assets/images/demo/`. Both are registered in pubspec.
- Android: `minSdk = 23`, `multiDexEnabled = true`, INTERNET permission, label "StudentNest".

### Phase 1 – Foundation ✅
- Material 3 theme (teal #0F766E + indigo, Poppins, 16px cards): `lib/theme/app_theme.dart`.
- `SessionProvider` streams the auth user and `users/{uid}`. A suspended user is signed out with a message.
- `RootGate`: splash (runs the seeder on first start) → auth → verify-email (skipped when isDemo) → role shell.
- Auth screen: Log In / Sign Up tabs, Student/Landlord role cards, validation, forgot password, friendly error messages (including duplicate email), demo-account quick-fill chips.
- Shells: Student (Home, Roommates, Chat, Saved, Profile), Landlord (My Listings, Enquiries, Profile), Admin (Verifications, Listings, Reports, Stats + a menu with moderation, reseed and logout).

### Phase 2 – Seeder ✅ (verified)
- `lib/services/seed_service.dart`: creates accounts through a secondary FirebaseApp named `seeder`, signs in when an account already exists, and writes as admin. Doc IDs are deterministic, so reseeding is idempotent.
- Accounts (password `Demo@123`): student, paid, landlord, admin and pending, all `@demo.com`.
- Seeded data:
  - 15 rooms across 6 cities: 2 premium, 2 flagged, 1 pending, 1 rented.
  - 12 extra students plus 1 suspicious landlord ("QuickLets Ltd").
  - 4 conversations, 5 reviews, 2 open reports, 8 payments and welcome notifications.
- Verified over REST: all 5 accounts log in, the student sees 13 approved rooms, the admin queues contain 1 verification, 1 pending room and 2 reports, and there are 8 payments.

### Phases 3–6 – Student, Chat, Landlord, Admin ✅ (code complete)
- **Student:**
  - Lifestyle editor with privacy toggles.
  - ID verification (ID + selfie, stored as base64).
  - Search with city chips, filter sheet (rent, deposit, distance, type, sort), and a list/map toggle with OSM price pins. Premium listings rank first.
  - Room details: gallery, red flag banner, stay-safe box, map with campus, landlord rating, and Save / Report / Contact buttons.
  - Saved tab with swipe-to-remove.
  - Roommates: locked view with blurred cards and $20 payment, then a ranked list with city and budget filters.
  - User profile shows the score breakdown, reviews, Message and Report.
  - Reviews are allowed only after a chat.
  - Report form with a confirmation screen.
  - Delete account: confirmation, password re-auth, Firestore data deleted, then the Auth user deleted.
- **Matching:** `lib/services/matching_service.dart` uses the weights 20/20/15/10/15/10/10. It is lifestyle-only and includes a fairness comment.
- **Chat:** live conversation list (unread dot, time), message bubbles, auto-scroll, report and review menu. Each message creates a notification for the receiver.
- **Landlord:**
  - Identity verification (ID + ownership proof).
  - Listings show status chips and a summary row.
  - Create/edit form: map picker for the room and campus, campus presets, rules chips, up to 3 photos. The first 2 listings are free; after that a $10 payment is required.
  - Mark rented/available, delete, and a $10 premium boost lasting 30 days.
  - Enquiries tab; tenants can be reviewed from the chat menu.
- **Admin:**
  - Verifications queue with tap-to-enlarge images and approve/reject + notification.
  - Listings queue (pending or all) with approve, reject with reason, and flag/unflag.
  - Reports queue with dismiss, flag listing, remove listing and suspend user; the reporter is notified.
  - Content moderation: remove reviews with a reason.
  - Stats: 8 metric cards, a listings-per-city bar chart and a revenue pie chart.
- **Payments:** simulated bottom sheet with "Use test card" / "Declining card" chips, a 2-second spinner, a success screen, and a failure screen with Retry. Card `4000 0000 0000 0002` always fails. Every attempt is written to `payments`.

### Phase 7 – Polish & security (mostly) ✅
- Notifications screen plus a bell with an unread badge in every app bar. Includes mark-read and mark-all-read.
- Skeleton loaders, empty states, error views, snackbars and pull-to-refresh.
- Firestore rules **deployed and tested over REST**:
  - Allowed: student chat batch, payment, matching unlock, landlord create/boost/rented/available, verification submit, review, report, admin approve.
  - Denied (403): student reading a pending room, student reading reports, self-promotion to admin, landlord self-approving a listing.
- A rules bug that broke the seeder (users create had no admin clause) was fixed and redeployed.

### Session 2
- Code review for runtime issues found one bug: duplicate `Hero` tags (Home and Saved are both mounted in an IndexedStack), which would assert when a room is opened. All Heroes were removed.
- README.md written.
- Re-verified: analyze clean, 6/6 tests pass, web build OK. The app was relaunched in Chrome on port 5555.

## Next (in order)
1. **User** clicks through the demo script in Chrome and reports anything broken. Fix it, then re-run analyze, test and build.
2. **Android** (when the user says "Android SDK is ready"): `flutter doctor`, `flutter doctor --android-licenses`, `flutter emulators --launch <id>`, `flutter run`, then fix any Gradle/Kotlin issues.
3. Optional: before the demo, run Admin → menu → "Reseed demo data" to reset state.

## Notes
- If the seeder ever needs to run again from scratch, delete `meta/seed` in the Firestore console and restart the app, or use the admin Reseed button.
- Test helper scripts (REST rules checks) were left in the session scratchpad, not in the project.
