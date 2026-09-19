import '../domain/room_models.dart';
import 'rooms_api.dart';

abstract interface class RoomsGateway {
  Future<List<RoomBranch>> branches();
  Future<List<MeetingRoom>> rooms(int branchId);
  Future<List<RoomAvailability>> availability({
    required int branchId,
    required DateTime from,
    required DateTime to,
  });
  Future<List<RoomReservation>> reservations({
    required DateTime from,
    required DateTime to,
  });
  Future<RoomReservation> create(RoomReservationDraft draft);
  Future<RoomReservation> cancel(int reservationId, {String? reason});
}

class RoomsRepository implements RoomsGateway {
  const RoomsRepository(this._api);

  final RoomsApi _api;

  @override
  Future<List<RoomBranch>> branches() => _api.branches();

  @override
  Future<List<MeetingRoom>> rooms(int branchId) => _api.rooms(branchId);

  @override
  Future<List<RoomAvailability>> availability({
    required int branchId,
    required DateTime from,
    required DateTime to,
  }) => _api.availability(branchId: branchId, from: from, to: to);

  @override
  Future<List<RoomReservation>> reservations({
    required DateTime from,
    required DateTime to,
  }) => _api.reservations(from: from, to: to);

  @override
  Future<RoomReservation> create(RoomReservationDraft draft) =>
      _api.create(draft);

  @override
  Future<RoomReservation> cancel(int reservationId, {String? reason}) =>
      _api.cancel(reservationId, reason: reason);
}
