import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/async_views.dart';
import '../../widgets/numeric_keypad_sheet.dart';

class DataConsoleScreen extends StatefulWidget {
  const DataConsoleScreen({super.key});

  @override
  State<DataConsoleScreen> createState() => _DataConsoleScreenState();
}

class _DataConsoleScreenState extends State<DataConsoleScreen> {
  bool _isLoading = true;
  String? _error;
  bool _initialized = false;

  List<Map<String, dynamic>> _models = [];
  List<Map<String, dynamic>> _audits = [];
  String? _selectedModel;

  String? _builderField;
  String _builderOp = '==';
  final _builderValueCtrl = TextEditingController();
  final _filterController = TextEditingController();
  String _lastPreviewedExpr = '';

  List<dynamic>? _previewRows;
  int _matchedCount = 0;
  bool _isPreviewLoading = false;
  bool _isDeleting = false;

  static const _operators = [
    {'op': '==', 'label': 'يساوي (==)'},
    {'op': '!=', 'label': 'لا يساوي (!=)'},
    {'op': '~=', 'label': 'يحتوي (~=)'},
    {'op': '^=', 'label': 'يبدأ بـ (^=)'},
    {'op': '>=', 'label': 'أكبر أو يساوي (>=)'},
    {'op': '<=', 'label': 'أصغر أو يساوي (<=)'},
    {'op': '>', 'label': 'أكبر من (>)'},
    {'op': '<', 'label': 'أصغر من (<)'},
  ];

