import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:vidzeon/Core/app_initializer.dart';
import 'package:vidzeon/Core/gradient.dart';

import 'package:vidzeon/Services/notification_service.dart';
import 'package:vidzeon/Services/local_storage_service.dart';
import 'package:vidzeon/Services/background_generation_service.dart';
import 'package:vidzeon/Services/data_service.dart';
import 'package:vidzeon/firebase_options.dart';
import 'package:vidzeon/pages/onboarding_page.dart';
import 'package:vidzeon/Widgets/main_navigation.dart';
import 'package:vidzeon/Widgets/main_navigation_with_paywall.dart';
import 'package:vidzeon/Services/subscription_service.dart';
import 'package:vidzeon/Services/connectivity_service.dart';
import 'package:vidzeon/Services/paywall_video_cache.dart';
import 'package:vidzeon/Helpers/error_dialog_helper.dart';
import 'package:vidzeon/Services/remote_config_service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

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
const Duration _totalInitTimeout = Duration(seconds: 25);

const Duration _firebaseTimeout = Duration(seconds: 10);
const Duration _googleSignInTimeout = Duration(seconds: 8);
const Duration _localStorageTimeout = Duration(seconds: 4);
const Duration _notificationTimeout = Duration(seconds: 6);
const Duration _userInitTimeout = Duration(seconds: 12);
const Duration _onboardingCheckTimeout = Duration(seconds: 3);
const Duration _bgServiceTimeout = Duration(seconds: 6);
const Duration _dataServiceTimeout = Duration(seconds: 8);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  String _statusMessage = 'Getting things ready…';

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.2, end: 0.6).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runInitialization();
    });
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _runInitialization() async {
    _updateStatus('Checking connection…');

    bool hasInternet = await _checkInternetConnection();
    if (!mounted) return;

    if (!hasInternet) {
      ErrorDialogHelper.showNoInternetRetryDialog(context, () {
        Navigator.of(context).pop();
        _runInitialization();
      });
      return;
    }

    ConnectivityService().initialize();

    final stopwatch = Stopwatch()..start();
    final InitializationResult result = await _initializeWithTimeout();

    final elapsedMs = stopwatch.elapsedMilliseconds;
    const minSplashDurationMs = 2000;
    if (elapsedMs < minSplashDurationMs) {
      await Future.delayed(
        Duration(milliseconds: minSplashDurationMs - elapsedMs),
      );
    }

    if (!mounted) return;
    _navigateToNext(result);
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup(
        'example.com',
      ).timeout(const Duration(seconds: 5));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) return true;
    } catch (_) {
      return false;
    }
    return false;
  }

  Future<InitializationResult> _initializeWithTimeout() async {
    return _doInitialize().timeout(
      _totalInitTimeout,
      onTimeout: () {
        debugPrint(
          '⏱️ [SplashScreen] Hard ceiling reached. Forcing navigation.',
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

    // Step 1: Firebase
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(_firebaseTimeout);

      // Reduce Firebase Storage retry timeouts so failed loads fail fast
      // instead of hanging the screen for minutes on flaky networks.
      FirebaseStorage.instance.setMaxDownloadRetryTime(
        const Duration(seconds: 10),
      );
      FirebaseStorage.instance.setMaxUploadRetryTime(
        const Duration(seconds: 10),
      );
      FirebaseStorage.instance.setMaxOperationRetryTime(
        const Duration(seconds: 10),
      );
    } on TimeoutException {
      _updateStatus('Almost there…');
      errors.add('Firebase init timeout');
    } catch (e) {
      errors.add('Firebase init: $e');
    }

    // Step 2: Google Sign-In
    try {
      await GoogleSignIn.instance.initialize().timeout(_googleSignInTimeout);
    } on TimeoutException {
      errors.add('GoogleSignIn init timeout');
    } catch (e) {
      errors.add('GoogleSignIn: $e');
    }

    // Step 4: Local Storage
    try {
      await LocalStorageService().initialize().timeout(_localStorageTimeout);
    } on TimeoutException {
      errors.add('LocalStorage timeout');
    } catch (e) {
      errors.add('LocalStorage: $e');
    }

    // Step 6: Notification Service
    try {
      _updateStatus('Just a moment…');
      await NotificationService().initialize().timeout(_notificationTimeout);
    } on TimeoutException {
      errors.add('NotificationService timeout');
    } catch (e) {
      errors.add('NotificationService: $e');
    }

    // Step 7: User initialization
    String? uid;
    try {
      _updateStatus('Getting things ready…');
      final AppInitializer initializer = AppInitializer();
      uid = await initializer.initializeUser().timeout(_userInitTimeout);

      unawaited(
        PaywallVideoCache().preload().catchError((Object e) {
          debugPrint('⚠️ [SplashScreen] Paywall video preload failed: $e');
        }),
      );

      final genPageVideoUrl = RemoteConfigService().generationPageVideo;
      if (genPageVideoUrl.isNotEmpty) {
        unawaited(() async {
          try {
            await DefaultCacheManager().downloadFile(genPageVideoUrl);
            debugPrint('🎬 [SplashScreen] Generation video preloaded ✅');
          } catch (e) {
            debugPrint('⚠️ [SplashScreen] Generation video preload failed: $e');
          }
        }());
      }
    } on TimeoutException {
      errors.add('User init timeout');
    } catch (e) {
      errors.add('User init: $e');
    }

    // Step 8: Onboarding check
    bool onboardingDone = false;
    try {
      onboardingDone = await OnboardingPage.hasCompleted().timeout(
        _onboardingCheckTimeout,
      );
    } on TimeoutException {
      onboardingDone = true;
    } catch (e) {
      onboardingDone = true;
    }

    // Step 9: DataService
    try {
      _updateStatus('Finishing up…');
      await DataService().initialize().timeout(_dataServiceTimeout);
    } on TimeoutException {
      errors.add('DataService timeout');
    } catch (e) {
      errors.add('DataService: $e');
    }

    // Step 10: Removed Background service initialization
    // App will only poll Replicate in foreground.
    unawaited(
      BackgroundGenerationService().resumePendingGenerations().catchError((
        Object e,
      ) {
        debugPrint('⚠️ [SplashScreen] resumePendingGenerations failed: $e');
      }),
    );

    return InitializationResult(
      uid: uid,
      showOnboarding: !onboardingDone,
      hadErrors: errors.isNotEmpty,
      errors: errors,
    );
  }

  void _updateStatus(String message) {
    if (!mounted) return;
    setState(() => _statusMessage = message);
  }

  bool _hasNavigated = false;

  void _navigateToNext(InitializationResult result) {
    if (!mounted || _hasNavigated) return;
    _hasNavigated = true;

    if (result.hadErrors) {
      debugPrint('⚠️ [SplashScreen] Init errors: ${result.errors}');
    }

    if (result.showOnboarding) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const OnboardingPage()),
      );
      return;
    }

    final bool isPaid = SubscriptionService().isSubscribed;

    if (!isPaid) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const MainNavigationWithPaywall(),
        ),
      );
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const MainNavigation()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        extendBodyBehindAppBar: true,
        body: Container(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // ── Center content: icon + text ─────────────────────
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // App icon
                    ClipRRect(
                      borderRadius: BorderRadius.circular(w * 0.065),
                      child: Image.asset(
                        'assets/images/app_logo.png',
                        width: w * 0.27,
                        height: w * 0.27,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: w * 0.27,
                          height: w * 0.27,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(w * 0.065),
                          ),
                          child: Icon(
                            Icons.auto_awesome,
                            size: w * 0.13,
                            color: const Color(0xFFF16E14),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: h * 0.02),

                    // App name
                    const Text(
                      'VidZeon',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Bottom progress bar + status text ────────────────────────
              Positioned(
                left: w * 0.12,
                right: w * 0.12,
                bottom: h * 0.08,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Orange tagline
                    Text(
                      'CREATE. EDIT. INSPIRE.',
                      style: TextStyle(
                        color: const Color(0xFFD66031),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2.8,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        backgroundColor: const Color(0xFF2A2A2A),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppGradients.proGradient.colors.last,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Color(0xFF888888),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
