class ApiConfig {
  /// Public API base used by release builds.
  ///
  /// Override for local/staging builds with:
  /// `--dart-define=SAKINA_API_BASE_URL=http://10.0.2.2:8080`
  static const String baseUrl = String.fromEnvironment(
    'SAKINA_API_BASE_URL',
    defaultValue: 'https://api.sakinaapp.com',
  );
  static const String apiToken = String.fromEnvironment('SAKINA_API_TOKEN');

  static const String healthEndpoint = '/health';
  static const String ragQueryEndpoint = '/rag/query';
  static const String classifyEndpoint = '/classify';
  static const String usersEndpoint = '/users';
  static const String syncBackupEndpoint = '/sync/backup';

  static const Duration timeout = Duration(seconds: 30);
  static const int retryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 1);
}