  ApiClient get _api => context.read<ApiClient>();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _filterController.addListener(_onFilterEdited);
      _loadModels();
    }
  }

  void _onFilterEdited() {
    if (_previewRows != null &&
        _filterController.text.trim() != _lastPreviewedExpr) {
      setState(() {
        _previewRows = null;
        _matchedCount = 0;
      });
    }
  }

  @override
  void dispose() {
    _filterController.removeListener(_onFilterEdited);
    _builderValueCtrl.dispose();
    _filterController.dispose();
    super.dispose();
  }

  List<Map<String, String>> _currentModelFields() {
    final model = _models
        .where((m) => m['name']?.toString() == _selectedModel)
        .firstOrNull;
    if (model == null) return [];
    final rawFilterFields = model['filter_fields'] as List<dynamic>? ?? [];
    if (rawFilterFields.isNotEmpty) {
      return rawFilterFields
          .map((f) {
            if (f is Map) {
              final name = f['name']?.toString() ?? '';
              final label = f['label']?.toString() ?? name;
              return {'name': name, 'label': '$label ($name)'};
            }
            final s = f.toString();
            return {'name': s, 'label': s};
          })
          .where((f) => f['name']!.isNotEmpty)
          .toList();
    }
    final rawFields = model['fields'] as List<dynamic>? ?? [];
    return rawFields
        .map((f) {
          final m = f as Map;
          final name = m['name']?.toString() ?? '';
          final label = m['label']?.toString() ?? name;
          return {'name': name, 'label': '$label ($name)'};
        })
        .where((f) => f['name']!.isNotEmpty)
        .toList();
  }

  void _syncDefaultField() {
    final fields = _currentModelFields();
    _builderField = fields.isNotEmpty ? fields.first['name'] : 'id';
  }

  void _applyBuilderExpression() {
    final field = _builderField ?? 'id';
    final rawVal = _builderValueCtrl.text.trim();
    if (rawVal.isEmpty) {
      AppFeedback.showError(context, 'أدخل قيمة لتركيب الشرط');
      return;
    }
    final isPlainLiteral = num.tryParse(rawVal) != null ||
        rawVal == 'true' ||
        rawVal == 'false' ||
        RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(rawVal);
    final formattedVal =
        isPlainLiteral ? rawVal : '"${rawVal.replaceAll('"', '\\"')}"';
    final nextExpr = '$field $_builderOp $formattedVal';
    setState(() {
      _filterController.text = nextExpr;
      _previewRows = null;
      _matchedCount = 0;
    });
  }

  Future<void> _openValueKeypad() async {
    final res = await AppNumericKeypadSheet.showString(
      context,
      title: 'إدخال قيمة رقمية للشرط',
      initialText: _builderValueCtrl.text.trim(),
      allowDecimal: true,
      allowNegative: true,
      isStringMode: false,
    );
    if (res != null && mounted) {
      setState(() => _builderValueCtrl.text = res);
    }
  }

  Future<void> _loadModels() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.get('/api/v1/admin/data-console/');
      if (!mounted) return;
      if (res is Map<String, dynamic>) {
        setState(() {
          _models = (res['models'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _audits = (res['audits'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          if (_models.isNotEmpty &&
              (_selectedModel == null ||
                  !_models.any(
                    (m) => m['name']?.toString() == _selectedModel,
                  ))) {
            _selectedModel = _models.first['name']?.toString();
          }
          _syncDefaultField();
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

  Future<void> _previewQuery() async {
    if (_selectedModel == null) return;
    if (_filterController.text.trim().isEmpty &&
        _builderValueCtrl.text.trim().isNotEmpty) {
      _applyBuilderExpression();
    }
    final expr = _filterController.text.trim();
    setState(() {
      _isPreviewLoading = true;
      _previewRows = null;
      _matchedCount = 0;
    });
    try {
      final params = <String, String>{'model': _selectedModel!};
      if (expr.isNotEmpty) {
        params['filter'] = expr;
      }
      final res = await _api.get(
        '/api/v1/admin/data-console/',
        queryParams: params,
      );
      if (!mounted) return;
      if (res is Map<String, dynamic>) {
        setState(() {
          _lastPreviewedExpr = expr;
          _previewRows = res['preview'] as List<dynamic>? ?? [];
          _matchedCount = (res['count'] as num?)?.toInt() ?? 0;
          _audits = (res['audits'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _isPreviewLoading = false;
        });
      } else {
        setState(() => _isPreviewLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPreviewLoading = false);
        AppFeedback.showError(context, 'خطأ في المعاينة: $e');
      }
    }
  }

  Future<void> _executeDelete() async {
    final expr = _filterController.text.trim();
    if (_selectedModel == null || expr.isEmpty) {
      AppFeedback.showError(
        context,
        'يجب تحديد شرط فلتر دقيق ومعاينته أولاً لتفادي مسح كل البيانات',
      );
      return;
    }
    if (expr != _lastPreviewedExpr || _previewRows == null) {
      AppFeedback.showError(
        context,
        'تغيّر نص الفلتر! اضغط "معاينة السجلات" للتحقق من العدد الجديد قبل الحذف.',
      );
      return;
    }

    final confirm = await AppConfirmDialog.show(
      context,
      title: 'تحذير حذف بيانات',
      message:
          'أنت على وشك حذف $_matchedCount سجل من جدول $_selectedModel بشرط:\n"$expr"\nسيتم حفظ نسخة احتياطية كاملة في سجل التدقيق.\nهل تود المتابعة؟',
      confirmLabel: 'تأكيد الحذف النهائي',
      isDestructive: true,
    );
    if (!confirm || !mounted) return;

    setState(() => _isDeleting = true);
    try {
      final res = await _api.post(
        '/api/v1/admin/data-console/delete/',
        body: {
          'model': _selectedModel,
          'filter': expr,
        },
      );
      if (!mounted) return;
      setState(() => _isDeleting = false);
      final count = (res as Map<String, dynamic>)['deleted_count'] ?? 0;
      AppFeedback.showSuccess(
        context,
        'تم حذف $count سجل وتسجيل نسخة احتياطية بنجاح',
      );
      _previewQuery();
    } catch (e) {
      if (mounted) {
        setState(() => _isDeleting = false);
        AppFeedback.showError(context, 'فشل الحذف: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = _currentModelFields();
    final canDelete = !_isPreviewLoading &&
        !_isDeleting &&
        _previewRows != null &&
        _matchedCount > 0 &&
        _filterController.text.trim().isNotEmpty &&
        _filterController.text.trim() == _lastPreviewedExpr;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'وحدة إدارة البيانات (Data Console)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loadModels,
          ),
        ],
      ),
      body: _isLoading
          ? const AppLoadingView(
              message: 'جاري تحميل هياكل البيانات وسجل التدقيق...',
            )
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
                            const Text(
                              '1. اختر الجدول / الموديل:',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              decoration: const InputDecoration(isDense: true),
                              value: _models.any(
                                      (m) => m['name']?.toString() == _selectedModel)
                                  ? _selectedModel
                                  : null,
                              items: _models.map<DropdownMenuItem<String>>((m) {
                                return DropdownMenuItem<String>(
                                  value: m['name']?.toString(),
                                  child: Text(
                                    '${m['label']} (${m['name']})',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontFamily: 'Cairo',
                                      fontSize: 13,
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedModel = val;
                                  _previewRows = null;
                                  _matchedCount = 0;
                                  _lastPreviewedExpr = '';
                                  _syncDefaultField();
                                });
                              },
                            ),
                            const SizedBox(height: 14),
                            const Text(
                              '2. منشئ شرط الاستعلام الآمن:',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (fields.isNotEmpty)
                              Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      value: fields.any(
                                              (f) => f['name'] == _builderField)
                                          ? _builderField
                                          : fields.first['name'],
                                      decoration: const InputDecoration(
                                        labelText: 'الحقل',
                                        isDense: true,
                                      ),
                                      items: fields
                                          .map(
                                            (f) => DropdownMenuItem<String>(
                                              value: f['name'],
                                              child: Text(
                                                f['label']!,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) =>
                                          setState(() => _builderField = v),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: DropdownButtonFormField<String>(
                                      isExpanded: true,
                                      value: _builderOp,
                                      decoration: const InputDecoration(
                                        labelText: 'المعامل',
                                        isDense: true,
                                      ),
                                      items: _operators
                                          .map(
                                            (o) => DropdownMenuItem<String>(
                                              value: o['op'],
                                              child: Text(
                                                o['label']!,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontFamily: 'Cairo',
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (v) => setState(
                                        () => _builderOp = v ?? '==',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _builderValueCtrl,
                                    decoration: InputDecoration(
                                      labelText: 'القيمة (رقم، تاريخ، أو نص)',
                                      isDense: true,
                                      suffixIcon: IconButton(
                                        tooltip: 'لوحة أرقام التطبيق',
                                        icon: const Icon(
                                          Icons.dialpad_rounded,
                                          color: AppColors.primary,
                                          size: 20,
                                        ),
                                        onPressed: _openValueKeypad,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    minimumSize: const Size(0, 48),
                                  ),
                                  onPressed: _applyBuilderExpression,
                                  child: const Text(
                                    'تركيب الشرط',
                                    style: TextStyle(
                                      fontFamily: 'Cairo',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _filterController,
                              decoration: const InputDecoration(
                                labelText: 'التعبير النهائي للفلتر',
                                hintText:
                                    'مثال: id == 50 أو date <= 2025-01-01',
                                isDense: true,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      minimumSize: const Size(0, 48),
                                    ),
                                    icon: const Icon(
                                      Icons.preview_outlined,
                                      size: 18,
                                    ),
                                    label: const Text(
                                      'معاينة السجلات',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onPressed: _isPreviewLoading || _isDeleting
                                        ? null
                                        : _previewQuery,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppColors.error,
                                      minimumSize: const Size(0, 48),
                                      side: BorderSide(
                                        color: canDelete
                                            ? AppColors.error
                                            : AppColors.border,
                                      ),
                                    ),
                                    icon: _isDeleting
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.delete_forever_outlined,
                                            size: 18,
                                          ),
                                    label: const Text(
                                      'حذف السجلات',
                                      style: TextStyle(
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    onPressed: canDelete ? _executeDelete : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_isPreviewLoading)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_previewRows != null) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'إجمالي السجلات المطابقة: $_matchedCount',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'معاينة أول ${_previewRows!.length}',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_previewRows!.isEmpty)
                          const AppEmptyView(
                            title: 'لا توجد سجلات مطابقة للشرط',
                            icon: Icons.find_in_page_outlined,
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _previewRows!.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, i) {
                              final row = Map<String, dynamic>.from(
                                _previewRows![i] as Map,
                              );
                              final id =
                                  row['id'] ?? row.values.firstOrNull ?? '';
                              final summary = row.entries
                                  .take(5)
                                  .map((e) => '${e.key}: ${e.value}')
                                  .join(' • ');
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'سجل #$id',
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      summary,
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 11.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        const SizedBox(height: 20),
                      ],
                      if (_audits.isNotEmpty) ...[
                        const Text(
                          'سجل التدقيق والنسخ الاحتياطي للحذف الأخير:',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._audits.map((a) {
                          final expr = (a['filters'] as Map?)?['expression']
                                  ?.toString() ??
                              '';
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.history_rounded,
                                  color: AppColors.accentAmber,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${a['model_label']} · حُذف ${a['deleted_count']} سجل',
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      Text(
                                        'بواسطة ${a['actor'] ?? '-'} | الشرط: $expr',
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
    );
  }
}
