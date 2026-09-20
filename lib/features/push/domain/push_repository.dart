import '../data/push_api.dart';
import 'push_models.dart';

abstract interface class PushGateway {
  Future<PushStatus> status();
  Future<PushInstallation> upsert(
    String installationId,
    PushInstallationDraft draft,
  );
  Future<void> unregister(String installationId);
}

class PushRepository implements PushGateway {
  const PushRepository(this._api);

  final PushApi _api;

  @override
  Future<PushStatus> status() => _api.status();

  @override
  Future<PushInstallation> upsert(
    String installationId,
    PushInstallationDraft draft,
  ) => _api.upsert(installationId, draft);

  @override
  Future<void> unregister(String installationId) =>
      _api.unregister(installationId);
}
