import 'package:flutter_test/flutter_test.dart';
import 'package:leiva_app_interna/features/push/domain/push_models.dart';
import 'package:leiva_app_interna/features/push/presentation/push_coordinator.dart';

void main() {
  test('acepta únicamente los deep links publicados por el portal', () {
    expect(PushTarget.parse('leivaapp://home')?.type, PushTargetType.home);
    final vehicle = PushTarget.parse('leivaapp://vehicles/reservations/84');
    expect(vehicle?.type, PushTargetType.vehicleReservation);
    expect(vehicle?.resourceId, 84);
    final parking = PushTarget.parse('leivaapp://parking/requests/17');
    expect(parking?.type, PushTargetType.parkingRequest);
    expect(parking?.resourceId, 17);
    final room = PushTarget.parse('leivaapp://rooms/reservations/23');
    expect(room?.type, PushTargetType.roomReservation);
    expect(room?.resourceId, 23);
    final expense = PushTarget.parse('leivaapp://expenses/records/41');
    expect(expense?.type, PushTargetType.expenseRecord);
    expect(expense?.resourceId, 41);
  });

  test('rechaza esquemas, rutas e identificadores no permitidos', () {
    const rejected = [
      'https://monitor.leivahnos.com.ar',
      'leivaapp://admin/users/1',
      'leivaapp://vehicles/reservations/no-numero',
      'leivaapp://vehicles/reservations/1?admin=true',
      'leivaapp://parking/requests/-2',
      'leivaapp://home/extra',
      'javascript:alert(1)',
    ];

    expect(rejected.every((value) => PushTarget.parse(value) == null), isTrue);
  });

  test('interpreta estado push sin exponer tokens', () {
    final status = PushStatus.fromJson({
      'provider': {
        'enabled': true,
        'configured': true,
        'provider': 'fcm',
        'android_channel_id': 'leiva_general',
      },
      'categories': ['general', 'parking_status'],
      'installations': [
        {
          'installation_id': '12345678-1234-4234-8234-123456789012',
          'platform': 'android',
          'device_name': 'Leiva App Android',
          'permission_status': 'authorized',
          'notifications_enabled': true,
          'categories': ['general'],
          'last_registered_at': '2026-09-20T02:00:00Z',
        },
      ],
    });

    expect(status.provider.configured, isTrue);
    expect(status.provider.androidChannelId, 'leiva_general');
    expect(status.installations.single.notificationsEnabled, isTrue);
    expect(status.installations.single.categories, ['general']);
  });

  test('genera el cuerpo exacto requerido para registrar la instalación', () {
    const draft = PushInstallationDraft(
      token: 'abcdefghijklmnopqrstuvwxyz1234567890',
      deviceName: 'Leiva App Android',
      appVersion: '1.8.0+8001',
      permissionStatus: 'authorized',
      notificationsEnabled: true,
      categories: ['general', 'expense_status'],
    );

    expect(draft.toJson(), {
      'token': 'abcdefghijklmnopqrstuvwxyz1234567890',
      'platform': 'android',
      'device_name': 'Leiva App Android',
      'app_version': '1.8.0+8001',
      'permission_status': 'authorized',
      'notifications_enabled': true,
      'categories': ['general', 'expense_status'],
    });
  });

  test('interpreta la página canónica de avisos persistidos', () {
    final page = NotificationPage.fromJson({
      'items': [
        {
          'id': '12345678-1234-4234-8234-123456789012',
          'category': 'room_reservation',
          'title': 'Sala actualizada',
          'body': 'Cambió el horario.',
          'priority': 'normal',
          'resource_type': 'room_reservation',
          'resource_id': '23',
          'deep_link': 'leivaapp://rooms/reservations/23',
          'is_read': false,
          'read_at': null,
          'created_at': '2026-09-20T17:00:00Z',
        },
      ],
      'unread_count': 1,
      'next_cursor': null,
      'retention_days': 180,
      'recommended_refresh_seconds': 120,
    });

    expect(page.unreadCount, 1);
    expect(page.items.single.isRead, isFalse);
    expect(page.items.single.deepLink, 'leivaapp://rooms/reservations/23');
    expect(page.recommendedRefreshSeconds, 120);
  });
}
