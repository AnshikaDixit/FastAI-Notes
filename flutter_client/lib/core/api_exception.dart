// core/api_exception.dart
// Converts raw Dio errors and FastAPI error responses into typed exceptions.
// Every service method catches errors here — screens only deal with ApiException.

import 'package:dio/dio.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final dynamic data; // raw error detail from FastAPI body

  const ApiException({
    this.statusCode,
    required this.message,
    this.data,
  });

  /// Build from a Dio error — handles network, timeout, and HTTP error cases.
  factory ApiException.fromDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          message: 'Request timed out. Check your connection.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          message: 'Unable to reach the server. Check your internet.',
        );
      case DioExceptionType.badResponse:
        final response = e.response;
        if (response != null) {
          return ApiException.fromResponse(response);
        }
        return const ApiException(message: 'Unexpected server error.');
      default:
        return ApiException(
          message: e.message ?? 'An unknown error occurred.',
        );
    }
  }

  /// Build from a Dio Response — extracts the FastAPI APIResponse error body.
  factory ApiException.fromResponse(Response response) {
    final body = response.data;
    String message = 'Something went wrong.';

    if (body is Map<String, dynamic>) {
      // FastAPI APIResponse shape: { "message": "...", "status_code": ... }
      message = body['message']?.toString() ??
          body['detail']?.toString() ??
          message;
    }

    return ApiException(
      statusCode: response.statusCode,
      message: message,
      data: body,
    );
  }

  factory ApiException.unknown() =>
      const ApiException(message: 'An unknown error occurred.');

  @override
  String toString() => 'ApiException($statusCode): $message';
}
