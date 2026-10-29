import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/room.dart';
import '../../models/social.dart';
import '../../providers/session_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/geo.dart';
import '../../widgets/app_image.dart';
import '../../widgets/common.dart';
import '../../widgets/map_widgets.dart';
import 'chat_screens.dart';
import 'report_screen.dart';
import 'user_profile_screen.dart';

class RoomDetailsScreen extends StatelessWidget {
  final String roomId;
  const RoomDetailsScreen({super.key, required this.roomId});

  static Future<void> open(BuildContext context, String roomId) {
    return Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RoomDetailsScreen(roomId: roomId)));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Room?>(
      stream: FirestoreService.instance.roomStream(roomId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(appBar: AppBar(), body: ErrorView(snap.error!));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(appBar: AppBar(), body: const LoadingView());
        }
        final room = snap.data;
        if (room == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'Listing not available',
              message: 'This room may have been removed by the landlord.',
            ),
          );
        }
        return _RoomDetailsView(room: room);
      },
    );
  }
}

class _RoomDetailsView extends StatefulWidget {
  final Room room;
  const _RoomDetailsView({required this.room});

  @override
  State<_RoomDetailsView> createState() => _RoomDetailsViewState();
}

class _RoomDetailsViewState extends State<_RoomDetailsView> {
  int _page = 0;

