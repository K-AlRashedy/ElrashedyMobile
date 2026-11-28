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

class StockScreen extends StatefulWidget {
  final int initialTab;

  const StockScreen({super.key, this.initialTab = 0});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _uuid = const Uuid();
  Timer? _searchDebounce;
  ApiCancelToken? _stockCancelToken;

  List<Map<String, dynamic>> _stockItems = [];
  bool _isLoadingStock = true;
  String? _stockError;
  String _searchQuery = '';
  int? _selectedBranchId;

  List<Map<String, dynamic>> _dailyReports = [];
  bool _isLoadingReport = false;
  String? _reportError;
  late DateTime _reportDate;

  List<Map<String, dynamic>> _catalogProducts = [];

  ApiClient get _api => context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _reportDate = now.hour < 9 ? now.subtract(const Duration(days: 1)) : now;

    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        if (_tabController.index == 1) _loadDailyReport();
        if (_tabController.index == 0) _loadStock();
        setState(() {});
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final branches = auth.allBranches.isNotEmpty ? auth.allBranches : auth.userBranches;
      if (branches.isNotEmpty) {
        _selectedBranchId = branches.first.id;
      }
      await Future.wait([
        _loadStock(),
        _loadCatalogProducts(),
        if (_tabController.index == 1) _loadDailyReport(),
      ]);
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _stockCancelToken?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is List) return raw.whereType<Map<String, dynamic>>().toList();
    return [];
  }

  Future<void> _loadCatalogProducts() async {
    try {
      final loaded = <Map<String, dynamic>>[];
      int page = 1;
      bool hasNext = true;
      while (hasNext && page <= 10) {
        final res = await _api.get('/api/v1/catalog/products/', queryParams: {'page': page, 'page_size': '100'});
        if (res is! Map<String, dynamic>) break;
        loaded.addAll(_mapList(res['results']));
        hasNext = res['has_next'] == true;
        page++;
      }
      if (mounted) setState(() => _catalogProducts = loaded);
    } catch (_) {}
  }

  Future<void> _loadStock() async {
    _stockCancelToken?.cancel();
    final token = ApiCancelToken();
    _stockCancelToken = token;

    setState(() {
      _isLoadingStock = true;
      _stockError = null;
    });
    try {
      final params = <String, dynamic>{
        'page_size': '100',
        if (_selectedBranchId != null) 'branch_id': _selectedBranchId.toString(),
        if (_searchQuery.trim().isNotEmpty) 'q': _searchQuery.trim(),
      };
      final res = await _api.get('/api/v1/stock/', queryParams: params, cancelToken: token);
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _stockItems = _mapList(res['results'] ?? res['stock']);
          _isLoadingStock = false;
        });
      }
    } on ApiException catch (e) {
      if (e.message == 'تم إلغاء الطلب.') return;
      if (mounted) setState(() { _isLoadingStock = false; _stockError = e.message; });
    } catch (e) {
      if (mounted) setState(() { _isLoadingStock = false; _stockError = e.toString(); });
    }
  }

  Future<void> _loadDailyReport() async {
    setState(() {
      _isLoadingReport = true;
      _reportError = null;
    });
    try {
      final dateStr = _reportDate.toIso8601String().split('T')[0];
      final params = <String, dynamic>{
        'date': dateStr,
        'page_size': '100',
        if (_selectedBranchId != null) 'branch_id': _selectedBranchId.toString(),
      };
      final res = await _api.get('/api/v1/stock/daily-report/', queryParams: params);
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _dailyReports = _mapList(res['results']);
          _isLoadingReport = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _isLoadingReport = false; _reportError = e.toString(); });
    }
  }

  Future<void> _showAdjustStockDialog(Map<String, dynamic> item) async {
    final unit = (item['product'] as Map<String, dynamic>?)?['unit']?.toString() ?? '';
    final deltaController = TextEditingController();
    final reasonController = TextEditingController(text: 'تسوية جرد ميداني');
    bool isSubmitting = false;
    String? dialogError;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text(
            'تسوية مخزون ${item['product_name']}',
            style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppInlineError(message: dialogError),
                Text(
                  'الرصيد الحالي: ${item['quantity']} $unit',
                  style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                AppNumericField(
                  controller: deltaController,
                  label: 'الفرق (+ زيادة أو - نقص) *',
                  unit: unit,
                  allowNegative: true,
                  quickAddValues: const [1, 5, 10, -1, -5],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'سبب التسوية *'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final delta = double.tryParse(deltaController.text.trim());
                      final reason = reasonController.text.trim();
                      if (delta == null || delta == 0 || reason.isEmpty) {
                        setDialogState(() => dialogError = 'أدخل قيمة تسوية غير صفرية مع سبب التسوية.');
                        return;
                      }
                      setDialogState(() { isSubmitting = true; dialogError = null; });
                      try {
                        await _api.post(
                          '/api/v1/stock/${item['id']}/adjust/',
                          idempotencyKey: _uuid.v4(),
                          body: {'delta': delta, 'reason': reason},
                        );
                        if (mounted) {
                          Navigator.pop(dialogCtx);
                          AppFeedback.showSuccess(context, 'تم تعديل رصيد المخزون بنجاح');
                          await Future.wait([_loadStock(), _loadDailyReport()]);
                        }
                      } catch (e) {
                        if (dialogCtx.mounted) {
                          setDialogState(() { isSubmitting = false; dialogError = e.toString(); });
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('تأكيد التسوية'),
            ),
          ],
        ),
      ),
    );
    deltaController.dispose();
    reasonController.dispose();
  }

  Future<void> _showStocktakeSheet() async {
    final auth = context.read<AuthProvider>();
    final branches = auth.allBranches.isNotEmpty ? auth.allBranches : auth.userBranches;
    int? branchId = _selectedBranchId ?? (branches.isNotEmpty ? branches.first.id : null);

    final entryRows = <Map<String, dynamic>>[];
    bool loadingBranchStock = true;
    bool isSubmitting = false;
    String? formError;
    bool initialLoaded = false;

    void clearEntryControllers() {
      for (final r in entryRows) {
        (r['controller'] as TextEditingController).dispose();
      }
      entryRows.clear();
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          Future<void> loadBranchRows(int? targetBranchId) async {
            if (targetBranchId == null) {
              setSheetState(() => loadingBranchStock = false);
              return;
            }
            setSheetState(() { loadingBranchStock = true; formError = null; });
            try {
              final res = await _api.get('/api/v1/stock/', queryParams: {
                'branch_id': targetBranchId.toString(),
                'page_size': '100',
              });
              final list = res is Map<String, dynamic> ? _mapList(res['results'] ?? res['stock']) : <Map<String, dynamic>>[];
              if (!ctx.mounted) return;
              clearEntryControllers();
              for (final item in list) {
                final rawQty = double.tryParse('${item['quantity'] ?? 0}') ?? 0.0;
                final safeQty = rawQty < 0 ? 0.0 : double.parse(rawQty.toStringAsFixed(3));
                entryRows.add({
                  'product_id': item['product_id'],
                  'product_name': item['product_name'],
                  'unit': (item['product'] as Map<String, dynamic>?)?['unit'] ?? '',
                  'controller': TextEditingController(text: AppNumericKeypadSheet.formatNumber(safeQty)),
                });
              }
              setSheetState(() => loadingBranchStock = false);
            } catch (e) {
              if (ctx.mounted) {
                setSheetState(() { loadingBranchStock = false; formError = e.toString(); });
              }
            }
          }

          if (!initialLoaded) {
            initialLoaded = true;
            Future.microtask(() => loadBranchRows(branchId));
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
                      const Expanded(child: Text('إدخال الجرد الفعلي للمخزن', style: TextStyle(fontFamily: 'Cairo', fontSize: 17.5, fontWeight: FontWeight.bold))),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(sheetCtx)),
                    ],
                  ),
                  AppInlineError(message: formError),
                  if (branches.isNotEmpty) ...[
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      value: branches.any((b) => b.id == branchId) ? branchId : branches.first.id,
                      decoration: const InputDecoration(labelText: 'الفرع / المخزن *', isDense: true),
                      items: branches.map((b) => DropdownMenuItem<int>(value: b.id, child: Text(b.name, style: const TextStyle(fontFamily: 'Cairo')))).toList(),
                      onChanged: (val) {
                        if (val != null && val != branchId) {
                          setSheetState(() => branchId = val);
                          loadBranchRows(val);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('الأصناف (${entryRows.length})', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13.5)),
                      TextButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('إضافة صنف للجرد', style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5)),
                        onPressed: _catalogProducts.isEmpty || loadingBranchStock
                            ? null
                            : () async {
                                final existingIds = entryRows.map((r) => r['product_id']).toSet();
                                final available = _catalogProducts.where((p) => !existingIds.contains(p['id'])).toList();
                                if (available.isEmpty) {
                                  AppFeedback.showError(ctx, 'جميع أصناف الكتالوج مضافة بالفعل.');
                                  return;
                                }
                                int? chosenId = available.first['id'] as int?;
                                final qCtrl = TextEditingController(text: '0');
                                final ok = await showDialog<bool>(
                                  context: ctx,
                                  builder: (dCtx) => StatefulBuilder(
                                    builder: (dc, setD) => AlertDialog(
                                      title: const Text('إضافة صنف لاستمارة الجرد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15.5)),
                                      content: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          DropdownButtonFormField<int>(
                                            isExpanded: true,
                                            value: chosenId,
                                            items: available
                                                .map((p) => DropdownMenuItem<int>(value: p['id'] as int, child: Text('${p['name']}', style: const TextStyle(fontFamily: 'Cairo'))))
                                                .toList(),
                                            onChanged: (v) => setD(() => chosenId = v),
                                          ),
                                          const SizedBox(height: 12),
                                          AppNumericField(
                                            controller: qCtrl,
                                            label: 'الرصيد الفعلي',
                                            quickAddValues: const [1, 5, 10, 25],
                                          ),
                                        ],
                                      ),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('إلغاء')),
                                        FilledButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('إضافة')),
                                      ],
                                    ),
                                  ),
                                );
                                if (ok == true && chosenId != null) {
                                  final prod = available.firstWhere((p) => p['id'] == chosenId);
                                  final parsed = double.tryParse(qCtrl.text.trim()) ?? 0;
                                  setSheetState(() {
                                    entryRows.add({
                                      'product_id': chosenId,
                                      'product_name': prod['name'],
                                      'unit': prod['unit'] ?? '',
                                      'controller': TextEditingController(text: AppNumericKeypadSheet.formatNumber(parsed)),
                                    });
                                  });
                                }
                                qCtrl.dispose();
                              },
                      ),
                    ],
                  ),
                  Expanded(
                    child: loadingBranchStock
                        ? const AppLoadingView(message: 'جاري تحميل أرصدة المخزن...')
                        : entryRows.isEmpty
                            ? const Center(child: Text('أضف أصنافاً لإدخال أرصدتها الفعلية', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)))
                            : ListView.separated(
                                itemCount: entryRows.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (c, idx) {
                                  final row = entryRows[idx];
                                  final ctrl = row['controller'] as TextEditingController;
                                  return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceMuted,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Text('${row['product_name']}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13.5)),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          flex: 2,
                                          child: AppNumericField(
                                            controller: ctrl,
                                            label: 'الرصيد',
                                            unit: '${row['unit']}',
                                            dialogTitle: 'جرد: ${row['product_name']}',
                                            isDense: true,
                                            quickAddValues: const [1, 5, 10, 25],
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: isSubmitting || entryRows.isEmpty || branchId == null || loadingBranchStock
                        ? null
                        : () async {
                            final itemsPayload = <Map<String, dynamic>>[];
                            for (final r in entryRows) {
                              final txt = (r['controller'] as TextEditingController).text.trim();
                              final parsed = double.tryParse(txt);
                              if (parsed == null || parsed < 0) {
                                setSheetState(() => formError = 'أدخل رصيداً صالحاً للصنف "${r['product_name']}".');
                                return;
                              }
                              itemsPayload.add({
                                'product_id': r['product_id'],
                                'quantity': double.parse(parsed.toStringAsFixed(3)),
                              });
                            }
                            setSheetState(() { isSubmitting = true; formError = null; });
                            try {
                              await _api.post(
                                '/api/v1/stock/entry/',
                                idempotencyKey: _uuid.v4(),
                                body: {'branch_id': branchId, 'items': itemsPayload},
                              );
                              if (!mounted) return;
                              Navigator.pop(sheetCtx);
                              AppFeedback.showSuccess(context, 'تم اعتماد وتحديث الجرد الفعلي بنجاح');
                              await Future.wait([_loadStock(), _loadDailyReport()]);
                            } catch (e) {
                              if (ctx.mounted) {
                                setSheetState(() { isSubmitting = false; formError = e.toString(); });
                              }
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('اعتماد نتائج الجرد الفعلي'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    clearEntryControllers();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final branches = auth.allBranches.isNotEmpty ? auth.allBranches : auth.userBranches;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('المخزون والجرد واليومية'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'أرصدة المخزون'),
            Tab(text: 'الحركة اليومية'),
            Tab(text: 'الجرد الفعلي'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              if (_tabController.index == 1) {
                _loadDailyReport();
              } else {
                _loadStock();
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.fact_check_rounded),
        label: const Text('إدخال جرد فعلي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        onPressed: _showStocktakeSheet,
      ),
      body: Column(
        children: [
          if (branches.isNotEmpty)
            Container(
              color: Colors.white,
              height: 50,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                itemCount: branches.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final isAll = i == 0;
                  final branch = isAll ? null : branches[i - 1];
                  final isSelected = isAll ? _selectedBranchId == null : _selectedBranchId == branch?.id;
                  return ChoiceChip(
                    label: Text(isAll ? 'جميع الفروع' : (branch?.name ?? ''), style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: isSelected ? Colors.white : AppColors.textPrimary)),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    onSelected: (_) {
                      setState(() => _selectedBranchId = branch?.id);
                      _loadStock();
                      if (_tabController.index == 1) _loadDailyReport();
                    },
                  );
                },
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'ابحث باسم الصنف...',
                          prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                          isDense: true,
                        ),
                        onChanged: (val) {
                          _searchQuery = val;
                          _searchDebounce?.cancel();
                          _searchDebounce = Timer(const Duration(milliseconds: 300), _loadStock);
                        },
                      ),
                    ),
                    Expanded(
                      child: _isLoadingStock
                          ? const AppLoadingView(message: 'جاري تحميل أرصدة المخازن...')
                          : _stockError != null
                              ? AppErrorView(message: _stockError!, onRetry: _loadStock)
                              : _stockItems.isEmpty
                                  ? AppEmptyView(
                                      title: 'لا توجد أرصدة مسجلة بهذا المخزن',
                                      actionLabel: 'إدخال جرد افتتاحي',
                                      onAction: _showStocktakeSheet,
                                    )
                                  : RefreshIndicator(
                                      onRefresh: _loadStock,
                                      child: ListView.separated(
                                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 88),
                                        itemCount: _stockItems.length,
                                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                                        itemBuilder: (ctx, i) {
                                          final item = _stockItems[i];
                                          final unit = (item['product'] as Map<String, dynamic>?)?['unit']?.toString() ?? '';
                                          return Container(
                                            padding: const EdgeInsets.all(14),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(16),
                                              border: Border.all(color: AppColors.border),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(item['product_name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo', fontSize: 14.5, fontWeight: FontWeight.bold)),
                                                      Text('الفرع: ${item['branch_name'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.textSecondary)),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                ConstrainedBox(
                                                  constraints: const BoxConstraints(maxWidth: 115),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                    decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
                                                    child: Text(
                                                      '${item['quantity']} $unit',
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.edit_note_rounded, color: AppColors.primary),
                                                  tooltip: 'تسوية الرصيد',
                                                  onPressed: () => _showAdjustStockDialog(item),
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
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month_rounded, size: 18),
                        label: Text('تاريخ التقرير: ${_reportDate.toIso8601String().split('T')[0]}'),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _reportDate,
                            firstDate: DateTime(2022),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _reportDate = picked);
                            _loadDailyReport();
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: _isLoadingReport
                          ? const AppLoadingView(message: 'جاري تحميل حركات المخزون اليومية...')
                          : _reportError != null
                              ? AppErrorView(message: _reportError!, onRetry: _loadDailyReport)
                              : _dailyReports.isEmpty
                                  ? const AppEmptyView(title: 'لا توجد حركات مخزنية مسجلة في هذا التاريخ')
                                  : RefreshIndicator(
                                      onRefresh: _loadDailyReport,
                                      child: ListView.separated(
                                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                                        itemCount: _dailyReports.length,
                                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                                        itemBuilder: (ctx, i) {
                                          final rep = _dailyReports[i];
                                          final prod = rep['product'] as Map<String, dynamic>?;
                                          final branch = rep['branch'] as Map<String, dynamic>?;
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
                                                      child: Text('${prod?['name'] ?? ''} (${branch?['name'] ?? ''})', style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
                                                    ),
                                                    AppStatusBadge(label: 'ختامي: ${rep['final_quantity']} ${prod?['unit'] ?? ''}', color: AppColors.primary),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Wrap(
                                                  spacing: 10,
                                                  runSpacing: 4,
                                                  children: [
                                                    Text('افتتاحي: ${rep['initial_quantity']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5)),
                                                    Text('مشتريات: +${rep['received_bills']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.success)),
                                                    Text('وارد تحويل: +${rep['received_transfers']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.info)),
                                                    Text('تصنيع: +${rep['produced']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.primary)),
                                                    Text('مبيعات: -${rep['sold']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.warning)),
                                                    Text('صادر تحويل: -${rep['sent']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.error)),
                                                    Text('مستهلك: -${rep['consumed']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.error)),
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
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                          child: const Icon(Icons.assignment_turned_in_rounded, size: 48, color: AppColors.primary),
                        ),
                        const SizedBox(height: 16),
                        const Text('إدخال الجرد الفعلي للمخازن', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text(
                          'أدخل الأرصدة الفعلية الموجودة بالمخزن لتحديث الأرصدة وتسجيل الفروق بتقرير الحركة اليومية آلياً.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          icon: const Icon(Icons.edit_note_rounded),
                          label: const Text('فتح استمارة الجرد الفعلي'),
                          onPressed: _showStocktakeSheet,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
