import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_settings_snapshot.dart';
import '../models/bill_record.dart';
import '../models/budget_plan.dart';
import '../models/debt_record.dart';
import '../models/expense_category.dart';
import '../models/expense_entry.dart';
import '../models/savings_goal.dart';
import '../models/wallet_account.dart';
import 'hive_storage_service.dart';

class SyncResult {
  const SyncResult({
    required this.didSync,
    this.didPullRemoteChanges = false,
    this.message,
  });

  final bool didSync;
  final bool didPullRemoteChanges;
  final String? message;
}

class DataSyncService {
  DataSyncService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  RealtimeChannel? _realtimeChannel;
  String? _realtimeUserId;

  bool get isConfigured => _client != null;
  bool get isSignedIn => _client?.auth.currentUser != null;
  String? get currentUserId => _client?.auth.currentUser?.id;
  bool get hasActiveRealtimeSubscription => _realtimeChannel != null;

  Future<SyncResult> bootstrap({
    required HiveStorageService storage,
    required AppSettingsSnapshot settings,
  }) async {
    if (!_canSync) {
      return const SyncResult(didSync: false);
    }

    final remoteSnapshot = await _fetchRemoteSnapshot();
    if (remoteSnapshot.hasData) {
      final mergedSnapshot = _mergeRemoteSnapshotWithLocal(
        remoteSnapshot,
        storage,
      );
      await storage.replaceAllData(
        categories: mergedSnapshot.snapshot.categories,
        entries: mergedSnapshot.snapshot.entries,
        budgets: mergedSnapshot.snapshot.budgets,
        bills: mergedSnapshot.snapshot.bills,
        debts: mergedSnapshot.snapshot.debts,
        goals: mergedSnapshot.snapshot.goals,
        wallets: mergedSnapshot.snapshot.wallets,
      );
      if (mergedSnapshot.snapshot.settings != null) {
        await storage.applySettingsSnapshot(mergedSnapshot.snapshot.settings!);
      }
      if (mergedSnapshot.requiresBackfill) {
        await pushLocalSnapshot(storage: storage, settings: settings);
      }
      return const SyncResult(didSync: true, didPullRemoteChanges: true);
    }

    await pushLocalSnapshot(storage: storage, settings: settings);
    return const SyncResult(didSync: true);
  }

  Future<SyncResult> pullRemoteSnapshot({
    required HiveStorageService storage,
  }) async {
    if (!_canSync) {
      return const SyncResult(didSync: false);
    }

    final remoteSnapshot = await _fetchRemoteSnapshot();
    if (!remoteSnapshot.hasData) {
      return const SyncResult(didSync: false);
    }

    final mergedSnapshot = _mergeRemoteSnapshotWithLocal(
      remoteSnapshot,
      storage,
    );
    await storage.replaceAllData(
      categories: mergedSnapshot.snapshot.categories,
      entries: mergedSnapshot.snapshot.entries,
      budgets: mergedSnapshot.snapshot.budgets,
      bills: mergedSnapshot.snapshot.bills,
      debts: mergedSnapshot.snapshot.debts,
      goals: mergedSnapshot.snapshot.goals,
      wallets: mergedSnapshot.snapshot.wallets,
    );
    if (mergedSnapshot.snapshot.settings != null) {
      await storage.applySettingsSnapshot(mergedSnapshot.snapshot.settings!);
    }
    if (mergedSnapshot.requiresBackfill) {
      await pushLocalSnapshot(
        storage: storage,
        settings: _settingsFromStorage(storage),
      );
    }

    return const SyncResult(didSync: true, didPullRemoteChanges: true);
  }

