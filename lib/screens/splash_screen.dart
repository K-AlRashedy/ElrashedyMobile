import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/colors.dart';
import '../providers/auth_provider.dart';
import 'home_dashboard_screen.dart';
import 'server_login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _networkFailed = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    setState(() {
      _networkFailed = false;
      _errorMsg = null;
    });
    await Future.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;

    final auth = context.read<AuthProvider>();
    final isLoggedIn = await auth.tryAutoLogin();

    if (!mounted) return;
    if (isLoggedIn) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeDashboardScreen()),
      );
      return;
    }

    if (auth.autoLoginNetworkError) {
      setState(() {
        _networkFailed = true;
        _errorMsg = auth.errorMessage ?? 'تعذر الاتصال بالسيرفر. تحقق من الإنترنت.';
      });
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ServerLoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: AppColors.border),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: Image.asset('assets/images/logo_erp.png', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'الرشيدي ERP',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 6),
                if (!_networkFailed) ...[
                  const Text(
                    'جاري تهيئة النظام والصلاحيات...',
                    style: TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.8,
                      color: AppColors.primary,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          _errorMsg ?? 'تعذر الاتصال بالسيرفر',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _checkSession,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const ServerLoginScreen()),
                      );
                    },
                    child: const Text(
                      'الانتقال لشاشة تسجيل الدخول',
                      style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
