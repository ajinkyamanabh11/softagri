import 'dart:async';
import 'dart:developer';

import 'package:apidemo/utils/preference_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:apidemo/Controller/theme_controller.dart';
import 'package:apidemo/bindings/app_bindings.dart';
import 'package:apidemo/routes/app_page_routes.dart';
import 'package:apidemo/routes/routes.dart';
import 'package:apidemo/utils/themes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize storage and preferences
  await GetStorage.init();
  await PreferenceManager.init();

  // Initialize theme controller
  Get.put(ThemeController(), permanent: true);

  // Determine initial route
  final initialRoute = await _determineInitialRoute();

  runApp(MyApp(initialRoute: initialRoute));
}

Future<String> _determineInitialRoute() async {
  final hasSeenWalkthrough = await PreferenceManager.hasSeenWalkthrough();

  // Use GetStorage instance properly and ensure data persistence
  final box = GetStorage();
  await box.writeIfNull('persisted', true); // Ensure storage is persisted

  // Read values with proper error handling
  final username = box.read('username');
  final subfolder = box.read('subfolder');

  final isLoggedIn = username != null && username.toString().isNotEmpty &&
      subfolder != null && subfolder.toString().isNotEmpty;

  if (!hasSeenWalkthrough) {
    return Routes.walkthrough;
  } else if (!isLoggedIn) {
    return Routes.login;
  } else {
    // User has seen walkthrough and is logged in - go to app lock
    return Routes.appLock;
  }
}

class MyApp extends StatelessWidget {
  final String initialRoute;

  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    final themeController = Get.find<ThemeController>();

    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppThemes.lightTheme,
      darkTheme: AppThemes.darkTheme,
      themeMode: themeController.themeMode,
      initialRoute: initialRoute,
      getPages: AppPages.routes,
      initialBinding: AppBindings(),
    );
  }
}