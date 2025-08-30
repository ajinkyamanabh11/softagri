// stock_report_controller.dart
import 'dart:developer';

import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter/material.dart';
import '../Model/item_master.dart';
import '../Model/item_detail.dart';
import '../Services/http_data_service.dart';

class StockReportController extends GetxController {
  var isLoading = true.obs;
  var isLoadingPage = false.obs;
  var errorMessage = Rx<String?>(null);
  var searchQuery = "".obs;
  var sortByColumn = 'Item Name'.obs;
  var sortAscending = true.obs;

  var currentpage = 0.obs;
  var itemPerPage = 25.obs;
  var totalItems = 0.obs;
  var totalPages = 0.obs;

  var currentPageData = <Map<String, dynamic>>[].obs;
  var totalCurrentStock = 0.0.obs;
  final debouncedSearchQuery = ''.obs;
  final GetStorage _storage = GetStorage();
  var isRefreshing = false.obs;
  var lastUpdated = Rx<DateTime?>(null);

  // Remove these constants since we're using HttpDataServices cache
  // static const _itemMasterKey = 'itemMaster';
  // static const _itemDetailKey = 'itemDetail';

  List<Map<String, dynamic>> allProcessedData = [];
  List<int> filteredDataIndices = [];

  @override
  void onInit() {
    super.onInit();
    _setupSubfolderListener();
    _initialDataLoad();

    debounce(searchQuery, (value) {
      debouncedSearchQuery.value = value;
      currentpage.value = 0;
      _onFilterChanged();
    }, time: Duration(milliseconds: 500));

    ever(searchQuery, (_) => _onFilterChanged());
    ever(sortByColumn, (_) => _onFilterChanged());
    ever(sortAscending, (_) => _onFilterChanged());
    ever(currentpage, (_) => _loadCurrentPageData());
    ever(itemPerPage, (_) => _onItemsPerPageChanged());
  }

  void _setupSubfolderListener() {
    ever(Get.find<HttpDataServices>().subfolderRx, (String subfolder) {
      if (subfolder.isNotEmpty) {
        loadStockReport();
      }
    });
  }

  void _initialDataLoad() {
    if (Get.find<HttpDataServices>().subfolderRx.isNotEmpty) {
      loadStockReport();
    }
  }

  Future<void> refreshData() async {
    isRefreshing.value = true;
    try {
      print('Starting refresh...');

      // Clear ALL cached data first
      await Get.find<HttpDataServices>().clearCache();

      // Clear local data
      allProcessedData.clear();
      filteredDataIndices.clear();
      currentPageData.value = [];
      totalCurrentStock.value = 0.0;
      currentpage.value = 0;

      // Force refresh both item master and item detail
      final allItemMaster = await Get.find<HttpDataServices>().fetchItemMaster(forceRefresh: true);
      final allItemDetail = await Get.find<HttpDataServices>().fetchItemDetail(forceRefresh: true);

      await _processAllData(allItemDetail, allItemMaster);

      print('Refresh completed successfully. Processed ${allProcessedData.length} items');

    } catch (e, stack) {
      errorMessage.value = 'Refresh failed: ${e.toString()}';
      log('Error during refresh: $e\n$stack');
      rethrow;
    } finally {
      isRefreshing.value = false;
      lastUpdated.value = DateTime.now();
    }
  }

