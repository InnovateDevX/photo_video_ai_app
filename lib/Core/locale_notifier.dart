import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reactively notifies the app of locale changes and persists the selection.
///
/// Usage:
///   localeNotifier.setLocale(const Locale('es')); // change to Spanish
class LocaleNotifier extends ValueNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en')) {
    _loadLocale();
  }

  static const String _localeKey = 'app_language_code';

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localeKey) ?? 'en';
    value = Locale(code);
  }

  Future<void> setLocale(Locale locale) async {
    value = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }
}

// Global instance — mirrors the themeNotifier pattern.
final localeNotifier = LocaleNotifier();
