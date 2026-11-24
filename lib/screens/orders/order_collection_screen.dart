import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../core/pagination.dart';
import '../../models/branch_model.dart';
import '../../widgets/async_views.dart';

class CollectionItem {
  final int productId;
  final String productName;
  final double requested;
  final double sent;
  final double remaining;

  const CollectionItem({
    required this.productId,
    required this.productName,
    required this.requested,
    required this.sent,
    required this.remaining,
  });

  factory CollectionItem.fromJson(Map<String, dynamic> json) => CollectionItem(
    productId: json['product_id'] as int? ?? 0,
    productName: json['product_name']?.toString() ?? '',
    requested: _number(json['requested']),
    sent: _number(json['sent']),
    remaining: _number(json['remaining']),
  );

  static double _number(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0;
}

class OrderCollectionScreen extends StatefulWidget {
  const OrderCollectionScreen({super.key});

  @override
  State<OrderCollectionScreen> createState() => _OrderCollectionScreenState();
}

class _OrderCollectionScreenState extends State<OrderCollectionScreen> {
  late final PaginationController<CollectionItem> _pagination;
  List<BranchModel> _branches = const [];
  BranchModel? _selectedBranch;
  BranchModel? _targetBranch;
  List<Map<String, dynamic>> _notes = const [];
  int? _branchId;

  @override
  void initState() {
    super.initState();
    _pagination = PaginationController<CollectionItem>(_fetchPage);
    WidgetsBinding.instance.addPostFrameCallback((_) => _pagination.refresh());
  }

  @override
  void dispose() {
    _pagination.dispose();
    super.dispose();
  }

  Future<PageResult<CollectionItem>> _fetchPage(int page, Map<String, dynamic> filters) async {
    final response = await context.read<ApiClient>().get('/api/v1/orders/collection/', queryParams: {
      ...filters,
      'page': page,
    });
    if (response is! Map<String, dynamic>) throw const FormatException('بيانات التجميع غير صالحة.');
    final rawBranches = response['branches'] as List<dynamic>? ?? const [];
    final branches = rawBranches.whereType<Map<String, dynamic>>().map(BranchModel.fromJson).toList();
    if (!mounted) throw ApiException('تم إلغاء الطلب.');
    setState(() {
      _branches = branches;
      final selected = response['selected_branch'];
      final target = response['target_branch'];
      _selectedBranch = selected is Map<String, dynamic> ? BranchModel.fromJson(selected) : null;
      _branchId ??= _selectedBranch?.id;
      _targetBranch = target is Map<String, dynamic> ? BranchModel.fromJson(target) : null;
      _notes = (response['notes'] as List<dynamic>? ?? const []).whereType<Map<String, dynamic>>().toList();
    });
    return PageResult.fromResponse(response, 'products', CollectionItem.fromJson);
  }

  Future<void> _selectBranch(int? branchId) async {
    if (branchId == null) return;
    final branch = _branches.firstWhere((branch) => branch.id == branchId);
    setState(() {
      _selectedBranch = branch;
      _branchId = branchId;
    });
    await _pagination.replaceFilters({'branch_id': branchId});
  }

  @override
  Widget build(BuildContext context) {
    final requested = _pagination.items.fold<double>(0, (sum, item) => sum + item.requested);
    final sent = _pagination.items.fold<double>(0, (sum, item) => sum + item.sent);
    final remaining = _pagination.items.fold<double>(0, (sum, item) => sum + item.remaining);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('التجميعة العامة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: _pagination.refresh, icon: const Icon(Icons.refresh_rounded))],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _branchId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'الفرع المجمع', border: OutlineInputBorder(), isDense: true),
                  items: [for (final branch in _branches) DropdownMenuItem(value: branch.id, child: Text(branch.name, style: const TextStyle(fontFamily: 'Cairo')))],
                  onChanged: _selectBranch,
                ),
                if (_targetBranch != null) ...[
                  const SizedBox(height: 8),
                  Text('يتم التجميع لحساب: ${_targetBranch!.name}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                _summary('المطلوب', requested, AppColors.textPrimary),
                _summary('المنصرف', sent, AppColors.info),
                _summary('المتبقي', remaining, AppColors.primary),
              ],
            ),
          ),
          Expanded(
            child: PagedListView<CollectionItem>(
              controller: _pagination,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              emptyMessage: 'لا توجد أصناف معلقة في التجميعة.',
              emptyIcon: Icons.account_tree_outlined,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, item) => Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(item.productName, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _summary('مطلوب', item.requested, AppColors.textSecondary),
                        _summary('منصرف', item.sent, AppColors.info),
                        _summary('متبقي', item.remaining, AppColors.primary),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_notes.isNotEmpty)
            ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 20),
              title: Text('ملاحظات الطلبات (${_notes.length})', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold)),
              children: [
                for (final note in _notes)
                  ListTile(
                    dense: true,
                    title: Text('${note['product_name']} • طلب #${note['order_id']}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                    subtitle: Text('${note['requesting_branch']?['name'] ?? ''}\n${note['note'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11)),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _summary(String label, double value, Color color) => Expanded(
    child: Column(
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textSecondary)),
        const SizedBox(height: 3),
        Text(value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2), style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    ),
  );
}
