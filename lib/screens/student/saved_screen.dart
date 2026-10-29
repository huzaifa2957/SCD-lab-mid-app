import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/room.dart';
import '../../providers/session_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/room_card.dart';
import '../common/room_details_screen.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  String _key = '';
  final Set<String> _removed = {};
  Future<List<Room>>? _future;

  void _load(List<String> ids, {bool force = false}) {
    final key = ids.join(',');
    if (key == _key && _future != null && !force) return;
    _key = key;
    _future = FirestoreService.instance.getRoomsByIds(ids);
  }

  Future<void> _remove(String uid, Room room) async {
    setState(() => _removed.add(room.id));
    try {
      await FirestoreService.instance.setSaved(uid, room.id, false);
      if (mounted) showSnack(context, 'Removed "${room.title}"');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<SessionProvider>().appUser;
    if (me == null) return const SizedBox.shrink();
    _load(me.savedRooms);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved rooms'),
        actions: const [NotificationBell()],
      ),
      body: me.savedRooms.isEmpty
          ? const EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'No saved rooms yet',
              message: 'Tap the heart on any room to keep it here.',
            )
          : FutureBuilder<List<Room>>(
              future: _future,
              builder: (context, snap) {
                if (snap.hasError) return ErrorView(snap.error!);
                if (!snap.hasData) return const SkeletonList(height: 250, count: 2);
                final rooms =
                    snap.data!.where((r) => !_removed.contains(r.id)).toList();
                if (rooms.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Saved rooms are no longer available',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() => _load(me.savedRooms, force: true));
                    await _future;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: rooms.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (_, i) {
                      final r = rooms[i];
                      return Dismissible(
                        key: ValueKey(r.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius:
                                BorderRadius.circular(AppTheme.radius),
                          ),
                          child: const Icon(Icons.delete_outline_rounded,
                              color: Colors.white),
                        ),
                        onDismissed: (_) => _remove(me.uid, r),
                        child: RoomCard(
                          room: r,
                          showStatus: r.status != RoomStatus.approved,
                          onTap: () => RoomDetailsScreen.open(context, r.id),
                          trailing: IconButton(
                            tooltip: 'Remove',
                            onPressed: () => _remove(me.uid, r),
                            icon: const Icon(Icons.favorite_rounded,
                                color: AppColors.danger),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
