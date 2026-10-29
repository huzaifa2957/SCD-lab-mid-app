import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../widgets/notification_bell.dart';
import '../common/account_widgets.dart';
import '../common/reviews.dart';

class LandlordProfileScreen extends StatelessWidget {
  const LandlordProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final u = context.watch<SessionProvider>().appUser;
    if (u == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: const [NotificationBell()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          ProfileHeader(user: u),
          const SizedBox(height: 14),
          AccountSection(user: u),
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Text(
              'Tip: open a chat in Enquiries and use the menu to review a tenant.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          ReviewsSection(targetId: u.uid, targetName: u.name, allowWrite: false),
        ],
      ),
    );
  }
}
