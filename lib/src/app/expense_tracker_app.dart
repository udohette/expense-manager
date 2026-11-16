import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/services/app_controller.dart';
import '../features/splash/splash_screen.dart';
import '../features/auth/password_reset_screen.dart';

class ExpenseTrackerApp extends StatefulWidget {
  const ExpenseTrackerApp({
    required this.controller,
    required this.initialization,
    super.key,
  });

  final AppController controller;
  final Future<void> initialization;

  @override
  State<ExpenseTrackerApp> createState() => _ExpenseTrackerAppState();
}

class _ExpenseTrackerAppState extends State<ExpenseTrackerApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late bool _showingRecovery;

  @override
  void initState() {
    super.initState();
    _showingRecovery = widget.controller.authController.isPasswordRecovery;
    widget.controller.authController.addListener(_handleRecovery);
  }

  void _handleRecovery() {
    final recovery = widget.controller.authController.isPasswordRecovery;
    if (!recovery) {
      _showingRecovery = false;
      return;
    }
    if (_showingRecovery) return;
    _showingRecovery = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.controller.authController.isPasswordRecovery) {
        return;
      }
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => PasswordResetScreen(controller: widget.controller),
        ),
        (_) => false,
      );
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  @override
  void dispose() {
    widget.controller.authController.removeListener(_handleRecovery);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Eintelix Expense Tracker',
      theme: AppTheme.lightTheme,
      home: widget.controller.authController.isPasswordRecovery
          ? PasswordResetScreen(controller: widget.controller)
          : SplashScreen(
              controller: widget.controller,
              initialization: widget.initialization,
            ),
    );
  }
}
