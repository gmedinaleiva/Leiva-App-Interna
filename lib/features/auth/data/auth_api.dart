import 'package:dio/dio.dart';

import '../../../core/network/api_response.dart';
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
    return AuthSession.fromJson(apiSuccessJson(response));
  }

  Future<AuthSession> me() async {
    final response = await _dio.get<dynamic>('auth/me');
    return AuthSession.fromJson(apiSuccessJson(response));
  }

  Future<String> rotateCsrf() async {
    final response = await _dio.get<dynamic>('auth/csrf');
    final json = apiSuccessJson(response);
    final data = json['data'] as Map<String, dynamic>;
    return data['csrf_token'] as String;
  }

  Future<void> logout() async {
    final response = await _dio.post<dynamic>('auth/logout');
    ensureApiSuccess(response);
  }

  Future<void> logoutAll(String password) async {
    final response = await _dio.post<dynamic>(
      'auth/logout-all',
      data: {'password': password},
      options: Options(contentType: Headers.jsonContentType),
    );
    ensureApiSuccess(response);
  }
}
