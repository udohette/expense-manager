import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const supportEmail = 'etteinnovations@gmail.com';
  static const sections = <(String, String)>[
    (
      'Who we are',
      'Eintelix Expense Tracker is provided by Eintelix Innovations Limited. Contact us at etteinnovations@gmail.com about privacy or account deletion. Effective 16 November 2026.',
    ),
    (
      'Information you provide',
      'We process your account email and user ID, and any profile information supplied through Google sign-in. Your records can include income, expenses, budgets, savings goals, bills, wallets, debts, names and phone numbers you enter for debt records, notes, and bank-alert text you choose to paste.',
    ),
    (
      'How your information is used',
      'We use this information to sign you in, display your records, calculate summaries, and sync your records across your devices. Pasted bank alerts are parsed to create transactions; the original text may be stored with the transaction and synced when you are signed in. We do not automatically read your SMS inbox or address book.',
    ),
    (
      'Storage and service providers',
      'Records are cached in the app’s private storage on your device. Signed-in records and account details are processed by Supabase to provide authentication and cloud sync. Google processes sign-in when you choose that option. These providers may process information outside your country. Connections to our cloud service use HTTPS. Local records are not additionally encrypted by this app; protect your device with a screen lock.',
    ),
    (
      'Advertising and tracking',
      'This release contains no advertising or third-party analytics SDK. We do not sell your personal information or use your finance records for targeted advertising. Infrastructure providers may process operational connection and security logs.',
    ),
    (
      'Your choices and deletion',
      'In Settings you can delete account data, permanently delete your account, and sign out. Account deletion is designed to remove your authentication account and associated cloud records. You may also request deletion at etteinnovations@gmail.com or through the account-deletion page linked below. We may ask you to verify ownership. Never send us your password or recovery link. Uninstalling removes local app storage but does not delete your cloud account. Records remain while your account is active; provider backups and legally required records may remain subject to provider retention and applicable obligations.',
    ),
    (
      'Children and changes',
      'This app is intended for adults managing their own finances and is not directed to children. We may update this policy when our practices change. The effective date will identify the latest version.',
    ),
  ];

  Future<void> _open(BuildContext context, Uri uri) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Keep a useful alternative when a browser or mail handler is unavailable.
    }
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Please contact etteinnovations@gmail.com.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy & your data')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          for (final section in sections) ...[
            Text(section.$1, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            SelectableText(section.$2),
            const SizedBox(height: 24),
          ],
          OutlinedButton.icon(
            onPressed: () => _open(
              context,
              Uri.parse(
                'https://expense-manager-ei-team2.vercel.app/delete-account/',
              ),
            ),
            icon: const Icon(Icons.person_remove_outlined),
            label: const Text('Request account deletion'),
          ),
          TextButton(
            onPressed: () =>
                _open(context, Uri(scheme: 'mailto', path: supportEmail)),
            child: const Text('Contact support'),
          ),
        ],
      ),
    );
  }
}
