import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/async_views.dart';

/// Resolves Django permission codenames to integer IDs for compatibility with
/// older backend deployments that only accept `'permissions': [int]`.
/// Prefers `'factory'` app permissions when duplicate codenames exist.
List<int> resolvePermissionIdsFromCodenames(
  Iterable<String> codenames,
  List<Map<String, dynamic>> allPermissions,
) {
  final preferredByCode = <String, int>{};
  final fallbackByCode = <String, int>{};
  for (final p in allPermissions) {
    final code = p['codename']?.toString();
    final id = p['id'];
    if (code == null || code.isEmpty || id is! num) continue;
    final intId = id.toInt();
    if (p['app_label']?.toString() == 'factory') {
      preferredByCode.putIfAbsent(code, () => intId);
    } else {
      fallbackByCode.putIfAbsent(code, () => intId);
    }
  }
  final seen = <int>{};
  final result = <int>[];
  for (final code in codenames) {
    final id = preferredByCode[code] ?? fallbackByCode[code];
    if (id != null && seen.add(id)) {
      result.add(id);
    }
  }
  return result;
}

/// Fallback permission matrix matching `factory/models.py:permission_groups` 1:1
/// in case the server has not been updated yet.
const List<Map<String, dynamic>> _kDefaultPermissionMatrix = [
  {
    'group_name': 'التوصيل (Delivery)',
    'icon': 'fa-truck-fast',
    'color': 'cyan',
    'permissions': [
      {'codename': 'view_deliveryzone', 'label': 'عرض مناطق التوصيل'},
      {'codename': 'add_deliveryzone', 'label': 'إضافة منطقة توصيل'},
      {'codename': 'change_deliveryzone', 'label': 'تعديل رسوم وحالة مناطق التوصيل'},
      {'codename': 'delete_deliveryzone', 'label': 'حذف منطقة توصيل'},
      {'codename': 'view_deliverycustomer', 'label': 'عرض عملاء التوصيل'},
      {'codename': 'add_deliverycustomer', 'label': 'إضافة عميل توصيل'},
      {'codename': 'change_deliverycustomer', 'label': 'تعديل بيانات عميل توصيل'},
      {'codename': 'delete_deliverycustomer', 'label': 'حذف عميل توصيل'},
    ],
  },
  {
    'group_name': 'المصروفات المستقلة (Standalone expenses)',
    'icon': 'fa-money-bill',
    'color': 'rose',
    'permissions': [
      {'codename': 'change_expense', 'label': 'تعديل حساب أو مركز تكلفة المصروف المستقل'},
    ],
  },
  {
    'group_name': 'الإنتاج والمخازن (Inventory & Production)',
    'icon': 'fa-boxes-stacked',
    'color': 'secondary',
    'permissions': [
      {'codename': 'add_orders', 'label': 'إنشاء الطلبات بين الفروع'},
      {'codename': 'view_orders', 'label': 'عرض وتتبع الطلبات بين الفروع'},
      {'codename': 'change_orders', 'label': 'صرف وإستلام الطلبات بين الفروع'},
      {'codename': 'lock_orders', 'label': 'قفل الطلبات بين الفروع'},
      {'codename': 'unlock_orders', 'label': 'فتح الطلبات بين الفروع'},
      {'codename': 'cancel_orders', 'label': 'إلغاء الصرف بين الفروع'},
      {'codename': 'view_all_orders', 'label': 'عرض جميع الطلبات بين الفروع'},
      {'codename': 'view_storeproducts', 'label': 'عرض وتتبع المخزون في المخازن والفروع'},
      {'codename': 'change_storeproducts', 'label': 'تعديل المخزون في المخازن والفروع'},
      {'codename': 'add_manufacturing', 'label': 'إضافة أوامر الإنتاج'},
      {'codename': 'view_manufacturing', 'label': 'عرض وتتبع أوامر الإنتاج'},
    ],
  },
  {
    'group_name': 'المشتريات والفواتير (Purchases & Bills)',
    'icon': 'fa-cart-flatbed',
    'color': 'warning',
    'permissions': [
      {'codename': 'add_bills', 'label': 'إضافة فاتورة جديدة'},
      {'codename': 'view_bills', 'label': 'عرض سجل الفواتير'},
      {'codename': 'change_bills', 'label': 'تعديل بيانات الفواتير'},
      {'codename': 'confirm_bills', 'label': 'تأكيد وإلغاء الفواتير'},
      {'codename': 'add_suppliers', 'label': 'تسجيل موردي المواد الخام'},
      {'codename': 'view_suppliers', 'label': 'عرض قائمة الموردين'},
      {'codename': 'change_suppliers', 'label': 'تعديل بيانات الموردين'},
    ],
  },
  {
    'group_name': 'المبيعات والعملاء (Sales)',
    'icon': 'fa-cart-shopping',
    'color': 'info',
    'permissions': [
      {'codename': 'view_selling_orders', 'label': 'عرض وتتبع أوامر البيع'},
      {'codename': 'add_selling_orders', 'label': 'إضافة أوامر البيع'},
      {'codename': 'confirm_selling_order', 'label': 'تأكيد وإلغاء أوامر البيع'},
      {'codename': 'add_any_selling_order', 'label': 'إضافة أوامر بيع لأي فرع'},
      {'codename': 'review_selling_orders', 'label': 'مراجعة واعتماد أوامر البيع بالخزينة'},
    ],
  },
  {
    'group_name': 'الموارد البشرية (HR)',
    'icon': 'fa-users-gear',
    'color': 'primary',
    'permissions': [
      {'codename': 'view_employees', 'label': 'عرض قائمة الموظفين'},
      {'codename': 'add_employees', 'label': 'إضافة موظف جديد'},
      {'codename': 'change_employees', 'label': 'تعديل بيانات موظف'},
      {'codename': 'add_attendance', 'label': 'تسجيل وتعديل الحضور والانصراف'},
      {'codename': 'add_employeepenalty', 'label': 'توقيع وتوجيه جزاء إداري'},
      {'codename': 'change_employeepenalty', 'label': 'مراجعة واعتماد الجزاءات (HR / Admin)'},
      {'codename': 'view_leaverequest', 'label': 'عرض طلبات الإجازات'},
      {'codename': 'add_leaverequest', 'label': 'تسجيل واستحقاق الإجازات'},
      {'codename': 'change_leaverequest', 'label': 'مراجعة واعتماد طلبات الإجازات'},
      {'codename': 'view_payroll', 'label': 'عرض وتصفية المرتبات'},
      {'codename': 'add_payroll', 'label': 'إضافة مرتبات جديدة'},
      {'codename': 'change_payroll', 'label': 'تعديل بيانات المرتبات'},
    ],
  },
  {
    'group_name': 'الخزينة والحسابات (Finance & Safe)',
    'icon': 'fa-vault',
    'color': 'success',
    'permissions': [
      {'codename': 'change_safe_balance', 'label': 'التحكم في الخزنة الرئيسية (محاسب الخزنة)'},
      {'codename': 'set_safe_balances', 'label': 'ضبط أرصدة الخزائن (صلاحية مدير النظام)'},
      {'codename': 'add_expenses', 'label': 'تسجيل المصروفات المستقلة / الخزينة العامة'},
      {'codename': 'view_expenses', 'label': 'عرض سجل المصروفات'},
      {'codename': 'add_cashin', 'label': 'فتح/إغلاق الورديات والتوريد النقدي'},
      {'codename': 'change_cashin', 'label': 'تعديل واعتماد الورديات والتوريد النقدي'},
      {'codename': 'view_cashin', 'label': 'عرض الورديات والتوريد النقدي'},
      {'codename': 'view_accounttypes', 'label': 'عرض شجرة الحسابات'},
      {'codename': 'add_accounttypes', 'label': 'إضافة حسابات جديدة'},
      {'codename': 'change_accounttypes', 'label': 'تعديل بيانات الحسابات'},
      {'codename': 'view_operations', 'label': 'عرض سجل العمليات المالية'},
      {'codename': 'pay_bills', 'label': 'دفع الفواتير'},
      {'codename': 'add_direct_advance', 'label': 'إدارة وصرف السلف المباشرة (الخزينة)'},
    ],
  },
  {
    'group_name': 'إدارة النظام والمستخدمين (Admin)',
    'icon': 'fa-user-shield',
    'color': 'danger',
    'permissions': [
      {'codename': 'add_user', 'label': 'إضافة مستخدم جديد للنظام'},
      {'codename': 'change_user', 'label': 'تعديل صلاحيات حسابات المستخدمين'},
      {'codename': 'view_user', 'label': 'عرض صلاحيات حسابات المستخدمين'},
      {'codename': 'delete_user', 'label': 'تعطيل أو حذف حساب مستخدم'},
      {'codename': 'view_branches', 'label': 'إدارة الفروع والمخازن'},
      {'codename': 'add_branches', 'label': 'إضافة فرع جديد'},
      {'codename': 'add_storestypes', 'label': 'إضافة مخزن جديد'},
      {'codename': 'add_units', 'label': 'إضافة وحدات قياس جديدة'},
      {'codename': 'view_units', 'label': 'عرض وحدات القياس'},
      {'codename': 'change_units', 'label': 'تعديل وحدات القياس'},
      {'codename': 'add_products', 'label': 'إضافة أصناف جديدة'},
      {'codename': 'view_products', 'label': 'عرض قائمة الأصناف'},
      {'codename': 'change_products', 'label': 'تعديل بيانات الأصناف'},
      {'codename': 'cost_products', 'label': 'تسعير وتكلفة الأصناف'},
      {'codename': 'view_branch_reports', 'label': 'عرض تقارير الفروع'},
    ],
  },
];

