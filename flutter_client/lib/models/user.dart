// models/user.dart
// Mirrors FastAPI's UserResponse, UserCreate, UserLogin, and Token schemas.

class UserResponse {
  final int id;
  final String email;
  final String? fullName;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserResponse({
    required this.id,
    required this.email,
    this.fullName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserResponse.fromJson(Map<String, dynamic> json) {
    return UserResponse(
      id: json['id'] as int,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class Token {
  final String accessToken;
  final String refreshToken;
  final String tokenType;

  const Token({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'bearer',
  });

  factory Token.fromJson(Map<String, dynamic> json) {
    return Token(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: json['token_type'] as String? ?? 'bearer',
    );
  }
}
