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
}
