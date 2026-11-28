import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../models/product_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/async_views.dart';
import '../../widgets/numeric_keypad_sheet.dart';
import '../../widgets/product_avatar.dart';

class ProductsCatalogScreen extends StatefulWidget {
  final int initialTab;
  final String? initialAction; // 'add_product' | 'add_section' | 'export' | 'import'

  const ProductsCatalogScreen({
    super.key,
    this.initialTab = 0,
    this.initialAction,
  });

  @override
  State<ProductsCatalogScreen> createState() => _ProductsCatalogScreenState();
}

class _ProductsCatalogScreenState extends State<ProductsCatalogScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late TabController _tabController;
  Timer? _debounce;
  ApiCancelToken? _loadToken;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  String? _error;

  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _allParentCandidates = [];
  List<Map<String, dynamic>> _units = [];
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _menuSections = [];
  bool _isLoadingSections = true;
  String? _sectionsError;
  String? _lookupsError;

  int? _selectedStoreId;
  bool _includeArchived = false;
  bool _initialized = false;

  ApiClient get _api => context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    final safeTab = widget.initialTab.clamp(0, 4);
    _tabController =
        TabController(length: 5, vsync: this, initialIndex: safeTab);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        setState(() {});
        if (_tabController.index == 4) {
          _loadMenuSections();
        } else {
          _loadProducts(reset: true);
        }
      }
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 250 &&
          !_isLoadingMore &&
          !_isLoading &&
          _hasMore &&
          _tabController.index != 4) {
        _loadProducts(reset: false);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadLookups();
        if (_tabController.index == 4) {
          _loadMenuSections();
        } else {
          _loadProducts(reset: true);
        }

        if (widget.initialAction == 'add_product') {
          _showProductFormSheet();
        } else if (widget.initialAction == 'add_section') {
          _showMenuSectionFormSheet();
        } else if (widget.initialAction == 'export' ||
            widget.initialAction == 'import') {
          _showBatchExportImportSheet(
            initialImport: widget.initialAction == 'import',
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _loadToken?.cancel();
    _tabController.dispose();
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _extractList(dynamic res) {
    if (res is Map<String, dynamic>) {
      final list = res['results'] as List<dynamic>? ??
          res['menu_sections'] as List<dynamic>? ??
          res['products'] as List<dynamic>? ??
          [];
      return list.whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  Future<void> _loadLookups() async {
    try {
      final results = await Future.wait([
        _api.get('/api/v1/catalog/units/', queryParams: {'page_size': '100'}),
        _api.get('/api/v1/catalog/stores/', queryParams: {'page_size': '100'}),
        _api.get(
          '/api/v1/catalog/menu-sections/',
          queryParams: {'page_size': '100'},
        ),
        _api.get(
          '/api/v1/catalog/products/',
          queryParams: {'page_size': '100', 'page': '1'},
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _units = _extractList(results[0]);
        _stores = _extractList(results[1]);
        _menuSections = _extractList(results[2]);
        _allParentCandidates = _extractList(results[3]);
        _isLoadingSections = false;
        _lookupsError = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSections = false;
          _lookupsError = e.toString();
        });
      }
    }
  }

  Future<void> _loadMenuSections() async {
    setState(() {
      _isLoadingSections = true;
      _sectionsError = null;
    });
    try {
      final res = await _api.get(
        '/api/v1/catalog/menu-sections/',
        queryParams: {'page_size': '100'},
      );
      if (!mounted) return;
      setState(() {
        _menuSections = _extractList(res);
        _isLoadingSections = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingSections = false;
          _sectionsError = e.toString();
        });
      }
    }
  }

  Future<void> _loadProducts({bool reset = true}) async {
    _loadToken?.cancel();
    final token = ApiCancelToken();
    _loadToken = token;

    if (reset) {
      setState(() {
        _isLoading = true;
        _error = null;
        _currentPage = 1;
        _hasMore = true;
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    final nextPage = reset ? 1 : _currentPage + 1;
    final q = _searchCtrl.text.trim();

    final params = <String, dynamic>{
      'page': nextPage.toString(),
      'page_size': '40',
      if (q.isNotEmpty) 'q': q,
      if (_selectedStoreId != null) 'store_id': _selectedStoreId.toString(),
      if (_includeArchived) 'include_archived': 'true',
    };

    try {
      dynamic res;
      if (_tabController.index == 1) {
        params['is_stock'] = 'true';
        res = await _api.get(
          '/api/v1/catalog/products/',
          queryParams: params,
          cancelToken: token,
        );
      } else if (_tabController.index == 2) {
        try {
          res = await _api.get(
            '/api/v1/reports/costs/bom-complete/',
            queryParams: {
              'page': nextPage.toString(),
              'page_size': '40',
              if (q.isNotEmpty) 'q': q,
              if (_selectedStoreId != null)
                'store_id': _selectedStoreId.toString(),
            },
            cancelToken: token,
          );
        } catch (e) {
          if (e is ApiException && e.statusCode == 404) {
            params['is_production'] = 'true';
            res = await _api.get(
              '/api/v1/catalog/products/',
              queryParams: params,
              cancelToken: token,
            );
          } else {
            rethrow;
          }
        }
      } else if (_tabController.index == 3) {
        try {
          res = await _api.get(
            '/api/v1/reports/costs/bom-incomplete/',
            queryParams: {
              'page': nextPage.toString(),
              'page_size': '40',
              if (q.isNotEmpty) 'q': q,
              if (_selectedStoreId != null)
                'store_id': _selectedStoreId.toString(),
            },
            cancelToken: token,
          );
        } catch (e) {
          if (e is ApiException && e.statusCode == 404) {
            params['is_production'] = 'true';
            res = await _api.get(
              '/api/v1/catalog/products/',
              queryParams: params,
              cancelToken: token,
            );
          } else {
            rethrow;
          }
        }
      } else {
        res = await _api.get(
          '/api/v1/catalog/products/',
          queryParams: params,
          cancelToken: token,
        );
      }

      if (token.isCancelled || !mounted) return;
      var items = _extractList(res);
      if (q.isNotEmpty &&
          (_tabController.index == 2 || _tabController.index == 3)) {
        final lowQ = q.toLowerCase();
        items = items
            .where((p) => (p['name']?.toString() ?? '').toLowerCase().contains(lowQ))
            .toList();
      }
      if (_selectedStoreId != null &&
          (_tabController.index == 2 || _tabController.index == 3)) {
        items = items.where((p) {
          final sid = p['store_id'] as int?;
          return sid == null || sid == _selectedStoreId;
        }).toList();
      }

      final totalPages =
          (res is Map ? (res['total_pages'] as num?)?.toInt() : null) ?? 1;
      final hasMoreFromServer = res is Map && res.containsKey('next')
          ? res['next'] != null
          : nextPage < totalPages;

      setState(() {
        if (reset) {
          _products = items;
        } else {
          _products = [..._products, ...items];
        }
        _currentPage = nextPage;
        _hasMore = hasMoreFromServer;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (token.isCancelled || !mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _syncOrderCatalog() async {
    try {
      await context.read<OrderProvider>().loadCatalog(refresh: true);
    } catch (_) {}
  }

  Future<void> _showProductFormSheet({Map<String, dynamic>? existing}) async {
    if (_units.isEmpty || _stores.isEmpty) {
      await _loadLookups();
      if (!mounted) return;
    }
    final isSuperuser = context.read<AuthProvider>().user?.isSuperuser == true;
    final parentMap = <int, Map<String, dynamic>>{};
    for (final p in _allParentCandidates) {
      final id = p['id'] as int?;
      if (id != null) parentMap[id] = p;
    }
    for (final p in _products) {
      final id = p['id'] as int?;
      if (id != null) parentMap[id] = p;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ProductFormSheet(
        api: _api,
        isSuperuser: isSuperuser,
        units: _units,
        stores: _stores,
        menuSections: _menuSections,
        parentCandidates: parentMap.values.toList(),
        existing: existing,
      ),
    );
    if (saved == true && mounted) {
      AppFeedback.showSuccess(
        context,
        existing != null
            ? 'تم تعديل الصنف بنجاح'
            : 'تم إضافة الصنف إلى الدليل بنجاح',
      );
      _syncOrderCatalog();
      _loadLookups();
      _loadProducts(reset: true);
    }
  }

  Future<void> _showProductDetailAndBomSheet(
    Map<String, dynamic> summaryItem,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ProductDetailBomSheet(
        api: _api,
        summaryItem: summaryItem,
        onEditProduct: (detail) => _showProductFormSheet(existing: detail),
        onCatalogMutated: () {
          _syncOrderCatalog();
          _loadProducts(reset: true);
        },
      ),
    );
  }

  Future<void> _showMenuSectionFormSheet({Map<String, dynamic>? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MenuSectionFormSheet(api: _api, existing: existing),
    );
    if (saved == true && mounted) {
      AppFeedback.showSuccess(
        context,
        existing != null ? 'تم تعديل القسم بنجاح' : 'تم إضافة القسم بنجاح',
      );
      _loadMenuSections();
      _syncOrderCatalog();
    }
  }

  Future<void> _deleteMenuSection(Map<String, dynamic> sec) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'حذف قسم المنيو',
      message: 'هل تريد حذف قسم "${sec['name']}"؟',
      confirmLabel: 'حذف',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await _api.delete('/api/v1/catalog/menu-sections/${sec['id']}/delete/');
      if (!mounted) return;
      AppFeedback.showSuccess(context, 'تم حذف القسم بنجاح');
      _loadMenuSections();
      _syncOrderCatalog();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, e.toString());
    }
  }

  Future<void> _showBatchExportImportSheet({bool initialImport = false}) async {
    final imported = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _BatchExportImportSheet(
        api: _api,
        initialImport: initialImport,
      ),
    );
    if (imported == true && mounted) {
      _syncOrderCatalog();
      _loadProducts(reset: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSectionsTab = _tabController.index == 4;
    final showStoreFilter =
        _stores.isNotEmpty && (_tabController.index == 0 || _tabController.index == 1);
    final showArchivedChip = _tabController.index == 0 || _tabController.index == 1;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'دليل الأصناف والمنيو والـ BOM',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'تصدير / تحديث جماعي',
            icon: const Icon(Icons.import_export_rounded),
            onPressed: () => _showBatchExportImportSheet(),
          ),
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => isSectionsTab
                ? _loadMenuSections()
                : _loadProducts(reset: true),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'جميع الأصناف'),
            Tab(text: 'المواد الخام'),
            Tab(text: 'مكونات مكتملة'),
            Tab(text: 'مكونات غير مكتملة'),
            Tab(text: 'أقسام المنيو'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: Icon(isSectionsTab ? Icons.category_rounded : Icons.add_box_rounded),
        label: Text(
          isSectionsTab ? 'قسم منيو جديد' : 'صنف جديد',
          style: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: () {
          if (isSectionsTab) {
            _showMenuSectionFormSheet();
          } else {
            _showProductFormSheet();
          }
        },
      ),
      body: isSectionsTab
          ? _buildMenuSectionsTab()
          : Column(
              children: [
                if (_lookupsError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: AppInlineError(
                      message: 'بعض القوائم المرجعية لم تكتمل: $_lookupsError',
                    ),
                  ),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Column(
                    children: [
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _searchCtrl,
                        builder: (_, val, __) => TextField(
                          controller: _searchCtrl,
                          onChanged: (_) {
                            _debounce?.cancel();
                            _debounce = Timer(
                              const Duration(milliseconds: 350),
                              () => _loadProducts(reset: true),
                            );
                          },
                          decoration: InputDecoration(
                            hintText: 'ابحث باسم الصنف...',
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: AppColors.primary,
                              size: 22,
                            ),
                            suffixIcon: val.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear_rounded,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      _loadProducts(reset: true);
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                      if (showArchivedChip || showStoreFilter) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              if (showArchivedChip)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: FilterChip(
                                    label: const Text(
                                      'إظهار المؤرشف',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 12,
                                      ),
                                    ),
                                    selected: _includeArchived,
                                    selectedColor: AppColors.accentAmberSoft,
                                    onSelected: (v) {
                                      setState(() => _includeArchived = v);
                                      _loadProducts(reset: true);
                                    },
                                  ),
                                ),
                              if (showStoreFilter) ...[
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: ChoiceChip(
                                    label: Text(
                                      'كل المخازن',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 12,
                                        color: _selectedStoreId == null
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                    selected: _selectedStoreId == null,
                                    selectedColor: AppColors.primary,
                                    onSelected: (_) {
                                      setState(() => _selectedStoreId = null);
                                      _loadProducts(reset: true);
                                    },
                                  ),
                                ),
                                ..._stores.map((s) {
                                  final sid = s['id'] as int;
                                  final sel = _selectedStoreId == sid;
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: ChoiceChip(
                                      label: Text(
                                        s['name']?.toString() ?? '',
                                        style: TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 12,
                                          color: sel
                                              ? Colors.white
                                              : AppColors.textPrimary,
                                        ),
                                      ),
                                      selected: sel,
                                      selectedColor: AppColors.primary,
                                      onSelected: (_) {
                                        setState(() => _selectedStoreId = sid);
                                        _loadProducts(reset: true);
                                      },
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const AppLoadingView(message: 'جاري تحميل الأصناف...')
                      : _error != null
                          ? AppErrorView(
                              message: _error!,
                              onRetry: () => _loadProducts(reset: true),
                            )
                          : _products.isEmpty
                              ? AppEmptyView(
                                  title: 'لا توجد أصناف مطابقة',
                                  message:
                                      'جرّب تغيير البحث أو إضافة صنف جديد',
                                  icon: Icons.inventory_2_outlined,
                                  actionLabel: 'إضافة صنف جديد',
                                  onAction: () => _showProductFormSheet(),
                                )
                              : RefreshIndicator(
                                  onRefresh: () => _loadProducts(reset: true),
                                  color: AppColors.primary,
                                  child: ListView.separated(
                                    controller: _scrollController,
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      12,
                                      16,
                                      96,
                                    ),
                                    itemCount: _products.length +
                                        (_isLoadingMore ? 1 : 0),
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(height: 10),
                                    itemBuilder: (ctx, i) {
                                      if (i >= _products.length) {
                                        return const Padding(
                                          padding: EdgeInsets.all(16),
                                          child: Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        );
                                      }
                                      return _buildProductCard(_products[i]);
                                    },
                                  ),
                                ),
                ),
              ],
            ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> p) {
    final name = p['name']?.toString() ?? 'صنف';
    final isVisible = p['is_visible'] != false;
    final isSold = p['is_sold'] == true;
    final isProduction = p['is_production'] == true;
    final sellingPrice = (p['selling_price'] as num?)?.toDouble() ?? 0;
    final directCost = p['direct_cost']?.toString();
    final price = (p['price'] as num?)?.toDouble() ?? 0;

    final displayAmount = isSold && sellingPrice > 0
        ? '${AppNumericKeypadSheet.formatNumber(sellingPrice)} ج.م'
        : directCost != null
            ? '$directCost ج.م'
            : '${AppNumericKeypadSheet.formatNumber(price)} ج.م';
    final displayLabel = isSold && sellingPrice > 0
        ? 'سعر البيع'
        : directCost != null
            ? 'التكلفة المباشرة'
            : 'السعر';

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _showProductDetailAndBomSheet(p),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isVisible ? AppColors.border : AppColors.error.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            ProductAvatar(
              product: ProductModel.fromJson(p),
              size: 48,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!isVisible)
                        const AppStatusBadge(
                          label: 'مؤرشف/مخفي',
                          color: AppColors.error,
                        ),
                      if (isProduction)
                        const AppStatusBadge(
                          label: 'BOM/إنتاج',
                          color: AppColors.accentPurple,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'مخزن: ${p['store_name'] ?? p['category'] ?? 'عام'} • ${p['unit_formula'] ?? p['unit_name'] ?? ''}',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  displayAmount,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  displayLabel,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 10.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuSectionsTab() {
    if (_isLoadingSections) {
      return const AppLoadingView(message: 'جاري تحميل أقسام المنيو...');
    }
    if (_sectionsError != null) {
      return AppErrorView(
        message: _sectionsError!,
        onRetry: _loadMenuSections,
      );
    }
    if (_menuSections.isEmpty) {
      return AppEmptyView(
        title: 'لا توجد أقسام منيو مسجلة',
        icon: Icons.category_outlined,
        actionLabel: 'إضافة قسم جديد',
        onAction: () => _showMenuSectionFormSheet(),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadMenuSections,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
        itemCount: _menuSections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) {
          final sec = _menuSections[i];
          final isActive = sec['is_active'] != false;
          final count = sec['product_count'] ?? sec['products_count'] ?? 0;
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.category_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            sec['name']?.toString() ?? '',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          AppStatusBadge(
                            label: isActive ? 'نشط' : 'مخفي',
                            color:
                                isActive ? AppColors.success : AppColors.error,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'ترتيب العرض: ${sec['display_order'] ?? 0} • الأصناف المرتبطة: $count',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'تعديل',
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  icon: const Icon(
                    Icons.edit_outlined,
                    color: AppColors.info,
                    size: 20,
                  ),
                  onPressed: () => _showMenuSectionFormSheet(existing: sec),
                ),
                IconButton(
                  tooltip: 'حذف',
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                  onPressed: () => _deleteMenuSection(sec),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProductFormSheet extends StatefulWidget {
  final ApiClient api;
  final bool isSuperuser;
  final List<Map<String, dynamic>> units;
  final List<Map<String, dynamic>> stores;
  final List<Map<String, dynamic>> menuSections;
  final List<Map<String, dynamic>> parentCandidates;
  final Map<String, dynamic>? existing;

  const _ProductFormSheet({
    required this.api,
    required this.isSuperuser,
    required this.units,
    required this.stores,
    required this.menuSections,
    required this.parentCandidates,
    this.existing,
  });

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _sellingPriceCtrl;
  late final TextEditingController _wholesaleCtrl;
  late final TextEditingController _patchCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _costCtrl;

  int? _selectedUnitId;
  int? _selectedStoreId;
  int? _selectedParentId;
  late Set<int> _selectedSections;

  late bool _isVisible;
  late bool _isSold;
  late bool _isStock;
  late bool _isProduction;
  late bool _isComponent;
  late bool _isWholesale;
  late bool _isFactoryProd;
  late bool _isShopProd;
  late bool _isFactoryUsed;
  late bool _isShopUsed;
  late bool _isExchange;
  late bool _isTransformer;
  late bool _isParent;

  bool _isSubmitting = false;
  String? _formError;

  bool get _canEditCost =>
      widget.isSuperuser || widget.existing?['cost'] != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?['name']?.toString() ?? '');
    _priceCtrl = TextEditingController(text: (e?['price'] ?? 0).toString());
    _sellingPriceCtrl =
        TextEditingController(text: (e?['selling_price'] ?? 0).toString());
    _wholesaleCtrl =
        TextEditingController(text: (e?['wholesale_price'] ?? 0).toString());
    _patchCtrl = TextEditingController(text: (e?['patch'] ?? 1).toString());
    _quantityCtrl =
        TextEditingController(text: (e?['quantity'] ?? 1).toString());
    _costCtrl = TextEditingController(text: (e?['cost'] ?? 0).toString());

    _selectedUnitId = e?['unit_id'] as int? ??
        (widget.units.isNotEmpty ? widget.units.first['id'] as int? : null);
    _selectedStoreId = e?['store_id'] as int? ??
        (widget.stores.isNotEmpty ? widget.stores.first['id'] as int? : null);
    _selectedParentId = e?['parent_id'] as int?;
    _selectedSections = <int>{
      ...((e?['menu_sections'] as List<dynamic>? ?? []).map((s) {
        if (s is Map) return s['id'] as int? ?? 0;
        if (s is int) return s;
        return 0;
      }).where((id) => id > 0)),
    };

    _isVisible = e?['is_visible'] != false;
    _isSold = e?['is_sold'] == true;
    _isStock = e?['is_stock'] == true;
    _isProduction = e?['is_production'] == true;
    _isComponent = e?['is_component'] == true;
    _isWholesale = e?['is_wholesale'] == true;
    _isFactoryProd = e?['is_factory_production'] == true;
    _isShopProd = e?['is_shop_production'] == true;
    _isFactoryUsed = e?['is_factory_used'] == true;
    _isShopUsed = e?['is_shop_used'] == true;
    _isExchange = e?['is_exchange'] == true;
    _isTransformer = e?['is_transformer'] == true;
    _isParent = e?['is_parent'] == true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _sellingPriceCtrl.dispose();
    _wholesaleCtrl.dispose();
    _patchCtrl.dispose();
    _quantityCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  double? _parseNumber(
    TextEditingController ctrl,
    String label, {
    double min = 0,
    bool strictMin = false,
  }) {
    final text = ctrl.text.trim();
    if (text.isEmpty) {
      if (min == 0 && !strictMin) return 0;
      setState(() => _formError = 'أدخل قيمة "$label".');
      return null;
    }
    final v = double.tryParse(text);
    if (v == null || (strictMin ? v <= min : v < min)) {
      setState(
        () => _formError = strictMin
            ? 'يجب أن تكون قيمة "$label" أكبر من $min.'
            : 'قيمة "$label" غير صالحة.',
      );
      return null;
    }
    return v;
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _formError = 'أدخل اسم الصنف أولاً.');
      return;
    }
    if (_selectedUnitId == null) {
      setState(() => _formError = 'اختر وحدة القياس.');
      return;
    }
    if (_selectedStoreId == null) {
      setState(() => _formError = 'اختر المخزن الرئيسي.');
      return;
    }

    final patchVal = _parseNumber(_patchCtrl, 'حجم التشغيلة (Patch)', strictMin: true);
    final qtyVal = _parseNumber(_quantityCtrl, 'معامل التحويل', strictMin: true);
    final priceVal = _parseNumber(_priceCtrl, 'سعر الشراء / المباشر');
    final sellingVal = _parseNumber(_sellingPriceCtrl, 'سعر البيع للجمهور');
    final wholesaleVal = _parseNumber(_wholesaleCtrl, 'سعر الجملة');
    final costVal = _canEditCost ? _parseNumber(_costCtrl, 'التكلفة') : 0.0;

    if (patchVal == null ||
        qtyVal == null ||
        priceVal == null ||
        sellingVal == null ||
        wholesaleVal == null ||
        costVal == null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _formError = null;
    });

    final body = <String, dynamic>{
      'name': name,
      'unit_id': _selectedUnitId,
      'store_id': _selectedStoreId,
      'price': priceVal,
      'selling_price': sellingVal,
      'wholesale_price': wholesaleVal,
      'patch': patchVal,
      'quantity': qtyVal,
      if (_canEditCost) 'cost': costVal,
      'menu_sections': _selectedSections.toList(),
      'is_visible': _isVisible,
      'is_sold': _isSold,
      'is_stock': _isStock,
      'is_production': _isProduction,
      'is_component': _isComponent,
      'is_wholesale': _isWholesale,
      'is_factory_production': _isFactoryProd,
      'is_shop_production': _isShopProd,
      'is_factory_used': _isFactoryUsed,
      'is_shop_used': _isShopUsed,
      'is_exchange': _isExchange,
      'is_transformer': _isTransformer,
      'is_parent': _isParent,
      'parent_id': _isTransformer ? _selectedParentId : null,
    };

    try {
      if (widget.existing != null) {
        await widget.api.put(
          '/api/v1/catalog/products/${widget.existing!['id']}/update/',
          body: body,
        );
      } else {
        await widget.api.post('/api/v1/catalog/products/create/', body: body);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _formError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentChoices = widget.parentCandidates
        .where((p) => p['id'] != widget.existing?['id'])
        .toList();

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existing != null ? 'تعديل بيانات الصنف' : 'إضافة صنف جديد',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _isSubmitting ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (_formError != null) ...[
                AppInlineError(message: _formError!),
                const SizedBox(height: 10),
              ],
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'اسم الصنف *',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'وحدة القياس *',
                      ),
                      value: widget.units.any((u) => u['id'] == _selectedUnitId)
                          ? _selectedUnitId
                          : null,
                      items: widget.units
                          .map(
                            (u) => DropdownMenuItem<int>(
                              value: u['id'] as int,
                              child: Text(
                                u['formula']?.toString() ??
                                    u['name']?.toString() ??
                                    '',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontFamily: 'Cairo'),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedUnitId = v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'المخزن الرئيسي *',
                      ),
                      value:
                          widget.stores.any((s) => s['id'] == _selectedStoreId)
                              ? _selectedStoreId
                              : null,
                      items: widget.stores
                          .map(
                            (s) => DropdownMenuItem<int>(
                              value: s['id'] as int,
                              child: Text(
                                s['name']?.toString() ?? '',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontFamily: 'Cairo'),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedStoreId = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppNumericField(
                      controller: _sellingPriceCtrl,
                      label: 'سعر البيع للجمهور',
                      unit: 'ج.م',
                      allowDecimal: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppNumericField(
                      controller: _wholesaleCtrl,
                      label: 'سعر الجملة',
                      unit: 'ج.م',
                      allowDecimal: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppNumericField(
                      controller: _priceCtrl,
                      label: 'سعر الشراء / المباشر',
                      unit: 'ج.م',
                      allowDecimal: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppNumericField(
                      controller: _patchCtrl,
                      label: 'حجم التشغيلة (Patch) *',
                      allowDecimal: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AppNumericField(
                      controller: _quantityCtrl,
                      label: 'معامل التحويل *',
                      allowDecimal: true,
                    ),
                  ),
                  if (_canEditCost) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppNumericField(
                        controller: _costCtrl,
                        label: 'التكلفة (الإدارة)',
                        unit: 'ج.م',
                        allowDecimal: true,
                      ),
                    ),
                  ],
                ],
              ),
              if (widget.menuSections.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  'أقسام المنيو (للمنتجات المباعة):',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: widget.menuSections.map((sec) {
                    final id = sec['id'] as int;
                    final sel = _selectedSections.contains(id);
                    return FilterChip(
                      label: Text(
                        '${sec['name']}',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: sel ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      selected: sel,
                      selectedColor: AppColors.primary,
                      onSelected: (v) {
                        setState(() {
                          if (v) {
                            _selectedSections.add(id);
                          } else {
                            _selectedSections.remove(id);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                'خصائص الصنف والتصنيف:',
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _flagChip('ظاهر بالمنيو/النظام', _isVisible,
                      (v) => setState(() => _isVisible = v)),
                  _flagChip('يُباع كصنف (POS)', _isSold,
                      (v) => setState(() => _isSold = v)),
                  _flagChip('صنف مخزني/خام', _isStock,
                      (v) => setState(() => _isStock = v)),
                  _flagChip('صنف إنتاجي (BOM)', _isProduction,
                      (v) => setState(() => _isProduction = v)),
                  _flagChip('يدخل كمكوّن (BOM)', _isComponent,
                      (v) => setState(() => _isComponent = v)),
                  _flagChip('بيع جملة', _isWholesale,
                      (v) => setState(() => _isWholesale = v)),
                  _flagChip('إنتاج مصنع', _isFactoryProd,
                      (v) => setState(() => _isFactoryProd = v)),
                  _flagChip('إنتاج محل', _isShopProd,
                      (v) => setState(() => _isShopProd = v)),
                  _flagChip('استخدام مصنع', _isFactoryUsed,
                      (v) => setState(() => _isFactoryUsed = v)),
                  _flagChip('استخدام محل', _isShopUsed,
                      (v) => setState(() => _isShopUsed = v)),
                  _flagChip('قابل للصرف/الطلب', _isExchange,
                      (v) => setState(() => _isExchange = v)),
                  _flagChip('صنف رئيسي (Parent)', _isParent,
                      (v) => setState(() => _isParent = v)),
                  _flagChip('صنف محوّل/تابع', _isTransformer,
                      (v) => setState(() => _isTransformer = v)),
                ],
              ),
              if (_isTransformer && parentChoices.isNotEmpty) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<int?>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'الصنف الأب (للتحويل)',
                  ),
                  value: parentChoices.any((p) => p['id'] == _selectedParentId)
                      ? _selectedParentId
                      : null,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        'بدون صنف أب',
                        style: TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                    ...parentChoices.map(
                      (p) => DropdownMenuItem<int?>(
                        value: p['id'] as int,
                        child: Text(
                          '${p['name']}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontFamily: 'Cairo'),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _selectedParentId = v),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        widget.existing != null
                            ? 'حفظ تعديلات الصنف'
                            : 'إنشاء الصنف',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _flagChip(String label, bool selected, ValueChanged<bool> onChanged) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
          color: selected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: selected,
      selectedColor: AppColors.primary,
      checkmarkColor: Colors.white,
      onSelected: onChanged,
    );
  }
}

class _ProductDetailBomSheet extends StatefulWidget {
  final ApiClient api;
  final Map<String, dynamic> summaryItem;
  final ValueChanged<Map<String, dynamic>> onEditProduct;
  final VoidCallback onCatalogMutated;

  const _ProductDetailBomSheet({
    required this.api,
    required this.summaryItem,
    required this.onEditProduct,
    required this.onCatalogMutated,
  });

  @override
  State<_ProductDetailBomSheet> createState() => _ProductDetailBomSheetState();
}

class _ProductDetailBomSheetState extends State<_ProductDetailBomSheet> {
  late Map<String, dynamic> _detail;
  List<Map<String, dynamic>> _components = [];
  bool _loadingDetail = true;
  String? _detailError;
  bool _busyAction = false;

  int get _productId => widget.summaryItem['id'] as int;

  @override
  void initState() {
    super.initState();
    _detail = Map<String, dynamic>.from(widget.summaryItem);
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    setState(() {
      _loadingDetail = true;
      _detailError = null;
    });
    try {
      final res = await widget.api.get('/api/v1/catalog/products/$_productId/');
      if (!mounted) return;
      if (res is Map<String, dynamic>) {
        final rawComp = res['components'] as List<dynamic>? ?? [];
        setState(() {
          _detail = res;
          _components = rawComp.whereType<Map<String, dynamic>>().toList();
          _loadingDetail = false;
        });
      } else {
        setState(() {
          _loadingDetail = false;
          _detailError = 'استجابة غير متوقعة من الخادم';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingDetail = false;
          _detailError = e.toString();
        });
      }
    }
  }

  Future<void> _toggleVisibility() async {
    final isVisible = _detail['is_visible'] != false;
    setState(() => _busyAction = true);
    try {
      await widget.api.put(
        '/api/v1/catalog/products/$_productId/update/',
        body: {'is_visible': !isVisible},
      );
      if (!mounted) return;
      setState(() => _busyAction = false);
      AppFeedback.showSuccess(
        context,
        !isVisible ? 'تم إظهار الصنف' : 'تم إخفاء الصنف',
      );
      await _fetchDetail();
      widget.onCatalogMutated();
    } catch (e) {
      if (mounted) {
        setState(() => _busyAction = false);
        AppFeedback.showError(context, e.toString());
      }
    }
  }

  Future<void> _archiveOrRestore() async {
    final isVisible = _detail['is_visible'] != false;
    final confirmed = await AppConfirmDialog.show(
      context,
      title: !isVisible ? 'استعادة الصنف' : 'أرشفة الصنف',
      message: !isVisible
          ? 'هل تريد استعادة "${_detail['name']}" وإظهاره في القوائم؟'
          : 'هل تريد أرشفة "${_detail['name']}" وإخفاءه من القوائم؟',
      confirmLabel: !isVisible ? 'استعادة وإظهار' : 'أرشفة',
      isDestructive: isVisible,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyAction = true);
    try {
      if (!isVisible) {
        await widget.api.post(
          '/api/v1/catalog/products/$_productId/restore/',
          body: {'make_visible': true},
        );
      } else {
        await widget.api.post('/api/v1/catalog/products/$_productId/archive/');
      }
      if (!mounted) return;
      setState(() => _busyAction = false);
      AppFeedback.showSuccess(
        context,
        !isVisible ? 'تمت استعادة الصنف وإظهاره' : 'تمت أرشفة الصنف',
      );
      Navigator.pop(context);
      widget.onCatalogMutated();
    } catch (e) {
      if (mounted) {
        setState(() => _busyAction = false);
        AppFeedback.showError(context, e.toString());
      }
    }
  }

  Future<void> _applyDirectCost() async {
    setState(() => _busyAction = true);
    try {
      final res = await widget.api.post(
        '/api/v1/reports/costs/direct/apply/',
        body: {'product_id': _productId},
      );
      if (!mounted) return;
      setState(() => _busyAction = false);
      final msg =
          (res is Map ? res['message']?.toString() : null) ?? 'تم تحديث تكلفة الصنف';
      AppFeedback.showSuccess(context, msg);
      await _fetchDetail();
      widget.onCatalogMutated();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busyAction = false);
        if (e.statusCode == 404) {
          AppFeedback.showError(
            context,
            'تحديث التكلفة المباشرة غير متاح على إصدار الخادم الحالي.',
          );
        } else {
          AppFeedback.showError(context, e.toString());
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busyAction = false);
        AppFeedback.showError(context, e.toString());
      }
    }
  }

  Future<void> _openComponentEditor({
    Map<String, dynamic>? existingComponent,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ComponentEditorDialog(
        api: widget.api,
        productId: _productId,
        existingComponent: existingComponent,
      ),
    );
    if (saved == true && mounted) {
      AppFeedback.showSuccess(
        context,
        existingComponent != null
            ? 'تم تعديل مكوّن الوصفة بنجاح'
            : 'تمت إضافة المكوّن للوصفة بنجاح',
      );
      await _fetchDetail();
      widget.onCatalogMutated();
    }
  }

  Future<void> _deleteComponent(Map<String, dynamic> comp) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'حذف مكوّن من الوصفة',
      message: 'هل تريد حذف "${comp['product_name']}" من مكونات الصنف؟',
      confirmLabel: 'حذف',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await widget.api.delete(
        '/api/v1/catalog/products/$_productId/components/${comp['id']}/delete/',
      );
      if (!mounted) return;
      AppFeedback.showSuccess(context, 'تم حذف المكوّن من الوصفة');
      await _fetchDetail();
      widget.onCatalogMutated();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, e.toString());
    }
  }

  Widget _kvRow(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            k,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 12.5,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            v,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isVisible = _detail['is_visible'] != false;
    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      maxChildSize: 0.94,
      minChildSize: 0.45,
      expand: false,
      builder: (ctx, sc) => Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                ProductAvatar(
                  product: ProductModel.fromJson(_detail),
                  size: 46,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _detail['name']?.toString() ?? '',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'وحدة: ${_detail['unit_formula'] ?? _detail['unit_name'] ?? ''}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'تعديل الصنف',
                  icon: const Icon(Icons.edit_outlined, color: AppColors.info),
                  onPressed: _busyAction
                      ? null
                      : () {
                          final currentDetail = _detail;
                          Navigator.pop(context);
                          widget.onEditProduct(currentDetail);
                        },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loadingDetail
                ? const Center(child: CircularProgressIndicator())
                : _detailError != null
                    ? AppErrorView(
                        message: _detailError!,
                        onRetry: _fetchDetail,
                      )
                    : ListView(
                        controller: sc,
                        padding: const EdgeInsets.all(20),
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (_detail['store_name'] != null)
                                AppStatusBadge(
                                  label: 'مخزن: ${_detail['store_name']}',
                                  color: AppColors.info,
                                ),
                              AppStatusBadge(
                                label: isVisible ? 'ظاهر بالنظام' : 'مخفي/مؤرشف',
                                color: isVisible
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                              if (_detail['is_sold'] == true)
                                const AppStatusBadge(
                                  label: 'متاح للبيع POS',
                                  color: AppColors.primary,
                                ),
                              if (_detail['is_production'] == true)
                                const AppStatusBadge(
                                  label: 'صنف إنتاجي',
                                  color: AppColors.accentPurple,
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                _kvRow(
                                  'سعر البيع للجمهور',
                                  '${_detail['selling_price'] ?? 0} ج.م',
                                ),
                                _kvRow(
                                  'سعر الجملة',
                                  '${_detail['wholesale_price'] ?? 0} ج.م',
                                ),
                                _kvRow(
                                  'سعر الشراء / المباشر',
                                  '${_detail['price'] ?? 0} ج.م',
                                ),
                                _kvRow(
                                  'التكلفة الكلية',
                                  '${_detail['cost'] ?? 0} ج.م',
                                ),
                                _kvRow(
                                  'حجم التشغيلة (Patch)',
                                  '${_detail['patch'] ?? 1}',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton.icon(
                                icon: Icon(
                                  isVisible
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  isVisible ? 'إخفاء' : 'إظهار',
                                  style: const TextStyle(fontFamily: 'Cairo'),
                                ),
                                onPressed:
                                    _busyAction ? null : _toggleVisibility,
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: !isVisible
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                                icon: Icon(
                                  !isVisible
                                      ? Icons.restore_from_trash_outlined
                                      : Icons.archive_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  !isVisible ? 'استعادة وإظهار' : 'أرشفة الصنف',
                                  style: const TextStyle(fontFamily: 'Cairo'),
                                ),
                                onPressed:
                                    _busyAction ? null : _archiveOrRestore,
                              ),
                              FilledButton.tonalIcon(
                                icon: const Icon(
                                  Icons.calculate_outlined,
                                  size: 18,
                                ),
                                label: const Text(
                                  'احتساب تكلفة الصنف',
                                  style: TextStyle(fontFamily: 'Cairo'),
                                ),
                                onPressed:
                                    _busyAction ? null : _applyDirectCost,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'مكونات الوصفة (BOM Components):',
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                ),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text(
                                  'إضافة مكوّن',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: _openComponentEditor,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (_components.isEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Text(
                                'لا توجد مكونات مسجلة لهذا الصنف حتى الآن.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Cairo',
                                  color: AppColors.textMuted,
                                ),
                              ),
                            )
                          else
                            ..._components.map(
                              (comp) => Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            comp['product_name']?.toString() ??
                                                '',
                                            style: const TextStyle(
                                              fontFamily: 'Cairo',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                          Text(
                                            'الكمية بالمكوّن: ${comp['quantity']} ${comp['unit_name'] ?? ''}',
                                            style: const TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 11.5,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'تعديل الكمية',
                                      constraints: const BoxConstraints(
                                        minWidth: 40,
                                        minHeight: 40,
                                      ),
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 19,
                                        color: AppColors.info,
                                      ),
                                      onPressed: () => _openComponentEditor(
                                        existingComponent: comp,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'حذف المكوّن',
                                      constraints: const BoxConstraints(
                                        minWidth: 40,
                                        minHeight: 40,
                                      ),
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 19,
                                        color: AppColors.error,
                                      ),
                                      onPressed: () => _deleteComponent(comp),
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

class _ComponentEditorDialog extends StatefulWidget {
  final ApiClient api;
  final int productId;
  final Map<String, dynamic>? existingComponent;

  const _ComponentEditorDialog({
    required this.api,
    required this.productId,
    this.existingComponent,
  });

  @override
  State<_ComponentEditorDialog> createState() => _ComponentEditorDialogState();
}

class _ComponentEditorDialogState extends State<_ComponentEditorDialog> {
  final TextEditingController _searchResCtrl = TextEditingController();
  late final TextEditingController _qtyCtrl;
  Timer? _searchDebounce;
  ApiCancelToken? _searchToken;

  List<Map<String, dynamic>> _searchResults = [];
  int? _selectedResId;
  bool _searching = false;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existingComponent != null;

  @override
  void initState() {
    super.initState();
    _qtyCtrl = TextEditingController(
      text: (widget.existingComponent?['quantity'] ?? 1).toString(),
    );
    _selectedResId = widget.existingComponent?['product_id'] as int?;
    if (!_isEdit) {
      _search('');
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchToken?.cancel();
    _searchResCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    _searchToken?.cancel();
    final token = ApiCancelToken();
    _searchToken = token;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final res = await widget.api.get(
        '/api/v1/catalog/products/',
        queryParams: {
          if (query.trim().isNotEmpty) 'q': query.trim(),
          'page_size': '30',
        },
        cancelToken: token,
      );
      if (token.isCancelled || !mounted) return;
      final list = (res is Map ? res['results'] as List<dynamic>? : null) ?? [];
      final filtered = list
          .whereType<Map<String, dynamic>>()
          .where((p) => p['id'] != widget.productId)
          .toList();
      setState(() {
        _searchResults = filtered;
        if (_searchResults.isNotEmpty &&
            !_searchResults.any((p) => p['id'] == _selectedResId)) {
          _selectedResId = _searchResults.first['id'] as int?;
        }
        _searching = false;
      });
    } catch (e) {
      if (token.isCancelled || !mounted) return;
      setState(() {
        _searching = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedResId == null) {
      setState(() => _error = 'اختر الصنف المكوّن أولاً.');
      return;
    }
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 0;
    if (qty <= 0) {
      setState(() => _error = 'أدخل كمية أكبر من صفر.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_isEdit) {
        await widget.api.put(
          '/api/v1/catalog/products/${widget.productId}/components/${widget.existingComponent!['id']}/update/',
          body: {'product_id': _selectedResId, 'quantity': qty},
        );
      } else {
        await widget.api.post(
          '/api/v1/catalog/products/${widget.productId}/components/create/',
          body: {'product_id': _selectedResId, 'quantity': qty},
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEdit ? 'تعديل كمية المكوّن' : 'إضافة مكوّن للوصفة (BOM)',
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              AppInlineError(message: _error!),
              const SizedBox(height: 10),
            ],
            if (!_isEdit) ...[
              TextField(
                controller: _searchResCtrl,
                decoration: InputDecoration(
                  hintText: 'ابحث عن الخامة أو المكوّن...',
                  isDense: true,
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searching
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                ),
                onChanged: (q) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(
                    const Duration(milliseconds: 300),
                    () => _search(q),
                  );
                },
              ),
              const SizedBox(height: 10),
              if (_searchResults.isNotEmpty)
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'الصنف المكوّن *',
                    isDense: true,
                  ),
                  value: _searchResults.any((p) => p['id'] == _selectedResId)
                      ? _selectedResId
                      : _searchResults.first['id'] as int,
                  items: _searchResults
                      .map(
                        (p) => DropdownMenuItem<int>(
                          value: p['id'] as int,
                          child: Text(
                            '${p['name']}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedResId = v),
                ),
              const SizedBox(height: 10),
            ],
            AppNumericField(
              controller: _qtyCtrl,
              label: 'الكمية داخل الوصفة *',
              dialogTitle: 'الكمية داخل الوصفة',
              allowDecimal: true,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'حفظ المكوّن',
                  style: TextStyle(fontFamily: 'Cairo'),
                ),
        ),
      ],
    );
  }
}

class _MenuSectionFormSheet extends StatefulWidget {
  final ApiClient api;
  final Map<String, dynamic>? existing;

  const _MenuSectionFormSheet({required this.api, this.existing});

  @override
  State<_MenuSectionFormSheet> createState() => _MenuSectionFormSheetState();
}

class _MenuSectionFormSheetState extends State<_MenuSectionFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _orderCtrl;
  late bool _isActive;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.existing?['name']?.toString() ?? '',
    );
    _orderCtrl = TextEditingController(
      text: (widget.existing?['display_order'] ?? 0).toString(),
    );
    _isActive = widget.existing?['is_active'] != false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'أدخل اسم قسم المنيو.');
      return;
    }
    final orderText = _orderCtrl.text.trim();
    final orderVal = orderText.isEmpty ? 0 : int.tryParse(orderText);
    if (orderVal == null || orderVal < 0) {
      setState(() => _error = 'ترتيب العرض يجب أن يكون رقماً صحيحاً 0 أو أكبر.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final body = {
      'name': name,
      'display_order': orderVal.clamp(0, 999999),
      'is_active': _isActive,
    };
    try {
      if (widget.existing != null) {
        await widget.api.put(
          '/api/v1/catalog/menu-sections/${widget.existing!['id']}/update/',
          body: body,
        );
      } else {
        await widget.api.post(
          '/api/v1/catalog/menu-sections/create/',
          body: body,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEdit ? 'تعديل قسم المنيو' : 'إضافة قسم منيو جديد',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed:
                      _isSubmitting ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_error != null) ...[
              AppInlineError(message: _error!),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'اسم القسم *',
                prefixIcon: Icon(Icons.category_outlined),
              ),
            ),
            const SizedBox(height: 12),
            AppNumericField(
              controller: _orderCtrl,
              label: 'ترتيب العرض بالمنيو',
              dialogTitle: 'ترتيب العرض (رقم صحيح)',
              prefixIcon: Icons.sort_rounded,
              allowDecimal: false,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'القسم نشط وظاهر بالكاشير',
                style: TextStyle(fontFamily: 'Cairo'),
              ),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      isEdit ? 'حفظ التعديلات' : 'إنشاء القسم',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BatchExportImportSheet extends StatefulWidget {
  final ApiClient api;
  final bool initialImport;

  const _BatchExportImportSheet({
    required this.api,
    this.initialImport = false,
  });

  @override
  State<_BatchExportImportSheet> createState() =>
      _BatchExportImportSheetState();
}

class _BatchExportImportSheetState extends State<_BatchExportImportSheet> {
  static const Set<String> _validTypes = {'', 'RM', 'FP', 'SL', 'SF'};
  static const Set<String> _validPlaces = {'', 'FA', 'SH'};

  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  bool _importing = false;
  String? _error;
  final Map<int, Map<String, String>> _edits = {};

  @override
  void initState() {
    super.initState();
    _loadRows();
  }

  static String _deriveType(Map<String, dynamic> p) {
    if (p['is_sold'] == true && p['is_production'] == true) return 'FP';
    if (p['is_production'] == true &&
        p['is_component'] == true &&
        p['is_stock'] != true) {
      return 'SL';
    }
    if (p['is_stock'] == true) return 'RM';
    return '';
  }

  static String _derivePlace(Map<String, dynamic> p) {
    if (p['is_factory_production'] == true) return 'FA';
    if (p['is_shop_production'] == true) return 'SH';
    return '';
  }

  Future<void> _loadRows() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      List<Map<String, dynamic>> fetched;
      try {
        final res = await widget.api.get('/api/v1/catalog/products/export/');
        fetched = (res is Map
                ? (res['results'] as List<dynamic>? ?? [])
                : const <dynamic>[])
            .whereType<Map<String, dynamic>>()
            .toList();
      } on ApiException catch (e) {
        if (e.statusCode != 404) rethrow;
        fetched = <Map<String, dynamic>>[];
        for (var page = 1; page <= 20; page++) {
          final res = await widget.api.get(
            '/api/v1/catalog/products/',
            queryParams: {'page': '$page', 'page_size': '100'},
          );
          if (res is! Map) break;
          final batch = (res['results'] as List<dynamic>? ?? [])
              .whereType<Map<String, dynamic>>()
              .map((p) {
                final unit = p['unit'];
                final store = p['store'];
                return <String, dynamic>{
                  ...p,
                  'unit_formula': p['unit_formula'] ??
                      (unit is Map ? unit['formula'] : null) ??
                      '',
                  'store_name': p['store_name'] ??
                      (store is Map ? store['name'] : null) ??
                      '',
                  'type': p['type'] ?? _deriveType(p),
                  'place': p['place'] ?? _derivePlace(p),
                };
              })
              .toList();
          fetched.addAll(batch);
          if (res['next'] == null || batch.isEmpty) break;
        }
      }
      if (!mounted) return;
      setState(() {
        _rows = fetched;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _copyCsv() async {
    final buffer = StringBuffer('id,name,unit_formula,store_name,type,place\n');
    for (final r in _rows) {
      buffer.writeln(
        '${r['id']},"${r['name']}","${r['unit_formula']}","${r['store_name']}",${r['type'] ?? ''},${r['place'] ?? ''}',
      );
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    AppFeedback.showSuccess(
      context,
      'تم نسخ بيانات ${_rows.length} صنف بصيغة CSV إلى الحافظة',
    );
  }

  Future<void> _applyBatchImport() async {
    setState(() {
      _importing = true;
      _error = null;
    });
    try {
      final payloadRows = _edits.entries
          .map(
            (e) => {
              'id': e.key,
              'type': e.value['type'] ?? '',
              'place': e.value['place'] ?? '',
            },
          )
          .toList();
      String msg = 'تم تحديث الأصناف بنجاح';
      try {
        final res = await widget.api.post(
          '/api/v1/catalog/products/import/',
          body: {'rows': payloadRows},
        );
        if (res is Map && res['message'] != null) {
          msg = res['message'].toString();
        }
      } on ApiException catch (e) {
        if (e.statusCode != 404) rethrow;
        var updated = 0;
        for (final row in payloadRows) {
          final id = row['id'];
          final t = (row['type'] ?? '').toString().toUpperCase();
          final p = (row['place'] ?? '').toString().toUpperCase();
          final updateBody = <String, dynamic>{
            if (t == 'RM' || t == 'SF') ...{
              'is_stock': true,
              'is_exchange': true,
              'is_component': true,
            } else if (t == 'FP') ...{
              'is_sold': true,
              'is_production': true,
            } else if (t == 'SL') ...{
              'is_production': true,
              'is_component': true,
            },
            if (p == 'FA') ...{
              'is_factory_production': true,
              'is_factory_used': true,
            } else if (p == 'SH') ...{
              'is_shop_production': true,
              'is_shop_used': true,
            },
          };
          if (updateBody.isNotEmpty) {
            await widget.api.put(
              '/api/v1/catalog/products/$id/update/',
              body: updateBody,
            );
            updated++;
          }
        }
        msg = 'تم تحديث $updated صنف بنجاح';
      }
      if (!mounted) return;
      AppFeedback.showSuccess(context, msg);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _importing = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, sc) => Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'تصدير وتحديث الأصناف الجماعي (Batch)',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _importing ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: AppInlineError(message: _error!),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text(
                    'نسخ CSV للحافظة',
                    style: TextStyle(fontFamily: 'Cairo'),
                  ),
                  onPressed: _rows.isEmpty || _loading ? null : _copyCsv,
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  icon: _importing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.cloud_upload_outlined, size: 18),
                  label: Text(
                    _edits.isEmpty
                        ? 'حفظ التعديلات'
                        : 'اعتماد تعديل (${_edits.length}) صنف',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: (_edits.isEmpty || _importing)
                      ? null
                      : _applyBatchImport,
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          Expanded(
            child: _loading
                ? const AppLoadingView(message: 'جاري تحميل قائمة التصنيفات...')
                : _error != null && _rows.isEmpty
                    ? AppErrorView(message: _error!, onRetry: _loadRows)
                    : _rows.isEmpty
                        ? AppEmptyView(
                            title: 'لا توجد أصناف للتصدير',
                            icon: Icons.table_rows_outlined,
                            actionLabel: 'إعادة المحاولة',
                            onAction: _loadRows,
                          )
                        : ListView.separated(
                            controller: sc,
                            padding: const EdgeInsets.all(16),
                            itemCount: _rows.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final r = _rows[i];
                              final id = r['id'] as int;
                              final rawType = _edits[id]?['type'] ??
                                  (r['type']?.toString() ?? '');
                              final rawPlace = _edits[id]?['place'] ??
                                  (r['place']?.toString() ?? '');
                              final curType =
                                  _validTypes.contains(rawType) ? rawType : '';
                              final curPlace = _validPlaces.contains(rawPlace)
                                  ? rawPlace
                                  : '';

                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _edits.containsKey(id)
                                        ? AppColors.primary
                                        : AppColors.border,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            r['name']?.toString() ?? '',
                                            style: const TextStyle(
                                              fontFamily: 'Cairo',
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${r['store_name'] ?? ''}',
                                          style: const TextStyle(
                                            fontFamily: 'Cairo',
                                            fontSize: 11.5,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            isExpanded: true,
                                            isDense: true,
                                            decoration: const InputDecoration(
                                              labelText: 'النوع',
                                            ),
                                            value: curType,
                                            items: const [
                                              DropdownMenuItem(
                                                value: '',
                                                child: Text(
                                                  '-',
                                                  style: TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'RM',
                                                child: Text(
                                                  'RM خام',
                                                  style: TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'FP',
                                                child: Text(
                                                  'FP تام',
                                                  style: TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'SF',
                                                child: Text(
                                                  'SF نصف مصنع',
                                                  style: TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'SL',
                                                child: Text(
                                                  'SL وسيط',
                                                  style: TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            onChanged: (val) => setState(
                                              () => _edits[id] = {
                                                'type': val ?? '',
                                                'place': curPlace,
                                              },
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: DropdownButtonFormField<String>(
                                            isExpanded: true,
                                            isDense: true,
                                            decoration: const InputDecoration(
                                              labelText: 'المكان',
                                            ),
                                            value: curPlace,
                                            items: const [
                                              DropdownMenuItem(
                                                value: '',
                                                child: Text(
                                                  '-',
                                                  style: TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'FA',
                                                child: Text(
                                                  'FA مصنع',
                                                  style: TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                              DropdownMenuItem(
                                                value: 'SH',
                                                child: Text(
                                                  'SH محل',
                                                  style: TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            onChanged: (val) => setState(
                                              () => _edits[id] = {
                                                'type': curType,
                                                'place': val ?? '',
                                              },
                                            ),
                                          ),
                                        ),
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
    );
  }
}
