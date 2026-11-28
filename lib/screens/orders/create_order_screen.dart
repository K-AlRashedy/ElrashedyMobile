import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/fast_quantity_dial_sheet.dart';
import '../../widgets/product_avatar.dart';

class CreateOrderScreen extends StatefulWidget {
  final String initialType; // 'order' or 'transfer'

  const CreateOrderScreen({super.key, this.initialType = 'order'});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _searchController = TextEditingController();
  final _noteController = TextEditingController();
  final _searchFocusNode = FocusNode();
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final orderProvider = context.read<OrderProvider>();
      _noteController.text = orderProvider.generalNote;
      orderProvider.setOrderType(widget.initialType);
      orderProvider.loadBootstrapBranches();
      orderProvider.loadCatalog(refresh: true);
      orderProvider.loadTopProducts();
    });

    _searchController.addListener(() {
      final q = _searchController.text.trim();
      setState(() => _showSearchResults = q.isNotEmpty);
      context.read<OrderProvider>().setSearchQuery(q);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _noteController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _showBranchSelector(BuildContext context, bool isFrom) {
    final orderProvider = context.read<OrderProvider>();
    final auth = context.read<AuthProvider>();
    final isTransfer = orderProvider.orderType == 'transfer';

    final branches = isFrom
        ? (auth.userBranches.isNotEmpty ? auth.userBranches : orderProvider.allDestinationBranches)
        : orderProvider.allDestinationBranches;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          maxChildSize: 0.85,
          minChildSize: 0.35,
          builder: (_, scrollCtrl) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              child: Column(
                children: [
                  Container(
                    width: 42,
                    height: 4.5,
                    decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(4)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Icon(isFrom ? Icons.store_rounded : Icons.apartment_rounded, color: AppColors.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isFrom
                              ? (isTransfer ? 'تحديد فرع الصرف (المصدر)' : 'تحديد الفرع الطالب (المستلم)')
                              : (isTransfer ? 'تحديد فرع الاستلام (الوجهة)' : 'تحديد فرع الصرف (المصدر)'),
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollCtrl,
                      itemCount: branches.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final b = branches[i];
                        final isSelected = isFrom
                            ? b.id == orderProvider.selectedFromBranch?.id
                            : b.id == orderProvider.selectedToBranch?.id;
                        final isSameAsOther = isFrom
                            ? b.id == orderProvider.selectedToBranch?.id
                            : b.id == orderProvider.selectedFromBranch?.id;

                        return ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          tileColor: isSelected ? AppColors.primarySoft : null,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary : AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              b.type == 'FACTORY' ? Icons.factory_rounded : Icons.store_rounded,
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            b.name,
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                              color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            isSameAsOther
                                ? 'محدد حالياً كفرع مقابل'
                                : (b.type == 'FACTORY' ? 'مصنع / إدارة مركزية' : 'فرع مبيعات / تشغيل'),
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 11.5,
                              color: isSameAsOther ? AppColors.warning : AppColors.textMuted,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                              : null,
                          onTap: () {
                            if (isSameAsOther) {
                              AppFeedback.showError(ctx, 'يجب أن يختلف الفرع الطالب عن الفرع المصدر.');
                              return;
                            }
                            if (isFrom) {
                              orderProvider.setBranches(from: b);
                            } else {
                              orderProvider.setBranches(to: b);
                            }
                            Navigator.of(ctx).pop();
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCatalogBrowserSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.82,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, scrollCtrl) {
            return Consumer<OrderProvider>(
              builder: (_, provider, __) {
                final categories = provider.categories;
                final products = provider.filteredProducts;

                return Column(
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      width: 42,
                      height: 4.5,
                      decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(4)),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Icon(Icons.category_rounded, color: AppColors.primary),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'كتالوج الأصناف والخامات',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Text(
                            '${products.length} صنف',
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 42,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (_, i) {
                          final cat = categories[i];
                          final isSelected = cat == provider.selectedCategory;
                          return ChoiceChip(
                            label: Text(cat, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            backgroundColor: AppColors.surfaceMuted,
                            onSelected: (_) => provider.setCategory(cat),
                          );
                        },
                      ),
                    ),
                    const Divider(height: 14),
                    Expanded(
                      child: NotificationListener<ScrollNotification>(
                        onNotification: (info) {
                          if (info.metrics.extentAfter < 300 && provider.catalogHasNext && !provider.isLoadingMoreCatalog) {
                            provider.loadMoreCatalog();
                          }
                          return false;
                        },
                        child: ListView.separated(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: products.length + (provider.catalogHasNext ? 1 : 0),
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            if (i >= products.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: provider.isLoadingMoreCatalog
                                      ? const CircularProgressIndicator(color: AppColors.primary)
                                      : OutlinedButton(
                                          onPressed: provider.loadMoreCatalog,
                                          child: const Text('تحميل المزيد من الأصناف'),
                                        ),
                                ),
                              );
                            }
                            final p = products[i];
                            final inCartQty = provider.getQuantityForProduct(p.id);

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: inCartQty > 0 ? AppColors.primary : AppColors.border,
                                  width: inCartQty > 0 ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  ProductAvatar(product: p, size: 40),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.name,
                                          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14),
                                        ),
                                        const SizedBox(height: 3),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryLight,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                p.unit,
                                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                                              ),
                                            ),
                                            Text(
                                              p.category,
                                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: inCartQty > 0 ? AppColors.accentAmber : AppColors.primary,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(82, 42),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    ),
                                    icon: Icon(inCartQty > 0 ? Icons.add_circle_outline : Icons.add, size: 16),
                                    label: Text(
                                      inCartQty > 0 ? '+1 (${AppNumericKeypadSheetSafe.format(inCartQty)})' : 'إضافة',
                                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      provider.addOrIncrement(p);
                                    },
                                  ),
                                ],
                              ),
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
  }

  Future<void> _confirmClearAll(BuildContext context) async {
    final ok = await AppConfirmDialog.show(
      context,
      title: 'مسح جميع الأصناف؟',
      message: 'هل تريد بالتأكيد إفراغ سلة الطلب الحالية والبدء من جديد؟',
      confirmLabel: 'مسح الكل',
      isDestructive: true,
    );
    if (ok && context.mounted) {
      context.read<OrderProvider>().clearCart();
      _noteController.clear();
    }
  }

  Future<void> _handleOrderSubmission(BuildContext context) async {
    final provider = context.read<OrderProvider>();
    if (provider.cartCount == 0) {
      AppFeedback.showError(context, 'عفواً، لا يمكن إرسال طلب فارغ. يرجى إضافة أصناف أولاً.');
      return;
    }

    provider.setGeneralNote(_noteController.text.trim());
    final success = await provider.submitOrder();
    if (!mounted) return;

    if (success) {
      _noteController.clear();
      HapticFeedback.heavyImpact();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 42),
              ),
              const SizedBox(height: 16),
              const Text(
                'تم رفع الطلب بنجاح!',
                style: TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'تم تسجيل الطلب في نظام الرشيدي ERP وهو جاهز للمراجعة والصرف.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).pop();
                  },
                  child: const Text('العودة للرئيسية'),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      AppFeedback.showError(context, provider.errorMessage ?? 'فشل رفع الطلب');
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final cartItems = orderProvider.cartItems;
    final topProducts = orderProvider.topProducts;
    final isTransfer = orderProvider.orderType == 'transfer';
    final fromBranch = orderProvider.selectedFromBranch;
    final toBranch = orderProvider.selectedToBranch;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isTransfer ? 'أمر تحويل بضاعة' : 'طلب صرف بضاعة',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'تغيير نوع العملية',
            initialValue: orderProvider.orderType,
            onSelected: (val) => orderProvider.setOrderType(val),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'order', child: Text('طلب صرف بضاعة', style: TextStyle(fontFamily: 'Cairo'))),
              PopupMenuItem(value: 'transfer', child: Text('أمر تحويل بضاعة', style: TextStyle(fontFamily: 'Cairo'))),
            ],
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isTransfer ? 'تحويل' : 'طلب صرف',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                  ),
                  const Icon(Icons.arrow_drop_down, color: AppColors.primaryDark, size: 18),
                ],
              ),
            ),
          ),
          if (cartItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.danger),
              tooltip: 'مسح كل الأصناف',
              onPressed: () => _confirmClearAll(context),
            ),
          IconButton(
            icon: const Icon(Icons.menu_book_rounded),
            tooltip: 'تصفح الكتالوج الكامل',
            onPressed: () => _showCatalogBrowserSheet(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Dual Branch Direction Card
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _showBranchSelector(context, true),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.storefront_rounded, size: 13, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  isTransfer ? 'فرع الصرف:' : 'الفرع الطالب:',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 10.5, color: AppColors.textSecondary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            fromBranch?.name ?? 'اختر الفرع...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                    child: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _showBranchSelector(context, false),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.apartment_rounded, size: 13, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  isTransfer ? 'فرع الاستلام:' : 'فرع الصرف:',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 10.5, color: AppColors.primary),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            toBranch?.name ?? 'اختر الوجهة...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Smart Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'ابحث عن صنف لإضافته للطلب...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _searchFocusNode.unfocus();
                        },
                      )
                    : null,
              ),
            ),
          ),

          // 3. Quick Top Products Chips
          if (!_showSearchResults && topProducts.isNotEmpty)
            Container(
              height: 48,
              margin: const EdgeInsets.only(top: 4, bottom: 4),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: topProducts.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  if (i == topProducts.length) {
                    return ActionChip(
                      backgroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.primary),
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.menu_book_rounded, size: 15, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text('كل الأصناف', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ],
                      ),
                      onPressed: () => _showCatalogBrowserSheet(context),
                    );
                  }
                  final prod = topProducts[i];
                  final inCart = orderProvider.getQuantityForProduct(prod.id) > 0;

                  return ActionChip(
                    backgroundColor: inCart ? AppColors.primaryLight : Colors.white,
                    side: BorderSide(color: inCart ? AppColors.primary : AppColors.border, width: inCart ? 1.5 : 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    avatar: ProductAvatar(product: prod, size: 24),
                    label: Text(
                      prod.name,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: inCart ? FontWeight.bold : FontWeight.w600,
                        color: inCart ? AppColors.primaryDark : AppColors.textPrimary,
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      orderProvider.addOrIncrement(prod);
                    },
                  );
                },
              ),
            ),

          // 4. Live Search Results OR Order Items List
          Expanded(
            child: _showSearchResults
                ? _buildLiveSearchResults(context, orderProvider)
                : _buildOrderItemsList(context, orderProvider, cartItems),
          ),

          // 5. Sticky Bottom Summary Bar
          _buildBottomSummaryBar(context, orderProvider),
        ],
      ),
    );
  }

  Widget _buildLiveSearchResults(BuildContext context, OrderProvider provider) {
    final results = provider.filteredProducts;

    if (provider.isLoadingCatalog && results.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 12),
              Text(
                'لا توجد أصناف مطابقة لـ "${_searchController.text}"',
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: NotificationListener<ScrollNotification>(
        onNotification: (info) {
          if (info.metrics.extentAfter < 250 && provider.catalogHasNext && !provider.isLoadingMoreCatalog) {
            provider.loadMoreCatalog();
          }
          return false;
        },
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: results.length + (provider.catalogHasNext ? 1 : 0),
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            if (i >= results.length) {
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Center(
                  child: provider.isLoadingMoreCatalog
                      ? const CircularProgressIndicator(color: AppColors.primary)
                      : TextButton(onPressed: provider.loadMoreCatalog, child: const Text('تحميل المزيد')),
                ),
              );
            }
            final prod = results[i];
            final inCartQty = provider.getQuantityForProduct(prod.id);

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: ProductAvatar(product: prod, size: 38),
              title: Text(prod.name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
              subtitle: Wrap(
                spacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(6)),
                    child: Text(prod.unit, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                  ),
                  Text(prod.category, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
              trailing: inCartQty > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(10)),
                      child: Text(
                        '+1 (${AppNumericKeypadSheetSafe.format(inCartQty)})',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    )
                  : const Icon(Icons.add_circle_rounded, color: AppColors.primary, size: 28),
              onTap: () {
                HapticFeedback.lightImpact();
                provider.addOrIncrement(prod);
                _searchController.clear();
                _searchFocusNode.unfocus();
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildOrderItemsList(BuildContext context, OrderProvider provider, List<CartItem> items) {
    if (items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                child: const Icon(Icons.shopping_basket_outlined, size: 42, color: AppColors.primary),
              ),
              const SizedBox(height: 14),
              const Text('الطلب فارغ حالياً', style: TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text(
                'اضغط على الأصناف السريعة بالأعلى أو ابحث بالاسم لإضافتها مباشرة للطلب.',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                icon: const Icon(Icons.menu_book_rounded, size: 18),
                label: const Text('تصفح كتالوج الأصناف الكامل'),
                onPressed: () => _showCatalogBrowserSheet(context),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: items.length + 1,
      itemBuilder: (ctx, i) {
        if (i == items.length) {
          return Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'ملاحظة عامة على الطلب (اختياري)',
                prefixIcon: Icon(Icons.note_alt_outlined, color: AppColors.primary, size: 20),
                isDense: true,
              ),
              onChanged: (v) => provider.setGeneralNote(v),
            ),
          );
        }

        final item = items[i];
        final p = item.product;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ProductAvatar(product: p, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14.5)),
                        const SizedBox(height: 3),
                        Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(6)),
                              child: Text(p.unit, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                            ),
                            Text(p.category, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 22),
                    tooltip: 'حذف الصنف',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      provider.removeItem(p.id);
                    },
                  ),
                ],
              ),
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الكمية:', style: TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                provider.decrementOrRemove(p.id, 1.0);
                              },
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Icon(Icons.remove_rounded, size: 20),
                              ),
                            ),
                            InkWell(
                              onTap: () async {
                                final result = await FastQuantityDialSheet.show(
                                  context,
                                  title: p.name,
                                  unit: p.unit,
                                  initialValue: item.quantity,
                                );
                                if (result != null && mounted) {
                                  provider.setQuantity(p.id, result);
                                }
                              },
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 58),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  border: Border.symmetric(vertical: BorderSide(color: AppColors.border)),
                                ),
                                alignment: Alignment.center,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      AppNumericKeypadSheetSafe.format(item.quantity),
                                      textDirection: TextDirection.ltr,
                                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.primary),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.dialpad_rounded, size: 13, color: AppColors.textMuted),
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                provider.addOrIncrement(p, 1.0);
                              },
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                child: Icon(Icons.add_rounded, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          provider.addOrIncrement(p, 5.0);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                          ),
                          child: const Text('+5', style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: ValueKey('note_${p.id}'),
                initialValue: item.note,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
                decoration: const InputDecoration(
                  hintText: 'ملاحظة على هذا الصنف (اختياري)...',
                  prefixIcon: Icon(Icons.edit_note_rounded, size: 18),
                  isDense: true,
                ),
                onChanged: (val) => provider.setItemNote(p.id, val),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomSummaryBar(BuildContext context, OrderProvider provider) {
    final count = provider.cartCount;
    final totalQty = provider.totalQuantity;
    final isSubmitting = provider.isSubmitting;
    final toBranchName = provider.selectedToBranch?.name ?? 'غير محدد';
    final isTransfer = provider.orderType == 'transfer';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -3))],
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(isTransfer ? 'الجهة المستلمة' : 'الجهة الصارفة', style: const TextStyle(fontFamily: 'Cairo', fontSize: 10.5, color: AppColors.textSecondary)),
                      Text(toBranchName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: AppColors.border),
                Expanded(
                  child: Column(
                    children: [
                      const Text('الأصناف', style: TextStyle(fontFamily: 'Cairo', fontSize: 10.5, color: AppColors.textSecondary)),
                      Text('$count صنف', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: AppColors.border),
                Expanded(
                  child: Column(
                    children: [
                      const Text('إجمالي الكمية', style: TextStyle(fontFamily: 'Cairo', fontSize: 10.5, color: AppColors.textSecondary)),
                      Text(AppNumericKeypadSheetSafe.format(totalQty), style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.primary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: count > 0 ? AppColors.primary : AppColors.surfaceMuted,
                  foregroundColor: count > 0 ? Colors.white : AppColors.textMuted,
                ),
                onPressed: isSubmitting || count == 0 ? null : () => _handleOrderSubmission(context),
                icon: isSubmitting
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Icon(isTransfer ? Icons.swap_horiz_rounded : Icons.send_rounded, size: 20),
                label: Text(
                  isSubmitting
                      ? 'جاري الإرسال...'
                      : (isTransfer ? 'إرسال وتأكيد أمر التحويل' : 'إرسال طلب الصرف إلى الـ ERP'),
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppNumericKeypadSheetSafe {
  static String format(double v) => v.truncateToDouble() == v
      ? v.toInt().toString()
      : v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
}
