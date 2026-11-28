import 'dart:async';
import 'package:flutter/material.dart';

import '../core/constants/colors.dart';

/// Displays floating notifications in the root [Overlay] so feedback is
/// ALWAYS visible even above open [showModalBottomSheet] and [showDialog] modals.
class AppFeedback {
  static OverlayEntry? _activeEntry;
  static Timer? _dismissTimer;

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, isError: false);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, isError: true);
  }

  static void _show(BuildContext context, String message, {required bool isError}) {
    _dismissTimer?.cancel();
    _activeEntry?.remove();
    _activeEntry = null;

    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontFamily: 'Cairo')),
          backgroundColor: isError ? AppColors.error : AppColors.success,
        ),
      );
      return;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) {
        final topPadding = MediaQuery.of(ctx).padding.top + 12;
        return Positioned(
          top: topPadding,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 220),
              tween: Tween(begin: -16, end: 0),
              builder: (_, offset, child) => Transform.translate(
                offset: Offset(0, offset),
                child: child,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: isError ? AppColors.error : AppColors.success,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        _dismissTimer?.cancel();
                        if (identical(_activeEntry, entry)) {
                          entry.remove();
                          _activeEntry = null;
                        }
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    _activeEntry = entry;
    overlay.insert(entry);
    _dismissTimer = Timer(Duration(seconds: isError ? 4 : 3), () {
      if (identical(_activeEntry, entry)) {
        entry.remove();
        _activeEntry = null;
      }
    });
  }
}

/// Inline error box for forms inside bottom sheets and dialogs.
class AppInlineError extends StatelessWidget {
  final String? message;

  const AppInlineError({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    if (message == null || message!.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message!,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Standard confirmation dialog for destructive or financial actions.
class AppConfirmDialog {
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'تأكيد',
    String cancelLabel = 'إلغاء',
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          title,
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Text(
          message,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 13.5, color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel, style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isDestructive ? AppColors.error : AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel, style: const TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );
    return result == true;
  }
}
