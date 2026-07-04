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
  static const String lastSelectedCategoryKey = 'last_selected_category';
  static const String lastSelectedMonthKey = 'last_selected_month';
  static const String lastSelectedStartDateKey = 'last_selected_start_date';
  static const String lastSelectedEndDateKey = 'last_selected_end_date';
  static const String lastSelectedTypeKey = 'last_selected_type';
  static const String lastSearchTextKey = 'last_search_text';
  static const String smsCleanupVersionKey = 'sms_cleanup_version';
  static const int smsCleanupVersion = 3;

  late List<ExpenseCategory> _categories;
  late List<ExpenseEntry> _entries;
  late List<BudgetPlan> _budgets;
  late List<DebtRecord> _debts;
  bool _onboardingComplete = false;
  bool _hideBalances = false;
  String _currencyCode = 'NGN';
  final List<StreamSubscription<BoxEvent>> _subscriptions = [];

  List<ExpenseCategory> get categories => List.unmodifiable(_categories);
  List<ExpenseEntry> get entries =>
      List.unmodifiable(_coalescedSmsEntries(_entries));
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
    await _runSmsImportCleanupIfNeeded();
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

  Future<void> _runSmsImportCleanupIfNeeded() async {
    final appliedVersion =
        _storage.settingsBox.get(smsCleanupVersionKey, defaultValue: 0) as int;
    if (appliedVersion >= smsCleanupVersion) {
      return;
    }

    await rerunSmsImportCleanup();
    await _storage.settingsBox.put(smsCleanupVersionKey, smsCleanupVersion);
  }

  Future<int> rerunSmsImportCleanup() async {
    final deletedKeys = await _collectSmsImportCleanupKeys();
    if (deletedKeys.isNotEmpty) {
      await _storage.entriesBox.deleteAll(deletedKeys);
    }
    _loadAll();
    return deletedKeys.length;
  }

  Future<List<dynamic>> _collectSmsImportCleanupKeys() async {
    final entryMap = _storage.entriesBox.toMap();
    final smsEntries = entryMap.entries
        .where((entry) => entry.value.source == TransactionSource.sms)
        .toList();

    if (smsEntries.isEmpty) {
      return const [];
    }

    final duplicates = <dynamic>{};
    for (final duplicate in _collectSmsDuplicateEntries(smsEntries)) {
      duplicates.add(duplicate.key);
    }
    return duplicates.toList();
  }

  List<ExpenseEntry> _coalescedSmsEntries(List<ExpenseEntry> entries) {
    final smsEntries = entries.where(
      (entry) => entry.source == TransactionSource.sms,
    );
    final duplicateIds = _collectSmsDuplicateEntries(
      smsEntries.map((entry) => MapEntry(entry.id, entry)).toList(),
    ).map((entry) => entry.value.id).toSet();
    return entries.where((entry) => !duplicateIds.contains(entry.id)).toList();
  }

  List<MapEntry<dynamic, ExpenseEntry>> _collectSmsDuplicateEntries(
    List<MapEntry<dynamic, ExpenseEntry>> smsEntries,
  ) {
    final duplicates = <MapEntry<dynamic, ExpenseEntry>>[];
    final grouped = <String, List<MapEntry<dynamic, ExpenseEntry>>>{};

    for (final entry in smsEntries) {
      final item = entry.value;
      final groupKey = [
        item.institutionName.trim().toLowerCase(),
        item.type.name,
        item.amount.toStringAsFixed(2),
        item.accountHint.trim().toLowerCase(),
        _dayKey(item.date),
      ].join('|');
      grouped.putIfAbsent(groupKey, () => []).add(entry);
    }

    for (final group in grouped.values) {
      if (group.length < 2) {
        continue;
      }
      group.sort((a, b) {
        final scoreCompare =
            _smsEntryRichnessScore(b.value) - _smsEntryRichnessScore(a.value);
        if (scoreCompare != 0) {
          return scoreCompare;
        }
        return a.value.date.compareTo(b.value.date);
      });

      for (var anchorIndex = 0; anchorIndex < group.length; anchorIndex++) {
        final anchor = group[anchorIndex].value;
        for (
          var compareIndex = anchorIndex + 1;
          compareIndex < group.length;
          compareIndex++
        ) {
          final candidate = group[compareIndex].value;
          if (_isLikelyDuplicatePair(anchor, candidate)) {
            duplicates.add(group[compareIndex]);
          }
        }
      }
    }

    final seenKeys = <dynamic>{};
    return duplicates.where((entry) => seenKeys.add(entry.key)).toList();
  }

  int _smsEntryRichnessScore(ExpenseEntry entry) {
    var score = 0;
    if (entry.rawMessage.trim().isNotEmpty) {
      score += 5;
    }
    if (_looksGenericSmsEntry(entry)) {
      score -= 4;
    }
    if (entry.merchantOrSender.trim().isNotEmpty &&
        entry.merchantOrSender.trim().toLowerCase() !=
            entry.institutionName.trim().toLowerCase()) {
      score += 4;
    }
    if (entry.title.trim().isNotEmpty &&
        entry.title.trim().toLowerCase() !=
            entry.institutionName.trim().toLowerCase()) {
      score += 3;
    }
    if (entry.accountHint.trim().isNotEmpty) {
      score += 2;
    }
    if (entry.note.trim().isNotEmpty) {
      score += 1;
    }
    return score;
  }

  bool _isLikelyDuplicatePair(ExpenseEntry keeper, ExpenseEntry candidate) {
    final keeperText = _normalizedSmsText(keeper);
    final candidateText = _normalizedSmsText(candidate);

    final sameDay = _dayKey(keeper.date) == _dayKey(candidate.date);
    final secondsApart = keeper.date.difference(candidate.date).inSeconds.abs();
    final withinLegacyWindow = secondsApart <= 180;

    final sameRawMessage =
        keeper.rawMessage.trim().isNotEmpty &&
        candidate.rawMessage.trim().isNotEmpty &&
        _normalizeLooseText(keeper.rawMessage) ==
            _normalizeLooseText(candidate.rawMessage);

    if (keeperText.isNotEmpty &&
        candidateText.isNotEmpty &&
        (keeperText == candidateText ||
            keeperText.contains(candidateText) ||
            candidateText.contains(keeperText))) {
      if (withinLegacyWindow || sameDay || sameRawMessage) {
        return true;
      }
    }

    if (_looksGenericSmsEntry(candidate) &&
        !_looksGenericSmsEntry(keeper) &&
        keeper.type == candidate.type &&
        (keeper.amount - candidate.amount).abs() < 0.009 &&
        (withinLegacyWindow || sameDay || sameRawMessage)) {
      return true;
    }

    if (sameRawMessage &&
        keeper.type == candidate.type &&
        (keeper.amount - candidate.amount).abs() < 0.009) {
      return true;
    }

    return false;
  }

  bool _looksGenericSmsEntry(ExpenseEntry entry) {
    final title = entry.title.trim().toLowerCase();
    final bank = entry.institutionName.trim().toLowerCase();
    final description = entry.merchantOrSender.trim().toLowerCase();

    if (title.isEmpty) {
      return true;
    }
    if (bank.isNotEmpty && title == bank) {
      return true;
    }
    if (description.isEmpty || description == title || description == bank) {
      return true;
    }
    return false;
  }

  String _normalizedSmsText(ExpenseEntry entry) {
    final value = [
      entry.title,
      entry.merchantOrSender,
      entry.rawMessage,
    ].join(' ');
    return _normalizeLooseText(value);
  }

  String _normalizeLooseText(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  String _dayKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.toIso8601String();
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
        ExpenseCategory(
          id: 'bank_debit',
          name: 'Bank Debit',
          iconCodePoint: Icons.account_balance_rounded.codePoint,
          colorValue: const Color(0xFFB94E48).toARGB32(),
          type: EntryType.expense,
          isDefault: true,
        ),
        ExpenseCategory(
          id: 'bank_credit',
          name: 'Bank Credit',
          iconCodePoint: Icons.account_balance_wallet_rounded.codePoint,
          colorValue: const Color(0xFF2E8B57).toARGB32(),
          type: EntryType.income,
          isDefault: true,
        ),
      ];

      await _storage.categoriesBox.addAll(seedCategories);
    } else {
      final existingIds = _storage.categoriesBox.values
          .map((item) => item.id)
          .toSet();
      final missingCategories = <ExpenseCategory>[
        if (!existingIds.contains('bank_debit'))
          ExpenseCategory(
            id: 'bank_debit',
            name: 'Bank Debit',
            iconCodePoint: Icons.account_balance_rounded.codePoint,
            colorValue: const Color(0xFFB94E48).toARGB32(),
            type: EntryType.expense,
            isDefault: true,
          ),
        if (!existingIds.contains('bank_credit'))
          ExpenseCategory(
            id: 'bank_credit',
            name: 'Bank Credit',
            iconCodePoint: Icons.account_balance_wallet_rounded.codePoint,
            colorValue: const Color(0xFF2E8B57).toARGB32(),
            type: EntryType.income,
            isDefault: true,
          ),
      ];
      if (missingCategories.isNotEmpty) {
        await _storage.categoriesBox.addAll(missingCategories);
      }
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

  ExpenseCategory? firstCategoryForType(EntryType type) {
    try {
      return _categories.firstWhere((item) => item.type == type);
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

  String? get lastSelectedCategory =>
      _storage.settingsBox.get(lastSelectedCategoryKey) as String?;

  EntryType? get lastSelectedType {
    final s = _storage.settingsBox.get(lastSelectedTypeKey) as String?;
    if (s == null) return null;
    return s == 'expense' ? EntryType.expense : EntryType.income;
  }

  String getLastSearchText() =>
      _storage.settingsBox.get(lastSearchTextKey, defaultValue: '') as String;

  Future<void> setLastSelectedCategory(String? categoryId) async {
    if (categoryId == null) {
      await _storage.settingsBox.delete(lastSelectedCategoryKey);
    } else {
      await _storage.settingsBox.put(lastSelectedCategoryKey, categoryId);
    }
    notifyListeners();
  }

  Future<void> setLastSelectedType(EntryType? type) async {
    if (type == null) {
      await _storage.settingsBox.delete(lastSelectedTypeKey);
    } else {
      final v = type == EntryType.expense ? 'expense' : 'income';
      await _storage.settingsBox.put(lastSelectedTypeKey, v);
    }
    notifyListeners();
  }

  Future<void> setLastSearchText(String text) async {
    if (text.isEmpty) {
      await _storage.settingsBox.delete(lastSearchTextKey);
    } else {
      await _storage.settingsBox.put(lastSearchTextKey, text);
    }
    notifyListeners();
  }

  DateTime getLastSelectedMonth() {
    final millis = _storage.settingsBox.get(lastSelectedMonthKey) as int?;
    if (millis == null) {
      final now = DateTime.now();
      return DateTime(now.year, now.month);
    }
    final d = DateTime.fromMillisecondsSinceEpoch(millis);
    return DateTime(d.year, d.month);
  }

  Future<void> setLastSelectedMonth(DateTime month) async {
    final normalized = DateTime(month.year, month.month);
    await _storage.settingsBox.put(
      lastSelectedMonthKey,
      normalized.millisecondsSinceEpoch,
    );
    notifyListeners();
  }

  DateTime? getLastSelectedStartDate() {
    final millis = _storage.settingsBox.get(lastSelectedStartDateKey) as int?;
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  DateTime? getLastSelectedEndDate() {
    final millis = _storage.settingsBox.get(lastSelectedEndDateKey) as int?;
    if (millis == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<void> setLastSelectedStartDate(DateTime? date) async {
    if (date == null) {
      await _storage.settingsBox.delete(lastSelectedStartDateKey);
    } else {
      await _storage.settingsBox.put(
        lastSelectedStartDateKey,
        date.millisecondsSinceEpoch,
      );
    }
    notifyListeners();
  }

  Future<void> setLastSelectedEndDate(DateTime? date) async {
    if (date == null) {
      await _storage.settingsBox.delete(lastSelectedEndDateKey);
    } else {
      await _storage.settingsBox.put(
        lastSelectedEndDateKey,
        date.millisecondsSinceEpoch,
      );
    }
    notifyListeners();
  }

  Future<void> addEntry(ExpenseEntry entry) async {
    await _storage.entriesBox.add(entry);
  }

  Future<void> addEntries(Iterable<ExpenseEntry> entries) async {
    await _storage.entriesBox.addAll(entries);
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

  Map<String, double> getMonthByCategory(DateTime month) {
    final result = <String, double>{};

    for (final entry in _entries.where(
      (item) =>
          item.type == EntryType.expense &&
          item.date.year == month.year &&
          item.date.month == month.month,
    )) {
      result.update(
        entry.categoryId,
        (value) => value + entry.amount,
        ifAbsent: () => entry.amount,
      );
    }
    return result;
  }

  double getMonthIncome(DateTime month) {
    return _entries
        .where(
          (item) =>
              item.type == EntryType.income &&
              item.date.year == month.year &&
              item.date.month == month.month,
        )
        .fold(0, (sum, item) => sum + item.amount);
  }

  double getMonthExpense(DateTime month) {
    return _entries
        .where(
          (item) =>
              item.type == EntryType.expense &&
              item.date.year == month.year &&
              item.date.month == month.month,
        )
        .fold(0, (sum, item) => sum + item.amount);
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
