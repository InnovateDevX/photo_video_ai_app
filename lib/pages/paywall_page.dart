import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:adjust_sdk/adjust.dart';
import 'package:adjust_sdk/adjust_event.dart';
import 'package:vidzeon/Services/subscription_service.dart';
import 'package:vidzeon/Services/remote_config_service.dart';
import 'package:vidzeon/Services/paywall_video_cache.dart';
import 'package:vidzeon/Core/gradient.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:vidzeon/Widgets/themed_dialog.dart';

class PaywallPage extends StatefulWidget {
  final bool isDismissible;
  final bool showOnboarding;
  final bool isStartup;
  final VoidCallback? onDismiss;

  const PaywallPage({
    super.key,
    this.isDismissible = true,
    this.showOnboarding = false,
    this.isStartup = false,
    this.onDismiss,
  });

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  // Weekly is selected by default (shows "Start Free Trial")
  bool _isMonthlySelected = false;
  bool _isFreeTrialEnabled = true;
  bool _isLoading = false;
  bool _isLoadingProducts = true;

  // Video hero
  VideoPlayerController? _videoController;

  ProductDetails? _weeklyProduct;
  ProductDetails? _monthlyProduct;
  final _config = RemoteConfigService();

  StreamSubscription<bool>? _subscriptionSub;

  @override
  void initState() {
    super.initState();
    _loadProducts();

    _attachVideoController();
    AdjustEvent paywallOpenEvent = new AdjustEvent('acazkt');

    // Track the event
    Adjust.trackEvent(paywallOpenEvent);
    _subscriptionSub = SubscriptionService().subscriptionStream.listen((
      isSubscribed,
    ) {
      if (!mounted) return;
      if (isSubscribed) {
        if (widget.onDismiss != null) {
          widget.onDismiss!();
        } else {
          Navigator.pop(context);
        }
      } else {
        setState(() => _isLoading = false);
      }
    });
  }

  @override
  void dispose() {
    _subscriptionSub?.cancel();
    // Do NOT dispose _videoController here — it is owned by PaywallVideoCache.
    // Disposing it here would break future paywall opens in the same session.
    super.dispose();
  }

  /// Attaches the pre-initialised controller from [PaywallVideoCache].
  /// If the cache is already ready, playback begins immediately.
  /// Otherwise, we wait briefly and try again once.
  void _attachVideoController() async {
    final cache = PaywallVideoCache();
    if (cache.isReady && cache.controller != null) {
      _videoController = cache.controller;
      _videoController!.play();
    }
    await cache.preload();
    if (mounted && cache.isReady && cache.controller != null) {
      setState(() {
        _videoController = cache.controller;
        _videoController!.play();
      });
    }
  }

  Future<void> _loadProducts() async {
    final service = SubscriptionService();
    if (service.products.isEmpty) {
      await service.loadProducts();
    }
    final config = RemoteConfigService();
    if (mounted) {
      setState(() {
        _weeklyProduct = service.products[_config.proWeekly];
        _monthlyProduct = service.products[_config.proMonthly];
        _isLoadingProducts = false;
      });
    }
  }

  /// Returns the display price from the selected offer's pricing phases.
  String _priceFor(String productId) {
    return SubscriptionService().getPriceText(productId);
  }

  /// Returns the full label (trial + price or just price) for a product.
  String _labelFor(String productId) {
    return SubscriptionService().getFullPriceLabel(
      productId,
      isTrialEnabled: _isFreeTrialEnabled,
    );
  }

  /// Returns the period label ("Week", "Month") for a product.
  String _periodFor(String productId) {
    return SubscriptionService().getPeriodLabel(productId);
  }

  /// Returns the intro offer label, e.g. "7-Day Intro Offer".
  String _trialLabelFor(String productId) {
    return SubscriptionService().getTrialLabel(productId);
  }

  /// Returns the recurring price line, e.g. "Then Rs 2,800 / week".
  String _recurringLabelFor(String productId) {
    return SubscriptionService().getRecurringPriceLabel(productId);
  }

