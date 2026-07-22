import 'package:flutter/material.dart';
import 'package:vidzeon/Core/colors.dart';
import 'package:vidzeon/Core/routes.dart';
import 'package:vidzeon/Services/subscription_service.dart';

class ErrorDialogHelper {
  static void showRestrictedContentDialog(
    BuildContext context, {
    String? messageKey,
  }) {
    final key = messageKey ?? 'nsfw_image_detected';

    String title;
    String message;

    if (key == 'restricted_content_detected') {
      final t = 'Restricted Text';
      final m =
          'Your prompt contains text that violates our safety guidelines. Please modify your prompt and try again.';
      title = t == 'restricted_text_title' ? 'Restricted Text' : t;
      message = m == 'restricted_text_message'
          ? 'Your prompt contains text that violates our safety guidelines. Please modify your prompt and try again.'
          : m;
    } else if (key == 'nsfw_image_detected') {
      final t = 'Restricted Image';
      final m =
          'The selected image contains content that violates our safety guidelines. Please choose a different image.';
      title = t == 'restricted_image_title' ? 'Restricted Image' : t;
      message = m == 'restricted_image_message'
          ? 'The selected image contains content that violates our safety guidelines. Please choose a different image.'
          : m;
    } else {
      title =
          'Restricted content detected. Please modify your prompt and try again.'
              .split('.')
              .first;
      message = _getMessageText(key);
    }

    _showCustomDialog(
      context: context,
      title: title,
      message: message,
      icon: Icons.gpp_bad_rounded,
      iconColor: Colors.redAccent,
    );
  }

  static void showErrorDialog(
    BuildContext context, {
    String? title,
    required String message,
  }) {
    _showCustomDialog(
      context: context,
      title: title ?? 'Error'.replaceAll(':', '').trim(),
      message: message,
      icon: Icons.error_outline_rounded,
      iconColor: const Color(0xFFD66031), // App primary color
    );
  }

  static void showTimeoutDialog(BuildContext context) {
    _showCustomDialog(
      context: context,
      title: 'Timeout', // You can use AppStrings.timeoutTitle if imported
      message: 'The request took too long. Please try again.',
      icon: Icons.timer_off_rounded,
      iconColor: Colors.orange,
    );
  }

