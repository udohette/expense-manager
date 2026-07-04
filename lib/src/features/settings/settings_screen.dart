import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/app_controller.dart';
import '../../widgets/branded_logo.dart';
import '../../widgets/section_header.dart';
import '../categories/categories_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({required this.controller, super.key});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Settings',
            subtitle:
                'Adjust local preferences while the app remains Hive-backed',
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BrandedLogo(height: 54),
                  const SizedBox(height: 18),
                  Text(
                    'Eintelix Innovations Limited',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This first release stores data locally with Hive, giving the team a stable offline-first base before a later cloud migration.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
                  leading: const Icon(Icons.cleaning_services_rounded),
                  title: const Text('Re-run SMS cleanup'),
                  subtitle: const Text(
                    'Remove old duplicate or malformed bank SMS imports',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final deletedCount = await controller
                        .rerunSmsImportCleanup();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          deletedCount == 0
                              ? 'No duplicate SMS imports were found.'
                              : 'Removed $deletedCount duplicate SMS import${deletedCount == 1 ? '' : 's'}.',
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security_update_good_rounded),
                  title: const Text('Storage mode'),
                  subtitle: const Text('Hive local storage enabled'),
                  trailing: const Chip(label: Text('Offline-first')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
