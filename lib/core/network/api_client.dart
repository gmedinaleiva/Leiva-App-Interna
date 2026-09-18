import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../security/secure_session_store.dart';

class ApiClient {
  ApiClient({required AppConfig config, required SessionStore sessionStore})
    : dio = Dio(
        BaseOptions(
          baseUrl: '${config.apiBaseUri}/',
          connectTimeout: const Duration(seconds: 12),
          sendTimeout: const Duration(seconds: 12),
          receiveTimeout: const Duration(seconds: 18),
          followRedirects: false,
          validateStatus: (status) =>
              status != null && status >= 100 && status < 600,
          headers: const {'Accept': 'application/json'},
        ),
      ) {
    dio.interceptors.add(
      _SessionInterceptor(
        sessionStore: sessionStore,
        expectedBaseUri: config.apiBaseUri,
      ),
    );
  }

  ApiClient.withDio(this.dio);

  final Dio dio;
}

class _SessionInterceptor extends Interceptor {
  _SessionInterceptor({
    required this.sessionStore,
    required this.expectedBaseUri,
  });

  static const cookieName = '__Host-leiva_app_session';
  static const csrfHeader = 'X-CSRF-Token';

  final SessionStore sessionStore;
  final Uri expectedBaseUri;

  bool _isExpectedDestination(Uri uri) =>
      uri.scheme == 'https' &&
      uri.host == expectedBaseUri.host &&
      uri.port == expectedBaseUri.port &&
      uri.path.startsWith('${expectedBaseUri.path}/');

  bool _requiresCsrf(RequestOptions options) {
    final method = options.method.toUpperCase();
    final isMutation = const {
      'POST',
      'PUT',
      'PATCH',
      'DELETE',
    }.contains(method);
    return isMutation && !options.path.endsWith('/auth/login');
  }

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isExpectedDestination(options.uri)) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.badCertificate,
          message: 'Destino de API no permitido.',
        ),
      );
      return;
    }

    final cookie = await sessionStore.readSessionCookie();
    if (cookie != null && cookie.isNotEmpty) {
      options.headers['Cookie'] = '$cookieName=$cookie';
    }

    if (_requiresCsrf(options)) {
      final csrf = await sessionStore.readCsrfToken();
      if (csrf != null && csrf.isNotEmpty) {
        options.headers[csrfHeader] = csrf;
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final cookies = response.headers.map['set-cookie'] ?? const <String>[];
    for (final header in cookies) {
      final match = RegExp(
        '^${RegExp.escape(cookieName)}=([^;]*)',
        caseSensitive: true,
      ).firstMatch(header);
      if (match == null) continue;
      final value = match.group(1) ?? '';
      if (value.isEmpty) {
        await sessionStore.clear();
      } else {
        await sessionStore.writeSessionCookie(value);
      }
    }
    handler.next(response);
  }
}
