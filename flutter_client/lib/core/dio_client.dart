// core/dio_client.dart
// Dio singleton with auth + error interceptors.
// All REST services use this instance — token attachment and error conversion
// happen automatically here, so service methods stay clean.

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import 'api_exception.dart';

class DioClient {
  DioClient._();

  static final Dio _dio = _buildDio();

  /// The shared Dio instance — use this in all services.
  static Dio get instance => _dio;

  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        contentType: 'application/json',
        responseType: ResponseType.json,
      ),
    );

    dio.interceptors.addAll([
      _AuthInterceptor(),
      _ErrorInterceptor(),
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
        logPrint: (o) => debugLog(o.toString()),
      ),
    ]);

    return dio;
  }

  static void debugLog(String message) {
    // ignore: avoid_print
    print('[DioClient] $message');
  }
}

// ---------------------------------------------------------------------------
// Auth Interceptor — attaches Bearer token to every request automatically.
// ---------------------------------------------------------------------------
class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConfig.kAccessToken);
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}

// ---------------------------------------------------------------------------
// Error Interceptor — converts DioException → ApiException before it
// propagates to the service layer. Services only catch ApiException.
// ---------------------------------------------------------------------------
class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Re-wrap as ApiException and rethrow so services get a typed error
    final apiException = ApiException.fromDioError(err);
    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: apiException,
        type: err.type,
        response: err.response,
      ),
    );
  }
}
