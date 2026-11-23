class ProductModel {
  final int id;
  final String name;
  final String unit;
  final String category;
  final double price;
  final bool isSold;
  final String? image;

  ProductModel({
    required this.id,
    required this.name,
    required this.unit,
    required this.category,
    required this.price,
    required this.isSold,
    this.image,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      unit: json['unit'] as String? ?? 'قطعة',
      category: json['category'] as String? ?? 'عام',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      isSold: json['is_sold'] as bool? ?? false,
      image: json['image'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'unit': unit,
      'category': category,
      'price': price,
      'is_sold': isSold,
      'image': image,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
