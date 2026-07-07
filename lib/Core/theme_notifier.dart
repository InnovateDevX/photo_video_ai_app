import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ValueNotifier<bool> {
  ThemeNotifier() : super(true) {
    _loadTheme();
  }

  static const String _themeKey = 'app_theme_is_dark';

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    value = prefs.getBool(_themeKey) ?? true;
  }

  Future<void> toggleTheme(bool isDark) async {
    value = isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
  }
}

// Global instance to be used across the app
final themeNotifier = ThemeNotifier();
