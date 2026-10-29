import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/room.dart';
import '../../providers/session_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';
import '../../widgets/map_widgets.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/room_card.dart';
import '../common/room_details_screen.dart';

class RoomFilters {
  static const anyRent = 3000.0;
  static const anyDeposit = 4000.0;
  static const anyDistance = 20.0;

  double maxRentUsd = anyRent;
  double maxDepositUsd = anyDeposit;
  double maxDistanceKm = anyDistance;
  Set<String> roomTypes = {};
  String sort = 'recommended'; // recommended | price | distance

  int get activeCount =>
      (maxRentUsd < anyRent ? 1 : 0) +
      (maxDepositUsd < anyDeposit ? 1 : 0) +
      (maxDistanceKm < anyDistance ? 1 : 0) +
      (roomTypes.isNotEmpty ? 1 : 0);

  RoomFilters copy() => RoomFilters()
    ..maxRentUsd = maxRentUsd
    ..maxDepositUsd = maxDepositUsd
    ..maxDistanceKm = maxDistanceKm
    ..roomTypes = {...roomTypes}
    ..sort = sort;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  late final Stream<List<Room>> _stream =
      FirestoreService.instance.approvedRoomsStream();
  RoomFilters _filters = RoomFilters();
  String _city = 'All';
  bool _mapView = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Room> _apply(List<Room> rooms) {
    final q = _search.text.trim().toLowerCase();
    final f = _filters;
    final list = rooms.where((r) {
      if (!r.isSearchable) return false;
      if (_city != 'All' && r.city != _city) return false;
      if (q.isNotEmpty &&
          !('${r.city} ${r.campusName} ${r.title} ${r.address}')
              .toLowerCase()
              .contains(q)) {
        return false;
      }
      if (f.maxRentUsd < RoomFilters.anyRent && r.rentUsd > f.maxRentUsd) {
        return false;
      }
      if (f.maxDepositUsd < RoomFilters.anyDeposit &&
          r.depositUsd > f.maxDepositUsd) {
        return false;
      }
      if (f.maxDistanceKm < RoomFilters.anyDistance &&
          r.distanceKm > f.maxDistanceKm) {
        return false;
      }
      if (f.roomTypes.isNotEmpty && !f.roomTypes.contains(r.roomType)) {
        return false;
      }
      return true;
    }).toList();

    int secondary(Room a, Room b) {
      switch (f.sort) {
        case 'price':
          return a.rentUsd.compareTo(b.rentUsd);
        case 'distance':
          return a.distanceKm.compareTo(b.distanceKm);
        default:
          if (a.verified != b.verified) return a.verified ? -1 : 1;
          return (b.createdAt ?? DateTime(2000))
              .compareTo(a.createdAt ?? DateTime(2000));
      }
    }

    // Premium listings always rank first.
    list.sort((a, b) {
      if (a.isPremiumActive != b.isPremiumActive) {
        return a.isPremiumActive ? -1 : 1;
      }
      return secondary(a, b);
    });
    return list;
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<RoomFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _FilterSheet(initial: _filters.copy()),
    );
    if (result != null) setState(() => _filters = result);
  }

  void _clearAll() {
    setState(() {
      _filters = RoomFilters();
      _city = 'All';
      _search.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<SessionProvider>().appUser;
    final firstName = (me?.name ?? '').split(' ').first;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hi $firstName 👋',
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.muted,
                    fontWeight: FontWeight.w500)),
            const Text('Find your next home'),
          ],
        ),
        toolbarHeight: 64,
        actions: const [NotificationBell(), SizedBox(width: 6)],
      ),
      body: StreamBuilder<List<Room>>(
        stream: _stream,
        builder: (context, snap) {
          final rooms = _apply(snap.data ?? const []);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: 'Search city or campus',
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _search.text.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.close_rounded),
                                  onPressed: () =>
                                      setState(() => _search.clear()),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Badge(
                      isLabelVisible: _filters.activeCount > 0,
                      label: Text('${_filters.activeCount}'),
                      child: IconButton.filledTonal(
                        tooltip: 'Filters',
                        style: IconButton.styleFrom(
                            minimumSize: const Size(50, 50)),
                        onPressed: _openFilters,
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final c in ['All', ...AppConstants.cities.keys])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c),
                          selected: _city == c,
                          onSelected: (_) => setState(() => _city = c),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        snap.hasData
                            ? '${rooms.length} verified ${rooms.length == 1 ? 'room' : 'rooms'}'
                            : 'Loading rooms…',
                        style: const TextStyle(
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500),
                      ),
                    ),
                    SegmentedButton<bool>(
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                          visualDensity: VisualDensity.compact),
                      segments: const [
                        ButtonSegment(
                            value: false,
                            icon: Icon(Icons.view_agenda_outlined, size: 18),
                            label: Text('List')),
                        ButtonSegment(
                            value: true,
                            icon: Icon(Icons.map_outlined, size: 18),
                            label: Text('Map')),
                      ],
                      selected: {_mapView},
                      onSelectionChanged: (s) =>
                          setState(() => _mapView = s.first),
                    ),
                  ],
                ),
              ),
              Expanded(child: _results(snap, rooms)),
            ],
          );
        },
      ),
    );
  }

  Widget _results(AsyncSnapshot<List<Room>> snap, List<Room> rooms) {
    if (snap.hasError) return ErrorView(snap.error!);
    if (!snap.hasData) return const SkeletonList(height: 250, count: 3);
    if (rooms.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No rooms match your filters',
        message: 'Try widening your budget, distance or choosing another city.',
        action: OutlinedButton.icon(
          onPressed: _clearAll,
          icon: const Icon(Icons.filter_alt_off_outlined),
          label: const Text('Clear filters'),
        ),
      );
    }
    if (_mapView) return _RoomsMap(rooms: rooms);
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: rooms.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, i) => RoomCard(
          room: rooms[i],
          onTap: () => RoomDetailsScreen.open(context, rooms[i].id),
        ),
      ),
    );
  }
}

