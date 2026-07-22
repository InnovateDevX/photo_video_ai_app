import 'package:flutter/material.dart';
import '../Core/colors.dart';

Future<void> showThemedDialog(
  BuildContext context, {
  required String title,
  required String message,
  IconData icon = Icons.info_outline,
  Color iconColor = Colors.blue,
  String okButtonText = 'OK',
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final sw = MediaQuery.of(context).size.width;
  final sh = MediaQuery.of(context).size.height;

  await showDialog(
    context: context,
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
            Container(
              padding: EdgeInsets.all(sw * 0.04),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: sw * 0.08,
              ),
            ),
            SizedBox(height: sh * 0.025),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textColor(isDark),
                fontSize: sw * 0.05,
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
            SizedBox(height: sh * 0.03),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                height: sh * 0.06,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(sw * 0.04),
                  border: Border.all(color: iconColor.withValues(alpha: 0.5)),
                ),
                child: Center(
                  child: Text(
                    okButtonText,
                    style: TextStyle(
                      color: iconColor,
                      fontWeight: FontWeight.bold,
                      fontSize: sw * 0.04,
                    ),
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
