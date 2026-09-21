import 'package:flutter_test/flutter_test.dart';
import 'package:leiva_app_interna/features/push/data/push_installation_store.dart';
import 'package:leiva_app_interna/features/push/domain/push_models.dart';
import 'package:leiva_app_interna/features/push/domain/push_repository.dart';
import 'package:leiva_app_interna/features/push/presentation/push_coordinator.dart';

void main() {
  test('logout ordinario conserva una instalación consentida', () async {
    final gateway = _FakePushGateway();
    final coordinator = PushCoordinator(
      gateway: gateway,
      installationStore: _MemoryInstallationStore(
        enrollment: StoredDeviceEnrollment(
          credential: 'opaque-device-credential-12345678901234567890',
          scheme: 'Device',
          expiresAt: DateTime.now().toUtc().add(const Duration(days: 30)),
        ),
      ),
    );
    addTearDown(coordinator.dispose);

    await coordinator.beforeLogout();

    expect(gateway.unregisterCalls, 0);
    expect(coordinator.persistentEnrollmentEnabled, isTrue);
  });

  test('logout sin consentimiento revoca la instalación de sesión', () async {
    final gateway = _FakePushGateway();
    final coordinator = PushCoordinator(
      gateway: gateway,
      installationStore: _MemoryInstallationStore(),
    );
    addTearDown(coordinator.dispose);

    await coordinator.beforeLogout();

    expect(gateway.unregisterCalls, 1);
    expect(gateway.unregisteredInstallation, 'installation-test-123456');
  });
}

class _MemoryInstallationStore extends PushInstallationStore {
  _MemoryInstallationStore({this.enrollment});

  StoredDeviceEnrollment? enrollment;

  @override
  Future<void> clearEnrollment() async => enrollment = null;

  @override
  Future<StoredDeviceEnrollment?> readEnrollment() async => enrollment;

  @override
  Future<String> readOrCreate() async => 'installation-test-123456';

  @override
  Future<void> writeEnrollment(StoredDeviceEnrollment value) async =>
      enrollment = value;
}

class _FakePushGateway implements PushGateway {
  int unregisterCalls = 0;
  String? unregisteredInstallation;

  @override
  Future<void> unregister(String installationId) async {
    unregisterCalls++;
    unregisteredInstallation = installationId;
  }

  @override
  Future<PersistentEnrollment> enablePersistentEnrollment(
    String installationId,
    String idempotencyKey,
  ) => throw UnimplementedError();

  @override
  Future<DeviceEnrollmentStatus> deviceStatus(
    String installationId,
    String credential,
  ) => throw UnimplementedError();

  @override
  Future<int> markAllRead() => throw UnimplementedError();

  @override
  Future<bool> markRead(String notificationId) => throw UnimplementedError();

  @override
  Future<NotificationPage> notifications({
    String? cursor,
    bool unreadOnly = false,
  }) => throw UnimplementedError();

  @override
  Future<void> refreshDeviceToken(
    String installationId,
    String credential,
    String idempotencyKey,
    DeviceTokenRefreshDraft draft,
  ) => throw UnimplementedError();

  @override
  Future<void> revokeDevice(String installationId, String credential) =>
      throw UnimplementedError();

  @override
  Future<void> selfTest(String installationId, String idempotencyKey) =>
      throw UnimplementedError();

  @override
  Future<PushStatus> status() => throw UnimplementedError();

  @override
  Future<int> unreadCount() => throw UnimplementedError();

  @override
  Future<PushInstallation> upsert(
    String installationId,
    PushInstallationDraft draft,
  ) => throw UnimplementedError();
}
