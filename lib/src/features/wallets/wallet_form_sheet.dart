import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/wallet_account.dart';
import '../../data/services/app_controller.dart';

class WalletFormSheet extends StatefulWidget {
  const WalletFormSheet({required this.controller, this.wallet, super.key});

  final AppController controller;
  final WalletAccount? wallet;

  @override
  State<WalletFormSheet> createState() => _WalletFormSheetState();
}

class _WalletFormSheetState extends State<WalletFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _noteController;
  late WalletKind _kind;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.wallet?.name ?? '');
    _noteController = TextEditingController(text: widget.wallet?.note ?? '');
    _kind = widget.wallet?.kind ?? WalletKind.cash;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              widget.wallet == null ? 'Create wallet' : 'Edit wallet',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Wallet name'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<WalletKind>(
              initialValue: _kind,
              decoration: const InputDecoration(labelText: 'Wallet type'),
              items: WalletKind.values
                  .map(
                    (kind) => DropdownMenuItem(
                      value: kind,
                      child: Text(_labelForKind(kind)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _kind = value);
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Note'),
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
                          ? (widget.wallet == null
                                ? 'Saving...'
                                : 'Updating...')
                          : (widget.wallet == null ? 'Save wallet' : 'Update'),
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
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a wallet name.')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final preset = _presetForKind(_kind);
      final wallet = WalletAccount(
        id:
            widget.wallet?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        kind: _kind,
        colorValue: widget.wallet?.colorValue ?? preset.color.toARGB32(),
        iconCodePoint: widget.wallet?.iconCodePoint ?? preset.icon.codePoint,
        note: _noteController.text.trim(),
        isDefault: widget.wallet?.isDefault ?? false,
      );

      if (widget.wallet == null) {
        await widget.controller.addWallet(wallet);
      } else {
        await widget.controller.updateWallet(wallet);
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

  String _labelForKind(WalletKind kind) {
    switch (kind) {
      case WalletKind.cash:
        return 'Cash';
      case WalletKind.bank:
        return 'Bank';
      case WalletKind.savings:
        return 'Savings';
      case WalletKind.business:
        return 'Business';
      case WalletKind.custom:
        return 'Custom';
    }
  }

  ({Color color, IconData icon}) _presetForKind(WalletKind kind) {
    switch (kind) {
      case WalletKind.cash:
        return (color: AppColors.warning, icon: Icons.payments_rounded);
      case WalletKind.bank:
        return (color: AppColors.primary, icon: Icons.account_balance_rounded);
      case WalletKind.savings:
        return (color: AppColors.success, icon: Icons.savings_rounded);
      case WalletKind.business:
        return (
          color: AppColors.primaryDark,
          icon: Icons.business_center_rounded,
        );
      case WalletKind.custom:
        return (
          color: AppColors.textSecondary,
          icon: Icons.account_balance_wallet_rounded,
        );
    }
  }
}
