import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../Model/item_master.dart';
import '../Model/salesReport_Models/salesInvoiceDetail_model.dart';
import '../Model/salesReport_Models/salesInvoiceMaster_model.dart';
import '../Model/salesReport_Models/salesItemDetail_combined.dart';
import '../Services/http_data_service.dart';
import 'base_remote_controller.dart';

class SalesController extends GetxController with BaseRemoteController {
  final HttpDataServices httpService = Get.find<HttpDataServices>();

  // Observable data
  final salesMaster = <SalesInvoiceMaster>[].obs;
  final salesDetails = <SalesInvoiceDetail>[].obs;
  final itemMaster = <ItemMaster>[].obs;
  final sales = <SalesEntry>[].obs;

  // Cache status
  final cacheStatus = 'Loading cache status...'.obs;
  final isCacheValid = false.obs;

  @override
  void onInit() {
    super.onInit();
    _setupSubfolderListener();
    _initialDataLoad();
  }

  void _setupSubfolderListener() {
    ever(httpService.subfolderRx, (String subfolder) {
      if (subfolder.isNotEmpty) {
        fetchSales();
      }
    });
  }

  void _initialDataLoad() {
    if (httpService.subfolderRx.isNotEmpty) {
      fetchSales();
    }
  }

  void _updateCacheStatus() {
    cacheStatus.value = '''
    Sales Master: ${httpService.getCacheStatus('salesInvoiceMaster')}
    Sales Details: ${httpService.getCacheStatus('salesInvoiceDetails')}
    Items: ${httpService.getCacheStatus('itemMaster')}
    ''';

    isCacheValid.value = httpService.isCacheValid('salesInvoiceMaster') &&
        httpService.isCacheValid('salesInvoiceDetails') &&
        httpService.isCacheValid('itemMaster');
  }

  Future<void> fetchSales({bool forceRefresh = false}) async {
    debugPrint('Fetching sales data for subfolder: ${httpService.subfolderRx}');
    return guard(() async {
      await _loadAllData(forceRefresh);
      _processCombinedSalesData();
      _updateCacheStatus();
    });
  }

  Future<void> _loadAllData(bool forceRefresh) async {
    final results = await Future.wait([
      httpService.fetchSalesInvoiceMaster(forceRefresh: forceRefresh),
      httpService.fetchSalesInvoiceDetails(forceRefresh: forceRefresh),
      httpService.fetchItemMaster(forceRefresh: forceRefresh),
    ]);

    salesMaster.value = results[0] as List<SalesInvoiceMaster>;
    salesDetails.value = results[1] as List<SalesInvoiceDetail>;
    itemMaster.value = results[2] as List<ItemMaster>;
  }

  void _processCombinedSalesData() {
    final itemCodeToName = _createItemCodeMap();
    final detailsByBillNo = _groupDetailsByBillNo(itemCodeToName);

    sales.value = salesMaster.map((master) => SalesEntry(
      accountName: master.accountName,
      billNo: master.billNo,
      paymentMode: master.paymentMode,
      amount: master.totalBillAmount,
      entryDate: master.entryDate,
      invoiceDate: master.invoiceDate,
      items: detailsByBillNo[master.billNo] ?? [],
    )).toList();
  }

  Map<String, String> _createItemCodeMap() {
    return {for (var item in itemMaster) item.itemcode: item.itemname};
  }

  Map<String, List<SalesItemDetail>> _groupDetailsByBillNo(Map<String, String> itemCodeToName) {
    final detailsByBillNo = <String, List<SalesItemDetail>>{};

    for (var detail in salesDetails) {
      if (detail.billNo.isEmpty) continue;

      detailsByBillNo.putIfAbsent(detail.billNo, () => []).add(
        SalesItemDetail(
          billNo: detail.billNo,
          itemCode: detail.itemCode,
          itemName: itemCodeToName[detail.itemCode] ?? 'Unknown Item',
          batchNo: detail.batchNo,
          packing: detail.packing,
          quantity: detail.quantity,
          rate: detail.salesPrice,
          amount: detail.total,
        ),
      );
    }

    return detailsByBillNo;
  }

  // Getters for totals
  double get totalCash => sales
      .where((s) => s.paymentMode?.toLowerCase() == 'cash')
      .fold(0.0, (sum, s) => sum + s.amount);

  double get totalCredit => sales
      .where((s) => s.paymentMode?.toLowerCase() == 'credit')
      .fold(0.0, (sum, s) => sum + s.amount);

  List<SalesEntry> filter({
    required String nameQ,
    required String billQ,
    DateTime? date,
  }) {
    return sales.where((s) {
      final nameMatch = s.accountName.toLowerCase().contains(nameQ.toLowerCase());
      final billMatch = s.billNo.toLowerCase().contains(billQ.toLowerCase());
      final dateMatch = date == null ||
          (s.entryDate != null && DateUtils.isSameDay(s.entryDate!, date));

      return nameMatch && billMatch && dateMatch;
    }).toList();
  }
}