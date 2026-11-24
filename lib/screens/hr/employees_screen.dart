import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/async_views.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final _api = ApiClient();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _employees = [];
  List<dynamic> _branches = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _api.setBaseUrl(auth.serverUrl);
    _api.setToken(auth.token);
    _loadEmployees();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final res = await _api.get('/api/v1/bootstrap/');
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _branches = res['branches'] as List<dynamic>? ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadEmployees() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.get('/api/v1/hr/employees/');
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _employees = res['results'] as List<dynamic>? ?? [];
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

  void _showEmployeeForm({Map<String, dynamic>? employee}) {
    final nameController = TextEditingController(text: employee?['name']?.toString() ?? '');
    final nationalIdController = TextEditingController(text: employee?['national_id']?.toString() ?? '');
    final phoneController = TextEditingController(text: employee?['phone']?.toString() ?? '');
    final salaryController = TextEditingController(text: employee?['basic_salary']?.toString() ?? '');
    final jobTitleController = TextEditingController(text: employee?['job_title']?.toString() ?? '');
    int? selectedBranchId = employee?['branch_id'] as int? ?? (_branches.isNotEmpty ? _branches.first['id'] as int? : null);
    String shiftType = employee?['shift_type']?.toString() ?? 'morning';
    bool isInsured = employee?['is_insured'] == true;
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
                    Text(employee == null ? 'إضافة موظف جديد' : 'تعديل بيانات الموظف', style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف', prefixIcon: Icon(Icons.phone_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nationalIdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'الرقم القومي (14 رقم)', prefixIcon: Icon(Icons.credit_card_outlined)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: jobTitleController,
                  decoration: const InputDecoration(labelText: 'المسمى الوظيفي / المهنة', prefixIcon: Icon(Icons.work_outline)),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: salaryController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'الراتب الأساسي (ج.م)', prefixIcon: Icon(Icons.payments_outlined)),
                ),
                const SizedBox(height: 12),
                if (_branches.isNotEmpty)
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'فرع العمل'),
                    value: selectedBranchId,
                    items: _branches.map<DropdownMenuItem<int>>((b) {
                      return DropdownMenuItem<int>(
                        value: b['id'] as int,
                        child: Text(b['name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo')),
                      );
                    }).toList(),
                    onChanged: (val) => setSheetState(() => selectedBranchId = val),
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'الوردية'),
                  value: shiftType,
                  items: const [
                    DropdownMenuItem(value: 'morning', child: Text('صباحية', style: TextStyle(fontFamily: 'Cairo'))),
                    DropdownMenuItem(value: 'evening', child: Text('مسائية', style: TextStyle(fontFamily: 'Cairo'))),
                    DropdownMenuItem(value: 'night', child: Text('ليلية', style: TextStyle(fontFamily: 'Cairo'))),
                  ],
                  onChanged: (val) => setSheetState(() => shiftType = val ?? 'morning'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('مؤمن عليه اجتماعياً (تأمين 350 ج)', style: TextStyle(fontFamily: 'Cairo', fontSize: 14)),
                  value: isInsured,
                  onChanged: (val) => setSheetState(() => isInsured = val),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (nameController.text.trim().isEmpty || salaryController.text.trim().isEmpty) return;
                          setSheetState(() => isSubmitting = true);
                          try {
                            final payload = {
                              'name': nameController.text.trim(),
                              'national_id': nationalIdController.text.trim(),
                              'phone': phoneController.text.trim(),
                              'basic_salary': salaryController.text.trim(),
                              'job_title': jobTitleController.text.trim(),
                              'branch_id': selectedBranchId,
                              'shift_type': shiftType,
                              'is_insured': isInsured,
                            };
                            if (employee == null) {
                              await _api.post('/api/v1/hr/employees/create/', body: payload);
                            } else {
                              await _api.post('/api/v1/hr/employees/${employee['id']}/update/', body: payload);
                            }
                            if (mounted) {
                              Navigator.pop(sheetContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم حفظ بيانات الموظف بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
                              );
                              _loadEmployees();
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
                      : Text(employee == null ? 'تسجيل الموظف' : 'حفظ التعديلات', style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
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
    final filtered = _employees.where((e) {
      final name = e['name']?.toString().toLowerCase() ?? '';
      final job = e['job_title']?.toString().toLowerCase() ?? '';
      final q = _searchQuery.toLowerCase();
      return q.isEmpty || name.contains(q) || job.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('سجل الموظفين والعمال', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث', onPressed: _loadEmployees),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_rounded),
        label: const Text('موظف جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        onPressed: () => _showEmployeeForm(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ابحث باسم الموظف أو الوظيفة...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const AppLoadingView(message: 'جاري تحميل الموظفين...')
                : _error != null
                    ? AppErrorView(message: _error!, onRetry: _loadEmployees)
                    : filtered.isEmpty
                        ? const AppEmptyView(title: 'لا يوجد موظفون مطابقون', icon: Icons.people_outline)
                        : RefreshIndicator(
                            onRefresh: _loadEmployees,
                            color: AppColors.primary,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final emp = filtered[i] as Map<String, dynamic>;
                                final isActive = emp['is_active'] != false;
                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: AppColors.primaryLight,
                                        child: Text(
                                          (emp['name']?.toString().isNotEmpty == true ? emp['name'][0] : 'E').toUpperCase(),
                                          style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              emp['name']?.toString() ?? '',
                                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${emp['job_title'] ?? 'موظف'} • فرع: ${emp['branch_name'] ?? emp['branch']?['name'] ?? ''}',
                                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary),
                                            ),
                                            Text(
                                              'الأساسي: ${emp['basic_salary']} ج.م • ${isActive ? 'نشط' : 'معطل'}',
                                              style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isActive ? AppColors.success : AppColors.error),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary),
                                        onPressed: () => _showEmployeeForm(employee: emp),
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
