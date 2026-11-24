import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../models/order_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
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
  final _searchFocusNode = FocusNode();
  bool _showSearchResults = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orderProvider = context.read<OrderProvider>();
      orderProvider.setOrderType(widget.initialType);
      orderProvider.loadBootstrapBranches();
      orderProvider.loadCatalog();
      orderProvider.loadTopProducts();
    });

    _searchController.addListener(() {
      final q = _searchController.text.trim();
      setState(() {
        _showSearchResults = q.isNotEmpty;
      });
      context.read<OrderProvider>().setSearchQuery(q);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        isFrom ? Icons.store_rounded : Icons.apartment_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isFrom
                            ? (isTransfer ? 'تحديد فرع الصرف (المصدر)' : 'تحديد الفرع الطالب (المستلم)')
                            : (isTransfer ? 'تحديد فرع الاستلام (الوجهة)' : 'تحديد فرع الصرف (المصدر)'),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollCtrl,
                      itemCount: branches.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (_, i) {
                        final b = branches[i];
                        final isSelected = isFrom
                            ? b.id == orderProvider.selectedFromBranch?.id
                            : b.id == orderProvider.selectedToBranch?.id;

                        return ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          tileColor: isSelected ? AppColors.primary.withOpacity(0.08) : null,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            b.type == 'FACTORY' ? 'مصنع / إدارة مركزية' : 'فرع مبيعات / تشغيل',
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22)
                              : null,
                          onTap: () {
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
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
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Icon(Icons.category_rounded, color: AppColors.primary),
                          const SizedBox(width: 8),
                          const Text(
                            'كتالوج الأصناف والخامات',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${products.length} صنف',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Categories horizontal
                    SizedBox(
                      height: 40,
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
                    const Divider(height: 16),
                    Expanded(
                      child: ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: products.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final p = products[i];
                          final inCartQty = provider.getQuantityForProduct(p.id);

                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: inCartQty > 0 ? AppColors.primary.withOpacity(0.5) : AppColors.border,
                              ),
                            ),
                            child: Row(
                              children: [
                                ProductAvatar(product: p, size: 38),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name,
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryLight,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              p.unit,
                                              style: const TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppColors.primaryDark,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            p.category,
                                            style: const TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 11,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: inCartQty > 0 ? AppColors.accent : AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: Icon(inCartQty > 0 ? Icons.add_circle_outline : Icons.add, size: 16),
                                  label: Text(
                                    inCartQty > 0 ? 'مضاف (${inCartQty.toStringAsFixed(inCartQty.truncateToDouble() == inCartQty ? 0 : 2)})' : 'إضافة',
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
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _confirmClearAll(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('مسح جميع الأصناف؟', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: const Text(
          'هل تريد بالتأكيد إفراغ سلة الطلب الحالية والبدء من جديد؟',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              context.read<OrderProvider>().clearCart();
              Navigator.of(ctx).pop();
            },
            child: const Text('مسح الكل', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleOrderSubmission(BuildContext context) async {
    final provider = context.read<OrderProvider>();
    if (provider.cartCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('عفواً، لا يمكن إرسال طلب فارغ. يرجى إضافة أصناف أولاً.', style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final success = await provider.submitOrder();
    if (!mounted) return;

    if (success) {
      HapticFeedback.heavyImpact();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 40),
              ),
              const SizedBox(height: 16),
              const Text(
                'تم رفع الطلب بنجاح!',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
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
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop(); // pop dialog
                    Navigator.of(context).pop(); // return to dashboard
                  },
                  child: const Text('العودة للرئيسية', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'فشل رفع الطلب', style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: AppColors.danger,
        ),
      );
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
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: Text(
          isTransfer ? 'أمر تحويل بضاعة' : 'طلب صرف بضاعة',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          // Mode switch dropdown
          PopupMenuButton<String>(
            tooltip: 'تغيير نوع العملية',
            initialValue: orderProvider.orderType,
            onSelected: (val) => orderProvider.setOrderType(val),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'order',
                child: Text('طلب صرف بضاعة', style: TextStyle(fontFamily: 'Cairo')),
              ),
              PopupMenuItem(
                value: 'transfer',
                child: Text('أمر تحويل بضاعة', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Text(
                    isTransfer ? 'تحويل' : 'طلب صرف',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
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
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // From Branch
                Expanded(
                  child: InkWell(
                    onTap: () => _showBranchSelector(context, true),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.storefront_rounded, size: 13, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                isTransfer ? 'فرع الصرف (المصدر):' : 'الفرع الطالب (المستلم):',
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            fromBranch?.name ?? 'اختر الفرع...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
                  ),
                ),
                // To Branch
                Expanded(
                  child: InkWell(
                    onTap: () => _showBranchSelector(context, false),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.apartment_rounded, size: 13, color: AppColors.primary),
                              const SizedBox(width: 4),
                              Text(
                                isTransfer ? 'فرع الاستلام (الوجهة):' : 'فرع الصرف (المصدر):',
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            toBranch?.name ?? 'اختر الوجهة...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
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
                hintText: 'ابحث عن صنف بالاسم أو الباركود...',
                hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textMuted),
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
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),
          ),

          // 3. Quick Chips ("الأصناف المعتادة / الأكثر طلباً")
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
                      side: const BorderSide(color: AppColors.primary, width: 1),
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.more_horiz_rounded, size: 16, color: AppColors.primary),
                          SizedBox(width: 4),
                          Text(
                            'المزيد •',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      onPressed: () => _showCatalogBrowserSheet(context),
                    );
                  }

                  final prod = topProducts[i];
                  final inCart = orderProvider.getQuantityForProduct(prod.id) > 0;

                  return ActionChip(
                    backgroundColor: inCart ? AppColors.primary.withOpacity(0.12) : Colors.white,
                    side: BorderSide(
                      color: inCart ? AppColors.primary : AppColors.border,
                      width: inCart ? 1.5 : 1,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                    avatar: ProductAvatar(product: prod, size: 24),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          prod.name,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: inCart ? FontWeight.bold : FontWeight.w600,
                            color: inCart ? AppColors.primary : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      orderProvider.addOrIncrement(prod);
                    },
                  );
                },
              ),
            ),

          // 4. Live Search Dropdown OR Main Order Items List
          Expanded(
            child: _showSearchResults
                ? _buildLiveSearchResults(context, orderProvider)
                : _buildOrderItemsList(context, orderProvider, cartItems),
          ),

          // 5. Sticky Bottom Summary Bar (Matching ERP 3-box Summary)
          _buildBottomSummaryBar(context, orderProvider),
        ],
      ),
    );
  }

  Widget _buildLiveSearchResults(BuildContext context, OrderProvider provider) {
    final results = provider.filteredProducts;

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
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: results.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
        itemBuilder: (_, i) {
          final prod = results[i];
          final inCartQty = provider.getQuantityForProduct(prod.id);

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: ProductAvatar(product: prod, size: 34),
            title: Text(
              prod.name,
              style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold),
            ),
            subtitle: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    prod.unit,
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  prod.category,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
            trailing: inCartQty > 0
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '+1 (${inCartQty.toStringAsFixed(inCartQty.truncateToDouble() == inCartQty ? 0 : 2)})',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  )
                : const Icon(Icons.add_circle_rounded, color: AppColors.primary, size: 28),
            onTap: () {
              HapticFeedback.lightImpact();
              provider.addOrIncrement(prod);
              // Clear search and return to order list
              _searchController.clear();
              _searchFocusNode.unfocus();
            },
          );
        },
      ),
    );
  }

  Widget _buildOrderItemsList(
    BuildContext context,
    OrderProvider provider,
    List<CartItem> items,
  ) {
    if (items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shopping_basket_outlined,
                  size: 46,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'الطلب فارغ حالياً',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'اضغط على الكبسولات السريعة بالأعلى 👆\nأو ابحث عن الأصناف لإضافتها مباشرة للطلب.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.menu_book_rounded, color: AppColors.primary, size: 18),
                label: const Text(
                  'تصفح كتالوج الأصناف الكامل',
                  style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                onPressed: () => _showCatalogBrowserSheet(context),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: items.length,
      itemBuilder: (ctx, i) {
        final item = items[i];
        final p = item.product;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.015),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Row 1: Avatar + Name + Unit Badge + Delete
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ProductAvatar(product: p, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F4EA),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                p.unit,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF137333),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              p.category,
                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Delete Button
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 22),
                    tooltip: 'حذف من الطلب',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      provider.removeItem(p.id);
                    },
                  ),
                ],
              ),
              const Divider(height: 20, color: AppColors.border),
              // Row 2: Quantity Stepper with Direct Decimal Input
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'الكمية المطلوبة:',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Stepper Container
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Minus button
                            InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                provider.decrementOrRemove(p.id, 1.0);
                              },
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(12)),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                child: Icon(Icons.remove_rounded, size: 20, color: AppColors.textPrimary),
                              ),
                            ),
                            // Number button that opens in-app instant dialpad (no keyboard lag!)
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
                                constraints: const BoxConstraints(minWidth: 55),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                alignment: Alignment.center,
                                child: Text(
                                  item.quantity.toStringAsFixed(
                                    item.quantity.truncateToDouble() == item.quantity ? 0 : 2,
                                  ).replaceFirst(RegExp(r'\.?0+$'), ''),
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            // Plus button
                            InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                provider.addOrIncrement(p, 1.0);
                              },
                              borderRadius: const BorderRadius.horizontal(left: Radius.circular(12)),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                child: Icon(Icons.add_rounded, size: 20, color: AppColors.textPrimary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Quick +5 button for rapid bulk entry
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          provider.addOrIncrement(p, 5.0);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: const Text(
                            '+5',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Row 3: Item Note field
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border.withOpacity(0.6)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit_note_rounded, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('note_${p.id}'),
                        initialValue: item.note,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textPrimary),
                        decoration: const InputDecoration(
                          hintText: 'ملاحظة على هذا الصنف (اختياري)...',
                          hintStyle: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                        onChanged: (val) => provider.setItemNote(p.id, val),
                      ),
                    ),
                  ],
                ),
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 3-Box Stats Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        isTransfer ? 'الجهة المستلمة' : 'الجهة الصارفة',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textSecondary),
                      ),
                      Text(
                        toBranchName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: AppColors.border),
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'إجمالي الأصناف',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textSecondary),
                      ),
                      Text(
                        '$count صنف',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: AppColors.border),
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'إجمالي الكمية',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textSecondary),
                      ),
                      Text(
                        totalQty.toStringAsFixed(totalQty.truncateToDouble() == totalQty ? 0 : 2),
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Primary Submit Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: count > 0 ? AppColors.primary : AppColors.surfaceMuted,
                  foregroundColor: count > 0 ? Colors.white : AppColors.textMuted,
                  elevation: count > 0 ? 3 : 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: isSubmitting || count == 0 ? null : () => _handleOrderSubmission(context),
                child: isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isTransfer ? Icons.swap_horiz_rounded : Icons.send_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            isTransfer ? 'إرسال وتأكيد أمر التحويل' : 'إرسال طلب الصرف إلى الـ ERP',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
