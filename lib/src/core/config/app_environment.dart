import 'package:flutter/foundation.dart';

class AppEnvironment {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wurjhwzphfomuasdjunf.supabase.co',
  );
  static const String supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_TO1v8l9Qa78NH4kQ3ZDXEw_C87Qy2zF',
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
