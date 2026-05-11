// models/note.dart
// Mirrors FastAPI's NoteResponse, NoteCreate, and NoteUpdate schemas.

class Note {
  final int id;
  final String title;
  final String description;
  final bool? personal;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Note({
    required this.id,
    required this.title,
    required this.description,
    this.personal,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String,
      personal: json['personal'] as bool?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Returns a copy of this Note with the given fields replaced.
  Note copyWith({
    String? title,
    String? description,
    bool? personal,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      personal: personal ?? this.personal,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class NoteCreate {
  final String title;
  final String description;
  final bool? personal;

  const NoteCreate({
    required this.title,
    required this.description,
    this.personal,
  });

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        if (personal != null) 'personal': personal,
      };
}

class NoteUpdate {
  final String? title;
  final String? description;
  final bool? personal;

  const NoteUpdate({this.title, this.description, this.personal});

  Map<String, dynamic> toJson() => {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (personal != null) 'personal': personal,
      };
}
