import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../../core/theme/app_colors.dart';
import '../models/app_settings_snapshot.dart';
import '../models/bill_record.dart';
import '../models/budget_plan.dart';
import '../models/debt_record.dart';
import '../models/expense_category.dart';
import '../models/expense_entry.dart';
import '../models/savings_goal.dart';
import '../models/wallet_account.dart';
import 'auth_controller.dart';
import 'data_sync_service.dart';
import 'hive_storage_service.dart';

class AppController extends ChangeNotifier {
  AppController(
    this._storage, {
    required this.authController,
    required DataSyncService syncService,
  }) : _syncService = syncService;

  final HiveStorageService _storage;
  final DataSyncService _syncService;
  final AuthController authController;

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
  static const String cloudUserIdKey = 'cloud_user_id';
  static const int smsCleanupVersion = 3;

  late List<ExpenseCategory> _categories;
  late List<ExpenseEntry> _entries;
  late List<BudgetPlan> _budgets;
  late List<BillRecord> _bills;
  late List<DebtRecord> _debts;
  late List<SavingsGoal> _goals;
  late List<WalletAccount> _wallets;
  bool _onboardingComplete = false;
  bool _hideBalances = false;
  String _currencyCode = 'NGN';
  bool _syncInProgress = false;
  bool _hasActiveRealtimeSync = false;
  bool _pendingRealtimeRefresh = false;
  bool _isMaterializingRecurringEntries = false;
  DateTime? _lastSyncAt;
  String? _syncErrorMessage;
  Timer? _realtimeRefreshDebounce;
  final List<StreamSubscription<BoxEvent>> _subscriptions = [];

  List<ExpenseCategory> get categories => List.unmodifiable(_categories);
  List<ExpenseEntry> get entries =>
      List.unmodifiable(_visibleEntries(_entries));
  List<ExpenseEntry> get recurringTemplates => List.unmodifiable(
    _entries.where((entry) => entry.isRecurringTemplate).toList()
      ..sort((a, b) => a.title.compareTo(b.title)),
  );
  List<BudgetPlan> get budgets => List.unmodifiable(_budgets);
  List<BillRecord> get bills => List.unmodifiable(_bills);
  List<DebtRecord> get debts => List.unmodifiable(_debts);
  List<SavingsGoal> get goals => List.unmodifiable(_goals);
  List<WalletAccount> get wallets => List.unmodifiable(_wallets);
  bool get onboardingComplete => _onboardingComplete;
  bool get hideBalances => _hideBalances;
  String get currencyCode => _currencyCode;
  bool get isCloudSyncEnabled => _syncService.isConfigured;
  bool get isSignedIn => authController.isSignedIn;
  bool get isSyncInProgress => _syncInProgress;
  bool get hasActiveRealtimeSync => _hasActiveRealtimeSync;
  DateTime? get lastSyncAt => _lastSyncAt;
  String? get syncErrorMessage => _syncErrorMessage;
  AppSettingsSnapshot get settingsSnapshot => AppSettingsSnapshot(
    onboardingComplete: _onboardingComplete,
    currencyCode: _currencyCode,
    hideBalances: _hideBalances,
  );

  Future<void> initialize() async {
    _onboardingComplete =
        _storage.settingsBox.get(onboardingKey, defaultValue: false) as bool;
    _hideBalances =
        _storage.settingsBox.get(hideBalancesKey, defaultValue: false) as bool;
    _currencyCode =
        _storage.settingsBox.get(currencyKey, defaultValue: 'NGN') as String;

    await _seedDefaults(includeDemoData: !_syncService.isConfigured);
    await _runSmsImportCleanupIfNeeded();
    _loadAll();
    await _materializeRecurringEntries();

    if (_syncService.isSignedIn) {
      await syncFromCloudOnLaunch();
      await _ensureRealtimeSubscription();
    }

    authController.addListener(_onAuthStateChanged);

    _subscriptions.add(
      _storage.categoriesBox.watch().listen((event) => _loadAll()),
    );
    _subscriptions.add(
      _storage.entriesBox.watch().listen((event) {
        _loadAll();
        if (!_isMaterializingRecurringEntries) {
          unawaited(_materializeRecurringEntries());
        }
      }),
    );
    _subscriptions.add(
      _storage.budgetsBox.watch().listen((event) => _loadAll()),
    );
    _subscriptions.add(_storage.billsBox.watch().listen((event) => _loadAll()));
    _subscriptions.add(_storage.debtsBox.watch().listen((event) => _loadAll()));
    _subscriptions.add(_storage.goalsBox.watch().listen((event) => _loadAll()));
    _subscriptions.add(
      _storage.walletsBox.watch().listen((event) => _loadAll()),
    );
  }

  void _loadAll() {
    _categories = _storage.categoriesBox.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    _entries = _storage.entriesBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    _budgets = _storage.budgetsBox.values.toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    _bills = _storage.billsBox.values.toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    _debts = _storage.debtsBox.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _goals = _storage.goalsBox.values.toList()
      ..sort((a, b) {
        final left = a.targetDate ?? DateTime(9999);
        final right = b.targetDate ?? DateTime(9999);
        final byDate = left.compareTo(right);
        if (byDate != 0) {
          return byDate;
        }
        return a.createdAt.compareTo(b.createdAt);
      });
    _wallets = _storage.walletsBox.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
  }

