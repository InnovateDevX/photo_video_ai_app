import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../Services/remote_config_service.dart';

class ThemeNotifier extends ValueNotifier<bool> {
  ThemeNotifier() : super(true) {
    _loadTheme();
  }

  static const String _themeKey = 'app_theme_is_dark';

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_themeKey);
      if (stored != null) {
        // User has an explicit preference — honor it.
        value = stored;
      } else {
        // Fresh install / cleared prefs — fall back to the Remote Config
        // default if it has been initialized, otherwise use the hard-coded
        // dark fallback so the splash screen is never blank.
        try {
          value = RemoteConfigService().isDarkThemeDefault;
        } catch (_) {
          value = true;
        }
      }
    } catch (e) {
      debugPrint('⚠️ [ThemeNotifier] _loadTheme failed: $e');
      value = true;
    }
  }

  /// Re-evaluates the default theme from Remote Config.
  ///
  /// Called by `AppInitializer` after `RemoteConfigService.initialize()`
  /// completes. If the user has *not* yet stored an explicit preference in
  /// SharedPreferences, the Remote Config `dark_theme` value is adopted and
  /// the listeners (e.g. `MaterialApp.themeMode` in `main.dart`) are notified.
  ///
  /// If the user has already toggled the theme at least once, their stored
  /// preference is preserved — Remote Config never overrides an explicit
  /// user choice.
  Future<void> applyRemoteConfigDefault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getBool(_themeKey);
      if (stored != null) {
        // User preference already wins — make sure the notifier reflects it
        // in case the initial _loadTheme() finished before this method was
        // awaited.
        if (value != stored) value = stored;
        return;
      }

      // No explicit user preference — adopt the Remote Config default.
      final bool rcDefault;
      try {
        rcDefault = RemoteConfigService().isDarkThemeDefault;
      } catch (_) {
        // RemoteConfig not yet initialized — keep current value.
        return;
      }

      if (value != rcDefault) {
        value = rcDefault;
        debugPrint(
          '🎨 [ThemeNotifier] Applied Remote Config default theme (isDark=$rcDefault).',
        );
      }
    } catch (e) {
      debugPrint('⚠️ [ThemeNotifier] applyRemoteConfigDefault failed: $e');
    }
  }

  Future<void> toggleTheme(bool isDark) async {
    value = isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, isDark);
  }
}

// Global instance to be used across the app
final themeNotifier = ThemeNotifier();
