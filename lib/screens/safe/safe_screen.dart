import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/async_views.dart';

class SafeScreen extends StatefulWidget {
  const SafeScreen({super.key});

  @override
  State<SafeScreen> createState() => _SafeScreenState();
}

class _SafeScreenState extends State<SafeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _api = ApiClient();

  // Tab 1: Pending Shifts
  List<dynamic> _pendingShifts = [];
  bool _isLoadingPending = true;

  // Tab 2: Direct Advances
  List<dynamic> _advances = [];
  bool _isLoadingAdvances = false;

  // Tab 3: Safe Balances
  List<dynamic> _safeBalances = [];
  bool _isLoadingBalances = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _advances.isEmpty) {
        _loadAdvances();
      } else if (_tabController.index == 2 && _safeBalances.isEmpty) {
        _loadBalances();
      }
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      _api.setBaseUrl(auth.serverUrl);
      _api.setToken(auth.token);
      _loadPendingShifts();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingShifts() async {
    setState(() => _isLoadingPending = true);
    try {
      final res = await _api.get('/api/v1/safe/pending/');
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _pendingShifts = res['pending_shifts'] as List<dynamic>? ?? res['results'] as List<dynamic>? ?? [];
          _isLoadingPending = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingPending = false);
    }
  }

  Future<void> _loadAdvances() async {
    setState(() => _isLoadingAdvances = true);
    try {
      final res = await _api.get('/api/v1/treasury/advances/');
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _advances = res['results'] as List<dynamic>? ?? res['advances'] as List<dynamic>? ?? [];
          _isLoadingAdvances = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAdvances = false);
    }
  }

  Future<void> _loadBalances() async {
    setState(() => _isLoadingBalances = true);
    try {
      final res = await _api.get('/api/v1/treasury/balances/');
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _safeBalances = res['results'] as List<dynamic>? ?? res['balances'] as List<dynamic>? ?? [];
          _isLoadingBalances = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingBalances = false);
    }
  }

  Future<void> _approveShift(int shiftId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('اعتماد إغلاق الوردية', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: const Text('سيتم ترحيل مبالغ الوردية والمصروفات إلى الخزينة الرئيسية واعتماد الإغلاق نهائياً. هل تريد الاستمرار؟', style: TextStyle(fontFamily: 'Cairo')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('اعتماد الوردية', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _api.post('/api/v1/treasury/shifts/$shiftId/approve/', body: {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم اعتماد إغلاق الوردية وترحيل الخزينة بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
        );
        _loadPendingShifts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showCloseShiftSheet() {
    final branches = context.read<AuthProvider>().userBranches;
    int? selectedBranch = branches.isNotEmpty ? branches.first.id : null;
    String selectedShift = 'صباحي';
    final cashController = TextEditingController();
    final passwordController = TextEditingController();
    final notesController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('تسليم الخزينة وإغلاق الوردية', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(sheetCtx)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (branches.isNotEmpty)
                    DropdownButtonFormField<int>(
                      initialValue: selectedBranch,
                      decoration: InputDecoration(
                        labelText: 'الفرع',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, style: const TextStyle(fontFamily: 'Cairo')))).toList(),
                      onChanged: (val) => setSheetState(() => selectedBranch = val),
                    ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedShift,
                    decoration: InputDecoration(
                      labelText: 'فترة الوردية',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'صباحي', child: Text('وردية صباحية', style: TextStyle(fontFamily: 'Cairo'))),
                      DropdownMenuItem(value: 'مسائي', child: Text('وردية مسائية', style: TextStyle(fontFamily: 'Cairo'))),
                      DropdownMenuItem(value: 'ليلي', child: Text('وردية ليلية', style: TextStyle(fontFamily: 'Cairo'))),
                    ],
                    onChanged: (val) => setSheetState(() => selectedShift = val ?? 'صباحي'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: cashController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'النقدية الفعلية في الدرج (ج.م) *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'كلمة مرور الكاشير للتأكيد *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'ملاحظات التسليم (اختياري)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
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
                            if (selectedBranch == null || cashController.text.trim().isEmpty || passwordController.text.trim().isEmpty) return;
                            setSheetState(() => isSubmitting = true);
                            try {
                              await _api.post('/api/v1/treasury/shifts/create/', body: {
                                'branch': selectedBranch,
                                'shift': selectedShift,
                                'real_cash': cashController.text.trim(),
                                'password': passwordController.text.trim(),
                                'notes': notesController.text.trim(),
                              });
                              if (mounted) {
                                Navigator.pop(sheetCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم تسليم الخزينة وإغلاق الوردية بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
                                );
                                _loadPendingShifts();
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
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('تأكيد وإرسال الإغلاق', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddAdvanceSheet() {
    final branches = context.read<AuthProvider>().userBranches;
    int? selectedBranch = branches.isNotEmpty ? branches.first.id : null;
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    final notesController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('تسجيل سلفة موظف مباشرة', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(sheetCtx)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (branches.isNotEmpty)
                    DropdownButtonFormField<int>(
                      initialValue: selectedBranch,
                      decoration: InputDecoration(
                        labelText: 'الفرع الخازن',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, style: const TextStyle(fontFamily: 'Cairo')))).toList(),
                      onChanged: (val) => setSheetState(() => selectedBranch = val),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'اسم الموظف / المستفيد *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'مبلغ السلفة (ج.م) *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'ملاحظات وسبب السلفة',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
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
                            if (amountController.text.trim().isEmpty || nameController.text.trim().isEmpty) return;
                            setSheetState(() => isSubmitting = true);
                            try {
                              await _api.post('/api/v1/treasury/advances/create/', body: {
                                'branch_id': selectedBranch,
                                'employee_name': nameController.text.trim(),
                                'amount': amountController.text.trim(),
                                'notes': notesController.text.trim(),
                              });
                              if (mounted) {
                                Navigator.pop(sheetCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم تسجيل السلفة وخصمها من الخزينة بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
                                );
                                _loadAdvances();
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
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('صرف السلفة من الخزينة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text('إدارة الخزينة والورديات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'الورديات المعلقة'),
            Tab(text: 'سلفيات الخزينة'),
            Tab(text: 'أرصدة الخزائن'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: () {
              if (_tabController.index == 0) _loadPendingShifts();
              if (_tabController.index == 1) _loadAdvances();
              if (_tabController.index == 2) _loadBalances();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_card_rounded),
            tooltip: 'إغلاق وردية',
            onPressed: _showCloseShiftSheet,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: Icon(_tabController.index == 1 ? Icons.money_off_rounded : Icons.lock_clock_rounded),
        label: Text(
          _tabController.index == 1 ? 'صرف سلفة موظف' : 'تسليم وردية',
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        onPressed: _tabController.index == 1 ? _showAddAdvanceSheet : _showCloseShiftSheet,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Pending Shifts
          _isLoadingPending
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _pendingShifts.isEmpty
                  ? const Center(child: AppEmptyView(title: 'لا توجد ورديات معلقة حالياً'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: _pendingShifts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final s = _pendingShifts[i];
                        final branch = s['branch_name'] ?? 'الفرع';
                        final shift = s['shift'] ?? 'الوردية';
                        final date = s['date'] ?? '';
                        final cash = s['real_cash'] ?? s['cash'] ?? 0;

                        return Container(
                          padding: const EdgeInsets.all(16),
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
                                      color: AppColors.accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.lock_clock_rounded, color: AppColors.accent, size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(branch, style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold)),
                                        Text('وردية: $shift • $date', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Text('$cash ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                ],
                              ),
                              const Divider(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                                    label: const Text('اعتماد وترحيل الخزينة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                    onPressed: () => _approveShift(s['id']),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),

          // Tab 2: Direct Advances
          _isLoadingAdvances
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _advances.isEmpty
                  ? AppEmptyView(title: 'لا توجد سلفيات مسجلة', actionLabel: 'صرف سلفة موظف', onAction: _showAddAdvanceSheet)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      itemCount: _advances.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final adv = _advances[i];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.money_off_rounded, color: AppColors.error, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      adv['employee_name'] ?? adv['employee']?['name'] ?? '',
                                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${adv['date'] ?? ''} • ${adv['notes'] ?? ''}',
                                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${adv['amount']} ج.م',
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.error),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

          // Tab 3: Safe Balances
          _isLoadingBalances
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _safeBalances.isEmpty
                  ? const Center(child: AppEmptyView(title: 'لا توجد بيانات أرصدة خزائن حالياً'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _safeBalances.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final b = _safeBalances[i];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.account_balance_wallet_rounded, color: AppColors.primary, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      b['name'] ?? b['account_name'] ?? '',
                                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      b['branch_name'] ?? 'المركز الرئيسي',
                                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                '${b['balance']} ج.م',
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }
}
