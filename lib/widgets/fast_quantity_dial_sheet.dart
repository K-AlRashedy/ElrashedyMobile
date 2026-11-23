import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/constants/colors.dart';

/// In-app virtual tactile numeric dialpad that eliminates OS keyboard lag,
/// screen resizing, and text/numpad switching.
class FastQuantityDialSheet extends StatefulWidget {
  final String title;
  final String unit;
  final double initialValue;
  final double? requestedValue;
  final ValueChanged<double> onConfirmed;

  const FastQuantityDialSheet({
    super.key,
    required this.title,
    required this.unit,
    required this.initialValue,
    this.requestedValue,
    required this.onConfirmed,
  });

  static Future<double?> show(
    BuildContext context, {
    required String title,
    required String unit,
    required double initialValue,
    double? requestedValue,
  }) {
    return showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FastQuantityDialSheet(
        title: title,
        unit: unit,
        initialValue: initialValue,
        requestedValue: requestedValue,
        onConfirmed: (val) => Navigator.of(context).pop(val),
      ),
    );
  }

  @override
  State<FastQuantityDialSheet> createState() => _FastQuantityDialSheetState();
}

class _FastQuantityDialSheetState extends State<FastQuantityDialSheet> {
  late String _currentText;

  @override
  void initState() {
    super.initState();
    if (widget.initialValue > 0) {
      _currentText = widget.initialValue.toStringAsFixed(
        widget.initialValue.truncateToDouble() == widget.initialValue ? 0 : 2,
      );
    } else if (widget.requestedValue != null && widget.requestedValue! > 0) {
      _currentText = widget.requestedValue!.toStringAsFixed(
        widget.requestedValue!.truncateToDouble() == widget.requestedValue! ? 0 : 2,
      );
    } else {
      _currentText = '1';
    }
  }

  void _appendDigit(String digit) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_currentText == '0' && digit != '.') {
        _currentText = digit;
      } else if (digit == '.') {
        if (!_currentText.contains('.')) {
          _currentText += '.';
        }
      } else {
        if (_currentText.length < 7) {
          _currentText += digit;
        }
      }
    });
  }

  void _backspace() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_currentText.isNotEmpty) {
        _currentText = _currentText.substring(0, _currentText.length - 1);
        if (_currentText.isEmpty) _currentText = '0';
      }
    });
  }

  void _clear() {
    HapticFeedback.mediumImpact();
    setState(() {
      _currentText = '0';
    });
  }

  void _addDelta(double delta) {
    HapticFeedback.lightImpact();
    setState(() {
      final current = double.tryParse(_currentText) ?? 0.0;
      final next = (current + delta).clamp(0.0, 99999.0);
      _currentText = next.toStringAsFixed(next.truncateToDouble() == next ? 0 : 2);
    });
  }

  void _setRequestedValue() {
    if (widget.requestedValue == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      final req = widget.requestedValue!;
      _currentText = req.toStringAsFixed(req.truncateToDouble() == req ? 0 : 2);
    });
  }

  void _confirm() {
    HapticFeedback.heavyImpact();
    final val = double.tryParse(_currentText) ?? 0.0;
    widget.onConfirmed(val);
  }

  Widget _buildKey(String label, {VoidCallback? onTap, Color? color, Color? textColor}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Material(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(14),
          elevation: 1,
          child: InkWell(
            onTap: onTap ?? () => _appendDigit(label),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 52,
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: textColor ?? AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Header: Title & Unit
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'الوحدة: ${widget.unit}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Current value display box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary, width: 2),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _currentText.isEmpty ? '0' : _currentText,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.unit,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Quick Preset Increment Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (widget.requestedValue != null && widget.requestedValue! > 0) ...[
                    ActionChip(
                      backgroundColor: AppColors.primary,
                      label: Text(
                        '⚡ كل المطلوب (${widget.requestedValue!.toStringAsFixed(widget.requestedValue!.truncateToDouble() == widget.requestedValue! ? 0 : 2)})',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      onPressed: _setRequestedValue,
                    ),
                    const SizedBox(width: 6),
                  ],
                  ActionChip(
                    backgroundColor: Colors.white,
                    label: const Text('+1', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _addDelta(1),
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    backgroundColor: Colors.white,
                    label: const Text('+5', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _addDelta(5),
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    backgroundColor: Colors.white,
                    label: const Text('+10', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _addDelta(10),
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    backgroundColor: Colors.white,
                    label: const Text('+25', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _addDelta(25),
                  ),
                  const SizedBox(width: 6),
                  ActionChip(
                    backgroundColor: Colors.white,
                    label: const Text('+50', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () => _addDelta(50),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Tactile 4x3 Calculator Keypad
            Row(
              children: [
                _buildKey('1'),
                _buildKey('2'),
                _buildKey('3'),
              ],
            ),
            Row(
              children: [
                _buildKey('4'),
                _buildKey('5'),
                _buildKey('6'),
              ],
            ),
            Row(
              children: [
                _buildKey('7'),
                _buildKey('8'),
                _buildKey('9'),
              ],
            ),
            Row(
              children: [
                _buildKey('.', onTap: () => _appendDigit('.')),
                _buildKey('0'),
                _buildKey(
                  '⌫',
                  onTap: _backspace,
                  color: Colors.red.shade50,
                  textColor: Colors.red.shade700,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bottom Actions: Clear & Confirm
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.textSecondary,
                      elevation: 0,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _clear,
                    child: const Text('مسح C', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _confirm,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 20),
                        SizedBox(width: 6),
                        Text(
                          'اعتماد الكمية',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
