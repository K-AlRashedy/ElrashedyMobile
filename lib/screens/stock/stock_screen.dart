import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/async_views.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _api = ApiClient();

  // Tab 1: Live Stock
  List<dynamic> _stockItems = [];
  bool _isLoadingStock = true;
  String _searchQuery = '';
  int? _selectedBranchId;

  // Tab 2: Daily Stock Report
  List<dynamic> _dailyReports = [];
  bool _isLoadingReport = false;
  DateTime _reportDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && _dailyReports.isEmpty) {
        _loadDailyReport();
      }
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      _api.setBaseUrl(auth.serverUrl);
      _api.setToken(auth.token);
      _loadStock();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadStock() async {
    setState(() => _isLoadingStock = true);
    try {
      final params = <String, String>{};
      if (_selectedBranchId != null) params['branch_id'] = _selectedBranchId.toString();
      final res = await _api.get('/api/v1/stock/', queryParams: params);
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _stockItems = res['results'] as List<dynamic>? ?? res['stock'] as List<dynamic>? ?? [];
          _isLoadingStock = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStock = false);
    }
  }

  Future<void> _loadDailyReport() async {
    setState(() => _isLoadingReport = true);
    try {
      final dateStr = _reportDate.toIso8601String().split('T')[0];
      final params = <String, String>{'date': dateStr};
      if (_selectedBranchId != null) params['branch_id'] = _selectedBranchId.toString();
      final res = await _api.get('/api/v1/stock/daily-report/', queryParams: params);
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _dailyReports = res['results'] as List<dynamic>? ?? [];
          _isLoadingReport = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingReport = false);
    }
  }

  void _showAdjustStockDialog(Map<String, dynamic> item) {
    final deltaController = TextEditingController();
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('تعديل مخزون ${item['product_name']}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الرصيد الحالي: ${item['quantity']} ${item['unit'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
              const SizedBox(height: 12),
              TextField(
                controller: deltaController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(
                  labelText: 'قيمة التعديل (مثال: +5 أو -2)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'سبب التسوية (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final delta = double.tryParse(deltaController.text.trim());
                      if (delta == null || delta == 0) return;
                      setDialogState(() => isSubmitting = true);
                      try {
                        await _api.post('/api/v1/stock/${item['id']}/adjust/', body: {
                          'delta': delta,
                          'reason': reasonController.text.trim(),
                        });
                        if (mounted) {
                          Navigator.pop(dialogCtx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم تعديل رصيد المخزون بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
                          );
                          _loadStock();
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('تأكيد التسوية', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }

  void _showStocktakeSheet() {
    int? branchId = _selectedBranchId;
    final qtyControllers = <int, TextEditingController>{};
    bool isSubmitting = false;

    for (final item in _stockItems) {
      final pid = item['product_id'] as int? ?? 0;
      qtyControllers[pid] = TextEditingController(text: '${item['quantity'] ?? 0}');
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('إدخال الجرد الفعلي للمخزن', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(sheetCtx)),
                ],
              ),
              const SizedBox(height: 8),
              const Text('قم بتحديث الأرصدة الفعلية للمنتجات ثم اضغط اعتماد الجرد.', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
              const Divider(height: 24),
              Expanded(
                child: ListView.separated(
                  itemCount: _stockItems.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (c, idx) {
                    final item = _stockItems[idx];
                    final pid = item['product_id'] as int? ?? 0;
                    final controller = qtyControllers[pid]!;
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['product_name'] ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                                Text('الفرع: ${item['branch_name']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 100,
                            child: TextField(
                              controller: controller,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                suffixText: item['unit'] ?? '',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
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
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: isSubmitting || _stockItems.isEmpty
                    ? null
                    : () async {
                        branchId ??= _stockItems.first['branch_id'] as int?;
                        if (branchId == null) return;
                        setSheetState(() => isSubmitting = true);
                        final itemsPayload = <Map<String, dynamic>>[];
                        for (final item in _stockItems) {
                          final pid = item['product_id'] as int? ?? 0;
                          final qty = double.tryParse(qtyControllers[pid]?.text.trim() ?? '') ?? 0.0;
                          itemsPayload.add({'product_id': pid, 'quantity': qty});
                        }
                        try {
                          await _api.post('/api/v1/stock/entry/', body: {
                            'branch_id': branchId,
                            'items': itemsPayload,
                          });
                          if (mounted) {
                            Navigator.pop(sheetCtx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم اعتماد وتحديث الجرد الفعلي بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
                            );
                            _loadStock();
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
                    : const Text('اعتماد نتائج الجرد الفعلي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final branches = context.watch<AuthProvider>().userBranches;

    final filteredStock = _stockItems.where((item) {
      final name = item['product_name']?.toString().toLowerCase() ?? '';
      final branch = item['branch_name']?.toString().toLowerCase() ?? '';
      final q = _searchQuery.toLowerCase();
      final matchesSearch = q.isEmpty || name.contains(q) || branch.contains(q);
      final matchesBranch = _selectedBranchId == null || item['branch_id'] == _selectedBranchId;
      return matchesSearch && matchesBranch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('إدارة المخزون والجرد', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'أرصدة المخزون'),
            Tab(text: 'جرد اليومية'),
            Tab(text: 'الجرد الفعلي'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
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
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Live Stock
          Column(
            children: [
              // Search & Branch Filter
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'ابحث بالصنف أو الفرع...',
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              if (branches.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: branches.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final isAll = i == 0;
                      final branch = isAll ? null : branches[i - 1];
                      final isSelected = isAll ? _selectedBranchId == null : _selectedBranchId == branch?.id;
                      return ChoiceChip(
                        label: Text(
                          isAll ? 'جميع الفروع' : (branch?.name ?? ''),
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: isSelected ? Colors.white : AppColors.textPrimary),
                        ),
                        selected: isSelected,
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.white,
                        onSelected: (_) {
                          setState(() => _selectedBranchId = branch?.id);
                          _loadStock();
                        },
                      );
                    },
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                child: Row(
                  children: [
                    Text(
                      'إجمالي الأصناف: ${filteredStock.length}',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoadingStock
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : filteredStock.isEmpty
                        ? const Center(child: AppEmptyView(title: 'لا توجد أرصدة مخزنية حالياً'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                            itemCount: filteredStock.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final item = filteredStock[i];
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
                                          Text(
                                            item['product_name'] ?? '',
                                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              const Icon(Icons.store_rounded, size: 14, color: AppColors.textMuted),
                                              const SizedBox(width: 4),
                                              Text(
                                                item['branch_name'] ?? '',
                                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLight,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${item['quantity']} ${item['unit'] ?? ''}',
                                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.edit_note_rounded, color: AppColors.primary),
                                      tooltip: 'تسوية رصيد',
                                      onPressed: () => _showAdjustStockDialog(item),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),

          // Tab 2: Daily Stock Report
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month_rounded, size: 18),
                        label: Text(
                          'تاريخ الجرد: ${_reportDate.toIso8601String().split('T')[0]}',
                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _reportDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() => _reportDate = picked);
                            _loadDailyReport();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoadingReport
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _dailyReports.isEmpty
                        ? const Center(child: AppEmptyView(title: 'لا يوجد تقرير جرد لهذا التاريخ'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                            itemCount: _dailyReports.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, i) {
                              final rep = _dailyReports[i];
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
                                        Text(
                                          rep['product_name'] ?? rep['product']?['name'] ?? '',
                                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(6)),
                                          child: Text(
                                            'الرصيد النهائي: ${rep['final_quantity'] ?? rep['quantity'] ?? 0}',
                                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        Text('الفرع: ${rep['branch_name'] ?? rep['branch']?['name'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary)),
                                        const Spacer(),
                                        Text('مبيعات: ${rep['sold'] ?? 0}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary)),
                                        const SizedBox(width: 8),
                                        Text('توالف: ${rep['damaged'] ?? 0}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.error)),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),

          // Tab 3: Stocktake Direct Action
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.assignment_turned_in_rounded, size: 48, color: AppColors.primary),
                  ),
                  const SizedBox(height: 16),
                  const Text('الجرد الفعلي للمخازن', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('يمكنك إدخال الكميات الفعلية الموجودة على أرض الواقع لمطابقتها مع السيستم آلياً.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('فتح استمارة الجرد الفعلي', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    onPressed: _showStocktakeSheet,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
