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

  Future<VehicleReservation> reservation(int reservationId) async {
    final response = await _dio.get<dynamic>(
      'vehicle-reservations/$reservationId',
    );
    return VehicleReservation.fromJson(apiData(response));
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
        'planned_distance_km': draft.plannedDistanceKm,
        'occupant_count': draft.occupantCount,
        'estimated_luggage_kg': draft.estimatedLuggageKg,
        'notes': draft.notes,
        'return_bay_id': draft.returnBayId,
        'return_parking_minutes': draft.returnParkingMinutes,
      },
      options: Options(
        contentType: Headers.jsonContentType,
        headers: {'Idempotency-Key': draft.idempotencyKey},
      ),
    );
    return VehicleReservation.fromJson(apiData(response));
  }

  Future<VehicleReturnParking> createReturnParking(
    int reservationId,
    VehicleReturnParkingDraft draft,
  ) async {
    final response = await _dio.post<dynamic>(
      'vehicle-reservations/$reservationId/return-parking',
      data: {'bay_id': draft.bayId, 'minutes': draft.minutes},
      options: Options(
        contentType: Headers.jsonContentType,
        headers: {'Idempotency-Key': draft.idempotencyKey},
      ),
    );
    final data = apiData(response);
    return VehicleReturnParking.fromJson(
      data['return_parking'] as Map<String, dynamic>,
    );
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

  Future<VehicleReservation> extend(
    int reservationId,
    DateTime endsAt, {
    String? notes,
  }) async {
    final response = await _dio.post<dynamic>(
      'vehicle-reservations/$reservationId/extend',
      data: {'ends_at': endsAt.toUtc().toIso8601String(), 'notes': notes},
      options: Options(contentType: Headers.jsonContentType),
    );
    return VehicleReservation.fromJson(apiData(response));
  }

  Future<VehicleTripView> trip(int reservationId, {required bool live}) async {
    final path = live
        ? 'vehicle-reservations/$reservationId/live'
        : 'vehicle-reservations/$reservationId/trajectory';
    final response = await _dio.get<dynamic>(
      path,
      queryParameters: live ? null : {'refresh': false},
    );
    return VehicleTripView.fromJson(apiData(response));
  }

  Future<List<VehicleNotice>> notices({int? reservationId}) async {
    final query = <String, dynamic>{'limit': 100};
    if (reservationId != null) {
      query['reservation_id'] = reservationId;
    }
    final data = apiData(
      await _dio.get<dynamic>('vehicle-notices', queryParameters: query),
    );
    return _items(data).map(VehicleNotice.fromJson).toList();
  }

  Future<VehicleNotice> notice(int noticeId) async {
    final response = await _dio.get<dynamic>('vehicle-notices/$noticeId');
    return VehicleNotice.fromJson(apiData(response));
  }

  Future<List<VehicleAgendaItem>> activeAgenda() async {
    final data = apiData(await _dio.get<dynamic>('vehicle-agenda/active'));
    return _items(data).map(VehicleAgendaItem.fromJson).toList();
  }

  Future<List<VehicleAgendaItem>> agendaHistory() async {
    final data = apiData(
      await _dio.get<dynamic>(
        'vehicle-agenda/history',
        queryParameters: {'limit': 100},
      ),
    );
    return _items(data).map(VehicleAgendaItem.fromJson).toList();
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> data) {
    final items = data['items'];
    if (items is! List) {
      throw const FormatException('La API devolvió una lista inesperada.');
    }
    return items.cast<Map<String, dynamic>>();
  }
}
