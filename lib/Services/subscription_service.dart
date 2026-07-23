import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
// TODO: Confirm this import path/package name matches your Adjust SDK dependency.
import 'package:adjust_sdk/adjust.dart';
import 'package:adjust_sdk/adjust_play_store_subscription.dart';
import 'credit_service.dart';
import '../repositories/subscription_ledger_repository.dart';
import '../repositories/user_repository.dart';
import '../Core/user_session.dart';

class RestoreResult {
  final bool success;
  final String message;

  RestoreResult({required this.success, required this.message});
}

class SubscriptionService {
  // ── Singleton ────────────────────────────────────────────────────────────────
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  // ── Product & Offer IDs (match Google Play Console exactly) ────────────────
  static const String weeklyProductId = 'vidzeon_pro_weekly';
  static const String monthlyProductId = 'vidzeon_pro_monthly';
  static const String weeklyOfferId = 'vidzeonproweeklytrial';
  static const String monthlyOfferId = 'vidzeonpromonthlytrial';

  // ── State ────────────────────────────────────────────────────────────────────
  bool _isSubscribed = false;
  bool get isSubscribed => _isSubscribed;

  /// A [ValueNotifier] that mirrors [isSubscribed]. Widgets can use
  /// [ValueListenableBuilder] on this instead of managing their own
  /// [StreamSubscription] on [subscriptionStream].
  final ValueNotifier<bool> isSubscribedNotifier = ValueNotifier<bool>(false);

  final bool _isUltra = false;
  bool get isUltra => _isUltra;

  /// The loaded product details (weekly, monthly) from Google Play.
  /// Stored as [ProductDetails] (the cross-platform type).
  final Map<String, ProductDetails> _products = {};
  Map<String, ProductDetails> get products => _products;

  /// A list of all raw product details (including all base plans/offers) returned by Google Play.
  List<ProductDetails> _rawStoreProducts = [];

  /// The selected offer (base plan + offer) for each product ID.
  /// Uses the Android-specific wrapper type for full access to offer details.
  final Map<String, SubscriptionOfferDetailsWrapper> _selectedOffers = {};
  Map<String, SubscriptionOfferDetailsWrapper> get selectedOffers =>
      _selectedOffers;

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

    // We no longer rely on local cache; always check Google Play Billing.
    _isSubscribed = false;
    isSubscribedNotifier.value = _isSubscribed;

