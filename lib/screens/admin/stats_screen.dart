import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/room.dart';
import '../../models/social.dart';
import '../../services/firestore_service.dart';
import '../../services/payment_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final fs = FirestoreService.instance;
    return StreamBuilder<List<AppUser>>(
      stream: fs.allUsersStream(),
      builder: (context, uSnap) => StreamBuilder<List<Room>>(
        stream: fs.allRoomsStream(),
        builder: (context, rSnap) => StreamBuilder<List<Payment>>(
          stream: fs.paymentsStream(),
          builder: (context, pSnap) {
            final err = uSnap.error ?? rSnap.error ?? pSnap.error;
            if (err != null) return ErrorView(err);
            if (!uSnap.hasData || !rSnap.hasData || !pSnap.hasData) {
              return const LoadingView(message: 'Crunching numbers…');
            }
            return _Dashboard(
                users: uSnap.data!, rooms: rSnap.data!, payments: pSnap.data!);
          },
        ),
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  final List<AppUser> users;
  final List<Room> rooms;
  final List<Payment> payments;
  const _Dashboard(
      {required this.users, required this.rooms, required this.payments});

  @override
  Widget build(BuildContext context) {
    final students = users.where((u) => u.isStudent).length;
    final landlords = users.where((u) => u.isLandlord).length;
    final approved = rooms.where((r) => r.status == RoomStatus.approved).length;
    final pending = rooms.where((r) => r.status == RoomStatus.pending).length;
    final unlocked = users.where((u) => u.matchingUnlocked).length;
    final ok = payments.where((p) => p.status == 'succeeded').toList();
    final revenue = ok.fold<double>(0, (s, p) => s + p.amount);
    final suspended = users.where((u) => u.suspended).length;

    final cards = [
      ('Total users', '${users.length}', Icons.people_alt_rounded, AppColors.primary),
      ('Students', '$students', Icons.school_rounded, AppColors.indigo),
      ('Landlords', '$landlords', Icons.apartment_rounded, const Color(0xFF0284C7)),
      ('Live listings', '$approved', Icons.home_work_rounded, AppColors.success),
      ('Pending listings', '$pending', Icons.hourglass_top_rounded, AppColors.warning),
      ('Matches unlocked', '$unlocked', Icons.auto_awesome_rounded, const Color(0xFFDB2777)),
      ('Total revenue', formatUsd(revenue), Icons.payments_rounded, AppColors.success),
      ('Suspended', '$suspended', Icons.block_rounded, AppColors.danger),
    ];

    final revenueByType = <String, double>{
      PaymentType.matchingUnlock: 0,
      PaymentType.extraListing: 0,
      PaymentType.premiumBoost: 0,
    };
    for (final p in ok) {
      revenueByType[p.type] = (revenueByType[p.type] ?? 0) + p.amount;
    }
    final cities = AppConstants.cities.keys.toList();
    final perCity = [
      for (final c in cities)
        rooms.where((r) => r.city == c && r.status == RoomStatus.approved).length
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth > 700 ? 4 : 2;
          final w = (c.maxWidth - (cols - 1) * 10) / cols;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final card in cards)
                SizedBox(
                  width: w,
                  child: _StatCard(
                      label: card.$1,
                      value: card.$2,
                      icon: card.$3,
                      color: card.$4),
                ),
            ],
          );
        }),
        const SectionTitle('Live listings by city'),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
            child: SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: (perCity.fold<int>(0, (a, b) => a > b ? a : b) + 1)
                      .toDouble(),
                  gridData: const FlGridData(
                      show: true, drawVerticalLine: false, horizontalInterval: 1),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 1,
                        getTitlesWidget: (v, meta) => Text('${v.toInt()}',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.muted)),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= cities.length) {
                            return const SizedBox.shrink();
                          }
                          final name = cities[i];
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                                name.length > 7
                                    ? '${name.substring(0, 6)}.'
                                    : name,
                                style: const TextStyle(fontSize: 11)),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    for (var i = 0; i < cities.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: perCity[i].toDouble(),
                          width: 22,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6)),
                          gradient: AppColors.brandGradient,
                        ),
                      ]),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SectionTitle('Revenue by product'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: revenue == 0
                ? const Text('No revenue yet.')
                : Row(
                    children: [
                      SizedBox(
                        width: 150,
                        height: 150,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 34,
                            sections: [
                              for (final e in revenueByType.entries)
                                if (e.value > 0)
                                  PieChartSectionData(
                                    value: e.value,
                                    color: _typeColor(e.key),
                                    radius: 38,
                                    title:
                                        '${(e.value / revenue * 100).round()}%',
                                    titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700),
                                  ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final e in revenueByType.entries)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 5),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                        radius: 6,
                                        backgroundColor: _typeColor(e.key)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text(PaymentType.label(e.key),
                                            style:
                                                const TextStyle(fontSize: 13))),
                                    Text(formatUsd(e.value),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            const Divider(),
                            Text(
                                '${ok.length} successful · ${payments.length - ok.length} failed payments',
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  static Color _typeColor(String type) => switch (type) {
        PaymentType.matchingUnlock => AppColors.primary,
        PaymentType.extraListing => AppColors.indigo,
        _ => AppColors.premium,
      };
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800)),
                ),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
