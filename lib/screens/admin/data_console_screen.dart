import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/async_views.dart';

class DataConsoleScreen extends StatefulWidget {
  const DataConsoleScreen({super.key});

  @override
  State<DataConsoleScreen> createState() => _DataConsoleScreenState();
}

class _DataConsoleScreenState extends State<DataConsoleScreen> {
  final _api = ApiClient();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _models = [];
  String? _selectedModel;
  final _filterController = TextEditingController();
  List<dynamic>? _previewRows;
  int _matchedCount = 0;
  bool _isPreviewLoading = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _api.setBaseUrl(auth.serverUrl);
    _api.setToken(auth.token);
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.get('/api/v1/admin/data-console/');
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _models = res['models'] as List<dynamic>? ?? [];
          if (_models.isNotEmpty) {
            _selectedModel = _models.first['name']?.toString();
          }
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

  Future<void> _previewQuery() async {
    if (_selectedModel == null) return;
    setState(() {
      _isPreviewLoading = true;
      _previewRows = null;
    });
    try {
      final params = <String, String>{'model': _selectedModel!};
      if (_filterController.text.trim().isNotEmpty) {
        params['filter'] = _filterController.text.trim();
      }
      final res = await _api.get('/api/v1/admin/data-console/', queryParams: params);
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _previewRows = res['preview'] as List<dynamic>? ?? [];
          _matchedCount = res['count'] as int? ?? 0;
          _isPreviewLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPreviewLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في المعاينة: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _executeDelete() async {
    if (_selectedModel == null || _filterController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يجب كتابة شرط فلتر محدد لتفادي مسح كل البيانات', style: TextStyle(fontFamily: 'Cairo'))),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تحذير حذف بيانات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.error)),
        content: Text(
          'أنت على وشك حذف $_matchedCount سجل من جدول $_selectedModel بشرط:\n"${_filterController.text.trim()}".\nسيتم حفظ نسخة احتياطية في سجل التدقيق.\nهل تود المتابعة؟',
          style: const TextStyle(fontFamily: 'Cairo'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('تأكيد الحذف', style: TextStyle(fontFamily: 'Cairo')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await _api.post('/api/v1/admin/data-console/delete/', body: {
        'model': _selectedModel,
        'filter': _filterController.text.trim(),
      });
      if (mounted) {
        final count = (res as Map<String, dynamic>)['deleted_count'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حذف $count سجل بنجاح', style: const TextStyle(fontFamily: 'Cairo'))),
        );
        _previewQuery();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل الحذف: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('لوحة التحكم بالبيانات (Data Console)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _isLoading
          ? const AppLoadingView(message: 'جاري تحميل هياكل البيانات...')
          : _error != null
              ? AppErrorView(message: _error!, onRetry: _loadModels)
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('اختر الجدول / الموديل:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              decoration: const InputDecoration(isDense: true),
                              value: _selectedModel,
                              items: _models.map<DropdownMenuItem<String>>((m) {
                                return DropdownMenuItem<String>(
                                  value: m['name']?.toString(),
                                  child: Text('${m['label']} (${m['name']})', style: const TextStyle(fontFamily: 'Cairo', fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedModel = val;
                                  _previewRows = null;
                                  _matchedCount = 0;
                                });
                              },
                            ),
                            const SizedBox(height: 14),
                            const Text('شرط الاستعلام / الفلتر:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _filterController,
                              decoration: const InputDecoration(
                                hintText: 'مثال: date__lt=2025-01-01 أو id=50',
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                                    icon: const Icon(Icons.preview_outlined, size: 18),
                                    label: const Text('معاينة السجلات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                    onPressed: _isPreviewLoading ? null : _previewQuery,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      side: const BorderSide(color: AppColors.error),
                                    ),
                                    icon: const Icon(Icons.delete_forever_outlined, size: 18),
                                    label: const Text('حذف السجلات', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                                    onPressed: _matchedCount > 0 ? _executeDelete : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_isPreviewLoading)
                        const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
                      else if (_previewRows != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('إجمالي السجلات المطابقة: $_matchedCount', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                            Text('عرض أول ${_previewRows!.length}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_previewRows!.isEmpty)
                          const AppEmptyView(title: 'لا توجد سجلات مطابقة للشرط', icon: Icons.find_in_page_outlined)
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _previewRows!.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final row = _previewRows![i] as Map<String, dynamic>;
                              final id = row['id'] ?? row.values.firstOrNull ?? '';
                              final summary = row.entries.take(4).map((e) => '${e.key}: ${e.value}').join(' • ');
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('سجل #$id', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.primary)),
                                    const SizedBox(height: 4),
                                    Text(summary, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary)),
                                  ],
                                ),
                              );
                            },
                          ),
                      ],
                    ],
                  ),
                ),
    );
  }
}
