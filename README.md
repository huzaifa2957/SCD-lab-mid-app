# StudentNest

StudentNest helps international students (18–30) who are moving to the UK, Canada, Australia, Germany and the USA. Students get **verified rooms** with real prices and **compatible roommates**, and the app actively warns them about scam listings.

- **Students** browse for free and pay **$20 once** to unlock AI roommate matching.
- **Landlords** get **2 free listings**, then pay **$10 per listing**. They can also pay **$10 for Premium** visibility (30 days at the top of search).
- **Admins** verify identities, approve listings, handle reports and see business stats.

Built with **Flutter** and **Firebase**:
- **Firebase Auth** for email/password accounts and email verification.
- **Cloud Firestore** as the real-time database, protected by security rules.
- Maps use **OpenStreetMap** through `flutter_map`, so no API key is needed.
- Payments are **simulated**. No real money is charged.

---

## How to run

### Web (Chrome)
```bash
cd studentnest
flutter pub get
flutter run -d chrome
```
The first launch automatically creates the demo accounts and demo data (the splash screen shows "Preparing demo data…"). This takes about 10–20 seconds and happens only once.

### Android
1. Open Android Studio, choose **Open**, and select the `studentnest` folder.
2. Start an emulator from Device Manager and press **Run ▶**.

Or from a terminal with an emulator running:
```bash
flutter run
```

### Useful commands
```bash
flutter analyze        # static analysis (no issues)
flutter test           # unit tests for the matching algorithm
flutter build web      # production web build
firebase deploy --only firestore:rules --project studentnest-b0b3a
```

---

## Demo accounts

All demo accounts use the password **`Demo@123`**. The login screen also has one-tap chips that fill these in.

| Email | Role | State |
|---|---|---|
| `student@demo.com` | Student | Verified student. AI matching **locked** (shows the $20 unlock screen). |
| `paid@demo.com` | Student | Verified student. AI matching **already unlocked**. |
| `landlord@demo.com` | Landlord | Approved landlord who owns most rooms. Both free listings are used, so the next listing costs $10. |
| `admin@demo.com` | Admin | Full moderation access. |
| `pending@demo.com` | Student | ID verification **pending**, so the admin queue is not empty. |

**Test cards** in the simulated checkout:
- `4242 4242 4242 4242` succeeds.
- `4000 0000 0000 0002` is always **declined** and shows the error screen with a Retry button.

To reset everything before a demo, log in as admin and choose **⋮ → Reseed demo data**.

---

## 5-minute demo script

**1. Sign up (≈40s)**
- Open the app. The splash screen appears, then the Log In / Sign Up screen.
- On **Sign Up**, pick *Student*, then enter a name, an email and a password.
- Show validation: a bad email, a short password, or an email that already exists (for example `student@demo.com`).
- After sign-up the **Verify your email** screen appears. Point out the "I've verified" and "Resend email" buttons.
- Choose *Use a different account*.

**2. Student – `student@demo.com` (≈2 min)**
1. **Profile:** show the Verified badge, then **Edit lifestyle profile** (languages chips, sleep schedule, cleanliness slider, diet, smoking, budget, privacy toggles) and **Save**.
2. **Home:**
   - Search "Manchester", or tap a city chip.
   - Open **Filters** (max rent, deposit, distance, room type) and apply.
   - Point out that **Premium ★** rooms are listed first.
3. **Map:** switch to **Map** to see the price pins, then tap a pin to open the room.
4. **Room details:**
   - Swipe the gallery.
   - Show the Verified badge, deposit, distance to campus, house rules, the map with the campus, and the landlord rating.
   - Show the **Stay safe** box.
5. **Scam warning:** open *"Luxury studio steps from Washington Square"* (New York) to show the **red warning banner**.
6. **Save** the room (heart icon), then open the **Saved** tab and swipe to remove it.
7. **Report** the listing (Fake listing + details) to reach the confirmation screen.
8. **Roommates:**
   - The locked screen shows blurred cards. Tap **Unlock AI Matching – $20**.
   - Tap *Declining card*, then **Pay**. The payment fails; tap **Retry**.
   - Tap *Use test card*, then **Pay** to see the success screen.
   - Students now appear **ranked by score**. Open one to show the **compatibility breakdown** bars.
   - Note that the score uses lifestyle answers only: never ethnicity, nationality, religion or gender.
9. **Chat:** open the chat with James (landlord) and send a message. It appears live.

**3. Landlord – `landlord@demo.com` (≈1 min)**
1. **Enquiries:** the student's message is already there, live.
2. **My Listings → New listing:**
   - Fill in the title, description and city.
   - Use **Set on map** for the room location and pick a campus chip.
   - Enter rent and deposit, add a rule, add a photo, and submit.
   - The **$10 payment** appears because both free listings are used. After paying, the listing shows as **Pending**.
3. On any live listing, open the **⋮** menu and choose **Boost to Premium – $10**, then pay. The ★ Premium badge appears.

**4. Admin – `admin@demo.com` (≈1 min)**
1. **Verifications:** open Priya Sharma's ID (tap to enlarge) and **Approve**. She gets an in-app notification.
2. **Listings:** **Approve** the listing just created. It is now visible to students.
3. **Reports:**
   - On the "QuickLets Ltd" scam report, choose **Suspend user**. That account can no longer log in.
   - On the other report, show **Flag listing** and **Dismiss**.
