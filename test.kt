package com.facetake.inAppPurchases

import android.app.Activity
import android.content.Context
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.edit
import com.adjust.sdk.Adjust
import com.adjust.sdk.AdjustEvent
import com.android.billingclient.api.*
import com.facetake.utills.ApiConstants.credits
import com.facetake.utills.AppUtils
import com.facetake.utills.AppUtils.isInternetAvailable
import com.facetake.utills.UserCreditManager
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.math.BigDecimal
import java.util.Currency
import java.util.concurrent.TimeUnit

class BillingManager(
    private val context: Context,
    private val activity: Activity,
    private var onPurchaseComplete: (() -> Unit)? = null,
    private var onPurchaseError: ((String) -> Unit)? = null
) : PurchasesUpdatedListener {

    companion object {
        private const val TAG = "BillingManager"
        private const val PREFS_NAME = "iap_prefs"

        // ── Trial Plan Constants ─────────────────────────────────────
        private const val TRIAL_PRODUCT_ID = "facetake_weekly_plan_dic"   // treat the discounted weekly plan as trial
        private const val WEEKLY_OFFER_ID = "dicfirstbuy" // Explicit offer ID for the weekly plan

        private val TRIAL_DURATION_MS = TimeUnit.DAYS.toMillis(3)

        private const val KEY_TRIAL_START_TIME_MS    = "trial_start_time_ms"
        private const val KEY_TRIAL_DURATION_MS      = "trial_duration_ms"
        private const val KEY_TRIAL_CONVERT_REPORTED = "trial_converted_reported"

        // Deduplication key — persists tracked tokens across app restarts
        private const val KEY_TRACKED_TOKENS = "tracked_purchase_tokens"
        private const val ADJUST_PURCHASE_EVENT_TOKEN = "jb4qwi"
    }

    private val subscriptionIds = listOf(
        "facetake_weekly_plan_dic",
        "facetake_monthly_plan",
        "facetake_monthly_discount"
    )

    private val pendingPriceCallbacks = mutableListOf<(Map<String, PriceModel>) -> Unit>()
    private val productDetailsMap = mutableMapOf<String, ProductDetails>()

    private var isConnected = false
    private var currentProductDetails: ProductDetails? = null

    // In-memory dedup set (guards same session)
    private val trackedPurchaseTokens = mutableSetOf<String>()

    private val billingClient = BillingClient.newBuilder(context)
        .setListener(this)
        .enablePendingPurchases(
            PendingPurchasesParams.newBuilder().enableOneTimeProducts().build()
        )
        .build()

    private val reconnectHandler = Handler(Looper.getMainLooper())
    private var reconnectAttempts = 0
    private val MAX_RECONNECT_ATTEMPTS = 5

    init {
        // Load persisted tracked tokens so restarts don't re-fire tracking
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val saved = prefs.getStringSet(KEY_TRACKED_TOKENS, emptySet()) ?: emptySet()
        trackedPurchaseTokens.addAll(saved)

        connectToBillingService()
    }

    // --------------------------------------------------------
    // Billing Connection
    // --------------------------------------------------------
    fun connectToBillingService() {
        if (billingClient.isReady) return

        billingClient.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    isConnected = true
                    reconnectAttempts = 0

                    queryActivePurchases { purchases ->
                        maybeReportTrialConversionOnNextOpen(purchases)
                    }

                    val callbacks = pendingPriceCallbacks.toList()
                    pendingPriceCallbacks.clear()
                    callbacks.forEach { fetchSubscriptionPrices(it) }

                    Log.d(TAG, "✅ Billing connected")
                } else {
                    onPurchaseError?.invoke(result.debugMessage)
                }
            }

            override fun onBillingServiceDisconnected() {
                isConnected = false
                if (reconnectAttempts++ < MAX_RECONNECT_ATTEMPTS) {
                    reconnectHandler.postDelayed({ connectToBillingService() }, 2000)
                }
            }
        })
    }

    // --------------------------------------------------------
    // Fetch Prices
    // --------------------------------------------------------
    fun fetchSubscriptionPrices(onPricesReady: (Map<String, PriceModel>) -> Unit) {
        if (!billingClient.isReady || !isConnected) {
            pendingPriceCallbacks.add { prices -> onPricesReady(prices) }
            connectToBillingService()
            return
        }

        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(
                subscriptionIds.map {
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(it)
                        .setProductType(BillingClient.ProductType.SUBS)
                        .build()
                }
            )
            .build()

        billingClient.queryProductDetailsAsync(params) { result, productDetailsList ->
            if (result.responseCode != BillingClient.BillingResponseCode.OK) {
                onPricesReady(emptyMap())
                return@queryProductDetailsAsync
            }

            val priceMap = mutableMapOf<String, PriceModel>()

            productDetailsList.productDetailsList.forEach { details ->
                productDetailsMap[details.productId] = details
                logProductDetails(details)

                // Explicitly look for the target offer ID for the discounted weekly plan
                val selectedOffer = if (details.productId == TRIAL_PRODUCT_ID) {
                    details.subscriptionOfferDetails?.firstOrNull { it.offerId == WEEKLY_OFFER_ID }
                        ?: details.subscriptionOfferDetails?.firstOrNull { it.pricingPhases.pricingPhaseList.size > 1 }
                        ?: details.subscriptionOfferDetails?.firstOrNull()
                } else {
                    details.subscriptionOfferDetails?.firstOrNull { it.pricingPhases.pricingPhaseList.size > 1 }
                        ?: details.subscriptionOfferDetails?.firstOrNull()
                }

                val phases = selectedOffer?.pricingPhases?.pricingPhaseList.orEmpty()

                val priceModel = when {
                    phases.size >= 2 -> {
                        val discountPhase = phases[0]
                        val recurringPhase = phases.last()
                        PriceModel(
                            firstPrice = discountPhase.formattedPrice,
                            recurringPrice = recurringPhase.formattedPrice
                        )
                    }
                    phases.size == 1 -> {
                        val phase = phases[0]
                        PriceModel(
                            firstPrice = phase.formattedPrice,
                            recurringPrice = phase.formattedPrice
                        )
                    }
                    else -> PriceModel(firstPrice = "N/A", recurringPrice = "N/A")
                }

                priceMap[details.productId] = priceModel
            }

            onPricesReady(priceMap)
        }
    }

    // --------------------------------------------------------
    // Launch Purchase
    // --------------------------------------------------------
    fun launchSubscriptionFlow(planId: String) {
        if (!billingClient.isReady) {
            onPurchaseError?.invoke("Billing not ready. Please try again.")
            return
        }

        if (activity.isFinishing || activity.isDestroyed) {
            onPurchaseError?.invoke("Activity not valid")
            return
        }

        val details = productDetailsMap[planId]
        if (details == null) {
            onPurchaseError?.invoke("Product not loaded")
            return
        }

        currentProductDetails = details

        val offerDetails = details.subscriptionOfferDetails
        if (offerDetails.isNullOrEmpty()) {
            onPurchaseError?.invoke("No subscription offers available")
            return
        }

        // Fetch the specific offer token based on the product ID and target offer ID
        val offerToken = if (planId == TRIAL_PRODUCT_ID) {
            offerDetails.firstOrNull { it.offerId == WEEKLY_OFFER_ID }?.offerToken
                ?: offerDetails.firstOrNull { it.pricingPhases.pricingPhaseList.isNotEmpty() }?.offerToken
        } else {
            offerDetails.firstOrNull { it.pricingPhases.pricingPhaseList.isNotEmpty() }?.offerToken
        }

        if (offerToken.isNullOrEmpty()) {
            onPurchaseError?.invoke("Offer token missing")
            return
        }

        val params = BillingFlowParams.ProductDetailsParams.newBuilder()
            .setProductDetails(details)
            .setOfferToken(offerToken)
            .build()

        val billingFlowParams = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(listOf(params))
            .build()

        val result = billingClient.launchBillingFlow(activity, billingFlowParams)

        if (result.responseCode != BillingClient.BillingResponseCode.OK) {
            onPurchaseError?.invoke("Failed to launch billing flow: ${result.debugMessage}")
        }
    }

    fun setOnPurchaseCompleteCallback(callback: () -> Unit) {
        this.onPurchaseComplete = callback
    }

    fun setOnPurchaseErrorCallback(callback: (String) -> Unit) {
        this.onPurchaseError = callback
    }

    // --------------------------------------------------------
    // Purchase Result
    // --------------------------------------------------------
    override fun onPurchasesUpdated(result: BillingResult, purchases: List<Purchase>?) {
        when (result.responseCode) {
            BillingClient.BillingResponseCode.OK -> purchases?.forEach { handlePurchase(it) }
            BillingClient.BillingResponseCode.USER_CANCELED ->
                Log.d(TAG, "User canceled purchase")
            else -> onPurchaseError?.invoke(result.debugMessage)
        }
    }

    private fun handlePurchase(purchase: Purchase) {
        when (purchase.purchaseState) {
            Purchase.PurchaseState.PURCHASED -> {
                if (!purchase.isAcknowledged) {
                    retryAcknowledgePurchase(purchase, retries = 3)
                } else {
                    // Only track if this token hasn't been tracked yet
                    if (!isAlreadyTracked(purchase.purchaseToken)) {
                        notifyPurchaseCompleteAndTrack(purchase)
                    } else {
                        Log.d(TAG, "⏭️ Skipping already-tracked purchase: ${purchase.purchaseToken}")
                        // Still reflect premium state in UI, but skip Adjust
                        savePurchaseLocally(purchase.products.firstOrNull())
                        onPurchaseComplete?.invoke()
                    }
                }
            }
            Purchase.PurchaseState.PENDING ->
                Log.d(TAG, "Purchase pending.")
            Purchase.PurchaseState.UNSPECIFIED_STATE ->
                Log.e(TAG, "Purchase state unspecified.")
        }
    }

    private fun retryAcknowledgePurchase(purchase: Purchase, retries: Int) {
        billingClient.acknowledgePurchase(
            AcknowledgePurchaseParams.newBuilder()
                .setPurchaseToken(purchase.purchaseToken)
                .build()
        ) { result ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                // Guard here too — retries could succeed in edge cases
                if (!isAlreadyTracked(purchase.purchaseToken)) {
                    notifyPurchaseCompleteAndTrack(purchase)
                } else {
                    Log.d(TAG, "⏭️ ACK retry: token already tracked, skipping Adjust.")
                    savePurchaseLocally(purchase.products.firstOrNull())
                    onPurchaseComplete?.invoke()
                }
            } else {
                if (retries > 0) {
                    Log.w(TAG, "Acknowledge failed, retrying... (${result.debugMessage})")
                    Handler(Looper.getMainLooper()).postDelayed({
                        retryAcknowledgePurchase(purchase, retries - 1)
                    }, 2000L)
                } else {
                    Log.e(TAG, "❌ Acknowledge failed: ${result.debugMessage}")
                    onPurchaseError?.invoke(result.debugMessage)
                }
            }
        }
    }

    private fun notifyPurchaseCompleteAndTrack(purchase: Purchase) {
        savePurchaseLocally(purchase.products.firstOrNull())
        trackPurchaseWithAdjust(purchase)
        markTokenAsTracked(purchase.purchaseToken)   // Mark AFTER firing event
        onPurchaseComplete?.invoke()
    }

    // --------------------------------------------------------
    // Deduplication Helpers
    // --------------------------------------------------------

    // Checks both in-memory set AND persisted SharedPreferences
    private fun isAlreadyTracked(token: String): Boolean {
        if (trackedPurchaseTokens.contains(token)) return true
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val saved = prefs.getStringSet(KEY_TRACKED_TOKENS, emptySet()) ?: emptySet()
        return saved.contains(token)
    }

    // Persists tracked token so it survives app restarts
    private fun markTokenAsTracked(token: String) {
        trackedPurchaseTokens.add(token)
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existing = prefs.getStringSet(KEY_TRACKED_TOKENS, mutableSetOf())?.toMutableSet()
            ?: mutableSetOf()
        existing.add(token)
        prefs.edit { putStringSet(KEY_TRACKED_TOKENS, existing) }
        Log.d(TAG, "✅ Token marked as tracked: $token")
    }

    // --------------------------------------------------------
    // Adjust Tracking
    // --------------------------------------------------------

    private fun trackPurchaseWithAdjust(purchase: Purchase) {
        try {
            val productId = purchase.products.firstOrNull() ?: ""
            val priceDetails = productDetailsMap[productId] ?: currentProductDetails
            val offerDetails = priceDetails?.subscriptionOfferDetails?.firstOrNull()
            val basePhase = offerDetails?.pricingPhases?.pricingPhaseList?.firstOrNull()

            if (basePhase != null) {
                val basePriceAsDouble = basePhase.priceAmountMicros / 1000000.0
                val adjustEvent = AdjustEvent(ADJUST_PURCHASE_EVENT_TOKEN).apply {
                    setRevenue(basePriceAsDouble, basePhase.priceCurrencyCode)
                    setOrderId(purchase.orderId)
                }

                Adjust.trackEvent(adjustEvent)
                Log.d(TAG, "Adjust tracked event token ($ADJUST_PURCHASE_EVENT_TOKEN) with revenue: $basePriceAsDouble")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Adjust IAP tracking calculation exception: ${e.message}")
        }
    }

    // --------------------------------------------------------
    // Trial Conversion (called on app open after trial ends)
    // --------------------------------------------------------

    private fun maybeReportTrialConversionOnNextOpen(activePurchases: List<Purchase>) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val alreadyReported = prefs.getBoolean(KEY_TRIAL_CONVERT_REPORTED, false)
        if (alreadyReported) return

        val trialEndMs = getTrialEndTimeMs()
        if (trialEndMs <= 0L) return

        val now = System.currentTimeMillis()
        if (now < trialEndMs) return

        val trialPurchase = activePurchases.firstOrNull {
            it.products.contains(TRIAL_PRODUCT_ID)
        } ?: return

        val details   = productDetailsMap[TRIAL_PRODUCT_ID] ?: return
        val offer     = details.subscriptionOfferDetails?.firstOrNull()
        val phases    = offer?.pricingPhases?.pricingPhaseList.orEmpty()
        val paidPhase = phases.firstOrNull { it.priceAmountMicros > 0L }

        val payAmount    = (paidPhase?.priceAmountMicros ?: 0L) / 1_000_000.0

        if (payAmount <= 0.0) return

        try {
            prefs.edit { putBoolean(KEY_TRIAL_CONVERT_REPORTED, true) }
            Log.d(TAG, "✅ Adjust: Local trial conversion completed successfully")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Adjust trial conversion exception: ${e.message}", e)
        }
    }

    // --------------------------------------------------------
    // Restore Purchases
    // --------------------------------------------------------
    fun restorePurchases(onRestoreComplete: ((Boolean) -> Unit)? = null) {
        if (!isConnected) {
            onRestoreComplete?.invoke(false)
            return
        }

        billingClient.queryPurchasesAsync(
            QueryPurchasesParams.newBuilder()
                .setProductType(BillingClient.ProductType.SUBS)
                .build()
        ) { result, purchases ->
            if (result.responseCode == BillingClient.BillingResponseCode.OK &&
                purchases.isNotEmpty()
            ) {
                savePurchaseLocally(purchases.first().products.firstOrNull())

                CoroutineScope(Dispatchers.IO).launch {
                    UserCreditManager.init(context.applicationContext)
                    credits = UserCreditManager.getCredits(context.applicationContext)
                }

                maybeReportTrialConversionOnNextOpen(purchases)

                onRestoreComplete?.invoke(true)
            } else {
                clearPurchaseData()
                onRestoreComplete?.invoke(false)
            }
        }
    }

    fun isBillingReady(): Boolean {
        return billingClient.isReady
    }

    // --------------------------------------------------------
    // Purchase State
    // --------------------------------------------------------
    private fun queryActivePurchases(onResult: ((List<Purchase>) -> Unit)? = null) {
        if (!billingClient.isReady) {
            onResult?.invoke(emptyList())
            return
        }

        billingClient.queryPurchasesAsync(
            QueryPurchasesParams.newBuilder()
                .setProductType(BillingClient.ProductType.SUBS)
                .build()
        ) { _, purchases ->
            if (purchases.isNotEmpty()) {
                savePurchaseLocally(purchases.first().products.firstOrNull())
            } else {
                clearPurchaseData()
            }
            onResult?.invoke(purchases)
        }
    }

    private fun savePurchaseLocally(planId: String?) {
        if (planId == null) return
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit {
            putBoolean("is_premium", true)
            putString("premium_plan_id", planId)
        }
    }

    private fun clearPurchaseData() {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit {
            putBoolean("is_premium", false)
        }
    }

    // --------------------------------------------------------
    // Trial Prefs
    // --------------------------------------------------------

    private fun saveTrialPrefs(startMs: Long) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit {
            putLong(KEY_TRIAL_START_TIME_MS, startMs)
            putLong(KEY_TRIAL_DURATION_MS, TRIAL_DURATION_MS)
            putBoolean(KEY_TRIAL_CONVERT_REPORTED, false)
        }
    }

    private fun getTrialEndTimeMs(): Long {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val start = prefs.getLong(KEY_TRIAL_START_TIME_MS, 0L)
        val dur   = prefs.getLong(KEY_TRIAL_DURATION_MS, 0L)
        if (start <= 0L || dur <= 0L) return 0L
        return start + dur
    }

    // --------------------------------------------------------
    // Logging
    // --------------------------------------------------------
    private fun logProductDetails(details: ProductDetails) {
        Log.d("BillingDebug", "==============================")
        Log.d("BillingDebug", "ProductId: ${details.productId}")
        Log.d("BillingDebug", "Title: ${details.title}")

        val offers = details.subscriptionOfferDetails
        if (offers.isNullOrEmpty()) {
            Log.d("BillingDebug", "❌ No subscription offers found")
            return
        }

        offers.forEachIndexed { offerIndex, offer ->
            Log.d(
                "BillingDebug",
                "➡️ Offer[$offerIndex] | offerToken=${offer.offerToken}"
            )

            offer.pricingPhases.pricingPhaseList.forEachIndexed { phaseIndex, phase ->
                Log.d(
                    "BillingDebug",
                    "   🔹 Phase[$phaseIndex] " +
                            "price=${phase.formattedPrice}, " +
                            "micros=${phase.priceAmountMicros}, " +
                            "period=${phase.billingPeriod}, " +
                            "recurrence=${phase.recurrenceMode}"
                )
            }
        }

        Log.d("BillingDebug", "==============================")
    }

    fun isUserPremium(): Boolean =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean("is_premium", false)
}

data class PriceModel(
    val firstPrice: String,
    val recurringPrice: String
)
 