  Future<void> _handlePurchase() async {
    final product = _isMonthlySelected ? _monthlyProduct : _weeklyProduct;
    if (product == null) {
      showThemedDialog(
        context,
        title: 'Error',
        message: 'Product not available. Please try again later.',
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
      return;
    }

    // Start loading spinner
    setState(() => _isLoading = true);

    // This only initiates the native Google Play / Apple bottom sheet.
    // The actual purchase result comes asynchronously via the stream.
    final error = await SubscriptionService().buyProduct(product);

    if (mounted) {
      if (error != null) {
        // Only clear loading here if we FAILED to open the native bottom sheet.
        // If error == null, the sheet is open, and we want to keep the spinner
        // running until the purchase stream emits a success or failure event.
        setState(() => _isLoading = false);
        showThemedDialog(
          context,
          title: 'Error',
          message: 'Purchase failed: $error',
          icon: Icons.error_outline,
          iconColor: Colors.red,
        );
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);

    final result = await SubscriptionService().restorePurchases();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.success) {
      showThemedDialog(
        context,
        title: 'No Active Subscription',
        message: result.message,
        icon: Icons.info_outline,
        iconColor: Colors.orange,
      );
    }
    // On success, the subscriptionStream listener in initState already
    // calls Navigator.pop() — no dialog needed.
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final bool weeklySelected = !_isMonthlySelected;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Hero Video / Image ──────────────────────────
                    SizedBox(
                      height: h * 0.40,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_videoController != null)
                            ClipRect(
                              child: FittedBox(
                                fit: BoxFit.cover,
                                child: SizedBox(
                                  width: _videoController!.value.size.width,
                                  height: _videoController!.value.size.height,
                                  child: VideoPlayer(_videoController!),
                                ),
                              ),
                            )
                          else
                            Container(color: Colors.black),
                          // Gradient fade to black at bottom
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: h * 0.13,
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, Colors.black],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Feature checkmarks ───────────────────────────────
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        w * 0.08,
                        h * 0.022,
                        w * 0.08,
                        h * 0.018,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildCheckRow('Unlock All Features', w),
                          SizedBox(height: h * 0.010),
                          _buildCheckRow('No Watermark', w),
                          SizedBox(height: h * 0.010),
                          _buildCheckRow('Advanced Editing Tools', w),
                        ],
                      ),
                    ),

                    // ── Free Trial Toggle ────────────────────────────────
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: w * 0.05),
                      child: Container(
                        margin: EdgeInsets.only(top: h * 0.02),
                        padding: EdgeInsets.symmetric(
                          horizontal: w * 0.04,
                          vertical: h * 0.015,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(w * 0.04),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.card_giftcard,
                              color: AppGradients.proGradient.colors.last,
                              size: w * 0.075,
                            ),
                            SizedBox(width: w * 0.035),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Try Trial',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: w * 0.04,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            CupertinoSwitch(
                              value: _isFreeTrialEnabled,
                              onChanged: (val) {
                                setState(() {
                                  _isFreeTrialEnabled = val;
                                });
                              },
                              activeTrackColor:
                                  AppGradients.proGradient.colors.last,
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: h * 0.02),

                    // ── Plan cards + CTA ─────────────────────────────────
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: w * 0.05),
                      child: Column(
                        children: [
                          // Monthly card
                          _buildVerticalPlanCard(
                            trialLabel: _isFreeTrialEnabled
                                ? _trialLabelFor(_config.proMonthly)
                                : null,
                            recurringLabel: _isFreeTrialEnabled
                                ? _recurringLabelFor(_config.proMonthly)
                                : _labelFor(_config.proMonthly),

                            isSelected: _isMonthlySelected,
                            onTap: () =>
                                setState(() => _isMonthlySelected = true),
                            w: w,
                            h: h,
                          ),
                          SizedBox(height: h * 0.016),
                          // Weekly card (selected by default)
                          _buildVerticalPlanCard(
                            trialLabel: _isFreeTrialEnabled
                                ? _trialLabelFor(_config.proWeekly)
                                : null,
                            recurringLabel: _isFreeTrialEnabled
                                ? _recurringLabelFor(_config.proWeekly)
                                : _labelFor(_config.proWeekly),

                            isSelected: weeklySelected,
                            onTap: () =>
                                setState(() => _isMonthlySelected = false),
                            w: w,
                            h: h,
                          ),
                          SizedBox(height: h * 0.03),

                          // ── CTA Button ─────────────────────────────────
                          GestureDetector(
                            onTap: (_isLoading || _isLoadingProducts)
                                ? null
                                : _handlePurchase,
                            child: Container(
                              width: double.infinity,
                              height: h * 0.072,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(w * 0.07),
                                gradient: AppGradients.proGradient,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppGradients.proGradient.colors.first
                                        .withValues(alpha: 0.4),
                                    blurRadius: w * 0.05,
                                    offset: Offset(0, h * 0.01),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isLoading
                                    ? SizedBox(
                                        width: w * 0.06,
                                        height: w * 0.06,
                                        child: const CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : Text(
                                        _isFreeTrialEnabled
                                            ? 'Start Trial'
                                            : 'Get Pro Access',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: w * 0.048,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: w * 0.0008,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          SizedBox(height: h * 0.014),

                          // ── Footer ─────────────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildFooterLink('Terms of Use', () {
                                final url = RemoteConfigService().termsOfUseUrl;
                                if (url.isNotEmpty) launchUrl(Uri.parse(url));
                              }, w),
                              _buildFooterSep(w),
                              _buildFooterLink('Restore', _handleRestore, w),
                              _buildFooterSep(w),
                              _buildFooterLink('Privacy Policy', () {
                                final url =
                                    RemoteConfigService().privacyPolicyUrl;
                                if (url.isNotEmpty) launchUrl(Uri.parse(url));
                              }, w),
                            ],
                          ),
                          SizedBox(height: h * 0.04),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Close Button (top-right) ─────────────────────────────────
            SafeArea(
              child: Padding(
                padding: EdgeInsets.all(w * 0.04),
                child: Align(
                  alignment: Alignment.topRight,
                  child: GestureDetector(
                    onTap: () {
                      if (widget.onDismiss != null) {
                        widget.onDismiss!();
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      width: w * 0.12,
                      height: w * 0.12,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        color: Colors.white,
                        size: w * 0.05,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper Widgets ──────────────────────────────────────────────────────

  /// Orange checkmark + label
  Widget _buildCheckRow(String text, double w) {
    return Row(
      children: [
        Icon(
          Icons.check,
          color: AppGradients.proGradient.colors.last,
          size: w * 0.045,
        ),
        SizedBox(width: w * 0.025),
        Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: w * 0.038,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Vertical plan card with radio button.
  /// When [trialLabel] is non-null, shows a two-line layout:
  ///   "7-Day Intro Offer" (bold)
  ///   "Then Rs X,XXX / week" (muted)
  /// Otherwise shows [recurringLabel] as a single bold line.
  Widget _buildVerticalPlanCard({
    required String? trialLabel,
    required String recurringLabel,

    required bool isSelected,
    required VoidCallback onTap,
    required double w,
    required double h,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: w * 0.05,
          vertical: h * 0.018,
        ),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : const Color(0xFF161616),
          borderRadius: BorderRadius.circular(w * 0.035),
          border: Border.all(
            color: isSelected
                ? AppGradients.proGradient.colors.first
                : Colors.white12,
            width: isSelected ? w * 0.005 : w * 0.0025,
          ),
        ),
        child: Row(
          children: [
            // Radio circle
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: w * 0.055,
              height: w * 0.055,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppGradients.proGradient.colors.first
                      : Colors.white38,
                  width: w * 0.005,
                ),
                color: isSelected
                    ? AppGradients.proGradient.colors.first
                    : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(Icons.circle, color: Colors.white, size: w * 0.025)
                  : null,
            ),
            SizedBox(width: w * 0.04),
            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (trialLabel != null) ...[
                    Text(
                      trialLabel,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: w * 0.043,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: h * 0.004),
                    Text(
                      recurringLabel,
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: w * 0.033,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ] else ...[
                    Text(
                      recurringLabel,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: w * 0.043,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: h * 0.004),
                    Text(
                      'Auto-renewable',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: w * 0.033,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterSep(double w) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: w * 0.02),
      child: Text(
        '|',
        style: TextStyle(color: Colors.white24, fontSize: w * 0.033),
      ),
    );
  }

  Widget _buildFooterLink(String text, VoidCallback onTap, double w) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white38,
          fontSize: w * 0.03,
          decoration: TextDecoration.underline,
          decorationColor: Colors.white24,
        ),
      ),
    );
  }
}