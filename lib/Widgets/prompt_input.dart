import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vidzeon/Core/colors.dart';
import 'package:vidzeon/Core/gradient.dart';

class PromptInput extends StatelessWidget {
  final double screenWidth;
  final double screenHeight;
  final bool isDark;
  final TextEditingController controller;
  final FocusNode focusNode;
  final List<File> selectedImages;
  final void Function(int index) onRemoveImage;
  final VoidCallback onAddImagePressed;
  final bool showCategoryToggle;
  final String? selectedCategory;
  final Function(String) onCategoryChanged;
  final int noOfUploadable;

  const PromptInput({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
    required this.isDark,
    required this.controller,
    required this.focusNode,
    required this.selectedImages,
    required this.onRemoveImage,
    required this.onAddImagePressed,
    this.showCategoryToggle = false,
    this.selectedCategory = 'image',
    required this.onCategoryChanged,
    this.noOfUploadable = 1,
  });

  Widget _buildCategoryToggle() {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.003),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(screenWidth * 0.04),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCategoryPillItem(
            icon: Icons.photo_outlined,
            isSelected: selectedCategory == 'image',
            onTap: () => onCategoryChanged.call('image'),
          ),
          _buildCategoryPillItem(
            icon: Icons.videocam_outlined,
            isSelected: selectedCategory == 'video',
            onTap: () => onCategoryChanged.call('video'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPillItem({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.025,
          vertical: screenHeight * 0.004,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(screenWidth * 0.035),
          gradient: isSelected ? AppGradients.proGradient : null,
          color: isSelected ? null : Colors.transparent,
        ),
        child: Icon(
          icon,
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.white60 : Colors.black54),
          size: screenWidth * 0.045,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenHeight * 0.01,
      ),
      child: Container(
        padding: EdgeInsets.all(screenWidth * 0.04),
        decoration: BoxDecoration(
          color: AppColors.tileBackgroundColor(isDark),
          borderRadius: BorderRadius.circular(screenWidth * 0.05),
          border: Border.all(color: AppColors.creditsCardBorder(isDark)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Describe your content',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: screenWidth * 0.038,
                        color: AppColors.textColor(isDark),
                      ),
                    ),
                    if (showCategoryToggle) ...[
                      SizedBox(width: screenWidth * 0.03),
                      _buildCategoryToggle(),
                    ],
                  ],
                ),
                GestureDetector(
                  onTap: selectedImages.length >= noOfUploadable
                      ? null
                      : onAddImagePressed,
                  child: Icon(
                    Icons.add_photo_alternate_outlined,
                    color: selectedImages.length >= noOfUploadable
                        ? AppColors.secondaryTextColor(
                            isDark,
                          ).withValues(alpha: 0.3)
                        : AppColors.textColor(isDark),
                    size: screenWidth * 0.07,
                  ),
                ),
              ],
            ),
            SizedBox(height: screenHeight * 0.015),
            Divider(
              color: AppColors.creditsCardBorder(isDark),
              thickness: 1,
              height: 1,
            ),
            SizedBox(height: screenHeight * 0.015),
            // Reference image thumbnails inside the prompt box
            if (selectedImages.isNotEmpty) ...[
              SizedBox(
                height: screenWidth * 0.22,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount:
                      selectedImages.length +
                      ((noOfUploadable > 1 &&
                              selectedImages.length < noOfUploadable)
                          ? 1
                          : 0),
                  separatorBuilder: (_, _) =>
                      SizedBox(width: screenWidth * 0.025),
                  itemBuilder: (context, index) {
                    if (index == selectedImages.length) {
                      // Placeholder for adding more images
                      return GestureDetector(
                        onTap: selectedImages.length >= noOfUploadable
                            ? null
                            : onAddImagePressed,
                        child: Container(
                          width: screenWidth * 0.2,
                          height: screenWidth * 0.2,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black12,
                            borderRadius: BorderRadius.circular(
                              screenWidth * 0.025,
                            ),
                            border: Border.all(
                              color: AppColors.creditsCardBorder(isDark),
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              Icons.add_photo_alternate_outlined,
                              color: selectedImages.length >= noOfUploadable
                                  ? AppColors.secondaryTextColor(
                                      isDark,
                                    ).withValues(alpha: 0.3)
                                  : AppColors.secondaryTextColor(isDark),
                              size: screenWidth * 0.08,
                            ),
                          ),
                        ),
                      );
                    }
                    return Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            screenWidth * 0.025,
                          ),
                          child: Image.file(
                            selectedImages[index],
                            width: screenWidth * 0.2,
                            height: screenWidth * 0.2,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: () => onRemoveImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(2),
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
                    );
                  },
                ),
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
                hintText: 'A futuristic city with flying cars...',
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
    );
  }
}
