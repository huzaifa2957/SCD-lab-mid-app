import 'dart:convert';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/formatters.dart';

void showSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : AppColors.text,
    ));
}

String friendlyError(Object e) {
  final s = e.toString();
  if (s.contains('permission-denied')) {
    return 'You do not have permission to do that.';
  }
  if (s.contains('unavailable') || s.contains('network')) {
    return 'Network problem. Please check your connection.';
  }
  return s.replaceFirst('Exception: ', '');
}

class LoadingView extends StatelessWidget {
  final String? message;
  const LoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(message!, style: const TextStyle(color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message = '',
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted)),
            ],
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  final Object error;
  const ErrorView(this.error, {super.key});

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Something went wrong',
        message: friendlyError(error),
      );
}

/// Skeleton placeholder shown while lists load.
class SkeletonList extends StatelessWidget {
  final int count;
  final double height;
  const SkeletonList({super.key, this.count = 4, this.height = 110});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: count,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, _) => _Pulse(
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFFE9EEF3),
            borderRadius: BorderRadius.circular(AppTheme.radius),
          ),
        ),
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  final Widget child;
  const _Pulse({required this.child});
  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
      opacity: Tween(begin: 0.45, end: 1.0).animate(_c), child: widget.child);
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(text,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final bool solid;

  const Pill(this.label,
      {super.key, this.color = AppColors.primary, this.icon, this.solid = false});

  @override
  Widget build(BuildContext context) {
    final fg = solid ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: solid ? color : color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  color: fg, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class VerifiedBadge extends StatelessWidget {
  final bool solid;
  const VerifiedBadge({super.key, this.solid = false});
  @override
  Widget build(BuildContext context) => Pill('Verified',
      icon: Icons.verified_rounded, color: AppColors.success, solid: solid);
}

class PremiumBadge extends StatelessWidget {
  final bool solid;
  const PremiumBadge({super.key, this.solid = false});
  @override
  Widget build(BuildContext context) => Pill('Premium',
      icon: Icons.star_rounded, color: AppColors.premium, solid: solid);
}

Color statusColor(String status) {
  switch (status) {
    case 'approved':
      return AppColors.success;
    case 'pending':
      return AppColors.warning;
    case 'rejected':
      return AppColors.danger;
    case 'rented':
      return AppColors.indigo;
    default:
      return AppColors.muted;
  }
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});
  @override
  Widget build(BuildContext context) =>
      Pill(capitalize(status), color: statusColor(status));
}

class AppAvatar extends StatelessWidget {
  final String name;
  final String photo;
  final double radius;

  const AppAvatar(
      {super.key, required this.name, this.photo = '', this.radius = 22});

  static const _palette = [
    Color(0xFF0F766E),
    Color(0xFF4F46E5),
    Color(0xFFDB2777),
    Color(0xFFEA580C),
    Color(0xFF0284C7),
    Color(0xFF7C3AED),
    Color(0xFF059669),
  ];

  @override
  Widget build(BuildContext context) {
    if (photo.isNotEmpty) {
      try {
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(base64Decode(photo)),
        );
      } catch (_) {}
    }
    final color = _palette[name.hashCode.abs() % _palette.length];
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(initials(name),
          style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: radius * 0.75)),
    );
  }
}

class InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const InfoTile(
      {super.key, required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 11.5)),
                Text(value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StarRow extends StatelessWidget {
  final double rating;
  final double size;
  const StarRow(this.rating, {super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final icon = rating >= i + 1
            ? Icons.star_rounded
            : (rating > i ? Icons.star_half_rounded : Icons.star_outline_rounded);
        return Icon(icon, size: size, color: AppColors.premium);
      }),
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
              : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Prompts for a short free-text reason. Returns null if cancelled.
Future<String?> askReason(BuildContext context,
    {required String title, String hint = 'Reason', String action = 'Submit'}) {
  final ctrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: TextFormField(
          controller: ctrl,
          autofocus: true,
          maxLines: 3,
          minLines: 1,
          decoration: InputDecoration(hintText: hint),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Please enter a reason' : null,
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(ctx, ctrl.text.trim());
            }
          },
          child: Text(action),
        ),
      ],
    ),
  );
}

class BrandLogo extends StatelessWidget {
  final double size;
  const BrandLogo({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: AppTheme.softShadow,
      ),
      child: Icon(Icons.home_work_rounded, color: Colors.white, size: size * 0.52),
    );
  }
}
