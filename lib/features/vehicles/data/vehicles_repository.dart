import '../domain/vehicle_models.dart';
import 'vehicles_api.dart';

abstract interface class VehiclesGateway {
  Future<List<VehicleOption>> available({
    required DateTime from,
    required DateTime to,
  });
  Future<List<VehicleReservation>> reservations();
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
  Future<VehicleTripView> trip(int reservationId, {required bool live});
  Future<List<VehicleNotice>> notices({int? reservationId});
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
  Future<VehicleTripView> trip(int reservationId, {required bool live}) =>
      _api.trip(reservationId, live: live);

  @override
  Future<List<VehicleNotice>> notices({int? reservationId}) =>
      _api.notices(reservationId: reservationId);
}
