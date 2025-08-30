// lib/screens/profit_screen.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'dart:math';

import '../Controller/profit_report_controller.dart';
import '../widgets/animated_Dots_LoadingText.dart';
import '../widgets/cache_status_indicator.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/rounded_search_field.dart';

class ProfitReportScreen extends StatefulWidget {
  const ProfitReportScreen({super.key});

  @override
  State<ProfitReportScreen> createState() => _ProfitReportScreenState();
}

class _ProfitReportScreenState extends State<ProfitReportScreen> {
  final prc = Get.put(ProfitReportController());

  DateTime fromDate = DateUtils.dateOnly(DateTime.now());
  DateTime toDate = DateUtils.dateOnly(DateTime.now());
  final TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fromDate = DateUtils.dateOnly(DateTime.now());
    toDate = DateUtils.dateOnly(DateTime.now());
    prc.loadProfitReport(startDate: fromDate, endDate: toDate);
  }

  @override
  void dispose() {
    searchController.dispose();
    Get.delete<ProfitReportController>();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      appBar: const CustomAppBar(title: Text('Profit Report')),
      body: Column(
        children: [
          // Fixed header section with app bar only
          // Content section (scrollable from date range to pie chart)
          Expanded(
            child: Obx(() {
              if (prc.isLoading.value) {
                return Center(child: DotsWaveLoadingText(
                  color: onSurfaceColor,
                ));
              }

              final filteredRows = prc.filteredRows;

              if (filteredRows.isEmpty) {
                final range = fromDate == toDate
                    ? DateFormat.yMMMd().format(fromDate)
                    : '${DateFormat.yMMMd().format(fromDate)} to ${DateFormat.yMMMd().format(toDate)}';
                return Column(
                  children: [
                    // Date range and search (now part of scrollable content)
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: _buildDateRangeRow(),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _buildSearchField(),
                    ),
                    const CacheStatusIndicator(status: ''),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Center(
                        child: Text('No data available for $range',
                            style: TextStyle(color: onSurfaceColor)),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  // Scrollable content from date range to pie chart
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        await prc.loadProfitReport(startDate: fromDate, endDate: toDate);
                      },
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            // Date range and search (now part of scrollable content)
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: _buildDateRangeRow(),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: _buildSearchField(),
                            ),
                            const CacheStatusIndicator(status: ''),
                            const SizedBox(height: 10),

                            // Table with its own scrolling
                            _buildTableWithTotals(filteredRows, context),
                            const SizedBox(height: 20),

                            // Pie chart
                            _buildProfitPieChart(filteredRows, context),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Fixed totals card at the bottom
                  Obx(() => prc.batchProfits.isNotEmpty ? _buildTotalsCard(context) : const SizedBox.shrink()),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  // ... (rest of your methods remain unchanged)
  Widget _buildDateRangeRow() {
    return Row(
      children: [
        _dateButton(
          label: 'From',
          date: fromDate,
          onPick: (d) {
            setState(() => fromDate = d);
            prc.loadProfitReport(startDate: d, endDate: toDate);
          },
        ),
        const SizedBox(width: 8),
        _dateButton(
          label: 'To',
          date: toDate,
          onPick: (d) {
            setState(() => toDate = d);
            prc.loadProfitReport(startDate: fromDate, endDate: d);
          },
        ),
      ],
    );
  }

  Widget _dateButton({required String label, required DateTime date, required Function(DateTime) onPick}) {
    return Expanded(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.date_range),
        label: Text('$label: ${DateFormat.yMMMd().format(date)}'),
        onPressed: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: date,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            builder: (context, child) {
              return Theme(
                data: Theme.of(context).copyWith(
                  colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: Theme.of(context).primaryColor,
                    onPrimary: Theme.of(context).colorScheme.onPrimary,
                    surface: Theme.of(context).colorScheme.surface,
                    onSurface: Theme.of(context).colorScheme.onSurface,
                  ),
                  textButtonTheme: TextButtonThemeData(
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                child: child!,
              );
            },
          );
          if (picked != null) onPick(picked);
        },
      ),
    );
  }

  Widget _buildSearchField() {
    return RoundedSearchField(
      controller: searchController,
      text: "Search By Item Name or Bill no..",
      onClear: () {
        searchController.clear();
        prc.searchQuery.value = '';
      },
      onChanged: (value) {
        prc.searchQuery.value = value;
      }, hintText: '',
    );
  }

  Widget _buildTableWithTotals(List<Map<String, dynamic>> rows, BuildContext context) {
    final sortedRows = List<Map<String, dynamic>>.from(rows)
      ..sort((a, b) => a['billno'].toString().compareTo(b['billno'].toString()));

    final rowsPer = sortedRows.isEmpty ? 1 : (sortedRows.length < 10 ? sortedRows.length : 10);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: PaginatedDataTable(
        key: ValueKey(sortedRows.hashCode),
        headingRowColor: MaterialStateProperty.all(Theme.of(context).colorScheme.surfaceVariant),
        columnSpacing: 24,
        rowsPerPage: rowsPer,
        availableRowsPerPage: sortedRows.length < 10 && sortedRows.isNotEmpty ? [rowsPer] : [10, 25, 50, 100, sortedRows.length],
        showFirstLastButtons: true,
        columns: [
          DataColumn(label: Text('Sr.', style: Theme.of(context).textTheme.titleSmall)),
          DataColumn(label: Text('Item', style: Theme.of(context).textTheme.titleSmall)),
          DataColumn(label: Text('Bill No', style: Theme.of(context).textTheme.titleSmall)),
          DataColumn(label: Text('Batch', style: Theme.of(context).textTheme.titleSmall)),
          DataColumn(label: Text('Date', style: Theme.of(context).textTheme.titleSmall)),
          DataColumn(label: Text('Qty', style: Theme.of(context).textTheme.titleSmall)),
          DataColumn(label: Text('Packing', style: Theme.of(context).textTheme.titleSmall)),
          DataColumn(label: Text('Sales Amt.', style: Theme.of(context).textTheme.titleSmall)),
          DataColumn(label: Text('Purchase Amt.', style: Theme.of(context).textTheme.titleSmall)),
          DataColumn(label: Text('Profit', style: Theme.of(context).textTheme.titleSmall)),
        ],
        source: _ProfitSource(sortedRows, context),
      ),
    );
  }

  Widget _buildProfitPieChart(List<Map<String, dynamic>> rows, BuildContext context) {
    final Map<String, double> itemProfits = {};
    double totalPositiveProfit = 0;

    for (var row in rows) {
      final itemName = (row['itemName'] ?? 'Unknown Item').toString();
      final profit = (row['profit'] ?? 0.0) as double;
      if (profit > 0) {
        itemProfits.update(itemName, (value) => value + profit,
            ifAbsent: () => profit);
        totalPositiveProfit += profit;
      }
    }

    if (totalPositiveProfit <= 0) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'No positive profit data to display pie chart.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
      );
    }

    final sortedItemProfits = itemProfits.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    List<PieChartSectionData> sections = [];
    double otherProfit = 0;
    final int maxSlices = 5;
    final List<Color> pieColors = [
      Colors.green.shade600,
      Colors.blue.shade600,
      Colors.orange.shade600,
      Colors.purple.shade600,
      Colors.red.shade600,
      Colors.teal.shade600,
      Colors.indigo.shade600,
      Colors.brown.shade600,
    ];
    final Random random = Random();

    for (int i = 0; i < sortedItemProfits.length; i++) {
      final entry = sortedItemProfits[i];
      if (i < maxSlices) {
        final color = pieColors[i % pieColors.length];
        sections.add(
          PieChartSectionData(
            color: color,
            value: entry.value,
            title: '${(entry.value / totalPositiveProfit * 100).toStringAsFixed(1)}%',
            radius: 80,
            titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            badgeWidget: sortedItemProfits.length == 1
                ? null
                : _buildBadge(entry.key, color, context),
            badgePositionPercentageOffset: 1.05,
          ),
        );
      } else {
        otherProfit += entry.value;
      }
    }

    if (otherProfit > 0) {
      sections.add(
        PieChartSectionData(
          color: Colors.grey.shade400,
          value: otherProfit,
          title: '${(otherProfit / totalPositiveProfit * 100).toStringAsFixed(1)}%',
          radius: 80,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          badgeWidget: _buildBadge('Other', Colors.grey.shade400, context),
          badgePositionPercentageOffset: 1.05,
        ),
      );
    }

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Profit Distribution by Item',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.headlineSmall?.color,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(touchCallback: (FlTouchEvent event, pieTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          pieTouchResponse == null ||
                          pieTouchResponse.touchedSection == null) {
                      } else {
                      }
                    });
                  }),
                  borderData: FlBorderData(show: false),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                  sections: sections,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8.0,
              runSpacing: 4.0,
              children: sections.map((section) {
                final String title = section?.badgeWidget is Column && (section.badgeWidget as Column).children.first is Text
                    ? ((section.badgeWidget as Column).children.first as Text).data ?? ''
                    : (section.title ?? '').replaceAll('%', '');
                return _buildLegendItem(title.replaceAll('%', ''), section.color!, context);
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color, BuildContext context) {
    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildLegendItem(String text, Color color, BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildTotalsCard(BuildContext context) {
    return Container(
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _totalTile('Total Sales', prc.totalSales.value, Colors.blue),
          _totalTile('Total Purchase', prc.totalPurchase.value, Colors.orange),
          _totalTile('Total Profit', prc.totalProfit.value, Colors.green),
        ],
      ),
    );
  }

  Widget _totalTile(String label, double amount, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        Text('₹${amount.toStringAsFixed(2)}',
            style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _ProfitSource extends DataTableSource {
  _ProfitSource(this.data, this.context);

  final List<Map<String, dynamic>> data;
  final BuildContext context;

  @override
  DataRow? getRow(int index) {
    if (index >= data.length) return null;
    final row = data[index];

    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final Color surfaceColor = Theme.of(context).colorScheme.surface;
    final Color surfaceVariantColor = Theme.of(context).colorScheme.surfaceVariant;

    return DataRow.byIndex(
      index: index,
      color: MaterialStateProperty.all(index.isEven ? surfaceColor : surfaceVariantColor),
      cells: [
        DataCell(Text('${index + 1}', style: TextStyle(color: onSurfaceColor))),
        DataCell(Text(row['itemName'] ?? '', style: TextStyle(color: onSurfaceColor))),
        DataCell(Text('${row['billno'] ?? ''}', style: TextStyle(color: onSurfaceColor))),
        DataCell(Text(row['batchno'] ?? '', style: TextStyle(color: onSurfaceColor))),
        DataCell(Text(row['date'] ?? '', style: TextStyle(color: onSurfaceColor))),
        DataCell(Text('${row['qty'] ?? ''}', style: TextStyle(color: onSurfaceColor))),
        DataCell(Text(row['packing'] ?? '', style: TextStyle(color: onSurfaceColor))),
        DataCell(Text('₹${(row['sales'] ?? 0).toStringAsFixed(2)}', style: TextStyle(color: onSurfaceColor))),
        DataCell(Text('₹${(row['purchase'] ?? 0).toStringAsFixed(2)}', style: TextStyle(color: onSurfaceColor))),
        DataCell(
          Text(
            '₹${(row['profit'] ?? 0).toStringAsFixed(2)}',
            style: TextStyle(
              color: (row['profit'] ?? 0) < 0 ? Colors.red : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  @override
  int get rowCount => data.length;

  @override
  bool get isRowCountApproximate => false;

  @override
  int get selectedRowCount => 0;
}