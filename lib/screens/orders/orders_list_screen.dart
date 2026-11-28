import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../core/pagination.dart';
import '../../models/order_model.dart';
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
  late final PaginationController<OrderModel> _pagination;
  String _filter = 'open';

  @override
  void initState() {
    super.initState();
    _pagination = PaginationController<OrderModel>(_fetchOrdersPage);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _pagination.dispose();
    super.dispose();
  }

  Future<PageResult<OrderModel>> _fetchOrdersPage(int page, Map<String, dynamic> filters) async {
    final apiFilters = Map<String, dynamic>.from(filters);
    if (apiFilters['direction'] == 'review') apiFilters['direction'] = 'all';
    final response = await context.read<ApiClient>().get('/api/v1/orders/list/', queryParams: {
      ...apiFilters,
      'page': page,
    });
    return PageResult.fromResponse(response, 'orders', OrderModel.fromJson);
  }

  Future<void> _load() {
    final isReview = widget.direction == 'review';
    if (isReview) {
      final revStatus = switch (_filter) {
        'open' => 'notLocked',
        'locked' => 'locked',
        _ => null,
      };
      return _pagination.replaceFilters({
        'direction': 'review',
        if (revStatus != null) 'rev_status': revStatus,
        'include_locked': true,
      });
    }

    final status = switch (_filter) {
      'locked' => 'locked',
      'open' => 'approved',
      _ => null,
    };
    return _pagination.replaceFilters({
      'direction': widget.direction,
      if (status != null) 'status': status,
      if (_filter == 'locked' || _filter == 'all') 'include_locked': true,
    });
  }

  Future<void> _showOrderDetails(OrderModel order) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: order.id)),
    );
    if (mounted) await _pagination.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isIncoming = widget.direction == 'incoming';
    final isReview = widget.direction == 'review';

    final filterChips = isReview
        ? const [
            ('open', 'بانتظار المراجعة'),
            ('locked', 'تمت المراجعة'),
            ('all', 'الكل'),
          ]
        : const [
            ('open', 'مفتوح للعمليات'),
            ('locked', 'مغلق'),
            ('all', 'الكل'),
          ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _pagination.refresh,
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
                if (mounted) await _pagination.refresh();
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
                  for (final entry in filterChips) ...[
                    FilterChip(
                      label: Text(entry.$2, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5)),
                      selected: _filter == entry.$1,
                      selectedColor: AppColors.primaryLight,
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontFamily: 'Cairo',
                        color: _filter == entry.$1 ? AppColors.primaryDark : AppColors.textPrimary,
                        fontWeight: _filter == entry.$1 ? FontWeight.bold : FontWeight.w600,
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
          const Divider(height: 1),
          Expanded(
            child: PagedListView<OrderModel>(
              controller: _pagination,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 92),
              emptyMessage: _filter == 'all' ? 'لا توجد طلبات مسجلة.' : 'لا توجد طلبات مطابقة لهذه الحالة.',
              emptyIcon: Icons.receipt_long_outlined,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, order) => _OrderCard(
                order: order,
                incoming: isIncoming,
                reviewMode: isReview,
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
  final bool reviewMode;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.incoming,
    required this.reviewMode,
    required this.onTap,
  });

  String _formatDateTime(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d • $hh:$mm';
  }

  @override
  Widget build(BuildContext context) {
    final sendLocked = order.sendStatus == 'locked';
    final receiveLocked = order.receiveStatus == 'locked';
    final revLocked = order.revStatus == 'locked';

    final String badgeLabel;
    final Color badgeColor;
    final IconData badgeIcon;

    if (reviewMode) {
      badgeLabel = revLocked ? 'تمت المراجعة' : 'بانتظار المراجعة';
      badgeColor = revLocked ? AppColors.success : AppColors.warning;
      badgeIcon = revLocked ? Icons.verified_rounded : Icons.rate_review_outlined;
    } else if (incoming) {
      badgeLabel = receiveLocked ? 'استلام مغلق' : 'استلام مفتوح';
      badgeColor = receiveLocked ? AppColors.danger : AppColors.success;
      badgeIcon = receiveLocked ? Icons.lock_rounded : Icons.lock_open_rounded;
    } else {
      badgeLabel = (sendLocked && receiveLocked)
          ? 'مغلق بالكامل'
          : sendLocked
              ? 'صرف مغلق'
              : 'مفتوح للعمليات';
      badgeColor = (sendLocked && receiveLocked)
          ? AppColors.danger
          : sendLocked
              ? AppColors.warning
              : AppColors.success;
      badgeIcon = (sendLocked || receiveLocked) ? Icons.lock_rounded : Icons.lock_open_rounded;
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('طلب #${order.id}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w800)),
                        Text(
                          _formatDateTime(order.datetime),
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  AppStatusBadge(label: badgeLabel, color: badgeColor, icon: badgeIcon),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.call_received_rounded, size: 15, color: AppColors.primary),
                        const SizedBox(width: 6),
                        const Text('المستلم: ', style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.textSecondary)),
                        Expanded(
                          child: Text(
                            order.fromBranchName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.local_shipping_outlined, size: 15, color: AppColors.info),
                        const SizedBox(width: 6),
                        const Text('المورد: ', style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.textSecondary)),
                        Expanded(
                          child: Text(
                            order.toBranchName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 15, color: AppColors.primary),
                  const SizedBox(width: 5),
                  Text(
                    '${order.itemsCount} أصناف',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  const Spacer(),
                  if (order.user.isNotEmpty)
                    Flexible(
                      child: Text(
                        order.user,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                    ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_left_rounded, size: 18, color: AppColors.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
