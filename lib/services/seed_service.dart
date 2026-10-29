import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../models/app_user.dart';
import '../utils/constants.dart';

/// Creates the demo accounts and demo data.
///
/// Auth accounts are created on a SECONDARY FirebaseApp ("seeder") so the
/// person currently using the app is never signed out. All seeded documents
/// use deterministic IDs, so reseeding simply resets them to a clean state.
class SeedService {
  static const _appName = 'seeder';
  static bool _running = false;

  static Future<bool> needsSeed() async {
    try {
      final snap =
          await FirebaseFirestore.instance.doc('meta/seed').get();
      return !snap.exists;
    } catch (e) {
      debugPrint('Seed check failed: $e');
      return false;
    }
  }

  static Future<void> seedIfNeeded() async {
    if (await needsSeed()) await run();
  }

  static Future<FirebaseApp> _seederApp() async {
    for (final a in Firebase.apps) {
      if (a.name == _appName) return a;
    }
    return Firebase.initializeApp(
        name: _appName, options: DefaultFirebaseOptions.currentPlatform);
  }

  static Future<String> _ensureAccount(FirebaseAuth auth, String email) async {
    try {
      final c = await auth.createUserWithEmailAndPassword(
          email: email, password: AppConstants.demoPassword);
      return c.user!.uid;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        final c = await auth.signInWithEmailAndPassword(
            email: email, password: AppConstants.demoPassword);
        return c.user!.uid;
      }
      rethrow;
    }
  }

  static Future<void> run({void Function(String)? onProgress}) async {
    if (_running) return;
    _running = true;
    try {
      onProgress?.call('Creating demo accounts…');
      final app = await _seederApp();
      final auth = FirebaseAuth.instanceFor(app: app);
      final db = FirebaseFirestore.instanceFor(app: app);

      final student = await _ensureAccount(auth, 'student@demo.com');
      final paid = await _ensureAccount(auth, 'paid@demo.com');
      final landlord = await _ensureAccount(auth, 'landlord@demo.com');
      final pending = await _ensureAccount(auth, 'pending@demo.com');
      // Admin last, so the seeder app stays signed in as admin for writes.
      final admin = await _ensureAccount(auth, 'admin@demo.com');

      final now = DateTime.now();
      Timestamp ago({int days = 0, int hours = 0, int minutes = 0}) =>
          Timestamp.fromDate(now.subtract(
              Duration(days: days, hours: hours, minutes: minutes)));

      // Admin doc first: security rules check this doc for admin rights.
      await db.collection('users').doc(admin).set(_user(
            name: 'StudentNest Admin',
            email: 'admin@demo.com',
            role: UserRole.admin,
            status: VerificationStatus.approved,
            createdAt: ago(days: 60),
          ));

      onProgress?.call('Adding demo users…');
      final batch = db.batch();
      final users = db.collection('users');

      batch.set(
          users.doc(student),
          _user(
            name: 'Aisha Khan',
            email: 'student@demo.com',
            role: UserRole.student,
            status: VerificationStatus.approved,
            createdAt: ago(days: 20),
            lifestyle: const Lifestyle(
              course: 'MSc Computer Science',
              university: 'University College London (UCL)',
              languages: ['English', 'Urdu', 'Hindi'],
              sleepSchedule: 'normal',
              cleanliness: 4,
              diet: 'halal',
              smoking: 'non-smoker',
              budget: 1200,
              city: 'London',
              bio: 'First-year MSc student from Lahore. I love cooking and quiet evenings.',
            ),
            saved: ['seed_room_02', 'seed_room_07'],
          ));
      batch.set(
          users.doc(paid),
          _user(
            name: 'Daniel Okafor',
            email: 'paid@demo.com',
            role: UserRole.student,
            status: VerificationStatus.approved,
            matching: true,
            createdAt: ago(days: 35),
            lifestyle: const Lifestyle(
              course: 'MSc Data Science',
              university: 'University of Manchester',
              languages: ['English', 'French'],
              sleepSchedule: 'early bird',
              cleanliness: 5,
              diet: 'no preference',
              smoking: 'non-smoker',
              budget: 800,
              city: 'Manchester',
              bio: 'Gym in the morning, library in the afternoon. Tidy and friendly.',
            ),
            saved: ['seed_room_04'],
          ));
      batch.set(
          users.doc(landlord),
          _user(
            name: 'James Whitfield',
            email: 'landlord@demo.com',
            role: UserRole.landlord,
            status: VerificationStatus.approved,
            freeListingsUsed: 2,
            createdAt: ago(days: 90),
          ));
      batch.set(
          users.doc(pending),
          _user(
            name: 'Priya Sharma',
            email: 'pending@demo.com',
            role: UserRole.student,
            status: VerificationStatus.pending,
            createdAt: ago(days: 2),
            lifestyle: const Lifestyle(
              course: 'MSc Data Science',
              university: 'University of Manchester',
              languages: ['English', 'Hindi', 'Bengali'],
              sleepSchedule: 'early bird',
              cleanliness: 4,
              diet: 'vegetarian',
              smoking: 'non-smoker',
              budget: 750,
              city: 'Manchester',
            ),
          ));
      batch.set(db.collection('verifications').doc(pending), {
        'userId': pending,
        'userName': 'Priya Sharma',
        'role': UserRole.student,
        'images': {
          'Student ID': 'assets/images/demo/student_id.png',
          'Selfie': 'assets/images/demo/selfie.png',
        },
        'status': VerificationStatus.pending,
        'rejectReason': '',
        'createdAt': ago(hours: 5),
      });

      // A second (suspicious) landlord – Firestore doc only.
      const shady = 'seed_landlord_01';
      batch.set(
          users.doc(shady),
          _user(
            name: 'QuickLets Ltd',
            email: 'quicklets@example.com',
            role: UserRole.landlord,
            status: VerificationStatus.none,
            createdAt: ago(days: 4),
          ));

      // Extra student profiles with varied lifestyles.
      final extra = _extraStudents();
      for (var i = 0; i < extra.length; i++) {
        final e = extra[i];
        batch.set(
            users.doc(_seedStudentId(i + 1)),
            _user(
              name: e.$1,
              email: '${e.$1.split(' ').first.toLowerCase()}@example.com',
              role: UserRole.student,
              status: i.isEven
                  ? VerificationStatus.approved
                  : VerificationStatus.none,
              createdAt: ago(days: 5 + i * 3),
              lifestyle: e.$2,
              privacy: i == 3
                  ? const PrivacySettings(showBudget: false, showCourse: false)
                  : const PrivacySettings(),
            ));
      }

      onProgress?.call('Adding rooms…');
      final rooms = _rooms(landlord, shady);
      for (var i = 0; i < rooms.length; i++) {
        final r = Map<String, dynamic>.from(rooms[i]);
        final ownerIsShady = r['landlordId'] == shady;
        r['landlordName'] = ownerIsShady ? 'QuickLets Ltd' : 'James Whitfield';
        r['currency'] = AppConstants.cities[r['city']]!.currency;
        r['createdAt'] = ago(days: 30 - i);
        r['rejectReason'] = '';
        r.putIfAbsent('status', () => 'approved');
        r.putIfAbsent('premium', () => false);
        r.putIfAbsent('flagged', () => false);
        r.putIfAbsent('flagReason', () => '');
        r['verified'] = r['status'] != 'pending' && !ownerIsShady;
        r['premiumUntil'] = r['premium'] == true
            ? Timestamp.fromDate(now.add(const Duration(days: 21)))
            : null;
        batch.set(db.collection('rooms').doc(_roomId(i + 1)), r);
      }
      await batch.commit();

      onProgress?.call('Adding chats, reviews and payments…');
      final b2 = db.batch();
      final convs = db.collection('conversations');
      String cid(String a, String b) => ([a, b]..sort()).join('_');

      void conversation({
        required String a,
        required String aName,
        required String aRole,
        required String b,
        required String bName,
        required String bRole,
        String roomId = '',
        String roomTitle = '',
        required List<(bool fromA, String text, int minutesAgo)> messages,
        int unreadForA = 0,
      }) {
        final id = cid(a, b);
        final last = messages.last;
        b2.set(convs.doc(id), {
          'participants': [a, b],
          'participantNames': {a: aName, b: bName},
          'participantRoles': {a: aRole, b: bRole},
          'roomId': roomId,
          'roomTitle': roomTitle,
          'lastMessage': last.$2,
          'lastSenderId': last.$1 ? a : b,
          'lastMessageAt': ago(minutes: last.$3),
          'unread': {a: unreadForA, b: 0},
        });
        for (var i = 0; i < messages.length; i++) {
          final m = messages[i];
          b2.set(convs.doc(id).collection('messages').doc('seed_msg_$i'), {
            'senderId': m.$1 ? a : b,
            'text': m.$2,
            'createdAt': ago(minutes: m.$3),
          });
        }
      }

      conversation(
        a: student,
        aName: 'Aisha Khan',
        aRole: UserRole.student,
        b: landlord,
        bName: 'James Whitfield',
        bRole: UserRole.landlord,
        roomId: _roomId(1),
        roomTitle: 'Bright ensuite near UCL, Bloomsbury',
        unreadForA: 1,
        messages: [
          (true, 'Hi James! Is the Bloomsbury ensuite still available from September?', 300),
          (false, 'Hi Aisha, yes it is. Would you like to book a video viewing?', 280),
          (true, 'That would be great. Does Thursday at 5pm work?', 270),
          (false, 'Thursday 5pm is perfect. I will send the video link here on StudentNest.', 60),
        ],
      );
      conversation(
        a: paid,
        aName: 'Daniel Okafor',
        aRole: UserRole.student,
        b: landlord,
        bName: 'James Whitfield',
        bRole: UserRole.landlord,
        roomId: _roomId(4),
        roomTitle: 'Modern ensuite in Fallowfield student house',
        messages: [
          (true, 'Hello, are bills included in the Fallowfield room?', 2000),
          (false, 'Yes, all bills including Wi-Fi are included.', 1990),
          (true, 'Brilliant, thank you! I will apply through the app.', 1980),
        ],
      );
      conversation(
        a: paid,
        aName: 'Daniel Okafor',
        aRole: UserRole.student,
        b: _seedStudentId(2),
        bName: 'Lucas Martin',
        bRole: UserRole.student,
        messages: [
          (false, 'Hey Daniel! We got a 91% match. Looking for a flat near Oxford Road?', 900),
          (true, 'Hi Lucas! Yes, ideally under £800 each. Early riser too?', 880),
          (false, 'Every day at 6:30 😄 Want to view the Fallowfield place together?', 870),
        ],
      );
      conversation(
        a: student,
        aName: 'Aisha Khan',
        aRole: UserRole.student,
        b: _seedStudentId(1),
        bName: 'Fatima Noor',
        bRole: UserRole.student,
        messages: [
          (false, 'Hi Aisha, I saw you are also at UCL. Are you looking for a flatmate?', 1500),
          (true, 'Hi Fatima! Yes, somewhere in Bloomsbury or Camden.', 1490),
        ],
      );

      // Reviews
      final reviews = db.collection('reviews');
      void review(String id, String authorId, String authorName,
          String targetId, String targetName, int rating, String text,
          int daysAgo) {
        b2.set(reviews.doc(id), {
          'authorId': authorId,
          'authorName': authorName,
          'targetId': targetId,
          'targetName': targetName,
          'rating': rating,
          'text': text,
          'removed': false,
          'removedReason': '',
          'createdAt': ago(days: daysAgo),
        });
      }

      review('seed_review_1', _seedStudentId(2), 'Lucas Martin', landlord,
          'James Whitfield', 5,
          'James was super responsive and the room matched the photos exactly.', 40);
      review('seed_review_2', _seedStudentId(5), 'Mei Lin', landlord,
          'James Whitfield', 4,
          'Great location and fair deposit. Repairs took a few days.', 25);
      review('seed_review_3', landlord, 'James Whitfield', paid,
          'Daniel Okafor', 5, 'Respectful, tidy and always paid on time.', 15);
      review('seed_review_4', paid, 'Daniel Okafor', _seedStudentId(2),
          'Lucas Martin', 4, 'Easy-going and clean. Would share again.', 10);
      review('seed_review_5', _seedStudentId(3), 'Omar Haddad', shady,
          'QuickLets Ltd', 1,
          'Asked me to pay the deposit by bank transfer before any viewing.', 3);

      // Open reports
      b2.set(db.collection('reports').doc('seed_report_1'), {
        'reporterId': _seedStudentId(3),
        'reporterName': 'Omar Haddad',
        'targetType': 'room',
        'targetId': _roomId(15),
        'targetName': 'Luxury studio steps from Washington Square',
        'reportedUserId': shady,
        'reason': 'Scam / asked for money outside app',
        'details':
            'The landlord asked me to wire \$900 via Western Union before I could see the room.',
        'status': 'open',
        'createdAt': ago(hours: 20),
      });
      b2.set(db.collection('reports').doc('seed_report_2'), {
        'reporterId': paid,
        'reporterName': 'Daniel Okafor',
        'targetType': 'user',
        'targetId': shady,
        'targetName': 'QuickLets Ltd',
        'reportedUserId': shady,
        'reason': 'Fake listing',
        'details':
            'Same photos appear on another website with a different address.',
        'status': 'open',
        'createdAt': ago(hours: 6),
      });

      // Payments (for the stats dashboard)
      final payments = <(String, double, String, String, int)>[
        (paid, 20, 'matching_unlock', 'succeeded', 30),
        (_seedStudentId(2), 20, 'matching_unlock', 'succeeded', 22),
        (_seedStudentId(4), 20, 'matching_unlock', 'succeeded', 12),
        (_seedStudentId(6), 20, 'matching_unlock', 'failed', 9),
        (landlord, 10, 'extra_listing', 'succeeded', 28),
        (landlord, 10, 'extra_listing', 'succeeded', 18),
        (landlord, 10, 'premium_boost', 'succeeded', 9),
        (landlord, 10, 'premium_boost', 'succeeded', 7),
      ];
      for (var i = 0; i < payments.length; i++) {
        final p = payments[i];
        b2.set(db.collection('payments').doc('seed_payment_$i'), {
          'userId': p.$1,
          'amount': p.$2,
          'type': p.$3,
          'status': p.$4,
          'cardLast4': p.$4 == 'failed' ? '0002' : '4242',
          'createdAt': ago(days: p.$5),
        });
      }

      // Welcome notifications
      b2.set(db.collection('notifications').doc('seed_note_student'), {
        'userId': student,
        'title': 'Welcome to StudentNest 👋',
        'body':
            'Your student ID is verified. Complete your lifestyle profile to get better roommate matches.',
        'type': 'verification',
        'read': false,
        'createdAt': ago(days: 1),
      });
      b2.set(db.collection('notifications').doc('seed_note_landlord'), {
        'userId': landlord,
        'title': 'Listing approved ✓',
        'body': 'Your listing "Furnished room in the Annex" is now live.',
        'type': 'listing',
        'read': false,
        'createdAt': ago(days: 2),
      });

      b2.set(db.doc('meta/seed'), {
        'seededAt': FieldValue.serverTimestamp(),
        'version': 1,
      });
      await b2.commit();
      await auth.signOut();
      onProgress?.call('Demo data ready');
    } finally {
      _running = false;
    }
  }

  static String _roomId(int n) => 'seed_room_${n.toString().padLeft(2, '0')}';
  static String _seedStudentId(int n) =>
      'seed_student_${n.toString().padLeft(2, '0')}';

  static Map<String, dynamic> _user({
    required String name,
    required String email,
    required String role,
    required String status,
    required Timestamp createdAt,
    bool matching = false,
    int freeListingsUsed = 0,
    Lifestyle lifestyle = const Lifestyle(),
    PrivacySettings privacy = const PrivacySettings(),
    List<String> saved = const [],
  }) =>
      {
        'name': name,
        'email': email,
        'role': role,
        'photo': '',
        'verificationStatus': status,
        'suspended': false,
        'isDemo': true,
        'matchingUnlocked': matching,
        'freeListingsUsed': freeListingsUsed,
        'lifestyle': lifestyle.toMap(),
        'privacy': privacy.toMap(),
        'savedRooms': saved,
        'createdAt': createdAt,
      };

  static List<(String, Lifestyle)> _extraStudents() => const [
        ('Fatima Noor', Lifestyle(course: 'MSc Computer Science', university: 'University College London (UCL)', languages: ['English', 'Urdu', 'Arabic'], sleepSchedule: 'normal', cleanliness: 4, diet: 'halal', smoking: 'non-smoker', budget: 1150, city: 'London', bio: 'Coffee, code and long walks in Regent’s Park.')),
        ('Lucas Martin', Lifestyle(course: 'MSc Data Science', university: 'University of Manchester', languages: ['English', 'French', 'Spanish'], sleepSchedule: 'early bird', cleanliness: 5, diet: 'no preference', smoking: 'non-smoker', budget: 780, city: 'Manchester', bio: 'Runner and early riser. Clean kitchen = happy life.')),
        ('Omar Haddad', Lifestyle(course: 'MEng Civil Engineering', university: 'Imperial College London', languages: ['Arabic', 'English', 'French'], sleepSchedule: 'night owl', cleanliness: 2, diet: 'halal', smoking: 'outside only', budget: 950, city: 'London')),
        ('Sofia García', Lifestyle(course: 'MA International Relations', university: "King's College London", languages: ['Spanish', 'English', 'Portuguese'], sleepSchedule: 'normal', cleanliness: 4, diet: 'vegetarian', smoking: 'non-smoker', budget: 1100, city: 'London')),
        ('Mei Lin', Lifestyle(course: 'MBA', university: 'University of Toronto', languages: ['Mandarin', 'English'], sleepSchedule: 'early bird', cleanliness: 5, diet: 'no preference', smoking: 'non-smoker', budget: 1000, city: 'Toronto', bio: 'Quiet, organised, love board games.')),
        ('Arjun Patel', Lifestyle(course: 'MSc Computer Science', university: 'University College London (UCL)', languages: ['English', 'Hindi', 'Gujarati'], sleepSchedule: 'night owl', cleanliness: 3, diet: 'vegetarian', smoking: 'non-smoker', budget: 1250, city: 'London')),
        ('Jake Thompson', Lifestyle(course: 'BA Film Studies', university: 'New York University (NYU)', languages: ['English'], sleepSchedule: 'night owl', cleanliness: 1, diet: 'other', smoking: 'smoker', budget: 2200, city: 'New York', bio: 'Night owl, musician, loves hosting friends.')),
        ('Hannah Schmidt', Lifestyle(course: 'MSc Mechanical Engineering', university: 'TU Berlin', languages: ['German', 'English'], sleepSchedule: 'early bird', cleanliness: 5, diet: 'vegan', smoking: 'non-smoker', budget: 650, city: 'Berlin')),
        ('Kwame Mensah', Lifestyle(course: 'MSc Data Science', university: 'University of Manchester', languages: ['English', 'French', 'Swahili'], sleepSchedule: 'normal', cleanliness: 4, diet: 'no preference', smoking: 'non-smoker', budget: 700, city: 'Manchester')),
        ('Yuki Tanaka', Lifestyle(course: 'MSc Marine Science', university: 'University of Sydney', languages: ['Japanese', 'English'], sleepSchedule: 'normal', cleanliness: 4, diet: 'no preference', smoking: 'non-smoker', budget: 1400, city: 'Sydney')),
        ('Ji-woo Park', Lifestyle(course: 'MSc Finance', university: 'University of Toronto', languages: ['Korean', 'English'], sleepSchedule: 'night owl', cleanliness: 3, diet: 'no preference', smoking: 'outside only', budget: 1300, city: 'Toronto')),
        ('Carlos Mendes', Lifestyle(course: 'MSc Economics', university: 'University of Manchester', languages: ['Portuguese', 'Spanish', 'English'], sleepSchedule: 'night owl', cleanliness: 2, diet: 'other', smoking: 'smoker', budget: 1100, city: 'Manchester')),
      ];

  static String _p(int n) => 'assets/images/rooms/room$n.jpg';

  static List<Map<String, dynamic>> _rooms(String landlord, String shady) => [
        {
          'title': 'Bright ensuite near UCL, Bloomsbury',
          'description': 'Light-filled ensuite in a quiet Georgian townhouse, 8 minutes walk to UCL main campus. Fully furnished with double bed, desk and wardrobe. Shared modern kitchen with three other postgraduate students. All bills and fast Wi-Fi included.',
          'city': 'London', 'address': '24 Tavistock Place, London WC1H 9RE',
          'lat': 51.5258, 'lng': -0.1260,
          'campusName': 'University College London (UCL)', 'campusLat': 51.5246, 'campusLng': -0.1340,
          'rent': 1150, 'deposit': 1150, 'roomType': 'ensuite',
          'rules': ['No smoking', 'Quiet hours after 11pm', 'Bills included'],
          'photos': [_p(1), _p(3), _p(6)], 'landlordId': landlord, 'premium': true,
        },
        {
          'title': 'Cosy single room in Camden house share',
          'description': 'Single room in a friendly 4-bed house share, 2 minutes from Camden Road station. Garden, washing machine and weekly cleaner for common areas.',
          'city': 'London', 'address': '38 Camden Road, London NW1 9DR',
          'lat': 51.5413, 'lng': -0.1385,
          'campusName': 'University College London (UCL)', 'campusLat': 51.5246, 'campusLng': -0.1340,
          'rent': 850, 'deposit': 900, 'roomType': 'single',
          'rules': ['No pets', 'Cleaning rota', 'Guests on weekends only'],
          'photos': [_p(2), _p(5)], 'landlordId': landlord,
        },
        {
          'title': 'Studio flat near King’s College – available now',
          'description': 'Large studio in central London for an unbelievable price. Keys can be posted to you once the deposit is received. No viewings needed.',
          'city': 'London', 'address': '15 Stamford Street, London SE1 9NT',
          'lat': 51.5068, 'lng': -0.1095,
          'campusName': "King's College London", 'campusLat': 51.5115, 'campusLng': -0.1160,
          'rent': 550, 'deposit': 1500, 'roomType': 'studio',
          'rules': ['Deposit before viewing'],
          'photos': [_p(9)], 'landlordId': shady, 'flagged': true,
          'flagReason': 'Rent far below market rate and the landlord asks for a deposit before any viewing.',
        },
        {
          'title': 'Modern ensuite in Fallowfield student house',
          'description': 'Newly refurbished ensuite in the heart of Fallowfield, on the main bus route to the University of Manchester (10 minutes). Shared lounge with smart TV and a large kitchen.',
          'city': 'Manchester', 'address': '112 Wilmslow Road, Manchester M14 6AN',
          'lat': 53.4469, 'lng': -2.2210,
          'campusName': 'University of Manchester', 'campusLat': 53.4668, 'campusLng': -2.2339,
          'rent': 620, 'deposit': 400, 'roomType': 'ensuite',
          'rules': ['No smoking', 'Bills included', 'No parties'],
          'photos': [_p(4), _p(8)], 'landlordId': landlord,
        },
        {
          'title': 'Double room near Oxford Road campus',
          'description': 'Comfortable double room a 5 minute walk from the Oxford Road campus and the Royal Infirmary.',
          'city': 'Manchester', 'address': '8 Hathersage Road, Manchester M13 0FD',
          'lat': 53.4613, 'lng': -2.2240,
          'campusName': 'University of Manchester', 'campusLat': 53.4668, 'campusLng': -2.2339,
          'rent': 540, 'deposit': 350, 'roomType': 'single',
          'rules': ['No pets'], 'photos': [_p(7)], 'landlordId': landlord,
          'status': 'rented',
        },
        {
          'title': 'Spacious studio in Hulme',
          'description': 'Self-contained studio with kitchenette and private bathroom, close to Manchester Metropolitan University and the city centre.',
          'city': 'Manchester', 'address': '25 Stretford Road, Manchester M15 5JH',
          'lat': 53.4660, 'lng': -2.2500,
          'campusName': 'Manchester Metropolitan University', 'campusLat': 53.4703, 'campusLng': -2.2397,
          'rent': 780, 'deposit': 780, 'roomType': 'studio',
          'rules': ['No smoking', 'Professional cleaning at move-out'],
          'photos': [_p(10), _p(12)], 'landlordId': landlord, 'status': 'pending',
        },
        {
          'title': 'Furnished room in the Annex',
          'description': 'Charming furnished room in a Victorian home in the Annex, a 10 minute walk to the University of Toronto St. George campus. Close to Spadina subway.',
          'city': 'Toronto', 'address': '185 Brunswick Ave, Toronto, ON M5S 2M4',
          'lat': 43.6640, 'lng': -79.4060,
          'campusName': 'University of Toronto', 'campusLat': 43.6629, 'campusLng': -79.3957,
          'rent': 1250, 'deposit': 1250, 'roomType': 'single',
          'rules': ['No smoking', 'Shoes off indoors', 'Quiet hours after 10pm'],
          'photos': [_p(11), _p(2)], 'landlordId': landlord, 'premium': true,
        },
        {
          'title': 'Shared room near Kensington Market',
          'description': 'Budget-friendly shared twin room in a lively student apartment next to Kensington Market and Chinatown.',
          'city': 'Toronto', 'address': '62 Baldwin St, Toronto, ON M5T 1L4',
          'lat': 43.6556, 'lng': -79.3970,
          'campusName': 'University of Toronto', 'campusLat': 43.6629, 'campusLng': -79.3957,
          'rent': 850, 'deposit': 425, 'roomType': 'shared',
          'rules': ['Cleaning rota', 'No overnight guests'],
          'photos': [_p(5), _p(1)], 'landlordId': landlord,
        },
        {
          'title': 'Sunny room in Newtown terrace',
          'description': 'Bright bedroom in a classic terrace on King Street, Newtown, surrounded by cafes. 15 minute walk to the University of Sydney.',
          'city': 'Sydney', 'address': '214 King St, Newtown NSW 2042',
          'lat': -33.8970, 'lng': 151.1790,
          'campusName': 'University of Sydney', 'campusLat': -33.8886, 'campusLng': 151.1873,
          'rent': 1300, 'deposit': 1200, 'roomType': 'single',
          'rules': ['No smoking', 'Pets negotiable'],
          'photos': [_p(6), _p(3)], 'landlordId': landlord,
        },
        {
          'title': 'Ensuite in Glebe student apartment',
          'description': 'Private ensuite with balcony in a secure student apartment in Glebe. Gym and study rooms in the building.',
          'city': 'Sydney', 'address': '45 Glebe Point Rd, Glebe NSW 2037',
          'lat': -33.8795, 'lng': 151.1860,
          'campusName': 'University of Sydney', 'campusLat': -33.8886, 'campusLng': 151.1873,
          'rent': 1650, 'deposit': 1650, 'roomType': 'ensuite',
          'rules': ['No parties', 'Bills included'],
          'photos': [_p(12), _p(9)], 'landlordId': landlord,
        },
        {
          'title': 'WG room in Charlottenburg',
          'description': 'Room in a friendly 3-person WG (flat share) in Charlottenburg, 10 minutes by bike to TU Berlin. Anmeldung (address registration) possible.',
          'city': 'Berlin', 'address': 'Kantstraße 52, 10627 Berlin',
          'lat': 52.5058, 'lng': 13.3050,
          'campusName': 'TU Berlin', 'campusLat': 52.5125, 'campusLng': 13.3269,
          'rent': 590, 'deposit': 1180, 'roomType': 'shared',
          'rules': ['Anmeldung possible', 'Recycling rules', 'No smoking'],
          'photos': [_p(8), _p(4)], 'landlordId': landlord,
        },
        {
          'title': 'Studio apartment near Ernst-Reuter-Platz',
          'description': 'Compact furnished studio with fitted kitchen, 3 minutes walk to TU Berlin main building.',
          'city': 'Berlin', 'address': 'Marchstraße 6, 10587 Berlin',
          'lat': 52.5155, 'lng': 13.3215,
          'campusName': 'TU Berlin', 'campusLat': 52.5125, 'campusLng': 13.3269,
          'rent': 890, 'deposit': 2670, 'roomType': 'studio',
          'rules': ['Anmeldung possible', 'Quiet hours 10pm-7am'],
          'photos': [_p(3), _p(10)], 'landlordId': landlord,
        },
        {
          'title': 'Room in Greenwich Village walk-up',
          'description': 'Private bedroom in a classic 3-bed walk-up, 2 blocks from NYU. Shared bathroom and kitchen with two graduate students.',
          'city': 'New York', 'address': '75 Bleecker St, New York, NY 10012',
          'lat': 40.7270, 'lng': -73.9960,
          'campusName': 'New York University (NYU)', 'campusLat': 40.7295, 'campusLng': -73.9965,
          'rent': 1850, 'deposit': 1850, 'roomType': 'single',
          'rules': ['No smoking', 'Guests with notice'],
          'photos': [_p(7), _p(11)], 'landlordId': landlord,
        },
        {
          'title': 'Shared apartment in East Village',
          'description': 'Shared room in a renovated East Village apartment, close to the L and 6 trains. Great for students on a budget.',
          'city': 'New York', 'address': '220 E 10th St, New York, NY 10003',
          'lat': 40.7290, 'lng': -73.9850,
          'campusName': 'New York University (NYU)', 'campusLat': 40.7295, 'campusLng': -73.9965,
          'rent': 1400, 'deposit': 700, 'roomType': 'shared',
          'rules': ['Cleaning rota', 'No pets'],
          'photos': [_p(1), _p(12)], 'landlordId': landlord,
        },
        {
          'title': 'Luxury studio steps from Washington Square',
          'description': 'Luxury doorman studio for only \$900 a month! Landlord is currently abroad. Pay the deposit by wire transfer and keys will be couriered to you.',
          'city': 'New York', 'address': '1 Washington Square N, New York, NY 10003',
          'lat': 40.7318, 'lng': -73.9973,
          'campusName': 'New York University (NYU)', 'campusLat': 40.7295, 'campusLng': -73.9965,
          'rent': 900, 'deposit': 2700, 'roomType': 'studio',
          'rules': ['Wire transfer only'],
          'photos': [_p(9), _p(6)], 'landlordId': shady, 'flagged': true,
          'flagReason': 'Photos appear on other websites and the landlord requests payment by wire transfer.',
        },
      ];
}
