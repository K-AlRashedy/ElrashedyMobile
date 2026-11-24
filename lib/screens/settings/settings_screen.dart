import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/config.dart';
import '../../providers/auth_provider.dart';
import '../server_login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('إعدادات التطبيق والحساب', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // User profile card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primaryLight,
                  child: Text(
                    (user != null && user.name.isNotEmpty ? user.name[0] : 'U').toUpperCase(),
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user != null && user.name.isNotEmpty ? user.name : 'مستخدم الـ ERP',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      Text(
                        user != null && user.username.isNotEmpty ? '@${user.username}' : '',
                        style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: user?.isSuperuser == true ? AppColors.accent.withValues(alpha: 0.1) : AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              user?.isSuperuser == true ? 'مدير نظام عام' : 'مستخدم نظام',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: user?.isSuperuser == true ? AppColors.accent : AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          if (user != null && user.branchName.isNotEmpty)
                            Text(
                              user.branchName,
                              style: const TextStyle(fontFamily: 'Cairo', fontSize: 11, color: AppColors.textMuted),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Server Connection Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.dns_outlined, color: AppColors.primary),
                  title: const Text('عنوان خادم النظام (Server URL)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(auth.serverUrl, style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
                  onTap: () {
                    final controller = TextEditingController(text: auth.serverUrl);
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('تغيير خادم النظام', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 16)),
                        content: TextField(
                          controller: controller,
                          decoration: const InputDecoration(labelText: 'URL الخادم الجديد'),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
                          FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                            onPressed: () {
                              final newUrl = controller.text.trim();
                              if (newUrl.isNotEmpty) {
                                auth.setServerUrl(newUrl);
                                Navigator.pop(ctx);
                              }
                            },
                            child: const Text('حفظ', style: TextStyle(fontFamily: 'Cairo')),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: AppColors.primary),
                  title: const Text('إصدار التطبيق', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('نسخة الموبايل 1.0.0 (متوافقة 100% مع Django ERP)', style: TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.timer_outlined, color: AppColors.primary),
                  title: const Text('مهلة الاتصال (Timeout)', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('${AppConfig.defaultTimeoutSeconds} ثانية مع إعادة المحاولة التلقائية', style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Logout Button
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('تسجيل الخروج من الحساب', style: TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.bold)),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('تأكيد تسجيل الخروج', style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج من هذا الجهاز؟', style: TextStyle(fontFamily: 'Cairo')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo'))),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('خروج', style: TextStyle(fontFamily: 'Cairo')),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await context.read<AuthProvider>().logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const ServerLoginScreen()),
                    (route) => false,
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
