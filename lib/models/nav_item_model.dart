import 'package:flutter/material.dart';

class NavGroupModel {
  final String id;
  final String title;
  final String icon;
  final String color;
  final String hint;
  final List<NavItemModel> items;

  NavGroupModel({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.hint,
    required this.items,
  });

  factory NavGroupModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    return NavGroupModel(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      icon: json['icon'] as String? ?? 'fa-circle',
      color: json['color'] as String? ?? 'green',
      hint: json['hint'] as String? ?? '',
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map((item) => NavItemModel.fromJson(item))
          .toList(),
    );
  }

  IconData get iconData => _resolveFaIcon(icon);
  Color get resolvedColor => _resolveColor(color);
}

class NavItemModel {
  final String title;
  final String icon;
  final String? url;
  final String? href;
  final bool quick;

  NavItemModel({
    required this.title,
    required this.icon,
    this.url,
    this.href,
    this.quick = false,
  });

  factory NavItemModel.fromJson(Map<String, dynamic> json) {
    return NavItemModel(
      title: json['title'] as String? ?? '',
      icon: json['icon'] as String? ?? 'fa-circle',
      url: json['url'] as String?,
      href: json['href'] as String?,
      quick: json['quick'] as bool? ?? false,
    );
  }

  IconData get iconData => _resolveFaIcon(icon);
}

IconData _resolveFaIcon(String faName) {
  final clean = faName.replaceAll('fa-solid ', '').replaceAll('fa-', '');
  switch (clean) {
    case 'cash-register':
      return Icons.point_of_sale_rounded;
    case 'vault':
      return Icons.account_balance_wallet_rounded;
    case 'clipboard-list':
    case 'rectangle-list':
      return Icons.assignment_rounded;
    case 'clipboard-check':
      return Icons.fact_check_rounded;
    case 'cart-plus':
      return Icons.add_shopping_cart_rounded;
    case 'truck-arrow-right':
      return Icons.local_shipping_rounded;
    case 'layer-group':
      return Icons.category_rounded;
    case 'boxes-stacked':
    case 'boxes-packing':
      return Icons.inventory_2_rounded;
    case 'users-gear':
    case 'users':
      return Icons.group_rounded;
    case 'cart-flatbed':
      return Icons.shopping_bag_rounded;
    case 'money-bill':
    case 'money-bills':
    case 'money-bill-transfer':
    case 'money-bill-wave':
      return Icons.payments_rounded;
    case 'hand-holding-dollar':
      return Icons.price_check_rounded;
    case 'receipt':
      return Icons.receipt_long_rounded;
    case 'chart-simple':
    case 'chart-line':
      return Icons.analytics_rounded;
    case 'gear':
      return Icons.settings_rounded;
    case 'calculator':
      return Icons.calculate_rounded;
    case 'gauge-high':
      return Icons.speed_rounded;
    case 'user-clock':
      return Icons.access_time_rounded;
    case 'calendar-day':
      return Icons.event_available_rounded;
    case 'industry':
      return Icons.precision_manufacturing_rounded;
    case 'shop':
      return Icons.store_rounded;
    case 'arrow-up-from-bracket':
      return Icons.outbox_rounded;
    case 'arrow-right-to-bracket':
      return Icons.move_to_inbox_rounded;
    default:
      return Icons.dashboard_customize_rounded;
  }
}

Color _resolveColor(String colorName) {
  switch (colorName.toLowerCase()) {
    case 'red':
      return const Color(0xFFDC2626);
    case 'green':
    case 'emerald':
      return const Color(0xFF16A34A);
    case 'blue':
      return const Color(0xFF2563EB);
    case 'amber':
      return const Color(0xFFD97706);
    case 'orange':
      return const Color(0xFFEA580C);
    case 'violet':
    case 'purple':
      return const Color(0xFF7C3AED);
    case 'indigo':
      return const Color(0xFF4F46E5);
    case 'rose':
      return const Color(0xFFE11D48);
    case 'teal':
      return const Color(0xFF0D9488);
    default:
      return const Color(0xFF4A9323);
  }
}
