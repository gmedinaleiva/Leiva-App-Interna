class AppConfig {
  AppConfig({Uri? apiBaseUri})
    : apiBaseUri = apiBaseUri ?? Uri.parse(_configuredApiBaseUrl) {
    if (this.apiBaseUri.scheme != 'https' ||
        this.apiBaseUri.host != 'monitor.leivahnos.com.ar' ||
        this.apiBaseUri.path != '/api/app/v1') {
      throw StateError('La URL configurada para la API no es válida.');
    }
  }

  static const _configuredApiBaseUrl = String.fromEnvironment(
    'APP_API_BASE_URL',
    defaultValue: 'https://monitor.leivahnos.com.ar/api/app/v1',
  );

  final Uri apiBaseUri;
}
