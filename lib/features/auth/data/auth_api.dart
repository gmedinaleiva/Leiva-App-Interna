import 'package:dio/dio.dart';

import '../../../core/network/api_error.dart';
import '../domain/auth_session.dart';

class AuthApi {
  const AuthApi(this._dio);

  final Dio _dio;

  Future<AuthSession> login({
    required String username,
    required String password,
    required String deviceName,
  }) async {
    final response = await _dio.post<dynamic>(
      'auth/login',
      data: {
        'username': username,
        'password': password,
        'device_name': deviceName,
        'client_platform': 'android',
      },
      options: Options(contentType: Headers.jsonContentType),
    );
    return AuthSession.fromJson(_successJson(response));
  }

  Future<AuthSession> me() async {
    final response = await _dio.get<dynamic>('auth/me');
    return AuthSession.fromJson(_successJson(response));
  }

  Future<String> rotateCsrf() async {
    final response = await _dio.get<dynamic>('auth/csrf');
    final json = _successJson(response);
    final data = json['data'] as Map<String, dynamic>;
    return data['csrf_token'] as String;
  }

  Future<void> logout() async {
    final response = await _dio.post<dynamic>('auth/logout');
    _ensureSuccess(response);
  }

  Future<void> logoutAll(String password) async {
    final response = await _dio.post<dynamic>(
      'auth/logout-all',
      data: {'password': password},
      options: Options(contentType: Headers.jsonContentType),
    );
    _ensureSuccess(response);
  }

  Map<String, dynamic> _successJson(Response<dynamic> response) {
    _ensureSuccess(response);
    final value = response.data;
    if (value is! Map<String, dynamic>) {
      throw const FormatException('La API devolvió una respuesta inesperada.');
    }
    return value;
  }

  void _ensureSuccess(Response<dynamic> response) {
    final status = response.statusCode ?? 0;
    if (status >= 200 && status < 300) return;

    var code = 'request_failed';
    var message = 'No se pudo completar la operación.';
    final body = response.data;
    if (body is Map<String, dynamic>) {
      final error = body['error'];
      if (error is Map<String, dynamic>) {
        code = error['code'] as String? ?? code;
        message = error['message'] as String? ?? message;
      }
    }
    final retryAfter = int.tryParse(
      response.headers.value('retry-after') ?? '',
    );
    throw ApiFailure(
      statusCode: status,
      code: code,
      message: message,
      retryAfterSeconds: retryAfter,
    );
  }
}
