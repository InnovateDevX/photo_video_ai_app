import 'dart:io';
import 'package:flutter/material.dart';
import 'package:trail_ai_app/Core/colors.dart';
import 'package:trail_ai_app/Core/gradient.dart';
import 'package:localization/localization.dart';

class PromptInput extends StatelessWidget {
  final double screenWidth;
  final double screenHeight;
  final bool isDark;
  final TextEditingController controller;
  final FocusNode focusNode;
  final File? selectedImage;
  final VoidCallback onRemoveImage;

  const PromptInput({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
    required this.isDark,
    required this.controller,
    required this.focusNode,
    this.selectedImage,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04,
            vertical: screenHeight * 0.01,
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(screenWidth * 0.02),
                decoration: const ProGradientDecoration(shape: BoxShape.circle),
                child: Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: screenWidth * 0.04,
                ),
              ),
              SizedBox(width: screenWidth * 0.02),
              Text(
                'describe_content'.i18n(),
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: screenWidth * 0.038,
                  color: AppColors.textColor(isDark),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
          child: Container(
            padding: EdgeInsets.all(screenWidth * 0.03),
            decoration: BoxDecoration(
              color: AppColors.tileBackgroundColor(isDark),
              borderRadius: BorderRadius.circular(screenWidth * 0.05),
              border: Border.all(color: AppColors.creditsCardBorder(isDark)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reference image thumbnail inside the prompt box
                if (selectedImage != null) ...[
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          screenWidth * 0.025,
                        ),
                        child: Image.file(
                          selectedImage!,
                          height: screenWidth * 0.2,
                          width: screenWidth * 0.2,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: screenWidth * 0.005,
                        right: screenWidth * 0.005,
                        child: GestureDetector(
                          onTap: onRemoveImage,
                          child: Container(
                            padding: EdgeInsets.all(screenWidth * 0.008),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: screenWidth * 0.035,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.01),
                ],
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  maxLines: 4,
                  minLines: 1,
                  style: TextStyle(
                    color: AppColors.textColor(isDark),
                    fontSize: screenWidth * 0.04,
                  ),
                  decoration: InputDecoration(
                    hintText: 'prompt_placeholder'.i18n(),
                    hintStyle: TextStyle(
                      color: AppColors.secondaryTextColor(
                        isDark,
                      ).withValues(alpha: 0.5),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: screenHeight * 0.01,
                      horizontal: screenWidth * 0.01,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
