import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/app_controller.dart';
import '../../data/services/sms_import_service.dart';
import '../budgets/budgets_screen.dart';
import '../debts/debts_screen.dart';
import '../goals/goals_screen.dart';
import '../settings/settings_screen.dart';
import '../transactions/transactions_screen.dart';
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
