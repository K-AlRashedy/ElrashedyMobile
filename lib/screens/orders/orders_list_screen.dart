import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../models/order_model.dart';
import '../../providers/order_provider.dart';
import 'create_order_screen.dart';
import 'order_detail_screen.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  String _filter = 'all'; // 'all', 'open', 'locked'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderProvider>().loadOrdersList();
    });
  }

  void _showOrderDetails(OrderModel order) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(orderId: order.id),
      ),
    ).then((_) {
      if (mounted) context.read<OrderProvider>().loadOrdersList();
    });
  }

  Widget _buildStatusBadge(String status) {
    Color bg = AppColors.success.withOpacity(0.12);
    Color fg = AppColors.success;
    String label = 'معتمد';

    if (status == 'locked') {
      bg = AppColors.error.withOpacity(0.12);
      fg = AppColors.error;
      label = 'مغلق';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final allOrders = orderProvider.recentOrders;
    final orders = allOrders.where((o) {
      if (_filter == 'open') return o.status != 'locked';
      if (_filter == 'locked') return o.status == 'locked';
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('سجل الطلبات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: () => orderProvider.loadOrdersList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
        label: const Text(
          'طلب جديد',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: Colors.white),
        ),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
          );
        },
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Text(
                  'التصفية:',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 10),
                ChoiceChip(
                  label: const Text('الكل', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                  selected: _filter == 'all',
                  onSelected: (_) => setState(() => _filter = 'all'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('مفتوح للعمليات', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                  selected: _filter == 'open',
                  onSelected: (_) => setState(() => _filter = 'open'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: const Text('مغلق 🔒', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                  selected: _filter == 'locked',
                  onSelected: (_) => setState(() => _filter = 'locked'),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Orders List Body
          Expanded(
            child: orderProvider.isLoadingOrders
                ? const Center(child: CircularProgressIndicator())
                : orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.primary),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'لا توجد طلبات مسجلة',
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => orderProvider.loadOrdersList(),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: orders.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (ctx, i) {
                            final order = orders[i];
                            return Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              elevation: 1,
                              child: InkWell(
                                onTap: () => _showOrderDetails(order),
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryLight,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                                              ),
                                              const SizedBox(width: 10),
                                              Text(
                                                'طلب #${order.id}',
                                                style: const TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          _buildStatusBadge(order.status),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          const Icon(Icons.storefront_rounded, size: 14, color: AppColors.textSecondary),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'من: ${order.fromBranchName} ➔ إلى: ${order.toBranchName}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            '${order.itemsCount} أصناف في الطلب',
                                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            order.datetime,
                                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
