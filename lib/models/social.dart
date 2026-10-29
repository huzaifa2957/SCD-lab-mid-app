import 'model_utils.dart';

class Conversation {
  final String id;
  final List<String> participants;
  final Map<String, String> participantNames;
  final Map<String, String> participantRoles;
  final String roomId;
  final String roomTitle;
  final String lastMessage;
  final String lastSenderId;
  final DateTime? lastMessageAt;
  final Map<String, int> unread;

  const Conversation({
    required this.id,
    this.participants = const [],
    this.participantNames = const {},
    this.participantRoles = const {},
    this.roomId = '',
    this.roomTitle = '',
    this.lastMessage = '',
    this.lastSenderId = '',
    this.lastMessageAt,
    this.unread = const {},
  });

  String otherId(String me) =>
      participants.firstWhere((p) => p != me, orElse: () => '');
  String otherName(String me) => participantNames[otherId(me)] ?? 'User';
  String otherRole(String me) => participantRoles[otherId(me)] ?? '';
  int unreadFor(String me) => unread[me] ?? 0;

  factory Conversation.fromMap(String id, Map<String, dynamic>? data) {
    final m = data ?? const {};
    return Conversation(
      id: id,
      participants: toStrList(m['participants']),
      participantNames: toMap(m['participantNames'])
          .map((k, v) => MapEntry(k, v.toString())),
      participantRoles: toMap(m['participantRoles'])
          .map((k, v) => MapEntry(k, v.toString())),
      roomId: toStr(m['roomId']),
      roomTitle: toStr(m['roomTitle']),
      lastMessage: toStr(m['lastMessage']),
      lastSenderId: toStr(m['lastSenderId']),
      lastMessageAt: toDate(m['lastMessageAt']),
      unread: toMap(m['unread']).map((k, v) => MapEntry(k, toInt(v))),
    );
  }
}

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime? createdAt;

  const ChatMessage({
    required this.id,
    this.senderId = '',
    this.text = '',
    this.createdAt,
  });

  factory ChatMessage.fromMap(String id, Map<String, dynamic>? data) {
    final m = data ?? const {};
    return ChatMessage(
      id: id,
      senderId: toStr(m['senderId']),
      text: toStr(m['text']),
      createdAt: toDate(m['createdAt']),
    );
  }
}

class Review {
  final String id;
  final String authorId;
  final String authorName;
  final String targetId;
  final String targetName;
  final int rating;
  final String text;
  final bool removed;
  final String removedReason;
  final DateTime? createdAt;

  const Review({
    required this.id,
    this.authorId = '',
    this.authorName = '',
    this.targetId = '',
    this.targetName = '',
    this.rating = 0,
    this.text = '',
    this.removed = false,
    this.removedReason = '',
    this.createdAt,
  });

  factory Review.fromMap(String id, Map<String, dynamic>? data) {
    final m = data ?? const {};
    return Review(
      id: id,
      authorId: toStr(m['authorId']),
      authorName: toStr(m['authorName'], 'User'),
      targetId: toStr(m['targetId']),
      targetName: toStr(m['targetName']),
      rating: toInt(m['rating']).clamp(0, 5),
      text: toStr(m['text']),
      removed: toBool(m['removed']),
      removedReason: toStr(m['removedReason']),
      createdAt: toDate(m['createdAt']),
    );
  }
}

class Report {
  final String id;
  final String reporterId;
  final String reporterName;
  final String targetType; // room | user | conversation
  final String targetId;
  final String targetName;
  final String reportedUserId;
  final String reason;
  final String details;
  final String status; // open | dismissed | removed | suspended | flagged
  final DateTime? createdAt;

  const Report({
    required this.id,
    this.reporterId = '',
    this.reporterName = '',
    this.targetType = 'room',
    this.targetId = '',
    this.targetName = '',
    this.reportedUserId = '',
    this.reason = '',
    this.details = '',
    this.status = 'open',
    this.createdAt,
  });

  factory Report.fromMap(String id, Map<String, dynamic>? data) {
    final m = data ?? const {};
    return Report(
      id: id,
      reporterId: toStr(m['reporterId']),
      reporterName: toStr(m['reporterName'], 'User'),
      targetType: toStr(m['targetType'], 'room'),
      targetId: toStr(m['targetId']),
      targetName: toStr(m['targetName']),
      reportedUserId: toStr(m['reportedUserId']),
      reason: toStr(m['reason']),
      details: toStr(m['details']),
      status: toStr(m['status'], 'open'),
      createdAt: toDate(m['createdAt']),
    );
  }
}

class Payment {
  final String id;
  final String userId;
  final double amount;
  final String type; // matching_unlock | extra_listing | premium_boost
  final String status; // succeeded | failed
  final DateTime? createdAt;

  const Payment({
    required this.id,
    this.userId = '',
    this.amount = 0,
    this.type = '',
    this.status = '',
    this.createdAt,
  });

  factory Payment.fromMap(String id, Map<String, dynamic>? data) {
    final m = data ?? const {};
    return Payment(
      id: id,
      userId: toStr(m['userId']),
      amount: toDouble(m['amount']),
      type: toStr(m['type']),
      status: toStr(m['status']),
      createdAt: toDate(m['createdAt']),
    );
  }
}

class AppNotification {
  final String id;
  final String userId;
  final String title;
  final String body;
  final String type;
  final bool read;
  final DateTime? createdAt;

  const AppNotification({
    required this.id,
    this.userId = '',
    this.title = '',
    this.body = '',
    this.type = '',
    this.read = false,
    this.createdAt,
  });

  factory AppNotification.fromMap(String id, Map<String, dynamic>? data) {
    final m = data ?? const {};
    return AppNotification(
      id: id,
      userId: toStr(m['userId']),
      title: toStr(m['title']),
      body: toStr(m['body']),
      type: toStr(m['type']),
      read: toBool(m['read']),
      createdAt: toDate(m['createdAt']),
    );
  }
}

class Verification {
  final String id; // same as userId
  final String userId;
  final String userName;
  final String role;
  final Map<String, String> images; // label -> base64 or asset path
  final String status;
  final String rejectReason;
  final DateTime? createdAt;

  const Verification({
    required this.id,
    this.userId = '',
    this.userName = '',
    this.role = '',
    this.images = const {},
    this.status = 'pending',
    this.rejectReason = '',
    this.createdAt,
  });

  factory Verification.fromMap(String id, Map<String, dynamic>? data) {
    final m = data ?? const {};
    return Verification(
      id: id,
      userId: toStr(m['userId'], id),
      userName: toStr(m['userName'], 'User'),
      role: toStr(m['role']),
      images: toMap(m['images']).map((k, v) => MapEntry(k, v.toString())),
      status: toStr(m['status'], 'pending'),
      rejectReason: toStr(m['rejectReason']),
      createdAt: toDate(m['createdAt']),
    );
  }
}
