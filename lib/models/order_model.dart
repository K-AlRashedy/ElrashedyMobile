import 'product_model.dart';

class CartItem {
  final ProductModel product;
  double quantity;
  String note;

  CartItem({
    required this.product,
    this.quantity = 1.0,
    this.note = '',
  });

  Map<String, dynamic> toApiPayload() {
    return {
      'product_id': product.id,
      'quantity': quantity,
      'note': note,
    };
  }
}

class OrderProductModel {
  final int id;
  final int productId;
  final String productName;
  final String unit;
  final double requested;
  final double sent;
  final String note;
  final bool isDone;

  OrderProductModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.unit,
    required this.requested,
    required this.sent,
    required this.note,
    required this.isDone,
  });

  factory OrderProductModel.fromJson(Map<String, dynamic> json) {
    return OrderProductModel(
      id: json['id'] as int? ?? 0,
      productId: json['product_id'] as int? ?? 0,
      productName: json['product_name'] as String? ?? '',
      unit: json['unit'] as String? ?? 'قطعة',
      requested: (json['requested'] as num?)?.toDouble() ?? 0.0,
      sent: (json['sent'] as num?)?.toDouble() ?? 0.0,
      note: json['note'] as String? ?? '',
      isDone: json['is_done'] as bool? ?? false,
    );
  }
}

class OrderModel {
  final int id;
  final String datetime;
  final int fromBranchId;
  final String fromBranchName;
  final int toBranchId;
  final String toBranchName;
  final String status;
  final String sendStatus;
  final String receiveStatus;
  final String revStatus;
  final String user;
  final int itemsCount;
  final List<OrderProductModel> items;

  OrderModel({
    required this.id,
    required this.datetime,
    required this.fromBranchId,
    required this.fromBranchName,
    required this.toBranchId,
    required this.toBranchName,
    required this.status,
    required this.sendStatus,
    required this.receiveStatus,
    this.revStatus = '',
    required this.user,
    required this.itemsCount,
    required this.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final fromMap = json['from_branch'] as Map<String, dynamic>? ?? {};
    final toMap = json['to_branch'] as Map<String, dynamic>? ?? {};
    final rawItems = json['items'] as List<dynamic>? ?? [];

    return OrderModel(
      id: json['id'] as int? ?? 0,
      datetime: json['datetime'] as String? ?? '',
      fromBranchId: fromMap['id'] as int? ?? 0,
      fromBranchName: fromMap['name'] as String? ?? '',
      toBranchId: toMap['id'] as int? ?? 0,
      toBranchName: toMap['name'] as String? ?? '',
      status: json['status'] as String? ?? 'approved',
      sendStatus: json['s_status'] as String? ?? json['status'] as String? ?? 'approved',
      receiveStatus: json['r_status'] as String? ?? json['r_status_legacy'] as String? ?? 'approved',
      revStatus: json['rev_status'] as String? ?? '',
      user: json['user'] as String? ?? '',
      itemsCount: json['items_count'] as int? ?? rawItems.length,
      items: rawItems
          .whereType<Map<String, dynamic>>()
          .map((i) => OrderProductModel.fromJson(i))
          .toList(),
    );
  }
}
