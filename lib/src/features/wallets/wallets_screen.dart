import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/app_formatters.dart';
import '../../data/models/wallet_account.dart';
import '../../data/services/app_controller.dart';
import '../../widgets/empty_state_card.dart';
import '../../widgets/section_header.dart';
import 'wallet_form_sheet.dart';
import 'wallet_transfer_sheet.dart';

class WalletsScreen extends StatelessWidget {
  const WalletsScreen({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallets')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showTransferSheet(context),
        icon: const Icon(Icons.swap_horiz_rounded),
        label: const Text('Transfer'),
        backgroundColor: AppColors.primary,
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final snapshots = controller.walletSnapshots;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(
                  title: 'Wallet manager',
                  subtitle:
                      'Track cash, bank, savings, and business balances separately.',
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => _showWalletForm(context),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Add wallet'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => _showTransferSheet(context),
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: const Text('Transfer funds'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (snapshots.isEmpty)
                  EmptyStateCard(
                    title: 'No wallets yet',
                    message:
                        'Create wallets for cash, bank accounts, savings, and business funds.',
                    icon: Icons.account_balance_wallet_rounded,
                    action: FilledButton(
                      onPressed: () => _showWalletForm(context),
                      child: const Text('Create wallet'),
                    ),
                  )
                else
                  ...snapshots.map(
                    (snapshot) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _WalletCard(
                        controller: controller,
                        snapshot: snapshot,
                        onEdit: () =>
                            _showWalletForm(context, wallet: snapshot.wallet),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showWalletForm(BuildContext context, {WalletAccount? wallet}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => WalletFormSheet(controller: controller, wallet: wallet),
    );
  }

  Future<void> _showTransferSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => WalletTransferSheet(controller: controller),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.controller,
    required this.snapshot,
    required this.onEdit,
  });

  final AppController controller;
  final WalletBalanceSnapshot snapshot;
  final Future<void> Function() onEdit;

  @override
  Widget build(BuildContext context) {
    final wallet = snapshot.wallet;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: wallet.color.withValues(alpha: 0.14),
                  child: Icon(wallet.icon, color: wallet.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        wallet.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_labelForKind(wallet.kind)} • ${snapshot.transactionCount} transaction${snapshot.transactionCount == 1 ? '' : 's'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) async {
                    switch (value) {
                      case 'transfer':
                        await showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          showDragHandle: true,
                          builder: (_) =>
                              WalletTransferSheet(controller: controller),
                        );
                        break;
                      case 'edit':
                        await onEdit();
                        break;
                      case 'delete':
                        final deleted = await controller.deleteWallet(
                          wallet.id,
                        );
                        if (!context.mounted) {
                          return;
                        }
                        final message = deleted
                            ? '${wallet.name} deleted.'
                            : wallet.isDefault
                            ? 'Default wallets cannot be deleted.'
                            : 'Move linked transactions before deleting this wallet.';
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(message)));
                        break;
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'transfer', child: Text('Transfer')),
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            if (wallet.note.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(wallet.note),
            ],
            const SizedBox(height: 14),
            Text(
              AppFormatters.currency(
                snapshot.balance,
                symbol: controller.currencyCode,
              ),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
                color: snapshot.balance < 0
                    ? AppColors.danger
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _WalletMetric(
                    label: 'Money in',
                    amount: snapshot.income,
                    color: AppColors.success,
                    currencyCode: controller.currencyCode,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _WalletMetric(
                    label: 'Money out',
                    amount: snapshot.expense,
                    color: AppColors.danger,
                    currencyCode: controller.currencyCode,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
}

class _WalletMetric extends StatelessWidget {
  const _WalletMetric({
    required this.label,
    required this.amount,
    required this.color,
    required this.currencyCode,
  });

  final String label;
  final double amount;
  final Color color;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            AppFormatters.currency(amount, symbol: currencyCode),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
