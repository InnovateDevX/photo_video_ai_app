import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:trail_ai_app/Core/app_initializer.dart';
import 'package:trail_ai_app/Services/ad_service.dart';
import 'package:trail_ai_app/Services/notification_service.dart';
import 'package:trail_ai_app/Services/local_storage_service.dart';
import 'package:trail_ai_app/Services/background_generation_service.dart';
import 'package:trail_ai_app/pages/onboarding_page.dart';
import 'package:trail_ai_app/Widgets/main_navigation.dart';

/// Result of the initialization process.
class InitializationResult {
  final String? uid;
  final bool showOnboarding;
  final bool hadErrors;
  final List<String> errors;

  InitializationResult({
    this.uid,
    required this.showOnboarding,
    this.hadErrors = false,
    this.errors = const [],
  });
}

/// Maximum time we'll wait for ALL initialization steps combined.
/// If anything hangs, we fall back to the home screen so the user is never stuck.
const Duration _totalInitTimeout = Duration(seconds: 25);

/// Per-step timeouts. Each individual step gets its own budget so a single
/// hanging service can't block the whole launch.
const Duration _firebaseTimeout = Duration(seconds: 10);
const Duration _googleSignInTimeout = Duration(seconds: 8);
const Duration _adsTimeout = Duration(seconds: 8);
const Duration _localStorageTimeout = Duration(seconds: 4);
const Duration _adServiceTimeout = Duration(seconds: 8);
const Duration _notificationTimeout = Duration(seconds: 6);
const Duration _userInitTimeout = Duration(seconds: 12);
const Duration _onboardingCheckTimeout = Duration(seconds: 3);
const Duration _bgServiceTimeout = Duration(seconds: 6);

