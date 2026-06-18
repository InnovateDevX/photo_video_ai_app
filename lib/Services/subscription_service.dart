import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:trail_ai_app/Services/remote_config_service.dart';
import 'credit_service.dart';

/// Entitlement IDs — Must match what is set in RevenueCat Dashboard.
const String kEntitlementPro = 'pro';
const String kEntitlementUltra = 'ultra';

class SubscriptionService {
  // ── Singleton ────────────────────────────────────────────────────────────────
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  // ── State ────────────────────────────────────────────────────────────────────
  bool _isSubscribed = false;
  bool get isSubscribed => _isSubscribed;

  bool _isUltra = false;
  bool get isUltra => _isUltra;

  Offerings? _offerings;
  Offerings? get offerings => _offerings;

  CustomerInfo? _customerInfo;
  CustomerInfo? get customerInfo => _customerInfo;

  final StreamController<bool> _subscriptionStreamController =
      StreamController<bool>.broadcast();

  Stream<bool> get subscriptionStream => _subscriptionStreamController.stream;

  // ── Local cache key ──────────────────────────────────────────────────────────
  static const String _localSubKey = 'is_subscribed';

  // ── Init ─────────────────────────────────────────────────────────────────────

  /// Configuration. Needs to be called with API keys from Remote Config.
  Future<void> initialize() async {
    final config = RemoteConfigService();
    String apiKey = Platform.isIOS ? config.rcIosKey : config.rcAndroidKey;

    if (apiKey.isEmpty) {
      debugPrint(
        '⚠️ [SubscriptionService] RevenueCat API Key is empty. Configuration skipped.',
      );
      return;
    }

    try {
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);
      debugPrint(
        '🛒 [SubscriptionService] FULL API KEY FROM FIREBASE: [$apiKey]',
      );
      debugPrint(
        '🛒 [SubscriptionService] API Key (first 5): ${apiKey.substring(0, 5.clamp(0, apiKey.length))}...',
      );
      PurchasesConfiguration configuration = PurchasesConfiguration(apiKey);
      await Purchases.configure(configuration);
      debugPrint('🛒 [SubscriptionService] Purchases configured successfully.');

      // Load local cache for instant UI
      final prefs = await SharedPreferences.getInstance();
      _isSubscribed = prefs.getBool(_localSubKey) ?? false;
      _subscriptionStreamController.add(_isSubscribed);
      debugPrint(
        '🛒 [SubscriptionService] Local cache loaded - subscribed: $_isSubscribed',
      );

      // 0. Force refresh cache (important if entitlements were just created)
      debugPrint(
        '🛒 [SubscriptionService] Invalidating cache to force-fetch latest metadata...',
      );
      await Purchases.invalidateCustomerInfoCache();

      // 1. Fetch Offerings (This often triggers a metadata sync)
      // Wrapped in its own try-catch so a ConfigurationError doesn't kill the whole init
      try {
        debugPrint(
          '🛒 [SubscriptionService] Pre-fetching offerings to sync metadata...',
        );
        _offerings = await Purchases.getOfferings();
        debugPrint(
          '🛒 [SubscriptionService] Offerings pre-fetched: ${_offerings?.current?.identifier}',
        );
      } catch (offeringsError) {
        debugPrint(
          '⚠️ [SubscriptionService] Offerings pre-fetch failed (non-fatal): $offeringsError',
        );
        // This is NOT fatal — the rest of init (customer info, listener) must still proceed
      }

      // 2. Fetch latest customer info
      _customerInfo = await Purchases.getCustomerInfo();
      _updateSubscriptionStatus(_customerInfo!);

      // Listen for changes
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        debugPrint(
          '🛒 [SubscriptionService] CustomerInfo updated listener triggered.',
        );
        _customerInfo = customerInfo;
        _updateSubscriptionStatus(customerInfo);
      });

      debugPrint('🛒 [SubscriptionService] Initialization complete.');
      debugPrint(
        '🛒 [SubscriptionService] Current User ID: ${await Purchases.appUserID}',
      );
    } catch (e) {
      debugPrint('❌ [SubscriptionService] Configuration failed: $e');
    }
  }

  /// Logs in the user to RevenueCat to sync billing history with the Firebase UID.
  Future<void> logIn(String uid) async {
    try {
      LogInResult result = await Purchases.logIn(uid);
      _customerInfo = result.customerInfo;
      _updateSubscriptionStatus(_customerInfo!);
      debugPrint('🛒 [SubscriptionService] User logged in: $uid');
    } catch (e) {
      debugPrint('❌ [SubscriptionService] LogIn failed: $e');
    }
  }

  /// Load available offerings from RevenueCat.
  Future<Offerings?> loadOfferings() async {
    try {
      debugPrint('🛒 [SubscriptionService] Loading offerings...');
      _offerings = await Purchases.getOfferings();
      if (_offerings != null) {
        debugPrint(
          '🛒 [SubscriptionService] Offerings loaded. Current: ${_offerings?.current?.identifier}',
        );
        for (var o in _offerings!.all.values) {
          debugPrint(
            '   Offering: ${o.identifier} has ${o.availablePackages.length} packages',
          );
        }
      } else {
        debugPrint('⚠️ [SubscriptionService] Offerings came back null.');
      }
      return _offerings;
    } catch (e) {
      debugPrint('❌ [SubscriptionService] Failed to load offerings: $e');
      return null;
    }
  }

  // ── Purchase ─────────────────────────────────────────────────────────────────

  /// Initiates a purchase for a RevenueCat [Package].
  Future<String?> buyPackage(Package package) async {
    try {
      debugPrint(
        '🛒 [SubscriptionService] Starting purchase for package: ${package.identifier} (${package.packageType})',
      );
      PurchaseResult result = await Purchases.purchase(
        PurchaseParams.package(package),
      );

      debugPrint('🛒 [SubscriptionService] Purchase call completed.');
      _customerInfo = result.customerInfo;
      _updateSubscriptionStatus(result.customerInfo);
      return null; // success
    } catch (e) {
      debugPrint('❌ [SubscriptionService] Purchase error: $e');
      if (e is PlatformException) {
        debugPrint(
          '   Code: ${e.code}, Message: ${e.message}, Details: ${e.details}',
        );
        if (e.code == '1') return 'CANCELED';
      }
      return e.toString();
    }
  }

  /// Restore purchases.
  Future<void> restorePurchases() async {
    try {
      debugPrint('🛒 [SubscriptionService] Restoring purchases...');
      CustomerInfo customerInfo = await Purchases.restorePurchases();
      debugPrint('🛒 [SubscriptionService] Restore complete.');
      _customerInfo = customerInfo;
      _updateSubscriptionStatus(customerInfo);
    } catch (e) {
      debugPrint('❌ [SubscriptionService] restorePurchases failed: $e');
    }
  }

  // ── Internal ─────────────────────────────────────────────────────────────────

  int _getCreditsForProduct(String productId) {
    try {
      final jsonStr = RemoteConfigService().rcCreditsMapJson;
      final Map<String, dynamic> map = jsonDecode(jsonStr);
      // Try to find the exact productId in the map, otherwise fallback to 999999
      return (map[productId] as int?) ?? 999999;
    } catch (e) {
      debugPrint('⚠️ [SubscriptionService] Error parsing rc_credits_map: $e');
      return 999999;
    }
  }

  void _updateSubscriptionStatus(CustomerInfo customerInfo) async {
    debugPrint('🛒 [SubscriptionService] Updating status.');
    debugPrint(
      '   - All Entitlements in RC: ${customerInfo.entitlements.all.keys}',
    );
    debugPrint(
      '   - Active Entitlements in RC: ${customerInfo.entitlements.active.keys}',
    );

    // Check for entitlements
    final EntitlementInfo? proEntitlement =
        customerInfo.entitlements.active[kEntitlementPro];
    final EntitlementInfo? ultraEntitlement =
        customerInfo.entitlements.active[kEntitlementUltra];

    final bool isPro = proEntitlement != null;
    final bool isUltraTier = ultraEntitlement != null;

    bool shouldBeSubscribed = isPro || isUltraTier;
    debugPrint(
      '🛒 [SubscriptionService] Status check: Pro=$isPro, Ultra=$isUltraTier -> shouldBeSubscribed=$shouldBeSubscribed',
    );

    if (shouldBeSubscribed != _isSubscribed || isUltraTier != _isUltra) {
      _isSubscribed = shouldBeSubscribed;
      _isUltra = isUltraTier;

      // 1. Local cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_localSubKey, _isSubscribed);

      // 2. Grant credits based on the product ID that unlocked the entitlement
      if (_isSubscribed) {
        // Use the product ID from the active entitlement to look up the credit reward
        String? activeProductId =
            ultraEntitlement?.productIdentifier ??
            proEntitlement?.productIdentifier;

        if (activeProductId != null) {
          int creditsToGrant = _getCreditsForProduct(activeProductId);
          await CreditService().setCredits(creditsToGrant);
          debugPrint(
            '🛒 [SubscriptionService] Granted $creditsToGrant credits for product: $activeProductId',
          );
        }
      }

      _subscriptionStreamController.add(_isSubscribed);
      debugPrint(
        '🛒 [SubscriptionService] Status Updated — Subscribed: $_isSubscribed, Ultra: $_isUltra',
      );
    }
  }

  void dispose() {
    _subscriptionStreamController.close();
  }
}
