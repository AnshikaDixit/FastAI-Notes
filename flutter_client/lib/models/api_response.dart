// models/api_response.dart
// Mirror of FastAPI's APIResponse[T] — generic wrapper around every response.
// Shape: { "status_code": int, "message": str, "data": T | null }

class ApiResponse<T> {
  final int statusCode;
  final String message;
  final T? data;

  const ApiResponse({
    required this.statusCode,
    required this.message,
    this.data,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json)? fromJsonT,
  ) {
    return ApiResponse<T>(
      statusCode: json['status_code'] as int,
      message: json['message'] as String,
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : null,
    );
  }
}
