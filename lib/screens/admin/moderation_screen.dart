import 'package:flutter/material.dart';

import '../../models/social.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';

/// Recent reviews with the ability to remove abusive ones.
class ModerationScreen extends StatelessWidget {
  const ModerationScreen({super.key});

  Future<void> _remove(BuildContext context, Review r) async {
    final reason = await askReason(context,
        title: 'Remove review',
        hint: 'e.g. Offensive language',
        action: 'Remove');
    if (reason == null) return;
    try {
      await FirestoreService.instance.removeReview(r, reason);
      if (context.mounted) showSnack(context, 'Review removed');
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Content moderation')),
      body: StreamBuilder<List<Review>>(
        stream: FirestoreService.instance.recentReviewsStream(),
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(snap.error!);
          if (!snap.hasData) return const SkeletonList(height: 110);
          final list = snap.data!;
          if (list.isEmpty) {
            return const EmptyState(
                icon: Icons.reviews_outlined, title: 'No reviews yet');
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final r = list[i];
              return Opacity(
                opacity: r.removed ? 0.55 : 1,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('${r.authorName} → ${r.targetName}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ),
                            StarRow(r.rating.toDouble(), size: 14),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(r.text),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                r.removed
                                    ? 'Removed: ${r.removedReason}'
                                    : formatDate(r.createdAt),
                                style: TextStyle(
                                    fontSize: 12,
                                    color: r.removed
                                        ? AppColors.danger
                                        : AppColors.muted),
                              ),
                            ),
                            if (!r.removed)
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                    foregroundColor: AppColors.danger),
                                onPressed: () => _remove(context, r),
                                icon: const Icon(Icons.delete_outline, size: 18),
                                label: const Text('Remove'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
