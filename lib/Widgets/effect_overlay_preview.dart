import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A high-performance preview widget for image overlays.
/// Uses [CustomPainter] to render composited images in real-time.
class EffectOverlayPreview extends StatelessWidget {
  final ui.Image? baseImage;
  final ui.Image? overlayImage;
  final double opacity;
  final ui.BlendMode blendMode;
  final Size? targetSize;

  const EffectOverlayPreview({
    super.key,
    this.baseImage,
    this.overlayImage,
    this.opacity = 1.0,
    this.blendMode = ui.BlendMode.screen,
    this.targetSize,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the logical size for the canvas
    Size size;
    if (baseImage != null) {
      size = Size(baseImage!.width.toDouble(), baseImage!.height.toDouble());
    } else if (targetSize != null) {
      size = targetSize!;
    } else {
      size = const Size(1000, 1000); // Fallback
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate fitting size
        final fitScale =
            constraints.hasBoundedWidth && constraints.hasBoundedHeight
            ? (constraints.maxWidth / size.width).clamp(
                0.0,
                constraints.maxHeight / size.height,
              )
            : 1.0;

        return Center(
          child: SizedBox(
            width: size.width * fitScale,
            height: size.height * fitScale,
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _EffectPainter(
                  baseImage: baseImage,
                  overlayImage: overlayImage,
                  opacity: opacity,
                  blendMode: blendMode,
                ),
                size: Size(size.width * fitScale, size.height * fitScale),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EffectPainter extends CustomPainter {
  final ui.Image? baseImage;
  final ui.Image? overlayImage;
  final double opacity;
  final ui.BlendMode blendMode;

  _EffectPainter({
    this.baseImage,
    this.overlayImage,
    required this.opacity,
    required this.blendMode,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background is transparent to allow the editor content to show through below the stack
    /*
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF1A1A1A),
    );
    */

    // 1. Draw base image if present
    if (baseImage != null) {
      final srcRect = Rect.fromLTWH(
        0,
        0,
        baseImage!.width.toDouble(),
        baseImage!.height.toDouble(),
      );
      final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
      canvas.drawImageRect(baseImage!, srcRect, dstRect, Paint());
    }

    // 2. Draw overlay if present
    if (overlayImage != null) {
      final srcRect = Rect.fromLTWH(
        0,
        0,
        overlayImage!.width.toDouble(),
        overlayImage!.height.toDouble(),
      );
      final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);

      final overlayPaint = Paint()
        ..color = Colors.white.withValues(alpha: opacity)
        ..blendMode = blendMode
        ..filterQuality = FilterQuality.high;

      canvas.drawImageRect(overlayImage!, srcRect, dstRect, overlayPaint);
    }

    // Show indicator if no images
    if (baseImage == null && overlayImage == null) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'Select an effect to preview',
          style: TextStyle(color: Colors.white54, fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          (size.width - textPainter.width) / 2,
          (size.height - textPainter.height) / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EffectPainter oldDelegate) {
    return oldDelegate.baseImage != baseImage ||
        oldDelegate.overlayImage != overlayImage ||
        oldDelegate.opacity != opacity ||
        oldDelegate.blendMode != blendMode;
  }
}
