import 'package:flutter/material.dart';
import '../core/network/api_client.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';
import '../models/branch_model.dart';

class OrderProvider extends ChangeNotifier {
  final ApiClient _api;

  List<ProductModel> _allProducts = [];
  List<ProductModel> _topProducts = [];
  List<String> _categories = ['الكل'];
  String _selectedCategory = 'الكل';
  String _searchQuery = '';

  // Fast Cart: productId -> CartItem
  final Map<int, CartItem> _cart = {};

  List<BranchModel> _allDestinationBranches = [];
  BranchModel? _selectedFromBranch;
  BranchModel? _selectedToBranch;
  String _orderType = 'order'; // 'order' or 'transfer'
  String _generalNote = '';

  List<OrderModel> _recentOrders = [];

  bool _isLoadingCatalog = false;
  bool _isLoadingTopProducts = false;
  bool _isSubmitting = false;
  bool _isLoadingOrders = false;
  String? _errorMessage;

  OrderProvider(this._api);

  List<ProductModel> get allProducts => _allProducts;
  List<ProductModel> get topProducts => _topProducts;
  List<String> get categories => _categories;
  String get selectedCategory => _selectedCategory;
  String get searchQuery => _searchQuery;

  Map<int, CartItem> get cart => _cart;
  List<CartItem> get cartItems => _cart.values.toList();
  int get cartCount => _cart.length;
  double get totalQuantity => _cart.values.fold(0.0, (sum, item) => sum + item.quantity);

  List<BranchModel> get allDestinationBranches => _allDestinationBranches;
  BranchModel? get selectedFromBranch => _selectedFromBranch;
  BranchModel? get selectedToBranch => _selectedToBranch;
  String get orderType => _orderType;
  String get generalNote => _generalNote;

  List<OrderModel> get recentOrders => _recentOrders;
  bool get isLoadingCatalog => _isLoadingCatalog;
  bool get isLoadingTopProducts => _isLoadingTopProducts;
  bool get isSubmitting => _isSubmitting;
  bool get isLoadingOrders => _isLoadingOrders;
  String? get errorMessage => _errorMessage;

