import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';
import '../utils/constants.dart';

TileLayer osmTileLayer() => TileLayer(
      urlTemplate: AppConstants.osmTiles,
      userAgentPackageName: AppConstants.userAgent,
    );

class OsmAttribution extends StatelessWidget {
  const OsmAttribution({super.key});
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.bottomLeft,
        child: Container(
          margin: const EdgeInsets.all(6),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(6),
          ),
          child: const Text('© OpenStreetMap contributors',
              style: TextStyle(fontSize: 10, color: AppColors.muted)),
        ),
      );
}

class MapPin extends StatelessWidget {
  final Color color;
  final IconData icon;
  const MapPin({super.key, this.color = AppColors.primary, this.icon = Icons.home_rounded});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: AppTheme.softShadow,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      );
}

/// Full-screen map where the user taps to choose a location.
class LocationPickerScreen extends StatefulWidget {
  final String title;
  final LatLng initial;
  final bool hasInitialPoint;

  const LocationPickerScreen({
    super.key,
    required this.title,
    required this.initial,
    this.hasInitialPoint = false,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  LatLng? _picked;

  @override
  void initState() {
    super.initState();
    if (widget.hasInitialPoint) _picked = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: widget.initial,
              initialZoom: 13,
              onTap: (_, p) => setState(() => _picked = p),
            ),
            children: [
              osmTileLayer(),
              if (_picked != null)
                MarkerLayer(markers: [
                  Marker(
                    point: _picked!,
                    width: 40,
                    height: 40,
                    child: const MapPin(icon: Icons.place_rounded),
                  ),
                ]),
              const OsmAttribution(),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: AppTheme.softShadow,
              ),
              child: Text(
                _picked == null
                    ? 'Tap on the map to set the location'
                    : 'Selected: ${_picked!.latitude.toStringAsFixed(5)}, ${_picked!.longitude.toStringAsFixed(5)}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed:
                _picked == null ? null : () => Navigator.pop(context, _picked),
            child: const Text('Use this location'),
          ),
        ),
      ),
    );
  }
}
