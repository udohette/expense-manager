import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/core/config/app_environment.dart';
import 'src/app/expense_tracker_app.dart';
import 'src/data/models/budget_plan.dart';
import 'src/data/models/bill_record.dart';
import 'src/data/models/debt_record.dart';
import 'src/data/models/expense_category.dart';
import 'src/data/models/expense_entry.dart';
import 'src/data/models/savings_goal.dart';
import 'src/data/models/wallet_account.dart';
import 'src/data/services/app_controller.dart';
import 'src/data/services/auth_controller.dart';
import 'src/data/services/data_sync_service.dart';
import 'src/data/services/hive_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final launchUri = Uri.base;
  if (AppEnvironment.hasSupabase) {
    await Supabase.initialize(
      url: AppEnvironment.supabaseUrl,
      publishableKey: AppEnvironment.supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(detectSessionInUri: false),
    );
  }

  final storage = HiveStorageService();
  await storage.initialize();
  storage.registerAdapter(EntryTypeAdapter());
  storage.registerAdapter(TransactionSourceAdapter());
  storage.registerAdapter(RecurrenceFrequencyAdapter());
  storage.registerAdapter(ExpenseCategoryAdapter());
  storage.registerAdapter(ExpenseEntryAdapter());
  storage.registerAdapter(BudgetPeriodAdapter());
  storage.registerAdapter(BudgetPlanAdapter());
  storage.registerAdapter(BillRecordAdapter());
  storage.registerAdapter(DebtTypeAdapter());
  storage.registerAdapter(DebtStatusAdapter());
  storage.registerAdapter(DebtPersonSourceAdapter());
  storage.registerAdapter(DebtRecordAdapter());
  storage.registerAdapter(SavingsGoalAdapter());
  storage.registerAdapter(WalletKindAdapter());
  storage.registerAdapter(WalletAccountAdapter());
  await storage.openBoxes();

  final supabaseClient = AppEnvironment.hasSupabase
      ? Supabase.instance.client
      : null;
  final authController = AuthController(client: supabaseClient);
  await authController.initialize();
  if (kIsWeb) {
    await authController.handleWebCallback(launchUri);
  }
  final syncService = DataSyncService(client: supabaseClient);
  final controller = AppController(
    storage,
    authController: authController,
    syncService: syncService,
  );
  final initialization = controller.initialize();

  // Render the Flutter splash while local data finishes loading instead of
  // leaving users on the native launch screen during startup work.
  runApp(
    ExpenseTrackerApp(controller: controller, initialization: initialization),
  );
}
