import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants/config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic> fields;
  final dynamic data;

  ApiException(this.message, [this.statusCode, this.fields = const {}, this.data]);

  bool get isUnauthorized => statusCode == 401;
  bool get isNetwork => statusCode == null;

  String? fieldError(String field) => fields[field]?.toString();

  @override
  String toString() => message;
}

class ApiCancelToken {
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;

  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }
}

class ApiClient {
  ApiClient({http.Client? client, this.defaultTimeout = const Duration(seconds: 20)})
      : _client = client ?? http.Client();

  final http.Client _client;
  final Duration defaultTimeout;

  String _baseUrl = AppConfig.defaultServerUrl;
  String? _token;
  void Function()? onUnauthorized;

  String get baseUrl => _baseUrl;
  String? get token => _token;

  void setBaseUrl(String url) {
    _baseUrl = normalizeBaseUrl(url);
  }

  void setToken(String? token) {
    _token = token == null || token.trim().isEmpty ? null : token.trim();
  }

  static String normalizeUrl(String url) => normalizeBaseUrl(url);

  static String normalizeBaseUrl(String url) {
    var cleaned = url.trim();
    if (!cleaned.startsWith('http://') && !cleaned.startsWith('https://')) {
      cleaned = 'http://$cleaned';
    }
    while (cleaned.endsWith('/')) {
      cleaned = cleaned.substring(0, cleaned.length - 1);
    }
    Uri parsed;
    try {
      parsed = Uri.parse(cleaned);
    } on FormatException {
      throw ApiException('عنوان السيرفر غير صالح.');
    }
    if ((parsed.scheme != 'http' && parsed.scheme != 'https') || parsed.host.isEmpty || parsed.hasQuery || parsed.hasFragment) {
      throw ApiException('عنوان السيرفر غير صالح.');
    }
    return cleaned;
  }

  Map<String, String> _headers({Map<String, String>? extra, String? idempotencyKey}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
      if (idempotencyKey != null && idempotencyKey.isNotEmpty) 'Idempotency-Key': idempotencyKey,
    };
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  Uri _uri(String endpoint, [Map<String, dynamic>? queryParams]) {
    final ep = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final uri = Uri.parse('$_baseUrl$ep');
    if (queryParams == null || queryParams.isEmpty) return uri;
    final pairs = <String>[];
    for (final entry in queryParams.entries) {
      final value = entry.value;
      if (value == null) continue;
      final values = value is Iterable ? value : [value];
      for (final item in values) {
        pairs.add('${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(item.toString())}');
      }
    }
    if (pairs.isEmpty) return uri;
    return uri.replace(query: [if (uri.query.isNotEmpty) uri.query, ...pairs].join('&'));
  }

