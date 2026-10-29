import 'package:flutter/material.dart';

import '../../models/room.dart';
import '../../models/social.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';
import '../common/room_details_screen.dart';
import '../common/user_profile_screen.dart';

class ReportsQueueScreen extends StatelessWidget {
  const ReportsQueueScreen({super.key});

  static final _fs = FirestoreService.instance;

  Future<void> _run(BuildContext context, Future<void> Function() action,
      String done) async {
    try {
      await action();
      if (context.mounted) showSnack(context, done);
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _dismiss(BuildContext context, Report r) => _run(
      context,
      () => _fs.resolveReport(r, 'dismissed',
          'we reviewed it and found no violation. Thanks for keeping StudentNest safe.'),
      'Report dismissed');

  Future<void> _removeListing(BuildContext context, Report r) async {
    final ok = await confirmDialog(context,
        title: 'Remove listing?',
        message: '"${r.targetName}" will be hidden from search.',
        confirmLabel: 'Remove',
        destructive: true);
    if (!ok || !context.mounted) return;
    await _run(context, () async {
      await _fs.updateRoom(r.targetId, {
        'status': RoomStatus.rejected,
        'rejectReason': 'Removed by moderation: ${r.reason}',
      });
      if (r.reportedUserId.isNotEmpty) {
        await _fs.notify(r.reportedUserId, 'Listing removed',
            '"${r.targetName}" was removed after a report (${r.reason}).',
            'listing');
      }
      await _fs.resolveReport(
          r, 'removed', 'the listing has been removed. Thank you!');
    }, 'Listing removed');
  }

  Future<void> _flagListing(BuildContext context, Report r) async {
    final reason = await askReason(context,
        title: 'Flag listing as suspicious',
        hint: 'Warning shown to students',
        action: 'Flag');
    if (reason == null || !context.mounted) return;
    await _run(context, () async {
      await _fs.updateRoom(r.targetId, {'flagged': true, 'flagReason': reason});
      await _fs.resolveReport(r, 'flagged',
          'the listing now shows a scam warning to all students.');
    }, 'Listing flagged');
  }

  Future<void> _suspend(BuildContext context, Report r) async {
    final ok = await confirmDialog(context,
        title: 'Suspend user?',
        message:
            'The reported user will be signed out and blocked from logging in.',
        confirmLabel: 'Suspend',
        destructive: true);
    if (!ok || !context.mounted) return;
    await _run(context, () async {
      await _fs.updateUser(r.reportedUserId, {'suspended': true});
      await _fs.resolveReport(
          r, 'suspended', 'the account has been suspended. Thank you!');
    }, 'User suspended');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Report>>(
      stream: _fs.openReportsStream(),
      builder: (context, snap) {
        if (snap.hasError) return ErrorView(snap.error!);
        if (!snap.hasData) return const SkeletonList(height: 180, count: 2);
        final list = snap.data!;
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.shield_rounded,
            title: 'No open reports',
            message: 'Community reports will appear here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (_, i) {
            final r = list[i];
            final isRoom = r.targetType == 'room';
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.flag_rounded, color: AppColors.danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(r.reason,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.danger)),
                        ),
                        Text(timeAgo(r.createdAt),
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(r.details),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: Icon(
                            isRoom
                                ? Icons.home_work_outlined
                                : r.targetType == 'conversation'
                                    ? Icons.forum_outlined
                                    : Icons.person_outline,
                            color: AppColors.indigo),
                        title: Text(r.targetName,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            'Reported ${r.targetType} · by ${r.reporterName}'),
                        trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                        onTap: () => isRoom
                            ? RoomDetailsScreen.open(context, r.targetId)
                            : UserProfileScreen.open(context, r.reportedUserId),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      alignment: WrapAlignment.end,
                      children: [
                        OutlinedButton(
                            onPressed: () => _dismiss(context, r),
                            child: const Text('Dismiss')),
                        if (isRoom)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.warning),
                            onPressed: () => _flagListing(context, r),
                            icon: const Icon(Icons.flag_rounded, size: 18),
                            label: const Text('Flag listing'),
                          ),
                        if (isRoom)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.danger),
                            onPressed: () => _removeListing(context, r),
                            icon: const Icon(Icons.delete_outline, size: 18),
                            label: const Text('Remove listing'),
                          ),
                        if (r.reportedUserId.isNotEmpty)
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.danger),
                            onPressed: () => _suspend(context, r),
                            icon: const Icon(Icons.block_rounded, size: 18),
                            label: const Text('Suspend user'),
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
