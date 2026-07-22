import 'dart:async';

import 'package:flutter/material.dart';
import 'package:vidzeon/Services/subscription_service.dart';
import 'package:vidzeon/Widgets/main_navigation.dart';
import 'package:vidzeon/pages/paywall_page.dart';

/// A wrapper that shows [MainNavigation] with [PaywallPage] as an overlay.
///
/// This ensures the app is fully loaded and visible first, then the paywall
/// appears on top. When a successful subscription is detected via
/// [SubscriptionService.subscriptionStream], the entire route is replaced
/// with a bare [MainNavigation] — the paywall is gone and never comes back.
class MainNavigationWithPaywall extends StatefulWidget {
  const MainNavigationWithPaywall({super.key});

  @override
  State<MainNavigationWithPaywall> createState() =>
      _MainNavigationWithPaywallState();
}

class _MainNavigationWithPaywallState extends State<MainNavigationWithPaywall> {
  bool _showPaywall = true;
  StreamSubscription<bool>? _subSub;

  @override
  void initState() {
    super.initState();
    _subSub = SubscriptionService().subscriptionStream.listen((isSubscribed) {
      if (isSubscribed && mounted) {
        // Full route replacement: swap this page with a clean MainNavigation.
        // Using pushReplacement removes the paywall from the back-stack so
        // the user cannot navigate back to it.
        Navigator.of(context).pushReplacement(
          PageRouteBuilder<void>(
            pageBuilder: (ctx, anim, secondaryAnim) => const MainNavigation(),
            // Subtle fade so the transition feels intentional, not jarring.
            transitionsBuilder: (ctx, anim, secondaryAnim, child) =>
                FadeTransition(
              opacity: CurvedAnimation(
                parent: anim,
                curve: Curves.easeIn,
              ),
              child: child,
            ),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _subSub?.cancel();
    super.dispose();
  }

  void _dismissPaywall() {
    setState(() => _showPaywall = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // MainNavigation is always rendered underneath so the home screen
        // is fully loaded before the paywall slides in.
        const MainNavigation(),
        // Paywall overlay on top — hidden after user manually dismisses it.
        if (_showPaywall)
          Positioned.fill(
            child: Material(
              color: Colors.black.withValues(alpha: 0.85),
              child: PaywallPage(
                isStartup: true,
                showOnboarding: false,
                isDismissible: true,
                // Override the default Navigator.pop behavior so that tapping
                // the close button collapses the overlay without popping the
                // entire route (which would go back to splash).
                onDismiss: _dismissPaywall,
              ),
            ),
          ),
      ],
    );
  }
}
