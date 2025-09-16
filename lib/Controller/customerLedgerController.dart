import 'dart:async';
import 'dart:developer';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../Model/AllAccounts_Model.dart';
import '../Model/accountMaster_models.dart';
import '../Model/customer_info_model.dart';
import '../Services/http_data_service.dart';
import 'package:printing/printing.dart';
import '../services/pdf_service.dart';
import 'dart:io';
import 'package:get_storage/get_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class CustomerLedgerController extends GetxController {
  final HttpDataServices _dataService = Get.find<HttpDataServices>();

  // Reactive stores
  final accounts = <AccountMaster_Model>[].obs;
  final transactions = <AllAccounts_Model>[].obs;
  final customerInfo = <CustomerInfoModel>[].obs;
  final supplierInfo = <CustomerInfoModel>[].obs;
  final debtors = <Map<String, dynamic>>[].obs;
  final creditors = <Map<String, dynamic>>[].obs;
  final filtered = <AllAccounts_Model>[].obs; // For filtered results

  // Filtering and totals
  final searchQuery = ''.obs;
  final RxDouble crTotal = 0.0.obs;
  final RxDouble drTotal = 0.0.obs;

  // Status flags
  final isLoading = false.obs;
  final error = RxnString();
  final isProcessingData = false.obs;
  final dataProcessingProgress = 0.0.obs;
  final lastRefreshTime = Rxn<DateTime>();

  // Pagination support
  final currentPage = 0.obs;
  final pageSize = 50;
  final hasMoreDebtors = true.obs;
  final hasMoreCreditors = true.obs;
  final isGeneratingPdf = false.obs;

  // Cached processed data
  final List<Map<String, dynamic>> _allDebtors = [];
  final List<Map<String, dynamic>> _allCreditors = [];
  final List<AllAccounts_Model> _allFiltered = []; // Corrected to use AllAccounts_Model

  // Getter to expose the full list for accurate total calculation
  List<Map<String, dynamic>> get allDebtors => _allDebtors;
  List<Map<String, dynamic>> get allCreditors => _allCreditors;


  @override
  void onInit() {
    super.onInit();
    loadData();

    // React to search query changes
    debounce(searchQuery, (_) => filterByName(), time: Duration(milliseconds: 500));
  }

  // Calculate totals whenever data changes
  void _calculateTotals() {
    // Corrected to use the reactive filtered list
    final drSum = filtered.fold<double>(0.0, (sum, item) => sum + (item.isDr ? item.amount : 0.0));
    final crSum = filtered.fold<double>(0.0, (sum, item) => sum + (!item.isDr ? item.amount : 0.0));

    drTotal.value = drSum;
    crTotal.value = crSum;
  }

  // Filter by name
  void filterByName([String? query]) {
    if (query != null) {
      searchQuery.value = query;
    }

    if (searchQuery.value.isEmpty) {
      clearFilter();
      return;
    }

    final queryText = searchQuery.value.toLowerCase();

    // Create a map of account numbers to account names for quick lookup
    final accountNameMap = {
      for (var account in accounts)
        account.accountNumber.toString(): account.accountName.toLowerCase()
    };

    // Filter transactions where either account name or code matches
    filtered.value = transactions.where((transaction) {
      final accountCode = transaction.accountCode.toString();
      final accountName = accountNameMap[accountCode] ?? '';

      return accountName.contains(queryText) || accountCode.contains(queryText);
    }).toList();

    _calculateTotals();
  }

  // Clear filter
  void clearFilter() {
    searchQuery.value = '';
    filtered.clear();
    _calculateTotals();
  }

  Future<void> loadData({bool forceRefresh = false}) async {
    try {
      isLoading(true);
      error.value = null;

      if (forceRefresh) {
        accounts.clear();
        transactions.clear();
        customerInfo.clear();
        supplierInfo.clear();
      }

      // Load data in parallel with progress updates
      await Future.wait([
        _loadWithProgress(_loadAccountMaster(forceRefresh: forceRefresh), 0.2),
        _loadWithProgress(_loadAllAccounts(forceRefresh: forceRefresh), 0.4),
        _loadWithProgress(_loadCustomerInfo(forceRefresh: forceRefresh), 0.6),
        _loadWithProgress(_loadSupplierInfo(forceRefresh: forceRefresh), 0.8),
      ]);

      await _processDataInIsolate();
      lastRefreshTime.value = DateTime.now();
      _calculateTotals();
    } catch (e, st) {
      error.value = e.toString();
      log('Error loading data: $e\n$st');
    } finally {
      isLoading(false);
    }
  }

  Future<void> _loadWithProgress(Future<void> task, double progressWeight) async {
    final startProgress = dataProcessingProgress.value;
    await task;
    dataProcessingProgress.value = startProgress + progressWeight;
  }

  Future<void> refreshData() async {
    try {
      isLoading(true);
      isProcessingData(true);
      error.value = null;

      await _dataService.clearCache();
      accounts.clear();
      transactions.clear();
      customerInfo.clear();
      supplierInfo.clear();
      _allDebtors.clear();
      _allCreditors.clear();
      debtors.clear();
      creditors.clear();
      filtered.clear();

      await Future.wait([
        _loadAccountMaster(forceRefresh: true),
        _loadAllAccounts(forceRefresh: true),
        _loadCustomerInfo(forceRefresh: true),
        _loadSupplierInfo(forceRefresh: true),
      ]);

      await _processDataInIsolate();
      lastRefreshTime.value = DateTime.now();
      _calculateTotals();

      Get.snackbar(
          'Success',
          'Data refreshed successfully',
          snackPosition: SnackPosition.BOTTOM,
          duration: Duration(seconds: 2),colorText: Colors.black
      );
    } catch (e, st) {
      error.value = 'Refresh failed: ${e.toString()}';
      log('Error during refresh: $e\n$st');
      Get.snackbar(
          'Error',
          'Failed to refresh data',
          snackPosition: SnackPosition.BOTTOM,
          duration: Duration(seconds: 2),colorText: Colors.black
      );
    } finally {
      isLoading(false);
      isProcessingData(false);
    }
  }

  Future<void> _loadAccountMaster({bool forceRefresh = false}) async {
    accounts.value = await _dataService.fetchAccountMaster(forceRefresh: forceRefresh);
  }

  Future<void> _loadAllAccounts({bool forceRefresh = false}) async {
    transactions.value = await _dataService.fetchAllAccounts(forceRefresh: forceRefresh);
  }

  Future<void> _loadCustomerInfo({bool forceRefresh = false}) async {
    try {
      customerInfo.value = await _dataService.fetchCustomerInfo(forceRefresh: forceRefresh);
    } catch (e) {
      log('Error loading customer info: $e');
      if (customerInfo.isNotEmpty) {
        log('Using existing customer info data');
      } else {
        rethrow;
      }
    }
  }

  Future<void> _loadSupplierInfo({bool forceRefresh = false}) async {
    try {
      supplierInfo.value = await _dataService.fetchSupplierInfo(forceRefresh: forceRefresh);
    } catch (e) {
      log('Error loading supplier info: $e');
      if (supplierInfo.isNotEmpty) {
        log('Using existing supplier info data');
      } else {
        rethrow;
      }
    }
  }

  Future<void> _processDataInIsolate() async {
    isProcessingData(true);
    dataProcessingProgress.value = 0.9;

    try {
      final processed = await compute(_processDataIsolate, {
        'accounts': accounts.map((e) => e.toJson()).toList(),
        'transactions': transactions.map((e) => e.toJson()).toList(),
        'customerInfo': customerInfo.map((e) => e.toJson()).toList(),
        'supplierInfo': supplierInfo.map((e) => e.toJson()).toList(),
      });

      _allDebtors.clear();
      _allCreditors.clear();
      _allDebtors.addAll(processed['debtors'] as List<Map<String, dynamic>>);
      _allCreditors.addAll(processed['creditors'] as List<Map<String, dynamic>>);

      // Now that we have the full list of transactions, we can run the filter
      filterByName();

      _loadInitialPages();
      dataProcessingProgress.value = 1.0;
    } catch (e, st) {
      error.value = 'Error processing data: $e';
      log('Error processing data: $e\n$st');
      rethrow;
    } finally {
      isProcessingData(false);
    }
  }

  static Map<String, dynamic> _processDataIsolate(Map<String, dynamic> data) {
    final accounts = (data['accounts'] as List)
        .map((e) => AccountMaster_Model.fromJson(e)).toList();
    final transactions = (data['transactions'] as List)
        .map((e) => AllAccounts_Model.fromJson(e)).toList();
    final customerInfo = (data['customerInfo'] as List)
        .map((e) => CustomerInfoModel.fromJson(e)).toList();
    final supplierInfo = (data['supplierInfo'] as List)
        .map((e) => CustomerInfoModel.fromJson(e)).toList();

    final debtors = <Map<String, dynamic>>[];
    final creditors = <Map<String, dynamic>>[];

    // Create lookup maps
    final custMap = {for (final r in customerInfo) r.accountNumber.toString(): r};
    final supMap = {for (final r in supplierInfo) r.accountNumber.toString(): r};

    // Create transaction map for faster lookup
    final accountTransactionMap = <String, List<AllAccounts_Model>>{};
    for (final t in transactions) {
      final accountCode = t.accountCode.toString();
      if (accountCode.isNotEmpty) {
        accountTransactionMap.putIfAbsent(accountCode, () => []).add(t);
      }
    }

    // Process accounts in batches
    const batchSize = 500;
    for (int i = 0; i < accounts.length; i += batchSize) {
      final end = i + batchSize > accounts.length ? accounts.length : i + batchSize;
      for (int j = i; j < end; j++) {
        final acc = accounts[j];
        final isCust = acc.type.toLowerCase() == 'customer';
        final isSupp = acc.type.toLowerCase() == 'supplier';
        if (!isCust && !isSupp) continue;

        final accountCode = acc.accountNumber.toString();
        final accountTransactions = accountTransactionMap[accountCode] ?? [];
        if (accountTransactions.isEmpty) continue;

        final bal = accountTransactions.fold<double>(
            0, (p, t) => p + (t.isDr ? t.amount : -t.amount));
        if (bal == 0) continue;

        final info = isCust ? custMap[accountCode] : supMap[accountCode];

        final row = {
          'accountNumber': accountCode,
          'name': acc.accountName,
          'type': acc.type,
          'closingBalance': bal.abs(),
          'area': info?.area ?? '-',
          'mobile': info?.mobile ?? '-',
          'drCr': bal > 0 ? 'Dr' : 'Cr',
        };

        if (bal > 0) {
          debtors.add(row);
        } else {
          creditors.add(row);
        }
      }
    }

    return {
      'debtors': debtors,
      'creditors': creditors,
    };
  }

  void _loadInitialPages() {
    currentPage.value = 0;
    hasMoreDebtors.value = _allDebtors.length > pageSize;
    hasMoreCreditors.value = _allCreditors.length > pageSize;

    debtors.value = _allDebtors.take(pageSize).toList();
    creditors.value = _allCreditors.take(pageSize).toList();
  }

  void loadMoreDebtors() {
    if (!hasMoreDebtors.value) return;
    final nextPage = currentPage.value + 1;
    final startIndex = nextPage * pageSize;
    if (startIndex >= _allDebtors.length) {
      hasMoreDebtors.value = false;
      return;
    }
    final moreItems = _allDebtors.skip(startIndex).take(pageSize).toList();
    debtors.addAll(moreItems);
    currentPage.value = nextPage;
    hasMoreDebtors.value = (startIndex + pageSize) < _allDebtors.length;
  }
  // Add these methods to your CustomerLedgerController class

  Future<void> generateAndSharePdf(String customerName) async {
    try {
      isGeneratingPdf(true); // Set PDF generation flag
      isLoading(true);

      // Get the current filtered transactions
      final transactions = filtered.toList();
      final netOutstanding = drTotal.value - crTotal.value;

      // Generate PDF
      final pdfFile = await _generateCustomerLedgerPdf(
        customerName: customerName,
        transactions: transactions,
        drTotal: drTotal.value,
        crTotal: crTotal.value,
        netOutstanding: netOutstanding,
      );

      // Share PDF
      await _sharePdf(pdfFile, customerName);

      Get.snackbar(
          'Success',
          'PDF generated and shared successfully',
          snackPosition: SnackPosition.BOTTOM,
          duration: Duration(seconds: 2),
          colorText: Colors.black
      );
    } catch (e, st) {
      error.value = 'Failed to generate PDF: ${e.toString()}';
      log('Error generating PDF: $e\n$st');
      Get.snackbar(
          'Error',
          'Failed to generate PDF: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM,
          duration: Duration(seconds: 4),
          colorText: Colors.black
      );
    } finally {
      isGeneratingPdf(false); // Reset PDF generation flag
      isLoading(false);
    }
  }

  String getCurrentCustomerName() {
    if (searchQuery.value.isEmpty) return 'All Customers';
    return searchQuery.value;
  }

  Future<File> _generateCustomerLedgerPdf({
    required String customerName,
    required List<AllAccounts_Model> transactions,
    required double drTotal,
    required double crTotal,
    required double netOutstanding,
  }) async {
    final pdf = pw.Document();
    final _box = GetStorage();
    final companyName = _box.read('companyname') ?? 'Company Name';
    // Calculate running balance
    double runningBalance = 0;
    final transactionsWithBalance = transactions.map((transaction) {
      runningBalance += transaction.isDr ? transaction.amount : -transaction.amount;
      return {
        'transaction': transaction,
        'balance': runningBalance
      };
    }).toList();

    // Header with company info
    final header = pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(companyName,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text('Customer Ledger Report',
                style: pw.TextStyle(fontSize: 14)),
          ],
        ),
        pw.Text(DateTime.now().toString().split(' ')[0],
            style: const pw.TextStyle(fontSize: 10)),
      ],
    );

    // Customer Info
    final customerInfo = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Customer: $customerName',
            style:  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Text('Generated on: ${DateTime.now()}', style: const pw.TextStyle(fontSize: 10)),
      ],
    );

    // Split transactions into chunks for pagination
    const transactionsPerPage = 30; // Adjust based on your needs
    final transactionChunks = [];
    for (var i = 0; i < transactionsWithBalance.length; i += transactionsPerPage) {
      final end = (i + transactionsPerPage < transactionsWithBalance.length)
          ? i + transactionsPerPage
          : transactionsWithBalance.length;
      transactionChunks.add(transactionsWithBalance.sublist(i, end));
    }

    for (var pageIndex = 0; pageIndex < transactionChunks.length; pageIndex++) {
      final chunk = transactionChunks[pageIndex] as List<dynamic>;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header on every page
                header,
                pw.SizedBox(height: 10),

                // Customer info only on first page
                if (pageIndex == 0) customerInfo,
                if (pageIndex == 0) pw.SizedBox(height: 15),

                // Transactions table
                _buildTransactionsTable(chunk.cast<Map<String, dynamic>>()),

                // Page info
                pw.SizedBox(height: 10),
                pw.Text(
                  'Page ${pageIndex + 1} of ${transactionChunks.length}',
                  style: const pw.TextStyle(fontSize: 10),
                ),

                // Totals only on last page
                if (pageIndex == transactionChunks.length - 1) pw.SizedBox(height: 15),
                if (pageIndex == transactionChunks.length - 1)
                  _buildTotalsSection(drTotal, crTotal, netOutstanding),
              ],
            );
          },
        ),
      );
    }

    // If no transactions, still create a PDF with header and totals
    if (transactions.isEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                header,
                pw.SizedBox(height: 10),
                customerInfo,
                pw.SizedBox(height: 20),
                pw.Center(
                  child: pw.Text('No transactions found',
                      style: const pw.TextStyle(fontSize: 14)),
                ),
                pw.SizedBox(height: 20),
                _buildTotalsSection(drTotal, crTotal, netOutstanding),
              ],
            );
          },
        ),
      );
    }

    // Get directory and save file
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/${customerName.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_Ledger.pdf');
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  pw.Widget _buildTransactionsTable(List<Map<String, dynamic>> transactionsWithBalance) {
    return pw.Table(
      border: pw.TableBorder.all(),
      columnWidths: {
        0: const pw.FlexColumnWidth(1.2), // Date
        1: const pw.FlexColumnWidth(2.0), // Narration
        2: const pw.FlexColumnWidth(1.0), // Invoice
        3: const pw.FlexColumnWidth(1.0), // Debit
        4: const pw.FlexColumnWidth(1.0), // Credit
        5: const pw.FlexColumnWidth(1.2), // Balance
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: [
        // Table Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text('Date',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text('Narration',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text('Invoice',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text('Debit',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text('Credit',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text('Balance',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
            ),
          ],
        ),

        // Table Rows
        ...transactionsWithBalance.map((item) {
          final transaction = item['transaction'] as AllAccounts_Model;
          final balance = item['balance'] as double;

          return pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(transaction.formattedDate,
                    style: const pw.TextStyle(fontSize: 8)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  transaction.narrations.length > 30
                      ? '${transaction.narrations.substring(0, 27)}...'
                      : transaction.narrations,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(transaction.invoiceNo ?? '-',
                    style: const pw.TextStyle(fontSize: 8)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  transaction.isDr ? transaction.amount.toStringAsFixed(2) : '-',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  !transaction.isDr ? transaction.amount.toStringAsFixed(2) : '-',
                  style: const pw.TextStyle(fontSize: 8),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(
                  '${balance.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: balance < 0 ? PdfColors.red : PdfColors.black,
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ],
    );
  }

  pw.Widget _buildTotalsSection(double drTotal, double crTotal, double netOutstanding) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Debit Total:', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Rs. ${drTotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Credit Total:', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Rs. ${crTotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Net Outstanding:',
                  style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text('Rs. ${netOutstanding.abs().toStringAsFixed(2)} ${netOutstanding < 0 ? 'Cr' : 'Dr'}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: netOutstanding < 0 ? PdfColors.red : PdfColors.green,
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sharePdf(File file, String customerName) async {
    // Check and request storage permission if needed
    if (Platform.isAndroid || Platform.isIOS) {
      final status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request();
      }
    }

    // Share the file
    await Share.shareXFiles([XFile(file.path)],
        text: 'Customer Ledger for $customerName');
  }

  void loadMoreCreditors() {
    if (!hasMoreCreditors.value) return;
    final nextPage = currentPage.value + 1;
    final startIndex = nextPage * pageSize;
    if (startIndex >= _allCreditors.length) {
      hasMoreCreditors.value = false;
      return;
    }
    final moreItems = _allCreditors.skip(startIndex).take(pageSize).toList();
    creditors.addAll(moreItems);
    currentPage.value = nextPage;
    hasMoreCreditors.value = (startIndex + pageSize) < _allCreditors.length;
  }

  @override
  void onClose() {
    accounts.clear();
    transactions.clear();
    customerInfo.clear();
    supplierInfo.clear();
    _allDebtors.clear();
    _allCreditors.clear();
    filtered.clear();
    super.onClose();
  }
}