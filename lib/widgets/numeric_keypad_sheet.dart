import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/constants/colors.dart';

/// Custom tactile in-app numeric keypad bottom sheet.
/// Guarantees the native mobile OS keyboard never opens for numeric fields.
class AppNumericKeypadSheet extends StatefulWidget {
  final String title;
  final String? unit;
  final String initialText;
  final bool allowDecimal;
  final bool allowNegative;
  final bool isStringMode;
  final int maxLength;
  final double? presetValue;
  final String? presetLabel;
  final List<double> quickAddValues;
  final String confirmLabel;

  const AppNumericKeypadSheet({
    super.key,
    required this.title,
    this.unit,
    this.initialText = '',
    this.allowDecimal = true,
    this.allowNegative = false,
    this.isStringMode = false,
    this.maxLength = 12,
    this.presetValue,
    this.presetLabel,
    this.quickAddValues = const [],
    this.confirmLabel = 'تأكيد الرقم',
  });

  static Future<String?> showString(
    BuildContext context, {
    required String title,
    String? unit,
    String initialText = '',
    bool allowDecimal = true,
    bool allowNegative = false,
    bool isStringMode = false,
    int maxLength = 14,
    double? presetValue,
    String? presetLabel,
    List<double> quickAddValues = const [],
    String confirmLabel = 'تأكيد',
  }) {
    FocusManager.instance.primaryFocus?.unfocus();
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AppNumericKeypadSheet(
        title: title,
        unit: unit,
        initialText: initialText,
        allowDecimal: allowDecimal,
        allowNegative: allowNegative,
        isStringMode: isStringMode,
        maxLength: maxLength,
        presetValue: presetValue,
        presetLabel: presetLabel,
        quickAddValues: quickAddValues,
        confirmLabel: confirmLabel,
      ),
    );
  }

  static Future<double?> showDouble(
    BuildContext context, {
    required String title,
    String? unit,
    double initialValue = 0,
    bool allowDecimal = true,
    bool allowNegative = false,
    double? presetValue,
    String? presetLabel,
    List<double> quickAddValues = const [],
    String confirmLabel = 'اعتماد',
  }) async {
    final init = initialValue == 0
        ? ''
        : (initialValue.truncateToDouble() == initialValue
            ? initialValue.toInt().toString()
            : initialValue.toStringAsFixed(2));
    final result = await showString(
      context,
      title: title,
      unit: unit,
      initialText: init,
      allowDecimal: allowDecimal,
      allowNegative: allowNegative,
      isStringMode: false,
      presetValue: presetValue,
      presetLabel: presetLabel,
      quickAddValues: quickAddValues,
      confirmLabel: confirmLabel,
    );
    if (result == null) return null;
    if (result.trim().isEmpty) return 0.0;
    return double.tryParse(result.trim());
  }

  static String formatNumber(double value) {
    if (value.truncateToDouble() == value) {
      return value.toInt().toString();
    }
    return value
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  @override
  State<AppNumericKeypadSheet> createState() => _AppNumericKeypadSheetState();
}

class _AppNumericKeypadSheetState extends State<AppNumericKeypadSheet> {
  late String _text;
  bool _replaceOnFirstInput = false;

  @override
  void initState() {
    super.initState();
    _text = widget.initialText.trim();
    _replaceOnFirstInput = _text.isNotEmpty;
  }

  void _append(String char) {
    HapticFeedback.lightImpact();
    setState(() {
      if (_replaceOnFirstInput) {
        _replaceOnFirstInput = false;
        if (char == '.') {
          _text = '0.';
          return;
        }
        _text = char;
        return;
      }

      if (char == '.') {
        if (!widget.allowDecimal) return;
        if (_text.contains('.')) return;
        if (_text.isEmpty || _text == '-') {
          _text += '0.';
        } else {
          _text += '.';
        }
        return;
      }

      if (!widget.isStringMode && _text == '0') {
        _text = char;
        return;
      }
      if (!widget.isStringMode && _text == '-0') {
        _text = '-$char';
        return;
      }

      if (_text.length + char.length <= widget.maxLength) {
        _text += char;
      }
    });
  }

  void _toggleSign() {
    if (!widget.allowNegative) return;
    HapticFeedback.lightImpact();
    setState(() {
      _replaceOnFirstInput = false;
      if (_text.startsWith('-')) {
        _text = _text.substring(1);
      } else if (_text.isEmpty) {
        _text = '-';
      } else {
        _text = '-$_text';
      }
    });
  }

