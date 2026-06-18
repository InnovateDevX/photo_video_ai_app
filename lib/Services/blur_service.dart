import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'blur_cache_manager.dart';

/// Production-grade GPU blur service using Flutter fragment shaders.
///
/// Architecture:
///   Realtime Preview → Dual Kawase Blur (with downsample chain)
///   Final Export     → Separable Gaussian Blur (H + V passes)
///   BG Composite     → Mask compositing with feathering
///
/// All operations are GPU-accelerated via [FragmentShader].
class BlurService {
  static final BlurService _instance = BlurService._internal();
  factory BlurService() => _instance;
  BlurService._internal();

  // ─── Shader programs ──────────────────────────────────────────
  ui.FragmentProgram? _kawaseProgram;
  ui.FragmentProgram? _gaussianHProgram;
  ui.FragmentProgram? _gaussianVProgram;
  ui.FragmentProgram? _maskCompositeProgram;

  // ─── Cache manager ────────────────────────────────────────────
  final BlurCacheManager _cacheManager = BlurCacheManager();

  bool _initialized = false;

  /// Load all shader programs. Call once at app startup or lazily.
  Future<void> init() async {
    if (_initialized) return;

    final results = await Future.wait([
      ui.FragmentProgram.fromAsset('shaders/kawase_blur.frag'),
      ui.FragmentProgram.fromAsset('shaders/gaussian_horizontal.frag'),
      ui.FragmentProgram.fromAsset('shaders/gaussian_vertical.frag'),
      ui.FragmentProgram.fromAsset('shaders/mask_composite.frag'),
    ]);

    _kawaseProgram = results[0];
    _gaussianHProgram = results[1];
    _gaussianVProgram = results[2];
    _maskCompositeProgram = results[3];

    _initialized = true;
  }

  // ─── Strength mapping ─────────────────────────────────────────
  //
  //   final sigma = pow(slider, 1.8) * 25.0
  //
  //   | Strength | Passes          | Visual    |
  //   |----------|-----------------|-----------|
  //   | 0–0.2    | [1]             | Light     |
  //   | 0.2–0.4  | [1, 2]          | Medium    |
  //   | 0.4–0.7  | [1, 2, 4]      | Strong    |
  //   | 0.7–1.0  | [1, 2, 4, 8]   | Heavy     |

  static List<double> _passesForStrength(double strength) {
    final s = strength.clamp(0.0, 1.0);
    if (s <= 0.2) return [1.0];
    if (s <= 0.4) return [1.0, 2.0];
    if (s <= 0.7) return [1.0, 2.0, 4.0];
    return [1.0, 2.0, 4.0, 8.0];
  }

  static double _sigmaForStrength(double strength) {
    return math.pow(strength.clamp(0.0, 1.0), 1.8).toDouble() * 25.0;
  }

  // ─── Kawase Blur (Preview) ────────────────────────────────────
  //
  // Pipeline:
  //   Full image → 1/4 res → Kawase passes → output
  //
  // During drag: use 1/4 res for speed
  // On release:  use 1/2 res for quality
  //
  // Returns the blurred [ui.Image].

  Future<ui.Image> applyKawasePreview({
    required ui.Image source,
    required double strength,
    bool highQuality = false,
  }) async {
    _ensureInitialized();
    _cacheManager.updateSource(source.width, source.height);

    // Step 1: Downsample
    final workingImage = highQuality
        ? await _cacheManager.getHalfRes(source)
        : await _cacheManager.getQuarterRes(source);

    final passes = _passesForStrength(strength);

    // Step 2: Run multi-pass Kawase
    final result = await _runKawasePasses(image: workingImage, passes: passes);

    // Step 3: Upsample back to original size
    final upsampled = await _upsample(result, source.width, source.height);

    // Cleanup intermediate result if it's not the cached downscale
    if (result != workingImage) {
      result.dispose();
    }

    return upsampled;
  }

  /// Runs a chain of Kawase blur passes using [shader].
  Future<ui.Image> _runKawasePasses({
    required ui.Image image,
    required List<double> passes,
  }) async {
    final shader = _kawaseProgram!.fragmentShader();
    ui.Image current = image;

    for (final offset in passes) {
      final w = current.width;
      final h = current.height;

      shader.setFloat(0, w.toDouble()); // uResolution.x
      shader.setFloat(1, h.toDouble()); // uResolution.y
      shader.setFloat(2, offset); // uOffset
      shader.setImageSampler(0, current);

      final paint = Paint()..shader = shader;
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), paint);

      final picture = recorder.endRecording();
      final next = await picture.toImage(w, h);

