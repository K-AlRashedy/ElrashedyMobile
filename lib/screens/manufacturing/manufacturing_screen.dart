import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/async_views.dart';

class ManufacturingScreen extends StatefulWidget {
  const ManufacturingScreen({super.key});

  @override
  State<ManufacturingScreen> createState() => _ManufacturingScreenState();
}

class _ManufacturingScreenState extends State<ManufacturingScreen> {
  final _api = ApiClient();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _orders = [];
  List<dynamic> _products = [];
  List<dynamic> _branches = [];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _api.setBaseUrl(auth.serverUrl);
    _api.setToken(auth.token);
    _loadData();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final boot = await _api.get('/api/v1/bootstrap/');
      if (boot is Map<String, dynamic> && mounted) {
        setState(() {
          _branches = boot['branches'] as List<dynamic>? ?? [];
        });
      }
      final cat = await _api.get('/api/v1/orders/catalog/');
      if (cat is Map<String, dynamic> && mounted) {
        setState(() {
          _products = (cat['products'] as List<dynamic>? ?? [])
              .where((p) => p['is_production'] == true || p['is_factory_production'] == true)
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.get('/api/v1/manufacturing/');
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _orders = res['results'] as List<dynamic>? ?? [];
          _isLoading = false;
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

  void _showCreateOrderSheet() {
    int? selectedBranchId = _branches.isNotEmpty ? _branches.first['id'] as int? : null;
    final List<Map<String, dynamic>> items = [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          int? currentProductId;
          final qtyController = TextEditingController();

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('أمر تصنيع وتشغيل جديد', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
                    ],
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'فرع التصنيع'),
                    value: selectedBranchId,
                    items: _branches.map<DropdownMenuItem<int>>((b) {
                      return DropdownMenuItem<int>(
                        value: b['id'] as int,
                        child: Text(b['name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo')),
                      );
                    }).toList(),
                    onChanged: (val) => setSheetState(() => selectedBranchId = val),
                  ),
                  const SizedBox(height: 14),
                  const Text('الأصناف المطلوب إنتاجها:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  if (items.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length,
                      itemBuilder: (c, idx) {
                        final item = items[idx];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.check_circle_outline, color: AppColors.success),
                          title: Text(item['name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                          subtitle: Text('الكمية: ${item['quantity']}', style: const TextStyle(fontFamily: 'Cairo')),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.error),
                            onPressed: () => setSheetState(() => items.removeAt(idx)),
                          ),
                        );
                      },
                    ),
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
                          decoration: const InputDecoration(labelText: 'اختر منتج التصنيع', isDense: true),
                          value: currentProductId,
                          items: _products.map<DropdownMenuItem<int>>((p) {
                            return DropdownMenuItem<int>(
                              value: p['id'] as int,
                              child: Text(p['name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo')),
                            );
                          }).toList(),
                          onChanged: (val) => currentProductId = val,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: qtyController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(labelText: 'الكمية المنتجة', isDense: true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('إضافة', style: TextStyle(fontFamily: 'Cairo')),
                              onPressed: () {
                                if (currentProductId != null && qtyController.text.trim().isNotEmpty) {
                                  final p = _products.firstWhere((x) => x['id'] == currentProductId);
                                  setSheetState(() {
                                    items.add({
                                      'product_id': currentProductId,
                                      'name': p['name'],
                                      'quantity': qtyController.text.trim(),
                                    });
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: items.isEmpty || selectedBranchId == null
                        ? null
                        : () async {
                            try {
                              await _api.post('/api/v1/manufacturing/create/', body: {
                                'branch_id': selectedBranchId,
                                'items': items.map((i) => {
                                  'product_id': i['product_id'],
                                  'quantity': i['quantity'],
                                }).toList(),
                              });
                              if (mounted) {
                                Navigator.pop(sheetContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تم إنشاء وتأكيد أمر التصنيع بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
                                );
                                _loadData();
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.error),
                                );
                              }
                            }
                          },
                    child: const Text('اعتماد أمر التشغيل والخصم من الخام', style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDetailSheet(Map<String, dynamic> order) {
    final items = order['items'] as List<dynamic>? ?? [];
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('أمر تصنيع #${order['id']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 8),
            Text('الفرع: ${order['branch_name'] ?? order['branch']?['name'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
            Text('التاريخ: ${order['date'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
            const Divider(height: 24),
            const Text('المنتجات المصنعة:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (c, i) {
                  final item = items[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item['product_name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    trailing: Text('${item['quantity']} ${item['unit'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.primary)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('أوامر التشغيل والتصنيع (BOM)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث', onPressed: _loadData),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.precision_manufacturing_rounded),
        label: const Text('أمر تشغيل جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        onPressed: _showCreateOrderSheet,
      ),
      body: _isLoading
          ? const AppLoadingView(message: 'جاري تحميل أوامر التصنيع...')
          : _error != null
              ? AppErrorView(message: _error!, onRetry: _loadData)
              : _orders.isEmpty
                  ? const AppEmptyView(title: 'لا توجد أوامر تشغيل مسجلة', icon: Icons.precision_manufacturing_outlined)
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: _orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final order = _orders[i] as Map<String, dynamic>;
                          final itemsCount = (order['items'] as List<dynamic>?)?.length ?? 0;
                          return InkWell(
                            onTap: () => _showDetailSheet(order),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
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
                                      color: AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.factory_outlined, color: AppColors.primary, size: 24),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'أمر تشغيل #${order['id']}',
                                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'الفرع: ${order['branch_name'] ?? order['branch']?['name'] ?? ''}',
                                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textSecondary),
                                        ),
                                        Text(
                                          'التاريخ: ${order['date'] ?? ''} • $itemsCount أصناف',
                                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textMuted),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
