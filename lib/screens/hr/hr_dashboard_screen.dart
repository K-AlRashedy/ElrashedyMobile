import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/async_views.dart';
import 'attendance_screen.dart';
import 'employees_screen.dart';
import 'leave_requests_screen.dart';
import 'payroll_screen.dart';
import 'penalties_screen.dart';

class HRDashboardScreen extends StatefulWidget {
  const HRDashboardScreen({super.key});

  @override
  State<HRDashboardScreen> createState() => _HRDashboardScreenState();
}

class _HRDashboardScreenState extends State<HRDashboardScreen> {
  final _api = ApiClient();
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _api.setBaseUrl(auth.serverUrl);
    _api.setToken(auth.token);
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.get('/api/v1/hr/dashboard/');
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _data = res;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('لوحة تحكم شؤون العاملين (HR)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث', onPressed: _loadDashboard),
        ],
      ),
      body: _isLoading
          ? const AppLoadingView(message: 'جاري تحميل مؤشرات الموارد البشرية...')
          : _error != null
              ? AppErrorView(message: _error!, onRetry: _loadDashboard)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Summary metrics
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'الموظفون النشطون',
                            '${_data?['active_employees'] ?? 0} / ${_data?['total_employees'] ?? 0}',
                            Icons.people_outline,
                            AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            'حضور اليوم',
                            '${_data?['attendance']?['present'] ?? 0} حاضر',
                            Icons.how_to_reg_outlined,
                            AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildMetricCard(
                            'طلبات إجازة معلقة',
                            '${_data?['pending_leaves'] ?? 0} طلب',
                            Icons.event_busy_outlined,
                            AppColors.accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildMetricCard(
                            'جزاءات قيد المراجعة',
                            '${_data?['pending_penalties'] ?? 0} جزاء',
                            Icons.gavel_outlined,
                            AppColors.error,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const Text('أقسام وإدارة شؤون العاملين:', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),

                    _buildNavigationCard(
                      title: 'سجل وبيانات الموظفين',
                      subtitle: 'إدارة بيانات العمال، الرواتب الأساسية والبدلات',
                      icon: Icons.badge_outlined,
                      color: AppColors.primary,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EmployeesScreen())),
                    ),
                    const SizedBox(height: 10),

                    _buildNavigationCard(
                      title: 'تسجيل وتحضير الحضور اليومي',
                      subtitle: 'كشف الحضور والانصراف بالفرع، والتأخير والغياب',
                      icon: Icons.fact_check_outlined,
                      color: AppColors.success,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AttendanceScreen())),
                    ),
                    const SizedBox(height: 10),

                    _buildNavigationCard(
                      title: 'طلبات واعتماد الإجازات',
                      subtitle: 'مراجعة طلبات الإجازة العادية والسنوية والاعتماد',
                      icon: Icons.calendar_month_outlined,
                      color: AppColors.accent,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LeaveRequestsScreen())),
                    ),
                    const SizedBox(height: 10),

                    _buildNavigationCard(
                      title: 'سجل الجزاءات والخصومات',
                      subtitle: 'تسجيل واعتماد الجزاءات الإدارية وخصم الأيام',
                      icon: Icons.warning_amber_rounded,
                      color: AppColors.error,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PenaltiesScreen())),
                    ),
                    const SizedBox(height: 10),

                    _buildNavigationCard(
                      title: 'مسيرات الرواتب الشهرية',
                      subtitle: 'توليد الرواتب، خصم السلف والغياب، وصرف المستحقات',
                      icon: Icons.monetization_on_outlined,
                      color: Colors.purple,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PayrollScreen())),
                    ),
                  ],
                ),
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
          Text(value, style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildNavigationCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: color, size: 26),
        ),
        title: Text(title, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textMuted),
        onTap: onTap,
      ),
    );
  }
}
