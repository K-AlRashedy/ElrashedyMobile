import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/async_views.dart';
import '../../widgets/numeric_keypad_sheet.dart';

class MasterDataScreen extends StatefulWidget {
  final int initialTab;
  final bool openCreate;

  const MasterDataScreen({super.key, this.initialTab = 0, this.openCreate = false});

  @override
  State<MasterDataScreen> createState() => _MasterDataScreenState();
}

class _MasterDataScreenState extends State<MasterDataScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  final _uuid = const Uuid();

  bool _isLoading = true;
  final List<String?> _tabErrors = [null, null, null, null];

  List<Map<String, dynamic>> _units = [];
  List<Map<String, dynamic>> _branches = [];
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _accounts = [];

  String _branchTypeFilter = '';
  String _accountStatusFilter = 'all';

  ApiClient get _api => context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    final safeIndex = widget.initialTab.clamp(0, 3);
    _tabController = TabController(length: 4, vsync: this, initialIndex: safeIndex);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadAll();
      if (widget.openCreate && mounted) _openCreateForCurrentTab();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _extractList(dynamic res) {
    if (res is Map<String, dynamic>) {
      final list = res['results'] as List<dynamic>? ?? [];
      return list.whereType<Map<String, dynamic>>().toList();
    }
    if (res is List) return res.whereType<Map<String, dynamic>>().toList();
    return [];
  }

  Future<void> _fetchTab(int index, Future<dynamic> Function() call, void Function(List<Map<String, dynamic>>) apply) async {
    _tabErrors[index] = null;
    try {
      final res = await call();
      apply(_extractList(res));
    } catch (e) {
      _tabErrors[index] = e.toString();
    }
  }

  Future<void> _loadAll() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchTab(0, () => _api.get('/api/v1/catalog/units/', queryParams: {'page_size': '100'}), (v) => _units = v),
      _fetchTab(1, () => _api.get('/api/v1/catalog/branches/', queryParams: {'page_size': '100'}), (v) => _branches = v),
      _fetchTab(2, () => _api.get('/api/v1/catalog/stores/', queryParams: {'page_size': '100'}), (v) => _stores = v),
      _fetchTab(3, () => _api.get('/api/v1/catalog/accounts/', queryParams: {'page_size': '100', 'include_inactive': 'true'}), (v) => _accounts = v),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  void _openCreateForCurrentTab() {
    switch (_tabController.index) {
      case 0:
        _showUnitFormSheet();
        break;
      case 1:
        _showBranchFormSheet();
        break;
      case 2:
        _showStoreFormSheet();
        break;
      case 3:
        _showAccountFormSheet();
        break;
    }
  }

  Future<void> _confirmDelete({
    required String title,
    required String endpoint,
    required String successMessage,
    bool refreshAuth = false,
  }) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'تأكيد الحذف',
      message: 'هل أنت متأكد من حذف "$title" نهائياً؟',
      confirmLabel: 'حذف',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await _api.delete(endpoint);
      if (!mounted) return;
      AppFeedback.showSuccess(context, successMessage);
      if (refreshAuth) {
        await context.read<AuthProvider>().refreshSession();
      }
      await _loadAll();
    } catch (e) {
      if (mounted) AppFeedback.showError(context, e.toString());
    }
  }

  Future<void> _showUnitFormSheet({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final rNameCtrl = TextEditingController(text: existing?['retail_name']?.toString() ?? '');
    final rsCtrl = TextEditingController(text: (existing?['retail_size'] ?? 1).toString());
    final sNameCtrl = TextEditingController(text: existing?['stock_name']?.toString() ?? '');
    final smCtrl = TextEditingController(text: (existing?['stock_size'] ?? 1).toString());
    final mNameCtrl = TextEditingController(text: existing?['minimum_name']?.toString() ?? '');
    bool submitting = false;
    String? formError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final previewFormula =
              '${rNameCtrl.text.isEmpty ? "وحدة الشراء" : rNameCtrl.text} = ${rsCtrl.text.isEmpty ? "1" : rsCtrl.text} × ${sNameCtrl.text.isEmpty ? "وحدة المخزن" : sNameCtrl.text} (وكل 1 ${sNameCtrl.text.isEmpty ? "مخزن" : sNameCtrl.text} = ${smCtrl.text.isEmpty ? "1" : smCtrl.text} × ${mNameCtrl.text.isEmpty ? "أصغر وحدة" : mNameCtrl.text})';

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(isEdit ? 'تعديل وحدة القياس' : 'إضافة وحدة قياس جديدة', style: const TextStyle(fontFamily: 'Cairo', fontSize: 17.5, fontWeight: FontWeight.bold))),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(sheetCtx)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AppInlineError(message: formError),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                      child: Text(previewFormula, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.primaryDark, fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(controller: rNameCtrl, onChanged: (_) => setSheetState(() {}), decoration: const InputDecoration(labelText: 'وحدة الشراء الكبرى *')),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppNumericField(
                            controller: rsCtrl,
                            label: 'المعامل *',
                            allowDecimal: false,
                            onChanged: (_) => setSheetState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(controller: sNameCtrl, onChanged: (_) => setSheetState(() {}), decoration: const InputDecoration(labelText: 'وحدة المخزن المتوسطة *')),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppNumericField(
                            controller: smCtrl,
                            label: 'المعامل *',
                            allowDecimal: false,
                            onChanged: (_) => setSheetState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: mNameCtrl, onChanged: (_) => setSheetState(() {}), decoration: const InputDecoration(labelText: 'أصغر وحدة تشغيل/وصفة *')),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: submitting
                          ? null
                          : () async {
                              final rName = rNameCtrl.text.trim();
                              final sName = sNameCtrl.text.trim();
                              final mName = mNameCtrl.text.trim();
                              final rs = int.tryParse(rsCtrl.text.trim()) ?? 0;
                              final sm = int.tryParse(smCtrl.text.trim()) ?? 0;
                              if (rName.isEmpty || sName.isEmpty || mName.isEmpty || rs < 1 || sm < 1) {
                                setSheetState(() => formError = 'أكمل أسماء الوحدات وتأكد أن معاملات التحويل ≥ 1.');
                                return;
                              }
                              setSheetState(() { submitting = true; formError = null; });
                              final body = {'Rname': rName, 'R_S': rs, 'Sname': sName, 'S_M': sm, 'Mname': mName};
                              try {
                                if (isEdit) {
                                  await _api.put('/api/v1/catalog/units/${existing['id']}/update/', idempotencyKey: _uuid.v4(), body: body);
                                } else {
                                  await _api.post('/api/v1/catalog/units/create/', idempotencyKey: _uuid.v4(), body: body);
                                }
                                if (!mounted) return;
                                Navigator.pop(sheetCtx);
                                AppFeedback.showSuccess(context, isEdit ? 'تم تحديث الوحدة بنجاح' : 'تمت إضافة الوحدة بنجاح');
                                await _loadAll();
                              } catch (e) {
                                if (ctx.mounted) setSheetState(() { submitting = false; formError = e.toString(); });
                              }
                            },
                      child: submitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(isEdit ? 'حفظ التعديلات' : 'حفظ الوحدة'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    rNameCtrl.dispose();
    rsCtrl.dispose();
    sNameCtrl.dispose();
    smCtrl.dispose();
    mNameCtrl.dispose();
  }

  Future<void> _showBranchFormSheet({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final auth = context.read<AuthProvider>();
    final isSuperuser = auth.user?.isSuperuser == true;

    final nameCtrl = TextEditingController(text: existing?['name']?.toString() ?? '');
    String selectedType = existing?['type']?.toString() ?? 'SHOP';
    int? selectedParentId = existing?['parent_id'] as int?;
    int? selectedStoreId = existing?['store_id'] as int?;
    bool isSuper = existing?['is_super'] == true;
    bool submitting = false;
    String? formError;

    final parentChoices = _branches.where((b) => b['id'] != existing?['id'] && b['type'] != 'section').toList();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(isEdit ? 'تعديل الفرع / القسم' : 'إضافة فرع أو قسم جديد', style: const TextStyle(fontFamily: 'Cairo', fontSize: 17.5, fontWeight: FontWeight.bold))),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(sheetCtx)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AppInlineError(message: formError),
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الفرع / القسم *')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'نوع الكيان *'),
                    items: const [
                      DropdownMenuItem(value: 'SHOP', child: Text('فرع بيع / محل (SHOP)', style: TextStyle(fontFamily: 'Cairo'))),
                      DropdownMenuItem(value: 'FACTORY', child: Text('مصنع (FACTORY)', style: TextStyle(fontFamily: 'Cairo'))),
                      DropdownMenuItem(value: 'store', child: Text('مخزن فرعي (store)', style: TextStyle(fontFamily: 'Cairo'))),
                      DropdownMenuItem(value: 'section', child: Text('قسم داخلي (section)', style: TextStyle(fontFamily: 'Cairo'))),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      setSheetState(() {
                        selectedType = val;
                        if (selectedType != 'section') selectedParentId = null;
                      });
                    },
                  ),
                  if (selectedType == 'section') ...[
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int?>(
                      isExpanded: true,
                      value: parentChoices.any((b) => b['id'] == selectedParentId) ? selectedParentId : null,
                      decoration: const InputDecoration(labelText: 'الفرع التابع له القسم'),
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('— بدون فرع أب —', style: TextStyle(fontFamily: 'Cairo'))),
                        ...parentChoices.map((b) => DropdownMenuItem<int?>(value: b['id'] as int, child: Text('${b['name']}', style: const TextStyle(fontFamily: 'Cairo')))),
                      ],
                      onChanged: (val) => setSheetState(() => selectedParentId = val),
                    ),
                  ],
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    value: _stores.any((s) => s['id'] == selectedStoreId) ? selectedStoreId : null,
                    decoration: const InputDecoration(labelText: 'نوع المخزن المرتبط'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('— بدون ربط مخزن —', style: TextStyle(fontFamily: 'Cairo'))),
                      ..._stores.map((s) => DropdownMenuItem<int?>(value: s['id'] as int, child: Text('${s['name']} (${s['type']})', style: const TextStyle(fontFamily: 'Cairo')))),
                    ],
                    onChanged: (val) => setSheetState(() => selectedStoreId = val),
                  ),
                  if (isSuperuser) ...[
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('فرع / قسم مركزي عام (Super)', style: TextStyle(fontFamily: 'Cairo')),
                      value: isSuper,
                      onChanged: (val) => setSheetState(() => isSuper = val),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) {
                              setSheetState(() => formError = 'يرجى إدخال اسم الفرع أو القسم.');
                              return;
                            }
                            setSheetState(() { submitting = true; formError = null; });
                            final body = <String, dynamic>{
                              'name': name,
                              'type': selectedType,
                              'parent_id': selectedType == 'section' ? selectedParentId : null,
                              'store_id': selectedStoreId,
                              if (isSuperuser) 'is_super': isSuper,
                            };
                            try {
                              if (isEdit) {
                                await _api.put('/api/v1/catalog/branches/${existing['id']}/update/', idempotencyKey: _uuid.v4(), body: body);
                              } else {
                                await _api.post('/api/v1/catalog/branches/create/', idempotencyKey: _uuid.v4(), body: body);
                              }
                              if (!mounted) return;
                              Navigator.pop(sheetCtx);
                              AppFeedback.showSuccess(context, isEdit ? 'تم تحديث الفرع بنجاح' : 'تمت إضافة الفرع بنجاح');
                              await auth.refreshSession();
                              await _loadAll();
                            } catch (e) {
                              if (ctx.mounted) setSheetState(() { submitting = false; formError = e.toString(); });
                            }
                          },
                    child: submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(isEdit ? 'حفظ التعديلات' : 'حفظ الفرع'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    nameCtrl.dispose();
  }

  Future<void> _showStoreFormSheet({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?['name']?.toString() ?? '');
    String selectedType = existing?['type']?.toString() ?? 'SHOP';
    bool submitting = false;
    String? formError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(isEdit ? 'تعديل نوع المخزن' : 'إضافة نوع مخزن جديد', style: const TextStyle(fontFamily: 'Cairo', fontSize: 17.5, fontWeight: FontWeight.bold))),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(sheetCtx)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AppInlineError(message: formError),
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المخزن / التصنيف المخزني *')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedType,
                    decoration: const InputDecoration(labelText: 'طبيعة المخزن *'),
                    items: const [
                      DropdownMenuItem(value: 'SHOP', child: Text('مخزن فروع ومبيعات (SHOP)', style: TextStyle(fontFamily: 'Cairo'))),
                      DropdownMenuItem(value: 'FACTORY', child: Text('مخزن مصنع وإنتاج (FACTORY)', style: TextStyle(fontFamily: 'Cairo'))),
                    ],
                    onChanged: (val) {
                      if (val != null) setSheetState(() => selectedType = val);
                    },
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) {
                              setSheetState(() => formError = 'يرجى إدخال اسم نوع المخزن.');
                              return;
                            }
                            setSheetState(() { submitting = true; formError = null; });
                            final body = {'name': name, 'type': selectedType};
                            try {
                              if (isEdit) {
                                await _api.put('/api/v1/catalog/stores/${existing['id']}/update/', idempotencyKey: _uuid.v4(), body: body);
                              } else {
                                await _api.post('/api/v1/catalog/stores/create/', idempotencyKey: _uuid.v4(), body: body);
                              }
                              if (!mounted) return;
                              Navigator.pop(sheetCtx);
                              AppFeedback.showSuccess(context, isEdit ? 'تم تحديث المخزن بنجاح' : 'تمت إضافة المخزن بنجاح');
                              await _loadAll();
                            } catch (e) {
                              if (ctx.mounted) setSheetState(() { submitting = false; formError = e.toString(); });
                            }
                          },
                    child: submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(isEdit ? 'حفظ التعديلات' : 'حفظ المخزن'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    nameCtrl.dispose();
  }

  Future<void> _showAccountFormSheet({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final auth = context.read<AuthProvider>();
    final branches = (auth.allBranches.isNotEmpty ? auth.allBranches : auth.userBranches)
        .map((b) => {'id': b.id, 'name': b.name})
        .toList();

    final nameCtrl = TextEditingController(text: existing?['name']?.toString() ?? '');
    int? selectedParentId = existing?['parent_id'] as int?;
    int? selectedDefaultBranchId = existing?['default_branch_id'] as int?;
    if (selectedDefaultBranchId != null && !branches.any((b) => b['id'] == selectedDefaultBranchId)) {
      final db = existing?['default_branch'] as Map<String, dynamic>?;
      branches.add({'id': selectedDefaultBranchId, 'name': db?['name'] ?? 'فرع #$selectedDefaultBranchId'});
    }

    bool isActive = existing?['is_active'] != false;
    bool visibleToCashier = existing?['visible_to_cashier'] != false;
    bool routeToCashierBranch = existing?['route_to_cashier_branch'] == true;
    bool isGeneral = existing?['is_general'] == true;
    bool isAsset = existing?['is_asset'] == true;
    bool submitting = false;
    String? formError;

    final parentOptions = _accounts.where((a) => a['id'] != existing?['id']).toList();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(isEdit ? 'تعديل بند الحساب' : 'إضافة بند حساب جديد', style: const TextStyle(fontFamily: 'Cairo', fontSize: 17.5, fontWeight: FontWeight.bold))),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(sheetCtx)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AppInlineError(message: formError),
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الحساب *')),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    value: parentOptions.any((a) => a['id'] == selectedParentId) ? selectedParentId : null,
                    decoration: const InputDecoration(labelText: 'الحساب الرئيسي الأب (اختياري)'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('— حساب رئيسي مستقل —', style: TextStyle(fontFamily: 'Cairo'))),
                      ...parentOptions.map((a) => DropdownMenuItem<int?>(value: a['id'] as int, child: Text('${a['name']}', style: const TextStyle(fontFamily: 'Cairo')))),
                    ],
                    onChanged: (val) => setSheetState(() => selectedParentId = val),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    value: branches.any((b) => b['id'] == selectedDefaultBranchId) ? selectedDefaultBranchId : null,
                    decoration: const InputDecoration(labelText: 'الفرع الافتراضي للتوجيه (اختياري)'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('— بدون فرع ثابت —', style: TextStyle(fontFamily: 'Cairo'))),
                      ...branches.map((b) => DropdownMenuItem<int?>(value: b['id'] as int, child: Text('${b['name']}', style: const TextStyle(fontFamily: 'Cairo')))),
                    ],
                    onChanged: (val) => setSheetState(() => selectedDefaultBranchId = val),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('الحساب نشط', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)), value: isActive, onChanged: (val) => setSheetState(() => isActive = val)),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('متاح للكاشير في المصروفات', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)), value: visibleToCashier, onChanged: (val) => setSheetState(() => visibleToCashier = val)),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('توجيه تلقائي لفرع الكاشير', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)), value: routeToCashierBranch, onChanged: (val) => setSheetState(() => routeToCashierBranch = val)),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('حساب عام / إداري', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)), value: isGeneral, onChanged: (val) => setSheetState(() => isGeneral = val)),
                  SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('حساب أصول رأسمالية', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)), value: isAsset, onChanged: (val) => setSheetState(() => isAsset = val)),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) {
                              setSheetState(() => formError = 'يرجى إدخال اسم الحساب.');
                              return;
                            }
                            setSheetState(() { submitting = true; formError = null; });
                            final body = {
                              'name': name,
                              'parent_id': selectedParentId,
                              'default_branch_id': selectedDefaultBranchId,
                              'is_active': isActive,
                              'visible_to_cashier': visibleToCashier,
                              'route_to_cashier_branch': routeToCashierBranch,
                              'is_general': isGeneral,
                              'is_asset': isAsset,
                            };
                            try {
                              if (isEdit) {
                                await _api.put('/api/v1/catalog/accounts/${existing['id']}/update/', idempotencyKey: _uuid.v4(), body: body);
                              } else {
                                await _api.post('/api/v1/catalog/accounts/create/', idempotencyKey: _uuid.v4(), body: body);
                              }
                              if (!mounted) return;
                              Navigator.pop(sheetCtx);
                              AppFeedback.showSuccess(context, isEdit ? 'تم تحديث الحساب بنجاح' : 'تمت إضافة الحساب بنجاح');
                              await _loadAll();
                            } catch (e) {
                              if (ctx.mounted) setSheetState(() { submitting = false; formError = e.toString(); });
                            }
                          },
                    child: submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(isEdit ? 'حفظ التعديلات' : 'حفظ الحساب'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    nameCtrl.dispose();
  }

  Future<void> _toggleAccountActive(Map<String, dynamic> account) async {
    final nextActive = !(account['is_active'] == true);
    try {
      await _api.put('/api/v1/catalog/accounts/${account['id']}/update/', idempotencyKey: _uuid.v4(), body: {'is_active': nextActive});
      if (!mounted) return;
      AppFeedback.showSuccess(context, nextActive ? 'تم استعادة تفعيل الحساب' : 'تمت أرشفة الحساب');
      await _loadAll();
    } catch (e) {
      if (mounted) AppFeedback.showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim().toLowerCase();
    final fabLabels = ['إضافة وحدة', 'إضافة فرع/قسم', 'إضافة مخزن', 'إضافة حساب'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('البيانات الأساسية والحسابات'),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث', onPressed: _loadAll)],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: 'الوحدات (${_units.length})'),
            Tab(text: 'الفروع والأقسام (${_branches.length})'),
            Tab(text: 'أنواع المخازن (${_stores.length})'),
            Tab(text: 'شجرة الحسابات (${_accounts.length})'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(fabLabels[_tabController.index], style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        onPressed: _openCreateForCurrentTab,
      ),
      body: _isLoading
          ? const AppLoadingView(message: 'جاري تحميل البيانات الأساسية...')
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'بحث سريع بالاسم...',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                      isDense: true,
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () => setState(() => _searchCtrl.clear()))
                          : null,
                    ),
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUnitsList(query),
                      _buildBranchesList(query),
                      _buildStoresList(query),
                      _buildAccountsList(query),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildUnitsList(String query) {
    if (_tabErrors[0] != null) return AppErrorView(message: _tabErrors[0]!, onRetry: _loadAll);
    final filtered = _units.where((u) => query.isEmpty || '${u['retail_name']} ${u['stock_name']} ${u['minimum_name']}'.toLowerCase().contains(query)).toList();
    if (filtered.isEmpty) return AppEmptyView(title: 'لا توجد وحدات قياس مطابقة', actionLabel: 'إضافة وحدة جديدة', onAction: () => _showUnitFormSheet());

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final u = filtered[i];
          final formula = '${u['retail_name']} = ${u['retail_size']} × ${u['stock_name']} = ${u['stock_size']} × ${u['minimum_name']}';
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Row(
              children: [
                Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.straighten_rounded, color: AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u['name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
                      const SizedBox(height: 3),
                      Text(formula, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.info, size: 20), onPressed: () => _showUnitFormSheet(existing: u)),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                  onPressed: () => _confirmDelete(title: u['name']?.toString() ?? '', endpoint: '/api/v1/catalog/units/${u['id']}/delete/', successMessage: 'تم حذف الوحدة بنجاح'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBranchesList(String query) {
    if (_tabErrors[1] != null) return AppErrorView(message: _tabErrors[1]!, onRetry: _loadAll);
    final isSuperuser = context.read<AuthProvider>().user?.isSuperuser == true;
    final filtered = _branches.where((b) {
      if (_branchTypeFilter.isNotEmpty && b['type'] != _branchTypeFilter) return false;
      if (query.isEmpty) return true;
      return (b['name']?.toString() ?? '').toLowerCase().contains(query);
    }).toList();

    const typeLabels = {'SHOP': 'فرع بيع', 'FACTORY': 'مصنع', 'store': 'مخزن', 'section': 'قسم'};

    return Column(
      children: [
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _filterChip('الكل', _branchTypeFilter.isEmpty, () => setState(() => _branchTypeFilter = '')),
              const SizedBox(width: 8),
              _filterChip('فروع بيع', _branchTypeFilter == 'SHOP', () => setState(() => _branchTypeFilter = 'SHOP')),
              const SizedBox(width: 8),
              _filterChip('مصانع', _branchTypeFilter == 'FACTORY', () => setState(() => _branchTypeFilter = 'FACTORY')),
              const SizedBox(width: 8),
              _filterChip('مخازن', _branchTypeFilter == 'store', () => setState(() => _branchTypeFilter = 'store')),
              const SizedBox(width: 8),
              _filterChip('أقسام', _branchTypeFilter == 'section', () => setState(() => _branchTypeFilter = 'section')),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: filtered.isEmpty
              ? AppEmptyView(title: 'لا توجد فروع أو أقسام مطابقة', actionLabel: 'إضافة فرع جديد', onAction: () => _showBranchFormSheet())
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final b = filtered[i];
                      final type = b['type']?.toString() ?? 'SHOP';
                      final storeMap = b['store'] as Map<String, dynamic>?;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                              child: Icon(
                                type == 'FACTORY' ? Icons.precision_manufacturing_rounded : type == 'section' ? Icons.account_tree_rounded : Icons.storefront_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(b['name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
                                      AppStatusBadge(label: typeLabels[type] ?? type, color: type == 'FACTORY' ? AppColors.accentAmber : AppColors.primary),
                                    ],
                                  ),
                                  if (storeMap != null) Text('المخزن المرتبط: ${storeMap['name']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.info, size: 20), onPressed: () => _showBranchFormSheet(existing: b)),
                            if (isSuperuser)
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                                onPressed: () => _confirmDelete(
                                  title: b['name']?.toString() ?? '',
                                  endpoint: '/api/v1/catalog/branches/${b['id']}/delete/',
                                  successMessage: 'تم حذف الفرع بنجاح',
                                  refreshAuth: true,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStoresList(String query) {
    if (_tabErrors[2] != null) return AppErrorView(message: _tabErrors[2]!, onRetry: _loadAll);
    final filtered = _stores.where((s) => query.isEmpty || (s['name']?.toString() ?? '').toLowerCase().contains(query)).toList();
    if (filtered.isEmpty) return AppEmptyView(title: 'لا توجد أنواع مخازن مطابقة', actionLabel: 'إضافة مخزن جديد', onAction: () => _showStoreFormSheet());

    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        itemCount: filtered.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final s = filtered[i];
          final isFactory = s['type'] == 'FACTORY';
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Row(
              children: [
                Container(width: 42, height: 42, decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.warehouse_rounded, color: AppColors.primary)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(s['name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
                          AppStatusBadge(label: isFactory ? 'مصنع' : 'محل/فروع', color: isFactory ? AppColors.accentAmber : AppColors.info),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text('الأصناف: ${s['product_count'] ?? 0} • الفروع المرتبطة: ${s['branch_count'] ?? 0}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.edit_outlined, color: AppColors.info, size: 20), onPressed: () => _showStoreFormSheet(existing: s)),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 20),
                  onPressed: () => _confirmDelete(title: s['name']?.toString() ?? '', endpoint: '/api/v1/catalog/stores/${s['id']}/delete/', successMessage: 'تم حذف نوع المخزن بنجاح'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAccountsList(String query) {
    if (_tabErrors[3] != null) return AppErrorView(message: _tabErrors[3]!, onRetry: _loadAll);
    final filtered = _accounts.where((a) {
      final active = a['is_active'] == true;
      if (_accountStatusFilter == 'active' && !active) return false;
      if (_accountStatusFilter == 'inactive' && active) return false;
      if (query.isEmpty) return true;
      final parentName = (a['parent'] as Map<String, dynamic>?)?['name']?.toString() ?? '';
      return '${a['name']} $parentName'.toLowerCase().contains(query);
    }).toList();

    return Column(
      children: [
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _filterChip('كل الحسابات', _accountStatusFilter == 'all', () => setState(() => _accountStatusFilter = 'all')),
              const SizedBox(width: 8),
              _filterChip('النشطة', _accountStatusFilter == 'active', () => setState(() => _accountStatusFilter = 'active')),
              const SizedBox(width: 8),
              _filterChip('المؤرشفة', _accountStatusFilter == 'inactive', () => setState(() => _accountStatusFilter = 'inactive')),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: filtered.isEmpty
              ? AppEmptyView(title: 'لا توجد حسابات مطابقة', actionLabel: 'إضافة حساب جديد', onAction: () => _showAccountFormSheet())
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final a = filtered[i];
                      final isActive = a['is_active'] == true;
                      final parentMap = a['parent'] as Map<String, dynamic>?;
                      final defaultBranch = a['default_branch'] as Map<String, dynamic>?;
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.white : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(color: isActive ? AppColors.primaryLight : Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                                  child: Icon(parentMap == null ? Icons.account_balance_rounded : Icons.subdirectory_arrow_left_rounded, color: isActive ? AppColors.primary : AppColors.textMuted),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Text(
                                            a['name']?.toString() ?? '',
                                            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: isActive ? AppColors.textPrimary : AppColors.textSecondary),
                                          ),
                                          AppStatusBadge(label: isActive ? 'نشط' : 'مؤرشف', color: isActive ? AppColors.success : AppColors.warning),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          if (parentMap != null) Text('الأب: ${parentMap['name']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.textSecondary)),
                                          if (defaultBranch != null) Text('فرع: ${defaultBranch['name']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.info)),
                                          if (a['visible_to_cashier'] == true) const Text('متاح للكاشير', style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.primary)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 14),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: Icon(isActive ? Icons.archive_outlined : Icons.unarchive_outlined, color: AppColors.warning, size: 17),
                                  label: Text(isActive ? 'أرشفة' : 'استعادة', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.warning)),
                                  onPressed: () => _toggleAccountActive(a),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.edit_outlined, color: AppColors.info, size: 17),
                                  label: const Text('تعديل', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.info)),
                                  onPressed: () => _showAccountFormSheet(existing: a),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 17),
                                  label: const Text('حذف', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.error)),
                                  onPressed: () => _confirmDelete(
                                    title: a['name']?.toString() ?? '',
                                    endpoint: '/api/v1/catalog/accounts/${a['id']}/delete/',
                                    successMessage: 'تم حذف الحساب بنجاح',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: selected ? FontWeight.bold : FontWeight.normal, color: selected ? Colors.white : AppColors.textPrimary),
      ),
      selected: selected,
      selectedColor: AppColors.primary,
      backgroundColor: Colors.white,
      onSelected: (_) => onTap(),
    );
  }
}
