import 'package:flutter/foundation.dart';

class AppEnvironment {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  static String? get authRedirectTo {
    if (kIsWeb) {
      return Uri.base.origin;
    }
    return 'com.eintelix.expensetracker://login-callback';
  }
}
