import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/app_controller.dart';
import '../../widgets/branded_logo.dart';
import '../dashboard/home_shell.dart';
import '../onboarding/onboarding_screen.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
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

    final next = widget.controller.onboardingComplete
        ? HomeShell(controller: widget.controller)
        : OnboardingScreen(controller: widget.controller);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => next),
      (route) => false,
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
                            'Set a new password',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Choose a new password for your account recovery session.',
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
                                  controller: _passwordController,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'New password',
                                    prefixIcon: Icon(Icons.lock_reset_rounded),
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
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Confirm new password',
                                    prefixIcon: Icon(
                                      Icons.verified_user_outlined,
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
          ),
        );
      },
    );
  }
}
