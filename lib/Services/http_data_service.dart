import 'dart:async';
import 'dart:convert';
import 'package:apidemo/Model/accountMaster_models.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../Model/AllAccounts_Model.dart';
import '../Model/customer_info_model.dart';
import '../Model/item_detail.dart';
import '../Model/item_master.dart';
import '../Model/salesReport_Models/salesInvoiceDetail_model.dart';
import '../Model/salesReport_Models/salesInvoiceMaster_model.dart';

import 'package:flutter/foundation.dart';

class HttpDataServices extends GetxService {
  static const String _baseUrl = 'http://103.26.205.120:5000';
  final GetStorage _storage = GetStorage();
  final RxList<AccountMaster_Model> accountMasterCache = <AccountMaster_Model>[].obs;
  final RxList<AllAccounts_Model> allAccountsCache = <AllAccounts_Model>[].obs;
  final RxList<CustomerInfoModel> customerInfoCache = <CustomerInfoModel>[].obs;
  final RxList<CustomerInfoModel> supplierInfoCache = <CustomerInfoModel>[].obs;

  final RxString subfolderRx = ''.obs;
  String get subfolder => subfolderRx.value;
  String get baseUrl => _baseUrl;

  // Cache duration (1 hour)
  final Duration _cacheDuration = const Duration(hours: 1);
  // Increased timeout duration
  final Duration _apiTimeout = const Duration(seconds: 60);
  // Retry configuration
  final int _maxRetries = 3;
  final Duration _retryDelay = const Duration(seconds: 2);

  final Connectivity _connectivity = Connectivity();
  final RxBool isOnline = true.obs;
  final RxBool isRefreshing = false.obs;

  @override
  void onInit() {
    super.onInit();
    _setupConnectivityListener();
    final storedSubfolder = _storage.read('subfolder');
    if (storedSubfolder != null) {
      subfolderRx.value = storedSubfolder;
    }
  }

  void _setupConnectivityListener() {
    _connectivity.onConnectivityChanged.listen((result) {
      isOnline.value = result != ConnectivityResult.none;
    });
  }

