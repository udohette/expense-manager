import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/app_controller.dart';
import '../budgets/budgets_screen.dart';
import '../debts/debts_screen.dart';
import '../settings/settings_screen.dart';
import '../transactions/transactions_screen.dart';
import 'overview_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({required this.controller, super.key});

  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final overviewPage = OverviewScreen(controller: widget.controller);
    final transactionsPage = TransactionsScreen(controller: widget.controller);
    final budgetsPage = BudgetsScreen(controller: widget.controller);
    final debtsPage = DebtsScreen(controller: widget.controller);
    final settingsPage = SettingsScreen(controller: widget.controller);
    final pages = [
      overviewPage,
      transactionsPage,
      budgetsPage,
      debtsPage,
      settingsPage,
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_customize_outlined),
            selectedIcon: Icon(Icons.dashboard_customize_rounded),
            label: 'Overview',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Entries',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: Icon(Icons.pie_chart_rounded),
            label: 'Budgets',
          ),
          NavigationDestination(
            icon: Icon(Icons.handshake_outlined),
            selectedIcon: Icon(Icons.handshake_rounded),
            label: 'Debts',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune_rounded),
            label: 'Settings',
          ),
        ],
      ),
      floatingActionButton: _index == 4
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                switch (_index) {
                  case 0:
                    overviewPage.onQuickAction(context);
                    break;
                  case 1:
                    transactionsPage.onQuickAction(context);
                    break;
                  case 2:
                    budgetsPage.onQuickAction(context);
                    break;
                  case 3:
                    debtsPage.onQuickAction(context);
                    break;
                  default:
                    break;
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add'),
              backgroundColor: AppColors.primary,
            ),
    );
  }
}

abstract class QuickActionHost {
  void onQuickAction(BuildContext context);
}
