import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../Controller/customerLedgerController.dart';
import '../widgets/animated_Dots_LoadingText.dart';
import '../widgets/custom_app_bar.dart';

class CreditorsScreen extends StatefulWidget {
  const CreditorsScreen({super.key});

  @override
  State<CreditorsScreen> createState() => _CreditorsScreenState();
}

class _CreditorsScreenState extends State<CreditorsScreen> {
  final ctrl = Get.find<CustomerLedgerController>();
  final searchCtrl = TextEditingController();
  final RxString searchQ = ''.obs;
  final RxString filterType = 'All'.obs;
  final ScrollController listCtrl = ScrollController();
  final RxBool showFab = false.obs;
  final RxBool isLoadingMore = false.obs;

  @override
  void initState() {
    super.initState();
    listCtrl.addListener(_onScroll);
    if (ctrl.creditors.isEmpty && !ctrl.isLoading.value) {
      ctrl.loadData();
    }
  }

  void _onScroll() {
    // The offset checks whether the user has scrolled past 300 pixels.
    // This value is arbitrary and can be adjusted.
    showFab.value = listCtrl.offset > 300;
    if (listCtrl.position.pixels >= listCtrl.position.maxScrollExtent - 200) {
      _loadMoreIfNeeded();
    }
  }

  void _loadMoreIfNeeded() async {
    if (isLoadingMore.value || !ctrl.hasMoreCreditors.value) return;
    isLoadingMore.value = true;
    try {
      await Future.delayed(const Duration(milliseconds: 100));
      ctrl.loadMoreCreditors();
    } finally {
      isLoadingMore.value = false;
    }
  }

