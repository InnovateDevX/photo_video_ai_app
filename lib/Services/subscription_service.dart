import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trail_ai_app/Services/remote_config_service.dart';
import 'package:trail_ai_app/repositories/user_repository.dart';
import 'package:trail_ai_app/Core/user_session.dart';
import 'credit_service.dart';

class SubscriptionService {
  // ── Singleton ────────────────────────────────────────────────────────────────
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  // ── State ────────────────────────────────────────────────────────────────────
  bool _isSubscribed = false;
  bool get isSubscribed => _isSubscribed;

  final bool _isUltra = false;
  bool get isUltra => _isUltra;

  /// The loaded product details (weekly, monthly) from Google Play.
  final Map<String, ProductDetails> _products = {};
  Map<String, ProductDetails> get products => _products;

  final StreamController<bool> _subscriptionStreamController =
      StreamController<bool>.broadcast();
  Stream<bool> get subscriptionStream => _subscriptionStreamController.stream;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;

  // ── Local cache key ──────────────────────────────────────────────────────────
  static const String _localSubKey = 'is_subscribed';

  // ── Init ─────────────────────────────────────────────────────────────────────

  /// Initialize the in-app purchase connection and listen for purchase updates.
  Future<void> initialize() async {
    debugPrint('🛒 [SubscriptionService] Initializing native IAP...');

    final bool available = await InAppPurchase.instance.isAvailable();
    if (!available) {
      debugPrint(
        '⚠️ [SubscriptionService] In-app purchases NOT available on this device.',
      );
      return;
    }

    // Load local cache
    final prefs = await SharedPreferences.getInstance();
    _isSubscribed = prefs.getBool(_localSubKey) ?? false;
    debugPrint(
      '🛒 [SubscriptionService] Local cache: subscribed=$_isSubscribed',
    );

    // Listen for purchase updates
    _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) {
        debugPrint('❌ [SubscriptionService] Purchase stream error: $error');
      },
    );

    // Load product details from Google Play
    await loadProducts();

    debugPrint('🛒 [SubscriptionService] Initialization complete.');
  }

  // ── Load Products ────────────────────────────────────────────────────────────

  /// Fetches product details (prices in local currency) from Google Play.
  Future<void> loadProducts() async {
    try {
      final config = RemoteConfigService();
      final weeklyId = config.proWeekly;
      final monthlyId = config.proMonthly;

      final Set<String> ids = {};
      if (weeklyId.isNotEmpty) ids.add(weeklyId);
      if (monthlyId.isNotEmpty) ids.add(monthlyId);

      if (ids.isEmpty) {
        debugPrint(
          '⚠️ [SubscriptionService] No product IDs configured in Remote Config.',
        );
        return;
      }

      debugPrint('🛒 [SubscriptionService] Querying products: $ids');

      final ProductDetailsResponse response = await InAppPurchase.instance
          .queryProductDetails(ids);

      if (response.error != null) {
        debugPrint(
          '❌ [SubscriptionService] Error querying products: ${response.error}',
        );
      }

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint(
          '⚠️ [SubscriptionService] Products NOT found: ${response.notFoundIDs}',
        );
      }

      _products.clear();
      for (final product in response.productDetails) {
        _products[product.id] = product;
        debugPrint(
          '🛒 [SubscriptionService] Product loaded: ${product.id} → ${product.price}',
        );
      }
    } catch (e) {
      debugPrint('❌ [SubscriptionService] Failed to load products: $e');
    }
  }

  // ── Purchase ─────────────────────────────────────────────────────────────────

  /// Initiates a subscription purchase for the given [ProductDetails].
  /// Returns null on success, 'CANCELED' if user cancelled, or error string.
  Future<String?> buyProduct(ProductDetails product) async {
    try {
      debugPrint(
        '🛒 [SubscriptionService] Starting purchase for: ${product.id} (${product.price})',
      );
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
      );
      // Use buyNonConsumable for subscriptions
      final bool success = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
      debugPrint(
        '🛒 [SubscriptionService] buyNonConsumable returned: $success',
      );
      return null; // The actual result comes via the purchaseStream
    } catch (e) {
      debugPrint('❌ [SubscriptionService] Purchase error: $e');
      return e.toString();
    }
  }

  /// Restore previous purchases.
  Future<void> restorePurchases() async {
    try {
      debugPrint('🛒 [SubscriptionService] Restoring purchases...');
      await InAppPurchase.instance.restorePurchases();
      debugPrint('🛒 [SubscriptionService] Restore initiated.');
    } catch (e) {
      debugPrint('❌ [SubscriptionService] restorePurchases failed: $e');
    }
  }

  // ── Internal ─────────────────────────────────────────────────────────────────

  /// Handles incoming purchase updates from the native billing stream.
  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      debugPrint(
        '🛒 [SubscriptionService] Purchase update: '
        'productID=${purchase.productID}, '
        'status=${purchase.status}',
      );

      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _completePurchase(purchase);
          break;
        case PurchaseStatus.error:
          debugPrint(
            '❌ [SubscriptionService] Purchase error: ${purchase.error}',
          );
          if (purchase.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(purchase);
          }
          break;
        case PurchaseStatus.canceled:
          debugPrint('🛒 [SubscriptionService] Purchase canceled by user.');
          if (purchase.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(purchase);
          }
          break;
        case PurchaseStatus.pending:
          debugPrint('🛒 [SubscriptionService] Purchase pending...');
          break;
      }
    }
  }

  /// Completes a successful purchase: grants credits, updates Firestore, caches locally.
  Future<void> _completePurchase(PurchaseDetails purchase) async {
    try {
      // 1. Complete the purchase with Google Play (REQUIRED)
      if (purchase.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchase);
        debugPrint('🛒 [SubscriptionService] Purchase completed with store.');
      }

      // 2. Grant credits
      final int creditsToGrant = _getCreditsForProduct(purchase.productID);
      await CreditService().setCredits(creditsToGrant);
      debugPrint(
        '🛒 [SubscriptionService] Granted $creditsToGrant credits for: ${purchase.productID}',
      );

      // 3. Update subscription state
      _isSubscribed = true;
      _subscriptionStreamController.add(true);

      // 4. Persist locally
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_localSubKey, true);

      // 5. Update Firestore pro status
      final uid = UserSession.instance.uid;
      if (uid != null) {
        await UserRepository().updateProStatus(
          uid,
          true,
          productId: purchase.productID,
        );
        debugPrint(
          '🛒 [SubscriptionService] Firestore isPro updated for uid=$uid',
        );
      }

      debugPrint(
        '🛒 [SubscriptionService] ✅ Purchase fully processed: ${purchase.productID}',
      );
    } catch (e) {
      debugPrint('❌ [SubscriptionService] _completePurchase failed: $e');
    }
  }

  int _getCreditsForProduct(String productId) {
    try {
      final jsonStr = RemoteConfigService().rcCreditsMapJson;
      final Map<String, dynamic> map = jsonDecode(jsonStr);
      return (map[productId] as int?) ?? 999999;
    } catch (e) {
      debugPrint('⚠️ [SubscriptionService] Error parsing rc_credits_map: $e');
      return 999999;
    }
  }

  /// Syncs the local subscription state with the database.
  Future<void> syncIsSubscribed(bool isSubscribed) async {
    if (_isSubscribed != isSubscribed) {
      _isSubscribed = isSubscribed;
      _subscriptionStreamController.add(isSubscribed);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_localSubKey, isSubscribed);
      debugPrint('🛒 [SubscriptionService] Synced isSubscribed from DB: $isSubscribed');
    }
  }

  void dispose() {
    _purchaseSubscription?.cancel();
    _subscriptionStreamController.close();
  }
}