  Future<SyncResult> pushLocalSnapshot({
    required HiveStorageService storage,
    required AppSettingsSnapshot settings,
  }) async {
    if (!_canSync) {
      return const SyncResult(didSync: false);
    }

    final userId = currentUserId!;
    final categories = storage.categoriesBox.values.toList();
    final entries = storage.entriesBox.values.toList();
    final budgets = storage.budgetsBox.values.toList();
    final bills = storage.billsBox.values.toList();
    final debts = storage.debtsBox.values.toList();
    final goals = storage.goalsBox.values.toList();
    final wallets = storage.walletsBox.values.toList();

    await _upsertCollection(
      table: 'expense_categories',
      localRows: categories.map((item) => _categoryRow(item, userId)).toList(),
    );
    await _upsertCollection(
      table: 'expense_entries',
      localRows: entries.map((item) => _entryRow(item, userId)).toList(),
    );
    await _upsertCollection(
      table: 'budget_plans',
      localRows: budgets.map((item) => _budgetRow(item, userId)).toList(),
    );
    await _upsertCollection(
      table: 'bill_records',
      localRows: bills.map((item) => _billRow(item, userId)).toList(),
    );
    await _upsertCollection(
      table: 'debt_records',
      localRows: debts.map((item) => _debtRow(item, userId)).toList(),
    );
    await _upsertCollection(
      table: 'savings_goals',
      localRows: goals.map((item) => _goalRow(item, userId)).toList(),
    );
    await _upsertCollection(
      table: 'wallet_accounts',
      localRows: wallets.map((item) => _walletRow(item, userId)).toList(),
    );

    await _client!
        .from('user_settings')
        .upsert(settings.toJson(userId), onConflict: 'user_id');

    return const SyncResult(didSync: true);
  }

