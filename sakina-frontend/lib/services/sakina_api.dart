import '../config/api_config.dart';
import 'api_service.dart';
import 'auth_service.dart';

/// Factory for API clients using runtime base URL resolution.
class SakinaApi {
  SakinaApi._();

  static Future<ApiService> create({AuthSession? session}) async {
    final baseUrl = await ApiConfig.resolveBaseUrl();
    final api = ApiService(baseUrl: baseUrl);
    if (session != null) {
      api.setAuthToken(session.accessToken);
    }
    return api;
  }
}
