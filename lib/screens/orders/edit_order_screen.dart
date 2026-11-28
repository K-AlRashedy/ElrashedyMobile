import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../models/product_model.dart';
import '../../providers/order_provider.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/async_views.dart';
import '../../widgets/numeric_keypad_sheet.dart';

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
  })  : quantity = TextEditingController(text: AppNumericKeypadSheet.formatNumber(quantity)),
        note = TextEditingController(text: note);

  void dispose() {
    quantity.dispose();
    note.dispose();
  }
}

class _EditOrderScreenState extends State<EditOrderScreen> {
  final _uuid = const Uuid();
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
      await context.read<OrderProvider>().loadCatalog(refresh: true);
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
      AppFeedback.showError(context, '${product.name} موجود بالفعل في الطلب.');
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
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(4))),
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
                      child: value.isLoadingCatalog && products.isEmpty
                          ? const AppLoadingView()
                          : value.errorMessage != null && products.isEmpty
                              ? AppErrorView(message: value.errorMessage!, onRetry: () => provider.loadCatalog(refresh: true))
                              : products.isEmpty
                                  ? const AppEmptyView(message: 'لا توجد أصناف مطابقة.')
                                  : NotificationListener<ScrollNotification>(
                                      onNotification: (info) {
                                        if (info.metrics.extentAfter < 250 && value.catalogHasNext && !value.isLoadingMoreCatalog) {
                                          value.loadMoreCatalog();
                                        }
                                        return false;
                                      },
                                      child: ListView.builder(
                                        controller: scrollController,
                                        itemCount: products.length + (value.catalogHasNext ? 1 : 0),
                                        itemBuilder: (_, index) {
                                          if (index >= products.length) {
                                            return const Padding(
                                              padding: EdgeInsets.all(14),
                                              child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                                            );
                                          }
                                          final product = products[index];
                                          return ListTile(
                                            leading: const Icon(Icons.inventory_2_rounded, color: AppColors.primary),
                                            title: Text(product.name, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                            subtitle: Text('${product.category} • ${product.unit}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5)),
                                            trailing: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary),
                                            onTap: () {
                                              _addProduct(product);
                                              Navigator.of(sheetContext).pop();
                                            },
                                          );
                                        },
                                      ),
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
    provider.clearSearch();
    searchController.dispose();
  }

  Future<void> _save() async {
    final payload = <Map<String, dynamic>>[];
    for (final item in _items) {
      final quantity = double.tryParse(item.quantity.text.trim());
      if (quantity == null || quantity <= 0) {
        AppFeedback.showError(context, 'أدخل كمية صحيحة أكبر من صفر للصنف ${item.name}.');
        return;
      }
      payload.add({
        'product_id': item.productId,
        'quantity': quantity,
        'note': item.note.text.trim(),
      });
    }
    if (payload.isEmpty) {
      AppFeedback.showError(context, 'لا يمكن حفظ طلب بدون أصناف.');
      return;
    }
    setState(() => _isSaving = true);
    try {
      await context.read<ApiClient>().post(
        '/api/v1/orders/update/${widget.orderId}/',
        idempotencyKey: _uuid.v4(),
        body: {'items': payload},
      );
      if (mounted) {
        AppFeedback.showSuccess(context, 'تم تحديث أصناف الطلب بنجاح');
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) AppFeedback.showError(context, error.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('تعديل طلب #${widget.orderId}')),
      body: _isLoading
          ? const AppLoadingView()
          : _error != null
              ? AppErrorView(message: _error!, onRetry: _load)
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(14)),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'سيتم استبدال أصناف الطلب الحالية بالقائمة التالية. الفروع لا يمكن تغييرها أثناء التعديل.',
                                    style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.primaryDark),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          for (var index = 0; index < _items.length; index++) _buildItemCard(index),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _showProductPicker,
                            icon: const Icon(Icons.add_rounded, size: 19),
                            label: const Text('إضافة صنف للطلب'),
                          ),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          boxShadow: [BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, -3))],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _save,
                          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                          icon: _isSaving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.save_rounded),
                          label: Text(_isSaving ? 'جارٍ الحفظ...' : 'حفظ تعديلات الطلب'),
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
              Expanded(child: Text(item.name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14.5, fontWeight: FontWeight.bold))),
              IconButton(
                tooltip: 'حذف الصنف',
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                onPressed: () => setState(() => _items.removeAt(index).dispose()),
              ),
            ],
          ),
          const SizedBox(height: 10),
          AppNumericField(
            controller: item.quantity,
            label: 'الكمية المطلوبة *',
            unit: item.unit,
            dialogTitle: 'تعديل كمية: ${item.name}',
            quickAddValues: const [1, 5, 10, 25],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: item.note,
            decoration: const InputDecoration(
              labelText: 'ملاحظة على الصنف (اختياري)',
              prefixIcon: Icon(Icons.sticky_note_2_outlined, size: 18),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}
