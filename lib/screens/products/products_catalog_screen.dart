import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../widgets/async_views.dart';
import '../orders/create_order_screen.dart';

class ProductsCatalogScreen extends StatefulWidget {
  const ProductsCatalogScreen({super.key});

  @override
  State<ProductsCatalogScreen> createState() => _ProductsCatalogScreenState();
}

class _ProductsCatalogScreenState extends State<ProductsCatalogScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _api = ApiClient();

  List<dynamic> _menuSections = [];
  bool _isLoadingSections = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 4 && _menuSections.isEmpty) {
        _loadMenuSections();
      }
      setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      _api.setBaseUrl(auth.serverUrl);
      _api.setToken(auth.token);
      context.read<OrderProvider>().loadCatalog();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadMenuSections() async {
    setState(() => _isLoadingSections = true);
    try {
      final res = await _api.get('/api/v1/catalog/menu-sections/');
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _menuSections = res['results'] as List<dynamic>? ?? res['menu_sections'] as List<dynamic>? ?? [];
          _isLoadingSections = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingSections = false);
    }
  }

  void _showAddProductSheet() {
    final nameController = TextEditingController();
    final unitController = TextEditingController(text: 'قطعة');
    final categoryController = TextEditingController(text: 'عام');
    final priceController = TextEditingController();
    final costController = TextEditingController();
    bool isSold = true;
    bool isStock = true;
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
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
                      const Text('إضافة صنف جديد للمنظومة', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(sheetContext)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'اسم الصنف *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: unitController,
                          decoration: InputDecoration(
                            labelText: 'الوحدة (مثال: قطعة، كجم)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: categoryController,
                          decoration: InputDecoration(
                            labelText: 'القسم / التصنيف',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'سعر البيع (ج.م) *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: costController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'التكلفة الاسترشادية',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('صنف قابل للبيع', style: TextStyle(fontFamily: 'Cairo')),
                    value: isSold,
                    onChanged: (val) => setSheetState(() => isSold = val),
                  ),
                  SwitchListTile(
                    title: const Text('صنف خاضع للمخزون والجرد', style: TextStyle(fontFamily: 'Cairo')),
                    value: isStock,
                    onChanged: (val) => setSheetState(() => isStock = val),
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
                            final price = double.tryParse(priceController.text.trim()) ?? 0.0;
                            if (name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('يرجى إدخال اسم الصنف', style: TextStyle(fontFamily: 'Cairo'))),
                              );
                              return;
                            }
                            setSheetState(() => isSubmitting = true);
                            try {
                              await _api.post('/api/v1/catalog/products/create/', body: {
                                'name': name,
                                'unit': unitController.text.trim(),
                                'category': categoryController.text.trim(),
                                'price': price,
                                'cost': double.tryParse(costController.text.trim()) ?? 0.0,
                                'is_sold': isSold,
                                'is_stock': isStock,
                                'is_visible': true,
                              });
                              if (mounted) {
                                Navigator.pop(sheetContext);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('تمت إضافة الصنف بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
                                );
                                context.read<OrderProvider>().loadCatalog();
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
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text('حفظ الصنف الجديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAddMenuSectionSheet() {
    final nameController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('إضافة قسم منيو جديد', style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(sheetContext)),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'اسم القسم (مثال: وجبات، مشروبات، إضافات) *',
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
                          if (name.isEmpty) return;
                          setSheetState(() => isSubmitting = true);
                          try {
                            await _api.post('/api/v1/catalog/menu-sections/create/', body: {'name': name});
                            if (mounted) {
                              Navigator.pop(sheetContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم إنشاء قسم المنيو بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
                              );
                              _loadMenuSections();
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
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('حفظ القسم', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<ProductModel> _getFilteredProducts(List<ProductModel> products) {
    switch (_tabController.index) {
      case 1: // Raw Materials
        return products.where((p) => p.category.contains('خام') || !p.isSold).toList();
      case 2: // Complete BOM
        return products.where((p) => p.isSold && p.price > 0).toList();
      case 3: // Incomplete BOM
        return products.where((p) => p.price <= 0).toList();
      case 0: // All
      default:
        return products;
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final allProducts = orderProvider.filteredProducts;
    final currentProducts = _getFilteredProducts(allProducts);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('دليل الأصناف والمنيو', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'جميع الأصناف'),
            Tab(text: 'المواد الخام'),
            Tab(text: 'مكونات مكتملة'),
            Tab(text: 'مكونات غير مكتملة'),
            Tab(text: 'أقسام المنيو'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: () {
              if (_tabController.index == 4) {
                _loadMenuSections();
              } else {
                orderProvider.loadCatalog();
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: 'إضافة جديدة',
            onSelected: (val) {
              if (val == 'product') _showAddProductSheet();
              if (val == 'section') _showAddMenuSectionSheet();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'product',
                child: Row(
                  children: [
                    Icon(Icons.add_box_rounded, color: AppColors.primary, size: 20),
                    SizedBox(width: 10),
                    Text('إضافة صنف جديد', style: TextStyle(fontFamily: 'Cairo')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'section',
                child: Row(
                  children: [
                    Icon(Icons.category_rounded, color: AppColors.accent, size: 20),
                    SizedBox(width: 10),
                    Text('إضافة قسم منيو', style: TextStyle(fontFamily: 'Cairo')),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart_rounded),
        label: const Text('طلب بهذه الأصناف', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
          );
        },
      ),
      body: _tabController.index == 4
          ? _buildMenuSectionsTab()
          : Column(
              children: [
                // Search Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'ابحث في الأصناف والتصنيفات...',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                orderProvider.setSearchQuery('');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onChanged: (val) => orderProvider.setSearchQuery(val),
                  ),
                ),

                // Categories Chips (only on All Tab)
                if (_tabController.index == 0)
                  SizedBox(
                    height: 44,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: orderProvider.categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (ctx, i) {
                        final cat = orderProvider.categories[i];
                        final isSelected = cat == orderProvider.selectedCategory;
                        return ChoiceChip(
                          label: Text(
                            cat,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: AppColors.primary,
                          backgroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: isSelected ? AppColors.primary : AppColors.border),
                          ),
                          onSelected: (_) => orderProvider.setCategory(cat),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 8),

                // Count Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'إجمالي النتائج: ${currentProducts.length}',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),

                // Products List
                Expanded(
                  child: orderProvider.isLoadingCatalog
                      ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                      : currentProducts.isEmpty
                          ? const Center(child: AppEmptyView(title: 'لا توجد أصناف مطابقة'))
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                              itemCount: currentProducts.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final product = currentProducts[i];
                                return _buildProductCard(context, product);
                              },
                            ),
                ),
              ],
            ),
    );
  }

  Widget _buildMenuSectionsTab() {
    if (_isLoadingSections) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_menuSections.isEmpty) {
      return AppEmptyView(
        title: 'لا توجد أقسام منيو حالياً',
        actionLabel: 'إضافة قسم جديد',
        onAction: _showAddMenuSectionSheet,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _menuSections.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) {
        final sec = _menuSections[i] as Map<String, dynamic>;
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
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.category_rounded, color: AppColors.accent, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sec['name'] ?? '',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    if (sec['code'] != null && sec['code'].toString().isNotEmpty)
                      Text(
                        'كود: ${sec['code']}',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              if (sec['products_count'] != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${sec['products_count']} أصناف',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductCard(BuildContext context, ProductModel product) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        product.category,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'الوحدة: ${product.unit}',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (product.price > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${product.price % 1 == 0 ? product.price.toInt() : product.price.toStringAsFixed(2)} ج.م',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  product.isSold ? 'سعر البيع' : 'سعر استرشادي',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textMuted),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
