// providers/auth_provider.dart
// Manages auth state: token, current user, login/logout/signup.
//
// Flow:
//   login()  → POST /auth/login → (token) → GET /auth/me → UserResponse
//   init()   → read token from SharedPrefs → GET /auth/me → restore session
//   logout() → clear SharedPrefs → unauthenticated
//
// CloudFront is now configured with:
//   - CachingDisabled cache policy
//   - ForwardAuthorizationHeader origin request policy
// So GET /auth/me correctly receives the Authorization header on EC2.

import 'package:flutter/foundation.dart';

import '../core/result.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AuthStatus _status = AuthStatus.unknown;
  UserResponse? _currentUser;
  String? _errorMessage;
  bool _isLoading = false;

  AuthStatus get status => _status;
  UserResponse? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  // ---------------------------------------------------------------------------
  // Lifecycle — validate persisted token via GET /auth/me on app start.
  // CloudFront now forwards the Authorization header so this works correctly.
  // ---------------------------------------------------------------------------
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConfig.kAccessToken);

    if (token == null || token.isEmpty) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    // Token exists — call /auth/me to validate it and load real user data.
    final result = await _authService.getMe();
    switch (result) {
      case Success(:final data):
        _currentUser = data;
        _status = AuthStatus.authenticated;
        debugPrint('[AuthProvider] Session restored for ${data.email}');
      case Failure(:final exception):
        // Token invalid or expired — force re-login.
        debugPrint('[AuthProvider] init() getMe failed: ${exception.message}');
        await _authService.clearTokens();
        _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Login — POST /auth/login → GET /auth/me → authenticated
  // ---------------------------------------------------------------------------
  Future<bool> login({required String email, required String password}) async {
    _setLoading(true);
    _errorMessage = null;

    // Step 1: Authenticate and persist tokens.
    final loginResult =
        await _authService.login(email: email, password: password);

    switch (loginResult) {
      case Failure(:final exception):
        _errorMessage = exception.message;
        _setLoading(false);
        notifyListeners();
        return false;
      case Success():
        break; // Tokens persisted by AuthService — continue to Step 2.
    }

    // Step 2: Fetch real user profile (CloudFront now forwards Authorization).
    final meResult = await _authService.getMe();
    switch (meResult) {
      case Success(:final data):
        _currentUser = data;
        _status = AuthStatus.authenticated;
        debugPrint('[AuthProvider] Logged in as ${data.email} (id: ${data.id})');
        _setLoading(false);
        return true;

      case Failure(:final exception):
        // Login succeeded but profile fetch failed — clear tokens.
        debugPrint('[AuthProvider] getMe() failed: ${exception.message}');
        await _authService.clearTokens();
        _errorMessage = 'Login succeeded but profile failed to load: ${exception.message}';
    }

    _setLoading(false);
    notifyListeners();
    return false;
  }

  // ---------------------------------------------------------------------------
  // Signup
  // ---------------------------------------------------------------------------
  Future<bool> signup({
    required String email,
    required String password,
    String? fullName,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    final result = await _authService.signup(
      email: email,
      password: password,
      fullName: fullName,
    );
    switch (result) {
      case Success():
        _setLoading(false);
        return true;
      case Failure(:final exception):
        _errorMessage = exception.message;
    }
    _setLoading(false);
    notifyListeners();
    return false;
  }

  // ---------------------------------------------------------------------------
  // Logout
  // ---------------------------------------------------------------------------
  Future<void> logout() async {
    await _authService.clearTokens();
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Refresh profile — e.g. after a profile update in a future feature.
  // ---------------------------------------------------------------------------
  Future<void> refreshProfile() async {
    final result = await _authService.getMe();
    switch (result) {
      case Success(:final data):
        _currentUser = data;
        notifyListeners();
      case Failure(:final exception):
        debugPrint('[AuthProvider] refreshProfile failed: ${exception.message}');
    }
  }

  // ---------------------------------------------------------------------------
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
