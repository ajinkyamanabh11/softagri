import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../Controller/customerLedgerController.dart';
import '../Controller/selfinformation_controller.dart';
import '../Services/http_data_service.dart';
import '../utils/data_processor.dart';
import 'homeScreen.dart';
import 'loginpage.dart';

class DataLoadingScreen extends StatefulWidget {
  const DataLoadingScreen({super.key});

  @override
  State<DataLoadingScreen> createState() => _DataLoadingScreenState();
}

class _DataLoadingScreenState extends State<DataLoadingScreen> {
  final _loadingProgress = ValueNotifier(0.0);
  final _loadingError = ValueNotifier(false);
  final _errorMessage = ValueNotifier<String?>(null);
  bool _initialized = false;

  @override
  void initState() {
    super.initState(); // Changed from super.onInit() to super.initState()
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final username = GetStorage().read('username');
      final subfolder = GetStorage().read('subfolder');

      if (username == null || subfolder == null) {
        throw Exception('No credentials found');
      }

      final httpService = Get.find<HttpDataServices>();
      httpService.setSubfolder(subfolder);

      // Start loading in background
      unawaited(_loadData());
    } catch (e) {
      _loadingError.value = true;
      _errorMessage.value = e.toString();
      Get.offAll(() => const LoginPage());
    }
  }

  Future<void> _loadData() async {
    try {
      // Load company name first
      _loadingProgress.value = 0.2;
      await Get.find<CompanyController>().fetchCompanyName();

      _loadingProgress.value = 0.5;
      // Load essential data in parallel with timeout handling
      await Future.wait([
        Get.find<HttpDataServices>().fetchItemMaster(forceRefresh: false),
        Get.find<HttpDataServices>().fetchItemDetail(forceRefresh: false),
        Get.find<HttpDataServices>().fetchAccountMaster(forceRefresh: false),
      ]).timeout(const Duration(seconds: 120)); // Moved timeout to the Future.wait result

      _loadingProgress.value = 1.0;

      // Navigate to home
      Get.offAll(() => const HomeScreen());
    } catch (e) {
      _loadingError.value = true;
      _errorMessage.value = e.toString();

      // Show error but don't navigate away immediately
      Get.snackbar(
        'Loading Error',
        'Failed to load data: ${e.toString()}',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
      );
    }
  }

  Future<void> _retryLoading() async {
    _loadingError.value = false;
    _errorMessage.value = null;
    _loadingProgress.value = 0.0;
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ValueListenableBuilder<bool>(
          valueListenable: _loadingError,
          builder: (context, hasError, _) {
            if (hasError) {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<String?>(
                    valueListenable: _errorMessage,
                    builder: (context, errorMessage, _) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          errorMessage ?? 'Failed to load data',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _retryLoading,
                    child: const Text('Retry'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Get.offAll(() => const LoginPage()),
                    child: const Text('Go to Login'),
                  ),
                ],
              );
            }

            return ValueListenableBuilder<double>(
              valueListenable: _loadingProgress,
              builder: (context, progress, _) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: Stack(
                        children: [
                          CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                          Center(
                            child: Text(
                              '${(progress * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Loading Application Data',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This may take a few moments...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (progress < 0.9)
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}