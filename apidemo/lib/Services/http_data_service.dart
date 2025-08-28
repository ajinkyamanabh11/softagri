import 'dart:async';
import 'dart:convert';
import 'package:apidemo/Model/accountMaster_models.dart';
import 'package:http/http.dart' as http;
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../Model/AllAccounts_Model.dart';
import '../Model/customer_info_model.dart';
import '../Model/item_detail.dart';
import '../Model/item_master.dart';
import '../Model/salesReport_Models/salesInvoiceDetail_model.dart';
import '../Model/salesReport_Models/salesInvoiceMaster_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class HttpDataServices extends GetxService {
  static const String _baseUrl = 'http://103.26.205.120:5000';
  static const String _filename = 'softagri.mdb';
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
  final RxBool isRefreshing = false.obs; // Added for refresh state tracking

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

  Uri _buildUrl(String table) {
    return Uri.parse(
      '$_baseUrl/read_table?subfolder=$subfolder/20252026&filename=$_filename&table=$table',
    );
  }

  Future<List<T>> _fetchWithRetry<T>({
    required Future<List<T>> Function() fetchFunction,
    required String table,
  }) async {
    int attempt = 0;
    while (attempt < _maxRetries) {
      try {
        // Check server availability before attempting
        final serverAvailable = await checkServerAvailability();
        if (!serverAvailable) {
          throw Exception('Server not available');
        }

        return await fetchFunction().timeout(_apiTimeout);
      } catch (e) {
        attempt++;
        print('Attempt $attempt failed for $table: $e');

        if (attempt == _maxRetries) {
          rethrow;
        }

        // Exponential backoff
        await Future.delayed(_retryDelay * attempt);
      }
    }
    throw Exception('Failed after $_maxRetries attempts');
  }

  bool _hasToJsonMethod(dynamic object) {
    try {
      return object.toJson() is Map<String, dynamic>;
    } catch (e) {
      return false;
    }
  }

  // This is the updated method to fix the type casting and caching issue.
  Future<List<T>> fetchWithCache<T>({
    required String table,
    required T Function(Map<String, dynamic>) fromJson,
    required String cacheKey,
    bool forceRefresh = false,
  }) async {
    print('Fetching $table with forceRefresh: $forceRefresh');

    if (subfolder.isEmpty) {
      throw Exception('Subfolder not set. Please log in first.');
    }

    final hasConnection = await checkConnection();
    dynamic cachedData;

    try {
      final now = DateTime.now();

      // Clear cache if forcing refresh
      if (forceRefresh) {
        await _storage.remove(cacheKey);
        print('Force refresh - cleared cache for $cacheKey');
      }

      // Try to read cached data
      cachedData = _storage.read(cacheKey);

      // Handle cached data if it exists and we're not forcing refresh
      if (cachedData != null && !forceRefresh) {
        try {
          List<dynamic> dataList;

          // Case 1: Cached data is already a List (old format)
          if (cachedData is List) {
            print('Returning cached data in List format for $table');
            dataList = cachedData;
          }
          // Case 2: Cached data is a Map with 'data' key (new format)
          else if (cachedData is Map && cachedData.containsKey('data')) {
            print('Returning cached data in Map format for $table');
            dataList = cachedData['data'] as List<dynamic>;
          }
          // Case 3: Cached data is a JSON string
          else if (cachedData is String) {
            print('Returning cached data in String format for $table');
            final decoded = json.decode(cachedData);
            if (decoded is List) {
              dataList = decoded;
            } else if (decoded is Map && decoded.containsKey('data')) {
              dataList = decoded['data'] as List<dynamic>;
            } else {
              throw Exception('Invalid cached data format');
            }
          } else {
            throw Exception('Unknown cached data format');
          }

          return dataList.map((e) => fromJson(e as Map<String, dynamic>)).toList();
        } catch (e, stack) {
          debugPrint('Error parsing cached data for $table: $e\n$stack');
          await _storage.remove(cacheKey); // Corrupted cache, so remove it
        }
      }

      // If no connection and no valid cached data
      if (!hasConnection) {
        throw Exception('No internet connection and no valid cached data available');
      }

      // Fetch from API with retry logic
      print('Making API call for $table');
      final response = await _fetchWithRetry(
        table: table,
        fetchFunction: () async {
          final response = await http.get(_buildUrl(table));
          if (response.statusCode == 200) {
            final decodedResponse = json.decode(response.body);
            final List<dynamic> data = decodedResponse['data'] ?? [];
            return data.map((json) => fromJson(json)).toList();
          } else {
            throw Exception('Failed to load $table data: ${response.statusCode}');
          }
        },
      );

      // Cache the successful response with proper serialization
      final cacheData = {
        'timestamp': now.toIso8601String(),
        'data': response.map((item) {
          // Convert each item to JSON based on its type
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
            // For any other type, try to call toJson() dynamically
            try {
              final dynamicItem = item as dynamic;
              if (dynamicItem.toJson != null) {
                return dynamicItem.toJson();
              }
            } catch (e) {
              debugPrint('Failed to serialize item of type ${item.runtimeType}: $e');
            }
            throw Exception('Unsupported type for caching: ${item.runtimeType}');
          }
        }).toList(),
      };

      await _storage.write(cacheKey, cacheData);
      print('Successfully fetched ${response.length} $table records and cached them');
      return response;

    } catch (e, stack) {
      debugPrint('Error in fetchWithCache for $table: $e\n$stack');

      // If API call fails, fall back to expired cache if it exists
      if (cachedData != null) {
        try {
          List<dynamic> dataList;

          if (cachedData is List) {
            dataList = cachedData;
          } else if (cachedData is Map && cachedData.containsKey('data')) {
            dataList = cachedData['data'] as List<dynamic>;
          } else if (cachedData is String) {
            final decoded = json.decode(cachedData);
            if (decoded is List) {
              dataList = decoded;
            } else if (decoded is Map && decoded.containsKey('data')) {
              dataList = decoded['data'] as List<dynamic>;
            } else {
              throw Exception('Invalid cached data format');
            }
          } else {
            throw Exception('Unknown cached data format');
          }

          print('API call failed, falling back to cached data for $table');
          return dataList.map((e) => fromJson(e as Map<String, dynamic>)).toList();
        } catch (fallbackError, fallbackStack) {
          debugPrint('Error falling back to cache: $fallbackError\n$fallbackStack');
          throw Exception('Failed to fetch data and cache is corrupted: $fallbackError');
        }
      }
      rethrow;
    }
  }

  // Specific data fetch methods with improved error handling
  Future<List<ItemMaster>> fetchItemMaster({bool forceRefresh = false}) async {
    try {
      return await fetchWithCache(
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
      return await fetchWithCache(
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
      return await fetchWithCache(
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
      return await fetchWithCache(
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
      final data = await fetchWithCache(
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
      final data = await fetchWithCache(
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
      final data = await fetchWithCache(
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
      final data = await fetchWithCache(
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

    // This method needs to handle the new caching format
    if (cachedData is List) {
      return 'Data stored directly as a list';
    }

    try {
      final cacheTime = DateTime.parse(cachedData['timestamp']);
      final age = DateTime.now().difference(cacheTime);

      if (age > _cacheDuration) {
        return 'Cache expired ${age.inHours}h ago';
      }
      return 'Cached ${age.inMinutes}m ago';
    } catch (e) {
      return 'Invalid cached data format';
    }
  }

  bool isCacheValid(String key) {
    final cachedData = _storage.read(key);
    if (cachedData == null) return false;

    // This method no longer checks for time validity, just existence.
    return cachedData is Map || cachedData is List;
  }

  // New method to force clear specific cache
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