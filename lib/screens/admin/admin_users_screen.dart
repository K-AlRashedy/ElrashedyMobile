import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/network/api_client.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/async_views.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _api = ApiClient();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _users = [];
  List<dynamic> _branches = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _api.setBaseUrl(auth.serverUrl);
    _api.setToken(auth.token);
    _loadUsers();
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

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await _api.get('/api/v1/admin/users/');
      if (res is Map<String, dynamic> && mounted) {
        setState(() {
          _users = res['results'] as List<dynamic>? ?? [];
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

  void _showResetPasswordDialog(Map<String, dynamic> user) {
    final passwordController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (c, setDialogState) => AlertDialog(
          title: Text('إعادة تعيين كلمة مرور ${user['username']}', style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة', prefixIcon: Icon(Icons.lock_reset_outlined)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (passwordController.text.trim().isEmpty) return;
                      setDialogState(() => isSubmitting = true);
                      try {
                        await _api.post('/api/v1/admin/users/${user['id']}/reset-password/', body: {
                          'password': passwordController.text.trim(),
                        });
                        if (mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('خطأ: $e', style: const TextStyle(fontFamily: 'Cairo')), backgroundColor: AppColors.error),
                          );
                        }
                      }
                    },
              child: const Text('حفظ كلمة المرور', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserFormSheet({Map<String, dynamic>? user}) {
    final usernameController = TextEditingController(text: user?['username']?.toString() ?? '');
    final nameController = TextEditingController(text: user?['first_name']?.toString() ?? '');
    final passwordController = TextEditingController();
    int? selectedBranchId = (user?['branches'] as List<dynamic>?)?.isNotEmpty == true
        ? user!['branches'][0]['id'] as int?
        : (_branches.isNotEmpty ? _branches.first['id'] as int? : null);
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
                  Text(user == null ? 'إضافة مستخدم جديد' : 'تعديل بيانات المستخدم', style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: 'اسم المستخدم (Login Username)', prefixIcon: Icon(Icons.account_circle_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'الاسم الكامل', prefixIcon: Icon(Icons.badge_outlined)),
              ),
              if (user == null) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'كلمة المرور', prefixIcon: Icon(Icons.lock_outline)),
                ),
              ],
              const SizedBox(height: 12),
              if (_branches.isNotEmpty)
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'الفرع الأساسي'),
                  value: selectedBranchId,
                  items: _branches.map<DropdownMenuItem<int>>((b) {
                    return DropdownMenuItem<int>(
                      value: b['id'] as int,
                      child: Text(b['name']?.toString() ?? '', style: const TextStyle(fontFamily: 'Cairo')),
                    );
                  }).toList(),
                  onChanged: (val) => setSheetState(() => selectedBranchId = val),
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
                        if (usernameController.text.trim().isEmpty) return;
                        setSheetState(() => isSubmitting = true);
                        try {
                          final payload = <String, dynamic>{
                            'username': usernameController.text.trim(),
                            'first_name': nameController.text.trim(),
                            if (selectedBranchId != null) 'branch_ids': [selectedBranchId],
                          };
                          if (user == null) {
                            payload['password'] = passwordController.text.trim();
                            await _api.post('/api/v1/admin/users/create/', body: payload);
                          } else {
                            await _api.post('/api/v1/admin/users/${user['id']}/update/', body: payload);
                          }
                          if (mounted) {
                            Navigator.pop(sheetContext);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم حفظ بيانات المستخدم بنجاح', style: TextStyle(fontFamily: 'Cairo'))),
                            );
                            _loadUsers();
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
                    : Text(user == null ? 'إنشاء المستخدم' : 'حفظ التعديلات', style: const TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _users.where((u) {
      final un = u['username']?.toString().toLowerCase() ?? '';
      final fn = u['first_name']?.toString().toLowerCase() ?? '';
      final q = _searchQuery.toLowerCase();
      return q.isEmpty || un.contains(q) || fn.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('إدارة المستخدمين والصلاحيات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: 'تحديث', onPressed: _loadUsers),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('مستخدم جديد', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        onPressed: () => _showUserFormSheet(),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ابحث باسم المستخدم أو الاسم الكامل...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 22),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const AppLoadingView(message: 'جاري تحميل المستخدمين...')
                : _error != null
                    ? AppErrorView(message: _error!, onRetry: _loadUsers)
                    : filtered.isEmpty
                        ? const AppEmptyView(title: 'لا يوجد مستخدمين مطابقين', icon: Icons.manage_accounts_outlined)
                        : RefreshIndicator(
                            onRefresh: _loadUsers,
                            color: AppColors.primary,
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final user = filtered[i] as Map<String, dynamic>;
                                final isSuper = user['is_superuser'] == true;
                                final isActive = user['is_active'] != false;
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
                                          color: isSuper ? AppColors.accent.withOpacity(0.1) : AppColors.primaryLight,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          isSuper ? Icons.admin_panel_settings_outlined : Icons.person_outline,
                                          color: isSuper ? AppColors.accent : AppColors.primary,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  user['username']?.toString() ?? '',
                                                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                                ),
                                                if (isSuper) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.accent.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: const Text('مدير نظام', style: TextStyle(fontFamily: 'Cairo', fontSize: 9, color: AppColors.accent, fontWeight: FontWeight.bold)),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (user['first_name'] != null && user['first_name'].toString().isNotEmpty)
                                              Text(
                                                user['first_name'].toString(),
                                                style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textSecondary),
                                              ),
                                            Text(
                                              isActive ? 'الحساب نشط' : 'الحساب معطل',
                                              style: TextStyle(fontFamily: 'Cairo', fontSize: 11, color: isActive ? AppColors.success : AppColors.error),
                                            ),
                                          ],
                                        ),
                                      ),
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
                                        onSelected: (val) {
                                          if (val == 'edit') {
                                            _showUserFormSheet(user: user);
                                          } else if (val == 'reset_pwd') {
                                            _showResetPasswordDialog(user);
                                          }
                                        },
                                        itemBuilder: (c) => [
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Text('تعديل البيانات', style: TextStyle(fontFamily: 'Cairo')),
                                          ),
                                          const PopupMenuItem(
                                            value: 'reset_pwd',
                                            child: Text('تغيير كلمة المرور', style: TextStyle(fontFamily: 'Cairo')),
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
