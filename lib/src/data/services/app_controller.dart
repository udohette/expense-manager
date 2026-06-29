import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../core/theme/app_colors.dart';
import '../models/budget_plan.dart';
import '../models/debt_record.dart';
import '../models/expense_category.dart';
import '../models/expense_entry.dart';
import 'hive_storage_service.dart';

class AppController extends ChangeNotifier {
  AppController(this._storage);

  final HiveStorageService _storage;

  static const String onboardingKey = 'onboarding_complete';
  static const String currencyKey = 'currency_code';
  static const String hideBalancesKey = 'hide_balances';

  late List<ExpenseCategory> _categories;
  late List<ExpenseEntry> _entries;
  late List<BudgetPlan> _budgets;
  late List<DebtRecord> _debts;
  bool _onboardingComplete = false;
  bool _hideBalances = false;
  String _currencyCode = 'NGN';
  final List<StreamSubscription<BoxEvent>> _subscriptions = [];

  List<ExpenseCategory> get categories => List.unmodifiable(_categories);
  List<ExpenseEntry> get entries => List.unmodifiable(_entries);
  List<BudgetPlan> get budgets => List.unmodifiable(_budgets);
  List<DebtRecord> get debts => List.unmodifiable(_debts);
  bool get onboardingComplete => _onboardingComplete;
  bool get hideBalances => _hideBalances;
  String get currencyCode => _currencyCode;

  Future<void> initialize() async {
    _onboardingComplete =
        _storage.settingsBox.get(onboardingKey, defaultValue: false) as bool;
    _hideBalances =
        _storage.settingsBox.get(hideBalancesKey, defaultValue: false) as bool;
    _currencyCode =
        _storage.settingsBox.get(currencyKey, defaultValue: 'NGN') as String;

    await _seedDefaults();
    _loadAll();

    _subscriptions.add(
      _storage.categoriesBox.watch().listen((event) => _loadAll()),
    );
    _subscriptions.add(
      _storage.entriesBox.watch().listen((event) => _loadAll()),
    );
    _subscriptions.add(
      _storage.budgetsBox.watch().listen((event) => _loadAll()),
    );
    _subscriptions.add(_storage.debtsBox.watch().listen((event) => _loadAll()));
  }

  void _loadAll() {
    _categories = _storage.categoriesBox.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    _entries = _storage.entriesBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    _budgets = _storage.budgetsBox.values.toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    _debts = _storage.debtsBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    notifyListeners();
  }

