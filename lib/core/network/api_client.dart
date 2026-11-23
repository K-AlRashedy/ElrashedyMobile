import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiClient {
  String _baseUrl = AppConfig.defaultServerUrl;
  String? _token;

  String get baseUrl => _baseUrl;
  String? get token => _token;

  void setBaseUrl(String url) {
    var cleaned = url.trim();
    if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
      cleaned = 'http://$cleaned';
    }
    while (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    _baseUrl = cleaned;
  }

  void setToken(String? token) {
    _token = token;
  }

  Map<String, String> _headers({Map<String, String>? extra}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_token';
    }
    if (extra != null) {
      headers.addAll(extra);
    }
    return headers;
  }

  Uri _uri(String endpoint, [Map<String, dynamic>? queryParams]) {
    final ep = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final fullUrl = '$_baseUrl$ep';
    final uri = Uri.parse(fullUrl);
    if (queryParams != null && queryParams.isNotEmpty) {
      final stringParams = queryParams.map((k, v) => MapEntry(k, v.toString()));
      return uri.replace(queryParameters: stringParams);
    }
    return uri;
  }

  Future<dynamic> get(String endpoint, {Map<String, dynamic>? queryParams}) async {
    try {
      final uri = _uri(endpoint, queryParams);
      final response = await http
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 15));
      return _processResponse(response);
    } on SocketException {
      throw ApiException('تعذر الاتصال بالسيرفر. تحقق من العنوان أو الشبكة.');
    } on TimeoutException {
      throw ApiException('انتهت مهلة الاتصال بالسيرفر.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('حدث خطأ غير متوقع: $e');
    }
  }

  Future<dynamic> post(String endpoint, {dynamic body}) async {
    try {
      final uri = _uri(endpoint);
      final response = await http
          .post(
            uri,
            headers: _headers(),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(const Duration(seconds: 20));
      return _processResponse(response);
    } on SocketException {
      throw ApiException('تعذر الاتصال بالسيرفر. تحقق من العنوان أو الشبكة.');
    } on TimeoutException {
      throw ApiException('انتهت مهلة الاتصال بالسيرفر.');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('حدث خطأ غير متوقع: $e');
    }
  }

  dynamic _processResponse(http.Response response) {
    final statusCode = response.statusCode;
    dynamic jsonBody;

    try {
      jsonBody = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      jsonBody = null;
    }

    if (statusCode >= 200 && statusCode < 300) {
      return jsonBody;
    }

    String errorMsg = 'حدث خطأ في السيرفر (رمز $statusCode)';
    if (jsonBody is Map<String, dynamic>) {
      if (jsonBody.containsKey('error')) {
        errorMsg = jsonBody['error'].toString();
      } else if (jsonBody.containsKey('message')) {
        errorMsg = jsonBody['message'].toString();
      }
    }

    throw ApiException(errorMsg, statusCode);
  }

  Future<bool> pingServer(String testUrl) async {
    var cleaned = testUrl.trim();
    if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
      cleaned = 'http://$cleaned';
    }
    while (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }

    try {
      final uri = Uri.parse('$cleaned/api/v1/ping/');
      final res = await http.get(uri).timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = jsonDecode(utf8.decode(res.bodyBytes));
        return body is Map && body['ok'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
