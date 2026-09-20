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
}
