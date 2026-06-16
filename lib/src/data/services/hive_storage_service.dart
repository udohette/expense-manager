import 'package:hive_flutter/hive_flutter.dart';

import '../models/budget_plan.dart';
import '../models/debt_record.dart';
import '../models/expense_category.dart';
import '../models/expense_entry.dart';

class HiveStorageService {
  static const String categoriesBoxName = 'categories_box';
  static const String entriesBoxName = 'entries_box';
  static const String budgetsBoxName = 'budgets_box';
  static const String debtsBoxName = 'debts_box';
  static const String settingsBoxName = 'settings_box';

  Future<void> initialize() async {
    await Hive.initFlutter();
  }

  void registerAdapter<T>(TypeAdapter<T> adapter) {
    if (!Hive.isAdapterRegistered(adapter.typeId)) {
      Hive.registerAdapter(adapter);
    }
  }

  Future<void> openBoxes() async {
    await Hive.openBox<ExpenseCategory>(categoriesBoxName);
    await Hive.openBox<ExpenseEntry>(entriesBoxName);
    await Hive.openBox<BudgetPlan>(budgetsBoxName);
    await Hive.openBox<DebtRecord>(debtsBoxName);
    await Hive.openBox<dynamic>(settingsBoxName);
  }

  Box<ExpenseCategory> get categoriesBox =>
      Hive.box<ExpenseCategory>(categoriesBoxName);

  Box<ExpenseEntry> get entriesBox => Hive.box<ExpenseEntry>(entriesBoxName);

  Box<BudgetPlan> get budgetsBox => Hive.box<BudgetPlan>(budgetsBoxName);

  Box<DebtRecord> get debtsBox => Hive.box<DebtRecord>(debtsBoxName);

  Box<dynamic> get settingsBox => Hive.box<dynamic>(settingsBoxName);
}
