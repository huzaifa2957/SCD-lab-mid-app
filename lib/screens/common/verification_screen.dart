import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/social.dart';
import '../../providers/session_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/image_utils.dart';
import '../../widgets/app_image.dart';
import '../../widgets/common.dart';

/// Student: student ID + selfie. Landlord: photo ID + proof of ownership.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final Map<String, String> _images = {};
  bool _busy = false;

  List<(String, String, IconData)> _slots(AppUser u) => u.isLandlord
      ? const [
          ('Photo ID', 'Passport or driving licence', Icons.badge_outlined),
          ('Proof of ownership', 'Title deed, tax bill or tenancy authority',
              Icons.description_outlined),
        ]
      : const [
          ('Student ID', 'Your university ID card or offer letter',
              Icons.badge_outlined),
          ('Selfie', 'A clear photo of your face', Icons.face_retouching_natural),
        ];

  Future<void> _pick(String label) async {
    ImageSource source = ImageSource.gallery;
    if (!kIsWeb) {
      final s = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Take a photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera)),
            ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
          ]),
        ),
      );
      if (s == null) return;
      source = s;
    }
    try {
      final b64 = await ImageUtils.pickBase64(source: source);
      if (b64 != null) setState(() => _images[label] = b64);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _submit(AppUser u) async {
    final slots = _slots(u);
    if (slots.any((s) => !_images.containsKey(s.$1))) {
      showSnack(context, 'Please add both images', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await FirestoreService.instance.submitVerification(u, Map.of(_images));
      if (mounted) {
        setState(() => _images.clear());
        showSnack(context, 'Submitted! An admin will review it shortly.');
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<SessionProvider>().appUser;
    if (u == null) return const Scaffold();
    return Scaffold(
      appBar: AppBar(
          title: Text(u.isLandlord ? 'Identity verification' : 'Verify student ID')),
      body: StreamBuilder<Verification?>(
        stream: FirestoreService.instance.verificationStream(u.uid),
        builder: (context, snap) {
          final v = snap.data;
          final status = u.verificationStatus;
          final canSubmit = status == VerificationStatus.none ||
              status == VerificationStatus.rejected;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatusBanner(status: status, reason: v?.rejectReason ?? ''),
              const SizedBox(height: 16),
              if (canSubmit) ...[
                Text(
                  u.isLandlord
                      ? 'Upload a photo ID and proof that you own or manage the property. Verified landlords get a badge and more trust from students.'
                      : 'Upload your student ID and a selfie. Once approved, a Verified badge appears on your profile.',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                for (final s in _slots(u))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ImageSlot(
                      title: s.$1,
                      subtitle: s.$2,
                      icon: s.$3,
                      image: _images[s.$1],
                      onTap: () => _pick(s.$1),
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _submit(u),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.upload_rounded),
                  label: const Text('Submit for review'),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Images are compressed and only visible to StudentNest admins.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ] else if (v != null) ...[
                const SectionTitle('Submitted documents'),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final e in v.images.entries)
                      GestureDetector(
                        onTap: () =>
                            openImageViewer(context, e.value, title: e.key),
                        child: Column(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AppImage(e.value, width: 150, height: 110),
                          ),
                          const SizedBox(height: 4),
                          Text(e.key, style: const TextStyle(fontSize: 12)),
                        ]),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final String status;
  final String reason;
  const _StatusBanner({required this.status, required this.reason});

  @override
  Widget build(BuildContext context) {
    final (color, icon, title, body) = switch (status) {
      VerificationStatus.approved => (
          AppColors.success,
          Icons.verified_rounded,
          'You are verified',
          'Your Verified badge is visible to everyone.'
        ),
      VerificationStatus.pending => (
          AppColors.warning,
          Icons.hourglass_top_rounded,
          'Verification pending',
          'An admin is reviewing your documents. You will get a notification.'
        ),
      VerificationStatus.rejected => (
          AppColors.danger,
          Icons.cancel_rounded,
          'Verification rejected',
          reason.isEmpty
              ? 'Please upload clearer documents and try again.'
              : 'Reason: $reason. Please try again.'
        ),
      _ => (
          AppColors.indigo,
          Icons.shield_outlined,
          'Not verified yet',
          'Verification builds trust and keeps StudentNest safe.'
        ),
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
                const SizedBox(height: 2),
                Text(body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageSlot extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String? image;
  final VoidCallback onTap;

  const _ImageSlot({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(
              color: image == null ? AppColors.border : AppColors.success,
              width: image == null ? 1 : 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: image == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 36, color: AppColors.primary),
                  const SizedBox(height: 8),
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                  const SizedBox(height: 4),
                  const Text('Tap to upload',
                      style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  AppImage(image!),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: Pill(title,
                        icon: Icons.check_circle_rounded,
                        color: AppColors.success,
                        solid: true),
                  ),
                  const Positioned(
                    right: 10,
                    top: 10,
                    child: Pill('Change',
                        icon: Icons.edit_rounded,
                        color: Colors.black54,
                        solid: true),
                  ),
                ],
              ),
      ),
    );
  }
}
