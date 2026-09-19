import 'package:dio/dio.dart';

import '../../../core/network/api_response.dart';
import '../domain/room_models.dart';

class RoomsApi {
  const RoomsApi(this._dio);

  final Dio _dio;

  Future<List<RoomBranch>> branches() async {
    final data = apiData(await _dio.get<dynamic>('branches'));
    return _items(data).map(RoomBranch.fromJson).toList();
  }

  Future<List<MeetingRoom>> rooms(int branchId) async {
    final data = apiData(
      await _dio.get<dynamic>(
        'rooms',
        queryParameters: {'branch_id': branchId},
      ),
    );
    return _items(data).map(MeetingRoom.fromJson).toList();
  }

  Future<List<RoomAvailability>> availability({
    required int branchId,
    required DateTime from,
    required DateTime to,
  }) async {
    final data = apiData(
      await _dio.get<dynamic>(
        'rooms/availability',
        queryParameters: {
          'branch_id': branchId,
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
        },
      ),
    );
    return _items(data).map(RoomAvailability.fromJson).toList();
  }

  Future<List<RoomReservation>> reservations({
    required DateTime from,
    required DateTime to,
  }) async {
    final data = apiData(
      await _dio.get<dynamic>(
        'room-reservations',
        queryParameters: {
          'from': from.toUtc().toIso8601String(),
          'to': to.toUtc().toIso8601String(),
          'limit': 100,
        },
      ),
    );
    return _items(data).map(RoomReservation.fromJson).toList();
  }

  Future<RoomReservation> create(RoomReservationDraft draft) async {
    final response = await _dio.post<dynamic>(
      'room-reservations',
      data: {
        'room_id': draft.roomId,
        'title': draft.title,
        'notes': draft.notes,
        'starts_at': draft.startsAt.toUtc().toIso8601String(),
        'ends_at': draft.endsAt.toUtc().toIso8601String(),
        'internal_participant_ids': <int>[],
        'external_participants': <Map<String, dynamic>>[],
      },
      options: Options(
        contentType: Headers.jsonContentType,
        headers: {'Idempotency-Key': draft.idempotencyKey},
      ),
    );
    return RoomReservation.fromJson(apiData(response));
  }

  Future<RoomReservation> cancel(int reservationId, {String? reason}) async {
    final response = await _dio.post<dynamic>(
      'room-reservations/$reservationId/cancel',
      data: {'reason': reason},
      options: Options(contentType: Headers.jsonContentType),
    );
    return RoomReservation.fromJson(apiData(response));
  }

  List<Map<String, dynamic>> _items(Map<String, dynamic> data) {
    final items = data['items'];
    if (items is! List) {
      throw const FormatException('La API devolvió una lista inesperada.');
    }
    return items.cast<Map<String, dynamic>>();
  }
}
