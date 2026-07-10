import 'package:flutter/material.dart';
import '../Core/colors.dart';

/// Shows a reusable cancel generation confirmation dialog.
///
/// Returns `true` if the user wants to cancel, `false` if they want to continue waiting.
Future<bool> showCancelDialog(
  BuildContext context, {
  String title = 'Cancel Generation?',
  String message =
      'The generation is in progress. Cancelling will stop the server request and you may lose any credits used.',
  String cancelButtonText = 'Yes, Cancel',
  String waitButtonText = 'Continue Waiting',
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final sw = MediaQuery.of(context).size.width;
  final sh = MediaQuery.of(context).size.height;

  final result = await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: EdgeInsets.all(sw * 0.06),
        decoration: BoxDecoration(
          color: AppColors.tileBackgroundColor(isDark),
          borderRadius: BorderRadius.circular(sw * 0.06),
          border: Border.all(
            color: AppColors.creditsCardBorder(isDark),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: EdgeInsets.all(sw * 0.04),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: const Color(0xFFFF9800),
                size: sw * 0.08,
              ),
            ),
            SizedBox(height: sh * 0.025),
            Text(
              title,
              style: TextStyle(
                color: AppColors.textColor(isDark),
                fontSize: sw * 0.055,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: sh * 0.015),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.secondaryTextColor(isDark),
                fontSize: sw * 0.035,
                height: 1.5,
              ),
            ),
            SizedBox(height: sh * 0.04),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(ctx, 'cancel'),
                  child: Container(
                    height: sh * 0.065,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(sw * 0.04),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        cancelButtonText,
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: sw * 0.04,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: sh * 0.015),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: sh * 0.015),
                  ),
                  onPressed: () => Navigator.pop(ctx, 'wait'),
                  child: Text(
                    waitButtonText,
                    style: TextStyle(
                      color: AppColors.secondaryTextColor(isDark),
                      fontWeight: FontWeight.w600,
                      fontSize: sw * 0.038,
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

  return result == 'cancel';
}
