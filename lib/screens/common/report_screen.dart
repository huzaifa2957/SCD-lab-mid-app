import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/common.dart';

/// Report a listing, user or conversation. targetType: room | user | conversation
class ReportScreen extends StatefulWidget {
  final String targetType;
  final String targetId;
  final String targetName;
  final String reportedUserId;

  const ReportScreen({
    super.key,
    required this.targetType,
    required this.targetId,
    required this.targetName,
    required this.reportedUserId,
  });

  static Future<void> open(BuildContext context,
      {required String targetType,
      required String targetId,
      required String targetName,
      required String reportedUserId}) {
    return Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ReportScreen(
        targetType: targetType,
        targetId: targetId,
        targetName: targetName,
        reportedUserId: reportedUserId,
      ),
    ));
  }

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _details = TextEditingController();
  String? _reason;
  bool _busy = false;
  bool _done = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final me = context.read<SessionProvider>().appUser;
    if (me == null) return;
    setState(() => _busy = true);
    try {
      await FirestoreService.instance.createReport(
        reporter: me,
        targetType: widget.targetType,
        targetId: widget.targetId,
        targetName: widget.targetName,
        reportedUserId: widget.reportedUserId,
        reason: _reason!,
        details: _details.text.trim(),
      );
      if (mounted) setState(() => _done = true);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _typeLabel => switch (widget.targetType) {
        'room' => 'listing',
        'conversation' => 'conversation',
        _ => 'user',
      };

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.verified_user_rounded,
          title: 'Thanks, report received',
          message:
              'Our moderation team will review "${widget.targetName}" shortly. You will get a notification with the outcome.',
          action: FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('Report $_typeLabel')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flag_rounded, color: AppColors.danger),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Reporting: ${widget.targetName}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Reason'),
              items: [
                for (final r in AppConstants.reportReasons)
                  DropdownMenuItem(value: r, child: Text(r)),
              ],
              onChanged: (v) => setState(() => _reason = v),
              validator: (v) => v == null ? 'Please choose a reason' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _details,
              minLines: 4,
              maxLines: 8,
              maxLength: 600,
              decoration: const InputDecoration(
                labelText: 'Details',
                hintText: 'Tell us what happened…',
                alignLabelWithHint: true,
              ),
              validator: (v) => (v == null || v.trim().length < 10)
                  ? 'Please add at least 10 characters'
                  : null,
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: const Text('Submit report'),
            ),
          ],
        ),
      ),
    );
  }
}
