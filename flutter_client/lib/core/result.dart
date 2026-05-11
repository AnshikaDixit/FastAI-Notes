// core/result.dart
// Sealed Result<T> type — every service method returns this instead of throwing.
//
// Usage in a service:
//   Future<Result<Note>> createNote(...) async {
//     try { ... return Success(note); }
//     on DioException catch (e) { return Failure(ApiException.fromDioError(e)); }
//   }
//
// Usage in a provider / UI:
//   final result = await noteService.createNote(...);
//   switch (result) {
//     case Success(:final data) => // use data
//     case Failure(:final exception) => // show exception.message
//   }

import 'api_exception.dart';

sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final ApiException exception;
  const Failure(this.exception);
}
