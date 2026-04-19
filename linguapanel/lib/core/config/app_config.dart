/// Application-wide configuration constants.
///
/// API_BASE_URL can be overridden at build time using:
/// ```
/// flutter run --dart-define=API_BASE_URL=https://your-api-url.com
/// ```
class AppConfig {
  AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  static String get translateImageEndpoint => '$apiBaseUrl/translate_image';
}
