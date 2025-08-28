import 'dart:developer';

import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../Model/item_detail.dart';
import '../Model/salesReport_Models/salesInvoiceDetail_model.dart';
import '../Services/http_data_service.dart';


class ProfitReportController extends GetxController {
  final HttpDataServices _dataService = Get.find<HttpDataServices>();

  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();

  final isLoading = false.obs;
  final batchProfits = <Map<String, dynamic>>[].obs;
  final filteredInvoices = <Map<String, dynamic>>[].obs;

  // Pagination variables
  final currentPage = 0.obs;
  final itemsPerPage = 50.obs;
  final totalItems = 0.obs;
  final totalPages = 0.obs;

  // All data storage for pagination
  List<Map<String, dynamic>> allBatchProfits = [];

  final totalSales = 0.0.obs;
  final totalPurchase = 0.0.obs;
  final totalProfit = 0.0.obs;

  final searchQuery = ''.obs;

  List<Map<String, dynamic>> get filteredRows {
    final search = searchQuery.value.toLowerCase();
    if (search.isEmpty) return batchProfits;
    return batchProfits.where((row) {
      final item = (row['itemName'] ?? '').toString().toLowerCase();
      final bill = (row['billno'] ?? '').toString().toLowerCase();
      return item.contains(search) || bill.contains(search);
    }).toList();
  }

  /// Navigate to next page
  void nextPage() {
    if (currentPage.value < totalPages.value - 1) {
      currentPage.value++;
      _updateDisplayedData();
    }
  }

  /// Navigate to previous page
  void previousPage() {
    if (currentPage.value > 0) {
      currentPage.value--;
      _updateDisplayedData();
    }
  }

  /// Go to specific page
  void goToPage(int page) {
    if (page >= 0 && page < totalPages.value) {
      currentPage.value = page;
      _updateDisplayedData();
    }
  }

  /// Set items per page and refresh display
  void setItemsPerPage(int items) {
    itemsPerPage.value = items;
    currentPage.value = 0; // Reset to first page
    _updatePaginationInfo();
    _updateDisplayedData();
  }

  void resetProfits() {
    batchProfits.clear();
    allBatchProfits.clear();
    totalSales.value = 0.0;
    totalPurchase.value = 0.0;
    totalProfit.value = 0.0;
    totalItems.value = 0;
    totalPages.value = 0;
    currentPage.value = 0;
  }

