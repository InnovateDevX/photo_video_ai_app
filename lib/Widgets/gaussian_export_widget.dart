import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../Services/blur_service.dart';

/// Export-quality Gaussian blur widget.
///
/// Runs separable Gaussian blur (horizontal + vertical passes) at
/// full resolution. Designed for the export pipeline, not for
/// real-time preview.
///
/// Usage:
/// ```dart
/// final gaussian = GaussianExportWidget(
///   image: yourUiImage,
///   strength: 0.5,
/// );
/// final result = await gaussian.render();
/// ```
class GaussianExportWidget extends StatefulWidget {
  final ui.Image image;
  final double strength;
  final double? sigma;

  const GaussianExportWidget({
    super.key,
    required this.image,
    this.strength = 0.5,
    this.sigma,
  });

  @override
  State<GaussianExportWidget> createState() => _GaussianExportWidgetState();
}

class _GaussianExportWidgetState extends State<GaussianExportWidget> {
  ui.Image? _blurred;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _applyBlur();
  }

  @override
  void didUpdateWidget(GaussianExportWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image ||
        oldWidget.strength != widget.strength ||
        oldWidget.sigma != widget.sigma) {
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
      final result = await BlurService().applyGaussianExport(
        source: widget.image,
        strength: widget.strength,
        sigma: widget.sigma,
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
      debugPrint('GaussianExportWidget error: $e');
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
