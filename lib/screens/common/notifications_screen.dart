import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/social.dart';
import '../../providers/session_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static IconData _icon(String type) {
    switch (type) {
      case 'message':
        return Icons.chat_bubble_rounded;
      case 'verification':
        return Icons.verified_user_rounded;
      case 'listing':
        return Icons.apartment_rounded;
      case 'report':
        return Icons.flag_rounded;
      case 'review':
        return Icons.star_rounded;
      case 'payment':
        return Icons.payments_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<SessionProvider>().appUser?.uid ?? '';
    final fs = FirestoreService.instance;
    return StreamBuilder<List<AppNotification>>(
      stream: fs.notificationsStream(uid),
      builder: (context, snap) {
        final list = snap.data ?? const <AppNotification>[];
        return Scaffold(
          appBar: AppBar(
            title: const Text('Notifications'),
            actions: [
              if (list.any((n) => !n.read))
                TextButton(
                  onPressed: () => fs.markAllNotificationsRead(list),
                  child: const Text('Mark all read'),
                ),
            ],
          ),
          body: snap.hasError
              ? ErrorView(snap.error!)
              : !snap.hasData
                  ? const SkeletonList(height: 72)
                  : list.isEmpty
                      ? const EmptyState(
                          icon: Icons.notifications_off_outlined,
                          title: 'No notifications yet',
                          message:
                              'Approvals, messages and report updates will show up here.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: list.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final n = list[i];
                            return Card(
                              color: n.read
                                  ? AppColors.surface
                                  : AppColors.primary.withValues(alpha: 0.05),
                              child: ListTile(
                                onTap: n.read
                                    ? null
                                    : () => fs.markNotificationRead(n.id),
                                leading: CircleAvatar(
                                  backgroundColor:
                                      AppColors.primary.withValues(alpha: 0.12),
                                  child: Icon(_icon(n.type),
                                      color: AppColors.primary, size: 20),
                                ),
                                title: Text(n.title,
                                    style: TextStyle(
                                        fontWeight: n.read
                                            ? FontWeight.w500
                                            : FontWeight.w700)),
                                subtitle: Text(n.body),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(timeAgo(n.createdAt),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.muted)),
                                    if (!n.read)
                                      const Padding(
                                        padding: EdgeInsets.only(top: 6),
                                        child: CircleAvatar(
                                            radius: 4,
                                            backgroundColor: AppColors.primary),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
        );
      },
    );
  }
}
