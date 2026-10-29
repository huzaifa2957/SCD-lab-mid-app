import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _checking = false;
  bool _sending = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    final session = context.read<SessionProvider>();
    try {
      await session.refreshEmailVerified();
      if (mounted && !session.emailVerified) {
        showSnack(context,
            'Not verified yet. Please click the link in your email first.',
            error: true);
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _sending = true);
    try {
      await context.read<SessionProvider>().auth.resendVerification();
      if (mounted) showSnack(context, 'Verification email sent again.');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final email = session.firebaseUser?.email ?? '';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.mark_email_unread_rounded,
                          size: 48, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('Verify your email',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Text(
                    'We sent a verification link to\n$email\n\nOpen the email, tap the link, then come back and press "I\'ve verified". Check your spam folder too.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: _checking ? null : _check,
                    icon: _checking
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.verified_rounded),
                    label: const Text("I've verified"),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _sending ? null : _resend,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Resend email'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: session.signOut,
                    child: const Text('Use a different account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
