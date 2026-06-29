import 'package:flutter/material.dart';
import 'package:trail_ai_app/Core/colors.dart';
import 'package:localization/localization.dart';

class MenuOverlay extends StatelessWidget {
  final double screenWidth;
  final double screenHeight;
  final bool isDark;
  final VoidCallback onRecreate;
  final VoidCallback onUseSettings;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final bool isDownloading;

  const MenuOverlay({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
    required this.isDark,
    required this.onRecreate,
    required this.onUseSettings,
    required this.onDownload,
    required this.onDelete,
    this.isDownloading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: screenHeight * 0.075,
      right: screenWidth * 0.04,
      child: Container(
        width: screenWidth * 0.5,
        padding: EdgeInsets.all(screenWidth * 0.04),
        decoration: BoxDecoration(
          color: AppColors.creditsCardBackground(isDark),
          borderRadius: BorderRadius.circular(screenWidth * 0.04),
          border: Border.all(color: AppColors.creditsCardBorder(isDark)),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: screenWidth * 0.025,
                offset: Offset(0, screenHeight * 0.005),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMenuItem(
              Icons.refresh,
              'recreate'.i18n(),
              screenWidth,
              onTap: onRecreate,
              isDark: isDark,
            ),
            SizedBox(height: screenHeight * 0.015),
            _buildMenuItem(
              Icons.download,
              'download'.i18n(),
              screenWidth,
              onTap: onDownload,
              isDark: isDark,
              isLoading: isDownloading,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String text,
    double screenWidth, {
    required VoidCallback onTap,
    bool isRed = false,
    bool isDark = false,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          isLoading
              ? SizedBox(
                  width: screenWidth * 0.045,
                  height: screenWidth * 0.045,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.textColor(isDark),
                  ),
                )
              : Icon(
                  icon,
                  color: isRed ? Colors.red : AppColors.textColor(isDark),
                  size: screenWidth * 0.045,
                ),
          SizedBox(width: screenWidth * 0.03),
          Text(
            text,
            style: TextStyle(
              color: isRed ? Colors.red : AppColors.textColor(isDark),
              fontWeight: FontWeight.w500,
              fontSize: screenWidth * 0.038,
            ),
          ),
        ],
      ),
    );
  }
}
