import 'dart:io';
import 'package:flutter/material.dart';
import 'package:trail_ai_app/Helpers/image_picker_helper.dart';
import 'package:trail_ai_app/Models/collage_template.dart';

class CollageGrid extends StatelessWidget {
  final CollageTemplate template;
  final List<File?> selectedImages;
  final Function(int index, File file) onImagePicked;
  final bool isExporting;

  const CollageGrid({
    super.key,
    required this.template,
    required this.selectedImages,
    required this.onImagePicked,
    this.isExporting = false,
  });

  @override
  Widget build(BuildContext context) {
    // Validate image count matches template
    final expectedCount = template.imageCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double canvasWidth = constraints.maxWidth;
        final double canvasHeight = constraints.maxHeight;

        return Stack(
          fit: StackFit.expand,
          children: [
            // 1. Base Image Layer
            for (int i = 0; i < template.slots.length; i++)
              Positioned(
                left: template.slots[i].x * canvasWidth,
                top: template.slots[i].y * canvasHeight,
                width: template.slots[i].width * canvasWidth,
                height: template.slots[i].height * canvasHeight,
                child: _CollageSlot(
                  image: i < selectedImages.length ? selectedImages[i] : null,
                  isExporting: isExporting,
                  onTap: () async {
                    if (isExporting) return;
                    final double slotAspectRatio =
                        template.slots[i].width / template.slots[i].height;

                    final file = await ImagePickerHelper.pickAndCropImage(
                      context,
                      targetAspectRatio: slotAspectRatio,
                    );
                    if (file != null) {
                      onImagePicked(i, file);
                    }
                  },
                ),
              ),

            // 2. Map Overlay
            Positioned.fill(
              child: IgnorePointer(
                child: Image.asset(template.mask, fit: BoxFit.cover),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CollageSlot extends StatelessWidget {
  final File? image;
  final VoidCallback onTap;
  final bool isExporting;

  const _CollageSlot({
    required this.image,
    required this.onTap,
    required this.isExporting,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: image == null ? Colors.white10 : Colors.transparent,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null) Image.file(image!, fit: BoxFit.cover),

          if (!isExporting)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: Center(
                  child: image == null
                        ? LayoutBuilder(
                            builder: (context, slotConstraints) {
                              return Icon(
                                Icons.add_a_photo_outlined,
                                size: slotConstraints.maxWidth * 0.15,
                                color: Colors.white,
                              );
                            },
                          )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
