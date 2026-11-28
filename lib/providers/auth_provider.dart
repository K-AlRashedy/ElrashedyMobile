import 'dart:async';

import 'package:flutter/material.dart';

import '../core/network/api_client.dart';
import '../core/storage/secure_storage.dart';
import '../models/branch_model.dart';
import '../models/nav_item_model.dart';
import '../models/user_model.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider(this._api, {AppStorage? storage}) : _storage = storage ?? AppStorage();

  final ApiClient _api;
  final AppStorage _storage;

  UserModel? _user;
  String? _token;
  String _serverUrl = '';
  List<NavGroupModel> _navGroups = [];
  List<BranchModel> _userBranches = [];
  List<BranchModel> _allBranches = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _autoLoginNetworkError = false;

  UserModel? get user => _user;
  String? get token => _token;
  String get serverUrl => _serverUrl;
  List<NavGroupModel> get navGroups => _navGroups;
  List<BranchModel> get userBranches => _userBranches;
  List<BranchModel> get allBranches => _allBranches.isNotEmpty ? _allBranches : _userBranches;
  bool get isAuthenticated => _token != null && _user != null;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get autoLoginNetworkError => _autoLoginNetworkError;

  static bool _isPosNavItem(NavItemModel item) {
    final url = (item.url ?? '').trim();
    final href = (item.href ?? '').trim();
    return url == 'pos' ||
        href == '/pos/' ||
        href == '/pos' ||
        href == '/factory/pos/' ||
        href == '/factory/pos' ||
        href.contains('/pos/download');
  }

  static List<NavGroupModel> filterMobileNavGroups(List<NavGroupModel> groups) {
    final filtered = <NavGroupModel>[];
    for (final group in groups) {
      final items = group.items.where((item) => !_isPosNavItem(item)).toList();
      if (items.isEmpty) continue;
      final removedPos = items.length != group.items.length;
      filtered.add(NavGroupModel(
        id: group.id,
        title: (removedPos && group.id == 'sales') ? 'المبيعات والتوصيل' : group.title,
        icon: group.icon,
        color: group.color,
        hint: (removedPos && group.id == 'sales') ? 'أوامر البيع ومناطق وعملاء التوصيل' : group.hint,
        items: items,
      ));
    }
    return filtered;
  }

  void _applySession(Map<String, dynamic> data, String token) {
    final userData = data['user'];
    if (userData is! Map<String, dynamic>) throw ApiException('بيانات المستخدم غير صالحة.');
    _token = token;
    _user = UserModel.fromJson(userData);
    _api.setToken(token);
    final rawNav = data['nav'] as List<dynamic>? ?? [];
    _navGroups = filterMobileNavGroups(
      rawNav.whereType<Map<String, dynamic>>().map(NavGroupModel.fromJson).toList(),
    );
    final rawBranches = data['user_branches'] as List<dynamic>? ?? data['branches'] as List<dynamic>? ?? [];
    _userBranches = rawBranches.whereType<Map<String, dynamic>>().map(BranchModel.fromJson).toList();
    final rawAll = data['all_branches'] as List<dynamic>? ?? [];
    if (rawAll.isNotEmpty) {
      _allBranches = rawAll.whereType<Map<String, dynamic>>().map(BranchModel.fromJson).toList();
    }
  }

  void _clearMemory() {
    _token = null;
    _user = null;
    _navGroups = [];
    _userBranches = [];
    _allBranches = [];
    _api.setToken(null);
  }

  void expireSession() {
    _clearMemory();
    _errorMessage = 'انتهت جلسة العمل. يرجى تسجيل الدخول مجدداً.';
    unawaited(_storage.clearToken());
    notifyListeners();
  }

  Future<bool> tryAutoLogin() async {
    _isLoading = true;
    _errorMessage = null;
    _autoLoginNetworkError = false;
    notifyListeners();
    try {
      final savedUrl = await _storage.getServerUrl();
      final savedToken = await _storage.getToken();
      if (savedToken == null || savedToken.trim().isEmpty) {
        _clearMemory();
        return false;
      }
      _serverUrl = savedUrl;
      _api.setBaseUrl(savedUrl);
      _api.setToken(savedToken);
      final data = await _api.get('/api/v1/bootstrap/');
      if (data is! Map<String, dynamic>) throw ApiException('استجابة غير متوقعة من السيرفر.');
      _applySession(data, savedToken);
      return true;
    } on ApiException catch (error) {
      _clearMemory();
      if (error.isUnauthorized) {
        await _storage.clearToken();
      } else {
        _autoLoginNetworkError = true;
        _errorMessage = error.message;
      }
      return false;
    } catch (e) {
      _clearMemory();
      _autoLoginNetworkError = true;
      _errorMessage = 'تعذر الاتصال بالسيرفر حالياً.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> refreshSession() async {
    final token = _token;
    if (token == null) return false;
    try {
      final data = await _api.get('/api/v1/bootstrap/');
      if (data is! Map<String, dynamic>) return false;
      _applySession(data, token);
      notifyListeners();
      return true;
    } on ApiException catch (error) {
      if (error.isUnauthorized) expireSession();
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> login({
    required String serverUrl,
    required String username,
    required String password,
    String? deviceName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _autoLoginNetworkError = false;
    notifyListeners();
    try {
      _api.setToken(null);
      _api.setBaseUrl(serverUrl);
      final response = await _api.post('/api/v1/auth/login/', body: {
        'username': username.trim(),
        'password': password,
        'device_name': deviceName ?? 'تطبيق الرشيدي للموبايل',
      });
      if (response is! Map<String, dynamic>) throw ApiException('استجابة غير متوقعة من السيرفر.');
      final token = response['token'];
      if (token is! String || token.trim().isEmpty) throw ApiException('رمز الجلسة غير صالح.');
      final normalizedUrl = _api.baseUrl;
      await _storage.saveServerUrl(normalizedUrl);
      await _storage.saveToken(token);
      await _storage.saveLastUsername(username.trim());
      _serverUrl = normalizedUrl;
      _applySession(response, token);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (error) {
      _api.setToken(null);
      _errorMessage = error.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> setServerUrl(String url, {bool resetSession = false}) async {
    final normalized = ApiClient.normalizeUrl(url);
    _serverUrl = normalized;
    _api.setBaseUrl(normalized);
    await _storage.saveServerUrl(normalized);
    if (resetSession) {
      _clearMemory();
      await _storage.clearToken();
    }
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      if (_token != null) await _api.post('/api/v1/auth/logout/');
    } catch (_) {}
    _clearMemory();
    _errorMessage = null;
    _autoLoginNetworkError = false;
    await _storage.clearToken();
    notifyListeners();
  }
}