  // Filtered Products for ultra-fast instant UI updates
  List<ProductModel> get filteredProducts {
    return _allProducts.where((p) {
      final matchesCategory = _selectedCategory == 'الكل' || p.category == _selectedCategory;
      final query = _searchQuery.trim().toLowerCase();
      final matchesQuery = query.isEmpty ||
          p.name.toLowerCase().contains(query) ||
          p.category.toLowerCase().contains(query);
      return matchesCategory && matchesQuery;
    }).toList();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setBranches({BranchModel? from, BranchModel? to}) {
    bool changed = false;
    if (from != null && _selectedFromBranch?.id != from.id) {
      _selectedFromBranch = from;
      changed = true;
    }
    if (to != null && _selectedToBranch?.id != to.id) {
      _selectedToBranch = to;
      changed = true;
    }
    notifyListeners();
    if (changed) {
      loadTopProducts();
    }
  }

  void setOrderType(String type) {
    _orderType = type;
    notifyListeners();
  }

  void setGeneralNote(String note) {
    _generalNote = note;
    notifyListeners();
  }

  // --- Cart Fast Operations ---
  void addOrIncrement(ProductModel product, [double delta = 1.0]) {
    if (_cart.containsKey(product.id)) {
      _cart[product.id]!.quantity += delta;
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

  void decrementOrRemove(int productId, [double delta = 1.0]) {
    if (!_cart.containsKey(productId)) return;
    final item = _cart[productId]!;
    if (item.quantity > delta) {
      item.quantity -= delta;
    } else {
      _cart.remove(productId);
    }
    notifyListeners();
  }

  void setItemNote(int productId, String note) {
    if (_cart.containsKey(productId)) {
      _cart[productId]!.note = note;
      notifyListeners();
    }
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

  double getQuantityForProduct(int productId) {
    return _cart[productId]?.quantity ?? 0.0;
  }

  // --- Network API Actions ---
  Future<void> loadCatalog() async {
    if (_allProducts.isNotEmpty && !_isLoadingCatalog) return; // Cached
    _isLoadingCatalog = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await _api.get('/api/v1/orders/catalog/');
      if (res is Map<String, dynamic>) {
        final rawProducts = res['products'] as List<dynamic>? ?? [];
        _allProducts = rawProducts
            .whereType<Map<String, dynamic>>()
            .map((p) => ProductModel.fromJson(p))
            .toList();

        // Extract distinct categories
        final catSet = <String>{'الكل'};
        for (final p in _allProducts) {
          if (p.category.isNotEmpty) catSet.add(p.category);
        }
        _categories = catSet.toList();
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoadingCatalog = false;
      notifyListeners();
    }
  }

  Future<void> loadBootstrapBranches() async {
    try {
      final res = await _api.get('/api/v1/bootstrap/');
      if (res is Map<String, dynamic>) {
        final rawAllBranches = res['all_branches'] as List<dynamic>? ?? [];
        _allDestinationBranches = rawAllBranches
            .whereType<Map<String, dynamic>>()
            .map((b) => BranchModel.fromJson(b))
            .toList();

        final rawUserBranches = res['user_branches'] as List<dynamic>? ?? [];
        final userBranches = rawUserBranches
            .whereType<Map<String, dynamic>>()
            .map((b) => BranchModel.fromJson(b))
            .toList();

        if (_selectedFromBranch == null && userBranches.isNotEmpty) {
          _selectedFromBranch = userBranches.first;
        }

        if (_selectedToBranch == null && _allDestinationBranches.isNotEmpty) {
          // Default to first factory or branch other than source
          _selectedToBranch = _allDestinationBranches.firstWhere(
            (b) => b.type == 'FACTORY' || b.id != _selectedFromBranch?.id,
            orElse: () => _allDestinationBranches.first,
          );
        }
        notifyListeners();
        loadTopProducts();
      }
    } catch (_) {}
  }

  Future<void> loadTopProducts() async {
    _isLoadingTopProducts = true;
    notifyListeners();

    try {
      final queryParams = <String, String>{};
      if (_selectedToBranch != null) queryParams['branch_id'] = _selectedToBranch!.id.toString();
      if (_selectedFromBranch != null) queryParams['from_branch_id'] = _selectedFromBranch!.id.toString();

      final res = await _api.get('/api/v1/orders/top-products/', queryParams: queryParams);
      if (res is Map<String, dynamic>) {
        final rawList = res['products'] as List<dynamic>? ?? [];
        _topProducts = rawList
            .whereType<Map<String, dynamic>>()
            .map((p) => ProductModel.fromJson(p))
            .toList();
      }
    } catch (_) {
      // If endpoint fails, fallback to first 10 catalog products
      if (_allProducts.isNotEmpty) {
        _topProducts = _allProducts.take(10).toList();
      }
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
      _errorMessage = 'يرجى تحديد الفرع الطالب والفرع المستلم.';
      notifyListeners();
      return false;
    }

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final payload = {
        'from_branch_id': _selectedFromBranch!.id,
        'to_branch_id': _selectedToBranch!.id,
        'type': _orderType,
        'general_note': _generalNote,
        'items': _cart.values.map((item) => item.toApiPayload()).toList(),
      };

      final res = await _api.post('/api/v1/orders/create/', body: payload);
      if (res is Map<String, dynamic> && res['ok'] == true) {
        clearCart();
        _isSubmitting = false;
        notifyListeners();
        // Refresh orders list
        loadOrdersList();
        return true;
      }

      throw ApiException(res['error']?.toString() ?? 'فشل رفع الطلب.');
    } catch (e) {
      _errorMessage = e.toString();
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> loadOrdersList() async {
    _isLoadingOrders = true;
    notifyListeners();

    try {
      final res = await _api.get('/api/v1/orders/list/');
      if (res is Map<String, dynamic>) {
        final rawOrders = res['orders'] as List<dynamic>? ?? [];
        _recentOrders = rawOrders
            .whereType<Map<String, dynamic>>()
            .map((o) => OrderModel.fromJson(o))
            .toList();
      }
    } catch (_) {} finally {
      _isLoadingOrders = false;
      notifyListeners();
    }
  }
}
