import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ThemeController extends GetxController {
  final _box = GetStorage();
  final _key = 'isDarkMode';

  late final RxBool _isDarkMode;

  @override
  void onInit() {
    super.onInit();
    final bool initialDarkModeValue = _box.read<bool>(_key) ?? false;
    _isDarkMode = RxBool(initialDarkModeValue);
    Get.changeThemeMode(_isDarkMode.value ? ThemeMode.dark : ThemeMode.light);
  }

  RxBool get isDarkMode => _isDarkMode;

  // Renamed the getter from 'theme' to 'themeMode'
  ThemeMode get themeMode => _isDarkMode.value ? ThemeMode.dark : ThemeMode.light;

  _saveThemeToBox(bool isDarkMode) => _box.write(_key, isDarkMode);

  void toggleTheme() {
    final bool currentValue = _isDarkMode.value;
    final ThemeMode newMode = currentValue ? ThemeMode.light : ThemeMode.dark;

    Get.changeThemeMode(newMode);
    _isDarkMode.value = !currentValue;
    _saveThemeToBox(_isDarkMode.value);
  }

  void setThemeMode(ThemeMode mode) {
    bool shouldBeDarkMode = mode == ThemeMode.dark;
    if (_isDarkMode.value != shouldBeDarkMode) {
      Get.changeThemeMode(mode);
      _isDarkMode.value = shouldBeDarkMode;
      _saveThemeToBox(shouldBeDarkMode);
    }
  }
}
