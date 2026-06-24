import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  static const String _envBaseUrl = String.fromEnvironment(
    'SAKINA_API_BASE_URL',
    defaultValue: 'http://localhost:28080/v1',
  );

  static const String prefsBaseUrlKey = 'sakina_api_base_url';

  static const String healthEndpoint = '/health';
  static const String classifyEndpoint = '/classify';
  static const String usersEndpoint = '/users';
  static const String syncBackupEndpoint = '/sync/backup';

  static const Duration timeout = Duration(seconds: 30);
  static const int retryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 1);

  /// Compile-time default (APK dart-define).
  static String get defaultBaseUrl => _envBaseUrl;

  /// Back-compat sync accessor (compile-time default only).
  static String get baseUrl => _envBaseUrl;

  static Future<String> resolveBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final override = prefs.getString(prefsBaseUrlKey)?.trim();
    if (override != null && override.isNotEmpty) {
      return override;
    }
    return _envBaseUrl;
  }

  static Future<void> setBaseUrlOverride(String? url) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      await prefs.remove(prefsBaseUrlKey);
      return;
    }
    await prefs.setString(prefsBaseUrlKey, trimmed);
  }

  /// Health URL without duplicate /v1.
  static String healthUrlFor(String baseUrl) {
    final trimmed = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    if (trimmed.endsWith('/v1')) {
      return '${trimmed.substring(0, trimmed.length - 3)}/health';
    }
    return '$trimmed/health';
  }
}
