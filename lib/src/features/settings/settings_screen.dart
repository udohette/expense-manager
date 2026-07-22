import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/app_controller.dart';
import '../../widgets/branded_logo.dart';
import '../../widgets/section_header.dart';
import '../auth/login_screen.dart';
import '../bills/bills_screen.dart';
import '../categories/categories_screen.dart';
import '../splash/splash_screen.dart';
import '../wallets/wallets_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.controller, super.key});

  final AppController controller;

  String _displaySyncIssue(String rawMessage) {
    if (rawMessage.contains("Could not find the '") &&
        rawMessage.contains("column of 'expense_entries'")) {
      return 'Your Supabase database schema is older than this app build. '
          'Sync can continue in compatibility mode, but the database should be updated to the latest schema.';
    }
    if (rawMessage.contains('Unable to subscribe to changes')) {
      return 'Live sync could not be enabled for this account. '
          'Manual sync still works, but Supabase Realtime needs to be enabled for the synced tables.';
    }
    return rawMessage;
  }

  Future<void> _handleSignOut(BuildContext context) async {
    await controller.authController.signOut();
    if (!context.mounted) {
      return;
    }
    if (controller.authController.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(controller.authController.errorMessage!)),
      );
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => SplashScreen(controller: controller)),
      (route) => false,
    );
  }

  Future<void> _openAuthFlow(
    BuildContext context, {
    bool startInSignUp = false,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            LoginScreen(controller: controller, startInSignUp: startInSignUp),
      ),
    );
  }

  Future<bool> _confirmAction({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmLabel,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                  )
                : null,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleDeleteAllData(BuildContext context) async {
    final confirmed = await _confirmAction(
      context: context,
      title: 'Delete all data?',
      message:
          'This will remove your synced expenses, budgets, debts, categories, and settings from this device and the cloud. Your account will remain active.',
      confirmLabel: 'Delete data',
      isDestructive: true,
    );
    if (!confirmed) {
      return;
    }

    try {
      await controller.deleteAllUserData();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All account data has been deleted.')),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final confirmed = await _confirmAction(
      context: context,
      title: 'Delete account permanently?',
      message:
          'This will permanently delete your account and all synced data from Supabase. This cannot be undone.',
      confirmLabel: 'Delete account',
      isDestructive: true,
    );
    if (!confirmed) {
      return;
    }

    try {
      await controller.deleteAccountPermanently();
      if (!context.mounted) {
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => SplashScreen(controller: controller)),
        (route) => false,
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller, controller.authController]),
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: 'Settings',
              subtitle: controller.isCloudSyncEnabled
                  ? 'Account, sync, and device preferences'
                  : 'Adjust local preferences while the app remains Hive-backed',
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(child: BrandedLogo(height: 70)),
                    const SizedBox(height: 18),
                    Text(
                      'Eintelix Innovations Limited',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.isCloudSyncEnabled
                          ? 'Your account details and finance records stay private to you. Data is stored securely, used only to keep your account available across your devices, and you can sign out or delete your data at any time.'
                          : 'Your records stay on this device unless you choose to sign in. When cloud sync is enabled, your account data is used only to back up and sync your information across your devices.',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    if (controller.authController.isSignedIn) ...[
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Chip(
                            avatar: const Icon(Icons.verified_user_rounded),
                            label: Text(
                              controller.authController.currentUserEmail ??
                                  'Signed in',
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () => _handleSignOut(context),
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Log out'),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 18),
                      Text(
                        'You are currently using the app without an account. Sign in or create one to enable cloud sync and cross-device backup.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          FilledButton.icon(
                            onPressed: () => _openAuthFlow(context),
                            icon: const Icon(Icons.login_rounded),
                            label: const Text('Sign in'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () =>
                                _openAuthFlow(context, startInSignUp: true),
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text('Create account'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (controller.isCloudSyncEnabled) ...[
              const SizedBox(height: 20),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.cloud_done_rounded),
                      title: const Text('Sync account'),
                      subtitle: Text(
                        controller.authController.currentUserEmail ??
                            'Signed out',
                      ),
                      trailing: controller.authController.isSignedIn
                          ? const Chip(label: Text('Connected'))
                          : FilledButton.tonal(
                              onPressed: () => _openAuthFlow(context),
                              child: const Text('Sign in'),
                            ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.sync_rounded),
                      title: const Text('Sync status'),
                      subtitle: Text(
                        controller.isSyncInProgress
                            ? 'Syncing now...'
                            : controller.hasActiveRealtimeSync
                            ? controller.lastSyncAt == null
                                  ? 'Live sync connected. Waiting for first refresh.'
                                  : 'Live sync connected. Last sync: ${controller.lastSyncAt}'
                            : controller.lastSyncAt == null
                            ? 'No sync completed yet'
                            : 'Last sync: ${controller.lastSyncAt}',
                      ),
                      trailing: FilledButton.tonal(
                        onPressed:
                            controller.authController.isSignedIn &&
                                !controller.isSyncInProgress
                            ? () async {
                                await controller.refreshFromCloud();
                                if (!context.mounted) {
                                  return;
                                }
                                final message =
                                    controller.syncErrorMessage == null
                                    ? 'Sync completed.'
                                    : _displaySyncIssue(
                                        controller.syncErrorMessage!,
                                      );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(message)),
                                );
                              }
                            : null,
                        child: const Text('Sync now'),
                      ),
                    ),
                    if (controller.syncErrorMessage != null) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.danger,
                        ),
                        title: const Text('Last sync issue'),
                        subtitle: Text(
                          _displaySyncIssue(controller.syncErrorMessage!),
                        ),
                      ),
                    ],
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.logout_rounded),
                      title: const Text('Sign out'),
                      subtitle: const Text(
                        'Stop syncing on this device until you sign in again',
                      ),
                      onTap: controller.authController.isSignedIn
                          ? () => _handleSignOut(context)
                          : null,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.delete_sweep_rounded,
                        color: AppColors.danger,
                      ),
                      title: const Text('Delete all data'),
                      subtitle: const Text(
                        'Remove your synced app data from this device and the cloud',
                      ),
                      onTap: controller.authController.isSignedIn
                          ? () => _handleDeleteAllData(context)
                          : null,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.person_remove_rounded,
                        color: AppColors.danger,
                      ),
                      title: const Text('Delete account permanently'),
                      subtitle: const Text(
                        'Permanently delete your account and all associated cloud data',
                      ),
                      onTap: controller.authController.isSignedIn
                          ? () => _handleDeleteAccount(context)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.currency_exchange_rounded),
                    title: const Text('Currency'),
                    subtitle: Text(controller.currencyCode),
                    trailing: DropdownButton<String>(
                      value: controller.currencyCode,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 'NGN', child: Text('NGN')),
                        DropdownMenuItem(value: 'USD', child: Text('USD')),
                        DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          controller.updateCurrency(value);
                        }
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(Icons.visibility_off_rounded),
                    title: const Text('Hide balances'),
                    subtitle: const Text(
                      'Mask amounts on the overview cards until you choose to reveal them',
                    ),
                    value: controller.hideBalances,
                    onChanged: controller.setHideBalances,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.category_rounded),
                    title: const Text('Manage categories'),
                    subtitle: const Text(
                      'Create or remove custom income and expense groups',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CategoriesScreen(controller: controller),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet_rounded),
                    title: const Text('Manage wallets'),
                    subtitle: const Text(
                      'Create cash, bank, savings, and business accounts',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WalletsScreen(controller: controller),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.receipt_long_rounded),
                    title: const Text('Manage bills'),
                    subtitle: const Text(
                      'Plan recurring bills and see which ones are due soon',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BillsScreen(controller: controller),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.security_update_good_rounded),
                    title: const Text('Storage mode'),
                    subtitle: Text(
                      controller.isCloudSyncEnabled
                          ? 'Hive cache + Supabase sync enabled'
                          : 'Hive local storage enabled',
                    ),
                    trailing: Chip(
                      label: Text(
                        controller.isCloudSyncEnabled
                            ? 'Cloud sync'
                            : 'Offline-first',
                      ),
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
