import 'package:flutter_test/flutter_test.dart';
import 'package:elrashedy_erp/core/navigation/mobile_router.dart';
import 'package:elrashedy_erp/models/nav_item_model.dart';
import 'package:elrashedy_erp/providers/auth_provider.dart';
import 'package:elrashedy_erp/screens/hr/attendance_screen.dart';
import 'package:elrashedy_erp/screens/safe/safe_screen.dart';

void main() {
  group('MobileRouter 100% ERP Navigation Parity', () {
    const canonicalErpNavUrls = <String>[
      // Downloads
      'mobile_app_download',
      'mobile_app_download_android',
      'mobile_app_download_android_arm64',
      'mobile_app_download_ios',
      // Delivery
      'delivery_zones',
      'add_delivery_zone',
      'delivery_customers',
      // Safe & Treasury
      'safe_pending_transactions',
      'add_cashin',
      'direct_advances',
      'supplier_receipts',
      'set_safe_balances',
      // Orders
      'orders',
      'Rorders',
      'ordersrev',
      'collection',
      'addorder',
      'transfer',
      'allorders',
      // Catalog & Master Data
      'products',
      'addproduct',
      'menu_sections',
      'add_menu_section',
      'units',
      'addunit',
      'branches',
      'addbranch',
      'stores',
      'addstoretype',
      'accounts',
      'addaccount',
      'excel',
      'upload',
      // HR
      'hr_dashboard',
      'payroll_list',
      'generate_payroll',
      'branch_attendance',
      'attendance',
      'leave_requests',
      'add_leave',
      'penalties_list',
      'employees_list',
      'add_employee',
      // Purchases & Suppliers
      'suppliers',
      'addsupplier',
      'suppliers_with_balance',
      'bills',
      'operations',
      'addbill',
      // Expenses
      'expenses',
      'addexpense',
      // Sales
      'selling_orders',
      'sell',
      // Stock
      'stock',
      'stockentry',
      'branchstocks',
      'itemsearch',
      'daily_Report',
      // Production
      'manufacturing',
      'manufactureProcess',
      // Reports & Costs
      'index',
      'dashboard',
      'branch_reports',
      'costanalysis',
      'indirectCost',
      'complete',
      'not_complete',
      'RMproducts',
      // Settings & Admin
      'users',
      'users_list',
      'admin_users',
      'signup',
      'data_console',
      'settings',
    ];

    test('Every canonical Django ERP URL name resolves to a real Flutter screen', () {
      for (final url in canonicalErpNavUrls) {
        final item = NavItemModel(title: url, icon: 'fa-circle', url: url);
        final screen = MobileRouter.resolveScreen(item);
        expect(
          screen,
          isNotNull,
          reason: 'Expected non-null Flutter screen for ERP navigation url "$url"',
        );
      }
    });

    test('POS terminal options are excluded from mobile navigation and router', () {
      expect(
        MobileRouter.resolveScreen(NavItemModel(title: 'فتح الكاشير', icon: 'fa-cash-register', url: 'pos')),
        isNull,
      );
      expect(
        MobileRouter.resolveScreen(NavItemModel(title: 'كاشير', icon: 'fa-cash-register', href: '/pos/')),
        isNull,
      );
      expect(
        MobileRouter.resolveScreen(NavItemModel(title: 'تحميل كاشير سطح المكتب', icon: 'fa-download', href: '/pos/download/')),
        isNull,
      );
      expect(
        MobileRouter.resolveScreen(NavItemModel(title: 'تقفيل وردية', icon: 'fa-money-bill-transfer', url: 'add_cashin')),
        isA<SafeScreen>(),
      );
      expect(
        MobileRouter.resolveScreen(NavItemModel(title: 'الورديات المعلقة', icon: 'fa-clipboard-check', url: 'safe_pending_transactions')),
        isA<SafeScreen>(),
      );

      final filtered = AuthProvider.filterMobileNavGroups([
        NavGroupModel(
          id: 'sales',
          title: 'المبيعات والكاشير',
          icon: 'fa-cash-register',
          color: 'red',
          hint: 'الكاشير وأوامر البيع',
          items: [
            NavItemModel(title: 'فتح الكاشير', icon: 'fa-cash-register', url: 'pos', href: '/factory/pos/'),
            NavItemModel(title: 'تحميل كاشير سطح المكتب', icon: 'fa-download', href: '/pos/download/'),
            NavItemModel(title: 'أوامر البيع', icon: 'fa-money-bills', url: 'selling_orders', href: '/factory/selling_orders/'),
          ],
        ),
        NavGroupModel(
          id: 'finance',
          title: 'الخزينة والمصروفات',
          icon: 'fa-vault',
          color: 'emerald',
          hint: 'الورديات',
          items: [
            NavItemModel(title: 'تقفيل وردية', icon: 'fa-money-bill-transfer', url: 'add_cashin'),
            NavItemModel(title: 'الورديات المعلقة', icon: 'fa-clipboard-check', url: 'safe_pending_transactions'),
          ],
        ),
      ]);

      expect(filtered.length, 2);
      expect(filtered.first.title, 'المبيعات والتوصيل');
      expect(filtered.first.items.map((i) => i.url).toList(), ['selling_orders']);
      expect(filtered.last.items.map((i) => i.url).toList(), ['add_cashin', 'safe_pending_transactions']);
    });
  });

  group('WorkerAttendanceState money-string parsing', () {
    test('Parses string decimal hours returned by /api/v1/attendance/branch/', () {
      final worker = WorkerAttendanceState.fromJson({
        'id': 7,
        'attendance_id': 42,
        'name': 'أحمد محمد',
        'job_title': 'شيف',
        'shift_type': 'morning',
        'status': 'present',
        'work_hours': '10.00',
        'overtime_hours': '2.50',
        'delay_hours': '0.25',
        'notes': 'التزام ممتاز',
        'is_saved': true,
      });

      expect(worker.id, 7);
      expect(worker.attendanceId, 42);
      expect(worker.workHours, 10.0);
      expect(worker.overtimeHours, 2.5);
      expect(worker.delayHours, 0.25);
      expect(worker.isSaved, isTrue);
    });
  });
}
