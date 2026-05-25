class ApiConfig {
  static const String baseUrl = 'http://localhost:8080/v1';

  static const String healthEndpoint = '/health';
  static const String ragQueryEndpoint = '/rag/query';
  static const String classifyEndpoint = '/classify';
  static const String usersEndpoint = '/users';
  static const String syncBackupEndpoint = '/sync/backup';

  static const Duration timeout = Duration(seconds: 30);
  static const int retryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 1);
}