      // Dispose intermediate (unless it's the original input)
      if (current != image) {
        current.dispose();
      }
      current = next;
    }

    return current;
  }

  // ─── Separable Gaussian Blur (Export) ─────────────────────────
  //
  // Pipeline:
  //   Full resolution → Horizontal pass → Vertical pass → output

  Future<ui.Image> applyGaussianExport({
    required ui.Image source,
    double strength = 0.5,
    double? sigma,
  }) async {
    _ensureInitialized();

    final actualSigma = sigma ?? _sigmaForStrength(strength);
    final w = source.width;
    final h = source.height;

    final hShader = _gaussianHProgram!.fragmentShader();
    final vShader = _gaussianVProgram!.fragmentShader();

    // ─── Pass 1: Horizontal ─────────────────────────────────────
    hShader.setFloat(0, w.toDouble());
    hShader.setFloat(1, h.toDouble());
    hShader.setFloat(2, actualSigma);
    hShader.setImageSampler(0, source);

    final hPaint = Paint()..shader = hShader;
    var recorder = ui.PictureRecorder();
    var canvas = ui.Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), hPaint);
    var picture = recorder.endRecording();
    var hResult = await picture.toImage(w, h);

    // ─── Pass 2: Vertical ───────────────────────────────────────
    vShader.setFloat(0, w.toDouble());
    vShader.setFloat(1, h.toDouble());
    vShader.setFloat(2, actualSigma);
    vShader.setImageSampler(0, hResult);

    final vPaint = Paint()..shader = vShader;
    recorder = ui.PictureRecorder();
    canvas = ui.Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), vPaint);
    picture = recorder.endRecording();
    final finalImage = await picture.toImage(w, h);

    // Cleanup intermediate
    hResult.dispose();

    return finalImage;
  }

  // ─── Mask Compositing ─────────────────────────────────────────
  //
  // Composites a foreground image over a blurred background using a
  // segmentation mask with feathering.

  Future<ui.Image> compositeWithMask({
    required ui.Image background,
    required ui.Image foreground,
    required ui.Image mask,
    double feather = 2.0,
  }) async {
    _ensureInitialized();

    final w = foreground.width;
    final h = foreground.height;

    final shader = _maskCompositeProgram!.fragmentShader();

    shader.setFloat(0, w.toDouble());
    shader.setFloat(1, h.toDouble());
    shader.setFloat(2, feather / 255.0); // normalized feather amount
    shader.setImageSampler(0, background);
    shader.setImageSampler(1, foreground);
    shader.setImageSampler(2, mask);

    final paint = Paint()..shader = shader;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()), paint);
    final picture = recorder.endRecording();
    return picture.toImage(w, h);
  }

  // ─── Full Background Blur Pipeline (Preview) ──────────────────
  //
  // Combines: background blur → mask composite → result
  // Used for the `bgBlur` sub-tool in the editor.

  Future<ui.Image> applyBackgroundBlurPreview({
    required ui.Image baseImage,
    required ui.Image foregroundImage,
    required ui.Image? maskImage,
    required double blurStrength,
    double feather = 2.0,
  }) async {
    // 1. Blur the background
    final blurredBg = await applyKawasePreview(
      source: baseImage,
      strength: blurStrength,
      highQuality: false,
    );

    // 2. If we have a mask, composite foreground over blurred bg
    if (maskImage != null) {
      final composite = await compositeWithMask(
        background: blurredBg,
        foreground: foregroundImage,
        mask: maskImage,
        feather: feather,
      );
      blurredBg.dispose();
      return composite;
    }

    // Without a mask, just return the blurred bg with fg drawn on top
    return await _composeWithoutMask(blurredBg, foregroundImage);
  }

  /// Full-resolution background blur for export.
  Future<ui.Image> applyBackgroundBlurExport({
    required ui.Image baseImage,
    required ui.Image foregroundImage,
    required ui.Image? maskImage,
    required double blurStrength,
    double feather = 2.0,
  }) async {
    final blurredBg = await applyGaussianExport(
      source: baseImage,
      strength: blurStrength,
    );

    if (maskImage != null) {
      final composite = await compositeWithMask(
        background: blurredBg,
        foreground: foregroundImage,
        mask: maskImage,
        feather: feather,
      );
      blurredBg.dispose();
      return composite;
    }

    return await _composeWithoutMask(blurredBg, foregroundImage);
  }

  /// Simple composite without a mask (draw foregound on top of background).
  Future<ui.Image> _composeWithoutMask(
    ui.Image background,
    ui.Image foreground,
  ) async {
    final w = foreground.width;
    final h = foreground.height;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    canvas.drawImageRect(
      background,
      Rect.fromLTWH(
        0,
        0,
        background.width.toDouble(),
        background.height.toDouble(),
      ),
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint(),
    );
    canvas.drawImageRect(
      foreground,
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint(),
    );

    final picture = recorder.endRecording();
    background.dispose();
    return picture.toImage(w, h);
  }

  // ─── Upsample helper ─────────────────────────────────────────

  Future<ui.Image> _upsample(ui.Image source, int targetW, int targetH) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    canvas.drawImageRect(
      source,
      Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
      Paint()..filterQuality = ui.FilterQuality.high,
    );

    final picture = recorder.endRecording();
    return picture.toImage(targetW, targetH);
  }

  // ─── Expose cache manager for external use ────────────────────

  BlurCacheManager get cacheManager => _cacheManager;

  // ─── Internal ─────────────────────────────────────────────────

  void _ensureInitialized() {
    if (!_initialized) {
      throw StateError(
        'BlurService not initialized. Call BlurService().init() first.',
      );
    }
  }

  /// Release all resources.
  void dispose() {
    _kawaseProgram = null;
    _gaussianHProgram = null;
    _gaussianVProgram = null;
    _maskCompositeProgram = null;
    _cacheManager.dispose();
    _initialized = false;
  }
}
