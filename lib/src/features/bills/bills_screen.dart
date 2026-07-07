import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/app_formatters.dart';
import '../../data/models/bill_record.dart';
import '../../data/services/app_controller.dart';
import '../../widgets/empty_state_card.dart';
import '../../widgets/section_header.dart';
import 'bill_form_sheet.dart';

class BillsScreen extends StatelessWidget {
  const BillsScreen({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bills')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBillForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add bill'),
        backgroundColor: AppColors.primary,
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Bill planner',
                subtitle:
                    'Track upcoming bills, reminder windows, and paid status.',
              ),
              const SizedBox(height: 16),
              if (controller.bills.isEmpty)
                EmptyStateCard(
                  title: 'No bills yet',
                  message:
                      'Create recurring bills for rent, subscriptions, electricity, and loan repayments.',
                  icon: Icons.receipt_rounded,
                  action: FilledButton(
                    onPressed: () => _showBillForm(context),
                    child: const Text('Create bill'),
                  ),
                )
              else
                ...controller.bills.map(
                  (bill) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _BillCard(controller: controller, bill: bill),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showBillForm(BuildContext context, {BillRecord? bill}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => BillFormSheet(controller: controller, bill: bill),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.controller, required this.bill});

  final AppController controller;
  final BillRecord bill;

  @override
  Widget build(BuildContext context) {
    final wallet = controller.findWallet(bill.walletAccountId);
    final now = DateTime.now();
    final dueSoon =
        !bill.isPaid &&
        !bill.reminderDate.isAfter(now) &&
        !bill.dueDate.isBefore(DateTime(now.year, now.month, now.day));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
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
                        bill.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        AppFormatters.currency(
                          bill.amount,
                          symbol: controller.currencyCode,
                        ),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    switch (value) {
                      case 'toggle':
                        await controller.updateBill(
                          bill.copyWith(isPaid: !bill.isPaid),
                        );
                        break;
                      case 'edit':
                        await showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          showDragHandle: true,
                          builder: (_) =>
                              BillFormSheet(controller: controller, bill: bill),
                        );
                        break;
                      case 'delete':
                        await controller.deleteBill(bill.id);
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'toggle',
                      child: Text(bill.isPaid ? 'Mark unpaid' : 'Mark paid'),
                    ),
                    const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    const PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    bill.isPaid
                        ? 'Paid'
                        : dueSoon
                        ? 'Due soon'
                        : 'Unpaid',
                  ),
                  backgroundColor: bill.isPaid
                      ? AppColors.success.withValues(alpha: 0.12)
                      : dueSoon
                      ? AppColors.warning.withValues(alpha: 0.16)
                      : null,
                ),
                Chip(label: Text(bill.frequency.name.toUpperCase())),
                if (wallet != null) Chip(label: Text(wallet.name)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Due ${AppFormatters.compactDate(bill.dueDate)} • remind ${bill.reminderDaysBefore} day${bill.reminderDaysBefore == 1 ? '' : 's'} before',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            if (bill.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(bill.note),
            ],
          ],
        ),
      ),
    );
  }
}
