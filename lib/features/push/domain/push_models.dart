class PushProviderStatus {
  const PushProviderStatus({
    required this.enabled,
    required this.configured,
    required this.provider,
    required this.androidChannelId,
  });

  factory PushProviderStatus.fromJson(Map<String, dynamic> json) =>
      PushProviderStatus(
        enabled: json['enabled'] as bool? ?? false,
        configured: json['configured'] as bool? ?? false,
        provider: json['provider'] as String? ?? 'fcm',
        androidChannelId:
            json['android_channel_id'] as String? ?? 'leiva_general',
      );

  final bool enabled;
  final bool configured;
  final String provider;
  final String androidChannelId;
}

class PushInstallation {
  const PushInstallation({
    required this.installationId,
    required this.platform,
    required this.deviceName,
    required this.permissionStatus,
    required this.notificationsEnabled,
    required this.categories,
    this.appVersion,
    this.lastRegisteredAt,
    this.lastSuccessAt,
    this.lastErrorCode,
    this.persistentEnrollment = false,
    this.credentialExpiresAt,
  });

  factory PushInstallation.fromJson(
    Map<String, dynamic> json,
  ) => PushInstallation(
    installationId: json['installation_id'] as String,
    platform: json['platform'] as String? ?? 'android',
    deviceName: json['device_name'] as String? ?? 'Leiva App Android',
    appVersion: json['app_version'] as String?,
    permissionStatus: json['permission_status'] as String? ?? 'not_determined',
    notificationsEnabled: json['notifications_enabled'] as bool? ?? false,
    categories: (json['categories'] as List? ?? const []).cast<String>(),
    lastRegisteredAt: DateTime.tryParse(
      json['last_registered_at'] as String? ?? '',
    ),
    lastSuccessAt: DateTime.tryParse(json['last_success_at'] as String? ?? ''),
    lastErrorCode: json['last_error_code'] as String?,
    persistentEnrollment: json['persistent_enrollment'] as bool? ?? false,
    credentialExpiresAt: DateTime.tryParse(
      json['credential_expires_at'] as String? ?? '',
    ),
  );

  final String installationId;
  final String platform;
  final String deviceName;
  final String? appVersion;
  final String permissionStatus;
  final bool notificationsEnabled;
  final List<String> categories;
  final DateTime? lastRegisteredAt;
  final DateTime? lastSuccessAt;
  final String? lastErrorCode;
  final bool persistentEnrollment;
  final DateTime? credentialExpiresAt;
}

class PersistentEnrollment {
  const PersistentEnrollment({
    required this.installation,
    required this.deviceCredential,
    required this.credentialScheme,
    required this.credentialExpiresAt,
  });

  factory PersistentEnrollment.fromJson(Map<String, dynamic> json) =>
      PersistentEnrollment(
        installation: PushInstallation.fromJson(
          json['installation'] as Map<String, dynamic>,
        ),
        deviceCredential: json['device_credential'] as String,
        credentialScheme: json['credential_scheme'] as String? ?? 'Device',
        credentialExpiresAt: DateTime.parse(
          json['credential_expires_at'] as String,
        ),
      );

  final PushInstallation installation;
  final String deviceCredential;
  final String credentialScheme;
  final DateTime credentialExpiresAt;
}

class DeviceEnrollmentStatus {
  const DeviceEnrollmentStatus({
    required this.installationId,
    required this.persistentEnrollment,
    required this.permissionStatus,
    required this.notificationsEnabled,
    required this.categories,
    required this.credentialExpiresAt,
    required this.lastRegisteredAt,
  });

  factory DeviceEnrollmentStatus.fromJson(Map<String, dynamic> json) =>
      DeviceEnrollmentStatus(
        installationId: json['installation_id'] as String,
        persistentEnrollment: json['persistent_enrollment'] as bool? ?? false,
        permissionStatus:
            json['permission_status'] as String? ?? 'not_determined',
        notificationsEnabled: json['notifications_enabled'] as bool? ?? false,
        categories: (json['categories'] as List? ?? const []).cast<String>(),
        credentialExpiresAt: DateTime.parse(
          json['credential_expires_at'] as String,
        ),
        lastRegisteredAt: DateTime.parse(json['last_registered_at'] as String),
      );

