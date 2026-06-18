import 'dart:io';
import 'package:flutter/material.dart';
import 'package:trail_ai_app/Core/colors.dart';
// non-translatable
import 'package:localization/localization.dart';

class AILoadingScreen extends StatelessWidget {
  final File? selectedImage;
  final Animation<double> progressAnimation;
  final VoidCallback onCancel;

  final List<String> aiTips;
  final String processingTitle;
  final String applyingText;
  final String waitText;
  final String? customLogoAsset;

  const AILoadingScreen({
    super.key,
    required this.selectedImage,
    required this.progressAnimation,
    required this.onCancel,
    required this.aiTips,
    required this.processingTitle,
    required this.applyingText,
    required this.waitText,
    this.customLogoAsset,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: sw * 0.04),
      child: Column(
        children: [
          SizedBox(height: sh * 0.01),

          // ── Preview image ────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(sw * 0.053),
            child: SizedBox(
              height: sh * 0.60,
              width: double.infinity,
              child: selectedImage != null
                  ? Image.file(selectedImage!, fit: BoxFit.contain)
                  : Container(
                      color: AppColors.tileBackgroundColor(isDark),
                      child: customLogoAsset != null
                          ? Center(
                              child: Padding(
                                padding: EdgeInsets.all(sw * 0.1),
                                child: Image.asset(
                                  customLogoAsset!,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            )
                          : Icon(
                              Icons.person_outline,
                              size: sw * 0.2,
                              color: AppColors.iconColor(
                                isDark,
                              ).withValues(alpha: 0.3),
                            ),
                    ),
            ),
          ),

          SizedBox(height: sh * 0.025),

          // ── Progress card ────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: sw * 0.05,
              vertical: sh * 0.022,
            ),
            decoration: BoxDecoration(
              color: AppColors.tileBackgroundColor(isDark),
              borderRadius: BorderRadius.circular(sw * 0.05),
              border: Border.all(
                color: AppColors.creditsCardBorder(
                  isDark,
                ).withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Text(
                    processingTitle,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: sw * 0.04,
                      color: AppColors.textColor(isDark),
                    ),
                  ),
                ),
                SizedBox(height: sh * 0.012),

                // Animated progress bar
                AnimatedBuilder(
                  animation: progressAnimation,
                  builder: (context, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(sw * 0.02),
                    child: LinearProgressIndicator(
                      value: progressAnimation.value,
                      minHeight: sh * 0.012,
                      backgroundColor: isDark
                          ? Colors.white12
                          : Colors.grey.shade200,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFFE53935),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: sh * 0.01),
                Text(
                  applyingText,
                  style: TextStyle(
                    fontSize: sw * 0.031,
                    color: AppColors.secondaryTextColor(isDark),
                  ),
                ),
                Text(
                  waitText,
                  style: TextStyle(
                    fontSize: sw * 0.031,
                    color: AppColors.secondaryTextColor(isDark),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: sh * 0.02),

          // ── AI Tips card ─────────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: sw * 0.05,
              vertical: sh * 0.02,
            ),
            decoration: BoxDecoration(
              color: AppColors.tileBackgroundColor(isDark),
              borderRadius: BorderRadius.circular(sw * 0.05),
              border: Border.all(
                color: AppColors.creditsCardBorder(
                  isDark,
                ).withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('💡', style: TextStyle(fontSize: 16)),
                    SizedBox(width: sw * 0.02),
                    Text(
                      'ai_tips_title'.i18n(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: sw * 0.038,
                        color: AppColors.textColor(isDark),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: sh * 0.01),
                ...aiTips.map(
                  (tip) => Padding(
                    padding: EdgeInsets.only(bottom: sh * 0.006),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '• ',
                          style: TextStyle(
                            color: AppColors.secondaryTextColor(isDark),
                            fontSize: sw * 0.033,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            tip,
                            style: TextStyle(
                              fontSize: sw * 0.033,
                              color: AppColors.secondaryTextColor(isDark),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: sh * 0.03),

          // ── Cancel button ────────────────────────────────────────────────
          GestureDetector(
            onTap: onCancel,
            child: Container(
              width: double.infinity,
              height: sh * 0.065,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(sw * 0.08),
                border: Border.all(
                  color: AppColors.creditsCardBorder(isDark),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  'cancel'.i18n(),
                  style: TextStyle(
                    fontSize: sw * 0.042,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textColor(isDark),
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: sh * 0.03),
        ],
      ),
    );
  }
}
