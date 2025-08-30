import 'dart:async';
import 'dart:ui'; // Import dart:ui for ImageFilter

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../Controller/customerLedgerController.dart';
import '../Model/AllAccounts_Model.dart';
import '../widgets/animated_Dots_LoadingText.dart';
import '../widgets/cache_status_indicator.dart';
import '../widgets/custom_app_bar.dart';

class CustomerLedgerScreen extends StatefulWidget {
  const CustomerLedgerScreen({super.key});

  @override
  State<CustomerLedgerScreen> createState() => _CustomerLedger_ScreenState();
}

class _CustomerLedger_ScreenState extends State<CustomerLedgerScreen> {
  final ctrl = Get.put(CustomerLedgerController());

  final searchCtrl = TextEditingController();
  final scrollCtrl = ScrollController();

  final searchFocus = FocusNode();

  // reactive helpers (no setState)
  final RxBool showFab = false.obs;
  final RxString searchQ = ''.obs;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();

    // toggle FAB
    scrollCtrl.addListener(() {
      showFab.value = scrollCtrl.offset > 300;
    });
  }

  @override
  void dispose() {
    scrollCtrl.dispose();
    searchCtrl.dispose();
    searchFocus.dispose();
    _debounce?.cancel();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get theme colors and text styles once
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color onPrimaryColor = Theme.of(context).colorScheme.onPrimary;
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;

    return WillPopScope(
      onWillPop: () async {
        ctrl.clearFilter();
        searchCtrl.clear();
        searchQ.value = '';
        return true;
      },
      child: Scaffold(
        appBar: CustomAppBar(
          title: Text(
            'Customer Ledger',
            style: Theme.of(context).appBarTheme.titleTextStyle,
          ),
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
        body: Obx(() {
          if (ctrl.isLoading.value) {
            return Center(child: DotsWaveLoadingText(color: onSurfaceColor));
          }

          if (ctrl.isProcessingData.value) {
            return Center(
              child: ProgressLoadingWidget(
                progress: ctrl.dataProcessingProgress.value,
                message: 'Processing customer data...',
                color: primaryColor,
              ),
            );
          }

          final names = ctrl.accounts
              .map((e) => e.accountName.toLowerCase())
              .toList();
          final txns = ctrl.filtered.cast<AllAccounts_Model>();
          final net = ctrl.drTotal.value - ctrl.crTotal.value;

          return RefreshIndicator(
            onRefresh: () async => ctrl.refreshData(),
            color: primaryColor, // Use theme primary color
            child: SingleChildScrollView(
              controller: scrollCtrl,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _autocomplete(names, context), // Pass context
                  const SizedBox(height: 12),
                  const CacheStatusIndicator(status: ''),
                  const SizedBox(height: 20),
                  Obx(
                        () => _messages(names, context),
                  ), // Pass context
                  if (txns.isNotEmpty) ...[
                    _paginatedTable(context, txns, ctrl.drTotal.value, ctrl.crTotal.value),
                    const SizedBox(height: 20),
                    _totals(net, context), // Totals now appears after the table
                  ],
                ],
              ),
            ),
          );
        }),
        floatingActionButton: Obx(
              () => showFab.value
              ? FloatingActionButton(
            heroTag: 'topBtn',
            backgroundColor: primaryColor, // Use theme primary color
            onPressed: () => scrollCtrl.animateTo(
              0,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
            ),
            child: Icon(
              Icons.arrow_upward,
              color: onPrimaryColor,
            ), // Use theme onPrimary color
          )
              : const SizedBox.shrink(),
        ),
      ),
    );
  }

  // ────────────────────── autocomplete & banner ──────────────────────

  Widget _autocomplete(List<String> names, BuildContext context) {
    // Retrieve theme colors inside the widget method
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final Color surfaceVariantColor = Theme.of(
      context,
    ).colorScheme.surfaceVariant;
    final Color cardColor = Theme.of(context).cardColor;

    return RawAutocomplete<String>(
      textEditingController: searchCtrl,
      focusNode: searchFocus,
      optionsBuilder: (v) => v.text.isEmpty
          ? const Iterable<String>.empty()
          : names.where((n) => n.contains(v.text.toLowerCase())),
      onSelected: (value) {
        ctrl.filterByName(value);
        searchQ.value = value;
        searchFocus.unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      fieldViewBuilder: (c, t, f, _) => TextField(
        controller: t,
        focusNode: f,
        decoration: InputDecoration(
          hintText: 'Search by Account Name',
          prefixIcon: Icon(
            Icons.search,
            color: primaryColor,
          ), // Use theme primary color
          suffixIcon: t.text.isEmpty
              ? null
              : IconButton(
            icon: Icon(
              Icons.clear,
              color: Theme.of(c).iconTheme.color,
            ), // Use theme icon color
            onPressed: () {
              t.clear();
              searchQ.value = '';
              ctrl.clearFilter();
              FocusScope.of(context).unfocus();
            },
          ),
          filled: true,
          // Use theme-aware fill color, fallback to surfaceVariant
          fillColor:
          Theme.of(c).inputDecorationTheme.fillColor ?? surfaceVariantColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          hintStyle: TextStyle(
            color: onSurfaceColor.withOpacity(0.6),
          ), // Hint text color
          labelStyle: TextStyle(color: onSurfaceColor), // Label text color
        ),
        style: TextStyle(color: onSurfaceColor), // Input text color
        onSubmitted: (v) {
          ctrl.filterByName(v.trim());
          searchQ.value = v.trim();
        },
        onChanged: (v) {
          _debounce?.cancel();
          _debounce = Timer(
            const Duration(milliseconds: 300),
                () => searchQ.value = v,
          );
        },
      ),
      optionsViewBuilder: (c, onSel, opts) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(8),
          color: cardColor, // Use theme card color for dropdown background
          child: SizedBox(
            width: MediaQuery.of(c).size.width - 24,
            child: ListView.builder(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              itemCount: opts.length,
              itemBuilder: (_, i) => ListTile(
                title: Text(
                  opts.elementAt(i),
                  style: TextStyle(color: onSurfaceColor),
                ), // Text color for options
                onTap: () => onSel(opts.elementAt(i)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _messages(List<String> names, BuildContext context) {
    final q = searchQ.value.trim();
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final Color errorColor = Theme.of(context).colorScheme.error;
    final Color warningColor = Theme.of(
      context,
    ).colorScheme.tertiary; // Use tertiary for warnings or an orange-like color

    if (q.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'Search an account name to see outstanding…',
          style: TextStyle(color: onSurfaceColor.withOpacity(0.7)),
        ),
      );
    }
    if (!names.contains(q.toLowerCase())) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'No customer or supplier named "$q" found.',
          style: TextStyle(color: errorColor),
        ), // Use theme error color
      );
    }
    if (ctrl.filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'No transactions found for "$q".',
          style: TextStyle(color: warningColor),
        ), // Use theme warning color
      );
    }
    return const SizedBox.shrink();
  }

  // ───────────────────────── table & totals ──────────────────────────

  Widget _paginatedTable(BuildContext context, List<AllAccounts_Model> txns, double drTotal, double crTotal) {
    final totalRows = txns.length + 1; // +1 for summary row
    final rowsPer = totalRows < 10 ? totalRows : 10;

    // Get theme colors for the table
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final Color surfaceVariantColor = Theme.of(
      context,
    ).colorScheme.surfaceVariant;

    return PaginatedDataTable(
      // Use theme-aware color for heading row
      headingRowColor: MaterialStateProperty.all(surfaceVariantColor),
      columnSpacing: 30,

      // if fewer than 10 rows, show them all; else fixed at 10
      rowsPerPage: rowsPer,
      availableRowsPerPage: totalRows < 10
          ? [rowsPer] // no dropdown when only one page size
          : const [10], // fixed 10 for larger datasets

      columns: [
        DataColumn(
          label: Text('Sr.', style: TextStyle(color: onSurfaceColor)),
        ),
        DataColumn(
          label: Text('Date', style: TextStyle(color: onSurfaceColor)),
        ),
        DataColumn(
          label: SizedBox(
            width: 120,
            child: Text('Type', style: TextStyle(color: onSurfaceColor)),
          ),
        ),
        DataColumn(
          label: Text('Invoice', style: TextStyle(color: onSurfaceColor)),
        ),
        DataColumn(
          label: Text('Debit', style: TextStyle(color: onSurfaceColor)),
        ),
        DataColumn(
          label: Text('Credit', style: TextStyle(color: onSurfaceColor)),
        ),
        DataColumn(
          label: Text('Balance', style: TextStyle(color: onSurfaceColor)),
        ),
      ],
      source: _LedgerSource(txns, context, drTotal, crTotal), // Pass context and totals to _LedgerSource
    );
  }

  Widget _totals(double net, BuildContext context) {
    // Get theme colors for the totals section
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final Color cardColor = Theme.of(context).cardColor;
    final Color errorColor = Theme.of(context).colorScheme.error;
    // Get outline color for the border
    final Color outlineColor = Theme.of(context).colorScheme.outline;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: outlineColor.withOpacity(0.5),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Dr Total', ctrl.drTotal.value, context), // Pass context
          const SizedBox(height: 8),
          _row('Cr Total', ctrl.crTotal.value, context), // Pass context
          Divider(
            color: Theme.of(context).colorScheme.outline,
          ), // Theme-aware divider color
          Row(
            children: [
              Text(
                'Net Outstanding: ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: onSurfaceColor,
                ),
              ), // Theme-aware text color
              Text(
                '₹${net.abs().toStringAsFixed(2)} ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: net < 0 ? errorColor : primaryColor,
                ),
              ), // Theme-aware colors
              Text(
                net < 0 ? 'Cr' : 'Dr',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: net < 0 ? errorColor : primaryColor,
                ),
              ), // Theme-aware colors
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, double amt, BuildContext context) {
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final Color primaryColor = Theme.of(context).primaryColor;
    return Row(
      children: [
        Expanded(
          child: Text('$label:', style: TextStyle(color: onSurfaceColor)),
        ), // Theme-aware text color
        Text(
          '₹${amt.toStringAsFixed(2)}',
          style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
        ), // Theme-aware color
      ],
    );
  }
}

