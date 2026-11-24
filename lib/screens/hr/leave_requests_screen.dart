import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/async_views.dart';

class LeaveRequestsScreen extends StatefulWidget {
  const LeaveRequestsScreen({super.key});

  @override
  State<LeaveRequestsScreen> createState() => _LeaveRequestsScreenState();
}

class _LeaveRequestsScreenState extends State<LeaveRequestsScreen> {
  final _api = ApiClient();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _leaves = [];
  List<dynamic> _employees = [];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _api.setBaseUrl(auth.serverUrl);
    _api.setToken(auth.token);
    _loadLeaves();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final res = await _api.get('/api/v1/hr/employees/');
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _employees = res['results'] as List<dynamic>? ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadLeaves() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.get('/api/v1/hr/leaves/');
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _leaves = res['results'] as List<dynamic>? ?? [];
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

  Future<void> _updateStatus(int id, String status) async {
    try {
      await _api.post('/api/v1/hr/leaves/$id/status/', body: {'status': status});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحديث حالة الطلب إلى $status', style: const TextStyle(fontFamily: 'Cairo'))),
        );
        _loadLeaves();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showCreateLeaveSheet() {
    int? selectedEmployeeId = _employees.isNotEmpty ? _employees.first['id'] as int? : null;
    String leaveType = 'regular';
    final reasonController = TextEditingController();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('تقديم طلب إجازة', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 14),
              if (_employees.isNotEmpty)
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'اختر الموظف'),
                  value: selectedEmployeeId,
                  items: _employees.map<DropdownMenuItem<int>>((e) {
                    return DropdownMenuItem<int>(
                      value: e['id'] as int,
                      child: Text(e['name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo')),
                    );
                  }).toList(),
                  onChanged: (val) => setSheetState(() => selectedEmployeeId = val),
                ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'نوع الإجازة'),
                value: leaveType,
                items: const [
                  DropdownMenuItem(value: 'regular', child: Text('إجازة اعتيادية', style: TextStyle(fontFamily: 'Cairo'))),
                  DropdownMenuItem(value: 'annual', child: Text('إجازة سنوية', style: TextStyle(fontFamily: 'Cairo'))),
                  DropdownMenuItem(value: 'sick', child: Text('إجازة مرضية', style: TextStyle(fontFamily: 'Cairo'))),
                  DropdownMenuItem(value: 'unpaid', child: Text('بدون راتب', style: TextStyle(fontFamily: 'Cairo'))),
                ],
                onChanged: (val) => setSheetState(() => leaveType = val ?? 'regular'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text('من: ${startDate.toString().split(' ')[0]}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setSheetState(() => startDate = picked);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text('إلى: ${endDate.toString().split(' ')[0]}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) setSheetState(() => endDate = picked);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: 'سبب الإجازة', prefixIcon: Icon(Icons.notes_outlined)),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (selectedEmployeeId == null) return;
                        setSheetState(() => isSubmitting = true);
                        try {
                          await _api.post('/api/v1/hr/leaves/create/', body: {
                            'employee_id': selectedEmployeeId,
                            'leave_type': leaveType,
                            'start_date': startDate.toString().split(' ')[0],
                            'end_date': endDate.toString().split(' ')[0],
                            'reason': reasonController.text.trim(),
                          });
                          if (mounted) {
                            Navigator.pop(sheetContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم تقديم طلب الإجازة بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
                            );
                            _loadLeaves();
                          }
                        } catch (e) {
                          setSheetState(() => isSubmitting = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.error),
                            );
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('تقديم طلب الإجازة', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('طلبات واعتماد الإجازات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث', onPressed: _loadLeaves),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('طلب إجازة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        onPressed: _showCreateLeaveSheet,
      ),
      body: _isLoading
          ? const AppLoadingView(message: 'جاري تحميل طلبات الإجازات...')
          : _error != null
              ? AppErrorView(message: _error!, onRetry: _loadLeaves)
              : _leaves.isEmpty
                  ? const AppEmptyView(title: 'لا توجد طلبات إجازة مسجلة', icon: Icons.event_available_outlined)
                  : RefreshIndicator(
                      onRefresh: _loadLeaves,
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: _leaves.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final leave = _leaves[i] as Map<String, dynamic>;
                          final status = leave['status']?.toString() ?? 'pending';
                          final isPending = status == 'pending';
                          final isApproved = status == 'approved';

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        leave['employee_name'] ?? leave['employee']?['name'] ?? 'موظف',
                                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isApproved
                                            ? AppColors.success.withOpacity(0.1)
                                            : isPending
                                                ? AppColors.accent.withOpacity(0.1)
                                                : AppColors.error.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isApproved ? 'معتمدة' : isPending ? 'قيد المراجعة' : 'مرفوضة',
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isApproved ? AppColors.success : isPending ? AppColors.accent : AppColors.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'الفترة: من ${leave['start_date']} إلى ${leave['end_date']} • نوع: ${leave['leave_type'] ?? 'اعتيادية'}',
                                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary),
                                ),
                                if (leave['reason'] != null && leave['reason'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'السبب: ${leave['reason']}',
                                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted),
                                  ),
                                ],
                                if (isPending) ...[
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.error,
                                          side: const BorderSide(color: AppColors.error),
                                        ),
                                        onPressed: () => _updateStatus(leave['id'] as int, 'rejected'),
                                        child: const Text('رفض', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton(
                                        style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                                        onPressed: () => _updateStatus(leave['id'] as int, 'approved'),
                                        child: const Text('اعتماد الإجازة', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
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
    );
  }
}
