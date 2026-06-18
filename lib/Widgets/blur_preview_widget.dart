import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../Services/blur_service.dart';

/// Real-time GPU-accelerated blur preview using Dual Kawase Blur.
///
/// Renders the blurred image via [CustomPainter] with pre-loaded
/// [FragmentShader]. Supports dynamic strength changes at 60fps.
///
/// Usage:
/// ```dart
/// BlurPreviewWidget(
///   image: yourUiImage,
///   strength: 0.5,
///   highQuality: false,  // true for 1/2 res, false for 1/4 res
/// )
/// ```
class BlurPreviewWidget extends StatefulWidget {
  final ui.Image image;
  final double strength;
  final bool highQuality;

  const BlurPreviewWidget({
    super.key,
    required this.image,
    this.strength = 0.0,
    this.highQuality = false,
  });

  @override
  State<BlurPreviewWidget> createState() => _BlurPreviewWidgetState();
}

class _BlurPreviewWidgetState extends State<BlurPreviewWidget> {
  ui.Image? _blurred;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _applyBlur();
  }

  @override
  void didUpdateWidget(BlurPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image ||
        oldWidget.strength != widget.strength ||
        oldWidget.highQuality != widget.highQuality) {
      _applyBlur();
    }
  }

  Future<void> _applyBlur() async {
    if (_busy || widget.strength <= 0.001) {
      if (widget.strength <= 0.001) {
        setState(() {
          _blurred?.dispose();
          _blurred = null;
        });
      }
      return;
    }

    _busy = true;

    try {
      final result = await BlurService().applyKawasePreview(
        source: widget.image,
        strength: widget.strength,
        highQuality: widget.highQuality,
      );

      if (mounted) {
        setState(() {
          _blurred?.dispose();
          _blurred = result;
        });
      } else {
        result.dispose();
      }
    } catch (e) {
      debugPrint('BlurPreviewWidget error: $e');
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _blurred?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_blurred == null || widget.strength <= 0.001) {
      // No blur — show original
      return _buildImage(widget.image);
    }

    return _buildImage(_blurred!);
  }

  Widget _buildImage(ui.Image image) {
    return CustomPaint(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      painter: _ImagePainter(image: image),
    );
  }
}

class _ImagePainter extends CustomPainter {
  final ui.Image image;
  _ImagePainter({required this.image});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..filterQuality = ui.FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(covariant _ImagePainter oldDelegate) {
    return oldDelegate.image != image;
  }
}
