import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/colors.dart';
import '../models/nav_item_model.dart';
import '../providers/auth_provider.dart';
import '../providers/order_provider.dart';
import 'orders/create_order_screen.dart';
import 'orders/orders_list_screen.dart';
import 'products/products_catalog_screen.dart';
import 'stock/stock_screen.dart';
import 'sales/sales_screen.dart';
import 'safe/safe_screen.dart';
import 'suppliers/suppliers_screen.dart';
import 'hr/attendance_screen.dart';
import 'server_login_screen.dart';
import '../core/services/app_update_service.dart';
import '../core/network/api_client.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  int _currentNavIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<OrderProvider>().loadBootstrapBranches();
      context.read<OrderProvider>().loadCatalog();

      try {
        final api = context.read<ApiClient>();
        final updateInfo = await AppUpdateService.checkForUpdate(api);
        if (updateInfo != null && updateInfo.hasUpdate && mounted) {
          AppUpdateService.showUpdatePrompt(context, updateInfo);
        }
      } catch (_) {}
    });
  }

  void _handleItemTap(NavItemModel item) {
    final url = item.url ?? '';
    if (url == 'addorder' || url == 'transfer') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CreateOrderScreen(
            initialType: url == 'transfer' ? 'transfer' : 'order',
          ),
        ),
      );
    } else if (url == 'orders' || url == 'Rorders' || url == 'allorders' || url == 'ordersrev' || url == 'collection') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const OrdersListScreen()),
      );
    } else if (url == 'products' || url == 'RMproducts' || url == 'complete' || url == 'not_complete' || url == 'menu_sections') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProductsCatalogScreen()),
      );
    } else if (url == 'branchstocks' || url == 'stock' || url == 'stockentry' || url == 'itemsearch') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const StockScreen()),
      );
    } else if (url == 'selling_orders') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SalesScreen()),
      );
    } else if (url == 'safe_pending_transactions' || url == 'add_cashin' || url == 'set_safe_balances' || url == 'expenses' || url == 'addexpense' || url == 'direct_advances') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SafeScreen()),
      );
    } else if (url == 'supplier_receipts' || url == 'suppliers' || url == 'bills') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SuppliersScreen()),
      );
    } else if (url == 'branch_attendance' || url == 'hr_dashboard' || url == 'payroll_list' || url == 'attendance' || url == 'leave_requests') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AttendanceScreen()),
      );
    } else {
      _showModuleActionSheet(item);
    }
  }

  void _showModuleActionSheet(NavItemModel item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(item.iconData, color: AppColors.primary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Text(
                          'متصل بنظام الرشيدي ERP',
                          style: TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'لديك الصلاحية للوصول إلى هذا القسم. يمكنك متابعة العمليات أو استخدام الشاشات المخصصة على الموبايل.',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'تسجيل الخروج',
            style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'هل أنت متأكد من رغبتك في تسجيل الخروج من التطبيق؟',
            style: TextStyle(fontFamily: 'Cairo', fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء', style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                Navigator.of(ctx).pop();
                await context.read<AuthProvider>().logout();
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const ServerLoginScreen()),
                  );
                }
              },
              child: const Text('خروج', style: TextStyle(fontFamily: 'Cairo')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final navGroups = auth.navGroups;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/images/logo_erp.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'الرشيدي ERP',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
            tooltip: 'تسجيل الخروج',
            onPressed: _showLogoutConfirmDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildCurrentTab(auth, user, navGroups),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentNavIndex,
        onTap: (index) {
          if (index == 1) {
            // Quick jump to Create Order
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateOrderScreen()),
            );
          } else if (index == 2) {
            // Quick jump to Orders List
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OrdersListScreen()),
            );
          } else {
            setState(() => _currentNavIndex = index);
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline_rounded),
            activeIcon: Icon(Icons.add_circle_rounded),
            label: 'رفع طلب',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long_rounded),
            label: 'الطلبات',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentTab(AuthProvider auth, dynamic user, List<NavGroupModel> navGroups) {
    return RefreshIndicator(
      onRefresh: () async {
        await context.read<AuthProvider>().tryAutoLogin();
        await context.read<OrderProvider>().loadBootstrapBranches();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Profile Hero Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.secondary, AppColors.secondaryLight],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.secondary.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
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
                          user?.displayName ?? 'المستخدم',
                          style: const TextStyle(
                            fontFamily: 'Cairo',
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                user?.isSuperuser == true ? 'مدير عام' : 'مستخدم مصرح',
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFC0E7A6),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                user?.branchName ?? 'المركز الرئيسي',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Cairo',
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
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

            const SizedBox(height: 20),

            // High Priority Actions Header
            const Row(
              children: [
                Icon(Icons.bolt_rounded, color: AppColors.accentAmber, size: 20),
                SizedBox(width: 6),
                Text(
                  'الإجراءات السريعة (Mobile-First)',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Hero Fast Buttons Grid
            Row(
              children: [
                Expanded(
                  child: _buildActionTile(
                    title: 'إنشاء طلب جديد',
                    subtitle: 'صرف بضاعة وخامات',
                    icon: Icons.add_shopping_cart_rounded,
                    gradient: const [Color(0xFF4A9323), Color(0xFF3A7220)],
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CreateOrderScreen(initialType: 'order')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionTile(
                    title: 'أمر تحويل',
                    subtitle: 'تحويل بين الفروع',
                    icon: Icons.local_shipping_rounded,
                    gradient: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CreateOrderScreen(initialType: 'transfer')),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSecondaryTile(
                    title: 'متابعة الطلبات',
                    icon: Icons.receipt_long_rounded,
                    color: const Color(0xFF7C3AED),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const OrdersListScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSecondaryTile(
                    title: 'جدول الأصناف',
                    icon: Icons.inventory_2_rounded,
                    color: const Color(0xFFD97706),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProductsCatalogScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildSecondaryTile(
                    title: 'حضور وانصراف',
                    icon: Icons.access_time_filled_rounded,
                    color: const Color(0xFF0284C7),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AttendanceScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildSecondaryTile(
                    title: 'الخزينة والورديات',
                    icon: Icons.account_balance_wallet_rounded,
                    color: const Color(0xFF059669),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SafeScreen()),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // Dynamic Permissions Sections from ERP build_nav
            Row(
              children: [
                const Icon(Icons.shield_outlined, color: AppColors.primary, size: 20),
                const SizedBox(width: 6),
                const Text(
                  'أقسام النظام المتاحة لصلاحياتك',
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${navGroups.length} مجموعات',
                    style: const TextStyle(
                      fontFamily: 'Cairo',
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Dynamic Groups List
            if (navGroups.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Center(
                  child: Text(
                    'لا توجد أقسام مفعلة لهذا الحساب حالياً.',
                    style: TextStyle(fontFamily: 'Cairo', color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ...navGroups.map((group) => _buildDynamicGroupCard(group)),

            const SizedBox(height: 40),
          ],
        ),
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
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient, begin: Alignment.topRight, end: Alignment.bottomLeft),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: gradient.first.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.85),
                ),
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicGroupCard(NavGroupModel group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: group.id == 'orders' || group.id == 'sales',
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: group.resolvedColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(group.iconData, color: group.resolvedColor, size: 22),
          ),
          title: Text(
            group.title,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: group.hint.isNotEmpty
              ? Text(
                  group.hint,
                  style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                )
              : null,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: group.items.map((item) {
                  return ActionChip(
                    avatar: Icon(item.iconData, size: 16, color: group.resolvedColor),
                    label: Text(
                      item.title,
                      style: const TextStyle(
                        fontFamily: 'Cairo',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    backgroundColor: AppColors.surfaceMuted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    onPressed: () => _handleItemTap(item),
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
