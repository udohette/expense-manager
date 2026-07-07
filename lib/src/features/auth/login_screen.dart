import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/app_controller.dart';
import '../../widgets/branded_logo.dart';
import '../dashboard/home_shell.dart';
import '../onboarding/onboarding_screen.dart';
import 'password_reset_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _handledAuthNavigation = false;

  @override
  void initState() {
    super.initState();
    widget.controller.authController.addListener(_handleAuthStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleAuthStateChanged();
    });
  }

  @override
  void dispose() {
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

    final next = widget.controller.onboardingComplete
        ? HomeShell(controller: widget.controller)
        : OnboardingScreen(controller: widget.controller);
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
    String? redirectTo;
    if (kIsWeb) {
      redirectTo = Uri.base.origin;
    }
    await widget.controller.authController.signInWithGoogle(
      redirectTo: redirectTo,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.controller.authController;

    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        return Scaffold(
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const BrandedLogo(height: 44),
                          const SizedBox(height: 24),
                          Text(
                            _isSignUp ? 'Create your workspace' : 'Sign in',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Use the same account on every device so expenses, budgets, debts, and settings stay in sync.',
                            style: Theme.of(context).textTheme.bodyLarge
                                ?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                ),
                          ),
                          const SizedBox(height: 24),
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: Icon(
                                      Icons.mail_outline_rounded,
                                    ),
                                  ),
                                  validator: (value) {
                                    final email = value?.trim() ?? '';
                                    if (email.isEmpty || !email.contains('@')) {
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
                                    labelText: 'Password',
                                    prefixIcon: const Icon(
                                      Icons.lock_outline_rounded,
                                    ),
                                    suffixIcon: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
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
                                    controller: _confirmPasswordController,
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
                                              ? Icons.visibility_off_rounded
                                              : Icons.visibility_rounded,
                                        ),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value != _passwordController.text) {
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
                            Text(
                              auth.errorMessage!,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.danger),
                            ),
                          ],
                          if (auth.infoMessage != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              auth.infoMessage!,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.success),
                            ),
                          ],
                          const SizedBox(height: 24),
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
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: Text(
                                  'or',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: auth.isBusy ? null : _continueWithGoogle,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 18,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.textSecondary
                                            .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    child: Text(
                                      'G',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.primary,
                                          ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    _isSignUp
                                        ? 'Continue with Google'
                                        : 'Sign in with Google',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (!_isSignUp) ...[
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: auth.isBusy ? null : _sendResetEmail,
                                child: const Text('Forgot password?'),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextButton(
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
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
