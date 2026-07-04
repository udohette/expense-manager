import 'package:flutter/material.dart';

import 'src/app/expense_tracker_app.dart';
import 'src/data/models/budget_plan.dart';
import 'src/data/models/debt_record.dart';
import 'src/data/models/expense_category.dart';
import 'src/data/models/expense_entry.dart';
import 'src/data/services/app_controller.dart';
import 'src/data/services/hive_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

  final controller = AppController(storage);
  await controller.initialize();

  runApp(ExpenseTrackerApp(controller: controller));
}
