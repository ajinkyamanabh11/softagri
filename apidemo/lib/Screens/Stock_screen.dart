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

  @override
  void initState() {
    super.initState();
    _initializeData();
    searchController.addListener(() {
      stockReportController.searchQuery.value = searchController.text;
    });
  }

  Future<void> _initializeData() async {
    try {
      await stockReportController.loadStockReport();
    } finally {
      if (mounted) {
        setState(() {
          _initialLoadCompleted = true;
        });
      }
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
            Obx(() => IconButton(
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: stockReportController.isLoading.value
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Icon(Icons.refresh, color: Colors.white),
              ),
              onPressed: stockReportController.isLoading.value
                  ? null
                  : () async {
                await stockReportController.refreshData();
              },
            )),
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

            // Last updated indicator
            _buildLastUpdatedIndicator(),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: _buildSortOptions(context),
            ),
            const SizedBox(height: 10),
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
                      'Initializing stock data...',
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

        // Debug button (optional - remove in production)
        // floatingActionButton: Column(
        //   mainAxisAlignment: MainAxisAlignment.end,
        //   children: [
        //     FloatingActionButton(
        //       onPressed: () {
        //         print('=== DEBUG INFO ===');
        //         print('Total processed items: ${stockReportController.allProcessedData.length}');
        //         print('Current page data: ${stockReportController.currentPageData.length}');
        //         print('Last updated: ${stockReportController.lastUpdated.value}');
        //         print('Is loading: ${stockReportController.isLoading.value}');
        //         print('Is refreshing: ${stockReportController.isRefreshing.value}');
        //
        //         // Check cache status
        //         final httpService = Get.find<HttpDataServices>();
        //         print('ItemMaster cache status: ${httpService.getCacheStatus('itemMaster')}');
        //         print('ItemDetail cache status: ${httpService.getCacheStatus('itemDetail')}');
        //         print('Is online: ${httpService.isOnline.value}');
        //       },
        //       child: const Icon(Icons.info),
        //       mini: true,
        //     ),
        //     SizedBox(height: 8),
        //     FloatingActionButton(
        //       onPressed: () async {
        //         await Get.find<HttpDataServices>().clearCache();
        //         Get.snackbar('Cache Cleared', 'All cached data has been cleared');
        //       },
        //       child: const Icon(Icons.clear_all),
        //       mini: true,
        //     ),
        //   ],
        // ),
      ),
    );
  }

  Widget _buildContent() {
    return Obx(() {
      if (stockReportController.isLoading.value) {
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
                  onPressed: () async {
                    await stockReportController.refreshData();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }

      if (stockReportController.totalItems.value == 0) {
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inventory_2_outlined, size: 50, color: Colors.grey),
              SizedBox(height: 10),
              Text(
                'No items with stock found or matching search.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        );
      }

      return RefreshIndicator(
        onRefresh: () async {
          await stockReportController.refreshData();
          // Force UI update
          setState(() {});
        },
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
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          Text(
            NumberFormat('#,##0.##').format(stockReportController.totalCurrentStock.value),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdatedIndicator() {
    return Obx(() {
      if (stockReportController.lastUpdated.value == null) return const SizedBox();

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: Text(
          'Last updated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(stockReportController.lastUpdated.value!)}',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      );
    });
  }
}