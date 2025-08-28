import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../Model/AllAccounts_Model.dart';
import '../Model/accountMaster_models.dart';
import '../Model/customer_info_model.dart';
import '../Services/http_data_service.dart';

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
      debugPrint('Error loading data: $e\n$st');
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
      debugPrint('Error during refresh: $e\n$st');
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
      debugPrint('Error loading customer info: $e');
      if (customerInfo.isNotEmpty) {
        debugPrint('Using existing customer info data');
      } else {
        rethrow;
      }
    }
  }

  Future<void> _loadSupplierInfo({bool forceRefresh = false}) async {
    try {
      supplierInfo.value = await _dataService.fetchSupplierInfo(forceRefresh: forceRefresh);
    } catch (e) {
      debugPrint('Error loading supplier info: $e');
      if (supplierInfo.isNotEmpty) {
        debugPrint('Using existing supplier info data');
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
      debugPrint('Error processing data: $e\n$st');
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