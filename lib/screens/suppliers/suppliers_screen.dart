import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../widgets/async_views.dart';

class SuppliersScreen extends StatefulWidget {
  final int initialTab;
  const SuppliersScreen({super.key, this.initialTab = 0});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _api = ApiClient();

  // Tab 1: Suppliers
  List<dynamic> _suppliers = [];
  bool _isLoadingSuppliers = true;
  String _supplierSearch = '';

  // Tab 2: Purchase Bills
  List<dynamic> _bills = [];
  bool _isLoadingBills = false;
  String _billSearch = '';

  // Tab 3: Operations Log
  List<dynamic> _operations = [];
  bool _isLoadingOperations = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTab.clamp(0, 2));
    _tabController.addListener(() {
      if (_tabController.index == 1 && _bills.isEmpty) {
        _loadBills();
      } else if (_tabController.index == 2 && _operations.isEmpty) {
        _loadOperations();
      }
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      _api.setBaseUrl(auth.serverUrl);
      _api.setToken(auth.token);
      _loadSuppliers();
      context.read<OrderProvider>().loadCatalog();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSuppliers() async {
    setState(() => _isLoadingSuppliers = true);
    try {
      final res = await _api.get('/api/v1/suppliers/');
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _suppliers = res['results'] as List<dynamic>? ?? res['suppliers'] as List<dynamic>? ?? [];
          _isLoadingSuppliers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSuppliers = false);
    }
  }

  Future<void> _loadBills() async {
    setState(() => _isLoadingBills = true);
    try {
      final res = await _api.get('/api/v1/bills/');
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _bills = res['results'] as List<dynamic>? ?? res['bills'] as List<dynamic>? ?? [];
          _isLoadingBills = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingBills = false);
    }
  }

  Future<void> _loadOperations() async {
    setState(() => _isLoadingOperations = true);
    try {
      final res = await _api.get('/api/v1/purchases/operations/');
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _operations = res['results'] as List<dynamic>? ?? res['operations'] as List<dynamic>? ?? [];
          _isLoadingOperations = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingOperations = false);
    }
  }

  void _showAddSupplierSheet() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final addressController = TextEditingController();
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
                      const Text('إضافة مورد جديد', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(sheetCtx)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'اسم المورد أو الشركة *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'رقم الهاتف *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressController,
                    decoration: InputDecoration(
                      labelText: 'العنوان أو الملاحظات',
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
                            final name = nameController.text.trim();
                            final phone = phoneController.text.trim();
                            if (name.isEmpty || phone.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('يرجى إدخال اسم المورد ورقم الهاتف', style: TextStyle(fontFamily: 'Cairo'))),
                              );
                              return;
                            }
                            setSheetState(() => isSubmitting = true);
                            try {
                              await _api.post('/api/v1/suppliers/create/', body: {
                                'name': name,
                                'phone': phone,
                                'address': addressController.text.trim(),
                              });
                              if (mounted) {
                                Navigator.pop(sheetCtx);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تمت إضافة المورد بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
                                );
                                _loadSuppliers();
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
                        : const Text('حفظ المورد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddBillSheet() {
    final branches = context.read<AuthProvider>().userBranches;
    int? selectedBranch = branches.isNotEmpty ? branches.first.id : null;
    int? selectedSupplierId = _suppliers.isNotEmpty ? _suppliers.first['id'] as int? : null;
    final products = context.read<OrderProvider>().products;
    final billItems = <int, double>{};
    final discountController = TextEditingController(text: '0');
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
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
                    const Text('إنشاء فاتورة مشتريات جديدة', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(sheetCtx)),
                  ],
                ),
                const SizedBox(height: 12),
                if (_suppliers.isNotEmpty)
                  DropdownButtonFormField<int>(
                    initialValue: selectedSupplierId,
                    decoration: InputDecoration(
                      labelText: 'المورد',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: _suppliers.map((s) => DropdownMenuItem<int>(value: s['id'] as int, child: Text(s['name'] ?? '', style: const TextStyle(fontFamily: 'Cairo')))).toList(),
                    onChanged: (val) => setSheetState(() => selectedSupplierId = val),
                  ),
                const SizedBox(height: 10),
                if (branches.isNotEmpty)
                  DropdownButtonFormField<int>(
                    initialValue: selectedBranch,
                    decoration: InputDecoration(
                      labelText: 'المخزن / الفرع المستلم',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, style: const TextStyle(fontFamily: 'Cairo')))).toList(),
                    onChanged: (val) => setSheetState(() => selectedBranch = val),
                  ),
                const SizedBox(height: 10),
                const Text('أصناف الفاتورة المستلمة:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 6),
                Expanded(
                  child: ListView.separated(
                    itemCount: products.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (c, idx) {
                      final p = products[idx];
                      final qty = billItems[p.id] ?? 0.0;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: qty > 0 ? AppColors.primaryLight.withValues(alpha: 0.3) : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text('الوحدة: ${p.unit}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                              onPressed: qty > 0 ? () => setSheetState(() => billItems[p.id] = (qty - 1).clamp(0, 99999)) : null,
                            ),
                            Text('${qty % 1 == 0 ? qty.toInt() : qty}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 20, color: AppColors.primary),
                              onPressed: () => setSheetState(() => billItems[p.id] = qty + 1),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: isSubmitting || billItems.values.every((v) => v <= 0) || selectedSupplierId == null
                      ? null
                      : () async {
                          setSheetState(() => isSubmitting = true);
                          final items = billItems.entries
                              .where((e) => e.value > 0)
                              .map((e) => {'product_id': e.key, 'quantity': e.value})
                              .toList();
                          try {
                            await _api.post('/api/v1/bills/create/', body: {
                              'supplier_id': selectedSupplierId,
                              'branch_id': selectedBranch,
                              'discount': double.tryParse(discountController.text.trim()) ?? 0.0,
                              'items': items,
                            });
                            if (mounted) {
                              Navigator.pop(sheetCtx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم إنشاء فاتورة المشتريات بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
                              );
                              _loadBills();
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
                      : const Text('حفظ فاتورة المشتريات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmBill(int billId) async {
    try {
      await _api.post('/api/v1/bills/$billId/confirm/', body: {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم اعتماد فاتورة المشتريات وإضافة البضاعة للمخزن', style: TextStyle(fontFamily: 'Cairo'))),
        );
        _loadBills();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: const Text('المشتريات وإدارة الموردين', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'دليل الموردين'),
            Tab(text: 'فواتير المشتريات'),
            Tab(text: 'سجل العمليات'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: () {
              if (_tabController.index == 0) _loadSuppliers();
              if (_tabController.index == 1) _loadBills();
              if (_tabController.index == 2) _loadOperations();
            },
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded),
            tooltip: 'فاتورة مشتريات جديدة',
            onPressed: _showAddBillSheet,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: Icon(_tabController.index == 1 ? Icons.post_add_rounded : Icons.person_add_rounded),
        label: Text(
          _tabController.index == 1 ? 'فاتورة مشتريات' : 'إضافة مورد',
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        onPressed: _tabController.index == 1 ? _showAddBillSheet : _showAddSupplierSheet,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Suppliers Directory
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'ابحث عن مورد بالاسم أو الهاتف...',
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary),
                  ),
                  onChanged: (val) => setState(() => _supplierSearch = val),
                ),
              ),
              Expanded(
                child: _isLoadingSuppliers
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _suppliers.isEmpty
                        ? AppEmptyView(title: 'لا يوجد موردين مسجلين', actionLabel: 'إضافة مورد جديد', onAction: _showAddSupplierSheet)
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: _suppliers.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, i) {
                              final sup = _suppliers[i];
                              final name = (sup['name'] ?? '').toString();
                              final phone = (sup['phone'] ?? '').toString();
                              final q = _supplierSearch.toLowerCase();
                              if (q.isNotEmpty && !name.toLowerCase().contains(q) && !phone.contains(q)) {
                                return const SizedBox.shrink();
                              }

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
                                      child: const Icon(Icons.business_rounded, color: AppColors.primary, size: 24),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 2),
                                          Text(phone.isNotEmpty ? phone : 'بدون هاتف', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                                        ],
                                      ),
                                    ),
                                    if (sup['balance'] != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.surfaceMuted,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '${sup['balance']} ج.م',
                                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),

          // Tab 2: Purchase Bills
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'ابحث برقم الفاتورة أو المورد...',
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary),
                  ),
                  onChanged: (val) => setState(() => _billSearch = val),
                ),
              ),
              Expanded(
                child: _isLoadingBills
                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                    : _bills.isEmpty
                        ? AppEmptyView(title: 'لا توجد فواتير مشتريات مسجلة', actionLabel: 'إنشاء فاتورة مشتريات', onAction: _showAddBillSheet)
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                            itemCount: _bills.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, i) {
                              final bill = _bills[i];
                              final id = (bill['id'] ?? '').toString();
                              final supName = (bill['supplier_name'] ?? bill['supplier']?['name'] ?? '').toString().toLowerCase();
                              final q = _billSearch.trim().toLowerCase();
                              if (q.isNotEmpty && !id.contains(q) && !supName.contains(q)) {
                                return const SizedBox.shrink();
                              }
                              final isConfirmed = bill['is_confirmed'] == true || bill['status'] == 'confirmed';
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
                                            color: isConfirmed ? AppColors.success.withValues(alpha: 0.12) : AppColors.warning.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            isConfirmed ? Icons.check_circle_rounded : Icons.pending_rounded,
                                            color: isConfirmed ? AppColors.success : AppColors.warning,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'فاتورة #${bill['id']} • ${bill['supplier_name'] ?? bill['supplier']?['name'] ?? ''}',
                                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold),
                                              ),
                                              Text(
                                                '${bill['branch_name'] ?? ''} • ${bill['date'] ?? ''}',
                                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '${bill['total']} ج.م',
                                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                                        ),
                                      ],
                                    ),
                                    if (!isConfirmed) ...[
                                      const Divider(height: 20),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          FilledButton.icon(
                                            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                                            icon: const Icon(Icons.done_all_rounded, size: 18),
                                            label: const Text('اعتماد وإدخال المخزن', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                            onPressed: () => _confirmBill(bill['id']),
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
            ],
          ),

          // Tab 3: Operations Log
          _isLoadingOperations
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _operations.isEmpty
                  ? const Center(child: AppEmptyView(title: 'لا توجد حركات مشتريات مسجلة'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _operations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final op = _operations[i];
                        return Container(
                          padding: const EdgeInsets.all(14),
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
                                  color: AppColors.accent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.history_rounded, color: AppColors.accent, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      op['details'] ?? op['title'] ?? 'حركة مشتريات',
                                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      op['date'] ?? '',
                                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              if (op['amount'] != null)
                                Text(
                                  '${op['amount']} ج.م',
                                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary),
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
