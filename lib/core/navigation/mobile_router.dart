import 'package:flutter/material.dart';

import '../../models/nav_item_model.dart';
import '../../screens/admin/admin_users_screen.dart';
import '../../screens/admin/data_console_screen.dart';
import '../../screens/catalog/master_data_screen.dart';
import '../../screens/delivery/delivery_customers_screen.dart';
import '../../screens/delivery/delivery_zones_screen.dart';
import '../../screens/expenses/expenses_screen.dart';
import '../../screens/hr/attendance_screen.dart';
import '../../screens/hr/employees_screen.dart';
import '../../screens/hr/hr_dashboard_screen.dart';
import '../../screens/hr/leave_requests_screen.dart';
import '../../screens/hr/payroll_screen.dart';
import '../../screens/hr/penalties_screen.dart';
import '../../screens/manufacturing/manufacturing_screen.dart';
import '../../screens/orders/create_order_screen.dart';
import '../../screens/orders/order_collection_screen.dart';
import '../../screens/orders/orders_list_screen.dart';
import '../../screens/products/products_catalog_screen.dart';
import '../../screens/reports/reports_hub_screen.dart';
import '../../screens/safe/safe_screen.dart';
import '../../screens/sales/sales_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/stock/stock_screen.dart';
import '../../screens/suppliers/suppliers_screen.dart';