  Future<dynamic> request(
    String method,
    String endpoint, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    String? idempotencyKey,
    Duration? timeout,
    int retries = 0,
    ApiCancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled ?? false) {
      throw ApiException('تم إلغاء الطلب.');
    }
    http.Request buildRequest() {
      final request = http.Request(method.toUpperCase(), _uri(endpoint, queryParams))
        ..headers.addAll(_headers(extra: headers, idempotencyKey: idempotencyKey));
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = body is String ? body : jsonEncode(body);
      }
      return request;
    }

    var attempt = 0;
    while (true) {
      if (cancelToken?.isCancelled ?? false) throw ApiException('تم إلغاء الطلب.');
      try {
        final response = await _send(buildRequest(), timeout ?? defaultTimeout, cancelToken);
        return _processResponse(response);
      } on ApiException {
        rethrow;
      } on TimeoutException {
        if (attempt >= retries) throw ApiException('انتهت مهلة الاتصال بالسيرفر.');
      } on SocketException {
        if (attempt >= retries) throw ApiException('تعذر الاتصال بالسيرفر. تحقق من العنوان أو الشبكة.');
      } on http.ClientException {
        if (attempt >= retries) throw ApiException('تعذر الاتصال بالسيرفر. تحقق من العنوان أو الشبكة.');
      } catch (error) {
        throw ApiException('حدث خطأ غير متوقع: $error');
      }
      attempt += 1;
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<http.Response> _send(http.BaseRequest request, Duration timeout, ApiCancelToken? cancelToken) async {
    final pending = _client.send(request).then(http.Response.fromStream);
    if (cancelToken == null) return pending.timeout(timeout);
    final result = Completer<http.Response>();
    pending.then((response) {
      if (!result.isCompleted) result.complete(response);
    }, onError: (Object error, StackTrace stackTrace) {
      if (!result.isCompleted) result.completeError(error, stackTrace);
    });
    cancelToken.whenCancelled.then((_) {
      if (!result.isCompleted) result.completeError(ApiException('تم إلغاء الطلب.'));
    });
    return result.future.timeout(timeout);
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    Duration? timeout,
    int retries = 1,
    ApiCancelToken? cancelToken,
  }) => request('GET', endpoint, queryParams: queryParams ?? queryParameters, headers: headers, timeout: timeout, retries: retries, cancelToken: cancelToken);

  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    String? idempotencyKey,
    Duration? timeout,
    ApiCancelToken? cancelToken,
  }) => request('POST', endpoint, body: body, queryParams: queryParams ?? queryParameters, headers: headers, idempotencyKey: idempotencyKey, timeout: timeout, cancelToken: cancelToken);

  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    String? idempotencyKey,
    Duration? timeout,
    ApiCancelToken? cancelToken,
  }) => request('PUT', endpoint, body: body, queryParams: queryParams ?? queryParameters, headers: headers, idempotencyKey: idempotencyKey, timeout: timeout, cancelToken: cancelToken);

  Future<dynamic> patch(
    String endpoint, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    String? idempotencyKey,
    Duration? timeout,
    ApiCancelToken? cancelToken,
  }) => request('PATCH', endpoint, body: body, queryParams: queryParams ?? queryParameters, headers: headers, idempotencyKey: idempotencyKey, timeout: timeout, cancelToken: cancelToken);

  Future<dynamic> delete(
    String endpoint, {
    dynamic body,
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
    String? idempotencyKey,
    Duration? timeout,
    ApiCancelToken? cancelToken,
  }) => request('DELETE', endpoint, body: body, queryParams: queryParams ?? queryParameters, headers: headers, idempotencyKey: idempotencyKey, timeout: timeout, cancelToken: cancelToken);

  Future<dynamic> multipart(
    String endpoint, {
    required Map<String, String> fields,
    List<http.MultipartFile> files = const [],
    String? idempotencyKey,
    Duration? timeout,
    ApiCancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled ?? false) throw ApiException('تم إلغاء الطلب.');
    final request = http.MultipartRequest('POST', _uri(endpoint))
      ..headers.addAll(_headers(idempotencyKey: idempotencyKey))
      ..fields.addAll(fields)
      ..files.addAll(files);
    try {
      final response = await _send(request, timeout ?? defaultTimeout, cancelToken);
      return _processResponse(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('انتهت مهلة الاتصال بالسيرفر.');
    } on SocketException {
      throw ApiException('تعذر الاتصال بالسيرفر. تحقق من العنوان أو الشبكة.');
    } on http.ClientException {
      throw ApiException('تعذر الاتصال بالسيرفر. تحقق من العنوان أو الشبكة.');
    } catch (error) {
      throw ApiException('حدث خطأ غير متوقع: $error');
    }
  }

  dynamic _processResponse(http.Response response) {
    dynamic jsonBody;
    try {
      final text = utf8.decode(response.bodyBytes);
      jsonBody = text.isEmpty ? null : jsonDecode(text);
    } catch (_) {
      jsonBody = null;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return jsonBody;

    var message = 'حدث خطأ في السيرفر (رمز ${response.statusCode})';
    Map<String, dynamic> fields = const {};
    if (jsonBody is Map) {
      if (jsonBody['error'] != null) message = jsonBody['error'].toString();
      else if (jsonBody['message'] != null) message = jsonBody['message'].toString();
      if (jsonBody['fields'] is Map) fields = Map<String, dynamic>.from(jsonBody['fields'] as Map);
    }
    if (response.statusCode == 401) onUnauthorized?.call();
    throw ApiException(message, response.statusCode, fields, jsonBody);
  }

  Future<bool> pingServer(String testUrl) async {
    try {
      final baseUrl = normalizeBaseUrl(testUrl);
      final response = await _client.get(Uri.parse('$baseUrl/api/v1/ping/')).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return false;
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      return body is Map && body['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  void close() => _client.close();
}
