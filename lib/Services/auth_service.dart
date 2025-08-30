// auth_service.dart
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // New method to check if the device can authenticate
  Future<bool> canAuthenticateWithDevice() async {
    try {
      final isSupported = await _localAuth.isDeviceSupported();
      final canCheckBiometrics = await _localAuth.canCheckBiometrics;
      return isSupported || canCheckBiometrics;
    } catch (e) {
      log('Error checking biometrics: $e');
      return false;
    }
  }

  Future<bool> authenticateWithDevice() async {
    try {
      bool canAuthenticate = await canAuthenticateWithDevice();
      if (!canAuthenticate) {
        // If device doesn't support biometrics, use alternative authentication
        return await _authenticateWithAlternativeMethod();
      }

      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to access the app',
        options: const AuthenticationOptions(
          biometricOnly: false, // Allow device PIN as fallback
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      log('Authentication error: $e');
      return false;
    }
  }

  Future<bool> _authenticateWithAlternativeMethod() async {
    return await showDialog(
      context: Get.context!,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 50,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              const Text(
                'Enter Security PIN',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  hintText: '••••',
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.green),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.green, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 20,
                  ),
                ),
                onChanged: (value) {
                  if (value.length == 4) {
                    // Simple PIN validation
                    Get.back(result: value == '1234'); // Default PIN for demo
                  }
                },
              ),
              const SizedBox(height: 20),
              Text(
                'Enter your 4-digit security PIN',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    ) ?? false;
  }

  Future<void> storeCredentials(String username) async {
    await _secureStorage.write(key: 'username', value: username);
  }

  Future<String?> getStoredUsername() async {
    return await _secureStorage.read(key: 'username');
  }

  Future<void> clearCredentials() async {
    await _secureStorage.delete(key: 'username');
  }
}
