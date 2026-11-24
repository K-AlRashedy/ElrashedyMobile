import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../widgets/fast_quantity_dial_sheet.dart';
import 'edit_order_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
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
      if (res is Map<String, dynamic> && res['order'] != null) {
        setState(() {
          _orderData = res['order'] as Map<String, dynamic>;
        });
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
      final res = await api.post('/api/v1/orders/disburse/', body: {
        'order_id': widget.orderId,
        'item_id': itemId,
        'sent': sentValue,
      });
      if (res is Map<String, dynamic> && res['ok'] == true) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message']?.toString() ?? 'تم الصرف بنجاح', style: const TextStyle(fontFamily: 'Cairo')),
              backgroundColor: AppColors.success,
            ),
          );
        }
        _loadOrderDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _disburseAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('صرف جميع الأصناف بالكامل؟', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: const Text(
          'سيتم صرف الكميات المطلوبة بالكامل لجميع أصناف الطلب وخصمها من مخزن الفرع المورد بضغطة واحدة.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('تأكيد وصرف الكل ⚡', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessingAction = true);
    try {
      final api = context.read<ApiClient>();
      final res = await api.post('/api/v1/orders/disburse/', body: {
        'order_id': widget.orderId,
        'all_requested': true,
      });
      if (res is Map<String, dynamic> && res['ok'] == true) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message']?.toString() ?? 'تم صرف جميع الأصناف بالكامل', style: const TextStyle(fontFamily: 'Cairo')),
              backgroundColor: AppColors.success,
            ),
          );
        }
        _loadOrderDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _cancelSent(int itemId) async {
    setState(() => _isProcessingAction = true);
    try {
      final api = context.read<ApiClient>();
      final res = await api.post('/api/v1/orders/cancel-sent/', body: {
        'order_id': widget.orderId,
        'item_id': itemId,
      });
      if (res is Map<String, dynamic> && res['ok'] == true) {
        HapticFeedback.mediumImpact();
        _loadOrderDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _receiveItem({int? itemId, bool allSent = false}) async {
    setState(() => _isProcessingAction = true);
    try {
      final api = context.read<ApiClient>();
      final res = await api.post('/api/v1/orders/receive/', body: {
        'order_id': widget.orderId,
        'item_id': itemId,
        'all_sent': allSent,
      });
      if (res is Map<String, dynamic> && res['ok'] == true) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message']?.toString() ?? 'تم تأكيد الاستلام بنجاح', style: const TextStyle(fontFamily: 'Cairo')),
              backgroundColor: AppColors.info,
            ),
          );
        }
        _loadOrderDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _lockOrder(String side) async {
    final title = side == 'send' ? 'قفل إذن الصرف' : 'قفل إذن الاستلام';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('$title؟', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: Text(
          side == 'send'
              ? 'هل تريد قفل مرحلة الصرف؟ لن يمكن تعديل الكميات المنصرفة بعد القفل إلا بإعادة فتح الطلب.'
              : 'هل تريد قفل مرحلة الاستلام وتأكيد إغلاق الطلب نهائياً؟',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('قفل الطلب 🔒', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessingAction = true);
    try {
      final api = context.read<ApiClient>();
      final res = await api.post('/api/v1/orders/lock/', body: {
        'order_id': widget.orderId,
        'side': side,
      });
      if (res is Map<String, dynamic> && res['ok'] == true) {
        HapticFeedback.heavyImpact();
        _loadOrderDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _unlockOrder(String side) async {
    final title = side == 'send' ? 'إعادة فتح مرحلة الصرف؟' : 'إعادة فتح مرحلة الاستلام؟';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: const Text(
          'سيتم إعادة فتح المرحلة المحددة لتكون متاحة للعمليات مجدداً.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('إعادة فتح 🔓', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isProcessingAction = true);
    try {
      final api = context.read<ApiClient>();
      final res = await api.post('/api/v1/orders/unlock/', body: {
        'order_id': widget.orderId,
        'side': side,
      });
      if (res is Map<String, dynamic> && res['ok'] == true) {
        HapticFeedback.heavyImpact();
        await _loadOrderDetail();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  Future<void> _deleteOrder() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('حذف الطلب؟', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        content: const Text(
          'سيتم حذف الطلب وأصنافه نهائياً. لا يمكن التراجع عن هذا الإجراء.',
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('حذف نهائي', style: TextStyle(fontFamily: 'Cairo', color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _isProcessingAction = true);
    try {
      final response = await context.read<ApiClient>().post(
        '/api/v1/orders/delete/${widget.orderId}/',
        body: const {},
        idempotencyKey: 'order-delete-${widget.orderId}-${DateTime.now().millisecondsSinceEpoch}',
      );
      if (response is Map<String, dynamic> && response['ok'] == true && mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $error', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingAction = false);
    }
  }

  void _openDialpadForDisburse(Map<String, dynamic> item) async {
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
    );

    if (result != null && mounted) {
      _disburseItem(item['id'] as int, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F8FA),
        appBar: AppBar(title: Text('طلب #${widget.orderId}')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _orderData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF6F8FA),
        appBar: AppBar(title: Text('طلب #${widget.orderId}')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 48),
                const SizedBox(height: 12),
                Text(_error ?? 'تعذر تحميل بيانات الطلب', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'Cairo')),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: _loadOrderDetail, child: const Text('إعادة المحاولة')),
              ],
            ),
          ),
        ),
      );
    }

    final o = _orderData!;
    final fromBranch = o['from_branch']?['name'] ?? 'غير محدد';
    final toBranch = o['to_branch']?['name'] ?? 'غير محدد';
    final dt = o['datetime'] ?? '';
    final issuer = o['user'] ?? 'مستخدم';
    final isSendLocked = o['is_send_locked'] == true;
    final isReceiveLocked = o['is_receive_locked'] == true;
    final perms = o['perms'] as Map<String, dynamic>? ?? {};
    final canDisburse = perms['can_disburse'] == true;
    final canReceive = perms['can_receive'] == true;
    final canCancelSent = perms['can_cancel_sent'] == true;
    final canLockSend = perms['can_lock_send'] == true;
    final canLockReceive = perms['can_lock_receive'] == true;
    final canUnlockSend = perms['can_unlock_send'] == true;
    final canUnlockReceive = perms['can_unlock_receive'] == true;
    final canUpdate = perms['can_update'] == true;
    final canDelete = perms['can_delete'] == true;
    final items = (o['items'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();

    final hasUndisbursed = items.any((i) => (i['sent'] as num?)?.toDouble() == 0.0);
    final hasUnreceived = items.any((i) => i['is_disbursed'] == true && i['is_received'] != true);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: Text('تفاصيل طلب #${widget.orderId}', style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (_isProcessingAction)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Order Header Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'طلب رقم #${widget.orderId}',
                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        issuer.isNotEmpty ? '$issuer • $dt' : dt,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Branches Direction Strip
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('الفرع الطالب (المستلم):', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textSecondary)),
                              Text(
                                fromBranch,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
                            child: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('الفرع المورد (المُصدر):', style: TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textSecondary)),
                              Text(
                                toBranch,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Lock States Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatusPill(
                        label: 'مرحلة الصرف',
                        isLocked: isSendLocked,
                        icon: isSendLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                      ),
                      Container(width: 1, height: 24, color: AppColors.border),
                      _buildStatusPill(
                        label: 'مرحلة الاستلام',
                        isLocked: isReceiveLocked,
                        icon: isReceiveLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 2. High-Priority Order Operations Bar
            if (canDisburse && !isSendLocked && hasUndisbursed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.flash_on_rounded, size: 20),
                  label: const Text(
                    '⚡ صرف جميع الأصناف بالكامل (بضغطة واحدة)',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isProcessingAction ? null : _disburseAll,
                ),
              ),

            if (canReceive && !isReceiveLocked && hasUnreceived)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.info,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.done_all_rounded, size: 20),
                  label: const Text(
                    '⚡ استلام جميع الأصناف المنصرفة (بضغطة واحدة)',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  onPressed: _isProcessingAction ? null : () => _receiveItem(allSent: true),
                ),
              ),

            if (canLockSend || canLockReceive || canUnlockSend || canUnlockReceive)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (canLockSend && !isSendLocked)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.secondary),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.secondary),
                      label: const Text('قفل الصرف', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                      onPressed: _isProcessingAction ? null : () => _lockOrder('send'),
                    ),
                  if (canLockReceive && !isReceiveLocked && isSendLocked)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.secondary),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.lock_rounded, size: 16, color: AppColors.secondary),
                      label: const Text('قفل الاستلام', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                      onPressed: _isProcessingAction ? null : () => _lockOrder('receive'),
                    ),
                  if (canUnlockSend && isSendLocked)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.lock_open_rounded, size: 16),
                      label: const Text('فتح الصرف', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: _isProcessingAction ? null : () => _unlockOrder('send'),
                    ),
                  if (canUnlockReceive && isReceiveLocked)
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warning,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.lock_open_rounded, size: 16),
                      label: const Text('فتح الاستلام', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                      onPressed: _isProcessingAction ? null : () => _unlockOrder('receive'),
                    ),
                ],
              ),
            const SizedBox(height: 16),

            // 3. Items Header
            Row(
              children: [
                const Icon(Icons.inventory_2_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  'أصناف الطلب (${items.length})',
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 4. Items List Cards
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final item = items[i];
                final pName = item['product_name'] ?? 'صنف';
                final pUnit = item['unit'] ?? 'وحدة';
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
                          ? AppColors.primary.withOpacity(0.5)
                          : isDisbursed
                              ? AppColors.info.withOpacity(0.5)
                              : AppColors.border,
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.015), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Item Name & Unit
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              pName,
                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              pUnit,
                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Quantities Row (المطلوب vs المنصرف)
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('المطلوب', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary)),
                                const SizedBox(height: 2),
                                Text(
                                  requested.toStringAsFixed(requested.truncateToDouble() == requested ? 0 : 2),
                                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                            Container(width: 1, height: 26, color: AppColors.border),
                            Column(
                              children: [
                                const Text('المنصرف', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary)),
                                const SizedBox(height: 2),
                                Text(
                                  sent.toStringAsFixed(sent.truncateToDouble() == sent ? 0 : 2),
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: sent > 0 ? AppColors.primary : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            Container(width: 1, height: 26, color: AppColors.border),
                            Column(
                              children: [
                                const Text('الحالة', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary)),
                                const SizedBox(height: 2),
                                Text(
                                  isReceived
                                      ? 'مستلم ✓'
                                      : isDisbursed
                                          ? 'منصرف ⏳'
                                          : 'قيد الانتظار',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isReceived
                                        ? AppColors.primary
                                        : isDisbursed
                                            ? AppColors.info
                                            : AppColors.warning,
                                  ),
                                ),
                              ],
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
                            Expanded(
                              child: Text(
                                note,
                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ],

                      // Item Action Buttons
                      if ((canDisburse && !isSendLocked) ||
                          (canReceive && !isReceiveLocked && isDisbursed && !isReceived) ||
                          (canCancelSent && !isSendLocked && isDisbursed && !isReceived)) ...[
                        const Divider(height: 18, color: AppColors.border),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (canDisburse && !isSendLocked && !isDisbursed) ...[
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  side: const BorderSide(color: AppColors.primary),
                                ),
                                icon: const Icon(Icons.edit_note_rounded, size: 16),
                                label: const Text('صرف الكمية', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: _isProcessingAction ? null : () => _openDialpadForDisburse(item),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: _isProcessingAction ? null : () => _disburseItem(item['id'] as int, requested),
                                child: const Text('كل المطلوب', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ],
                            if (canCancelSent && !isSendLocked && isDisbursed && !isReceived)
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.danger,
                                  side: const BorderSide(color: AppColors.danger),
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.undo_rounded, size: 16),
                                label: const Text('إلغاء الصرف وإرجاع الكمية', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold)),
                                onPressed: _isProcessingAction ? null : () => _cancelSent(item['id'] as int),
                              ),
                            if (canReceive && !isReceiveLocked && isDisbursed && !isReceived)
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.info,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.check_rounded, size: 16),
                                label: const Text('تأكيد الاستلام', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
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
    );
  }

  Widget _buildStatusPill({required String label, required bool isLocked, required IconData icon}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: isLocked ? AppColors.danger : AppColors.success),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textSecondary)),
            Text(
              isLocked ? 'مقفل 🔒' : 'مفتوح للعمليات',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isLocked ? AppColors.danger : AppColors.success,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
