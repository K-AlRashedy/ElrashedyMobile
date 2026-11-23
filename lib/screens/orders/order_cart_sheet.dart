import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/colors.dart';
import '../../providers/order_provider.dart';

class OrderCartSheet extends StatefulWidget {
  const OrderCartSheet({super.key});

  @override
  State<OrderCartSheet> createState() => _OrderCartSheetState();
}

class _OrderCartSheetState extends State<OrderCartSheet> {
  final _generalNoteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _generalNoteController.text = context.read<OrderProvider>().generalNote;
  }

  @override
  void dispose() {
    _generalNoteController.dispose();
    super.dispose();
  }

  void _showEditQuantityDialog(BuildContext context, int productId, double currentQty, String unit) {
    final controller = TextEditingController(text: currentQty % 1 == 0 ? currentQty.toInt().toString() : currentQty.toString());
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'تعديل الكمية ($unit)',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 24, fontWeight: FontWeight.bold),
            decoration: InputDecoration(
              suffixText: unit,
              hintText: '0',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () {
                final val = double.tryParse(controller.text);
                if (val != null) {
                  context.read<OrderProvider>().setQuantity(productId, val);
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('حفظ', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final orderProvider = context.watch<OrderProvider>();
    final items = orderProvider.cartItems;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),

              // Title and Clear Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.shopping_bag_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'مراجعة الطلب',
                            style: TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '${items.length} أصناف في السلة',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (items.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                        label: const Text(
                          'تفريغ',
                          style: TextStyle(fontFamily: 'Cairo', color: AppColors.error, fontSize: 13),
                        ),
                        onPressed: () => orderProvider.clearCart(),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),

              // Items List
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      'السلة فارغة حالياً. قم بإضافة أصناف من القائمة.',
                      style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final item = items[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.product.name,
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        'الوحدة: ${item.product.unit}',
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Quantity Stepper
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove_rounded, size: 18),
                                        onPressed: () => orderProvider.decrementOrRemove(item.product.id),
                                        padding: const EdgeInsets.all(6),
                                        constraints: const BoxConstraints(),
                                        color: AppColors.error,
                                      ),
                                      InkWell(
                                        onTap: () => _showEditQuantityDialog(
                                          context,
                                          item.product.id,
                                          item.quantity,
                                          item.product.unit,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          child: Text(
                                            item.quantity % 1 == 0
                                                ? item.quantity.toInt().toString()
                                                : item.quantity.toStringAsFixed(1),
                                            style: const TextStyle(
                                              fontFamily: 'Cairo',
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_rounded, size: 18),
                                        onPressed: () => orderProvider.addOrIncrement(item.product),
                                        padding: const EdgeInsets.all(6),
                                        constraints: const BoxConstraints(),
                                        color: AppColors.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Quick item note
                            TextField(
                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'ملاحظة خاصة بهذا الصنف (اختياري)',
                                hintStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 11),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                              ),
                              onChanged: (val) => orderProvider.setItemNote(item.product.id, val),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

              // General Order Note
              if (items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: TextField(
                    controller: _generalNoteController,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'ملاحظة عامة على الطلب بأكمله',
                      hintText: 'مثال: طلبية صباحية عاجلة للفرع',
                      prefixIcon: const Icon(Icons.note_alt_outlined, color: AppColors.primary, size: 20),
                      fillColor: AppColors.surfaceMuted,
                    ),
                    onChanged: (val) => orderProvider.setGeneralNote(val),
                  ),
                ),

              // Submit Action
              if (items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: ElevatedButton(
                    onPressed: orderProvider.isSubmitting
                        ? null
                        : () async {
                            final ok = await orderProvider.submitOrder();
                            if (ok && mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Row(
                                    children: [
                                      Icon(Icons.check_circle_rounded, color: Colors.white),
                                      SizedBox(width: 8),
                                      Text(
                                        'تم رفع وتأكيد الطلب بنجاح إلى السيرفر!',
                                        style: TextStyle(fontFamily: 'Cairo'),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: AppColors.success,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: orderProvider.isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send_rounded, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'تأكيد وإرسال الطلب (${items.length} أصناف)',
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
