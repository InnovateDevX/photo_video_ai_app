import 'package:flutter/material.dart';
import 'package:trail_ai_app/Widgets/main_navigation.dart';
import 'package:trail_ai_app/pages/paywall_page.dart';

/// A wrapper that shows MainNavigation with Paywall as an overlay.
/// This ensures Homepage is fully loaded and visible first, then Paywall appears on top.
class MainNavigationWithPaywall extends StatefulWidget {
  const MainNavigationWithPaywall({super.key});

  @override
  State<MainNavigationWithPaywall> createState() =>
      _MainNavigationWithPaywallState();
}

class _MainNavigationWithPaywallState extends State<MainNavigationWithPaywall> {
  bool _showPaywall = true;

  void _dismissPaywall() {
    setState(() {
      _showPaywall = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // MainNavigation with Homepage - fully loaded and visible
        const MainNavigation(),
        // Paywall overlay on top
        if (_showPaywall)
          Positioned.fill(
            child: Material(
              color: Colors.black.withOpacity(0.85),
              child: PaywallPage(
                isStartup: true,
                showOnboarding: false,
                isDismissible: true,
                // Override the default Navigator.pop behavior
                onDismiss: _dismissPaywall,
              ),
            ),
          ),
      ],
    );
  }
}
