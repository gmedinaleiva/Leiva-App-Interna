class AuthUser {
  const AuthUser({required this.id, required this.username, this.fullName});

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as int,
    username: json['username'] as String,
    fullName: json['full_name'] as String?,
  );

  final int id;
  final String username;
  final String? fullName;

  String get displayName {
    final candidate = fullName?.trim();
    return candidate == null || candidate.isEmpty ? username : candidate;
  }
}

class AppCapabilities {
  const AppCapabilities(this.values);

  factory AppCapabilities.fromJson(Map<String, dynamic>? json) =>
      AppCapabilities(Map<String, dynamic>.unmodifiable(json ?? const {}));

  final Map<String, dynamic> values;

  bool isEnabled(String key) {
    final value = values[key];
    if (value is bool) return value;
    if (value is Map<String, dynamic>) {
      return value.values.any((item) => item == true);
    }
    return false;
  }

  bool allows(String key, String action) {
    final value = values[key];
    if (value is bool) return value;
    if (value is Map<String, dynamic>) return value[action] == true;
    return false;
  }
}

class AuthSession {
  const AuthSession({
    required this.authProvider,
    required this.user,
    required this.capabilities,
    required this.csrfToken,
    required this.idleExpiresAt,
    required this.absoluteExpiresAt,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>;
    return AuthSession(
      authProvider: data['auth_provider'] as String,
      user: AuthUser.fromJson(data['user'] as Map<String, dynamic>),
      capabilities: AppCapabilities.fromJson(
        data['capabilities'] as Map<String, dynamic>?,
      ),
      csrfToken: data['csrf_token'] as String? ?? '',
      idleExpiresAt: DateTime.parse(data['idle_expires_at'] as String),
      absoluteExpiresAt: DateTime.parse(data['absolute_expires_at'] as String),
    );
  }

  final String authProvider;
  final AuthUser user;
  final AppCapabilities capabilities;
  final String csrfToken;
  final DateTime idleExpiresAt;
  final DateTime absoluteExpiresAt;
}
