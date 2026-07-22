import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/app_environment.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/app_controller.dart';
import '../../widgets/branded_logo.dart';
import '../dashboard/home_shell.dart';
import 'auth_visuals.dart';
import 'password_reset_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    required this.controller,
    this.startInSignUp = false,
    super.key,
  });

  final AppController controller;
  final bool startInSignUp;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _handledAuthNavigation = false;
  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    _isSignUp = widget.startInSignUp;
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
    widget.controller.authController.addListener(_handleAuthStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleAuthStateChanged();
    });
  }

  @override
  void dispose() {
    _ambientController.dispose();
    widget.controller.authController.removeListener(_handleAuthStateChanged);
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleAuthStateChanged() async {
    if (!mounted || _handledAuthNavigation) {
      return;
    }

    final auth = widget.controller.authController;
    if (auth.isPasswordRecovery) {
      _handledAuthNavigation = true;
      await Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => PasswordResetScreen(controller: widget.controller),
        ),
        (route) => false,
      );
      return;
    }

    if (!auth.isSignedIn || _isSignUp) {
      return;
    }

    _handledAuthNavigation = true;
    await widget.controller.syncFromCloudOnLaunch();
    if (!mounted) {
      return;
    }

    if (!widget.controller.onboardingComplete) {
      await widget.controller.setOnboardingComplete();
      if (!mounted) {
        return;
      }
    }

    final next = HomeShell(controller: widget.controller);
    await Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => next),
      (route) => false,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final auth = widget.controller.authController;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final emailRedirectTo = kIsWeb ? Uri.base.origin : null;

    if (_isSignUp) {
      await auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: emailRedirectTo,
      );
    } else {
      await auth.signIn(email: email, password: password);
    }

    if (!mounted) {
      return;
    }

    if (_isSignUp && auth.errorMessage == null && !auth.isSignedIn) {
      setState(() => _isSignUp = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            auth.infoMessage ??
                'Account created. Sign in after confirming your email.',
          ),
        ),
      );
      return;
    }

    if (!auth.isSignedIn) {
      return;
    }

    if (_handledAuthNavigation) {
      return;
    }

    await _handleAuthStateChanged();
  }

  Future<void> _sendResetEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      widget.controller.authController.clearMessages();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter your email first.')));
      return;
    }

    String? redirectTo;
    if (kIsWeb) {
      redirectTo = Uri.parse(
        Uri.base.origin,
      ).replace(queryParameters: const {'mode': 'recovery'}).toString();
    }

    await widget.controller.authController.sendPasswordResetEmail(
      email: email,
      redirectTo: redirectTo,
    );
  }

  Future<void> _continueWithGoogle() async {
    await widget.controller.authController.signInWithGoogle(
      redirectTo: AppEnvironment.authRedirectTo,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.controller.authController;
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF7F9FC), Color(0xFFE9EEF7)],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  Positioned(
                    top: -60,
                    right: -30,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 120,
                    left: -40,
                    child: Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF8FA8CF).withValues(alpha: 0.12),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: IgnorePointer(
                      child: FinanceAuthBackdrop(
                        progress: _ambientController,
                        isSignUp: _isSignUp,
                      ),
                    ),
                  ),
                  Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const BrandedLogo(height: 25),
                                const SizedBox(height: 18),
                                Container(
                                  padding: const EdgeInsets.all(18),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppColors.primaryDark,
                                        AppColors.primary.withValues(
                                          alpha: 0.92,
                                        ),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _isSignUp
                                                  ? 'Create your workspace'
                                                  : 'Welcome back',
                                              style: theme.textTheme.titleLarge
                                                  ?.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              _isSignUp
                                                  ? 'Start with cloud sync enabled so your records stay available on every device.'
                                                  : 'Sign in to keep expenses, budgets, debts, and settings in sync.',
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: Colors.white
                                                        .withValues(
                                                          alpha: 0.84,
                                                        ),
                                                    height: 1.45,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 22),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: auth.isBusy || !_isSignUp
                                              ? null
                                              : () => setState(() {
                                                  _isSignUp = false;
                                                  _confirmPasswordController
                                                      .clear();
                                                }),
                                          style: FilledButton.styleFrom(
                                            elevation: 0,
                                            backgroundColor: !_isSignUp
                                                ? AppColors.primary
                                                : Colors.transparent,
                                            foregroundColor: !_isSignUp
                                                ? Colors.white
                                                : AppColors.textSecondary,
                                            disabledBackgroundColor: !_isSignUp
                                                ? AppColors.primary
                                                : Colors.transparent,
                                            disabledForegroundColor: !_isSignUp
                                                ? Colors.white
                                                : AppColors.textSecondary,
                                          ),
                                          child: const Text('Sign in'),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: FilledButton(
                                          onPressed: auth.isBusy || _isSignUp
                                              ? null
                                              : () => setState(() {
                                                  _isSignUp = true;
                                                }),
                                          style: FilledButton.styleFrom(
                                            elevation: 0,
                                            backgroundColor: _isSignUp
                                                ? AppColors.primary
                                                : Colors.transparent,
                                            foregroundColor: _isSignUp
                                                ? Colors.white
                                                : AppColors.textSecondary,
                                            disabledBackgroundColor: _isSignUp
                                                ? AppColors.primary
                                                : Colors.transparent,
                                            disabledForegroundColor: _isSignUp
                                                ? Colors.white
                                                : AppColors.textSecondary,
                                          ),
                                          child: const Text('Create account'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 22),
                                Text(
                                  _isSignUp
                                      ? 'Account details'
                                      : 'Account access',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _isSignUp
                                      ? 'Use an email address you can verify. You can also continue with Google below.'
                                      : 'Enter your email and password, or continue with Google.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Form(
                                  key: _formKey,
                                  child: Column(
                                    children: [
                                      TextFormField(
                                        controller: _emailController,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        decoration: const InputDecoration(
                                          labelText: 'Email address',
                                          prefixIcon: Icon(
                                            Icons.mail_outline_rounded,
                                          ),
                                        ),
                                        validator: (value) {
                                          final email = value?.trim() ?? '';
                                          if (email.isEmpty ||
                                              !email.contains('@')) {
                                            return 'Enter a valid email address.';
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: _passwordController,
                                        obscureText: _obscurePassword,
                                        decoration: InputDecoration(
                                          labelText: _isSignUp
                                              ? 'Create password'
                                              : 'Password',
                                          prefixIcon: const Icon(
                                            Icons.lock_outline_rounded,
                                          ),
                                          suffixIcon: IconButton(
                                            onPressed: () {
                                              setState(() {
                                                _obscurePassword =
                                                    !_obscurePassword;
                                              });
                                            },
                                            icon: Icon(
                                              _obscurePassword
                                                  ? Icons.visibility_off_rounded
                                                  : Icons.visibility_rounded,
                                            ),
                                          ),
                                        ),
                                        validator: (value) {
                                          if ((value ?? '').length < 6) {
                                            return 'Use at least 6 characters.';
                                          }
                                          return null;
                                        },
                                      ),
                                      if (_isSignUp) ...[
                                        const SizedBox(height: 16),
                                        TextFormField(
                                          controller:
                                              _confirmPasswordController,
                                          obscureText: _obscureConfirmPassword,
                                          decoration: InputDecoration(
                                            labelText: 'Confirm password',
                                            prefixIcon: const Icon(
                                              Icons.verified_user_outlined,
                                            ),
                                            suffixIcon: IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  _obscureConfirmPassword =
                                                      !_obscureConfirmPassword;
                                                });
                                              },
                                              icon: Icon(
                                                _obscureConfirmPassword
                                                    ? Icons
                                                          .visibility_off_rounded
                                                    : Icons.visibility_rounded,
                                              ),
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value !=
                                                _passwordController.text) {
                                              return 'Passwords do not match.';
                                            }
                                            return null;
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (auth.errorMessage != null) ...[
                                  const SizedBox(height: 16),
                                  AuthStatusBanner(
                                    icon: Icons.error_outline_rounded,
                                    message: auth.errorMessage!,
                                    background: const Color(0xFFFBEAEA),
                                    foreground: AppColors.danger,
                                  ),
                                ],
                                if (auth.infoMessage != null) ...[
                                  const SizedBox(height: 16),
                                  AuthStatusBanner(
                                    icon: Icons.mark_email_read_rounded,
                                    message: auth.infoMessage!,
                                    background: const Color(0xFFE9F7F1),
                                    foreground: AppColors.success,
                                  ),
                                ],
                                const SizedBox(height: 22),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: auth.isBusy ? null : _submit,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                    ),
                                    child: Text(
                                      auth.isBusy
                                          ? 'Please wait...'
                                          : _isSignUp
                                          ? 'Create account'
                                          : 'Sign in',
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    const Expanded(child: Divider()),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text(
                                        'OR CONTINUE WITH',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: AppColors.textSecondary,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.1,
                                            ),
                                      ),
                                    ),
                                    const Expanded(child: Divider()),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: auth.isBusy
                                        ? null
                                        : _continueWithGoogle,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      backgroundColor: Colors.white,
                                      side: const BorderSide(
                                        color: AppColors.border,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 30,
                                          height: 30,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: AppColors.background,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: AppColors.border,
                                            ),
                                          ),
                                          child: Text(
                                            'G',
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w900,
                                                  color: AppColors.primary,
                                                ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          _isSignUp
                                              ? 'Create account with Google'
                                              : 'Sign in with Google',
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (!_isSignUp) ...[
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: auth.isBusy
                                          ? null
                                          : _sendResetEmail,
                                      child: const Text('Forgot password?'),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Center(
                                  child: TextButton(
                                    onPressed: auth.isBusy
                                        ? null
                                        : () => setState(() {
                                            _isSignUp = !_isSignUp;
                                            _confirmPasswordController.clear();
                                          }),
                                    child: Text(
                                      _isSignUp
                                          ? 'Already have an account? Sign in'
                                          : 'Need an account? Create one',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
