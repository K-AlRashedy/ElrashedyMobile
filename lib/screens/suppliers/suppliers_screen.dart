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

class SuppliersScreen extends StatefulWidget {
  final int initialTab;
  final String? initialAction; // 'add_supplier' | 'add_bill'
  final bool withBalanceOnly;

  const SuppliersScreen({
    super.key,
    this.initialTab = 0,
    this.initialAction,
    this.withBalanceOnly = false,
  });

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _uuid = const Uuid();
  Timer? _supplierDebounce;
  ApiCancelToken? _supplierCancelToken;

  // Tab 0: Suppliers
  List<Map<String, dynamic>> _suppliers = [];
  bool _isLoadingSuppliers = true;
  String? _suppliersError;
  late bool _withBalanceOnly;
  String _supplierSearch = '';
  String _totalDebt = '0.00';
  String _totalAdvance = '0.00';
  String _netBalance = '0.00';

  // Tab 1: Purchase Bills
  List<Map<String, dynamic>> _bills = [];
  bool _isLoadingBills = false;
  String? _billsError;
  String _billStatusFilter = ''; // '' | 'pend' | 'conf'
  String _billPayFilter = ''; // '' | 'pend' | 'paid'
  String _billSearch = '';

  // Tab 2: Supplier Payment Receipts
  List<Map<String, dynamic>> _receipts = [];
  bool _isLoadingReceipts = false;
  String? _receiptsError;

  // Tab 3: Operations Log
  List<Map<String, dynamic>> _operations = [];
  bool _isLoadingOperations = false;
  String? _operationsError;

  // Stock Products for Bills
  List<Map<String, dynamic>> _stockProducts = [];
  String? _stockProductsError;