    // Listen for purchase updates
    _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (error) {
        debugPrint('❌ [SubscriptionService] Purchase stream error: $error');
      },
    );

    // Load product details from Google Play
    await loadProducts();

    // Verify active paid subscription with Google Play Billing API on startup
    await verifySubscriptionOnStartup();

    debugPrint('🛒 [SubscriptionService] Initialization complete.');
  }

  /// Verifies active subscription status with Google Play Billing API on startup.
  /// If an active paid subscription exists, maintains pro privileges & credits.
  /// If no active paid subscription exists, revokes pro status, sets credits to 0, and re-enables paywalls.
  Future<void> verifySubscriptionOnStartup() async {
    debugPrint(
      '🛒 [SubscriptionService] Verifying active subscription with Google Play...',
    );
    try {
      bool activePurchaseFound = false;

      final sub = InAppPurchase.instance.purchaseStream.listen((purchases) {
        for (final p in purchases) {
          if ((p.status == PurchaseStatus.purchased ||
                  p.status == PurchaseStatus.restored) &&
              p.productID.isNotEmpty) {
            activePurchaseFound = true;
          }
        }
      });

      await InAppPurchase.instance.restorePurchases();
      await Future.delayed(const Duration(milliseconds: 1500));
      await sub.cancel();

      if (activePurchaseFound) {
        debugPrint(
          '🛒 [SubscriptionService] ✅ Active paid subscription confirmed by Google Play.',
        );
      } else {
        debugPrint(
          '🛒 [SubscriptionService] ⚠️ No active subscription found by Google Play -> Revoking pro status & setting credits to 0.',
        );
        await _revokeSubscription();
      }
    } catch (e) {
      debugPrint(
        '⚠️ [SubscriptionService] verifySubscriptionOnStartup error: $e',
      );
    }
  }

  /// Checks if the user is eligible for a free trial by querying past purchases on Google Play.
  /// If they have any past purchase of the weekly or monthly products, they are NOT eligible.
  Future<bool> isEligibleForTrial() async {
    if (!Platform.isAndroid) return true;
    try {
      final InAppPurchaseAndroidPlatformAddition androidAddition = InAppPurchase
          .instance
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();

      final QueryPurchaseDetailsResponse response = await androidAddition
          .queryPastPurchases();
      if (response.error == null) {
        for (final purchase in response.pastPurchases) {
          // If they have purchased either weekly or monthly before, they aren't eligible for a trial
          if (purchase.productID == weeklyProductId ||
              purchase.productID == monthlyProductId) {
            debugPrint(
              '🛒 [SubscriptionService] User is NOT eligible for trial (found past purchase of ${purchase.productID})',
            );
            return false;
          }
        }
      }
      debugPrint(
        '🛒 [SubscriptionService] User is eligible for trial (no past purchases found)',
      );
      return true;
    } catch (e) {
      debugPrint(
        '⚠️ [SubscriptionService] Error checking trial eligibility: $e',
      );
      return true; // Default to true if the check fails so we don't lock users out
    }
  }

  // ── Load Products ────────────────────────────────────────────────────────────

  /// Fetches product details (prices in local currency) from Google Play.
  /// For each product, selects the best offer and caches it.
  Future<void> loadProducts() async {
    try {
      final Set<String> ids = {weeklyProductId, monthlyProductId};

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
      _selectedOffers.clear();
      _rawStoreProducts = List.from(response.productDetails);

      for (final product in response.productDetails) {
        _products[product.id] = product;

        // Try to extract Android-specific offer details
        final offers = _extractSubscriptionOffers(product);
        if (offers != null) {
          // Log all offers for this product
          debugPrint('🛒 [SubscriptionService] Product loaded: ${product.id}');
          for (int i = 0; i < offers.length; i++) {
            final offer = offers[i];
            debugPrint(
              '  Offer ${i + 1}:'
              ' Base Plan ID=${offer.basePlanId},'
              ' Offer ID=${offer.offerId ?? "null"},'
              ' Offer Token=${offer.offerIdToken}',
            );
          }

          // Select the best offer for this product
          final selectedOffer = selectOffer(product);
          if (selectedOffer != null) {
            _selectedOffers[product.id] = selectedOffer;
            debugPrint(
              '🛒 [SubscriptionService] Selected offer for ${product.id}:'
              ' offerId=${selectedOffer.offerId ?? "null"},'
              ' offerToken=${selectedOffer.offerIdToken}',
            );
          } else {
            debugPrint(
              '⚠️ [SubscriptionService] No offer selected for ${product.id}',
            );
          }
        } else {
          debugPrint(
            '🛒 [SubscriptionService] Product loaded (no offers): ${product.id} → ${product.price}',
          );
        }
      }
    } catch (e) {
      debugPrint('❌ [SubscriptionService] Failed to load products: $e');
    }
  }

  /// Extracts the Android-specific [SubscriptionOfferDetailsWrapper] list from
  /// a [ProductDetails] by casting to [GooglePlayProductDetails].
  List<SubscriptionOfferDetailsWrapper>? _extractSubscriptionOffers(
    ProductDetails product,
  ) {
    if (product is GooglePlayProductDetails) {
      return product.productDetails.subscriptionOfferDetails;
    }
    return null;
  }

  // ── Offer Selection ──────────────────────────────────────────────────────────

  /// Selects the best [SubscriptionOfferDetailsWrapper] for the given
  /// [ProductDetails].
  ///
  /// For weekly products:
  ///   1. Find offer with [offerId] == [weeklyOfferId]
  ///   2. Fallback: first offer with multiple pricing phases (trial + recurring)
  ///   3. Fallback: first offer
  ///
  /// For monthly products:
  ///   1. Find offer with [offerId] == [monthlyOfferId]
  ///   2. Fallback: first offer with multiple pricing phases (trial + recurring)
  ///   3. Fallback: first offer
  SubscriptionOfferDetailsWrapper? selectOffer(ProductDetails product) {
    final offers = _extractSubscriptionOffers(product);
    if (offers == null || offers.isEmpty) return null;

    String? targetOfferId;

    if (product.id == weeklyProductId) {
      targetOfferId = weeklyOfferId;
    } else if (product.id == monthlyProductId) {
      targetOfferId = monthlyOfferId;
    }

    // 1. Try exact offer ID match
    if (targetOfferId != null) {
      for (final offer in offers) {
        if (offer.offerId == targetOfferId) {
          return offer;
        }
      }
    }

    // 2. Fallback: first offer with multiple pricing phases
    for (final offer in offers) {
      if (offer.pricingPhases.length >= 2) {
        return offer;
      }
    }

    // 3. Final fallback
    return offers.first;
  }

  // ── Price Text Helper ────────────────────────────────────────────────────────

  /// Returns a human-readable price string for the given product ID.
  ///
  /// If the selected offer has a trial (2+ pricing phases):
  ///   Returns the recurring price (e.g. "$X.99")
  /// Otherwise:
  ///   Returns the single price (e.g. "$X.99")
  String getPriceText(String productId) {
    final offer = _selectedOffers[productId];
    if (offer != null) {
      final phases = offer.pricingPhases;
      if (phases.isNotEmpty) {
        if (phases.length >= 2) {
          // Trial offer: last phase is the recurring price
          return phases.last.formattedPrice;
        }
        return phases.first.formattedPrice;
      }
    }

    // Fallback to raw product price
    final product = _products[productId];
    return product?.price ?? '\$ —';
  }

  /// Returns the full pricing label for a product, including trial info.
  ///
  /// If the selected offer has a trial (2+ pricing phases):
  ///   "7 Days Trial, then \$X.99 / Week"
  /// Otherwise:
  ///   "Just \$X.99 / Week"
  String getFullPriceLabel(String productId, {bool isTrialEnabled = false}) {
    final offer = _selectedOffers[productId];
    if (offer != null) {
      final phases = offer.pricingPhases;
      if (phases.length >= 2) {
        // Trial + recurring: show the recurring price
        final recurringPrice = phases.last.formattedPrice;
        if (isTrialEnabled) {
          return '7 Days Trial, then $recurringPrice';
        } else {
          return 'Just $recurringPrice';
        }
      }
      if (phases.isNotEmpty) {
        final price = phases.first.formattedPrice;
        return isTrialEnabled ? '7 Days Trial, then $price' : 'Just $price';
      }
    }

    // Fallback
    final product = _products[productId];
    final price = product?.price ?? '\$ —';
    return isTrialEnabled ? '7 Days Trial, then $price' : 'Just $price';
  }

  /// Returns the recurring period label (e.g., "Week", "Month") for a product.
  String getPeriodLabel(String productId) {
    final product = _products[productId];
    if (product == null) return '';

    if (productId == weeklyProductId) return 'Week';
    if (productId == monthlyProductId) return 'Month';
    return '';
  }

  /// Returns a human-readable intro offer label, e.g. "7-Day Intro Offer".
  /// Derives the duration from the first (trial) pricing phase if available.
  String getTrialLabel(String productId) {
    final offer = _selectedOffers[productId];
    if (offer != null && offer.pricingPhases.length >= 2) {
      final trialPhase = offer.pricingPhases.first;
      final period = trialPhase.billingPeriod; // ISO 8601, e.g. "P7D", "P1M"
      final price = trialPhase.formattedPrice;
      final days = _parseDaysFromPeriod(period);
      if (days != null) return '$days-Day Intro Offer for $price';
      return 'Intro Offer for $price';
    }
    return 'Intro Offer';
  }

  /// Returns the recurring price with period, e.g. "Rs 2,800 / week".
  /// Used as the "Then …" line under the intro offer label.
  String getRecurringPriceLabel(String productId) {
    final price = getPriceText(productId);
    final period = getPeriodLabel(productId).toLowerCase();
    if (period.isNotEmpty) return 'Then $price / $period';
    return 'Then $price';
  }

  /// Parses a simple ISO 8601 duration (P7D, P1W, P1M, P30D) into total days.
  int? _parseDaysFromPeriod(String period) {
    if (period.isEmpty) return null;
    final dMatch = RegExp(r'P(\d+)D').firstMatch(period);
    if (dMatch != null) return int.tryParse(dMatch.group(1)!);
    final wMatch = RegExp(r'P(\d+)W').firstMatch(period);
    if (wMatch != null) {
      final weeks = int.tryParse(wMatch.group(1)!);
      return weeks != null ? weeks * 7 : null;
    }
    final mMatch = RegExp(r'P(\d+)M').firstMatch(period);
    if (mMatch != null) {
      final months = int.tryParse(mMatch.group(1)!);
      return months != null ? months * 30 : null;
    }
    return null;
  }

  // ── Purchase ─────────────────────────────────────────────────────────────────

  /// Initiates a subscription purchase for the given [ProductDetails].
  /// Uses the cached selected offer's [offerIdToken] for base-plan + offer
  /// purchases.
  /// Returns null on success, 'CANCELED' if user cancelled, or error string.
  Future<String?> buyProduct(ProductDetails product) async {
    try {
      final selectedOffer = _selectedOffers[product.id];

      debugPrint(
        '🛒 [SubscriptionService] Starting purchase for: ${product.id}'
        '${selectedOffer != null ? ' (offerToken: ${selectedOffer.offerIdToken})' : ' (no offer token)'}',
      );

      ProductDetails purchaseProduct = product;
      if (Platform.isAndroid && selectedOffer != null) {
        final matchingProduct = _rawStoreProducts.firstWhere(
          (p) => p is GooglePlayProductDetails && p.offerToken == selectedOffer.offerIdToken,
          orElse: () => product,
        );
        purchaseProduct = matchingProduct;
      }

      // Use GooglePlayPurchaseParam (Android-specific)
      final GooglePlayPurchaseParam purchaseParam = GooglePlayPurchaseParam(
        productDetails: purchaseProduct,
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
  Future<RestoreResult> restorePurchases() async {
    try {
      debugPrint('🛒 [SubscriptionService] Restoring purchases...');

      bool foundPurchases = false;
      final sub = InAppPurchase.instance.purchaseStream.listen((purchases) {
        if (purchases.isNotEmpty) foundPurchases = true;
      });

      await InAppPurchase.instance.restorePurchases();
      debugPrint(
        '🛒 [SubscriptionService] Native restore initiated. Waiting for stream...',
      );

      // Wait a short moment for the Dart event loop to deliver the stream events
      await Future.delayed(const Duration(milliseconds: 150));
      await sub.cancel();

      if (!foundPurchases) {
        debugPrint('🛒 [SubscriptionService] Native SDK returned 0 purchases.');
        return RestoreResult(
          success: false,
          message: 'No active subscription found.',
        );
      }

      debugPrint(
        '🛒 [SubscriptionService] Found purchases, waiting for backend processing...',
      );
      final restored = await subscriptionStream.first.timeout(
        const Duration(seconds: 15),
      );

      if (restored) {
        return RestoreResult(
          success: true,
          message: 'Purchases restored successfully.',
        );
      } else {
        return RestoreResult(
          success: false,
          message: 'Restore processing failed.',
        );
      }
    } on TimeoutException {
      debugPrint('🛒 [SubscriptionService] Restore processing timed out.');
      return RestoreResult(
        success: false,
        message: 'Restore processing timed out. Please try again.',
      );
    } catch (e) {
      debugPrint('❌ [SubscriptionService] restorePurchases failed: $e');
      return RestoreResult(success: false, message: 'Failed to restore: $e');
    }
  }

  // ── Internal ─────────────────────────────────────────────────────────────────

  /// Handles incoming purchase updates from the native billing stream.
  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      // ── Guard: empty productID — subscription state-change signal ──────────
      // Google Play Billing sends a synthetic PurchaseStatus.purchased event
      // with an EMPTY productID when a subscription is cancelled or expires.
      // This is NOT a real purchase — it's the billing client's way of saying
      // "something changed, re-verify". Route it directly to revocation.
      if (purchase.productID.isEmpty) {
        debugPrint(
          '🛒 [SubscriptionService] Empty-productID event '
          '(status=${purchase.status}) — treating as subscription revocation.',
        );
        if (purchase.pendingCompletePurchase) {
          try {
            await InAppPurchase.instance.completePurchase(purchase);
          } catch (e) {
            debugPrint(
              '⚠️ [SubscriptionService] completePurchase (empty) threw: $e',
            );
          }
        }
        await _revokeSubscription();
        continue;
      }

      debugPrint(
        '🛒 [SubscriptionService] Purchase update: '
        'productID=${purchase.productID}, '
        'status=${purchase.status}',
      );

      switch (purchase.status) {
        case PurchaseStatus.purchased:
          await _completePurchase(purchase);
          break;
        case PurchaseStatus.restored:
          // isRestore=true prevents the ledger fallback from granting credits
          // when Firestore is unreachable — we cannot verify if the token was
          // already processed, so the safe default is to skip extra credits.
          await _completePurchase(purchase, isRestore: true);
          break;
        case PurchaseStatus.error:
          debugPrint(
            '❌ [SubscriptionService] Purchase error: ${purchase.error}',
          );
          if (purchase.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(purchase);
          }
          // Emit false so UI clears its loading spinners.
          _subscriptionStreamController.add(false);
          break;
        case PurchaseStatus.canceled:
          debugPrint('🛒 [SubscriptionService] Purchase canceled by user.');
          if (purchase.pendingCompletePurchase) {
            await InAppPurchase.instance.completePurchase(purchase);
          }
          // Unconditionally revoke Pro status so both UI and Firestore
          // reflect the cancelled state, regardless of what _isSubscribed
          // was before. This covers:
          //   • User cancels the billing dialog (was not subscribed — no-op in DB)
          //   • Google Play reports an active subscription as cancelled
          await _revokeSubscription(productId: purchase.productID);
          break;
        case PurchaseStatus.pending:
          debugPrint('🛒 [SubscriptionService] Purchase pending...');
          break;
      }
    }
  }

  /// Reports a completed purchase to Adjust for subscription attribution.
  /// Non-fatal — Adjust tracking failures must never block the purchase flow.
  void _trackPurchaseWithAdjust(PurchaseDetails purchaseDetails) {
    try {
      final productId = purchaseDetails.productID;

      // Cast generic Flutter In-App Purchase details to Google Play native types
      final googlePurchase = purchaseDetails as GooglePlayPurchaseDetails;

      // Look up the exact offer that was cached/selected for this specific purchase
      final selectedOffer = _selectedOffers[productId];
      final basePhase = selectedOffer?.pricingPhases.firstOrNull;

      if (basePhase == null) {
        debugPrint(
          '⚠️ [SubscriptionService] Adjust tracking skipped — no pricing '
          'phase found for $productId.',
        );
        return;
      }

      // CRITICAL FIX: Convert micros to standard decimal price format (e.g. 1990000 -> "1.99")
      final priceString = (basePhase.priceAmountMicros / 1000000.0).toString();

      final subscription = AdjustPlayStoreSubscription(
        priceString,
        basePhase.priceCurrencyCode,
        productId,
        googlePurchase.billingClientPurchase.orderId,
        googlePurchase.billingClientPurchase.signature,
        googlePurchase.billingClientPurchase.purchaseToken,
      );

      subscription.purchaseTime = googlePurchase
          .billingClientPurchase
          .purchaseTime
          .toString();

      Adjust.trackPlayStoreSubscription(subscription);

      debugPrint(
        '🛒 [SubscriptionService] Adjust tracked Play Store subscription '
        'for product: $productId (Recorded Price: $priceString)',
      );
    } catch (e) {
      debugPrint('⚠️ [SubscriptionService] Adjust IAP tracking exception: $e');
    }
  }

  /// Completes a successful (or restored) purchase.
  ///
  /// Each side-effect runs inside its own try/catch so a failure in one
  /// step never blocks the others.
  ///
  /// [isRestore] — when true, the ledger fallback conservatively skips credit
  /// grants if Firestore is unreachable, preventing duplicate credit grants on
  /// every restore attempt. For new purchases it stays false so over-granting
  /// is preferred over leaving a paying user with nothing.
  ///
  /// Steps:
  ///   1. Acknowledge the purchase with Google Play (mandatory).
  ///   2. Extract the purchase token.
  ///   3. Resolve uid from UserSession.
  ///   4. Write the ledger to Firestore (idempotent). Non-fatal on failure.
  ///   5. Initialize CreditService and grant credits additively (new only).
  ///   6. Write `isPro=true` + productId to users/{uid}. Non-fatal on failure.
  ///   7. Broadcast subscription state so PaywallPage can close.
  ///   8. Persist locally.
  Future<void> _completePurchase(
    PurchaseDetails purchase, {
    bool isRestore = false,
  }) async {
    // Fire-and-forget analytics side-effect — never awaited into the
    // critical path, and internally guarded so it can't throw out here.
    _trackPurchaseWithAdjust(purchase);

    debugPrint(
      '🛒 [SubscriptionService] _completePurchase START for ${purchase.productID}'
      '${isRestore ? ' (RESTORE)' : ' (NEW)'}',
    );

    // ── 1. Acknowledge with Google Play (REQUIRED — must throw to retry) ────
    if (purchase.pendingCompletePurchase) {
      try {
        await InAppPurchase.instance.completePurchase(purchase);
        debugPrint(
          '🛒 [SubscriptionService] ✅ Purchase acknowledged with store.',
        );
      } catch (e) {
        debugPrint('❌ [SubscriptionService] completePurchase threw: $e');
      }
    }

    // ── 2. Extract token ────────────────────────────────────────────────────
    String? token;
    if (purchase.verificationData.serverVerificationData.isNotEmpty) {
      token = purchase.verificationData.serverVerificationData;
    } else {
      token = purchase.purchaseID; // Fallback
    }

    if (token == null || token.isEmpty) {
      debugPrint('❌ [SubscriptionService] Purchase missing token. Aborting.');
      return;
    }

    // ── 3. Resolve uid ──────────────────────────────────────────────────────
    String? uid = UserSession.instance.uid;
    int attempts = 0;
    while (uid == null && attempts < 16) {
      await Future.delayed(const Duration(milliseconds: 250));
      uid = UserSession.instance.uid;
      attempts++;
    }
    if (uid == null) {
      uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        UserSession.instance.uid = uid;
      }
    }
    if (uid == null) {
      try {
        final credential = await FirebaseAuth.instance.signInAnonymously();
        uid = credential.user?.uid;
        if (uid != null) {
          UserSession.instance.uid = uid;
        }
      } catch (e) {
        debugPrint(
          '⚠️ [SubscriptionService] Anonymous auth fallback failed: $e',
        );
      }
    }
    if (uid == null) {
      debugPrint(
        '❌ [SubscriptionService] UserSession.uid could not be resolved. Aborting.',
      );
      return;
    }

    final int creditsToGrant = _getCreditsForProduct(purchase.productID);

    // ── 4. Write ledger — non-fatal ─────────────────────────────────────────
    bool isNew = true;
    int existingCredits = 0;
    try {
      final repo = SubscriptionLedgerRepository();
      debugPrint(
        '🛒 [SubscriptionService] Processing ledger for product=${purchase.productID}, '
        'creditsToGrant=$creditsToGrant, uid=$uid',
      );
      final result = await repo.processPurchase(
        token: token,
        productId: purchase.productID,
        uid: uid,
        initialCredits: creditsToGrant,
        isRestore: isRestore,
      );
      isNew = result.$1;
      existingCredits = result.$2;
      debugPrint(
        '🛒 [SubscriptionService] Ledger result: isNew=$isNew, '
        'existingCredits=$existingCredits',
      );
    } catch (e) {
      debugPrint(
        '⚠️ [SubscriptionService] Ledger write failed (non-fatal): $e. '
        'Continuing with credit grant + Pro flag.',
      );
      // For new purchases, over-grant to avoid leaving the user empty-handed.
      // For restores, conservatively skip credit grant — we cannot verify
      // whether the token was already processed.
      isNew = !isRestore;
    }

    // ── 5. Ensure CreditService ready, then grant credits additively ───────
    try {
      await CreditService().initialize();
      if (isNew) {
        await CreditService().addCredits(creditsToGrant);
        debugPrint(
          '🛒 [SubscriptionService] ✅ NEW purchase. Granted $creditsToGrant '
          'credits additively. New balance=${CreditService().credits}',
        );
      } else {
        if (existingCredits >= 0) {
          // This handles the reinstall + restore flow. The user got a new UID
          // with default sign-up credits, but they restored a past subscription.
          // We overwrite their local balance with the ledger's remaining balance
          // so they don't lose their previous credits (and can't farm credits
          // by reinstalling).
          await CreditService().setCredits(existingCredits);
          debugPrint(
            '🛒 [SubscriptionService] ✅ RESTORED purchase. Synced local credits '
            'with ledger balance ($existingCredits). New balance=${CreditService().credits}',
          );
        } else {
          debugPrint(
            '🛒 [SubscriptionService] ✅ RESTORED purchase. Ledger read failed '
            'so skipping credit sync. Keeping local balance=${CreditService().credits}',
          );
        }
      }
    } catch (e) {
      debugPrint('⚠️ [SubscriptionService] Credit grant failed: $e');
    }

    // ── 6. Persist Pro status to the user doc — non-fatal but critical ──────
    //    Without this, AppInitializer's getProStatus() returns false on next
    //    cold start and the user is shown the paywall again, even though they
    //    just paid. This is what made "subscripting is done but nothing else
    //    updates" happen.
    try {
      final userRepo = UserRepository();
      await userRepo.updateProStatus(uid, true, productId: purchase.productID);

      debugPrint(
        '🛒 [SubscriptionService] ✅ isPro=true written to users/$uid '
        '(product=${purchase.productID}).',
      );
    } catch (e) {
      debugPrint(
        '⚠️ [SubscriptionService] updateProStatus failed (non-fatal): $e',
      );
    }

    // ── 7. Broadcast subscription state — closes the paywall ───────────────
    _isSubscribed = true;
    isSubscribedNotifier.value = true;
    _subscriptionStreamController.add(true);
    debugPrint(
      '🛒 [SubscriptionService] ✅ Broadcast subscriptionStream = true '
      '(paywall should pop).',
    );

    // ── 8. Persist locally ──────────────────────────────────────────────────
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_localSubKey, true);
    } catch (e) {
      debugPrint('⚠️ [SubscriptionService] SharedPreferences write failed: $e');
    }

    debugPrint(
      '🛒 [SubscriptionService] ✅ Purchase fully processed: ${purchase.productID}'
      ' | creditsToGrant=$creditsToGrant | isNew=$isNew'
      ' | finalBalance=${CreditService().credits}',
    );
  }

  int _getCreditsForProduct(String productId) {
    // Credits granted per product (must match Google Play Console)
    const creditsMap = {weeklyProductId: 1500, monthlyProductId: 6000};
    return creditsMap[productId] ?? 0;
  }

  // ── Subscription Revocation ──────────────────────────────────────────────────────

  /// Mirror-image of [_completePurchase]. Called when a subscription is
  /// cancelled or revoked (including when the user dismisses the billing
  /// dialog). Performs each side-effect in its own try/catch so one failure
  /// cannot block the others.
  ///
  /// Steps:
  ///   1. Write [isPro=false] to Firestore users doc.
  ///   2. Set [_isSubscribed = false] + persist to SharedPreferences.
  ///   3. Expire credits.
  ///   4. Broadcast [false] through [subscriptionStream] and [isSubscribedNotifier].
  Future<void> _revokeSubscription({String? productId}) async {
    debugPrint(
      '🛒 [SubscriptionService] _revokeSubscription START (product=${productId ?? 'unknown'})',
    );

    // ── 1. Write isPro=false to Firestore ────────────────────────────────
    final uid = UserSession.instance.uid;
    if (uid != null) {
      try {
        final userRepo = UserRepository();
        // productId may be null when triggered by an empty-productID event
        // (Google Play cancellation signal). updateProStatus handles null
        // by simply not updating the proProductId field.
        await userRepo.updateProStatus(uid, false, productId: productId);
        debugPrint(
          '🛒 [SubscriptionService] ✅ isPro=false written to users/$uid.',
        );
      } catch (e) {
        debugPrint(
          '⚠️ [SubscriptionService] updateProStatus(false) failed (non-fatal): $e',
        );
      }
    } else {
      debugPrint(
        '⚠️ [SubscriptionService] uid is null — skipping Firestore revocation.',
      );
    }

    // ── 2. Update local state ────────────────────────────────────────────
    _isSubscribed = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_localSubKey, false);
    } catch (e) {
      debugPrint(
        '⚠️ [SubscriptionService] SharedPreferences revoke write failed: $e',
      );
    }

    // ── 3. Expire Credits ────────────────────────────────────────────────
    try {
      await CreditService().setCredits(0);
      debugPrint(
        '🛒 [SubscriptionService] ✅ Credits reset to 0 (expired) due to revocation.',
      );
    } catch (e) {
      debugPrint('⚠️ [SubscriptionService] Failed to reset credits: $e');
    }

    // ── 4. Broadcast ────────────────────────────────────────────────────────
    isSubscribedNotifier.value = false;
    _subscriptionStreamController.add(false);
    debugPrint(
      '🛒 [SubscriptionService] ✅ Revocation broadcast complete — UI should revert.',
    );
  }

  /// Syncs the local subscription state with the database.
  Future<void> syncIsSubscribed(bool isSubscribed) async {
    if (_isSubscribed != isSubscribed) {
      _isSubscribed = isSubscribed;
      isSubscribedNotifier.value = isSubscribed;
      _subscriptionStreamController.add(isSubscribed);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_localSubKey, isSubscribed);

      if (!isSubscribed) {
        try {
          await CreditService().setCredits(0);
          debugPrint(
            '🛒 [SubscriptionService] Credits reset to 0 (expired) on sync',
          );
        } catch (e) {
          debugPrint(
            '⚠️ [SubscriptionService] Failed to reset credits on sync: $e',
          );
        }
      }

      debugPrint(
        '🛒 [SubscriptionService] Synced isSubscribed from DB: $isSubscribed',
      );
    }
  }

  void dispose() {
    _purchaseSubscription?.cancel();
    _subscriptionStreamController.close();
  }
}