  Future<bool> checkConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      isOnline.value = result != ConnectivityResult.none;
      return isOnline.value;
    } catch (e) {
      isOnline.value = false;
      return false;
    }
  }

  void setSubfolder(String subfolderName) {
    subfolderRx.value = subfolderName;
    _storage.write('subfolder', subfolderName);
  }

  Uri _buildUrl(String table, {int page = 1, int perPage = 100}) {
    return Uri.parse(
      '$_baseUrl/read_table?subfolder=$subfolder/20252026&filename=softagri.mdb&table=$table&page=$page&per_page=$perPage',
    );
  }

  Future<Map<String, dynamic>> _fetchPaginatedData(String table, {int page = 1, int perPage = 100}) async {
    try {
      final response = await http.get(_buildUrl(table, page: page, perPage: perPage));

      if (response.statusCode == 200) {
        final decodedResponse = json.decode(response.body);
        return decodedResponse;
      } else {
        throw Exception('Failed to load $table data: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<T>> fetchAllPaginatedData<T>({
    required String table,
    required T Function(Map<String, dynamic>) fromJson,
    String? cacheKey,
    bool forceRefresh = false,
  }) async {
    if (subfolder.isEmpty) {
      throw Exception('Subfolder not set. Please log in first.');
    }

    // Check cache first if not forcing refresh
    if (!forceRefresh && cacheKey != null) {
      final cachedData = _storage.read(cacheKey);
      if (cachedData != null) {
        try {
          List<dynamic> dataList;

          if (cachedData is List) {
            dataList = cachedData;
          } else if (cachedData is Map && cachedData.containsKey('data')) {
            dataList = cachedData['data'] as List<dynamic>;
          } else if (cachedData is String) {
            final decoded = json.decode(cachedData);
            dataList = decoded is List ? decoded : decoded['data'] as List<dynamic>;
          } else {
            throw Exception('Invalid cached data format');
          }

          return dataList.map((e) => fromJson(e as Map<String, dynamic>)).toList();
        } catch (e) {
          // Cache is corrupted, remove it
          await _storage.remove(cacheKey);
        }
      }
    }

    // Fetch all data with pagination
    List<T> allData = [];
    int currentPage = 1;
    bool hasMore = true;

    while (hasMore) {
      try {
        final response = await _fetchPaginatedData(table, page: currentPage, perPage: 100);
        final List<dynamic> pageData = response['data'] ?? [];

        if (pageData.isEmpty) {
          hasMore = false;
        } else {
          allData.addAll(pageData.map((json) => fromJson(json)).toList());
          currentPage++;

          // Check if we've reached the last page
          final pagination = response['pagination'] ?? {};
          hasMore = pagination['has_next'] ?? (pageData.length == 100);
        }
      } catch (e) {
        // If we have some data, return it with a warning
        if (allData.isNotEmpty) {
          debugPrint('Partial data loaded for $table: $e');
          return allData;
        }
        rethrow;
      }
    }

    // Cache the data if a cache key is provided
    if (cacheKey != null) {
      final cacheData = {
        'timestamp': DateTime.now().toIso8601String(),
        'data': allData.map((item) => _convertToJson(item)).toList(),
      };
      await _storage.write(cacheKey, cacheData);
    }

    return allData;
  }

  dynamic _convertToJson(dynamic item) {
    if (item is SalesInvoiceMaster) {
      return item.toJson();
    } else if (item is SalesInvoiceDetail) {
      return item.toJson();
    } else if (item is AccountMaster_Model) {
      return item.toJson();
    } else if (item is AllAccounts_Model) {
      return item.toJson();
    } else if (item is CustomerInfoModel) {
      return item.toJson();
    } else if (item is ItemMaster) {
      return item.toJson();
    } else if (item is ItemDetail) {
      return item.toJson();
    } else if (item is Map<String, dynamic>) {
      return item;
    } else {
      try {
        final dynamicItem = item as dynamic;
        if (dynamicItem.toJson != null) {
          return dynamicItem.toJson();
        }
      } catch (e) {
        debugPrint('Failed to serialize item: $e');
      }
      return {};
    }
  }

  // Update all fetch methods to use the new paginated approach
  Future<List<ItemMaster>> fetchItemMaster({bool forceRefresh = false}) async {
    try {
      return await fetchAllPaginatedData(
        table: 'ItemMaster',
        fromJson: ItemMaster.fromJson,
        cacheKey: 'itemMaster',
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      print('Error in fetchItemMaster: $e');
      rethrow;
    }
  }

  Future<List<ItemDetail>> fetchItemDetail({bool forceRefresh = false}) async {
    try {
      return await fetchAllPaginatedData(
        table: 'ItemDetail',
        fromJson: ItemDetail.fromJson,
        cacheKey: 'itemDetail',
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      print('Error in fetchItemDetail: $e');
      rethrow;
    }
  }

  Future<List<SalesInvoiceMaster>> fetchSalesInvoiceMaster({bool forceRefresh = false}) async {
    try {
      return await fetchAllPaginatedData(
        table: 'SalesInvoiceMaster',
        fromJson: SalesInvoiceMaster.fromJson,
        cacheKey: 'salesInvoiceMaster',
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      print('Error in fetchSalesInvoiceMaster: $e');
      rethrow;
    }
  }

  Future<List<SalesInvoiceDetail>> fetchSalesInvoiceDetails({bool forceRefresh = false}) async {
    try {
      return await fetchAllPaginatedData(
        table: 'SalesInvoiceDetails',
        fromJson: SalesInvoiceDetail.fromJson,
        cacheKey: 'salesInvoiceDetails',
        forceRefresh: forceRefresh,
      );
    } catch (e) {
      print('Error in fetchSalesInvoiceDetails: $e');
      rethrow;
    }
  }

  Future<List<AccountMaster_Model>> fetchAccountMaster({bool forceRefresh = false}) async {
    try {
      final data = await fetchAllPaginatedData(
        table: 'AccountMaster',
        fromJson: AccountMaster_Model.fromJson,
        cacheKey: 'accountMaster',
        forceRefresh: forceRefresh,
      );
      accountMasterCache.assignAll(data);
      return data;
    } catch (e) {
      print('Error in fetchAccountMaster: $e');
      if (accountMasterCache.isNotEmpty) {
        print('Returning cached accountMasterCache');
        return accountMasterCache.toList();
      }
      rethrow;
    }
  }

  Future<List<AllAccounts_Model>> fetchAllAccounts({bool forceRefresh = false}) async {
    try {
      final data = await fetchAllPaginatedData(
        table: 'AllAccounts',
        fromJson: AllAccounts_Model.fromJson,
        cacheKey: 'allAccounts',
        forceRefresh: forceRefresh,
      );
      allAccountsCache.assignAll(data);
      return data;
    } catch (e) {
      print('Error in fetchAllAccounts: $e');
      if (allAccountsCache.isNotEmpty) {
        print('Returning cached allAccountsCache');
        return allAccountsCache.toList();
      }
      rethrow;
    }
  }

  Future<List<CustomerInfoModel>> fetchCustomerInfo({bool forceRefresh = false}) async {
    try {
      final data = await fetchAllPaginatedData(
        table: 'CustomerInformation',
        fromJson: CustomerInfoModel.fromJson,
        cacheKey: 'customerInformation',
        forceRefresh: forceRefresh,
      );
      customerInfoCache.assignAll(data);
      return data;
    } catch (e) {
      print('Error in fetchCustomerInfo: $e');
      if (customerInfoCache.isNotEmpty) {
        print('Returning cached customerInfoCache');
        return customerInfoCache.toList();
      }
      rethrow;
    }
  }

  Future<List<CustomerInfoModel>> fetchSupplierInfo({bool forceRefresh = false}) async {
    try {
      final data = await fetchAllPaginatedData(
        table: 'SupplierInformation',
        fromJson: CustomerInfoModel.fromJson,
        cacheKey: 'supplierInformation',
        forceRefresh: forceRefresh,
      );
      supplierInfoCache.assignAll(data);
      return data;
    } catch (e) {
      print('Error in fetchSupplierInfo: $e');
      if (supplierInfoCache.isNotEmpty) {
        print('Returning cached supplierInfoCache');
        return supplierInfoCache.toList();
      }
      rethrow;
    }
  }

  Future<void> clearCache() async {
    print('Clearing all cached data');
    await _storage.erase();
    accountMasterCache.clear();
    allAccountsCache.clear();
    customerInfoCache.clear();
    supplierInfoCache.clear();
  }

  String getCacheStatus(String key) {
    final cachedData = _storage.read(key);
    if (cachedData == null) return 'No cached data';

    try {
      if (cachedData is Map && cachedData.containsKey('timestamp')) {
        final cacheTime = DateTime.parse(cachedData['timestamp']);
        final age = DateTime.now().difference(cacheTime);

        if (age > _cacheDuration) {
          return 'Cache expired ${age.inHours}h ago';
        }
        return 'Cached ${age.inMinutes}m ago';
      }
      return 'Cached (legacy format)';
    } catch (e) {
      return 'Invalid cached data format';
    }
  }

  bool isCacheValid(String key) {
    final cachedData = _storage.read(key);
    if (cachedData == null) return false;

    try {
      if (cachedData is Map && cachedData.containsKey('timestamp')) {
        final cacheTime = DateTime.parse(cachedData['timestamp']);
        return DateTime.now().difference(cacheTime) <= _cacheDuration;
      }
      // Legacy format - consider it valid
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> clearSpecificCache(String cacheKey) async {
    print('Clearing specific cache for $cacheKey');
    await _storage.remove(cacheKey);
  }

  Future<bool> checkServerAvailability() async {
    try {
      final response = await http.get(
          Uri.parse('$_baseUrl/'),
          headers: {'Connection': 'close'}
      ).timeout(Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('Server availability check failed: $e');
      return false;
    }
  }
}