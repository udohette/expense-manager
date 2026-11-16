import 'dart:async';
import 'package:flutter/material.dart';
import 'package:eintelix_expense_tracker/src/app/expense_tracker_app.dart';
import 'package:eintelix_expense_tracker/src/data/services/data_sync_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:eintelix_expense_tracker/src/data/services/auth_controller.dart';
import 'package:eintelix_expense_tracker/src/data/services/app_controller.dart';
import 'package:eintelix_expense_tracker/src/data/services/hive_storage_service.dart';
import 'package:eintelix_expense_tracker/src/features/auth/password_reset_screen.dart';

class RecoveryAuth extends AuthController {
  String? savedPassword;
  bool recovery = false;
  @override
  bool get isPasswordRecovery => recovery;
  void receiveRecovery() {
    recovery = true;
    notifyListeners();
  }

  @override
  bool get canResetPassword => true;
  @override
  bool get isSignedIn => true;
  @override
  Future<void> updatePassword({required String password}) async {
    savedPassword = password;
    notifyListeners();
  }
}

void main() {
  test(
    'Recovery URL without a valid session stays in recovery with an error',
    () async {
      final auth = AuthController();
      await auth.handleWebCallback(
        Uri.parse('https://example.com/?mode=recovery#/reset-password'),
      );
      expect(auth.isPasswordRecovery, isTrue);
      expect(auth.errorMessage, contains('expired'));
      auth.dispose();
    },
  );

  test(
    'Ordinary OAuth callback is not classified as password recovery',
    () async {
      final auth = AuthController();
      await auth.handleWebCallback(
        Uri.parse('https://example.com/?code=oauth-code'),
      );
      expect(auth.isPasswordRecovery, isFalse);
      auth.dispose();
    },
  );

  for (final coldStart in [true, false]) {
    testWidgets('Recovery routes directly to reset, cold start: $coldStart', (
      tester,
    ) async {
      final auth = RecoveryAuth()..recovery = coldStart;
      final controller = AppController(
        HiveStorageService(),
        authController: auth,
        syncService: DataSyncService(),
      );
      await tester.pumpWidget(
        ExpenseTrackerApp(
          controller: controller,
          initialization: Completer<void>().future,
        ),
      );
      if (!coldStart) {
        auth.receiveRecovery();
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byType(PasswordResetScreen), findsOneWidget);
      expect(find.text('Choose a new password'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsNothing);
    });
  }

  testWidgets(
    'Reset validates confirmation and stays on success instead of opening app',
    (tester) async {
      final auth = RecoveryAuth();
      final controller = AppController(
        HiveStorageService(),
        authController: auth,
        syncService: DataSyncService(),
      );
      await tester.pumpWidget(
        MaterialApp(home: PasswordResetScreen(controller: controller)),
      );
      expect(find.text('Sign in with Google'), findsNothing);
      await tester.enterText(find.byType(TextFormField).at(0), 'new-password');
      await tester.enterText(find.byType(TextFormField).at(1), 'different');
      await tester.tap(find.text('Save new password'));
      await tester.pump();
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(auth.savedPassword, isNull);
      await tester.enterText(find.byType(TextFormField).at(1), 'new-password');
      await tester.tap(find.text('Save new password'));
      await tester.pumpAndSettle();
      expect(auth.savedPassword, 'new-password');
      expect(find.text('Password updated'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Return to sign in'), findsOneWidget);
    },
  );
}
