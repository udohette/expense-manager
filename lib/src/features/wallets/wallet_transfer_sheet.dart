import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/wallet_account.dart';
import '../../data/services/app_controller.dart';

class WalletTransferSheet extends StatefulWidget {
  const WalletTransferSheet({required this.controller, super.key});

  final AppController controller;

  @override
  State<WalletTransferSheet> createState() => _WalletTransferSheetState();
}

class _WalletTransferSheetState extends State<WalletTransferSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  WalletAccount? _fromWallet;
  WalletAccount? _toWallet;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _noteController = TextEditingController();
    final wallets = widget.controller.wallets;
    if (wallets.isNotEmpty) {
      _fromWallet = wallets.first;
    }
    if (wallets.length > 1) {
      _toWallet = wallets[1];
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallets = widget.controller.wallets;

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
              'Transfer between wallets',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<WalletAccount>(
              initialValue: wallets.contains(_fromWallet) ? _fromWallet : null,
              decoration: const InputDecoration(labelText: 'Transfer from'),
              items: wallets
                  .map(
                    (wallet) => DropdownMenuItem(
                      value: wallet,
                      child: Text(wallet.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _fromWallet = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<WalletAccount>(
              initialValue: wallets.contains(_toWallet) ? _toWallet : null,
              decoration: const InputDecoration(labelText: 'Transfer to'),
              items: wallets
                  .map(
                    (wallet) => DropdownMenuItem(
                      value: wallet,
                      child: Text(wallet.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _toWallet = value),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Amount'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.calendar_month_rounded),
                title: const Text('Transfer date'),
                subtitle: Text('${_date.day}/${_date.month}/${_date.year}'),
                trailing: TextButton(
                  onPressed: () async {
                    final selectedDate = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      initialDate: _date,
                    );
                    if (selectedDate != null) {
                      setState(() => _date = selectedDate);
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
                onPressed: _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                ),
                child: const Text('Transfer funds'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (_fromWallet == null ||
        _toWallet == null ||
        _fromWallet!.id == _toWallet!.id ||
        amount == null ||
        amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choose two different wallets and a valid amount.'),
        ),
      );
      return;
    }

    await widget.controller.transferBetweenWallets(
      fromWalletId: _fromWallet!.id,
      toWalletId: _toWallet!.id,
      amount: amount,
      date: _date,
      note: _noteController.text.trim(),
    );

    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}
