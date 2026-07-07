import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthController extends ChangeNotifier {
  AuthController({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  StreamSubscription<AuthState>? _subscription;

  User? _currentUser;
  bool _busy = false;
  String? _errorMessage;
  String? _infoMessage;
  bool _isPasswordRecovery = false;

  bool get isConfigured => _client != null;
  bool get isBusy => _busy;
  String? get errorMessage => _errorMessage;
  String? get infoMessage => _infoMessage;
  User? get currentUser => _currentUser;
  bool get isSignedIn => _currentUser != null;
  String? get currentUserId => _currentUser?.id;
  String? get currentUserEmail => _currentUser?.email;
  bool get isPasswordRecovery => _isPasswordRecovery;

  Future<void> initialize() async {
    final client = _client;
    _subscription = client?.auth.onAuthStateChange.listen((data) {
      _currentUser = data.session?.user ?? client.auth.currentUser;
      _errorMessage = null;
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _isPasswordRecovery = true;
        _infoMessage = 'Set a new password to finish account recovery.';
      } else if (data.event == AuthChangeEvent.userUpdated) {
        _isPasswordRecovery = false;
      } else if (data.event == AuthChangeEvent.signedOut) {
        _isPasswordRecovery = false;
        _infoMessage = null;
      }
      notifyListeners();
    });
    _currentUser = client?.auth.currentUser;
    if (client != null && kIsWeb) {
      final isRecoveryLink = _isRecoveryLink(Uri.base);
      if (isRecoveryLink) {
        _isPasswordRecovery = true;
        _infoMessage = 'Set a new password to finish account recovery.';
      }
    }
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    await _runAuthCall(() async {
      final client = _client;
      if (client == null) {
        return;
      }
      await client.auth.signInWithPassword(email: email, password: password);
      _currentUser = client.auth.currentUser;
      _infoMessage = 'Signed in successfully.';
    });
  }

  Future<void> signUp({
    required String email,
    required String password,
    String? emailRedirectTo,
  }) async {
    await _runAuthCall(() async {
      final client = _client;
      if (client == null) {
        return;
      }
      final response = await client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: emailRedirectTo,
      );
      _currentUser = client.auth.currentUser;
      _infoMessage = response.session != null || _currentUser != null
          ? 'Account created successfully.'
          : 'Account created. Check your email to confirm it, then sign in.';
    });
  }

  Future<void> signInWithGoogle({String? redirectTo}) async {
    await _runAuthCall(() async {
      final client = _client;
      if (client == null) {
        return;
      }
      final launched = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
      );
      if (!launched) {
        throw 'Could not open the Google sign-in flow.';
      }
      _infoMessage = 'Continue with Google to finish signing in.';
    });
  }

  Future<void> signOut() async {
    if (_client == null) {
      return;
    }
    await _runAuthCall(() async {
      await _client.auth.signOut();
      _currentUser = null;
      _isPasswordRecovery = false;
      _infoMessage = null;
    });
  }

  void clearSessionLocally() {
    _currentUser = null;
    _busy = false;
    _errorMessage = null;
    _infoMessage = null;
    _isPasswordRecovery = false;
    notifyListeners();
  }

  Future<void> sendPasswordResetEmail({
    required String email,
    String? redirectTo,
  }) async {
    await _runAuthCall(() async {
      final client = _client;
      if (client == null) {
        return;
      }
      await client.auth.resetPasswordForEmail(email, redirectTo: redirectTo);
      _infoMessage =
          'Password reset email sent. Open the recovery link, then return here to set a new password.';
    });
  }

  Future<void> updatePassword({required String password}) async {
    await _runAuthCall(() async {
      final client = _client;
      if (client == null) {
        return;
      }
      await client.auth.updateUser(UserAttributes(password: password));
      _isPasswordRecovery = false;
      _infoMessage = 'Password updated. You can continue into the app.';
    });
  }

  void clearMessages() {
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();
  }

  bool _isRecoveryLink(Uri uri) {
    return uri.queryParameters['mode'] == 'recovery' ||
        uri.queryParameters['type'] == 'recovery' ||
        uri.fragment.contains('type=recovery');
  }

  Future<void> _runAuthCall(Future<void> Function() operation) async {
    if (_client == null) {
      _errorMessage = 'Supabase is not configured for this build.';
      notifyListeners();
      return;
    }

    _busy = true;
    _errorMessage = null;
    _infoMessage = null;
    notifyListeners();

    try {
      await operation();
    } on AuthException catch (error) {
      _errorMessage = error.message;
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
