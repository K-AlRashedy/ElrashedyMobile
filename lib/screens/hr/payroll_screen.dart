import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/async_views.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  final _api = ApiClient();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _payrolls = [];
  String _selectedMonth = DateTime.now().toString().substring(0, 7); // YYYY-MM

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _api.setBaseUrl(auth.serverUrl);
    _api.setToken(auth.token);
    _loadPayroll();
  }

  Future<void> _loadPayroll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.get('/api/v1/hr/payroll/', queryParams: {'month': _selectedMonth});
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _payrolls = res['results'] as List<dynamic>? ?? [];
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

  Future<void> _generatePayroll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('توليد رواتب شهر $_selectedMonth', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text(
          'سيقوم النظام باحتساب الأجر الأساسي والبدلات والإضافي وخصم الغياب والتأخير والسلف آلياً.\nهل تود المتابعة؟',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد التوليد', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await _api.post('/api/v1/hr/payroll/generate/', body: {'month': _selectedMonth});
      if (mounted) {
        final count = (res as Map<String, dynamic>)['generated_count'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم توليد رواتب $count موظف بنجاح', style: const TextStyle(fontFamily: 'Cairo'))),
        );
        _loadPayroll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التوليد: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _paySalary(int id, String name, String net) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('صرف راتب $name', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('سيتم صرف مبلغ $net ج.م نقداً من الخزينة الرئيسية وتسجيل الراتب كـ "مسدد".\nهل تود المتابعة؟', style: const TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('صرف الراتب', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _api.post('/api/v1/hr/payroll/$id/pay/', body: {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم صرف الراتب وخصم المبلغ من الخزينة بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
        );
        _loadPayroll();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الصرف: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('مسيرات الرواتب الشهرية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث', onPressed: _loadPayroll),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.auto_mode_rounded),
        label: const Text('توليد مسير الرواتب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        onPressed: _generatePayroll,
      ),
      body: Column(
        children: [
          // Month Selector
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text('مسير شهر: $_selectedMonth', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                  label: const Text('تغيير الشهر', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() {
                        _selectedMonth = picked.toString().substring(0, 7);
                      });
                      _loadPayroll();
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const AppLoadingView(message: 'جاري تحميل مسير الرواتب...')
                : _error != null
                    ? AppErrorView(message: _error!, onRetry: _loadPayroll)
                    : _payrolls.isEmpty
                        ? AppEmptyView(
                            title: 'لم يتم توليد رواتب لشهر $_selectedMonth بعد',
                            icon: Icons.payments_outlined,
                            actionLabel: 'اضغط لتوليد المسير الآن',
                            onAction: _generatePayroll,
                          )
                        : RefreshIndicator(
                            onRefresh: _loadPayroll,
                            color: AppColors.primary,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                              itemCount: _payrolls.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final p = _payrolls[i] as Map<String, dynamic>;
                                final isPaid = p['is_paid'] == true;
                                final name = p['employee_name'] ?? p['employee']?['name'] ?? 'موظف';
                                final net = p['net_salary']?.toString() ?? '0';

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
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isPaid ? AppColors.success.withOpacity(0.1) : AppColors.accent.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isPaid ? 'مسدد' : 'مستحق للصرف',
                                              style: TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isPaid ? AppColors.success : AppColors.accent,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('الأساسي: ${p['basic_salary']} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                                          Text('إجمالي الاستحقاق: ${p['total_due']} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                                        ],
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('خصومات وسلف: ${p['total_deductions']} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.error)),
                                          Text('صافي الراتب: $net ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                        ],
                                      ),
                                      if (!isPaid) ...[
                                        const Divider(height: 16),
                                        Align(
                                          alignment: Alignment.centerLeft,
                                          child: FilledButton.icon(
                                            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                                            icon: const Icon(Icons.price_check_rounded, size: 18),
                                            label: const Text('صرف الراتب نقداً', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                                            onPressed: () => _paySalary(p['id'] as int, name, net),
                                          ),
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
}