  ApiClient get _api => context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    _withBalanceOnly = widget.withBalanceOnly;
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        if (_tabController.index == 0) _loadSuppliers();
        if (_tabController.index == 1) _loadBills();
        if (_tabController.index == 2) _loadReceipts();
        if (_tabController.index == 3) _loadOperations();
        setState(() {});
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        _loadSuppliers(),
        _loadStockProducts(),
        if (_tabController.index == 1) _loadBills(),
        if (_tabController.index == 2) _loadReceipts(),
        if (_tabController.index == 3) _loadOperations(),
      ]);
      if (!mounted) return;
      if (widget.initialAction == 'add_supplier') {
        _showSupplierFormSheet();
      } else if (widget.initialAction == 'add_bill') {
        _showBillFormSheet();
      }
    });
  }

  @override
  void dispose() {
    _supplierDebounce?.cancel();
    _supplierCancelToken?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is List) return raw.whereType<Map<String, dynamic>>().toList();
    return [];
  }

  Future<void> _loadStockProducts() async {
    _stockProductsError = null;
    try {
      final loaded = <Map<String, dynamic>>[];
      int page = 1;
      bool hasNext = true;
      while (hasNext && page <= 10) {
        final res = await _api.get('/api/v1/catalog/products/', queryParams: {
          'is_stock': 'true',
          'page': page,
          'page_size': '100',
        });
        if (res is! Map<String, dynamic>) break;
        loaded.addAll(_mapList(res['results']));
        hasNext = res['has_next'] == true;
        page++;
      }
      if (mounted) setState(() => _stockProducts = loaded);
    } catch (e) {
      if (mounted) setState(() => _stockProductsError = e.toString());
    }
  }

  Future<void> _loadSuppliers() async {
    _supplierCancelToken?.cancel();
    final token = ApiCancelToken();
    _supplierCancelToken = token;

    setState(() { _isLoadingSuppliers = true; _suppliersError = null; });
    try {
      final results = await Future.wait([
        _api.get('/api/v1/suppliers/', queryParams: {
          'page_size': '100',
          if (_withBalanceOnly) 'with_balance': 'true',
          if (_supplierSearch.trim().isNotEmpty) 'q': _supplierSearch.trim(),
        }, cancelToken: token),
        _api.get('/api/v1/suppliers/balance/', queryParams: {'page_size': '1'}, cancelToken: token)
            .catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;
      final listRes = results[0];
      final balRes = results[1];
      setState(() {
        if (listRes is Map<String, dynamic>) {
          _suppliers = _mapList(listRes['results'] ?? listRes['suppliers']);
        }
        if (balRes is Map<String, dynamic>) {
          _totalDebt = balRes['total_debt']?.toString() ?? '0.00';
          _totalAdvance = balRes['total_advance']?.toString() ?? '0.00';
          _netBalance = balRes['net_balance']?.toString() ?? '0.00';
        }
        _isLoadingSuppliers = false;
      });
    } on ApiException catch (e) {
      if (e.message == 'تم إلغاء الطلب.') return;
      if (mounted) setState(() { _isLoadingSuppliers = false; _suppliersError = e.message; });
    } catch (e) {
      if (mounted) setState(() { _isLoadingSuppliers = false; _suppliersError = e.toString(); });
    }
  }

  Future<void> _loadBills() async {
    setState(() { _isLoadingBills = true; _billsError = null; });
    try {
      final params = <String, dynamic>{
        'page_size': '100',
        if (_billStatusFilter.isNotEmpty) 'status': _billStatusFilter,
        if (_billPayFilter.isNotEmpty) 'Pstatus': _billPayFilter,
      };
      final res = await _api.get('/api/v1/bills/', queryParams: params);
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _bills = _mapList(res['results']);
          _isLoadingBills = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoadingBills = false; _billsError = e.toString(); });
    }
  }

  Future<void> _loadReceipts() async {
    setState(() { _isLoadingReceipts = true; _receiptsError = null; });
    try {
      final res = await _api.get('/api/v1/purchases/receipts/', queryParams: {'page_size': '100'});
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _receipts = _mapList(res['results']);
          _isLoadingReceipts = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoadingReceipts = false; _receiptsError = e.toString(); });
    }
  }

  Future<void> _loadOperations() async {
    setState(() { _isLoadingOperations = true; _operationsError = null; });
    try {
      final res = await _api.get('/api/v1/purchases/operations/', queryParams: {'page_size': '100'});
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _operations = _mapList(res['results']);
          _isLoadingOperations = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoadingOperations = false; _operationsError = e.toString(); });
    }
  }

  Future<void> _showSupplierFormSheet({Map<String, dynamic>? existing}) async {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?['name']?.toString() ?? '');
    final phoneCtrl = TextEditingController(text: existing?['phone']?.toString() ?? '');
    final addressCtrl = TextEditingController(text: (existing?['address'] ?? existing?['adress'] ?? '').toString());
    final selectedProducts = <int>{
      ...((existing?['product_ids'] as List<dynamic>? ?? [])
          .map((e) => e is int ? e : int.tryParse(e.toString()))
          .whereType<int>()),
    };
    String productFilter = '';
    bool submitting = false;
    String? formError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final visibleStock = _stockProducts.where((p) {
            if (productFilter.isEmpty) return true;
            return (p['name']?.toString() ?? '').toLowerCase().contains(productFilter.toLowerCase());
          }).toList();

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.90),
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
                            isEdit ? 'تعديل بيانات المورد' : 'إضافة مورد جديد',
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 17.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(sheetCtx)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AppInlineError(message: formError),
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم المورد / الشركة *')),
                    const SizedBox(height: 10),
                    AppNumericField(
                      controller: phoneCtrl,
                      label: 'رقم الهاتف',
                      prefixIcon: Icons.phone_rounded,
                      allowDecimal: false,
                      isStringMode: true,
                      maxLength: 15,
                    ),
                    const SizedBox(height: 10),
                    TextField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'العنوان')),
                    if (_stockProducts.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text('أصناف المورد المعتمدة (${selectedProducts.length} محدد):', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        decoration: const InputDecoration(hintText: 'فلترة الأصناف المخزنية...', prefixIcon: Icon(Icons.search_rounded, size: 19), isDense: true),
                        onChanged: (v) => setSheetState(() => productFilter = v),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: visibleStock.take(40).map((p) {
                          final pid = p['id'] as int;
                          final sel = selectedProducts.contains(pid);
                          return FilterChip(
                            label: Text('${p['name']}', style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: sel ? Colors.white : AppColors.textPrimary)),
                            selected: sel,
                            selectedColor: AppColors.primary,
                            checkmarkColor: Colors.white,
                            onSelected: (v) {
                              setSheetState(() {
                                if (v) {
                                  selectedProducts.add(pid);
                                } else {
                                  selectedProducts.remove(pid);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: submitting
                          ? null
                          : () async {
                              if (nameCtrl.text.trim().isEmpty) {
                                setSheetState(() => formError = 'يرجى إدخال اسم المورد.');
                                return;
                              }
                              setSheetState(() { submitting = true; formError = null; });
                              final body = {
                                'name': nameCtrl.text.trim(),
                                'phone': phoneCtrl.text.trim(),
                                'address': addressCtrl.text.trim(),
                                'product_ids': selectedProducts.toList(),
                              };
                              try {
                                if (isEdit) {
                                  await _api.post('/api/v1/suppliers/${existing['id']}/update/', idempotencyKey: _uuid.v4(), body: body);
                                } else {
                                  await _api.post('/api/v1/suppliers/create/', idempotencyKey: _uuid.v4(), body: body);
                                }
                                if (!mounted) return;
                                Navigator.pop(sheetCtx);
                                AppFeedback.showSuccess(context, isEdit ? 'تم تحديث بيانات المورد' : 'تمت إضافة المورد بنجاح');
                                await _loadSuppliers();
                              } catch (e) {
                                if (ctx.mounted) setSheetState(() { submitting = false; formError = e.toString(); });
                              }
                            },
                      child: submitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(isEdit ? 'حفظ التعديلات' : 'حفظ المورد'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    nameCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
  }

  void _showSupplierDetailSheet(Map<String, dynamic> sup) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(sup['name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold))),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(sheetCtx)),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  _kv('صافي رصيد المورد', '${sup['balance'] ?? '0.00'} ج.م', highlight: true),
                  _kv('إجمالي المديونية المؤكدة', '${sup['confirmed_debt'] ?? '0.00'} ج.م'),
                  _kv('الدفعات المقدمة لدى المورد', '${sup['advance_payment'] ?? '0.00'} ج.م'),
                  _kv('رقم الهاتف', sup['phone']?.toString().isNotEmpty == true ? sup['phone'].toString() : '—'),
                  _kv('العنوان', (sup['address'] ?? sup['adress'] ?? '').toString().isNotEmpty ? (sup['address'] ?? sup['adress']).toString() : '—'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  label: const Text('سداد دفعة للمورد'),
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    _showPaymentDialog(supplierId: sup['id'] as int, title: 'سداد دفعة للمورد ${sup['name']}');
                  },
                ),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('تعديل'),
                  onPressed: () {
                    Navigator.pop(sheetCtx);
                    _showSupplierFormSheet(existing: sup);
                  },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('حذف'),
                  onPressed: () async {
                    final confirmed = await AppConfirmDialog.show(
                      sheetCtx,
                      title: 'حذف المورد؟',
                      message: 'هل أنت متأكد من حذف "${sup['name']}" نهائياً؟',
                      confirmLabel: 'حذف',
                      isDestructive: true,
                    );
                    if (!confirmed || !mounted) return;
                    Navigator.pop(sheetCtx);
                    try {
                      await _api.delete('/api/v1/suppliers/${sup['id']}/delete/');
                      if (!mounted) return;
                      AppFeedback.showSuccess(context, 'تم حذف المورد بنجاح');
                      await _loadSuppliers();
                    } catch (e) {
                      if (mounted) AppFeedback.showError(context, e.toString());
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPaymentDialog({int? supplierId, int? billId, required String title, String? suggestedAmount}) async {
    final amountCtrl = TextEditingController(text: suggestedAmount ?? '');
    final notesCtrl = TextEditingController();
    String method = 'cash';
    bool submitting = false;
    String? dialogError;

    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppInlineError(message: dialogError),
                AppNumericField(
                  controller: amountCtrl,
                  label: billId != null ? 'مبلغ السداد (عدد صحيح) *' : 'مبلغ السداد *',
                  unit: 'ج.م',
                  allowDecimal: billId == null,
                  quickAddValues: const [100, 500, 1000, 5000],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  value: method,
                  decoration: const InputDecoration(labelText: 'الخزنة المسدد منها'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('الخزنة النقدية (Cash)', style: TextStyle(fontFamily: 'Cairo'))),
                    DropdownMenuItem(value: 'instapay', child: Text('InstaPay', style: TextStyle(fontFamily: 'Cairo'))),
                    DropdownMenuItem(value: 'wallet', child: Text('محفظة إلكترونية', style: TextStyle(fontFamily: 'Cairo'))),
                    DropdownMenuItem(value: 'visa', child: Text('فيزا (Visa)', style: TextStyle(fontFamily: 'Cairo'))),
                  ],
                  onChanged: (v) => setDlg(() => method = v ?? 'cash'),
                ),
                const SizedBox(height: 12),
                TextField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'ملاحظات السداد')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('إلاء' == 'إلاء' ? 'إلغاء' : 'إلغاء')),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      final amt = double.tryParse(amountCtrl.text.trim()) ?? 0;
                      if (amt <= 0) {
                        setDlg(() => dialogError = 'يرجى إدخال مبلغ سداد أكبر من صفر.');
                        return;
                      }
                      setDlg(() { submitting = true; dialogError = null; });
                      try {
                        final endpoint = billId != null ? '/api/v1/bills/$billId/payment/' : '/api/v1/suppliers/$supplierId/payment/';
                        await _api.post(endpoint, idempotencyKey: _uuid.v4(), body: {
                          'amount': amountCtrl.text.trim(),
                          'payment_method': method,
                          'notes': notesCtrl.text.trim(),
                        });
                        if (!mounted) return;
                        Navigator.pop(dlgCtx);
                        AppFeedback.showSuccess(context, 'تم تسجيل السداد وإصدار إيصال الصرف بنجاح');
                        await Future.wait([_loadSuppliers(), _loadBills(), _loadReceipts(), _loadOperations()]);
                      } catch (e) {
                        if (ctx.mounted) setDlg(() { submitting = false; dialogError = e.toString(); });
                      }
                    },
              child: submitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('تأكيد السداد'),
            ),
          ],
        ),
      ),
    );
    amountCtrl.dispose();
    notesCtrl.dispose();
  }

  Future<void> _showBillFormSheet({Map<String, dynamic>? existing}) async {
    if (_stockProducts.isEmpty) await _loadStockProducts();
    if (_suppliers.isEmpty) await _loadSuppliers();
    if (!mounted) return;

    final isEdit = existing != null;
    final auth = context.read<AuthProvider>();
    final branches = (auth.allBranches.isNotEmpty ? auth.allBranches : auth.userBranches)
        .map((b) => {'id': b.id, 'name': b.name})
        .toList();

    int? selectedBranch = isEdit ? (existing['branch_id'] as int?) : (branches.isNotEmpty ? branches.first['id'] as int? : null);
    if (isEdit && selectedBranch != null && !branches.any((b) => b['id'] == selectedBranch)) {
      branches.add({'id': selectedBranch, 'name': existing['branch']?['name'] ?? 'فرع #$selectedBranch'});
    }

    int? selectedSupplierId = isEdit
        ? (existing['supplier_id'] as int?)
        : (_suppliers.isNotEmpty ? _suppliers.first['id'] as int? : null);

    final today = DateTime.now().toIso8601String().split('T').first;
    final dateCtrl = TextEditingController(text: isEdit ? (existing['date']?.toString() ?? today) : today);
    final endDateCtrl = TextEditingController(text: isEdit ? (existing['enddate']?.toString() ?? today) : today);
    final discountCtrl = TextEditingController(
      text: isEdit ? ((double.tryParse(existing['discount']?.toString() ?? '0') ?? 0).toInt().toString()) : '0',
    );

    final lines = <Map<String, dynamic>>[];
    if (isEdit) {
      for (final item in _mapList(existing['items'])) {
        lines.add({
          'product_id': item['product_id'],
          'product_name': item['product_name'],
          'quantity': (item['quantity'] ?? 1).toString(),
          'price': (item['price'] ?? '1').toString(),
          'discount': (item['discount'] ?? 0).toString(),
        });
      }
    }

    bool submitting = false;
    String? formError = _stockProductsError;

    Future<void> openLineDialog(BuildContext ctx, StateSetter setSheetState, {int? editIdx}) async {
      final isEditingLine = editIdx != null;
      final line = isEditingLine ? lines[editIdx] : null;
      int? pid = isEditingLine ? line!['product_id'] as int? : (_stockProducts.isNotEmpty ? _stockProducts.first['id'] as int? : null);
      final firstPrice = (_stockProducts.isNotEmpty ? (_stockProducts.first['price'] ?? 10) : 10).toString();
      final qC = TextEditingController(text: isEditingLine ? line!['quantity'].toString() : '1');
      final pC = TextEditingController(text: isEditingLine ? line!['price'].toString() : ((double.tryParse(firstPrice) ?? 0) > 0 ? firstPrice : '10'));
      final dC = TextEditingController(text: isEditingLine ? line!['discount'].toString() : '0');
      String? lineError;

      final saved = await showDialog<bool>(
        context: ctx,
        builder: (dCtx) => StatefulBuilder(
          builder: (dc, setD) => AlertDialog(
            title: Text(isEditingLine ? 'تعديل بند المشتريات' : 'إضافة بند مشتريات', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppInlineError(message: lineError),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    value: _stockProducts.any((p) => p['id'] == pid) ? pid : null,
                    decoration: const InputDecoration(labelText: 'الصنف المخزني *'),
                    items: _stockProducts
                        .map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text('${p['name']}', style: const TextStyle(fontFamily: 'Cairo'))))
                        .toList(),
                    onChanged: isEditingLine
                        ? null
                        : (v) {
                            setD(() {
                              pid = v;
                              final found = _stockProducts.where((x) => x['id'] == v).firstOrNull;
                              final pr = (found?['price'] as num?)?.toDouble() ?? 0;
                              if (pr > 0) pC.text = AppNumericKeypadSheet.formatNumber(pr);
                            });
                          },
                  ),
                  const SizedBox(height: 10),
                  AppNumericField(controller: qC, label: 'الكمية بوحدة الشراء *', quickAddValues: const [1, 5, 10, 25]),
                  const SizedBox(height: 10),
                  AppNumericField(controller: pC, label: 'سعر الوحدة *', unit: 'ج.م'),
                  const SizedBox(height: 10),
                  AppNumericField(controller: dC, label: 'خصم الصنف (0–100)', unit: '%'),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('إلغاء')),
              FilledButton(
                onPressed: () {
                  final q = double.tryParse(qC.text.trim()) ?? 0;
                  final pr = double.tryParse(pC.text.trim()) ?? 0;
                  final ds = double.tryParse(dC.text.trim().isEmpty ? '0' : dC.text.trim());
                  if (pid == null || q <= 0 || pr <= 0 || ds == null || ds < 0 || ds > 100) {
                    setD(() => lineError = 'تحقق من الكمية (> 0)، السعر (> 0)، ونسبة الخصم (0–100).');
                    return;
                  }
                  Navigator.pop(dCtx, true);
                },
                child: Text(isEditingLine ? 'تحديث' : 'إضافة'),
              ),
            ],
          ),
        ),
      );

      if (saved == true && pid != null) {
        final prod = _stockProducts.where((x) => x['id'] == pid).firstOrNull;
        setSheetState(() {
          final updated = {
            'product_id': pid,
            'product_name': prod?['name'] ?? line?['product_name'] ?? '',
            'quantity': qC.text.trim(),
            'price': pC.text.trim(),
            'discount': dC.text.trim().isEmpty ? '0' : dC.text.trim(),
          };
          if (isEditingLine) {
            lines[editIdx] = updated;
          } else {
            lines.add(updated);
          }
        });
      }
      qC.dispose();
      pC.dispose();
      dC.dispose();
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          double subtotal = 0;
          for (final l in lines) {
            final q = double.tryParse(l['quantity'].toString()) ?? 0;
            final p = double.tryParse(l['price'].toString()) ?? 0;
            final d = double.tryParse(l['discount'].toString()) ?? 0;
            subtotal += q * p * (1 - d / 100);
          }
          final discText = discountCtrl.text.trim();
          final billDiscount = discText.isEmpty ? 0 : int.tryParse(discText);
          final netTotal = subtotal - (billDiscount ?? 0);
          final isWholeTotal = billDiscount != null && (netTotal - netTotal.round()).abs() < 0.0001 && netTotal >= 0;

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.92),
              padding: const EdgeInsets.all(20),
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
                            isEdit ? 'تعديل فاتورة مشتريات #${existing['id']}' : 'إنشاء فاتورة مشتريات جديدة',
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 17.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(sheetCtx)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AppInlineError(message: formError),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            value: _suppliers.any((s) => s['id'] == selectedSupplierId) ? selectedSupplierId : null,
                            decoration: const InputDecoration(labelText: 'المورد *', isDense: true),
                            items: _suppliers
                                .map((s) => DropdownMenuItem<int>(value: s['id'] as int, child: Text('${s['name']}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Cairo'))))
                                .toList(),
                            onChanged: (val) => setSheetState(() => selectedSupplierId = val),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            isExpanded: true,
                            value: branches.any((b) => b['id'] == selectedBranch) ? selectedBranch : null,
                            decoration: const InputDecoration(labelText: 'الفرع المستلم *', isDense: true),
                            items: branches
                                .map((b) => DropdownMenuItem<int>(value: b['id'] as int, child: Text('${b['name']}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Cairo'))))
                                .toList(),
                            onChanged: (val) => setSheetState(() => selectedBranch = val),
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
                            decoration: const InputDecoration(labelText: 'تاريخ الفاتورة *', isDense: true),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: DateTime.tryParse(dateCtrl.text) ?? DateTime.now(),
                                firstDate: DateTime(2023),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                final s = picked.toIso8601String().split('T').first;
                                setSheetState(() {
                                  dateCtrl.text = s;
                                  if (endDateCtrl.text.compareTo(s) < 0) endDateCtrl.text = s;
                                });
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: endDateCtrl,
                            readOnly: true,
                            decoration: const InputDecoration(labelText: 'تاريخ الاستحقاق *', isDense: true),
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate: DateTime.tryParse(endDateCtrl.text) ?? DateTime.now(),
                                firstDate: DateTime(2023),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setSheetState(() => endDateCtrl.text = picked.toIso8601String().split('T').first);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('بنود الفاتورة (${lines.length})', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        FilledButton.tonalIcon(
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('إضافة صنف', style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5)),
                          onPressed: _stockProducts.isEmpty ? null : () => openLineDialog(ctx, setSheetState),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...lines.asMap().entries.map((entry) {
                      final l = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => openLineDialog(ctx, setSheetState, editIdx: entry.key),
                                child: Text(
                                  '${l['product_name']} • ${l['quantity']} × ${l['price']} ج.م (خصم ${l['discount']}%)',
                                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: AppColors.info, size: 18),
                              onPressed: () => openLineDialog(ctx, setSheetState, editIdx: entry.key),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 19),
                              onPressed: () => setSheetState(() => lines.removeAt(entry.key)),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 10),
                    AppNumericField(
                      controller: discountCtrl,
                      label: 'خصم الفاتورة الإجمالي (عدد صحيح)',
                      unit: 'ج.م',
                      allowDecimal: false,
                      onChanged: (_) => setSheetState(() {}),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isWholeTotal ? AppColors.primaryLight : AppColors.warningSoft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              billDiscount == null
                                  ? 'قيمة الخصم يجب أن تكون عدداً صحيحاً'
                                  : isWholeTotal
                                      ? 'صافي الفاتورة النهائي:'
                                      : 'يجب أن يكون صافي الفاتورة عدداً صحيحاً دون كسور!',
                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text('${netTotal.toStringAsFixed(2)} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: submitting || lines.isEmpty || !isWholeTotal || selectedSupplierId == null || selectedBranch == null
                          ? null
                          : () async {
                              setSheetState(() { submitting = true; formError = null; });
                              final payload = {
                                'supplier_id': selectedSupplierId,
                                'branch_id': selectedBranch,
                                'date': dateCtrl.text.trim(),
                                'enddate': endDateCtrl.text.trim(),
                                'discount': billDiscount,
                                'items': lines
                                    .map((l) => {
                                          'product_id': l['product_id'],
                                          'quantity': l['quantity'],
                                          'price': l['price'],
                                          'discount': l['discount'],
                                        })
                                    .toList(),
                              };
                              try {
                                if (isEdit) {
                                  await _api.post('/api/v1/bills/${existing['id']}/update/', idempotencyKey: _uuid.v4(), body: payload);
                                } else {
                                  await _api.post('/api/v1/bills/create/', idempotencyKey: _uuid.v4(), body: payload);
                                }
                                if (!mounted) return;
                                Navigator.pop(sheetCtx);
                                AppFeedback.showSuccess(
                                  context,
                                  isEdit ? 'تم تحديث فاتورة المشتريات بنجاح' : 'تم إنشاء فاتورة المشتريات وإضافة المخزون بنجاح',
                                );
                                await Future.wait([_loadBills(), _loadSuppliers()]);
                              } catch (e) {
                                if (ctx.mounted) setSheetState(() { submitting = false; formError = e.toString(); });
                              }
                            },
                      child: submitting
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(isEdit ? 'حفظ التعديلات' : 'حفظ الفاتورة'),
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
    endDateCtrl.dispose();
    discountCtrl.dispose();
  }

  Future<void> _showBillDetailSheet(int billId) async {
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
              final res = await _api.get('/api/v1/bills/$billId/');
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

          final b = detail;
          final isConf = b?['status'] == 'conf';
          final isPaid = b?['Pstatus'] == 'paid';
          final restNum = double.tryParse(b?['rest']?.toString() ?? '0') ?? 0;
          final paidNum = double.tryParse(b?['paid']?.toString() ?? '0') ?? 0;
          final items = _mapList(b?['items']);

          return Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.90),
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            child: loading && b == null
                ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
                : (detailError != null || b == null)
                    ? AppErrorView(message: detailError ?? 'تعذر تحميل تفاصيل الفاتورة', onRetry: reload)
                    : SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text('فاتورة #${b['id']} • ${b['supplier']?['name'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 17.5, fontWeight: FontWeight.bold)),
                                ),
                                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(sheetCtx)),
                              ],
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                AppStatusBadge(label: isConf ? 'مؤكدة' : 'معلقة', color: isConf ? AppColors.success : AppColors.warning),
                                AppStatusBadge(label: isPaid ? 'مسددة بالكامل' : 'غير مسددة', color: isPaid ? AppColors.primary : AppColors.error),
                                if (b['branch']?['name'] != null) AppStatusBadge(label: 'فرع: ${b['branch']['name']}', color: AppColors.info),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(16)),
                              child: Column(
                                children: [
                                  _kv('تاريخ الفاتورة / الاستحقاق', '${b['date']} ← ${b['enddate']}'),
                                  _kv('إجمالي الأصناف قبل الخصم', '${b['subtotal']} ج.م'),
                                  _kv('الخصم', '${b['discount']} ج.م'),
                                  _kv('صافي الفاتورة', '${b['total']} ج.م', highlight: true),
                                  _kv('المسدد', '${b['paid']} ج.م'),
                                  _kv('المتبقي للسداد', '${b['rest']} ج.م'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text('الأصناف المستلمة (${items.length}):', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                            const SizedBox(height: 6),
                            ...items.map((it) => ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text('${it['product_name']}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                                  subtitle: Text('${it['quantity']} × ${it['price']} ج.م (خصم ${it['discount']}%)', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                                  trailing: Text('${it['total']} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.primary)),
                                )),
                            const Divider(height: 20),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (!isConf)
                                  FilledButton.icon(
                                    icon: const Icon(Icons.verified_rounded, size: 18),
                                    label: const Text('تأكيد واعتماد الفاتورة'),
                                    onPressed: () async {
                                      try {
                                        await _api.post('/api/v1/bills/$billId/confirm/', idempotencyKey: _uuid.v4(), body: const {});
                                        if (ctx.mounted) AppFeedback.showSuccess(ctx, 'تم اعتماد الفاتورة');
                                        await reload();
                                        _loadBills();
                                        _loadSuppliers();
                                        _loadReceipts();
                                        _loadOperations();
                                      } catch (e) {
                                        if (ctx.mounted) AppFeedback.showError(ctx, e.toString());
                                      }
                                    },
                                  ),
                                if (isConf && paidNum == 0)
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.lock_open_rounded, size: 18),
                                    label: const Text('إلغاء التأكيد'),
                                    onPressed: () async {
                                      try {
                                        await _api.post('/api/v1/bills/$billId/unconfirm/', idempotencyKey: _uuid.v4(), body: const {});
                                        if (ctx.mounted) AppFeedback.showSuccess(ctx, 'تمت إعادة فتح الفاتورة');
                                        await reload();
                                        _loadBills();
                                        _loadSuppliers();
                                      } catch (e) {
                                        if (ctx.mounted) AppFeedback.showError(ctx, e.toString());
                                      }
                                    },
                                  ),
                                if (isConf && restNum > 0)
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                                    icon: const Icon(Icons.payments_rounded, size: 18),
                                    label: const Text('سداد الفاتورة'),
                                    onPressed: () {
                                      Navigator.pop(sheetCtx);
                                      _showPaymentDialog(billId: billId, title: 'سداد فاتورة #$billId', suggestedAmount: restNum.toInt().toString());
                                    },
                                  ),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.discount_outlined, size: 18),
                                  label: const Text('تعديل الخصم'),
                                  onPressed: () async {
                                    final discCtrl = TextEditingController(text: (double.tryParse(b['discount']?.toString() ?? '0') ?? 0).toInt().toString());
                                    String? dErr;
                                    final ok = await showDialog<bool>(
                                      context: ctx,
                                      builder: (dCtx) => StatefulBuilder(
                                        builder: (dc, setD) => AlertDialog(
                                          title: const Text('تعديل خصم الفاتورة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              AppInlineError(message: dErr),
                                              AppNumericField(
                                                controller: discCtrl,
                                                label: 'قيمة الخصم (عدد صحيح)',
                                                unit: 'ج.م',
                                                allowDecimal: false,
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('إلغاء')),
                                            FilledButton(
                                              onPressed: () {
                                                final v = int.tryParse(discCtrl.text.trim());
                                                if (v == null || v < 0) {
                                                  setD(() => dErr = 'أدخل قيمة خصم صحيحة (>= 0).');
                                                  return;
                                                }
                                                Navigator.pop(dCtx, true);
                                              },
                                              child: const Text('تطبيق الخصم'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                    if (ok == true) {
                                      final newDiscount = int.parse(discCtrl.text.trim());
                                      try {
                                        await _api.post('/api/v1/bills/$billId/discount/', idempotencyKey: _uuid.v4(), body: {
                                          'discount': newDiscount,
                                        });
                                        if (ctx.mounted) AppFeedback.showSuccess(ctx, 'تم تعديل الخصم');
                                        await reload();
                                        _loadBills();
                                        _loadSuppliers();
                                      } on ApiException catch (e) {
                                        if (e.statusCode == 404 && !isConf && items.isNotEmpty) {
                                          try {
                                            await _api.put('/api/v1/bills/$billId/update/', body: {
                                              if (b['supplier']?['id'] != null) 'supplier_id': b['supplier']['id'],
                                              if (b['branch']?['id'] != null) 'branch_id': b['branch']['id'],
                                              'date': b['date'],
                                              'enddate': b['enddate'],
                                              'discount': newDiscount,
                                              'items': items
                                                  .map((it) => {
                                                        'product_id': it['product_id'],
                                                        'quantity': it['quantity'],
                                                        'price': it['price'],
                                                        'discount': it['discount'] ?? 0,
                                                      })
                                                  .toList(),
                                            });
                                            if (ctx.mounted) AppFeedback.showSuccess(ctx, 'تم تعديل الخصم');
                                            await reload();
                                            _loadBills();
                                            _loadSuppliers();
                                          } catch (err2) {
                                            if (ctx.mounted) AppFeedback.showError(ctx, err2.toString());
                                          }
                                        } else if (e.statusCode == 404) {
                                          if (ctx.mounted) {
                                            AppFeedback.showError(
                                              ctx,
                                              isConf
                                                  ? 'لا يمكن تعديل خصم فاتورة مؤكدة على إصدار الخادم الحالي؛ قم بإلغاء التأكيد أولاً ثم عدّل الفاتورة.'
                                                  : 'تعذر تعديل الخصم على إصدار الخادم الحالي.',
                                            );
                                          }
                                        } else {
                                          if (ctx.mounted) AppFeedback.showError(ctx, e.toString());
                                        }
                                      } catch (e) {
                                        if (ctx.mounted) AppFeedback.showError(ctx, e.toString());
                                      }
                                    }
                                    discCtrl.dispose();
                                  },
                                ),
                                if (!isConf) ...[
                                  OutlinedButton.icon(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    label: const Text('تعديل الأصناف'),
                                    onPressed: () {
                                      Navigator.pop(sheetCtx);
                                      _showBillFormSheet(existing: b);
                                    },
                                  ),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                                    label: const Text('حذف الفاتورة'),
                                    onPressed: () async {
                                      final confirmed = await AppConfirmDialog.show(
                                        sheetCtx,
                                        title: 'حذف الفاتورة؟',
                                        message: 'سيتم حذف الفاتورة #$billId وعكس الكميات المضافة للمخزون.',
                                        confirmLabel: 'حذف',
                                        isDestructive: true,
                                      );
                                      if (!confirmed || !mounted) return;
                                      Navigator.pop(sheetCtx);
                                      try {
                                        await _api.delete('/api/v1/bills/$billId/delete/');
                                        if (!mounted) return;
                                        AppFeedback.showSuccess(context, 'تم حذف الفاتورة وعكس المخزون بنجاح');
                                        await Future.wait([_loadBills(), _loadSuppliers()]);
                                      } catch (e) {
                                        if (mounted) AppFeedback.showError(context, e.toString());
                                      }
                                    },
                                  ),
                                ],
                              ],
                            ),
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
            style: TextStyle(fontFamily: 'Cairo', fontSize: highlight ? 15 : 13.5, fontWeight: FontWeight.bold, color: highlight ? AppColors.primary : AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('المشتريات والموردون'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'الموردون والأرصدة'),
            Tab(text: 'فواتير المشتريات'),
            Tab(text: 'سندات الصرف'),
            Tab(text: 'سجل العمليات'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              if (_tabController.index == 0) _loadSuppliers();
              if (_tabController.index == 1) _loadBills();
              if (_tabController.index == 2) _loadReceipts();
              if (_tabController.index == 3) _loadOperations();
            },
          ),
        ],
      ),
      floatingActionButton: (_tabController.index == 0 || _tabController.index == 1)
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: Icon(_tabController.index == 1 ? Icons.post_add_rounded : Icons.person_add_rounded),
              label: Text(_tabController.index == 1 ? 'فاتورة مشتريات' : 'إضافة مورد', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              onPressed: () => _tabController.index == 1 ? _showBillFormSheet() : _showSupplierFormSheet(),
            )
          : null,
      body: TabBarView(
        controller: _tabController,
        children: [_buildSuppliersTab(), _buildBillsTab(), _buildReceiptsTab(), _buildOperationsTab()],
      ),
    );
  }

  Widget _buildSuppliersTab() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Expanded(child: _summaryCol('مديونية مؤكدة', '$_totalDebt ج.م')),
              Expanded(child: _summaryCol('دفعات مقدمة', '$_totalAdvance ج.م')),
              Expanded(child: _summaryCol('صافي الرصيد', '$_netBalance ج.م')),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(hintText: 'ابحث عن مورد بالاسم أو الهاتف...', prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary), isDense: true),
                  onChanged: (val) {
                    _supplierSearch = val;
                    _supplierDebounce?.cancel();
                    _supplierDebounce = Timer(const Duration(milliseconds: 300), _loadSuppliers);
                  },
                ),
              ),
              const SizedBox(width: 8),
              FilterChip(
                label: const Text('بأرصدة فقط', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                selected: _withBalanceOnly,
                selectedColor: AppColors.primaryLight,
                onSelected: (v) {
                  setState(() => _withBalanceOnly = v);
                  _loadSuppliers();
                },
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingSuppliers
              ? const AppLoadingView(message: 'جاري تحميل الموردين...')
              : _suppliersError != null
                  ? AppErrorView(message: _suppliersError!, onRetry: _loadSuppliers)
                  : _suppliers.isEmpty
                      ? AppEmptyView(title: 'لا يوجد موردون مطابقون', actionLabel: 'إضافة مورد جديد', onAction: () => _showSupplierFormSheet())
                      : RefreshIndicator(
                          onRefresh: _loadSuppliers,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                            itemCount: _suppliers.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, i) {
                              final sup = _suppliers[i];
                              return InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showSupplierDetailSheet(sup),
                                child: Container(
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(11),
                                        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                                        child: const Icon(Icons.business_rounded, color: AppColors.primary, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('${sup['name']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14.5, fontWeight: FontWeight.bold)),
                                            Text((sup['phone']?.toString().isNotEmpty == true) ? '${sup['phone']}' : 'بدون هاتف', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('${sup['balance'] ?? '0.00'} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.primary)),
                                          const Text('تفاصيل وسداد', style: TextStyle(fontFamily: 'Cairo', fontSize: 10.5, color: AppColors.textMuted)),
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
    );
  }

  Widget _summaryCol(String label, String val) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: Colors.white70)),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(val, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white)),
        ),
      ],
    );
  }

  Widget _buildBillsTab() {
    final q = _billSearch.trim().toLowerCase();
    final filtered = _bills.where((b) {
      if (q.isEmpty) return true;
      final id = '${b['id']}';
      final sup = (b['supplier']?['name'] ?? '').toString().toLowerCase();
      return id.contains(q) || sup.contains(q);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: TextField(
            decoration: const InputDecoration(hintText: 'ابحث برقم الفاتورة أو اسم المورد...', prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary), isDense: true),
            onChanged: (val) => setState(() => _billSearch = val),
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _chip('الكل', _billStatusFilter.isEmpty && _billPayFilter.isEmpty, () {
                setState(() { _billStatusFilter = ''; _billPayFilter = ''; });
                _loadBills();
              }),
              const SizedBox(width: 6),
              _chip('معلقة', _billStatusFilter == 'pend', () {
                setState(() {
                  _billStatusFilter = _billStatusFilter == 'pend' ? '' : 'pend';
                  if (_billStatusFilter == 'pend') _billPayFilter = '';
                });
                _loadBills();
              }),
              const SizedBox(width: 6),
              _chip('مؤكدة', _billStatusFilter == 'conf', () {
                setState(() => _billStatusFilter = _billStatusFilter == 'conf' ? '' : 'conf');
                _loadBills();
              }),
              const SizedBox(width: 6),
              _chip('غير مسددة', _billPayFilter == 'pend', () {
                setState(() => _billPayFilter = _billPayFilter == 'pend' ? '' : 'pend');
                _loadBills();
              }),
              const SizedBox(width: 6),
              _chip('مسددة', _billPayFilter == 'paid', () {
                setState(() {
                  _billPayFilter = _billPayFilter == 'paid' ? '' : 'paid';
                  if (_billPayFilter == 'paid' && _billStatusFilter == 'pend') _billStatusFilter = '';
                });
                _loadBills();
              }),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingBills
              ? const AppLoadingView(message: 'جاري تحميل فواتير المشتريات...')
              : _billsError != null
                  ? AppErrorView(message: _billsError!, onRetry: _loadBills)
                  : filtered.isEmpty
                      ? AppEmptyView(title: 'لا توجد فواتير مشتريات مطابقة', actionLabel: 'إنشاء فاتورة مشتريات', onAction: () => _showBillFormSheet())
                      : RefreshIndicator(
                          onRefresh: _loadBills,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, i) {
                              final bill = filtered[i];
                              final isConf = bill['status'] == 'conf';
                              final isPaid = bill['Pstatus'] == 'paid';
                              return InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showBillDetailSheet(bill['id'] as int),
                                child: Container(
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(color: isConf ? AppColors.primaryLight : AppColors.warningSoft, borderRadius: BorderRadius.circular(12)),
                                        child: Icon(isConf ? Icons.receipt_long_rounded : Icons.pending_actions_rounded, color: isConf ? AppColors.primary : AppColors.warning, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('فاتورة #${bill['id']} • ${bill['supplier']?['name'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
                                            Text('${bill['branch']?['name'] ?? ''} • ${bill['date'] ?? ''} • متبقي: ${bill['rest']} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.textSecondary)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('${bill['total']} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary)),
                                          const SizedBox(height: 2),
                                          AppStatusBadge(label: !isConf ? 'معلقة' : (isPaid ? 'مسددة' : 'ذمم'), color: !isConf ? AppColors.warning : (isPaid ? AppColors.success : AppColors.error)),
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
    );
  }

  Widget _buildReceiptsTab() {
    if (_isLoadingReceipts) return const AppLoadingView(message: 'جاري تحميل سندات الصرف...');
    if (_receiptsError != null) return AppErrorView(message: _receiptsError!, onRetry: _loadReceipts);
    if (_receipts.isEmpty) return const AppEmptyView(title: 'لا توجد سندات صرف موردين مسجلة');
    return RefreshIndicator(
      onRefresh: _loadReceipts,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _receipts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final r = _receipts[i];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.request_quote_rounded, color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('إيصال #${r['id']} • ${r['supplier']?['name'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('طريقة الدفع: ${r['payment_method']} • الفواتير المسددة: ${r['bills_count'] ?? 0}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.textSecondary)),
                      if ((r['notes']?.toString() ?? '').isNotEmpty) Text('${r['notes']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                Text('${r['amount']} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOperationsTab() {
    if (_isLoadingOperations) return const AppLoadingView(message: 'جاري تحميل سجل العمليات...');
    if (_operationsError != null) return AppErrorView(message: _operationsError!, onRetry: _loadOperations);
    if (_operations.isEmpty) return const AppEmptyView(title: 'لا توجد عمليات مالية مسجلة');
    return RefreshIndicator(
      onRefresh: _loadOperations,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _operations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final op = _operations[i];
          final bill = op['bill'] as Map<String, dynamic>?;
          final dt = (op['datetime']?.toString() ?? '').split('T').first;
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.infoSoft, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.history_edu_rounded, color: AppColors.info, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('فاتورة #${op['bill_id']} • ${bill?['supplier']?['name'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13.5)),
                      Text('${op['status'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                      Text(dt, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                Text('${op['amount']} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: selected ? Colors.white : AppColors.textPrimary)),
      selected: selected,
      selectedColor: AppColors.primary,
      onSelected: (_) => onTap(),
    );
  }
}
