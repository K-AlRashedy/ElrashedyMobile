import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/network/api_client.dart';
import '../core/pagination.dart';
import '../models/branch_model.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';

class OrderProvider extends ChangeNotifier {
  OrderProvider(this._api) {
    ordersPagination = PaginationController<OrderModel>(_fetchOrdersPage);
  }

  final ApiClient _api;
  final _uuid = const Uuid();
  Timer? _searchDebounce;
  ApiCancelToken? _catalogCancelToken;
  int _catalogGeneration = 0;

  List<ProductModel> _allProducts = [];
  List<ProductModel> _topProducts = [];
  List<String> _categories = const ['الكل'];
  String _selectedCategory = 'الكل';
  String _searchQuery = '';

  final Map<int, CartItem> _cart = {};

  List<BranchModel> _allBranches = [];
  List<BranchModel> _userBranches = [];
  BranchModel? _selectedFromBranch;
  BranchModel? _selectedToBranch;
  String _orderType = 'order';
  String _generalNote = '';

  late final PaginationController<OrderModel> ordersPagination;
  Map<String, dynamic> _orderFilters = const {'direction': 'all'};

  bool _isLoadingCatalog = false;
  bool _isLoadingMoreCatalog = false;
  bool _isLoadingTopProducts = false;
  bool _isSubmitting = false;
  int _catalogPage = 0;
  bool _catalogHasNext = false;
  String? _errorMessage;
  String? _topProductsError;

  List<ProductModel> get allProducts => List.unmodifiable(_allProducts);
  List<ProductModel> get products => allProducts;
  List<ProductModel> get topProducts => List.unmodifiable(_topProducts);
  List<String> get categories => _categories;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;
  bool get catalogHasNext => _catalogHasNext;
  String? get topProductsError => _topProductsError;

  Map<int, CartItem> get cart => Map.unmodifiable(_cart);
  List<CartItem> get cartItems => _cart.values.toList(growable: false);
  int get cartCount => _cart.length;
  double get totalQuantity => _cart.values.fold(0, (sum, item) => sum + item.quantity);

  List<BranchModel> get allDestinationBranches => _allBranches;
  List<BranchModel> get userBranches => _userBranches;
  BranchModel? get selectedFromBranch => _selectedFromBranch;
  BranchModel? get selectedToBranch => _selectedToBranch;
  String get orderType => _orderType;
  String get generalNote => _generalNote;

  bool get isLoadingCatalog => _isLoadingCatalog;
  bool get isLoadingMoreCatalog => _isLoadingMoreCatalog;
  bool get isLoadingTopProducts => _isLoadingTopProducts;
  bool get isSubmitting => _isSubmitting;
  bool get isLoadingOrders => ordersPagination.isLoading;
  String? get errorMessage => _errorMessage;