  List<ExpenseEntry> _visibleEntries(List<ExpenseEntry> entries) {
    final nonTemplates = entries.where((entry) => !entry.isRecurringTemplate);
    return _coalescedSmsEntries(nonTemplates.toList());
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

  Future<void> _materializeRecurringEntries() async {
    if (_isMaterializingRecurringEntries) {
      return;
    }

    final templates = _storage.entriesBox.values
        .where((entry) => entry.isRecurringTemplate && entry.hasRecurrence)
        .toList();
    if (templates.isEmpty) {
      return;
    }

    _isMaterializingRecurringEntries = true;
    try {
      final existingEntries = _storage.entriesBox.values.toList();
      final existingIds = existingEntries.map((entry) => entry.id).toSet();
      final newEntries = <ExpenseEntry>[];
      final now = _dateOnly(DateTime.now());

      for (final template in templates) {
        var occurrenceDate = _dateOnly(template.date);
        while (!occurrenceDate.isAfter(now) &&
            _isBeforeOrSame(occurrenceDate, template.recurrenceEndDate)) {
          final occurrenceId = _recurringOccurrenceId(
            template.id,
            occurrenceDate,
          );
          if (!existingIds.contains(occurrenceId)) {
            newEntries.add(
              ExpenseEntry(
                id: occurrenceId,
                title: template.title,
                amount: template.amount,
                date: occurrenceDate,
                categoryId: template.categoryId,
                type: template.type,
                paymentMethod: template.paymentMethod,
                note: template.note,
                tag: template.tag,
                source: template.source,
                externalId: template.externalId,
                merchantOrSender: template.merchantOrSender,
                accountHint: template.accountHint,
                institutionName: template.institutionName,
                rawMessage: template.rawMessage,
                importedAt: template.importedAt,
                walletAccountId: template.walletAccountId,
                recurrenceFrequency: RecurrenceFrequency.none,
                recurrenceInterval: 1,
                recurrenceEndDate: null,
                isRecurringTemplate: false,
                recurrenceTemplateId: template.id,
              ),
            );
            existingIds.add(occurrenceId);
          }
          final next = _advanceRecurringDate(template, occurrenceDate);
          if (next == occurrenceDate) {
            break;
          }
          occurrenceDate = next;
        }
      }

      if (newEntries.isNotEmpty) {
        await _storage.entriesBox.addAll(newEntries);
        _loadAll();
      }
    } finally {
      _isMaterializingRecurringEntries = false;
    }
  }

  Future<void> _deleteGeneratedEntriesForTemplate(String templateId) async {
    final keysToDelete = _storage.entriesBox.keys.where((key) {
      final item = _storage.entriesBox.get(key);
      return item != null && item.recurrenceTemplateId == templateId;
    }).toList();
    if (keysToDelete.isEmpty) {
      return;
    }
    await _storage.entriesBox.deleteAll(keysToDelete);
    _loadAll();
  }

  Future<void> _deleteTransferEntries(String transferExternalId) async {
    final keysToDelete = _storage.entriesBox.keys.where((key) {
      final item = _storage.entriesBox.get(key);
      return item != null && item.externalId == transferExternalId;
    }).toList();
    if (keysToDelete.isEmpty) {
      return;
    }
    await _storage.entriesBox.deleteAll(keysToDelete);
    _loadAll();
  }

  String _recurringOccurrenceId(String templateId, DateTime date) {
    final normalized = _dateOnly(date);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '$templateId::${normalized.year}$month$day';
  }

  DateTime _advanceRecurringDate(ExpenseEntry template, DateTime currentDate) {
    switch (template.recurrenceFrequency) {
      case RecurrenceFrequency.weekly:
        return currentDate.add(Duration(days: 7 * template.recurrenceInterval));
      case RecurrenceFrequency.monthly:
        return DateTime(
          currentDate.year,
          currentDate.month + template.recurrenceInterval,
          template.date.day,
        );
      case RecurrenceFrequency.yearly:
        return DateTime(
          currentDate.year + template.recurrenceInterval,
          currentDate.month,
          template.date.day,
        );
      case RecurrenceFrequency.none:
        return currentDate;
    }
  }

  DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  bool _isBeforeOrSame(DateTime value, DateTime? limit) {
    if (limit == null) {
      return true;
    }
    return !value.isAfter(_dateOnly(limit));
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

  Future<void> _seedDefaults({required bool includeDemoData}) async {
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
        ExpenseCategory(
          id: 'wallet_transfer_out',
          name: 'Wallet Transfer Out',
          iconCodePoint: Icons.swap_horiz_rounded.codePoint,
          colorValue: AppColors.warning.toARGB32(),
          type: EntryType.expense,
          isDefault: true,
        ),
        ExpenseCategory(
          id: 'wallet_transfer_in',
          name: 'Wallet Transfer In',
          iconCodePoint: Icons.swap_horiz_rounded.codePoint,
          colorValue: AppColors.primary.toARGB32(),
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
        if (!existingIds.contains('wallet_transfer_out'))
          ExpenseCategory(
            id: 'wallet_transfer_out',
            name: 'Wallet Transfer Out',
            iconCodePoint: Icons.swap_horiz_rounded.codePoint,
            colorValue: AppColors.warning.toARGB32(),
            type: EntryType.expense,
            isDefault: true,
          ),
        if (!existingIds.contains('wallet_transfer_in'))
          ExpenseCategory(
            id: 'wallet_transfer_in',
            name: 'Wallet Transfer In',
            iconCodePoint: Icons.swap_horiz_rounded.codePoint,
            colorValue: AppColors.primary.toARGB32(),
            type: EntryType.income,
            isDefault: true,
          ),
      ];
      if (missingCategories.isNotEmpty) {
        await _storage.categoriesBox.addAll(missingCategories);
      }
    }

    if (includeDemoData && _storage.entriesBox.isEmpty) {
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
          walletAccountId: 'wallet_business',
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
          walletAccountId: 'wallet_business',
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
          walletAccountId: 'wallet_bank',
        ),
      ];
      await _storage.entriesBox.addAll(sampleEntries);
    }

