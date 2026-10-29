import 'model_utils.dart';

class UserRole {
  static const student = 'student';
  static const landlord = 'landlord';
  static const admin = 'admin';
}

class VerificationStatus {
  static const none = 'none';
  static const pending = 'pending';
  static const approved = 'approved';
  static const rejected = 'rejected';
}

class Lifestyle {
  final String course;
  final String university;
  final List<String> languages;
  final String sleepSchedule;
  final int cleanliness;
  final String diet;
  final String smoking;
  final double budget;
  final String city;
  final String bio;

  const Lifestyle({
    this.course = '',
    this.university = '',
    this.languages = const [],
    this.sleepSchedule = 'normal',
    this.cleanliness = 3,
    this.diet = 'no preference',
    this.smoking = 'non-smoker',
    this.budget = 900,
    this.city = '',
    this.bio = '',
  });

  bool get isComplete => course.isNotEmpty && university.isNotEmpty;

  factory Lifestyle.fromMap(Map<String, dynamic> m) => Lifestyle(
        course: toStr(m['course']),
        university: toStr(m['university']),
        languages: toStrList(m['languages']),
        sleepSchedule: toStr(m['sleepSchedule'], 'normal'),
        cleanliness: toInt(m['cleanliness'], 3).clamp(1, 5),
        diet: toStr(m['diet'], 'no preference'),
        smoking: toStr(m['smoking'], 'non-smoker'),
        budget: toDouble(m['budget'], 900),
        city: toStr(m['city']),
        bio: toStr(m['bio']),
      );

  Map<String, dynamic> toMap() => {
        'course': course,
        'university': university,
        'languages': languages,
        'sleepSchedule': sleepSchedule,
        'cleanliness': cleanliness,
        'diet': diet,
        'smoking': smoking,
        'budget': budget,
        'city': city,
        'bio': bio,
      };

  Lifestyle copyWith({
    String? course,
    String? university,
    List<String>? languages,
    String? sleepSchedule,
    int? cleanliness,
    String? diet,
    String? smoking,
    double? budget,
    String? city,
    String? bio,
  }) =>
      Lifestyle(
        course: course ?? this.course,
        university: university ?? this.university,
        languages: languages ?? this.languages,
        sleepSchedule: sleepSchedule ?? this.sleepSchedule,
        cleanliness: cleanliness ?? this.cleanliness,
        diet: diet ?? this.diet,
        smoking: smoking ?? this.smoking,
        budget: budget ?? this.budget,
        city: city ?? this.city,
        bio: bio ?? this.bio,
      );
}

class PrivacySettings {
  final bool showCourse;
  final bool showUniversity;
  final bool showLanguages;
  final bool showBudget;
  final bool showLifestyle;

  const PrivacySettings({
    this.showCourse = true,
    this.showUniversity = true,
    this.showLanguages = true,
    this.showBudget = true,
    this.showLifestyle = true,
  });

  factory PrivacySettings.fromMap(Map<String, dynamic> m) => PrivacySettings(
        showCourse: toBool(m['showCourse'], true),
        showUniversity: toBool(m['showUniversity'], true),
        showLanguages: toBool(m['showLanguages'], true),
        showBudget: toBool(m['showBudget'], true),
        showLifestyle: toBool(m['showLifestyle'], true),
      );

  Map<String, dynamic> toMap() => {
        'showCourse': showCourse,
        'showUniversity': showUniversity,
        'showLanguages': showLanguages,
        'showBudget': showBudget,
        'showLifestyle': showLifestyle,
      };
}

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String role;
  final String photo;
  final String verificationStatus;
  final bool suspended;
  final bool isDemo;
  final bool matchingUnlocked;
  final int freeListingsUsed;
  final Lifestyle lifestyle;
  final PrivacySettings privacy;
  final List<String> savedRooms;
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    this.name = '',
    this.email = '',
    this.role = UserRole.student,
    this.photo = '',
    this.verificationStatus = VerificationStatus.none,
    this.suspended = false,
    this.isDemo = false,
    this.matchingUnlocked = false,
    this.freeListingsUsed = 0,
    this.lifestyle = const Lifestyle(),
    this.privacy = const PrivacySettings(),
    this.savedRooms = const [],
    this.createdAt,
  });

  bool get isStudent => role == UserRole.student;
  bool get isLandlord => role == UserRole.landlord;
  bool get isAdmin => role == UserRole.admin;
  bool get isVerified => verificationStatus == VerificationStatus.approved;

  factory AppUser.fromMap(String uid, Map<String, dynamic>? data) {
    final m = data ?? const {};
    return AppUser(
      uid: uid,
      name: toStr(m['name'], 'User'),
      email: toStr(m['email']),
      role: toStr(m['role'], UserRole.student),
      photo: toStr(m['photo']),
      verificationStatus:
          toStr(m['verificationStatus'], VerificationStatus.none),
      suspended: toBool(m['suspended']),
      isDemo: toBool(m['isDemo']),
      matchingUnlocked: toBool(m['matchingUnlocked']),
      freeListingsUsed: toInt(m['freeListingsUsed']),
      lifestyle: Lifestyle.fromMap(toMap(m['lifestyle'])),
      privacy: PrivacySettings.fromMap(toMap(m['privacy'])),
      savedRooms: toStrList(m['savedRooms']),
      createdAt: toDate(m['createdAt']),
    );
  }
}
