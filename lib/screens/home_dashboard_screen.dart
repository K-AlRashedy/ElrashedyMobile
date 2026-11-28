import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/colors.dart';
import '../core/navigation/mobile_router.dart';
import '../core/network/api_client.dart';
import '../core/services/app_update_service.dart';
import '../models/nav_item_model.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../widgets/app_feedback.dart';
import 'hr/attendance_screen.dart';
import 'orders/create_order_screen.dart';
import 'orders/orders_list_screen.dart';
import 'products/products_catalog_screen.dart';
import 'reports/reports_hub_screen.dart';
import 'safe/safe_screen.dart';
import 'server_login_screen.dart';
import 'settings/settings_screen.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  final TextEditingController _navSearchCtrl = TextEditingController();
  String _navQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final orderProvider = context.read<OrderProvider>();
      context.read<AuthProvider>().refreshSession();
      orderProvider.loadBootstrapBranches();
      orderProvider.loadCatalog();

      try {
        final api = context.read<ApiClient>();
        final updateInfo = await AppUpdateService.checkForUpdate(api);
        if (updateInfo != null && updateInfo.hasUpdate && mounted) {
          AppUpdateService.showUpdatePrompt(context, updateInfo);
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _navSearchCtrl.dispose();
    super.dispose();
  }

  void _handleItemTap(NavItemModel item) {
    MobileRouter.openNavItem(context, item);
  }

  Future<void> _showLogoutConfirmDialog() async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'تسجيل الخروج',
      message: 'هل أنت متأكد من رغبتك في تسجيل الخروج من التطبيق؟',
      confirmLabel: 'خروج',
      isDestructive: true,
    );
    if (!confirmed || !mounted) return;
    await context.read<AuthProvider>().logout();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ServerLoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final navGroups = auth.navGroups;

    final q = _navQuery.trim().toLowerCase();
    final filteredGroups = q.isEmpty
        ? navGroups
        : navGroups
            .map((g) {
              final groupMatches = g.title.toLowerCase().contains(q) || g.hint.toLowerCase().contains(q);
              final matchedItems = groupMatches
                  ? g.items
                  : g.items
                      .where((i) =>
                          i.title.toLowerCase().contains(q) ||
                          (i.url ?? '').toLowerCase().contains(q))
                      .toList();
              return NavGroupModel(
                id: g.id,
                title: g.title,
                icon: g.icon,
                color: g.color,
                hint: g.hint,
                items: matchedItems,
              );
            })
            .where((g) => g.items.isNotEmpty)
            .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset('assets/images/logo_erp.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 10),
            const Text('الرشيدي ERP'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_rounded, size: 22),
            tooltip: 'التقارير والمؤشرات',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReportsHubScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            tooltip: 'الإعدادات',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
            tooltip: 'تسجيل الخروج',
            onPressed: _showLogoutConfirmDialog,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await context.read<AuthProvider>().refreshSession();
          if (mounted) {
            await context.read<OrderProvider>().loadBootstrapBranches();
          }
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            // Hero Profile Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.secondary, AppColors.secondaryLight],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(color: Color(0x280F172A), blurRadius: 16, offset: Offset(0, 6)),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      user != null && user.displayName.isNotEmpty
                          ? user.displayName.substring(0, 1).toUpperCase()
                          : 'ر',
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مرحباً، ${user?.displayName ?? 'المستخدم'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16.5,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.28),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                user?.isSuperuser == true ? 'مدير عام' : 'صلاحيات مفعلة',
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFC8F0AC),
                                ),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.storefront_rounded, size: 14, color: Colors.white70),
                                const SizedBox(width: 4),
                                Text(
                                  user?.branchName ?? 'المركز الرئيسي',
                                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 12, color: Colors.white70),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Quick Actions
            const Row(
              children: [
                Icon(Icons.bolt_rounded, color: AppColors.accentAmber, size: 21),
                SizedBox(width: 6),
                Text(
                  'الوصول السريع',
                  style: TextStyle(fontFamily: 'Cairo', fontSize: 15.5, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _buildActionTile(
                    title: 'إنشاء طلب',
                    subtitle: 'صرف بضاعة وخامات',
                    icon: Icons.add_shopping_cart_rounded,
                    gradient: const [AppColors.primary, AppColors.primaryDark],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CreateOrderScreen(initialType: 'order')),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionTile(
                    title: 'أمر تحويل',
                    subtitle: 'تحويل بين الفروع',
                    icon: Icons.local_shipping_rounded,
                    gradient: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CreateOrderScreen(initialType: 'transfer')),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildSecondaryTile(
                    title: 'الطلبات',
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.accentPurple,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OrdersListScreen()),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSecondaryTile(
                    title: 'الأصناف',
                    icon: Icons.inventory_2_rounded,
                    color: AppColors.accentAmber,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ProductsCatalogScreen()),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildSecondaryTile(
                    title: 'الحضور',
                    icon: Icons.access_time_filled_rounded,
                    color: AppColors.info,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSecondaryTile(
                    title: 'الخزينة',
                    icon: Icons.account_balance_wallet_rounded,
                    color: AppColors.success,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SafeScreen()),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 22),

            // Quick Section Search
            Row(
              children: [
                const Icon(Icons.apps_rounded, color: AppColors.primary, size: 20),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'أقسام النظام',
                    style: TextStyle(fontFamily: 'Cairo', fontSize: 15.5, fontWeight: FontWeight.w800),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '${filteredGroups.length} أقسام',
                    style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _navSearchCtrl,
              decoration: InputDecoration(
                hintText: 'ابحث عن شاشة أو قسم (مثال: جرد، رواتب، مصروفات)...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary),
                suffixIcon: _navQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 19),
                        onPressed: () {
                          _navSearchCtrl.clear();
                          setState(() => _navQuery = '');
                        },
                      )
                    : null,
              ),
              onChanged: (v) => setState(() => _navQuery = v),
            ),
            const SizedBox(height: 12),

            if (filteredGroups.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Center(
                  child: Text(
                    _navQuery.isNotEmpty ? 'لا توجد شاشات مطابقة للبحث "$_navQuery"' : 'لا توجد أقسام مفعلة لهذا الحساب حالياً.',
                    style: const TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ...filteredGroups.map((group) => _buildDynamicGroupCard(group, forceExpand: _navQuery.isNotEmpty)),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (index) {
          if (index == 1) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
            );
          } else if (index == 2) {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OrdersListScreen()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.add_circle_rounded), label: 'رفع طلب'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_rounded), label: 'الطلبات'),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient, begin: Alignment.topRight, end: Alignment.bottomLeft),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: gradient.first.withValues(alpha: 0.28), blurRadius: 12, offset: const Offset(0, 5)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(fontFamily: 'Cairo', fontSize: 15.5, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: Colors.white.withValues(alpha: 0.88)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryTile({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontFamily: 'Cairo', fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicGroupCard(NavGroupModel group, {bool forceExpand = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('${group.id}_$forceExpand'),
          initiallyExpanded: forceExpand || group.id == 'orders' || group.id == 'sales',
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: group.resolvedColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(group.iconData, color: group.resolvedColor, size: 22),
          ),
          title: Text(
            group.title,
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          subtitle: group.hint.isNotEmpty
              ? Text(group.hint, style: const TextStyle(fontFamily: 'Cairo', fontSize: 11.5, color: AppColors.textSecondary))
              : null,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: group.items.map((item) {
                  return InkWell(
                    onTap: () => _handleItemTap(item),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item.iconData, size: 17, color: group.resolvedColor),
                          const SizedBox(width: 6),
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontFamily: 'Cairo',
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
