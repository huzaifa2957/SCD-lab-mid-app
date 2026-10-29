import 'dart:convert';

import 'package:image_picker/image_picker.dart';

/// Picks a compressed image and returns it as a base64 string.
/// Images are stored in Firestore (no Firebase Storage), so they are kept small.
class ImageUtils {
  static const maxBytes = 350 * 1024;

  static Future<String?> pickBase64({
    ImageSource source = ImageSource.gallery,
  }) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 600,
      imageQuality: 60,
    );
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBytes) {
      throw Exception('Image is too large. Please choose a smaller photo.');
    }
    return base64Encode(bytes);
  }

  static bool isAsset(String src) => src.startsWith('assets/');
}
