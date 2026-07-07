import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/app_controller.dart';
import '../bills/bills_screen.dart';
import '../../data/services/sms_import_service.dart';
import '../budgets/budgets_screen.dart';
import '../debts/debts_screen.dart';
import '../goals/goals_screen.dart';
import '../settings/settings_screen.dart';
import '../transactions/transactions_screen.dart';
import '../wallets/wallets_screen.dart';
import 'overview_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({required this.controller, super.key});

  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  final SmsImportService _smsImportService = SmsImportService();
  Timer? _smsAutoSyncTimer;
  StreamSubscription<SmsImportCandidate>? _incomingSmsSubscription;
  bool _isAutoImportRunning = false;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startSmsAutoSync();
    unawaited(_ensureSmsPermissionPrompt());
    unawaited(_startIncomingSmsListener());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _smsAutoSyncTimer?.cancel();
    _incomingSmsSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startSmsAutoSync(runImmediately: true);
      unawaited(_startIncomingSmsListener());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      _smsAutoSyncTimer?.cancel();
      _incomingSmsSubscription?.cancel();
    }
  }

  void _startSmsAutoSync({bool runImmediately = true}) {
    _smsAutoSyncTimer?.cancel();
    if (runImmediately) {
      unawaited(_autoImportSmsTransactions());
    }
    _smsAutoSyncTimer = Timer.periodic(
      const Duration(seconds: 20),
      (_) => unawaited(_autoImportSmsTransactions()),
    );
  }

  Future<void> _ensureSmsPermissionPrompt() async {
    final hasPermission = await _smsImportService.hasSmsPermission();
    if (hasPermission || !mounted) {
      return;
    }

    final granted = await _smsImportService.requestSmsPermission();
    if (!mounted) {
      return;
    }

    if (granted) {
      _startSmsAutoSync(runImmediately: true);
      unawaited(_startIncomingSmsListener());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('SMS access enabled. Importing bank alerts now.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'SMS access was not granted. You can still allow it later from Import from SMS.',
        ),
      ),
    );
  }

  Future<void> _autoImportSmsTransactions() async {
    if (_isAutoImportRunning) {
      return;
    }
    _isAutoImportRunning = true;
    try {
      final hasPermission = await _smsImportService.hasSmsPermission();
      if (!hasPermission || !mounted) {
        return;
      }

      final session = await _smsImportService.prepareImport(
        existingEntries: widget.controller.entries,
        categories: widget.controller.categories,
      );
      if (session.status != SmsImportStatus.ready ||
          session.candidates.isEmpty) {
        return;
      }

      final candidates = _smsImportService.filterNewCandidates(
        candidates: session.candidates,
        existingEntries: widget.controller.entries,
      );
      final entries = _smsImportService.buildEntriesFromCandidates(
        candidates: candidates,
        categories: widget.controller.categories,
      );
      if (entries.isEmpty) {
        return;
      }

      await widget.controller.addEntries(entries);
    } finally {
      _isAutoImportRunning = false;
    }
  }

  Future<void> _startIncomingSmsListener() async {
    await _incomingSmsSubscription?.cancel();
    final hasPermission = await _smsImportService.hasSmsPermission();
    if (!hasPermission || !mounted) {
      return;
    }

    _incomingSmsSubscription = _smsImportService.watchIncomingSms().listen((
      candidate,
    ) async {
      if (_isAutoImportRunning) {
        return;
      }
      final candidates = _smsImportService.filterNewCandidates(
        candidates: [candidate],
        existingEntries: widget.controller.entries,
      );
      if (candidates.isEmpty) {
        return;
      }
      final entries = _smsImportService.buildEntriesFromCandidates(
        candidates: candidates,
        categories: widget.controller.categories,
      );
      if (entries.isEmpty) {
        return;
      }
      await widget.controller.addEntries(entries);
    }, onError: (_) {});
  }

  Future<void> _handleEntriesDestinationTap(BuildContext context) async {
    final navigator = Navigator.of(context);
    final selection = await showModalBottomSheet<_EntriesDestination>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Entries',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'Jump to transactions, bill planner, or wallet manager.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              _EntriesLauncherTile(
                icon: Icons.receipt_long_rounded,
                title: 'Transactions',
                subtitle: 'View and add income or expense entries',
                onTap: () =>
                    Navigator.of(context).pop(_EntriesDestination.transactions),
              ),
              const SizedBox(height: 12),
              _EntriesLauncherTile(
                icon: Icons.receipt_rounded,
                title: 'Bills',
                subtitle: 'Open the bill planner and due reminders',
                onTap: () =>
                    Navigator.of(context).pop(_EntriesDestination.bills),
              ),
              const SizedBox(height: 12),
              _EntriesLauncherTile(
                icon: Icons.account_balance_wallet_rounded,
                title: 'Wallets',
                subtitle: 'Manage wallets, accounts, and transfers',
                onTap: () =>
                    Navigator.of(context).pop(_EntriesDestination.wallets),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || selection == null) {
      return;
    }

    switch (selection) {
      case _EntriesDestination.transactions:
        setState(() => _index = 1);
        break;
      case _EntriesDestination.bills:
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => BillsScreen(controller: widget.controller),
          ),
        );
        break;
      case _EntriesDestination.wallets:
        await navigator.push(
          MaterialPageRoute(
            builder: (_) => WalletsScreen(controller: widget.controller),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final overviewPage = OverviewScreen(controller: widget.controller);
    final transactionsPage = TransactionsScreen(controller: widget.controller);
    final budgetsPage = BudgetsScreen(controller: widget.controller);
    final goalsPage = GoalsScreen(controller: widget.controller);
    final debtsPage = DebtsScreen(controller: widget.controller);
    final settingsPage = SettingsScreen(controller: widget.controller);
    final pages = [
      overviewPage,
      transactionsPage,
      budgetsPage,
      goalsPage,
      debtsPage,
      settingsPage,
    ];

    return Scaffold(
      body: SafeArea(child: pages[_index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          if (value == 1) {
            unawaited(_handleEntriesDestinationTap(context));
            return;
          }
          setState(() => _index = value);
        },
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
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings_rounded),
            label: 'Goals',
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
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _index == 5
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 72),
              child: FloatingActionButton.extended(
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
                      goalsPage.onQuickAction(context);
                      break;
                    case 4:
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
            ),
    );
  }
}

abstract class QuickActionHost {
  void onQuickAction(BuildContext context);
}

enum _EntriesDestination { transactions, bills, wallets }

class _EntriesLauncherTile extends StatelessWidget {
  const _EntriesLauncherTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.14),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Icon(icon, color: AppColors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
