import 'dart:async';
import 'dart:convert';

import 'package:elrashedy_erp/core/network/api_client.dart';
import 'package:elrashedy_erp/core/pagination.dart';
import 'package:elrashedy_erp/models/product_model.dart';
import 'package:elrashedy_erp/providers/order_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> pageResponse(List<Map<String, dynamic>> items, {int page = 1, int count = 1}) => {
  'results': items,
  'count': count,
  'page': page,
  'page_size': 1,
  'total_pages': count,
  'has_next': page < count,
  'has_previous': page > 1,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PageResult', () {
    test('parses modern and legacy paginated envelopes', () {
      final modern = PageResult<int>.fromResponse(pageResponse([
        {'id': 1},
      ], count: 3), 'products', (json) => json['id'] as int);
      expect(modern.items, [1]);
      expect(modern.count, 3);
      expect(modern.hasNext, isTrue);
      expect(modern.hasPrevious, isFalse);

      final legacy = PageResult<int>.fromResponse({
        'products': [
          {'id': 2},
        ],
      }, 'products', (json) => json['id'] as int);
      expect(legacy.items, [2]);
      expect(legacy.page, 1);
      expect(legacy.hasNext, isFalse);
    });
  });

  group('PaginationController', () {
    test('deduplicates load-more and retains items after a failed page', () async {
      final requests = <int>[];
      final secondPage = Completer<PageResult<int>>();
      late final PaginationController<int> controller;
      controller = PaginationController<int>((page, filters) async {
        requests.add(page);
        if (page == 1) {
          return PageResult(items: [1], count: 3, page: 1, pageSize: 1, totalPages: 3, hasNext: true, hasPrevious: false);
        }
        if (page == 2) return secondPage.future;
        throw StateError('offline');
      });
      addTearDown(controller.dispose);

      await controller.load();
      final pending = controller.loadMore();
      final duplicate = controller.loadMore();
      secondPage.completeError(StateError('offline'));
      await Future.wait([pending, duplicate]);

      expect(requests, [1, 2]);
      expect(controller.items, [1]);
      expect(controller.hasError, isTrue);
      expect(controller.isLoadingMore, isFalse);
    });

    test('ignores stale responses after replacing filters', () async {
      final oldPage = Completer<PageResult<int>>();
      late final PaginationController<int> controller;
      controller = PaginationController<int>((page, filters) {
        if (filters['status'] == 'old') return oldPage.future;
        return Future.value(const PageResult(items: [2], count: 1, page: 1, pageSize: 1, totalPages: 1, hasNext: false, hasPrevious: false));
      });
      addTearDown(controller.dispose);

      final oldRequest = controller.replaceFilters({'status': 'old'});
      await controller.replaceFilters({'status': 'new'});
      oldPage.complete(const PageResult(items: [1], count: 1, page: 1, pageSize: 1, totalPages: 1, hasNext: false, hasPrevious: false));
      await oldRequest;

      expect(controller.items, [2]);
      expect(controller.filters, {'status': 'new'});
      expect(controller.error, isNull);
    });
  });

  group('OrderProvider API contracts', () {
    test('uses canonical branch payloads and refreshes orders after creation', () async {
      final writes = <http.Request>[];
      final queries = <Uri>[];
      final api = ApiClient(client: MockClient((request) async {
        if (request.url.path == '/api/v1/bootstrap/') {
          return http.Response(jsonEncode({
            'all_branches': [
              {'id': 1, 'name': 'الفرع الطالب', 'type': 'SHOP'},
              {'id': 2, 'name': 'المصنع', 'type': 'FACTORY'},
            ],
            'user_branches': [
              {'id': 1, 'name': 'الفرع الطالب', 'type': 'SHOP'},
            ],
          }), 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/v1/orders/top-products/') {
          return http.Response('{"products":[]}', 200, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/v1/orders/create/') {
          writes.add(request);
          return http.Response('{"ok":true,"id":9}', 201, headers: {'content-type': 'application/json'});
        }
        if (request.url.path == '/api/v1/orders/list/') {
          queries.add(request.url);
          return http.Response(jsonEncode(pageResponse([])), 200, headers: {'content-type': 'application/json'});
        }
        throw StateError('Unexpected request: ${request.url}');
      }));
      final provider = OrderProvider(api);
      addTearDown(provider.dispose);
      await provider.loadBootstrapBranches();
      provider.setOrderType('transfer');
      provider.addOrIncrement(ProductModel(id: 5, name: 'صنف', unit: 'كيلو', category: 'عام', price: 10, isSold: true), 2.5);

      expect(await provider.submitOrder(), isTrue);
      expect(jsonDecode(writes.single.body), {
        'from_branch_id': 1,
        'to_branch_id': 2,
        'type': 'transfer',
        'general_note': '',
        'items': [
          {'product_id': 5, 'quantity': 2.5, 'note': ''},
        ],
      });
      expect(writes.single.headers['idempotency-key'], isNotEmpty);
      expect(queries.single.queryParameters['direction'], 'all');
      expect(provider.cart, isEmpty);
      expect(provider.ordersPagination.hasLoaded, isTrue);
    });

    test('maps incoming status filters to the receive-side API contract', () async {
      late Uri requested;
      final api = ApiClient(client: MockClient((request) async {
        requested = request.url;
        return http.Response(jsonEncode(pageResponse([])), 200, headers: {'content-type': 'application/json'});
      }));
      final provider = OrderProvider(api);
      addTearDown(provider.dispose);

      await provider.loadOrdersList(direction: 'incoming', status: 'locked', includeLocked: true);
      expect(requested.queryParameters['direction'], 'incoming');
      expect(requested.queryParameters['status'], 'locked');
      expect(requested.queryParameters['include_locked'], 'true');
    });
  });
}