  final String installationId;
  final bool persistentEnrollment;
  final String permissionStatus;
  final bool notificationsEnabled;
  final List<String> categories;
  final DateTime credentialExpiresAt;
  final DateTime lastRegisteredAt;
}

class PushStatus {
  const PushStatus({
    required this.provider,
    required this.categories,
    required this.installations,
  });

  factory PushStatus.fromJson(Map<String, dynamic> json) => PushStatus(
    provider: PushProviderStatus.fromJson(
      json['provider'] as Map<String, dynamic>? ?? const {},
    ),
    categories: (json['categories'] as List? ?? const []).cast<String>(),
    installations: _pushMaps(json['installations'])
        .map(PushInstallation.fromJson)
        .toList(),
  );

  final PushProviderStatus provider;
  final List<String> categories;
  final List<PushInstallation> installations;
}

class PushInstallationDraft {
  const PushInstallationDraft({
    required this.token,
    required this.deviceName,
    required this.permissionStatus,
    required this.notificationsEnabled,
    required this.categories,
    this.appVersion,
  });

  final String token;
  final String deviceName;
  final String? appVersion;
  final String permissionStatus;
  final bool notificationsEnabled;
  final List<String> categories;

  Map<String, dynamic> toJson() => {
    'token': token,
    'platform': 'android',
    'device_name': deviceName,
    'app_version': appVersion,
    'permission_status': permissionStatus,
    'notifications_enabled': notificationsEnabled,
    'categories': categories,
  };
}

class DeviceTokenRefreshDraft {
  const DeviceTokenRefreshDraft({
    required this.token,
    required this.permissionStatus,
    required this.notificationsEnabled,
    required this.categories,
    this.appVersion,
  });

  final String token;
  final String? appVersion;
  final String permissionStatus;
  final bool notificationsEnabled;
  final List<String> categories;

  Map<String, dynamic> toJson() => {
    'token': token,
    'app_version': appVersion,
    'permission_status': permissionStatus,
    'notifications_enabled': notificationsEnabled,
    'categories': categories,
  };
}

List<Map<String, dynamic>> _pushMaps(dynamic value) =>
    (value as List? ?? const []).whereType<Map<String, dynamic>>().toList();

class AppNotification {
  const AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.priority,
    required this.isRead,
    required this.createdAt,
    this.resourceType,
    this.resourceId,
    this.deepLink,
    this.readAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: json['id'] as String,
        category: json['category'] as String? ?? 'general',
        title: json['title'] as String? ?? 'Leiva Interna',
        body: json['body'] as String? ?? '',
        priority: json['priority'] as String? ?? 'normal',
        resourceType: json['resource_type'] as String?,
        resourceId: json['resource_id'] as String?,
        deepLink: json['deep_link'] as String?,
        isRead: json['is_read'] as bool? ?? false,
        readAt: DateTime.tryParse(json['read_at'] as String? ?? '')?.toLocal(),
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      );

  final String id;
  final String category;
  final String title;
  final String body;
  final String priority;
  final String? resourceType;
  final String? resourceId;
  final String? deepLink;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;
}

class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.unreadCount,
    required this.retentionDays,
    required this.recommendedRefreshSeconds,
    this.nextCursor,
  });

  factory NotificationPage.fromJson(Map<String, dynamic> json) =>
      NotificationPage(
        items: _pushMaps(json['items']).map(AppNotification.fromJson).toList(),
        unreadCount: json['unread_count'] as int? ?? 0,
        nextCursor: json['next_cursor'] as String?,
        retentionDays: json['retention_days'] as int? ?? 180,
        recommendedRefreshSeconds:
            json['recommended_refresh_seconds'] as int? ?? 120,
      );

  final List<AppNotification> items;
  final int unreadCount;
  final String? nextCursor;
  final int retentionDays;
  final int recommendedRefreshSeconds;
}
