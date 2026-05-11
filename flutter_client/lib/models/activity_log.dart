// models/activity_log.dart
// Mirrors FastAPI's ActivityLog schema — tracks background job results.
// Statuses: "pending" → "completed" / "failed"

class ActivityLog {
  final int id;
  final String action;
  final String status;
  final String? detail;
  final String? filePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ActivityLog({
    required this.id,
    required this.action,
    required this.status,
    this.detail,
    this.filePath,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: json['id'] as int,
      action: json['action'] as String,
      status: json['status'] as String,
      detail: json['detail'] as String?,
      filePath: json['file_path'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
}
