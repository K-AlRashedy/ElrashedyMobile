import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/config.dart';

class AppStorage {
  static const _keyToken = 'auth_token';
  static const _keyServerUrl = 'server_url';
  static const _keyLastUsername = 'last_username';

  final FlutterSecureStorage _secure = const FlutterSecureStorage();

  Future<void> saveToken(String token) async {
    await _secure.write(key: _keyToken, value: token);
  }

  Future<String?> getToken() async {
    return await _secure.read(key: _keyToken);
  }

  Future<void> clearToken() async {
    await _secure.delete(key: _keyToken);
  }

  Future<void> saveServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerUrl, url);
  }

  Future<String> getServerUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_keyServerUrl);
    if (saved != null && saved.trim().isNotEmpty) {
      return saved.trim();
    }
    return AppConfig.defaultServerUrl;
  }

  Future<void> saveLastUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastUsername, username);
  }

  Future<String?> getLastUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastUsername);
  }

  Future<void> clearAll() async {
    await _secure.deleteAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
  }
}
