import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/app_controller.dart';
import '../../widgets/branded_logo.dart';
import '../auth/login_screen.dart';
import '../auth/password_reset_screen.dart';
import '../dashboard/home_shell.dart';
import '../onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), _routeNext);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _routeNext() {
    if (!mounted) {
      return;
    }

    final next = widget.controller.authController.isPasswordRecovery
        ? PasswordResetScreen(controller: widget.controller)
        : widget.controller.isCloudSyncEnabled &&
              !widget.controller.authController.isSignedIn
        ? LoginScreen(controller: widget.controller)
        : widget.controller.authController.isSignedIn
        ? HomeShell(controller: widget.controller)
        : widget.controller.onboardingComplete
        ? HomeShell(controller: widget.controller)
        : OnboardingScreen(controller: widget.controller);

    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (context, animation, secondaryAnimation) => next,
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(color: Colors.white),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BrandedLogo(height: 120),
              const SizedBox(height: 28),
              Text(
                'Expense Tracker',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Eintelix Innovations Limited',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
