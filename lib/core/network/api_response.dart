import 'package:dio/dio.dart';

import 'api_error.dart';

Map<String, dynamic> apiSuccessJson(Response<dynamic> response) {
  ensureApiSuccess(response);
  final value = response.data;
  if (value is! Map<String, dynamic>) {
    throw const FormatException('La API devolvió una respuesta inesperada.');
  }
  return value;
}

Map<String, dynamic> apiData(Response<dynamic> response) {
  final json = apiSuccessJson(response);
  final data = json['data'];
  if (data is! Map<String, dynamic>) {
    throw const FormatException('La API devolvió datos inesperados.');
  }
  return data;
}

void ensureApiSuccess(Response<dynamic> response) {
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
  throw ApiFailure(
    statusCode: status,
    code: code,
    message: message,
    retryAfterSeconds: int.tryParse(
      response.headers.value('retry-after') ?? '',
    ),
  );
}
