import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/async_views.dart';
import '../../widgets/numeric_keypad_sheet.dart';

class DeliveryZonesScreen extends StatefulWidget {
  final bool openCreate;

  const DeliveryZonesScreen({
    super.key,
    this.openCreate = false,
  });

  @override
  State<DeliveryZonesScreen> createState() => _DeliveryZonesScreenState();
}

class _DeliveryZonesScreenState extends State<DeliveryZonesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _zones = [];
  String _activeFilter = 'all'; // all | active | inactive
  bool _initialized = false;

  ApiClient get _api => context.read<ApiClient>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _loadZones();
        if (widget.openCreate && mounted) {
          _showZoneDialog();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadZones() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.get(
        '/api/v1/admin/delivery-zones/',
        queryParams: {'page_size': '100'},
      );
      if (!mounted) return;
      if (res is Map<String, dynamic>) {
        final raw = res['results'] as List<dynamic>? ?? [];
        setState(() {
          _zones = raw.whereType<Map<String, dynamic>>().toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'استجابة غير متوقعة من الخادم';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _deleteZone(Map<String, dynamic> zone) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'حذف منطقة التوصيل',
      message: 'هل تريد حذف المنطقة "${zone['name']}"؟',
      confirmLabel: 'حذف',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await _api.post('/api/v1/admin/delivery-zones/${zone['id']}/delete/');
      if (!mounted) return;
      AppFeedback.showSuccess(context, 'تم حذف منطقة التوصيل بنجاح');
      _loadZones();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, e.toString());
    }
  }

  Future<void> _showZoneDialog({Map<String, dynamic>? zone}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _DeliveryZoneFormSheet(api: _api, zone: zone),
    );
    if (saved == true && mounted) {
      AppFeedback.showSuccess(
        context,
        zone == null ? 'تم إضافة منطقة التوصيل بنجاح' : 'تم حفظ تعديلات المنطقة',
      );
      _loadZones();
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = _zones.where((z) {
      final active = z['is_active'] != false;
      if (_activeFilter == 'active' && !active) return false;
      if (_activeFilter == 'inactive' && active) return false;
      if (q.isEmpty) return true;
      return (z['name']?.toString() ?? '').toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'مناطق ورسوم التوصيل',
          style: TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loadZones,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text(
          'إضافة منطقة',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showZoneDialog(),
      ),
      body: _isLoading
          ? const AppLoadingView(message: 'جاري تحميل مناطق التوصيل...')
          : _error != null
              ? AppErrorView(message: _error!, onRetry: _loadZones)
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _searchCtrl,
                        builder: (_, val, __) => TextField(
                          controller: _searchCtrl,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'ابحث باسم المنطقة...',
                            prefixIcon: const Icon(
                              Icons.search_rounded,
                              color: AppColors.primary,
                            ),
                            suffixIcon: val.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 20),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() {});
                                    },
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          ChoiceChip(
                            label: Text(
                              'الكل (${_zones.length})',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _activeFilter == 'all'
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                            selected: _activeFilter == 'all',
                            selectedColor: AppColors.primary,
                            onSelected: (_) =>
                                setState(() => _activeFilter = 'all'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(
                              'نشطة',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _activeFilter == 'active'
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                            selected: _activeFilter == 'active',
                            selectedColor: AppColors.primary,
                            onSelected: (_) =>
                                setState(() => _activeFilter = 'active'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(
                              'متوقفة',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _activeFilter == 'inactive'
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                            selected: _activeFilter == 'inactive',
                            selectedColor: AppColors.primary,
                            onSelected: (_) =>
                                setState(() => _activeFilter = 'inactive'),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? AppEmptyView(
                              title: 'لا توجد مناطق توصيل مطابقة',
                              icon: Icons.map_outlined,
                              actionLabel: 'إضافة منطقة',
                              onAction: () => _showZoneDialog(),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadZones,
                              color: AppColors.primary,
                              child: ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 12, 16, 92),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (ctx, i) {
                                  final zone = filtered[i];
                                  final isActive = zone['is_active'] != false;
                                  final fee = zone['delivery_fee'] ??
                                      zone['fee'] ??
                                      '0.00';
                                  return Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(18),
                                      border:
                                          Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: AppColors.primarySoft,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: const Icon(
                                            Icons.location_on_rounded,
                                            color: AppColors.primary,
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 4,
                                                crossAxisAlignment:
                                                    WrapCrossAlignment.center,
                                                children: [
                                                  Text(
                                                    zone['name']?.toString() ??
                                                        '',
                                                    style: const TextStyle(
                                                      fontFamily: 'Cairo',
                                                      fontSize: 15,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  AppStatusBadge(
                                                    label: isActive
                                                        ? 'نشطة'
                                                        : 'متوقفة',
                                                    color: isActive
                                                        ? AppColors.success
                                                        : AppColors.warning,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'رسوم التوصيل: $fee ج.م',
                                                style: const TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.primary,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'تعديل',
                                          constraints: const BoxConstraints(
                                            minWidth: 44,
                                            minHeight: 44,
                                          ),
                                          icon: const Icon(
                                            Icons.edit_outlined,
                                            size: 20,
                                            color: AppColors.info,
                                          ),
                                          onPressed: () =>
                                              _showZoneDialog(zone: zone),
                                        ),
                                        IconButton(
                                          tooltip: 'حذف',
                                          constraints: const BoxConstraints(
                                            minWidth: 44,
                                            minHeight: 44,
                                          ),
                                          icon: const Icon(
                                            Icons.delete_outline_rounded,
                                            size: 20,
                                            color: AppColors.error,
                                          ),
                                          onPressed: () => _deleteZone(zone),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }
}

class _DeliveryZoneFormSheet extends StatefulWidget {
  final ApiClient api;
  final Map<String, dynamic>? zone;

  const _DeliveryZoneFormSheet({required this.api, this.zone});

  @override
  State<_DeliveryZoneFormSheet> createState() => _DeliveryZoneFormSheetState();
}

class _DeliveryZoneFormSheetState extends State<_DeliveryZoneFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _feeController;
  late bool _isActive;
  bool _isSubmitting = false;
  String? _formError;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.zone?['name']?.toString() ?? '');
    _feeController = TextEditingController(
      text: (widget.zone?['delivery_fee'] ?? widget.zone?['fee'] ?? '0')
          .toString(),
    );
    _isActive = widget.zone?['is_active'] != false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _formError = 'أدخل اسم المنطقة أو الحي.');
      return;
    }
    final feeText = _feeController.text.trim();
    final fee = feeText.isEmpty ? 0.0 : double.tryParse(feeText);
    if (fee == null || fee < 0) {
      setState(() => _formError = 'أدخل رسوم توصيل صحيحة (0 أو أكبر).');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _formError = null;
    });
    try {
      final payload = {
        'name': name,
        'delivery_fee': AppNumericKeypadSheet.formatNumber(fee),
        'is_active': _isActive,
      };
      if (widget.zone == null) {
        await widget.api.post(
          '/api/v1/admin/delivery-zones/create/',
          body: payload,
        );
      } else {
        await widget.api.post(
          '/api/v1/admin/delivery-zones/${widget.zone!['id']}/update/',
          body: payload,
        );
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _formError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.zone == null
                      ? 'إضافة منطقة توصيل'
                      : 'تعديل منطقة التوصيل',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed:
                      _isSubmitting ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_formError != null) ...[
              AppInlineError(message: _formError!),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم المنطقة / الحي *',
                prefixIcon: Icon(Icons.map_outlined),
              ),
            ),
            const SizedBox(height: 12),
            AppNumericField(
              controller: _feeController,
              label: 'رسوم التوصيل (ج.م) *',
              unit: 'ج.م',
              dialogTitle: 'تحديد رسوم التوصيل',
              prefixIcon: Icons.delivery_dining_outlined,
              allowDecimal: true,
              quickAddValues: const [5, 10, 15, 20, 30],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'منطقة التوصيل نشطة',
                style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.w600),
              ),
              value: _isActive,
              onChanged: (val) => setState(() => _isActive = val),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      widget.zone == null ? 'إضافة المنطقة' : 'حفظ التعديلات',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
