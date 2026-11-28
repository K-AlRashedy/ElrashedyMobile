import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/async_views.dart';
import '../../widgets/numeric_keypad_sheet.dart';

class PayrollScreen extends StatefulWidget {
  const PayrollScreen({super.key});

  @override
  State<PayrollScreen> createState() => _PayrollScreenState();
}

class _PayrollScreenState extends State<PayrollScreen> {
  bool _isLoading = true;
  bool _isGenerating = false;
  String? _error;
  List<Map<String, dynamic>> _payrolls = [];
  String _selectedMonth = DateTime.now().toIso8601String().substring(0, 7);
  int? _selectedBranchId;
  bool _initialized = false;

  ApiClient get _api => context.read<ApiClient>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadPayroll();
    }
  }

  Future<void> _loadPayroll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.get(
        '/api/v1/hr/payroll/',
        queryParams: {
          'month': _selectedMonth,
          'page_size': '100',
          if (_selectedBranchId != null)
            'branch_id': _selectedBranchId.toString(),
        },
      );
      if (!mounted) return;
      if (res is Map<String, dynamic>) {
        final raw = res['results'] as List<dynamic>? ?? [];
        setState(() {
          _payrolls = raw.whereType<Map<String, dynamic>>().toList();
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

  Future<void> _generatePayroll() async {
    if (_isGenerating) return;
    final confirm = await AppConfirmDialog.show(
      context,
      title: 'توليد رواتب شهر $_selectedMonth',
      message:
          'سيقوم النظام باحتساب الأجر الأساسي والبدلات والإضافي وخصم الغياب والجزاءات والسلف آلياً.\nهل تود المتابعة؟',
      confirmLabel: 'تأكيد التوليد',
    );
    if (!confirm || !mounted) return;

    setState(() => _isGenerating = true);
    try {
      final res = await _api.post(
        '/api/v1/hr/payroll/generate/',
        body: {
          'month': _selectedMonth,
          if (_selectedBranchId != null) 'branch_id': _selectedBranchId,
        },
      );
      if (!mounted) return;
      setState(() => _isGenerating = false);
      final count = (res as Map<String, dynamic>)['generated_count'] ?? 0;
      AppFeedback.showSuccess(
        context,
        'تم توليد/تحديث رواتب $count موظف بنجاح',
      );
      _loadPayroll();
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        AppFeedback.showError(context, e.toString());
      }
    }
  }

  Future<void> _paySalary(int id, String name, String net) async {
    final confirm = await AppConfirmDialog.show(
      context,
      title: 'صرف راتب $name',
      message:
          'سيتم صرف مبلغ $net ج.م نقداً من الخزينة الرئيسية وتسجيل الراتب كـ "مسدد".',
      confirmLabel: 'صرف الراتب',
    );
    if (!confirm || !mounted) return;

    try {
      await _api.post('/api/v1/hr/payroll/$id/pay/', body: {});
      if (!mounted) return;
      AppFeedback.showSuccess(
        context,
        'تم صرف الراتب وخصم المبلغ من الخزينة بنجاح',
      );
      _loadPayroll();
    } catch (e) {
      if (mounted) {
        AppFeedback.showError(context, e.toString());
      }
    }
  }

  Future<void> _showPayslipAndExtrasSheet(Map<String, dynamic> p) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _PayslipExtrasSheet(api: _api, payroll: p),
    );
    if (saved == true && mounted) {
      AppFeedback.showSuccess(
        context,
        'تم تحديث مفردات الراتب وإعادة احتساب الصافي',
      );
      _loadPayroll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final branches =
        auth.userBranches.isNotEmpty ? auth.userBranches : auth.allBranches;
    final months = List.generate(12, (idx) {
      final d = DateTime(DateTime.now().year, DateTime.now().month - idx, 1);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'مسيرات الرواتب الشهرية',
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
            onPressed: _loadPayroll,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: _isGenerating
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.auto_mode_rounded),
        label: Text(
          _isGenerating ? 'جاري التوليد...' : 'توليد مسير الرواتب',
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: _isGenerating ? null : _generatePayroll,
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'مسير الشهر',
                      isDense: true,
                    ),
                    value: months.contains(_selectedMonth)
                        ? _selectedMonth
                        : months.first,
                    items: months
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(
                              m,
                              style: const TextStyle(fontFamily: 'Cairo'),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _selectedMonth = v);
                        _loadPayroll();
                      }
                    },
                  ),
                ),
                if (branches.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'الفرع',
                        isDense: true,
                      ),
                      value: branches.any((b) => b.id == _selectedBranchId)
                          ? _selectedBranchId
                          : null,
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text(
                            'كل الفروع',
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                        ),
                        ...branches.map(
                          (b) => DropdownMenuItem<int?>(
                            value: b.id,
                            child: Text(
                              b.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: 'Cairo'),
                            ),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedBranchId = val);
                        _loadPayroll();
                      },
                    ),
                  ),
                ],
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
                              padding:
                                  const EdgeInsets.fromLTRB(16, 12, 16, 92),
                              itemCount: _payrolls.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final p = _payrolls[i];
                                final isPaid = p['is_paid'] == true;
                                final name =
                                    p['employee']?['name']?.toString() ??
                                        p['employee_name']?.toString() ??
                                        'موظف';
                                final net = p['net_salary']?.toString() ?? '0.00';

                                return InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () => _showPayslipAndExtrasSheet(p),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border:
                                          Border.all(color: AppColors.border),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: const TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            AppStatusBadge(
                                              label: isPaid
                                                  ? 'مسدد'
                                                  : 'مستحق للصرف',
                                              color: isPaid
                                                  ? AppColors.success
                                                  : AppColors.accent,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 4,
                                          children: [
                                            Text(
                                              'إجمالي الاستحقاق: ${p['total_due'] ?? 0} ج.م',
                                              style: const TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            Text(
                                              'الخصومات: ${p['total_deductions'] ?? 0} ج.م',
                                              style: const TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 12,
                                                color: AppColors.error,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Divider(height: 18),
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          alignment:
                                              WrapAlignment.spaceBetween,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              'صافي الراتب: $net ج.م',
                                              style: const TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                            if (!isPaid)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        _showPayslipAndExtrasSheet(
                                                      p,
                                                    ),
                                                    child: const Text(
                                                      'مكافآت/خصم',
                                                      style: TextStyle(
                                                        fontFamily: 'Cairo',
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  FilledButton.icon(
                                                    style:
                                                        FilledButton.styleFrom(
                                                      backgroundColor:
                                                          AppColors.success,
                                                    ),
                                                    icon: const Icon(
                                                      Icons.price_check_rounded,
                                                      size: 16,
                                                    ),
                                                    label: const Text(
                                                      'صرف',
                                                      style: TextStyle(
                                                        fontFamily: 'Cairo',
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                    onPressed: () => _paySalary(
                                                      p['id'] as int,
                                                      name,
                                                      net,
                                                    ),
                                                  ),
                                                ],
                                              ),
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

class _PayslipExtrasSheet extends StatefulWidget {
  final ApiClient api;
  final Map<String, dynamic> payroll;

  const _PayslipExtrasSheet({
    required this.api,
    required this.payroll,
  });

  @override
  State<_PayslipExtrasSheet> createState() => _PayslipExtrasSheetState();
}

class _PayslipExtrasSheetState extends State<_PayslipExtrasSheet> {
  late final TextEditingController _bonusesCtrl;
  late final TextEditingController _additionsCtrl;
  late final TextEditingController _overtimeCtrl;
  late final TextEditingController _insuranceCtrl;
  late final TextEditingController _latenessCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.payroll;
    _bonusesCtrl =
        TextEditingController(text: (p['bonuses'] ?? '0').toString());
    _additionsCtrl =
        TextEditingController(text: (p['other_additions'] ?? '0').toString());
    _overtimeCtrl =
        TextEditingController(text: (p['overtime'] ?? '0').toString());
    _insuranceCtrl =
        TextEditingController(text: (p['insurance'] ?? '0').toString());
    _latenessCtrl = TextEditingController(
      text: (p['lateness_deduction'] ?? '0').toString(),
    );
  }

  @override
  void dispose() {
    _bonusesCtrl.dispose();
    _additionsCtrl.dispose();
    _overtimeCtrl.dispose();
    _insuranceCtrl.dispose();
    _latenessCtrl.dispose();
    super.dispose();
  }

  String? _parseNum(TextEditingController ctrl, String fieldLabel) {
    final raw = ctrl.text.trim();
    if (raw.isEmpty) return '0';
    final v = double.tryParse(raw);
    if (v == null || v < 0) {
      setState(() => _error = 'قيمة "$fieldLabel" غير صالحة.');
      return null;
    }
    return AppNumericKeypadSheet.formatNumber(v);
  }

  Future<void> _submit() async {
    final bonuses = _parseNum(_bonusesCtrl, 'مكافآت وحوافز');
    final additions = _parseNum(_additionsCtrl, 'إضافات أخرى');
    final overtime = _parseNum(_overtimeCtrl, 'قيمة الإضافي');
    final insurance = _parseNum(_insuranceCtrl, 'خصم التأمينات');
    final lateness = _parseNum(_latenessCtrl, 'خصم تأخيرات يدوي');
    if (bonuses == null ||
        additions == null ||
        overtime == null ||
        insurance == null ||
        lateness == null) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.api.post(
        '/api/v1/hr/payroll/${widget.payroll['id']}/update/',
        body: {
          'bonuses': bonuses,
          'other_additions': additions,
          'overtime': overtime,
          'insurance': insurance,
          'lateness_deduction': lateness,
        },
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.statusCode == 404
            ? 'تعديل مفردات المرتب من التطبيق غير متاح على إصدار الخادم الحالي.'
            : e.toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  Widget _row(String k, String v, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            k,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            v,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: highlight ? 15 : 13,
              fontWeight: FontWeight.bold,
              color: highlight ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payroll;
    final isPaid = p['is_paid'] == true;
    final totalFixedAllow = (double.tryParse('${p['allowances'] ?? 0}') ?? 0) +
        (double.tryParse('${p['safe_allowance'] ?? 0}') ?? 0) +
        (double.tryParse('${p['transport_allowance'] ?? 0}') ?? 0) +
        (double.tryParse('${p['night_shift'] ?? 0}') ?? 0) +
        (double.tryParse('${p['other_allowances'] ?? 0}') ?? 0);

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
                Expanded(
                  child: Text(
                    'بيان راتب: ${p['employee']?['name'] ?? p['employee_name'] ?? ''}',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  _row('الراتب الأساسي', '${p['basic_salary']} ج.م'),
                  _row(
                    'مجموع البدلات الثابتة',
                    '${totalFixedAllow.toStringAsFixed(2)} ج.م',
                  ),
                  _row(
                    'خصم الغياب',
                    '-${p['absence_deduction'] ?? '0.00'} ج.م',
                  ),
                  _row('خصم السلف', '-${p['advances'] ?? '0.00'} ج.م'),
                  _row(
                    'خصم الجزاءات',
                    '-${p['penalty_deduction'] ?? '0.00'} ج.م',
                  ),
                  const Divider(height: 14),
                  _row(
                    'صافي الراتب الحالي',
                    '${p['net_salary']} ج.م',
                    highlight: true,
                  ),
                ],
              ),
            ),
            if (!isPaid) ...[
              const SizedBox(height: 14),
              if (_error != null) ...[
                AppInlineError(message: _error!),
                const SizedBox(height: 10),
              ],
              const Text(
                'تعديل المكافآت والإضافات والخصومات اليدوية:',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppNumericField(
                      controller: _bonusesCtrl,
                      label: 'مكافآت وحوافز',
                      unit: 'ج.م',
                      allowDecimal: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppNumericField(
                      controller: _additionsCtrl,
                      label: 'إضافات أخرى',
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
                      controller: _overtimeCtrl,
                      label: 'قيمة الإضافي',
                      unit: 'ج.م',
                      allowDecimal: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppNumericField(
                      controller: _insuranceCtrl,
                      label: 'خصم التأمينات',
                      unit: 'ج.م',
                      allowDecimal: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              AppNumericField(
                controller: _latenessCtrl,
                label: 'خصم تأخيرات يدوي',
                unit: 'ج.م',
                allowDecimal: true,
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'حفظ التعديلات وإعادة حساب الصافي',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