  Future<void> _toggleSave(bool saved) async {
    final me = context.read<SessionProvider>().appUser!;
    try {
      await FirestoreService.instance.setSaved(me.uid, widget.room.id, !saved);
      if (mounted) {
        showSnack(context, saved ? 'Removed from saved' : 'Saved to your list');
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final me = context.watch<SessionProvider>().appUser;
    final saved = me?.savedRooms.contains(room.id) ?? false;
    final isStudent = me?.isStudent ?? false;
    final photos = room.photos.isEmpty ? [''] : room.photos;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            foregroundColor: Colors.white,
            backgroundColor: AppColors.primary,
            actions: [
              if (isStudent)
                IconButton(
                  tooltip: saved ? 'Unsave' : 'Save',
                  onPressed: () => _toggleSave(saved),
                  icon: Icon(saved
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PageView.builder(
                    itemCount: photos.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => GestureDetector(
                      onTap: () => openImageViewer(context, photos[i],
                          title: room.title),
                      child: AppImage(photos[i]),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [Colors.black45, Colors.transparent],
                      ),
                    ),
                  ),
                  if (photos.length > 1)
                    Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          photos.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: i == _page ? 20 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _page ? Colors.white : Colors.white60,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (photos.length > 1)
                    Positioned(
                      right: 12,
                      bottom: 30,
                      child: Pill('${_page + 1}/${photos.length}',
                          icon: Icons.photo_library_outlined,
                          color: Colors.black54,
                          solid: true),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (room.flagged) _flagBanner(room.flagReason),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    if (room.verified) const VerifiedBadge(),
                    if (room.isPremiumActive) const PremiumBadge(),
                    if (room.status != RoomStatus.approved)
                      StatusChip(room.status),
                  ]),
                  const SizedBox(height: 10),
                  Text(room.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.place_outlined,
                        size: 16, color: AppColors.muted),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(room.address,
                            style: const TextStyle(color: AppColors.muted))),
                  ]),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(formatMoney(room.rent, room.currency),
                          style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary)),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4, left: 4),
                        child: Text('per month',
                            style: TextStyle(color: AppColors.muted)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(builder: (context, c) {
                    final w = (c.maxWidth - 10) / 2;
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SizedBox(
                            width: w,
                            child: InfoTile(
                                icon: Icons.savings_outlined,
                                label: 'Deposit',
                                value: formatMoney(room.deposit, room.currency))),
                        SizedBox(
                            width: w,
                            child: InfoTile(
                                icon: Icons.bed_outlined,
                                label: 'Room type',
                                value: capitalize(room.roomType))),
                        SizedBox(
                            width: w,
                            child: InfoTile(
                                icon: Icons.school_outlined,
                                label: 'To ${room.campusName}',
                                value: formatKm(room.distanceKm))),
                        SizedBox(
                            width: w,
                            child: InfoTile(
                                icon: Icons.location_city_outlined,
                                label: 'City',
                                value: room.city)),
                      ],
                    );
                  }),
                  const SectionTitle('About this room'),
                  Text(room.description.isEmpty
                      ? 'No description provided.'
                      : room.description),
                  if (room.rules.isNotEmpty) ...[
                    const SectionTitle('House rules'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final r in room.rules)
                          Chip(
                            avatar: const Icon(Icons.rule_rounded,
                                size: 16, color: AppColors.primary),
                            label: Text(r),
                          ),
                      ],
                    ),
                  ],
                  const SectionTitle('Location'),
                  _mapPreview(room),
                  const SectionTitle('Landlord'),
                  _LandlordTile(room: room),
                  const SizedBox(height: 16),
                  _safetyTip(),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isStudent
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    IconButton.outlined(
                      tooltip: 'Report listing',
                      onPressed: () => ReportScreen.open(context,
                          targetType: 'room',
                          targetId: room.id,
                          targetName: room.title,
                          reportedUserId: room.landlordId),
                      icon: const Icon(Icons.flag_outlined,
                          color: AppColors.danger),
                    ),
                    const SizedBox(width: 8),
                    IconButton.outlined(
                      tooltip: saved ? 'Unsave' : 'Save',
                      onPressed: () => _toggleSave(saved),
                      icon: Icon(
                          saved
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: AppColors.danger),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => openChatWith(context,
                            otherId: room.landlordId,
                            otherName: room.landlordName.isEmpty
                                ? 'Landlord'
                                : room.landlordName,
                            otherRole: 'landlord',
                            roomId: room.id,
                            roomTitle: room.title),
                        icon: const Icon(Icons.chat_bubble_outline_rounded),
                        label: const Text('Contact landlord'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _flagBanner(String reason) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.gpp_maybe_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Warning: possible scam',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(
                      reason.isEmpty
                          ? 'This listing was flagged as suspicious by our team.'
                          : reason,
                      style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 4),
                  const Text('Do not send any money for this room.',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _safetyTip() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, color: AppColors.primary),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Stay safe',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text(
                      'Never pay deposits outside StudentNest. Always view the room or do a video call first.'),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _mapPreview(Room room) {
    final roomPt = LatLng(room.lat, room.lng);
    final campusPt = LatLng(room.campusLat, room.campusLng);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: SizedBox(
        height: 220,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: [roomPt, campusPt],
              padding: const EdgeInsets.all(50),
              maxZoom: 16,
            ),
            interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.pinchZoom |
                    InteractiveFlag.drag |
                    InteractiveFlag.doubleTapZoom),
          ),
          children: [
            osmTileLayer(),
            PolylineLayer(polylines: [
              Polyline(
                points: [roomPt, campusPt],
                color: AppColors.indigo,
                strokeWidth: 3,
                pattern: StrokePattern.dashed(segments: const [8, 6]),
              ),
            ]),
            MarkerLayer(markers: [
              Marker(
                  point: campusPt,
                  width: 36,
                  height: 36,
                  child: const MapPin(
                      color: AppColors.indigo, icon: Icons.school_rounded)),
              Marker(
                  point: roomPt,
                  width: 36,
                  height: 36,
                  child: const MapPin()),
            ]),
            const OsmAttribution(),
          ],
        ),
      ),
    );
  }
}

class _LandlordTile extends StatelessWidget {
  final Room room;
  const _LandlordTile({required this.room});

  @override
  Widget build(BuildContext context) {
    final name = room.landlordName.isEmpty ? 'Landlord' : room.landlordName;
    return StreamBuilder<List<Review>>(
      stream: FirestoreService.instance.reviewsForStream(room.landlordId),
      builder: (context, snap) {
        final list = snap.data ?? const <Review>[];
        final avg = list.isEmpty
            ? 0.0
            : list.map((r) => r.rating).reduce((a, b) => a + b) / list.length;
        return Card(
          child: ListTile(
            onTap: () => UserProfileScreen.open(context, room.landlordId),
            leading: AppAvatar(name: name, radius: 22),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: list.isEmpty
                ? const Text('No reviews yet')
                : Row(children: [
                    StarRow(avg, size: 14),
                    const SizedBox(width: 6),
                    Text('${avg.toStringAsFixed(1)} (${list.length})'),
                  ]),
            trailing: const Icon(Icons.chevron_right_rounded),
          ),
        );
      },
    );
  }
}
