// services/export_service.dart
// Background export API calls — trigger export (fire-and-forget) and get history.

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/api_exception.dart';
import '../core/dio_client.dart';
import '../core/result.dart';
import '../models/activity_log.dart';
import '../models/api_response.dart';

class ExportService {
  final Dio _dio = DioClient.instance;

  /// Trigger a background note export.
  /// FastAPI returns 202 Accepted immediately; actual export runs in background.
  Future<Result<ApiResponse<ActivityLog>>> triggerExport() async {
    try {
      final response = await _dio.post('/export/notes');
      final apiResponse = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (json) => ActivityLog.fromJson(json as Map<String, dynamic>),
      );
      return Success(apiResponse);
    } on DioException catch (e) {
      return Failure(_extractException(e));
    } catch (e, stack) {
      debugPrint('[ExportService.triggerExport] Error: $e\n$stack');
      return Failure(ApiException.unknown());
    }
  }

  /// Get the user's export history (activity log).
  /// Poll this after triggering an export to see when status → "completed".
  Future<Result<List<ActivityLog>>> getHistory() async {
    try {
      final response = await _dio.get('/export/history');
      final apiResponse = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (json) => (json as List)
            .map((e) => ActivityLog.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      return Success(apiResponse.data ?? []);
    } on DioException catch (e) {
      return Failure(_extractException(e));
    } catch (e, stack) {
      debugPrint('[ExportService.getHistory] Error: $e\n$stack');
      return Failure(ApiException.unknown());
    }
  }

  // -------------------------------------------------------------------------
  ApiException _extractException(DioException e) {
    if (e.error is ApiException) return e.error as ApiException;
    return ApiException.fromDioError(e);
  }
}