  List<ProductModel> get filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    return _allProducts.where((product) {
      final matchesCategory = _selectedCategory == 'الكل' || product.category == _selectedCategory;
      final matchesQuery = query.isEmpty ||
          product.name.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList(growable: false);
  }

  void setCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query, {bool immediate = false}) {
    _searchQuery = query;
    notifyListeners();
    _searchDebounce?.cancel();
    if (immediate) {
      loadCatalog(refresh: true, query: query);
    } else {
      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
        loadCatalog(refresh: true, query: query);
      });
    }
  }

  void clearSearch() {
    if (_searchQuery.isEmpty) return;
    setSearchQuery('', immediate: true);
  }

  void setBranches({BranchModel? from, BranchModel? to}) {
    var changed = false;
    if (from != null && _selectedFromBranch?.id != from.id) {
      _selectedFromBranch = from;
      changed = true;
    }
    if (to != null && _selectedToBranch?.id != to.id) {
      _selectedToBranch = to;
      changed = true;
    }
    notifyListeners();
    if (changed) loadTopProducts();
  }

  void setOrderType(String type) {
    if (_orderType == type) return;
    _orderType = type;
    notifyListeners();
    loadTopProducts();
  }

  void setGeneralNote(String note) {
    _generalNote = note;
    notifyListeners();
  }

  void addOrIncrement(ProductModel product, [double delta = 1]) {
    if (delta <= 0) return;
    final current = _cart[product.id];
    if (current != null) {
      current.quantity += delta;
    } else {
      _cart[product.id] = CartItem(product: product, quantity: delta);
    }
    notifyListeners();
  }

  void setQuantity(int productId, double quantity) {
    if (quantity <= 0) {
      _cart.remove(productId);
    } else if (_cart.containsKey(productId)) {
      _cart[productId]!.quantity = quantity;
    }
    notifyListeners();
  }

  void decrementOrRemove(int productId, [double delta = 1]) {
    final item = _cart[productId];
    if (item == null) return;
    if (item.quantity > delta) {
      item.quantity -= delta;
    } else {
      _cart.remove(productId);
    }
    notifyListeners();
  }

  void setItemNote(int productId, String note) {
    final item = _cart[productId];
    if (item == null) return;
    item.note = note;
    notifyListeners();
  }

  void removeItem(int productId) {
    _cart.remove(productId);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    _generalNote = '';
    notifyListeners();
  }

  double getQuantityForProduct(int productId) => _cart[productId]?.quantity ?? 0;

  Future<void> loadCatalog({bool refresh = true, String? query}) async {
    if (!refresh && (_isLoadingMoreCatalog || _isLoadingCatalog || !_catalogHasNext)) return;

    final effectiveQuery = (query ?? _searchQuery).trim();
    final page = refresh ? 1 : _catalogPage + 1;
    final generation = refresh ? ++_catalogGeneration : _catalogGeneration;

    if (refresh) {
      _catalogCancelToken?.cancel();
      _catalogCancelToken = ApiCancelToken();
      _isLoadingCatalog = true;
    } else {
      _isLoadingMoreCatalog = true;
    }
    final token = _catalogCancelToken;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _api.get(
        '/api/v1/orders/catalog/',
        queryParams: {
          'page': page,
          if (effectiveQuery.isNotEmpty) 'q': effectiveQuery,
        },
        cancelToken: token,
      );
      if (generation != _catalogGeneration) return;
      final result = PageResult.fromResponse(response, 'products', ProductModel.fromJson);
      if (page == 1) {
        _allProducts = result.items;
      } else {
        final existingIds = _allProducts.map((e) => e.id).toSet();
        _allProducts = [
          ..._allProducts,
          ...result.items.where((e) => !existingIds.contains(e.id)),
        ];
      }
      _catalogPage = result.page;
      _catalogHasNext = result.hasNext;
      final categories = <String>{'الكل'};
      for (final product in _allProducts) {
        if (product.category.isNotEmpty) categories.add(product.category);
      }
      _categories = categories.toList(growable: false);
      if (!_categories.contains(_selectedCategory)) _selectedCategory = 'الكل';
    } on ApiException catch (error) {
      if (generation == _catalogGeneration && error.message != 'تم إلغاء الطلب.') {
        _errorMessage = error.message;
      }
    } catch (error) {
      if (generation == _catalogGeneration) {
        _errorMessage = error.toString();
      }
    } finally {
      if (generation == _catalogGeneration) {
        _isLoadingCatalog = false;
        _isLoadingMoreCatalog = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreCatalog() => loadCatalog(refresh: false);

  Future<void> loadBootstrapBranches() async {
    _errorMessage = null;
    try {
      final response = await _api.get('/api/v1/bootstrap/');
      if (response is! Map<String, dynamic>) throw const FormatException('بيانات الفروع غير صالحة.');
      final rawAll = response['all_branches'] as List<dynamic>? ?? const [];
      final rawUser = response['user_branches'] as List<dynamic>? ?? const [];
      _allBranches = rawAll
          .whereType<Map<String, dynamic>>()
          .map(BranchModel.fromJson)
          .toList(growable: false);
      _userBranches = rawUser
          .whereType<Map<String, dynamic>>()
          .map(BranchModel.fromJson)
          .toList(growable: false);
      _selectedFromBranch ??= _userBranches.isEmpty
          ? (_allBranches.isEmpty ? null : _allBranches.first)
          : _userBranches.first;
      if (_allBranches.isNotEmpty) {
        _selectedToBranch ??= _allBranches.firstWhere(
          (branch) => branch.type == 'FACTORY' || branch.id != _selectedFromBranch?.id,
          orElse: () => _allBranches.first,
        );
      }
      notifyListeners();
      await loadTopProducts();
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<void> loadTopProducts() async {
    if (_isLoadingTopProducts) return;
    _isLoadingTopProducts = true;
    _topProductsError = null;
    notifyListeners();
    try {
      final isTransfer = _orderType == 'transfer';
      // In transfer mode, from_branch is dispensing and to_branch is requesting.
      // Backend expects branch_id = dispensing branch, from_branch_id = requesting branch.
      final dispensingId = isTransfer ? _selectedFromBranch?.id : _selectedToBranch?.id;
      final requestingId = isTransfer ? _selectedToBranch?.id : _selectedFromBranch?.id;

      final response = await _api.get('/api/v1/orders/top-products/', queryParams: {
        if (dispensingId != null) 'branch_id': dispensingId,
        if (!isTransfer && requestingId != null) 'from_branch_id': requestingId,
      });
      if (response is! Map<String, dynamic>) throw const FormatException('بيانات الأصناف غير صالحة.');
      final raw = response['products'] as List<dynamic>? ?? const [];
      _topProducts = raw
          .whereType<Map<String, dynamic>>()
          .map(ProductModel.fromJson)
          .toList(growable: false);
    } catch (error) {
      _topProducts = [];
      _topProductsError = error.toString();
    } finally {
      _isLoadingTopProducts = false;
      notifyListeners();
    }
  }

  Future<bool> submitOrder() async {
    if (_cart.isEmpty) {
      _errorMessage = 'السلة فارغة. يرجى إضافة أصناف أولاً.';
      notifyListeners();
      return false;
    }
    if (_selectedFromBranch == null || _selectedToBranch == null) {
      _errorMessage = 'يرجى تحديد الفرعين.';
      notifyListeners();
      return false;
    }
    if (_selectedFromBranch!.id == _selectedToBranch!.id) {
      _errorMessage = 'يجب أن يكون الفرع الطالب مختلفاً عن الفرع المورد.';
      notifyListeners();
      return false;
    }
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _api.post(
        '/api/v1/orders/create/',
        idempotencyKey: _uuid.v4(),
        body: {
          'from_branch_id': _selectedFromBranch!.id,
          'to_branch_id': _selectedToBranch!.id,
          'type': _orderType,
          'general_note': _generalNote,
          'items': _cart.values.map((item) => item.toApiPayload()).toList(),
        },
      );
      if (response is! Map<String, dynamic> || response['ok'] != true) {
        throw ApiException(response is Map ? response['error']?.toString() ?? 'فشل رفع الطلب.' : 'فشل رفع الطلب.');
      }
      clearCart();
      await ordersPagination.replaceFilters(_orderFilters);
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> loadOrdersList({
    String direction = 'all',
    String? status,
    String? revStatus,
    int? branchId,
    bool includeLocked = false,
  }) async {
    _orderFilters = {
      'direction': direction,
      if (status != null && status.isNotEmpty) 'status': status,
      if (revStatus != null && revStatus.isNotEmpty) 'rev_status': revStatus,
      if (branchId != null) 'branch_id': branchId,
      if (includeLocked) 'include_locked': true,
    };
    await ordersPagination.replaceFilters(_orderFilters);
  }

  Future<void> refreshOrders() => ordersPagination.refresh();
  Future<void> loadMoreOrders() => ordersPagination.loadMore();

  Future<PageResult<OrderModel>> _fetchOrdersPage(int page, Map<String, dynamic> filters) async {
    final apiFilters = Map<String, dynamic>.from(filters);
    if (apiFilters['direction'] == 'review') apiFilters['direction'] = 'all';
    final response = await _api.get('/api/v1/orders/list/', queryParams: {
      ...apiFilters,
      'page': page,
    });
    return PageResult.fromResponse(response, 'orders', OrderModel.fromJson);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _catalogCancelToken?.cancel();
    ordersPagination.dispose();
    super.dispose();
  }
}
