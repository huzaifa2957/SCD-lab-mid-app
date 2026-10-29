import 'package:intl/intl.dart';

String formatMoney(num amount, String currency) {
  try {
    return NumberFormat.simpleCurrency(name: currency, decimalDigits: 0)
        .format(amount);
  } catch (_) {
    return '$currency ${amount.round()}';
  }
}

String formatUsd(num amount) =>
    NumberFormat.simpleCurrency(name: 'USD', decimalDigits: 0).format(amount);

String formatDate(DateTime? d) =>
    d == null ? '' : DateFormat('d MMM yyyy').format(d);

String formatDateTime(DateTime? d) =>
    d == null ? '' : DateFormat('d MMM, HH:mm').format(d);

/// Short relative time for lists (e.g. chats, notifications).
String timeAgo(DateTime? d) {
  if (d == null) return '';
  final diff = DateTime.now().difference(d);
  if (diff.inSeconds < 60) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return DateFormat('HH:mm').format(d);
  if (diff.inDays < 7) return DateFormat('EEE').format(d);
  return DateFormat('d MMM').format(d);
}

String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String initials(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}
