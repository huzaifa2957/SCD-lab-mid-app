import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/session_provider.dart';
import '../../services/seed_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../widgets/common.dart';
import '../admin/admin_shell.dart';
import '../auth/auth_screen.dart';
import '../auth/verify_email_screen.dart';
import '../landlord/landlord_shell.dart';
import '../student/student_shell.dart';

/// Decides which screen to show: splash → auth → verify email → role home.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool _ready = false;
  String _status = 'Loading…';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final minSplash = Future<void>.delayed(const Duration(milliseconds: 1400));
    try {
      if (await SeedService.needsSeed()) {
        if (mounted) setState(() => _status = 'Preparing demo data…');
        await SeedService.run(onProgress: (s) {
          if (mounted) setState(() => _status = s);
        }).timeout(const Duration(seconds: 60));
      }
    } catch (e) {
      debugPrint('Seeding skipped: $e');
    }
    await minSplash;
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    if (!_ready || session.initializing) return SplashScreen(status: _status);
    if (session.firebaseUser == null) return const AuthScreen();

    final user = session.appUser;
    if (user == null) {
      return Scaffold(
        body: session.profileLoading
            ? const LoadingView(message: 'Loading your profile…')
            : EmptyState(
                icon: Icons.person_search_rounded,
                title: 'Setting up your account…',
                message:
                    'If this takes more than a few seconds, sign out and log in again.',
                action: OutlinedButton(
                    onPressed: session.signOut, child: const Text('Sign out')),
              ),
      );
    }
    if (!user.isDemo && !session.emailVerified) {
      return const VerifyEmailScreen();
    }
    if (user.isAdmin) return const AdminShell();
    if (user.isLandlord) return const LandlordShell();
    return const StudentShell();
  }
}

class SplashScreen extends StatelessWidget {
  final String status;
  const SplashScreen({super.key, this.status = ''});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.7, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutBack,
                builder: (_, s, child) =>
                    Transform.scale(scale: s, child: child),
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(Icons.home_work_rounded,
                      size: 52, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: 22),
              const Text(AppConstants.appName,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(AppConstants.tagline,
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 40),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              ),
              const SizedBox(height: 12),
              Text(status,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
