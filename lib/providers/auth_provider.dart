import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_storage.dart';
import '../models/user_model.dart';
import '../models/nav_item_model.dart';
import '../models/branch_model.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _api;
  final AppStorage _storage = AppStorage();

  UserModel? _user;
  String? _token;
  String _serverUrl = '';
  List<NavGroupModel> _navGroups = [];
  List<BranchModel> _userBranches = [];

  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider(this._api);

  UserModel? get user => _user;
  String? get token => _token;
  String get serverUrl => _serverUrl;
  List<NavGroupModel> get navGroups => _navGroups;
  List<BranchModel> get userBranches => _userBranches;
  bool get isAuthenticated => _token != null && _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<bool> tryAutoLogin() async {
    _isLoading = true;
    notifyListeners();

    try {
      final savedUrl = await _storage.getServerUrl();
      final savedToken = await _storage.getToken();

      if (savedUrl == null || savedUrl.isEmpty || savedToken == null || savedToken.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _serverUrl = savedUrl;
      _api.setBaseUrl(savedUrl);
      _api.setToken(savedToken);

      // Verify token & fetch fresh bootstrap info
      final data = await _api.get('/api/v1/bootstrap/');
      if (data is Map<String, dynamic>) {
        _user = UserModel.fromJson(data['user'] as Map<String, dynamic>);
        _token = savedToken;

        final rawNav = data['nav'] as List<dynamic>? ?? [];
        _navGroups = rawNav
            .whereType<Map<String, dynamic>>()
            .map((g) => NavGroupModel.fromJson(g))
            .toList();

        final rawBranches = data['user_branches'] as List<dynamic>? ?? [];
        _userBranches = rawBranches
            .whereType<Map<String, dynamic>>()
            .map((b) => BranchModel.fromJson(b))
            .toList();

        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (_) {
      // Auto-login failed, user will be prompted to login
    }

    _token = null;
    _user = null;
    _isLoading = false;
    notifyListeners();
    return false;
  }

  Future<bool> login({
    required String serverUrl,
    required String username,
    required String password,
    String? deviceName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _api.setBaseUrl(serverUrl);
      final payload = {
        'username': username.trim(),
        'password': password,
        'device_name': deviceName ?? 'تطبيق الرشيدي للموبايل',
      };

      final res = await _api.post('/api/v1/auth/login/', body: payload);

      if (res is Map<String, dynamic>) {
        final tokenStr = res['token'] as String;
        _token = tokenStr;
        _serverUrl = serverUrl;
        _api.setToken(tokenStr);

        _user = UserModel.fromJson(res['user'] as Map<String, dynamic>);

        final rawNav = res['nav'] as List<dynamic>? ?? [];
        _navGroups = rawNav
            .whereType<Map<String, dynamic>>()
            .map((g) => NavGroupModel.fromJson(g))
            .toList();

        final rawBranches = res['branches'] as List<dynamic>? ?? [];
        _userBranches = rawBranches
            .whereType<Map<String, dynamic>>()
            .map((b) => BranchModel.fromJson(b))
            .toList();

        // Save session locally
        await _storage.saveServerUrl(serverUrl);
        await _storage.saveToken(tokenStr);
        await _storage.saveLastUsername(username);

        _isLoading = false;
        notifyListeners();
        return true;
      }

      throw ApiException('استجابة غير متوقعة من السيرفر.');
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      if (_token != null) {
        await _api.post('/api/v1/auth/logout/');
      }
    } catch (_) {}

    _token = null;
    _user = null;
    _navGroups = [];
    _userBranches = [];
    _api.setToken(null);
    await _storage.clearToken();
    notifyListeners();
  }
}
