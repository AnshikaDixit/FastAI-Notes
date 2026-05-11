// services/note_service.dart
// Notes CRUD API calls — all returning Result<T>.

import 'package:dio/dio.dart';

import '../core/api_exception.dart';
import '../core/dio_client.dart';
import '../core/result.dart';
import '../models/api_response.dart';
import '../models/note.dart';

class NoteService {
  final Dio _dio = DioClient.instance;

  /// Fetch all notes for the logged-in user.
  Future<Result<List<Note>>> getNotes() async {
    try {
      final response = await _dio.get('/notes/');
      final apiResponse = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (json) => (json as List)
            .map((e) => Note.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
      return Success(apiResponse.data ?? []);
    } on DioException catch (e) {
      return Failure(_extractException(e));
    } catch (e) {
      return Failure(ApiException.unknown());
    }
  }

  /// Create a new note.
  Future<Result<Note>> createNote(NoteCreate noteCreate) async {
    try {
      final response = await _dio.post('/notes/', data: noteCreate.toJson());
      final apiResponse = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (json) => Note.fromJson(json as Map<String, dynamic>),
      );
      return Success(apiResponse.data!);
    } on DioException catch (e) {
      return Failure(_extractException(e));
    } catch (e) {
      return Failure(ApiException.unknown());
    }
  }

  /// Update an existing note (partial update).
  Future<Result<Note>> updateNote(int id, NoteUpdate noteUpdate) async {
    try {
      final response =
          await _dio.put('/notes/$id', data: noteUpdate.toJson());
      final apiResponse = ApiResponse.fromJson(
        response.data as Map<String, dynamic>,
        (json) => Note.fromJson(json as Map<String, dynamic>),
      );
      return Success(apiResponse.data!);
    } on DioException catch (e) {
      return Failure(_extractException(e));
    } catch (e) {
      return Failure(ApiException.unknown());
    }
  }

  /// Delete a note by ID.
  Future<Result<void>> deleteNote(int id) async {
    try {
      await _dio.delete('/notes/$id');
      return const Success(null);
    } on DioException catch (e) {
      return Failure(_extractException(e));
    } catch (e) {
      return Failure(ApiException.unknown());
    }
  }

  // -------------------------------------------------------------------------
  ApiException _extractException(DioException e) {
    if (e.error is ApiException) return e.error as ApiException;
    return ApiException.fromDioError(e);
  }
}
