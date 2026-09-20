import '../domain/vehicle_models.dart';
import 'vehicles_api.dart';

abstract interface class VehiclesGateway {
  Future<List<VehicleOption>> available({
    required DateTime from,
    required DateTime to,
  });
  Future<List<VehicleReservation>> reservations();
  Future<VehicleReservation> reservation(int reservationId);
  Future<VehicleReservation> create(VehicleReservationDraft draft);
  Future<VehicleReservation> action(
    int reservationId,
    String action, {
    String? notes,
  });
  Future<VehicleReservation> extend(
    int reservationId,
    DateTime endsAt, {
    String? notes,
  });
  Future<VehicleReturnParking> createReturnParking(
    int reservationId,
    VehicleReturnParkingDraft draft,
  );
  Future<VehicleTripView> trip(int reservationId, {required bool live});
  Future<List<VehicleNotice>> notices({int? reservationId});
  Future<VehicleNotice> notice(int noticeId);
  Future<List<VehicleAgendaItem>> activeAgenda();
  Future<List<VehicleAgendaItem>> agendaHistory();
}

class VehiclesRepository implements VehiclesGateway {
  const VehiclesRepository(this._api);
  final VehiclesApi _api;

  @override
  Future<List<VehicleOption>> available({
    required DateTime from,
    required DateTime to,
  }) => _api.available(from: from, to: to);

  @override
  Future<List<VehicleReservation>> reservations() => _api.reservations();

  @override
  Future<VehicleReservation> reservation(int reservationId) =>
      _api.reservation(reservationId);

  @override
  Future<VehicleReservation> create(VehicleReservationDraft draft) =>
      _api.create(draft);

  @override
  Future<VehicleReservation> action(
    int reservationId,
    String action, {
    String? notes,
  }) => _api.action(reservationId, action, notes: notes);

  @override
  Future<VehicleReservation> extend(
    int reservationId,
    DateTime endsAt, {
    String? notes,
  }) => _api.extend(reservationId, endsAt, notes: notes);

  @override
  Future<VehicleReturnParking> createReturnParking(
    int reservationId,
    VehicleReturnParkingDraft draft,
  ) => _api.createReturnParking(reservationId, draft);

  @override
  Future<VehicleTripView> trip(int reservationId, {required bool live}) =>
      _api.trip(reservationId, live: live);

  @override
  Future<List<VehicleNotice>> notices({int? reservationId}) =>
      _api.notices(reservationId: reservationId);

  @override
  Future<VehicleNotice> notice(int noticeId) => _api.notice(noticeId);

  @override
  Future<List<VehicleAgendaItem>> activeAgenda() => _api.activeAgenda();

  @override
  Future<List<VehicleAgendaItem>> agendaHistory() => _api.agendaHistory();
}