  Future<void> loadStockReport({bool forceRefresh = false}) async {
    isLoading.value = true;
    errorMessage.value = null;
    print('Loading stock report with forceRefresh: $forceRefresh');

    try {
      if (forceRefresh) {
        // For force refresh, use the refreshData method
        await refreshData();
        return;
      }

      // For normal load, use HttpDataServices which handles caching internally
      List<ItemDetail> allItemDetail;
      List<ItemMaster> allItemMaster;

      if (Get.find<HttpDataServices>().isOnline.value) {
        allItemMaster = await Get.find<HttpDataServices>().fetchItemMaster(forceRefresh: false);
        allItemDetail = await Get.find<HttpDataServices>().fetchItemDetail(forceRefresh: false);
      } else {
        // In offline mode, HttpDataServices will automatically fall back to cached data
        allItemMaster = await Get.find<HttpDataServices>().fetchItemMaster(forceRefresh: false);
        allItemDetail = await Get.find<HttpDataServices>().fetchItemDetail(forceRefresh: false);
      }

      await _processAllData(allItemDetail, allItemMaster);

      if (allProcessedData.isEmpty) {
        errorMessage.value = 'No stock data found after processing.';
      }
    } catch (e, st) {
      errorMessage.value = 'Failed to load stock data: ${e.toString()}';
      log('Error loading stock data: $e\n$st');

      // Try to load from cache using HttpDataServices
      try {
        // Force use of cache even if expired
        final allItemMaster = await Get.find<HttpDataServices>().fetchItemMaster(forceRefresh: false);
        final allItemDetail = await Get.find<HttpDataServices>().fetchItemDetail(forceRefresh: false);
        await _processAllData(allItemDetail, allItemMaster);
      } catch (cacheError) {
        log('Cache load error: $cacheError');
        throw Exception('Both API and cache failed: $cacheError');
      }
    } finally {
      isLoading.value = false;
      lastUpdated.value = DateTime.now();
    }
  }

  Future<void> _processAllData(List<ItemDetail> allItemDetail, List<ItemMaster> allItemMaster) async {
    print('Processing ${allItemDetail.length} item details and ${allItemMaster.length} item masters');

    final List<Map<String, dynamic>> processedList = [];
    double currentTotalStock = 0.0;
    final masterMap = {for (var item in allItemMaster) item.itemcode: item};

    int itemsWithStock = 0;

    for (final itemDetail in allItemDetail) {
      if (itemDetail.currentstock > 0) {
        itemsWithStock++;
        final itemMaster = masterMap[itemDetail.itemcode];
        if (itemMaster != null) {
          final pkg = itemDetail.packing?.isNotEmpty ?? false ? itemDetail.packing : '';
          final unit = itemDetail.cmbunit?.isNotEmpty ?? false ? itemDetail.cmbunit : '';

          final pkgunit = [pkg, unit].where((s) => s?.isNotEmpty ?? false).join(' ');

          processedList.add({
            'Item Code': itemDetail.itemcode ?? '',
            'Item Name': itemMaster.itemname ?? '',
            'Batch No': itemDetail.batchno ?? '',
            'Package': pkgunit.isNotEmpty ? pkgunit : 'N/A',
            'Current Stock': itemDetail.currentstock ?? 0.0,
            'Type': itemMaster.itemtype ?? '',
          });
          currentTotalStock += itemDetail.currentstock ?? 0.0;
        }
      }
    }

    allProcessedData = processedList;
    totalCurrentStock.value = currentTotalStock;

    print('Processed $itemsWithStock items with stock. Total stock: $currentTotalStock');

    _applyFilterAndSort();
    _loadCurrentPageData();
  }

  // ... rest of the methods remain the same (setSortColumn, toggleSortOrder, etc.)
  void setSortColumn(String column) {
    if (sortByColumn.value == column) {
      toggleSortOrder();
    } else {
      sortByColumn.value = column;
      sortAscending.value = true;
    }
  }

  void toggleSortOrder() {
    sortAscending.value = !sortAscending.value;
  }

  void nextPage() {
    if (currentpage.value < totalPages.value - 1) {
      currentpage.value++;
    }
  }

  void previousPage() {
    if (currentpage.value > 0) {
      currentpage.value--;
    }
  }

  void goToPage(int page) {
    if (page >= 0 && page < totalPages.value) {
      currentpage.value = page;
    }
  }

  void setItemsPerPage(int? newItemsPerPage) {
    if (newItemsPerPage != null) {
      itemPerPage.value = newItemsPerPage;
      loadStockReport();
    }
  }

