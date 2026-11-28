import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/async_views.dart';
import '../../widgets/numeric_keypad_sheet.dart';

class DeliveryCustomersScreen extends StatefulWidget {
  const DeliveryCustomersScreen({super.key});

  @override
  State<DeliveryCustomersScreen> createState() =>
      _DeliveryCustomersScreenState();
}

class _DeliveryCustomersScreenState extends State<DeliveryCustomersScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  Timer? _debounce;
  ApiCancelToken? _cancelToken;

  bool _isLoading = true;
  String? _error;
  String? _zonesError;
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _zones = [];
  int? _selectedZoneFilter;
  bool _initialized = false;

  ApiClient get _api => context.read<ApiClient>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadZones();
      _loadCustomers();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cancelToken?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadZones() async {
    try {
      final res = await _api.get(
        '/api/v1/admin/delivery-zones/',
        queryParams: {'page_size': '100'},
      );
      if (res is Map<String, dynamic> && mounted) {
        final raw = res['results'] as List<dynamic>? ?? [];
        setState(() {
          _zones = raw.whereType<Map<String, dynamic>>().toList();
          _zonesError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _zonesError = e.toString());
      }
    }
  }

  Future<void> _loadCustomers() async {
    _cancelToken?.cancel();
    final token = ApiCancelToken();
    _cancelToken = token;

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final params = <String, dynamic>{
        'page_size': '100',
        if (_searchCtrl.text.trim().isNotEmpty) 'q': _searchCtrl.text.trim(),
        if (_selectedZoneFilter != null)
          'delivery_zone_id': _selectedZoneFilter.toString(),
      };
      final res = await _api.get(
        '/api/v1/admin/delivery-customers/',
        queryParams: params,
        cancelToken: token,
      );
      if (token.isCancelled || !mounted) return;
      if (res is Map<String, dynamic>) {
        final raw = res['results'] as List<dynamic>? ?? [];
        setState(() {
          _customers = raw.whereType<Map<String, dynamic>>().toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'استجابة غير متوقعة من الخادم';
        });
      }
    } catch (e) {
      if (token.isCancelled || !mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _deleteCustomer(Map<String, dynamic> customer) async {
    final name = customer['customer_name']?.toString().isNotEmpty == true
        ? customer['customer_name']
        : customer['phone_number'];
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'حذف عميل التوصيل',
      message: 'هل تريد حذف العميل "$name" نهائياً؟',
      confirmLabel: 'حذف',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await _api.post(
        '/api/v1/admin/delivery-customers/${customer['id']}/delete/',
      );
      if (!mounted) return;
      AppFeedback.showSuccess(context, 'تم حذف العميل بنجاح');
      _loadCustomers();
    } catch (e) {
      if (!mounted) return;
      AppFeedback.showError(context, e.toString());
    }
  }

  Future<void> _showCustomerDialog({Map<String, dynamic>? customer}) async {
    if (_zones.isEmpty) {
      await _loadZones();
      if (!mounted) return;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _DeliveryCustomerFormSheet(
        api: _api,
        zones: _zones,
        customer: customer,
      ),
    );
    if (saved == true && mounted) {
      AppFeedback.showSuccess(
        context,
        customer == null
            ? 'تم تسجيل عميل التوصيل بنجاح'
            : 'تم تحديث بيانات العميل بنجاح',
      );
      _loadCustomers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'عملاء التوصيل (الدليفري)',
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
            onPressed: () {
              _loadZones();
              _loadCustomers();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text(
          'عميل جديد',
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        onPressed: () => _showCustomerDialog(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchCtrl,
              builder: (_, val, __) => TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم أو رقم التليفون أو العنوان...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  suffixIcon: val.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 20),
                          onPressed: () {
                            _searchCtrl.clear();
                            _loadCustomers();
                          },
                        )
                      : null,
                ),
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(
                    const Duration(milliseconds: 350),
                    _loadCustomers,
                  );
                },
              ),
            ),
          ),
          if (_zonesError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: AppInlineError(message: 'تعذر تحميل المناطق: $_zonesError'),
            ),
          if (_zones.isNotEmpty)
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  ChoiceChip(
                    label: Text(
                      'كل المناطق',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _selectedZoneFilter == null
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                    selected: _selectedZoneFilter == null,
                    selectedColor: AppColors.primary,
                    onSelected: (_) {
                      setState(() => _selectedZoneFilter = null);
                      _loadCustomers();
                    },
                  ),
                  ..._zones.map((z) {
                    final id = z['id'] as int;
                    final selected = _selectedZoneFilter == id;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                          '${z['name']}',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                selected ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                        selected: selected,
                        selectedColor: AppColors.primary,
                        onSelected: (_) {
                          setState(() => _selectedZoneFilter = id);
                          _loadCustomers();
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Expanded(
            child: _isLoading
                ? const AppLoadingView(message: 'جاري تحميل عملاء التوصيل...')
                : _error != null
                    ? AppErrorView(
                        message: _error!,
                        onRetry: _loadCustomers,
                      )
                    : _customers.isEmpty
                        ? AppEmptyView(
                            title: 'لا يوجد عملاء مطابقون للبحث',
                            message: 'أضف عميل توصيل جديد أو غيّر كلمة البحث',
                            icon: Icons.contact_phone_outlined,
                            actionLabel: 'إضافة عميل جديد',
                            onAction: () => _showCustomerDialog(),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadCustomers,
                            color: AppColors.primary,
                            child: ListView.separated(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 10, 16, 92),
                              itemCount: _customers.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final customer = _customers[i];
                                final zone = customer['delivery_zone']
                                    as Map<String, dynamic>?;
                                final notes =
                                    customer['notes']?.toString().trim() ?? '';
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.primarySoft,
                                          borderRadius:
                                              BorderRadius.circular(14),
                                        ),
                                        child: const Icon(
                                          Icons.person_pin_circle_rounded,
                                          color: AppColors.primary,
                                          size: 24,
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
                                                  (customer['customer_name']
                                                              ?.toString()
                                                              .trim()
                                                              .isNotEmpty ==
                                                          true)
                                                      ? customer['customer_name']
                                                          .toString()
                                                      : 'عميل توصيل',
                                                  style: const TextStyle(
                                                    fontFamily: 'Cairo',
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                ),
                                                if (zone != null)
                                                  AppStatusBadge(
                                                    label: '${zone['name']}',
                                                    color: AppColors.info,
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Directionality(
                                              textDirection: TextDirection.ltr,
                                              child: Text(
                                                customer['phone_number']
                                                        ?.toString() ??
                                                    '',
                                                style: const TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontSize: 13.5,
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ),
                                            if (customer['address'] != null &&
                                                customer['address']
                                                    .toString()
                                                    .trim()
                                                    .isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                customer['address'].toString(),
                                                style: const TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontSize: 12,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                            if (notes.isNotEmpty) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                'ملاحظات: $notes',
                                                style: const TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontSize: 11,
                                                  color: AppColors.textMuted,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
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
                                                _showCustomerDialog(
                                              customer: customer,
                                            ),
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
                                            onPressed: () =>
                                                _deleteCustomer(customer),
                                          ),
                                        ],
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

class _DeliveryCustomerFormSheet extends StatefulWidget {
  final ApiClient api;
  final List<Map<String, dynamic>> zones;
  final Map<String, dynamic>? customer;

  const _DeliveryCustomerFormSheet({
    required this.api,
    required this.zones,
    this.customer,
  });

  @override
  State<_DeliveryCustomerFormSheet> createState() =>
      _DeliveryCustomerFormSheetState();
}

class _DeliveryCustomerFormSheetState
    extends State<_DeliveryCustomerFormSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _notesController;
  int? _selectedZoneId;
  bool _isSubmitting = false;
  String? _formError;

  List<Map<String, dynamic>> get _selectableZones {
    final active =
        widget.zones.where((z) => z['is_active'] != false).toList();
    if (_selectedZoneId != null &&
        !active.any((z) => z['id'] == _selectedZoneId)) {
      final current =
          widget.zones.where((z) => z['id'] == _selectedZoneId).toList();
      if (current.isNotEmpty) {
        return [...current, ...active];
      }
    }
    return active.isNotEmpty ? active : widget.zones;
  }

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameController = TextEditingController(
      text: (c?['customer_name'] ?? c?['name'] ?? '').toString(),
    );
    _phoneController = TextEditingController(
      text: (c?['phone_number'] ?? c?['phone'] ?? '').toString(),
    );
    _addressController =
        TextEditingController(text: c?['address']?.toString() ?? '');
    _notesController =
        TextEditingController(text: c?['notes']?.toString() ?? '');
    _selectedZoneId = c?['delivery_zone_id'] as int? ??
        (c?['delivery_zone'] as Map<String, dynamic>?)?['id'] as int?;
    if (_selectedZoneId == null) {
      final active =
          widget.zones.where((z) => z['is_active'] != false).toList();
      _selectedZoneId = active.isNotEmpty
          ? active.first['id'] as int?
          : (widget.zones.isNotEmpty ? widget.zones.first['id'] as int? : null);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();
    if (phone.length < 6 || phone.length > 15) {
      setState(() => _formError = 'أدخل رقم هاتف صحيحاً (من 6 إلى 15 رقماً).');
      return;
    }
    if (address.isEmpty) {
      setState(() => _formError = 'أدخل العنوان التفصيلي للعميل.');
      return;
    }
    if (_selectedZoneId == null) {
      setState(() => _formError = 'اختر منطقة التوصيل.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _formError = null;
    });

    try {
      final payload = {
        'customer_name': _nameController.text.trim(),
        'phone_number': phone,
        'delivery_zone_id': _selectedZoneId,
        'address': address,
        'notes': _notesController.text.trim(),
      };
      if (widget.customer == null) {
        await widget.api.post(
          '/api/v1/admin/delivery-customers/create/',
          body: payload,
        );
      } else {
        await widget.api.post(
          '/api/v1/admin/delivery-customers/${widget.customer!['id']}/update/',
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
    final zones = _selectableZones;
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
                  widget.customer == null
                      ? 'إضافة عميل توصيل جديد'
                      : 'تعديل بيانات العميل',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: _isSubmitting ? null : () => Navigator.pop(context),
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
                labelText: 'اسم العميل',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            AppNumericField(
              controller: _phoneController,
              label: 'رقم الهاتف (6–15 رقماً) *',
              dialogTitle: 'أدخل رقم هاتف العميل',
              prefixIcon: Icons.phone_outlined,
              isStringMode: true,
              allowDecimal: false,
              maxLength: 15,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'منطقة التوصيل *',
                prefixIcon: Icon(Icons.map_outlined),
              ),
              value: zones.any((z) => z['id'] == _selectedZoneId)
                  ? _selectedZoneId
                  : null,
              items: zones.map((z) {
                final fee = z['delivery_fee'] ?? z['fee'] ?? '0.00';
                final active = z['is_active'] != false;
                return DropdownMenuItem<int>(
                  value: z['id'] as int,
                  child: Text(
                    '${z['name']} ($fee ج.م)${active ? '' : ' [متوقفة]'}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Cairo'),
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedZoneId = val),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'العنوان التفصيلي *',
                prefixIcon: Icon(Icons.home_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'ملاحظات التوصيل',
                prefixIcon: Icon(Icons.note_alt_outlined),
              ),
            ),
            const SizedBox(height: 20),
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
                      widget.customer == null ? 'تسجيل العميل' : 'حفظ التعديلات',
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
