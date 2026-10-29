import 'package:flutter/material.dart';

import '../../models/social.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_image.dart';
import '../../widgets/common.dart';

class VerificationsQueueScreen extends StatelessWidget {
  const VerificationsQueueScreen({super.key});

  Future<void> _decide(
      BuildContext context, Verification v, bool approve) async {
    String reason = '';
    if (!approve) {
      final r = await askReason(context,
          title: 'Reject verification',
          hint: 'e.g. Image is blurry',
          action: 'Reject');
      if (r == null) return;
      reason = r;
    }
    try {
      await FirestoreService.instance.decideVerification(v, approve, reason);
      if (context.mounted) {
        showSnack(context,
            approve ? '${v.userName} approved ✓' : '${v.userName} rejected');
      }
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Verification>>(
      stream: FirestoreService.instance.pendingVerificationsStream(),
      builder: (context, snap) {
        if (snap.hasError) return ErrorView(snap.error!);
        if (!snap.hasData) return const SkeletonList(height: 220, count: 2);
        final list = snap.data!;
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.task_alt_rounded,
            title: 'All caught up',
            message: 'No pending verifications.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (_, i) {
            final v = list[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        AppAvatar(name: v.userName),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(v.userName,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              Text(
                                  '${capitalize(v.role)} · submitted ${timeAgo(v.createdAt)}',
                                  style: const TextStyle(
                                      color: AppColors.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                        const StatusChip('pending'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (final e in v.images.entries)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => openImageViewer(context, e.value,
                                    title: '${v.userName} – ${e.key}'),
                                child: Column(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: AppImage(e.value,
                                          height: 120,
                                          width: double.infinity),
                                    ),
                                    const SizedBox(height: 4),
                                    Text('${e.key} · tap to enlarge',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.muted)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.danger),
                            onPressed: () => _decide(context, v, false),
                            icon: const Icon(Icons.close_rounded),
                            label: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.success),
                            onPressed: () => _decide(context, v, true),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Approve'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
