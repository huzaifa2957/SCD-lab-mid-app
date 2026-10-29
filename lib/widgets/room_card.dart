import 'package:flutter/material.dart';

import '../models/room.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/geo.dart';
import 'app_image.dart';
import 'common.dart';

class RoomCard extends StatelessWidget {
  final Room room;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showStatus;

  const RoomCard({
    super.key,
    required this.room,
    this.onTap,
    this.trailing,
    this.showStatus = false,
  });

  @override
  Widget build(BuildContext context) {
    final photo = room.photos.isNotEmpty ? room.photos.first : '';
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: AppTheme.softShadow,
        border: room.isPremiumActive
            ? Border.all(color: AppColors.premium.withValues(alpha: 0.6), width: 1.4)
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 170,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(photo),
                    Positioned(
                      left: 10,
                      top: 10,
                      right: 10,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (room.isPremiumActive)
                            const PremiumBadge(solid: true),
                          if (room.verified) const VerifiedBadge(solid: true),
                          if (room.flagged)
                            const Pill('Flagged',
                                icon: Icons.warning_amber_rounded,
                                color: AppColors.danger,
                                solid: true),
                          if (showStatus) _solidStatus(room.status),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text.rich(TextSpan(children: [
                          TextSpan(
                            text: formatMoney(room.rent, room.currency),
                            style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColors.primary,
                                fontSize: 15),
                          ),
                          const TextSpan(
                              text: ' /mo',
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 11)),
                        ])),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(room.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 15)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.place_outlined,
                                  size: 14, color: AppColors.muted),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(room.address,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: AppColors.muted, fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              Pill(
                                '${formatKm(room.distanceKm)} to ${_shortCampus(room.campusName)}',
                                icon: Icons.school_outlined,
                                color: AppColors.indigo,
                              ),
                              Pill(capitalize(room.roomType),
                                  icon: Icons.bed_outlined,
                                  color: AppColors.primary),
                            ],
                          ),
                        ],
                      ),
                    ),
                    ?trailing,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _solidStatus(String status) =>
      Pill(capitalize(status), color: statusColor(status), solid: true);

  static String _shortCampus(String name) {
    final m = RegExp(r'\(([^)]+)\)').firstMatch(name);
    if (m != null) return m.group(1)!;
    return name.length > 22 ? '${name.substring(0, 20)}…' : name;
  }
}
