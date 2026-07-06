import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trail_ai_app/Widgets/image_crop_page.dart';
import 'package:localization/localization.dart';
import 'package:trail_ai_app/Services/content_safety_service.dart';
import 'package:trail_ai_app/Helpers/error_dialog_helper.dart';

class ImagePickerHelper {
  /// Wrapper for backward compatibility.
  static Future<File?> pickAndCropImage(
    BuildContext context, {
    double? targetAspectRatio,
  }) {
    return pickImage(
      context: context,
      crop: true,
      targetAspectRatio: targetAspectRatio,
    );
  }

  /// Centralized image picker that handles source selection, cropping, and safety checks.
  /// If [source] is null and [context] is provided, it shows a bottom sheet to select source.
  /// If [crop] is true, it navigates to ImageCropPage after picking.
  static Future<File?> pickImage({
    BuildContext? context,
    bool crop = false,
    double? targetAspectRatio,
    ImageSource? source,
  }) async {
    if (source == null && context != null) {
      source = await _showSourcePicker(context);
      if (source == null) {
        return null;
      }
    }

    // Default to gallery if still null (e.g. if context was null and source was null)
    source ??= ImageSource.gallery;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (pickedFile == null) return null;

    File file = File(pickedFile.path);

    // --- Safety Check ---
    try {
      if (context != null && context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(
            child: CircularProgressIndicator(color: Color(0xFFD66031)),
          ),
        );
      }

      await ContentSafetyService().checkImageFileSafe(file);

      if (context != null && context.mounted) {
        Navigator.pop(context); // Remove loading
      }
    } catch (e) {
      if (context != null && context.mounted) {
        Navigator.pop(context); // Remove loading
        if (e is NsfwContentException) {
          ErrorDialogHelper.showRestrictedContentDialog(
            context,
            messageKey: e.messageKey,
          );
        } else {
          debugPrint('⚠️ [ImagePickerHelper] Safety check error: $e');
        }
      } else if (e is NsfwContentException) {
        // Rethrow if no context so callers like BLoC can handle it
        rethrow;
      }
      return null;
    }

    if (crop && context != null && context.mounted) {
      final croppedFile = await Navigator.push<File?>(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ImageCropPage(imageFile: file, aspectRatio: targetAspectRatio),
        ),
      );
      if (croppedFile == null) return null;
      file = croppedFile;
    }

    return file;
  }

  static Future<ImageSource?> _showSourcePicker(BuildContext context) async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final w = MediaQuery.of(ctx).size.width;
        return ClipRRect(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(MediaQuery.of(context).size.width * 0.06),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                w * 0.05,
                w * 0.04,
                w * 0.05,
                w * 0.06,
              ),
              decoration: BoxDecoration(
                color: Color.fromRGBO(0, 0, 0, 0.5),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(
                    MediaQuery.of(context).size.width * 0.06,
                  ),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: w * 0.1,
                    height: 4,
                    margin: EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(
                        MediaQuery.of(context).size.width * 0.06,
                      ),
                    ),
                  ),
                  Text(
                    'add_reference_image'.i18n(),
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: w * 0.045,
                    ),
                  ),
                  SizedBox(height: w * 0.02),
                  Text(
                    'choose_source'.i18n(),
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: w * 0.035,
                    ),
                  ),
                  SizedBox(height: w * 0.06),
                  Row(
                    children: [
                      Expanded(
                        child: _SourceTile(
                          icon: Icons.photo_library_outlined,
                          label: 'gallery'.i18n(),
                          onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                        ),
                      ),
                      SizedBox(width: w * 0.04),
                      Expanded(
                        child: _SourceTile(
                          icon: Icons.camera_alt_outlined,
                          label: 'camera'.i18n(),
                          onTap: () => Navigator.pop(ctx, ImageSource.camera),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: w * 0.04),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Text(
                      'cancel'.i18n(),
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: w * 0.038,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: w * 0.05),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(255, 255, 255, 0.12),
          borderRadius: BorderRadius.circular(w * 0.04),
          border: Border.all(
            color: const Color.fromRGBO(255, 255, 255, 0.2),
            width: 0.8,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: w * 0.08),
            SizedBox(height: w * 0.02),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: w * 0.038,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
