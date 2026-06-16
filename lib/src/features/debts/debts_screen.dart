import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/app_formatters.dart';
import '../../data/models/debt_record.dart';
import '../../data/services/app_controller.dart';
import '../../widgets/empty_state_card.dart';
import '../../widgets/section_header.dart';
import '../dashboard/home_shell.dart';
import 'debt_form_sheet.dart';

class DebtsScreen extends StatefulWidget implements QuickActionHost {
  const DebtsScreen({required this.controller, super.key});

  final AppController controller;

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();

  @override
  void onQuickAction(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DebtFormSheet(controller: controller),
    );
  }
}

class _DebtsScreenState extends State<DebtsScreen> {
  DebtType? _filter;

  @override
  Widget build(BuildContext context) {
    final filteredDebts = widget.controller.debts.where((debt) {
      return _filter == null || debt.type == _filter;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Debts',
            subtitle:
                'Track both money owed to you and money you still need to pay',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DebtSummaryCard(
                  title: 'Owed to me',
                  amount: widget.controller.receivablesTotal,
                  color: AppColors.success,
                  controller: widget.controller,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DebtSummaryCard(
                  title: 'I owe',
                  amount: widget.controller.payablesTotal,
                  color: AppColors.warning,
                  controller: widget.controller,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                label: const Text('Owed to me'),
                selected: _filter == DebtType.owedToMe,
                onSelected: (_) => setState(() => _filter = DebtType.owedToMe),
              ),
              ChoiceChip(
                label: const Text('I owe'),
                selected: _filter == DebtType.iOwe,
                onSelected: (_) => setState(() => _filter = DebtType.iOwe),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (filteredDebts.isEmpty)
            EmptyStateCard(
              title: 'No debt records yet',
              message:
                  'Create a debtor or creditor record manually, or pull the person from your contacts.',
              icon: Icons.account_balance_wallet_rounded,
              action: FilledButton(
                onPressed: () => widget.onQuickAction(context),
                child: const Text('Add debt'),
              ),
            )
          else
            ...filteredDebts.map(
              (debt) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Dismissible(
                  key: ValueKey('debt-${debt.id}'),
                  background: const _SwipeActionBackground(
                    alignment: Alignment.centerLeft,
                    color: AppColors.primary,
                    icon: Icons.edit_rounded,
                    label: 'Edit',
                  ),
                  secondaryBackground: const _SwipeActionBackground(
                    alignment: Alignment.centerRight,
                    color: AppColors.danger,
                    icon: Icons.delete_rounded,
                    label: 'Delete',
                  ),
                  confirmDismiss: (direction) async {
                    if (direction == DismissDirection.startToEnd) {
                      await _showDebtEditor(debt);
                      return false;
                    }
                    return _confirmDebtDelete(debt);
                  },
                  onDismissed: (_) async {
                    final messenger = ScaffoldMessenger.of(context);
                    await widget.controller.deleteDebt(debt.id);
                    messenger.showSnackBar(
                      SnackBar(content: Text('${debt.personName} deleted')),
                    );
                  },
                  child: _DebtTile(
                    controller: widget.controller,
                    debt: debt,
                    onEdit: () => _showDebtEditor(debt),
                    onView: () => _showDebtDetails(debt),
                    onDelete: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final shouldDelete = await _confirmDebtDelete(debt);
                      if (shouldDelete) {
                        await widget.controller.deleteDebt(debt.id);
                        messenger.showSnackBar(
                          SnackBar(content: Text('${debt.personName} deleted')),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showDebtEditor(DebtRecord debt) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => DebtFormSheet(controller: widget.controller, debt: debt),
    );
  }

  Future<void> _showDebtDetails(DebtRecord debt) async {
    final typeLabel = debt.type == DebtType.owedToMe ? 'Owed to me' : 'I owe';
    final statusLabel = debt.status == DebtStatus.active ? 'Active' : 'Settled';
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
                debt.personName,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              _DetailRow(
                label: 'Amount',
                value: AppFormatters.currency(
                  debt.amount,
                  symbol: widget.controller.currencyCode,
                ),
              ),
              _DetailRow(label: 'Direction', value: typeLabel),
              _DetailRow(label: 'Status', value: statusLabel),
              _DetailRow(
                label: 'Source',
                value: debt.personSource == DebtPersonSource.contacts
                    ? 'From contacts'
                    : 'Manual entry',
              ),
              if ((debt.phoneNumber ?? '').isNotEmpty)
                _DetailRow(label: 'Phone', value: debt.phoneNumber!),
              if (debt.dueDate != null)
                _DetailRow(
                  label: 'Due date',
                  value: AppFormatters.compactDate(debt.dueDate!),
                ),
              if (debt.note.isNotEmpty)
                _DetailRow(label: 'Note', value: debt.note),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    await _showDebtEditor(debt);
                  },
                  child: const Text('Edit record'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDebtDelete(DebtRecord debt) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete debt record?'),
        content: Text('Remove ${debt.personName} from your debt list?'),
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

class _DebtSummaryCard extends StatelessWidget {
  const _DebtSummaryCard({
    required this.title,
    required this.amount,
    required this.color,
    required this.controller,
  });

  final String title;
  final double amount;
  final Color color;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.payments_rounded, color: color),
            const SizedBox(height: 10),
            Text(title, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text(
              AppFormatters.currency(amount, symbol: controller.currencyCode),
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtTile extends StatelessWidget {
  const _DebtTile({
    required this.controller,
    required this.debt,
    required this.onEdit,
    required this.onView,
    required this.onDelete,
  });

  final AppController controller;
  final DebtRecord debt;
  final Future<void> Function() onEdit;
  final Future<void> Function() onView;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final color = debt.type == DebtType.owedToMe
        ? AppColors.success
        : AppColors.warning;
    return Card(
      child: ListTile(
        onTap: onView,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.14),
          child: Icon(
            debt.type == DebtType.owedToMe
                ? Icons.call_received_rounded
                : Icons.call_made_rounded,
            color: color,
          ),
        ),
        title: Row(
          children: [
            Expanded(child: Text(debt.personName)),
            Text(
              AppFormatters.currency(
                debt.amount,
                symbol: controller.currencyCode,
              ),
              style: TextStyle(fontWeight: FontWeight.w800, color: color),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  debt.personSource == DebtPersonSource.contacts
                      ? 'From contacts'
                      : 'Manual entry',
                  debt.phoneNumber ?? '',
                  debt.status == DebtStatus.active ? 'Active' : 'Settled',
                ].where((item) => item.isNotEmpty).join(' • '),
              ),
              if (debt.dueDate != null)
                Text(
                  'Due ${AppFormatters.compactDate(debt.dueDate!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (value) async {
            if (value == 'view') {
              await onView();
            } else if (value == 'edit') {
              await onEdit();
            } else if (value == 'settle') {
              await controller.updateDebt(
                debt.copyWith(status: DebtStatus.settled),
              );
            } else {
              await onDelete();
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'view', child: Text('View')),
            const PopupMenuItem(value: 'edit', child: Text('Edit')),
            if (debt.status == DebtStatus.active)
              const PopupMenuItem(value: 'settle', child: Text('Mark settled')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

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

class _SwipeActionBackground extends StatelessWidget {
  const _SwipeActionBackground({
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