  Future<void> _seedDefaults() async {
    if (_storage.categoriesBox.isEmpty) {
      final seedCategories = <ExpenseCategory>[
        ExpenseCategory(
          id: 'housing',
          name: 'Housing',
          iconCodePoint: Icons.home_rounded.codePoint,
          colorValue: const Color(0xFF3E6BAA).toARGB32(),
          type: EntryType.expense,
          isDefault: true,
        ),
        ExpenseCategory(
          id: 'transport',
          name: 'Transport',
          iconCodePoint: Icons.directions_car_filled_rounded.codePoint,
          colorValue: const Color(0xFFF39C12).toARGB32(),
          type: EntryType.expense,
          isDefault: true,
        ),
        ExpenseCategory(
          id: 'food',
          name: 'Food',
          iconCodePoint: Icons.restaurant_rounded.codePoint,
          colorValue: const Color(0xFFE74C3C).toARGB32(),
          type: EntryType.expense,
          isDefault: true,
        ),
        ExpenseCategory(
          id: 'utilities',
          name: 'Utilities',
          iconCodePoint: Icons.lightbulb_circle_rounded.codePoint,
          colorValue: const Color(0xFF9B59B6).toARGB32(),
          type: EntryType.expense,
          isDefault: true,
        ),
        ExpenseCategory(
          id: 'health',
          name: 'Health',
          iconCodePoint: Icons.health_and_safety_rounded.codePoint,
          colorValue: const Color(0xFF16A085).toARGB32(),
          type: EntryType.expense,
          isDefault: true,
        ),
        ExpenseCategory(
          id: 'salary',
          name: 'Salary',
          iconCodePoint: Icons.account_balance_wallet_rounded.codePoint,
          colorValue: AppColors.success.toARGB32(),
          type: EntryType.income,
          isDefault: true,
        ),
        ExpenseCategory(
          id: 'freelance',
          name: 'Freelance',
          iconCodePoint: Icons.work_history_rounded.codePoint,
          colorValue: AppColors.primary.toARGB32(),
          type: EntryType.income,
          isDefault: true,
        ),
      ];

      await _storage.categoriesBox.addAll(seedCategories);
    }

    if (_storage.entriesBox.isEmpty) {
      final now = DateTime.now();
      final sampleEntries = <ExpenseEntry>[
        ExpenseEntry(
          id: _randomId(),
          title: 'Office internet',
          amount: 45500,
          date: now.subtract(const Duration(days: 2)),
          categoryId: 'utilities',
          type: EntryType.expense,
          paymentMethod: 'Transfer',
          note: 'Monthly business broadband',
        ),
        ExpenseEntry(
          id: _randomId(),
          title: 'Client payment',
          amount: 350000,
          date: now.subtract(const Duration(days: 4)),
          categoryId: 'freelance',
          type: EntryType.income,
          paymentMethod: 'Bank',
          note: 'Project milestone settlement',
        ),
        ExpenseEntry(
          id: _randomId(),
          title: 'Team lunch',
          amount: 22000,
          date: now.subtract(const Duration(days: 1)),
          categoryId: 'food',
          type: EntryType.expense,
          paymentMethod: 'Card',
        ),
      ];
      await _storage.entriesBox.addAll(sampleEntries);
    }

    if (_storage.budgetsBox.isEmpty) {
      await _storage.budgetsBox.addAll([
        BudgetPlan(
          id: _randomId(),
          name: 'Operations',
          limit: 120000,
          categoryId: 'utilities',
          startDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
          period: BudgetPeriod.monthly,
        ),
        BudgetPlan(
          id: _randomId(),
          name: 'Meals',
          limit: 70000,
          categoryId: 'food',
          startDate: DateTime(DateTime.now().year, DateTime.now().month, 1),
          period: BudgetPeriod.monthly,
        ),
      ]);
    }

    if (_storage.debtsBox.isEmpty) {
      final now = DateTime.now();
      await _storage.debtsBox.addAll([
        DebtRecord(
          id: _randomId(),
          personName: 'Chinonso',
          amount: 18000,
          type: DebtType.owedToMe,
          status: DebtStatus.active,
          personSource: DebtPersonSource.manual,
          createdAt: now.subtract(const Duration(days: 5)),
          note: 'Short-term cash support',
          dueDate: now.add(const Duration(days: 7)),
        ),
        DebtRecord(
          id: _randomId(),
          personName: 'Office Vendor',
          amount: 42500,
          type: DebtType.iOwe,
          status: DebtStatus.active,
          personSource: DebtPersonSource.manual,
          createdAt: now.subtract(const Duration(days: 3)),
          note: 'Outstanding printer maintenance bill',
          dueDate: now.add(const Duration(days: 14)),
        ),
      ]);
    }
  }

  ExpenseCategory? findCategory(String categoryId) {
    try {
      return _categories.firstWhere((item) => item.id == categoryId);
    } catch (_) {
      return null;
    }
  }

  Future<void> setOnboardingComplete() async {
    _onboardingComplete = true;
    await _storage.settingsBox.put(onboardingKey, true);
    notifyListeners();
  }

  Future<void> updateCurrency(String currencyCode) async {
    _currencyCode = currencyCode;
    await _storage.settingsBox.put(currencyKey, currencyCode);
    notifyListeners();
  }

  Future<void> setHideBalances(bool hideBalances) async {
    _hideBalances = hideBalances;
    await _storage.settingsBox.put(hideBalancesKey, hideBalances);
    notifyListeners();
  }

  Future<void> addEntry(ExpenseEntry entry) async {
    await _storage.entriesBox.add(entry);
  }

  Future<void> updateEntry(ExpenseEntry entry) async {
    final key = _findBoxKey<ExpenseEntry>(
      _storage.entriesBox,
      (item) => item.id == entry.id,
    );
    if (key == null) {
      return;
    }
    await _storage.entriesBox.put(key, entry);
  }

