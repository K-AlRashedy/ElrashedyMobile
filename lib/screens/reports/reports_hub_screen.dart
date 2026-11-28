import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../models/branch_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_feedback.dart';
import '../../widgets/async_views.dart';
import '../../widgets/numeric_keypad_sheet.dart';

class ReportsHubScreen extends StatefulWidget {
  final int initialTab;
  final String? costSubFilter; // 'all' | 'complete' | 'incomplete' | 'raw'
  final String initialBranchReportType; // 'profits' | 'sales' | 'expenses'

  const ReportsHubScreen({
    super.key,
    this.initialTab = 0,
    this.costSubFilter,
    this.initialBranchReportType = 'profits',
  });

  @override
  State<ReportsHubScreen> createState() => _ReportsHubScreenState();
}

class _ReportsHubScreenState extends State<ReportsHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  String? _error;
  bool _initialized = false;

  // Tab 0: Dashboard & Balances
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _balancesData;
  List<BranchModel> _fallbackBranches = [];

  // Tab 1: Branch Reports
  int? _selectedBranchId;
  late String _reportType; // sales | expenses | profits
  late String _selectedMonth; // YYYY-MM
  Map<String, dynamic>? _branchReportData;
  bool _loadingBranchReport = false;
  String? _branchError;

  // Tab 2: Direct Costing & BOM
  late String _costFilter; // all | complete | incomplete | raw
  List<Map<String, dynamic>> _costProducts = [];
  bool _loadingDirectCosts = false;
  String? _directCostError;
  bool _applyingDirect = false;

  // Tab 3: Indirect Costing
  Map<String, dynamic>? _indirectCostData;
  bool _loadingIndirect = false;
  String? _indirectError;
  bool _applyingIndirect = false;

  ApiClient get _api => context.read<ApiClient>();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    _costFilter = widget.costSubFilter ?? 'all';
    _reportType = const {'profits', 'sales', 'expenses'}
            .contains(widget.initialBranchReportType)
        ? widget.initialBranchReportType
        : 'profits';

    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 3),
    );

    _tabController.addListener(() {
      if (!_tabController.indexIsChanging && mounted) {
        if (_tabController.index == 1 && _branchReportData == null) {
          _loadBranchReport();
        }
        if (_tabController.index == 2 && _costProducts.isEmpty) {
          _loadDirectCosts();
        }
        if (_tabController.index == 3 && _indirectCostData == null) {
          _loadIndirectCosts();
        }
        setState(() {});
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final auth = context.read<AuthProvider>();
      final branches =
          auth.userBranches.isNotEmpty ? auth.userBranches : auth.allBranches;
      if (branches.isNotEmpty) {
        _selectedBranchId = branches.first.id;
      }
      _loadAll();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<BranchModel> _availableBranches(AuthProvider auth) {
    if (auth.userBranches.isNotEmpty) return auth.userBranches;
    if (auth.allBranches.isNotEmpty) return auth.allBranches;
    return _fallbackBranches;
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _api.get('/api/v1/reports/dashboard/'),
        _api
            .get('/api/v1/treasury/balances/')
            .catchError((_) => <String, dynamic>{}),
      ]);
      if (!mounted) return;

      final dash = results[0] as Map<String, dynamic>?;
      final rawBranches = _mapList(dash?['branches']);
      final parsedBranches = rawBranches
          .where((b) => b['id'] != null)
          .map(
            (b) => BranchModel(
              id: (b['id'] as num).toInt(),
              name: b['name']?.toString() ?? '',
              type: b['type']?.toString() ?? 'SHOP',
            ),
          )
          .toList();

      setState(() {
        _dashboardData = dash;
        _balancesData = results[1] as Map<String, dynamic>?;
        _fallbackBranches = parsedBranches;
        if (_selectedBranchId == null && parsedBranches.isNotEmpty) {
          _selectedBranchId = parsedBranches.first.id;
        }
        _isLoading = false;
      });
      if (_tabController.index == 1) _loadBranchReport();
      if (_tabController.index == 2) _loadDirectCosts();
      if (_tabController.index == 3) _loadIndirectCosts();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadBranchReport() async {
    if (_selectedBranchId == null) {
      setState(() {
        _loadingBranchReport = false;
        _branchError = 'لا توجد فروع متاحة لعرض التقرير.';
      });
      return;
    }
    setState(() {
      _loadingBranchReport = true;
      _branchError = null;
    });
    try {
      final res = await _api.get(
        '/api/v1/reports/branch/',
        queryParams: {
          'branch_id': _selectedBranchId.toString(),
          'report_type': _reportType,
          'month': _selectedMonth,
        },
      );
      if (!mounted) return;
      if (res is Map<String, dynamic>) {
        setState(() {
          _branchReportData = res;
          _loadingBranchReport = false;
        });
      } else {
        setState(() {
          _loadingBranchReport = false;
          _branchError = 'استجابة غير متوقعة من الخادم';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingBranchReport = false;
          _branchError = e.toString();
        });
      }
    }
  }

  Future<void> _loadDirectCosts() async {
    setState(() {
      _loadingDirectCosts = true;
      _directCostError = null;
    });
    try {
      String endpoint = '/api/v1/reports/costs/';
      if (_costFilter == 'complete') {
        endpoint = '/api/v1/reports/costs/bom-complete/';
      }
      if (_costFilter == 'incomplete') {
        endpoint = '/api/v1/reports/costs/bom-incomplete/';
      }
      if (_costFilter == 'raw') {
        endpoint = '/api/v1/reports/costs/raw-materials/';
      }

      final res = await _api.get(endpoint);
      if (!mounted) return;
      if (res is Map<String, dynamic>) {
        setState(() {
          _costProducts = _mapList(res['results']);
          _loadingDirectCosts = false;
        });
      } else {
        setState(() {
          _loadingDirectCosts = false;
          _directCostError = 'استجابة غير متوقعة من الخادم';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingDirectCosts = false;
          _directCostError = e.toString();
        });
      }
    }
  }

  Future<void> _applyAllDirectCosts() async {
    if (_applyingDirect) return;
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'احتساب واعتماد التكلفة المباشرة',
      message:
          'سيتم إعادة احتساب وتحديث التكلفة المباشرة لجميع أصناف الإنتاج بناءً على وصفاتها الحالية. هل تود المتابعة؟',
      confirmLabel: 'اعتماد الكل',
    );
    if (!confirmed || !mounted) return;

    setState(() => _applyingDirect = true);
    try {
      final res = await _api.post('/api/v1/reports/costs/direct/apply/', body: {});
      if (!mounted) return;
      setState(() => _applyingDirect = false);
      AppFeedback.showSuccess(
        context,
        (res as Map?)?['message']?.toString() ??
            'تم تحديث تكاليف جميع الأصناف بنجاح',
      );
      _loadDirectCosts();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _applyingDirect = false);
      if (e.statusCode == 404) {
        AppFeedback.showError(
          context,
          'تحديث التكلفة المباشرة المجمّع غير متاح على إصدار الخادم الحالي.',
        );
      } else {
        AppFeedback.showError(context, e.toString());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _applyingDirect = false);
      AppFeedback.showError(context, e.toString());
    }
  }

  Future<void> _showProductCostDetailSheet(int productId) async {
    try {
      final res = await _api.get('/api/v1/reports/costs/$productId/');
      if (res is! Map<String, dynamic> || !mounted) return;
      final components = _mapList(res['components']);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.72,
          maxChildSize: 0.92,
          minChildSize: 0.45,
          expand: false,
          builder: (_, sc) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
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
                  children: [
                    Expanded(
                      child: Text(
                        'بطاقة التكلفة: ${res['name'] ?? ''}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      _buildSafeRow(
                        'التكلفة المباشرة للوحدة',
                        '${res['direct_cost'] ?? 0} ج.م',
                      ),
                      const Divider(height: 12),
                      _buildSafeRow(
                        'إجمالي تكلفة الباتش (${res['patch'] ?? 1})',
                        '${res['direct_total'] ?? 0} ج.م',
                      ),
                      const Divider(height: 12),
                      _buildSafeRow(
                        'سعر البيع الحالي',
                        '${res['selling_price'] ?? 0} ج.م',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'تفصيل المكونات (${components.length}):',
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: components.isEmpty
                      ? const Center(
                          child: Text(
                            'لا توجد مكونات مسجلة',
                            style: TextStyle(fontFamily: 'Cairo'),
                          ),
                        )
                      : ListView.separated(
                          controller: sc,
                          itemCount: components.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 10),
                          itemBuilder: (_, i) {
                            final c = components[i];
                            final name = c['product_name']?.toString() ??
                                c['product']?['name']?.toString() ??
                                '';
                            return Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      Text(
                                        'الكمية: ${c['quantity']} • سعر الوحدة: ${c['unit_price']} ج.م',
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${c['line_cost'] ?? 0} ج.م',
                                  style: const TextStyle(
                                    fontFamily: 'Cairo',
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) AppFeedback.showError(context, e.toString());
    }
  }

  Future<void> _loadIndirectCosts() async {
    if (_selectedBranchId == null) {
      setState(() {
        _loadingIndirect = false;
        _indirectError = 'لا توجد فروع متاحة لعرض التكاليف غير المباشرة.';
      });
      return;
    }
    setState(() {
      _loadingIndirect = true;
      _indirectError = null;
    });
    try {
      final res = await _api.get(
        '/api/v1/reports/costs/indirect/',
        queryParams: {'branch_id': _selectedBranchId.toString()},
      );
      if (!mounted) return;
      if (res is Map<String, dynamic>) {
        setState(() {
          _indirectCostData = res;
          _loadingIndirect = false;
        });
      } else {
        setState(() {
          _loadingIndirect = false;
          _indirectError = 'استجابة غير متوقعة من الخادم';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingIndirect = false;
          _indirectError = e.toString();
        });
      }
    }
  }

  Future<void> _applyIndirectCosts() async {
    if (_selectedBranchId == null || _applyingIndirect) return;
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'اعتماد وتوزيع التكاليف غير المباشرة',
      message:
          'سيتم توزيع مصروفات الـ 30 يوماً واعتماد التكلفة غير المباشرة لأصناف الفرع المحدد. هل تود المتابعة؟',
      confirmLabel: 'اعتماد التكلفة',
    );
    if (!confirmed || !mounted) return;

    setState(() => _applyingIndirect = true);
    try {
      final res = await _api.post(
        '/api/v1/reports/costs/indirect/apply/',
        body: {'branch_id': _selectedBranchId},
      );
      if (!mounted) return;
      setState(() => _applyingIndirect = false);
      AppFeedback.showSuccess(
        context,
        (res as Map?)?['message']?.toString() ??
            'تم توزيع واعتماد التكاليف غير المباشرة بنجاح',
      );
      _loadIndirectCosts();
    } catch (e) {
      if (!mounted) return;
      setState(() => _applyingIndirect = false);
      AppFeedback.showError(context, e.toString());
    }
  }

  List<Map<String, dynamic>> _mapList(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return const [];
  }

  String _formatNetProfit(dynamic val) {
    if (val is num) {
      return AppNumericKeypadSheet.formatNumber(val.toDouble());
    }
    final parsed = double.tryParse(val?.toString() ?? '');
    if (parsed != null) return AppNumericKeypadSheet.formatNumber(parsed);
    return '${val ?? 0}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'التقارير والتحليلات والتكاليف',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'تحديث',
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'المؤشرات العامة'),
            Tab(text: 'تقارير الفروع الشهرية'),
            Tab(text: 'التكلفة المباشرة والـ BOM'),
            Tab(text: 'التكاليف غير المباشرة'),
          ],
        ),
      ),
      body: _isLoading
          ? const AppLoadingView(message: 'جاري تجميع التقارير المالية...')
          : _error != null
              ? AppErrorView(message: _error!, onRetry: _loadAll)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDashboardTab(),
                    _buildBranchTab(),
                    _buildDirectCostTab(),
                    _buildIndirectCostsTab(),
                  ],
                ),
    );
  }

  Widget _buildDashboardTab() {
    final kpis = _mapList(_dashboardData?['kpis']);
    final alerts = _mapList(_dashboardData?['alerts']);
    final tables = _dashboardData?['tables'] as Map<String, dynamic>? ?? {};
    final lowInventory = _mapList(tables['low_inventory']);
    final safes = _mapList(_balancesData?['safes']);

    return RefreshIndicator(
      onRefresh: _loadAll,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (kpis.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.48,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: kpis.length,
              itemBuilder: (_, i) {
                final k = kpis[i];
                final isMoney = k['money'] == true;
                return _buildMetricCard(
                  k['title']?.toString() ?? '',
                  '${k['value']}${isMoney ? ' ج.م' : ''}',
                  isMoney ? Icons.payments_outlined : Icons.analytics_outlined,
                  AppColors.primary,
                );
              },
            ),
          if (alerts.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'تنبيهات تحتاج مراجعة:',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            ...alerts.map(
              (a) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentAmberSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.accentAmber.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.accentAmber,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${a['title'] ?? ''}: ${a['count'] ?? a['message'] ?? ''}',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (safes.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'أرصدة الخزائن:',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: safes
                    .map(
                      (s) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: _buildSafeRow(
                          '${s['label']}',
                          '${s['amount']} ج.م',
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          if (lowInventory.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'تنبيهات انخفاض المخزون:',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: lowInventory.map((row) {
                  final prodName = row['product_name']?.toString() ??
                      row['product']?['name']?.toString() ??
                      '';
                  final brName = row['branch']?['name']?.toString() ??
                      row['branch_name']?.toString() ??
                      '';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: _buildSafeRow(
                      brName.isNotEmpty ? '$prodName ($brName)' : prodName,
                      '${row['quantity']}',
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBranchTab() {
    final auth = context.watch<AuthProvider>();
    final branches = _availableBranches(auth);
    final months = List.generate(12, (idx) {
      final d = DateTime(DateTime.now().year, DateTime.now().month - idx, 1);
      return '${d.year}-${d.month.toString().padLeft(2, '0')}';
    });

    final lineChart = _branchReportData?['line_chart_data'] as List<dynamic>? ??
        const [];

    return RefreshIndicator(
      onRefresh: _loadBranchReport,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                if (branches.isNotEmpty)
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'الفرع',
                      isDense: true,
                    ),
                    value: branches.any((b) => b.id == _selectedBranchId)
                        ? _selectedBranchId
                        : branches.first.id,
                    items: branches
                        .map(
                          (b) => DropdownMenuItem<int>(
                            value: b.id,
                            child: Text(
                              b.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontFamily: 'Cairo'),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      setState(() => _selectedBranchId = val);
                      _loadBranchReport();
                    },
                  ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'نوع التقرير',
                          isDense: true,
                        ),
                        value: _reportType,
                        items: const [
                          DropdownMenuItem(
                            value: 'profits',
                            child: Text(
                              'صافي الأرباح والخسائر',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'sales',
                            child: Text(
                              'المبيعات اليومية',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'expenses',
                            child: Text(
                              'تحليل المصروفات',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontFamily: 'Cairo', fontSize: 12.5),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _reportType = val);
                            _loadBranchReport();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'الشهر',
                          isDense: true,
                        ),
                        value: months.contains(_selectedMonth)
                            ? _selectedMonth
                            : months.first,
                        items: months
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(
                                  m,
                                  style: const TextStyle(fontFamily: 'Cairo'),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedMonth = val);
                            _loadBranchReport();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_loadingBranchReport)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_branchError != null)
            AppErrorView(message: _branchError!, onRetry: _loadBranchReport)
          else if (_branchReportData != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'فرع ${_branchReportData!['branch']?['name'] ?? ''} — $_selectedMonth',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(height: 20),
                  if (_reportType == 'profits') ...[
                    _buildSafeRow(
                      'إجمالي المبيعات المعتمدة',
                      '${_branchReportData!['total_sales'] ?? 0} ج.م',
                    ),
                    const Divider(height: 14),
                    _buildSafeRow(
                      'إجمالي الرواتب والبدلات',
                      '${_branchReportData!['salaries'] ?? 0} ج.م',
                    ),
                    const Divider(height: 14),
                    _buildSafeRow(
                      'إجمالي مصروفات الفرع',
                      '${_branchReportData!['expenses'] ?? 0} ج.م',
                    ),
                    const Divider(height: 14),
                    _buildSafeRow(
                      'تكلفة التحويلات المنصرفة',
                      '${_branchReportData!['transfers'] ?? 0} ج.م',
                    ),
                    const Divider(height: 18),
                    _buildSafeRow(
                      'صافي الربح التشغيلي',
                      '${_formatNetProfit(_branchReportData!['net_profit'])} ج.م',
                      highlight: true,
                    ),
                  ] else if (_reportType == 'sales') ...[
                    _buildSafeRow(
                      'إجمالي مبيعات الشهر',
                      '${_branchReportData!['total_sales'] ?? 0} ج.م',
                      highlight: true,
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(
                      (_branchReportData!['labels'] as List<dynamic>? ?? [])
                          .length,
                      (i) {
                        final day = (_branchReportData!['labels'] as List)[i];
                        final chartList =
                            _branchReportData!['chart_data'] as List? ?? [];
                        final val = i < chartList.length ? chartList[i] : 0;
                        if (val is num && val == 0) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: _buildSafeRow(
                            'يوم $day/$_selectedMonth',
                            '$val ج.م',
                          ),
                        );
                      },
                    ),
                  ] else ...[
                    _buildSafeRow(
                      'إجمالي مصروفات الشهر',
                      '${_branchReportData!['total_expenses'] ?? 0} ج.م',
                      highlight: true,
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(
                      (_branchReportData!['pie_labels'] as List<dynamic>? ?? [])
                          .length,
                      (i) {
                        final cat =
                            (_branchReportData!['pie_labels'] as List)[i];
                        final pieData =
                            _branchReportData!['pie_data'] as List? ?? [];
                        final val = i < pieData.length ? pieData[i] : 0;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: _buildSafeRow('$cat', '$val ج.م'),
                        );
                      },
                    ),
                    if (lineChart.isNotEmpty) ...[
                      const Divider(height: 20),
                      const Text(
                        'توزيع المصروفات اليومي:',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...List.generate(lineChart.length, (i) {
                        final v = lineChart[i];
                        if (v is num && v == 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: _buildSafeRow(
                            'يوم ${i + 1}/$_selectedMonth',
                            '$v ج.م',
                          ),
                        );
                      }),
                    ],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDirectCostTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'تحليل التكلفة المباشرة للأصناف:',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                icon: _applyingDirect
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.bolt_rounded, size: 18),
                label: const Text(
                  'احتساب واعتماد الكل',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _applyingDirect ? null : _applyAllDirectCosts,
              ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              _costChip('كل أصناف الإنتاج', 'all'),
              const SizedBox(width: 6),
              _costChip('مكتملة الوصفة', 'complete'),
              const SizedBox(width: 6),
              _costChip('غير مكتملة', 'incomplete'),
              const SizedBox(width: 6),
              _costChip('المواد الخام', 'raw'),
            ],
          ),
        ),
        Expanded(
          child: _loadingDirectCosts
              ? const AppLoadingView(message: 'جاري احتساب تكاليف المنتجات...')
              : _directCostError != null
                  ? AppErrorView(
                      message: _directCostError!,
                      onRetry: _loadDirectCosts,
                    )
                  : _costProducts.isEmpty
                      ? const AppEmptyView(title: 'لا توجد أصناف مطابقة')
                      : RefreshIndicator(
                          onRefresh: _loadDirectCosts,
                          color: AppColors.primary,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _costProducts.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final p = _costProducts[i];
                              return InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: _costFilter == 'raw'
                                    ? null
                                    : () => _showProductCostDetailSheet(
                                          p['id'] as int,
                                        ),
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${p['name']}',
                                              style: const TextStyle(
                                                fontFamily: 'Cairo',
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            Text(
                                              'بيع: ${p['selling_price']} ج.م • مكونات: ${p['component_count'] ?? '-'}',
                                              style: const TextStyle(
                                                fontFamily: 'Cairo',
                                                fontSize: 12,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${p['direct_cost'] ?? p['price']} ج.م',
                                        style: const TextStyle(
                                          fontFamily: 'Cairo',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
        ),
      ],
    );
  }

  Widget _costChip(String label, String val) {
    final sel = _costFilter == val;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontFamily: 'Cairo',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: sel ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: sel,
      selectedColor: AppColors.primary,
      onSelected: (_) {
        setState(() => _costFilter = val);
        _loadDirectCosts();
      },
    );
  }

  Widget _buildIndirectCostsTab() {
    final auth = context.watch<AuthProvider>();
    final branches = _availableBranches(auth);
    final rows = _mapList(_indirectCostData?['results']);

    return RefreshIndicator(
      onRefresh: _loadIndirectCosts,
      color: AppColors.primary,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (branches.isNotEmpty) ...[
            DropdownButtonFormField<int>(
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'الفرع / مركز التكلفة',
                isDense: true,
              ),
              value: branches.any((b) => b.id == _selectedBranchId)
                  ? _selectedBranchId
                  : branches.first.id,
              items: branches
                  .map(
                    (b) => DropdownMenuItem<int>(
                      value: b.id,
                      child: Text(
                        b.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontFamily: 'Cairo'),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (val) {
                setState(() => _selectedBranchId = val);
                _loadIndirectCosts();
              },
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مصروفات الـ 30 يوماً: ${_indirectCostData?['total_expenses'] ?? '0.00'} ج.م',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                    ),
                    const Text(
                      'توزيع نسبي على نشاط الإنتاج والمبيعات',
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                icon: _applyingIndirect
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.calculate_outlined, size: 18),
                label: const Text(
                  'اعتماد التكلفة',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _applyingIndirect ? null : _applyIndirectCosts,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_loadingIndirect)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_indirectError != null)
            AppErrorView(
              message: _indirectError!,
              onRetry: _loadIndirectCosts,
            )
          else if (rows.isEmpty)
            const AppEmptyView(
              title: 'لا توجد منتجات مسجلة للتكاليف غير المباشرة',
              icon: Icons.calculate_outlined,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final row = rows[i];
                final p = row['product'] as Map<String, dynamic>? ?? {};
                final prodName =
                    p['name']?.toString() ?? row['product_name']?.toString() ?? '';
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              prodName,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'الكمية: ${row['quantity']} • السعر المباشر: ${row['unit_price']} ج.م',
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${row['allocated_cost'] ?? row['unit_price']} ج.م',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSafeRow(
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Cairo',
              fontSize: highlight ? 14 : 13,
              fontWeight: highlight ? FontWeight.bold : FontWeight.normal,
              color: highlight ? AppColors.textPrimary : AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'Cairo',
            fontSize: highlight ? 15 : 14,
            fontWeight: FontWeight.bold,
            color: highlight ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
