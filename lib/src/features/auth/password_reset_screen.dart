import 'package:flutter/material.dart';

import '../../data/services/app_controller.dart';
import '../../widgets/branded_logo.dart';
import 'login_screen.dart';

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _hidden = true;
  bool _complete = false;

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = widget.controller.authController;
    await auth.updatePassword(password: _password.text);
    if (!mounted || auth.errorMessage != null) return;
    _password.clear();
    _confirmation.clear();
    setState(() => _complete = true);
  }

  Future<void> _returnToSignIn() async {
    final auth = widget.controller.authController;
    await auth.signOut();
    if (!mounted || auth.errorMessage != null) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => LoginScreen(controller: widget.controller),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = widget.controller.authController;
    return AnimatedBuilder(
      animation: auth,
      builder: (context, _) {
        if (auth.isBusy && !auth.canResetPassword && !_complete) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final invalid = !auth.canResetPassword;
        final theme = Theme.of(context);
        return Scaffold(
          backgroundColor: const Color(0xFFF3F6FB),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: BrandedLogo(height: 32),
                          ),
                          const SizedBox(height: 32),
                          Icon(
                            _complete
                                ? Icons.check_circle_outline_rounded
                                : invalid
                                ? Icons.link_off_rounded
                                : Icons.lock_reset_rounded,
                            size: 48,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _complete
                                ? 'Password updated'
                                : invalid
                                ? 'Reset link unavailable'
                                : 'Choose a new password',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _complete
                                ? 'Your new password is ready. You can close this page or return to sign in.'
                                : invalid
                                ? 'This link has expired or could not be verified. Return to sign in and request a new reset email.'
                                : 'Enter and confirm your new password to secure your account.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 28),
                          if (!_complete && !invalid)
                            Form(
                              key: _formKey,
                              child: Column(
                                children: [
                                  TextFormField(
                                    controller: _password,
                                    enabled: !auth.isBusy,
                                    obscureText: _hidden,
                                    autofillHints: const [
                                      AutofillHints.newPassword,
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'New password',
                                      helperText: 'Use at least 6 characters.',
                                      suffixIcon: IconButton(
                                        tooltip: _hidden
                                            ? 'Show passwords'
                                            : 'Hide passwords',
                                        onPressed: () =>
                                            setState(() => _hidden = !_hidden),
                                        icon: Icon(
                                          _hidden
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                      ),
                                    ),
                                    validator: (value) =>
                                        (value ?? '').length < 6
                                        ? 'Use at least 6 characters.'
                                        : null,
                                  ),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    controller: _confirmation,
                                    enabled: !auth.isBusy,
                                    obscureText: _hidden,
                                    decoration: const InputDecoration(
                                      labelText: 'Confirm new password',
                                    ),
                                    validator: (value) =>
                                        value != _password.text
                                        ? 'Passwords do not match.'
                                        : null,
                                    onFieldSubmitted: (_) {
                                      if (!auth.isBusy) _submit();
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  SizedBox(
                                    width: double.infinity,
                                    child: FilledButton(
                                      onPressed: auth.isBusy ? null : _submit,
                                      child: Text(
                                        auth.isBusy
                                            ? 'Updating password…'
                                            : 'Save new password',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (auth.errorMessage != null && !_complete) ...[
                            const SizedBox(height: 16),
                            Text(
                              auth.errorMessage!,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ],
                          if (_complete || invalid)
                            FilledButton(
                              onPressed: auth.isBusy ? null : _returnToSignIn,
                              child: const Text('Return to sign in'),
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
