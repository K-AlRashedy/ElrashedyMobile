class UserModel {
  final int id;
  final String username;
  final String displayName;
  final bool isSuperuser;
  final int? employeeId;
  final int? branchId;
  final String branchName;

  String get name => displayName.isNotEmpty ? displayName : username;

  UserModel({
    required this.id,
    required this.username,
    required this.displayName,
    required this.isSuperuser,
    this.employeeId,
    this.branchId,
    required this.branchName,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int? ?? 0,
      username: json['username'] as String? ?? '',
      displayName: json['display_name'] as String? ?? json['username'] as String? ?? '',
      isSuperuser: json['is_superuser'] as bool? ?? false,
      employeeId: json['employee_id'] as int?,
      branchId: json['branch_id'] as int?,
      branchName: json['branch_name'] as String? ?? 'المركز الرئيسي',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'display_name': displayName,
      'is_superuser': isSuperuser,
      'employee_id': employeeId,
      'branch_id': branchId,
      'branch_name': branchName,
    };
  }
}
