import 'package:cloud_firestore/cloud_firestore.dart';

/// Safe converters so missing / malformed Firestore fields never crash the UI.
DateTime? toDate(dynamic v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v);
  return null;
}

double toDouble(dynamic v, [double fallback = 0]) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? fallback;
  return fallback;
}

int toInt(dynamic v, [int fallback = 0]) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? fallback;
  return fallback;
}

String toStr(dynamic v, [String fallback = '']) =>
    v == null ? fallback : v.toString();

bool toBool(dynamic v, [bool fallback = false]) => v is bool ? v : fallback;

List<String> toStrList(dynamic v) =>
    v is Iterable ? v.map((e) => e.toString()).toList() : <String>[];

Map<String, dynamic> toMap(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
