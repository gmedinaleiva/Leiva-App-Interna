import '../data/push_api.dart';
import 'push_models.dart';

abstract interface class PushGateway {
  Future<PushStatus> status();
  Future<PushInstallation> upsert(
    String installationId,
    PushInstallationDraft draft,
  );
  Future<void> unregister(String installationId);
  Future<PersistentEnrollment> enablePersistentEnrollment(
    String installationId,
    String idempotencyKey,
  );
  Future<DeviceEnrollmentStatus> deviceStatus(
    String installationId,
    String credential,
  );
  Future<void> refreshDeviceToken(
    String installationId,
    String credential,
    String idempotencyKey,
    DeviceTokenRefreshDraft draft,
  );
  Future<void> revokeDevice(String installationId, String credential);
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
  Future<PersistentEnrollment> enablePersistentEnrollment(
    String installationId,
    String idempotencyKey,
  ) => _api.enablePersistentEnrollment(installationId, idempotencyKey);

  @override
  Future<DeviceEnrollmentStatus> deviceStatus(
    String installationId,
    String credential,
  ) => _api.deviceStatus(installationId, credential);

  @override
  Future<void> refreshDeviceToken(
    String installationId,
    String credential,
    String idempotencyKey,
    DeviceTokenRefreshDraft draft,
  ) => _api.refreshDeviceToken(
    installationId,
    credential,
    idempotencyKey,
    draft,
  );

  @override
  Future<void> revokeDevice(String installationId, String credential) =>
      _api.revokeDevice(installationId, credential);

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
