import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/amount_input_formatter.dart';
import '../../data/models/bill_record.dart';
import '../../data/models/expense_entry.dart';
import '../../data/models/wallet_account.dart';
import '../../data/services/app_controller.dart';

class BillFormSheet extends StatefulWidget {
  const BillFormSheet({required this.controller, this.bill, super.key});

  final AppController controller;
  final BillRecord? bill;

  @override
  State<BillFormSheet> createState() => _BillFormSheetState();
}

class _BillFormSheetState extends State<BillFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late final TextEditingController _reminderController;
  late RecurrenceFrequency _frequency;
  WalletAccount? _selectedWallet;
  late DateTime _dueDate;
  late bool _isPaid;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final bill = widget.bill;
    _nameController = TextEditingController(text: bill?.name ?? '');
    _amountController = TextEditingController(
      text: bill != null ? AmountInputFormatter.formatValue(bill.amount) : '',
    );
    _noteController = TextEditingController(text: bill?.note ?? '');
    _reminderController = TextEditingController(
      text: (bill?.reminderDaysBefore ?? 3).toString(),
    );
    _frequency = bill?.frequency ?? RecurrenceFrequency.monthly;
    _selectedWallet = bill?.walletAccountId.isNotEmpty == true
        ? widget.controller.findWallet(bill!.walletAccountId)
        : widget.controller.defaultWallet;
    _dueDate = bill?.dueDate ?? DateTime.now().add(const Duration(days: 7));
    _isPaid = bill?.isPaid ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    _reminderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallets = widget.controller.wallets;
    _selectedWallet ??= wallets.isEmpty ? null : wallets.first;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.bill == null ? 'Create bill' : 'Edit bill',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Bill name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [AmountInputFormatter()],
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<WalletAccount>(
              initialValue: wallets.contains(_selectedWallet)
                  ? _selectedWallet
                  : null,
              decoration: const InputDecoration(labelText: 'Pay from wallet'),
              items: wallets
                  .map(
                    (wallet) => DropdownMenuItem(
                      value: wallet,
                      child: Text(wallet.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _selectedWallet = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RecurrenceFrequency>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Repeats'),
              items: const [
                DropdownMenuItem(
                  value: RecurrenceFrequency.weekly,
                  child: Text('Weekly'),
                ),
                DropdownMenuItem(
                  value: RecurrenceFrequency.monthly,
                  child: Text('Monthly'),
                ),
                DropdownMenuItem(
                  value: RecurrenceFrequency.yearly,
                  child: Text('Yearly'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _frequency = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reminderController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Reminder days before due date',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              value: _isPaid,
              contentPadding: EdgeInsets.zero,
              title: const Text('Already paid'),
              onChanged: (value) => setState(() => _isPaid = value),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_rounded),
                title: const Text('Due date'),
                subtitle: Text(
                  '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final selectedDate = await showDatePicker(
                      context: context,
                      firstDate: DateTime.now().subtract(
                        const Duration(days: 365),
                      ),
                      lastDate: DateTime.now().add(const Duration(days: 3650)),
                      initialDate: _dueDate,
                    );
                    if (selectedDate != null) {
                      setState(() => _dueDate = selectedDate);
                    }
                  },
                  child: const Text('Change'),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isSubmitting) ...[
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Text(
                      _isSubmitting
                          ? (widget.bill == null ? 'Saving...' : 'Updating...')
                          : (widget.bill == null ? 'Save bill' : 'Update bill'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }
    final amount = double.tryParse(
      AmountInputFormatter.normalize(_amountController.text),
    );
    final reminderDays = int.tryParse(_reminderController.text.trim()) ?? 3;
    if (_nameController.text.trim().isEmpty ||
        amount == null ||
        amount <= 0 ||
        _selectedWallet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete the bill name, amount, and wallet.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final bill = BillRecord(
        id: widget.bill?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        amount: amount,
        dueDate: _dueDate,
        frequency: _frequency,
        reminderDaysBefore: reminderDays.clamp(0, 30),
        isPaid: _isPaid,
        note: _noteController.text.trim(),
        walletAccountId: _selectedWallet!.id,
      );

      if (widget.bill == null) {
        await widget.controller.addBill(bill);
      } else {
        await widget.controller.updateBill(bill);
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }
}
