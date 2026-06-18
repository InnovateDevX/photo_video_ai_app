import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Pre-allocated render target cache for shader-based blur operations.
///
/// Avoids reallocating [PictureRecorder], [Canvas], and intermediate images
/// on every slider tick. Instead, caches downsampled buffers and recorder
/// pairs, reusing them across frames.
///
/// Call [dispose] when the source image changes or the widget is destroyed.
class BlurCacheManager {
  BlurCacheManager();

  // ─── Cached downsampled images ────────────────────────────────
  ui.Image? _halfRes;
  ui.Image? _quarterRes;
  int _sourceWidth = 0;
  int _sourceHeight = 0;

  /// Initialize or update the cache for a new source image.
  void updateSource(int width, int height) {
    if (width == _sourceWidth && height == _sourceHeight) return;
    _sourceWidth = width;
    _sourceHeight = height;
    _flushDownsampled();
  }

  /// Renders the source image at 1/2 resolution and caches it.
  Future<ui.Image> getHalfRes(ui.Image source) async {
    if (_halfRes != null &&
        _halfRes!.width == (source.width / 2).round() &&
        _halfRes!.height == (source.height / 2).round()) {
      return _halfRes!;
    }
    _halfRes?.dispose();
    _halfRes = await _downsample(source, 0.5);
    return _halfRes!;
  }

  /// Renders the source image at 1/4 resolution and caches it.
  Future<ui.Image> getQuarterRes(ui.Image source) async {
    if (_quarterRes != null &&
        _quarterRes!.width == (source.width / 4).round() &&
        _quarterRes!.height == (source.height / 4).round()) {
      return _quarterRes!;
    }
    _quarterRes?.dispose();
    _quarterRes = await _downsample(source, 0.25);
    return _quarterRes!;
  }

  /// Renders an image at [scale] using nearest-neighbor (fast, no extra blur).
  Future<ui.Image> _downsample(ui.Image source, double scale) async {
    final dstW = (source.width * scale).round().clamp(1, source.width);
    final dstH = (source.height * scale).round().clamp(1, source.height);

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    canvas.drawImageRect(
      source,
      Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      Rect.fromLTWH(0, 0, dstW.toDouble(), dstH.toDouble()),
      Paint()..filterQuality = ui.FilterQuality.low,
    );

    final picture = recorder.endRecording();
    return picture.toImage(dstW, dstH);
  }

  /// Flushes all cached downsampled images.
  void _flushDownsampled() {
    _halfRes?.dispose();
    _halfRes = null;
    _quarterRes?.dispose();
    _quarterRes = null;
  }

  /// Releases all resources.
  void dispose() {
    _flushDownsampled();
  }
}