    if (includeDemoData && _storage.budgetsBox.isEmpty) {
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

    if (includeDemoData && _storage.billsBox.isEmpty) {
      final now = DateTime.now();
      await _storage.billsBox.addAll([
        BillRecord(
          id: _randomId(),
          name: 'Office internet bill',
          amount: 45500,
          dueDate: DateTime(now.year, now.month, now.day + 3),
          frequency: RecurrenceFrequency.monthly,
          reminderDaysBefore: 2,
          walletAccountId: 'wallet_business',
          note: 'Business broadband renewal.',
        ),
        BillRecord(
          id: _randomId(),
          name: 'Electricity token',
          amount: 28000,
          dueDate: DateTime(now.year, now.month, now.day + 5),
          frequency: RecurrenceFrequency.monthly,
          reminderDaysBefore: 3,
          walletAccountId: 'wallet_bank',
        ),
      ]);
    }

    if (includeDemoData && _storage.debtsBox.isEmpty) {
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

    if (includeDemoData && _storage.goalsBox.isEmpty) {
      final now = DateTime.now();
      await _storage.goalsBox.addAll([
        SavingsGoal(
          id: _randomId(),
          name: 'Office expansion fund',
          targetAmount: 500000,
          currentAmount: 180000,
          createdAt: now.subtract(const Duration(days: 20)),
          note: 'Build a reserve for new equipment and workspace upgrades.',
          targetDate: now.add(const Duration(days: 120)),
        ),
        SavingsGoal(
          id: _randomId(),
          name: 'Emergency buffer',
          targetAmount: 250000,
          currentAmount: 90000,
          createdAt: now.subtract(const Duration(days: 10)),
          targetDate: now.add(const Duration(days: 90)),
        ),
      ]);
    }

    if (_storage.walletsBox.isEmpty) {
      await _storage.walletsBox.addAll([
        WalletAccount(
          id: 'wallet_cash',
          name: 'Cash Wallet',
          kind: WalletKind.cash,
          colorValue: AppColors.warning.toARGB32(),
          iconCodePoint: Icons.payments_rounded.codePoint,
          isDefault: true,
          note: 'Cash on hand for quick daily spending.',
        ),
        WalletAccount(
          id: 'wallet_bank',
          name: 'Main Bank Account',
          kind: WalletKind.bank,
          colorValue: AppColors.primary.toARGB32(),
          iconCodePoint: Icons.account_balance_rounded.codePoint,
          isDefault: true,
          note: 'Primary bank account for transfers and card payments.',
        ),
        WalletAccount(
          id: 'wallet_savings',
          name: 'Savings Wallet',
          kind: WalletKind.savings,
          colorValue: AppColors.success.toARGB32(),
          iconCodePoint: Icons.savings_rounded.codePoint,
          isDefault: true,
          note: 'Reserved funds and emergency buffer.',
        ),
        WalletAccount(
          id: 'wallet_business',
          name: 'Business Account',
          kind: WalletKind.business,
          colorValue: AppColors.primaryDark.toARGB32(),
          iconCodePoint: Icons.business_center_rounded.codePoint,
          isDefault: true,
          note: 'Business income and expense flow.',
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

  WalletAccount? findWallet(String walletId) {
    try {
      return _wallets.firstWhere((item) => item.id == walletId);
    } catch (_) {
      return null;
    }
  }

  WalletAccount? suggestWalletForEntry(ExpenseEntry? entry) {
    if (entry == null) {
      return defaultWallet;
    }
    if (entry.walletAccountId.isNotEmpty) {
      return findWallet(entry.walletAccountId) ?? defaultWallet;
    }

    final method = entry.paymentMethod.trim().toLowerCase();
    final rawText =
        '${entry.institutionName} ${entry.accountHint} ${entry.note}'
            .toLowerCase();
    final combined = '$method $rawText';
    if (combined.contains('saving')) {
      return walletForKind(WalletKind.savings) ?? defaultWallet;
    }
    if (combined.contains('business')) {
      return walletForKind(WalletKind.business) ?? defaultWallet;
    }
    if (combined.contains('cash')) {
      return walletForKind(WalletKind.cash) ?? defaultWallet;
    }
    if (combined.contains('bank') ||
        combined.contains('transfer') ||
        combined.contains('card') ||
        entry.institutionName.trim().isNotEmpty) {
      return walletForKind(WalletKind.bank) ?? defaultWallet;
    }
    return defaultWallet;
  }

  WalletAccount? walletForKind(WalletKind kind) {
    try {
      return _wallets.firstWhere((item) => item.kind == kind);
    } catch (_) {
      return null;
    }
  }

  WalletAccount? get defaultWallet {
    try {
      return _wallets.firstWhere((item) => item.isDefault);
    } catch (_) {
      return _wallets.isEmpty ? null : _wallets.first;
    }
  }

  bool isTransferEntry(ExpenseEntry entry) {
    return entry.externalId.startsWith('wallet_transfer:');
  }

  DateTime? nextDueDateForTemplate(ExpenseEntry template) {
    if (!template.isRecurringTemplate || !template.hasRecurrence) {
      return null;
    }

    final existingDates = _entries
        .where((entry) => entry.recurrenceTemplateId == template.id)
        .map((entry) => _dateOnly(entry.date))
        .toSet();
    final now = _dateOnly(DateTime.now());
    var occurrenceDate = _dateOnly(template.date);

    while (!occurrenceDate.isAfter(now)) {
      if (_isBeforeOrSame(occurrenceDate, template.recurrenceEndDate) &&
          !existingDates.contains(occurrenceDate)) {
        return occurrenceDate;
      }
      final next = _advanceRecurringDate(template, occurrenceDate);
      if (next == occurrenceDate) {
        break;
      }
      occurrenceDate = next;
    }

    if (!_isBeforeOrSame(occurrenceDate, template.recurrenceEndDate)) {
      return null;
    }

    return occurrenceDate;
  }

  Future<void> setOnboardingComplete() async {
    _onboardingComplete = true;
    await _storage.settingsBox.put(onboardingKey, true);
    notifyListeners();
    await _pushLocalChanges();
  }

  Future<void> updateCurrency(String currencyCode) async {
    _currencyCode = currencyCode;
    await _storage.settingsBox.put(currencyKey, currencyCode);
    notifyListeners();
    await _pushLocalChanges();
  }

  Future<void> setHideBalances(bool hideBalances) async {
    _hideBalances = hideBalances;
    await _storage.settingsBox.put(hideBalancesKey, hideBalances);
    notifyListeners();
    await _pushLocalChanges();
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
    await _materializeRecurringEntries();
    await _pushLocalChanges();
  }

  Future<void> addEntries(Iterable<ExpenseEntry> entries) async {
    await _storage.entriesBox.addAll(entries);
    await _materializeRecurringEntries();
    await _pushLocalChanges();
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
    await _deleteGeneratedEntriesForTemplate(entry.id);
    await _materializeRecurringEntries();
    await _pushLocalChanges();
  }

  Future<void> deleteEntry(String entryId) async {
    ExpenseEntry? entry;
    for (final item in _entries) {
      if (item.id == entryId) {
        entry = item;
        break;
      }
    }
    if (entry != null && isTransferEntry(entry)) {
      await _deleteTransferEntries(entry.externalId);
      await _pushLocalChanges();
      return;
    }

    await _deleteGeneratedEntriesForTemplate(entryId);
    final key = _findBoxKey<ExpenseEntry>(
      _storage.entriesBox,
      (item) => item.id == entryId,
    );
    if (key == null) {
      return;
    }
    await _storage.entriesBox.delete(key);
    await _pushLocalChanges();
  }

  Future<void> transferBetweenWallets({
    required String fromWalletId,
    required String toWalletId,
    required double amount,
    DateTime? date,
    String note = '',
  }) async {
    if (fromWalletId == toWalletId || amount <= 0) {
      return;
    }
    final fromWallet = findWallet(fromWalletId);
    final toWallet = findWallet(toWalletId);
    if (fromWallet == null || toWallet == null) {
      return;
    }

    final transferDate = date ?? DateTime.now();
    final groupId = 'wallet_transfer:${_randomId()}';
    final fromEntry = ExpenseEntry(
      id: _randomId(),
      title: 'Transfer to ${toWallet.name}',
      amount: amount,
      date: transferDate,
      categoryId: 'wallet_transfer_out',
      type: EntryType.expense,
      paymentMethod: 'Wallet Transfer',
      note: note,
      externalId: groupId,
      merchantOrSender: toWallet.name,
      walletAccountId: fromWallet.id,
    );
    final toEntry = ExpenseEntry(
      id: _randomId(),
      title: 'Transfer from ${fromWallet.name}',
      amount: amount,
      date: transferDate,
      categoryId: 'wallet_transfer_in',
      type: EntryType.income,
      paymentMethod: 'Wallet Transfer',
      note: note,
      externalId: groupId,
      merchantOrSender: fromWallet.name,
      walletAccountId: toWallet.id,
    );

    await _storage.entriesBox.addAll([fromEntry, toEntry]);
    await _pushLocalChanges();
  }

  Future<void> addCategory(ExpenseCategory category) async {
    await _storage.categoriesBox.add(category);
    await _pushLocalChanges();
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
    await _pushLocalChanges();
  }

  Future<void> addBudget(BudgetPlan budget) async {
    await _storage.budgetsBox.add(budget);
    await _pushLocalChanges();
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
    await _pushLocalChanges();
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
    await _pushLocalChanges();
  }

  Future<void> addBill(BillRecord bill) async {
    await _storage.billsBox.add(bill);
    await _pushLocalChanges();
  }

  Future<void> updateBill(BillRecord bill) async {
    final key = _findBoxKey<BillRecord>(
      _storage.billsBox,
      (item) => item.id == bill.id,
    );
    if (key == null) {
      return;
    }
    await _storage.billsBox.put(key, bill);
    await _pushLocalChanges();
  }

  Future<void> deleteBill(String billId) async {
    final key = _findBoxKey<BillRecord>(
      _storage.billsBox,
      (item) => item.id == billId,
    );
    if (key == null) {
      return;
    }
    await _storage.billsBox.delete(key);
    await _pushLocalChanges();
  }

  Future<void> addDebt(DebtRecord debt) async {
    await _storage.debtsBox.add(debt);
    await _pushLocalChanges();
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
    await _pushLocalChanges();
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
    await _pushLocalChanges();
  }

  Future<void> recordDebtPayment(String debtId, double amount) async {
    if (amount <= 0) {
      return;
    }
    DebtRecord? debt;
    for (final item in _debts) {
      if (item.id == debtId) {
        debt = item;
        break;
      }
    }
    if (debt == null) {
      return;
    }
    final nextPaid = (debt.amountPaid + amount)
        .clamp(0, debt.amount)
        .toDouble();
    await updateDebt(
      debt.copyWith(
        amountPaid: nextPaid,
        status: nextPaid >= debt.amount ? DebtStatus.settled : debt.status,
      ),
    );
  }

  Future<void> addGoal(SavingsGoal goal) async {
    await _storage.goalsBox.add(goal);
    await _pushLocalChanges();
  }

  Future<void> updateGoal(SavingsGoal goal) async {
    final key = _findBoxKey<SavingsGoal>(
      _storage.goalsBox,
      (item) => item.id == goal.id,
    );
    if (key == null) {
      return;
    }
    await _storage.goalsBox.put(key, goal);
    await _pushLocalChanges();
  }

  Future<void> deleteGoal(String goalId) async {
    final key = _findBoxKey<SavingsGoal>(
      _storage.goalsBox,
      (item) => item.id == goalId,
    );
    if (key == null) {
      return;
    }
    await _storage.goalsBox.delete(key);
    await _pushLocalChanges();
  }

  Future<void> contributeToGoal(String goalId, double amount) async {
    if (amount <= 0) {
      return;
    }
    SavingsGoal? goal;
    for (final item in _goals) {
      if (item.id == goalId) {
        goal = item;
        break;
      }
    }
    if (goal == null) {
      return;
    }
    await updateGoal(
      goal.copyWith(
        currentAmount: (goal.currentAmount + amount).clamp(0, double.infinity),
      ),
    );
  }

  Future<void> addWallet(WalletAccount wallet) async {
    await _storage.walletsBox.add(wallet);
    await _pushLocalChanges();
  }

  Future<void> updateWallet(WalletAccount wallet) async {
    final key = _findBoxKey<WalletAccount>(
      _storage.walletsBox,
      (item) => item.id == wallet.id,
    );
    if (key == null) {
      return;
    }
    await _storage.walletsBox.put(key, wallet);
    await _pushLocalChanges();
  }

  Future<bool> deleteWallet(String walletId) async {
    final wallet = findWallet(walletId);
    if (wallet == null || wallet.isDefault || walletEntryCount(walletId) > 0) {
      return false;
    }
    final key = _findBoxKey<WalletAccount>(
      _storage.walletsBox,
      (item) => item.id == walletId,
    );
    if (key == null) {
      return false;
    }
    await _storage.walletsBox.delete(key);
    await _pushLocalChanges();
    return true;
  }

  Future<void> deleteAllUserData() async {
    if (_syncService.isSignedIn) {
      await _syncService.deleteAllUserData();
    }

    await _resetLocalDataForCurrentSession();

    if (_syncService.isSignedIn) {
      await _pushLocalChanges();
    }
  }

  Future<void> deleteAccountPermanently() async {
    if (!_syncService.isSignedIn) {
      return;
    }

    await _syncService.deleteCurrentAccount();
    await _clearAllLocalState();
    authController.clearSessionLocally();
    _hasActiveRealtimeSync = false;
    _pendingRealtimeRefresh = false;
    _lastSyncAt = null;
    _syncErrorMessage = null;
    notifyListeners();
  }

  Future<void> syncFromCloudOnLaunch() async {
    await _prepareLocalCacheForSignedInUser();
    await _runSync(
      () =>
          _syncService.bootstrap(storage: _storage, settings: settingsSnapshot),
    );
  }

  Future<void> refreshFromCloud() async {
    await _runSync(() => _syncService.pullRemoteSnapshot(storage: _storage));
  }

  Future<void> _pushLocalChanges() async {
    if (!_syncService.isSignedIn) {
      return;
    }
    await _runSync(
      () => _syncService.pushLocalSnapshot(
        storage: _storage,
        settings: settingsSnapshot,
      ),
      notifyAtStart: false,
    );
  }

  Future<void> _runSync(
    Future<SyncResult> Function() operation, {
    bool notifyAtStart = true,
  }) async {
    if (!_syncService.isConfigured || _syncInProgress) {
      return;
    }

    _syncInProgress = true;
    _syncErrorMessage = null;
    if (notifyAtStart) {
      notifyListeners();
    }

    try {
      final result = await operation();
      if (result.didPullRemoteChanges) {
        _onboardingComplete =
            _storage.settingsBox.get(onboardingKey, defaultValue: false)
                as bool;
        _hideBalances =
            _storage.settingsBox.get(hideBalancesKey, defaultValue: false)
                as bool;
        _currencyCode =
            _storage.settingsBox.get(currencyKey, defaultValue: 'NGN')
                as String;
        _loadAll();
      }
      if (result.didSync) {
        _lastSyncAt = DateTime.now();
      }
      _syncErrorMessage = result.message;
    } catch (error) {
      _syncErrorMessage = error.toString();
    } finally {
      _syncInProgress = false;
      if (_pendingRealtimeRefresh) {
        _pendingRealtimeRefresh = false;
        unawaited(refreshFromCloud());
      }
      notifyListeners();
    }
  }

  void _onAuthStateChanged() {
    unawaited(_syncRealtimeSubscriptionForAuthState());
  }

  Future<void> _syncRealtimeSubscriptionForAuthState() async {
    if (!_syncService.isConfigured) {
      return;
    }

    if (!authController.isSignedIn) {
      _realtimeRefreshDebounce?.cancel();
      _pendingRealtimeRefresh = false;
      _hasActiveRealtimeSync = false;
      await _syncService.stopRealtimeSubscription();
      notifyListeners();
      return;
    }

    await syncFromCloudOnLaunch();
    await _ensureRealtimeSubscription();
  }

  Future<void> _ensureRealtimeSubscription() async {
    if (!_syncService.isSignedIn) {
      return;
    }

    await _syncService.startRealtimeSubscription(
      onRemoteChange: _scheduleRealtimeRefresh,
      onStatusMessage: (message) {
        _syncErrorMessage = message == 'Live sync connected.' ? null : message;
        _hasActiveRealtimeSync = message == 'Live sync connected.';
        notifyListeners();
      },
    );
    _hasActiveRealtimeSync = _syncService.hasActiveRealtimeSubscription;
    notifyListeners();
  }

  Future<void> _scheduleRealtimeRefresh() async {
    _pendingRealtimeRefresh = true;
    _realtimeRefreshDebounce?.cancel();
    _realtimeRefreshDebounce = Timer(const Duration(milliseconds: 350), () {
      if (_syncInProgress) {
        return;
      }
      _pendingRealtimeRefresh = false;
      unawaited(refreshFromCloud());
    });
  }

  Future<void> _prepareLocalCacheForSignedInUser() async {
    final userId = authController.currentUserId;
    if (userId == null) {
      return;
    }

    final previousUserId = _storage.settingsBox.get(cloudUserIdKey) as String?;
    if (previousUserId == userId) {
      return;
    }

    await _storage.replaceAllData(
      categories: <ExpenseCategory>[],
      entries: <ExpenseEntry>[],
      budgets: <BudgetPlan>[],
      bills: <BillRecord>[],
      debts: <DebtRecord>[],
      goals: <SavingsGoal>[],
      wallets: <WalletAccount>[],
    );
    _onboardingComplete = false;
    _hideBalances = false;
    _currencyCode = 'NGN';
    await _storage.applySettingsSnapshot(settingsSnapshot);
    await _storage.settingsBox.put(cloudUserIdKey, userId);
    await _seedDefaults(includeDemoData: false);
    _loadAll();
  }

  Future<void> _resetLocalDataForCurrentSession() async {
    final userId = authController.currentUserId;
    await _storage.replaceAllData(
      categories: <ExpenseCategory>[],
      entries: <ExpenseEntry>[],
      budgets: <BudgetPlan>[],
      bills: <BillRecord>[],
      debts: <DebtRecord>[],
      goals: <SavingsGoal>[],
      wallets: <WalletAccount>[],
    );
    await _storage.clearSettings();
    _onboardingComplete = false;
    _hideBalances = false;
    _currencyCode = 'NGN';
    await _storage.applySettingsSnapshot(settingsSnapshot);
    if (userId != null) {
      await _storage.settingsBox.put(cloudUserIdKey, userId);
    }
    await _seedDefaults(includeDemoData: false);
    _loadAll();
  }

  Future<void> _clearAllLocalState() async {
    await _storage.replaceAllData(
      categories: <ExpenseCategory>[],
      entries: <ExpenseEntry>[],
      budgets: <BudgetPlan>[],
      bills: <BillRecord>[],
      debts: <DebtRecord>[],
      goals: <SavingsGoal>[],
      wallets: <WalletAccount>[],
    );
    await _storage.clearSettings(preserveSmsCleanupVersion: false);
    _onboardingComplete = false;
    _hideBalances = false;
    _currencyCode = 'NGN';
    await _seedDefaults(includeDemoData: false);
    _loadAll();
  }

  double get totalIncome => entries
      .where((item) => item.type == EntryType.income && !isTransferEntry(item))
      .fold(0, (sum, item) => sum + item.amount);

  double get totalExpense => entries
      .where((item) => item.type == EntryType.expense && !isTransferEntry(item))
      .fold(0, (sum, item) => sum + item.amount);

  double get netBalance => totalIncome - totalExpense;

  TrendComparisonSnapshot get weeklyExpenseTrend {
    final now = DateTime.now();
    final currentStart = _dateOnly(
      now.subtract(Duration(days: now.weekday - 1)),
    );
    final currentEnd = _dateOnly(now);
    final previousStart = currentStart.subtract(const Duration(days: 7));
    final previousEnd = currentStart.subtract(const Duration(days: 1));
    return TrendComparisonSnapshot(
      label: 'Weekly spending',
      currentTotal: expenseForRange(currentStart, currentEnd),
      previousTotal: expenseForRange(previousStart, previousEnd),
    );
  }

  TrendComparisonSnapshot get monthlyExpenseTrend {
    final now = DateTime.now();
    final currentStart = DateTime(now.year, now.month, 1);
    final currentEnd = _dateOnly(now);
    final previousStart = DateTime(now.year, now.month - 1, 1);
    final previousEnd = DateTime(now.year, now.month, 0);
    return TrendComparisonSnapshot(
      label: 'Monthly spending',
      currentTotal: expenseForRange(currentStart, currentEnd),
      previousTotal: expenseForRange(previousStart, previousEnd),
    );
  }

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

  double get goalsSavedTotal =>
      _goals.fold(0, (sum, item) => sum + item.currentAmount);

  double get goalsTargetTotal =>
      _goals.fold(0, (sum, item) => sum + item.targetAmount);

  List<SavingsGoal> get highlightedGoals => _goals.take(2).toList();

  List<BillRecord> get upcomingBills {
    final now = DateTime.now();
    return _bills
        .where((bill) => !bill.isPaid && !bill.dueDate.isBefore(_dateOnly(now)))
        .take(4)
        .toList();
  }

  List<DebtRecord> get upcomingDebtInstallments {
    return _debts
        .where(
          (debt) =>
              debt.status == DebtStatus.active &&
              debt.nextInstallmentDate != null,
        )
        .toList()
      ..sort(
        (a, b) => a.nextInstallmentDate!.compareTo(b.nextInstallmentDate!),
      );
  }

  List<WalletBalanceSnapshot> get walletSnapshots {
    return _wallets.map((wallet) {
      final walletEntries = entries
          .where((entry) => resolveWalletIdForEntry(entry) == wallet.id)
          .toList();
      final income = walletEntries
          .where((entry) => entry.type == EntryType.income)
          .fold<double>(0, (sum, entry) => sum + entry.amount);
      final expense = walletEntries
          .where((entry) => entry.type == EntryType.expense)
          .fold<double>(0, (sum, entry) => sum + entry.amount);
      return WalletBalanceSnapshot(
        wallet: wallet,
        income: income,
        expense: expense,
        transactionCount: walletEntries.length,
      );
    }).toList()..sort((a, b) => b.balance.compareTo(a.balance));
  }

  List<WalletBalanceSnapshot> get highlightedWallets =>
      walletSnapshots.take(3).toList();

  double incomeForRange(DateTime start, DateTime end) {
    return entries
        .where(
          (entry) =>
              entry.type == EntryType.income &&
              !isTransferEntry(entry) &&
              _isWithinInclusiveRange(entry.date, start, end),
        )
        .fold(0, (sum, entry) => sum + entry.amount);
  }

  double expenseForRange(DateTime start, DateTime end) {
    return entries
        .where(
          (entry) =>
              entry.type == EntryType.expense &&
              !isTransferEntry(entry) &&
              _isWithinInclusiveRange(entry.date, start, end),
        )
        .fold(0, (sum, entry) => sum + entry.amount);
  }

  ExpenseCategorySpendSnapshot? topCategoryForRange(
    DateTime start,
    DateTime end,
  ) {
    final totals = <String, double>{};
    for (final entry in entries.where(
      (item) =>
          item.type == EntryType.expense &&
          !isTransferEntry(item) &&
          _isWithinInclusiveRange(item.date, start, end),
    )) {
      totals.update(
        entry.categoryId,
        (value) => value + entry.amount,
        ifAbsent: () => entry.amount,
      );
    }
    if (totals.isEmpty) {
      return null;
    }
    final sorted = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final winner = sorted.first;
    return ExpenseCategorySpendSnapshot(
      categoryId: winner.key,
      amount: winner.value,
    );
  }

  List<TrendSeriesPoint> weeklyTrendSeries({int weeks = 8}) {
    final now = DateTime.now();
    final currentWeekStart = _dateOnly(
      now.subtract(Duration(days: now.weekday - 1)),
    );
    return List.generate(weeks, (index) {
      final start = currentWeekStart.subtract(
        Duration(days: 7 * (weeks - index - 1)),
      );
      final end = start.add(const Duration(days: 6));
      return TrendSeriesPoint(
        label: 'W${index + 1}',
        start: start,
        end: end,
        income: incomeForRange(start, end),
        expense: expenseForRange(start, end),
      );
    });
  }

  List<TrendSeriesPoint> monthlyTrendSeries({int months = 6}) {
    final now = DateTime.now();
    return List.generate(months, (index) {
      final pointMonth = DateTime(
        now.year,
        now.month - (months - index - 1),
        1,
      );
      final start = DateTime(pointMonth.year, pointMonth.month, 1);
      final end = DateTime(pointMonth.year, pointMonth.month + 1, 0);
      return TrendSeriesPoint(
        label: '${start.month}/${start.year % 100}',
        start: start,
        end: end,
        income: incomeForRange(start, end),
        expense: expenseForRange(start, end),
      );
    });
  }

  int walletEntryCount(String walletId) {
    return entries
        .where((entry) => resolveWalletIdForEntry(entry) == walletId)
        .length;
  }

  String resolveWalletIdForEntry(ExpenseEntry entry) {
    final directId = entry.walletAccountId.trim();
    if (directId.isNotEmpty && findWallet(directId) != null) {
      return directId;
    }
    return suggestWalletForEntry(entry)?.id ?? '';
  }

  Map<String, double> get currentMonthByCategory {
    final now = DateTime.now();
    final result = <String, double>{};

    for (final entry in entries.where(
      (item) =>
          item.type == EntryType.expense &&
          !isTransferEntry(item) &&
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

    for (final entry in entries.where(
      (item) =>
          item.type == EntryType.expense &&
          !isTransferEntry(item) &&
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
    return entries
        .where(
          (item) =>
              item.type == EntryType.income &&
              !isTransferEntry(item) &&
              item.date.year == month.year &&
              item.date.month == month.month,
        )
        .fold(0, (sum, item) => sum + item.amount);
  }

  double getMonthExpense(DateTime month) {
    return entries
        .where(
          (item) =>
              item.type == EntryType.expense &&
              !isTransferEntry(item) &&
              item.date.year == month.year &&
              item.date.month == month.month,
        )
        .fold(0, (sum, item) => sum + item.amount);
  }

  double spentForBudget(BudgetPlan budget) {
    return entries
        .where(
          (entry) =>
              entry.type == EntryType.expense &&
              !isTransferEntry(entry) &&
              (budget.categoryId == null ||
                  entry.categoryId == budget.categoryId) &&
              _isWithinBudgetPeriod(entry.date, budget),
        )
        .fold(0, (sum, entry) => sum + entry.amount);
  }

  List<BudgetUsageSnapshot> budgetAlertsForMonth(
    DateTime month, {
    double warningThreshold = 0.8,
  }) {
    return _budgets
        .where((budget) => _budgetOverlapsMonth(budget, month))
        .map((budget) {
          final spent = spentForBudget(budget);
          final ratio = budget.limit <= 0 ? 0.0 : spent / budget.limit;
          return BudgetUsageSnapshot(
            budget: budget,
            spent: spent,
            ratio: ratio,
          );
        })
        .where((snapshot) => snapshot.ratio >= warningThreshold)
        .toList()
      ..sort((a, b) => b.ratio.compareTo(a.ratio));
  }

  bool _isWithinBudgetPeriod(DateTime date, BudgetPlan budget) {
    if (budget.period == BudgetPeriod.weekly) {
      final end = budget.startDate.add(const Duration(days: 7));
      return !date.isBefore(budget.startDate) && date.isBefore(end);
    }

    return date.year == budget.startDate.year &&
        date.month == budget.startDate.month;
  }

  bool _budgetOverlapsMonth(BudgetPlan budget, DateTime month) {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 1);

    if (budget.period == BudgetPeriod.weekly) {
      final budgetEnd = budget.startDate.add(const Duration(days: 7));
      return budget.startDate.isBefore(monthEnd) &&
          budgetEnd.isAfter(monthStart);
    }

    return budget.startDate.year == month.year &&
        budget.startDate.month == month.month;
  }

  bool _isWithinInclusiveRange(DateTime value, DateTime start, DateTime end) {
    final normalizedValue = _dateOnly(value);
    final normalizedStart = _dateOnly(start);
    final normalizedEnd = _dateOnly(end);
    return !normalizedValue.isBefore(normalizedStart) &&
        !normalizedValue.isAfter(normalizedEnd);
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
    authController.removeListener(_onAuthStateChanged);
    _realtimeRefreshDebounce?.cancel();
    unawaited(_syncService.stopRealtimeSubscription());
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }
}

class BudgetUsageSnapshot {
  const BudgetUsageSnapshot({
    required this.budget,
    required this.spent,
    required this.ratio,
  });

  final BudgetPlan budget;
  final double spent;
  final double ratio;

  double get remaining => budget.limit - spent;
  bool get isOverLimit => ratio >= 1;
  bool get isNearLimit => ratio >= 0.8 && ratio < 1;
}

class WalletBalanceSnapshot {
  const WalletBalanceSnapshot({
    required this.wallet,
    required this.income,
    required this.expense,
    required this.transactionCount,
  });

  final WalletAccount wallet;
  final double income;
  final double expense;
  final int transactionCount;

  double get balance => income - expense;
}

class TrendSeriesPoint {
  const TrendSeriesPoint({
    required this.label,
    required this.start,
    required this.end,
    required this.income,
    required this.expense,
  });

  final String label;
  final DateTime start;
  final DateTime end;
  final double income;
  final double expense;
}

class TrendComparisonSnapshot {
  const TrendComparisonSnapshot({
    required this.label,
    required this.currentTotal,
    required this.previousTotal,
  });

  final String label;
  final double currentTotal;
  final double previousTotal;

  double get changeAmount => currentTotal - previousTotal;

  double get changeRatio {
    if (previousTotal == 0) {
      return currentTotal == 0 ? 0 : 1;
    }
    return changeAmount / previousTotal;
  }

  bool get isIncrease => changeAmount > 0;
}

class ExpenseCategorySpendSnapshot {
  const ExpenseCategorySpendSnapshot({
    required this.categoryId,
    required this.amount,
  });

  final String categoryId;
  final double amount;
}
