// Render the actual Android-themed app widgets with isolated fictional data.
// Run via scripts/release/generate_store_assets.py; never touches a user's boxes.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:eintelix_expense_tracker/src/core/theme/app_theme.dart';
import 'package:eintelix_expense_tracker/src/data/models/bill_record.dart';
import 'package:eintelix_expense_tracker/src/data/models/budget_plan.dart';
import 'package:eintelix_expense_tracker/src/data/models/debt_record.dart';
import 'package:eintelix_expense_tracker/src/data/models/expense_category.dart';
import 'package:eintelix_expense_tracker/src/data/models/expense_entry.dart';
import 'package:eintelix_expense_tracker/src/data/models/savings_goal.dart';
import 'package:eintelix_expense_tracker/src/data/models/wallet_account.dart';
import 'package:eintelix_expense_tracker/src/data/services/app_controller.dart';
import 'package:eintelix_expense_tracker/src/data/services/auth_controller.dart';
import 'package:eintelix_expense_tracker/src/data/services/data_sync_service.dart';
import 'package:eintelix_expense_tracker/src/data/services/hive_storage_service.dart';
import 'package:eintelix_expense_tracker/src/features/dashboard/home_shell.dart';

void main() {
  testWidgets('Capture six Play Store screens using fictional local records', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final previousShadows = debugDisableShadows;
    debugDisableShadows = false;
    addTearDown(() => debugDisableShadows = previousShadows);
    final boundaryKey = GlobalKey();
    late AppController controller;
    late Directory temporary;
    await tester.runAsync(() async {
      const sdk = String.fromEnvironment('FLUTTER_SDK');
      for (final font in [
        'Roboto-Regular.ttf',
        'Roboto-Bold.ttf',
        'Roboto-Medium.ttf',
      ]) {
        final data = await File(
          '$sdk/bin/cache/artifacts/material_fonts/$font',
        ).readAsBytes();
        await (FontLoader(
          'Roboto',
        )..addFont(Future.value(ByteData.sublistView(data)))).load();
      }
      final iconBytes = await File(
        '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(iconBytes)))).load();
      final defaultBytes = await File(
        '$sdk/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      ).readAsBytes();
      await (FontLoader(
        'Ahem',
      )..addFont(Future.value(ByteData.sublistView(defaultBytes)))).load();
      temporary = await Directory.systemTemp.createTemp(
        'eintelix-store-capture-',
      );
      Hive.init(temporary.path);
      final storage = HiveStorageService();
      storage.registerAdapter(EntryTypeAdapter());
      storage.registerAdapter(TransactionSourceAdapter());
      storage.registerAdapter(RecurrenceFrequencyAdapter());
      storage.registerAdapter(ExpenseCategoryAdapter());
      storage.registerAdapter(ExpenseEntryAdapter());
      storage.registerAdapter(BudgetPeriodAdapter());
      storage.registerAdapter(BudgetPlanAdapter());
      storage.registerAdapter(BillRecordAdapter());
      storage.registerAdapter(DebtTypeAdapter());
      storage.registerAdapter(DebtStatusAdapter());
      storage.registerAdapter(DebtPersonSourceAdapter());
      storage.registerAdapter(DebtRecordAdapter());
      storage.registerAdapter(SavingsGoalAdapter());
      storage.registerAdapter(WalletKindAdapter());
      storage.registerAdapter(WalletAccountAdapter());
      await storage.openBoxes();
      final now = DateTime.now();
      final month = DateTime(now.year, now.month);
      final items = [
        (
          'Monthly salary',
          450000.0,
          'salary',
          EntryType.income,
          'wallet_bank',
          1,
        ),
        (
          'Design project',
          125000.0,
          'freelance',
          EntryType.income,
          'wallet_business',
          3,
        ),
        ('Groceries', 32500.0, 'food', EntryType.expense, 'wallet_bank', 6),
        (
          'Internet subscription',
          18000.0,
          'utilities',
          EntryType.expense,
          'wallet_business',
          8,
        ),
        (
          'Transport',
          12500.0,
          'transport',
          EntryType.expense,
          'wallet_cash',
          10,
        ),
        (
          'Electricity',
          24000.0,
          'utilities',
          EntryType.expense,
          'wallet_bank',
          11,
        ),
        (
          'Lunch with friends',
          15000.0,
          'food',
          EntryType.expense,
          'wallet_bank',
          12,
        ),
        (
          'Monthly rent',
          85000.0,
          'housing',
          EntryType.expense,
          'wallet_bank',
          5,
        ),
      ];
      await storage.entriesBox.addAll([
        for (var i = 0; i < items.length; i++)
          ExpenseEntry(
            id: 'demo-$i',
            title: items[i].$1,
            amount: items[i].$2,
            categoryId: items[i].$3,
            type: items[i].$4,
            walletAccountId: items[i].$5,
            date: DateTime(now.year, now.month, items[i].$6),
            paymentMethod: 'Transfer',
          ),
      ]);
      await storage.budgetsBox.addAll([
        BudgetPlan(
          id: 'food-plan',
          name: 'Food & groceries',
          limit: 80000,
          startDate: month,
          categoryId: 'food',
        ),
        BudgetPlan(
          id: 'utilities-plan',
          name: 'Home essentials',
          limit: 60000,
          startDate: month,
          categoryId: 'utilities',
        ),
        BudgetPlan(
          id: 'transport-plan',
          name: 'Getting around',
          limit: 40000,
          startDate: month,
          categoryId: 'transport',
        ),
      ]);
      await storage.goalsBox.addAll([
        SavingsGoal(
          id: 'emergency',
          name: 'Emergency fund',
          targetAmount: 600000,
          currentAmount: 390000,
          createdAt: month,
          targetDate: now.add(const Duration(days: 90)),
        ),
        SavingsGoal(
          id: 'travel',
          name: 'Holiday plans',
          targetAmount: 350000,
          currentAmount: 140000,
          createdAt: month,
          targetDate: now.add(const Duration(days: 120)),
        ),
      ]);
      await storage.debtsBox.addAll([
        DebtRecord(
          id: 'ada',
          personName: 'Ada',
          amount: 45000,
          amountPaid: 15000,
          type: DebtType.owedToMe,
          status: DebtStatus.active,
          personSource: DebtPersonSource.manual,
          createdAt: month,
          dueDate: now.add(const Duration(days: 12)),
        ),
        DebtRecord(
          id: 'tunde',
          personName: 'Tunde',
          amount: 20000,
          amountPaid: 5000,
          type: DebtType.iOwe,
          status: DebtStatus.active,
          personSource: DebtPersonSource.manual,
          createdAt: month,
          dueDate: now.add(const Duration(days: 20)),
        ),
      ]);
      await storage.settingsBox.put('onboarding_complete', true);
      controller = AppController(
        storage,
        authController: AuthController(),
        syncService: DataSyncService(),
      );
      await controller.initialize();
    });
    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 2.5);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(
          'store/google-play/raw/$name.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }

    await tester.pumpWidget(
      RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme.copyWith(
            platform: TargetPlatform.android,
            textTheme: AppTheme.lightTheme.textTheme.apply(
              fontFamily: 'Roboto',
            ),
          ),
          home: HomeShell(controller: controller),
        ),
      ),
    );
    await capture('01-overview');
    await tester.tap(find.text('Entries').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transactions').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -620));
    await capture('02-transactions');
    await tester.tap(find.text('Budgets').last);
    await capture('03-budgets');
    await tester.tap(find.text('Goals').last);
    await capture('04-goals');
    await tester.tap(find.text('Debts').last);
    await capture('05-debts');
    await tester.tap(find.text('Entries').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wallets').last);
    await capture('06-wallets');
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await tester.runAsync(() async {
      await Hive.close();
      await temporary.delete(recursive: true);
    });
    debugDisableShadows = previousShadows;
  });
}
