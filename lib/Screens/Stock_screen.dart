import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../Controller/stock_report_controller.dart';
import '../Services/http_data_service.dart';
import '../widgets/animated_Dots_LoadingText.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custome_paginated_table.dart';
import '../widgets/rounded_search_field.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  final StockReportController stockReportController = Get.find();
  final TextEditingController searchController = TextEditingController();
  final FocusNode searchFocusNode = FocusNode();
  bool _initialLoadCompleted = false;
  String _cacheStatus = 'Checking cache...';

  @override
  void initState() {
    super.initState();
    _initializeData();
    searchController.addListener(() {
      stockReportController.searchQuery.value = searchController.text;
    });

    // Listen to cache status
    _updateCacheStatus();
  }

  Future<void> _initializeData() async {
    try {
      await stockReportController.loadStockReport();
      _updateCacheStatus();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load stock data: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } finally {
      if (mounted) {
        setState(() {
          _initialLoadCompleted = true;
        });
      }
    }
  }

  void _updateCacheStatus() {
    final httpService = Get.find<HttpDataServices>();
    final itemMasterStatus = httpService.getCacheStatus('itemMaster');
    final itemDetailStatus = httpService.getCacheStatus('itemDetail');

    setState(() {
      _cacheStatus = 'ItemMaster: $itemMasterStatus\nItemDetail: $itemDetailStatus';
    });
  }

  Future<void> _refreshData() async {
    try {
      await stockReportController.refreshData();
      _updateCacheStatus();
      Get.snackbar(
        'Success',
        'Data refreshed successfully',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Refresh failed: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: CustomAppBar(
          title: const Text('Stock Report'),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'refresh') {
                  _refreshData();
                } else if (value == 'clear_cache') {
                  Get.find<HttpDataServices>().clearCache();
                  _updateCacheStatus();
                  Get.snackbar(
                    'Cache Cleared',
                    'All cached data has been cleared',
                    snackPosition: SnackPosition.BOTTOM,
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'refresh',
                  child: ListTile(
                    leading: Icon(Icons.refresh),
                    title: Text('Force Refresh'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'clear_cache',
                  child: ListTile(
                    leading: Icon(Icons.clear_all),
                    title: Text('Clear Cache'),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // Refresh indicator
            Obx(() {
              if (stockReportController.isRefreshing.value) {
                return const LinearProgressIndicator();
              }
              return const SizedBox.shrink();
            }),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: RoundedSearchField(
                controller: searchController,
                focusNode: searchFocusNode,
                text: "Search By Item Code or Item Name...",
                onClear: () {
                  searchController.clear();
                  stockReportController.searchQuery.value = '';
                  searchFocusNode.unfocus();
                },
                hintText: '',
              ),
            ),

            // Cache status and last updated
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _cacheStatus,
                    style: TextStyle(
                      fontSize: 10,
                      color: onSurfaceColor.withOpacity(0.6),
                    ),
                  ),
                  _buildLastUpdatedIndicator(),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: _buildSortOptions(context),
            ),

            Expanded(
              child: _initialLoadCompleted
                  ? _buildContent()
                  : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(
                      'Loading stock data...',
                      style: TextStyle(color: onSurfaceColor),
                    ),
                  ],
                ),
              ),
            ),

            Obx(() => Visibility(
              visible: _initialLoadCompleted &&
                  !stockReportController.isLoading.value &&
                  stockReportController.errorMessage.value == null &&
                  stockReportController.totalItems.value > 0,
              child: _buildTotalStockCard(context),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Obx(() {
      if (stockReportController.isLoading.value &&
          stockReportController.currentPageData.isEmpty) {
        return Center(
          child: DotsWaveLoadingText(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        );
      }

      if (stockReportController.errorMessage.value != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 40),
                const SizedBox(height: 10),
                Text(
                  'Error: ${stockReportController.errorMessage.value}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _refreshData,
                  child: const Text('Retry'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () {
                    // Try to load from cache only
                    stockReportController.loadStockReport(forceRefresh: false);
                  },
                  child: const Text('Use Cached Data'),
                ),
              ],
            ),
          ),
        );
      }

      if (stockReportController.totalItems.value == 0) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined,
                  size: 50,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5)),
              const SizedBox(height: 10),
              Text(
                searchController.text.isEmpty
                    ? 'No items with stock found.'
                    : 'No items match your search.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                ),
              ),
              if (searchController.text.isNotEmpty)
                TextButton(
                  onPressed: () {
                    searchController.clear();
                    stockReportController.searchQuery.value = '';
                  },
                  child: const Text('Clear Search'),
                ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: _refreshData,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CustomPaginatedTable(
            data: stockReportController.currentPageData,
            columnHeaders: const [
              'Sr.', 'Item Code', 'Item Name', 'Batch No',
              'Package', 'Current Stock', 'Type',
            ],
            columnKeys: const [
              'Sr.No.', 'Item Code', 'Item Name', 'Batch No',
              'Package', 'Current Stock', 'Type',
            ],
            currentPage: stockReportController.currentpage.value,
            totalPages: stockReportController.totalPages.value,
            totalItems: stockReportController.totalItems.value,
            itemsPerPage: stockReportController.itemPerPage.value,
            availableItemsPerPage: stockReportController.availableItemsPerPage,
            paginationInfo: stockReportController.getPaginationInfo(),
            hasNextPage: stockReportController.hasNextpage,
            hasPreviousPage: stockReportController.hasPreviousPage,
            isLoading: stockReportController.isLoadingPage.value,
            onNextPage: stockReportController.nextPage,
            onPreviousPage: stockReportController.previousPage,
            onGoToPage: stockReportController.goToPage,
            onItemsPerPageChanged: stockReportController.setItemsPerPage,
          ),
        ),
      );
    });
  }

  // ... rest of the methods remain the same (_buildSortOptions, _buildTotalStockCard, etc.)
  Widget _buildLastUpdatedIndicator() {
    return Obx(() {
      if (stockReportController.lastUpdated.value == null) return const SizedBox();

      return Text(
        'Last updated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(stockReportController.lastUpdated.value!)}',
        style: TextStyle(
          fontSize: 10,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
        ),
      );
    });
  }

  Widget _buildSortOptions(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() => Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        ChoiceChip(
          label: const Text('Item Name'),
          selected: stockReportController.sortByColumn.value == 'Item Name',
          onSelected: (selected) => selected
              ? stockReportController.setSortColumn('Item Name')
              : stockReportController.toggleSortOrder(),
          selectedColor: theme.primaryColor,
          labelStyle: TextStyle(
            color: stockReportController.sortByColumn.value == 'Item Name'
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
          ),
          backgroundColor: theme.colorScheme.surfaceVariant,
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Current Stock'),
          selected: stockReportController.sortByColumn.value == 'Current Stock',
          onSelected: (selected) => selected
              ? stockReportController.setSortColumn('Current Stock')
              : stockReportController.toggleSortOrder(),
          selectedColor: theme.primaryColor,
          labelStyle: TextStyle(
            color: stockReportController.sortByColumn.value == 'Current Stock'
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
          ),
          backgroundColor: theme.colorScheme.surfaceVariant,
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(
            stockReportController.sortAscending.value
                ? Icons.arrow_upward
                : Icons.arrow_downward,
            color: theme.primaryColor,
          ),
          onPressed: () => stockReportController.toggleSortOrder(),
        ),
      ],
    ));
  }

  Widget _buildTotalStockCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total Current Stock:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          Text(
            NumberFormat('#,##0.##').format(stockReportController.totalCurrentStock.value),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}