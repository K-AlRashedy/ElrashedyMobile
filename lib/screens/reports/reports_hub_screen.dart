import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/async_views.dart';

class ReportsHubScreen extends StatefulWidget {
  const ReportsHubScreen({super.key});

  @override
  State<ReportsHubScreen> createState() => _ReportsHubScreenState();
}

class _ReportsHubScreenState extends State<ReportsHubScreen> with SingleTickerProviderStateMixin {
  final _api = ApiClient();
  late TabController _tabController;
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _branchData;
  Map<String, dynamic>? _indirectCostData;
  List<dynamic> _branches = [];
  int? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final auth = context.read<AuthProvider>();
    _api.setBaseUrl(auth.serverUrl);
    _api.setToken(auth.token);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final boot = await _api.get('/api/v1/bootstrap/');
      if (boot is Map<String, dynamic> && mounted) {
        _branches = boot['branches'] as List<dynamic>? ?? [];
        if (_branches.isNotEmpty && _selectedBranchId == null) {
          _selectedBranchId = _branches.first['id'] as int?;
        }
      }
      final dash = await _api.get('/api/v1/reports/dashboard/');
      if (dash is Map<String, dynamic> && mounted) {
        _dashboardData = dash;
      }
      await _loadBranchReport();
      await _loadIndirectCosts();
      if (mounted) setState(() => _isLoading = false);
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
    if (_selectedBranchId == null) return;
    try {
      final res = await _api.get('/api/v1/reports/branch/', queryParams: {'branch_id': _selectedBranchId.toString()});
      if (res is Map<String, dynamic> && mounted) {
        setState(() => _branchData = res);
      }
    } catch (_) {}
  }

  Future<void> _loadIndirectCosts() async {
    if (_selectedBranchId == null) return;
    try {
      final res = await _api.get('/api/v1/reports/costs/indirect/', queryParams: {'branch_id': _selectedBranchId.toString()});
      if (res is Map<String, dynamic> && mounted) {
        setState(() => _indirectCostData = res);
      }
    } catch (_) {}
  }

  Future<void> _applyIndirectCosts() async {
    if (_selectedBranchId == null) return;
    try {
      final res = await _api.post('/api/v1/reports/costs/indirect/apply/', body: {'branch_id': _selectedBranchId});
      if (mounted) {
        final count = (res as Map<String, dynamic>)['updated_count'] ?? 0;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم توزيع التكاليف وتحديث $count منتج بنجاح', style: const TextStyle(fontFamily: 'Cairo'))),
        );
        _loadIndirectCosts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('التقارير ولوحة المؤشرات (BI)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        bottom: TabBar(
          controller: _tabController,
          labelStyle: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'المؤشرات العامة'),
            Tab(text: 'تقرير الفرع'),
            Tab(text: 'التكاليف غير المباشرة'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث', onPressed: _loadAll),
        ],
      ),
      body: _isLoading
          ? const AppLoadingView(message: 'جاري تحميل التقارير والمؤشرات...')
          : _error != null
              ? AppErrorView(message: _error!, onRetry: _loadAll)
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDashboardTab(),
                    _buildBranchTab(),
                    _buildIndirectCostsTab(),
                  ],
                ),
    );
  }

  Widget _buildDashboardTab() {
    final kpis = _dashboardData?['kpis'] as Map<String, dynamic>? ?? {};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricCard('إجمالي المبيعات', '${kpis['total_sales'] ?? 0} ج.م', Icons.payments_outlined, AppColors.success)),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricCard('إجمالي المصروفات', '${kpis['total_expenses'] ?? 0} ج.م', Icons.receipt_long_outlined, AppColors.error)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildMetricCard('الطلبات الجارية', '${kpis['pending_orders'] ?? 0}', Icons.local_shipping_outlined, AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricCard('الورديات المفتوحة', '${kpis['active_shifts'] ?? 0}', Icons.timelapse_outlined, AppColors.accent)),
          ],
        ),
        const SizedBox(height: 18),
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
              const Text('حالة السيولة بالخزائن النقدية:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 12),
              _buildSafeRow('الخزينة النقدية الكاش', '${_dashboardData?['safes']?['cash'] ?? 0} ج.م'),
              const Divider(height: 16),
              _buildSafeRow('إنستاباي (InstaPay)', '${_dashboardData?['safes']?['instapay'] ?? 0} ج.م'),
              const Divider(height: 16),
              _buildSafeRow('محافظ إلكترونية (فودافون كاش)', '${_dashboardData?['safes']?['wallet'] ?? 0} ج.م'),
              const Divider(height: 16),
              _buildSafeRow('فيزا / شبكة البنوك (Visa)', '${_dashboardData?['safes']?['visa'] ?? 0} ج.م'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBranchTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_branches.isNotEmpty) ...[
          DropdownButtonFormField<int>(
            decoration: const InputDecoration(labelText: 'اختر الفرع لعرض تقريره'),
            value: _selectedBranchId,
            items: _branches.map<DropdownMenuItem<int>>((b) {
              return DropdownMenuItem<int>(
                value: b['id'] as int,
                child: Text(b['name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo')),
              );
            }).toList(),
            onChanged: (val) {
              setState(() => _selectedBranchId = val);
              _loadBranchReport();
            },
          ),
          const SizedBox(height: 16),
        ],
        if (_branchData != null) ...[
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
                Text('تقرير فرع: ${_branchData!['branch']?['name'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('الفترة: من ${_branchData!['start_date'] ?? ''} إلى ${_branchData!['end_date'] ?? ''}', style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontSize: 12)),
                const Divider(height: 20),
                _buildSafeRow('إجمالي مبيعات الفرع', '${_branchData!['sales_total'] ?? 0} ج.م'),
                const Divider(height: 16),
                _buildSafeRow('إجمالي مصروفات الفرع', '${_branchData!['expenses_total'] ?? 0} ج.م'),
                const Divider(height: 16),
                _buildSafeRow('تحويلات صادرة من الفرع', '${_branchData!['outgoing_orders_count'] ?? 0} طلب'),
                const Divider(height: 16),
                _buildSafeRow('تحويلات واردة للفرع', '${_branchData!['incoming_orders_count'] ?? 0} طلب'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIndirectCostsTab() {
    final rows = _indirectCostData?['results'] as List<dynamic>? ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('إجمالي المصروفات: ${_indirectCostData?['total_expenses'] ?? 0} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, color: AppColors.error)),
                const Text('توزيع المصروفات على تكاليف الإنتاج (30 يوماً)', style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              icon: const Icon(Icons.calculate_outlined, size: 18),
              label: const Text('اعتماد التكلفة', style: TextStyle(fontFamily: 'Cairo')),
              onPressed: _applyIndirectCosts,
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (rows.isEmpty)
          const AppEmptyView(title: 'لا توجد منتجات مسجلة للتكاليف غير المباشرة', icon: Icons.calculate_outlined)
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final row = rows[i] as Map<String, dynamic>;
              final p = row['product'] as Map<String, dynamic>? ?? {};
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
                          Text(p['name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                          Text('الكمية المنتجة: ${row['quantity']} • السعر المباشر: ${row['unit_price']} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('التكلفة بعد التوزيع:', style: const TextStyle(fontFamily: 'Cairo', fontSize: 10, color: AppColors.textMuted)),
                        Text('${row['allocated_cost'] ?? row['unit_price']} ج.م', style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildSafeRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textSecondary)),
        Text(value, style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }
}