/// A robust splash screen that:
///   1) Renders the splash UI immediately (so the Android native splash
///      transitions cleanly to a Flutter splash).
///   2) Runs all heavy initialization in the background with strict
///      per-step timeouts.
///   3) Falls back to the home screen after a hard ceiling, so the app
///      can NEVER be stuck on this screen indefinitely — even if Firebase,
///      FCM, the background service, or the network is misbehaving.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _statusMessage = 'Starting up…';

  @override
  void initState() {
    super.initState();
    // Kick off initialization on the next frame so the splash paints first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runInitialization();
    });
  }

  /// Runs initialization with a hard ceiling so the splash can NEVER hang.
  Future<void> _runInitialization() async {
    final InitializationResult result = await _initializeWithTimeout();
    if (!mounted) return;
    _navigateToNext(result);
  }

  Future<InitializationResult> _initializeWithTimeout() async {
    // Hard ceiling — even if every individual step times out, we still
    // navigate after this duration.
    return _doInitialize().timeout(
      _totalInitTimeout,
      onTimeout: () {
        debugPrint(
          '⏱️ [SplashScreen] Hard ceiling reached '
          '(${_totalInitTimeout.inSeconds}s). Forcing navigation to home.',
        );
        return InitializationResult(
          uid: null,
          showOnboarding: false,
          hadErrors: true,
          errors: const ['Global initialization timeout'],
        );
      },
    );
  }

  Future<InitializationResult> _doInitialize() async {
    final errors = <String>[];

    // ── Step 1: Firebase ───────────────────────────────────────────────────
    try {
      await Firebase.initializeApp().timeout(_firebaseTimeout);
    } on TimeoutException {
      _updateStatus('Network slow — skipping Firebase…');
      errors.add('Firebase init timeout');
      debugPrint('⚠️ [SplashScreen] Firebase.initializeApp timed out');
    } catch (e) {
      errors.add('Firebase init: $e');
      debugPrint('❌ [SplashScreen] Firebase.initializeApp failed: $e');
    }

    // ── Step 2: Google Sign-In ─────────────────────────────────────────────
    try {
      await GoogleSignIn.instance.initialize().timeout(_googleSignInTimeout);
    } on TimeoutException {
      errors.add('GoogleSignIn init timeout');
      debugPrint('⚠️ [SplashScreen] GoogleSignIn timed out');
    } catch (e) {
      errors.add('GoogleSignIn: $e');
      debugPrint('❌ [SplashScreen] GoogleSignIn failed: $e');
    }

    // ── Step 3: Mobile Ads ─────────────────────────────────────────────────
    try {
      await MobileAds.instance.initialize().timeout(_adsTimeout);
    } on TimeoutException {
      errors.add('MobileAds init timeout');
      debugPrint('⚠️ [SplashScreen] MobileAds timed out');
    } catch (e) {
      errors.add('MobileAds: $e');
      debugPrint('❌ [SplashScreen] MobileAds failed: $e');
    }

    // ── Step 4: Local Storage (assets cache) ───────────────────────────────
    try {
      await LocalStorageService().initialize().timeout(_localStorageTimeout);
    } on TimeoutException {
      errors.add('LocalStorage timeout');
      debugPrint('⚠️ [SplashScreen] LocalStorage timed out');
    } catch (e) {
      errors.add('LocalStorage: $e');
      debugPrint('❌ [SplashScreen] LocalStorage failed: $e');
    }

    // ── Step 5: Ad Service (loads rewarded ad) ─────────────────────────────
    try {
      _updateStatus('Preparing ads…');
      await AdService().initialize().timeout(_adServiceTimeout);
    } on TimeoutException {
      errors.add('AdService timeout');
      debugPrint('⚠️ [SplashScreen] AdService timed out (non-fatal)');
    } catch (e) {
      errors.add('AdService: $e');
      debugPrint('❌ [SplashScreen] AdService failed (non-fatal): $e');
    }

    // ── Step 6: Notification Service ───────────────────────────────────────
    try {
      _updateStatus('Setting up notifications…');
      await NotificationService().initialize().timeout(_notificationTimeout);
    } on TimeoutException {
      errors.add('NotificationService timeout');
      debugPrint('⚠️ [SplashScreen] NotificationService timed out');
    } catch (e) {
      errors.add('NotificationService: $e');
      debugPrint('❌ [SplashScreen] NotificationService failed: $e');
    }

    // ── Step 7: User initialization (Auth, Firestore, Remote Config) ──────
    String? uid;
    try {
      _updateStatus('Signing you in…');
      final AppInitializer initializer = AppInitializer();
      uid = await initializer.initializeUser().timeout(_userInitTimeout);
    } on TimeoutException {
      errors.add('User init timeout');
      debugPrint('⚠️ [SplashScreen] User init timed out');
    } catch (e) {
      errors.add('User init: $e');
      debugPrint('❌ [SplashScreen] User init failed: $e');
    }

    // ── Step 8: Onboarding check ───────────────────────────────────────────
    bool onboardingDone = false;
    try {
      onboardingDone = await OnboardingPage.hasCompleted().timeout(
        _onboardingCheckTimeout,
      );
    } on TimeoutException {
      debugPrint(
        '⚠️ [SplashScreen] Onboarding check timed out — assuming done',
      );
      onboardingDone = true;
    } catch (e) {
      debugPrint('❌ [SplashScreen] Onboarding check failed: $e');
      onboardingDone = true;
    }

    // ── Step 9: Background service (fire-and-forget) ──────────────────────
    // We do NOT await this in the splash — it's a long-running service that
    // can take several seconds on first launch. Run it in the background so
    // it can never block the splash.
    unawaited(_initializeBackgroundServiceSafely());

    return InitializationResult(
      uid: uid,
      showOnboarding: !onboardingDone,
      hadErrors: errors.isNotEmpty,
      errors: errors,
    );
  }

  /// Wraps the background-service setup with a timeout + try/catch so even
  /// if it hangs, it never affects the splash navigation.
  Future<void> _initializeBackgroundServiceSafely() async {
    try {
      await BackgroundGenerationService().initializeBackgroundService().timeout(
        _bgServiceTimeout,
      );
      // resumePendingGenerations makes HTTP calls — let it run on its own.
      unawaited(
        BackgroundGenerationService().resumePendingGenerations().catchError((
          Object e,
        ) {
          debugPrint('⚠️ [SplashScreen] resumePendingGenerations failed: $e');
        }),
      );
    } on TimeoutException {
      debugPrint(
        '⚠️ [SplashScreen] Background service init timed out '
        '— continuing in background',
      );
    } catch (e) {
      debugPrint('❌ [SplashScreen] Background service init failed: $e');
    }
  }

  void _updateStatus(String message) {
    if (!mounted) return;
    setState(() => _statusMessage = message);
  }

  void _navigateToNext(InitializationResult result) {
    debugPrint(
      '✅ [SplashScreen] Initialization complete. '
      'uid=${result.uid}, showOnboarding=${result.showOnboarding}, '
      'hadErrors=${result.hadErrors}',
    );

    if (result.hadErrors) {
      debugPrint('⚠️ [SplashScreen] Init errors: ${result.errors}');
    }

    // Always navigate — never leave the user stuck.
    // The UID is already published to UserSession.instance.uid by
    // AppInitializer.initializeUser(), so MainNavigation does not need it.
    if (result.showOnboarding) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const OnboardingPage()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const MainNavigation()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always use dark theme for the splash screen
    const Color bgColor = Color(0xFF161616);
    const Color textColor = Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // App icon / logo. Falls back gracefully if the asset is missing.
              Image.asset(
                'assets/images/app_logo.png',
                width: 120,
                height: 120,
                errorBuilder: (_, __, ___) => Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF16E14).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 64,
                    color: Color(0xFFF16E14),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Trail AI Studio',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFF16E14)),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _statusMessage,
                style: TextStyle(
                  fontSize: 14,
                  color: textColor.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
