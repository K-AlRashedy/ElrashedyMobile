import 'dart:async';
import 'dart:convert';

import 'package:elrashedy_erp/core/network/api_client.dart';
import 'package:elrashedy_erp/core/storage/secure_storage.dart';
import 'package:elrashedy_erp/providers/auth_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  http.Response jsonResponse(Object? body, int status) => http.Response(
    jsonEncode(body),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  group('ApiClient', () {
    test('sends authenticated requests, repeated filters, and idempotency keys', () async {
      late http.Request captured;
      final client = ApiClient(client: MockClient((request) async {
        captured = request;
        return http.Response('{"ok":true}', 200);
      }))
        ..setBaseUrl('https://erp.example.com/')
        ..setToken('device-token');

      final result = await client.post('/api/v1/orders/create/', body: {
        'items': [1, 2],
      }, queryParams: {
        'branch_id': [3, 4],
      }, idempotencyKey: 'create-1');

      expect(result, {'ok': true});
      expect(captured.url.toString(), 'https://erp.example.com/api/v1/orders/create/?branch_id=3&branch_id=4');
      expect(captured.method, 'POST');
      expect(captured.headers['authorization'], 'Bearer device-token');
      expect(captured.headers['idempotency-key'], 'create-1');
      expect(jsonDecode(captured.body), {'items': [1, 2]});
    });

    test('preserves field validation errors and reports session expiry once', () async {
      var unauthorizedCalls = 0;
      final client = ApiClient(client: MockClient((request) async => jsonResponse({
        'error': 'بيانات غير صالحة',
        'fields': {'quantity': 'أدخل كمية صحيحة'},
      }, 400)));

      await expectLater(
        client.post('/api/v1/orders/create/', body: {'quantity': 0}),
        throwsA(isA<ApiException>()
            .having((error) => error.statusCode, 'status', 400)
            .having((error) => error.fieldError('quantity'), 'field', 'أدخل كمية صحيحة')),
      );

      client.onUnauthorized = () => unauthorizedCalls += 1;
      final expired = ApiClient(client: MockClient((request) async => jsonResponse({
        'error': 'انتهت الجلسة',
      }, 401)))..onUnauthorized = () => unauthorizedCalls += 1;
      await expectLater(expired.get('/api/v1/bootstrap/'), throwsA(isA<ApiException>().having((error) => error.isUnauthorized, 'unauthorized', true)));
      expect(unauthorizedCalls, 1);
    });

    test('retries safe reads but not mutations', () async {
      var reads = 0;
      final reader = ApiClient(client: MockClient((request) async {
        reads += 1;
        if (reads == 1) throw http.ClientException('offline');
        return http.Response('{"ok":true}', 200);
      }));
      expect(await reader.get('/api/v1/ping/'), {'ok': true});
      expect(reads, 2);

      var writes = 0;
      final writer = ApiClient(client: MockClient((request) async {
        writes += 1;
        throw http.ClientException('offline');
      }));
      await expectLater(writer.post('/api/v1/orders/create/', body: {}), throwsA(isA<ApiException>().having((error) => error.isNetwork, 'network', true)));
      expect(writes, 1);
    });

    test('cancels a pending read', () async {
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      final client = ApiClient(client: MockClient((request) {
        if (!started.isCompleted) started.complete();
        return pending.future;
      }));
      final token = ApiCancelToken();
      final request = client.get('/api/v1/orders/list/', retries: 0, cancelToken: token);
      await started.future;
      token.cancel();
      expect(token.isCancelled, isTrue);
      await token.whenCancelled;
      await expectLater(request, throwsA(isA<ApiException>().having((error) => error.message, 'message', 'تم إلغاء الطلب.')));
      pending.complete(jsonResponse({}, 200));
    });
  });

  group('AuthProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      FlutterSecureStorage.setMockInitialValues({});
    });

    test('persists a normalized session and clears an expired token', () async {
      final storage = AppStorage();
      final api = ApiClient(client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/login/')) {
          return jsonResponse({
            'token': 'new-token',
            'user': {'id': 1, 'username': 'manager'},
            'nav': [],
            'branches': [{'id': 2, 'name': 'الفرع', 'type': 'SHOP'}],
          }, 200);
        }
        return jsonResponse({'error': 'expired'}, 401);
      }));
      final auth = AuthProvider(api, storage: storage);
      api.onUnauthorized = auth.expireSession;

      expect(await auth.login(serverUrl: 'erp.example.com/', username: ' manager ', password: 'secret'), isTrue);
      expect(auth.isAuthenticated, isTrue);
      expect(auth.serverUrl, 'http://erp.example.com');
      expect(api.token, 'new-token');
      expect(await storage.getToken(), 'new-token');
      expect(await storage.getServerUrl(), 'http://erp.example.com');

      expect(await auth.tryAutoLogin(), isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(api.token, isNull);
      expect(await storage.getToken(), isNull);
    });

    test('keeps the saved token after a temporary network failure', () async {
      final storage = AppStorage();
      await storage.saveToken('saved-token');
      await storage.saveServerUrl('https://erp.example.com');
      final api = ApiClient(client: MockClient((request) async => throw http.ClientException('offline')));
      final auth = AuthProvider(api, storage: storage);

      expect(await auth.tryAutoLogin(), isFalse);
      expect(auth.isAuthenticated, isFalse);
      expect(api.token, isNull);
      expect(await storage.getToken(), 'saved-token');
    });
  });
}
