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
    defaultValue: 'http://10.0.2.2:8080',
  );

  // Job-based endpoints
  static String get jobImageEndpoint => '$apiBaseUrl/jobs/image';
  static String get jobChapterEndpoint => '$apiBaseUrl/jobs/chapter';
  static String jobStatusEndpoint(String jobId) => '$apiBaseUrl/jobs/$jobId/status';
  static String jobPageEndpoint(String jobId, int page) => '$apiBaseUrl/jobs/$jobId/pages/$page';
  static String jobDownloadEndpoint(String jobId) => '$apiBaseUrl/jobs/$jobId/download';
}
