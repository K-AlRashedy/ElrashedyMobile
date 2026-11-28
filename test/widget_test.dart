import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elrashedy_erp/core/network/api_client.dart';
import 'package:elrashedy_erp/models/order_model.dart';
import 'package:elrashedy_erp/models/product_model.dart';
import 'package:elrashedy_erp/models/nav_item_model.dart';
import 'package:elrashedy_erp/providers/order_provider.dart';
import 'package:elrashedy_erp/screens/admin/admin_users_screen.dart';
import 'package:elrashedy_erp/widgets/numeric_keypad_sheet.dart';

void main() {
  group('Models & Cart Tests', () {
    test('ProductModel parses JSON correctly', () {
      final json = {
        'id': 101,
        'name': 'صدور دجاج متبلة',
        'unit': 'كيلو',
        'category': 'دواجن',
        'price': 180.0,
        'is_sold': true,
      };

      final p = ProductModel.fromJson(json);
      expect(p.id, 101);
      expect(p.name, 'صدور دجاج متبلة');
      expect(p.unit, 'كيلو');
      expect(p.price, 180.0);
    });

    test('OrderModel parses revStatus accurately', () {
      final order = OrderModel.fromJson({
        'id': 77,
        'datetime': '2026-11-26T10:00:00Z',
        'from_branch': {'id': 1, 'name': 'المصنع'},
        'to_branch': {'id': 2, 'name': 'الفرع الرئيسي'},
        'status': 'confirmed',
        'send_status': 'disbursed',
        'receive_status': 'pending',
        'rev_status': 'notLocked',
        'user': 'admin',
        'items_count': 1,
        'items': const [],
      });

      expect(order.id, 77);
      expect(order.revStatus, 'notLocked');
    });

    test('NavGroupModel parses dynamic navigation', () {
      final json = {
        'id': 'orders',
        'title': 'الطلبات',
        'icon': 'fa-clipboard-list',
        'color': 'blue',
        'hint': 'الصرف والاستلام',
        'items': [
          {
            'title': 'إنشاء طلب',
            'icon': 'fa-cart-plus',
            'url': 'addorder',
            'quick': true,
          },
        ],
      };

      final g = NavGroupModel.fromJson(json);
      expect(g.id, 'orders');
      expect(g.items.length, 1);
      expect(g.items.first.title, 'إنشاء طلب');
      expect(g.items.first.iconData, Icons.add_shopping_cart_rounded);
    });

    test('OrderProvider fast cart operations test', () {
      final api = ApiClient();
      final provider = OrderProvider(api);

      final product = ProductModel(
        id: 1,
        name: 'لحم بقري مفروم',
        unit: 'كيلو',
        category: 'لحوم',
        price: 320.0,
        isSold: true,
      );

      provider.addOrIncrement(product, 2.5);
      expect(provider.cartCount, 1);
      expect(provider.totalQuantity, 2.5);

      provider.addOrIncrement(product, 5.0);
      expect(provider.totalQuantity, 7.5);

      provider.decrementOrRemove(product.id, 1.0);
      expect(provider.totalQuantity, 6.5);

      provider.clearCart();
      expect(provider.cartCount, 0);
      expect(provider.totalQuantity, 0.0);
    });
  });

  group('In-App Numeric Keypad Tests', () {
    test('formatNumber strips trailing zeros cleanly', () {
      expect(AppNumericKeypadSheet.formatNumber(12.0), '12');
      expect(AppNumericKeypadSheet.formatNumber(12.5), '12.5');
      expect(AppNumericKeypadSheet.formatNumber(3.75), '3.75');
    });

    testWidgets('AppNumericField opens in-app keypad instead of OS keyboard',
        (WidgetTester tester) async {
      final controller = TextEditingController(text: '10');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: AppNumericField(
                controller: controller,
                label: 'الكمية',
                unit: 'كيلو',
                allowDecimal: true,
              ),
            ),
          ),
        ),
      );

      expect(find.byType(EditableText), findsNothing);

      await tester.tap(find.byType(AppNumericField));
      await tester.pumpAndSettle();

      // Enter 25.5 on the in-app keypad (first press replaces initial '10').
      for (final key in ['2', '5', '.', '5']) {
        await tester.tap(find.widgetWithText(InkWell, key));
        await tester.pump();
      }

      await tester.tap(find.text('تأكيد'));
      await tester.pumpAndSettle();

      expect(controller.text, '25.5');
      controller.dispose();
    });

    testWidgets('AppNumericField string mode preserves leading zeros',
        (WidgetTester tester) async {
      final phoneCtrl = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: AppNumericField(
                controller: phoneCtrl,
                label: 'رقم الهاتف',
                isStringMode: true,
                allowDecimal: false,
                maxLength: 15,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AppNumericField));
      await tester.pumpAndSettle();

      for (final digit in ['0', '1', '0', '9', '8']) {
        await tester.tap(find.widgetWithText(InkWell, digit));
        await tester.pump();
      }
      await tester.tap(find.text('تأكيد'));
      await tester.pumpAndSettle();

      expect(phoneCtrl.text, '01098');
      phoneCtrl.dispose();
    });
  });

  group('Admin Permission Mapping Tests', () {
    test('resolvePermissionIdsFromCodenames prefers factory app & deduplicates', () {
      final catalog = <Map<String, dynamic>>[
        {'id': 1, 'app_label': 'auth', 'codename': 'view_user'},
        {'id': 42, 'app_label': 'factory', 'codename': 'view_user'},
        {'id': 55, 'app_label': 'factory', 'codename': 'change_user'},
        {'id': 77, 'app_label': 'pos', 'codename': 'add_selling_orders'},
      ];

      final resolved = resolvePermissionIdsFromCodenames(
        ['view_user', 'change_user', 'add_selling_orders', 'view_user', 'missing_code'],
        catalog,
      );

      expect(resolved, [42, 55, 77]);
    });
  });
}
