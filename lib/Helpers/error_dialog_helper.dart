import 'package:flutter/material.dart';
import 'package:localization/localization.dart';
import 'package:trail_ai_app/Core/colors.dart';

class ErrorDialogHelper {
  static void showRestrictedContentDialog(
    BuildContext context, {
    String? messageKey,
  }) {
    final key = messageKey ?? 'nsfw_image_detected';

    String title;
    String message;

    if (key == 'restricted_content_detected') {
      final t = 'restricted_text_title'.i18n();
      final m = 'restricted_text_message'.i18n();
      title = t == 'restricted_text_title' ? 'Restricted Text' : t;
      message = m == 'restricted_text_message'
          ? 'Your prompt contains text that violates our safety guidelines. Please modify your prompt and try again.'
          : m;
    } else if (key == 'nsfw_image_detected') {
      final t = 'restricted_image_title'.i18n();
      final m = 'restricted_image_message'.i18n();
      title = t == 'restricted_image_title' ? 'Restricted Image' : t;
      message = m == 'restricted_image_message'
          ? 'The selected image contains content that violates our safety guidelines. Please choose a different image.'
          : m;
    } else {
      title = 'restricted_content_detected'.i18n().split('.').first;
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
      title: title ?? 'error'.i18n().replaceAll(':', '').trim(),
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

  static void _showCustomDialog({
    required BuildContext context,
    required String title,
    required String message,
    required IconData icon,
    required Color iconColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
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
                  onPressed: () => Navigator.pop(ctx),
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
                    'ok'.i18n(),
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
        return 'nsfw_image_detected'.i18n();
      case 'restricted_content_detected':
        return 'restricted_content_detected'.i18n();
      default:
        return messageKey.i18n();
    }
  }
}
