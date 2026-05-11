// config/app_config.dart
// Central configuration — base URL, timeouts, and environment constants.
// To switch environments, change baseUrl here.

class AppConfig {
  AppConfig._(); // prevent instantiation

  /// Production EC2 instance behind Nginx.
  /// Replace with your actual EC2 public IP or domain.
  static const String baseUrl = 'https://d2zjhfb8fhj63u.cloudfront.net';

  // Dio timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Shared preference keys
  static const String kAccessToken = 'access_token';
  static const String kRefreshToken = 'refresh_token';
  static const String kUserEmail = 'user_email'; // stored at login to avoid GET /auth/me
}
