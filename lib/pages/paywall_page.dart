import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:trail_ai_app/Services/subscription_service.dart';
import 'package:trail_ai_app/Services/remote_config_service.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _isMonthlySelected = true;
  bool _freeTrialEnabled = true;
  bool _isLoading = false;
  bool _isLoadingProducts = true;

  ProductDetails? _weeklyProduct;
  ProductDetails? _monthlyProduct;

  StreamSubscription<bool>? _subscriptionSub;

  @override
  void initState() {
    super.initState();
    _loadProducts();

    _subscriptionSub = SubscriptionService().subscriptionStream.listen((
      isSubscribed,
    ) {
      if (isSubscribed && mounted) {
        Navigator.pop(context);
      }
    });
  }

  @override
  void dispose() {
    _subscriptionSub?.cancel();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final service = SubscriptionService();

    // If products aren't loaded yet, fetch them
    if (service.products.isEmpty) {
      await service.loadProducts();
    }

    final config = RemoteConfigService();
    final weeklyId = config.proWeekly;
    final monthlyId = config.proMonthly;

    if (mounted) {
      setState(() {
        _weeklyProduct = service.products[weeklyId];
        _monthlyProduct = service.products[monthlyId];
        _isLoadingProducts = false;
      });
    }
  }

  Future<void> _handlePurchase() async {
    final product = _isMonthlySelected ? _monthlyProduct : _weeklyProduct;
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product not available. Please try again later.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final error = await SubscriptionService().buyProduct(product);

    if (mounted) {
      setState(() => _isLoading = false);
      if (error == null || error == 'CANCELED') {
        // Purchase initiated successfully or user cancelled — results come via stream
        if (error == null) {
          // The purchase stream will handle the rest; we can pop
          // But we wait a moment to let the stream process
        }
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Purchase failed: $error')));
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isLoading = true);
    await SubscriptionService().restorePurchases();
    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Purchases restored.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Scrollable content
            SingleChildScrollView(
              child: Column(
                children: [
                  // ── Hero Image ───────────────────────────────────────────
                  SizedBox(
                    height: h * 0.42,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Hero image
                        Image.asset(
                          'assets/images/pywall.png',
                          fit: BoxFit.cover,
                        ),
                        // Gradient fade to black at bottom
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          height: h * 0.15,
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

                  // ── Title ────────────────────────────────────────────────
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: w * 0.06),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Get Pro Access',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: w * 0.07,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: h * 0.025),

                        // ── Feature List ─────────────────────────────────
                        _buildFeatureRow(
                          Icons.lock_open_rounded,
                          'Unlock All Styles',
                          'Ads',
                          'Ads free experience.',
                          w,
                        ),
                        SizedBox(height: h * 0.015),
                        _buildFeatureRowSimple(
                          Icons.all_inclusive,
                          'Unlimited Video & Image Generation',
                          w,
                        ),
                        SizedBox(height: h * 0.015),
                        _buildFeatureRowSimple(
                          Icons.speed_rounded,
                          'Quick & Best Quality Image',
                          w,
                        ),
                        SizedBox(height: h * 0.03),

                        // ── Free Trial Toggle ────────────────────────────
                        Row(
                          children: [
                            Text(
                              'Free Trial',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: w * 0.042,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.info_outline,
                              color: Colors.white38,
                              size: w * 0.04,
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Text(
                                  'ON',
                                  style: TextStyle(
                                    color: _freeTrialEnabled
                                        ? const Color(0xFFFF9800)
                                        : Colors.white38,
                                    fontSize: w * 0.035,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _freeTrialEnabled = !_freeTrialEnabled;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 48,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      color: _freeTrialEnabled
                                          ? const Color(0xFFFF9800)
                                          : Colors.white24,
                                    ),
                                    child: AnimatedAlign(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      alignment: _freeTrialEnabled
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: Container(
                                        width: 22,
                                        height: 22,
                                        margin: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: h * 0.025),

                        // ── Subscription Cards ───────────────────────────
                        Row(
                          children: [
                            // Weekly Card
                            Expanded(
                              child: _buildPlanCard(
                                title: 'Weekly\naccess',
                                price: _weeklyProduct?.price ?? '\$ —',
                                period: 'Per week',
                                isSelected: !_isMonthlySelected,
                                badge: null,
                                onTap: () =>
                                    setState(() => _isMonthlySelected = false),
                                w: w,
                              ),
                            ),
                            SizedBox(width: w * 0.035),
                            // Monthly Card
                            Expanded(
                              child: _buildPlanCard(
                                title: 'Monthly\naccess',
                                price: _monthlyProduct?.price ?? '\$ —',
                                period: 'Per month',
                                isSelected: _isMonthlySelected,
                                badge: '90% off',
                                onTap: () =>
                                    setState(() => _isMonthlySelected = true),
                                w: w,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: h * 0.03),

                        // ── Continue Button ──────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF6B00), Color(0xFFFF9800)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFFF9800,
                                  ).withOpacity(0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(28),
                                onTap: (_isLoading || _isLoadingProducts)
                                    ? null
                                    : _handlePurchase,
                                child: Center(
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Text(
                                          'Continue',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: w * 0.048,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: h * 0.01),

                        // Cancel anytime
                        Center(
                          child: Text(
                            'Cancel anytime',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: w * 0.033,
                            ),
                          ),
                        ),
                        SizedBox(height: h * 0.025),

                        // ── Footer Links ─────────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildFooterLink('Terms Of Use', () {
                              final url = RemoteConfigService().termsOfUseUrl;
                              if (url.isNotEmpty) launchUrl(Uri.parse(url));
                            }),
                            _buildFooterLink('Privacy policy', () {
                              final url =
                                  RemoteConfigService().privacyPolicyUrl;
                              if (url.isNotEmpty) launchUrl(Uri.parse(url));
                            }),
                            _buildFooterLink(
                              'Restore Purchase',
                              _handleRestore,
                            ),
                          ],
                        ),
                        SizedBox(height: h * 0.04),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Close Button ─────────────────────────────────────────────
            if (widget.isDismissible || widget.isStartup)
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(w * 0.04),
                  child: Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      onTap: () {
                        // If onDismiss callback is provided, use it (for overlay mode)
                        // Otherwise use Navigator.pop (for route mode)
                        if (widget.onDismiss != null) {
                          widget.onDismiss!();
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24),
                        ),
                        padding: EdgeInsets.all(w * 0.022),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
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

  // ── Helper Widgets ──────────────────────────────────────────────────────────

  Widget _buildFeatureRow(
    IconData icon,
    String text,
    String badgeText,
    String trailingText,
    double w,
  ) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFF9800), size: w * 0.055),
        SizedBox(width: w * 0.03),
        Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: w * 0.04,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(width: w * 0.025),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            badgeText,
            style: TextStyle(
              color: Colors.white54,
              fontSize: w * 0.028,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        SizedBox(width: w * 0.02),
        Text(
          trailingText,
          style: TextStyle(color: Colors.white70, fontSize: w * 0.034),
        ),
      ],
    );
  }

  Widget _buildFeatureRowSimple(IconData icon, String text, double w) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFF9800), size: w * 0.055),
        SizedBox(width: w * 0.03),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: w * 0.04,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String period,
    required bool isSelected,
    required String? badge,
    required VoidCallback onTap,
    required double w,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: w * 0.06,
              horizontal: w * 0.02,
            ),
            decoration: BoxDecoration(
              color: isSelected ? Colors.black : const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFFFF9800) : Colors.white24,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: w * 0.042,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                  ),
                ),
                SizedBox(height: w * 0.03),
                Text(
                  price,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: w * 0.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  period,
                  style: TextStyle(color: Colors.white54, fontSize: w * 0.032),
                ),
              ],
            ),
          ),
          // Badge
          if (badge != null)
            Positioned(
              top: -10,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B00),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: w * 0.028,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 12,
          decoration: TextDecoration.underline,
          decorationColor: Colors.white24,
        ),
      ),
    );
  }
}
