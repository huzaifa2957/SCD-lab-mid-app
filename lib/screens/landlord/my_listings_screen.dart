import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../models/room.dart';
import '../../providers/session_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/payment_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/payment_sheet.dart';
import '../../widgets/room_card.dart';
import '../common/room_details_screen.dart';
import '../common/verification_screen.dart';
import 'listing_form_screen.dart';

class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<SessionProvider>().appUser;
    if (me == null) return const SizedBox.shrink();
    final freeLeft =
        (AppConstants.freeListings - me.freeListingsUsed).clamp(0, 99);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Listings'),
        actions: const [NotificationBell()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ListingFormScreen())),
        icon: const Icon(Icons.add_home_outlined),
        label: const Text('New listing'),
      ),
      body: StreamBuilder<List<Room>>(
        stream: FirestoreService.instance.landlordRoomsStream(me.uid),
        builder: (context, snap) {
          if (snap.hasError) return ErrorView(snap.error!);
          if (!snap.hasData) return const SkeletonList(height: 250, count: 2);
          final rooms = snap.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            children: [
              if (!me.isVerified) _verifyBanner(context, me),
              _summary(rooms, freeLeft),
              const SizedBox(height: 14),
              if (rooms.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: EmptyState(
                    icon: Icons.add_home_work_outlined,
                    title: 'No listings yet',
                    message:
                        'Create your first listing – your first 2 listings are free.',
                  ),
                ),
              for (final r in rooms)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: RoomCard(
                    room: r,
                    showStatus: true,
                    onTap: () => RoomDetailsScreen.open(context, r.id),
                    trailing: _ListingMenu(room: r, me: me),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _verifyBanner(BuildContext context, AppUser me) {
    final pending = me.verificationStatus == VerificationStatus.pending;
    return Card(
      color: AppColors.warning.withValues(alpha: 0.08),
      child: ListTile(
        leading: Icon(
            pending ? Icons.hourglass_top_rounded : Icons.shield_outlined,
            color: AppColors.warning),
        title: Text(pending
            ? 'Verification pending'
            : 'Verify your identity to build trust'),
        subtitle: Text(pending
            ? 'We are reviewing your documents.'
            : 'Upload a photo ID and proof of ownership.'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const VerificationScreen())),
      ),
    );
  }

  Widget _summary(List<Room> rooms, int freeLeft) {
    int count(String s) => rooms.where((r) => r.status == s).length;
    final items = [
      ('Live', count(RoomStatus.approved), AppColors.success),
      ('Pending', count(RoomStatus.pending), AppColors.warning),
      ('Rented', count(RoomStatus.rented), AppColors.indigo),
      ('Free left', freeLeft, AppColors.primary),
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          for (final i in items)
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Text('${i.$2}',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: i.$3)),
                    Text(i.$1,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.muted)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ListingMenu extends StatelessWidget {
  final Room room;
  final AppUser me;
  const _ListingMenu({required this.room, required this.me});

  Future<void> _boost(BuildContext context) async {
    final ok = await showPaymentSheet(
      context,
      userId: me.uid,
      amount: AppConstants.premiumPrice,
      type: PaymentType.premiumBoost,
      title: 'Boost to Premium',
      description: '30 days at the top of search',
      refId: room.id,
    );
    if (!ok) return;
    try {
      await FirestoreService.instance.updateRoom(room.id, {
        'premium': true,
        'premiumUntil': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 30))),
      });
      if (context.mounted) {
        showSnack(context, '"${room.title}" is now Premium for 30 days ★');
      }
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _setStatus(BuildContext context, String status) async {
    try {
      await FirestoreService.instance.updateRoom(room.id, {'status': status});
      if (context.mounted) {
        showSnack(
            context,
            status == RoomStatus.rented
                ? 'Marked as rented – hidden from search'
                : 'Listing is live again');
      }
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await confirmDialog(context,
        title: 'Delete listing?',
        message: '"${room.title}" will be permanently removed.',
        confirmLabel: 'Delete',
        destructive: true);
    if (!ok) return;
    try {
      await FirestoreService.instance.deleteRoom(room.id);
      if (context.mounted) showSnack(context, 'Listing deleted');
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Manage listing',
      onSelected: (v) {
        switch (v) {
          case 'edit':
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ListingFormScreen(existing: room)));
          case 'boost':
            _boost(context);
          case 'rented':
            _setStatus(context, RoomStatus.rented);
          case 'available':
            _setStatus(context, RoomStatus.approved);
          case 'delete':
            _delete(context);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
            value: 'edit',
            child: ListTile(
                leading: Icon(Icons.edit_outlined), title: Text('Edit'))),
        if (!room.isPremiumActive &&
            room.status != RoomStatus.rented &&
            room.status != RoomStatus.rejected)
          PopupMenuItem(
              value: 'boost',
              child: ListTile(
                  leading: const Icon(Icons.star_rounded,
                      color: AppColors.premium),
                  title: Text(
                      'Boost to Premium – ${formatUsd(AppConstants.premiumPrice)}'))),
        if (room.status == RoomStatus.approved)
          const PopupMenuItem(
              value: 'rented',
              child: ListTile(
                  leading: Icon(Icons.key_rounded),
                  title: Text('Mark as rented'))),
        if (room.status == RoomStatus.rented)
          const PopupMenuItem(
              value: 'available',
              child: ListTile(
                  leading: Icon(Icons.restart_alt_rounded),
                  title: Text('Mark as available'))),
        const PopupMenuItem(
            value: 'delete',
            child: ListTile(
                leading:
                    Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                title: Text('Delete'))),
      ],
    );
  }
}
