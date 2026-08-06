import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/services/app_controller.dart';
import '../features/splash/splash_screen.dart';

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({
    required this.controller,
    required this.initialization,
    super.key,
  });

  final AppController controller;
  final Future<void> initialization;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Eintelix Expense Tracker',
      theme: AppTheme.lightTheme,
      home: SplashScreen(
        controller: controller,
        initialization: initialization,
      ),
    );
  }
}
