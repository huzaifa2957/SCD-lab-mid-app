import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Displays a bundled asset path or a base64 image, with a graceful fallback.
class AppImage extends StatelessWidget {
  final String src;
  final BoxFit fit;
  final double? width;
  final double? height;

  const AppImage(this.src,
      {super.key, this.fit = BoxFit.cover, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    if (src.isEmpty) return RoomPlaceholder(width: width, height: height);
    if (src.startsWith('assets/')) {
      return Image.asset(
        src,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (_, _, _) =>
            RoomPlaceholder(width: width, height: height),
      );
    }
    try {
      return Image.memory(
        base64Decode(src),
        fit: fit,
        width: width,
        height: height,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) =>
            RoomPlaceholder(width: width, height: height),
      );
    } catch (_) {
      return RoomPlaceholder(width: width, height: height);
    }
  }
}

class RoomPlaceholder extends StatelessWidget {
  final double? width;
  final double? height;
  const RoomPlaceholder({super.key, this.width, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.75),
            AppColors.indigo.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.bed_rounded, color: Colors.white70, size: 42),
      ),
    );
  }
}

void openImageViewer(BuildContext context, String src, {String title = ''}) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(title, style: const TextStyle(color: Colors.white)),
      ),
      body: Center(
        child: InteractiveViewer(
          maxScale: 5,
          child: AppImage(src, fit: BoxFit.contain),
        ),
      ),
    ),
  ));
}
