import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/nav_item_model.dart';
import '../../providers/auth_provider.dart';
import '../../screens/admin/admin_users_screen.dart';
import '../../screens/admin/data_console_screen.dart';
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
import '../../screens/pos/pos_screen.dart';
import '../../screens/products/products_catalog_screen.dart';
import '../../screens/reports/reports_hub_screen.dart';
import '../../screens/safe/safe_screen.dart';
import '../../screens/sales/sales_screen.dart';
import '../../screens/settings/settings_screen.dart';
import '../../screens/stock/stock_screen.dart';
import '../../screens/suppliers/suppliers_screen.dart';

class MobileRouter {
  static Future<dynamic> openNavItem(BuildContext context, NavItemModel item) {
    final url = item.url ?? '';
    Widget? destination;
    switch (url) {
      // POS & Cashier
      case 'pos':
        destination = const POSScreen();

      // Delivery
      case 'delivery_zones':
      case 'add_delivery_zone':
        destination = const DeliveryZonesScreen();
      case 'delivery_customers':
        destination = const DeliveryCustomersScreen();

      // Orders
      case 'addorder':
        destination = const CreateOrderScreen(initialType: 'order');
      case 'transfer':
        destination = const CreateOrderScreen(initialType: 'transfer');
      case 'orders':
        destination = const OrdersListScreen(direction: 'outgoing', title: 'طلبات الصرف');
      case 'Rorders':
        destination = const OrdersListScreen(direction: 'incoming', title: 'طلبات الاستلام');
      case 'ordersrev':
        destination = const OrdersListScreen(direction: 'review', title: 'مراجعة الطلبات');
      case 'allorders':
        destination = const OrdersListScreen(direction: 'all', title: 'جميع الطلبات');
      case 'collection':
        destination = const OrderCollectionScreen();

      // Catalog & Products
      case 'products':
      case 'RMproducts':
      case 'complete':
      case 'not_complete':
      case 'menu_sections':
      case 'addproduct':
      case 'add_menu_section':
        destination = const ProductsCatalogScreen();

      // Stock
      case 'branchstocks':
      case 'stock':
      case 'stockentry':
      case 'itemsearch':
      case 'daily_Report':
        destination = const StockScreen();

      // Sales
      case 'selling_orders':
        destination = const SalesScreen();

      // Safe & Treasury
      case 'safe_pending_transactions':
      case 'add_cashin':
      case 'set_safe_balances':
      case 'direct_advances':
        destination = const SafeScreen();

      // Expenses
      case 'expenses':
      case 'addexpense':
        destination = const ExpensesScreen();

      // Purchases & Suppliers
      case 'supplier_receipts':
      case 'suppliers':
      case 'suppliers_with_balance':
      case 'bills':
      case 'addbill':
      case 'operations':
        destination = const SuppliersScreen();

      // Manufacturing
      case 'manufacturing':
      case 'manufactureProcess':
        destination = const ManufacturingScreen();

      // HR & Personnel
      case 'hr_dashboard':
        destination = const HRDashboardScreen();
      case 'employees_list':
        destination = const EmployeesScreen();
      case 'attendance':
      case 'branch_attendance':
        destination = const AttendanceScreen();
      case 'leave_requests':
        destination = const LeaveRequestsScreen();
      case 'penalties_list':
        destination = const PenaltiesScreen();
      case 'payroll_list':
        destination = const PayrollScreen();

      // Reports & BI
      case 'branch_reports':
      case 'dashboard':
      case 'costanalysis':
      case 'indirectCost':
        destination = const ReportsHubScreen();

      // Administration & Settings
      case 'users_list':
      case 'admin_users':
        destination = const AdminUsersScreen();
      case 'data_console':
        destination = const DataConsoleScreen();
      case 'settings':
        destination = const SettingsScreen();
    }

    if (destination != null) {
      final screen = destination;
      return Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    }
    final auth = context.read<AuthProvider>();
    if (item.href != null && item.href!.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${item.title} متاح من متصفح النظام على ${auth.serverUrl}', style: const TextStyle(fontFamily: 'Cairo'))),
      );
      return Future<dynamic>.value();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('لم يتم ربط ${item.title} بشاشة موبايل بعد.', style: const TextStyle(fontFamily: 'Cairo'))),
    );
    return Future<dynamic>.value();
  }
}
