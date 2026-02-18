import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettingsService {
  AppSettingsService._();

  static const String _alertsEnabledKey = 'app_alerts_enabled';
  static final ValueNotifier<bool> alertsEnabled = ValueNotifier<bool>(true);
  static bool _loaded = false;

  static Future<void> ensureLoaded() async {
    if (_loaded) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    alertsEnabled.value = prefs.getBool(_alertsEnabledKey) ?? true;
    _loaded = true;
  }

  static Future<void> setAlertsEnabled(bool value) async {
    alertsEnabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_alertsEnabledKey, value);
  }
}