IconData _resolveMatrixIcon(String rawIcon) {
  final clean = rawIcon.replaceAll('fa-solid ', '').replaceAll('fa-', '').trim();
  switch (clean) {
    case 'truck-fast':
      return Icons.local_shipping_rounded;
    case 'money-bill':
      return Icons.receipt_long_rounded;
    case 'boxes-stacked':
      return Icons.inventory_2_rounded;
    case 'cart-flatbed':
      return Icons.shopping_bag_rounded;
    case 'cart-shopping':
      return Icons.point_of_sale_rounded;
    case 'users-gear':
      return Icons.groups_rounded;
    case 'vault':
      return Icons.account_balance_wallet_rounded;
    case 'user-shield':
      return Icons.admin_panel_settings_rounded;
    default:
      return Icons.verified_user_rounded;
  }
}

Color _resolveMatrixColor(String rawColor) {
  switch (rawColor.toLowerCase()) {
    case 'cyan':
    case 'info':
      return const Color(0xFF0284C7);
    case 'rose':
    case 'danger':
      return const Color(0xFFDC2626);
    case 'warning':
      return const Color(0xFFD97706);
    case 'success':
      return const Color(0xFF16A34A);
    case 'primary':
      return const Color(0xFF2563EB);
    case 'secondary':
      return const Color(0xFF475569);
    default:
      return AppColors.primary;
  }
}

class AdminUsersScreen extends StatefulWidget {
  final bool openCreate;

  const AdminUsersScreen({super.key, this.openCreate = false});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _isLoading = true;
  String? _error;
  bool _initialized = false;

  ApiClient get _api => context.read<ApiClient>();

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _permissionMatrix = [];
  List<Map<String, dynamic>> _allPermissions = [];

