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

class ManufacturingScreen extends StatefulWidget {
  final bool openCreate;

  const ManufacturingScreen({super.key, this.openCreate = false});

  @override
  State<ManufacturingScreen> createState() => _ManufacturingScreenState();
}

class _ManufacturingScreenState extends State<ManufacturingScreen> {
  final _uuid = const Uuid();
  bool _isLoading = true;
  String? _error;
  String? _productsError;

  List<Map<String, dynamic>> _orders = [];
  List<Map<String, dynamic>> _products = [];
  int? _selectedBranchFilter;

  ApiClient get _api => context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([_loadData(), _loadProductionProducts()]);
      if (widget.openCreate && mounted) _showManufacturingFormSheet();
    });
  }

  List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is List) return raw.whereType<Map<String, dynamic>>().toList();
    return [];
  }

  Future<void> _loadProductionProducts() async {
    _productsError = null;
    try {
      final loaded = <Map<String, dynamic>>[];
      int page = 1;
      bool hasNext = true;
      while (hasNext && page <= 10) {
        final res = await _api.get('/api/v1/catalog/products/', queryParams: {
          'is_production': 'true',
          'page': page,
          'page_size': '100',
        });
        if (res is! Map<String, dynamic>) break;
        loaded.addAll(_mapList(res['results']));
        hasNext = res['has_next'] == true;
        page++;
      }
      if (mounted) setState(() => _products = loaded);
    } catch (e) {
      if (mounted) setState(() => _productsError = e.toString());
    }
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await _api.get('/api/v1/manufacturing/', queryParams: {
        'page_size': '100',
        if (_selectedBranchFilter != null) 'branch_id': _selectedBranchFilter.toString(),
      });
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _orders = _mapList(res['results']);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _error = e.toString(); });
    }
  }

  Future<void> _deleteOrder(int id) async {
    final confirm = await AppConfirmDialog.show(
      context,
      title: 'حذف أمر التصنيع وعكس المخزون',
      message: 'سيتم عكس الكميات المنتجة وإعادة المواد الخام المستهلكة إلى المخزن. هل أنت متأكد؟',
      confirmLabel: 'حذف وعكس المخزون',
      isDestructive: true,
    );
    if (!confirm || !mounted) return;
    try {
      await _api.post('/api/v1/manufacturing/$id/delete/', idempotencyKey: _uuid.v4(), body: const {});
      if (!mounted) return;
      AppFeedback.showSuccess(context, 'تم حذف أمر التصنيع وعكس حركات المخزون بنجاح');
      await _loadData();
    } catch (e) {
      if (mounted) AppFeedback.showError(context, e.toString());
    }
  }

  Future<void> _showManufacturingFormSheet({Map<String, dynamic>? existing}) async {
    if (_products.isEmpty) await _loadProductionProducts();
    if (!mounted) return;

    final isEdit = existing != null;
    final auth = context.read<AuthProvider>();
    final branches = auth.allBranches.isNotEmpty ? auth.allBranches : auth.userBranches;
    int? selectedBranchId = isEdit
        ? (existing['branch_id'] as int?)
        : (_selectedBranchFilter ?? (branches.isNotEmpty ? branches.first.id : null));

    final items = <Map<String, dynamic>>[];
    if (isEdit) {
      for (final raw in _mapList(existing['items'])) {
        final prod = raw['product'] as Map<String, dynamic>?;
        items.add({
          'product_id': raw['product_id'],
          'name': prod?['name'] ?? '',
          'unit': prod?['unit'] ?? '',
          'quantity': (double.tryParse('${raw['quantity'] ?? 1}') ?? 1),
        });
      }
    }

    int? currentProductId = _products.isNotEmpty ? _products.first['id'] as int? : null;
    final qtyController = TextEditingController(text: '1');
    bool submitting = false;
    String? formError = _productsError;

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
                        isEdit ? 'تعديل أمر تصنيع #${existing['id']}' : 'أمر تصنيع وتشغيل جديد',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 17.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                const SizedBox(height: 10),
                AppInlineError(message: formError),
                if (branches.isNotEmpty) ...[
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'فرع / مصنع التشغيل *'),
                    value: branches.any((b) => b.id == selectedBranchId) ? selectedBranchId : branches.first.id,
                    items: branches.map((b) => DropdownMenuItem<int>(value: b.id, child: Text(b.name, style: const TextStyle(fontFamily: 'Cairo')))).toList(),
                    onChanged: isEdit ? null : (val) => setSheetState(() => selectedBranchId = val),
                  ),
                  const SizedBox(height: 14),
                ],
                Text('الأصناف المنتجة (${items.length}):', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 6),
                ...items.asMap().entries.map((entry) {
                  final item = entry.value;
                  final qtyVal = (item['quantity'] as num).toDouble();
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_circle_outline, color: AppColors.success),
                    title: Text('${item['name']}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    subtitle: Text('الكمية: ${AppNumericKeypadSheet.formatNumber(qtyVal)} ${item['unit'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo')),
                    onTap: () async {
                      final edited = await FastQuantityDialSheet.show(
                        ctx,
                        title: '${item['name']}',
                        unit: '${item['unit'] ?? 'وحدة'}',
                        initialValue: qtyVal,
                      );
                      if (edited != null && edited > 0) {
                        setSheetState(() => items[entry.key]['quantity'] = edited);
                      }
                    },
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.dialpad_rounded, size: 19, color: AppColors.primary),
                          onPressed: () async {
                            final edited = await FastQuantityDialSheet.show(
                              ctx,
                              title: '${item['name']}',
                              unit: '${item['unit'] ?? 'وحدة'}',
                              initialValue: qtyVal,
                            );
                            if (edited != null && edited > 0) {
                              setSheetState(() => items[entry.key]['quantity'] = edited);
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: AppColors.error),
                          onPressed: () => setSheetState(() => items.removeAt(entry.key)),
                        ),
                      ],
                    ),
                  );
                }),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      DropdownButtonFormField<int>(
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'اختر منتج التصنيع (BOM)', isDense: true),
                        value: _products.any((p) => p['id'] == currentProductId) ? currentProductId : null,
                        items: _products
                            .map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text('${p['name']} (${p['unit'] ?? ''})', style: const TextStyle(fontFamily: 'Cairo'))))
                            .toList(),
                        onChanged: (val) => setSheetState(() => currentProductId = val),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: AppNumericField(
                              controller: qtyController,
                              label: 'الكمية المنتجة',
                              isDense: true,
                              quickAddValues: const [1, 5, 10, 25],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('إضافة'),
                            onPressed: () {
                              final q = double.tryParse(qtyController.text.trim()) ?? 0;
                              if (currentProductId == null) {
                                setSheetState(() => formError = 'اختر منتج التصنيع أولاً.');
                                return;
                              }
                              if (q <= 0) {
                                setSheetState(() => formError = 'أدخل كمية منتجة أكبر من صفر.');
                                return;
                              }
                              final p = _products.firstWhere((x) => x['id'] == currentProductId);
                              setSheetState(() {
                                formError = null;
                                final existingIdx = items.indexWhere((it) => it['product_id'] == currentProductId);
                                if (existingIdx >= 0) {
                                  items[existingIdx]['quantity'] = (items[existingIdx]['quantity'] as double) + q;
                                } else {
                                  items.add({
                                    'product_id': currentProductId,
                                    'name': p['name'],
                                    'unit': p['unit'] ?? '',
                                    'quantity': q,
                                  });
                                }
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: submitting || items.isEmpty || selectedBranchId == null
                      ? null
                      : () async {
                          setSheetState(() { submitting = true; formError = null; });
                          final payload = {
                            'branch_id': selectedBranchId,
                            'items': items
                                .map((i) => {
                                      'product_id': i['product_id'],
                                      'quantity': AppNumericKeypadSheet.formatNumber((i['quantity'] as num).toDouble()),
                                    })
                                .toList(),
                          };
                          try {
                            if (isEdit) {
                              await _api.post('/api/v1/manufacturing/${existing['id']}/update/', idempotencyKey: _uuid.v4(), body: payload);
                            } else {
                              await _api.post('/api/v1/manufacturing/create/', idempotencyKey: _uuid.v4(), body: payload);
                            }
                            if (mounted) {
                              Navigator.pop(sheetContext);
                              AppFeedback.showSuccess(
                                context,
                                isEdit ? 'تم تحديث أمر التصنيع وتسوية المخزون بنجاح' : 'تم اعتماد أمر التشغيل وخصم الخامات بنجاح',
                              );
                              await _loadData();
                            }
                          } catch (e) {
                            if (ctx.mounted) setSheetState(() { submitting = false; formError = e.toString(); });
                          }
                        },
                  child: submitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(isEdit ? 'حفظ التعديلات وتسوية الخام' : 'اعتماد أمر التشغيل والخصم من الخام'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    qtyController.dispose();
  }

  void _showDetailSheet(Map<String, dynamic> order) {
    final items = _mapList(order['items']);
    final branchName = (order['branch'] as Map<String, dynamic>?)?['name']?.toString() ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (sheetCtx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetCtx).size.height * 0.85),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('أمر تصنيع #${order['id']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold))),
                IconButton(onPressed: () => Navigator.pop(sheetCtx), icon: const Icon(Icons.close)),
              ],
            ),
            Text('الفرع: $branchName • التاريخ: ${order['date'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
            const Divider(height: 22),
            const Text('المنتجات المصنعة:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (c, i) {
                  final item = items[i];
                  final prod = item['product'] as Map<String, dynamic>?;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${prod?['name'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    trailing: Text('${item['quantity']} ${prod?['unit'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.primary)),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('حذف وعكس المخزون'),
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      _deleteOrder(order['id'] as int);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('تعديل الكميات'),
                    onPressed: () {
                      Navigator.pop(sheetCtx);
                      _showManufacturingFormSheet(existing: order);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final branches = auth.allBranches.isNotEmpty ? auth.allBranches : auth.userBranches;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('التصنيع وأوامر التشغيل'),
        actions: [IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث', onPressed: _loadData)],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.precision_manufacturing_rounded),
        label: const Text('أمر تشغيل جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        onPressed: () => _showManufacturingFormSheet(),
      ),
      body: Column(
        children: [
          if (branches.isNotEmpty)
            Container(
              color: Colors.white,
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                children: [
                  ChoiceChip(
                    label: Text('كل الفروع', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: _selectedBranchFilter == null ? Colors.white : AppColors.textPrimary)),
                    selected: _selectedBranchFilter == null,
                    selectedColor: AppColors.primary,
                    onSelected: (_) {
                      setState(() => _selectedBranchFilter = null);
                      _loadData();
                    },
                  ),
                  ...branches.map((b) {
                    final sel = _selectedBranchFilter == b.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(b.name, style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: sel ? Colors.white : AppColors.textPrimary)),
                        selected: sel,
                        selectedColor: AppColors.primary,
                        onSelected: (_) {
                          setState(() => _selectedBranchFilter = b.id);
                          _loadData();
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const AppLoadingView(message: 'جاري تحميل أوامر التصنيع...')
                : _error != null
                    ? AppErrorView(message: _error!, onRetry: _loadData)
                    : _orders.isEmpty
                        ? AppEmptyView(
                            title: 'لا توجد أوامر تشغيل مسجلة',
                            icon: Icons.precision_manufacturing_outlined,
                            actionLabel: 'إنشاء أمر تشغيل',
                            onAction: () => _showManufacturingFormSheet(),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadData,
                            color: AppColors.primary,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                              itemCount: _orders.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final order = _orders[i];
                                final itemsCount = (order['items'] as List<dynamic>?)?.length ?? 0;
                                final branchName = (order['branch'] as Map<String, dynamic>?)?['name']?.toString() ?? '';
                                return InkWell(
                                  onTap: () => _showDetailSheet(order),
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                                          child: const Icon(Icons.factory_outlined, color: AppColors.primary, size: 24),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('أمر تشغيل #${order['id']} • $branchName', style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold)),
                                              Text('التاريخ: ${order['date'] ?? ''} • $itemsCount أصناف مصنعة', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                                            ],
                                          ),
                                        ),
                                        const Icon(Icons.chevron_left_rounded, size: 20, color: AppColors.textMuted),
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
