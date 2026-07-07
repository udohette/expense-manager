class AppSettingsSnapshot {
  const AppSettingsSnapshot({
    required this.onboardingComplete,
    required this.currencyCode,
    required this.hideBalances,
  });

  final bool onboardingComplete;
  final String currencyCode;
  final bool hideBalances;

  Map<String, dynamic> toJson(String userId) {
    return {
      'user_id': userId,
      'onboarding_complete': onboardingComplete,
      'currency_code': currencyCode,
      'hide_balances': hideBalances,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  bool get hasMeaningfulState =>
      onboardingComplete || currencyCode != 'NGN' || hideBalances;
}
