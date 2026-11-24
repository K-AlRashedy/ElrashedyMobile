import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../models/product_model.dart';
import '../../providers/order_provider.dart';
import '../../widgets/async_views.dart';

class EditOrderScreen extends StatefulWidget {
  final int orderId;

  const EditOrderScreen({super.key, required this.orderId});

  @override
  State<EditOrderScreen> createState() => _EditOrderScreenState();
}

class _EditableOrderItem {
  final int productId;
  final String name;
  final String unit;
  final TextEditingController quantity;
  final TextEditingController note;

  _EditableOrderItem({
    required this.productId,
    required this.name,
    required this.unit,
    required double quantity,
    required String note,
  })  : quantity = TextEditingController(text: _number(quantity)),
        note = TextEditingController(text: note);

  static String _number(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();

  void dispose() {
    quantity.dispose();
    note.dispose();
  }
}

class _EditOrderScreenState extends State<EditOrderScreen> {
  final List<_EditableOrderItem> _items = [];
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await context.read<ApiClient>().get('/api/v1/orders/${widget.orderId}/');
      if (response is! Map<String, dynamic> || response['order'] is! Map<String, dynamic>) {
        throw const FormatException('بيانات الطلب غير صالحة.');
      }
      final order = response['order'] as Map<String, dynamic>;
      final rawItems = order['items'] as List<dynamic>? ?? const [];
      final loaded = rawItems.whereType<Map<String, dynamic>>().map((item) {
        return _EditableOrderItem(
          productId: item['product_id'] as int? ?? 0,
          name: item['product_name']?.toString() ?? 'صنف',
          unit: item['unit']?.toString() ?? '',
          quantity: (item['requested'] as num?)?.toDouble() ?? 0,
          note: item['note']?.toString() ?? '',
        );
      }).toList();
      if (!mounted) {
        for (final item in loaded) {
          item.dispose();
        }
        return;
      }
      for (final item in _items) {
        item.dispose();
      }
      _items
        ..clear()
        ..addAll(loaded);
      await context.read<OrderProvider>().loadCatalog();
    } catch (error) {
      if (mounted) _error = error.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addProduct(ProductModel product) {
    if (_items.any((item) => item.productId == product.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} موجود بالفعل في الطلب.', style: const TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }
    setState(() {
      _items.add(_EditableOrderItem(
        productId: product.id,
        name: product.name,
        unit: product.unit,
        quantity: 1,
        note: '',
      ));
    });
  }

  Future<void> _showProductPicker() async {
    final provider = context.read<OrderProvider>();
    final searchController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Consumer<OrderProvider>(
              builder: (_, value, __) {
                final products = value.filteredProducts;
                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4))),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          hintText: 'ابحث عن صنف لإضافته...',
                          prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary),
                        ),
                        onChanged: provider.setSearchQuery,
                      ),
                    ),
                    Expanded(
                      child: products.isEmpty
                          ? const AppEmptyView(message: 'لا توجد أصناف مطابقة.')
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: products.length,
                              itemBuilder: (_, index) {
                                final product = products[index];
                                return ListTile(
                                  leading: const Icon(Icons.inventory_2_rounded, color: AppColors.primary),
                                  title: Text(product.name, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                  subtitle: Text('${product.category} • ${product.unit}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                                  trailing: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                                  onTap: () {
                                    _addProduct(product);
                                    Navigator.of(sheetContext).pop();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
    searchController.dispose();
  }

  Future<void> _save() async {
    final payload = <Map<String, dynamic>>[];
    for (final item in _items) {
      final quantity = double.tryParse(item.quantity.text.trim());
      if (quantity == null || quantity <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('أدخل كمية صحيحة للصنف ${item.name}.', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
        );
        return;
      }
      payload.add({
        'product_id': item.productId,
        'quantity': quantity,
        'note': item.note.text.trim(),
      });
    }
    if (payload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن حفظ طلب بدون أصناف.', style: TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await context.read<ApiClient>().post(
        '/api/v1/orders/update/${widget.orderId}/',
        idempotencyKey: 'order-update-${widget.orderId}-${DateTime.now().millisecondsSinceEpoch}',
        body: {'items': payload},
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString(), style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('تعديل أصناف الطلب', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const AppLoadingView()
          : _error != null
              ? AppErrorView(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(14)),
                            child: const Row(children: [
                              Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                              SizedBox(width: 10),
                              Expanded(child: Text('سيتم استبدال أصناف الطلب الحالية بالقائمة التالية. الفروع لا يمكن تغييرها أثناء التعديل.', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.primaryDark))),
                            ]),
                          ),
                          const SizedBox(height: 12),
                          for (var index = 0; index < _items.length; index++) _buildItemCard(index),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _showProductPicker,
                            icon: const Icon(Icons.add_rounded, size: 19),
                            label: const Text('إضافة صنف للطلب', style: TextStyle(fontFamily: 'Cairo')),
                          ),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, minimumSize: const Size.fromHeight(52)),
                          icon: _isSaving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.save_rounded),
                          label: Text(_isSaving ? 'جارٍ الحفظ...' : 'حفظ تعديلات الطلب', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(item.name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
              IconButton(tooltip: 'حذف الصنف', icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger), onPressed: () => setState(() { _items.removeAt(index).dispose(); })),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: item.quantity,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'الكمية', suffixText: item.unit, isDense: true, border: const OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.sticky_note_2_outlined, size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: item.note,
                  decoration: const InputDecoration(labelText: 'ملاحظة', isDense: true, border: const OutlineInputBorder()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
