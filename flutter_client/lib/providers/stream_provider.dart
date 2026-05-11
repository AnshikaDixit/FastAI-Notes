// providers/stream_provider.dart
// Manages SSE streaming state — connects to GET /stream/export,
// accumulates Markdown chunks, and tracks live progress.

import 'dart:async';
import 'package:flutter/foundation.dart';

import '../services/stream_service.dart';

enum NoteStreamStatus { idle, connecting, streaming, complete, error }

class NoteStreamProvider extends ChangeNotifier {
  final StreamService _streamService = StreamService();
  StreamSubscription<SseEvent>? _subscription;

  // State
  NoteStreamStatus _status = NoteStreamStatus.idle;
  String _statusMessage = '';
  String _fullMarkdown = '';
  int _currentNote = 0;
  int _totalNotes = 0;
  String? _errorMessage;

  // Getters
  NoteStreamStatus get status => _status;
  String get statusMessage => _statusMessage;
  String get fullMarkdown => _fullMarkdown;
  int get currentNote => _currentNote;
  int get totalNotes => _totalNotes;
  String? get errorMessage => _errorMessage;
  double get progress =>
      _totalNotes > 0 ? (_currentNote / _totalNotes).clamp(0.0, 1.0) : 0.0;
  bool get isStreaming =>
      _status == NoteStreamStatus.connecting || _status == NoteStreamStatus.streaming;

  // ---------------------------------------------------------------------------
  // Start streaming — subscribes to the SSE stream and reacts to each event
  // ---------------------------------------------------------------------------
  Future<void> startStream() async {
    if (isStreaming) return;

    // Reset state
    _status = NoteStreamStatus.connecting;
    _statusMessage = 'Connecting to server...';
    _fullMarkdown = '';
    _currentNote = 0;
    _totalNotes = 0;
    _errorMessage = null;
    notifyListeners();

    _subscription = _streamService.streamExport().listen(
      (event) => _handleEvent(event),
      onError: (error) {
        _status = NoteStreamStatus.error;
        _errorMessage = error.toString();
        _statusMessage = 'Connection error.';
        notifyListeners();
      },
      onDone: () {
        // Stream closed — if not already marked complete, it was cancelled
        if (_status != NoteStreamStatus.complete) {
          _status = NoteStreamStatus.idle;
        }
        notifyListeners();
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Handle individual SSE events
  // ---------------------------------------------------------------------------
  void _handleEvent(SseEvent event) {
    if (event.isProgress) {
      _status = NoteStreamStatus.streaming;
      _statusMessage = event.data['message']?.toString() ?? '';
      _totalNotes = (event.data['total_notes'] as int?) ?? _totalNotes;
      _currentNote = (event.data['current'] as int?) ?? _currentNote;
    } else if (event.isChunk) {
      _status = NoteStreamStatus.streaming;
      final content = event.data['content']?.toString() ?? '';
      _fullMarkdown += content;
    } else if (event.isComplete) {
      _status = NoteStreamStatus.complete;
      _statusMessage = '✅ Export complete!';
      _totalNotes = (event.data['total_notes'] as int?) ?? _totalNotes;
      _currentNote = _totalNotes; // ensure progress bar is full
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Cancel the active stream (e.g. user navigates away)
  // ---------------------------------------------------------------------------
  void cancel() {
    _subscription?.cancel();
    _subscription = null;
    _streamService.cancel();
    _status = NoteStreamStatus.idle;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Reset to initial state (before a new stream starts)
  // ---------------------------------------------------------------------------
  void reset() {
    cancel();
    _statusMessage = '';
    _fullMarkdown = '';
    _currentNote = 0;
    _totalNotes = 0;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    cancel();
    super.dispose();
  }
}
