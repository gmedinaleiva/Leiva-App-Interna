import 'package:dio/dio.dart';

import '../../../core/network/api_response.dart';
import '../domain/push_models.dart';

class PushApi {
  const PushApi(this._dio);

  final Dio _dio;

  Future<PushStatus> status() async =>
      PushStatus.fromJson(apiData(await _dio.get<dynamic>('push/status')));

  Future<PushInstallation> upsert(
    String installationId,
    PushInstallationDraft draft,
  ) async => PushInstallation.fromJson(
    apiData(
      await _dio.put<dynamic>(
        'push/installations/$installationId',
        data: draft.toJson(),
        options: Options(contentType: Headers.jsonContentType),
      ),
    ),
  );

  Future<void> unregister(String installationId) async {
    final response = await _dio.delete<dynamic>(
      'push/installations/$installationId',
    );
    ensureApiSuccess(response);
  }

  Future<PersistentEnrollment> enablePersistentEnrollment(
    String installationId,
    String idempotencyKey,
  ) async => PersistentEnrollment.fromJson(
    apiData(
      await _dio.post<dynamic>(
        'push/installations/$installationId/persistent-enrollment',
        data: const {'consent': true, 'consent_version': '1'},
        options: Options(
          contentType: Headers.jsonContentType,
          headers: {'Idempotency-Key': idempotencyKey},
        ),
      ),
    ),
  );

  Future<DeviceEnrollmentStatus> deviceStatus(
    String installationId,
    String credential,
  ) async => DeviceEnrollmentStatus.fromJson(
    apiData(
      await _dio.get<dynamic>(
        'push/device/installations/$installationId',
        options: _deviceOptions(credential),
      ),
    ),
  );

  Future<void> refreshDeviceToken(
    String installationId,
    String credential,
    String idempotencyKey,
    DeviceTokenRefreshDraft draft,
  ) async {
    ensureApiSuccess(
      await _dio.put<dynamic>(
        'push/device/installations/$installationId/token',
        data: draft.toJson(),
        options: _deviceOptions(
          credential,
          headers: {'Idempotency-Key': idempotencyKey},
        ),
      ),
    );
  }

  Future<void> revokeDevice(String installationId, String credential) async {
    ensureApiSuccess(
      await _dio.delete<dynamic>(
        'push/device/installations/$installationId',
        options: _deviceOptions(credential),
      ),
    );
  }

  Future<NotificationPage> notifications({
    String? cursor,
    bool unreadOnly = false,
  }) async => NotificationPage.fromJson(
    apiData(
      await _dio.get<dynamic>(
        'notifications',
        queryParameters: <String, dynamic>{
          'cursor': cursor,
          'unread_only': unreadOnly,
          'limit': 30,
        }..removeWhere((_, value) => value == null),
      ),
    ),
  );

  Future<int> unreadCount() async =>
      apiData(
            await _dio.get<dynamic>('notifications/unread-count'),
          )['unread_count']
          as int? ??
      0;

  Future<bool> markRead(String notificationId) async =>
      apiData(
            await _dio.post<dynamic>('notifications/$notificationId/read'),
          )['changed']
          as bool? ??
      false;

  Future<int> markAllRead() async =>
      apiData(await _dio.post<dynamic>('notifications/read-all'))['marked_read']
          as int? ??
      0;

  Future<void> selfTest(String installationId, String idempotencyKey) async {
    ensureApiSuccess(
      await _dio.post<dynamic>(
        'push/test',
        data: {'installation_id': installationId},
        options: Options(
          contentType: Headers.jsonContentType,
          headers: {'Idempotency-Key': idempotencyKey},
        ),
      ),
    );
  }

  Options _deviceOptions(String credential, {Map<String, dynamic>? headers}) =>
      Options(
        contentType: Headers.jsonContentType,
        headers: <String, dynamic>{
          'Authorization': 'Device $credential',
          ...?headers,
        },
        extra: const {'deviceCredentialRequest': true},
      );
}
