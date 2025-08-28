// login_controller.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../Screens/loginpage.dart';
import '../Services/auth_service.dart';
import '../Services/http_data_service.dart';
import '../Screens/data_loading_screen.dart';
import '../routes/routes.dart';
import '../utils/preference_manager.dart';

// login_controller.dart - Remove the useDeviceAuth option and make app lock compulsory
class LoginController extends GetxController {
  final HttpDataServices _httpDataServices = Get.find<HttpDataServices>();
  final Connectivity _connectivity = Connectivity();
  final AuthService _authService = AuthService();
  var isLoading = false.obs;
  var canCheckBiometrics = false.obs;
  final box = GetStorage();

  @override
  void onInit() {
    super.onInit();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    canCheckBiometrics.value = await _authService.canAuthenticateWithDevice();
  }

  Future<bool> authenticateAppLock() async {
    // Always attempt authentication - app lock is now compulsory
    bool success = await _authService.authenticateWithDevice();
    return success;
  }

  Future<bool> login(String username) async {
    isLoading.value = true;
    try {
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        Get.snackbar(
          "No Internet",
          "Please check your internet connection and try again",
          duration: const Duration(seconds: 3),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
        );
        return false;
      }

      // Test server connectivity first
      final canReachServer = await _testServerConnectivity();
      if (!canReachServer) {
        Get.snackbar(
          "Server Unreachable",
          "Cannot connect to the server. Please try again later.",
          duration: const Duration(seconds: 3),
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.orange,
        );
        return false;
      }

      final response = await http.get(
        Uri.parse('${_httpDataServices.baseUrl}/get_credentials?subfolder=$username'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['username'] != null) {
          // Ensure data persistence
          await box.write('username', username);
          await box.write('subfolder', username);
          await box.save(); // Force save to disk

          _httpDataServices.setSubfolder(username);

          // Always store credentials for app lock
          await _authService.storeCredentials(username);

          // Check if user has completed walkthrough
          final hasSeenWalkthrough = await PreferenceManager.hasSeenWalkthrough();

          if (!hasSeenWalkthrough) {
            Get.offAllNamed(Routes.walkthrough);
          } else {
            // Go to app lock screen instead of data loading
            Get.offAllNamed(Routes.appLock);
          }
          return true;
        }
      }

      Get.snackbar(
          "Error",
          "Invalid User Id Number",
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red
      );

    } on SocketException catch (e) {
      Get.snackbar(
        "Connection Error",
        "Cannot connect to server. Please check your internet connection.",
        duration: const Duration(seconds: 3),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
      );
    } on TimeoutException catch (e) {
      Get.snackbar(
        "Timeout",
        "Connection timed out. Please try again.",
        duration: const Duration(seconds: 3),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
      );
    } on http.ClientException catch (e) {
      Get.snackbar(
        "Network Error",
        "Failed to establish connection. Please try again.",
        duration: const Duration(seconds: 3),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Login failed: ${e.toString().replaceAll('Exception: ', '')}",
        duration: const Duration(seconds: 3),
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
      );
    } finally {
      isLoading.value = false;
    }
    return false;
  }

// Add this helper method to test server connectivity
  Future<bool> _testServerConnectivity() async {
    try {
      final response = await http.get(
          Uri.parse('${_httpDataServices.baseUrl}/'),
          headers: {'Connection': 'close'}
      ).timeout(Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      print('Server connectivity test failed: $e');
      return false;
    }
  }

  void logout({bool fromAppLock = false}) async {
    await _authService.clearCredentials();
    box.remove('username');
    box.remove('subfolder');

    if (fromAppLock) {
      // If logging out from app lock, navigate to login
      Get.offAll(() => const LoginPage());
    } else {
      // Regular logout
      Get.offAll(() => const LoginPage());
    }
  }
}