class MobileRouter {
  static Widget? resolveScreen(NavItemModel item) {
    final url = (item.url ?? '').trim();
    final href = (item.href ?? '').trim();

    switch (url) {
      // App Downloads
      case 'mobile_app_download':
      case 'mobile_app_download_android':
      case 'mobile_app_download_android_arm64':
      case 'mobile_app_download_ios':
        return const SettingsScreen();

      // Delivery
      case 'delivery_zones':
        return const DeliveryZonesScreen();
      case 'add_delivery_zone':
        return const DeliveryZonesScreen(openCreate: true);
      case 'delivery_customers':
        return const DeliveryCustomersScreen();

      // Orders
      case 'addorder':
        return const CreateOrderScreen(initialType: 'order');
      case 'transfer':
        return const CreateOrderScreen(initialType: 'transfer');
      case 'orders':
        return const OrdersListScreen(direction: 'outgoing', title: 'طلبات الصرف');
      case 'Rorders':
        return const OrdersListScreen(direction: 'incoming', title: 'طلبات الاستلام');
      case 'ordersrev':
        return const OrdersListScreen(direction: 'review', title: 'مراجعة الطلبات');
      case 'allorders':
        return const OrdersListScreen(direction: 'all', title: 'جميع الطلبات');
      case 'collection':
        return const OrderCollectionScreen();

      // Catalog, BOM, Menu Sections & Excel Import/Export
      case 'products':
        return const ProductsCatalogScreen(initialTab: 0);
      case 'addproduct':
        return const ProductsCatalogScreen(initialTab: 0, initialAction: 'add_product');
      case 'excel':
        return const ProductsCatalogScreen(initialTab: 0, initialAction: 'export');
      case 'upload':
        return const ProductsCatalogScreen(initialTab: 0, initialAction: 'import');
      case 'RMproducts':
        return const ProductsCatalogScreen(initialTab: 1);
      case 'complete':
        return const ProductsCatalogScreen(initialTab: 2);
      case 'not_complete':
        return const ProductsCatalogScreen(initialTab: 3);
      case 'menu_sections':
        return const ProductsCatalogScreen(initialTab: 4);
      case 'add_menu_section':
        return const ProductsCatalogScreen(initialTab: 4, initialAction: 'add_section');

      // Master Data: Units, Branches, Store Types, Chart of Accounts
      case 'units':
        return const MasterDataScreen(initialTab: 0);
      case 'addunit':
        return const MasterDataScreen(initialTab: 0, openCreate: true);
      case 'branches':
      case 'getBranches':
        return const MasterDataScreen(initialTab: 1);
      case 'addbranch':
        return const MasterDataScreen(initialTab: 1, openCreate: true);
      case 'stores':
        return const MasterDataScreen(initialTab: 2);
      case 'addstoretype':
        return const MasterDataScreen(initialTab: 2, openCreate: true);
      case 'accounts':
        return const MasterDataScreen(initialTab: 3);
      case 'addaccount':
        return const MasterDataScreen(initialTab: 3, openCreate: true);

      // Stock & Daily Reports
      case 'branchstocks':
      case 'stock':
      case 'itemsearch':
        return const StockScreen(initialTab: 0);
      case 'daily_Report':
        return const StockScreen(initialTab: 1);
      case 'stockentry':
        return const StockScreen(initialTab: 2);

      // Sales
      case 'selling_orders':
        return const SalesScreen();
      case 'sell':
        return const SalesScreen(openCreate: true);

      // Safe & Treasury
      case 'safe_pending_transactions':
        return const SafeScreen(initialTab: 0);
      case 'add_cashin':
        return const SafeScreen(initialTab: 0, initialAction: 'add_cashin');
      case 'direct_advances':
        return const SafeScreen(initialTab: 1);
      case 'set_safe_balances':
        return const SafeScreen(initialTab: 2, initialAction: 'set_balances');

      // Expenses
      case 'expenses':
        return const ExpensesScreen();
      case 'addexpense':
        return const ExpensesScreen(openCreate: true);

      // Purchases & Suppliers
      case 'suppliers':
      case 'getSuppliers':
        return const SuppliersScreen(initialTab: 0);
      case 'addsupplier':
        return const SuppliersScreen(initialTab: 0, initialAction: 'add_supplier');
      case 'suppliers_with_balance':
        return const SuppliersScreen(initialTab: 0, withBalanceOnly: true);
      case 'bills':
      case 'updatebill':
        return const SuppliersScreen(initialTab: 1);
      case 'addbill':
        return const SuppliersScreen(initialTab: 1, initialAction: 'add_bill');
      case 'supplier_receipts':
      case 'print_all_receipts':
        return const SuppliersScreen(initialTab: 2);
      case 'operations':
        return const SuppliersScreen(initialTab: 3);

      // Manufacturing
      case 'manufacturing':
        return const ManufacturingScreen(openCreate: true);
      case 'manufactureProcess':
        return const ManufacturingScreen();

      // HR & Personnel
      case 'hr_dashboard':
        return const HRDashboardScreen();
      case 'employees_list':
        return const EmployeesScreen();
      case 'add_employee':
        return const EmployeesScreen(openCreate: true);
      case 'branch_attendance':
        return const AttendanceScreen();
      case 'attendance':
        return const AttendanceScreen(openRecordsSheet: true);
      case 'leave_requests':
      case 'add_leave':
        return const LeaveRequestsScreen();
      case 'penalties_list':
        return const PenaltiesScreen();
      case 'payroll_list':
      case 'generate_payroll':
        return const PayrollScreen();

      // Reports, Dashboard & Costing
      case 'index':
      case 'dashboard':
        return const ReportsHubScreen(initialTab: 0);
      case 'branch_reports':
        return const ReportsHubScreen(initialTab: 1);
      case 'last_month_expenses':
      case 'branches_expenses':
        return const ReportsHubScreen(
          initialTab: 1,
          initialBranchReportType: 'expenses',
        );
      case 'branches_sales':
      case 'monthly_branches_sales':
        return const ReportsHubScreen(
          initialTab: 1,
          initialBranchReportType: 'sales',
        );
      case 'costanalysis':
        return const ReportsHubScreen(initialTab: 2);
      case 'indirectCost':
        return const ReportsHubScreen(initialTab: 3);

      // Administration & Settings
      case 'users':
      case 'users_list':
      case 'admin_users':
        return const AdminUsersScreen();
      case 'signup':
        return const AdminUsersScreen(openCreate: true);
      case 'data_console':
        return const DataConsoleScreen();
      case 'settings':
        return const SettingsScreen();
    }

    if (href.contains('/mobile-app')) {
      return const SettingsScreen();
    }

    return null;
  }

  static Future<dynamic> openNavItem(BuildContext context, NavItemModel item) {
    final destination = resolveScreen(item);
    if (destination != null) {
      return Navigator.of(context).push(MaterialPageRoute(builder: (_) => destination));
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('الوجهة غير معروفة: ${item.title}', style: const TextStyle(fontFamily: 'Cairo')),
      ),
    );
    return Future<dynamic>.value();
  }
}
