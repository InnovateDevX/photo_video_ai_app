import 'package:flutter/material.dart';
import 'package:localization/localization.dart';
import 'package:trail_ai_app/Core/colors.dart';

class NsfwDialogHelper {
  static void showRestrictedContentDialog(
    BuildContext context, {
    String? messageKey,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.tileBackgroundColor(isDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Flexible(
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: w * 0.07,
              ),
              SizedBox(width: w * 0.02),
              Flexible(
                child: Text(
                  'restricted_content_detected'
                      .i18n()
                      .split('.')
                      .first, // "Restricted content detected"
                  style: TextStyle(
                    color: AppColors.textColor(isDark),
                    fontWeight: FontWeight.bold,
                    fontSize: w * 0.045,
                  ),
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
            ],
          ),
        ),
        content: Text(
          _getMessageText(messageKey ?? 'nsfw_image_detected', isDark),
          style: TextStyle(
            color: AppColors.secondaryTextColor(isDark),
            fontSize: w * 0.038,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'ok'.i18n(),
              style: const TextStyle(
                color: Color(0xFFD66031),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _getMessageText(String messageKey, bool isDark) {
    switch (messageKey) {
      case 'azure_credentials_missing':
        return 'NSFW check is not configured. Please contact support.';
      case 'nsfw_image_detected':
        return 'nsfw_image_detected'.i18n();
      case 'restricted_content_detected':
        return 'restricted_content_detected'.i18n();
      default:
        return messageKey.i18n();
    }
  }
}
