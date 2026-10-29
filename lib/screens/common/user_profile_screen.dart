import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/session_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/matching_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';
import '../../widgets/score_ring.dart';
import 'chat_screens.dart';
import 'report_screen.dart';
import 'reviews.dart';

/// Public profile of another user (roommate or landlord).
class UserProfileScreen extends StatelessWidget {
  final String userId;
  const UserProfileScreen({super.key, required this.userId});

  static Future<void> open(BuildContext context, String userId) {
    return Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => UserProfileScreen(userId: userId)));
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<SessionProvider>().appUser;
    return StreamBuilder<AppUser?>(
      stream: FirestoreService.instance.userStream(userId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(appBar: AppBar(), body: ErrorView(snap.error!));
        }
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(appBar: AppBar(), body: const LoadingView());
        }
        final u = snap.data;
        if (u == null || me == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(
                icon: Icons.person_off_outlined,
                title: 'Profile not available',
                message: 'This account may have been deleted.'),
          );
        }
        final isMe = u.uid == me.uid;
        final showMatch =
            me.isStudent && u.isStudent && !isMe && me.matchingUnlocked;
        final match =
            showMatch ? MatchingService.compute(me.lifestyle, u.lifestyle) : null;
        return Scaffold(
          appBar: AppBar(
            title: Text(u.isLandlord ? 'Landlord' : 'Profile'),
            actions: [
              if (!isMe)
                IconButton(
                  tooltip: 'Report user',
                  icon: const Icon(Icons.flag_outlined),
                  onPressed: () => ReportScreen.open(context,
                      targetType: 'user',
                      targetId: u.uid,
                      targetName: u.name,
                      reportedUserId: u.uid),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            children: [
              _header(u, match),
              if (u.lifestyle.bio.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(u.lifestyle.bio,
                    style: const TextStyle(color: AppColors.muted)),
              ],
              if (u.isStudent) ..._lifestyle(u),
              if (match != null) ..._breakdown(match),
              ReviewsSection(
                  targetId: u.uid, targetName: u.name, allowWrite: !isMe),
            ],
          ),
          bottomNavigationBar: isMe
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: FilledButton.icon(
                      onPressed: () => openChatWith(context,
                          otherId: u.uid,
                          otherName: u.name,
                          otherRole: u.role),
                      icon: const Icon(Icons.chat_bubble_outline_rounded),
                      label: Text('Message ${u.name.split(' ').first}'),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _header(AppUser u, MatchResult? match) {
    final l = u.lifestyle;
    final p = u.privacy;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          AppAvatar(name: u.name, photo: u.photo, radius: 34),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(u.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 18)),
                const SizedBox(height: 4),
                if (u.isStudent && p.showCourse && l.course.isNotEmpty)
                  Text(l.course,
                      style: const TextStyle(color: AppColors.muted)),
                if (u.isStudent && p.showUniversity && l.university.isNotEmpty)
                  Text(l.university,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12.5)),
                if (u.isLandlord)
                  Text('Member since ${formatDate(u.createdAt)}',
                      style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  if (u.isVerified) const VerifiedBadge(),
                  Pill(capitalize(u.role),
                      color: u.isLandlord ? AppColors.indigo : AppColors.primary),
                ]),
              ],
            ),
          ),
          if (match != null) ScoreRing(match.score, size: 64),
        ],
      ),
    );
  }

  List<Widget> _lifestyle(AppUser u) {
    final l = u.lifestyle;
    final p = u.privacy;
    final tiles = <Widget>[
      if (l.city.isNotEmpty)
        InfoTile(icon: Icons.location_city_rounded, label: 'City', value: l.city),
      if (p.showBudget)
        InfoTile(
            icon: Icons.account_balance_wallet_outlined,
            label: 'Budget',
            value: '${formatUsd(l.budget)}/mo'),
      if (p.showLifestyle) ...[
        InfoTile(
            icon: Icons.bedtime_outlined,
            label: 'Sleep',
            value: capitalize(l.sleepSchedule)),
        InfoTile(
            icon: Icons.cleaning_services_outlined,
            label: 'Cleanliness',
            value: '${l.cleanliness} / 5'),
        InfoTile(
            icon: Icons.restaurant_outlined,
            label: 'Diet',
            value: capitalize(l.diet)),
        InfoTile(
            icon: Icons.smoke_free_rounded,
            label: 'Smoking',
            value: capitalize(l.smoking)),
      ],
    ];
    return [
      const SectionTitle('Lifestyle'),
      if (tiles.isEmpty)
        const Text('This student keeps their lifestyle details private.',
            style: TextStyle(color: AppColors.muted))
      else
        LayoutBuilder(builder: (context, c) {
          final w = (c.maxWidth - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [for (final t in tiles) SizedBox(width: w, child: t)],
          );
        }),
      if (p.showLanguages && l.languages.isNotEmpty) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final lang in l.languages)
              Pill(lang, icon: Icons.translate_rounded, color: AppColors.indigo),
          ],
        ),
      ],
    ];
  }

  List<Widget> _breakdown(MatchResult m) => [
        const SectionTitle('Compatibility breakdown'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (final e in MatchingService.weights.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: Text(e.key,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600))),
                            Text('${((m.breakdown[e.key] ?? 0) * 100).round()}%',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            Text('  · weight ${(e.value * 100).round()}%',
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: m.breakdown[e.key] ?? 0,
                            minHeight: 8,
                            backgroundColor: AppColors.border,
                            valueColor: AlwaysStoppedAnimation(scoreColor(
                                ((m.breakdown[e.key] ?? 0) * 100).round())),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Text(
                  'Scores use lifestyle answers only – never ethnicity, nationality, religion or gender.',
                  style: TextStyle(color: AppColors.muted, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ),
      ];
}