  @override
  void dispose() {
    listCtrl.removeListener(_onScroll);
    listCtrl.dispose();
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final onPrimaryColor = theme.colorScheme.onPrimary;
    final onSurfaceColor = theme.colorScheme.onSurface;

    return Scaffold(
      appBar: CustomAppBar(
        title: Text('Creditors', style: theme.appBarTheme.titleTextStyle),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              try {
                await ctrl.refreshData();
              } catch (e) {
                Get.snackbar(
                  'Refresh Failed',
                  'Could not refresh data: ${e.toString()}',
                  snackPosition: SnackPosition.BOTTOM,
                  colorText: Colors.black,
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: Obx(() => showFab.value
          ? FloatingActionButton(
        heroTag: 'toTopBtn',
        backgroundColor: primaryColor,
        onPressed: () => listCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        ),
        child: Icon(Icons.arrow_upward, color: onPrimaryColor),
      )
          : const SizedBox.shrink()),
        body: Obx(() {
          if (ctrl.isLoading.value && ctrl.creditors.isEmpty) {
            return Center(child: DotsWaveLoadingText(color: onSurfaceColor));
          }

          if (ctrl.error.value != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '❌  ${ctrl.error.value!}',
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ctrl.loadData(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          // Use the filtered and sorted list here
          final filteredAndSortedCreditors = _getFilteredCreditors();

          if (filteredAndSortedCreditors.isEmpty) {
            return _buildEmptyState(context);
          }

          return Stack(
            children: [
              RefreshIndicator(
                onRefresh: () => ctrl.refreshData(),
                color: primaryColor,
                child: SingleChildScrollView(
                  controller: listCtrl,
                  padding: const EdgeInsets.only(bottom: 80), // Space for totals container
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                        child: TextField(
                          controller: searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Search by name',
                            prefixIcon: Icon(Icons.search, color: primaryColor),
                            suffixIcon: searchCtrl.text.isEmpty
                                ? null
                                : IconButton(
                              icon: Icon(Icons.clear, color: theme.iconTheme.color),
                              onPressed: () {
                                searchCtrl.clear();
                                searchQ.value = '';
                              },
                            ),
                            filled: true,
                            fillColor: theme.colorScheme.surfaceVariant,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            hintStyle: TextStyle(color: onSurfaceColor.withOpacity(0.6)),
                          ),
                          style: TextStyle(color: onSurfaceColor),
                          onChanged: (v) => searchQ.value = v,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
                        child: Wrap(
                          spacing: 8,
                          children: [
                            _chip('All', context),
                            _chip('Customer', context),
                            _chip('Supplier', context),
                          ],
                        ),
                      ),
                      if (ctrl.isProcessingData.value)
                        _buildProcessingIndicator(ctrl.dataProcessingProgress.value, context),

                      // List items
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredAndSortedCreditors.length + (ctrl.hasMoreCreditors.value ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i == filteredAndSortedCreditors.length) {
                            return _buildLoadingMoreIndicator();
                          }
                          return _creditorTile(filteredAndSortedCreditors[i], context);
                        },
                      ),
                      const SizedBox(height: 20), // Extra space at bottom
                    ],
                  ),
                ),
              ),

              // Totals section (positioned at bottom)
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: _totals(filteredAndSortedCreditors, context),
              ),
            ],
          );
        }),
    );
  }

  Widget _buildProcessingIndicator(double progress, BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          ),
          const SizedBox(height: 8),
          Text(
            'Processing data... ${(progress * 100).toInt()}%',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
          ),
          if (progress < 0.9) const SizedBox(height: 4),
          if (progress < 0.9) Text(
            'Processing large dataset, please wait...',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet_outlined,
              size: 64, color: theme.colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('No creditors found.',
              style: TextStyle(color: theme.colorScheme.onSurface)),
          if (searchQ.value.isNotEmpty || filterType.value != 'All') ...[
            const SizedBox(height: 8),
            Text('Try adjusting your filters.',
                style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.7))),
          ]
        ],
      ),
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Obx(() => Container(
      padding: const EdgeInsets.all(16),
      child: isLoadingMore.value
          ? Center(
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).primaryColor),
          ),
        ),
      )
          : const SizedBox.shrink(),
    ));
  }

  List<Map<String, dynamic>> _getFilteredCreditors() {
    final filtered = ctrl.allCreditors.where((d) {
      if (searchQ.value.isNotEmpty) {
        final name = d['name']?.toString().toLowerCase() ?? '';
        if (!name.contains(searchQ.value.toLowerCase())) {
          return false;
        }
      }
      if (filterType.value != 'All') {
        final type = d['type']?.toString().toLowerCase() ?? '';
        if (type != filterType.value.toLowerCase()) {
          return false;
        }
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      final nameA = a['name']?.toString().toLowerCase() ?? '';
      final nameB = b['name']?.toString().toLowerCase() ?? '';
      return nameA.compareTo(nameB);
    });

    return filtered;
  }

  ChoiceChip _chip(String label, BuildContext context) {
    final bool isSelected = filterType.value == label;
    final theme = Theme.of(context);
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
        ),
      ),
      selected: isSelected,
      selectedColor: theme.primaryColor,
      backgroundColor: theme.colorScheme.surface,
      onSelected: (_) => filterType.value = label,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? theme.primaryColor
              : theme.colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _creditorTile(Map<String, dynamic> d, BuildContext context) {
    final theme = Theme.of(context);
    final bal = (d['closingBalance'] as double?) ?? 0.0;
    final area = d['area'] ?? '-';
    final mobile = d['mobile'] ?? '-';
    final displayBal = NumberFormat.currency(symbol: '₹').format(bal);
    final balanceType = bal <= 0 ? 'Dr' : 'Cr';
    final balanceColor = bal <= 0 ? theme.primaryColor : theme.colorScheme.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4,horizontal: 4),
      child: Material(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        elevation: 2,
        shadowColor: theme.shadowColor.withOpacity(0.12),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {},
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 8,
                    decoration: BoxDecoration(
                      color: theme.primaryColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  d['name'] ?? '',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 16,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: theme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$displayBal $balanceType',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                      color: balanceColor),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _badge('Area:', area, context),
                          _badge('Mobile:', mobile, context),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, dynamic value, BuildContext context) {
    return Text.rich(
      TextSpan(
        style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).colorScheme.onSurface),
        children: [
          TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          TextSpan(text: value?.toString() ?? '-'),
        ],
      ),
      softWrap: true,
    );
  }

  Widget _totals(List<Map<String, dynamic>> filteredCreditors, BuildContext context) {
    final theme = Theme.of(context);
    final double total = filteredCreditors.fold(0.0, (sum, item) {
      return sum + (item['closingBalance'] as double? ?? 0.0);
    });

    final formattedTotal = NumberFormat.currency(symbol: '₹').format(total);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: theme.cardColor.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              // Add a border for a defined outline
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.5),
                width: 1.0,
              ),
              // Add a box shadow for elevation
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Creditors Amount:',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Flexible(
                  child: Text(
                    formattedTotal,
                    textAlign: TextAlign.right,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.error, // Reverted to the original color
                      fontSize: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}