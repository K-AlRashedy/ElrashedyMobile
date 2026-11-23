class BranchModel {
  final int id;
  final String name;
  final String type; // SHOP, FACTORY, etc.

  BranchModel({
    required this.id,
    required this.name,
    required this.type,
  });

  factory BranchModel.fromJson(Map<String, dynamic> json) {
    return BranchModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'SHOP',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BranchModel && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
