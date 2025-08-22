import 'package:apidemo/Controller/profit_report_controller.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/bindings_interface.dart';

import '../Controller/Sales_controller.dart';
import '../Controller/customerLedgerController.dart';
import '../Controller/item_controller.dart';
import '../Controller/login_controller.dart';
import '../Controller/selfinformation_controller.dart';
import '../Controller/stock_report_controller.dart';
import '../Services/auth_service.dart';
import '../Services/http_data_service.dart';

class AppBindings implements Bindings {
  @override
  void dependencies() {
    // Persistent services
    Get.put(HttpDataServices(), permanent: true);
    Get.put(AuthService(), permanent: true);
    Get.put(LoginController(), permanent: true); // Make LoginController permanent

    // Lazy-loaded controllers
    Get.lazyPut(() => CompanyController(), fenix: true);
    Get.lazyPut(() => CustomerLedgerController(), fenix: true);
    Get.lazyPut(() => SalesController(), fenix: true);
    Get.lazyPut(() => StockReportController(), fenix: true);
    Get.lazyPut(() => ProfitReportController(), fenix: true);
  }
}