import 'package:shared_preferences/shared_preferences.dart';

class PreferenceManager {
  static const _keyWalkthroughSeen = 'walkthrough_seen';
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      // It's not possible to create an in-memory fallback with shared_preferences.
      // The best course of action is to handle the error and proceed without the preference manager
      // or to gracefully fail. The original code's approach was incorrect.
      print('Error initializing SharedPreferences: $e');
    }
  }

  static bool hasSeenWalkthrough() {
    if (_prefs == null) return false;
    return _prefs!.getBool(_keyWalkthroughSeen) ?? false;
  }
  static Future<void> setWalkthroughSeen() async {
    if (_prefs == null) return;
    await _prefs!.setBool(_keyWalkthroughSeen, true);
  }

  static Future<void> resetWalkthroughSeen() async {
    // Only access preferences if they have been successfully initialized
    if (_prefs == null) return;
    await _prefs!.setBool(_keyWalkthroughSeen, false);
  }
  static const _keyFirstLaunch = 'first_launch';

  static Future<bool> isFirstLaunch() async {
    if (_prefs == null) return true;
    return _prefs!.getBool(_keyFirstLaunch) ?? true;
  }

  static Future<void> setFirstLaunchComplete() async {
    if (_prefs == null) return;
    await _prefs!.setBool(_keyFirstLaunch, false);
  }
  static Map<String, dynamic> getAllPreferences() {
    // Only access preferences if they have been successfully initialized
    if (_prefs == null) return {};
    try {
      return _prefs!.getKeys().fold<Map<String, dynamic>>(
        <String, dynamic>{},
            (Map<String, dynamic> map, String key) {
          map[key] = _prefs!.get(key);
          return map;
        },
      );
    } catch (e) {
      print('Error getting all preferences: $e');
      return {};
    }
  }
}
