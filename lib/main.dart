import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/core/config/app_environment.dart';
import 'src/app/expense_tracker_app.dart';
import 'src/data/models/budget_plan.dart';
import 'src/data/models/debt_record.dart';
import 'src/data/models/expense_category.dart';
import 'src/data/models/expense_entry.dart';
import 'src/data/services/app_controller.dart';
import 'src/data/services/auth_controller.dart';
import 'src/data/services/data_sync_service.dart';
import 'src/data/services/hive_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (AppEnvironment.hasSupabase) {
    await Supabase.initialize(
      url: AppEnvironment.supabaseUrl,
      publishableKey: AppEnvironment.supabasePublishableKey,
    );
  }

  final storage = HiveStorageService();
  await storage.initialize();
  storage.registerAdapter(EntryTypeAdapter());
  storage.registerAdapter(TransactionSourceAdapter());
  storage.registerAdapter(ExpenseCategoryAdapter());
  storage.registerAdapter(ExpenseEntryAdapter());
  storage.registerAdapter(BudgetPeriodAdapter());
  storage.registerAdapter(BudgetPlanAdapter());
  storage.registerAdapter(DebtTypeAdapter());
  storage.registerAdapter(DebtStatusAdapter());
  storage.registerAdapter(DebtPersonSourceAdapter());
  storage.registerAdapter(DebtRecordAdapter());
  await storage.openBoxes();

  final supabaseClient = AppEnvironment.hasSupabase
      ? Supabase.instance.client
      : null;
  final authController = AuthController(client: supabaseClient);
  await authController.initialize();
  final syncService = DataSyncService(client: supabaseClient);
  final controller = AppController(
    storage,
    authController: authController,
    syncService: syncService,
  );
  await controller.initialize();

  runApp(ExpenseTrackerApp(controller: controller));
}
