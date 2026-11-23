import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elrashedy_erp/core/network/api_client.dart';
import 'package:elrashedy_erp/models/product_model.dart';
import 'package:elrashedy_erp/models/nav_item_model.dart';
import 'package:elrashedy_erp/providers/order_provider.dart';

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

    test('NavGroupModel parses dynamic navigation', () {
      final json = {
        'id': 'orders',
        'title': 'الطلبات',
        'icon': 'fa-clipboard-list',
        'color': 'blue',
        'hint': 'الصرف والاستلام',
        'items': [
          {'title': 'إنشاء طلب', 'icon': 'fa-cart-plus', 'url': 'addorder', 'quick': true},
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

      // Add item
      provider.addOrIncrement(product, 2.5);
      expect(provider.cartCount, 1);
      expect(provider.totalQuantity, 2.5);

      // Increment by 5
      provider.addOrIncrement(product, 5.0);
      expect(provider.totalQuantity, 7.5);

      // Decrement by 1
      provider.decrementOrRemove(product.id, 1.0);
      expect(provider.totalQuantity, 6.5);

      // Clear cart
      provider.clearCart();
      expect(provider.cartCount, 0);
      expect(provider.totalQuantity, 0.0);
    });
  });
}
