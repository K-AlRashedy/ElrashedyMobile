import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/async_views.dart';

class DeliveryCustomersScreen extends StatefulWidget {
  const DeliveryCustomersScreen({super.key});

  @override
  State<DeliveryCustomersScreen> createState() => _DeliveryCustomersScreenState();
}

class _DeliveryCustomersScreenState extends State<DeliveryCustomersScreen> {
  final _api = ApiClient();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _customers = [];
  List<dynamic> _zones = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _api.setBaseUrl(auth.serverUrl);
    _api.setToken(auth.token);
    _loadCustomers();
    _loadZones();
  }

  Future<void> _loadZones() async {
    try {
      final res = await _api.get('/api/v1/admin/delivery-zones/');
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _zones = res['results'] as List<dynamic>? ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.get('/api/v1/admin/delivery-customers/');
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _customers = res['results'] as List<dynamic>? ?? [];
          _isLoading = false;
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

  void _showCustomerDialog({Map<String, dynamic>? customer}) {
    final nameController = TextEditingController(text: customer?['name']?.toString() ?? '');
    final phoneController = TextEditingController(text: customer?['phone']?.toString() ?? '');
    final altPhoneController = TextEditingController(text: customer?['alternative_phone']?.toString() ?? '');
    final addressController = TextEditingController(text: customer?['address']?.toString() ?? '');
    final notesController = TextEditingController(text: customer?['notes']?.toString() ?? '');
    int? selectedZoneId = customer?['zone_id'] as int? ?? (_zones.isNotEmpty ? _zones.first['id'] as int? : null);
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(customer == null ? 'إضافة عميل توصيل جديد' : 'تعديل بيانات العميل', style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'اسم العميل', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف الأساسي', prefixIcon: Icon(Icons.phone_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: altPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'هاتف بديل (اختياري)', prefixIcon: Icon(Icons.phone_android_outlined)),
                ),
                const SizedBox(height: 12),
                if (_zones.isNotEmpty)
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'منطقة التوصيل'),
                    value: selectedZoneId,
                    items: _zones.map<DropdownMenuItem<int>>((z) {
                      return DropdownMenuItem<int>(
                        value: z['id'] as int,
                        child: Text('${z['name']} (${z['fee']} ج.م)', style: const TextStyle(fontFamily: 'Cairo')),
                      );
                    }).toList(),
                    onChanged: (val) => setSheetState(() => selectedZoneId = val),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'العنوان التفصيلي / الشارع / العمارة', prefixIcon: Icon(Icons.home_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'ملاحظات توصيل', prefixIcon: Icon(Icons.note_alt_outlined)),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (nameController.text.trim().isEmpty || phoneController.text.trim().isEmpty) return;
                          setSheetState(() => isSubmitting = true);
                          try {
                            final payload = {
                              'name': nameController.text.trim(),
                              'phone': phoneController.text.trim(),
                              'alternative_phone': altPhoneController.text.trim(),
                              'zone_id': selectedZoneId,
                              'address': addressController.text.trim(),
                              'notes': notesController.text.trim(),
                            };
                            if (customer == null) {
                              await _api.post('/api/v1/admin/delivery-customers/create/', body: payload);
                            } else {
                              await _api.post('/api/v1/admin/delivery-customers/${customer['id']}/update/', body: payload);
                            }
                            if (mounted) {
                              Navigator.pop(sheetContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم حفظ بيانات العميل بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
                              );
                              _loadCustomers();
                            }
                          } catch (e) {
                            setSheetState(() => isSubmitting = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.error),
                              );
                            }
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(customer == null ? 'تسجيل العميل' : 'حفظ التعديلات', style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _customers.where((c) {
      final name = c['name']?.toString().toLowerCase() ?? '';
      final phone = c['phone']?.toString().toLowerCase() ?? '';
      final q = _searchQuery.toLowerCase();
      return q.isEmpty || name.contains(q) || phone.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('دليل عملاء التوصيل (الدليفري)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث', onPressed: _loadCustomers),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('عميل جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        onPressed: () => _showCustomerDialog(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو رقم التليفون...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const AppLoadingView(message: 'جاري تحميل عملاء التوصيل...')
                : _error != null
                    ? AppErrorView(message: _error!, onRetry: _loadCustomers)
                    : filtered.isEmpty
                        ? const AppEmptyView(title: 'لا يوجد عملاء مطابقين للبحث', icon: Icons.contact_phone_outlined)
                        : RefreshIndicator(
                            onRefresh: _loadCustomers,
                            color: AppColors.primary,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final customer = filtered[i] as Map<String, dynamic>;
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: const Icon(Icons.person_pin_circle_outlined, color: AppColors.primary, size: 24),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              customer['name']?.toString() ?? '',
                                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              customer['phone']?.toString() ?? '',
                                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold),
                                            ),
                                            if (customer['address'] != null && customer['address'].toString().isNotEmpty)
                                              Text(
                                                customer['address'].toString(),
                                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary),
                                        onPressed: () => _showCustomerDialog(customer: customer),
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
