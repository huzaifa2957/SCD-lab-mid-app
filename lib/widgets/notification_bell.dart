import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/social.dart';
import '../providers/session_provider.dart';
import '../screens/common/notifications_screen.dart';
import '../services/firestore_service.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.select<SessionProvider, String?>((s) => s.appUser?.uid);
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<List<AppNotification>>(
      stream: FirestoreService.instance.notificationsStream(uid),
      builder: (context, snap) {
        final unread = (snap.data ?? const []).where((n) => !n.read).length;
        return IconButton(
          tooltip: 'Notifications',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const NotificationsScreen())),
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text(unread > 9 ? '9+' : '$unread'),
            child: const Icon(Icons.notifications_none_rounded),
          ),
        );
      },
    );
  }
}
