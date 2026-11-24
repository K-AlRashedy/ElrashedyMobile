import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/async_views.dart';

class POSScreen extends StatefulWidget {
  const POSScreen({super.key});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final _api = ApiClient();
  bool _isLoading = true;
  String? _error;

  List<dynamic> _branches = [];
  int? _selectedBranchId;
  List<dynamic> _products = [];
  String _selectedCategory = 'الكل';
  String _searchQuery = '';

  // Cart
  final Map<int, int> _cart = {}; // product_id -> qty
  String _orderType = 'takeaway'; // takeaway, dine_in, delivery
  String _paymentMethod = 'cash'; // cash, visa, instapay, wallet
  final _customerPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _api.setBaseUrl(auth.serverUrl);
    _api.setToken(auth.token);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.get('/api/v1/pos/bootstrap/');
      if (res is Map<String, dynamic> && mounted) {
        final branches = res['branches'] as List<dynamic>? ?? [];
        final prods = res['products'] as List<dynamic>? ?? [];
        setState(() {
          _branches = branches;
          if (branches.isNotEmpty) {
            _selectedBranchId = branches.first['id'] as int?;
          }
          _products = prods;
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

  Future<void> _loadCatalog(int branchId) async {
    try {
      final res = await _api.get('/api/v1/pos/catalog/$branchId/');
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _products = res['products'] as List<dynamic>? ?? [];
        });
      }
    } catch (_) {}
  }

  double get _totalPrice {
    double total = 0;
    for (final entry in _cart.entries) {
      final p = _products.firstWhere((x) => x['id'] == entry.key, orElse: () => null);
      if (p != null) {
        final price = double.tryParse(p['price']?.toString() ?? '0') ?? 0;
        total += price * entry.value;
      }
    }
    return total;
  }

  Future<void> _submitTicket() async {
    if (_cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('السلة فارغة. أضف أصنافاً أولاً', style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }
    final items = _cart.entries.map((e) => {
      'product_id': e.key,
      'quantity': e.value,
    }).toList();

    try {
      await _api.post('/api/v1/pos/ticket/', body: {
        'branch_id': _selectedBranchId,
        'order_type': _orderType,
        'payment_method': _paymentMethod,
        'items': items,
        'customer_phone': _customerPhoneController.text.trim(),
      });
      if (mounted) {
        setState(() => _cart.clear());
        _customerPhoneController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل الطلب وإصدار الفاتورة بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  void _showShiftCloseDialog() {
    final passwordController = TextEditingController();
    String selectedShift = 'day';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDialogState) => AlertDialog(
          title: const Text('تقفيل الوردية الحالية', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'نوع الوردية'),
                value: selectedShift,
                items: const [
                  DropdownMenuItem(value: 'day', child: Text('وردية نهارية', style: TextStyle(fontFamily: 'Cairo'))),
                  DropdownMenuItem(value: 'night', child: Text('وردية ليلية', style: TextStyle(fontFamily: 'Cairo'))),
                ],
                onChanged: (val) => setDialogState(() => selectedShift = val ?? 'day'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'تأكيد كلمة مرور الكاشير', prefixIcon: Icon(Icons.lock_outline)),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (passwordController.text.trim().isEmpty) return;
                      setDialogState(() => isSubmitting = true);
                      try {
                        await _api.post('/api/v1/pos/shift/close/', body: {
                          'branch': _selectedBranchId,
                          'shift': selectedShift,
                          'password': passwordController.text.trim(),
                        });
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم تقفيل الوردية بنجاح وإرسالها للمراجعة', style: TextStyle(fontFamily: 'Cairo'))),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
              child: const Text('تقفيل الوردية', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = {'الكل', ..._products.map((p) => p['category_name']?.toString() ?? 'أخرى')}.toList();
    final filtered = _products.where((p) {
      final name = p['name']?.toString().toLowerCase() ?? '';
      final cat = p['category_name']?.toString() ?? 'أخرى';
      final matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());
      final matchesCat = _selectedCategory == 'الكل' || cat == _selectedCategory;
      return matchesSearch && matchesCat;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('نقطة البيع (الكاشير السريع)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.lock_clock_outlined),
            tooltip: 'تقفيل الوردية',
            onPressed: _showShiftCloseDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _bootstrap,
          ),
        ],
      ),
      body: _isLoading
          ? const AppLoadingView(message: 'جاري تهيئة الكاشير...')
          : _error != null
              ? AppErrorView(message: _error!, onRetry: _bootstrap)
              : Column(
                  children: [
                    // Branch Selector & Order Type
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedBranchId,
                                isExpanded: true,
                                items: _branches.map<DropdownMenuItem<int>>((b) {
                                  return DropdownMenuItem<int>(
                                    value: b['id'] as int,
                                    child: Text(b['name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13)),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() {
                                      _selectedBranchId = val;
                                      _cart.clear();
                                    });
                                    _loadCatalog(val);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(value: 'takeaway', label: Text('تيك أواي', style: TextStyle(fontFamily: 'Cairo', fontSize: 11))),
                              ButtonSegment(value: 'dine_in', label: Text('صالة', style: TextStyle(fontFamily: 'Cairo', fontSize: 11))),
                              ButtonSegment(value: 'delivery', label: Text('توصيل', style: TextStyle(fontFamily: 'Cairo', fontSize: 11))),
                            ],
                            selected: {_orderType},
                            onSelectionChanged: (val) => setState(() => _orderType = val.first),
                          ),
                        ],
                      ),
                    ),

                    // Search & Categories
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'ابحث عن صنف...',
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 6),
                        itemBuilder: (ctx, i) {
                          final cat = categories[i];
                          final isSelected = cat == _selectedCategory;
                          return ChoiceChip(
                            label: Text(cat, style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isSelected ? Colors.white : AppColors.textPrimary)),
                            selected: isSelected,
                            selectedColor: AppColors.primary,
                            onSelected: (_) => setState(() => _selectedCategory = cat),
                          );
                        },
                      ),
                    ),

                    // Products Grid
                    Expanded(
                      child: filtered.isEmpty
                          ? const AppEmptyView(title: 'لا توجد أصناف مطابقة', icon: Icons.inventory_2_outlined)
                          : GridView.builder(
                              padding: const EdgeInsets.all(12),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 1.3,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (ctx, i) {
                                final p = filtered[i] as Map<String, dynamic>;
                                final id = p['id'] as int;
                                final qtyInCart = _cart[id] ?? 0;
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _cart[id] = qtyInCart + 1;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(16),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: qtyInCart > 0 ? AppColors.primary : AppColors.border, width: qtyInCart > 0 ? 2 : 1),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                p['name']?.toString() ?? '',
                                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (qtyInCart > 0)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                                                child: Text('$qtyInCart', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                              ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${p['price']} ج.م',
                                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                                            ),
                                            if (qtyInCart > 0)
                                              InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    if (qtyInCart <= 1) {
                                                      _cart.remove(id);
                                                    } else {
                                                      _cart[id] = qtyInCart - 1;
                                                    }
                                                  });
                                                },
                                                child: const Icon(Icons.remove_circle_outline, color: AppColors.error, size: 22),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    // Bottom Summary Bar
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -3))],
                      ),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('إجمالي الطلب: ${_totalPrice.toStringAsFixed(2)} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                              Text('${_cart.length} صنف بالسلة', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.success,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            icon: const Icon(Icons.check_circle_rounded),
                            label: const Text('دفع وإصدار الفاتورة', style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
                            onPressed: _cart.isEmpty ? null : _submitTicket,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
