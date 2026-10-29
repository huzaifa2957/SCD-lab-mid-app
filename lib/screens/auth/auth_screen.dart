import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/session_provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/constants.dart';
import '../../utils/validators.dart';
import '../../widgets/common.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  final _loginKey = GlobalKey<FormState>();
  final _signupKey = GlobalKey<FormState>();
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();
  final _name = TextEditingController();
  final _signupEmail = TextEditingController();
  final _signupPassword = TextEditingController();
  final _confirm = TextEditingController();
  String _role = UserRole.student;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = context.read<SessionProvider>();
      if (session.signOutReason != null) {
        setState(() => _error = session.signOutReason);
        session.clearSignOutReason();
      }
    });
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) setState(() => _error = null);
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final c in [
      _loginEmail,
      _loginPassword,
      _name,
      _signupEmail,
      _signupPassword,
      _confirm
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  AuthService get _auth => context.read<SessionProvider>().auth;

  Future<void> _run(Future<void> Function() action) async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _login() {
    if (!_loginKey.currentState!.validate()) return;
    _run(() => _auth.signIn(_loginEmail.text, _loginPassword.text));
  }

  void _signup() {
    if (!_signupKey.currentState!.validate()) return;
    _run(() => _auth.signUp(
          name: _name.text,
          email: _signupEmail.text,
          password: _signupPassword.text,
          role: _role,
        ));
  }

  Future<void> _forgotPassword() async {
    final ctrl = TextEditingController(text: _loginEmail.text);
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Enter your account email and we will send you a reset link.'),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Send link')),
        ],
      ),
    );
    if (email == null || !mounted) return;
    if (Validators.email(email) != null) {
      showSnack(context, 'Please enter a valid email address', error: true);
      return;
    }
    try {
      await _auth.sendPasswordReset(email);
      if (mounted) showSnack(context, 'Password reset email sent to $email');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e), error: true);
    }
  }

  void _fillDemo(String email) {
    _tabs.animateTo(0);
    setState(() {
      _loginEmail.text = email;
      _loginPassword.text = AppConstants.demoPassword;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const Center(child: BrandLogo(size: 68)),
                  const SizedBox(height: 14),
                  Text(AppConstants.appName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const Text(
                    'Safe, verified housing for international students',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppTheme.softShadow,
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: TabBar(
                            controller: _tabs,
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            indicator: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            labelColor: Colors.white,
                            unselectedLabelColor: AppColors.muted,
                            labelStyle:
                                const TextStyle(fontWeight: FontWeight.w600),
                            tabs: const [
                              Tab(text: 'Log In'),
                              Tab(text: 'Sign Up')
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (_error != null) _errorBanner(_error!),
                        AnimatedBuilder(
                          animation: _tabs,
                          builder: (_, _) =>
                              _tabs.index == 0 ? _loginForm() : _signupForm(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _demoAccounts(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorBanner(String text) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(
                child: Text(text,
                    style: const TextStyle(color: AppColors.danger))),
          ],
        ),
      );

  Widget _passwordField(TextEditingController c, String label,
      {String? helper,
      String? Function(String?)? validator,
      VoidCallback? onSubmit}) {
    return TextFormField(
      controller: c,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(_obscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      validator: validator,
      onFieldSubmitted: onSubmit == null ? null : (_) => onSubmit(),
    );
  }

  Widget _loginForm() {
    return Form(
      key: _loginKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _loginEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
                labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
            validator: Validators.email,
          ),
          const SizedBox(height: 12),
          _passwordField(_loginPassword, 'Password',
              validator: Validators.password, onSubmit: _login),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
                onPressed: _busy ? null : _forgotPassword,
                child: const Text('Forgot password?')),
          ),
          FilledButton(
            onPressed: _busy ? null : _login,
            child: _busy ? _spinner() : const Text('Log In'),
          ),
        ],
      ),
    );
  }

  Widget _signupForm() {
    return Form(
      key: _signupKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('I am a…', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: _roleCard(UserRole.student, Icons.school_rounded,
                      'Student', 'Find rooms & roommates')),
              const SizedBox(width: 10),
              Expanded(
                  child: _roleCard(UserRole.landlord, Icons.apartment_rounded,
                      'Landlord', 'List verified rooms')),
            ],
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline_rounded)),
            validator: Validators.name,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _signupEmail,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
                labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
            validator: Validators.email,
          ),
          const SizedBox(height: 12),
          _passwordField(_signupPassword, 'Password',
              helper: 'At least 6 characters', validator: Validators.password),
          const SizedBox(height: 12),
          _passwordField(_confirm, 'Confirm password',
              validator: (v) =>
                  v != _signupPassword.text ? 'Passwords do not match' : null),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _signup,
            child: _busy ? _spinner() : const Text('Create account'),
          ),
          const SizedBox(height: 8),
          const Text(
            'We will email you a verification link.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _roleCard(String role, IconData icon, String title, String sub) {
    final selected = _role == role;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _role = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.muted),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(sub,
                style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _spinner() => const SizedBox(
      width: 22,
      height: 22,
      child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white));

  Widget _demoAccounts() {
    const accounts = [
      ('student@demo.com', 'Student'),
      ('paid@demo.com', 'Student (paid)'),
      ('landlord@demo.com', 'Landlord'),
      ('admin@demo.com', 'Admin'),
    ];
    return Column(
      children: [
        const Text('Demo accounts (password Demo@123)',
            style: TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in accounts)
              ActionChip(
                label: Text(a.$2),
                avatar: const Icon(Icons.flash_on_rounded, size: 16),
                onPressed: () => _fillDemo(a.$1),
              ),
          ],
        ),
      ],
    );
  }
}
