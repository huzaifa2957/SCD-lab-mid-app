import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';
import '../../widgets/notification_bell.dart';
import '../common/account_widgets.dart';
import '../common/reviews.dart';
import 'lifestyle_screen.dart';

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final u = context.watch<SessionProvider>().appUser;
    if (u == null) return const SizedBox.shrink();
    final l = u.lifestyle;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: const [NotificationBell()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          ProfileHeader(user: u),
          SectionTitle(
            'Lifestyle profile',
            trailing: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LifestyleScreen())),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(l.isComplete ? 'Edit' : 'Set up'),
            ),
          ),
          if (!l.isComplete)
            Card(
              color: AppColors.indigo.withValues(alpha: 0.06),
              child: ListTile(
                leading: const Icon(Icons.auto_awesome_rounded,
                    color: AppColors.indigo),
                title: const Text('Complete your lifestyle profile'),
                subtitle:
                    const Text('Needed for accurate roommate matching.'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const LifestyleScreen())),
              ),
            )
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _row(Icons.school_outlined, l.course, l.university),
                    _row(Icons.location_city_rounded, l.city.isEmpty ? '—' : l.city,
                        'Budget ${formatUsd(l.budget)}/mo'),
                    _row(Icons.bedtime_outlined, capitalize(l.sleepSchedule),
                        'Cleanliness ${l.cleanliness}/5'),
                    _row(Icons.restaurant_outlined, capitalize(l.diet),
                        capitalize(l.smoking)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final lang in l.languages)
                          Pill(lang,
                              icon: Icons.translate_rounded,
                              color: AppColors.indigo),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 14),
          AccountSection(user: u),
          ReviewsSection(
              targetId: u.uid, targetName: u.name, allowWrite: false),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String title, String sub) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(sub,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12.5)),
                ],
              ),
            ),
          ],
        ),
      );
}
