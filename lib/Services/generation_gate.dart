import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vidzeon/Services/credit_service.dart';
import 'package:vidzeon/Helpers/error_dialog_helper.dart';
import 'package:vidzeon/Services/subscription_service.dart';
import 'package:vidzeon/Core/routes.dart';

class GenerationGate {
  const GenerationGate._();

  static Future<bool> check({
    required BuildContext context,
    required CreditService creditService,
    required int creditCost,
  }) async {
    // ── 0. Internet Connectivity Check ───────────────────────────────────────
    bool hasInternet = false;
    try {
      final result = await InternetAddress.lookup('example.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        hasInternet = true;
      }
    } on SocketException catch (_) {
      hasInternet = false;
    }

    if (!hasInternet) {
      if (context.mounted) {
        ErrorDialogHelper.showNoInternetDialog(context);
      }
      return false;
    }

    // ── 1. Credit check ──────────────────────────────────────────────────────
    if (!creditService.hasEnoughCredits(creditCost)) {
      if (context.mounted) {
        if (creditService.credits == 0 && !SubscriptionService().isSubscribed) {
          Navigator.pushNamed(context, AppRoutes.paywall);
        } else {
          ErrorDialogHelper.showInsufficientCreditsDialog(
            context,
            creditCost,
            creditService.credits,
          );
        }
      }
      return false;
    }

    // All checks passed – caller may proceed with generation
    return true;
  }
}
