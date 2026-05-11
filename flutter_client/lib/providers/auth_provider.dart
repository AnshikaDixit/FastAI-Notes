// providers/auth_provider.dart
// Manages auth state: token, current user, login/logout/signup, and PIN management.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../core/result.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

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
  // Lifecycle
  // ---------------------------------------------------------------------------
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConfig.kAccessToken);

    if (token == null || token.isEmpty) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    final result = await _authService.getMe();
    switch (result) {
      case Success(:final data):
        _currentUser = data;
        _status = AuthStatus.authenticated;
      case Failure(:final exception):
        debugPrint('[AuthProvider] init() getMe failed: ${exception.message}');
        await _authService.clearTokens();
        _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Login
  // ---------------------------------------------------------------------------
  Future<bool> login({required String email, required String password}) async {
    _setLoading(true);
    _errorMessage = null;

    final loginResult = await _authService.login(email: email, password: password);
    switch (loginResult) {
      case Failure(:final exception):
        _errorMessage = exception.message;
        _setLoading(false);
        notifyListeners();
        return false;
      case Success():
        break;
    }

    final meResult = await _authService.getMe();
    switch (meResult) {
      case Success(:final data):
        _currentUser = data;
        _status = AuthStatus.authenticated;
        _setLoading(false);
        return true;
      case Failure(:final exception):
        await _authService.clearTokens();
        _errorMessage = 'Profile failed to load: ${exception.message}';
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

    final result = await _authService.signup(email: email, password: password, fullName: fullName);
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
  // PIN Management
  // ---------------------------------------------------------------------------

  Future<bool> setPin(String pin) async {
    _setLoading(true);
    final result = await _authService.setPin(pin);
    _setLoading(false);
    switch (result) {
      case Success(:final data):
        _currentUser = data;
        notifyListeners();
        return true;
      case Failure(:final exception):
        _errorMessage = exception.message;
        notifyListeners();
        return false;
    }
  }

  Future<bool> verifyPin(String pin) async {
    final result = await _authService.verifyPin(pin);
    switch (result) {
      case Success(:final data):
        return data;
      case Failure(:final exception):
        _errorMessage = exception.message;
        return false;
    }
  }

  Future<bool> resetPin(String newPin, {String? oldPin}) async {
    _setLoading(true);
    final result = await _authService.resetPin(newPin, oldPin: oldPin);
    _setLoading(false);
    switch (result) {
      case Success(:final data):
        _currentUser = data;
        notifyListeners();
        return true;
      case Failure(:final exception):
        _errorMessage = exception.message;
        notifyListeners();
        return false;
    }
  }

  Future<bool> forgotPin(String email, String password) async {
    _setLoading(true);
    final result = await _authService.forgotPin(email, password);
    _setLoading(false);
    switch (result) {
      case Success(:final data):
        _currentUser = data;
        notifyListeners();
        return true;
      case Failure(:final exception):
        _errorMessage = exception.message;
        notifyListeners();
        return false;
    }
  }

  // ---------------------------------------------------------------------------
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