  void _onItemsPerPageChanged() {
    currentpage.value = 0;
    _applyFilterAndSort();
    _loadCurrentPageData();
  }

  void _onFilterChanged() {
    _applyFilterAndSort();
    _loadCurrentPageData();
  }

  void _applyFilterAndSort() {
    isLoadingPage.value = true;

    try {
      final search = searchQuery.value.toLowerCase().trim();
      List<int> indices = [];

      if (search.isEmpty) {
        indices = List.generate(allProcessedData.length, (index) => index);
      } else {
        for (int i = 0; i < allProcessedData.length; i++) {
          final item = allProcessedData[i];
          final itemCode = item['Item Code']?.toString().toLowerCase() ?? '';
          final itemName = item['Item Name']?.toString().toLowerCase() ?? '';
          final batchNo = item['Batch No']?.toString().toLowerCase() ?? '';

          if (itemCode.contains(search) ||
              itemName.contains(search) ||
              batchNo.contains(search)) {
            indices.add(i);
          }
        }
      }

      // Sort logic
      indices.sort((aIndex, bIndex) {
        final a = allProcessedData[aIndex];
        final b = allProcessedData[bIndex];
        int compareResult = 0;

        if (sortByColumn.value == 'Item Name') {
          compareResult = (a['Item Name']?.toString().toLowerCase() ?? '')
              .compareTo(b['Item Name']?.toString().toLowerCase() ?? '');
        } else if (sortByColumn.value == 'Current Stock') {
          final valA = a['Current Stock'] ?? 0.0;
          final valB = b['Current Stock'] ?? 0.0;
          compareResult = (valA as num).compareTo(valB as num);
        } else if (sortByColumn.value == 'Item Code') {
          compareResult = (a['Item Code']?.toString().toLowerCase() ?? '')
              .compareTo(b['Item Code']?.toString().toLowerCase() ?? '');
        }

        return sortAscending.value ? compareResult : -compareResult;
      });

      filteredDataIndices = indices;
      totalItems.value = filteredDataIndices.length;
      totalPages.value = (totalItems.value / itemPerPage.value).ceil();

      if (currentpage.value >= totalPages.value && totalPages.value > 0) {
        currentpage.value = totalPages.value - 1;
      } else if (totalPages.value == 0) {
        currentpage.value = 0;
      }
    } finally {
      isLoadingPage.value = false;
    }
  }

  void _loadCurrentPageData() {
    if (filteredDataIndices.isEmpty) {
      currentPageData.value = [];
      return;
    }

    isLoadingPage.value = true;

    try {
      final startIndex = currentpage.value * itemPerPage.value;
      var endIndex = startIndex + itemPerPage.value;
      endIndex = endIndex > filteredDataIndices.length
          ? filteredDataIndices.length
          : endIndex;

      final List<Map<String, dynamic>> pageData = [];
      for (int i = startIndex; i < endIndex; i++) {
        final dataIndex = filteredDataIndices[i];
        final item = Map<String, dynamic>.from(allProcessedData[dataIndex]);
        item['Sr.No.'] = i + 1;
        pageData.add(item);
      }
      currentPageData.value = pageData;
    } finally {
      isLoadingPage.value = false;
    }
  }

  String getPaginationInfo() {
    if (totalItems.value == 0) return 'No items';
    final startItem = (currentpage.value * itemPerPage.value) + 1;
    final endItem = ((currentpage.value + 1) * itemPerPage.value)
        .clamp(0, totalItems.value);
    return 'Showing $startItem-$endItem of ${totalItems.value} items';
  }

  bool get hasNextpage => currentpage.value < totalPages.value - 1;
  bool get hasPreviousPage => currentpage.value > 0;

  List<int> get availableItemsPerPage {
    // Always include the standard options
    List<int> options = [10, 25, 50, 100];

    // If total items is less than the smallest option, include it
    if (totalItems.value > 0 && totalItems.value < options.first) {
      options = [totalItems.value, ...options];
    }

    // Remove duplicates and sort
    return options.toSet().toList()..sort();
  }
}