import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/social.dart';
import '../../providers/session_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';

/// Opens the review form if the two users have chatted; otherwise explains why not.
Future<void> startReview(BuildContext context,
    {required String targetId, required String targetName}) async {
  final me = context.read<SessionProvider>().appUser;
  if (me == null) return;
  if (me.uid == targetId) return;
  final allowed =
      await FirestoreService.instance.haveConversation(me.uid, targetId);
  if (!context.mounted) return;
  if (!allowed) {
    showSnack(context,
        'You can only review people you have connected with through chat.',
        error: true);
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ReviewSheet(targetId: targetId, targetName: targetName),
  );
}

class _ReviewSheet extends StatefulWidget {
  final String targetId;
  final String targetName;
  const _ReviewSheet({required this.targetId, required this.targetName});

  @override
  State<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<_ReviewSheet> {
  int _rating = 0;
  final _text = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      showSnack(context, 'Please choose a star rating', error: true);
      return;
    }
    if (_text.text.trim().length < 5) {
      showSnack(context, 'Please write a short review', error: true);
      return;
    }
    final me = context.read<SessionProvider>().appUser!;
    setState(() => _busy = true);
    try {
      await FirestoreService.instance.addReview(
        author: me,
        targetId: widget.targetId,
        targetName: widget.targetName,
        rating: _rating,
        text: _text.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      showSnack(context, 'Thanks! Your review was posted.');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Review ${widget.targetName}',
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              return IconButton(
                iconSize: 38,
                onPressed: () => setState(() => _rating = i + 1),
                icon: Icon(
                  i < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: AppColors.premium,
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _text,
            minLines: 3,
            maxLines: 5,
            maxLength: 400,
            decoration:
                const InputDecoration(hintText: 'Share your experience…'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Post review'),
          ),
        ],
      ),
    );
  }
}

/// Live list of reviews for a user, with average rating header.
class ReviewsSection extends StatelessWidget {
  final String targetId;
  final String targetName;
  final bool allowWrite;

  const ReviewsSection({
    super.key,
    required this.targetId,
    required this.targetName,
    this.allowWrite = true,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Review>>(
      stream: FirestoreService.instance.reviewsForStream(targetId),
      builder: (context, snap) {
        final list = snap.data ?? const <Review>[];
        final avg = list.isEmpty
            ? 0.0
            : list.map((r) => r.rating).reduce((a, b) => a + b) / list.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              'Reviews',
              trailing: allowWrite
                  ? TextButton.icon(
                      onPressed: () => startReview(context,
                          targetId: targetId, targetName: targetName),
                      icon: const Icon(Icons.rate_review_outlined, size: 18),
                      label: const Text('Write review'),
                    )
                  : null,
            ),
            if (list.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Text(avg.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    StarRow(avg, size: 20),
                    const SizedBox(width: 8),
                    Text('(${list.length})',
                        style: const TextStyle(color: AppColors.muted)),
                  ],
                ),
              ),
            if (!snap.hasData)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (list.isEmpty)
              const Text('No reviews yet.',
                  style: TextStyle(color: AppColors.muted))
            else
              ...list.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                AppAvatar(name: r.authorName, radius: 16),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(r.authorName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                ),
                                StarRow(r.rating.toDouble(), size: 14),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(r.text),
                            const SizedBox(height: 4),
                            Text(formatDate(r.createdAt),
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  )),
          ],
        );
      },
    );
  }
}
