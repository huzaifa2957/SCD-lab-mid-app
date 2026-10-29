class Validators {
  static final _email = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

  static String? required(String? v, [String field = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    if (!_email.hasMatch(v.trim())) return 'Enter a valid email address';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? name(String? v) {
    if (v == null || v.trim().length < 2) return 'Please enter your full name';
    return null;
  }

  static String? positiveNumber(String? v, [String field = 'Value']) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    final n = num.tryParse(v.trim());
    if (n == null) return 'Enter a valid number';
    if (n < 0) return '$field cannot be negative';
    return null;
  }
}
