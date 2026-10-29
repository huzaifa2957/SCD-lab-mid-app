import 'package:flutter_test/flutter_test.dart';
import 'package:studentnest/models/app_user.dart';
import 'package:studentnest/services/matching_service.dart';

void main() {
  const a = Lifestyle(
    course: 'MSc Data Science',
    university: 'University of Manchester',
    languages: ['English', 'French'],
    sleepSchedule: 'early bird',
    cleanliness: 5,
    diet: 'vegetarian',
    smoking: 'non-smoker',
    budget: 800,
    city: 'Manchester',
  );

  const opposite = Lifestyle(
    course: 'BA Film Studies',
    university: 'New York University (NYU)',
    languages: ['Korean'],
    sleepSchedule: 'night owl',
    cleanliness: 1,
    diet: 'halal',
    smoking: 'smoker',
    budget: 2500,
    city: 'New York',
  );

  group('MatchingService', () {
    test('identical profiles score 100%', () {
      final r = MatchingService.compute(a, a);
      expect(r.score, 100);
      for (final v in r.breakdown.values) {
        expect(v, 1.0);
      }
    });

    test('opposite profiles score low', () {
      final r = MatchingService.compute(a, opposite);
      expect(r.score, lessThan(20));
    });

    test('score is symmetric', () {
      final b = a.copyWith(sleepSchedule: 'normal', cleanliness: 3, budget: 950);
      expect(MatchingService.compute(a, b).score,
          MatchingService.compute(b, a).score);
    });

    test('similar profiles score higher than different ones', () {
      final similar = a.copyWith(cleanliness: 4, budget: 850);
      expect(MatchingService.compute(a, similar).score,
          greaterThan(MatchingService.compute(a, opposite).score));
    });

    test('weights add up to 100%', () {
      final total = MatchingService.weights.values.reduce((x, y) => x + y);
      expect(total, closeTo(1.0, 1e-9));
    });

    test('score is always between 0 and 100', () {
      const empty = Lifestyle(languages: [], budget: 0);
      final r = MatchingService.compute(empty, opposite);
      expect(r.score, inInclusiveRange(0, 100));
    });
  });
}
