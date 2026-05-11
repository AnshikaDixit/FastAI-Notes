// providers/note_provider.dart
// Manages note list state — fetch, create, update, delete.
// All operations update the in-memory list optimistically or on success.

import 'package:flutter/foundation.dart';

import '../core/result.dart';
import '../models/note.dart';
import '../services/note_service.dart';

class NoteProvider extends ChangeNotifier {
  final NoteService _noteService = NoteService();

  List<Note> _notes = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Note> get notes => List.unmodifiable(_notes);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // ---------------------------------------------------------------------------
  // Fetch all notes
  // ---------------------------------------------------------------------------
  Future<void> fetchNotes() async {
    _setLoading(true);
    _errorMessage = null;

    final result = await _noteService.getNotes();
    switch (result) {
      case Success(:final data):
        _notes = data;
      case Failure(:final exception):
        _errorMessage = exception.message;
    }
    _setLoading(false);
  }

  // ---------------------------------------------------------------------------
  // Create note — returns the created Note or null on error
  // ---------------------------------------------------------------------------
  Future<Note?> createNote(NoteCreate noteCreate) async {
    _setLoading(true);
    _errorMessage = null;

    final result = await _noteService.createNote(noteCreate);
    switch (result) {
      case Success(:final data):
        _notes.insert(0, data); // newest first
        _setLoading(false);
        return data;
      case Failure(:final exception):
        _errorMessage = exception.message;
    }
    _setLoading(false);
    return null;
  }

  // ---------------------------------------------------------------------------
  // Update note
  // ---------------------------------------------------------------------------
  Future<Note?> updateNote(int id, NoteUpdate noteUpdate) async {
    _setLoading(true);
    _errorMessage = null;

    final result = await _noteService.updateNote(id, noteUpdate);
    switch (result) {
      case Success(:final data):
        final index = _notes.indexWhere((n) => n.id == id);
        if (index != -1) _notes[index] = data;
        _setLoading(false);
        return data;
      case Failure(:final exception):
        _errorMessage = exception.message;
    }
    _setLoading(false);
    return null;
  }

  // ---------------------------------------------------------------------------
  // Delete note
  // ---------------------------------------------------------------------------
  Future<bool> deleteNote(int id) async {
    _setLoading(true);
    _errorMessage = null;

    final result = await _noteService.deleteNote(id);
    switch (result) {
      case Success():
        _notes.removeWhere((n) => n.id == id);
        _setLoading(false);
        return true;
      case Failure(:final exception):
        _errorMessage = exception.message;
    }
    _setLoading(false);
    return false;
  }

  // ---------------------------------------------------------------------------
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
