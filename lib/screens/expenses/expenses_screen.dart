import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/async_views.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final _api = ApiClient();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _expenses = [];
  List<dynamic> _accounts = [];
  List<dynamic> _branches = [];
  int? _selectedBranchId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  void _initAndLoad() {
    final auth = context.read<AuthProvider>();
    _api.setBaseUrl(auth.serverUrl);
    _api.setToken(auth.token);
    _loadExpenses();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final res = await _api.get('/api/v1/expenses/options/');
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _accounts = res['accounts'] as List<dynamic>? ?? [];
        });
      }
      final boot = await _api.get('/api/v1/bootstrap/');
      if (boot is Map<String, dynamic> && mounted) {
        setState(() {
          _branches = boot['branches'] as List<dynamic>? ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadExpenses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final params = <String, String>{};
      if (_selectedBranchId != null) {
        params['branch_id'] = _selectedBranchId.toString();
      }
      final res = await _api.get('/api/v1/expenses/', queryParams: params);
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _expenses = res['results'] as List<dynamic>? ?? res['expenses'] as List<dynamic>? ?? [];
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

  Future<void> _cancelExpense(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء المصروف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: const Text('هل أنت متأكد من رغبتك في إلغاء هذا المصروف؟', style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('تراجع', style: TextStyle(fontFamily: 'Cairo'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الإلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await _api.post('/api/v1/expenses/$id/cancel/', body: {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إلغاء المصروف بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
        );
        _loadExpenses();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الإلغاء: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showAddExpenseSheet() {
    int? selectedAccountId;
    int? selectedBranchId = _branches.isNotEmpty ? _branches.first['id'] as int? : null;
    final amountController = TextEditingController();
    final reasonController = TextEditingController();
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
                  const Text('إضافة مصروف جديد', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'بند المصروف (الحساب)'),
                value: selectedAccountId,
                items: _accounts.map<DropdownMenuItem<int>>((acc) {
                  return DropdownMenuItem<int>(
                    value: acc['id'] as int,
                    child: Text(acc['name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo')),
                  );
                }).toList(),
                onChanged: (val) => setSheetState(() => selectedAccountId = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'الفرع المستفيد'),
                value: selectedBranchId,
                items: _branches.map<DropdownMenuItem<int>>((b) {
                  return DropdownMenuItem<int>(
                    value: b['id'] as int,
                    child: Text(b['name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo')),
                  );
                }).toList(),
                onChanged: (val) => setSheetState(() => selectedBranchId = val),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'المبلغ (ج.م)', prefixIcon: Icon(Icons.attach_money_rounded)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'بيان / سبب الصرف', prefixIcon: Icon(Icons.notes_rounded)),
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
                        if (selectedAccountId == null || selectedBranchId == null || amountController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('يرجى ملء جميع الحقول المطلوبة', style: TextStyle(fontFamily: 'Cairo'))),
                          );
                          return;
                        }
                        setSheetState(() => isSubmitting = true);
                        try {
                          await _api.post('/api/v1/expenses/create/', body: {
                            'account_id': selectedAccountId,
                            'branch_id': selectedBranchId,
                            'amount': amountController.text.trim(),
                            'reason': reasonController.text.trim(),
                          });
                          if (mounted) {
                            Navigator.pop(sheetContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم تسجيل المصروف بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
                            );
                            _loadExpenses();
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
                    : const Text('تسجيل المصروف', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _expenses.where((exp) {
      final reason = exp['reason']?.toString().toLowerCase() ?? '';
      final account = exp['account_name']?.toString().toLowerCase() ?? '';
      final q = _searchQuery.toLowerCase();
      return q.isEmpty || reason.contains(q) || account.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('سجل المصروفات النثرية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث', onPressed: _loadExpenses),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('تسجيل مصروف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        onPressed: _showAddExpenseSheet,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'ابحث في المصروفات...',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                if (_branches.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  DropdownButton<int?>(
                    value: _selectedBranchId,
                    hint: const Text('كل الفروع', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                    underline: const SizedBox(),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('كل الفروع', style: TextStyle(fontFamily: 'Cairo', fontSize: 12))),
                      ..._branches.map((b) => DropdownMenuItem<int?>(
                            value: b['id'] as int,
                            child: Text(b['name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                          )),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedBranchId = val);
                      _loadExpenses();
                    },
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const AppLoadingView(message: 'جاري تحميل المصروفات...')
                : _error != null
                    ? AppErrorView(message: _error!, onRetry: _loadExpenses)
                    : filtered.isEmpty
                        ? const AppEmptyView(title: 'لا توجد مصروفات مسجلة', icon: Icons.receipt_long_outlined)
                        : RefreshIndicator(
                            onRefresh: _loadExpenses,
                            color: AppColors.primary,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final exp = filtered[i] as Map<String, dynamic>;
                                final isCanceled = exp['is_canceled'] == true;
                                final amount = exp['amount']?.toString() ?? '0';
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isCanceled ? AppColors.error.withOpacity(0.3) : AppColors.border),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isCanceled ? AppColors.error.withOpacity(0.1) : AppColors.primaryLight,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          isCanceled ? Icons.cancel_outlined : Icons.monetization_on_outlined,
                                          color: isCanceled ? AppColors.error : AppColors.primary,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              exp['account_name']?.toString() ?? 'مصروف',
                                              style: TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: isCanceled ? AppColors.textMuted : AppColors.textPrimary,
                                                decoration: isCanceled ? TextDecoration.lineThrough : null,
                                              ),
                                            ),
                                            if (exp['reason'] != null && exp['reason'].toString().isNotEmpty)
                                              Text(
                                                exp['reason'].toString(),
                                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textSecondary),
                                              ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.storefront_outlined, size: 14, color: AppColors.textMuted),
                                                const SizedBox(width: 4),
                                                Text(
                                                  exp['beneficiary_branch_name']?.toString() ?? exp['branch_name']?.toString() ?? '',
                                                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted),
                                                ),
                                                const SizedBox(width: 12),
                                                Icon(Icons.schedule_outlined, size: 14, color: AppColors.textMuted),
                                                const SizedBox(width: 4),
                                                Text(
                                                  exp['date']?.toString() ?? '',
                                                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '$amount ج.م',
                                            style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                              color: isCanceled ? AppColors.textMuted : AppColors.error,
                                            ),
                                          ),
                                          if (!isCanceled) ...[
                                            const SizedBox(height: 6),
                                            InkWell(
                                              onTap: () => _cancelExpense(exp['id'] as int),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppColors.error.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'إلغاء',
                                                  style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.error, fontWeight: FontWeight.bold),
                                                ),
                                              ),
                                            ),
                                          ] else ...[
                                            const SizedBox(height: 6),
                                            const Text(
                                              'ملغي',
                                              style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.error, fontWeight: FontWeight.bold),
                                            ),
                                          ],
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
      ),
    );
  }
}
