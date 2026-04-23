import 'package:flutter/material.dart';
import 'package:localization/localization.dart';
import 'package:trail_ai_app/Services/ad_service.dart';
import 'package:trail_ai_app/Services/credit_service.dart';

class GenerationGate {
  const GenerationGate._();

  static Future<bool> check({
    required BuildContext context,
    required AdService adService,
    required CreditService creditService,
    required int creditCost,
  }) async {
    // ── 1. Credit check ──────────────────────────────────────────────────────
    if (!creditService.hasEnoughCredits(creditCost)) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('insufficient_credits'.i18n()),
            content: Text(
              'You need $creditCost credits but only have '
              '${creditService.credits}. Purchase more credits to continue.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('ok'.i18n()),
              ),
            ],
          ),
        );
      }
      return false;
    }

    // ── 2. Rewarded interstitial ad ──────────────────────────────────────────
    final adResult = await adService.showRewardedAd();

    if (adResult == null) {
      // Ads not configured in Remote Config
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('ads_setup_required'.i18n()),
            content: Text('ads_setup_message'.i18n()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('ok'.i18n()),
              ),
            ],
          ),
        );
      }
      return false;
    }

    if (adResult == false) {
      // User dismissed/failed the ad without completing it
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('watch_complete_ad'.i18n())),
        );
      }
      return false;
    }

    // All checks passed – caller may proceed with generation
    return true;
  }
}
