import 'package:dio/dio.dart';

import '../../../core/network/api_response.dart';
import '../domain/vehicle_models.dart';

class VehiclesApi {
  const VehiclesApi(this._dio);
  final Dio _dio;

  Future<List<VehicleOption>> available({
    required DateTime from,
    required DateTime to,
  }) async {
    final data = apiData(
      await _dio.get<dynamic>(
        'vehicles',
        queryParameters: {
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
        },
      ),
    );
    return _items(data).map(VehicleOption.fromJson).toList();
  }

  Future<List<VehicleReservation>> reservations() async {
    final data = apiData(
      await _dio.get<dynamic>(
        'vehicle-reservations',
        queryParameters: {'limit': 100},
      ),
    );
    return _items(data).map(VehicleReservation.fromJson).toList();
  }

  Future<VehicleReservation> create(VehicleReservationDraft draft) async {
    final response = await _dio.post<dynamic>(
      'vehicle-reservations',
      data: {
        'vehicle_id': draft.vehicleId,
        'starts_at': draft.startsAt.toUtc().toIso8601String(),
        'ends_at': draft.endsAt.toUtc().toIso8601String(),
        'purpose': draft.purpose,
        'destination': draft.destination,
        'occupant_count': draft.occupantCount,
        'notes': draft.notes,
      },
      options: Options(
        contentType: Headers.jsonContentType,
        headers: {'Idempotency-Key': draft.idempotencyKey},
      ),
    );
    return VehicleReservation.fromJson(apiData(response));
  }

  Future<VehicleReservation> action(
    int reservationId,
    String action, {
    String? notes,
  }) async {
    final response = await _dio.post<dynamic>(
      'vehicle-reservations/$reservationId/action',
      data: {'action': action, 'notes': notes},
      options: Options(contentType: Headers.jsonContentType),
    );
    return VehicleReservation.fromJson(apiData(response));
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> data) {
    final items = data['items'];
    if (items is! List) {
      throw const FormatException('La API devolvió una lista inesperada.');
    }
    return items.cast<Map<String, dynamic>>();
  }
}
