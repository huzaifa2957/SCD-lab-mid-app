import '../utils/constants.dart';
import '../utils/geo.dart';
import 'model_utils.dart';

class RoomStatus {
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
  static const rented = 'rented';
}

class Room {
  final String id;
  final String title;
  final String description;
  final String city;
  final String address;
  final double lat;
  final double lng;
  final String campusName;
  final double campusLat;
  final double campusLng;
  final double rent;
  final double deposit;
  final String currency;
  final String roomType;
  final List<String> rules;
  final List<String> photos;
  final String landlordId;
  final String landlordName;
  final String status;
  final bool verified;
  final bool premium;
  final DateTime? premiumUntil;
  final bool flagged;
  final String flagReason;
  final String rejectReason;
  final DateTime? createdAt;

  const Room({
    required this.id,
    this.title = '',
    this.description = '',
    this.city = '',
    this.address = '',
    this.lat = 0,
    this.lng = 0,
    this.campusName = '',
    this.campusLat = 0,
    this.campusLng = 0,
    this.rent = 0,
    this.deposit = 0,
    this.currency = 'USD',
    this.roomType = 'single',
    this.rules = const [],
    this.photos = const [],
    this.landlordId = '',
    this.landlordName = '',
    this.status = RoomStatus.pending,
    this.verified = false,
    this.premium = false,
    this.premiumUntil,
    this.flagged = false,
    this.flagReason = '',
    this.rejectReason = '',
    this.createdAt,
  });

  double get distanceKm => haversineKm(lat, lng, campusLat, campusLng);

  bool get isPremiumActive =>
      premium && (premiumUntil == null || premiumUntil!.isAfter(DateTime.now()));

  double get rentUsd => rent * (AppConstants.usdRates[currency] ?? 1);
  double get depositUsd => deposit * (AppConstants.usdRates[currency] ?? 1);

  bool get isSearchable => status == RoomStatus.approved;

  factory Room.fromMap(String id, Map<String, dynamic>? data) {
    final m = data ?? const {};
    return Room(
      id: id,
      title: toStr(m['title'], 'Untitled room'),
      description: toStr(m['description']),
      city: toStr(m['city']),
      address: toStr(m['address']),
      lat: toDouble(m['lat']),
      lng: toDouble(m['lng']),
      campusName: toStr(m['campusName']),
      campusLat: toDouble(m['campusLat']),
      campusLng: toDouble(m['campusLng']),
      rent: toDouble(m['rent']),
      deposit: toDouble(m['deposit']),
      currency: toStr(m['currency'], 'USD'),
      roomType: toStr(m['roomType'], 'single'),
      rules: toStrList(m['rules']),
      photos: toStrList(m['photos']),
      landlordId: toStr(m['landlordId']),
      landlordName: toStr(m['landlordName']),
      status: toStr(m['status'], RoomStatus.pending),
      verified: toBool(m['verified']),
      premium: toBool(m['premium']),
      premiumUntil: toDate(m['premiumUntil']),
      flagged: toBool(m['flagged']),
      flagReason: toStr(m['flagReason']),
      rejectReason: toStr(m['rejectReason']),
      createdAt: toDate(m['createdAt']),
    );
  }

  /// Fields a landlord edits through the listing form.
  Map<String, dynamic> toEditableMap() => {
        'title': title,
        'description': description,
        'city': city,
        'address': address,
        'lat': lat,
        'lng': lng,
        'campusName': campusName,
        'campusLat': campusLat,
        'campusLng': campusLng,
        'rent': rent,
        'deposit': deposit,
        'currency': currency,
        'roomType': roomType,
        'rules': rules,
        'photos': photos,
      };
}
