import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/config.dart';
import '../../core/network/api_client.dart';
import '../../core/services/app_update_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_feedback.dart';
import '../server_login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppUpdateInfo? _updateInfo;
  bool _checkingUpdate = false;
  String? _updateCheckError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVersion());
  }

  Future<void> _checkVersion({bool showToastIfCurrent = false}) async {
    if (!mounted) return;
    setState(() {
      _checkingUpdate = true;
      _updateCheckError = null;
    });
    try {
      final api = context.read<ApiClient>();
      final info = await AppUpdateService.checkForUpdate(api);
      if (!mounted) return;
      setState(() {
        _updateInfo = info;
        _checkingUpdate = false;
      });
      if (info == null) {
        const msg = 'تعذر التحقق من التحديثات (الخادم غير متصل أو لا يدعم الفحص).';
        setState(() => _updateCheckError = msg);
        if (showToastIfCurrent) {
          AppFeedback.showError(context, msg);
        }
        return;
      }
      if (info.hasUpdate && showToastIfCurrent) {
        AppUpdateService.showUpdatePrompt(context, info);
      } else if (showToastIfCurrent) {
        AppFeedback.showSuccess(
          context,
          'أنت تستخدم أحدث إصدار من تطبيق الرشيدي ERP (${AppUpdateService.currentVersion}).',
        );
      }
    } catch (e) {
      if (!mounted) return;
      final msg = 'فشل فحص التحديثات: $e';
      setState(() {
        _checkingUpdate = false;
        _updateCheckError = msg;
      });
      if (showToastIfCurrent) {
        AppFeedback.showError(context, msg);
      }
    }
  }

  Future<void> _openDownloadPath(String baseUrl, String pathOrFullUrl) async {
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final fullUrl = pathOrFullUrl.startsWith('http')
        ? pathOrFullUrl
        : '$normalizedBase$pathOrFullUrl';
    final uri = Uri.tryParse(fullUrl);
    if (uri == null) {
      AppFeedback.showError(context, 'رابط التحميل غير صالح: $fullUrl');
      return;
    }
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      AppFeedback.showError(context, 'تعذر فتح الرابط: $fullUrl');
    }
  }

  Future<void> _showServerUrlDialog(AuthProvider auth) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ChangeServerUrlDialog(auth: auth),
    );
    if (changed == true && mounted) {
      AppFeedback.showSuccess(
        context,
        'تم تغيير الخادم وإعادة ضبط الجلسة. سجّل الدخول الآن.',
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const ServerLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'الإعدادات ومركز تحميل التطبيقات',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                  backgroundColor: AppColors.primarySoft,
                  child: Text(
                    (user != null && user.name.isNotEmpty ? user.name[0] : 'U')
                        .toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user != null && user.name.isNotEmpty
                            ? user.name
                            : 'مستخدم الـ ERP',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        user != null && user.username.isNotEmpty
                            ? '@${user.username}'
                            : '',
                        style: const TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: user?.isSuperuser == true
                                  ? AppColors.accentAmberSoft
                                  : AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              user?.isSuperuser == true
                                  ? 'مدير نظام عام'
                                  : 'مستخدم نظام',
                              style: TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 10.5,
                                fontWeight: FontWeight.bold,
                                color: user?.isSuperuser == true
                                    ? AppColors.accent
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                          if (user != null && user.branchName.isNotEmpty)
                            Text(
                              user.branchName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Cairo',
                                fontSize: 11.5,
                                color: AppColors.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.system_update_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'مركز تحميل وتحديث تطبيقات الرشيدي',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (_checkingUpdate)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      TextButton.icon(
                        onPressed: () =>
                            _checkVersion(showToastIfCurrent: true),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text(
                          'فحص التحديثات',
                          style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                        ),
                      ),
                  ],
                ),
                if (_updateCheckError != null) ...[
                  const SizedBox(height: 8),
                  AppInlineError(message: _updateCheckError!),
                ],
                if (_updateInfo != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'أحدث إصدار على الخادم: ${_updateInfo!.latestVersion} · الإصدار المثبت: ${AppUpdateService.currentVersion}',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (_updateInfo!.releaseNotes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _updateInfo!.releaseNotes,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      icon: const Icon(Icons.android_rounded, size: 18),
                      label: const Text(
                        'Android (شامل APK)',
                        style: TextStyle(
                          fontFamily: 'Cairo',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () => _openDownloadPath(
                        auth.serverUrl,
                        (_updateInfo?.androidUrl.isNotEmpty ?? false)
                            ? _updateInfo!.androidUrl
                            : '/mobile-app/download/android/',
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.memory_rounded, size: 18),
                      label: const Text(
                        'Android arm64 (سريع)',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                      ),
                      onPressed: () => _openDownloadPath(
                        auth.serverUrl,
                        '/mobile-app/download/android-arm64/',
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.phone_iphone_rounded, size: 18),
                      label: const Text(
                        'iOS (آيفون IPA)',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                      ),
                      onPressed: () => _openDownloadPath(
                        auth.serverUrl,
                        (_updateInfo?.iosUrl.isNotEmpty ?? false)
                            ? _updateInfo!.iosUrl
                            : '/mobile-app/download/ios/',
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.desktop_windows_rounded, size: 18),
                      label: const Text(
                        'كاشير سطح المكتب POS',
                        style: TextStyle(fontFamily: 'Cairo', fontSize: 12),
                      ),
                      onPressed: () => _openDownloadPath(
                        auth.serverUrl,
                        '/pos/download/',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.dns_outlined, color: AppColors.primary),
                  title: const Text(
                    'عنوان خادم النظام (Server URL)',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      auth.serverUrl,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.textMuted,
                  ),
                  onTap: () => _showServerUrlDialog(auth),
                ),
                const Divider(height: 1),
                const ListTile(
                  leading: Icon(Icons.info_outline, color: AppColors.primary),
                  title: Text(
                    'إصدار التطبيق',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    'نسخة الموبايل ${AppUpdateService.currentVersion} (متوافق 100% مع Django ERP)',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.timer_outlined, color: AppColors.primary),
                  title: const Text(
                    'مهلة الاتصال (Timeout)',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    '${AppConfig.defaultTimeoutSeconds} ثانية مع إعادة المحاولة التلقائية',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text(
              'تسجيل الخروج من الحساب',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () async {
              final confirm = await AppConfirmDialog.show(
                context,
                title: 'تأكيد تسجيل الخروج',
                message:
                    'هل أنت متأكد من رغبتك في تسجيل الخروج من هذا الجهاز؟',
                confirmLabel: 'تسجيل الخروج',
                isDestructive: true,
              );
              if (confirm && context.mounted) {
                await context.read<AuthProvider>().logout();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(
                      builder: (_) => const ServerLoginScreen(),
                    ),
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

class _ChangeServerUrlDialog extends StatefulWidget {
  final AuthProvider auth;

  const _ChangeServerUrlDialog({required this.auth});

  @override
  State<_ChangeServerUrlDialog> createState() => _ChangeServerUrlDialogState();
}

class _ChangeServerUrlDialogState extends State<_ChangeServerUrlDialog> {
  late final TextEditingController _controller;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.auth.serverUrl);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newUrl = _controller.text.trim();
    if (newUrl.isEmpty) {
      setState(() => _error = 'أدخل عنوان الخادم الجديد.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.auth.setServerUrl(newUrl, resetSession: true);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'تغيير خادم النظام',
        style: TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              AppInlineError(message: _error!),
              const SizedBox(height: 10),
            ],
            Directionality(
              textDirection: TextDirection.ltr,
              child: TextField(
                controller: _controller,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'URL الخادم الجديد',
                  hintText: 'https://example.com',
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'سيتم تسجيل الخروج من الجلسة الحالية عند تغيير الخادم.',
              style: TextStyle(
                fontFamily: 'Cairo',
                fontSize: 11.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo')),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'حفظ وإعادة الربط',
                  style: TextStyle(fontFamily: 'Cairo'),
                ),
        ),
      ],
    );
  }
}
