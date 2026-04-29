import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trail_ai_app/Widgets/image_crop_page.dart';
import 'package:localization/localization.dart';
import 'package:trail_ai_app/Services/content_safety_service.dart';
import 'package:trail_ai_app/Helpers/nsfw_dialog_helper.dart';

class ImagePickerHelper {
  /// Opens a bottom sheet to pick between Gallery and Camera.
  /// Returns the [File] of the cropped image, or null if cancelled.
  static Future<File?> pickAndCropImage(
    BuildContext context, {
    double? targetAspectRatio,
  }) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final w = MediaQuery.of(ctx).size.width;
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                w * 0.05,
                w * 0.04,
                w * 0.05,
                w * 0.06,
              ),
              decoration: const BoxDecoration(
                color: Color.fromRGBO(0, 0, 0, 0.5),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: w * 0.1,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(99),
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

    if (source == null) return null;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    
    if (pickedFile == null) return null;

    if (!context.mounted) return null;

    final File? croppedFile = await Navigator.push<File?>(
      context,
      MaterialPageRoute(
        builder: (_) => ImageCropPage(
          imageFile: File(pickedFile.path),
          aspectRatio: targetAspectRatio,
        ),
      ),
    );

    if (croppedFile == null) return null;

    // --- Safety Check ---
    if (!context.mounted) return croppedFile;

    try {
      // Show checking overlay
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFD66031)),
        ),
      );

      await ContentSafetyService().checkImageFileSafe(croppedFile);
      
      if (context.mounted) Navigator.pop(context); // Remove loading
    } catch (e) {
      if (context.mounted) Navigator.pop(context); // Remove loading
      
      if (e is NsfwContentException) {
        if (context.mounted) {
          NsfwDialogHelper.showRestrictedContentDialog(context);
        }
        return null;
      }
      // Log other errors but don't block user
      debugPrint('⚠️ [ImagePickerHelper] Safety check error: $e');
    }

    return croppedFile;
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
