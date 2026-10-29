import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/room.dart';
import '../models/social.dart';

/// All Firestore reads/writes. Queries use single-field filters only, and
/// sorting/filtering is done on the client so no composite indexes are needed.
class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get users => db.collection('users');
  CollectionReference<Map<String, dynamic>> get rooms => db.collection('rooms');
  CollectionReference<Map<String, dynamic>> get conversations =>
      db.collection('conversations');
  CollectionReference<Map<String, dynamic>> get reviews =>
      db.collection('reviews');
  CollectionReference<Map<String, dynamic>> get reports =>
      db.collection('reports');
  CollectionReference<Map<String, dynamic>> get payments =>
      db.collection('payments');
  CollectionReference<Map<String, dynamic>> get notifications =>
      db.collection('notifications');
  CollectionReference<Map<String, dynamic>> get verifications =>
      db.collection('verifications');

  // ---------------------------------------------------------------- users

  Stream<AppUser?> userStream(String uid) => users.doc(uid).snapshots().map(
      (s) => s.exists ? AppUser.fromMap(s.id, s.data()) : null);

  Future<AppUser?> getUser(String uid) async {
    try {
      final s = await users.doc(uid).get();
      return s.exists ? AppUser.fromMap(s.id, s.data()) : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) =>
      users.doc(uid).update(data);

  Future<void> saveLifestyle(
      String uid, Lifestyle lifestyle, PrivacySettings privacy) {
    return users.doc(uid).update({
      'lifestyle': lifestyle.toMap(),
      'privacy': privacy.toMap(),
    });
  }

  Future<void> setSaved(String uid, String roomId, bool saved) {
    return users.doc(uid).update({
      'savedRooms': saved
          ? FieldValue.arrayUnion([roomId])
          : FieldValue.arrayRemove([roomId]),
    });
  }

  Stream<List<AppUser>> studentsStream() => users
      .where('role', isEqualTo: UserRole.student)
      .snapshots()
      .map((q) => q.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList());

  /// Removes everything owned by the user. The Auth user is deleted separately.
  Future<void> deleteUserData(AppUser user) async {
    if (user.isLandlord) {
      final owned = await rooms.where('landlordId', isEqualTo: user.uid).get();
      for (final d in owned.docs) {
        await d.reference.delete();
      }
    }
    try {
      await verifications.doc(user.uid).delete();
    } catch (_) {}
    try {
      final notes =
          await notifications.where('userId', isEqualTo: user.uid).get();
      for (final d in notes.docs) {
        await d.reference.delete();
      }
    } catch (_) {}
    await users.doc(user.uid).delete();
  }

  // ---------------------------------------------------------------- rooms

  List<Room> _rooms(QuerySnapshot<Map<String, dynamic>> q) =>
      q.docs.map((d) => Room.fromMap(d.id, d.data())).toList();

  Stream<List<Room>> approvedRoomsStream() => rooms
      .where('status', isEqualTo: RoomStatus.approved)
      .snapshots()
      .map(_rooms);

  Stream<List<Room>> landlordRoomsStream(String uid) => rooms
      .where('landlordId', isEqualTo: uid)
      .snapshots()
      .map((q) => _rooms(q)
        ..sort((a, b) => (b.createdAt ?? DateTime(2000))
            .compareTo(a.createdAt ?? DateTime(2000))));

  Stream<List<Room>> pendingRoomsStream() => rooms
      .where('status', isEqualTo: RoomStatus.pending)
      .snapshots()
      .map(_rooms);

  Stream<List<Room>> allRoomsStream() => rooms.snapshots().map(_rooms);

  Stream<Room?> roomStream(String id) => rooms.doc(id).snapshots().map(
      (s) => s.exists ? Room.fromMap(s.id, s.data()) : null);

  Future<Room?> getRoom(String id) async {
    try {
      final s = await rooms.doc(id).get();
      return s.exists ? Room.fromMap(s.id, s.data()) : null;
    } catch (_) {
      return null;
    }
  }

  Future<List<Room>> getRoomsByIds(List<String> ids) async {
    final result = await Future.wait(ids.map(getRoom));
    return result.whereType<Room>().toList();
  }

  Future<String> createRoom(Map<String, dynamic> data) async {
    final ref = await rooms.add({
      ...data,
      'status': RoomStatus.pending,
      'verified': false,
      'premium': false,
      'premiumUntil': null,
      'flagged': false,
      'flagReason': '',
      'rejectReason': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<void> updateRoom(String id, Map<String, dynamic> data) =>
      rooms.doc(id).update(data);

  Future<void> deleteRoom(String id) => rooms.doc(id).delete();

  // ---------------------------------------------------------- conversations

  static String conversationId(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join('_');
  }

  /// Opens (or creates) the 1:1 conversation between [me] and the other user.
  Future<String> openConversation({
    required AppUser me,
    required String otherId,
    required String otherName,
    required String otherRole,
    String roomId = '',
    String roomTitle = '',
  }) async {
    final id = conversationId(me.uid, otherId);
    final ref = conversations.doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'participants': [me.uid, otherId],
        'participantNames': {me.uid: me.name, otherId: otherName},
        'participantRoles': {me.uid: me.role, otherId: otherRole},
        'roomId': roomId,
        'roomTitle': roomTitle,
        'lastMessage': '',
        'lastSenderId': '',
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unread': {me.uid: 0, otherId: 0},
      });
    } else if (roomId.isNotEmpty) {
      await ref.update({'roomId': roomId, 'roomTitle': roomTitle});
    }
    return id;
  }

  Stream<List<Conversation>> conversationsStream(String uid) => conversations
      .where('participants', arrayContains: uid)
      .snapshots()
      .map((q) => q.docs
          .map((d) => Conversation.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => (b.lastMessageAt ?? DateTime.now())
            .compareTo(a.lastMessageAt ?? DateTime.now())));

  Stream<Conversation?> conversationStream(String id) => conversations
      .doc(id)
      .snapshots()
      .map((s) => s.exists ? Conversation.fromMap(s.id, s.data()) : null);

  Stream<List<ChatMessage>> messagesStream(String conversationId) =>
      conversations
          .doc(conversationId)
          .collection('messages')
          .orderBy('createdAt')
          .snapshots()
          .map((q) => q.docs
              .map((d) => ChatMessage.fromMap(d.id, d.data()))
              .toList());

  Future<void> sendMessage({
    required Conversation conversation,
    required AppUser me,
    required String text,
  }) async {
    final otherId = conversation.otherId(me.uid);
    final ref = conversations.doc(conversation.id);
    final batch = db.batch();
    batch.set(ref.collection('messages').doc(), {
      'senderId': me.uid,
      'text': text,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(ref, {
      'lastMessage': text,
      'lastSenderId': me.uid,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unread.$otherId': FieldValue.increment(1),
    });
    batch.set(notifications.doc(), {
      'userId': otherId,
      'title': 'New message from ${me.name}',
      'body': text.length > 80 ? '${text.substring(0, 80)}…' : text,
      'type': 'message',
      'refId': conversation.id,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> markConversationRead(String conversationId, String uid) async {
    try {
      await conversations.doc(conversationId).update({'unread.$uid': 0});
    } catch (_) {}
  }

  /// Reviews are only allowed between users who have chatted.
  Future<bool> haveConversation(String a, String b) async {
    try {
      final s = await conversations.doc(conversationId(a, b)).get();
      return s.exists;
    } catch (_) {
      return false;
    }
  }

  // --------------------------------------------------------------- reviews

  Stream<List<Review>> reviewsForStream(String targetId) => reviews
      .where('targetId', isEqualTo: targetId)
      .snapshots()
      .map((q) => q.docs
          .map((d) => Review.fromMap(d.id, d.data()))
          .where((r) => !r.removed)
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.now())
            .compareTo(a.createdAt ?? DateTime.now())));

  Stream<List<Review>> recentReviewsStream() => reviews
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map((q) => q.docs.map((d) => Review.fromMap(d.id, d.data())).toList());

  Future<void> addReview({
    required AppUser author,
    required String targetId,
    required String targetName,
    required int rating,
    required String text,
  }) async {
    await reviews.add({
      'authorId': author.uid,
      'authorName': author.name,
      'targetId': targetId,
      'targetName': targetName,
      'rating': rating,
      'text': text,
      'removed': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await notify(targetId, 'New review', '${author.name} rated you $rating★',
        'review');
  }

  Future<void> removeReview(Review r, String reason) async {
    await reviews.doc(r.id).update({'removed': true, 'removedReason': reason});
    await notify(r.authorId, 'Review removed',
        'Your review of ${r.targetName} was removed: $reason', 'moderation');
  }

  // --------------------------------------------------------------- reports

  Future<void> createReport({
    required AppUser reporter,
    required String targetType,
    required String targetId,
    required String targetName,
    required String reportedUserId,
    required String reason,
    required String details,
  }) {
    return reports.add({
      'reporterId': reporter.uid,
      'reporterName': reporter.name,
      'targetType': targetType,
      'targetId': targetId,
      'targetName': targetName,
      'reportedUserId': reportedUserId,
      'reason': reason,
      'details': details,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<Report>> openReportsStream() => reports
      .where('status', isEqualTo: 'open')
      .snapshots()
      .map((q) => q.docs.map((d) => Report.fromMap(d.id, d.data())).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.now())
            .compareTo(a.createdAt ?? DateTime.now())));

  Future<void> resolveReport(Report r, String status, String outcome) async {
    await reports.doc(r.id).update({
      'status': status,
      'resolvedAt': FieldValue.serverTimestamp(),
    });
    await notify(r.reporterId, 'Report update',
        'Your report about "${r.targetName}": $outcome', 'report');
  }

  // --------------------------------------------------------- notifications

  Future<void> notify(String userId, String title, String body, String type) {
    return notifications.add({
      'userId': userId,
      'title': title,
      'body': body,
      'type': type,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<AppNotification>> notificationsStream(String uid) => notifications
      .where('userId', isEqualTo: uid)
      .snapshots()
      .map((q) => q.docs
          .map((d) => AppNotification.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.now())
            .compareTo(a.createdAt ?? DateTime.now())));

  Future<void> markNotificationRead(String id) =>
      notifications.doc(id).update({'read': true});

  Future<void> markAllNotificationsRead(List<AppNotification> list) async {
    final batch = db.batch();
    for (final n in list.where((n) => !n.read)) {
      batch.update(notifications.doc(n.id), {'read': true});
    }
    await batch.commit();
  }

  // --------------------------------------------------------- verifications

  Future<void> submitVerification(
      AppUser user, Map<String, String> images) async {
    await verifications.doc(user.uid).set({
      'userId': user.uid,
      'userName': user.name,
      'role': user.role,
      'images': images,
      'status': VerificationStatus.pending,
      'rejectReason': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await users
        .doc(user.uid)
        .update({'verificationStatus': VerificationStatus.pending});
  }

  Stream<Verification?> verificationStream(String uid) => verifications
      .doc(uid)
      .snapshots()
      .map((s) => s.exists ? Verification.fromMap(s.id, s.data()) : null);

  Stream<List<Verification>> pendingVerificationsStream() => verifications
      .where('status', isEqualTo: VerificationStatus.pending)
      .snapshots()
      .map((q) =>
          q.docs.map((d) => Verification.fromMap(d.id, d.data())).toList());

  Future<void> decideVerification(Verification v, bool approve,
      [String reason = '']) async {
    final status =
        approve ? VerificationStatus.approved : VerificationStatus.rejected;
    final batch = db.batch();
    batch.update(verifications.doc(v.id),
        {'status': status, 'rejectReason': reason});
    batch.update(users.doc(v.userId), {'verificationStatus': status});
    await batch.commit();
    await notify(
      v.userId,
      approve ? 'Verification approved ✓' : 'Verification rejected',
      approve
          ? 'Your identity is verified. A Verified badge now shows on your profile.'
          : 'Your verification was rejected${reason.isEmpty ? '' : ': $reason'}. Please upload clearer documents.',
      'verification',
    );
  }

  // ------------------------------------------------------------- payments

  Stream<List<Payment>> paymentsStream() => payments
      .snapshots()
      .map((q) => q.docs.map((d) => Payment.fromMap(d.id, d.data())).toList());

  Stream<List<AppUser>> allUsersStream() => users
      .snapshots()
      .map((q) => q.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList());
}
