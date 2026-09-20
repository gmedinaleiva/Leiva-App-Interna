import '../data/push_api.dart';
import 'push_models.dart';

abstract interface class PushGateway {
  Future<PushStatus> status();
  Future<PushInstallation> upsert(
    String installationId,
    PushInstallationDraft draft,
  );
  Future<void> unregister(String installationId);
  Future<NotificationPage> notifications({
    String? cursor,
    bool unreadOnly = false,
  });
  Future<int> unreadCount();
  Future<bool> markRead(String notificationId);
  Future<int> markAllRead();
  Future<void> selfTest(String installationId, String idempotencyKey);
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

  @override
  Future<NotificationPage> notifications({
    String? cursor,
    bool unreadOnly = false,
  }) => _api.notifications(cursor: cursor, unreadOnly: unreadOnly);

  @override
  Future<int> unreadCount() => _api.unreadCount();

  @override
  Future<bool> markRead(String notificationId) => _api.markRead(notificationId);

  @override
  Future<int> markAllRead() => _api.markAllRead();

  @override
  Future<void> selfTest(String installationId, String idempotencyKey) =>
      _api.selfTest(installationId, idempotencyKey);
}
