// lib/routes/app_page_routes.dart
import 'package:get/get.dart';
import '../Screens/Creditors_Screen.dart';
import '../Screens/Customer_Ledger_screen.dart';
import '../Screens/Debtors_screen.dart';
import '../Screens/Profit_screen.dart';
import '../Screens/Stock_screen.dart';
import '../Screens/app_lock_screen.dart';
import '../Screens/data_loading_screen.dart';
import '../Screens/homeScreen.dart';

import '../screens/sales_screen.dart';
 // Updated import
import '../screens/splash_screen.dart';
import '../screens/loginpage.dart';
import '../screens/walkthrough_screen.dart';
import 'routes.dart';

class AppPages {
  static final routes = [
    GetPage(name: Routes.appLock, page: () => const AppLockScreen()),
    GetPage(name: Routes.walkthrough, page: () => const WalkthroughScreen()),
    GetPage(name: Routes.splash, page: () => const SplashScreen()),
    GetPage(name: Routes.login, page: () => const LoginPage()),
    GetPage(name: Routes.home, page: () => const HomeScreen()),
    GetPage(name: Routes.dataLoading, page: () => const DataLoadingScreen()),

    // Stock
    GetPage(name: Routes.itemTypes, page: () => StockScreen()),

    // Sales
    GetPage(name: Routes.sales, page: () => const SalesScreen()),

    // Ledgers
    GetPage(name: Routes.customerLedger, page: () => const CustomerLedgerScreen()),

    // Derived screens
    GetPage(name: Routes.debtors, page: () => const DebtorsScreen()),
    GetPage(name: Routes.creditors, page: () => const CreditorsScreen()),
    GetPage(name: Routes.profit, page: () => const ProfitReportScreen()), // Updated class name
  ];
}