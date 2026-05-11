// services/stream_service.dart
// SSE streaming consumer — uses package:http (NOT Dio) because Dio cannot
// stream SSE. This is the only service that uses http.Client directly.
//
// Returns a Stream<SseEvent> so the StreamProvider can listen and react
// to individual events as they arrive from GET /stream/export.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';

/// Typed SSE event — wraps the parsed JSON payload and the event type.
class SseEvent {
  final String type;       // "progress" | "chunk" | "complete"
  final Map<String, dynamic> data;

  const SseEvent({required this.type, required this.data});

  // Convenience getters
  bool get isProgress => type == 'progress';
  bool get isChunk => type == 'chunk';
  bool get isComplete => type == 'complete';
}

class StreamService {
  http.Client? _client;

  /// Opens a persistent HTTP connection to GET /stream/export and yields
  /// typed SseEvents as they arrive — one per SSE event block.
  ///
  /// SSE parsing:
  ///   The server sends text lines. A blank line separates events.
  ///   We buffer lines until a blank line, then parse the buffered block.
  ///
  ///   event: progress
  ///   id: progress-1
  ///   data: {"step":"exporting","message":"Exporting note 1 of 3","current":1}
  ///   ← blank line → dispatch SseEvent
  Stream<SseEvent> streamExport() async* {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(AppConfig.kAccessToken) ?? '';

    final request = http.Request(
      'GET',
      Uri.parse('${AppConfig.baseUrl}/stream/export'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'text/event-stream';
    request.headers['Cache-Control'] = 'no-cache';

    _client = http.Client();

    try {
      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        throw Exception(
            'SSE connection failed with status ${response.statusCode}');
      }

      // Buffer for the current event's lines
      String currentEvent = '';
      String currentData = '';

      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.startsWith('event: ')) {
          currentEvent = line.substring(7).trim();
        } else if (line.startsWith('data: ')) {
          currentData = line.substring(6).trim();
        } else if (line.isEmpty) {
          // Blank line = end of this SSE event — dispatch it
          if (currentData.isNotEmpty) {
            try {
              final jsonData =
                  jsonDecode(currentData) as Map<String, dynamic>;
              yield SseEvent(
                type: currentEvent.isNotEmpty ? currentEvent : 'message',
                data: jsonData,
              );
            } catch (_) {
              // Malformed JSON — skip this event
            }
          }
          // Reset buffers for next event
          currentEvent = '';
          currentData = '';
        }
      }
    } finally {
      cancel();
    }
  }

  /// Cancel the active SSE connection (e.g. user navigates away).
  void cancel() {
    _client?.close();
    _client = null;
  }
}
