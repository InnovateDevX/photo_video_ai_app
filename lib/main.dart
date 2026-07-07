import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:localization/localization.dart';
import 'package:trail_ai_app/Core/routes.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:trail_ai_app/Core/theme_notifier.dart';
import 'package:trail_ai_app/Core/locale_notifier.dart';
import 'package:trail_ai_app/Services/notification_service.dart';
import 'package:trail_ai_app/Services/replicate_service.dart';
import 'package:trail_ai_app/Widgets/global_notification_overlay.dart';
import 'package:trail_ai_app/pages/splash_screen.dart';

import 'package:trail_ai_app/Services/localization_service.dart';

void main() {
  // We intentionally do NOT await anything here.
  //
  // Historically, all heavy initialization (Firebase, Google Sign-In, Ads,
  // FCM, the background service, the user initializer, …) was awaited here
  // before runApp() was called. On the second app launch, one of those awaits
  // would hang — most commonly FlutterBackgroundService.configure() when the
  // foreground service from a previous session was still alive — and the
  // user would be stuck on the Android system splash screen forever.
  //
  // The fix is to render a Flutter splash screen immediately, run every
  // initialization step in the background with strict per-step timeouts, and
  // navigate to the home/onboarding screen when done. The splash screen
  // itself has a hard ceiling that guarantees the user is never stuck.
  WidgetsFlutterBinding.ensureInitialized();
  LocalizationService.init();
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.manual,
    overlays: [SystemUiOverlay.top],
  );
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  // Route uncaught errors to Crashlytics without blocking startup. Crashlytics
  // is initialized lazily; the first recordError call will initialize it.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    // Fire and forget — don't block UI on the crashlytics round-trip.
    unawaited(
      _safeRecordFatal(details.exception, details.stack ?? StackTrace.empty),
    );
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('🛑 [PlatformDispatcher] Uncaught error: $error\n$stack');
    unawaited(_safeRecordFatal(error, stack));
    return true;
  };

  runApp(const MyApp());
}

Future<void> _safeRecordFatal(Object error, StackTrace stack) async {
  try {
    await FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
  } catch (_) {
    // Crashlytics may not be initialized yet — that's fine, ignore.
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // App is being minimized or killed — cancel any active Replicate prediction
      debugPrint(
        '🚫 [MyApp] App lifecycle: $state — Cancelling active Replicate prediction',
      );
      // Fire-and-forget; never block on this.
      unawaited(_safeCancelActive());
    }
  }

  Future<void> _safeCancelActive() async {
    try {
      await ReplicateService().cancelActivePrediction();
    } catch (e) {
      debugPrint('⚠️ [MyApp] cancelActivePrediction failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: localeNotifier,
      builder: (context, locale, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: themeNotifier,
          builder: (context, isDark, child) {
            SystemChrome.setSystemUIOverlayStyle(
              SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: isDark
                    ? Brightness.light
                    : Brightness.dark,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarIconBrightness: isDark
                    ? Brightness.light
                    : Brightness.dark,
                systemNavigationBarContrastEnforced: false,
              ),
            );
            return MaterialApp(
              debugShowCheckedModeBanner: false,
              navigatorKey: NotificationService().navigatorKey,
              themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
              theme: ThemeData(
                brightness: Brightness.light,
                scaffoldBackgroundColor: Colors.white,
              ),
              darkTheme: ThemeData(
                brightness: Brightness.dark,
                scaffoldBackgroundColor: isDark
                    ? Color(0xFF161616)
                    : Colors.white,
              ),
              locale: locale,
              localizationsDelegates: [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                LocalJsonLocalization.delegate,
              ],
              supportedLocales: const [
                Locale('en'), // English
                Locale('es'), // Spanish
                Locale('fr'), // French
                Locale('hi'), // Hindi
                Locale('ne'), // Nepali
                Locale('zh'), // Chinese
                Locale('de'), // German
                Locale('id'), // Indonesian
                Locale('pt'), // Portuguese
                Locale('tr'), // Turkish
              ],
              // ──────────────────────────────────────────────────────────────────
              builder: (context, child) {
                return GlobalNotificationOverlay(child: child!);
              },
              // Always start at the splash screen. The splash screen performs
              // all initialization in the background and navigates to either
              // OnboardingPage or MainNavigation when done (or after a hard
              // 25s ceiling). This guarantees the user is never stuck.
              home: const SplashScreen(),
              routes: getAppRoutes(),
            );
          },
        );
      },
    );
  }
}
