import 'package:flutter/material.dart';

import '../../models/room.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/geo.dart';
import '../../widgets/common.dart';
import '../../widgets/room_card.dart';
import '../common/room_details_screen.dart';

class ListingsQueueScreen extends StatefulWidget {
  const ListingsQueueScreen({super.key});

  @override
  State<ListingsQueueScreen> createState() => _ListingsQueueScreenState();
}

class _ListingsQueueScreenState extends State<ListingsQueueScreen> {
  bool _showAll = false;
  final _fs = FirestoreService.instance;

  Future<void> _approve(Room r) async {
    try {
      await _fs.updateRoom(r.id, {
        'status': RoomStatus.approved,
        'verified': true,
        'rejectReason': '',
      });
      await _fs.notify(r.landlordId, 'Listing approved ✓',
          '"${r.title}" is now live on StudentNest.', 'listing');
      if (mounted) showSnack(context, 'Listing approved');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _reject(Room r) async {
    final reason = await askReason(context,
        title: 'Reject listing',
        hint: 'e.g. Photos do not match the address',
        action: 'Reject');
    if (reason == null) return;
    try {
      await _fs.updateRoom(
          r.id, {'status': RoomStatus.rejected, 'rejectReason': reason});
      await _fs.notify(r.landlordId, 'Listing rejected',
          '"${r.title}" was rejected: $reason', 'listing');
      if (mounted) showSnack(context, 'Listing rejected');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  Future<void> _toggleFlag(Room r) async {
    try {
      if (r.flagged) {
        await _fs.updateRoom(r.id, {'flagged': false, 'flagReason': ''});
        if (mounted) showSnack(context, 'Flag removed');
        return;
      }
      final reason = await askReason(context,
          title: 'Flag as suspicious',
          hint: 'Shown to students as a warning',
          action: 'Flag');
      if (reason == null) return;
      await _fs.updateRoom(r.id, {'flagged': true, 'flagReason': reason});
      if (mounted) showSnack(context, 'Listing flagged');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Room>>(
      stream: _showAll ? _fs.allRoomsStream() : _fs.pendingRoomsStream(),
      builder: (context, snap) {
        final rooms = [...?snap.data]..sort((a, b) =>
            (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Pending approval')),
                  ButtonSegment(value: true, label: Text('All listings')),
                ],
                selected: {_showAll},
                onSelectionChanged: (s) => setState(() => _showAll = s.first),
              ),
            ),
            Expanded(
              child: snap.hasError
                  ? ErrorView(snap.error!)
                  : !snap.hasData
                      ? const SkeletonList(height: 250, count: 2)
                      : rooms.isEmpty
                          ? const EmptyState(
                              icon: Icons.task_alt_rounded,
                              title: 'No listings waiting',
                              message: 'New listings will appear here for approval.')
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: rooms.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: 16),
                              itemBuilder: (_, i) => _item(rooms[i]),
                            ),
            ),
          ],
        );
      },
    );
  }

  Widget _item(Room r) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RoomCard(
          room: r,
          showStatus: true,
          onTap: () => RoomDetailsScreen.open(context, r.id),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            'Landlord: ${r.landlordName} · ${formatMoney(r.deposit, r.currency)} deposit · ${formatKm(r.distanceKm)} to campus${r.rejectReason.isNotEmpty ? '\nRejected: ${r.rejectReason}' : ''}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.end,
          children: [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                  foregroundColor:
                      r.flagged ? AppColors.muted : AppColors.warning),
              onPressed: () => _toggleFlag(r),
              icon: Icon(r.flagged ? Icons.outlined_flag : Icons.flag_rounded),
              label: Text(r.flagged ? 'Unflag' : 'Flag'),
            ),
            if (r.status != RoomStatus.rejected)
              OutlinedButton.icon(
                style:
                    OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () => _reject(r),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Reject'),
              ),
            if (r.status != RoomStatus.approved &&
                r.status != RoomStatus.rented)
              FilledButton.icon(
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.success),
                onPressed: () => _approve(r),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Approve'),
              ),
          ],
        ),
      ],
    );
  }
}
