import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/colors.dart';
import '../core/constants/config.dart';
import '../core/network/api_client.dart';
import '../core/storage/secure_storage.dart';
import '../providers/auth_provider.dart';
import 'home_dashboard_screen.dart';

class ServerLoginScreen extends StatefulWidget {
  const ServerLoginScreen({super.key});

  @override
  State<ServerLoginScreen> createState() => _ServerLoginScreenState();
}

class _ServerLoginScreenState extends State<ServerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverUrlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _storage = AppStorage();

  bool _obscurePassword = true;
  bool _isTestingPing = false;
  bool? _isServerReachable;
  String? _pingMessage;
  bool _showServerField = false;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final savedUrl = await _storage.getServerUrl();
    final savedUser = await _storage.getLastUsername();

    final effectiveUrl = savedUrl.isNotEmpty ? savedUrl : AppConfig.defaultServerUrl;
    _serverUrlController.text = effectiveUrl;
    _showServerField = effectiveUrl != AppConfig.defaultServerUrl;
    _testServerConnection(effectiveUrl);

    if (savedUser != null && savedUser.isNotEmpty) {
      _usernameController.text = savedUser;
    }
    if (mounted) setState(() {});
  }

  Future<void> _testServerConnection(String url) async {
    if (url.trim().isEmpty) return;
    setState(() {
      _isTestingPing = true;
      _isServerReachable = null;
      _pingMessage = null;
    });

    final api = context.read<ApiClient>();
    final reachable = await api.pingServer(url);

    if (mounted) {
      setState(() {
        _isTestingPing = false;
        _isServerReachable = reachable;
        _pingMessage = reachable
            ? 'السيرفر متصل وجاهز للعمل'
            : 'تعذر الاتصال بالسيرفر. تحقق من الرابط أو الإنترنت';
      });
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final auth = context.read<AuthProvider>();
    final success = await auth.login(
      serverUrl: _serverUrlController.text.trim(),
      username: _usernameController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
      );
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppColors.border),
                          boxShadow: const [
                            BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(0, 6)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset('assets/images/logo_erp.png', fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'الرشيدي ERP',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'منظومة إدارة الفروع والمخازن والإنتاج',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),

                    // Connection status badge
                    Center(
                      child: InkWell(
                        onTap: () => _testServerConnection(_serverUrlController.text),
                        borderRadius: BorderRadius.circular(100),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: _isServerReachable == true
                                ? AppColors.successSoft
                                : _isServerReachable == false
                                    ? AppColors.dangerSoft
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: _isServerReachable == true
                                  ? AppColors.success.withValues(alpha: 0.3)
                                  : _isServerReachable == false
                                      ? AppColors.error.withValues(alpha: 0.3)
                                      : AppColors.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isTestingPing)
                                const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              else
                                Icon(
                                  _isServerReachable == true
                                      ? Icons.cloud_done_rounded
                                      : _isServerReachable == false
                                          ? Icons.cloud_off_rounded
                                          : Icons.dns_outlined,
                                  size: 16,
                                  color: _isServerReachable == true
                                      ? AppColors.success
                                      : _isServerReachable == false
                                          ? AppColors.error
                                          : AppColors.textSecondary,
                                ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _isTestingPing
                                      ? 'جاري فحص الاتصال بالسيرفر...'
                                      : (_pingMessage ?? 'اضغط لفحص الاتصال'),
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _isServerReachable == true
                                        ? AppColors.success
                                        : _isServerReachable == false
                                            ? AppColors.error
                                            : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                        boxShadow: const [
                          BoxShadow(color: Color(0x0A000000), blurRadius: 18, offset: Offset(0, 6)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'تسجيل الدخول',
                                  style: TextStyle(
                                    fontFamily: 'Cairo',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: () => setState(() => _showServerField = !_showServerField),
                                icon: Icon(
                                  _showServerField ? Icons.expand_less_rounded : Icons.dns_rounded,
                                  size: 17,
                                  color: AppColors.primary,
                                ),
                                label: Text(
                                  _showServerField ? 'إخفاء السيرفر' : 'تغيير السيرفر',
                                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          if (_showServerField) ...[
                            TextFormField(
                              controller: _serverUrlController,
                              keyboardType: TextInputType.url,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.start,
                              decoration: InputDecoration(
                                labelText: 'رابط السيرفر',
                                hintText: AppConfig.defaultServerUrl,
                                prefixIcon: const Icon(Icons.dns_rounded, color: AppColors.primary, size: 20),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.refresh_rounded, size: 20),
                                  onPressed: () => _testServerConnection(_serverUrlController.text),
                                  tooltip: 'فحص الاتصال',
                                ),
                              ),
                              validator: (val) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'يرجى إدخال رابط السيرفر.';
                                }
                                return null;
                              },
                            ),
                            if (_serverUrlController.text.trim() != AppConfig.defaultServerUrl)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _serverUrlController.text = AppConfig.defaultServerUrl;
                                    });
                                    _testServerConnection(AppConfig.defaultServerUrl);
                                  },
                                  icon: const Icon(Icons.restore_rounded, size: 15),
                                  label: const Text('استعادة السيرفر الرسمي', style: TextStyle(fontFamily: 'Cairo', fontSize: 12)),
                                ),
                              ),
                            const SizedBox(height: 12),
                          ],

                          TextFormField(
                            controller: _usernameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'اسم المستخدم',
                              hintText: 'أدخل اسم المستخدم في النظام',
                              prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.primary, size: 22),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'يرجى إدخال اسم المستخدم.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => auth.isLoading ? null : _handleLogin(),
                            decoration: InputDecoration(
                              labelText: 'كلمة المرور',
                              hintText: '••••••••',
                              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 22),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  size: 20,
                                  color: AppColors.textMuted,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty) {
                                return 'يرجى إدخال كلمة المرور.';
                              }
                              return null;
                            },
                          ),

                          if (auth.errorMessage != null) ...[
                            const SizedBox(height: 14),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.dangerSoft,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      auth.errorMessage!,
                                      style: const TextStyle(
                                        fontFamily: 'Cairo',
                                        fontSize: 12.5,
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          ElevatedButton(
                            onPressed: auth.isLoading ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                            ),
                            child: auth.isLoading
                                ? const SizedBox(
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : const Text(
                                    'دخول للنظام',
                                    style: TextStyle(fontFamily: 'Cairo', fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'اتصال مشفر مباشر مع سيرفر الرشيدي ERP',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