// ───────────────── LedgerSource (sorted + Net Outstanding) ──────────────
class _LedgerSource extends DataTableSource {
  // Modified constructor to accept BuildContext and totals
  _LedgerSource(this.txns, this.context, this.drTotal, this.crTotal) {
    // Corrected sorting logic to handle potential null dates
    txns.sort((a, b) {
      final dateA = a.transactionDate;
      final dateB = b.transactionDate;

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return -1;
      if (dateB == null) return 1;

      return dateA.compareTo(dateB);
    });

    netOutstanding = txns.fold<double>(
      0,
          (p, t) => p + (t.isDr ? t.amount : -t.amount),
    );
  }

  final List<AllAccounts_Model> txns;
  final BuildContext context; // Store context to access theme
  final double drTotal;
  final double crTotal;
  late final double netOutstanding;
  double runningBal = 0;

  @override
  DataRow? getRow(int index) {
    // Get theme colors inside getRow
    final Color onSurfaceColor = Theme.of(context).colorScheme.onSurface;
    final Color surfaceColor = Theme.of(context).colorScheme.surface;
    final Color surfaceVariantColor = Theme.of(
      context,
    ).colorScheme.surfaceVariant;
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color errorColor = Theme.of(context).colorScheme.error;
    final Color cardColor = Theme.of(context).cardColor;
    final Color shadowColor = Theme.of(context).shadowColor;

    // ─── summary row (no Sr. number) ───────────────────────────
    if (index == txns.length) {
      final isCr = netOutstanding < 0;
      return DataRow.byIndex(
        index: index,
        // Use theme-aware color for summary row
        color: MaterialStateProperty.all(surfaceVariantColor),
        cells: [
          const DataCell(Text('')), // ← empty Sr.
          const DataCell(Text('')), // Date blank
          DataCell(
            Text(
              'Closing Balance',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: onSurfaceColor,
              ),
            ),
          ), // Theme-aware text color
          const DataCell(Text('-')), // Invoice
          DataCell(
            Text(
              drTotal.toStringAsFixed(2),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: onSurfaceColor,
              ),
            ),
          ), // Total Debit
          DataCell(
            Text(
              crTotal.toStringAsFixed(2),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: onSurfaceColor,
              ),
            ),
          ), // Total Credit
          DataCell(
            Text(
              '₹${netOutstanding.abs().toStringAsFixed(2)} ${isCr ? 'Cr' : 'Dr'}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCr ? errorColor : primaryColor,
              ), // Theme-aware colors
            ),
          ),
        ],
      );
    }

    // ─── normal row ────────────────────────────────────────────
    final t = txns[index];
    if (index == 0) runningBal = 0;
    runningBal += t.isDr ? t.amount : -t.amount;

    // Corrected `transactionDate` usage with null-check
    final formattedDate = t.transactionDate != null
        ? DateFormat('dd/MM/yy').format(t.transactionDate!)
        : '-';

    return DataRow.byIndex(
      index: index,
      // Use theme-aware colors for alternating row backgrounds
      color: MaterialStateProperty.all(
        index.isEven ? surfaceColor : surfaceVariantColor,
      ),
      cells: [
        DataCell(
          Text('${index + 1}', style: TextStyle(color: onSurfaceColor)),
        ), // Sr. #
        DataCell(Text(formattedDate, style: TextStyle(color: onSurfaceColor))),
        DataCell(
          SizedBox(
            width: 120,
            child: Text(
              t.narrations,
              overflow: TextOverflow.ellipsis,
              style: t.narrations.toLowerCase() == 'opening balance'
                  ? TextStyle(
                fontWeight: FontWeight.bold,
                color: onSurfaceColor,
              ) // Theme-aware color
                  : TextStyle(color: onSurfaceColor), // Theme-aware color
            ),
          ),
          // 👇 show floating snackbar on tap
          onTap: () => Get.snackbar(
            '',
            '',
            titleText: Text(
              'Narration',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: onSurfaceColor,
              ),
            ), // Theme-aware color
            messageText: Text(
              t.narrations,
              style: TextStyle(color: onSurfaceColor),
            ), // Theme-aware color
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: cardColor, // Use theme card color
            borderRadius: 12,
            margin: const EdgeInsets.all(16),
            snackStyle: SnackStyle.FLOATING,
            duration: const Duration(seconds: 4),
            animationDuration: const Duration(milliseconds: 300),
            boxShadows: [
              BoxShadow(
                color: shadowColor.withOpacity(0.26),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ), // Theme-aware shadow
            ],
          ),
        ),

        DataCell(
          Center(
            child: Text(
              t.invoiceNo?.toString() ?? '-',
              style: TextStyle(color: onSurfaceColor),
            ),
          ),
        ), // Theme-aware color
        DataCell(
          Text(
            t.isDr ? t.amount.toStringAsFixed(2) : '-',
            style: TextStyle(color: onSurfaceColor),
          ),
        ), // Theme-aware color
        DataCell(
          Text(
            !t.isDr ? t.amount.toStringAsFixed(2) : '-',
            style: TextStyle(color: onSurfaceColor),
          ),
        ), // Theme-aware color
        DataCell(
          Text(
            '₹${runningBal.toStringAsFixed(2)}',
            style: TextStyle(color: runningBal < 0 ? errorColor : primaryColor),
          ),
        ), // Theme-aware colors
      ],
    );
  }

  @override
  int get rowCount => txns.length + 1; // + summary row
  @override
  bool get isRowCountApproximate => false;
  @override
  int get selectedRowCount => 0;
}