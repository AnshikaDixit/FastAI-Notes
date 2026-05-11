// services/auth_service.dart
// Authentication API calls — signup, login, getMe, PIN management.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../core/api_exception.dart';
import '../core/dio_client.dart';
import '../core/result.dart';
import '../models/api_response.dart';
import '../models/user.dart';

class AuthService {
  final Dio _dio = DioClient.instance;

  /// Register a new user account.
  Future<Result<UserResponse>> signup({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final response = await _dio.post('/auth/signup', data: {
        'email': email,
        'password': password,
        if (fullName != null && fullName.isNotEmpty) 'full_name': fullName,
      });
      final apiResponse = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (json) => UserResponse.fromJson(json as Map<String, dynamic>),
      );
      return Success(apiResponse.data!);
    } on DioException catch (e) {
      return Failure(_extractException(e));
    } catch (e) {
      return Failure(ApiException.unknown());
    }
  }

  /// Login and persist the tokens + email to SharedPreferences.
  Future<Result<Token>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      final apiResponse = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (json) => Token.fromJson(json as Map<String, dynamic>),
      );
      final token = apiResponse.data!;
      await _persistTokens(token, email: email);
      return Success(token);
    } on DioException catch (e) {
      return Failure(_extractException(e));
    } catch (e) {
      return Failure(ApiException.unknown());
    }
  }

  /// Fetch the current user's profile.
  Future<Result<UserResponse>> getMe() async {
    try {
      final response = await _dio.get('/auth/me');
      final apiResponse = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (json) => UserResponse.fromJson(json as Map<String, dynamic>),
      );
      return Success(apiResponse.data!);
    } on DioException catch (e) {
      return Failure(_extractException(e));
    } catch (e, stack) {
      debugPrint('[AuthService.getMe] parse error: $e\n$stack');
      return Failure(ApiException(message: 'Failed to load profile: $e'));
    }
  }

  // --- PIN Management ---

  /// Set the initial PIN.
  Future<Result<UserResponse>> setPin(String pin) async {
    try {
      final response = await _dio.post('/auth/pin/set', data: {'pin': pin});
      final apiResponse = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (json) => UserResponse.fromJson(json as Map<String, dynamic>),
      );
      return Success(apiResponse.data!);
    } on DioException catch (e) {
      return Failure(_extractException(e));
    } catch (e) {
      return Failure(ApiException.unknown());
    }
  }

  /// Verify if the provided PIN is correct.
  Future<Result<bool>> verifyPin(String pin) async {
    try {
      final response = await _dio.post('/auth/pin/verify', data: {'pin': pin});
      final apiResponse = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (json) => json as bool,
      );
      return Success(apiResponse.data ?? false);
    } on DioException catch (e) {
      return Failure(_extractException(e));
    } catch (e) {
      return Failure(ApiException.unknown());
    }
  }

  /// Change existing PIN.
  Future<Result<UserResponse>> resetPin(String newPin, {String? oldPin}) async {
    try {
      final response = await _dio.post('/auth/pin/reset', data: {
        'old_pin': oldPin,
        'new_pin': newPin,
      });
      final apiResponse = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (json) => UserResponse.fromJson(json as Map<String, dynamic>),
      );
      return Success(apiResponse.data!);
    } on DioException catch (e) {
      return Failure(_extractException(e));
    } catch (e) {
      return Failure(ApiException.unknown());
    }
  }

  /// Reset PIN by providing login credentials.
  Future<Result<UserResponse>> forgotPin(String email, String password) async {
    try {
      final response = await _dio.post('/auth/pin/forgot', data: {
        'email': email,
        'password': password,
      });
      final apiResponse = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (json) => UserResponse.fromJson(json as Map<String, dynamic>),
      );
      return Success(apiResponse.data!);
    } on DioException catch (e) {
      return Failure(_extractException(e));
    } catch (e) {
      return Failure(ApiException.unknown());
    }
  }

  // -------------------------------------------------------------------------

  /// Clear stored tokens and user email on logout.
  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.kAccessToken);
    await prefs.remove(AppConfig.kRefreshToken);
    await prefs.remove(AppConfig.kUserEmail);
  }

  // -------------------------------------------------------------------------
  // Private helpers
  // -------------------------------------------------------------------------

  Future<void> _persistTokens(Token token, {required String email}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConfig.kAccessToken, token.accessToken);
    await prefs.setString(AppConfig.kRefreshToken, token.refreshToken);
    await prefs.setString(AppConfig.kUserEmail, email);
  }

  ApiException _extractException(DioException e) {
    if (e.error is ApiException) return e.error as ApiException;
    return ApiException.fromDioError(e);
  }
}
