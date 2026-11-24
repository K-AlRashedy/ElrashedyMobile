import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/async_views.dart';

class PenaltiesScreen extends StatefulWidget {
  const PenaltiesScreen({super.key});

  @override
  State<PenaltiesScreen> createState() => _PenaltiesScreenState();
}

class _PenaltiesScreenState extends State<PenaltiesScreen> {
  final _api = ApiClient();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _penalties = [];
  List<dynamic> _employees = [];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _api.setBaseUrl(auth.serverUrl);
    _api.setToken(auth.token);
    _loadPenalties();
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

  Future<void> _loadPenalties() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.get('/api/v1/hr/penalties/');
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _penalties = res['results'] as List<dynamic>? ?? [];
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
      await _api.post('/api/v1/hr/penalties/$id/status/', body: {'status': status});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم تحديث حالة الجزاء إلى $status', style: const TextStyle(fontFamily: 'Cairo'))),
        );
        _loadPenalties();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showAddPenaltySheet() {
    int? selectedEmployeeId = _employees.isNotEmpty ? _employees.first['id'] as int? : null;
    final reasonController = TextEditingController();
    final amountController = TextEditingController(text: '0');
    final daysController = TextEditingController(text: '1');
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
                  const Text('تسجيل جزاء إداري جديد', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
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
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: daysController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'خصم بالأيام (يوم)', prefixIcon: Icon(Icons.calendar_today_outlined)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'أو مبلغ ثابت (ج.م)', prefixIcon: Icon(Icons.money_off_outlined)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'سبب ومخالفة الجزاء', prefixIcon: Icon(Icons.warning_amber_outlined)),
              ),
              const SizedBox(height: 20),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        if (selectedEmployeeId == null || reasonController.text.trim().isEmpty) return;
                        setSheetState(() => isSubmitting = true);
                        try {
                          await _api.post('/api/v1/hr/penalties/create/', body: {
                            'employee_id': selectedEmployeeId,
                            'days': daysController.text.trim(),
                            'amount': amountController.text.trim(),
                            'reason': reasonController.text.trim(),
                            'date': DateTime.now().toString().split(' ')[0],
                          });
                          if (mounted) {
                            Navigator.pop(sheetContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم تسجيل الجزاء بنجاح وبانتظار الاعتماد', style: TextStyle(fontFamily: 'Cairo'))),
                            );
                            _loadPenalties();
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
                    : const Text('تسجيل الجزاء', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
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
        title: const Text('سجل الجزاءات والخصومات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث', onPressed: _loadPenalties),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.error,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.gavel_rounded),
        label: const Text('تسجيل جزاء', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        onPressed: _showAddPenaltySheet,
      ),
      body: _isLoading
          ? const AppLoadingView(message: 'جاري تحميل الجزاءات...')
          : _error != null
              ? AppErrorView(message: _error!, onRetry: _loadPenalties)
              : _penalties.isEmpty
                  ? const AppEmptyView(title: 'لا توجد جزاءات مسجلة', icon: Icons.verified_user_outlined)
                  : RefreshIndicator(
                      onRefresh: _loadPenalties,
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: _penalties.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final penalty = _penalties[i] as Map<String, dynamic>;
                          final status = penalty['status']?.toString() ?? 'pending';
                          final isPending = status == 'pending';
                          final isApproved = status == 'approved';
                          final days = penalty['days'] ?? 0;
                          final amount = penalty['amount'] ?? 0;

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
                                        penalty['employee_name'] ?? penalty['employee']?['name'] ?? 'موظف',
                                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isApproved
                                            ? AppColors.error.withOpacity(0.1)
                                            : isPending
                                                ? AppColors.accent.withOpacity(0.1)
                                                : AppColors.textMuted.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        isApproved ? 'معتمد' : isPending ? 'قيد المراجعة' : 'ملغي / مرفوض',
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: isApproved ? AppColors.error : isPending ? AppColors.accent : AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'الخصم: ${days > 0 ? '$days يوم' : ''} ${amount > 0 ? '$amount ج.م' : ''} • التاريخ: ${penalty['date'] ?? ''}',
                                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.error),
                                ),
                                if (penalty['reason'] != null)
                                  Text(
                                    'السبب: ${penalty['reason']}',
                                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                if (isPending) ...[
                                  const Divider(height: 16),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: AppColors.textSecondary,
                                          side: const BorderSide(color: AppColors.border),
                                        ),
                                        onPressed: () => _updateStatus(penalty['id'] as int, 'rejected'),
                                        child: const Text('إلغاء الجزاء', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton(
                                        style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                                        onPressed: () => _updateStatus(penalty['id'] as int, 'approved'),
                                        child: const Text('اعتماد وخصم', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
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