4. **⋮ → Content moderation:** remove a review with a reason.
5. **Stats:** user and listing counts, matches unlocked, **total revenue**, the bar chart of listings per city and the revenue pie chart.

**5. Firebase console (≈20s)**
- Open https://console.firebase.google.com/project/studentnest-b0b3a/firestore.
- Show the `users`, `rooms`, `payments`, `reports`, `conversations/…/messages` and `notifications` collections updating live.
- Show the Authentication tab with the demo accounts.

---

## User story → feature mapping

| ID | User story | Implemented in |
|---|---|---|
| US-S01 | As a student I can sign up / log in with email & password | `screens/auth/auth_screen.dart`, `services/auth_service.dart` |
| US-S02 | As a student I must verify my email before using the app | `screens/auth/verify_email_screen.dart`, `screens/common/root_gate.dart` |
| US-S03 | As a student I can create and edit my lifestyle profile | `screens/student/lifestyle_screen.dart` |
| US-S04 | As a student I control which details others see, and can delete my account | Privacy toggles in `lifestyle_screen.dart`; delete in `screens/common/account_widgets.dart` |
| US-S05 | As a student I can verify my student ID to get a Verified badge | `screens/common/verification_screen.dart`, `ProfileHeader` |
| US-S06 | As a student I can search rooms by city or campus | `screens/student/home_screen.dart` (search bar + city chips) |
| US-S07 | As a student I can filter by price, deposit, distance and room type | `home_screen.dart` → `_FilterSheet` |
| US-S08 | As a student I can view rooms on a map | `home_screen.dart` → `_RoomsMap` (OSM price pins) |
| US-S09 | As a student I can see full room details and scam warnings | `screens/common/room_details_screen.dart` |
| US-S10 | As a student I can save rooms for later | Heart in room details; `screens/student/saved_screen.dart` |
| US-S11 | As a student I can report a listing, user or conversation | `screens/common/report_screen.dart` |
| US-S12 | As a student I can pay $20 to unlock AI roommate matching | `screens/student/roommates_screen.dart` (`_Locked`), `widgets/payment_sheet.dart` |
| US-S13 | As a student I see roommates ranked by compatibility with a breakdown | `roommates_screen.dart`, `services/matching_service.dart`, `screens/common/user_profile_screen.dart` |
| US-S14 | As a student I can chat in real time with landlords and roommates | `screens/common/chat_screens.dart` |
| US-S15 | As a student I can review people I have connected with | `screens/common/reviews.dart` (chat required) |
| US-L01 | As a landlord I can verify my identity and ownership | `screens/common/verification_screen.dart` (landlord mode) |
| US-L02 | As a landlord I can create listings (2 free, then $10) | `screens/landlord/listing_form_screen.dart` |
| US-L03 | As a landlord I can edit, mark rented and delete listings | `screens/landlord/my_listings_screen.dart` |
| US-L04 | As a landlord I can boost a listing to Premium for $10 | `my_listings_screen.dart` → Boost to Premium |
| US-L05 | As a landlord I can answer student enquiries | `screens/landlord/landlord_shell.dart` (Enquiries tab) |
| US-L06 | As a landlord I can review tenants I have chatted with | Chat menu → Write a review (`reviews.dart`) |
| US-A01 | As an admin I can approve/reject identity verifications | `screens/admin/verifications_queue_screen.dart` |
| US-A02 | As an admin I can approve/reject new listings and flag suspicious ones | `screens/admin/listings_queue_screen.dart` |
| US-A03 | As an admin I can handle reports (dismiss, remove listing, suspend user) | `screens/admin/reports_queue_screen.dart` |
| US-A04 | As an admin I can moderate reviews | `screens/admin/moderation_screen.dart` |
| US-A05 | As an admin I can see platform statistics and revenue | `screens/admin/stats_screen.dart` (fl_chart) |

---

## Architecture

```
lib/
  main.dart                 Firebase init + Provider + MaterialApp
  firebase_options.dart     generated by FlutterFire CLI
  models/                   AppUser, Lifestyle, Room, Conversation, Review, Report, Payment…
  services/                 auth_service, firestore_service, matching_service,
                            payment_service (simulated), seed_service (demo data)
  providers/                SessionProvider (auth user + live profile)
  screens/auth|student|landlord|admin|common
  widgets/                  room card, payment sheet, maps, score ring, common UI
  theme/  utils/
test/matching_service_test.dart
firestore.rules
```

**Technical decisions**
- **Images:** no Firebase Storage. Images are compressed (600px wide, 60% quality) and stored as base64 in Firestore. Seed photos are bundled assets.
- **Queries:** only single-field `where` queries, so no composite indexes are needed. Filtering and sorting (premium first, price, distance) happen on the client.
- **Live updates:** Firestore streams drive chats, listings, queues and notifications.
- **Distance to campus:** computed with the **haversine** formula.
- **Seeder:** runs on a **secondary FirebaseApp**, so the signed-in user is never logged out.
- **Security rules:**
  - Users can edit only their own profile, and cannot change their role, suspension or approval status.
  - Landlords can write only their own rooms and cannot approve or flag them.
  - Only chat participants can read messages.
  - Admins can do everything.
