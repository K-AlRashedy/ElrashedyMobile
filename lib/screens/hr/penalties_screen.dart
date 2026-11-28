import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/async_views.dart';
import '../../widgets/numeric_keypad_sheet.dart';

class PenaltiesScreen extends StatefulWidget {
  const PenaltiesScreen({super.key});

  @override
  State<PenaltiesScreen> createState() => _PenaltiesScreenState();
}

class _PenaltiesScreenState extends State<PenaltiesScreen> {
  bool _isLoading = true;
  String? _error;
  String? _employeesError;
  List<Map<String, dynamic>> _penalties = [];
  List<Map<String, dynamic>> _employees = [];
  String _statusFilter = '';
  bool _initialized = false;

  ApiClient get _api => context.read<ApiClient>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadPenalties();
      _loadEmployees();
    }
  }

  Future<void> _loadEmployees() async {
    try {
      final collected = <Map<String, dynamic>>[];
      int page = 1;
      bool hasNext = true;
      while (hasNext && page <= 10) {
        final res = await _api.get(
          '/api/v1/hr/employees/',
          queryParams: {
            'is_active': 'true',
            'page': page.toString(),
            'page_size': '100',
          },
        );
        if (!mounted) return;
        if (res is Map<String, dynamic>) {
          final raw = res['results'] as List<dynamic>? ?? [];
          collected.addAll(raw.whereType<Map<String, dynamic>>());
          final totalPages = (res['total_pages'] as num?)?.toInt() ?? 1;
          hasNext = page < totalPages && raw.isNotEmpty;
          page++;
        } else {
          hasNext = false;
        }
      }
      if (!mounted) return;
      setState(() {
        _employees = collected;
        _employeesError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _employeesError = e.toString());
      }
    }
  }

  Future<void> _loadPenalties() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.get(
        '/api/v1/hr/penalties/',
        queryParams: {
          'page_size': '80',
          if (_statusFilter.isNotEmpty) 'status': _statusFilter,
        },
      );
      if (!mounted) return;
      if (res is Map<String, dynamic>) {
        final raw = res['results'] as List<dynamic>? ?? [];
        setState(() {
          _penalties = raw.whereType<Map<String, dynamic>>().toList();
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

  Future<void> _updateStatus(int id, String status, String empName) async {
    final isApprove = status == 'approved';
    final confirmed = await AppConfirmDialog.show(
      context,
      title: isApprove ? 'اعتماد الجزاء' : 'رفض الجزاء',
      message: isApprove
          ? 'هل تريد اعتماد الجزاء الإداري على "$empName" وتطبيق الخصم؟'
          : 'هل تريد رفض الجزاء الإداري على "$empName"؟',
      confirmLabel: isApprove ? 'اعتماد وخصم' : 'رفض',
      isDestructive: isApprove,
    );
    if (!confirmed || !mounted) return;

    try {
      await _api.post(
        '/api/v1/hr/penalties/$id/status/',
        body: {'status': status},
      );
      if (!mounted) return;
      AppFeedback.showSuccess(
        context,
        isApprove ? 'تم اعتماد الجزاء وتطبيق الخصم' : 'تم رفض الجزاء',
      );
      _loadPenalties();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, e.toString());
    }
  }

  Future<void> _deletePenalty(int id, String empName) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'حذف الجزاء الإداري',
      message: 'هل تريد حذف جزاء "$empName" نهائياً؟',
      confirmLabel: 'حذف',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await _api.delete('/api/v1/hr/penalties/$id/delete/');
      if (!mounted) return;
      AppFeedback.showSuccess(context, 'تم حذف الجزاء بنجاح');
      _loadPenalties();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, e.toString());
    }
  }

  Future<void> _showPenaltyFormSheet({Map<String, dynamic>? existing}) async {
    if (_employees.isEmpty) {
      await _loadEmployees();
      if (!mounted) return;
    }

    final resultStatus = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PenaltyFormSheet(
        api: _api,
        employees: _employees,
        existing: existing,
      ),
    );
    if (resultStatus != null && mounted) {
      final msg = existing != null
          ? 'تم تعديل الجزاء بنجاح'
          : (resultStatus == 'approved'
              ? 'تم تسجيل واعتماد الجزاء بنجاح'
              : 'تم تسجيل الجزاء وبانتظار الاعتماد');
      AppFeedback.showSuccess(context, msg);
      _loadPenalties();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'سجل الجزاءات والخصومات',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: () {
              _loadEmployees();
              _loadPenalties();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.gavel_rounded),
        label: const Text(
          'تسجيل جزاء',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showPenaltyFormSheet(),
      ),
      body: Column(
        children: [
          if (_employeesError != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: AppInlineError(
                message: 'تعذر تحميل قائمة الموظفين: $_employeesError',
              ),
            ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                _chip('الكل', ''),
                const SizedBox(width: 8),
                _chip('قيد المراجعة', 'pending'),
                const SizedBox(width: 8),
                _chip('معتمد', 'approved'),
                const SizedBox(width: 8),
                _chip('مرفوض', 'rejected'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const AppLoadingView(message: 'جاري تحميل الجزاءات...')
                : _error != null
                    ? AppErrorView(message: _error!, onRetry: _loadPenalties)
                    : _penalties.isEmpty
                        ? AppEmptyView(
                            title: 'لا توجد جزاءات مطابقة',
                            icon: Icons.verified_user_outlined,
                            actionLabel: 'تسجيل جزاء جديد',
                            onAction: () => _showPenaltyFormSheet(),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadPenalties,
                            color: AppColors.primary,
                            child: ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 92),
                              itemCount: _penalties.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final penalty = _penalties[i];
                                final status =
                                    penalty['status']?.toString() ?? 'pending';
                                final isPending = status == 'pending';
                                final isApproved = status == 'approved';
                                final days = double.tryParse(
                                      penalty['days']?.toString() ?? '0',
                                    ) ??
                                    0;
                                final amount = double.tryParse(
                                      penalty['amount']?.toString() ?? '0',
                                    ) ??
                                    0;
                                final empName = penalty['employee']?['name']
                                        ?.toString() ??
                                    penalty['employee_name']?.toString() ??
                                    'موظف';

                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              empName,
                                              style: const TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          AppStatusBadge(
                                            label: isApproved
                                                ? 'معتمد'
                                                : isPending
                                                    ? 'قيد المراجعة'
                                                    : 'مرفوض',
                                            color: isApproved
                                                ? AppColors.error
                                                : isPending
                                                    ? AppColors.accent
                                                    : AppColors.textMuted,
                                          ),
                                          if (isPending) ...[
                                            IconButton(
                                              tooltip: 'تعديل',
                                              constraints: const BoxConstraints(
                                                minWidth: 40,
                                                minHeight: 40,
                                              ),
                                              icon: const Icon(
                                                Icons.edit_outlined,
                                                size: 19,
                                                color: AppColors.info,
                                              ),
                                              onPressed: () =>
                                                  _showPenaltyFormSheet(
                                                existing: penalty,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'حذف',
                                              constraints: const BoxConstraints(
                                                minWidth: 40,
                                                minHeight: 40,
                                              ),
                                              icon: const Icon(
                                                Icons.delete_outline_rounded,
                                                size: 19,
                                                color: AppColors.error,
                                              ),
                                              onPressed: () => _deletePenalty(
                                                penalty['id'] as int,
                                                empName,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'الخصم: ${days > 0 ? '${penalty['days']} يوم ' : ''}${amount > 0 ? '${penalty['amount']} ج.م' : ''} • ${penalty['date'] ?? ''}',
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.error,
                                        ),
                                      ),
                                      if (penalty['reason'] != null &&
                                          penalty['reason']
                                              .toString()
                                              .trim()
                                              .isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'السبب: ${penalty['reason']}',
                                          style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                      if (isPending) ...[
                                        const Divider(height: 18),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            OutlinedButton(
                                              onPressed: () => _updateStatus(
                                                penalty['id'] as int,
                                                'rejected',
                                                empName,
                                              ),
                                              child: const Text(
                                                'رفض الجزاء',
                                                style: TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            FilledButton(
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.error,
                                              ),
                                              onPressed: () => _updateStatus(
                                                penalty['id'] as int,
                                                'approved',
                                                empName,
                                              ),
                                              child: const Text(
                                                'اعتماد وخصم',
                                                style: TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
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

  Widget _chip(String label, String val) {
    final sel = _statusFilter == val;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: sel ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: sel,
      selectedColor: AppColors.primary,
      onSelected: (_) {
        setState(() => _statusFilter = val);
        _loadPenalties();
      },
    );
  }
}

class _PenaltyFormSheet extends StatefulWidget {
  final ApiClient api;
  final List<Map<String, dynamic>> employees;
  final Map<String, dynamic>? existing;

  const _PenaltyFormSheet({
    required this.api,
    required this.employees,
    this.existing,
  });

  @override
  State<_PenaltyFormSheet> createState() => _PenaltyFormSheetState();
}

class _PenaltyFormSheetState extends State<_PenaltyFormSheet> {
  late final TextEditingController _reasonController;
  late final TextEditingController _daysController;
  late final TextEditingController _amountController;
  late final TextEditingController _dateCtrl;
  late final List<Map<String, dynamic>> _selectableEmployees;
  int? _selectedEmployeeId;
  bool _isSubmitting = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _selectableEmployees = List<Map<String, dynamic>>.from(widget.employees);
    final existingEmpId = e?['employee_id'] as int? ??
        (e?['employee'] as Map<String, dynamic>?)?['id'] as int?;
    if (existingEmpId != null &&
        !_selectableEmployees.any((emp) => emp['id'] == existingEmpId)) {
      _selectableEmployees.insert(0, {
        'id': existingEmpId,
        'name': e?['employee']?['name']?.toString() ??
            e?['employee_name']?.toString() ??
            'موظف #$existingEmpId',
      });
    }
    _selectedEmployeeId = e != null
        ? existingEmpId
        : (_selectableEmployees.isNotEmpty
            ? _selectableEmployees.first['id'] as int?
            : null);

    _reasonController =
        TextEditingController(text: e?['reason']?.toString() ?? '');
    _daysController = TextEditingController(
      text: (e?['days'] ?? '').toString() == '0'
          ? ''
          : (e?['days'] ?? '').toString(),
    );
    _amountController = TextEditingController(
      text: (e?['amount'] ?? '').toString() == '0'
          ? ''
          : (e?['amount'] ?? '').toString(),
    );
    _dateCtrl = TextEditingController(
      text: e?['date']?.toString() ??
          DateTime.now().toIso8601String().split('T')[0],
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _daysController.dispose();
    _amountController.dispose();
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedEmployeeId == null) {
      setState(() => _formError = 'اختر الموظف أولاً.');
      return;
    }
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _formError = 'أدخل سبب ومخالفة الجزاء.');
      return;
    }
    final daysNum = double.tryParse(_daysController.text.trim()) ?? 0;
    final amtNum = double.tryParse(_amountController.text.trim()) ?? 0;
    if (daysNum <= 0 && amtNum <= 0) {
      setState(
        () => _formError = 'حدد عدد أيام خصم أو مبلغ خصم أكبر من صفر.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _formError = null;
    });

    final payload = <String, dynamic>{
      'employee_id': _selectedEmployeeId,
      'date': _dateCtrl.text.trim(),
      'reason': reason,
      'days':
          daysNum > 0 ? AppNumericKeypadSheet.formatNumber(daysNum) : null,
      'amount':
          amtNum > 0 ? AppNumericKeypadSheet.formatNumber(amtNum) : null,
    };
    try {
      dynamic res;
      if (widget.existing != null) {
        res = await widget.api.put(
          '/api/v1/hr/penalties/${widget.existing!['id']}/update/',
          body: payload,
        );
      } else {
        res = await widget.api.post(
          '/api/v1/hr/penalties/create/',
          body: payload,
        );
      }
      if (!mounted) return;
      final savedStatus =
          (res is Map ? res['status']?.toString() : null) ?? 'pending';
      Navigator.pop(context, savedStatus);
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
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
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
                  isEdit ? 'تعديل الجزاء الإداري' : 'تسجيل جزاء إداري جديد',
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
            const SizedBox(height: 12),
            if (_formError != null) ...[
              AppInlineError(message: _formError!),
              const SizedBox(height: 12),
            ],
            if (_selectableEmployees.isEmpty)
              const AppInlineError(
                message: 'لا توجد بيانات موظفين متاحة للاختيار.',
              )
            else
              DropdownButtonFormField<int>(
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'الموظف *',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                value: _selectableEmployees
                        .any((e) => e['id'] == _selectedEmployeeId)
                    ? _selectedEmployeeId
                    : _selectableEmployees.first['id'] as int,
                items: _selectableEmployees
                    .map(
                      (e) => DropdownMenuItem<int>(
                        value: e['id'] as int,
                        child: Text(
                          e['name']?.toString() ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Cairo'),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedEmployeeId = val),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: AppNumericField(
                    controller: _daysController,
                    label: 'خصم بالأيام',
                    unit: 'يوم',
                    dialogTitle: 'عدد أيام الخصم',
                    allowDecimal: true,
                    quickAddValues: const [0.5, 1, 2, 3],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppNumericField(
                    controller: _amountController,
                    label: 'أو مبلغ ثابت',
                    unit: 'ج.م',
                    dialogTitle: 'مبلغ الخصم الثابت',
                    allowDecimal: true,
                    quickAddValues: const [50, 100, 200],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dateCtrl,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'تاريخ الجزاء',
                prefixIcon: Icon(Icons.event_outlined),
              ),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate:
                      DateTime.tryParse(_dateCtrl.text) ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(
                    () => _dateCtrl.text = picked.toIso8601String().split('T')[0],
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'سبب ومخالفة الجزاء *',
                prefixIcon: Icon(Icons.warning_amber_outlined),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.error,
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
                      isEdit ? 'حفظ التعديلات' : 'تسجيل الجزاء',
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
    );
  }
}
