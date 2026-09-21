import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leiva_app_interna/core/config/app_config.dart';
import 'package:leiva_app_interna/core/network/api_client.dart';
import 'package:leiva_app_interna/core/security/secure_session_store.dart';

void main() {
  test(
    'una llamada Device no mezcla cookie o CSRF ni invalida la sesión',
    () async {
      final store = _MemorySessionStore(
        cookie: 'session-secret',
        csrf: 'csrf-secret',
      );
      var unauthorizedCalls = 0;
      final client = ApiClient(
        config: AppConfig(
          apiBaseUri: Uri.parse('https://monitor.leivahnos.com.ar/api/app/v1'),
        ),
        sessionStore: store,
        onUnauthorized: () => unauthorizedCalls++,
      );
      final adapter = _CaptureAdapter(statusCode: 401);
      client.dio.httpClientAdapter = adapter;

      await client.dio.get<dynamic>(
        'push/device/installations/installation-123456',
        options: Options(
          headers: const {
            'Authorization': 'Device opaque-credential-12345678901234567890',
          },
          extra: const {'deviceCredentialRequest': true},
        ),
      );

      expect(adapter.request!.headers['Authorization'], startsWith('Device '));
      expect(adapter.request!.headers, isNot(contains('Cookie')));
      expect(adapter.request!.headers, isNot(contains('X-CSRF-Token')));
      expect(store.clearCalls, 0);
      expect(unauthorizedCalls, 0);
    },
  );

  test('una mutación autenticada conserva cookie y CSRF', () async {
    final store = _MemorySessionStore(
      cookie: 'session-secret',
      csrf: 'csrf-secret',
    );
    final client = ApiClient(
      config: AppConfig(
        apiBaseUri: Uri.parse('https://monitor.leivahnos.com.ar/api/app/v1'),
      ),
      sessionStore: store,
    );
    final adapter = _CaptureAdapter(statusCode: 200);
    client.dio.httpClientAdapter = adapter;

    await client.dio.post<dynamic>('notifications/read-all');

    expect(
      adapter.request!.headers['Cookie'],
      '__Host-leiva_app_session=session-secret',
    );
    expect(adapter.request!.headers['X-CSRF-Token'], 'csrf-secret');
  });
}

class _MemorySessionStore implements SessionStore {
  _MemorySessionStore({this.cookie, this.csrf});

  String? cookie;
  String? csrf;
  int clearCalls = 0;

  @override
  Future<void> clear() async {
    clearCalls++;
    cookie = null;
    csrf = null;
  }

  @override
  Future<String?> readCsrfToken() async => csrf;

  @override
  Future<String?> readSessionCookie() async => cookie;

  @override
  Future<void> writeCsrfToken(String value) async => csrf = value;

  @override
  Future<void> writeSessionCookie(String value) async => cookie = value;
}

class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter({required this.statusCode});

  final int statusCode;
  RequestOptions? request;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    final body = statusCode >= 400
        ? '{"error":{"code":"invalid_device_credential","message":"invalid"}}'
        : '{"data":{}}';
    return ResponseBody.fromString(
      body,
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}
