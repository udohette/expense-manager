import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/app_formatters.dart';
import '../../data/models/expense_category.dart';
import '../../data/models/expense_entry.dart';
import '../../data/services/app_controller.dart';
import '../../data/services/sms_import_service.dart';
import '../../widgets/empty_state_card.dart';
import '../../widgets/section_header.dart';
import '../dashboard/home_shell.dart';
import 'sms_import_sheet.dart';
import 'transaction_form_sheet.dart';

enum _TransactionViewMode { regular, bank }

class TransactionsScreen extends StatefulWidget implements QuickActionHost {
  const TransactionsScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();

  @override
  void onQuickAction(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => TransactionFormSheet(controller: controller),
    );
  }
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final SmsImportService _smsImportService = SmsImportService();
  EntryType? _filter;
  String? _selectedCategory;
  String? _selectedBank;
  String? _selectedPaymentMethod;
  String? _selectedTag;
  String? _selectedWalletAccountId;
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _minAmountController = TextEditingController();
  final TextEditingController _maxAmountController = TextEditingController();
  bool _isImportingFromSms = false;
  _TransactionViewMode _viewMode = _TransactionViewMode.regular;
  bool _showAdvancedFilters = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.controller.lastSelectedCategory;
    _filter = widget.controller.lastSelectedType;
    _startDate = widget.controller.getLastSelectedStartDate();
    _endDate = widget.controller.getLastSelectedEndDate();
    final lastSearch = widget.controller.getLastSearchText();
    if (lastSearch.isNotEmpty) {
      _searchController.text = lastSearch;
    }
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _minAmountController.dispose();
    _maxAmountController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    widget.controller.setLastSearchText(_searchController.text);
    setState(() {});
  }

  Future<void> _resetFilters() async {
    setState(() {
      _filter = null;
      _selectedCategory = null;
      _selectedBank = null;
      _selectedPaymentMethod = null;
      _selectedTag = null;
      _selectedWalletAccountId = null;
      _startDate = null;
      _endDate = null;
      _minAmountController.clear();
      _maxAmountController.clear();
      _searchController.clear();
    });
    await widget.controller.setLastSelectedCategory(null);
    await widget.controller.setLastSelectedStartDate(null);
    await widget.controller.setLastSelectedEndDate(null);
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 640;
    final allEntries = widget.controller.entries;
    final recurringTemplates = widget.controller.recurringTemplates;
    final minAmount = double.tryParse(_minAmountController.text.trim());
    final maxAmount = double.tryParse(_maxAmountController.text.trim());
    final bankOptions =
        allEntries
            .map(_resolvedBankName)
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final paymentMethodOptions =
        allEntries
            .map((entry) => entry.paymentMethod.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final tagOptions =
        allEntries
            .map((entry) => entry.tag.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final walletOptions =
        widget.controller.wallets
            .where(
              (wallet) => allEntries.any(
                (entry) =>
                    widget.controller.resolveWalletIdForEntry(entry) ==
                    wallet.id,
              ),
            )
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final filtered = allEntries.where((entry) {
      final category = widget.controller.findCategory(entry.categoryId);
      final walletId = widget.controller.resolveWalletIdForEntry(entry);
      final matchesType = _filter == null || entry.type == _filter;
      final matchesCategory =
          _selectedCategory == null || entry.categoryId == _selectedCategory;
      final resolvedBank = _resolvedBankName(entry);
      final matchesBank =
          _selectedBank == null || resolvedBank == _selectedBank;
      final matchesPaymentMethod =
          _selectedPaymentMethod == null ||
          entry.paymentMethod.trim() == _selectedPaymentMethod;
      final matchesTag =
          _selectedTag == null || entry.tag.trim() == _selectedTag;
      final matchesWallet =
          _selectedWalletAccountId == null ||
          walletId == _selectedWalletAccountId;
      final matchesAmount =
          (minAmount == null || entry.amount >= minAmount) &&
          (maxAmount == null || entry.amount <= maxAmount);
      final matchesViewMode =
          _viewMode == _TransactionViewMode.regular || resolvedBank.isNotEmpty;
      final matchesDateRange =
          (_startDate == null ||
              entry.date.isAfter(
                _startDate!.subtract(const Duration(days: 1)),
              )) &&
          (_endDate == null ||
              entry.date.isBefore(_endDate!.add(const Duration(days: 1))));
      final matchesQuery =
          query.isEmpty ||
          entry.title.toLowerCase().contains(query) ||
          (category?.name.toLowerCase().contains(query) ?? false) ||
          entry.note.toLowerCase().contains(query) ||
          entry.paymentMethod.toLowerCase().contains(query) ||
          entry.tag.toLowerCase().contains(query) ||
          entry.merchantOrSender.toLowerCase().contains(query) ||
          resolvedBank.toLowerCase().contains(query) ||
          entry.accountHint.toLowerCase().contains(query) ||
          (widget.controller
                  .findWallet(walletId)
                  ?.name
                  .toLowerCase()
                  .contains(query) ??
              false);
      return matchesType &&
          matchesCategory &&
          matchesBank &&
          matchesPaymentMethod &&
          matchesTag &&
          matchesWallet &&
          matchesAmount &&
          matchesViewMode &&
          matchesDateRange &&
          matchesQuery;
    }).toList();
    final bankSummaryEntries = _bankEntriesForSummary(allEntries);
    final bankCreditTotal = bankSummaryEntries
        .where((entry) => entry.type == EntryType.income)
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    final bankDebitTotal = bankSummaryEntries
        .where((entry) => entry.type == EntryType.expense)
        .fold<double>(0, (sum, entry) => sum + entry.amount);
    final bankNetTotal = bankCreditTotal - bankDebitTotal;

    const floatingTotalsBottomOffset = 10.0;
    const floatingTotalsSideMargin = 20.0;

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 190),
          children: [
            const SectionHeader(
              title: 'Transactions',
              subtitle:
                  'Search, review, and maintain every expense and income record',
            ),
            const SizedBox(height: 16),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FilledButton.tonalIcon(
                          onPressed: _isImportingFromSms
                              ? null
                              : _importFromSms,
                          icon: _isImportingFromSms
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.sms_rounded),
                          label: Text(
                            _isImportingFromSms
                                ? 'Checking SMS...'
                                : 'Import from SMS',
                          ),
                        ),
                        SizedBox(
                          width: isCompact ? double.infinity : 280,
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search description, bank, tag, wallet',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: query.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () =>
                                          _searchController.clear(),
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _FilterSectionLabel(label: 'View'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ChoiceChip(
                          label: const Text('Regular Transactions'),
                          selected: _viewMode == _TransactionViewMode.regular,
                          onSelected: (_) {
                            setState(() {
                              _viewMode = _TransactionViewMode.regular;
                              _selectedBank = null;
                            });
                          },
                        ),
                        ChoiceChip(
                          label: const Text('Bank Totals'),
                          selected: _viewMode == _TransactionViewMode.bank,
                          onSelected: (_) {
                            setState(() {
                              _viewMode = _TransactionViewMode.bank;
                              _selectedCategory = null;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _FilterSectionLabel(
                      label: _viewMode == _TransactionViewMode.bank
                          ? 'Bank Transaction Type'
                          : 'Transaction Type',
                    ),
                    const SizedBox(height: 10),
                    _SelectionDropdown<String>(
                      label: 'Choose type',
                      value: _filterDropdownValue,
                      items: [
                        const DropdownMenuItem<String>(
                          value: 'all',
                          child: Text('All'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'expense',
                          child: Text(
                            _viewMode == _TransactionViewMode.bank
                                ? 'Debits'
                                : 'Expenses',
                          ),
                        ),
                        DropdownMenuItem<String>(
                          value: 'income',
                          child: Text(
                            _viewMode == _TransactionViewMode.bank
                                ? 'Credits'
                                : 'Income',
                          ),
                        ),
                      ],
                      onChanged: (value) async {
                        switch (value) {
                          case 'expense':
                            setState(() => _filter = EntryType.expense);
                            await widget.controller.setLastSelectedType(
                              EntryType.expense,
                            );
                            break;
                          case 'income':
                            setState(() => _filter = EntryType.income);
                            await widget.controller.setLastSelectedType(
                              EntryType.income,
                            );
                            break;
                          case 'all':
                          default:
                            setState(() => _filter = null);
                            await widget.controller.setLastSelectedType(null);
                            break;
                        }
                      },
                    ),
                    const SizedBox(height: 18),
                    _FilterSectionLabel(label: 'Quick Period'),
                    const SizedBox(height: 10),
                    _SelectionDropdown<String>(
                      label: 'Choose period',
                      value: _quickPeriodValue,
                      items: const [
                        DropdownMenuItem<String>(
                          value: 'daily',
                          child: Text('Daily'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'weekly',
                          child: Text('Weekly'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'monthly',
                          child: Text('Monthly'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'yearly',
                          child: Text('Yearly'),
                        ),
                        DropdownMenuItem<String>(
                          value: 'custom',
                          child: Text('Custom'),
                        ),
                      ],
                      onChanged: (value) async {
                        switch (value) {
                          case 'daily':
                            await _setQuickPeriod(const Duration(days: 1));
                            break;
                          case 'weekly':
                            await _setQuickPeriod(const Duration(days: 7));
                            break;
                          case 'monthly':
                            await _setCurrentMonthRange();
                            break;
                          case 'yearly':
                            await _setCurrentYearRange();
                            break;
                          case 'custom':
                          default:
                            break;
                        }
                      },
                    ),
                    const SizedBox(height: 18),
                    TextButton.icon(
                      onPressed: () {
                        setState(
                          () => _showAdvancedFilters = !_showAdvancedFilters,
                        );
                      },
                      icon: Icon(
                        _showAdvancedFilters
                            ? Icons.tune_rounded
                            : Icons.tune_outlined,
                      ),
                      label: Text(
                        _showAdvancedFilters
                            ? 'Hide advanced filters'
                            : 'Show advanced filters',
                      ),
                    ),
                    if (_showAdvancedFilters) ...[
                      const SizedBox(height: 8),
                      if (_viewMode == _TransactionViewMode.regular)
                        _FilterDropdown(
                          label: 'Category',
                          value: _selectedCategory,
                          hint: 'All Categories',
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('All Categories'),
                            ),
                            ...widget.controller.categories
                                .where(
                                  (cat) => allEntries.any(
                                    (entry) => entry.categoryId == cat.id,
                                  ),
                                )
                                .map(
                                  (cat) => DropdownMenuItem<String?>(
                                    value: cat.id,
                                    child: Text(cat.name),
                                  ),
                                ),
                          ],
                          onChanged: (value) async {
                            setState(() => _selectedCategory = value);
                            await widget.controller.setLastSelectedCategory(
                              value,
                            );
                          },
                        ),
                      _FilterDropdown(
                        label: 'Bank',
                        value: _selectedBank,
                        hint: bankOptions.isEmpty
                            ? 'No bank imports yet'
                            : 'All Banks',
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All Banks'),
                          ),
                          ...bankOptions.map(
                            (bank) => DropdownMenuItem<String?>(
                              value: bank,
                              child: Text(bank),
                            ),
                          ),
                        ],
                        onChanged: bankOptions.isEmpty
                            ? null
                            : (value) => setState(() => _selectedBank = value),
                      ),
                      const SizedBox(height: 10),
                      _FilterDropdown(
                        label: 'Payment method',
                        value: _selectedPaymentMethod,
                        hint: paymentMethodOptions.isEmpty
                            ? 'No methods yet'
                            : 'All payment methods',
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All payment methods'),
                          ),
                          ...paymentMethodOptions.map(
                            (method) => DropdownMenuItem<String?>(
                              value: method,
                              child: Text(method),
                            ),
                          ),
                        ],
                        onChanged: paymentMethodOptions.isEmpty
                            ? null
                            : (value) => setState(
                                () => _selectedPaymentMethod = value,
                              ),
                      ),
                      const SizedBox(height: 10),
                      _FilterDropdown(
                        label: 'Tag',
                        value: _selectedTag,
                        hint: tagOptions.isEmpty ? 'No tags yet' : 'All tags',
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All tags'),
                          ),
                          ...tagOptions.map(
                            (tag) => DropdownMenuItem<String?>(
                              value: tag,
                              child: Text(tag),
                            ),
                          ),
                        ],
                        onChanged: tagOptions.isEmpty
                            ? null
                            : (value) => setState(() => _selectedTag = value),
                      ),
                      const SizedBox(height: 10),
                      _FilterDropdown(
                        label: 'Wallet / Account',
                        value: _selectedWalletAccountId,
                        hint: walletOptions.isEmpty
                            ? 'No wallet-linked entries yet'
                            : 'All wallets / accounts',
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('All wallets / accounts'),
                          ),
                          ...walletOptions.map(
                            (wallet) => DropdownMenuItem<String?>(
                              value: wallet.id,
                              child: Text(wallet.name),
                            ),
                          ),
                        ],
                        onChanged: walletOptions.isEmpty
                            ? null
                            : (value) => setState(
                                () => _selectedWalletAccountId = value,
                              ),
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 560;
                          final minField = _AmountRangeField(
                            controller: _minAmountController,
                            label: 'Min amount',
                            onChanged: (_) => setState(() {}),
                          );
                          final maxField = _AmountRangeField(
                            controller: _maxAmountController,
                            label: 'Max amount',
                            onChanged: (_) => setState(() {}),
                          );
                          if (stacked) {
                            return Column(
                              children: [
                                minField,
                                const SizedBox(height: 10),
                                maxField,
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: minField),
                              const SizedBox(width: 10),
                              Expanded(child: maxField),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final stacked = constraints.maxWidth < 560;
                          final children = [
                            _DateFilterButton(
                              label: _startDate == null
                                  ? 'Start Date'
                                  : AppFormatters.compactDate(_startDate!),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _startDate ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setState(() => _startDate = picked);
                                  await widget.controller
                                      .setLastSelectedStartDate(picked);
                                }
                              },
                              isActive: _startDate != null,
                              onClear: () async {
                                setState(() => _startDate = null);
                                await widget.controller
                                    .setLastSelectedStartDate(null);
                              },
                            ),
                            _DateFilterButton(
                              label: _endDate == null
                                  ? 'End Date'
                                  : AppFormatters.compactDate(_endDate!),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _endDate ?? DateTime.now(),
                                  firstDate: _startDate ?? DateTime(2000),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setState(() => _endDate = picked);
                                  await widget.controller
                                      .setLastSelectedEndDate(picked);
                                }
                              },
                              isActive: _endDate != null,
                              onClear: () async {
                                setState(() => _endDate = null);
                                await widget.controller.setLastSelectedEndDate(
                                  null,
                                );
                              },
                            ),
                          ];
                          if (stacked) {
                            return Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: children[0],
                                ),
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: children[1],
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(child: children[0]),
                              const SizedBox(width: 10),
                              Expanded(child: children[1]),
                            ],
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (_startDate != null ||
                _endDate != null ||
                _selectedCategory != null ||
                _selectedBank != null ||
                _selectedPaymentMethod != null ||
                _selectedTag != null ||
                _selectedWalletAccountId != null ||
                _minAmountController.text.trim().isNotEmpty ||
                _maxAmountController.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async => await _resetFilters(),
                    icon: const Icon(Icons.close),
                    label: const Text('Clear filters'),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (_viewMode == _TransactionViewMode.bank) ...[
              _BankSummaryCard(
                periodLabel: _bankSummaryLabel,
                selectedBank: _selectedBank,
                selectedType: _filter,
                creditTotal: bankCreditTotal,
                debitTotal: bankDebitTotal,
                netTotal: bankNetTotal,
                currencyCode: widget.controller.currencyCode,
              ),
              const SizedBox(height: 16),
            ],
            if (_viewMode == _TransactionViewMode.regular &&
                recurringTemplates.isNotEmpty) ...[
              Text(
                'Recurring Schedules',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Templates that automatically create dated entries up to today.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              ...recurringTemplates.map(
                (template) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _RecurringTemplateCard(
                    template: template,
                    controller: widget.controller,
                    onEdit: () async => _showEntryEditor(template),
                    onDelete: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final shouldDelete = await _confirmEntryDelete(template);
                      if (shouldDelete) {
                        await widget.controller.deleteEntry(template.id);
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                '${template.title} schedule deleted',
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              _viewMode == _TransactionViewMode.bank
                  ? 'Bank Imported Transactions'
                  : _filter == EntryType.expense
                  ? 'Expense Transactions'
                  : _filter == EntryType.income
                  ? 'Income Transactions'
                  : 'All Transactions',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              _viewMode == _TransactionViewMode.bank
                  ? 'Only imported bank alerts and bank-linked entries appear here.'
                  : 'Manual and imported transactions appear together here.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              EmptyStateCard(
                title: 'No matching transactions',
                message: query.isEmpty
                    ? _viewMode == _TransactionViewMode.bank
                          ? 'No bank transactions match this view yet.'
                          : 'Start recording activity to build your ledger.'
                    : 'Try another search or clear the filter chips.',
                icon: Icons.receipt_long_rounded,
                action: query.isNotEmpty
                    ? OutlinedButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        child: const Text('Clear search'),
                      )
                    : null,
              )
            else
              ListView.separated(
                itemCount: filtered.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final entry = filtered[index];
                  final category = widget.controller.findCategory(
                    entry.categoryId,
                  );
                  final isRecurringOccurrence = entry.isRecurringOccurrence;
                  final isTransferEntry = widget.controller.isTransferEntry(
                    entry,
                  );
                  return Dismissible(
                    key: ValueKey('entry-${entry.id}'),
                    background: const _TransactionSwipeActionBackground(
                      alignment: Alignment.centerLeft,
                      color: AppColors.primary,
                      icon: Icons.edit_rounded,
                      label: 'Edit',
                    ),
                    secondaryBackground:
                        const _TransactionSwipeActionBackground(
                          alignment: Alignment.centerRight,
                          color: AppColors.danger,
                          icon: Icons.delete_rounded,
                          label: 'Delete',
                        ),
                    confirmDismiss: (direction) async {
                      if (isRecurringOccurrence) {
                        return false;
                      }
                      if (direction == DismissDirection.startToEnd &&
                          !isTransferEntry) {
                        await _showEntryEditor(entry);
                        return false;
                      }
                      if (direction == DismissDirection.startToEnd &&
                          isTransferEntry) {
                        return false;
                      }
                      return _confirmEntryDelete(entry);
                    },
                    onDismissed: (_) async {
                      final messenger = ScaffoldMessenger.of(context);
                      await widget.controller.deleteEntry(entry.id);
                      messenger.showSnackBar(
                        SnackBar(content: Text('${entry.title} deleted')),
                      );
                    },
                    child: Card(
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor:
                              (category?.color ?? AppColors.primary).withValues(
                                alpha: 0.15,
                              ),
                          child: Icon(
                            category?.icon ?? Icons.category_rounded,
                            color: category?.color ?? AppColors.primary,
                          ),
                        ),
                        title: Text(entry.title),
                        subtitle: Text(_buildEntrySubtitle(entry, category)),
                        trailing: Text(
                          '${entry.type == EntryType.expense ? '-' : '+'}${AppFormatters.currency(entry.amount, symbol: widget.controller.currencyCode)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: entry.type == EntryType.expense
                                ? AppColors.danger
                                : AppColors.success,
                          ),
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _buildEntryMeta(entry),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                const SizedBox(height: 8),
                                if (entry.note.isNotEmpty) Text(entry.note),
                                if (isRecurringOccurrence) ...[
                                  const SizedBox(height: 8),
                                  const _RecurringEntryBanner(),
                                ],
                                if (isTransferEntry) ...[
                                  const SizedBox(height: 8),
                                  const _TransferEntryBanner(),
                                ],
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    TextButton(
                                      onPressed: () async {
                                        await _showEntryDetails(
                                          context,
                                          entry,
                                          category,
                                        );
                                      },
                                      child: const Text('View'),
                                    ),
                                    if (!isRecurringOccurrence &&
                                        !isTransferEntry)
                                      TextButton(
                                        onPressed: () async {
                                          await _showEntryEditor(entry);
                                        },
                                        child: const Text('Edit'),
                                      ),
                                    if (!isRecurringOccurrence)
                                      TextButton(
                                        onPressed: () async {
                                          final messenger =
                                              ScaffoldMessenger.of(context);
                                          final shouldDelete =
                                              await _confirmEntryDelete(entry);
                                          if (shouldDelete) {
                                            await widget.controller.deleteEntry(
                                              entry.id,
                                            );
                                            messenger.showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  '${entry.title} deleted',
                                                ),
                                              ),
                                            );
                                            setState(() {});
                                          }
                                        },
                                        child: const Text('Delete'),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        Positioned(
          left: floatingTotalsSideMargin,
          right: floatingTotalsSideMargin,
          bottom: floatingTotalsBottomOffset,
          child: _TransactionTotals(
            entries: filtered,
            controller: widget.controller,
            floating: true,
          ),
        ),
      ],
    );
  }

  Future<void> _showEntryDetails(
    BuildContext context,
    ExpenseEntry entry,
    ExpenseCategory? category,
  ) async {
    final resolvedBankName = _resolvedBankName(entry);
    final wallet = widget.controller.findWallet(
      widget.controller.resolveWalletIdForEntry(entry),
    );
    final amountText =
        '${entry.type == EntryType.expense ? '-' : '+'}${AppFormatters.currency(entry.amount, symbol: widget.controller.currencyCode)}';
    final sourceLabel = switch (entry.source) {
      TransactionSource.sms => 'SMS Import',
      TransactionSource.bankApi => 'Bank API',
      TransactionSource.manual => 'Manual Entry',
    };

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).padding.bottom + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 16),
                _TransactionDetailRow(label: 'Amount', value: amountText),
                _TransactionDetailRow(
                  label: 'Category',
                  value: category?.name ?? 'Category',
                ),
                if (resolvedBankName.isNotEmpty)
                  _TransactionDetailRow(label: 'Bank', value: resolvedBankName),
                _TransactionDetailRow(
                  label: 'Payment method',
                  value: entry.paymentMethod,
                ),
                if (wallet != null)
                  _TransactionDetailRow(label: 'Wallet', value: wallet.name),
                _TransactionDetailRow(
                  label: 'Transaction type',
                  value: entry.type == EntryType.expense
                      ? 'Debit / Expense'
                      : 'Credit / Income',
                ),
                _TransactionDetailRow(
                  label: 'Date',
                  value: AppFormatters.compactDate(entry.date),
                ),
                if (entry.isRecurringOccurrence)
                  const _TransactionDetailRow(
                    label: 'Schedule',
                    value: 'Auto-generated from a recurring template',
                  ),
                if (entry.isRecurringTemplate)
                  _TransactionDetailRow(
                    label: 'Repeats',
                    value: _recurrenceLabel(entry.recurrenceFrequency),
                  ),
                _TransactionDetailRow(label: 'Source', value: sourceLabel),
                if (entry.accountHint.isNotEmpty)
                  _TransactionDetailRow(
                    label: 'Account hint',
                    value: entry.accountHint,
                  ),
                if (entry.tag.isNotEmpty)
                  _TransactionDetailRow(label: 'Tag', value: entry.tag),
                if (entry.merchantOrSender.isNotEmpty)
                  _TransactionDetailRow(
                    label: 'Description',
                    value: entry.merchantOrSender,
                  ),
                if (entry.importedAt != null)
                  _TransactionDetailRow(
                    label: 'Imported at',
                    value: AppFormatters.compactDate(entry.importedAt!),
                  ),
                if (entry.note.isNotEmpty)
                  _TransactionDetailRow(label: 'Note', value: entry.note),
                if (entry.rawMessage.isNotEmpty)
                  _TransactionDetailRow(
                    label: 'Raw alert',
                    value: entry.rawMessage,
                    isMonospace: true,
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: entry.isRecurringOccurrence
                        ? null
                        : () async {
                            Navigator.of(context).pop();
                            await showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              showDragHandle: true,
                              builder: (_) => TransactionFormSheet(
                                controller: widget.controller,
                                entry: entry,
                              ),
                            );
                          },
                    child: Text(
                      entry.isRecurringOccurrence
                          ? 'Managed by schedule'
                          : 'Edit entry',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEntryEditor(ExpenseEntry entry) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          TransactionFormSheet(controller: widget.controller, entry: entry),
    );
  }

  List<ExpenseEntry> _bankEntriesForSummary(List<ExpenseEntry> entries) {
    final range = _bankSummaryRange();
    return entries.where((entry) {
      final bankName = _resolvedBankName(entry);
      if (bankName.isEmpty) {
        return false;
      }
      final matchesBank = _selectedBank == null || bankName == _selectedBank;
      final matchesRange =
          !entry.date.isBefore(range.start) && !entry.date.isAfter(range.end);
      return matchesBank && matchesRange;
    }).toList();
  }

  ({DateTime start, DateTime end}) _bankSummaryRange() {
    if (_startDate != null && _endDate != null) {
      return (
        start: DateTime(_startDate!.year, _startDate!.month, _startDate!.day),
        end: DateTime(
          _endDate!.year,
          _endDate!.month,
          _endDate!.day,
          23,
          59,
          59,
          999,
        ),
      );
    }

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    return (start: start, end: end);
  }

  String _resolvedBankName(ExpenseEntry entry) {
    if (entry.institutionName.trim().isNotEmpty) {
      return entry.institutionName.trim();
    }
    final paymentMethod = entry.paymentMethod.trim();
    if (_looksLikeBankName(paymentMethod)) {
      return _normalizeBankName(paymentMethod);
    }
    final title = entry.title.trim();
    if (_looksLikeBankName(title)) {
      return _normalizeBankName(title);
    }
    final rawText =
        '${entry.note} ${entry.rawMessage} ${entry.merchantOrSender}'.trim();
    final match = RegExp(
      r'(providus|wema\s*bank|wemabank|gtbank|gt\s*bank|access\s*bank|union\s*bank|unionbank|stanbic(?:\s*ibtc)?)',
      caseSensitive: false,
    ).firstMatch(rawText);
    return _normalizeBankName(match?.group(0) ?? '');
  }

  bool _looksLikeBankName(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('bank') ||
        normalized.contains('providus') ||
        normalized.contains('stanbic');
  }

  String _normalizeBankName(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.contains('providus')) return 'Providus';
    if (normalized.contains('wema')) return 'Wema Bank';
    if (normalized.contains('gtbank') || normalized.contains('gt bank')) {
      return 'GTBank';
    }
    if (normalized.contains('access')) return 'Access Bank';
    if (normalized.contains('union')) return 'Union Bank';
    if (normalized.contains('stanbic')) return 'Stanbic IBTC';
    return value.trim();
  }

  String _buildEntrySubtitle(ExpenseEntry entry, ExpenseCategory? category) {
    final bankName = _resolvedBankName(entry);
    final wallet = widget.controller.findWallet(
      widget.controller.resolveWalletIdForEntry(entry),
    );
    final recurringLabel = entry.isRecurringOccurrence ? 'Recurring' : null;
    final transferLabel = widget.controller.isTransferEntry(entry)
        ? 'Transfer'
        : null;
    final tagLabel = entry.tag.trim().isEmpty ? null : '#${entry.tag.trim()}';
    if (bankName.isNotEmpty) {
      return [
        bankName,
        if (wallet != null) wallet.name,
        AppFormatters.compactDate(entry.date),
        ...?tagLabel == null ? null : [tagLabel],
        ...?transferLabel == null ? null : [transferLabel],
        ...?recurringLabel == null ? null : [recurringLabel],
      ].join(' • ');
    }
    return [
      category?.name ?? 'Category',
      if (wallet != null) wallet.name,
      AppFormatters.compactDate(entry.date),
      ...?tagLabel == null ? null : [tagLabel],
      ...?transferLabel == null ? null : [transferLabel],
      ...?recurringLabel == null ? null : [recurringLabel],
    ].join(' • ');
  }

  String _buildEntryMeta(ExpenseEntry entry) {
    final bankName = _resolvedBankName(entry);
    final wallet = widget.controller.findWallet(
      widget.controller.resolveWalletIdForEntry(entry),
    );
    final parts = <String>[
      if (wallet != null) wallet.name,
      if (bankName.isNotEmpty) bankName else entry.paymentMethod,
      AppFormatters.compactDate(entry.date),
      if (entry.accountHint.isNotEmpty) entry.accountHint,
      if (entry.tag.isNotEmpty) '#${entry.tag}',
      if (widget.controller.isTransferEntry(entry)) 'Internal transfer',
      if (entry.isRecurringOccurrence) 'Scheduled',
    ];
    return parts.join(' • ');
  }

  String _recurrenceLabel(RecurrenceFrequency frequency) {
    switch (frequency) {
      case RecurrenceFrequency.weekly:
        return 'Weekly';
      case RecurrenceFrequency.monthly:
        return 'Monthly';
      case RecurrenceFrequency.yearly:
        return 'Yearly';
      case RecurrenceFrequency.none:
        return 'Does not repeat';
    }
  }

  String get _filterDropdownValue {
    if (_filter == EntryType.expense) {
      return 'expense';
    }
    if (_filter == EntryType.income) {
      return 'income';
    }
    return 'all';
  }

  String get _quickPeriodValue {
    if (_matchesQuickPeriod(const Duration(days: 1))) {
      return 'daily';
    }
    if (_matchesQuickPeriod(const Duration(days: 7))) {
      return 'weekly';
    }
    if (_isCurrentMonthRange()) {
      return 'monthly';
    }
    if (_isCurrentYearRange()) {
      return 'yearly';
    }
    return 'custom';
  }

  String get _bankSummaryLabel {
    switch (_quickPeriodValue) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'monthly':
        return 'Monthly';
      case 'yearly':
        return 'Yearly';
      case 'custom':
      default:
        return 'Custom';
    }
  }

  bool _matchesQuickPeriod(Duration duration) {
    if (_startDate == null || _endDate == null) {
      return false;
    }
    final today = DateTime.now();
    final expectedStart = DateTime(
      today.subtract(duration - const Duration(days: 1)).year,
      today.subtract(duration - const Duration(days: 1)).month,
      today.subtract(duration - const Duration(days: 1)).day,
    );
    final expectedEnd = DateTime(today.year, today.month, today.day);
    return _isSameDate(_startDate!, expectedStart) &&
        _isSameDate(_endDate!, expectedEnd);
  }

  bool _isCurrentMonthRange() {
    if (_startDate == null || _endDate == null) {
      return false;
    }
    final now = DateTime.now();
    return _isSameDate(_startDate!, DateTime(now.year, now.month, 1)) &&
        _isSameDate(_endDate!, DateTime(now.year, now.month, now.day));
  }

  bool _isCurrentYearRange() {
    if (_startDate == null || _endDate == null) {
      return false;
    }
    final now = DateTime.now();
    return _isSameDate(_startDate!, DateTime(now.year, 1, 1)) &&
        _isSameDate(_endDate!, DateTime(now.year, now.month, now.day));
  }

  Future<void> _setQuickPeriod(Duration duration) async {
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    final rawStart = today.subtract(duration - const Duration(days: 1));
    final start = DateTime(rawStart.year, rawStart.month, rawStart.day);
    setState(() {
      _startDate = start;
      _endDate = end;
    });
    await widget.controller.setLastSelectedStartDate(start);
    await widget.controller.setLastSelectedEndDate(end);
  }

  Future<void> _setCurrentMonthRange() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month, now.day);
    setState(() {
      _startDate = start;
      _endDate = end;
    });
    await widget.controller.setLastSelectedStartDate(start);
    await widget.controller.setLastSelectedEndDate(end);
  }

  Future<void> _setCurrentYearRange() async {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year, now.month, now.day);
    setState(() {
      _startDate = start;
      _endDate = end;
    });
    await widget.controller.setLastSelectedStartDate(start);
    await widget.controller.setLastSelectedEndDate(end);
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _importFromSms() async {
    setState(() => _isImportingFromSms = true);
    final messenger = ScaffoldMessenger.of(context);
    final session = await _smsImportService.prepareImport(
      existingEntries: widget.controller.entries,
      categories: widget.controller.categories,
    );
    if (!mounted) {
      return;
    }
    setState(() => _isImportingFromSms = false);

    switch (session.status) {
      case SmsImportStatus.unsupported:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('SMS import is currently available on Android only.'),
          ),
        );
        return;
      case SmsImportStatus.permissionDenied:
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'SMS permission was denied. Allow SMS access to import alerts.',
            ),
          ),
        );
        return;
      case SmsImportStatus.failed:
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              session.errorMessage ?? 'Unable to read SMS messages right now.',
            ),
          ),
        );
        return;
      case SmsImportStatus.ready:
        if (session.candidates.isEmpty) {
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                session.duplicateCount > 0
                    ? 'No new SMS transactions found. ${session.duplicateCount} duplicates were skipped.'
                    : 'No debit or credit SMS alerts were found in the selected window.',
              ),
            ),
          );
          return;
        }
    }

    final importedCount = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          SmsImportSheet(controller: widget.controller, session: session),
    );

    if (!mounted || importedCount == null || importedCount == 0) {
      return;
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Imported $importedCount transaction${importedCount == 1 ? '' : 's'} from SMS.',
        ),
      ),
    );
  }

  Future<bool> _confirmEntryDelete(ExpenseEntry entry) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: Text('Remove "${entry.title}" from your transaction list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return shouldDelete ?? false;
  }
}

