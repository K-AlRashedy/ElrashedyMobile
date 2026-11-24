import 'package:flutter/material.dart';

import '../core/constants/colors.dart';
import '../core/pagination.dart';

class AppLoadingView extends StatelessWidget {
  final String? message;

  const AppLoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class AppErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final IconData icon;

  const AppErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.icon = Icons.cloud_off_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.danger),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 14,
                color: AppColors.textPrimary,
                height: 1.6,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('إعادة المحاولة', style: TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppEmptyView extends StatelessWidget {
  final String? message;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  const AppEmptyView({
    super.key,
    this.message,
    this.title,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.inbox_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 14),
            if (title != null) ...[
              Text(
                title!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
            ],
            if (message != null && message!.isNotEmpty)
              Text(
                message!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              )
            else if (title == null)
              const Text(
                'لا توجد بيانات متاحة حالياً',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!, style: const TextStyle(fontFamily: 'Cairo')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppStatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;

  const AppStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class AppDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const AppDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
          ],
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PagedListView<T> extends StatefulWidget {
  final PaginationController<T> controller;
  final Widget Function(BuildContext, T) itemBuilder;
  final Widget Function(BuildContext, T)? separatorBuilder;
  final EdgeInsetsGeometry padding;
  final String emptyMessage;
  final IconData emptyIcon;
  final VoidCallback? emptyAction;
  final double loadMoreThreshold;

  const PagedListView({
    super.key,
    required this.controller,
    required this.itemBuilder,
    this.separatorBuilder,
    this.padding = const EdgeInsets.all(16),
    required this.emptyMessage,
    this.emptyIcon = Icons.inbox_rounded,
    this.emptyAction,
    this.loadMoreThreshold = 400,
  });

  @override
  State<PagedListView<T>> createState() => _PagedListViewState<T>();
}

class _PagedListViewState<T> extends State<PagedListView<T>> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.extentAfter <= widget.loadMoreThreshold) {
      widget.controller.loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (!widget.controller.hasLoaded && widget.controller.isLoading) {
          return const AppLoadingView();
        }
        if (!widget.controller.hasLoaded && widget.controller.hasError) {
          return AppErrorView(
            message: widget.controller.error ?? 'تعذر تحميل البيانات.',
            onRetry: widget.controller.refresh,
          );
        }
        final items = widget.controller.items;
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: widget.controller.refresh,
          child: ListView.builder(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: widget.padding,
            itemCount: items.length + 1,
            itemBuilder: (context, index) {
              if (index < items.length) {
                final child = widget.itemBuilder(context, items[index]);
                if (index == 0 || widget.separatorBuilder == null) return child;
                return Column(
                  children: [
                    widget.separatorBuilder!(context, items[index - 1]),
                    child,
                  ],
                );
              }
              if (items.isEmpty) {
                return AppEmptyView(
                  message: widget.emptyMessage,
                  icon: widget.emptyIcon,
                  actionLabel: widget.emptyAction == null ? null : 'إضافة سجل جديد',
                  onAction: widget.emptyAction,
                );
              }
              return _buildFooter();
            },
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    if (widget.controller.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
          ),
        ),
      );
    }
    if (widget.controller.hasError) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: AppErrorView(
          message: widget.controller.error ?? 'تعذر تحميل المزيد.',
          onRetry: widget.controller.loadMore,
        ),
      );
    }
    if (!widget.controller.hasNext) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(
          'إجمالي السجلات: ${widget.controller.count}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
