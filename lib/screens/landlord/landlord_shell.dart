import 'package:flutter/material.dart';

import '../../widgets/notification_bell.dart';
import '../common/chat_screens.dart';
import 'landlord_profile_screen.dart';
import 'my_listings_screen.dart';

class LandlordShell extends StatefulWidget {
  const LandlordShell({super.key});

  @override
  State<LandlordShell> createState() => _LandlordShellState();
}

class _LandlordShellState extends State<LandlordShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          MyListingsScreen(),
          ConversationsScreen(
            title: 'Enquiries',
            emptyMessage:
                'When students contact you about a room, their messages appear here.',
            actions: [NotificationBell()],
          ),
          LandlordProfileScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.apartment_outlined),
              selectedIcon: Icon(Icons.apartment_rounded),
              label: 'My Listings'),
          NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum_rounded),
              label: 'Enquiries'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile'),
        ],
      ),
    );
  }
}