class _RoomsMap extends StatelessWidget {
  final List<Room> rooms;
  const _RoomsMap({required this.rooms});

  @override
  Widget build(BuildContext context) {
    final points = rooms.map((r) => LatLng(r.lat, r.lng)).toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        child: FlutterMap(
          key: ValueKey(rooms.map((r) => r.id).join()),
          options: MapOptions(
            initialCameraFit: CameraFit.coordinates(
              coordinates: points,
              padding: const EdgeInsets.all(60),
              maxZoom: 14,
            ),
          ),
          children: [
            osmTileLayer(),
            MarkerLayer(
              markers: [
                for (final r in rooms)
                  Marker(
                    point: LatLng(r.lat, r.lng),
                    width: 96,
                    height: 34,
                    child: GestureDetector(
                      onTap: () => RoomDetailsScreen.open(context, r.id),
                      child: _PricePin(room: r),
                    ),
                  ),
              ],
            ),
            const OsmAttribution(),
          ],
        ),
      ),
    );
  }
}

class _PricePin extends StatelessWidget {
  final Room room;
  const _PricePin({required this.room});

  @override
  Widget build(BuildContext context) {
    final color = room.flagged
        ? AppColors.danger
        : (room.isPremiumActive ? AppColors.premium : AppColors.primary);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: AppTheme.softShadow,
        ),
        child: Text(formatMoney(room.rent, room.currency),
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final RoomFilters initial;
  const _FilterSheet({required this.initial});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late RoomFilters f = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('Filters',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: () => setState(() => f = RoomFilters()),
                child: const Text('Reset'),
              ),
            ],
          ),
          _label('Max rent',
              f.maxRentUsd >= RoomFilters.anyRent ? 'Any' : '≈ ${formatUsd(f.maxRentUsd)}/mo'),
          Slider(
            value: f.maxRentUsd,
            min: 300,
            max: RoomFilters.anyRent,
            divisions: 27,
            onChanged: (v) => setState(() => f.maxRentUsd = v),
          ),
          _label('Max deposit',
              f.maxDepositUsd >= RoomFilters.anyDeposit ? 'Any' : '≈ ${formatUsd(f.maxDepositUsd)}'),
          Slider(
            value: f.maxDepositUsd,
            min: 200,
            max: RoomFilters.anyDeposit,
            divisions: 38,
            onChanged: (v) => setState(() => f.maxDepositUsd = v),
          ),
          _label(
              'Max distance to campus',
              f.maxDistanceKm >= RoomFilters.anyDistance
                  ? 'Any'
                  : '${f.maxDistanceKm.toStringAsFixed(1)} km'),
          Slider(
            value: f.maxDistanceKm,
            min: 0.5,
            max: RoomFilters.anyDistance,
            divisions: 39,
            onChanged: (v) => setState(() => f.maxDistanceKm = v),
          ),
          const SizedBox(height: 6),
          const Text('Room type', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in AppConstants.roomTypes)
                FilterChip(
                  label: Text(capitalize(t)),
                  selected: f.roomTypes.contains(t),
                  onSelected: (s) => setState(
                      () => s ? f.roomTypes.add(t) : f.roomTypes.remove(t)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Sort by', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final s in const [
                ('recommended', 'Recommended'),
                ('price', 'Lowest price'),
                ('distance', 'Closest to campus'),
              ])
                ChoiceChip(
                  label: Text(s.$2),
                  selected: f.sort == s.$1,
                  onSelected: (_) => setState(() => f.sort = s.$1),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Rents are compared in USD using approximate exchange rates. Premium listings are always shown first.',
            style: TextStyle(color: AppColors.muted, fontSize: 11.5),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context, f),
            child: const Text('Show rooms'),
          ),
        ],
      ),
    );
  }

  Widget _label(String title, String value) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Expanded(
                child: Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            Text(value,
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