  static void showInsufficientCreditsDialog(
    BuildContext context,
    int required,
    int available,
  ) {
    if (available > 0) {
      _showCustomDialog(
        context: context,
        title: 'Not Enough Credits',
        message:
            'Credits not enough for this model. Switch To a cheaper model.',
        icon: Icons.monetization_on_rounded,
        iconColor: const Color(0xFFD66031), // App primary color
      );
    } else {
      final isSubscribed = SubscriptionService().isSubscribed;
      if (isSubscribed) {
        _showCustomDialog(
          context: context,
          title: 'Not Enough Credits',
          message:
              'You have run out of credits on your current plan. Upgrade your plan to get more credits and continue generating.',
          icon: Icons.workspace_premium_rounded,
          iconColor: const Color(0xFFD66031),
          buttonText: 'Upgrade Plan',
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.paywall);
          },
        );
      } else {
        _showCustomDialog(
          context: context,
          title: 'Not Enough Credits',
          message:
              'You need $required credits, Purchase more credits to continue.',
          icon: Icons.monetization_on_rounded,
          iconColor: const Color(0xFFD66031), // App primary color
          buttonText: 'Get Premium',
          onPressed: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, AppRoutes.paywall);
          },
        );
      }
    }
  }

  static void showNoInternetDialog(BuildContext context) {
    _showCustomDialog(
      context: context,
      title: 'No Internet Connection',
      message: 'Please check your internet connection and try again.',
      icon: Icons.wifi_off_rounded,
      iconColor: const Color(0xFFD66031),
    );
  }

  /// Shown when a feature is gated behind the Pro subscription but the user
  /// is not subscribed. Keeps the app compliant with Google Play's policy
  /// requiring premium features to be properly locked.
  ///
  /// Returns a [Future] that completes when the user dismisses the dialog,
  /// so callers can chain a navigation (e.g. push the paywall) after.
  static Future showSubscriptionRequiredDialog(BuildContext context) {
    return _showCustomDialog(
      context: context,
      title: 'Restore Unsuccessful',
      message:
          'We couldn\'t restore your purchases. Please check if you are logged into the correct Google Play account and try again.',
      icon: Icons.workspace_premium_rounded,
      iconColor: const Color(0xFFD66031),
    );
  }

  static void showNoInternetRetryDialog(
    BuildContext context,
    VoidCallback onRetry,
  ) {
    _showCustomDialog(
      context: context,
      title: 'No Internet Connection',
      message:
          'This app requires an active internet connection to function. Please check your network and try again.',
      icon: Icons.wifi_off_rounded,
      iconColor: const Color(0xFFD66031),
      buttonText: 'Retry',
      onPressed: onRetry,
      barrierDismissible: false,
    );
  }

  static Future _showCustomDialog({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
    String? buttonText,
    VoidCallback? onPressed,
    bool barrierDismissible = true,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;

    return showDialog(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: EdgeInsets.all(w * 0.05),
          decoration: BoxDecoration(
            color: AppColors.tileBackgroundColor(isDark),
            borderRadius: BorderRadius.circular(w * 0.05),
            border: Border.all(
              color: AppColors.creditsCardBorder(isDark).withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(w * 0.04),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: w * 0.1),
              ),
              SizedBox(height: w * 0.04),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textColor(isDark),
                  fontWeight: FontWeight.bold,
                  fontSize: w * 0.05,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: w * 0.02),
              Text(
                message,
                style: TextStyle(
                  color: AppColors.secondaryTextColor(isDark),
                  fontSize: w * 0.038,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: w * 0.06),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onPressed ?? () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD66031),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: w * 0.035),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(w * 0.03),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    buttonText ?? 'OK',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: w * 0.04,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _getMessageText(String messageKey) {
    switch (messageKey) {
      case 'azure_credentials_missing':
      case 'google_vision_credentials_missing':
      case 'google_cloud_credentials_missing':
        return 'Content check is not configured. Please contact support.';
      case 'nsfw_image_detected':
        return 'Restricted content detected in the image. Please choose a different image.';
      case 'restricted_content_detected':
        return 'Restricted content detected. Please modify your prompt and try again.';
      default:
        return messageKey;
    }
  }

  static void showSuccessDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    _showCustomDialog(
      context: context,
      title: title,
      message: message,
      icon: Icons.check_circle_outline_rounded,
      iconColor: Colors.green,
    );
  }

  static void showLoadingDialog(
    BuildContext context, {
    required String message,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: EdgeInsets.all(w * 0.05),
            decoration: BoxDecoration(
              color: AppColors.tileBackgroundColor(isDark),
              borderRadius: BorderRadius.circular(w * 0.05),
              border: Border.all(
                color: AppColors.creditsCardBorder(
                  isDark,
                ).withValues(alpha: 0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 15,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: w * 0.12,
                  height: w * 0.12,
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFD66031),
                    ),
                    strokeWidth: 3,
                  ),
                ),
                SizedBox(height: w * 0.06),
                Text(
                  message,
                  style: TextStyle(
                    color: AppColors.textColor(isDark),
                    fontWeight: FontWeight.bold,
                    fontSize: w * 0.045,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void hideLoadingDialog(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }

  static void showConfirmationDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    required VoidCallback onConfirm,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: EdgeInsets.all(w * 0.05),
          decoration: BoxDecoration(
            color: AppColors.tileBackgroundColor(isDark),
            borderRadius: BorderRadius.circular(w * 0.05),
            border: Border.all(
              color: AppColors.creditsCardBorder(isDark).withValues(alpha: 0.5),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(w * 0.04),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.help_outline_rounded,
                  color: Colors.orange,
                  size: w * 0.1,
                ),
              ),
              SizedBox(height: w * 0.04),
              Text(
                title,
                style: TextStyle(
                  color: AppColors.textColor(isDark),
                  fontWeight: FontWeight.bold,
                  fontSize: w * 0.05,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: w * 0.02),
              Text(
                message,
                style: TextStyle(
                  color: AppColors.secondaryTextColor(isDark),
                  fontSize: w * 0.038,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: w * 0.06),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textColor(isDark),
                        side: BorderSide(
                          color: AppColors.creditsCardBorder(isDark),
                        ),
                        padding: EdgeInsets.symmetric(vertical: w * 0.035),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(w * 0.03),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: w * 0.04,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: w * 0.03),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onConfirm();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD66031),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: w * 0.035),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(w * 0.03),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        confirmText,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: w * 0.04,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
