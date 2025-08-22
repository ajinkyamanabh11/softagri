import 'dart:async';

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
  // 1. First initialize Flutter bindings in the root zone
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Make zone errors non-fatal in production (keep true for development)
  BindingBase.debugZoneErrorsAreFatal = false;

  // 3. Run everything in the same zone
  runZonedGuarded(() async {
    // Initialize storage and preferences
    await GetStorage.init();
    await PreferenceManager.init();

    // Initialize theme controller
    Get.put(ThemeController(), permanent: true);

    // Run the app
    runApp(MyApp(initialRoute: await _determineInitialRoute()));
  }, (error, stack) {
    // Handle any errors that occur in the zone
    debugPrint('Application error: $error\n$stack');
    // Consider adding crash reporting here
  });
}

Future<String> _determineInitialRoute() async {
  final hasSeenWalkthrough = await PreferenceManager.hasSeenWalkthrough();
  final box = GetStorage();

  final username = box.read('username');
  final subfolder = box.read('subfolder');
  final isLoggedIn = username != null && username.toString().isNotEmpty &&
      subfolder != null && subfolder.toString().isNotEmpty;

  if (!hasSeenWalkthrough) {
    return Routes.walkthrough;
  } else if (!isLoggedIn) {
    return Routes.login;
  } else {
    // User is logged in - go to main app, not app lock
    return Routes.home;  // Change this to your main route
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