  void _backspace() {
    HapticFeedback.lightImpact();
    setState(() {
      _replaceOnFirstInput = false;
      if (_text.isNotEmpty) {
        _text = _text.substring(0, _text.length - 1);
      }
    });
  }

  void _clear() {
    HapticFeedback.mediumImpact();
    setState(() {
      _replaceOnFirstInput = false;
      _text = '';
    });
  }

  void _addDelta(double delta) {
    HapticFeedback.lightImpact();
    setState(() {
      _replaceOnFirstInput = false;
      final current = double.tryParse(_text) ?? 0.0;
      var next = current + delta;
      if (!widget.allowNegative && next < 0) next = 0;
      _text = AppNumericKeypadSheet.formatNumber(next);
    });
  }

  void _applyPreset() {
    if (widget.presetValue == null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _replaceOnFirstInput = false;
      _text = AppNumericKeypadSheet.formatNumber(widget.presetValue!);
    });
  }

  void _confirm() {
    HapticFeedback.heavyImpact();
    var out = _text.trim();
    if (out == '-' || out == '.') {
      out = '';
    } else if (out.endsWith('.')) {
      out = out.substring(0, out.length - 1);
    }
    Navigator.of(context).pop(out);
  }

  Widget _buildKey(
    String label, {
    VoidCallback? onTap,
    Color? bgColor,
    Color? textColor,
    IconData? icon,
    double fontSize = 23,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4.5),
        child: Material(
          color: bgColor ?? Colors.white,
          borderRadius: BorderRadius.circular(16),
          elevation: 0.5,
          shadowColor: Colors.black12,
          child: InkWell(
            onTap: onTap ?? () => _append(label),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border.withValues(alpha: 0.85)),
              ),
              alignment: Alignment.center,
              child: icon != null
                  ? Icon(icon, size: 24, color: textColor ?? AppColors.textPrimary)
                  : Text(
                      label,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: fontSize,
                        fontWeight: FontWeight.w800,
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
    final displayValue = _text.isEmpty ? '0' : _text;
    final hasQuickRow = widget.presetValue != null || widget.quickAddValues.isNotEmpty || widget.allowNegative;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Title & Close
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.dialpad_rounded, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 10),
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
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        if (widget.unit != null && widget.unit!.isNotEmpty)
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
                  IconButton(
                    tooltip: 'إغلاق',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // High-contrast numeric display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _replaceOnFirstInput ? AppColors.accentBlue : AppColors.primary,
                    width: 2,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0A000000),
                      blurRadius: 10,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (widget.unit != null && widget.unit!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.unit!,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          displayValue,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: _text.isEmpty
                                ? AppColors.textMuted
                                : (_replaceOnFirstInput ? AppColors.accentBlue : AppColors.secondary),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                    if (_text.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: _clear,
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.cancel_rounded, size: 22, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (hasQuickRow) ...[
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (widget.allowNegative) ...[
                        ActionChip(
                          avatar: const Icon(Icons.exposure_rounded, size: 16, color: AppColors.secondary),
                          backgroundColor: Colors.white,
                          label: Text(
                            _text.startsWith('-') ? 'تحويل لموجب (+)' : 'تحويل لسالب (-)',
                            style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _toggleSign,
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (widget.presetValue != null) ...[
                        ActionChip(
                          backgroundColor: AppColors.primary,
                          side: BorderSide.none,
                          label: Text(
                            widget.presetLabel ??
                                '⚡ ${AppNumericKeypadSheet.formatNumber(widget.presetValue!)}',
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          onPressed: _applyPreset,
                        ),
                        const SizedBox(width: 6),
                      ],
                      for (final delta in widget.quickAddValues) ...[
                        ActionChip(
                          backgroundColor: Colors.white,
                          label: Text(
                            delta > 0
                                ? '+${AppNumericKeypadSheet.formatNumber(delta)}'
                                : AppNumericKeypadSheet.formatNumber(delta),
                            textDirection: TextDirection.ltr,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          onPressed: () => _addDelta(delta),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Force LTR keypad order (1-2-3 left-to-right like every phone/calculator)
              Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Row(children: [_buildKey('1'), _buildKey('2'), _buildKey('3')]),
                    Row(children: [_buildKey('4'), _buildKey('5'), _buildKey('6')]),
                    Row(children: [_buildKey('7'), _buildKey('8'), _buildKey('9')]),
                    Row(
                      children: [
                        if (widget.allowDecimal && !widget.isStringMode)
                          _buildKey('.', onTap: () => _append('.'))
                        else
                          _buildKey('00', fontSize: 19, onTap: () => _append('00')),
                        _buildKey('0'),
                        _buildKey(
                          '⌫',
                          icon: Icons.backspace_outlined,
                          bgColor: AppColors.dangerSoft,
                          textColor: AppColors.danger,
                          onTap: _backspace,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.borderStrong),
                        minimumSize: const Size(0, 52),
                      ),
                      onPressed: _clear,
                      child: const Text('مسح', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 52),
                      ),
                      onPressed: _confirm,
                      icon: const Icon(Icons.check_circle_rounded, size: 22),
                      label: Text(
                        widget.confirmLabel,
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 15.5, fontWeight: FontWeight.bold),
                      ),
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

/// Tappable numeric input field that opens [AppNumericKeypadSheet] instead of
/// the native OS keyboard, while preserving standard [TextEditingController] binding.
class AppNumericField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? unit;
  final String? dialogTitle;
  final IconData? prefixIcon;
  final bool allowDecimal;
  final bool allowNegative;
  final bool isStringMode;
  final int maxLength;
  final double? presetValue;
  final String? presetLabel;
  final List<double> quickAddValues;
  final ValueChanged<String>? onChanged;
  final String? errorText;
  final bool enabled;
  final bool isDense;

  const AppNumericField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.unit,
    this.dialogTitle,
    this.prefixIcon,
    this.allowDecimal = true,
    this.allowNegative = false,
    this.isStringMode = false,
    this.maxLength = 14,
    this.presetValue,
    this.presetLabel,
    this.quickAddValues = const [],
    this.onChanged,
    this.errorText,
    this.enabled = true,
    this.isDense = false,
  });

  Future<void> _openKeypad(BuildContext context) async {
    if (!enabled) return;
    final result = await AppNumericKeypadSheet.showString(
      context,
      title: dialogTitle ?? label.replaceAll('*', '').trim(),
      unit: unit,
      initialText: controller.text,
      allowDecimal: allowDecimal,
      allowNegative: allowNegative,
      isStringMode: isStringMode,
      maxLength: maxLength,
      presetValue: presetValue,
      presetLabel: presetLabel,
      quickAddValues: quickAddValues,
    );
    if (result != null) {
      controller.text = result;
      onChanged?.call(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final text = value.text.trim();
        final isEmpty = text.isEmpty;

        return InkWell(
          onTap: enabled ? () => _openKeypad(context) : null,
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            isEmpty: isEmpty,
            decoration: InputDecoration(
              labelText: label,
              hintText: hint,
              errorText: errorText,
              isDense: isDense,
              filled: true,
              fillColor: enabled ? Colors.white : AppColors.surfaceMuted,
              prefixIcon: prefixIcon != null
                  ? Icon(prefixIcon, color: AppColors.primary, size: 20)
                  : null,
              suffixText: unit,
              suffixIcon: Icon(
                Icons.dialpad_rounded,
                size: 19,
                color: enabled ? AppColors.primary : AppColors.textMuted,
              ),
            ),
            child: Text(
              isEmpty ? (hint ?? '') : text,
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.start,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: isDense ? 14 : 15.5,
                fontWeight: isEmpty ? FontWeight.normal : FontWeight.w800,
                color: isEmpty ? AppColors.textMuted : AppColors.textPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Tappable time field (`HH:MM`) that opens a visual clock picker instead of an OS keyboard.
class AppTimeField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isDense;

  const AppTimeField({
    super.key,
    required this.controller,
    required this.label,
    this.isDense = false,
  });

  TimeOfDay _parseInitial() {
    final parts = controller.text.trim().split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      if (h != null && m != null && h >= 0 && h < 24 && m >= 0 && m < 60) {
        return TimeOfDay(hour: h, minute: m);
      }
    }
    return const TimeOfDay(hour: 9, minute: 0);
  }

  Future<void> _pick(BuildContext context) async {
    FocusManager.instance.primaryFocus?.unfocus();
    final picked = await showTimePicker(
      context: context,
      initialTime: _parseInitial(),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      controller.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final text = value.text.trim();
        return InkWell(
          onTap: () => _pick(context),
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            isEmpty: text.isEmpty,
            decoration: InputDecoration(
              labelText: label,
              isDense: isDense,
              suffixIcon: const Icon(Icons.access_time_rounded, size: 18, color: AppColors.primary),
            ),
            child: Text(
              text.isEmpty ? 'HH:MM' : text,
              textDirection: TextDirection.ltr,
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: isDense ? 13.5 : 15,
                fontWeight: text.isEmpty ? FontWeight.normal : FontWeight.bold,
                color: text.isEmpty ? AppColors.textMuted : AppColors.textPrimary,
              ),
            ),
          ),
        );
      },
    );
  }
}
