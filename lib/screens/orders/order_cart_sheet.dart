import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../providers/order_provider.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/fast_quantity_dial_sheet.dart';
import '../../widgets/numeric_keypad_sheet.dart';

class OrderCartSheet extends StatefulWidget {
  const OrderCartSheet({super.key});

  @override
  State<OrderCartSheet> createState() => _OrderCartSheetState();
}

class _OrderCartSheetState extends State<OrderCartSheet> {
  final _generalNoteController = TextEditingController();
  String? _submitError;

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

  Future<void> _editQuantityWithKeypad(
    BuildContext context,
    int productId,
    String productName,
    double currentQty,
    String unit,
  ) async {
    final val = await FastQuantityDialSheet.show(
      context,
      title: productName,
      unit: unit,
      initialValue: currentQty,
    );
    if (val != null && context.mounted) {
      context.read<OrderProvider>().setQuantity(productId, val);
    }
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
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(color: AppColors.borderStrong, borderRadius: BorderRadius.circular(10)),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.shopping_bag_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('مراجعة الطلب', style: TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.bold)),
                          Text('${items.length} أصناف في السلة', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    if (items.isNotEmpty)
                      TextButton.icon(
                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                        label: const Text('تفريغ', style: TextStyle(fontFamily: 'Cairo', color: AppColors.error, fontSize: 13)),
                        onPressed: () => orderProvider.clearCart(),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              if (_submitError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: AppInlineError(message: _submitError),
                ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                  child: Center(
                    child: Text(
                      'السلة فارغة حالياً. قم بإضافة أصناف من القائمة.',
                      textAlign: TextAlign.center,
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
                                      Text(item.product.name, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold)),
                                      Text('الوحدة: ${item.product.unit}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary)),
                                    ],
                                  ),
                                ),
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
                                        icon: const Icon(Icons.remove_rounded, size: 20),
                                        onPressed: () => orderProvider.decrementOrRemove(item.product.id),
                                        color: AppColors.error,
                                      ),
                                      InkWell(
                                        onTap: () => _editQuantityWithKeypad(
                                          context,
                                          item.product.id,
                                          item.product.name,
                                          item.quantity,
                                          item.product.unit,
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          child: Text(
                                            AppNumericKeypadSheet.formatNumber(item.quantity),
                                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add_rounded, size: 20),
                                        onPressed: () => orderProvider.addOrIncrement(item.product),
                                        color: AppColors.primary,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              key: ValueKey('cart_note_${item.product.id}'),
                              initialValue: item.note,
                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
                              decoration: const InputDecoration(
                                hintText: 'ملاحظة خاصة بهذا الصنف (اختياري)',
                                isDense: true,
                                fillColor: Colors.white,
                              ),
                              onChanged: (val) => orderProvider.setItemNote(item.product.id, val),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              if (items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: TextField(
                    controller: _generalNoteController,
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 13),
                    decoration: const InputDecoration(
                      labelText: 'ملاحظة عامة على الطلب',
                      hintText: 'مثال: طلبية صباحية عاجلة للفرع',
                      prefixIcon: Icon(Icons.note_alt_outlined, color: AppColors.primary, size: 20),
                      fillColor: AppColors.surfaceMuted,
                    ),
                    onChanged: (val) => orderProvider.setGeneralNote(val),
                  ),
                ),
              if (items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: ElevatedButton.icon(
                    onPressed: orderProvider.isSubmitting
                        ? null
                        : () async {
                            setState(() => _submitError = null);
                            final ok = await orderProvider.submitOrder();
                            if (!mounted) return;
                            if (ok) {
                              Navigator.of(context).pop();
                              AppFeedback.showSuccess(context, 'تم رفع وتأكيد الطلب بنجاح!');
                            } else {
                              final msg = orderProvider.errorMessage ?? 'تعذر إرسال الطلب.';
                              setState(() => _submitError = msg);
                              AppFeedback.showError(context, msg);
                            }
                          },
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    icon: orderProvider.isSubmitting
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Icon(Icons.send_rounded, size: 20),
                    label: Text(
                      orderProvider.isSubmitting
                          ? 'جارٍ الإرسال...'
                          : 'تأكيد وإرسال الطلب (${items.length} أصناف)',
                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold),
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