  Future<void> loadProfitReport({
    required DateTime startDate,
    required DateTime endDate,
    bool forceRefresh = false,
  }) async {
    isLoading.value = true;
    totalSales.value = 0.0;
    totalPurchase.value = 0.0;
    totalProfit.value = 0.0;
    batchProfits.clear();
    allBatchProfits.clear();

    log('📈 ProfitReportController: Starting load for dates: $startDate to $endDate');

    try {
      // Fetch all required data
      final masters = await _dataService.fetchSalesInvoiceMaster(forceRefresh: forceRefresh);
      final details = await _dataService.fetchSalesInvoiceDetails(forceRefresh: forceRefresh);
      final items = await _dataService.fetchItemMaster(forceRefresh: forceRefresh);
      final itemDetails = await _dataService.fetchItemDetail(forceRefresh: forceRefresh);

      log('📈 ProfitReportController: Data fetched - Masters: ${masters.length}, Details: ${details.length}');

      // Filter invoices by date range
      final filtered = masters.where((inv) {
        final date = inv.invoiceDate ?? inv.entryDate;
        if (date == null) return false;
        return date.isAfter(startDate.subtract(Duration(days: 1))) &&
            date.isBefore(endDate.add(Duration(days: 1)));
      }).toList();

      filteredInvoices.assignAll(filtered.map((e) => e.toJson()));
      log('📄 ProfitReportController: Filtered invoices: ${filtered.length}');

      // Prepare lookup maps
      final detailsByInvoice = <String, List<SalesInvoiceDetail>>{};
      for (final detail in details) {
        final bill = detail.billNo.toUpperCase();
        detailsByInvoice.putIfAbsent(bill, () => []).add(detail);
      }

      final itemMap = {
        for (var item in items) item.itemcode.toUpperCase(): item
      };

      final itemDetailsByItemBatch = <String, List<ItemDetail>>{};
      for (var detail in itemDetails) {
        final key = '${detail.itemcode.toUpperCase()}_${detail.batchno.toUpperCase()}';
        itemDetailsByItemBatch.putIfAbsent(key, () => []).add(detail);
      }

      // Process data
      final results = <Map<String, dynamic>>[];
      for (final inv in filtered) {
        final invoiceNo = inv.billNo.toUpperCase();
        final invoiceDate = inv.invoiceDate ?? inv.entryDate;
        if (invoiceNo.isEmpty || invoiceDate == null) continue;

        final matchingLines = detailsByInvoice[invoiceNo] ?? [];

        for (final d in matchingLines) {
          final itemCode = d.itemCode.toUpperCase();
          final batchNo = d.batchNo.toUpperCase();
          final salesPacking = _normalizePacking(d.packing);

          final salesDetailQty = d.quantity;
          final salesDetailPrice = d.cgstTaxableAmt;

          if (salesDetailQty <= 0 || itemCode.isEmpty) continue;

          final item = itemMap[itemCode];
          final itemName = item?.itemname ?? itemCode;

          final lookupKey = '${itemCode}_${batchNo}';
          ItemDetail? matchingDetail;

          List<ItemDetail> potentialMatches = itemDetailsByItemBatch[lookupKey] ?? [];

          if (potentialMatches.isEmpty) {
            potentialMatches = itemDetails.where((detail) =>
            detail.itemcode.toUpperCase() == itemCode &&
                (detail.batchno.toUpperCase() == '..' ||
                    detail.batchno.isEmpty)).toList();
          }

          if (potentialMatches.isNotEmpty) {
            matchingDetail = potentialMatches.firstWhere(
                  (detail) {
                final itemDetailPacking = _normalizePacking('${detail?.packing}${detail.cmbunit}');
                return itemDetailPacking == salesPacking;
              },
              orElse: () => potentialMatches.first,
            );
          }

          final String calculatedPacking = matchingDetail != null
              ? '${matchingDetail.packing}${matchingDetail.cmbunit}'
              : '';

          final purcPricePerUnit = matchingDetail?.purchasePrice ?? 0.0; // Changed from currentstock
          final totalPurchase = purcPricePerUnit * salesDetailQty;
          final profitCalculated = salesDetailPrice - totalPurchase;
          final entry = {
            'billno': invoiceNo,
            'batchno': batchNo,
            'qty': salesDetailQty,
            'sales': salesDetailPrice,
            'purchase': totalPurchase,
            'profit': profitCalculated,
            'packing': calculatedPacking,
            'itemName': itemName,
            'itemCode': itemCode,
            'date': DateFormat('yyyy-MM-dd').format(invoiceDate),
          };

          results.add(entry);
        }
      }

      log('📈 ProfitReportController: Data processing returned ${results.length} entries.');

      if (results.isNotEmpty) {
        allBatchProfits = results;
        _updateTotals(results);
        _updatePaginationInfo();
        _updateDisplayedData();
        log('📈 ProfitReportController: Data updated. Sales: ${totalSales.value}, Profit: ${totalProfit.value}');
      } else {
        resetProfits();
        log('📈 ProfitReportController: No data returned, profits reset to 0.');
      }
    } catch (e, st) {
      log('[ProfitReport] ❌ Error in loadProfitReport: $e\n$st');
      resetProfits();
      filteredInvoices.clear();
    } finally {
      isLoading.value = false;
      log('📈 ProfitReportController: Loading finished. isLoading: ${isLoading.value}');
    }
  }

  void _updateTotals(List<Map<String, dynamic>> rows) {
    double sale = 0;
    double purchase = 0;
    double profit = 0;

    for (final row in rows) {
      sale += row['sales'] ?? 0;
      purchase += row['purchase'] ?? 0;
      profit += row['profit'] ?? 0;
    }

    totalSales.value = sale;
    totalPurchase.value = purchase;
    totalProfit.value = profit;
  }

  /// Update pagination information
  void _updatePaginationInfo() {
    totalItems.value = allBatchProfits.length;
    totalPages.value = (totalItems.value / itemsPerPage.value).ceil();

    // Reset to first page if current page is out of bounds
    if (currentPage.value >= totalPages.value && totalPages.value > 0) {
      currentPage.value = 0;
    }
  }

  /// Update the displayed data based on current page
  void _updateDisplayedData() {
    if (allBatchProfits.isEmpty) {
      batchProfits.value = [];
      return;
    }

    final startIndex = currentPage.value * itemsPerPage.value;
    final endIndex = (startIndex + itemsPerPage.value).clamp(0, allBatchProfits.length);

    final pageData = allBatchProfits.sublist(startIndex, endIndex);
    batchProfits.value = pageData;

    log('📄 ProfitReportController: Displaying page ${currentPage.value + 1} of ${totalPages.value} (${pageData.length} items)');
  }

  /// Get pagination info as string
  String getPaginationInfo() {
    if (totalItems.value == 0) return 'No items';

    final startItem = (currentPage.value * itemsPerPage.value) + 1;
    final endItem = ((currentPage.value + 1) * itemsPerPage.value).clamp(0, totalItems.value);

    return 'Showing $startItem-$endItem of ${totalItems.value} items';
  }

  /// Check if there are more pages
  bool get hasNextPage => currentPage.value < totalPages.value - 1;
  bool get hasPreviousPage => currentPage.value > 0;

  String _normalizePacking(String packing) {
    if (packing.isEmpty) return '';
    return packing.replaceAllMapped(RegExp(r'(\d+)\.0(\D*)$'), (match) {
      return '${match.group(1)}${match.group(2)}';
    }).toUpperCase().trim();
  }

  void clear() {
    resetProfits();
    filteredInvoices.clear();
    searchQuery.value = '';
  }
}