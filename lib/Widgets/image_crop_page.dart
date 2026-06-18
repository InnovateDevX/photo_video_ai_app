import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:trail_ai_app/Core/colors.dart';
import 'package:trail_ai_app/Core/gradient.dart';

/// A full-screen crop page that wraps [ImageCropper].
///
/// Usage:
/// ```dart
/// final File? cropped = await Navigator.push<File?>(
///   context,
///   MaterialPageRoute(
///     builder: (_) => ImageCropPage(imageFile: pickedFile),
///   ),
/// );
/// if (cropped != null) { /* use cropped image */ }
/// ```
///
/// Returns [null] when the user presses Back / cancels.
/// Returns a [File] with the cropped image when the user confirms.
class ImageCropPage extends StatefulWidget {
  /// The original image file to crop.
  final File imageFile;

  /// The target aspect ratio for the crop box (optional).
  final double? aspectRatio;

  const ImageCropPage({super.key, required this.imageFile, this.aspectRatio});

  @override
  State<ImageCropPage> createState() => _ImageCropPageState();
}

class _ImageCropPageState extends State<ImageCropPage> {
  final bool _isCropping = false;

  Future<void> _openCropper() async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: widget.imageFile.path,
      aspectRatio: widget.aspectRatio != null
          ? CropAspectRatio(ratioX: widget.aspectRatio!, ratioY: 1.0)
          : null,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Image',
          toolbarColor: isDark ? const Color(0xFF161616) : Colors.white,
          toolbarWidgetColor: isDark ? Colors.white : Colors.black87,
          backgroundColor: isDark ? const Color(0xFF161616) : Colors.white,
          activeControlsWidgetColor: const Color(0xFF9B59B6),
          dimmedLayerColor: Colors.black.withValues(alpha: 0.7),
          cropFrameColor: const Color(0xFF9B59B6),
          cropGridColor: Colors.white24,
          showCropGrid: true,
          lockAspectRatio: widget.aspectRatio != null,
          hideBottomControls: false,
          initAspectRatio: CropAspectRatioPreset.original,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
        IOSUiSettings(
          title: 'Crop Image',
          cancelButtonTitle: 'Cancel',
          doneButtonTitle: 'Done',
          aspectRatioLockEnabled: widget.aspectRatio != null,
          resetAspectRatioEnabled: widget.aspectRatio == null,
          aspectRatioPickerButtonHidden: widget.aspectRatio != null,
          rotateButtonsHidden: false,
          aspectRatioLockDimensionSwapEnabled: false,
          aspectRatioPresets: [
            CropAspectRatioPreset.original,
            CropAspectRatioPreset.square,
            CropAspectRatioPreset.ratio3x2,
            CropAspectRatioPreset.ratio4x3,
            CropAspectRatioPreset.ratio16x9,
          ],
        ),
      ],
    );

    if (!mounted) return;

    if (croppedFile != null) {
      Navigator.pop(context, File(croppedFile.path));
    } else {
      // User cancelled the native cropper — go back without a result
      Navigator.pop(context, null);
    }
  }

  @override
  void initState() {
    super.initState();
    // Launch cropper after the first frame so the page is visible briefly
    WidgetsBinding.instance.addPostFrameCallback((_) => _openCropper());
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(isDark),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ──────────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: sw * 0.04,
                vertical: sh * 0.015,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _CircleBtn(
                    isDark: isDark,
                    icon: Icons.arrow_back_ios_new,
                    onTap: () => Navigator.pop(context, null),
                  ),
                  Column(
                    children: [
                      Text(
                        'Crop Image',
                        style: TextStyle(
                          fontSize: sw * 0.048,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textColor(isDark),
                        ),
                      ),
                      Text(
                        'Adjust before uploading',
                        style: TextStyle(
                          fontSize: sw * 0.032,
                          color: AppColors.secondaryTextColor(isDark),
                        ),
                      ),
                    ],
                  ),
                  _CircleBtn(
                    isDark: isDark,
                    icon: Icons.close,
                    onTap: () => Navigator.pop(context, null),
                  ),
                ],
              ),
            ),

            // ── Preview ───────────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: sw * 0.04),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(sw * 0.06),
                  child: Image.file(
                    widget.imageFile,
                    fit: BoxFit.contain,
                    width: double.infinity,
                  ),
                ),
              ),
            ),

            SizedBox(height: sh * 0.025),

            // ── Action buttons ────────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: sw * 0.04,
                vertical: sh * 0.01,
              ),
              child: Row(
                children: [
                  // Skip / Use Original
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context, widget.imageFile),
                      child: Container(
                        height: sh * 0.07,
                        decoration: BoxDecoration(
                          color: AppColors.tileBackgroundColor(isDark),
                          borderRadius: BorderRadius.circular(sw * 0.07),
                          border: Border.all(
                            color: AppColors.creditsCardBorder(
                              isDark,
                            ).withValues(alpha: 0.5),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Skip',
                            style: TextStyle(
                              color: AppColors.textColor(isDark),
                              fontSize: sw * 0.042,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(width: sw * 0.03),

                  // Crop (open native cropper)
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _isCropping ? null : _openCropper,
                      child: Container(
                        height: sh * 0.07,
                        decoration: ProGradientDecoration(
                          borderRadius: BorderRadius.all(
                            Radius.circular(sw * 0.07),
                          ),
                        ),
                        child: Center(
                          child: _isCropping
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.crop,
                                      color: Colors.white,
                                      size: sw * 0.05,
                                    ),
                                    SizedBox(width: sw * 0.02),
                                    Text(
                                      'Crop',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: sw * 0.045,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: sh * 0.02),
          ],
        ),
      ),
    );
  }
}

// ── Helper widget ─────────────────────────────────────────────────────────────

class _CircleBtn extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final VoidCallback onTap;

  const _CircleBtn({
    required this.isDark,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(sw * 0.022),
        decoration: BoxDecoration(
          color: AppColors.tileBackgroundColor(isDark),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.creditsCardBorder(isDark).withValues(alpha: 0.4),
          ),
        ),
        child: Icon(icon, size: sw * 0.045, color: AppColors.textColor(isDark)),
      ),
    );
  }
}
