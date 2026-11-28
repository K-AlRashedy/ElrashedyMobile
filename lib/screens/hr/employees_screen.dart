import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../models/branch_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/async_views.dart';
import '../../widgets/numeric_keypad_sheet.dart';

class EmployeesScreen extends StatefulWidget {
  final bool openCreate;

  const EmployeesScreen({
    super.key,
    this.openCreate = false,
  });

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _employees = [];
  String _searchQuery = '';
  String _activeFilter = 'active'; // active | inactive | all
  int? _selectedBranchId;
  bool _initialized = false;

  ApiClient get _api => context.read<ApiClient>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _loadEmployees();
        if (widget.openCreate && mounted) {
          _showEmployeeForm();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final params = <String, dynamic>{
        'page_size': '100',
        if (_activeFilter == 'active') 'is_active': 'true',
        if (_activeFilter == 'inactive') 'is_active': 'false',
        if (_selectedBranchId != null)
          'branch_id': _selectedBranchId.toString(),
      };
      final res = await _api.get('/api/v1/hr/employees/', queryParams: params);
      if (!mounted) return;
      if (res is Map<String, dynamic>) {
        final raw = res['results'] as List<dynamic>? ?? [];
        setState(() {
          _employees = raw.whereType<Map<String, dynamic>>().toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'استجابة غير متوقعة من الخادم';
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

  Future<void> _archiveOrReactivate(Map<String, dynamic> emp) async {
    final isActive = emp['is_active'] != false;
    final id = emp['id'] as int;

    if (!isActive) {
      final confirmed = await AppConfirmDialog.show(
        context,
        title: 'إعادة تفعيل موظف',
        message: 'هل تريد إعادة تفعيل الموظف "${emp['name']}" على رأس العمل؟',
        confirmLabel: 'تفعيل',
      );
      if (!confirmed || !mounted) return;
      try {
        await _api.post('/api/v1/hr/employees/$id/reactivate/', body: {});
        if (!mounted) return;
        AppFeedback.showSuccess(context, 'تمت إعادة تفعيل الموظف بنجاح');
        _loadEmployees();
      } catch (e) {
        if (!mounted) return;
        AppFeedback.showError(context, e.toString());
      }
      return;
    }

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _ArchiveEmployeeDialog(name: '${emp['name'] ?? ''}'),
    );
    if (result == null || !mounted) return;

    try {
      await _api.post(
        '/api/v1/hr/employees/$id/archive/',
        body: {
          'layoff_date': result['date'],
          'layoff_reason': result['reason'],
        },
      );
      if (!mounted) return;
      AppFeedback.showSuccess(context, 'تم أرشفة الموظف بنجاح');
      _loadEmployees();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, e.toString());
    }
  }

  Future<void> _showEmployeeForm({Map<String, dynamic>? employee}) async {
    final auth = context.read<AuthProvider>();
    final branches =
        auth.userBranches.isNotEmpty ? auth.userBranches : auth.allBranches;
    final isSuperuser = auth.user?.isSuperuser == true;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _EmployeeFormSheet(
        api: _api,
        branches: branches,
        isSuperuser: isSuperuser,
        employee: employee,
      ),
    );
    if (saved == true && mounted) {
      AppFeedback.showSuccess(
        context,
        employee == null
            ? 'تم تسجيل الموظف بنجاح'
            : 'تم حفظ بيانات الموظف بنجاح',
      );
      _loadEmployees();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final branches =
        auth.userBranches.isNotEmpty ? auth.userBranches : auth.allBranches;
    final filtered = _employees.where((e) {
      final name = e['name']?.toString().toLowerCase() ?? '';
      final job = e['job_title']?.toString().toLowerCase() ?? '';
      final phone = e['phone']?.toString().toLowerCase() ?? '';
      final q = _searchQuery.trim().toLowerCase();
      return q.isEmpty ||
          name.contains(q) ||
          job.contains(q) ||
          phone.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'سجل الموظفين والرواتب',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loadEmployees,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text(
          'موظف جديد',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showEmployeeForm(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'ابحث باسم الموظف أو الوظيفة أو الهاتف...',
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                if (branches.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    value: branches.any((b) => b.id == _selectedBranchId)
                        ? _selectedBranchId
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'تصفية حسب الفرع',
                      isDense: true,
                      prefixIcon: Icon(Icons.store_mall_directory_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text(
                          'كل الفروع',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 13),
                        ),
                      ),
                      ...branches.map(
                        (b) => DropdownMenuItem<int?>(
                          value: b.id,
                          child: Text(
                            b.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedBranchId = val);
                      _loadEmployees();
                    },
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ChoiceChip(
                  label: Text(
                    'على رأس العمل',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _activeFilter == 'active'
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                  selected: _activeFilter == 'active',
                  selectedColor: AppColors.primary,
                  onSelected: (_) {
                    setState(() => _activeFilter = 'active');
                    _loadEmployees();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(
                    'المؤرشفون',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _activeFilter == 'inactive'
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                  selected: _activeFilter == 'inactive',
                  selectedColor: AppColors.primary,
                  onSelected: (_) {
                    setState(() => _activeFilter = 'inactive');
                    _loadEmployees();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(
                    'الكل',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _activeFilter == 'all'
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                  selected: _activeFilter == 'all',
                  selectedColor: AppColors.primary,
                  onSelected: (_) {
                    setState(() => _activeFilter = 'all');
                    _loadEmployees();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const AppLoadingView(message: 'جاري تحميل الموظفين...')
                : _error != null
                    ? AppErrorView(message: _error!, onRetry: _loadEmployees)
                    : filtered.isEmpty
                        ? AppEmptyView(
                            title: 'لا يوجد موظفون مطابقون',
                            icon: Icons.people_outline,
                            actionLabel: 'إضافة موظف جديد',
                            onAction: () => _showEmployeeForm(),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadEmployees,
                            color: AppColors.primary,
                            child: ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 92),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final emp = filtered[i];
                                final isActive = emp['is_active'] != false;
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor: isActive
                                            ? AppColors.primarySoft
                                            : Colors.grey.shade200,
                                        child: Text(
                                          (emp['name']?.toString().isNotEmpty ==
                                                      true
                                                  ? emp['name'][0]
                                                  : 'E')
                                              .toUpperCase(),
                                          style: TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            color: isActive
                                                ? AppColors.primary
                                                : AppColors.textMuted,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              emp['name']?.toString() ?? '',
                                              style: const TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              '${emp['job_title'] ?? 'موظف'} • ${emp['branch_name'] ?? ''}',
                                              style: const TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'الأساسي: ${emp['basic_salary']} ج.م • ${isActive ? 'نشط' : 'مؤرشف (${emp['layoff_reason'] ?? ''})'}',
                                              style: TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                                color: isActive
                                                    ? AppColors.success
                                                    : AppColors.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'تعديل',
                                        constraints: const BoxConstraints(
                                          minWidth: 44,
                                          minHeight: 44,
                                        ),
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 20,
                                          color: AppColors.info,
                                        ),
                                        onPressed: () =>
                                            _showEmployeeForm(employee: emp),
                                      ),
                                      IconButton(
                                        constraints: const BoxConstraints(
                                          minWidth: 44,
                                          minHeight: 44,
                                        ),
                                        icon: Icon(
                                          isActive
                                              ? Icons.person_off_outlined
                                              : Icons.person_add_alt_1_outlined,
                                          size: 20,
                                          color: isActive
                                              ? AppColors.error
                                              : AppColors.success,
                                        ),
                                        tooltip: isActive
                                            ? 'أرشفة / إنهاء خدمة'
                                            : 'إعادة تفعيل',
                                        onPressed: () =>
                                            _archiveOrReactivate(emp),
                                      ),
                                    ],
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

class _ArchiveEmployeeDialog extends StatefulWidget {
  final String name;

  const _ArchiveEmployeeDialog({required this.name});

  @override
  State<_ArchiveEmployeeDialog> createState() => _ArchiveEmployeeDialogState();
}

class _ArchiveEmployeeDialogState extends State<_ArchiveEmployeeDialog> {
  late final TextEditingController _dateCtrl;
  final TextEditingController _reasonCtrl = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _dateCtrl = TextEditingController(
      text: DateTime.now().toIso8601String().split('T').first,
    );
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'إيقاف / أرشفة ${widget.name}',
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              AppInlineError(message: _error!),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _dateCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'تاريخ ترك العمل *',
                prefixIcon: Icon(Icons.event_outlined),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  _dateCtrl.text = picked.toIso8601String().split('T').first;
                }
              },
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'سبب إنهاء الخدمة / الأرشفة *',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () {
            final reason = _reasonCtrl.text.trim();
            if (reason.isEmpty) {
              setState(() => _error = 'أدخل سبب الأرشفة أو ترك العمل.');
              return;
            }
            Navigator.pop(context, {
              'date': _dateCtrl.text.trim(),
              'reason': reason,
            });
          },
          child:
              const Text('أرشفة الموظف', style: TextStyle(fontFamily: 'Cairo')),
        ),
      ],
    );
  }
}

class _EmployeeFormSheet extends StatefulWidget {
  final ApiClient api;
  final List<BranchModel> branches;
  final bool isSuperuser;
  final Map<String, dynamic>? employee;

  const _EmployeeFormSheet({
    required this.api,
    required this.branches,
    required this.isSuperuser,
    this.employee,
  });

  @override
  State<_EmployeeFormSheet> createState() => _EmployeeFormSheetState();
}

class _EmployeeFormSheetState extends State<_EmployeeFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _nationalIdController;
  late final TextEditingController _phoneController;
  late final TextEditingController _fatherPhoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _jobTitleController;
  late final TextEditingController _dateJoinedCtrl;
  late final TextEditingController _salaryController;
  late final TextEditingController _allowancesCtrl;
  late final TextEditingController _safeAllowCtrl;
  late final TextEditingController _transportAllowCtrl;
  late final TextEditingController _nightShiftAllowCtrl;
  late final TextEditingController _otherAllowCtrl;

  late int? _selectedBranchId;
  late String _shiftType;
  late bool _isInsured;
  late bool _isOwner;
  bool _isSubmitting = false;
  String? _formError;

  List<BranchModel> get _selectableBranches {
    final list = List<BranchModel>.from(widget.branches);
    final empBranchId = widget.employee?['branch_id'] as int?;
    if (empBranchId != null && !list.any((b) => b.id == empBranchId)) {
      list.insert(
        0,
        BranchModel(
          id: empBranchId,
          name: widget.employee?['branch_name']?.toString() ?? 'فرع #$empBranchId',
          type: 'SHOP',
        ),
      );
    }
    return list;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.employee;
    _nameController = TextEditingController(text: e?['name']?.toString() ?? '');
    _nationalIdController =
        TextEditingController(text: e?['national_id']?.toString() ?? '');
    _phoneController =
        TextEditingController(text: e?['phone']?.toString() ?? '');
    _fatherPhoneController =
        TextEditingController(text: e?['father_phone']?.toString() ?? '');
    _addressController =
        TextEditingController(text: e?['address']?.toString() ?? '');
    _jobTitleController =
        TextEditingController(text: e?['job_title']?.toString() ?? '');
    _dateJoinedCtrl = TextEditingController(
      text: e?['date_joined']?.toString() ??
          DateTime.now().toIso8601String().split('T').first,
    );
    _salaryController =
        TextEditingController(text: (e?['basic_salary'] ?? '0').toString());
    _allowancesCtrl =
        TextEditingController(text: (e?['allowances'] ?? '0').toString());
    _safeAllowCtrl =
        TextEditingController(text: (e?['safe_allowance'] ?? '0').toString());
    _transportAllowCtrl = TextEditingController(
      text: (e?['transport_allowance'] ?? '0').toString(),
    );
    _nightShiftAllowCtrl = TextEditingController(
      text: (e?['night_shift_allowance'] ?? '0').toString(),
    );
    _otherAllowCtrl =
        TextEditingController(text: (e?['other_allowances'] ?? '0').toString());

    _selectedBranchId = e?['branch_id'] as int? ??
        (widget.branches.isNotEmpty ? widget.branches.first.id : null);
    final rawShift = e?['shift_type']?.toString() ?? 'morning';
    _shiftType =
        (rawShift == 'morning' || rawShift == 'evening') ? rawShift : 'morning';
    _isInsured = e?['is_insured'] == true;
    _isOwner = e?['is_owner'] == true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nationalIdController.dispose();
    _phoneController.dispose();
    _fatherPhoneController.dispose();
    _addressController.dispose();
    _jobTitleController.dispose();
    _dateJoinedCtrl.dispose();
    _salaryController.dispose();
    _allowancesCtrl.dispose();
    _safeAllowCtrl.dispose();
    _transportAllowCtrl.dispose();
    _nightShiftAllowCtrl.dispose();
    _otherAllowCtrl.dispose();
    super.dispose();
  }

  String? _parseMoneyField(TextEditingController ctrl, String fieldName) {
    final text = ctrl.text.trim();
    if (text.isEmpty) return '0';
    final v = double.tryParse(text);
    if (v == null || v < 0) {
      setState(() => _formError = 'قيمة "$fieldName" غير صالحة.');
      return null;
    }
    return AppNumericKeypadSheet.formatNumber(v);
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _formError = 'أدخل الاسم الكامل للموظف.');
      return;
    }
    if (_selectedBranchId == null) {
      setState(() => _formError = 'اختر فرع العمل.');
      return;
    }

    final salary = _parseMoneyField(_salaryController, 'الراتب الأساسي');
    final allowances = _parseMoneyField(_allowancesCtrl, 'بدلات أساسية');
    final safeAllow = _parseMoneyField(_safeAllowCtrl, 'بدل خزنة/عهدة');
    final transportAllow =
        _parseMoneyField(_transportAllowCtrl, 'بدل انتقالات');
    final nightAllow =
        _parseMoneyField(_nightShiftAllowCtrl, 'بدل سهر/مسائي');
    final otherAllow = _parseMoneyField(_otherAllowCtrl, 'بدلات أخرى');
    if (salary == null ||
        allowances == null ||
        safeAllow == null ||
        transportAllow == null ||
        nightAllow == null ||
        otherAllow == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _formError = null;
    });

    try {
      final payload = <String, dynamic>{
        'name': name,
        'national_id': _nationalIdController.text.trim(),
        'phone': _phoneController.text.trim(),
        'father_phone': _fatherPhoneController.text.trim(),
        'address': _addressController.text.trim(),
        'job_title': _jobTitleController.text.trim(),
        'date_joined': _dateJoinedCtrl.text.trim(),
        'branch_id': _selectedBranchId,
        'shift_type': _shiftType,
        'basic_salary': salary,
        'allowances': allowances,
        'safe_allowance': safeAllow,
        'transport_allowance': transportAllow,
        'night_shift_allowance': nightAllow,
        'other_allowances': otherAllow,
        'is_insured': _isInsured,
        if (widget.isSuperuser) 'is_owner': _isOwner,
      };
      if (widget.employee == null) {
        await widget.api.post('/api/v1/hr/employees/create/', body: payload);
      } else {
        await widget.api.put(
          '/api/v1/hr/employees/${widget.employee!['id']}/update/',
          body: payload,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _formError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final branches = _selectableBranches;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.employee == null
                        ? 'إضافة موظف جديد'
                        : 'تعديل بيانات الموظف',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _isSubmitting ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_formError != null) ...[
                AppInlineError(message: _formError!),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'الاسم الكامل *',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppNumericField(
                      controller: _phoneController,
                      label: 'رقم الهاتف',
                      dialogTitle: 'رقم هاتف الموظف',
                      isStringMode: true,
                      allowDecimal: false,
                      maxLength: 15,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppNumericField(
                      controller: _fatherPhoneController,
                      label: 'هاتف ولي الأمر / قريب',
                      dialogTitle: 'هاتف ولي الأمر / قريب',
                      isStringMode: true,
                      allowDecimal: false,
                      maxLength: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppNumericField(
                      controller: _nationalIdController,
                      label: 'الرقم القومي',
                      dialogTitle: 'الرقم القومي (14 رقماً)',
                      isStringMode: true,
                      allowDecimal: false,
                      maxLength: 14,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _jobTitleController,
                      decoration: const InputDecoration(
                        labelText: 'المسمى الوظيفي',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(labelText: 'العنوان'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (branches.isNotEmpty)
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'فرع العمل *',
                        ),
                        value: branches.any((b) => b.id == _selectedBranchId)
                            ? _selectedBranchId
                            : branches.first.id,
                        items: branches
                            .map(
                              (b) => DropdownMenuItem<int>(
                                value: b.id,
                                child: Text(
                                  b.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontFamily: 'Cairo'),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedBranchId = val),
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'الوردية'),
                      value: _shiftType,
                      items: const [
                        DropdownMenuItem(
                          value: 'morning',
                          child: Text(
                            'صباحية',
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'evening',
                          child: Text(
                            'مسائية',
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                        ),
                      ],
                      onChanged: (val) =>
                          setState(() => _shiftType = val ?? 'morning'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'الراتب الأساسي والبدلات الشهرية (ج.م):',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: AppNumericField(
                      controller: _salaryController,
                      label: 'الراتب الأساسي *',
                      unit: 'ج.م',
                      allowDecimal: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppNumericField(
                      controller: _allowancesCtrl,
                      label: 'بدلات أساسية',
                      unit: 'ج.م',
                      allowDecimal: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppNumericField(
                      controller: _transportAllowCtrl,
                      label: 'بدل انتقالات',
                      unit: 'ج.م',
                      allowDecimal: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppNumericField(
                      controller: _safeAllowCtrl,
                      label: 'بدل خزنة/عهدة',
                      unit: 'ج.م',
                      allowDecimal: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppNumericField(
                      controller: _nightShiftAllowCtrl,
                      label: 'بدل سهر/مسائي',
                      unit: 'ج.م',
                      allowDecimal: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppNumericField(
                      controller: _otherAllowCtrl,
                      label: 'بدلات أخرى',
                      unit: 'ج.م',
                      allowDecimal: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'مؤمن عليه اجتماعياً',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 14),
                ),
                value: _isInsured,
                onChanged: (val) => setState(() => _isInsured = val),
              ),
              if (widget.isSuperuser)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'شريك / مالك (Owner)',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 14),
                  ),
                  value: _isOwner,
                  onChanged: (val) => setState(() => _isOwner = val),
                ),
              const SizedBox(height: 14),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.employee == null
                            ? 'تسجيل الموظف'
                            : 'حفظ التعديلات',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
