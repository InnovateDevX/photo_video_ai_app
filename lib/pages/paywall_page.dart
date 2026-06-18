import 'package:flutter/material.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:trail_ai_app/Services/subscription_service.dart';

class PaywallPage extends StatefulWidget {
  const PaywallPage({super.key});

  @override
  State<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends State<PaywallPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // We use a Stack to handle the Close button over the RevenueCat view
      body: Stack(
        children: [
          // 1. The ACTUAL RevenueCat Dashboard Paywall
          // This will automatically try to load your Offering.
          // If the Play Store is broken, it will show an error message inside this view.
          PaywallView(
            onPurchaseCompleted: (customerInfo, transaction) {
              SubscriptionService().restorePurchases();
              Navigator.pop(context);
            },
            onRestoreCompleted: (customerInfo) {
              if (customerInfo.entitlements.active.isNotEmpty) {
                Navigator.pop(context);
              }
            },
          ),

          // 2. A custom "Close" button in the top right
          // This ensures you can always get out of the paywall during testing
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.topRight,
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    padding: const EdgeInsets.all(8),
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
    );
  }
}
