import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../services/seed_service.dart';
import '../../widgets/common.dart';
import '../../widgets/notification_bell.dart';
import 'listings_queue_screen.dart';
import 'moderation_screen.dart';
import 'reports_queue_screen.dart';
import 'stats_screen.dart';
import 'verifications_queue_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  static const _titles = ['Verifications', 'Listings', 'Reports', 'Stats'];

  Future<void> _reseed() async {
    final ok = await confirmDialog(context,
        title: 'Reseed demo data?',
        message:
            'Demo accounts, rooms, chats, reviews, reports and payments will be reset to their original state. Real user data is not touched.',
        confirmLabel: 'Reseed');
    if (!ok || !mounted) return;
    final status = ValueNotifier('Starting…');
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 18),
          Expanded(
            child: ValueListenableBuilder<String>(
                valueListenable: status, builder: (_, s, _) => Text(s)),
          ),
        ]),
      ),
    );
    try {
      await SeedService.run(onProgress: (s) => status.value = s);
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        showSnack(context, 'Demo data reseeded');
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        showSnack(context, 'Reseed failed: ${friendlyError(e)}', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          const NotificationBell(),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'moderation':
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const ModerationScreen()));
                case 'reseed':
                  _reseed();
                case 'logout':
                  context.read<SessionProvider>().signOut();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: 'moderation',
                  child: ListTile(
                      leading: Icon(Icons.rate_review_outlined),
                      title: Text('Content moderation'))),
              PopupMenuItem(
                  value: 'reseed',
                  child: ListTile(
                      leading: Icon(Icons.restart_alt_rounded),
                      title: Text('Reseed demo data'))),
              PopupMenuItem(
                  value: 'logout',
                  child: ListTile(
                      leading: Icon(Icons.logout_rounded),
                      title: Text('Log out'))),
            ],
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: const [
          VerificationsQueueScreen(),
          ListingsQueueScreen(),
          ReportsQueueScreen(),
          StatsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.verified_user_outlined),
              selectedIcon: Icon(Icons.verified_user_rounded),
              label: 'Verifications'),
          NavigationDestination(
              icon: Icon(Icons.home_work_outlined),
              selectedIcon: Icon(Icons.home_work_rounded),
              label: 'Listings'),
          NavigationDestination(
              icon: Icon(Icons.flag_outlined),
              selectedIcon: Icon(Icons.flag_rounded),
              label: 'Reports'),
          NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights_rounded),
              label: 'Stats'),
        ],
      ),
    );
  }
}
