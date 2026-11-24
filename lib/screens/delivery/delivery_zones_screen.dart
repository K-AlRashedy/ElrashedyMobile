import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/async_views.dart';

class DeliveryZonesScreen extends StatefulWidget {
  const DeliveryZonesScreen({super.key});

  @override
  State<DeliveryZonesScreen> createState() => _DeliveryZonesScreenState();
}

class _DeliveryZonesScreenState extends State<DeliveryZonesScreen> {
  final _api = ApiClient();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _zones = [];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _api.setBaseUrl(auth.serverUrl);
    _api.setToken(auth.token);
    _loadZones();
  }

  Future<void> _loadZones() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.get('/api/v1/admin/delivery-zones/');
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _zones = res['results'] as List<dynamic>? ?? [];
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

  void _showZoneDialog({Map<String, dynamic>? zone}) {
    final nameController = TextEditingController(text: zone?['name']?.toString() ?? '');
    final feeController = TextEditingController(text: zone?['fee']?.toString() ?? '0');
    final minOrderController = TextEditingController(text: zone?['min_order']?.toString() ?? '0');
    final timeController = TextEditingController(text: zone?['estimated_time_minutes']?.toString() ?? '30');
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(zone == null ? 'إضافة منطقة توصيل' : 'تعديل منطقة التوصيل', style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'اسم المنطقة / الحي', prefixIcon: Icon(Icons.map_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: feeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'رسوم التوصيل (ج.م)', prefixIcon: Icon(Icons.delivery_dining_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: minOrderController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'الحد الأدنى للطلب (ج.م)', prefixIcon: Icon(Icons.shopping_bag_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الوقت المقدر (بالدقائق)', prefixIcon: Icon(Icons.timer_outlined)),
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
                        if (nameController.text.trim().isEmpty) return;
                        setSheetState(() => isSubmitting = true);
                        try {
                          final payload = {
                            'name': nameController.text.trim(),
                            'fee': feeController.text.trim(),
                            'min_order': minOrderController.text.trim(),
                            'estimated_time_minutes': int.tryParse(timeController.text.trim()) ?? 30,
                          };
                          if (zone == null) {
                            await _api.post('/api/v1/admin/delivery-zones/create/', body: payload);
                          } else {
                            await _api.post('/api/v1/admin/delivery-zones/${zone['id']}/update/', body: payload);
                          }
                          if (mounted) {
                            Navigator.pop(sheetContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم حفظ منطقة التوصيل بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
                            );
                            _loadZones();
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
                    : Text(zone == null ? 'إضافة المنطقة' : 'حفظ التعديلات', style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('مناطق ورسوم التوصيل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث', onPressed: _loadZones),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('إضافة منطقة', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        onPressed: () => _showZoneDialog(),
      ),
      body: _isLoading
          ? const AppLoadingView(message: 'جاري تحميل مناطق التوصيل...')
          : _error != null
              ? AppErrorView(message: _error!, onRetry: _loadZones)
              : _zones.isEmpty
                  ? const AppEmptyView(title: 'لا توجد مناطق توصيل مسجلة', icon: Icons.map_outlined)
                  : RefreshIndicator(
                      onRefresh: _loadZones,
                      color: AppColors.primary,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                        itemCount: _zones.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final zone = _zones[i] as Map<String, dynamic>;
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
                                  child: const Icon(Icons.location_on_outlined, color: AppColors.primary, size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        zone['name']?.toString() ?? '',
                                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'الوقت المقدر: ${zone['estimated_time_minutes'] ?? 30} دقيقة • الحد الأدنى: ${zone['min_order'] ?? 0} ج.م',
                                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${zone['fee']} ج.م',
                                      style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary),
                                      onPressed: () => _showZoneDialog(zone: zone),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
