import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppThemeService {
  static const _themeModeKey = 'app_theme_mode';
  static final AppThemeService _instance = AppThemeService._internal();
  factory AppThemeService() => _instance;
  AppThemeService._internal();

  final ValueNotifier<ThemeMode> themeModeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_themeModeKey);
    themeModeNotifier.value = _parse(raw);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeModeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, _serialize(mode));
  }

  ThemeMode _parse(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.light;
    }
  }

  String _serialize(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
