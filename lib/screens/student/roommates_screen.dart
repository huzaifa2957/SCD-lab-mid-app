import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/session_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/matching_service.dart';
import '../../services/payment_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';
import '../../widgets/notification_bell.dart';
import '../../widgets/payment_sheet.dart';
import '../../widgets/score_ring.dart';
import '../common/user_profile_screen.dart';
import 'lifestyle_screen.dart';

class RoommatesScreen extends StatelessWidget {
  const RoommatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<SessionProvider>().appUser;
    if (me == null) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Roommates'),
        actions: const [NotificationBell()],
      ),
      body: me.matchingUnlocked ? _Matches(me: me) : _Locked(me: me),
    );
  }
}

class _Locked extends StatelessWidget {
  final AppUser me;
  const _Locked({required this.me});

  Future<void> _unlock(BuildContext context) async {
    final ok = await showPaymentSheet(
      context,
      userId: me.uid,
      amount: AppConstants.matchingPrice,
      type: PaymentType.matchingUnlock,
      title: 'Unlock AI Matching',
      description: 'One-time payment, lifetime access',
    );
    if (!ok) return;
    try {
      await FirestoreService.instance
          .updateUser(me.uid, {'matchingUnlocked': true});
      await FirestoreService.instance.notify(
          me.uid,
          'AI Matching unlocked 🎉',
          'You can now see your compatibility with other students.',
          'payment');
      if (context.mounted) showSnack(context, 'AI Matching unlocked!');
    } catch (e) {
      if (context.mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    const fakes = [
      ('Sara M.', 'MSc Computer Science', 92),
      ('Leo K.', 'MBA', 81),
      ('Amara O.', 'MA Economics', 74),
      ('Chen W.', 'MEng Civil', 63),
    ];
    return Stack(
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: IgnorePointer(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final f in fakes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: AppAvatar(name: f.$1, radius: 26),
                        title: Text(f.$1),
                        subtitle: Text(f.$2),
                        trailing: ScoreRing(f.$3, size: 52),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            color: AppColors.background.withValues(alpha: 0.35),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppTheme.softShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      gradient: AppColors.brandGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_rounded,
                        color: Colors.white, size: 34),
                  ),
                  const SizedBox(height: 16),
                  const Text('Find compatible roommates',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text(
                    'Our AI ranks students by lifestyle compatibility: sleep, cleanliness, smoking, diet, budget, languages and studies.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 14),
                  for (final b in const [
                    'Ranked matches with a 0-100% score',
                    'Category-by-category breakdown',
                    'Message matches instantly',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.success, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(b)),
                      ]),
                    ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _unlock(context),
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Unlock AI Matching – \$20'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text('One-time payment',
                      style: TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Matches extends StatefulWidget {
  final AppUser me;
  const _Matches({required this.me});

  @override
  State<_Matches> createState() => _MatchesState();
}

class _MatchesState extends State<_Matches> {
  late final Stream<List<AppUser>> _stream =
      FirestoreService.instance.studentsStream();
  String _city = 'Any';
  double _maxBudget = 2500;

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    return StreamBuilder<List<AppUser>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) return ErrorView(snap.error!);
        if (!snap.hasData) return const SkeletonList(height: 90);
        final scored = snap.data!
            .where((u) => u.uid != me.uid && !u.suspended)
            .where((u) => _city == 'Any' || u.lifestyle.city == _city)
            .where((u) => _maxBudget >= 2500 || u.lifestyle.budget <= _maxBudget)
            .map((u) => (u, MatchingService.compute(me.lifestyle, u.lifestyle)))
            .toList()
          ..sort((a, b) => b.$2.score.compareTo(a.$2.score));

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            if (!me.lifestyle.isComplete)
              Card(
                color: AppColors.indigo.withValues(alpha: 0.06),
                child: ListTile(
                  leading: const Icon(Icons.tips_and_updates_outlined,
                      color: AppColors.indigo),
                  title: const Text('Complete your lifestyle profile'),
                  subtitle: const Text('Better answers = more accurate matches'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const LifestyleScreen())),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final c in ['Any', ...AppConstants.cities.keys])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(c == 'Any' ? 'All cities' : c),
                        selected: _city == c,
                        onSelected: (_) => setState(() => _city = c),
                      ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                const Text('Max budget',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Expanded(
                  child: Slider(
                    value: _maxBudget,
                    min: 500,
                    max: 2500,
                    divisions: 20,
                    onChanged: (v) => setState(() => _maxBudget = v),
                  ),
                ),
                SizedBox(
                  width: 64,
                  child: Text(
                      _maxBudget >= 2500 ? 'Any' : formatUsd(_maxBudget),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
            Text('${scored.length} students ranked by compatibility',
                style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 10),
            if (scored.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: EmptyState(
                  icon: Icons.person_search_rounded,
                  title: 'No students match these filters',
                  message: 'Try another city or a higher budget.',
                ),
              ),
            for (final s in scored)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _MatchCard(user: s.$1, score: s.$2.score),
              ),
          ],
        );
      },
    );
  }
}

class _MatchCard extends StatelessWidget {
  final AppUser user;
  final int score;
  const _MatchCard({required this.user, required this.score});

  @override
  Widget build(BuildContext context) {
    final l = user.lifestyle;
    final p = user.privacy;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => UserProfileScreen.open(context, user.uid),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              AppAvatar(name: user.name, photo: user.photo, radius: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(user.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15.5)),
                      ),
                      if (user.isVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified_rounded,
                            size: 16, color: AppColors.success),
                      ],
                    ]),
                    if (p.showCourse && l.course.isNotEmpty)
                      Text(l.course,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13)),
                    if (p.showUniversity && l.university.isNotEmpty)
                      Text(l.university,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      if (l.city.isNotEmpty)
                        Pill(l.city, icon: Icons.place_outlined),
                      if (p.showBudget)
                        Pill('${formatUsd(l.budget)}/mo',
                            color: AppColors.indigo,
                            icon: Icons.account_balance_wallet_outlined),
                    ]),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ScoreRing(score, size: 58),
            ],
          ),
        ),
      ),
    );
  }
}