  Future<void> startRealtimeSubscription({
    required Future<void> Function() onRemoteChange,
    void Function(String message)? onStatusMessage,
  }) async {
    if (!_canSync) {
      return;
    }

    final client = _client;
    final userId = currentUserId;
    if (client == null || userId == null) {
      return;
    }
    if (_realtimeChannel != null && _realtimeUserId == userId) {
      return;
    }

    await stopRealtimeSubscription();

    final filter = PostgresChangeFilter(
      type: PostgresChangeFilterType.eq,
      column: 'user_id',
      value: userId,
    );
    final channel = client.channel('expense-sync-$userId');

    for (final table in const [
      'expense_categories',
      'expense_entries',
      'budget_plans',
      'bill_records',
      'debt_records',
      'savings_goals',
      'wallet_accounts',
      'user_settings',
    ]) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: filter,
        callback: (_) => unawaited(onRemoteChange()),
      );
    }

    channel.subscribe((status, error) {
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          onStatusMessage?.call('Live sync connected.');
        case RealtimeSubscribeStatus.channelError:
          onStatusMessage?.call(
            error?.toString() ?? 'Live sync channel reported an error.',
          );
        case RealtimeSubscribeStatus.closed:
          onStatusMessage?.call('Live sync disconnected.');
        case RealtimeSubscribeStatus.timedOut:
          onStatusMessage?.call('Live sync connection timed out.');
      }
    });

    _realtimeChannel = channel;
    _realtimeUserId = userId;
  }

  Future<void> stopRealtimeSubscription() async {
    final client = _client;
    final channel = _realtimeChannel;
    _realtimeChannel = null;
    _realtimeUserId = null;
    if (client == null || channel == null) {
      return;
    }
    await client.removeChannel(channel);
  }

  Future<void> deleteAllUserData() async {
    if (!_canSync) {
      return;
    }

    final userId = currentUserId!;
    for (final table in const [
      'expense_entries',
      'budget_plans',
      'bill_records',
      'debt_records',
      'expense_categories',
      'savings_goals',
      'wallet_accounts',
      'user_settings',
    ]) {
      await _client!.from(table).delete().eq('user_id', userId);
    }
  }

  Future<void> deleteCurrentAccount() async {
    if (!_canSync) {
      return;
    }
    await _client!.rpc('delete_my_account');
  }

  bool get _canSync => _client != null && currentUserId != null;

  _RemoteMergeResult _mergeRemoteSnapshotWithLocal(
    _RemoteSnapshot remoteSnapshot,
    HiveStorageService storage,
  ) {
    final localBills = storage.billsBox.values.toList();
    final localWallets = storage.walletsBox.values.toList();
    final usedLocalBills =
        remoteSnapshot.bills.isEmpty && localBills.isNotEmpty;
    final usedLocalWallets =
        remoteSnapshot.wallets.isEmpty && localWallets.isNotEmpty;

    return _RemoteMergeResult(
      snapshot: _RemoteSnapshot(
        categories: remoteSnapshot.categories,
        entries: remoteSnapshot.entries,
        budgets: remoteSnapshot.budgets,
        bills: usedLocalBills ? localBills : remoteSnapshot.bills,
        debts: remoteSnapshot.debts,
        goals: remoteSnapshot.goals,
        wallets: usedLocalWallets ? localWallets : remoteSnapshot.wallets,
        settings: remoteSnapshot.settings,
      ),
      requiresBackfill: usedLocalBills || usedLocalWallets,
    );
  }

  AppSettingsSnapshot _settingsFromStorage(HiveStorageService storage) {
    return AppSettingsSnapshot(
      onboardingComplete:
          storage.settingsBox.get('onboarding_complete', defaultValue: false)
              as bool,
      currencyCode:
          storage.settingsBox.get('currency_code', defaultValue: 'NGN')
              as String,
      hideBalances:
          storage.settingsBox.get('hide_balances', defaultValue: false) as bool,
    );
  }

  Future<void> _upsertCollection({
    required String table,
    required List<Map<String, dynamic>> localRows,
  }) async {
    final userId = currentUserId!;
    final remoteIds = await _fetchRemoteIds(table, userId);
    final localIds = localRows.map((row) => row['id'] as String).toSet();
    final staleIds = remoteIds.difference(localIds).toList();

    if (localRows.isNotEmpty) {
      await _upsertCollectionWithCompatibility(
        table: table,
        localRows: localRows,
      );
    }

    if (staleIds.isNotEmpty) {
      await _client!
          .from(table)
          .delete()
          .eq('user_id', userId)
          .inFilter('id', staleIds);
    }
  }

  Future<Set<String>> _fetchRemoteIds(String table, String userId) async {
    final response = await _client!
        .from(table)
        .select('id')
        .eq('user_id', userId);
    return response
        .map((row) => row['id'] as String)
        .whereType<String>()
        .toSet();
  }

  Future<void> _upsertCollectionWithCompatibility({
    required String table,
    required List<Map<String, dynamic>> localRows,
  }) async {
    var rowsToSync = localRows;
    while (true) {
      try {
        await _client!.from(table).upsert(rowsToSync, onConflict: 'id');
        return;
      } on PostgrestException catch (error) {
        final missingColumn = _extractMissingColumnName(error);
        if (missingColumn == null) {
          rethrow;
        }

        var changed = false;
        final sanitizedRows = rowsToSync.map((row) {
          if (!row.containsKey(missingColumn)) {
            return row;
          }
          changed = true;
          final copy = Map<String, dynamic>.from(row);
          copy.remove(missingColumn);
          return copy;
        }).toList();

        if (!changed) {
          rethrow;
        }
        rowsToSync = sanitizedRows;
      }
    }
  }

  String? _extractMissingColumnName(PostgrestException error) {
    final match = RegExp(
      r"Could not find the '([^']+)' column",
      caseSensitive: false,
    ).firstMatch(error.message);
    return match?.group(1);
  }

  Future<_RemoteSnapshot> _fetchRemoteSnapshot() async {
    final userId = currentUserId!;
    final client = _client;
    if (client == null) {
      return const _RemoteSnapshot(
        categories: [],
        entries: [],
        budgets: [],
        bills: [],
        debts: [],
        goals: [],
        wallets: [],
        settings: null,
      );
    }

    final categoriesResponse = await client
        .from('expense_categories')
        .select()
        .eq('user_id', userId)
        .order('name');
    final entriesResponse = await client
        .from('expense_entries')
        .select()
        .eq('user_id', userId)
        .order('date', ascending: false);
    final budgetsResponse = await client
        .from('budget_plans')
        .select()
        .eq('user_id', userId)
        .order('start_date', ascending: false);
    final billsResponse = await client
        .from('bill_records')
        .select()
        .eq('user_id', userId)
        .order('due_date');
    final debtsResponse = await client
        .from('debt_records')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    final goalsResponse = await client
        .from('savings_goals')
        .select()
        .eq('user_id', userId)
        .order('target_date', ascending: true);
    final walletsResponse = await client
        .from('wallet_accounts')
        .select()
        .eq('user_id', userId)
        .order('name');
    final settingsResponse = await client
        .from('user_settings')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    return _RemoteSnapshot(
      categories: categoriesResponse.map(_categoryFromRow).toList(),
      entries: entriesResponse.map(_entryFromRow).toList(),
      budgets: budgetsResponse.map(_budgetFromRow).toList(),
      bills: billsResponse.map(_billFromRow).toList(),
      debts: debtsResponse.map(_debtFromRow).toList(),
      goals: goalsResponse.map(_goalFromRow).toList(),
      wallets: walletsResponse.map(_walletFromRow).toList(),
      settings: settingsResponse == null
          ? null
          : AppSettingsSnapshot(
              onboardingComplete:
                  settingsResponse['onboarding_complete'] as bool? ?? false,
              currencyCode:
                  settingsResponse['currency_code'] as String? ?? 'NGN',
              hideBalances: settingsResponse['hide_balances'] as bool? ?? false,
            ),
    );
  }

  Map<String, dynamic> _categoryRow(ExpenseCategory item, String userId) {
    return {
      'id': item.id,
      'user_id': userId,
      'name': item.name,
      'icon_code_point': item.iconCodePoint,
      // Postgres integer is signed 32-bit, while Flutter color ints are
      // commonly treated as unsigned ARGB values. Normalize before sync.
      'color_value': _toSigned32Bit(item.colorValue),
      'type': item.type.name,
      'is_default': item.isDefault,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> _entryRow(ExpenseEntry item, String userId) {
    return {
      'id': item.id,
      'user_id': userId,
      'title': item.title,
      'amount': item.amount,
      'date': item.date.toUtc().toIso8601String(),
      'category_id': item.categoryId,
      'type': item.type.name,
      'payment_method': item.paymentMethod,
      'note': item.note,
      'tag': item.tag,
      'source': item.source.name,
      'external_id': item.externalId,
      'merchant_or_sender': item.merchantOrSender,
      'account_hint': item.accountHint,
      'institution_name': item.institutionName,
      'raw_message': item.rawMessage,
      'imported_at': item.importedAt?.toUtc().toIso8601String(),
      'wallet_account_id': item.walletAccountId,
      'recurrence_frequency': item.recurrenceFrequency.name,
      'recurrence_interval': item.recurrenceInterval,
      'recurrence_end_date': item.recurrenceEndDate?.toUtc().toIso8601String(),
      'is_recurring_template': item.isRecurringTemplate,
      'recurrence_template_id': item.recurrenceTemplateId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> _budgetRow(BudgetPlan item, String userId) {
    return {
      'id': item.id,
      'user_id': userId,
      'name': item.name,
      'limit_amount': item.limit,
      'category_id': item.categoryId,
      'start_date': item.startDate.toUtc().toIso8601String(),
      'period': item.period.name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> _billRow(BillRecord item, String userId) {
    return {
      'id': item.id,
      'user_id': userId,
      'name': item.name,
      'amount': item.amount,
      'due_date': item.dueDate.toUtc().toIso8601String(),
      'frequency': item.frequency.name,
      'reminder_days_before': item.reminderDaysBefore,
      'is_paid': item.isPaid,
      'note': item.note,
      'wallet_account_id': item.walletAccountId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> _debtRow(DebtRecord item, String userId) {
    return {
      'id': item.id,
      'user_id': userId,
      'person_name': item.personName,
      'amount': item.amount,
      'type': item.type.name,
      'status': item.status.name,
      'person_source': item.personSource.name,
      'created_at': item.createdAt.toUtc().toIso8601String(),
      'phone_number': item.phoneNumber,
      'note': item.note,
      'contact_id': item.contactId,
      'due_date': item.dueDate?.toUtc().toIso8601String(),
      'amount_paid': item.amountPaid,
      'installment_amount': item.installmentAmount,
      'next_installment_date': item.nextInstallmentDate
          ?.toUtc()
          .toIso8601String(),
      'repayment_frequency': item.repaymentFrequency.name,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> _goalRow(SavingsGoal item, String userId) {
    return {
      'id': item.id,
      'user_id': userId,
      'name': item.name,
      'target_amount': item.targetAmount,
      'current_amount': item.currentAmount,
      'created_at': item.createdAt.toUtc().toIso8601String(),
      'note': item.note,
      'target_date': item.targetDate?.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> _walletRow(WalletAccount item, String userId) {
    return {
      'id': item.id,
      'user_id': userId,
      'name': item.name,
      'kind': item.kind.name,
      'color_value': _toSigned32Bit(item.colorValue),
      'icon_code_point': item.iconCodePoint,
      'note': item.note,
      'is_default': item.isDefault,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  ExpenseCategory _categoryFromRow(Map<String, dynamic> row) {
    return ExpenseCategory(
      id: row['id'] as String,
      name: row['name'] as String,
      iconCodePoint: (row['icon_code_point'] as num).toInt(),
      colorValue: _toUnsigned32Bit((row['color_value'] as num).toInt()),
      type: _entryTypeFromString(row['type'] as String?),
      isDefault: row['is_default'] as bool? ?? false,
    );
  }

  ExpenseEntry _entryFromRow(Map<String, dynamic> row) {
    return ExpenseEntry(
      id: row['id'] as String,
      title: row['title'] as String,
      amount: (row['amount'] as num).toDouble(),
      date: DateTime.parse(row['date'] as String).toLocal(),
      categoryId: row['category_id'] as String,
      type: _entryTypeFromString(row['type'] as String?),
      paymentMethod: row['payment_method'] as String? ?? '',
      note: row['note'] as String? ?? '',
      tag: row['tag'] as String? ?? '',
      source: _sourceFromString(row['source'] as String?),
      externalId: row['external_id'] as String? ?? '',
      merchantOrSender: row['merchant_or_sender'] as String? ?? '',
      accountHint: row['account_hint'] as String? ?? '',
      institutionName: row['institution_name'] as String? ?? '',
      rawMessage: row['raw_message'] as String? ?? '',
      importedAt: row['imported_at'] == null
          ? null
          : DateTime.parse(row['imported_at'] as String).toLocal(),
      walletAccountId: row['wallet_account_id'] as String? ?? '',
      recurrenceFrequency: _recurrenceFrequencyFromString(
        row['recurrence_frequency'] as String?,
      ),
      recurrenceInterval: (row['recurrence_interval'] as num?)?.toInt() ?? 1,
      recurrenceEndDate: row['recurrence_end_date'] == null
          ? null
          : DateTime.parse(row['recurrence_end_date'] as String).toLocal(),
      isRecurringTemplate: row['is_recurring_template'] as bool? ?? false,
      recurrenceTemplateId: row['recurrence_template_id'] as String? ?? '',
    );
  }

  BudgetPlan _budgetFromRow(Map<String, dynamic> row) {
    return BudgetPlan(
      id: row['id'] as String,
      name: row['name'] as String,
      limit: (row['limit_amount'] as num).toDouble(),
      categoryId: row['category_id'] as String?,
      startDate: DateTime.parse(row['start_date'] as String).toLocal(),
      period: _budgetPeriodFromString(row['period'] as String?),
    );
  }

  BillRecord _billFromRow(Map<String, dynamic> row) {
    return BillRecord(
      id: row['id'] as String,
      name: row['name'] as String,
      amount: (row['amount'] as num).toDouble(),
      dueDate: DateTime.parse(row['due_date'] as String).toLocal(),
      frequency: _recurrenceFrequencyFromString(row['frequency'] as String?),
      reminderDaysBefore: (row['reminder_days_before'] as num?)?.toInt() ?? 3,
      isPaid: row['is_paid'] as bool? ?? false,
      note: row['note'] as String? ?? '',
      walletAccountId: row['wallet_account_id'] as String? ?? '',
    );
  }

  DebtRecord _debtFromRow(Map<String, dynamic> row) {
    return DebtRecord(
      id: row['id'] as String,
      personName: row['person_name'] as String,
      amount: (row['amount'] as num).toDouble(),
      type: _debtTypeFromString(row['type'] as String?),
      status: _debtStatusFromString(row['status'] as String?),
      personSource: _debtPersonSourceFromString(
        row['person_source'] as String?,
      ),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      phoneNumber: row['phone_number'] as String?,
      note: row['note'] as String? ?? '',
      contactId: row['contact_id'] as String?,
      dueDate: row['due_date'] == null
          ? null
          : DateTime.parse(row['due_date'] as String).toLocal(),
      amountPaid: (row['amount_paid'] as num?)?.toDouble() ?? 0,
      installmentAmount: (row['installment_amount'] as num?)?.toDouble() ?? 0,
      nextInstallmentDate: row['next_installment_date'] == null
          ? null
          : DateTime.parse(row['next_installment_date'] as String).toLocal(),
      repaymentFrequency: _recurrenceFrequencyFromString(
        row['repayment_frequency'] as String?,
      ),
    );
  }

  SavingsGoal _goalFromRow(Map<String, dynamic> row) {
    return SavingsGoal(
      id: row['id'] as String,
      name: row['name'] as String,
      targetAmount: (row['target_amount'] as num).toDouble(),
      currentAmount: (row['current_amount'] as num).toDouble(),
      createdAt: DateTime.parse(row['created_at'] as String).toLocal(),
      note: row['note'] as String? ?? '',
      targetDate: row['target_date'] == null
          ? null
          : DateTime.parse(row['target_date'] as String).toLocal(),
    );
  }

  WalletAccount _walletFromRow(Map<String, dynamic> row) {
    return WalletAccount(
      id: row['id'] as String,
      name: row['name'] as String,
      kind: _walletKindFromString(row['kind'] as String?),
      colorValue: _toUnsigned32Bit((row['color_value'] as num).toInt()),
      iconCodePoint: (row['icon_code_point'] as num).toInt(),
      note: row['note'] as String? ?? '',
      isDefault: row['is_default'] as bool? ?? false,
    );
  }

  EntryType _entryTypeFromString(String? value) {
    return value == EntryType.income.name
        ? EntryType.income
        : EntryType.expense;
  }

  TransactionSource _sourceFromString(String? value) {
    switch (value) {
      case 'sms':
        return TransactionSource.sms;
      case 'bankApi':
        return TransactionSource.bankApi;
      default:
        return TransactionSource.manual;
    }
  }

  RecurrenceFrequency _recurrenceFrequencyFromString(String? value) {
    switch (value) {
      case 'weekly':
        return RecurrenceFrequency.weekly;
      case 'monthly':
        return RecurrenceFrequency.monthly;
      case 'yearly':
        return RecurrenceFrequency.yearly;
      case 'none':
      default:
        return RecurrenceFrequency.none;
    }
  }

  BudgetPeriod _budgetPeriodFromString(String? value) {
    return value == BudgetPeriod.weekly.name
        ? BudgetPeriod.weekly
        : BudgetPeriod.monthly;
  }

  DebtType _debtTypeFromString(String? value) {
    return value == DebtType.iOwe.name ? DebtType.iOwe : DebtType.owedToMe;
  }

  DebtStatus _debtStatusFromString(String? value) {
    return value == DebtStatus.settled.name
        ? DebtStatus.settled
        : DebtStatus.active;
  }

  DebtPersonSource _debtPersonSourceFromString(String? value) {
    return value == DebtPersonSource.contacts.name
        ? DebtPersonSource.contacts
        : DebtPersonSource.manual;
  }

  WalletKind _walletKindFromString(String? value) {
    switch (value) {
      case 'bank':
        return WalletKind.bank;
      case 'savings':
        return WalletKind.savings;
      case 'business':
        return WalletKind.business;
      case 'custom':
        return WalletKind.custom;
      case 'cash':
      default:
        return WalletKind.cash;
    }
  }

  int _toSigned32Bit(int value) {
    final normalized = value & 0xFFFFFFFF;
    return normalized > 0x7FFFFFFF ? normalized - 0x100000000 : normalized;
  }

  int _toUnsigned32Bit(int value) {
    return value & 0xFFFFFFFF;
  }
}

class _RemoteSnapshot {
  const _RemoteSnapshot({
    required this.categories,
    required this.entries,
    required this.budgets,
    required this.bills,
    required this.debts,
    required this.goals,
    required this.wallets,
    required this.settings,
  });

  final List<ExpenseCategory> categories;
  final List<ExpenseEntry> entries;
  final List<BudgetPlan> budgets;
  final List<BillRecord> bills;
  final List<DebtRecord> debts;
  final List<SavingsGoal> goals;
  final List<WalletAccount> wallets;
  final AppSettingsSnapshot? settings;

  bool get hasData =>
      categories.isNotEmpty ||
      entries.isNotEmpty ||
      budgets.isNotEmpty ||
      bills.isNotEmpty ||
      debts.isNotEmpty ||
      goals.isNotEmpty ||
      wallets.isNotEmpty ||
      settings?.hasMeaningfulState == true;
}

class _RemoteMergeResult {
  const _RemoteMergeResult({
    required this.snapshot,
    required this.requiresBackfill,
  });

  final _RemoteSnapshot snapshot;
  final bool requiresBackfill;
}
