import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/async_views.dart';

class LeaveRequestsScreen extends StatefulWidget {
  const LeaveRequestsScreen({super.key});

  @override
  State<LeaveRequestsScreen> createState() => _LeaveRequestsScreenState();
}

class _LeaveRequestsScreenState extends State<LeaveRequestsScreen> {
  bool _isLoading = true;
  String? _error;
  String? _employeesError;
  List<Map<String, dynamic>> _leaves = [];
  List<Map<String, dynamic>> _employees = [];
  String _statusFilter = ''; // '' | 'pending' | 'approved' | 'rejected'
  bool _initialized = false;

  ApiClient get _api => context.read<ApiClient>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadLeaves();
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

  Future<void> _loadLeaves() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.get(
        '/api/v1/hr/leaves/',
        queryParams: {
          'page_size': '80',
          if (_statusFilter.isNotEmpty) 'status': _statusFilter,
        },
      );
      if (!mounted) return;
      if (res is Map<String, dynamic>) {
        final raw = res['results'] as List<dynamic>? ?? [];
        setState(() {
          _leaves = raw.whereType<Map<String, dynamic>>().toList();
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
      title: isApprove ? 'اعتماد طلب الإجازة' : 'رفض طلب الإجازة',
      message: isApprove
          ? 'هل تريد اعتماد إجازة "$empName"؟'
          : 'هل تريد رفض طلب إجازة "$empName"؟',
      confirmLabel: isApprove ? 'اعتماد' : 'رفض',
      isDestructive: !isApprove,
    );
    if (!confirmed || !mounted) return;

    try {
      await _api.post('/api/v1/hr/leaves/$id/status/', body: {'status': status});
      if (!mounted) return;
      AppFeedback.showSuccess(
        context,
        isApprove ? 'تم اعتماد الإجازة' : 'تم رفض الإجازة',
      );
      _loadLeaves();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, e.toString());
    }
  }

