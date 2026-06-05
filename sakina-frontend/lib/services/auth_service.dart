import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import 'api_service.dart';

class AuthSession {
  const AuthSession({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
    required this.email,
  });

  final String userId;
  final String accessToken;
  final String refreshToken;
  final String email;
}

class AuthService {
  AuthService({ApiService? api, FlutterSecureStorage? secureStorage})
      : _api = api ?? ApiService(baseUrl: ApiConfig.baseUrl),
        _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const _userIdKey = 'sakina_user_id';
  static const _tokenKey = 'sakina_access_token';
  static const _refreshTokenKey = 'sakina_refresh_token';
  static const _emailKey = 'sakina_email';

  final ApiService _api;
  final FlutterSecureStorage _secureStorage;

  Future<AuthSession?> currentSession() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString(_userIdKey);
    final token = await _secureStorage.read(key: _tokenKey);
    final refreshToken = await _secureStorage.read(key: _refreshTokenKey);
    final email = prefs.getString(_emailKey);
    if (userId == null || token == null || refreshToken == null || email == null) {
      return null;
    }
    _api.setAuthToken(token);
    try {
      final current = await _api.currentUser();
      return AuthSession(
        userId: current.userId,
        accessToken: token,
        refreshToken: refreshToken,
        email: current.email.isEmpty ? email : current.email,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        try {
          final refreshed = await _api.refreshWithToken(
            refreshToken: refreshToken,
          );
          return _persist(refreshed, refreshed.email ?? email);
        } catch (_) {
          await clear();
          return null;
        }
      }
      rethrow;
    }
  }

  Future<AuthSession> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final response = await _api.registerWithPassword(
      email: email,
      password: password,
      name: name,
    );
    return _persist(response, email);
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.loginWithPassword(
      email: email,
      password: password,
    );
    return _persist(response, email);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_emailKey);
    await _secureStorage.delete(key: _tokenKey);
    await _secureStorage.delete(key: _refreshTokenKey);
  }

  Future<void> logout() async {
    final token = await _secureStorage.read(key: _tokenKey);
    if (token != null && token.isNotEmpty) {
      _api.setAuthToken(token);
      await _api.logout();
    }
    await clear();
  }

  Future<AuthSession> _persist(
      PasswordAuthResponse response, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, response.userId);
    await prefs.setString(_emailKey, response.email ?? email);
    await _secureStorage.write(key: _tokenKey, value: response.accessToken);
    await _secureStorage.write(
      key: _refreshTokenKey,
      value: response.refreshToken,
    );
    _api.setAuthToken(response.accessToken);
    return AuthSession(
      userId: response.userId,
      accessToken: response.accessToken,
      refreshToken: response.refreshToken,
      email: response.email ?? email,
    );
  }

  void close() => _api.close();
}
