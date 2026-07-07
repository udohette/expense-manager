import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../data/services/app_controller.dart';
import '../features/splash/splash_screen.dart';

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Eintelix Expense Tracker',
      theme: AppTheme.lightTheme,
      home: SplashScreen(controller: controller),
    );
  }
}