  Future<void> deleteEntry(String entryId) async {
    final key = _findBoxKey<ExpenseEntry>(
      _storage.entriesBox,
      (item) => item.id == entryId,
    );
    if (key == null) {
      return;
    }
    await _storage.entriesBox.delete(key);
  }

  Future<void> addCategory(ExpenseCategory category) async {
    await _storage.categoriesBox.add(category);
  }

  Future<void> deleteCategory(String categoryId) async {
    final category = findCategory(categoryId);
    if (category == null || category.isDefault) {
      return;
    }

    final key = _findBoxKey<ExpenseCategory>(
      _storage.categoriesBox,
      (item) => item.id == categoryId,
    );
    if (key == null) {
      return;
    }
    await _storage.categoriesBox.delete(key);
  }

  Future<void> addBudget(BudgetPlan budget) async {
    await _storage.budgetsBox.add(budget);
  }

  Future<void> updateBudget(BudgetPlan budget) async {
    final key = _findBoxKey<BudgetPlan>(
      _storage.budgetsBox,
      (item) => item.id == budget.id,
    );
    if (key == null) {
      return;
    }
    await _storage.budgetsBox.put(key, budget);
  }

  Future<void> deleteBudget(String budgetId) async {
    final key = _findBoxKey<BudgetPlan>(
      _storage.budgetsBox,
      (item) => item.id == budgetId,
    );
    if (key == null) {
      return;
    }
    await _storage.budgetsBox.delete(key);
  }

  Future<void> addDebt(DebtRecord debt) async {
    await _storage.debtsBox.add(debt);
  }

  Future<void> updateDebt(DebtRecord debt) async {
    final key = _findBoxKey<DebtRecord>(
      _storage.debtsBox,
      (item) => item.id == debt.id,
    );
    if (key == null) {
      return;
    }
    await _storage.debtsBox.put(key, debt);
  }

  Future<void> deleteDebt(String debtId) async {
    final key = _findBoxKey<DebtRecord>(
      _storage.debtsBox,
      (item) => item.id == debtId,
    );
    if (key == null) {
      return;
    }
    await _storage.debtsBox.delete(key);
  }

  double get totalIncome => _entries
      .where((item) => item.type == EntryType.income)
      .fold(0, (sum, item) => sum + item.amount);

  double get totalExpense => _entries
      .where((item) => item.type == EntryType.expense)
      .fold(0, (sum, item) => sum + item.amount);

  double get netBalance => totalIncome - totalExpense;

  double get receivablesTotal => _debts
      .where(
        (item) =>
            item.type == DebtType.owedToMe && item.status == DebtStatus.active,
      )
      .fold(0, (sum, item) => sum + item.amount);

  double get payablesTotal => _debts
      .where(
        (item) =>
            item.type == DebtType.iOwe && item.status == DebtStatus.active,
      )
      .fold(0, (sum, item) => sum + item.amount);

  Map<String, double> get currentMonthByCategory {
    final now = DateTime.now();
    final result = <String, double>{};

    for (final entry in _entries.where(
      (item) =>
          item.type == EntryType.expense &&
          item.date.year == now.year &&
          item.date.month == now.month,
    )) {
      result.update(
        entry.categoryId,
        (value) => value + entry.amount,
        ifAbsent: () => entry.amount,
      );
    }
    return result;
  }

  double spentForBudget(BudgetPlan budget) {
    return _entries
        .where(
          (entry) =>
              entry.type == EntryType.expense &&
              (budget.categoryId == null ||
                  entry.categoryId == budget.categoryId) &&
              _isWithinBudgetPeriod(entry.date, budget),
        )
        .fold(0, (sum, entry) => sum + entry.amount);
  }

  bool _isWithinBudgetPeriod(DateTime date, BudgetPlan budget) {
    if (budget.period == BudgetPeriod.weekly) {
      final end = budget.startDate.add(const Duration(days: 7));
      return !date.isBefore(budget.startDate) && date.isBefore(end);
    }

    return date.year == budget.startDate.year &&
        date.month == budget.startDate.month;
  }

  String _randomId() {
    return '${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(999)}';
  }

  dynamic _findBoxKey<T>(Box<T> box, bool Function(T item) test) {
    for (final key in box.keys) {
      final item = box.get(key);
      if (item != null && test(item)) {
        return key;
      }
    }
    return null;
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}
