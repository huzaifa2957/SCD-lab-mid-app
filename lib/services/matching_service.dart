import '../models/app_user.dart';

class MatchResult {
  /// Overall compatibility, 0-100.
  final int score;

  /// Per-category similarity, each 0.0-1.0.
  final Map<String, double> breakdown;

  const MatchResult(this.score, this.breakdown);
}

/// Computes roommate compatibility from lifestyle answers only.
///
/// FAIRNESS: the score deliberately uses ONLY lifestyle preferences the
/// student chose to share (sleep, cleanliness, smoking, diet, budget,
/// languages, course/university). It NEVER uses ethnicity, nationality,
/// religion or gender, and none of those are stored in the profile.
class MatchingService {
  static const weights = <String, double>{
    'Sleep schedule': 0.20,
    'Cleanliness': 0.20,
    'Smoking': 0.15,
    'Diet': 0.10,
    'Budget': 0.15,
    'Languages': 0.10,
    'Course / University': 0.10,
  };

  static MatchResult compute(Lifestyle a, Lifestyle b) {
    final breakdown = <String, double>{
      'Sleep schedule': _sleep(a.sleepSchedule, b.sleepSchedule),
      'Cleanliness': 1 - (a.cleanliness - b.cleanliness).abs() / 4,
      'Smoking': _smoking(a.smoking, b.smoking),
      'Diet': _diet(a.diet, b.diet),
      'Budget': _budget(a.budget, b.budget),
      'Languages': _languages(a.languages, b.languages),
      'Course / University': _study(a, b),
    };
    var total = 0.0;
    weights.forEach((k, w) => total += w * (breakdown[k] ?? 0));
    return MatchResult((total * 100).round().clamp(0, 100), breakdown);
  }

  static const _sleepOrder = ['early bird', 'normal', 'night owl'];

  static double _sleep(String a, String b) {
    final ia = _sleepOrder.indexOf(a);
    final ib = _sleepOrder.indexOf(b);
    if (ia < 0 || ib < 0) return 0.5;
    final d = (ia - ib).abs();
    return d == 0 ? 1 : (d == 1 ? 0.5 : 0);
  }

  static double _smoking(String a, String b) {
    if (a == b) return 1;
    final pair = {a, b};
    if (pair.containsAll(['non-smoker', 'outside only'])) return 0.5;
    if (pair.containsAll(['outside only', 'smoker'])) return 0.6;
    return 0; // non-smoker vs smoker
  }

  static double _diet(String a, String b) {
    if (a == b) return 1;
    if (a == 'no preference' || b == 'no preference') return 0.7;
    if ({a, b}.containsAll(['vegetarian', 'vegan'])) return 0.7;
    return 0.3;
  }

  static double _budget(double a, double b) {
    if (a <= 0 || b <= 0) return 0.5;
    final ratio = (a - b).abs() / (a > b ? a : b);
    return (1 - ratio * 2).clamp(0.0, 1.0);
  }

  static double _languages(List<String> a, List<String> b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final shared = a.toSet().intersection(b.toSet()).length;
    final smaller = a.length < b.length ? a.length : b.length;
    return (shared / smaller).clamp(0.0, 1.0);
  }

  static double _study(Lifestyle a, Lifestyle b) {
    var s = 0.0;
    if (a.university.isNotEmpty &&
        a.university.toLowerCase() == b.university.toLowerCase()) {
      s += 0.5;
    }
    if (a.course.isNotEmpty && a.course.toLowerCase() == b.course.toLowerCase()) {
      s += 0.5;
    }
    return s;
  }
}
