import 'package:hive_flutter/hive_flutter.dart';

import '../models/app_settings_snapshot.dart';
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

  Future<void> replaceAllData({
    required Iterable<ExpenseCategory> categories,
    required Iterable<ExpenseEntry> entries,
    required Iterable<BudgetPlan> budgets,
    required Iterable<DebtRecord> debts,
  }) async {
    await categoriesBox.clear();
    await categoriesBox.addAll(categories);
    await entriesBox.clear();
    await entriesBox.addAll(entries);
    await budgetsBox.clear();
    await budgetsBox.addAll(budgets);
    await debtsBox.clear();
    await debtsBox.addAll(debts);
  }

  Future<void> applySettingsSnapshot(AppSettingsSnapshot settings) async {
    await settingsBox.put('onboarding_complete', settings.onboardingComplete);
    await settingsBox.put('currency_code', settings.currencyCode);
    await settingsBox.put('hide_balances', settings.hideBalances);
  }
}