  // Exact 4 filters matching factory/templates/factory/users.html
  final _usernameFilterCtrl = TextEditingController();
  final _employeeFilterCtrl = TextEditingController();
  final _jobTitleFilterCtrl = TextEditingController();
  int? _branchFilterId;
  bool _showAdvancedFilters = false;
  bool _didAutoOpenCreate = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _bootstrapData();
    }
  }

  @override
  void dispose() {
    _usernameFilterCtrl.dispose();
    _employeeFilterCtrl.dispose();
    _jobTitleFilterCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrapData() async {
    await Future.wait([_loadOptions(), _loadUsers()]);
    if (widget.openCreate && !_didAutoOpenCreate && mounted) {
      _didAutoOpenCreate = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openUserForm();
      });
    }
  }

  Future<void> _loadOptions() async {
    try {
      final res = await _api.get('/api/v1/admin/users/options/');
      var perms = (res is Map<String, dynamic>
              ? (res['permissions'] as List<dynamic>? ?? [])
              : const <dynamic>[])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (perms.isEmpty) {
        perms = await _fetchAllPermissions(_api);
      }
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _branches = (res['branches'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _stores = (res['stores'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _employees = (res['employees'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          final rawMatrix = res['permission_matrix'] as List<dynamic>?;
          if (rawMatrix != null && rawMatrix.isNotEmpty) {
            _permissionMatrix = rawMatrix
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          } else {
            _permissionMatrix = _kDefaultPermissionMatrix;
          }
          _allPermissions = perms;
        });
      }
    } catch (_) {
      if (_permissionMatrix.isEmpty && mounted) {
        setState(() => _permissionMatrix = _kDefaultPermissionMatrix);
      }
    }
  }

  static Future<List<Map<String, dynamic>>> _fetchAllPermissions(ApiClient api) async {
    final all = <Map<String, dynamic>>[];
    for (var page = 1; page <= 10; page++) {
      try {
        final res = await api.get(
          '/api/v1/admin/permissions/',
          queryParams: {'page': '$page', 'page_size': '200'},
        );
        if (res is! Map) break;
        final batch = (res['results'] as List<dynamic>? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        all.addAll(batch);
        if (res['next'] == null || batch.isEmpty) break;
      } catch (_) {
        break;
      }
    }
    return all;
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final params = <String, String>{
        'page_size': '100',
        if (_usernameFilterCtrl.text.trim().isNotEmpty) 'username': _usernameFilterCtrl.text.trim(),
        if (_employeeFilterCtrl.text.trim().isNotEmpty) 'employee_name': _employeeFilterCtrl.text.trim(),
        if (_jobTitleFilterCtrl.text.trim().isNotEmpty) 'job_title': _jobTitleFilterCtrl.text.trim(),
        if (_branchFilterId != null) 'branch': '$_branchFilterId',
      };
      final res = await _api.get('/api/v1/admin/users/', queryParams: params);
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _users = (res['results'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  void _resetFilters() {
    _usernameFilterCtrl.clear();
    _employeeFilterCtrl.clear();
    _jobTitleFilterCtrl.clear();
    setState(() => _branchFilterId = null);
    _loadUsers();
  }

  Future<void> _openUserForm({Map<String, dynamic>? user}) async {
    if (_allPermissions.isEmpty || _branches.isEmpty) {
      await _loadOptions();
    }
    if (!mounted) return;
    final empLinkById = <int, Map<String, dynamic>>{};
    for (final u in _users) {
      final emp = u['employee'];
      if (emp is Map && emp['id'] is num) {
        empLinkById[(emp['id'] as num).toInt()] = u;
      }
    }
    final enrichedEmployees = _employees.map((e) {
      if (e['linked_user_id'] != null) return e;
      final eid = (e['id'] as num?)?.toInt();
      final linkedUser = eid != null ? empLinkById[eid] : null;
      if (linkedUser == null) return e;
      return {
        ...e,
        'linked_user_id': linkedUser['id'],
        'linked_username': linkedUser['username'],
      };
    }).toList();

    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => UserPermissionsFormScreen(
          api: _api,
          user: user,
          branches: _branches,
          stores: _stores,
          employees: enrichedEmployees,
          permissionMatrix: _permissionMatrix.isNotEmpty ? _permissionMatrix : _kDefaultPermissionMatrix,
          allPermissions: _allPermissions,
        ),
      ),
    );
    if (saved == true && mounted) {
      await Future.wait([_loadOptions(), _loadUsers()]);
    }
  }

  Future<void> _confirmDeleteUser(Map<String, dynamic> user) async {
    final ok = await AppConfirmDialog.show(
      context,
      title: 'تأكيد مسح حساب المستخدم',
      message:
          'هل أنت متأكد من مسح حساب المستخدم "${user['username']}" نهائياً؟\n(إذا كان الحساب مرتبطاً بحركات محمية يمكنك تعطيله بدلاً من مسحه).',
      confirmLabel: 'تأكيد المسح',
      isDestructive: true,
    );
    if (!ok || !mounted) return;
    try {
      await _api.post('/api/v1/admin/users/${user['id']}/delete/');
      if (!mounted) return;
      AppFeedback.showSuccess(context, 'تم مسح حساب المستخدم بنجاح');
      _loadOptions();
      _loadUsers();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 404) {
        AppFeedback.showError(
          context,
          'حذف الحسابات غير متاح على إصدار الخادم الحالي؛ استخدم زر التعطيل بدلاً من الحذف.',
        );
      } else {
        AppFeedback.showError(context, 'تعذر المسح: $e');
      }
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, 'تعذر المسح: $e');
    }
  }

  Future<void> _toggleUserActive(Map<String, dynamic> user) async {
    final isActive = user['is_active'] != false;
    final confirmed = await AppConfirmDialog.show(
      context,
      title: isActive ? 'تعطيل حساب المستخدم' : 'إعادة تفعيل الحساب',
      message: isActive
          ? 'هل تريد تعطيل حساب "${user['username']}" وإلغاء جلساته النشطة؟'
          : 'هل تريد إعادة تفعيل حساب "${user['username']}"؟',
      confirmLabel: isActive ? 'تعطيل الحساب' : 'تفعيل الحساب',
      isDestructive: isActive,
    );
    if (!confirmed || !mounted) return;
    final endpoint = isActive
        ? '/api/v1/admin/users/${user['id']}/deactivate/'
        : '/api/v1/admin/users/${user['id']}/reactivate/';
    try {
      await _api.post(endpoint);
      if (!mounted) return;
      AppFeedback.showSuccess(
        context,
        isActive
            ? 'تم تعطيل الحساب وإلغاء الجلسات النشطة.'
            : 'تم إعادة تفعيل الحساب بنجاح.',
      );
      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, 'خطأ: $e');
    }
  }

  void _showItemsListDialog(String title, List<String> names) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
        content: Wrap(
          spacing: 6,
          runSpacing: 6,
          children: names
              .map((n) => Chip(
                    label: Text(n, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                    backgroundColor: const Color(0xFFF1F5F9),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق', style: TextStyle(fontFamily: 'Cairo'))),
        ],
      ),
    );
  }

  Widget _buildBadgesWrap(List<String> items, String unitWord, String dialogTitle) {
    if (items.isEmpty) {
      return const Text('-', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted));
    }
    final shown = items.length > 3 ? items.take(2).toList() : items;
    final remaining = items.length - shown.length;
    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: [
        ...shown.map(
          (name) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          ),
        ),
        if (remaining > 0)
          InkWell(
            onTap: () => _showItemsListDialog(dialogTitle, items),
            borderRadius: BorderRadius.circular(7),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF475569),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text('+$remaining $unitWord', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final actorIsSuper = context.watch<AuthProvider>().user?.isSuperuser == true;
    final hasActiveFilters = _usernameFilterCtrl.text.trim().isNotEmpty ||
        _employeeFilterCtrl.text.trim().isNotEmpty ||
        _jobTitleFilterCtrl.text.trim().isNotEmpty ||
        _branchFilterId != null;

    // Client-side instant filter for job_title as fallback alongside server filter
    final jobQuery = _jobTitleFilterCtrl.text.trim().toLowerCase();
    final visibleUsers = _users.where((u) {
      if (jobQuery.isEmpty) return true;
      final jt = ((u['employee'] as Map?)?['job_title']?.toString() ?? '').toLowerCase();
      return jt.contains(jobQuery);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('قائمة مستخدمي النظام', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 17)),
            Text('إدارة حسابات الدخول والصلاحيات للفروع والمخازن', style: TextStyle(fontFamily: 'Cairo', fontSize: 10.5, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: hasActiveFilters,
              child: Icon(_showAdvancedFilters ? Icons.filter_alt_off_rounded : Icons.filter_alt_rounded),
            ),
            tooltip: 'البحث والفلترة',
            onPressed: () => setState(() => _showAdvancedFilters = !_showAdvancedFilters),
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث', onPressed: _loadUsers),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('إضافة مستخدم جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        onPressed: () => _openUserForm(),
      ),
      body: Column(
        children: [
          // Top Search + Expandable Web-Parity Filter Panel
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _usernameFilterCtrl,
                        builder: (_, val, __) => TextField(
                          controller: _usernameFilterCtrl,
                          onSubmitted: (_) => _loadUsers(),
                          decoration: InputDecoration(
                            hintText: 'بحث باسم المستخدم (Username)...',
                            prefixIcon: const Icon(Icons.person_search_rounded, color: AppColors.primary, size: 20),
                            suffixIcon: val.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 16),
                                    onPressed: () {
                                      _usernameFilterCtrl.clear();
                                      _loadUsers();
                                    },
                                  )
                                : null,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _loadUsers,
                      child: const Icon(Icons.search_rounded, size: 20),
                    ),
                    if (hasActiveFilters) ...[
                      const SizedBox(width: 6),
                      IconButton.outlined(
                        tooltip: 'إعادة ضبط',
                        onPressed: _resetFilters,
                        icon: const Icon(Icons.rotate_left_rounded, size: 20),
                      ),
                    ],
                  ],
                ),
                if (_showAdvancedFilters) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _employeeFilterCtrl,
                          onSubmitted: (_) => _loadUsers(),
                          decoration: const InputDecoration(
                            labelText: 'اسم الموظف المرتبط',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _jobTitleFilterCtrl,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _loadUsers(),
                          decoration: const InputDecoration(
                            labelText: 'المسمى الوظيفي',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    value: _branchFilterId,
                    isDense: true,
                    decoration: const InputDecoration(
                      labelText: 'يمتلك صلاحية على فرع',
                      prefixIcon: Icon(Icons.store_mall_directory_outlined, size: 18),
                      isDense: true,
                    ),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('جميع الفروع', style: TextStyle(fontFamily: 'Cairo', fontSize: 13))),
                      ..._branches.map((b) => DropdownMenuItem<int?>(
                            value: (b['id'] as num).toInt(),
                            child: Text(b['name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                          )),
                    ],
                    onChanged: (val) {
                      setState(() => _branchFilterId = val);
                      _loadUsers();
                    },
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),

          // Users Cards List matching users.html table columns
          Expanded(
            child: _isLoading
                ? const AppLoadingView(message: 'جاري تحميل مستخدمي النظام...')
                : _error != null
                    ? AppErrorView(message: _error!, onRetry: _loadUsers)
                    : visibleUsers.isEmpty
                        ? const AppEmptyView(title: 'لا يوجد مستخدمون مسجلون بناءً على محددات البحث', icon: Icons.manage_accounts_outlined)
                        : RefreshIndicator(
                            onRefresh: _loadUsers,
                            color: AppColors.primary,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(14, 12, 14, 88),
                              itemCount: visibleUsers.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final user = visibleUsers[i];
                                final id = user['id'];
                                final username = user['username']?.toString() ?? '';
                                final isSuper = user['is_superuser'] == true;
                                final isActive = user['is_active'] != false;
                                final emp = user['employee'] as Map<String, dynamic>?;
                                final branchNames = (user['branches'] as List<dynamic>? ?? [])
                                    .map((b) => (b as Map)['name']?.toString() ?? '')
                                    .where((s) => s.isNotEmpty)
                                    .toList();
                                final storeNames = (user['stores'] as List<dynamic>? ?? [])
                                    .map((s) => (s as Map)['name']?.toString() ?? '')
                                    .where((s) => s.isNotEmpty)
                                    .toList();
                                final directCount = (user['direct_permission_ids'] as List<dynamic>?)?.length ??
                                    (user['permissions'] as List<dynamic>?)?.length ??
                                    0;

                                return Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isActive ? AppColors.border : AppColors.error.withValues(alpha: 0.4),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.025),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        // Top Row: #ID, Username, Account Type Badge
                                        Row(
                                          children: [
                                            Container(
                                              width: 38,
                                              height: 38,
                                              decoration: BoxDecoration(
                                                color: isSuper ? const Color(0xFFFEE2E2) : AppColors.primaryLight,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.shield_outlined,
                                                size: 20,
                                                color: isSuper ? AppColors.error : AppColors.primary,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        '#$id',
                                                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted),
                                                      ),
                                                      const SizedBox(width: 6),
                                                      Flexible(
                                                        child: Text(
                                                          username,
                                                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                                        ),
                                                      ),
                                                      if (!isActive) ...[
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                          decoration: BoxDecoration(
                                                            color: AppColors.error.withValues(alpha: 0.12),
                                                            borderRadius: BorderRadius.circular(5),
                                                          ),
                                                          child: const Text('معطل', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.error)),
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                  if (emp != null)
                                                    Text(
                                                      '${emp['name']}${emp['job_title'] != null && emp['job_title'].toString().isNotEmpty ? ' • ${emp['job_title']}' : ''}',
                                                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                                                    )
                                                  else
                                                    const Text(
                                                      '- غير مرتبط بموظف -',
                                                      style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.textMuted),
                                                    ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isSuper ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                isSuper ? 'مدير عام (Admin)' : 'مستخدم نظام',
                                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                            ),
                                          ],
                                        ),

                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 10),
                                          child: Divider(height: 1),
                                        ),

                                        // Branches & Stores Badges matching users.html
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(
                                              width: 96,
                                              child: Text('الفروع المتاحة:', style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                                            ),
                                            Expanded(
                                              child: _buildBadgesWrap(branchNames, 'فرع', 'الفروع المتاحة لـ $username'),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 7),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(
                                              width: 96,
                                              child: Text('المخازن المتاحة:', style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                                            ),
                                            Expanded(
                                              child: _buildBadgesWrap(storeNames, 'مخزن', 'المخازن المتاحة لـ $username'),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 7),
                                        Row(
                                          children: [
                                            const SizedBox(
                                              width: 96,
                                              child: Text('الصلاحيات:', style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                                            ),
                                            Text(
                                              isSuper ? 'كافة صلاحيات النظام مفتوحة' : '$directCount صلاحية مخصصة مفعلة',
                                              style: TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: isSuper ? AppColors.error : AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 12),

                                        // Direct Action Buttons matching users.html
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  foregroundColor: AppColors.primary,
                                                  side: const BorderSide(color: AppColors.primary),
                                                  padding: const EdgeInsets.symmetric(vertical: 9),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                                                ),
                                                icon: const Icon(Icons.edit_note_rounded, size: 19),
                                                label: const Text(
                                                  'تعديل وتعيين الصلاحيات',
                                                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12.5),
                                                ),
                                                onPressed: () => _openUserForm(user: user),
                                              ),
                                            ),
                                            if (username != 'admin') ...[
                                              const SizedBox(width: 8),
                                              IconButton.outlined(
                                                tooltip: isActive ? 'تعطيل الحساب' : 'إعادة تفعيل الحساب',
                                                style: IconButton.styleFrom(
                                                  foregroundColor: isActive ? AppColors.warning : AppColors.success,
                                                  side: BorderSide(color: (isActive ? AppColors.warning : AppColors.success).withValues(alpha: 0.5)),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                                                ),
                                                icon: Icon(isActive ? Icons.block_rounded : Icons.check_circle_outline_rounded, size: 19),
                                                onPressed: () => _toggleUserActive(user),
                                              ),
                                            ],
                                            if (actorIsSuper && username != 'admin') ...[
                                              const SizedBox(width: 6),
                                              IconButton.outlined(
                                                tooltip: 'مسح المستخدم',
                                                style: IconButton.styleFrom(
                                                  foregroundColor: AppColors.error,
                                                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.45)),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
                                                ),
                                                icon: const Icon(Icons.delete_outline_rounded, size: 19),
                                                onPressed: () => _confirmDeleteUser(user),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

/// Full-screen Create / Edit User & Custom Permission Matrix matching `factory/templates/factory/newuser.html`.
class UserPermissionsFormScreen extends StatefulWidget {
  final ApiClient api;
  final Map<String, dynamic>? user;
  final List<Map<String, dynamic>> branches;
  final List<Map<String, dynamic>> stores;
  final List<Map<String, dynamic>> employees;
  final List<Map<String, dynamic>> permissionMatrix;
  final List<Map<String, dynamic>> allPermissions;

  const UserPermissionsFormScreen({
    super.key,
    required this.api,
    this.user,
    required this.branches,
    required this.stores,
    required this.employees,
    required this.permissionMatrix,
    required this.allPermissions,
  });

  @override
  State<UserPermissionsFormScreen> createState() => _UserPermissionsFormScreenState();
}

class _UserPermissionsFormScreenState extends State<UserPermissionsFormScreen> {
  late final TextEditingController _usernameCtrl;
  final _passwordCtrl = TextEditingController();
  final _permSearchCtrl = TextEditingController();

  int? _selectedEmployeeId;
  late final Set<int> _selectedBranchIds;
  late final Set<int> _selectedStoreIds;
  late final Set<String> _selectedCodenames;

  bool _obscurePassword = true;
  bool _isActive = true;
  bool _isSuperuser = false;
  bool _isSubmitting = false;
  String _permQuery = '';

  @override
  void initState() {
    super.initState();
    final u = widget.user;
    _usernameCtrl = TextEditingController(text: u?['username']?.toString() ?? '');
    _selectedEmployeeId = (u?['employee'] as Map<String, dynamic>?)?['id'] as int?;
    _selectedBranchIds = {
      for (final b in (u?['branches'] as List<dynamic>? ?? [])) ((b as Map)['id'] as num).toInt(),
    };
    _selectedStoreIds = {
      for (final s in (u?['stores'] as List<dynamic>? ?? [])) ((s as Map)['id'] as num).toInt(),
    };

    // Populate user's direct permission codenames (matching views.user: user_perms)
    final directCodes = u?['direct_permission_codenames'] as List<dynamic>?;
    if (directCodes != null) {
      _selectedCodenames = directCodes.map((e) => e.toString()).toSet();
    } else {
      final directIds = (u?['direct_permission_ids'] as List<dynamic>? ?? [])
          .whereType<num>()
          .map((e) => e.toInt())
          .toSet();
      final effectivePerms = (u?['permissions'] as List<dynamic>? ?? []);
      _selectedCodenames = <String>{};
      final idToCode = <int, String>{};
      for (final p in widget.allPermissions) {
        final pid = (p['id'] as num?)?.toInt();
        final code = p['codename']?.toString();
        if (pid != null && code != null) idToCode[pid] = code;
      }
      for (final p in effectivePerms) {
        if (p is Map) {
          final pid = (p['id'] as num?)?.toInt();
          final code = p['codename']?.toString();
          if (pid != null && code != null) {
            idToCode.putIfAbsent(pid, () => code);
            if (directIds.contains(pid)) {
              _selectedCodenames.add(code);
            }
          }
        }
      }
      for (final pid in directIds) {
        final code = idToCode[pid];
        if (code != null) _selectedCodenames.add(code);
      }
    }

    _isActive = u?['is_active'] != false;
    _isSuperuser = u?['is_superuser'] == true;
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _permSearchCtrl.dispose();
    super.dispose();
  }

  Set<String> _allMatrixCodenames() {
    final codes = <String>{};
    for (final grp in widget.permissionMatrix) {
      for (final p in (grp['permissions'] as List<dynamic>? ?? [])) {
        final code = (p as Map)['codename']?.toString();
        if (code != null && code.isNotEmpty) codes.add(code);
      }
    }
    return codes;
  }

  void _toggleAllPermissions() {
    HapticFeedback.selectionClick();
    final allCodes = _allMatrixCodenames();
    final allSelected = allCodes.isNotEmpty && allCodes.every(_selectedCodenames.contains);
    setState(() {
      if (allSelected) {
        _selectedCodenames.removeAll(allCodes);
      } else {
        _selectedCodenames.addAll(allCodes);
      }
    });
  }

  Future<void> _pickEmployeeSheet() async {
    String search = '';
    final chosen = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (c, setSheet) {
          final q = search.toLowerCase();
          final filtered = widget.employees.where((e) {
            if (q.isEmpty) return true;
            final name = e['name']?.toString().toLowerCase() ?? '';
            final job = e['job_title']?.toString().toLowerCase() ?? '';
            final br = e['branch_name']?.toString().toLowerCase() ?? '';
            return name.contains(q) || job.contains(q) || br.contains(q);
          }).toList();

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            maxChildSize: 0.92,
            minChildSize: 0.45,
            builder: (_, scrollCtrl) => Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(c).viewInsets.bottom + 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('اختر الموظف المرتبط بالحساب', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: () => Navigator.pop(ctx, _selectedEmployeeId), icon: const Icon(Icons.close_rounded)),
                    ],
                  ),
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'ابحث عن اسم الموظف أو الوظيفة أو الفرع...',
                      prefixIcon: Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                    onChanged: (v) => setSheet(() => search = v),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.link_off_rounded, color: AppColors.textMuted),
                    title: const Text('بدون ربط بموظف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    trailing: _selectedEmployeeId == null ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
                    onTap: () => Navigator.pop(ctx, -1),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollCtrl,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, idx) {
                        final emp = filtered[idx];
                        final id = (emp['id'] as num).toInt();
                        final selected = id == _selectedEmployeeId;
                        final linkedUserId = (emp['linked_user_id'] as num?)?.toInt();
                        final linkedUsername = emp['linked_username']?.toString();
                        final currentEditingId = (widget.user?['id'] as num?)?.toInt();
                        final isLinkedElsewhere = linkedUserId != null && linkedUserId != currentEditingId;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: selected
                                ? AppColors.primary
                                : (isLinkedElsewhere ? const Color(0xFFFEF3C7) : AppColors.primaryLight),
                            child: Icon(
                              Icons.person_rounded,
                              size: 17,
                              color: selected
                                  ? Colors.white
                                  : (isLinkedElsewhere ? AppColors.warning : AppColors.primary),
                            ),
                          ),
                          title: Text(emp['name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13.5)),
                          subtitle: Text(
                            '${emp['job_title'] ?? 'موظف'} • ${emp['branch_name'] ?? ''}'
                            '${isLinkedElsewhere ? ' (مرتبط بحساب: @$linkedUsername)' : ''}',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11.5,
                              color: isLinkedElsewhere ? AppColors.warning : AppColors.textSecondary,
                            ),
                          ),
                          trailing: selected ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
                          onTap: () => Navigator.pop(ctx, id),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (chosen != null) {
      setState(() => _selectedEmployeeId = chosen == -1 ? null : chosen);
    }
  }

  Future<void> _pickMultiItemsSheet({
    required String title,
    required String searchHint,
    required List<Map<String, dynamic>> options,
    required Set<int> targetSet,
  }) async {
    final temp = Set<int>.from(targetSet);
    String search = '';

    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (c, setSheet) {
          final q = search.toLowerCase();
          final visible = options.where((o) {
            if (q.isEmpty) return true;
            return (o['name']?.toString().toLowerCase() ?? '').contains(q);
          }).toList();

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            maxChildSize: 0.92,
            minChildSize: 0.45,
            builder: (_, scrollCtrl) => Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(c).viewInsets.bottom + 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('$title (${temp.length})', style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                    ],
                  ),
                  TextField(
                    decoration: InputDecoration(
                      hintText: searchHint,
                      prefixIcon: const Icon(Icons.search_rounded),
                      isDense: true,
                    ),
                    onChanged: (v) => setSheet(() => search = v),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.done_all_rounded, size: 17),
                        label: const Text('تحديد الكل', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        onPressed: () => setSheet(() {
                          for (final item in visible) {
                            temp.add((item['id'] as num).toInt());
                          }
                        }),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.deselect_rounded, size: 17, color: AppColors.error),
                        label: const Text('إلغاء التحديد', style: TextStyle(fontFamily: 'Cairo', color: AppColors.error)),
                        onPressed: () => setSheet(temp.clear),
                      ),
                    ],
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      itemCount: visible.length,
                      itemBuilder: (_, idx) {
                        final item = visible[idx];
                        final id = (item['id'] as num).toInt();
                        final checked = temp.contains(id);
                        return CheckboxListTile(
                          dense: true,
                          activeColor: AppColors.primary,
                          value: checked,
                          title: Text(item['name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600, fontSize: 13.5)),
                          onChanged: (v) => setSheet(() => v == true ? temp.add(id) : temp.remove(id)),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(ctx, temp),
                    child: Text('اعتماد الاختيار (${temp.length})', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    if (result != null) {
      setState(() {
        targetSet
          ..clear()
          ..addAll(result);
      });
    }
  }

  String _describeSaveError(Object e) {
    if (e is ApiException) {
      if (e.fields.isNotEmpty) {
        final details = e.fields.entries
            .map((entry) {
              final val = entry.value;
              if (val is List) return val.join('، ');
              return val?.toString() ?? '';
            })
            .where((s) => s.isNotEmpty)
            .join(' | ');
        if (details.isNotEmpty) return '${e.message} ($details)';
      }
      return e.message;
    }
    return e.toString();
  }

  Future<void> _saveUser() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    final isCreating = widget.user == null;

    if (username.isEmpty) {
      AppFeedback.showError(context, 'يرجى إدخال اسم المستخدم (للدخول).');
      return;
    }
    if (isCreating && password.isEmpty) {
      AppFeedback.showError(context, 'يرجى إدخال كلمة المرور للمستخدم الجديد.');
      return;
    }

    // Check if chosen employee is currently linked to another user account
    bool transferEmployee = false;
    if (_selectedEmployeeId != null) {
      final empObj = widget.employees.where((e) => (e['id'] as num).toInt() == _selectedEmployeeId).firstOrNull;
      final linkedUid = (empObj?['linked_user_id'] as num?)?.toInt();
      final linkedUname = empObj?['linked_username']?.toString() ?? '';
      final currentEditingId = (widget.user?['id'] as num?)?.toInt();
      if (linkedUid != null && linkedUid != currentEditingId) {
        final confirmTransfer = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: const Text('الموظف مرتبط بحساب آخر', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
            content: Text(
              'الموظف "${empObj?['name']}" مرتبط حالياً بحساب المستخدم "@$linkedUname".\nهل تريد نقل ربط الموظف إلى الحساب "$username"؟',
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('نعم، نقل الربط والحفظ', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        if (confirmTransfer != true) return;
        transferEmployee = true;
      }
    }

    if (!mounted) return;
    final actorIsSuper = context.read<AuthProvider>().user?.isSuperuser == true;
    setState(() => _isSubmitting = true);

    try {
      var catalogPerms = widget.allPermissions;
      if (catalogPerms.isEmpty) {
        catalogPerms = await _AdminUsersScreenState._fetchAllPermissions(widget.api);
      }
      final resolvedPermIds = resolvePermissionIdsFromCodenames(_selectedCodenames, catalogPerms);

      final payload = <String, dynamic>{
        'username': username,
        'employee_id': _selectedEmployeeId,
        if (transferEmployee) 'transfer_employee': true,
        'branches': _selectedBranchIds.toList(),
        'stores': _selectedStoreIds.toList(),
        'permissions': resolvedPermIds,
        'permission_codenames': _selectedCodenames.toList(),
        'is_active': _isActive,
        if (actorIsSuper) 'is_superuser': _isSuperuser,
        if (actorIsSuper) 'is_staff': _isSuperuser ? true : (widget.user?['is_staff'] == true),
      };

      bool passwordResetFailed = false;
      String? passwordResetErr;
      if (isCreating) {
        payload['password'] = password;
        await widget.api.post('/api/v1/admin/users/create/', body: payload);
      } else {
        final userId = widget.user!['id'];
        await widget.api.post('/api/v1/admin/users/$userId/update/', body: payload);
        if (password.isNotEmpty) {
          try {
            await widget.api.post('/api/v1/admin/users/$userId/reset-password/', body: {'new_password': password});
          } catch (pwErr) {
            passwordResetFailed = true;
            passwordResetErr = _describeSaveError(pwErr);
          }
        }
      }

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      if (passwordResetFailed) {
        AppFeedback.showError(
          context,
          'تم حفظ بيانات المستخدم، لكن فشل تغيير كلمة المرور: $passwordResetErr',
        );
      } else {
        AppFeedback.showSuccess(
          context,
          isCreating ? 'تم إضافة المستخدم وصلاحياته بنجاح!' : 'تم تعديل المستخدم وصلاحياته بنجاح!',
        );
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      AppFeedback.showError(context, 'خطأ أثناء الحفظ: ${_describeSaveError(e)}');
    }
  }

  Widget _buildMultiSelectBox({
    required String label,
    required Color labelColor,
    required String hint,
    required List<Map<String, dynamic>> options,
    required Set<int> selectedIds,
    required VoidCallback onTapPicker,
  }) {
    final selectedItems = options.where((o) => selectedIds.contains((o['id'] as num).toInt())).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: labelColor)),
            Row(
              children: [
                InkWell(
                  onTap: () => setState(() {
                    for (final o in options) {
                      selectedIds.add((o['id'] as num).toInt());
                    }
                  }),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text('اختيار الكل', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                ),
                if (selectedIds.isNotEmpty)
                  InkWell(
                    onTap: () => setState(selectedIds.clear),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text('مسح', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.error)),
                    ),
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTapPicker,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (selectedItems.isEmpty)
                  Row(
                    children: [
                      const Icon(Icons.add_circle_outline_rounded, size: 18, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(hint, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted)),
                      ),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
                    ],
                  )
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...selectedItems.map((item) {
                        final id = (item['id'] as num).toInt();
                        return InputChip(
                          label: Text(item['name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.w600)),
                          backgroundColor: labelColor.withValues(alpha: 0.1),
                          deleteIconColor: labelColor,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          onDeleted: () => setState(() => selectedIds.remove(id)),
                        );
                      }),
                      ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 15),
                        label: const Text('إضافة / تعديل', style: TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onPressed: onTapPicker,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCreating = widget.user == null;
    final actorIsSuper = context.watch<AuthProvider>().user?.isSuperuser == true;
    final selectedEmployee = widget.employees
        .where((e) => (e['id'] as num).toInt() == _selectedEmployeeId)
        .firstOrNull;

    final allCodes = _allMatrixCodenames();
    final activeMatrixCount = allCodes.where(_selectedCodenames.contains).length;
    final allChecked = allCodes.isNotEmpty && activeMatrixCount == allCodes.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: Text(
          isCreating ? 'إضافة مستخدم جديد' : 'تعديل مستخدم: ${widget.user!['username']}',
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16.5),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryDark,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _isSubmitting ? null : _saveUser,
              icon: _isSubmitting
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_rounded, size: 18),
              label: const Text('حفظ', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: AppColors.border)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedBranchIds.length} فرع • ${_selectedStoreIds.length} مخزن',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    Text(
                      'الصلاحيات المفعلة: $activeMatrixCount من ${allCodes.length}',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isSubmitting ? null : _saveUser,
                icon: _isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_rounded),
                label: const Text('حفظ المستخدم', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          // ===================================================================
          // CARD 1: البيانات الأساسية (matching left card in newuser.html)
          // ===================================================================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.badge_outlined, color: AppColors.secondary, size: 22),
                    SizedBox(width: 8),
                    Text('البيانات الأساسية', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 14),

                // Username
                const Text('اسم المستخدم (للدخول)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: _usernameCtrl,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    hintText: 'username',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 14),

                // Password
                const Text('كلمة المرور', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: isCreating ? 'أدخل كلمة المرور...' : 'اتركه فارغاً للاحتفاظ بكلمة المرور الحالية',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 19),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    isDense: true,
                  ),
                ),
                if (!isCreating) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'اتركه فارغاً إذا كنت لا تريد تغيير كلمة المرور الحالية.',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted),
                  ),
                ],

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1),
                ),

                // Linked Employee (Searchable Picker matching selectpicker data-live-search)
                const Text('الموظف المرتبط', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2563EB))),
                const SizedBox(height: 6),
                InkWell(
                  onTap: _pickEmployeeSheet,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedEmployee != null ? Icons.person_pin_rounded : Icons.person_search_outlined,
                          color: selectedEmployee != null ? const Color(0xFF2563EB) : AppColors.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedEmployee != null
                                ? '${selectedEmployee['name']} (${selectedEmployee['branch_name'] ?? ''})'
                                : 'ابحث عن اسم الموظف...',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: selectedEmployee != null ? FontWeight.bold : FontWeight.normal,
                              color: selectedEmployee != null ? AppColors.textPrimary : AppColors.textMuted,
                            ),
                          ),
                        ),
                        if (selectedEmployee != null)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.clear_rounded, size: 18, color: AppColors.textMuted),
                            onPressed: () => setState(() => _selectedEmployeeId = null),
                          )
                        else
                          const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Allowed Branches (Choices.js equivalent)
                _buildMultiSelectBox(
                  label: 'الفروع المصرح بها',
                  labelColor: AppColors.success,
                  hint: 'اضغط للبحث واختيار فرع أو أكثر أو الكل...',
                  options: widget.branches,
                  selectedIds: _selectedBranchIds,
                  onTapPicker: () => _pickMultiItemsSheet(
                    title: 'الفروع المصرح بها',
                    searchHint: 'ابحث عن فرع...',
                    options: widget.branches,
                    targetSet: _selectedBranchIds,
                  ),
                ),
                const SizedBox(height: 14),

                // Allowed Stores (Choices.js equivalent)
                _buildMultiSelectBox(
                  label: 'المخازن المصرح بها',
                  labelColor: const Color(0xFF0284C7),
                  hint: 'اضغط للبحث واختيار مخزن واحد أو أكثر أو الكل...',
                  options: widget.stores,
                  selectedIds: _selectedStoreIds,
                  onTapPicker: () => _pickMultiItemsSheet(
                    title: 'المخازن المصرح بها',
                    searchHint: 'ابحث عن مخزن أو مستودع...',
                    options: widget.stores,
                    targetSet: _selectedStoreIds,
                  ),
                ),

                if (actorIsSuper) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.primary,
                    title: const Text('الحساب نشط (مسموح بتسجيل الدخول)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12.5)),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    activeColor: AppColors.error,
                    title: const Text('مدير عام كامل الصلاحيات (Superuser Admin)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.error)),
                    subtitle: const Text('يمنح كافة صلاحيات النظام وجميع الفروع تلقائياً', style: TextStyle(fontFamily: 'Cairo', fontSize: 10.5)),
                    value: _isSuperuser,
                    onChanged: (v) => setState(() => _isSuperuser = v),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ===================================================================
          // CARD 2: مصفوفة الصلاحيات المخصصة (matching Accordion in newuser.html)
          // ===================================================================
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_open_rounded, color: AppColors.primary, size: 22),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'مصفوفة الصلاحيات المخصصة',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: allChecked ? AppColors.error : const Color(0xFF2563EB),
                        side: BorderSide(color: allChecked ? AppColors.error : const Color(0xFF2563EB)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
                      ),
                      onPressed: _toggleAllPermissions,
                      child: Text(
                        allChecked ? 'إلغاء الكل' : 'تحديد / إلغاء الكل',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if ((widget.user?['groups'] as List<dynamic>? ?? const []).isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      'تنبيه: المستخدم عضو في مجموعات (${(widget.user!['groups'] as List).map((g) => g is Map ? g['name'] : g).join('، ')})؛ الاختيارات أدناه تتحكم في الصلاحيات المخصصة المباشرة فقط.',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Color(0xFF92400E), fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Quick Permission Search
                TextField(
                  controller: _permSearchCtrl,
                  onChanged: (v) => setState(() => _permQuery = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'ابحث في الصلاحيات (مثال: الطلبات، الفواتير، الرواتب، الخزينة)...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 19, color: AppColors.textMuted),
                    suffixIcon: _permQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 17),
                            onPressed: () {
                              _permSearchCtrl.clear();
                              setState(() => _permQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  ),
                ),
                const SizedBox(height: 12),

                // Accordion Categories from models.permission_groups
                ...List.generate(widget.permissionMatrix.length, (idx) {
                  final grp = widget.permissionMatrix[idx];
                  final groupName = grp['group_name']?.toString() ?? '';
                  final groupColor = _resolveMatrixColor(grp['color']?.toString() ?? '');
                  final groupIcon = _resolveMatrixIcon(grp['icon']?.toString() ?? '');
                  final rawPerms = (grp['permissions'] as List<dynamic>? ?? [])
                      .map((e) => Map<String, dynamic>.from(e as Map))
                      .toList();

                  final visiblePerms = _permQuery.isEmpty
                      ? rawPerms
                      : rawPerms.where((p) {
                          final lbl = p['label']?.toString().toLowerCase() ?? '';
                          final code = p['codename']?.toString().toLowerCase() ?? '';
                          return lbl.contains(_permQuery) ||
                              code.contains(_permQuery) ||
                              groupName.toLowerCase().contains(_permQuery);
                        }).toList();

                  if (visiblePerms.isEmpty) return const SizedBox.shrink();

                  final groupCodes = rawPerms.map((p) => p['codename']?.toString() ?? '').where((c) => c.isNotEmpty).toSet();
                  final enabledInGroup = groupCodes.where(_selectedCodenames.contains).length;
                  final allGroupSelected = groupCodes.isNotEmpty && enabledInGroup == groupCodes.length;

                  return Container(
                    key: ValueKey('$groupName-${_permQuery.isNotEmpty}'),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: enabledInGroup > 0 ? groupColor.withValues(alpha: 0.45) : AppColors.border,
                      ),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: _permQuery.isNotEmpty || idx == 0,
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: groupColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(groupIcon, color: groupColor, size: 20),
                        ),
                        title: Text(
                          groupName,
                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textPrimary),
                        ),
                        subtitle: Row(
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 3),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                              decoration: BoxDecoration(
                                color: enabledInGroup > 0 ? AppColors.primary.withValues(alpha: 0.14) : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$enabledInGroup / ${groupCodes.length} مفعلة',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: enabledInGroup > 0 ? AppColors.primaryDark : AppColors.textSecondary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  if (allGroupSelected) {
                                    _selectedCodenames.removeAll(groupCodes);
                                  } else {
                                    _selectedCodenames.addAll(groupCodes);
                                  }
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(top: 3),
                                child: Text(
                                  allGroupSelected ? 'إلغاء القسم' : 'تحديد القسم',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: allGroupSelected ? AppColors.error : groupColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(bottom: Radius.circular(13)),
                            ),
                            child: Column(
                              children: visiblePerms.map((perm) {
                                final code = perm['codename']?.toString() ?? '';
                                final label = perm['label']?.toString() ?? code;
                                final active = _selectedCodenames.contains(code);
                                return Container(
                                  decoration: BoxDecoration(
                                    color: active ? AppColors.primary.withValues(alpha: 0.05) : Colors.white,
                                    border: Border(top: BorderSide(color: Colors.grey.shade100)),
                                  ),
                                  child: SwitchListTile(
                                    dense: true,
                                    activeColor: AppColors.primary,
                                    value: active,
                                    title: Text(
                                      label,
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 12.5,
                                        fontWeight: active ? FontWeight.bold : FontWeight.w500,
                                        color: active ? AppColors.textPrimary : AppColors.textSecondary,
                                      ),
                                    ),
                                    onChanged: (val) {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        if (val) {
                                          _selectedCodenames.add(code);
                                        } else {
                                          _selectedCodenames.remove(code);
                                        }
                                      });
                                    },
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
