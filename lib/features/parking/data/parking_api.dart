import 'package:dio/dio.dart';

import '../../../core/network/api_response.dart';
import '../domain/parking_models.dart';

class ParkingApi {
  const ParkingApi(this._dio);
  final Dio _dio;

  Future<List<ParkingBranch>> branches() async {
    final data = apiData(await _dio.get<dynamic>('branches'));
    return _items(data).map(ParkingBranch.fromJson).toList();
  }

  Future<List<ParkingBay>> bays({
    required int branchId,
    required DateTime from,
    required DateTime to,
    required String vehicleType,
  }) async {
    final data = apiData(
      await _dio.get<dynamic>(
        'parking/bays',
        queryParameters: {
          'branch_id': branchId,
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
          'vehicle_type': vehicleType,
        },
      ),
    );
    return _items(data).map(ParkingBay.fromJson).toList();
  }

  Future<List<ParkingRequest>> requests() async {
    final data = apiData(
      await _dio.get<dynamic>(
        'parking/requests',
        queryParameters: {'limit': 100},
      ),
    );
    return _items(data).map(ParkingRequest.fromJson).toList();
  }

  Future<ParkingRequest> create(ParkingRequestDraft draft) async {
    final response = await _dio.post<dynamic>(
      'parking/requests',
      data: {
        'bay_id': draft.bayId,
        'starts_at': draft.startsAt.toUtc().toIso8601String(),
        'ends_at': draft.endsAt.toUtc().toIso8601String(),
        'vehicle_type': draft.vehicleType,
        'plate': draft.plate,
        'purpose': draft.purpose,
        'notes': draft.notes,
      },
      options: Options(
        contentType: Headers.jsonContentType,
        headers: {'Idempotency-Key': draft.idempotencyKey},
      ),
    );
    return ParkingRequest.fromJson(apiData(response));
  }

  Future<ParkingRequest> cancel(int requestId) async {
    final response = await _dio.post<dynamic>(
      'parking/requests/$requestId/cancel',
    );
    return ParkingRequest.fromJson(apiData(response));
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> data) {
    final items = data['items'];
    if (items is! List) {
      throw const FormatException('La API devolvió una lista inesperada.');
    }
    return items.cast<Map<String, dynamic>>();
  }
}
