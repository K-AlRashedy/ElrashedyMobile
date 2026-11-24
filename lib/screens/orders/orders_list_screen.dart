import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../models/order_model.dart';
import '../../providers/order_provider.dart';
import '../../widgets/async_views.dart';
import 'create_order_screen.dart';
import 'order_detail_screen.dart';

class OrdersListScreen extends StatefulWidget {
  final String direction;
  final String title;

  const OrdersListScreen({
    super.key,
    this.direction = 'all',
    this.title = 'سجل الطلبات',
  });

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  String _filter = 'open';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() {
    final status = switch (_filter) {
      'locked' => 'locked',
      'open' => 'approved',
      _ => null,
    };
    return context.read<OrderProvider>().loadOrdersList(
      direction: widget.direction,
      status: status,
      includeLocked: widget.direction == 'review' || _filter == 'locked',
    );
  }

  Future<void> _showOrderDetails(OrderModel order) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
    );
    if (mounted) await context.read<OrderProvider>().refreshOrders();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrderProvider>();
    final pagination = provider.ordersPagination;
    final isIncoming = widget.direction == 'incoming';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: pagination.isLoading ? null : provider.refreshOrders,
          ),
        ],
      ),
      floatingActionButton: isIncoming
          ? null
          : FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_shopping_cart_rounded),
              label: const Text('طلب جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
                );
                if (mounted) await provider.refreshOrders();
              },
            ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final entry in const [
                    ('open', 'مفتوح للعمليات'),
                    ('locked', 'مغلق'),
                    ('all', 'الكل'),
                  ]) ...[
                    FilterChip(
                      label: Text(entry.$2, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                      selected: _filter == entry.$1,
                      selectedColor: AppColors.primaryLight,
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontFamily: 'Cairo',
                        color: _filter == entry.$1 ? AppColors.primaryDark : AppColors.textPrimary,
                        fontWeight: _filter == entry.$1 ? FontWeight.bold : FontWeight.normal,
                      ),
                      onSelected: (_) {
                        setState(() => _filter = entry.$1);
                        _load();
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Expanded(
            child: PagedListView<OrderModel>(
              controller: pagination,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
              emptyMessage: _filter == 'all' ? 'لا توجد طلبات مسجلة.' : 'لا توجد طلبات مطابقة لهذه الحالة.',
              emptyIcon: Icons.receipt_long_outlined,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, order) => _OrderCard(
                order: order,
                incoming: isIncoming,
                onTap: () => _showOrderDetails(order),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final bool incoming;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.incoming, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = incoming ? order.receiveStatus : order.sendStatus;
    final locked = status == 'locked';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 0.5,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 21),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'طلب #${order.id}',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  AppStatusBadge(
                    label: locked ? 'مغلق' : 'مفتوح',
                    color: locked ? AppColors.danger : AppColors.success,
                    icon: locked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_rounded, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'المستلم: ${order.fromBranchName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textPrimary),
                      ),
                    ),
                    const Icon(Icons.arrow_back_rounded, size: 15, color: AppColors.primary),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'المورد: ${order.toBranchName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(Icons.inventory_2_outlined, size: 14, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${order.itemsCount} أصناف',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      order.datetime,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
