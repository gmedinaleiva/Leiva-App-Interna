import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/network/api_error.dart';
import '../../../core/security/idempotency_key.dart';
import '../data/push_installation_store.dart';
import '../domain/push_models.dart';
import '../domain/push_repository.dart';

const pushAndroidChannelId = 'leiva_general';

@pragma('vm:entry-point')
Future<void> leivaFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Firebase permanece cerrado cuando falta la configuración corporativa.
  }
}

enum PushClientState {
  idle,
  loading,
  serverNotConfigured,
  clientNotConfigured,
  permissionDenied,
  registered,
  disabled,
  error,
}

enum PushTargetType {
  home,
  roomReservation,
  vehicleReservation,
  parkingRequest,
  expenseRecord,
}

class PushTarget {
  const PushTarget(this.type, {this.resourceId});

  final PushTargetType type;
  final int? resourceId;

  static PushTarget? parse(String? value) {
    final uri = Uri.tryParse(value ?? '');
    if (uri == null ||
        uri.scheme != 'leivaapp' ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    if (uri.host == 'home' && uri.pathSegments.isEmpty) {
      return const PushTarget(PushTargetType.home);
    }
    if (uri.host == 'vehicles' &&
        uri.pathSegments.length == 2 &&
        uri.pathSegments.first == 'reservations') {
      final id = int.tryParse(uri.pathSegments.last);
      return id != null && id > 0
          ? PushTarget(PushTargetType.vehicleReservation, resourceId: id)
          : null;
    }
    if (uri.host == 'rooms' &&
        uri.pathSegments.length == 2 &&
        uri.pathSegments.first == 'reservations') {
      final id = int.tryParse(uri.pathSegments.last);
      return id != null && id > 0
          ? PushTarget(PushTargetType.roomReservation, resourceId: id)
          : null;
    }
    if (uri.host == 'parking' &&
        uri.pathSegments.length == 2 &&
        uri.pathSegments.first == 'requests') {
      final id = int.tryParse(uri.pathSegments.last);
      return id != null && id > 0
          ? PushTarget(PushTargetType.parkingRequest, resourceId: id)
          : null;
    }
    if (uri.host == 'expenses' &&
        uri.pathSegments.length == 2 &&
        uri.pathSegments.first == 'records') {
      final id = int.tryParse(uri.pathSegments.last);
      return id != null && id > 0
          ? PushTarget(PushTargetType.expenseRecord, resourceId: id)
          : null;
    }
    return null;
  }
}

class PushCoordinator extends ChangeNotifier {
  PushCoordinator({
    required this.gateway,
    PushInstallationStore? installationStore,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _installationStore = installationStore ?? PushInstallationStore(),
       _injectedMessaging = messaging,
       _localNotifications =
           localNotifications ?? FlutterLocalNotificationsPlugin();

  final PushGateway gateway;
  final PushInstallationStore _installationStore;
  final FirebaseMessaging? _injectedMessaging;
  final FlutterLocalNotificationsPlugin _localNotifications;

  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  void Function(PushTarget target)? _navigationHandler;
  PushTarget? _pendingTarget;
  String? _installationId;
  String? _token;
  bool _started = false;
  bool _firebaseReady = false;

  FirebaseMessaging get _messaging =>
      _injectedMessaging ?? FirebaseMessaging.instance;

  PushClientState state = PushClientState.idle;
  PushStatus? status;
  PushInstallation? installation;
  String? message;
  Set<String> selectedCategories = const {};
  List<AppNotification> notifications = const [];
  int unreadCount = 0;
  String? nextNotificationCursor;
  int notificationRetentionDays = 180;
  bool inboxLoading = false;
  String? inboxError;
  DateTime? _lastInboxRefresh;

  bool get canConfigure =>
      _firebaseReady && status?.provider.configured == true;

  void attachNavigationHandler(void Function(PushTarget target) handler) {
    _navigationHandler = handler;
    final pending = _pendingTarget;
    if (pending != null) {
      _pendingTarget = null;
      handler(pending);
    }
  }

  void detachNavigationHandler() => _navigationHandler = null;

  Future<void> startAuthenticated({bool force = false}) async {
    if (_started && !force) return;
    _started = true;
    state = PushClientState.loading;
    message = null;
    notifyListeners();
    try {
      _installationId ??= await _installationStore.readOrCreate();
      await _initializeLocalNotifications();
      await refreshInbox(force: true);
      status = await gateway.status();
      installation = status!.installations
          .where((item) => item.installationId == _installationId)
          .firstOrNull;
      selectedCategories = {
        ...(installation?.categories ?? status!.categories),
      };
      if (!status!.provider.configured) {
        state = PushClientState.serverNotConfigured;
        message = 'Sistemas todavía debe activar Firebase en el portal.';
        notifyListeners();
        return;
      }
      _firebaseReady = await _initializeFirebase();
      if (!_firebaseReady) {
        state = PushClientState.clientNotConfigured;
        message = 'Falta la configuración Firebase corporativa de Android.';
        notifyListeners();
        return;
      }
      await _bindFirebaseStreams();
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final permission = _permissionName(settings.authorizationStatus);
      if (permission != 'authorized') {
        state = PushClientState.permissionDenied;
        message = 'Las notificaciones no están autorizadas en el teléfono.';
        notifyListeners();
        return;
      }
      _token = await _messaging.getToken();
      if (_token == null || _token!.length < 32) {
        state = PushClientState.error;
        message = 'Firebase no entregó un token válido para este teléfono.';
        notifyListeners();
        return;
      }
      await _register(
        token: _token!,
        permissionStatus: permission,
        notificationsEnabled: installation?.notificationsEnabled ?? true,
      );
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) _openMessage(initialMessage);
    } on ApiFailure catch (error) {
      if (error.statusCode == 503 && error.code == 'push_not_configured') {
        state = PushClientState.serverNotConfigured;
        message = 'Sistemas todavía debe activar Firebase en el portal.';
      } else {
        state = PushClientState.error;
        message = error.message;
      }
      notifyListeners();
    } catch (_) {
      state = PushClientState.error;
      message = 'No pudimos preparar las notificaciones en este momento.';
      notifyListeners();
    }
  }

  Future<void> refreshStatus() async {
    try {
      _installationId ??= await _installationStore.readOrCreate();
      status = await gateway.status();
      installation = status!.installations
          .where((item) => item.installationId == _installationId)
          .firstOrNull;
      selectedCategories = {
        ...(installation?.categories ?? status!.categories),
      };
      if (!status!.provider.configured) {
        state = PushClientState.serverNotConfigured;
      }
      notifyListeners();
    } on ApiFailure catch (error) {
      state = PushClientState.error;
      message = error.message;
      notifyListeners();
    }
  }

  Future<bool> showLocalTestNotification() async {
    try {
      await _initializeLocalNotifications();
      final android = _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final allowed = await android?.requestNotificationsPermission() ?? true;
      if (!allowed) {
        state = PushClientState.permissionDenied;
        message = 'Android no autorizó las notificaciones en este teléfono.';
        notifyListeners();
        return false;
      }
      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          pushAndroidChannelId,
          'Leiva Interna',
          channelDescription:
              'Avisos de reservas, estacionamiento y gestiones personales.',
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_launcher_foreground',
          playSound: true,
          enableVibration: true,
        ),
      );
      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
        title: 'Prueba de Leiva Interna',
        body: 'El sonido y la vibración de las notificaciones están listos.',
        notificationDetails: details,
        payload: 'leivaapp://home',
      );
      return true;
    } catch (_) {
      message = 'No pudimos ejecutar la prueba local de notificaciones.';
      notifyListeners();
      return false;
    }
  }

  Future<void> refreshInbox({
    bool force = false,
    bool append = false,
    bool unreadOnly = false,
  }) async {
    final now = DateTime.now();
    if (!force &&
        !append &&
        _lastInboxRefresh != null &&
        now.difference(_lastInboxRefresh!) < const Duration(seconds: 120)) {
      return;
    }
    if (append && nextNotificationCursor == null) return;
    inboxLoading = true;
    inboxError = null;
    notifyListeners();
    try {
      final page = await gateway.notifications(
        cursor: append ? nextNotificationCursor : null,
        unreadOnly: unreadOnly,
      );
      notifications = append
          ? List.unmodifiable([...notifications, ...page.items])
          : List.unmodifiable(page.items);
      unreadCount = page.unreadCount;
      nextNotificationCursor = page.nextCursor;
      notificationRetentionDays = page.retentionDays;
      _lastInboxRefresh = now;
    } on ApiFailure catch (error) {
      inboxError = error.message;
    } catch (_) {
      inboxError = 'No pudimos actualizar la bandeja de avisos.';
    } finally {
      inboxLoading = false;
      notifyListeners();
    }
  }

  Future<void> markNotificationRead(AppNotification item) async {
    if (!item.isRead) await gateway.markRead(item.id);
    await refreshInbox(force: true);
  }

  Future<void> markAllNotificationsRead() async {
    await gateway.markAllRead();
    await refreshInbox(force: true);
  }

  Future<void> openNotification(AppNotification item) async {
    await markNotificationRead(item);
    final target = PushTarget.parse(item.deepLink);
    if (target != null) _emitTarget(target);
  }

  Future<bool> sendRealPushTest() async {
    final id = installation?.installationId;
    if (id == null) {
      message = 'Este teléfono todavía no está registrado para recibir FCM.';
      notifyListeners();
      return false;
    }
    try {
      await gateway.selfTest(id, newIdempotencyKey());
      await refreshInbox(force: true);
      return true;
    } on ApiFailure catch (error) {
      message = error.statusCode == 429
          ? 'Esperá un minuto antes de repetir la prueba real.'
          : error.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> updatePreferences({
    required bool enabled,
    required Set<String> categories,
  }) async {
    final token = _token;
    if (!canConfigure || token == null) return;
    selectedCategories = categories.intersection(status!.categories.toSet());
    state = PushClientState.loading;
    message = null;
    notifyListeners();
    try {
      await _register(
        token: token,
        permissionStatus: 'authorized',
        notificationsEnabled: enabled,
      );
    } on ApiFailure catch (error) {
      state = error.statusCode == 503
          ? PushClientState.serverNotConfigured
          : PushClientState.error;
      message = error.message;
      notifyListeners();
    }
  }

  Future<void> unregister() async {
    final id = _installationId ?? await _installationStore.readOrCreate();
    try {
      await gateway.unregister(id);
    } on ApiFailure catch (error) {
      if (error.statusCode != 404 && error.statusCode != 401) rethrow;
    } finally {
      await _cancelStreams();
      _started = false;
      installation = null;
      state = PushClientState.idle;
      notifyListeners();
    }
  }

  Future<void> _register({
    required String token,
    required String permissionStatus,
    required bool notificationsEnabled,
  }) async {
    final packageInfo = await PackageInfo.fromPlatform();
    final id = _installationId ?? await _installationStore.readOrCreate();
    installation = await gateway.upsert(
      id,
      PushInstallationDraft(
        token: token,
        deviceName: 'Leiva App Android',
        appVersion: '${packageInfo.version}+${packageInfo.buildNumber}',
        permissionStatus: permissionStatus,
        notificationsEnabled: notificationsEnabled,
        categories: selectedCategories.toList()..sort(),
      ),
    );
    state = installation!.notificationsEnabled
        ? PushClientState.registered
        : PushClientState.disabled;
    message = null;
    notifyListeners();
  }

  Future<bool> _initializeFirebase() async {
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _initializeLocalNotifications() async {
    const initialization = InitializationSettings(
      android: AndroidInitializationSettings('ic_launcher_foreground'),
    );
    await _localNotifications.initialize(
      settings: initialization,
      onDidReceiveNotificationResponse: (response) {
        final target = PushTarget.parse(response.payload);
        if (target != null) _emitTarget(target);
      },
    );
    const channel = AndroidNotificationChannel(
      pushAndroidChannelId,
      'Leiva Interna',
      description:
          'Avisos de reservas, estacionamiento y gestiones personales.',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
    final launch = await _localNotifications.getNotificationAppLaunchDetails();
    final payload = launch?.notificationResponse?.payload;
    final target = PushTarget.parse(payload);
    if (target != null) _emitTarget(target);
  }

  Future<void> _bindFirebaseStreams() async {
    await _cancelStreams();
    _tokenSubscription = _messaging.onTokenRefresh.listen((token) async {
      if (token.length < 32) return;
      _token = token;
      try {
        await _register(
          token: token,
          permissionStatus: 'authorized',
          notificationsEnabled: installation?.notificationsEnabled ?? true,
        );
      } catch (_) {
        // Se reintentará al abrir Ajustes o en el próximo inicio de sesión.
      }
    });
    _messageSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundMessage,
    );
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      _openMessage,
    );
  }

  Future<void> _showForegroundMessage(RemoteMessage remoteMessage) async {
    unawaited(refreshInbox(force: true));
    final notification = remoteMessage.notification;
    if (notification == null) return;
    final target = PushTarget.parse(remoteMessage.data['deep_link']);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        pushAndroidChannelId,
        'Leiva Interna',
        channelDescription:
            'Avisos de reservas, estacionamiento y gestiones personales.',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_launcher_foreground',
      ),
    );
    await _localNotifications.show(
      id:
          (remoteMessage.messageId?.hashCode ??
              DateTime.now().millisecondsSinceEpoch.remainder(2147483647)) &
          0x7fffffff,
      title: notification.title ?? 'Leiva Interna',
      body: notification.body ?? 'Tenés una nueva actualización.',
      notificationDetails: details,
      payload: target == null ? null : remoteMessage.data['deep_link'],
    );
  }

  void _openMessage(RemoteMessage message) {
    final target = PushTarget.parse(message.data['deep_link']);
    if (target != null) _emitTarget(target);
  }

  void _emitTarget(PushTarget target) {
    final handler = _navigationHandler;
    if (handler == null) {
      _pendingTarget = target;
    } else {
      handler(target);
    }
  }

  String _permissionName(AuthorizationStatus status) => switch (status) {
    AuthorizationStatus.authorized ||
    AuthorizationStatus.provisional => 'authorized',
    AuthorizationStatus.denied ||
    AuthorizationStatus.deniedPermanently => 'denied',
    AuthorizationStatus.notDetermined => 'not_determined',
  };

  Future<void> _cancelStreams() async {
    await _tokenSubscription?.cancel();
    await _messageSubscription?.cancel();
    await _openedSubscription?.cancel();
    _tokenSubscription = null;
    _messageSubscription = null;
    _openedSubscription = null;
  }

  @override
  void dispose() {
    unawaited(_cancelStreams());
    super.dispose();
  }
}
