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
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
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
      Get.offAll(() => const LoginPage());
    }
  }

  Future<void> _loadData() async {
    try {
      // Load company name first
      await Get.find<CompanyController>().fetchCompanyName();
      _loadingProgress.value = 0.3;

      // Then load ledger data in background
      // final ledgerCtrl = Get.find<CustomerLedgerController>();
      // await ledgerCtrl.loadData();
      // _loadingProgress.value = 1.0;

      // Navigate to home
      Get.offAll(() => const HomeScreen());
    } catch (e) {
      _loadingError.value = true;
      Get.offAll(() => const LoginPage());
    }
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
                  const Icon(Icons.error, size: 48),
                  const SizedBox(height: 16),
                  const Text('Failed to load data'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Get.offAll(() => const LoginPage()),
                    child: const Text('Retry'),
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
                    CircularProgressIndicator(value: progress),
                    const SizedBox(height: 16),
                    Text('Loading... ${(progress * 100).toInt()}%'),
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