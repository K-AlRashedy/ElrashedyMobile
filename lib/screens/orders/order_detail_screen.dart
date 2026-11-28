import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/async_views.dart';
import '../../widgets/fast_quantity_dial_sheet.dart';
import '../../widgets/numeric_keypad_sheet.dart';
import 'edit_order_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final _uuid = const Uuid();
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _orderData;
  bool _isProcessingAction = false;

  @override
  void initState() {
    super.initState();
    _loadOrderDetail();
  }

  Future<void> _loadOrderDetail() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = context.read<ApiClient>();
      final res = await api.get('/api/v1/orders/${widget.orderId}/');
      if (res is Map<String, dynamic> && res['order'] is Map<String, dynamic>) {
        if (mounted) {
          setState(() {
            _orderData = Map<String, dynamic>.from(res['order'] as Map);
          });
        }
      } else {
        throw const FormatException('بيانات الطلب غير صالحة.');
      }
    } catch (e) {
      if (mounted) _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _disburseItem(int itemId, double sentValue) async {
    setState(() => _isProcessingAction = true);
    try {
      final api = context.read<ApiClient>();
      final res = await api.post(
        '/api/v1/orders/disburse/',
        idempotencyKey: _uuid.v4(),
        body: {
          'order_id': widget.orderId,
          'item_id': itemId,
          'sent': sentValue,
        },
      );
      if (res is Map<String, dynamic>) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          AppFeedback.showSuccess(context, res['message']?.toString() ?? 'تم تسجيل الصرف بنجاح');
          await _loadOrderDetail();
        }
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, '$e');
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _disburseAll() async {
    final confirm = await AppConfirmDialog.show(
      context,
      title: 'صرف جميع الأصناف بالكامل؟',
      message: 'سيتم صرف الكميات المطلوبة بالكامل لجميع أصناف الطلب المتبقية وخصمها من مخزن الفرع المورد.',
      confirmLabel: 'تأكيد وصرف الكل ⚡',
    );
    if (!confirm) return;

    setState(() => _isProcessingAction = true);
    try {
      final api = context.read<ApiClient>();
      final res = await api.post(
        '/api/v1/orders/disburse/',
        idempotencyKey: _uuid.v4(),
        body: {'order_id': widget.orderId, 'all_requested': true},
      );
      if (res is Map<String, dynamic>) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          AppFeedback.showSuccess(context, res['message']?.toString() ?? 'تم صرف جميع الأصناف بالكامل');
          await _loadOrderDetail();
        }
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, '$e');
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _cancelSent(int itemId) async {
    final confirm = await AppConfirmDialog.show(
      context,
      title: 'إلغاء الصرف؟',
      message: 'سيتم إلغاء صرف هذا الصنف وإرجاع الكمية المنصرفة لمخزون الفرع المورد.',
      confirmLabel: 'إلغاء الصرف',
      isDestructive: true,
    );
    if (!confirm) return;

    setState(() => _isProcessingAction = true);
    try {
      final api = context.read<ApiClient>();
      final res = await api.post(
        '/api/v1/orders/cancel-sent/',
        idempotencyKey: _uuid.v4(),
        body: {'order_id': widget.orderId, 'item_id': itemId},
      );
      if (res is Map<String, dynamic>) {
        HapticFeedback.mediumImpact();
        if (mounted) {
          AppFeedback.showSuccess(context, res['message']?.toString() ?? 'تم إلغاء الصرف وإعادة الكمية');
          await _loadOrderDetail();
        }
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, '$e');
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _receiveItem({int? itemId, bool allSent = false}) async {
    setState(() => _isProcessingAction = true);
    try {
      final api = context.read<ApiClient>();
      final res = await api.post(
        '/api/v1/orders/receive/',
        idempotencyKey: _uuid.v4(),
        body: {
          'order_id': widget.orderId,
          if (itemId != null) 'item_id': itemId,
          'all_sent': allSent,
        },
      );
      if (res is Map<String, dynamic>) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          AppFeedback.showSuccess(context, res['message']?.toString() ?? 'تم تأكيد الاستلام بنجاح');
          await _loadOrderDetail();
        }
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, '$e');
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _lockOrder(String side) async {
    final title = side == 'send' ? 'قفل إذن الصرف' : 'قفل إذن الاستلام';
    final confirm = await AppConfirmDialog.show(
      context,
      title: '$title؟',
      message: side == 'send'
          ? 'هل تريد قفل مرحلة الصرف؟ لن يمكن تعديل الكميات المنصرفة بعد القفل إلا بإعادة فتح الطلب.'
          : 'هل تريد قفل مرحلة الاستلام وتأكيد إغلاق الطلب نهائياً؟',
      confirmLabel: 'قفل الطلب 🔒',
    );
    if (!confirm) return;

    setState(() => _isProcessingAction = true);
    try {
      final api = context.read<ApiClient>();
      final res = await api.post(
        '/api/v1/orders/lock/',
        idempotencyKey: _uuid.v4(),
        body: {'order_id': widget.orderId, 'side': side},
      );
      if (res is Map<String, dynamic>) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          AppFeedback.showSuccess(
            context,
            side == 'send' ? 'تم قفل مرحلة الصرف بنجاح' : 'تم قفل مرحلة الاستلام وإغلاق الطلب',
          );
          await _loadOrderDetail();
        }
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, '$e');
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _unlockOrder(String side) async {
    final title = side == 'send' ? 'إعادة فتح مرحلة الصرف؟' : 'إعادة فتح مرحلة الاستلام؟';
    final confirm = await AppConfirmDialog.show(
      context,
      title: title,
      message: 'سيتم إعادة فتح المرحلة المحددة لتكون متاحة للعمليات مجدداً.',
      confirmLabel: 'إعادة فتح 🔓',
    );
    if (!confirm) return;

    setState(() => _isProcessingAction = true);
    try {
      final api = context.read<ApiClient>();
      final res = await api.post(
        '/api/v1/orders/unlock/',
        idempotencyKey: _uuid.v4(),
        body: {'order_id': widget.orderId, 'side': side},
      );
      if (res is Map<String, dynamic>) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          AppFeedback.showSuccess(
            context,
            side == 'send' ? 'تمت إعادة فتح مرحلة الصرف' : 'تمت إعادة فتح مرحلة الاستلام',
          );
          await _loadOrderDetail();
        }
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, '$e');
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _reviewLockOrder() async {
    final confirm = await AppConfirmDialog.show(
      context,
      title: 'اعتماد مراجعة الطلب؟',
      message: 'سيتم تسجيل الطلب كطلب مراجَع ومعتمد.',
      confirmLabel: 'اعتماد المراجعة ✓',
    );
    if (!confirm) return;

    setState(() => _isProcessingAction = true);
    try {
      await context.read<ApiClient>().post(
        '/api/v1/orders/${widget.orderId}/review/',
        idempotencyKey: _uuid.v4(),
        body: const {},
      );
      if (mounted) {
        HapticFeedback.heavyImpact();
        AppFeedback.showSuccess(context, 'تم اعتماد مراجعة الطلب بنجاح');
        await _loadOrderDetail();
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, '$e');
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _deleteOrder() async {
    final confirm = await AppConfirmDialog.show(
      context,
      title: 'حذف الطلب؟',
      message: 'سيتم حذف الطلب وأصنافه نهائياً. لا يمكن التراجع عن هذا الإجراء.',
      confirmLabel: 'حذف نهائي',
      isDestructive: true,
    );
    if (!confirm) return;

    setState(() => _isProcessingAction = true);
    try {
      final response = await context.read<ApiClient>().post(
        '/api/v1/orders/delete/${widget.orderId}/',
        body: const {},
        idempotencyKey: _uuid.v4(),
      );
      if (response is Map<String, dynamic> && mounted) {
        AppFeedback.showSuccess(context, 'تم حذف الطلب بنجاح');
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) AppFeedback.showError(context, '$error');
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _openDialpadForDisburse(Map<String, dynamic> item) async {
    final pName = item['product_name']?.toString() ?? 'الصنف';
    final pUnit = item['unit']?.toString() ?? 'وحدة';
    final requested = (item['requested'] as num?)?.toDouble() ?? 0.0;
    final sent = (item['sent'] as num?)?.toDouble() ?? 0.0;
    final initial = sent > 0 ? sent : requested;

    final result = await FastQuantityDialSheet.show(
      context,
      title: 'صرف: $pName',
      unit: pUnit,
      initialValue: initial,
      requestedValue: requested,
      allowZero: false,
      maxValue: requested > 0 ? requested : null,
    );

    if (result != null && result > 0 && mounted) {
      _disburseItem(item['id'] as int, result);
    }
  }

  String _formatDt(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return iso;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} • ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text('طلب #${widget.orderId}')),
        body: const AppLoadingView(message: 'جاري تحميل تفاصيل الطلب...'),
      );
    }

    if (_error != null || _orderData == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text('طلب #${widget.orderId}')),
        body: AppErrorView(
          message: _error ?? 'تعذر تحميل بيانات الطلب',
          onRetry: _loadOrderDetail,
        ),
      );
    }

    final o = _orderData!;
    final fromBranch = o['from_branch']?['name']?.toString() ?? 'غير محدد';
    final toBranch = o['to_branch']?['name']?.toString() ?? 'غير محدد';
    final dt = _formatDt(o['datetime']?.toString() ?? '');
    final issuer = o['user']?.toString() ?? '';
    final isSendLocked = o['is_send_locked'] == true;
    final isReceiveLocked = o['is_receive_locked'] == true;
    final isReviewLocked = o['rev_status'] == 'locked';
    final perms = o['perms'] as Map<String, dynamic>? ?? {};
    final canDisburse = perms['can_disburse'] == true;
    final canReceive = perms['can_receive'] == true;
    final canCancelSent = perms['can_cancel_sent'] == true;
    final canLockSend = perms['can_lock_send'] == true;
    final canLockReceive = perms['can_lock_receive'] == true;
    final canUnlockSend = perms['can_unlock_send'] == true;
    final canUnlockReceive = perms['can_unlock_receive'] == true;
    final canLockAny = perms['can_lock'] == true;
    final canUpdate = perms['can_update'] == true;
    final canDelete = perms['can_delete'] == true;
    final canReview = !isReviewLocked && (canLockAny || canUpdate || canDisburse || canReceive);

    final items = (o['items'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();
    final hasUndisbursed = items.any((i) => i['is_disbursed'] != true);
    final hasUnreceived = items.any((i) => i['is_disbursed'] == true && i['is_received'] != true);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('تفاصيل طلب #${widget.orderId}'),
        actions: [
          if (_isProcessingAction)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.primary)),
              ),
            )
          else
            IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث', onPressed: _loadOrderDetail),
          if (canUpdate || canDelete)
            PopupMenuButton<String>(
              tooltip: 'إجراءات الطلب',
              enabled: !_isProcessingAction,
              onSelected: (action) async {
                if (action == 'update') {
                  final changed = await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => EditOrderScreen(orderId: widget.orderId)),
                  );
                  if (changed == true && mounted) await _loadOrderDetail();
                } else if (action == 'delete') {
                  await _deleteOrder();
                }
              },
              itemBuilder: (_) => [
                if (canUpdate)
                  const PopupMenuItem(
                    value: 'update',
                    child: Row(children: [Icon(Icons.edit_outlined, size: 19), SizedBox(width: 10), Text('تعديل الأصناف', style: TextStyle(fontFamily: 'Cairo'))]),
                  ),
                if (canDelete)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(children: [Icon(Icons.delete_outline_rounded, size: 19, color: AppColors.danger), SizedBox(width: 10), Text('حذف الطلب', style: TextStyle(fontFamily: 'Cairo', color: AppColors.danger))]),
                  ),
              ],
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadOrderDetail,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Order Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            'طلب #${widget.orderId}',
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            issuer.isNotEmpty ? '$issuer • $dt' : dt,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('الفرع الطالب (المستلم):', style: TextStyle(fontFamily: 'Cairo', fontSize: 10.5, color: AppColors.textSecondary)),
                                Text(fromBranch, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13.5, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
                              child: const Icon(Icons.arrow_forward_rounded, size: 15, color: AppColors.primary),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('الفرع المورد (المُصدر):', style: TextStyle(fontFamily: 'Cairo', fontSize: 10.5, color: AppColors.textSecondary)),
                                Text(toBranch, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13.5, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildStatusPill(label: 'الصرف', isLocked: isSendLocked, icon: isSendLocked ? Icons.lock_rounded : Icons.lock_open_rounded)),
                        Container(width: 1, height: 24, color: AppColors.border),
                        Expanded(child: _buildStatusPill(label: 'الاستلام', isLocked: isReceiveLocked, icon: isReceiveLocked ? Icons.lock_rounded : Icons.lock_open_rounded)),
                        Container(width: 1, height: 24, color: AppColors.border),
                        Expanded(child: _buildStatusPill(label: 'المراجعة', isLocked: isReviewLocked, icon: isReviewLocked ? Icons.verified_rounded : Icons.rate_review_outlined, positiveWhenLocked: true)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 2. Bulk Operations Bar
              if (canDisburse && !isSendLocked && hasUndisbursed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.flash_on_rounded, size: 20),
                    label: const Flexible(
                      child: Text(
                        'صرف جميع الأصناف بالكامل',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 14.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    onPressed: _isProcessingAction ? null : _disburseAll,
                  ),
                ),

              if (canReceive && !isReceiveLocked && hasUnreceived)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.info),
                    icon: const Icon(Icons.done_all_rounded, size: 20),
                    label: const Flexible(
                      child: Text(
                        'استلام جميع الأصناف المنصرفة',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 14.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    onPressed: _isProcessingAction ? null : () => _receiveItem(allSent: true),
                  ),
                ),

              if (canLockSend || canLockReceive || canUnlockSend || canUnlockReceive || canReview)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (canLockSend && !isSendLocked)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.secondary, side: const BorderSide(color: AppColors.secondary)),
                        icon: const Icon(Icons.lock_outline_rounded, size: 17),
                        label: const Text('قفل الصرف'),
                        onPressed: _isProcessingAction ? null : () => _lockOrder('send'),
                      ),
                    if (canLockReceive && !isReceiveLocked && isSendLocked)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: AppColors.secondary, side: const BorderSide(color: AppColors.secondary)),
                        icon: const Icon(Icons.lock_rounded, size: 17),
                        label: const Text('قفل الاستلام'),
                        onPressed: _isProcessingAction ? null : () => _lockOrder('receive'),
                      ),
                    if (canUnlockSend && isSendLocked)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                        icon: const Icon(Icons.lock_open_rounded, size: 17),
                        label: const Text('فتح الصرف'),
                        onPressed: _isProcessingAction ? null : () => _unlockOrder('send'),
                      ),
                    if (canUnlockReceive && isReceiveLocked)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning),
                        icon: const Icon(Icons.lock_open_rounded, size: 17),
                        label: const Text('فتح الاستلام'),
                        onPressed: _isProcessingAction ? null : () => _unlockOrder('receive'),
                      ),
                    if (canReview)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryDark),
                        icon: const Icon(Icons.fact_check_outlined, size: 17),
                        label: const Text('اعتماد المراجعة'),
                        onPressed: _isProcessingAction ? null : _reviewLockOrder,
                      ),
                  ],
                ),

              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('أصناف الطلب (${items.length})', style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),

              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final item = items[i];
                  final pName = item['product_name']?.toString() ?? 'صنف';
                  final pUnit = item['unit']?.toString() ?? 'وحدة';
                  final requested = (item['requested'] as num?)?.toDouble() ?? 0.0;
                  final sent = (item['sent'] as num?)?.toDouble() ?? 0.0;
                  final note = item['note']?.toString() ?? '';
                  final isDisbursed = item['is_disbursed'] == true;
                  final isReceived = item['is_received'] == true;

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isReceived
                            ? AppColors.primary.withValues(alpha: 0.5)
                            : isDisbursed
                                ? AppColors.info.withValues(alpha: 0.5)
                                : AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(pName, style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(6)),
                              child: Text(pUnit, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text('المطلوب', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary)),
                                    Text(AppNumericKeypadSheet.formatNumber(requested), style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                              Container(width: 1, height: 26, color: AppColors.border),
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text('المنصرف', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary)),
                                    Text(
                                      AppNumericKeypadSheet.formatNumber(sent),
                                      style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: sent > 0 ? AppColors.primary : AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Container(width: 1, height: 26, color: AppColors.border),
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text('الحالة', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary)),
                                    Text(
                                      isReceived ? 'مستلم ✓' : isDisbursed ? 'منصرف' : 'انتظار',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: isReceived ? AppColors.primary : isDisbursed ? AppColors.info : AppColors.warning,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (note.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.sticky_note_2_rounded, size: 14, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(child: Text(note, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.textSecondary))),
                            ],
                          ),
                        ],
                        if ((canDisburse && !isSendLocked && !isDisbursed) ||
                            (canReceive && !isReceiveLocked && isDisbursed && !isReceived) ||
                            (canCancelSent && !isSendLocked && isDisbursed && !isReceived)) ...[
                          const Divider(height: 18),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (canDisburse && !isSendLocked && !isDisbursed) ...[
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.dialpad_rounded, size: 16),
                                  label: const Text('صرف كمية مخصصة'),
                                  onPressed: _isProcessingAction ? null : () => _openDialpadForDisburse(item),
                                ),
                                ElevatedButton(
                                  onPressed: _isProcessingAction ? null : () => _disburseItem(item['id'] as int, requested),
                                  child: const Text('صرف كل المطلوب'),
                                ),
                              ],
                              if (canCancelSent && !isSendLocked && isDisbursed && !isReceived)
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, side: const BorderSide(color: AppColors.danger)),
                                  icon: const Icon(Icons.undo_rounded, size: 16),
                                  label: const Text('إلغاء الصرف'),
                                  onPressed: _isProcessingAction ? null : () => _cancelSent(item['id'] as int),
                                ),
                              if (canReceive && !isReceiveLocked && isDisbursed && !isReceived)
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.info),
                                  icon: const Icon(Icons.check_rounded, size: 16),
                                  label: const Text('تأكيد الاستلام'),
                                  onPressed: _isProcessingAction ? null : () => _receiveItem(itemId: item['id'] as int),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusPill({
    required String label,
    required bool isLocked,
    required IconData icon,
    bool positiveWhenLocked = false,
  }) {
    final color = positiveWhenLocked
        ? (isLocked ? AppColors.success : AppColors.warning)
        : (isLocked ? AppColors.danger : AppColors.success);
    final statusText = positiveWhenLocked
        ? (isLocked ? 'مراجَع ✓' : 'معلق')
        : (isLocked ? 'مغلق' : 'مفتوح');

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textSecondary)),
              Text(statusText, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.bold, color: color)),
            ],
          ),
        ),
      ],
    );
  }
}
