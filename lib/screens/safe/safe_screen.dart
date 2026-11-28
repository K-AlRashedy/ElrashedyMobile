import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/async_views.dart';
import '../../widgets/numeric_keypad_sheet.dart';

class SafeScreen extends StatefulWidget {
  final int initialTab;
  final String? initialAction; // 'add_cashin' | 'add_advance' | 'set_balances'

  const SafeScreen({super.key, this.initialTab = 0, this.initialAction});

  @override
  State<SafeScreen> createState() => _SafeScreenState();
}

class _SafeScreenState extends State<SafeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _uuid = const Uuid();

  List<Map<String, dynamic>> _optBranches = [];
  List<Map<String, dynamic>> _optShifts = [];
  List<Map<String, dynamic>> _optAccounts = [];
  List<Map<String, dynamic>> _optEmployees = [];
  String _operationalDate = '';

  List<Map<String, dynamic>> _shiftsList = [];
  bool _isLoadingShifts = true;
  String? _shiftsError;
  String _shiftFilter = 'pending'; // pending | done | all
  int? _selectedBranchId;

  List<Map<String, dynamic>> _advances = [];
  bool _isLoadingAdvances = false;
  String? _advancesError;

  List<Map<String, dynamic>> _safeBalances = [];
  String _totalSafeBalance = '0.00';
  bool _isLoadingBalances = false;
  String? _balancesError;

  ApiClient get _api => context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        if (_tabController.index == 0) _loadShifts();
        if (_tabController.index == 1) _loadAdvances();
        if (_tabController.index == 2) _loadBalances();
        setState(() {});
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadOptions();
      await Future.wait([
        _loadShifts(),
        if (_tabController.index == 1) _loadAdvances(),
        if (_tabController.index == 2) _loadBalances(),
      ]);
      if (!mounted) return;
      if (widget.initialAction == 'add_cashin') {
        _showCashInFormSheet();
      } else if (widget.initialAction == 'add_advance') {
        _showAdvanceFormSheet();
      } else if (widget.initialAction == 'set_balances') {
        await _loadBalances();
        if (mounted) _showSetBalancesSheet();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is List) return raw.whereType<Map<String, dynamic>>().toList();
    return [];
  }

  Future<void> _loadOptions() async {
    try {
      final res = await _api.get('/api/v1/treasury/options/');
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _optBranches = _mapList(res['branches']);
          _optShifts = _mapList(res['shifts']);
          _optAccounts = _mapList(res['accounts']);
          _optEmployees = _mapList(res['employees']);
          _operationalDate = res['operational_date']?.toString() ?? '';
        });
      }
    } catch (_) {
      // Fallback for users with add_direct_advance but without change_cashin/add_cashin
      try {
        final empRes = await _api.get('/api/v1/hr/employees/', queryParams: {'is_active': 'true', 'page_size': '100'});
        if (empRes is Map<String, dynamic> && mounted) {
          setState(() => _optEmployees = _mapList(empRes['results']));
        }
      } catch (_) {}
    }
  }

  Future<void> _loadShifts() async {
    setState(() { _isLoadingShifts = true; _shiftsError = null; });
    try {
      final params = <String, dynamic>{
        'page_size': '100',
        if (_shiftFilter == 'pending') 'pending': 'true',
        if (_shiftFilter == 'done') 'done': 'true',
        if (_selectedBranchId != null) 'branch_id': _selectedBranchId.toString(),
      };
      final res = await _api.get('/api/v1/treasury/shifts/', queryParams: params);
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _shiftsList = _mapList(res['results']);
          _isLoadingShifts = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _shiftsError = e.toString(); _isLoadingShifts = false; });
    }
  }

  Future<void> _loadAdvances() async {
    setState(() { _isLoadingAdvances = true; _advancesError = null; });
    try {
      final res = await _api.get('/api/v1/treasury/advances/', queryParams: {'page_size': '100'});
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _advances = _mapList(res['results']);
          _isLoadingAdvances = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoadingAdvances = false; _advancesError = e.toString(); });
    }
  }

  Future<void> _loadBalances() async {
    setState(() { _isLoadingBalances = true; _balancesError = null; });
    try {
      final res = await _api.get('/api/v1/treasury/balances/');
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _safeBalances = _mapList(res['balances'] ?? res['results']);
          _totalSafeBalance = res['total']?.toString() ?? '0.00';
          _isLoadingBalances = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoadingBalances = false; _balancesError = e.toString(); });
    }
  }

  Future<void> _approveShift(int shiftId) async {
    final confirm = await AppConfirmDialog.show(
      context,
      title: 'اعتماد أمر التوريد',
      message: 'سيتم اعتماد التوريد وترحيل صافي النقدية والمحافظ إلى الخزائن وتسوية سدادات الموردين نهائياً. هل تريد الاستمرار؟',
      confirmLabel: 'اعتماد وترحيل',
    );
    if (!confirm) return;

    try {
      await _api.post('/api/v1/treasury/shifts/$shiftId/approve/', idempotencyKey: _uuid.v4(), body: const {});
      if (!mounted) return;
      AppFeedback.showSuccess(context, 'تم اعتماد أمر التوريد وترحيل الخزائن بنجاح');
      await Future.wait([_loadShifts(), _loadBalances()]);
    } catch (e) {
      if (mounted) AppFeedback.showError(context, e.toString());
    }
  }

  Future<void> _showShiftDetailSheet(int shiftId) async {
    Map<String, dynamic>? detail;
    bool loading = true;
    String? detailError;
    bool initialLoaded = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> reload() async {
            setSheetState(() { loading = true; detailError = null; });
            try {
              final res = await _api.get('/api/v1/treasury/shifts/$shiftId/');
              if (res is Map<String, dynamic> && ctx.mounted) {
                setSheetState(() { detail = res; loading = false; });
              }
            } catch (e) {
              if (ctx.mounted) setSheetState(() { loading = false; detailError = e.toString(); });
            }
          }

          if (!initialLoaded) {
            initialLoaded = true;
            Future.microtask(reload);
          }

          final d = detail;
          final isDone = d?['is_done'] == true;
          final expenses = _mapList(d?['expenses']);
          final supplierPayments = _mapList(d?['supplier_payments']);
          final advances = _mapList(d?['employee_advances']);

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.90),
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: loading && d == null
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  )
                : (detailError != null || d == null)
                    ? AppErrorView(message: detailError ?? 'تعذر تحميل تفاصيل التوريد', onRetry: reload)
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'توريد #${d['id']} • ${d['branch']?['name'] ?? ''}',
                                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 17.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(sheetCtx)),
                              ],
                            ),
                            Row(
                              children: [
                                Text('${d['shift_display'] ?? d['shift']} • ${d['date']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                                const Spacer(),
                                AppStatusBadge(label: isDone ? 'معتمد' : 'بانتظار المراجعة', color: isDone ? AppColors.success : AppColors.warning),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(16)),
                              child: Column(
                                children: [
                                  _kv('مبيعات النظام (المطلوب)', '${d['total_amount']} ج.م'),
                                  _kv('المبلغ الفعلي الإجمالي', '${d['real_amount']} ج.م', highlight: true),
                                  const Divider(height: 16),
                                  _kv('صافي النقدي المسلّم للخزنة (Cash)', '${d['cash']} ج.م'),
                                  _kv('إنستا باي (InstaPay)', '${d['insta']} ج.م'),
                                  _kv('فودافون كاش / محفظة', '${d['vodafone']} ج.م'),
                                  _kv('فيزا (Visa)', '${d['visa']} ج.م'),
                                  _kv('مرتجعات', '${d['returns']} ج.م'),
                                  _kv('عمولة توصيل', '${d['delivery_commission']} ج.م'),
                                ],
                              ),
                            ),
                            if ((d['notes']?.toString() ?? '').isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('ملاحظات: ${d['notes']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                            ],
                            if (expenses.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              Text('مصروفات الوردية (${expenses.length}):', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                              ...expenses.map((exp) {
                                final canceled = exp['is_canceled'] == true;
                                return ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    '${exp['account_name']} — ${exp['amount']} ج.م',
                                    style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, decoration: canceled ? TextDecoration.lineThrough : null),
                                  ),
                                  subtitle: Text('${exp['reason'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                                  trailing: (!isDone && !canceled)
                                      ? TextButton(
                                          onPressed: () async {
                                            final ok = await AppConfirmDialog.show(
                                              ctx,
                                              title: 'إلغاء مصروف الوردية؟',
                                              message: 'سيتم رد قيمة المصروف إلى نقدية الوردية.',
                                              confirmLabel: 'إلغاء المصروف',
                                              isDestructive: true,
                                            );
                                            if (!ok) return;
                                            try {
                                              await _api.post('/api/v1/treasury/expenses/${exp['id']}/cancel/', body: const {});
                                              await reload();
                                              _loadShifts();
                                            } catch (e) {
                                              if (ctx.mounted) AppFeedback.showError(ctx, e.toString());
                                            }
                                          },
                                          child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppColors.error, fontSize: 12)),
                                        )
                                      : (canceled ? const AppStatusBadge(label: 'ملغي', color: AppColors.error) : null),
                                );
                              }),
                            ],
                            if (supplierPayments.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text('سداد الموردين (${supplierPayments.length}):', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                              ...supplierPayments.map((sp) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text('${sp['supplier_name']} — ${sp['amount']} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                    subtitle: Text('${sp['notes'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                                    trailing: !isDone
                                        ? TextButton(
                                            onPressed: () async {
                                              final ok = await AppConfirmDialog.show(
                                                ctx,
                                                title: 'إلغاء سداد المورد؟',
                                                message: 'سيتم حذف السداد من الوردية ورد المبلغ للنقدية.',
                                                confirmLabel: 'إلغاء',
                                                isDestructive: true,
                                              );
                                              if (!ok) return;
                                              try {
                                                await _api.post('/api/v1/treasury/supplier-payments/${sp['id']}/cancel/', body: const {});
                                                await reload();
                                                _loadShifts();
                                              } catch (e) {
                                                if (ctx.mounted) AppFeedback.showError(ctx, e.toString());
                                              }
                                            },
                                            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppColors.error, fontSize: 12)),
                                          )
                                        : null,
                                  )),
                            ],
                            if (advances.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text('سلف الموظفين بالوردية (${advances.length}):', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                              ...advances.map((adv) => ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text('${adv['employee']?['name'] ?? ''} — ${adv['amount']} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                    subtitle: Text('${adv['notes'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                                    trailing: !isDone
                                        ? TextButton(
                                            onPressed: () async {
                                              final ok = await AppConfirmDialog.show(
                                                ctx,
                                                title: 'إلغاء السلفة؟',
                                                message: 'سيتم حذف السلفة من الوردية ورد المبلغ للنقدية.',
                                                confirmLabel: 'إلغاء',
                                                isDestructive: true,
                                              );
                                              if (!ok) return;
                                              try {
                                                await _api.post('/api/v1/treasury/shift-advances/${adv['id']}/cancel/', body: const {});
                                                await reload();
                                                _loadShifts();
                                              } catch (e) {
                                                if (ctx.mounted) AppFeedback.showError(ctx, e.toString());
                                              }
                                            },
                                            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppColors.error, fontSize: 12)),
                                          )
                                        : null,
                                  )),
                            ],
                            if (!isDone) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.edit_outlined, size: 18),
                                      label: const Text('تعديل التوريد'),
                                      onPressed: () {
                                        Navigator.pop(sheetCtx);
                                        _showCashInFormSheet(existing: d);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: FilledButton.icon(
                                      icon: const Icon(Icons.check_circle_rounded, size: 18),
                                      label: const Text('اعتماد التوريد'),
                                      onPressed: () {
                                        Navigator.pop(sheetCtx);
                                        _approveShift(d['id'] as int);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
          );
        },
      ),
    );
  }

  Widget _kv(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: highlight ? 15 : 13.5,
              fontWeight: FontWeight.bold,
              color: highlight ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCashInFormSheet({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final auth = context.read<AuthProvider>();
    final authBranches = auth.allBranches.isNotEmpty ? auth.allBranches : auth.userBranches;
    final branchItems = _optBranches.isNotEmpty
        ? _optBranches
        : authBranches.map((b) => {'id': b.id, 'name': b.name}).toList();

    int? selectedBranch = isEdit
        ? (existing['branch']?['id'] as int?)
        : (branchItems.isNotEmpty ? branchItems.first['id'] as int? : null);
    if (selectedBranch != null && !branchItems.any((b) => b['id'] == selectedBranch)) {
      branchItems.add({'id': selectedBranch, 'name': existing?['branch']?['name'] ?? 'فرع #$selectedBranch'});
    }

    String selectedShift = isEdit ? (existing['shift']?.toString() ?? 'day') : 'day';
    final dateCtrl = TextEditingController(
      text: isEdit
          ? (existing['date']?.toString() ?? '')
          : (_operationalDate.isNotEmpty ? _operationalDate : DateTime.now().toIso8601String().split('T').first),
    );

    final totalSystemCtrl = TextEditingController(text: (existing?['total_amount'] ?? '0').toString());
    final cashCtrl = TextEditingController(text: (existing?['cash'] ?? '0').toString());
    final instaCtrl = TextEditingController(text: (existing?['insta'] ?? '0').toString());
    final vodafoneCtrl = TextEditingController(text: (existing?['vodafone'] ?? '0').toString());
    final visaCtrl = TextEditingController(text: (existing?['visa'] ?? '0').toString());
    final returnsCtrl = TextEditingController(text: (existing?['returns'] ?? '0').toString());
    final deliveryCommCtrl = TextEditingController(text: (existing?['delivery_commission'] ?? '0').toString());
    final notesCtrl = TextEditingController(text: existing?['notes']?.toString() ?? '');

    final childExpenses = <Map<String, dynamic>>[
      if (isEdit)
        ..._mapList(existing['expenses'])
            .where((e) => e['is_canceled'] != true)
            .map((e) => {
                  'account_id': e['account_id'],
                  'account_name': e['account_name'],
                  'amount': e['amount'].toString(),
                  'reason': e['reason'] ?? '',
                  'beneficiary_branch_id': e['beneficiary_branch']?['id'] ?? selectedBranch,
                }),
    ];
    final existingSupplierSum = isEdit
        ? _mapList(existing['supplier_payments']).fold<double>(0, (s, e) => s + (double.tryParse('${e['amount']}') ?? 0))
        : 0.0;
    final existingAdvanceSum = isEdit
        ? _mapList(existing['employee_advances']).fold<double>(0, (s, e) => s + (double.tryParse('${e['amount']}') ?? 0))
        : 0.0;

    bool submitting = false;
    String? formError;

    double numOf(TextEditingController c) => double.tryParse(c.text.trim()) ?? 0;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final childExpSum = childExpenses.fold<double>(0, (s, e) => s + (double.tryParse(e['amount'].toString()) ?? 0));
          final computedReal = numOf(cashCtrl) +
              numOf(instaCtrl) +
              numOf(vodafoneCtrl) +
              numOf(visaCtrl) +
              numOf(returnsCtrl) +
              numOf(deliveryCommCtrl) +
              childExpSum +
              existingSupplierSum +
              existingAdvanceSum;
          final sysTotal = numOf(totalSystemCtrl);
          final hasDeficit = computedReal + 0.001 < sysTotal;

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.92),
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isEdit ? 'تعديل أمر التوريد #${existing['id']}' : 'تسجيل توريد وردية جديد',
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 17.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(sheetCtx)),
                      ],
                    ),
                    AppInlineError(message: formError),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            value: branchItems.any((b) => b['id'] == selectedBranch) ? selectedBranch : null,
                            decoration: const InputDecoration(labelText: 'الفرع *', isDense: true),
                            items: branchItems
                                .map((b) => DropdownMenuItem<int>(value: b['id'] as int, child: Text('${b['name']}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Cairo'))))
                                .toList(),
                            onChanged: (val) => setSheetState(() => selectedBranch = val),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: selectedShift,
                            decoration: const InputDecoration(labelText: 'الوردية *', isDense: true),
                            items: (_optShifts.isNotEmpty
                                    ? _optShifts
                                    : const [
                                        {'value': 'day', 'label': 'صباحية'},
                                        {'value': 'night', 'label': 'مسائية'},
                                        {'value': 'container', 'label': 'كونتنر'},
                                      ])
                                .map((s) => DropdownMenuItem<String>(value: s['value']?.toString() ?? 'day', child: Text('${s['label']}', style: const TextStyle(fontFamily: 'Cairo'))))
                                .toList(),
                            onChanged: (val) => setSheetState(() => selectedShift = val ?? 'day'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: dateCtrl,
                            readOnly: true,
                            decoration: const InputDecoration(labelText: 'تاريخ التشغيل', prefixIcon: Icon(Icons.calendar_today_rounded, size: 18), isDense: true),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: DateTime.tryParse(dateCtrl.text) ?? DateTime.now(),
                                firstDate: DateTime(2023),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setSheetState(() => dateCtrl.text = picked.toIso8601String().split('T').first);
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppNumericField(
                            controller: totalSystemCtrl,
                            label: 'مبيعات النظام *',
                            unit: 'ج.م',
                            isDense: true,
                            onChanged: (_) => setSheetState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: AppNumericField(
                            controller: cashCtrl,
                            label: 'النقدية المسلّمة',
                            unit: 'ج.م',
                            isDense: true,
                            onChanged: (_) => setSheetState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppNumericField(
                            controller: instaCtrl,
                            label: 'InstaPay',
                            unit: 'ج.م',
                            isDense: true,
                            onChanged: (_) => setSheetState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: AppNumericField(
                            controller: vodafoneCtrl,
                            label: 'فودافون كاش',
                            unit: 'ج.م',
                            isDense: true,
                            onChanged: (_) => setSheetState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppNumericField(
                            controller: visaCtrl,
                            label: 'فيزا (Visa)',
                            unit: 'ج.م',
                            isDense: true,
                            onChanged: (_) => setSheetState(() {}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: AppNumericField(
                            controller: returnsCtrl,
                            label: 'مرتجعات',
                            unit: 'ج.م',
                            isDense: true,
                            onChanged: (_) => setSheetState(() {}),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppNumericField(
                            controller: deliveryCommCtrl,
                            label: 'عمولة دليفري',
                            unit: 'ج.م',
                            isDense: true,
                            onChanged: (_) => setSheetState(() {}),
                          ),
                        ),
                      ],
                    ),
                    if (existingSupplierSum > 0 || existingAdvanceSum > 0) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.infoSoft, borderRadius: BorderRadius.circular(12)),
                        child: Text(
                          'مشمول بالتوريد: سداد موردين (${existingSupplierSum.toStringAsFixed(2)}) • سلف موظفين (${existingAdvanceSum.toStringAsFixed(2)}) ج.م',
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.secondary),
                        ),
                      ),
                    ],
                    if (_optAccounts.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('مصروفات من الوردية (${childExpenses.length})', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                          TextButton.icon(
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('إضافة مصروف', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                            onPressed: () async {
                              int? accId = _optAccounts.first['id'] as int?;
                              int? expBranchId = selectedBranch;
                              final amtC = TextEditingController();
                              final rsnC = TextEditingController();
                              final ok = await showDialog<bool>(
                                context: ctx,
                                builder: (dCtx) => StatefulBuilder(
                                  builder: (dc, setD) => AlertDialog(
                                    title: const Text('مصروف ضمن الوردية', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15.5)),
                                    content: SingleChildScrollView(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          DropdownButtonFormField<int>(
                                            isExpanded: true,
                                            value: accId,
                                            decoration: const InputDecoration(labelText: 'بند المصروف *', isDense: true),
                                            items: _optAccounts
                                                .map((a) => DropdownMenuItem<int>(value: a['id'] as int, child: Text('${a['name']}', style: const TextStyle(fontFamily: 'Cairo'))))
                                                .toList(),
                                            onChanged: (v) => setD(() => accId = v),
                                          ),
                                          if (branchItems.isNotEmpty) ...[
                                            const SizedBox(height: 10),
                                            DropdownButtonFormField<int>(
                                              isExpanded: true,
                                              value: branchItems.any((b) => b['id'] == expBranchId) ? expBranchId : null,
                                              decoration: const InputDecoration(labelText: 'الفرع المستفيد', isDense: true),
                                              items: branchItems
                                                  .map((b) => DropdownMenuItem<int>(value: b['id'] as int, child: Text('${b['name']}', style: const TextStyle(fontFamily: 'Cairo'))))
                                                  .toList(),
                                              onChanged: (v) => setD(() => expBranchId = v),
                                            ),
                                          ],
                                          const SizedBox(height: 10),
                                          AppNumericField(controller: amtC, label: 'المبلغ *', unit: 'ج.م', quickAddValues: const [50, 100, 200]),
                                          const SizedBox(height: 10),
                                          TextField(controller: rsnC, decoration: const InputDecoration(labelText: 'البيان', isDense: true)),
                                        ],
                                      ),
                                    ),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('إلغاء')),
                                      FilledButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('إضافة')),
                                    ],
                                  ),
                                ),
                              );
                              if (ok == true && accId != null && (double.tryParse(amtC.text.trim()) ?? 0) > 0) {
                                final accName = _optAccounts.firstWhere((a) => a['id'] == accId)['name'];
                                setSheetState(() {
                                  childExpenses.add({
                                    'account_id': accId,
                                    'account_name': accName,
                                    'amount': amtC.text.trim(),
                                    'reason': rsnC.text.trim(),
                                    'beneficiary_branch_id': expBranchId ?? selectedBranch,
                                  });
                                });
                              }
                              amtC.dispose();
                              rsnC.dispose();
                            },
                          ),
                        ],
                      ),
                      ...childExpenses.asMap().entries.map((entry) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('${entry.value['account_name']} — ${entry.value['amount']} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.bold)),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 19),
                              onPressed: () => setSheetState(() => childExpenses.removeAt(entry.key)),
                            ),
                          )),
                    ],
                    const SizedBox(height: 10),
                    TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'ملاحظات التوريد', isDense: true)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: hasDeficit ? AppColors.dangerSoft : AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              hasDeficit ? 'عجز (الفعلي أقل من مبيعات النظام!)' : 'الإجمالي الفعلي المحسوب:',
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: hasDeficit ? AppColors.error : AppColors.primaryDark),
                            ),
                          ),
                          Text(
                            '${computedReal.toStringAsFixed(2)} ج.م',
                            style: TextStyle(fontFamily: 'Cairo', fontSize: 15.5, fontWeight: FontWeight.w800, color: hasDeficit ? AppColors.error : AppColors.primaryDark),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: submitting || hasDeficit || selectedBranch == null
                          ? null
                          : () async {
                              setSheetState(() { submitting = true; formError = null; });
                              final payload = <String, dynamic>{
                                'branch_id': selectedBranch,
                                'shift': selectedShift,
                                'date': dateCtrl.text.trim(),
                                'total_amount': numOf(totalSystemCtrl).toStringAsFixed(2),
                                'real_amount': computedReal.toStringAsFixed(2),
                                'cash': numOf(cashCtrl).toStringAsFixed(2),
                                'insta': numOf(instaCtrl).toStringAsFixed(2),
                                'vodafone': numOf(vodafoneCtrl).toStringAsFixed(2),
                                'visa': numOf(visaCtrl).toStringAsFixed(2),
                                'returns': numOf(returnsCtrl).toStringAsFixed(2),
                                'delivery_commission': numOf(deliveryCommCtrl).toStringAsFixed(2),
                                'notes': notesCtrl.text.trim(),
                                'expenses': childExpenses
                                    .map((e) => {
                                          'account_id': e['account_id'],
                                          'amount': e['amount'],
                                          'reason': e['reason'] ?? '',
                                          'beneficiary_branch_id': e['beneficiary_branch_id'] ?? selectedBranch,
                                        })
                                    .toList(),
                              };
                              try {
                                if (isEdit) {
                                  await _api.post('/api/v1/treasury/shifts/${existing['id']}/update/', idempotencyKey: _uuid.v4(), body: payload);
                                } else {
                                  await _api.post('/api/v1/treasury/shifts/create/', idempotencyKey: _uuid.v4(), body: payload);
                                }
                                if (!mounted) return;
                                Navigator.pop(sheetCtx);
                                AppFeedback.showSuccess(context, isEdit ? 'تم تحديث التوريد بنجاح' : 'تم تسجيل توريد الوردية بنجاح');
                                await _loadShifts();
                              } catch (e) {
                                if (ctx.mounted) setSheetState(() { submitting = false; formError = e.toString(); });
                              }
                            },
                      child: submitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(isEdit ? 'حفظ التعديلات' : 'إرسال أمر التوريد'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    dateCtrl.dispose();
    totalSystemCtrl.dispose();
    cashCtrl.dispose();
    instaCtrl.dispose();
    vodafoneCtrl.dispose();
    visaCtrl.dispose();
    returnsCtrl.dispose();
    deliveryCommCtrl.dispose();
    notesCtrl.dispose();
  }

  Future<void> _showAdvanceFormSheet({Map<String, dynamic>? existing}) async {
    if (_optEmployees.isEmpty) await _loadOptions();
    if (!mounted) return;

    final isEdit = existing != null;
    int? selectedEmployeeId = isEdit
        ? (existing['employee']?['id'] as int?)
        : (_optEmployees.isNotEmpty ? _optEmployees.first['id'] as int? : null);
    final amountCtrl = TextEditingController(text: isEdit ? (existing['amount'] ?? '').toString() : '');
    final dateCtrl = TextEditingController(
      text: isEdit ? (existing['date'] ?? '').toString() : DateTime.now().toIso8601String().split('T').first,
    );
    final notesCtrl = TextEditingController(text: existing?['notes']?.toString() ?? '');
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
                      Expanded(
                        child: Text(
                          isEdit ? 'تعديل سلفة الموظف' : 'صرف سلفة موظف مباشرة من الخزينة',
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(sheetCtx)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AppInlineError(message: formError),
                  if (!isEdit) ...[
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: _optEmployees.any((e) => e['id'] == selectedEmployeeId) ? selectedEmployeeId : null,
                      decoration: const InputDecoration(labelText: 'الموظف المستفيد *'),
                      items: _optEmployees
                          .map((e) => DropdownMenuItem<int>(value: e['id'] as int, child: Text('${e['name']} (${e['branch_name'] ?? ''})', style: const TextStyle(fontFamily: 'Cairo'))))
                          .toList(),
                      onChanged: (val) => setSheetState(() => selectedEmployeeId = val),
                    ),
                    const SizedBox(height: 12),
                  ],
                  AppNumericField(
                    controller: amountCtrl,
                    label: 'مبلغ السلفة *',
                    unit: 'ج.م',
                    quickAddValues: const [50, 100, 200, 500],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: dateCtrl,
                    readOnly: true,
                    decoration: const InputDecoration(labelText: 'تاريخ الصرف', prefixIcon: Icon(Icons.calendar_today_rounded, size: 18)),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.tryParse(dateCtrl.text) ?? DateTime.now(),
                        firstDate: DateTime(2023),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setSheetState(() => dateCtrl.text = picked.toIso8601String().split('T').first);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'ملاحظات السلفة')),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                            if (!isEdit && selectedEmployeeId == null) {
                              setSheetState(() => formError = 'يرجى اختيار الموظف.');
                              return;
                            }
                            if (amt <= 0) {
                              setSheetState(() => formError = 'يرجى إدخال مبلغ سلفة أكبر من صفر.');
                              return;
                            }
                            setSheetState(() { submitting = true; formError = null; });
                            try {
                              if (isEdit) {
                                await _api.post(
                                  '/api/v1/treasury/advances/${existing['id']}/update/',
                                  idempotencyKey: _uuid.v4(),
                                  body: {'amount': amountCtrl.text.trim(), 'date': dateCtrl.text.trim(), 'notes': notesCtrl.text.trim()},
                                );
                              } else {
                                await _api.post(
                                  '/api/v1/treasury/advances/create/',
                                  idempotencyKey: _uuid.v4(),
                                  body: {
                                    'employee_id': selectedEmployeeId,
                                    'amount': amountCtrl.text.trim(),
                                    'date': dateCtrl.text.trim(),
                                    'notes': notesCtrl.text.trim(),
                                  },
                                );
                              }
                              if (!mounted) return;
                              Navigator.pop(sheetCtx);
                              AppFeedback.showSuccess(context, isEdit ? 'تم تعديل السلفة بنجاح' : 'تم صرف السلفة وخصمها من الخزينة');
                              await Future.wait([
                                _loadAdvances(),
                                _loadBalances(),
                                if (isEdit && existing['cash_in_id'] != null) _loadShifts(),
                              ]);
                            } catch (e) {
                              if (ctx.mounted) setSheetState(() { submitting = false; formError = e.toString(); });
                            }
                          },
                    child: submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(isEdit ? 'حفظ التعديلات' : 'صرف السلفة'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    amountCtrl.dispose();
    dateCtrl.dispose();
    notesCtrl.dispose();
  }

  Future<void> _showSetBalancesSheet() async {
    if (_safeBalances.isEmpty) {
      await _loadBalances();
      if (!mounted) return;
      if (_balancesError != null || _safeBalances.isEmpty) {
        AppFeedback.showError(context, _balancesError ?? 'تعذر تحميل أرصدة الخزائن الحالية قبل التعديل.');
        return;
      }
    }

    String amountFor(String name) {
      final row = _safeBalances.where((b) => b['name'] == name).firstOrNull;
      return row?['amount']?.toString() ?? '0.00';
    }

    final cashC = TextEditingController(text: amountFor('cash'));
    final instaC = TextEditingController(text: amountFor('instapay'));
    final walletC = TextEditingController(text: amountFor('wallet'));
    final visaC = TextEditingController(text: amountFor('visa'));
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
                      const Expanded(child: Text('ضبط وتعديل أرصدة الخزائن', style: TextStyle(fontFamily: 'Cairo', fontSize: 17.5, fontWeight: FontWeight.bold))),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(sheetCtx)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  AppInlineError(message: formError),
                  AppNumericField(controller: cashC, label: 'الخزنة النقدية الرئيسية (Cash)', unit: 'ج.م'),
                  const SizedBox(height: 10),
                  AppNumericField(controller: instaC, label: 'حساب InstaPay', unit: 'ج.م'),
                  const SizedBox(height: 10),
                  AppNumericField(controller: walletC, label: 'المحفظة الإلكترونية (Vodafone Cash)', unit: 'ج.م'),
                  const SizedBox(height: 10),
                  AppNumericField(controller: visaC, label: 'حساب الفيزا (Visa)', unit: 'ج.م'),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: submitting
                        ? null
                        : () async {
                            for (final pair in [('النقدية', cashC), ('InstaPay', instaC), ('المحفظة', walletC), ('الفيزا', visaC)]) {
                              final v = double.tryParse(pair.$2.text.trim());
                              if (v == null || v < 0) {
                                setSheetState(() => formError = 'أدخل رصيداً صالحاً لحساب ${pair.$1}.');
                                return;
                              }
                            }
                            setSheetState(() { submitting = true; formError = null; });
                            try {
                              await _api.post('/api/v1/treasury/balances/set/', idempotencyKey: _uuid.v4(), body: {
                                'cash': cashC.text.trim(),
                                'instapay': instaC.text.trim(),
                                'wallet': walletC.text.trim(),
                                'visa': visaC.text.trim(),
                              });
                              if (!mounted) return;
                              Navigator.pop(sheetCtx);
                              AppFeedback.showSuccess(context, 'تم تحديث أرصدة الخزائن بنجاح');
                              await _loadBalances();
                            } catch (e) {
                              if (ctx.mounted) setSheetState(() { submitting = false; formError = e.toString(); });
                            }
                          },
                    child: submitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('حفظ الأرصدة الجديدة'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    cashC.dispose();
    instaC.dispose();
    walletC.dispose();
    visaC.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الخزينة والورديات والسلف'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'الورديات والتوريد'),
            Tab(text: 'سلف الموظفين'),
            Tab(text: 'أرصدة الخزائن'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: () {
              if (_tabController.index == 0) _loadShifts();
              if (_tabController.index == 1) _loadAdvances();
              if (_tabController.index == 2) _loadBalances();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: Icon(
          _tabController.index == 0
              ? Icons.add_card_rounded
              : _tabController.index == 1
                  ? Icons.money_off_rounded
                  : Icons.tune_rounded,
        ),
        label: Text(
          _tabController.index == 0
              ? 'تسجيل توريد وردية'
              : _tabController.index == 1
                  ? 'صرف سلفة موظف'
                  : 'ضبط أرصدة الخزائن',
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        onPressed: () {
          if (_tabController.index == 0) _showCashInFormSheet();
          if (_tabController.index == 1) _showAdvanceFormSheet();
          if (_tabController.index == 2) _showSetBalancesSheet();
        },
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildShiftsTab(), _buildAdvancesTab(), _buildBalancesTab()],
      ),
    );
  }

  Widget _buildShiftsTab() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final entry in const [('pending', 'المعلقة'), ('done', 'المعتمدة'), ('all', 'الكل')]) ...[
                      ChoiceChip(
                        label: Text(entry.$2, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: _shiftFilter == entry.$1 ? Colors.white : AppColors.textPrimary)),
                        selected: _shiftFilter == entry.$1,
                        selectedColor: AppColors.primary,
                        onSelected: (_) {
                          setState(() => _shiftFilter = entry.$1);
                          _loadShifts();
                        },
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
              if (_optBranches.isNotEmpty) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  isExpanded: true,
                  value: _optBranches.any((b) => b['id'] == _selectedBranchId) ? _selectedBranchId : null,
                  decoration: const InputDecoration(labelText: 'تصفية حسب الفرع', isDense: true),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('كل الفروع', style: TextStyle(fontFamily: 'Cairo'))),
                    ..._optBranches.map((b) => DropdownMenuItem<int?>(value: b['id'] as int, child: Text('${b['name']}', style: const TextStyle(fontFamily: 'Cairo')))),
                  ],
                  onChanged: (val) {
                    setState(() => _selectedBranchId = val);
                    _loadShifts();
                  },
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _isLoadingShifts
              ? const AppLoadingView(message: 'جاري تحميل أوامر التوريد...')
              : _shiftsError != null
                  ? AppErrorView(message: _shiftsError!, onRetry: _loadShifts)
                  : _shiftsList.isEmpty
                      ? AppEmptyView(
                          title: 'لا توجد أوامر توريد مطابقة',
                          actionLabel: 'تسجيل توريد جديد',
                          onAction: () => _showCashInFormSheet(),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadShifts,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                            itemCount: _shiftsList.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final s = _shiftsList[i];
                              final isDone = s['is_done'] == true;
                              final branchName = s['branch']?['name']?.toString() ?? 'الفرع';
                              final shiftLabel = s['shift_display']?.toString() ?? s['shift']?.toString() ?? '';
                              return InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showShiftDetailSheet(s['id'] as int),
                                child: Container(
                                  padding: const EdgeInsets.all(15),
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
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: isDone ? AppColors.primaryLight : AppColors.warningSoft,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Icon(isDone ? Icons.verified_rounded : Icons.lock_clock_rounded, color: isDone ? AppColors.primary : AppColors.warning, size: 22),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  '#${s['id']} • $branchName ($shiftLabel)',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold),
                                                ),
                                                Text(
                                                  '${s['date']} • نقدي: ${s['cash']} ج.م',
                                                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.textSecondary),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text('${s['real_amount']} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                              const SizedBox(height: 2),
                                              AppStatusBadge(label: isDone ? 'معتمد' : 'معلق', color: isDone ? AppColors.success : AppColors.warning),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (!isDone) ...[
                                        const Divider(height: 18),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: () => _showShiftDetailSheet(s['id'] as int),
                                              child: const Text('تفاصيل ومراجعة', style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5)),
                                            ),
                                            const SizedBox(width: 8),
                                            FilledButton.icon(
                                              icon: const Icon(Icons.check_circle_rounded, size: 16),
                                              label: const Text('اعتماد سريع', style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.bold)),
                                              onPressed: () => _approveShift(s['id'] as int),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _buildAdvancesTab() {
    if (_isLoadingAdvances) return const AppLoadingView(message: 'جاري تحميل سلف الموظفين...');
    if (_advancesError != null) return AppErrorView(message: _advancesError!, onRetry: _loadAdvances);
    if (_advances.isEmpty) {
      return AppEmptyView(
        title: 'لا توجد سلف مسجلة',
        actionLabel: 'صرف سلفة موظف',
        onAction: () => _showAdvanceFormSheet(),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAdvances,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
        itemCount: _advances.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final adv = _advances[i];
          final isApproved = adv['is_approved'] == true;
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.dangerSoft, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.money_off_rounded, color: AppColors.error, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(adv['employee']?['name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(
                        '${adv['date'] ?? ''}${adv['notes'] != null && adv['notes'].toString().isNotEmpty ? " • ${adv['notes']}" : ""}',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Text('${adv['amount']} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.error)),
                if (!isApproved)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.info),
                    onPressed: () => _showAdvanceFormSheet(existing: adv),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBalancesTab() {
    if (_isLoadingBalances) return const AppLoadingView(message: 'جاري تحميل أرصدة الخزائن...');
    if (_balancesError != null) return AppErrorView(message: _balancesError!, onRetry: _loadBalances);
    return RefreshIndicator(
      onRefresh: _loadBalances,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('إجمالي السيولة بجميع الخزائن', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.white70)),
                const SizedBox(height: 6),
                Text('$_totalSafeBalance ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ..._safeBalances.map((safe) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(safe['label']?.toString() ?? safe['name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                    Text('${safe['amount']} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
