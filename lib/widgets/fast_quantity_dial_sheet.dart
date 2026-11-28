import 'package:flutter/material.dart';
import 'numeric_keypad_sheet.dart';

/// In-app virtual tactile numeric dialpad that eliminates OS keyboard lag,
/// screen resizing, and text/numpad switching.
class FastQuantityDialSheet extends StatelessWidget {
  final String title;
  final String unit;
  final double initialValue;
  final double? requestedValue;
  final ValueChanged<double> onConfirmed;
  final bool allowZero;
  final double? maxValue;

  const FastQuantityDialSheet({
    super.key,
    required this.title,
    required this.unit,
    required this.initialValue,
    this.requestedValue,
    required this.onConfirmed,
    this.allowZero = false,
    this.maxValue,
  });

  static Future<double?> show(
    BuildContext context, {
    required String title,
    required String unit,
    required double initialValue,
    double? requestedValue,
    bool allowZero = false,
    double? maxValue,
  }) async {
    final init = initialValue > 0
        ? initialValue
        : (requestedValue != null && requestedValue > 0 ? requestedValue : 0.0);

    final result = await AppNumericKeypadSheet.showDouble(
      context,
      title: title,
      unit: unit,
      initialValue: init,
      allowDecimal: true,
      allowNegative: false,
      presetValue: (requestedValue != null && requestedValue > 0) ? requestedValue : null,
      presetLabel: (requestedValue != null && requestedValue > 0)
          ? '⚡ كل المطلوب (${AppNumericKeypadSheet.formatNumber(requestedValue)})'
          : null,
      quickAddValues: const [1, 5, 10, 25, 50],
      confirmLabel: 'اعتماد الكمية',
    );

    if (result == null) return null;
    if (!allowZero && result <= 0) return null;
    if (maxValue != null && result > maxValue) return maxValue;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final req = requestedValue;
    final init = initialValue > 0
        ? initialValue
        : (req != null && req > 0 ? req : 0.0);

    return AppNumericKeypadSheet(
      title: title,
      unit: unit,
      initialText: init > 0 ? AppNumericKeypadSheet.formatNumber(init) : '',
      allowDecimal: true,
      allowNegative: false,
      presetValue: (req != null && req > 0) ? req : null,
      presetLabel: (req != null && req > 0)
          ? '⚡ كل المطلوب (${AppNumericKeypadSheet.formatNumber(req)})'
          : null,
      quickAddValues: const [1, 5, 10, 25, 50],
      confirmLabel: 'اعتماد الكمية',
    );
  }
}
