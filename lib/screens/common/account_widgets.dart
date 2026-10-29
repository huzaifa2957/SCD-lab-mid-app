import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/session_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/image_utils.dart';
import '../../widgets/common.dart';
import 'notifications_screen.dart';
import 'verification_screen.dart';

/// Gradient header card with avatar, name, email, role and badges.
class ProfileHeader extends StatelessWidget {
  final AppUser user;
  const ProfileHeader({super.key, required this.user});

  Future<void> _changePhoto(BuildContext context) async {
    try {
      final b64 = await ImageUtils.pickBase64();
      if (b64 == null) return;
      await FirestoreService.instance.updateUser(user.uid, {'photo': b64});
      if (context.mounted) showSnack(context, 'Profile photo updated');
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _changePhoto(context),
            child: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: AppAvatar(name: user.name, photo: user.photo, radius: 32),
                ),
                const Positioned(
                  right: 0,
                  bottom: 0,
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.camera_alt_rounded,
                        size: 13, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 19)),
                Text(user.email,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  Pill(capitalize(user.role),
                      color: Colors.white24, solid: true),
                  if (user.isVerified) const VerifiedBadge(solid: true),
                  if (user.verificationStatus == VerificationStatus.pending)
                    const Pill('Verification pending',
                        icon: Icons.hourglass_top_rounded,
                        color: AppColors.warning,
                        solid: true),
                  if (user.isStudent && user.matchingUnlocked)
                    const Pill('AI Matching',
                        icon: Icons.auto_awesome_rounded,
                        color: AppColors.premium,
                        solid: true),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color color;
  final Widget? trailing;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.color = AppColors.primary,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: trailing ?? const Icon(Icons.chevron_right_rounded),
    );
  }
}

/// Verification, notifications, logout and delete-account tiles shared by
/// student and landlord profile screens.
class AccountSection extends StatelessWidget {
  final AppUser user;
  const AccountSection({super.key, required this.user});

  String get _verificationSubtitle => switch (user.verificationStatus) {
        VerificationStatus.approved => 'Verified ✓',
        VerificationStatus.pending => 'Pending admin review',
        VerificationStatus.rejected => 'Rejected – please resubmit',
        _ => 'Not verified – tap to start',
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Column(
            children: [
              SettingsTile(
                icon: Icons.verified_user_outlined,
                title: user.isLandlord
                    ? 'Identity verification'
                    : 'Student ID verification',
                subtitle: _verificationSubtitle,
                color: statusColor(user.verificationStatus == 'none'
                    ? 'other'
                    : user.verificationStatus),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const VerificationScreen())),
              ),
              const Divider(indent: 16, endIndent: 16),
              SettingsTile(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const NotificationsScreen())),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Card(
          child: Column(
            children: [
              SettingsTile(
                icon: Icons.logout_rounded,
                title: 'Log out',
                color: AppColors.text,
                trailing: const SizedBox.shrink(),
                onTap: () async {
                  final ok = await confirmDialog(context,
                      title: 'Log out?',
                      message: 'You can log back in any time.',
                      confirmLabel: 'Log out');
                  if (ok && context.mounted) {
                    await context.read<SessionProvider>().signOut();
                  }
                },
              ),
              const Divider(indent: 16, endIndent: 16),
              SettingsTile(
                icon: Icons.delete_forever_outlined,
                title: 'Delete account',
                subtitle: 'Permanently remove your data',
                color: AppColors.danger,
                trailing: const SizedBox.shrink(),
                onTap: () => deleteAccountFlow(context, user),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Confirmation → delete Firestore data → delete Auth user.
/// Handles `requires-recent-login` by asking for the password again.
Future<void> deleteAccountFlow(BuildContext context, AppUser user) async {
  final ok = await confirmDialog(
    context,
    title: 'Delete your account?',
    message:
        'This permanently deletes your profile${user.isLandlord ? ', your listings' : ''} and verification documents. This cannot be undone.',
    confirmLabel: 'Delete',
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  final session = context.read<SessionProvider>();
  // Firebase only deletes recently signed-in users, so confirm the password
  // up front (this is how requires-recent-login is handled).
  final password = await _askPassword(context);
  if (password == null || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
        canPop: false, child: Center(child: CircularProgressIndicator())),
  );
  try {
    await session.auth.reauthenticate(password);
    await FirestoreService.instance.deleteUserData(user);
    try {
      await session.auth.deleteAuthUser();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') rethrow;
      await session.signOut();
    }
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true)
          .popUntil((route) => route.isFirst);
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      showSnack(context, friendlyError(e), error: true);
    }
  }
}

Future<String?> _askPassword(BuildContext context) {
  final ctrl = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Confirm your password'),
      content: TextField(
        controller: ctrl,
        obscureText: true,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Password'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.pop(ctx, ctrl.text),
          child: const Text('Delete account'),
        ),
      ],
    ),
  );
}
