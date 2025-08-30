import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../Controller/login_controller.dart';
import '../Controller/selfinformation_controller.dart';
import '../Services/http_data_service.dart';
import '../routes/routes.dart';
import '../utils/preference_manager.dart';
import 'homeScreen.dart';
import 'loginpage.dart';
import 'data_loading_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final box = GetStorage();
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
      await Future.delayed(const Duration(milliseconds: 500));
      final username = box.read('username');
      final subfolder = box.read('subfolder');
      final hasSeenWalkthrough = await PreferenceManager.hasSeenWalkthrough();

      if (username != null && subfolder != null) {
        // User is logged in, always go to app lock screen
        Get.offAllNamed(Routes.appLock);
      } else if (!hasSeenWalkthrough) {
        // First time user, go to walkthrough
        Get.offAllNamed(Routes.walkthrough);
      } else {
        // Returning user but not logged in, go to login
        Get.offAll(() => const LoginPage());
      }
    } catch (e) {
      log('Splash initialization error: $e');
      Get.offAll(() => const LoginPage());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/loginbg1.png'),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black45,
              BlendMode.darken,
            ),
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF4CAF50),
              Color(0xFF81C784),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/applogo_circle.png', width: 120, height: 120),
              const SizedBox(height: 20),
              const Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const CircularProgressIndicator(color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}