class _TransactionDetailRow extends StatelessWidget {
  const _TransactionDetailRow({
    required this.label,
    required this.value,
    this.isMonospace = false,
  });

  final String label;
  final String value;
  final bool isMonospace;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.35,
              fontFamily: isMonospace ? 'monospace' : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final String hint;
  final List<DropdownMenuItem<String?>> items;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String?>(
          isExpanded: true,
          value: value,
          hint: Text(hint),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SelectionDropdown<T> extends StatelessWidget {
  const _SelectionDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _FilterSectionLabel extends StatelessWidget {
  const _FilterSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _TransactionSwipeActionBackground extends StatelessWidget {
  const _TransactionSwipeActionBackground({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: alignment == Alignment.centerLeft
            ? MainAxisAlignment.start
            : MainAxisAlignment.end,
        children: [
          if (alignment == Alignment.centerRight)
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (alignment == Alignment.centerRight) const SizedBox(width: 8),
          Icon(icon, color: Colors.white),
          if (alignment == Alignment.centerLeft) const SizedBox(width: 8),
          if (alignment == Alignment.centerLeft)
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}

class _DateFilterButton extends StatelessWidget {
  const _DateFilterButton({
    required this.label,
    required this.onPressed,
    required this.isActive,
    required this.onClear,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isActive;
  final Future<void> Function() onClear;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_rounded, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (isActive)
            IconButton(
              onPressed: () async => await onClear(),
              icon: const Icon(Icons.close_rounded, size: 18),
              splashRadius: 18,
              tooltip: 'Clear date',
            ),
        ],
      ),
    );
  }
}

class _AmountRangeField extends StatelessWidget {
  const _AmountRangeField({
    required this.controller,
    required this.label,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, prefixText: 'NGN '),
    );
  }
}

class _BankSummaryCard extends StatelessWidget {
  const _BankSummaryCard({
    required this.periodLabel,
    required this.selectedBank,
    required this.selectedType,
    required this.creditTotal,
    required this.debitTotal,
    required this.netTotal,
    required this.currencyCode,
  });

  final String periodLabel;
  final String? selectedBank;
  final EntryType? selectedType;
  final double creditTotal;
  final double debitTotal;
  final double netTotal;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 640;
    final title = selectedBank == null
        ? 'Bank Transaction Totals'
        : '$selectedBank Totals';
    final showCredit = selectedType != EntryType.expense;
    final showDebit = selectedType != EntryType.income;
    final showNet = selectedType == null;

    return Card(
      color: const Color(0xFFF4F7FF),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Credit and debit totals from imported bank alerts',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).dividerColor),
                  ),
                  child: Text(
                    periodLabel,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                if (showCredit)
                  SizedBox(
                    width: isCompact ? double.infinity : 180,
                    child: _MetricTile(
                      label: 'Total Credit',
                      value: AppFormatters.currency(
                        creditTotal,
                        symbol: currencyCode,
                      ),
                      color: AppColors.success,
                      icon: Icons.south_west_rounded,
                    ),
                  ),
                if (showDebit)
                  SizedBox(
                    width: isCompact ? double.infinity : 180,
                    child: _MetricTile(
                      label: 'Total Debit',
                      value: AppFormatters.currency(
                        debitTotal,
                        symbol: currencyCode,
                      ),
                      color: AppColors.danger,
                      icon: Icons.north_east_rounded,
                    ),
                  ),
                if (showNet)
                  SizedBox(
                    width: isCompact ? double.infinity : 180,
                    child: _MetricTile(
                      label: 'Net Flow',
                      value: AppFormatters.currency(
                        netTotal,
                        symbol: currencyCode,
                      ),
                      color: netTotal >= 0
                          ? AppColors.success
                          : AppColors.danger,
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurringTemplateCard extends StatelessWidget {
  const _RecurringTemplateCard({
    required this.template,
    required this.controller,
    required this.onEdit,
    required this.onDelete,
  });

  final ExpenseEntry template;
  final AppController controller;
  final Future<void> Function() onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final nextDueDate = controller.nextDueDateForTemplate(template);
    final recurrenceLabel = switch (template.recurrenceFrequency) {
      RecurrenceFrequency.weekly => 'Weekly',
      RecurrenceFrequency.monthly => 'Monthly',
      RecurrenceFrequency.yearly => 'Yearly',
      RecurrenceFrequency.none => 'No repeat',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        template.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${AppFormatters.currency(template.amount, symbol: controller.currencyCode)} • $recurrenceLabel',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    template.type == EntryType.expense ? 'Expense' : 'Income',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _SchedulePill(
                  icon: Icons.event_available_rounded,
                  label: nextDueDate == null
                      ? 'No upcoming occurrence'
                      : 'Next due ${AppFormatters.compactDate(nextDueDate)}',
                ),
                _SchedulePill(
                  icon: Icons.calendar_today_rounded,
                  label: 'Starts ${AppFormatters.compactDate(template.date)}',
                ),
                if (template.recurrenceEndDate != null)
                  _SchedulePill(
                    icon: Icons.event_busy_rounded,
                    label:
                        'Ends ${AppFormatters.compactDate(template.recurrenceEndDate!)}',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: onEdit,
                  child: const Text('Edit schedule'),
                ),
                TextButton(
                  onPressed: onDelete,
                  child: const Text('Delete schedule'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SchedulePill extends StatelessWidget {
  const _SchedulePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _RecurringEntryBanner extends StatelessWidget {
  const _RecurringEntryBanner();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.sync_rounded, size: 16, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'This entry is generated from a recurring schedule. Edit the schedule instead.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransferEntryBanner extends StatelessWidget {
  const _TransferEntryBanner();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.success),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'This entry is part of an internal wallet transfer. Delete it to remove both sides.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTotals extends StatelessWidget {
  const _TransactionTotals({
    required this.entries,
    required this.controller,
    this.floating = false,
  });

  final List<ExpenseEntry> entries;
  final AppController controller;
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final totalIncome = entries
        .where((e) => e.type == EntryType.income)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final totalExpense = entries
        .where((e) => e.type == EntryType.expense)
        .fold<double>(0, (sum, e) => sum + e.amount);

    final totals = [
      _TotalCard(
        label: 'Total Income',
        amount: totalIncome,
        color: AppColors.success,
        symbol: controller.currencyCode,
      ),
      _TotalCard(
        label: 'Total Expense',
        amount: totalExpense,
        color: AppColors.danger,
        symbol: controller.currencyCode,
      ),
      _TotalCard(
        label: 'Net',
        amount: totalIncome - totalExpense,
        color: (totalIncome - totalExpense) >= 0
            ? AppColors.success
            : AppColors.danger,
        symbol: controller.currencyCode,
      ),
    ];

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 280;
          if (compact) {
            return Column(
              children: [
                for (var index = 0; index < totals.length; index++) ...[
                  totals[index],
                  if (index != totals.length - 1) const SizedBox(height: 10),
                ],
              ],
            );
          }
          return Row(
            children: [
              for (var index = 0; index < totals.length; index++) ...[
                Expanded(child: totals[index]),
                if (index != totals.length - 1) const SizedBox(width: 12),
              ],
            ],
          );
        },
      ),
    );

    if (floating) {
      return Material(
        elevation: 8,
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.28),
            ),
          ),
          child: content,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: content,
    );
  }
}

class _TotalCard extends StatelessWidget {
  const _TotalCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.symbol,
  });

  final String label;
  final double amount;
  final Color color;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            AppFormatters.currency(amount, symbol: symbol),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
