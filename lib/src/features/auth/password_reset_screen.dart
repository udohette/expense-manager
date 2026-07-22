import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/app_controller.dart';
import '../../widgets/branded_logo.dart';
import '../dashboard/home_shell.dart';
import 'auth_visuals.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final auth = widget.controller.authController;
    await auth.updatePassword(password: _passwordController.text);
    if (!mounted || auth.errorMessage != null) {
      return;
    }

    if (!widget.controller.onboardingComplete) {
      await widget.controller.setOnboardingComplete();
      if (!mounted) {
        return;
      }
    }

    final next = HomeShell(controller: widget.controller);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => next),
      (route) => false,
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
                        isSignUp: false,
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
                                      Container(
                                        width: 124,
                                        height: 72,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.08,
                                              ),
                                              blurRadius: 18,
                                              offset: const Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: const Center(
                                          child: BrandedLogo(height: 28),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Reset password',
                                              style: theme.textTheme.titleLarge
                                                  ?.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Choose a new password to secure your account and continue with synced financial data.',
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
                                Text(
                                  'Set a new password',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Enter a strong new password below. Once updated, you will continue back into the app.',
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
                                        controller: _passwordController,
                                        obscureText: _obscurePassword,
                                        decoration: InputDecoration(
                                          labelText: 'New password',
                                          prefixIcon: const Icon(
                                            Icons.lock_reset_rounded,
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
                                      const SizedBox(height: 16),
                                      TextFormField(
                                        controller: _confirmPasswordController,
                                        obscureText: _obscureConfirmPassword,
                                        decoration: InputDecoration(
                                          labelText: 'Confirm new password',
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
                                          if (value !=
                                              _passwordController.text) {
                                            return 'Passwords do not match.';
                                          }
                                          return null;
                                        },
                                      ),
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
                                          : 'Update password',
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
