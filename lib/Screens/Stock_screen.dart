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

  @override
  void dispose() {
    searchController.dispose();
    searchFocusNode.dispose();
    super.dispose();
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
                    : const Icon(Icons.refresh, color: Colors.white),
              ),
              onPressed: stockReportController.isLoading.value
                  ? null
                  : () async {
                await stockReportController.refreshData();
              },
            )),
          ],
        ),
        body: _buildBody(context, onSurfaceColor),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Color onSurfaceColor) {
    return Obx(() {
      if (stockReportController.isRefreshing.value) {
        return Column(
          children: [
            const LinearProgressIndicator(),
            Expanded(
              child: _ContentBody(
                controller: stockReportController,
                searchController: searchController,
                searchFocusNode: searchFocusNode,
              ),
            ),
          ],
        );
      }

      return _initialLoadCompleted
          ? _ContentBody(
        controller: stockReportController,
        searchController: searchController,
        searchFocusNode: searchFocusNode,
      )
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
      );
    });
  }
}

class _ContentBody extends StatelessWidget {
  final StockReportController controller;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;

  const _ContentBody({
    required this.controller,
    required this.searchController,
    required this.searchFocusNode,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await controller.refreshData();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: RoundedSearchField(
                controller: searchController,
                focusNode: searchFocusNode,
                text: "Search By Item Code or Item Name...",
                onClear: () {
                  searchController.clear();
                  controller.searchQuery.value = '';
                  searchFocusNode.unfocus();
                },
                hintText: '',
              ),
            ),

            // Last updated indicator
            _buildLastUpdatedIndicator(context, controller),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              child: _buildSortOptions(context, controller),
            ),
            const SizedBox(height: 10),

            Obx(() {
              if (controller.isLoading.value) {
                return Center(
                  child: DotsWaveLoadingText(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                );
              }

              if (controller.errorMessage.value != null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 40),
                        const SizedBox(height: 10),
                        Text(
                          'Error: ${controller.errorMessage.value}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () async {
                            await controller.refreshData();
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (controller.totalItems.value == 0) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
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

              return Container(
                height: MediaQuery.of(context).size.height * 0.6,
                padding: const EdgeInsets.all(8.0),
                child: CustomPaginatedTable(
                  data: controller.currentPageData,
                  columnHeaders: const [
                    'Sr.', 'Item Code', 'Item Name', 'Batch No',
                    'Package', 'Current Stock', 'Type',
                  ],
                  columnKeys: const [
                    'Sr.No.', 'Item Code', 'Item Name', 'Batch No',
                    'Package', 'Current Stock', 'Type',
                  ],
                  currentPage: controller.currentpage.value,
                  totalPages: controller.totalPages.value,
                  totalItems: controller.totalItems.value,
                  itemsPerPage: controller.itemPerPage.value,
                  availableItemsPerPage: controller.availableItemsPerPage,
                  paginationInfo: controller.getPaginationInfo(),
                  hasNextPage: controller.hasNextpage,
                  hasPreviousPage: controller.hasPreviousPage,
                  isLoading: controller.isLoadingPage.value,
                  onNextPage: controller.nextPage,
                  onPreviousPage: controller.previousPage,
                  onGoToPage: controller.goToPage,
                  onItemsPerPageChanged: controller.setItemsPerPage,
                ),
              );
            }),

            Obx(() => Visibility(
              visible: !controller.isLoading.value &&
                  controller.errorMessage.value == null &&
                  controller.totalItems.value > 0,
              child: _buildTotalStockCard(context, controller),
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOptions(BuildContext context, StockReportController controller) {
    final theme = Theme.of(context);

    return Obx(() => Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        ChoiceChip(
          label: const Text('Item Name'),
          selected: controller.sortByColumn.value == 'Item Name',
          onSelected: (selected) => selected
              ? controller.setSortColumn('Item Name')
              : controller.toggleSortOrder(),
          selectedColor: theme.primaryColor,
          labelStyle: TextStyle(
            color: controller.sortByColumn.value == 'Item Name'
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
          ),
          backgroundColor: theme.colorScheme.surfaceVariant,
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('Current Stock'),
          selected: controller.sortByColumn.value == 'Current Stock',
          onSelected: (selected) => selected
              ? controller.setSortColumn('Current Stock')
              : controller.toggleSortOrder(),
          selectedColor: theme.primaryColor,
          labelStyle: TextStyle(
            color: controller.sortByColumn.value == 'Current Stock'
                ? theme.colorScheme.onPrimary
                : theme.colorScheme.onSurface,
          ),
          backgroundColor: theme.colorScheme.surfaceVariant,
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(
            controller.sortAscending.value
                ? Icons.arrow_upward
                : Icons.arrow_downward,
            color: theme.primaryColor,
          ),
          onPressed: () => controller.toggleSortOrder(),
        ),
      ],
    ));
  }

  Widget _buildTotalStockCard(BuildContext context, StockReportController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: const Offset(0, 3),
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
            NumberFormat('#,##0.##').format(controller.totalCurrentStock.value),
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

  Widget _buildLastUpdatedIndicator(BuildContext context, StockReportController controller) {
    return Obx(() {
      if (controller.lastUpdated.value == null) return const SizedBox();

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
        child: Text(
          'Last updated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(controller.lastUpdated.value!)}',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      );
    });
  }
}