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
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = widget.controller.entries.where((entry) {
      final category = widget.controller.findCategory(entry.categoryId);
      final matchesFilter = _filter == null || entry.type == _filter;
      final matchesQuery =
          query.isEmpty ||
          entry.title.toLowerCase().contains(query) ||
          (category?.name.toLowerCase().contains(query) ?? false) ||
          entry.note.toLowerCase().contains(query);
      return matchesFilter && matchesQuery;
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
                : ListView.separated(
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
                            SnackBar(content: Text('${entry.title} deleted')),
                          );
                        },
                        child: Card(
                          child: ListTile(
                            onTap: () =>
                                _showEntryDetails(context, entry, category),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            leading: CircleAvatar(
                              backgroundColor:
                                  (category?.color ?? AppColors.primary)
                                      .withValues(alpha: 0.15),
                              child: Icon(
                                category?.icon ?? Icons.category_rounded,
                                color: category?.color ?? AppColors.primary,
                              ),
                            ),
                            title: Text(entry.title),
                            subtitle: Text(
                              '${category?.name ?? 'Category'} • ${entry.paymentMethod} • ${AppFormatters.compactDate(entry.date)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${entry.type == EntryType.expense ? '-' : '+'}${AppFormatters.currency(entry.amount, symbol: widget.controller.currencyCode)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: entry.type == EntryType.expense
                                        ? AppColors.danger
                                        : AppColors.success,
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert_rounded),
                                  onSelected: (value) async {
                                    if (value == 'view') {
                                      await _showEntryDetails(
                                        context,
                                        entry,
                                        category,
                                      );
                                    } else if (value == 'edit') {
                                      await _showEntryEditor(entry);
                                    } else {
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
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
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'view',
                                      child: Text('View'),
                                    ),
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
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
