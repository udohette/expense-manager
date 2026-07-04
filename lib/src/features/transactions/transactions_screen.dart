import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/app_formatters.dart';
import '../../data/models/expense_category.dart';
import '../../data/models/expense_entry.dart';
import '../../data/services/app_controller.dart';
import '../../widgets/empty_state_card.dart';
import '../../widgets/section_header.dart';
import '../dashboard/home_shell.dart';
import 'transaction_form_sheet.dart';

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
  EntryType? _filter;
  String? _selectedCategory;
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    setState(() {
      _filter = null;
      _selectedCategory = null;
      _startDate = null;
      _endDate = null;
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = widget.controller.entries.where((entry) {
      final category = widget.controller.findCategory(entry.categoryId);
      final matchesType = _filter == null || entry.type == _filter;
      final matchesCategory =
          _selectedCategory == null || entry.categoryId == _selectedCategory;
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
          entry.note.toLowerCase().contains(query);
      return matchesType && matchesCategory && matchesDateRange && matchesQuery;
    }).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Transactions',
            subtitle:
                'Search, review, and maintain every expense and income record',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Search by title, note, or category',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 14),
          // Type filter chips
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _filter == null,
                onSelected: (_) => setState(() => _filter = null),
              ),
              ChoiceChip(
                label: const Text('Expenses'),
                selected: _filter == EntryType.expense,
                onSelected: (_) => setState(() => _filter = EntryType.expense),
              ),
              ChoiceChip(
                label: const Text('Income'),
                selected: _filter == EntryType.income,
                onSelected: (_) => setState(() => _filter = EntryType.income),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Date and category filters
          Row(
            children: [
              Expanded(
                child: _DateFilterButton(
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
                    }
                  },
                  isActive: _startDate != null,
                  onClear: () => setState(() => _startDate = null),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DateFilterButton(
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
                    }
                  },
                  isActive: _endDate != null,
                  onClear: () => setState(() => _endDate = null),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Category filter (dropdown)
          Row(
            children: [
              const Text(
                'Category:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: _selectedCategory,
                  hint: const Text('All Categories'),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All Categories'),
                    ),
                    ...widget.controller.categories
                        .where(
                          (cat) => widget.controller.entries.any(
                            (e) => e.categoryId == cat.id,
                          ),
                        )
                        .map(
                          (cat) => DropdownMenuItem<String?>(
                            value: cat.id,
                            child: Text(cat.name),
                          ),
                        )
                        .toList(),
                  ],
                  onChanged: (v) => setState(() => _selectedCategory = v),
                ),
              ),
            ],
          ),
          if (_startDate != null ||
              _endDate != null ||
              _selectedCategory != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _resetFilters,
                  icon: const Icon(Icons.close),
                  label: const Text('Clear filters'),
                ),
              ),
            ),
          const SizedBox(height: 16),
          Expanded(
            child: filtered.isEmpty
                ? EmptyStateCard(
                    title: 'No matching transactions',
                    message: query.isEmpty
                        ? 'Start recording activity to build your ledger.'
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
                : Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final entry = filtered[index];
                            final category = widget.controller.findCategory(
                              entry.categoryId,
                            );
                            return Dismissible(
                              key: ValueKey('entry-${entry.id}'),
                              background:
                                  const _TransactionSwipeActionBackground(
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
                                if (direction == DismissDirection.startToEnd) {
                                  await _showEntryEditor(entry);
                                  return false;
                                }
                                return _confirmEntryDelete(entry);
                              },
                              onDismissed: (_) async {
                                final messenger = ScaffoldMessenger.of(context);
                                await widget.controller.deleteEntry(entry.id);
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: Text('${entry.title} deleted'),
                                  ),
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
                                        (category?.color ?? AppColors.primary)
                                            .withValues(alpha: 0.15),
                                    child: Icon(
                                      category?.icon ?? Icons.category_rounded,
                                      color:
                                          category?.color ?? AppColors.primary,
                                    ),
                                  ),
                                  title: Text(entry.title),
                                  subtitle: Text(
                                    '${category?.name ?? 'Category'} • ${AppFormatters.compactDate(entry.date)}',
                                  ),
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
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        0,
                                        16,
                                        12,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${entry.paymentMethod} • ${AppFormatters.compactDate(entry.date)}',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                          ),
                                          const SizedBox(height: 8),
                                          if (entry.note.isNotEmpty)
                                            Text(entry.note),
                                          const SizedBox(height: 12),
                                          Row(
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
                                              const SizedBox(width: 8),
                                              TextButton(
                                                onPressed: () async {
                                                  await _showEntryEditor(entry);
                                                },
                                                child: const Text('Edit'),
                                              ),
                                              const SizedBox(width: 8),
                                              TextButton(
                                                onPressed: () async {
                                                  final shouldDelete =
                                                      await _confirmEntryDelete(
                                                        entry,
                                                      );
                                                  if (shouldDelete) {
                                                    await widget.controller
                                                        .deleteEntry(entry.id);
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
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
                      ),
                      // Totals below the list
                      _TransactionTotals(
                        entries: filtered,
                        controller: widget.controller,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEntryDetails(
    BuildContext context,
    ExpenseEntry entry,
    ExpenseCategory? category,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              _TransactionDetailRow(
                label: 'Amount',
                value:
                    '${entry.type == EntryType.expense ? '-' : '+'}${AppFormatters.currency(entry.amount, symbol: widget.controller.currencyCode)}',
              ),
              _TransactionDetailRow(
                label: 'Category',
                value: category?.name ?? 'Category',
              ),
              _TransactionDetailRow(
                label: 'Payment method',
                value: entry.paymentMethod,
              ),
              _TransactionDetailRow(
                label: 'Date',
                value: AppFormatters.compactDate(entry.date),
              ),
              if (entry.note.isNotEmpty)
                _TransactionDetailRow(label: 'Note', value: entry.note),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
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
                  child: const Text('Edit entry'),
                ),
              ),
            ],
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
  const _TransactionDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
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
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.calendar_today_rounded, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }
}

class _TransactionTotals extends StatelessWidget {
  const _TransactionTotals({required this.entries, required this.controller});

  final List<ExpenseEntry> entries;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final totalIncome = entries
        .where((e) => e.type == EntryType.income)
        .fold<double>(0, (sum, e) => sum + e.amount);
    final totalExpense = entries
        .where((e) => e.type == EntryType.expense)
        .fold<double>(0, (sum, e) => sum + e.amount);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
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
        ],
      ),
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
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          AppFormatters.currency(amount, symbol: symbol),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
