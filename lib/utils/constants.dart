import 'package:latlong2/latlong.dart';

class AppConstants {
  static const appName = 'StudentNest';
  static const tagline = 'Verified rooms. Compatible roommates.';
  static const demoPassword = 'Demo@123';
  static const matchingPrice = 20.0;
  static const listingPrice = 10.0;
  static const premiumPrice = 10.0;
  static const freeListings = 2;
  static const failingCard = '4000000000000002';
  static const userAgent = 'com.studentnest.studentnest';
  static const osmTiles = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static const roomTypes = ['single', 'shared', 'studio', 'ensuite'];
  static const sleepSchedules = ['early bird', 'normal', 'night owl'];
  static const diets = [
    'no preference',
    'vegetarian',
    'vegan',
    'halal',
    'other'
  ];
  static const smokingOptions = ['non-smoker', 'outside only', 'smoker'];
  static const languages = [
    'English',
    'Hindi',
    'Urdu',
    'Mandarin',
    'Spanish',
    'Arabic',
    'French',
    'German',
    'Portuguese',
    'Bengali',
    'Turkish',
    'Korean',
    'Japanese',
    'Italian',
    'Vietnamese',
    'Swahili',
  ];
  static const reportReasons = [
    'Fake listing',
    'Scam / asked for money outside app',
    'Inappropriate content',
    'Harassment',
    'Other',
  ];

  /// Rough fixed FX rates used only to compare rents across currencies.
  static const usdRates = {
    'USD': 1.0,
    'GBP': 1.27,
    'EUR': 1.08,
    'CAD': 0.73,
    'AUD': 0.66,
  };

  static const cities = <String, CityInfo>{
    'London': CityInfo('London', 'GBP', LatLng(51.5072, -0.1276)),
    'Manchester': CityInfo('Manchester', 'GBP', LatLng(53.4808, -2.2426)),
    'Toronto': CityInfo('Toronto', 'CAD', LatLng(43.6532, -79.3832)),
    'Sydney': CityInfo('Sydney', 'AUD', LatLng(-33.8688, 151.2093)),
    'Berlin': CityInfo('Berlin', 'EUR', LatLng(52.52, 13.405)),
    'New York': CityInfo('New York', 'USD', LatLng(40.7128, -74.006)),
  };

  static const campuses = <Campus>[
    Campus('University College London (UCL)', 'London', 51.5246, -0.1340),
    Campus("King's College London", 'London', 51.5115, -0.1160),
    Campus('Imperial College London', 'London', 51.4988, -0.1749),
    Campus('University of Manchester', 'Manchester', 53.4668, -2.2339),
    Campus('Manchester Metropolitan University', 'Manchester', 53.4703,
        -2.2397),
    Campus('University of Toronto', 'Toronto', 43.6629, -79.3957),
    Campus('Toronto Metropolitan University', 'Toronto', 43.6577, -79.3788),
    Campus('University of Sydney', 'Sydney', -33.8886, 151.1873),
    Campus('UNSW Sydney', 'Sydney', -33.9173, 151.2313),
    Campus('TU Berlin', 'Berlin', 52.5125, 13.3269),
    Campus('Humboldt University of Berlin', 'Berlin', 52.5180, 13.3936),
    Campus('New York University (NYU)', 'New York', 40.7295, -73.9965),
    Campus('Columbia University', 'New York', 40.8075, -73.9626),
  ];
}

class CityInfo {
  final String name;
  final String currency;
  final LatLng center;
  const CityInfo(this.name, this.currency, this.center);
}

class Campus {
  final String name;
  final String city;
  final double lat;
  final double lng;
  const Campus(this.name, this.city, this.lat, this.lng);
}