  Future<void> _deleteLeave(int id, String empName) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'حذف طلب الإجازة',
      message: 'هل تريد حذف طلب إجازة "$empName" نهائياً؟',
      confirmLabel: 'حذف',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await _api.delete('/api/v1/hr/leaves/$id/delete/');
      if (!mounted) return;
      AppFeedback.showSuccess(context, 'تم حذف طلب الإجازة');
      _loadLeaves();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, e.toString());
    }
  }

  Future<void> _showLeaveFormSheet({Map<String, dynamic>? existing}) async {
    if (_employees.isEmpty) {
      await _loadEmployees();
      if (!mounted) return;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _LeaveFormSheet(
        api: _api,
        employees: _employees,
        existing: existing,
      ),
    );
    if (saved == true && mounted) {
      AppFeedback.showSuccess(
        context,
        existing != null
            ? 'تم تعديل طلب الإجازة بنجاح'
            : 'تم تقديم طلب الإجازة بنجاح',
      );
      _loadLeaves();
    }
  }

  @override
  Widget build(BuildContext context) {
    const typeLabels = {
      'annual': 'سنوية',
      'sick': 'مرضية',
      'unpaid': 'بدون راتب',
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'طلبات واعتماد الإجازات',
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
              _loadLeaves();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text(
          'طلب إجازة',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showLeaveFormSheet(),
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
                _chip('معتمدة', 'approved'),
                const SizedBox(width: 8),
                _chip('مرفوضة', 'rejected'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const AppLoadingView(message: 'جاري تحميل طلبات الإجازات...')
                : _error != null
                    ? AppErrorView(message: _error!, onRetry: _loadLeaves)
                    : _leaves.isEmpty
                        ? AppEmptyView(
                            title: 'لا توجد طلبات إجازة مطابقة',
                            icon: Icons.event_available_outlined,
                            actionLabel: 'تقديم طلب إجازة',
                            onAction: () => _showLeaveFormSheet(),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadLeaves,
                            color: AppColors.primary,
                            child: ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 8, 16, 92),
                              itemCount: _leaves.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final leave = _leaves[i];
                                final status =
                                    leave['status']?.toString() ?? 'pending';
                                final isPending = status == 'pending';
                                final isApproved = status == 'approved';
                                final notes =
                                    (leave['notes'] ?? leave['reason'] ?? '')
                                        .toString();
                                final empName = leave['employee']?['name']
                                        ?.toString() ??
                                    leave['employee_name']?.toString() ??
                                    'موظف';
                                final tLabel = leave['leave_type_display']
                                        ?.toString() ??
                                    typeLabels[leave['leave_type']] ??
                                    '${leave['leave_type']}';

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
                                                ? 'معتمدة'
                                                : isPending
                                                    ? 'قيد المراجعة'
                                                    : 'مرفوضة',
                                            color: isApproved
                                                ? AppColors.success
                                                : isPending
                                                    ? AppColors.accent
                                                    : AppColors.error,
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
                                                  _showLeaveFormSheet(
                                                existing: leave,
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
                                              onPressed: () => _deleteLeave(
                                                leave['id'] as int,
                                                empName,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'من ${leave['start_date']} إلى ${leave['end_date']} • $tLabel',
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 12.5,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      if (notes.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'ملاحظات: $notes',
                                          style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 12,
                                            color: AppColors.textMuted,
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
                                              style: OutlinedButton.styleFrom(
                                                foregroundColor:
                                                    AppColors.error,
                                                side: const BorderSide(
                                                  color: AppColors.error,
                                                ),
                                              ),
                                              onPressed: () => _updateStatus(
                                                leave['id'] as int,
                                                'rejected',
                                                empName,
                                              ),
                                              child: const Text(
                                                'رفض',
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
                                                    AppColors.success,
                                              ),
                                              onPressed: () => _updateStatus(
                                                leave['id'] as int,
                                                'approved',
                                                empName,
                                              ),
                                              child: const Text(
                                                'اعتماد الإجازة',
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
        _loadLeaves();
      },
    );
  }
}

class _LeaveFormSheet extends StatefulWidget {
  final ApiClient api;
  final List<Map<String, dynamic>> employees;
  final Map<String, dynamic>? existing;

  const _LeaveFormSheet({
    required this.api,
    required this.employees,
    this.existing,
  });

  @override
  State<_LeaveFormSheet> createState() => _LeaveFormSheetState();
}

class _LeaveFormSheetState extends State<_LeaveFormSheet> {
  late final TextEditingController _notesController;
  late final List<Map<String, dynamic>> _selectableEmployees;
  int? _selectedEmployeeId;
  late String _leaveType;
  late DateTime _startDate;
  late DateTime _endDate;
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
    final rawType = e?['leave_type']?.toString() ?? 'annual';
    _leaveType =
        const {'annual', 'sick', 'unpaid'}.contains(rawType) ? rawType : 'annual';
    _notesController = TextEditingController(
      text: (e?['notes'] ?? e?['reason'] ?? '').toString(),
    );
    _startDate =
        DateTime.tryParse(e?['start_date']?.toString() ?? '') ?? DateTime.now();
    _endDate =
        DateTime.tryParse(e?['end_date']?.toString() ?? '') ?? DateTime.now();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedEmployeeId == null) {
      setState(() => _formError = 'اختر الموظف أولاً.');
      return;
    }
    if (_endDate.isBefore(_startDate)) {
      setState(() => _formError = 'تاريخ الانتهاء يجب أن يكون بعد أو يساوي تاريخ البداية.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _formError = null;
    });
    final payload = {
      'employee_id': _selectedEmployeeId,
      'leave_type': _leaveType,
      'start_date': _startDate.toIso8601String().split('T')[0],
      'end_date': _endDate.toIso8601String().split('T')[0],
      'notes': _notesController.text.trim(),
    };
    try {
      if (widget.existing != null) {
        await widget.api.put(
          '/api/v1/hr/leaves/${widget.existing!['id']}/update/',
          body: payload,
        );
      } else {
        await widget.api.post('/api/v1/hr/leaves/create/', body: payload);
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
                  isEdit ? 'تعديل طلب الإجازة' : 'تقديم طلب إجازة جديد',
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
            DropdownButtonFormField<String>(
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'نوع الإجازة *'),
              value: _leaveType,
              items: const [
                DropdownMenuItem(
                  value: 'annual',
                  child: Text('إجازة سنوية', style: TextStyle(fontFamily: 'Cairo')),
                ),
                DropdownMenuItem(
                  value: 'sick',
                  child: Text('إجازة مرضية', style: TextStyle(fontFamily: 'Cairo')),
                ),
                DropdownMenuItem(
                  value: 'unpaid',
                  child: Text(
                    'إجازة بدون راتب',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                ),
              ],
              onChanged: (val) =>
                  setState(() => _leaveType = val ?? 'annual'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(
                      'من: ${_startDate.toIso8601String().split('T')[0]}',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(() {
                          _startDate = picked;
                          if (_endDate.isBefore(_startDate)) {
                            _endDate = _startDate;
                          }
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    icon: const Icon(Icons.calendar_today_outlined, size: 16),
                    label: Text(
                      'إلى: ${_endDate.toIso8601String().split('T')[0]}',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate,
                        firstDate: _startDate,
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) setState(() => _endDate = picked);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات / سبب الإجازة',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 20),
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
                      isEdit ? 'حفظ التعديلات' : 'تقديم طلب الإجازة',
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
