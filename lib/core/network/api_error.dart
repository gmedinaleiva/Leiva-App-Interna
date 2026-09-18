class ApiFailure implements Exception {
  const ApiFailure({
    required this.statusCode,
    required this.code,
    required this.message,
    this.retryAfterSeconds,
  });

  final int statusCode;
  final String code;
  final String message;
  final int? retryAfterSeconds;

  bool get isInvalidSession => statusCode == 401 && code == 'invalid_session';
}
