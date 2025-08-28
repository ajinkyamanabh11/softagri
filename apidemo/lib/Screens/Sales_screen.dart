import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../Controller/Sales_controller.dart';
import '../Model/salesReport_Models/salesItemDetail_combined.dart';
import '../widgets/animated_Dots_LoadingText.dart';
import '../widgets/custom_app_bar.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> with SingleTickerProviderStateMixin {
  //late ScrollController _verticalScrollController;
  final SalesController sc = Get.find<SalesController>();
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController billCtrl = TextEditingController();
  DateTime selectedDate = DateTime.now();
  bool showCash = true;
  bool sortAscending = true;

  AnimationController? _animationController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;
  late Worker _everWorker;
  ScrollController? _verticalScrollController;
  @override
  void initState() {
    super.initState();

    _initAnimations();
    _verticalScrollController = ScrollController();
    sc.fetchSales();
    // This is the correct way to link the worker to the widget's lifecycle
    _everWorker = ever(sc.isLoading, (isLoading) {
      if (!isLoading && sc.error.value == null && mounted) {
        _animationController?.forward(from: 0);
      }
    });
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    billCtrl.dispose();
    _everWorker?.dispose(); // Use the safe-call operator
    _animationController?.dispose(); // Use the safe-call operator
    _verticalScrollController?.dispose(); // Use the safe-call operator
    super.dispose();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController!, curve: Curves.easeOut),
    );
    // Remove the `ever` listener from here
    // ever(sc.isLoading, (isLoading) {
    //   if (!isLoading && sc.error.value == null) {
    //     _animationController?.forward(from: 0);
    //   }
    // });
  }



  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
      _animationController?.forward(from: 0);
    }
  }

  List<SalesEntry> _getFilteredAndSortedData() {
    try {
      final allData = sc.sales.toList();

      // 1. First filter by selected date
      var dateFiltered = allData.where((entry) {
        final entryDate = entry.entryDate ?? entry.invoiceDate;
        return entryDate != null &&
            DateUtils.isSameDay(entryDate, selectedDate);
      }).toList();

      // 2. Then filter by search queries if they exist
      if (nameCtrl.text.isNotEmpty || billCtrl.text.isNotEmpty) {
        dateFiltered = dateFiltered.where((entry) {
          final nameMatch = entry.accountName.toLowerCase()
              .contains(nameCtrl.text.toLowerCase());
          final billMatch = entry.billNo.toLowerCase()
              .contains(billCtrl.text.toLowerCase());
          return nameMatch && billMatch;
        }).toList();
      }

      // 3. Filter by payment type
      final paymentFiltered = showCash
          ? dateFiltered.where((s) => s.paymentMode?.toLowerCase() == 'cash').toList()
          : dateFiltered.where((s) => s.paymentMode?.toLowerCase() == 'credit').toList();

      // 4. Sort the results
      paymentFiltered.sort((a, b) {
        final dateA = a.entryDate ?? a.invoiceDate ?? DateTime(0);
        final dateB = b.entryDate ?? b.invoiceDate ?? DateTime(0);
        return sortAscending
            ? dateA.compareTo(dateB)
            : b.compareTo(a);
      });

      return paymentFiltered;
    } catch (e, stack) {
      debugPrint('Error in filtering: $e\n$stack');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: CustomAppBar(
        title: const Text('Sales Report'),
        actions: [
          Obx(() => IconButton(
            icon: Icon(Icons.refresh,
              color: sc.isLoading.value
                  ? colorScheme.onSurface.withOpacity(0.5)
                  : colorScheme.primary,
            ),
            onPressed: sc.isLoading.value ? null : () {
              // Explicitly force a refresh when button is pressed
              sc.fetchSales(forceRefresh: true);
            },
          ),),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Obx(() {
          if (sc.isLoading.value) {
            return Center(child: DotsWaveLoadingText(color: colorScheme.onSurface));
          }
          if (sc.error.value != null) {
            return Center(
              child: Text(
                'Error: ${sc.error.value}',
                style: TextStyle(color: colorScheme.error),
              ),
            );
          }

          final filteredData = _getFilteredAndSortedData();
          final filteredByDate = sc.sales.where((entry) {
            final entryDate = entry.entryDate ?? entry.invoiceDate;
            return entryDate != null && DateUtils.isSameDay(entryDate, selectedDate);
          }).toList();

          final cashTotal = filteredByDate
              .where((s) => s.paymentMode?.toLowerCase() == 'cash')
              .fold(0.0, (sum, entry) => sum + entry.amount);

          final creditTotal = filteredByDate
              .where((s) => s.paymentMode?.toLowerCase() == 'credit')
              .fold(0.0, (sum, entry) => sum + entry.amount);

          final grandTotal = filteredByDate.fold(0.0, (sum, entry) => sum + entry.amount);

          return FadeTransition(
            opacity: _fadeAnimation!,
            child: SlideTransition(
              position: _slideAnimation!,
              child: Column(
                children: [
                  _buildFilterRow(context),
                  const SizedBox(height: 12),
                  _buildPaymentTypeTabs(context, cashTotal, creditTotal),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _buildSalesTable(filteredData),
                  ),
                  _buildGrandTotal(grandTotal),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFilterRow(BuildContext context) {
    return SingleChildScrollView(
      primary: false, // <-- Add this line

      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Name',
                prefixIcon: const Icon(Icons.search,),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (_) {
                setState(() {});
                _animationController?.forward(from: 0);
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: billCtrl,
              decoration: InputDecoration(
                labelText: 'Bill No',
                prefixIcon: const Icon(Icons.receipt),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (_) {
                setState(() {});
                _animationController?.forward(from: 0);
              },
            ),
          ),
          const SizedBox(width: 4),
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () => _selectDate(context),
                tooltip: 'Select Date',

              ),
              Text(DateFormat('dd-MMM-yy').format(selectedDate),style: TextStyle(fontSize: 11),),
            ],
          ),
          IconButton(
            icon: Icon(sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () {
              setState(() {
                sortAscending = !sortAscending;
              });
              _animationController?.forward(from: 0);
            },
          ),
          // Obx(() => Text(
          //   sc.cacheStatus.value,
          //   style: TextStyle(
          //     fontSize: 12,
          //     color: sc.isCacheValid.value ? Colors.green : Colors.orange,
          //   ),
          // )),
        ],
      ),
    );
  }

  Widget _buildPaymentTypeTabs(BuildContext context, double cashTotal, double creditTotal) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: _buildPaymentTypeButton(
            'Cash Sales',
            cashTotal,
            showCash,
            theme.primaryColor,
            theme.colorScheme.onPrimary,
                () {
              setState(() {
                showCash = true;
              });
              _animationController?.forward(from: 0);
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildPaymentTypeButton(
            'Credit Sales',
            creditTotal,
            !showCash,
            theme.colorScheme.secondary,
            theme.colorScheme.onSecondary,
                () {
              setState(() {
                showCash = false;
              });
              _animationController?.forward(from: 0);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentTypeButton(
      String label,
      double amount,
      bool isActive,
      Color backgroundColor,
      Color textColor,
      VoidCallback onPressed,
      ) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive ? backgroundColor : backgroundColor.withOpacity(0.2),
        foregroundColor: isActive ? textColor : textColor.withOpacity(0.7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesTable(List<SalesEntry> data) {
    try {
      if (data.isEmpty) {
        return const Center(
          child: Text(
            'No data found for the selected filters.',
            style: TextStyle(fontSize: 16),
          ),
        );
      }

      // Fixed column widths
      const double srNoWidth = 60;
      const double nameWidth = 180;
      const double billNoWidth = 100;
      const double dateWidth = 100;
      const double amountWidth = 120;
      const double detailsWidth = 80;
      const double rowHeight = 48;

      return Scrollbar(
        thumbVisibility: true,
        controller: _verticalScrollController,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          primary: false,
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            controller: _verticalScrollController,
            primary: false,
            child: DataTable(
              headingRowHeight: rowHeight,
              dataRowMinHeight: rowHeight,
              dataRowMaxHeight: rowHeight,
              columnSpacing: 0,
              horizontalMargin: 12,
              columns: [
                DataColumn(
                  label: SizedBox(
                    width: srNoWidth,
                    child: const Text(
                      'Sr.No',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                DataColumn(
                  label: SizedBox(
                    width: nameWidth,
                    child: const Text(
                      'Name',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                DataColumn(
                  label: SizedBox(
                    width: billNoWidth,
                    child: const Text(
                      'Bill No',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                DataColumn(
                  label: SizedBox(
                    width: dateWidth,
                    child: const Text(
                      'Date',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                DataColumn(
                  label: SizedBox(
                    width: amountWidth,
                    child: const Text(
                      'Amount',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  numeric: true,
                ),
                DataColumn(
                  label: SizedBox(
                    width: detailsWidth,
                    child: const Text(
                      'Details',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
              rows: List<DataRow>.generate(data.length, (index) {
                final entry = data[index];
                return DataRow(
                  cells: [
                    DataCell(
                      SizedBox(
                        width: srNoWidth,
                        height: rowHeight,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('${index + 1}'),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: nameWidth,
                        height: rowHeight,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            entry.accountName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: billNoWidth,
                        height: rowHeight,
                        child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(entry.billNo)),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: dateWidth,
                        height: rowHeight,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            entry.entryDate != null
                                ? DateFormat('dd-MMM-yy').format(entry.entryDate!)
                                : '-',
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: amountWidth,
                        height: rowHeight,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '₹${entry.amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: detailsWidth,
                        height: rowHeight,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: IconButton(
                            icon: const Icon(Icons.info_outline, size: 20),
                            onPressed: () => _showDetailsDialog(entry),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      );
    } catch (e, stack) {
      debugPrint('Error building table: $e\n$stack');
      return Center(
        child: Text(
          'Error displaying data: $e',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
  }


  Widget _buildGrandTotal(double grandTotal) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Grand Total (${DateFormat('dd-MMM').format(selectedDate)})'),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: grandTotal),
            duration: const Duration(milliseconds: 500),
            builder: (context, value, child) {
              return Text(
                '₹${value.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showDetailsDialog(SalesEntry entry) {
    Get.defaultDialog(
      title: 'Bill Details - ${entry.billNo}',
      content: SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Item')),
              DataColumn(label: Text('Batch')),
              DataColumn(label: Text('Qty')),
              DataColumn(label: Text('Rate')),
              DataColumn(label: Text('Amount')),
            ],
            rows: entry.items.map((item) {
              return DataRow(
                cells: [
                  DataCell(Text(item.itemName)),
                  DataCell(Text(item.batchNo)),
                  DataCell(Text(item.quantity.toStringAsFixed(2))),
                  DataCell(Text('₹${item.rate.toStringAsFixed(2)}')),
                  DataCell(Text('₹${item.amount.toStringAsFixed(2)}')),
                ],
              );
            }).toList(),
          ),
        ),
      ),
      confirm: TextButton(
        onPressed: () => Get.back(),
        child: const Text('Close'),
      ),
    );
  }
}