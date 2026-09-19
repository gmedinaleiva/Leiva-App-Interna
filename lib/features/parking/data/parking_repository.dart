import '../domain/parking_models.dart';
import 'parking_api.dart';

abstract interface class ParkingGateway {
  Future<List<ParkingBranch>> branches();
  Future<List<ParkingBay>> bays({
    required int branchId,
    required DateTime from,
    required DateTime to,
    required String vehicleType,
  });
  Future<List<ParkingRequest>> requests();
  Future<ParkingRequest> create(ParkingRequestDraft draft);
  Future<ParkingRequest> cancel(int requestId);
}

class ParkingRepository implements ParkingGateway {
  const ParkingRepository(this._api);
  final ParkingApi _api;

  @override
  Future<List<ParkingBranch>> branches() => _api.branches();

  @override
  Future<List<ParkingBay>> bays({
    required int branchId,
    required DateTime from,
    required DateTime to,
    required String vehicleType,
  }) => _api.bays(
    branchId: branchId,
    from: from,
    to: to,
    vehicleType: vehicleType,
  );

  @override
  Future<List<ParkingRequest>> requests() => _api.requests();

  @override
  Future<ParkingRequest> create(ParkingRequestDraft draft) =>
      _api.create(draft);

  @override
  Future<ParkingRequest> cancel(int requestId) => _api.cancel(requestId);
}
