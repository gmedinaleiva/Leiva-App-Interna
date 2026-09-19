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
  Future<RoomReservation> detail(int reservationId);
  Future<List<RoomParticipantOption>> participants(String query);
  Future<VisitorParkingOptions> visitorParkingOptions(
    int reservationId, {
    required String vehicleType,
  });
  Future<Map<String, dynamic>> createVisitorParking(
    int reservationId,
    VisitorParkingDraft draft,
  );
  Future<RoomReservation> create(RoomReservationDraft draft);
  Future<RoomReservation> update(
    int reservationId,
    RoomReservationUpdate draft,
  );
  Future<void> withdraw(int reservationId);
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
  Future<RoomReservation> detail(int reservationId) =>
      _api.detail(reservationId);

  @override
  Future<List<RoomParticipantOption>> participants(String query) =>
      _api.participants(query);

  @override
  Future<VisitorParkingOptions> visitorParkingOptions(
    int reservationId, {
    required String vehicleType,
  }) => _api.visitorParkingOptions(reservationId, vehicleType: vehicleType);

  @override
  Future<Map<String, dynamic>> createVisitorParking(
    int reservationId,
    VisitorParkingDraft draft,
  ) => _api.createVisitorParking(reservationId, draft);

  @override
  Future<RoomReservation> create(RoomReservationDraft draft) =>
      _api.create(draft);

  @override
  Future<RoomReservation> update(
    int reservationId,
    RoomReservationUpdate draft,
  ) => _api.update(reservationId, draft);

  @override
  Future<void> withdraw(int reservationId) => _api.withdraw(reservationId);

  @override
  Future<RoomReservation> cancel(int reservationId, {String? reason}) =>
      _api.cancel(reservationId, reason: reason);
}
