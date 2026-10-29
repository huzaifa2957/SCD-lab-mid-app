import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/constants.dart';

class PaymentType {
  static const matchingUnlock = 'matching_unlock';
  static const extraListing = 'extra_listing';
  static const premiumBoost = 'premium_boost';

  static String label(String type) {
    switch (type) {
      case matchingUnlock:
        return 'AI matching unlock';
      case extraListing:
        return 'Extra listing';
      case premiumBoost:
        return 'Premium boost';
      default:
        return type;
    }
  }
}

class PaymentDeclined implements Exception {
  final String message;
  PaymentDeclined(this.message);
  @override
  String toString() => message;
}

/// SIMULATED payment processor. No real card is charged.
/// Card 4000 0000 0000 0002 always declines so failures can be demonstrated.
class PaymentService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> pay({
    required String userId,
    required double amount,
    required String type,
    required String cardNumber,
    String refId = '',
  }) async {
    await Future<void>.delayed(const Duration(seconds: 2));
    final digits = cardNumber.replaceAll(RegExp(r'\D'), '');
    final declined = digits == AppConstants.failingCard;
    final ref = await _db.collection('payments').add({
      'userId': userId,
      'amount': amount,
      'type': type,
      'status': declined ? 'failed' : 'succeeded',
      'cardLast4': digits.length >= 4 ? digits.substring(digits.length - 4) : '',
      'refId': refId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (declined) {
      throw PaymentDeclined(
          'Your card was declined by the issuer. Please try another card.');
    }
    return ref.id;
  }
}
