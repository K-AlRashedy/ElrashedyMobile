import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/async_views.dart';
import '../../widgets/fast_quantity_dial_sheet.dart';
import '../../widgets/numeric_keypad_sheet.dart';

class SalesScreen extends StatefulWidget {
  final bool openCreate;

  const SalesScreen({super.key, this.openCreate = false});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _uuid = const Uuid();
  ApiCancelToken? _salesCancelToken;

  List<Map<String, dynamic>> _salesOrders = [];
  List<Map<String, dynamic>> _soldProducts = [];
  bool _isLoading = true;
  String? _error;
  String? _catalogError;
  String _searchQuery = '';
  int? _selectedBranchId;

  ApiClient get _api => context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        _loadSales();
        setState(() {});
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([_loadSales(), _loadSoldCatalog()]);
      if (widget.openCreate && mounted) {
        _showSaleFormSheet();
      }
    });
  }

  @override
  void dispose() {
    _salesCancelToken?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSoldCatalog() async {
    _catalogError = null;
    try {
      final loaded = <Map<String, dynamic>>[];
      int page = 1;
      bool hasNext = true;
      while (hasNext && page <= 10) {
        final res = await _api.get('/api/v1/catalog/products/', queryParams: {
          'is_sold': 'true',
          'page': page,
          'page_size': '100',
        });
        if (res is! Map<String, dynamic>) break;
        final raw = res['results'] as List<dynamic>? ?? [];
        loaded.addAll(raw.whereType<Map<String, dynamic>>());
        hasNext = res['has_next'] == true;
        page++;
      }
      if (mounted) setState(() => _soldProducts = loaded);
    } catch (e) {
      if (mounted) setState(() => _catalogError = e.toString());
    }
  }

  Future<void> _loadSales() async {
    _salesCancelToken?.cancel();
    final token = ApiCancelToken();
    _salesCancelToken = token;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final params = <String, dynamic>{'page_size': '100'};
      if (_tabController.index == 1) {
        params['status'] = 'draft';
      } else if (_tabController.index == 2) {
        params['status'] = 'confirmed';
      }
      if (_selectedBranchId != null) {
        params['branch_id'] = _selectedBranchId.toString();
      }
      final res = await _api.get('/api/v1/sales/', queryParams: params, cancelToken: token);
      if (res is Map<String, dynamic> && mounted) {
        final raw = res['results'] as List<dynamic>? ?? res['sales'] as List<dynamic>? ?? [];
        setState(() {
          _salesOrders = raw.whereType<Map<String, dynamic>>().toList();
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

  Future<void> _confirmSale(int orderId) async {
    final confirm = await AppConfirmDialog.show(
      context,
      title: 'تأكيد أمر البيع',
      message: 'سيتم خصم كميات المنتجات أو مكوناتها من المخزون واعتماد الأمر نهائياً. هل تريد المتابعة؟',
      confirmLabel: 'تأكيد واعتماد',
    );
    if (!confirm) return;

    try {
      await _api.post('/api/v1/sales/$orderId/confirm/', idempotencyKey: _uuid.v4(), body: const {});
      if (mounted) {
        AppFeedback.showSuccess(context, 'تم تأكيد واعتماد أمر البيع بنجاح');
        await _loadSales();
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, e.toString());
    }
  }

  Future<void> _deleteSale(int orderId) async {
    final confirm = await AppConfirmDialog.show(
      context,
      title: 'حذف أمر البيع المسودة',
      message: 'هل أنت متأكد من حذف هذا الأمر؟ لا يمكن التراجع عن هذه الخطوة.',
      confirmLabel: 'حذف',
      isDestructive: true,
    );
    if (!confirm) return;

    try {
      await _api.post('/api/v1/sales/$orderId/delete/', idempotencyKey: _uuid.v4(), body: const {});
      if (mounted) {
        AppFeedback.showSuccess(context, 'تم حذف أمر البيع المسودة بنجاح');
        await _loadSales();
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, e.toString());
    }
  }

  void _showOrderDetailSheet(Map<String, dynamic> order) {
    final items = (order['items'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();
    final isSaved = order['is_saved'] == true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.78,
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('أمر بيع #${order['id']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold))),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            Row(
              children: [
                Expanded(child: Text('الفرع: ${order['branch_name'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary))),
                AppStatusBadge(label: isSaved ? 'مؤكد ومعتمد' : 'مسودة معلقة', color: isSaved ? AppColors.success : AppColors.warning),
              ],
            ),
            if (order['date'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'التاريخ: ${order['date']} • نقدية إضافية: ${order['cash'] ?? '0.00'} ج.م',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textMuted),
                ),
              ),
            const Divider(height: 22),
            const Text('بنود الأمر:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('لا توجد بنود في هذا الأمر', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)))
                  : ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (c, idx) {
                        final line = items[idx];
                        final isWholesale = line['is_wholesale'] == true;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 6,
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: [
                                        Text(line['product']?['name']?.toString() ?? line['product_name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13.5)),
                                        if (isWholesale) const AppStatusBadge(label: 'جملة', color: AppColors.info),
                                      ],
                                    ),
                                    Text('${line['quantity']} × ${line['price']} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                              Text('${line['total']} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.primary)),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('إجمالي قيمة الأمر:', style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold)),
                Text('${order['total']} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
            if (!isSaved) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  IconButton(
                    style: IconButton.styleFrom(backgroundColor: AppColors.dangerSoft),
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                    tooltip: 'حذف المسودة',
                    onPressed: () {
                      Navigator.pop(ctx);
                      _deleteSale(order['id'] as int);
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('تعديل'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showSaleFormSheet(existing: order);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                      label: const Text('اعتماد'),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _confirmSale(order['id'] as int);
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
  }

  Future<void> _showSaleFormSheet({Map<String, dynamic>? existing}) async {
    if (_soldProducts.isEmpty) await _loadSoldCatalog();
    if (!mounted) return;

    final isEdit = existing != null;
    final auth = context.read<AuthProvider>();
    final branches = auth.allBranches.isNotEmpty ? auth.allBranches : auth.userBranches;
    int? selectedBranch = isEdit
        ? (existing['branch_id'] as int?)
        : (_selectedBranchId ?? (branches.isNotEmpty ? branches.first.id : null));

    final cart = <int, double>{};
    final wholesaleMap = <int, bool>{};
    if (isEdit) {
      final rawItems = (existing['items'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>();
      for (final item in rawItems) {
        final pid = item['product_id'] as int?;
        final qty = (item['quantity'] as num?)?.toDouble() ?? 0;
        if (pid != null && qty > 0) {
          cart[pid] = qty;
          wholesaleMap[pid] = item['is_wholesale'] == true;
        }
      }
    }

    final cashController = TextEditingController(text: isEdit ? (existing['cash'] ?? '0').toString() : '0');
    String prodQuery = '';
    bool isSubmitting = false;
    String? formError = _catalogError;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final visibleProducts = _soldProducts.where((p) {
            if (prodQuery.isEmpty) return true;
            return (p['name']?.toString() ?? '').toLowerCase().contains(prodQuery.toLowerCase());
          }).toList();

          double calcTotal() {
            double total = double.tryParse(cashController.text.trim()) ?? 0.0;
            for (final entry in cart.entries) {
              if (entry.value <= 0) continue;
              final p = _soldProducts.where((x) => x['id'] == entry.key).firstOrNull;
              if (p == null) continue;
              final useW = wholesaleMap[entry.key] == true;
              final price = double.tryParse((useW ? (p['wholesale_price'] ?? p['selling_price'] ?? 0) : (p['selling_price'] ?? p['price'] ?? 0)).toString()) ?? 0;
              total += price * entry.value;
            }
            return total;
          }

          Future<void> submitOrder(String action) async {
            if (selectedBranch == null) {
              setSheetState(() => formError = 'يرجى اختيار الفرع.');
              return;
            }
            final cashText = cashController.text.trim();
            final cashVal = cashText.isEmpty ? 0.0 : double.tryParse(cashText);
            if (cashVal == null || cashVal < 0) {
              setSheetState(() => formError = 'أدخل قيمة نقدية إضافية صالحة.');
              return;
            }
            setSheetState(() { isSubmitting = true; formError = null; });
            final items = cart.entries
                .where((e) => e.value > 0)
                .map((e) => {
                      'product_id': e.key,
                      'quantity': e.value,
                      'is_wholesale': wholesaleMap[e.key] == true,
                    })
                .toList();
            final payload = {
              'branch_id': selectedBranch,
              'items': items,
              'cash': cashVal,
              if (!isEdit) 'action': action,
            };
            bool updatedFirst = false;
            try {
              if (isEdit) {
                await _api.post('/api/v1/sales/${existing['id']}/update/', idempotencyKey: _uuid.v4(), body: payload);
                updatedFirst = true;
                if (action == 'confirm') {
                  await _api.post('/api/v1/sales/${existing['id']}/confirm/', idempotencyKey: _uuid.v4(), body: const {});
                }
              } else {
                await _api.post('/api/v1/sales/create/', idempotencyKey: _uuid.v4(), body: payload);
              }
              if (!mounted) return;
              Navigator.pop(sheetCtx);
              AppFeedback.showSuccess(
                context,
                action == 'confirm' ? 'تم حفظ واعتماد أمر البيع بنجاح' : 'تم حفظ أمر البيع كمسودة بنجاح',
              );
              await _loadSales();
            } catch (e) {
              if (updatedFirst) _loadSales();
              if (ctx.mounted) {
                setSheetState(() { isSubmitting = false; formError = e.toString(); });
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: Container(
              height: MediaQuery.of(ctx).size.height * 0.90,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isEdit ? 'تعديل أمر بيع #${existing['id']}' : 'إنشاء أمر بيع جديد',
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 17.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(sheetCtx)),
                    ],
                  ),
                  AppInlineError(message: formError),
                  if (branches.isNotEmpty)
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: branches.any((b) => b.id == selectedBranch) ? selectedBranch : branches.first.id,
                      decoration: const InputDecoration(labelText: 'فرع البيع *', isDense: true),
                      items: branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, style: const TextStyle(fontFamily: 'Cairo')))).toList(),
                      onChanged: (val) => setSheetState(() => selectedBranch = val),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(hintText: 'ابحث عن صنف بيع...', prefixIcon: Icon(Icons.search_rounded), isDense: true),
                    onChanged: (val) => setSheetState(() => prodQuery = val),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: visibleProducts.isEmpty
                        ? const AppEmptyView(message: 'لا توجد أصناف بيع مطابقة.')
                        : ListView.separated(
                            itemCount: visibleProducts.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (c, idx) {
                              final p = visibleProducts[idx];
                              final pid = p['id'] as int;
                              final qty = cart[pid] ?? 0;
                              final canWholesale = p['is_wholesale'] == true;
                              final useWholesale = wholesaleMap[pid] == true;
                              final displayPrice = useWholesale
                                  ? (p['wholesale_price'] ?? p['selling_price'] ?? 0)
                                  : (p['selling_price'] ?? p['price'] ?? 0);

                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: qty > 0 ? AppColors.primarySoft : AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: qty > 0 ? AppColors.primary.withValues(alpha: 0.4) : AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('${p['name']}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13.5)),
                                          const SizedBox(height: 2),
                                          Wrap(
                                            spacing: 6,
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            children: [
                                              Text('$displayPrice ج.م / ${p['unit'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.textSecondary)),
                                              if (canWholesale)
                                                InkWell(
                                                  onTap: () => setSheetState(() => wholesaleMap[pid] = !useWholesale),
                                                  child: AppStatusBadge(
                                                    label: useWholesale ? 'سعر جملة' : 'قطاعي',
                                                    color: useWholesale ? AppColors.info : AppColors.primary,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline_rounded, size: 22),
                                      onPressed: qty > 0
                                          ? () => setSheetState(() {
                                                if (qty <= 1) {
                                                  cart.remove(pid);
                                                } else {
                                                  cart[pid] = qty - 1;
                                                }
                                              })
                                          : null,
                                    ),
                                    InkWell(
                                      onTap: () async {
                                        final val = await FastQuantityDialSheet.show(
                                          ctx,
                                          title: '${p['name']}',
                                          unit: '${p['unit'] ?? 'وحدة'}',
                                          initialValue: qty > 0 ? qty : 1,
                                          allowZero: true,
                                        );
                                        if (val != null) {
                                          setSheetState(() {
                                            if (val <= 0) {
                                              cart.remove(pid);
                                            } else {
                                              cart[pid] = val;
                                            }
                                          });
                                        }
                                      },
                                      child: Container(
                                        constraints: const BoxConstraints(minWidth: 42),
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        alignment: Alignment.center,
                                        child: Text(
                                          AppNumericKeypadSheet.formatNumber(qty),
                                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w800),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline_rounded, size: 22, color: AppColors.primary),
                                      onPressed: () => setSheetState(() => cart[pid] = qty + 1),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 10),
                  AppNumericField(
                    controller: cashController,
                    label: 'نقدية إضافية محصلة',
                    unit: 'ج.م',
                    quickAddValues: const [50, 100, 500],
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('إجمالي الأمر التقديري:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('${calcTotal().toStringAsFixed(2)} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primaryDark)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: isSubmitting || cart.values.every((v) => v <= 0) ? null : () => submitOrder('draft'),
                          child: const Text('حفظ كمسودة'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: isSubmitting || cart.values.every((v) => v <= 0) ? null : () => submitOrder('confirm'),
                          child: isSubmitting
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('اعتماد مباشر'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    cashController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final branches = auth.allBranches.isNotEmpty ? auth.allBranches : auth.userBranches;
    final filtered = _salesOrders.where((order) {
      final id = (order['id'] ?? '').toString();
      final branch = (order['branch_name'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      return q.isEmpty || id.contains(q) || branch.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('سجل وأوامر المبيعات'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'الكل'),
            Tab(text: 'المسودات المعلقة'),
            Tab(text: 'المعتمدة'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث', onPressed: _loadSales),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('أمر بيع جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        onPressed: () => _showSaleFormSheet(),
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'ابحث برقم الأمر أو اسم الفرع...',
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                    isDense: true,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                if (branches.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    value: branches.any((b) => b.id == _selectedBranchId) ? _selectedBranchId : null,
                    decoration: const InputDecoration(labelText: 'تصفية حسب الفرع', isDense: true),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('كل الفروع', style: TextStyle(fontFamily: 'Cairo'))),
                      ...branches.map((b) => DropdownMenuItem<int?>(value: b.id, child: Text(b.name, style: const TextStyle(fontFamily: 'Cairo')))),
                    ],
                    onChanged: (val) {
                      setState(() => _selectedBranchId = val);
                      _loadSales();
                    },
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const AppLoadingView(message: 'جاري تحميل أوامر البيع...')
                : _error != null
                    ? AppErrorView(message: _error!, onRetry: _loadSales)
                    : filtered.isEmpty
                        ? AppEmptyView(
                            title: 'لا توجد أوامر بيع مطابقة',
                            actionLabel: 'إنشاء أمر بيع',
                            onAction: () => _showSaleFormSheet(),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadSales,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final order = filtered[i];
                                final isSaved = order['is_saved'] == true;
                                final itemsCount = (order['items'] as List<dynamic>? ?? []).length;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () => _showOrderDetailSheet(order),
                                  child: Container(
                                    padding: const EdgeInsets.all(15),
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
                                            color: isSaved ? AppColors.primaryLight : AppColors.warningSoft,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            isSaved ? Icons.check_circle_outline_rounded : Icons.pending_actions_rounded,
                                            color: isSaved ? AppColors.primary : AppColors.warning,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'أمر بيع #${order['id']} • ${order['branch_name'] ?? ''}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${order['date'] ?? ''} • $itemsCount بند',
                                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              '${order['total']} ج.م',
                                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.primary),
                                            ),
                                            const SizedBox(height: 3),
                                            AppStatusBadge(
                                              label: isSaved ? 'معتمد' : 'مسودة',
                                              color: isSaved ? AppColors.success : AppColors.warning,
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
