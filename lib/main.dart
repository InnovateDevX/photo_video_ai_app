import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:localization/localization.dart';
import 'package:trail_ai_app/Core/routes.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:trail_ai_app/Services/ad_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:trail_ai_app/Core/theme_notifier.dart';
import 'package:trail_ai_app/Core/locale_notifier.dart';
import 'package:trail_ai_app/Core/app_initializer.dart';
import 'package:trail_ai_app/Services/notification_service.dart';
import 'package:trail_ai_app/Services/local_storage_service.dart';
import 'package:trail_ai_app/Widgets/global_notification_overlay.dart';
import 'firebase_options.dart';

void main() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          systemNavigationBarIconBrightness: Brightness.dark,
          systemNavigationBarContrastEnforced: false,
        ),
      );
      await dotenv.load(fileName: ".env");
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      // await FirebaseAppCheck.instance.activate(
      //   androidProvider: AndroidProvider.debug,
      //   appleProvider: AppleProvider.debug,
      // );

      await GoogleSignIn.instance.initialize();
      await MobileAds.instance.initialize();
      await LocalStorageService().initialize();

      FlutterError.onError =
          FirebaseCrashlytics.instance.recordFlutterFatalError;

      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      await AdService().initialize();
      await NotificationService().initialize();
      final initializer = AppInitializer();
      final uid = await initializer.initializeUser();
      runApp(MyApp(initialUid: uid));
    },
    (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    },
  );
}

class MyApp extends StatelessWidget {
  final String? initialUid;

  const MyApp({super.key, required this.initialUid});

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
              // ── Localization ───────────────────────────────────────────────────
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
              initialRoute: AppRoutes.home,
              routes: getAppRoutes(),
            );
          },
        );
      },
    );
  }
}
