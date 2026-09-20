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

List<Map<String, dynamic>> _pushMaps(dynamic value) =>
    (value as List? ?? const []).whereType<Map<String, dynamic>>().toList();
