import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/async_views.dart';
import '../../widgets/numeric_keypad_sheet.dart';

class ExpensesScreen extends StatefulWidget {
  final bool openCreate;

  const ExpensesScreen({super.key, this.openCreate = false});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  final _uuid = const Uuid();
  Timer? _debounce;
  ApiCancelToken? _cancelToken;

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _expenses = [];
  List<Map<String, dynamic>> _accounts = [];

  int? _selectedBranchId;
  String _canceledFilter = 'active'; // active | canceled | all

  ApiClient get _api => context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([_loadOptions(), _loadExpenses()]);
      if (widget.openCreate && mounted) _showExpenseFormSheet();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cancelToken?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    try {
      final loaded = <Map<String, dynamic>>[];
      int page = 1;
      bool hasNext = true;
      while (hasNext && page <= 5) {
        final res = await _api.get('/api/v1/expenses/options/', queryParams: {'page': page, 'page_size': '100'});
        if (res is! Map<String, dynamic>) break;
        final raw = res['results'] as List<dynamic>? ?? res['accounts'] as List<dynamic>? ?? [];
        loaded.addAll(raw.whereType<Map<String, dynamic>>());
        hasNext = res['has_next'] == true;
        page++;
      }
      if (mounted) setState(() => _accounts = loaded);
    } catch (_) {}
  }

  Future<void> _loadExpenses() async {
    _cancelToken?.cancel();
    final token = ApiCancelToken();
    _cancelToken = token;

    setState(() { _isLoading = true; _error = null; });
    try {
      final params = <String, dynamic>{
        'page_size': '100',
        if (_selectedBranchId != null) 'beneficiary_branch_id': _selectedBranchId.toString(),
        if (_canceledFilter == 'active') 'is_canceled': 'false',
        if (_canceledFilter == 'canceled') 'is_canceled': 'true',
        if (_searchCtrl.text.trim().isNotEmpty) 'q': _searchCtrl.text.trim(),
      };
      final res = await _api.get('/api/v1/expenses/', queryParams: params, cancelToken: token);
      if (res is Map<String, dynamic> && mounted) {
        final raw = res['results'] as List<dynamic>? ?? res['expenses'] as List<dynamic>? ?? [];
        setState(() {
          _expenses = raw.whereType<Map<String, dynamic>>().toList();
          _isLoading = false;
        });
      }
    } on ApiException catch (e) {
      if (e.message == 'تم إلغاء الطلب.') return;
      if (mounted) setState(() { _isLoading = false; _error = e.message; });
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  Future<void> _toggleCancelRestore(Map<String, dynamic> exp) async {
    final isCanceled = exp['is_canceled'] == true;
    final id = exp['id'] as int;
    final confirmed = await AppConfirmDialog.show(
      context,
      title: isCanceled ? 'استعادة المصروف؟' : 'إلغاء المصروف؟',
      message: isCanceled
          ? 'سيتم إعادة تفعيل المصروف وخصم قيمته من الخزينة أو الوردية.'
          : 'سيتم إلغاء المصروف ورد قيمته إلى الخزينة أو الوردية.',
      confirmLabel: isCanceled ? 'استعادة' : 'إلغاء المصروف',
      isDestructive: !isCanceled,
    );
    if (!confirmed) return;

    try {
      if (isCanceled) {
        await _api.post('/api/v1/expenses/$id/restore/', idempotencyKey: _uuid.v4(), body: const {});
      } else {
        await _api.post('/api/v1/expenses/$id/cancel/', idempotencyKey: _uuid.v4(), body: const {});
      }
      if (!mounted) return;
      AppFeedback.showSuccess(
        context,
        isCanceled ? 'تم استعادة المصروف بنجاح' : 'تم إلغاء المصروف ورد المبلغ للخزينة',
      );
      await _loadExpenses();
    } catch (e) {
      if (mounted) AppFeedback.showError(context, e.toString());
    }
  }

  Future<void> _showExpenseFormSheet({Map<String, dynamic>? existing}) async {
    if (_accounts.isEmpty) await _loadOptions();
    if (!mounted) return;

    final isEdit = existing != null;
    final auth = context.read<AuthProvider>();
    final branches = (auth.allBranches.isNotEmpty ? auth.allBranches : auth.userBranches)
        .map((b) => {'id': b.id, 'name': b.name})
        .toList();

    final accountOptions = List<Map<String, dynamic>>.from(_accounts);
    int? selectedAccountId = isEdit
        ? (existing['account_id'] as int? ?? (existing['account'] as Map<String, dynamic>?)?['id'] as int?)
        : (accountOptions.isNotEmpty ? accountOptions.first['id'] as int? : null);
    if (isEdit && selectedAccountId != null && !accountOptions.any((a) => a['id'] == selectedAccountId)) {
      final accObj = existing['account'] as Map<String, dynamic>?;
      accountOptions.add({'id': selectedAccountId, 'name': accObj?['name'] ?? 'حساب #$selectedAccountId'});
    }

    int? selectedBranchId = isEdit
        ? (existing['beneficiary_branch_id'] as int? ?? (existing['beneficiary_branch'] as Map<String, dynamic>?)?['id'] as int?)
        : (branches.isNotEmpty ? branches.first['id'] as int? : null);
    if (isEdit && selectedBranchId != null && !branches.any((b) => b['id'] == selectedBranchId)) {
      final brObj = existing['beneficiary_branch'] as Map<String, dynamic>?;
      branches.add({'id': selectedBranchId, 'name': brObj?['name'] ?? 'فرع #$selectedBranchId'});
    }

    final amountController = TextEditingController(text: isEdit ? (existing['amount'] ?? '').toString() : '');
    final reasonController = TextEditingController(text: existing?['reason']?.toString() ?? '');
    bool isSubmitting = false;
    String? formError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEdit ? 'تعديل حساب ومركز تكلفة المصروف' : 'تسجيل مصروف مباشر من الخزينة',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 10),
                AppInlineError(message: formError),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'بند المصروف (الحساب) *'),
                  value: accountOptions.any((a) => a['id'] == selectedAccountId) ? selectedAccountId : null,
                  items: accountOptions
                      .map((acc) => DropdownMenuItem<int>(value: acc['id'] as int, child: Text(acc['name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo'))))
                      .toList(),
                  onChanged: (val) => setSheetState(() => selectedAccountId = val),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'الفرع المستفيد (مركز التكلفة) *'),
                  value: branches.any((b) => b['id'] == selectedBranchId) ? selectedBranchId : null,
                  items: branches
                      .map((b) => DropdownMenuItem<int>(value: b['id'] as int, child: Text(b['name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo'))))
                      .toList(),
                  onChanged: (val) => setSheetState(() => selectedBranchId = val),
                ),
                if (!isEdit) ...[
                  const SizedBox(height: 12),
                  AppNumericField(
                    controller: amountController,
                    label: 'المبلغ *',
                    unit: 'ج.م',
                    prefixIcon: Icons.payments_outlined,
                    quickAddValues: const [50, 100, 200, 500],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'بيان / سبب الصرف', prefixIcon: Icon(Icons.notes_rounded)),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final amt = double.tryParse(amountController.text.trim()) ?? 0;
                          if (selectedAccountId == null || selectedBranchId == null || (!isEdit && amt <= 0)) {
                            setSheetState(() => formError = 'يرجى اختيار الحساب والفرع وإدخال مبلغ أكبر من صفر.');
                            return;
                          }
                          setSheetState(() { isSubmitting = true; formError = null; });
                          try {
                            if (isEdit) {
                              await _api.post('/api/v1/expenses/${existing['id']}/update/', idempotencyKey: _uuid.v4(), body: {
                                'account_id': selectedAccountId,
                                'beneficiary_branch_id': selectedBranchId,
                              });
                            } else {
                              await _api.post('/api/v1/expenses/create/', idempotencyKey: _uuid.v4(), body: {
                                'account_id': selectedAccountId,
                                'beneficiary_branch_id': selectedBranchId,
                                'amount': amountController.text.trim(),
                                'reason': reasonController.text.trim(),
                              });
                            }
                            if (mounted) {
                              Navigator.pop(sheetContext);
                              AppFeedback.showSuccess(context, isEdit ? 'تم تحديث المصروف بنجاح' : 'تم تسجيل المصروف بنجاح');
                              await _loadExpenses();
                            }
                          } catch (e) {
                            if (ctx.mounted) setSheetState(() { isSubmitting = false; formError = e.toString(); });
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(isEdit ? 'حفظ التعديل' : 'تسجيل المصروف'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    amountController.dispose();
    reasonController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final branches = auth.allBranches.isNotEmpty ? auth.allBranches : auth.userBranches;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('سجل المصروفات'),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث', onPressed: _loadExpenses)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('تسجيل مصروف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        onPressed: () => _showExpenseFormSheet(),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    hintText: 'ابحث ببيان المصروف...',
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                    isDense: true,
                  ),
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 350), _loadExpenses);
                  },
                ),
                if (branches.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    value: branches.any((b) => b.id == _selectedBranchId) ? _selectedBranchId : null,
                    decoration: const InputDecoration(labelText: 'تصفية حسب الفرع المستفيد', isDense: true),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('كل الفروع', style: TextStyle(fontFamily: 'Cairo'))),
                      ...branches.map((b) => DropdownMenuItem<int?>(value: b.id, child: Text(b.name, style: const TextStyle(fontFamily: 'Cairo')))),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedBranchId = val);
                      _loadExpenses();
                    },
                  ),
                ],
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final entry in const [('active', 'النشطة'), ('canceled', 'الملغاة'), ('all', 'الكل')]) ...[
                        ChoiceChip(
                          label: Text(entry.$2, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: _canceledFilter == entry.$1 ? Colors.white : AppColors.textPrimary)),
                          selected: _canceledFilter == entry.$1,
                          selectedColor: AppColors.primary,
                          onSelected: (_) {
                            setState(() => _canceledFilter = entry.$1);
                            _loadExpenses();
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const AppLoadingView(message: 'جاري تحميل المصروفات...')
                : _error != null
                    ? AppErrorView(message: _error!, onRetry: _loadExpenses)
                    : _expenses.isEmpty
                        ? AppEmptyView(
                            title: 'لا توجد مصروفات مطابقة',
                            icon: Icons.receipt_long_outlined,
                            actionLabel: 'تسجيل مصروف جديد',
                            onAction: () => _showExpenseFormSheet(),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadExpenses,
                            color: AppColors.primary,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                              itemCount: _expenses.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final exp = _expenses[i];
                                final isCanceled = exp['is_canceled'] == true;
                                final isStandalone = exp['is_standalone'] == true;
                                final shiftDone = !isStandalone && (exp['shift']?['is_done'] == true);
                                final accountName = (exp['account'] as Map<String, dynamic>?)?['name']?.toString() ?? 'مصروف';
                                final branchName = (exp['beneficiary_branch'] as Map<String, dynamic>?)?['name']?.toString() ?? '';
                                final amount = exp['amount']?.toString() ?? '0.00';

                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isCanceled ? AppColors.error.withValues(alpha: 0.3) : AppColors.border),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: isCanceled ? AppColors.dangerSoft : AppColors.primaryLight,
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
                                                  accountName,
                                                  style: TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: isCanceled ? AppColors.textMuted : AppColors.textPrimary,
                                                    decoration: isCanceled ? TextDecoration.lineThrough : null,
                                                  ),
                                                ),
                                                if ((exp['reason']?.toString() ?? '').isNotEmpty)
                                                  Text(exp['reason'].toString(), style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                                                const SizedBox(height: 4),
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 4,
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  children: [
                                                    AppStatusBadge(
                                                      label: isStandalone ? 'خزينة مباشرة' : 'ضمن وردية',
                                                      color: isStandalone ? AppColors.info : AppColors.accentAmber,
                                                    ),
                                                    Text('$branchName • ${exp['date'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '$amount ج.م',
                                            style: TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 15.5,
                                              fontWeight: FontWeight.w800,
                                              color: isCanceled ? AppColors.textMuted : AppColors.error,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if ((isStandalone && !isCanceled) || !shiftDone) ...[
                                        const Divider(height: 16),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            if (isStandalone && !isCanceled)
                                              TextButton.icon(
                                                icon: const Icon(Icons.edit_outlined, size: 17, color: AppColors.info),
                                                label: const Text('تعديل', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.info)),
                                                onPressed: () => _showExpenseFormSheet(existing: exp),
                                              ),
                                            if (!shiftDone)
                                              TextButton.icon(
                                                icon: Icon(
                                                  isCanceled ? Icons.restore_rounded : Icons.cancel_outlined,
                                                  size: 17,
                                                  color: isCanceled ? AppColors.success : AppColors.error,
                                                ),
                                                label: Text(
                                                  isCanceled ? 'استعادة' : 'إلغاء المصروف',
                                                  style: TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: isCanceled ? AppColors.success : AppColors.error,
                                                  ),
                                                ),
                                                onPressed: () => _toggleCancelRestore(exp),
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
}
