import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'blur_service.dart';

class EffectEngine {
  static final EffectEngine _instance = EffectEngine._internal();
  factory EffectEngine() => _instance;
  EffectEngine._internal();

  /// Decodes an image from a local file path.
  Future<ui.Image> decodeImageFromFile(File file) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw ArgumentError('Image file is empty: ${file.path}');
    }
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    if (image.width <= 0 || image.height <= 0) {
      image.dispose();
      throw ArgumentError(
        'Decoded image has invalid dimensions: ${image.width}x${image.height}',
      );
    }
    return image;
  }

  /// Decodes an image from a Flutter asset path.
  Future<ui.Image> decodeImageFromAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    if (bytes.isEmpty) {
      throw ArgumentError('Asset file is empty: $assetPath');
    }
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    if (image.width <= 0 || image.height <= 0) {
      image.dispose();
      throw ArgumentError(
        'Decoded asset image has invalid dimensions: ${image.width}x${image.height}',
      );
    }
    return image;
  }

  /// Composites a base image with an overlay effect.
  Future<ui.Image> composite({
    required ui.Image baseImage,
    required ui.Image overlayImage,
    required double opacity,
    required ui.BlendMode blendMode,
    double? scale,
    ui.Offset? translation,
  }) async {
    // Validate base image
    if (baseImage.width <= 0 || baseImage.height <= 0) {
      throw ArgumentError(
        'Invalid baseImage dimensions: ${baseImage.width}x${baseImage.height}',
      );
    }

    // Safely check if overlay image is disposed/valid
    int overlayW = 0;
    int overlayH = 0;
    try {
      overlayW = overlayImage.width;
      overlayH = overlayImage.height;
    } catch (e) {
      throw ArgumentError('overlayImage is disposed or invalid');
    }

    if (overlayW <= 0 || overlayH <= 0) {
      throw ArgumentError(
        'Invalid overlayImage dimensions: ${overlayW}x$overlayH',
      );
    }

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final baseSize = ui.Size(
      baseImage.width.toDouble(),
      baseImage.height.toDouble(),
    );

    if (scale != null && translation != null) {
      canvas.save();
      canvas.translate(translation.dx, translation.dy);
      canvas.scale(scale);
      canvas.drawImage(baseImage, ui.Offset.zero, ui.Paint());
      canvas.restore();
    } else {
      canvas.drawImage(baseImage, ui.Offset.zero, ui.Paint());
    }

    // Sanitize opacity to prevent NaN/Infinity crashing color functions
    final double safeOpacity = opacity.isNaN || opacity.isInfinite
        ? 1.0
        : opacity.clamp(0.0, 1.0);

    final overlayPaint = ui.Paint()
      ..color = ui.Color.fromRGBO(255, 255, 255, safeOpacity)
      ..blendMode = blendMode;

    _drawScaledOverlay(canvas, baseSize, overlayImage, overlayPaint);

    final picture = recorder.endRecording();
    return await picture.toImage(baseImage.width, baseImage.height);
  }

  void _drawScaledOverlay(
    ui.Canvas canvas,
    ui.Size baseSize,
    ui.Image overlay,
    ui.Paint paint,
  ) {
    final overlaySize = ui.Size(
      overlay.width.toDouble(),
      overlay.height.toDouble(),
    );
    final destRect = ui.Rect.fromLTWH(0, 0, baseSize.width, baseSize.height);
    canvas.drawImageRect(
      overlay,
      ui.Rect.fromLTWH(0, 0, overlaySize.width, overlaySize.height),
      destRect,
      paint,
    );
  }

  /// Applies circular adjustments (blur, brightness, contrast, saturation) to a region.
  Future<ui.Image> applyCircleAdjustment({
    required ui.Image srcImg,
    required ui.Offset center,
    required double radius,
    required bool editInside,
    required double blur,
    required double brightness,
    required double contrast,
    required double saturation,
    required double hue,
  }) async {
    final imgW = srcImg.width.toDouble();
    final imgH = srcImg.height.toDouble();

    // Sanitize center and radius coordinates to prevent NaNs/Infinites
    final safeCenter = ui.Offset(
      center.dx.isNaN || center.dx.isInfinite ? imgW / 2 : center.dx,
      center.dy.isNaN || center.dy.isInfinite ? imgH / 2 : center.dy,
    );
    final safeRadius = radius.isNaN || radius.isInfinite || radius <= 0
        ? 10.0
        : radius;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final fullRect = ui.Rect.fromLTWH(0, 0, imgW, imgH);
    final circlePath = ui.Path()
      ..addOval(ui.Rect.fromCircle(center: safeCenter, radius: safeRadius));

    final ui.Path adjustPath;
    if (editInside) {
      adjustPath = circlePath;
    } else {
      adjustPath = ui.Path.combine(
        ui.PathOperation.difference,
        ui.Path()..addRect(fullRect),
        circlePath,
      );
    }

    canvas.drawImage(srcImg, ui.Offset.zero, ui.Paint());
    final ui.Paint drawPaint = ui.Paint();
    if (brightness != 0 || contrast != 0 || saturation != 0 || hue != 0) {
      drawPaint.colorFilter = ui.ColorFilter.matrix(
        buildColorMatrix(brightness, contrast, saturation, hue),
      );
    }
    if (blur > 0) {
      drawPaint.imageFilter = ui.ImageFilter.blur(
        sigmaX: blur,
        sigmaY: blur,
        tileMode: ui.TileMode.decal,
      );
    }

    canvas.save();
    canvas.clipPath(adjustPath);
    canvas.drawImage(srcImg, ui.Offset.zero, drawPaint);
    canvas.restore();

    final picture = recorder.endRecording();
    return await picture.toImage(imgW.toInt(), imgH.toInt());
  }

  /// Applies a global color matrix to an image.
  Future<ui.Image> applyGlobalAdjustment({
    required ui.Image srcImg,
    required List<double> matrix,
  }) async {
    final imgW = srcImg.width.toDouble();
    final imgH = srcImg.height.toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final drawPaint = ui.Paint()..colorFilter = ui.ColorFilter.matrix(matrix);

    canvas.drawImage(srcImg, ui.Offset.zero, drawPaint);
    final picture = recorder.endRecording();
    return await picture.toImage(imgW.toInt(), imgH.toInt());
  }

  // ── Adjust Sub-Tool Methods ────────────────────────────────────────────────

  /// Adds film grain noise to the image.
  ///
  /// [strength] ranges 0.0–1.0. At 0.5 the noise amplitude is ~30 per channel.
  /// Applies grain to the image using the same GrainPainter layout.
  Future<ui.Image> applyGrain(ui.Image srcImg, double strength) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final painter = GrainPainter(
      strength: strength,
      image: srcImg,
      imageDstRect: ui.Rect.fromLTWH(
        0,
        0,
        srcImg.width.toDouble(),
        srcImg.height.toDouble(),
      ),
    );
    painter.paint(
      canvas,
      ui.Size(srcImg.width.toDouble(), srcImg.height.toDouble()),
    );

    final picture = recorder.endRecording();
    final result = await picture.toImage(srcImg.width, srcImg.height);
    picture.dispose();
    return result;
  }

  /// Applies a vignette (edge-darkening) effect.
  ///
  /// [strength] 0.0 = none, 1.0 = heavy vignette.
  Future<ui.Image> applyVignette(ui.Image srcImg, double strength) async {
    final w = srcImg.width.toDouble();
    final h = srcImg.height.toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Draw the original image first
    canvas.drawImage(srcImg, ui.Offset.zero, ui.Paint());

    // Overlay a radial gradient from transparent centre to dark edges
    final center = ui.Offset(w / 2, h / 2);
    final radius = math.max(w, h) * 0.75;
    final vignetteAlpha = (strength * 220).clamp(0, 220).toInt();
    final gradient = ui.Gradient.radial(
      center,
      radius,
      [
        const ui.Color(0x00000000), // transparent centre
        ui.Color.fromARGB(vignetteAlpha, 0, 0, 0), // dark edges
      ],
      [0.4, 1.0],
    );
    final paint = ui.Paint()
      ..shader = gradient
      ..blendMode = ui.BlendMode.srcOver;
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, w, h), paint);

    final picture = recorder.endRecording();
    return picture.toImage(srcImg.width, srcImg.height);
  }

  /// Sharpens the image using an unsharp-mask approach.
  ///
  /// [strength] 0.0–1.0.  Internally maps to a kernel weight 0.5–4.0.
  Future<ui.Image> applySharpen(ui.Image srcImg, double strength) async {
    final w = srcImg.width;
    final h = srcImg.height;
    final byteData = await srcImg.toByteData();
    if (byteData == null) throw Exception('Failed to read image pixels');
    final src = byteData.buffer.asUint8List();
    final out = Uint8List(src.length);
    final k = 0.5 + strength * 3.5; // kernel centre weight

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final idx = (y * w + x) * 4;
        for (int c = 0; c < 3; c++) {
          double val = src[idx + c] * (1 + k);
          // subtract 4-neighbour average
          if (x > 0) val -= src[idx - 4 + c] * (k / 4);
          if (x < w - 1) val -= src[idx + 4 + c] * (k / 4);
          if (y > 0) val -= src[idx - w * 4 + c] * (k / 4);
          if (y < h - 1) val -= src[idx + w * 4 + c] * (k / 4);
          out[idx + c] = val.clamp(0, 255).toInt();
        }
        out[idx + 3] = src[idx + 3]; // alpha
      }
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      out,
      w,
      h,
      ui.PixelFormat.rgba8888,
      (img) => completer.complete(img),
    );
    return completer.future;
  }

  /// Simple 3×3 box-blur for noise reduction (denoise).
  ///
  /// [strength] 0.0–1.0 maps to 1–5 passes.
  Future<ui.Image> applyDenoise(ui.Image srcImg, double strength) async {
    final passes = (1 + strength * 4).round();
    ui.Image current = srcImg;
    for (int p = 0; p < passes; p++) {
      current = await _boxBlurPass(current);
    }
    return current;
  }

  Future<ui.Image> _boxBlurPass(ui.Image srcImg) async {
    final w = srcImg.width;
    final h = srcImg.height;
    final byteData = await srcImg.toByteData();
    if (byteData == null) throw Exception('Failed to read image pixels');
    final src = byteData.buffer.asUint8List();
    final out = Uint8List(src.length);

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final idx = (y * w + x) * 4;
        for (int c = 0; c < 3; c++) {
          int sum = 0, count = 0;
          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              final nx = x + dx;
              final ny = y + dy;
              if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
                sum += src[(ny * w + nx) * 4 + c];
                count++;
              }
            }
          }
          out[idx + c] = (sum / count).round();
        }
        out[idx + 3] = src[idx + 3];
      }
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      out,
      w,
      h,
      ui.PixelFormat.rgba8888,
      (img) => completer.complete(img),
    );
    return completer.future;
  }

  /// Mid-tone contrast enhancement (clarity).
  ///
  /// Uses an unsharp-mask with lower kernel weight focused on mid-tones.
  Future<ui.Image> applyClarity(ui.Image srcImg, double strength) async {
    // Clarity = original + weighted(original - blurred)
    final w = srcImg.width;
    final h = srcImg.height;
    final blurred = await _boxBlurPass(srcImg);
    final srcData = await srcImg.toByteData();
    final blurData = await blurred.toByteData();
    if (srcData == null || blurData == null) {
      throw Exception('Failed to read image pixels');
    }
    final src = srcData.buffer.asUint8List();
    final blur = blurData.buffer.asUint8List();
    final out = Uint8List(src.length);
    final factor = strength * 1.5;

    for (int i = 0; i < src.length - 3; i += 4) {
      for (int c = 0; c < 3; c++) {
        final orig = src[i + c];
        final blr = blur[i + c];
        // Only boost mid-tones (avoid blowing out highlights/shadows)
        final lum = orig / 255.0;
        final midWeight = 1.0 - (2.0 * lum - 1.0).abs(); // peaks at 0.5
        final boost = (orig - blr) * factor * midWeight;
        out[i + c] = (orig + boost).clamp(0, 255).toInt();
      }
      out[i + 3] = src[i + 3];
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      out,
      w,
      h,
      ui.PixelFormat.rgba8888,
      (img) => completer.complete(img),
    );
    return completer.future;
  }

  /// Boosts vibrance (saturation on less-saturated pixels, skin-safe).
  ///
  /// [strength] –1.0 to 1.0 (centred at 0.0).
  Future<ui.Image> applyVibrance(ui.Image srcImg, double strength) async {
    final w = srcImg.width;
    final h = srcImg.height;
    final byteData = await srcImg.toByteData();
    if (byteData == null) throw Exception('Failed to read image pixels');
    final src = byteData.buffer.asUint8List();
    final out = Uint8List(src.length);

    for (int i = 0; i < src.length; i += 4) {
      final r = src[i] / 255.0;
      final g = src[i + 1] / 255.0;
      final b = src[i + 2] / 255.0;
      final maxC = math.max(r, math.max(g, b));
      final minC = math.min(r, math.min(g, b));
      final sat = maxC - minC;
      // Vibrance: apply more boost to low-saturation pixels
      double boost = strength * (1.0 - sat);

      // Protect skin tones: warm hues (red/orange/yellow range, roughly 0-50 and 340-360 degrees)
      if (sat > 0.0) {
        double hue = 0.0;
        if (maxC == r) {
          hue = ((g - b) / sat) % 6;
        } else if (maxC == g) {
          hue = (b - r) / sat + 2;
        } else {
          hue = (r - g) / sat + 4;
        }
        hue *= 60.0;
        if (hue < 0) hue += 360.0;

        // Skin tones are centered around 25 degrees. Protect skin tones from being over-boosted.
        double distanceToSkin = 0.0;
        if (hue > 340) {
          distanceToSkin = (hue - 385).abs(); // 385 is 360 + 25
        } else {
          distanceToSkin = (hue - 25).abs();
        }

        if (distanceToSkin < 40) {
          final protection = 0.15 + 0.85 * (distanceToSkin / 40.0);
          boost *= protection;
        }
      }

      final avg = (r + g + b) / 3.0;
      out[i] = ((r + (r - avg) * boost) * 255).clamp(0, 255).toInt();
      out[i + 1] = ((g + (g - avg) * boost) * 255).clamp(0, 255).toInt();
      out[i + 2] = ((b + (b - avg) * boost) * 255).clamp(0, 255).toInt();
      out[i + 3] = src[i + 3];
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      out,
      w,
      h,
      ui.PixelFormat.rgba8888,
      (img) => completer.complete(img),
    );
    return completer.future;
  }

  /// Center-weighted gaussian blur (convex / tilt-shift style).
  ///
  /// [strength] 0.0–1.0, maps to blur sigma 0–20.
  Future<ui.Image> applyConvex(ui.Image srcImg, double strength) async {
    final w = srcImg.width.toDouble();
    final h = srcImg.height.toDouble();
    final sigma = strength * 20.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Draw blurred version
    canvas.saveLayer(
      ui.Rect.fromLTWH(0, 0, w, h),
      ui.Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: sigma,
          sigmaY: sigma,
          tileMode: ui.TileMode.decal,
        ),
    );
    canvas.drawImage(srcImg, ui.Offset.zero, ui.Paint());
    canvas.restore();

    // Overlay sharp centre ellipse
    final center = ui.Offset(w / 2, h / 2);
    final rx = w * 0.35;
    final ry = h * 0.35;
    final clearGrad = ui.Gradient.radial(
      center,
      math.max(rx, ry),
      [const ui.Color(0xFFFFFFFF), const ui.Color(0x00FFFFFF)],
      [0.0, 1.0],
    );
    // Use destination-in to restore the sharp centre
    canvas.saveLayer(ui.Rect.fromLTWH(0, 0, w, h), ui.Paint());
    canvas.drawImage(srcImg, ui.Offset.zero, ui.Paint());
    canvas.drawOval(
      ui.Rect.fromCenter(center: center, width: rx * 2, height: ry * 2),
      ui.Paint()
        ..shader = clearGrad
        ..blendMode = ui.BlendMode.dstOut,
    );
    canvas.restore();

    final picture = recorder.endRecording();
    return picture.toImage(srcImg.width, srcImg.height);
  }

  /// Shifts skin-tone hues (orange-yellow range, ~10°–45°) by a small amount.
  ///
  /// [strength] –1.0 (cooler skin) to 1.0 (warmer/more orange skin).
  Future<ui.Image> applySkinTone(ui.Image srcImg, double strength) async {
    final w = srcImg.width;
    final h = srcImg.height;
    final byteData = await srcImg.toByteData();
    if (byteData == null) throw Exception('Failed to read image pixels');
    final src = byteData.buffer.asUint8List();
    final out = Uint8List(src.length);
    final shift = strength * 15.0; // max ±15° hue shift

    for (int i = 0; i < src.length; i += 4) {
      double r = src[i] / 255.0;
      double g = src[i + 1] / 255.0;
      double b = src[i + 2] / 255.0;

      // RGB → HSL
      final maxC = math.max(r, math.max(g, b));
      final minC = math.min(r, math.min(g, b));
      final delta = maxC - minC;
      double h2 = 0;
      double s = 0;
      final l = (maxC + minC) / 2.0;

      if (delta > 0) {
        s = l < 0.5 ? delta / (maxC + minC) : delta / (2 - maxC - minC);
        if (r == maxC) {
          h2 = ((g - b) / delta + (g < b ? 6 : 0)) * 60;
        } else if (g == maxC) {
          h2 = ((b - r) / delta + 2) * 60;
        } else {
          h2 = ((r - g) / delta + 4) * 60;
        }
      }

      // Only shift skin-tone hues (10°–45°) with sufficient saturation
      if (h2 >= 10 && h2 <= 45 && s > 0.2 && l > 0.2 && l < 0.8) {
        h2 = (h2 + shift).clamp(5, 55);
      }

      // HSL → RGB
      if (s == 0) {
        final v = (l * 255).round().clamp(0, 255);
        out[i] = v;
        out[i + 1] = v;
        out[i + 2] = v;
      } else {
        final q = l < 0.5 ? l * (1 + s) : l + s - l * s;
        final p = 2 * l - q;
        final hk = h2 / 360.0;
        out[i] = _hueToRgb(p, q, hk + 1.0 / 3.0);
        out[i + 1] = _hueToRgb(p, q, hk);
        out[i + 2] = _hueToRgb(p, q, hk - 1.0 / 3.0);
      }
      out[i + 3] = src[i + 3];
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      out,
      w,
      h,
      ui.PixelFormat.rgba8888,
      (img) => completer.complete(img),
    );
    return completer.future;
  }

  static int _hueToRgb(double p, double q, double t) {
    if (t < 0) t += 1.0;
    if (t > 1) t -= 1.0;
    double v;
    if (t < 1.0 / 6.0) {
      v = p + (q - p) * 6.0 * t;
    } else if (t < 1.0 / 2.0) {
      v = q;
    } else if (t < 2.0 / 3.0) {
      v = p + (q - p) * (2.0 / 3.0 - t) * 6.0;
    } else {
      v = p;
    }
    return (v * 255).round().clamp(0, 255);
  }

  // ── Matrix helpers for colour-matrix-based adjust tools ──────────────────

  /// Builds a colour matrix for global saturation adjustment.
  /// [strength] –1.0 (desaturate) to 1.0 (full saturation boost).
  List<double> buildSaturationMatrix(double strength) {
    return buildColorMatrix(0, 0, strength.clamp(-1.0, 1.0), 0);
  }

  /// Builds a vibrance matrix approximation using selective HSL matrix.
  /// This boosts saturation of greens, cyans, and blues more while protecting
  /// skin tones (reds and yellows).
  /// [strength] -1.0 to 1.0 (centred at 0.0).
  List<double> buildVibranceMatrix(double strength) {
    final s = strength.clamp(-1.0, 1.0);
    double clamp01(double v) => v.clamp(0.0, 1.0);

    return buildSelectiveHSLMatrix([
      {'hue': 0.5, 'saturation': 0.5, 'luminance': 0.5}, // Master
      {
        'hue': 0.5,
        'saturation': clamp01(0.50 + s * 0.05),
        'luminance': 0.5,
      }, // Red
      {
        'hue': 0.5,
        'saturation': clamp01(0.50 + s * 0.10),
        'luminance': 0.5,
      }, // Yellow
      {
        'hue': 0.5,
        'saturation': clamp01(0.50 + s * 0.90),
        'luminance': 0.5,
      }, // Green
      {
        'hue': 0.5,
        'saturation': clamp01(0.50 + s * 1.00),
        'luminance': 0.5,
      }, // Cyan
      {
        'hue': 0.5,
        'saturation': clamp01(0.50 + s * 1.00),
        'luminance': 0.5,
      }, // Blue
      {
        'hue': 0.5,
        'saturation': clamp01(0.50 + s * 0.40),
        'luminance': 0.5,
      }, // Magenta
    ]);
  }

  /// Builds a warm/cool colour matrix for temperature adjustment.
  /// [strength] –1.0 = very cool (blue), +1.0 = very warm (orange).
  List<double> buildTemperatureMatrix(double strength) {
    final warm = strength.clamp(-1.0, 1.0);
    final rScale = 1.0 + warm * 0.25;
    final bScale = 1.0 - warm * 0.25;

    return <double>[
      rScale,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      bScale,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  /// Builds a tone matrix: lifts shadows and compresses highlights slightly.
  /// [strength] 0.0 = neutral, 1.0 = lifted shadows + compressed highlights.
  List<double> buildToneMatrix(double strength) {
    final s = strength.clamp(-1.0, 1.0);
    final shadowLift = s * 0.18;
    final scale = 1.0 - s.abs() * 0.05;

    return <double>[
      scale,
      0,
      0,
      0,
      shadowLift,
      0,
      scale,
      0,
      0,
      shadowLift,
      0,
      0,
      scale,
      0,
      shadowLift,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  /// Photoshop-like luminance-preserving contrast.
  /// [strength] ranges from -1.0 to +1.0 (slider 0..1 mapped to -1..1).
  /// Positive = more contrast, Negative = flat/washed out.
  List<double> buildContrastMatrix(double strength) {
    // Tune this multiplier to taste. 0.75 = Photoshop standard
    final scale = 1.0 + strength * 0.75; // Range: 0.25 .. 1.75

    // Perceptual luminance weights (ITU-R BT.709)
    const lr = 0.299;
    const lg = 0.587;
    const lb = 0.114;

    // "mix" blends between original color and its luminance.
    final mix = 1.0 - scale;

    return <double>[
      scale + lr * mix,
      lg * mix,
      lb * mix,
      0,
      0,
      lr * mix,
      scale + lg * mix,
      lb * mix,
      0,
      0,
      lr * mix,
      lg * mix,
      scale + lb * mix,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  /// Blurs the background and overlays a sharp foreground subject.
  ///
  /// Uses CPU-based [ImageFilter.blur] (legacy). For GPU-accelerated
  /// versions, use [applyBackgroundBlurGPU] or [applyBackgroundBlurExport].
  Future<ui.Image> applyBackgroundBlur({
    required ui.Image baseImage,
    required ui.Image foregroundImage,
    required double blurIntensity,
  }) async {
    final width = baseImage.width.toDouble();
    final height = baseImage.height.toDouble();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, width, height));

    // 1. Draw blurred background
    if (blurIntensity > 0.01) {
      final sigma = blurIntensity;
      canvas.saveLayer(
        ui.Rect.fromLTWH(0, 0, width, height),
        ui.Paint()
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: ui.TileMode.decal,
          ),
      );
      canvas.drawImage(baseImage, ui.Offset.zero, ui.Paint());
      canvas.restore();
    } else {
      canvas.drawImage(baseImage, ui.Offset.zero, ui.Paint());
    }

    // 2. Draw sharp foreground
    canvas.drawImageRect(
      foregroundImage,
      ui.Rect.fromLTWH(
        0,
        0,
        foregroundImage.width.toDouble(),
        foregroundImage.height.toDouble(),
      ),
      ui.Rect.fromLTWH(0, 0, width, height),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );

    final picture = recorder.endRecording();
    return await picture.toImage(width.toInt(), height.toInt());
  }

  /// GPU-accelerated background blur for realtime preview.
  ///
  /// Uses Dual Kawase Blur with downsample chain and optional mask
  /// compositing. Much faster and smoother than CPU [ImageFilter.blur].
  ///
  /// [blurIntensity] is mapped through a non-linear curve (pow 1.8) for
  /// natural-feeling slider control.
  ///
  /// [maskImage] - optional segmentation mask for preserving foreground subject.
  /// [feather] - edge feathering in pixels (applied to mask).
  Future<ui.Image> applyBackgroundBlurGPU({
    required ui.Image baseImage,
    required ui.Image foregroundImage,
    ui.Image? maskImage,
    required double blurIntensity,
    double feather = 2.0,
    bool highQuality = false,
  }) async {
    // Ensure BlurService is initialized
    if (!(await _ensureBlurService())) {
      // Fallback to CPU if shaders fail to load
      return applyBackgroundBlur(
        baseImage: baseImage,
        foregroundImage: foregroundImage,
        blurIntensity: blurIntensity,
      );
    }

    return BlurService().applyBackgroundBlurPreview(
      baseImage: baseImage,
      foregroundImage: foregroundImage,
      maskImage: maskImage,
      blurStrength: blurIntensity,
      feather: feather,
    );
  }

  /// GPU-accelerated background blur for high-quality export.
  ///
  /// Uses Separable Gaussian Blur (H + V passes) at full resolution.
  /// Call this only for final export, not for real-time preview.
  Future<ui.Image> applyBackgroundBlurExport({
    required ui.Image baseImage,
    required ui.Image foregroundImage,
    ui.Image? maskImage,
    required double blurIntensity,
    double feather = 2.0,
  }) async {
    if (!(await _ensureBlurService())) {
      return applyBackgroundBlur(
        baseImage: baseImage,
        foregroundImage: foregroundImage,
        blurIntensity: blurIntensity,
      );
    }

    return BlurService().applyBackgroundBlurExport(
      baseImage: baseImage,
      foregroundImage: foregroundImage,
      maskImage: maskImage,
      blurStrength: blurIntensity,
      feather: feather,
    );
  }

  /// Apply GPU Kawase blur preview to a single image (no compositing).
  Future<ui.Image> applyKawaseBlur({
    required ui.Image source,
    required double strength,
    bool highQuality = false,
  }) async {
    if (!(await _ensureBlurService())) {
      // Fallback: simple CPU blur
      return _cpuBlurFallback(source, strength);
    }

    return BlurService().applyKawasePreview(
      source: source,
      strength: strength,
      highQuality: highQuality,
    );
  }

  /// Apply GPU separable Gaussian blur (export quality).
  Future<ui.Image> applyGaussianBlur({
    required ui.Image source,
    required double strength,
  }) async {
    if (!(await _ensureBlurService())) {
      return _cpuBlurFallback(source, strength);
    }

    return BlurService().applyGaussianExport(
      source: source,
      strength: strength,
    );
  }

  /// Ensure BlurService is initialized; returns false on failure.
  Future<bool> _ensureBlurService() async {
    try {
      await BlurService().init();
      return true;
    } catch (e) {
      debugPrint('BlurService init failed, falling back to CPU: $e');
      return false;
    }
  }

  /// Simple CPU-based blur fallback if shaders are unavailable.
  Future<ui.Image> _cpuBlurFallback(ui.Image source, double strength) async {
    final w = source.width.toDouble();
    final h = source.height.toDouble();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    canvas.saveLayer(
      ui.Rect.fromLTWH(0, 0, w, h),
      ui.Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: strength * 10,
          sigmaY: strength * 10,
          tileMode: ui.TileMode.decal,
        ),
    );
    canvas.drawImage(source, ui.Offset.zero, ui.Paint());
    canvas.restore();

    final picture = recorder.endRecording();
    return picture.toImage(source.width, source.height);
  }

  /// Converts a ui.Image to bytes.
  Future<Uint8List> exportToBytes(
    ui.Image image, {
    ui.ImageByteFormat format = ui.ImageByteFormat.png,
  }) async {
    final byteData = await image.toByteData(format: format);
    if (byteData == null) throw Exception('Failed to encode image');
    return byteData.buffer.asUint8List();
  }

  // ── Selective HSL (Per‑Pixel) ──────────────────────────────────────

  /// Hue ranges for each color index.
  /// index 0 = Master (always applied), 1=Red, 2=Yellow, 3=Green,
  ///        4=Cyan, 5=Blue, 6=Magenta

  /// Applies per‑pixel HSL adjustments for each of the 7 colour ranges.
  ///
  /// [adjustments] must contain exactly 7 maps with keys 'hue', 'saturation',
  /// 'luminance' (0.0‑1.0, 0.5 = neutral).
  Future<ui.Image> applySelectiveHSLAdjustment({
    required ui.Image srcImg,
    required List<Map<String, double>> adjustments,
  }) async {
    assert(
      adjustments.length == 7,
      'Need exactly 7 adjustment maps (master + 6 colours)',
    );

    final w = srcImg.width;
    final h = srcImg.height;

    final byteData = await srcImg.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    if (byteData == null) throw Exception('Failed to read image pixels');
    final pixels = byteData.buffer.asUint8List();

    final processedBytes = await compute(_runHslProcessingInIsolate, {
      'bytes': pixels,
      'adjustments': adjustments,
    });

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      processedBytes,
      w,
      h,
      ui.PixelFormat.rgba8888,
      (image) => completer.complete(image),
    );
    return completer.future;
  }

  static Uint8List _runHslProcessingInIsolate(Map<String, dynamic> params) {
    final Uint8List bytes = params['bytes'] as Uint8List;
    final List<Map<String, double>> adjustments =
        (params['adjustments'] as List)
            .map((item) => Map<String, double>.from(item as Map))
            .toList();
    return HslProcessor.apply(bytes, adjustments);
  }

  // ── Color-matrix helpers (kept for live preview & other tools) ──────

  List<double> buildSelectiveHSLMatrix(List<Map<String, double>> adjustments) {
    // Start with identity matrix
    List<double> result = <double>[
      1,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];

    for (int i = 0; i < adjustments.length; i++) {
      final adj = adjustments[i];
      final h = (adj['hue']! - 0.5) * 360;
      final s = (adj['saturation']! - 0.5) * 2;
      final l = (adj['luminance']! - 0.5) * 2;

      if (h == 0 && s == 0 && l == 0) continue;

      List<double> m;
      if (i == 0) {
        // Master adjustment (Global)
        m = buildColorMatrix(l / 2, 0, s, h);
      } else {
        // Selective adjustment (i=1:Red, 2:Yellow, 3:Green, 4:Cyan, 5:Blue, 6:Magenta)
        m = _buildSingleSelectiveMatrix(i, h, s, l);
      }
      result = _concat(m, result);
    }
    return result;
  }

  List<double> _buildSingleSelectiveMatrix(
    int colorIndex,
    double h,
    double s,
    double l,
  ) {
    // Photoshop-style Selective Matrix:
    // Target pixels where the selected color is dominant.

    int p = 0, s1 = 1, s2 = 2;
    bool isSecondary = false;

    switch (colorIndex) {
      case 1:
        p = 0;
        s1 = 1;
        s2 = 2;
        break; // Red
      case 2:
        p = 2;
        s1 = 0;
        s2 = 1;
        isSecondary = true;
        break; // Yellow
      case 3:
        p = 1;
        s1 = 0;
        s2 = 2;
        break; // Green
      case 4:
        p = 0;
        s1 = 1;
        s2 = 2;
        isSecondary = true;
        break; // Cyan
      case 5:
        p = 2;
        s1 = 0;
        s2 = 1;
        break; // Blue
      case 6:
        p = 1;
        s1 = 0;
        s2 = 2;
        isSecondary = true;
        break; // Magenta
    }

    final matrix = List<double>.generate(20, (i) => (i % 6 == 0) ? 1.0 : 0.0);

    if (!isSecondary) {
      // Primary colors (R, G, B)
      // Saturation
      matrix[p * 5 + p] += s;
      matrix[p * 5 + s1] -= s * 0.5;
      matrix[p * 5 + s2] -= s * 0.5;

      // Luminance
      for (int i = 0; i < 3; i++) {
        matrix[i * 5 + p] += l * 0.5;
        matrix[i * 5 + s1] -= l * 0.25;
        matrix[i * 5 + s2] -= l * 0.25;
      }

      // Selective Hue Shift (Approximation)
      if (h != 0) {
        int targetChannel = (h > 0) ? s1 : s2;
        double hAbs = h.abs() / 180;
        matrix[targetChannel * 5 + p] += hAbs;
        matrix[targetChannel * 5 + s1] -= hAbs * 0.5;
        matrix[targetChannel * 5 + s2] -= hAbs * 0.5;
      }
    } else {
      // Secondary colors (Yellow, Cyan, Magenta)
      int c1 = s1, c2 = s2; // The dominant channels

      // Saturation
      matrix[c1 * 5 + c1] += s * 0.5;
      matrix[c1 * 5 + p] -= s * 0.5;
      matrix[c2 * 5 + c2] += s * 0.5;
      matrix[c2 * 5 + p] -= s * 0.5;

      // Luminance
      for (int i = 0; i < 3; i++) {
        matrix[i * 5 + c1] += l * 0.25;
        matrix[i * 5 + c2] += l * 0.25;
        matrix[i * 5 + p] -= l * 0.5;
      }
    }

    return matrix;
  }

  List<double> buildColorMatrix(
    double brightness,
    double contrast,
    double saturation,
    double hue,
  ) {
    final s = 1.0 + saturation;
    final invS = 1.0 - s;
    const lr = 0.213;
    const lg = 0.715;
    const lb = 0.072;
    final c = 1.0 + contrast;
    final t = 0.5 * (1.0 - c);
    final b = brightness;

    final m = <double>[
      c * (lr * invS + s),
      c * lg * invS,
      c * lb * invS,
      0,
      b + t,
      c * lr * invS,
      c * (lg * invS + s),
      c * lb * invS,
      0,
      b + t,
      c * lr * invS,
      c * lg * invS,
      c * (lb * invS + s),
      0,
      b + t,
      0,
      0,
      0,
      1,
      0,
    ];

    if (hue != 0) {
      final hueRad = hue * 3.1415926535897932 / 180;
      final cosVal = math.cos(hueRad);
      final sinVal = math.sin(hueRad);
      final lumR = 0.213;
      final lumG = 0.715;
      final lumB = 0.072;

      final hMat = <double>[
        lumR + cosVal * (1 - lumR) + sinVal * (-lumR),
        lumG + cosVal * (-lumG) + sinVal * (-lumG),
        lumB + cosVal * (-lumB) + sinVal * (1 - lumB),
        0,
        0,
        lumR + cosVal * (-lumR) + sinVal * (0.143),
        lumG + cosVal * (1 - lumG) + sinVal * (0.140),
        lumB + cosVal * (-lumB) + sinVal * (-0.283),
        0,
        0,
        lumR + cosVal * (-lumR) + sinVal * (-(1 - lumR)),
        lumG + cosVal * (-lumG) + sinVal * (lumG),
        lumB + cosVal * (1 - lumB) + sinVal * (lumB),
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ];
      return _concat(hMat, m);
    }
    return m;
  }

  List<double> _concat(List<double> m1, List<double> m2) {
    final result = List<double>.filled(20, 0.0);
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 5; j++) {
        double sum = 0;
        for (int k = 0; k < 4; k++) {
          sum += m1[i * 5 + k] * m2[k * 5 + j];
        }
        if (j == 4) sum += m1[i * 5 + 4];
        result[i * 5 + j] = sum;
      }
    }
    return result;
  }
}

class HslUtils {
  /// RGB [0..255] → HSL [0..1, 0..1, 0..1]
  static List<double> rgbToHsl(int r, int g, int b) {
    final rd = r / 255.0;
    final gd = g / 255.0;
    final bd = b / 255.0;

    final max = [rd, gd, bd].reduce((a, b) => a > b ? a : b);
    final min = [rd, gd, bd].reduce((a, b) => a < b ? a : b);
    final l = (max + min) / 2.0;

    if (max == min) return [0.0, 0.0, l]; // grayscale

    final d = max - min;
    final s = l > 0.5 ? d / (2.0 - max - min) : d / (max + min);

    double h;
    if (max == rd) {
      h = ((gd - bd) / d) + (gd < bd ? 6.0 : 0.0);
    } else if (max == gd) {
      h = ((bd - rd) / d) + 2.0;
    } else {
      h = ((rd - gd) / d) + 4.0;
    }
    h /= 6.0;

    return [h, s, l];
  }

  /// HSL [0..1, 0..1, 0..1] → RGB [0..255]
  static List<int> hslToRgb(double h, double s, double l) {
    double r, g, b;

    if (s == 0) {
      r = g = b = l;
    } else {
      final q = l < 0.5 ? l * (1.0 + s) : l + s - l * s;
      final p = 2.0 * l - q;
      r = _hue2rgb(p, q, h + 1.0 / 3.0);
      g = _hue2rgb(p, q, h);
      b = _hue2rgb(p, q, h - 1.0 / 3.0);
    }

    return [
      (r * 255.0).round().clamp(0, 255),
      (g * 255.0).round().clamp(0, 255),
      (b * 255.0).round().clamp(0, 255),
    ];
  }

  static double _hue2rgb(double p, double q, double t) {
    if (t < 0) t += 1;
    if (t > 1) t -= 1;
    if (t < 1 / 6) return p + (q - p) * 6.0 * t;
    if (t < 1 / 2) return q;
    if (t < 2 / 3) return p + (q - p) * (2.0 / 3.0 - t) * 6.0;
    return p;
  }
}

class HslChannel {
  /// Returns null for grayscale / near-grayscale so only Master applies.
  static int? fromHue(double h, double s) {
    if (s < 0.005) return null; // ← FIX: prevents gray pixels mapping to Red

    if (h >= 0.92 || h < 0.08) return 1; // Red
    if (h < 0.25) return 2; // Yellow
    if (h < 0.42) return 3; // Green
    if (h < 0.58) return 4; // Cyan
    if (h < 0.75) return 5; // Blue
    return 6; // Magenta
  }
}

class HslProcessor {
  // Fixed constants to match matrix-based live preview calculations
  // Hue: ±180° (same as matrix), Saturation: -1 to +1, Luminance: -1 to +1
  static const double _maxHueShift = 180.0; // ±180° to match matrix
  static const double _maxLumShift = 1.0; // ±1.0 to match matrix

  /// Fast path: check if every slider is at 0.5 (neutral).
  static bool isNeutral(List<Map<String, double>> adj) {
    for (final m in adj) {
      if ((m['hue']! - 0.5).abs() > 0.001) return false;
      if ((m['saturation']! - 0.5).abs() > 0.001) return false;
      if ((m['luminance']! - 0.5).abs() > 0.001) return false;
    }
    return true;
  }

  /// [adjustments] = List length 7 (index 0 = Master, 1..6 = channels)
  static Uint8List apply(
    Uint8List rgba,
    List<Map<String, double>> adjustments,
  ) {
    final bool neutral = isNeutral(adjustments);

    // Fast path: no work needed
    if (neutral) return Uint8List.fromList(rgba);

    final out = Uint8List(rgba.length);

    for (int i = 0; i < rgba.length; i += 4) {
      final r = rgba[i];
      final g = rgba[i + 1];
      final b = rgba[i + 2];
      final a = rgba[i + 3];

      final hsl = HslUtils.rgbToHsl(r, g, b);
      var h = hsl[0]; // [0..1]
      var s = hsl[1];
      var l = hsl[2];

      // ── Master (index 0) ──
      // FIXED: Match matrix calculations exactly:
      // - Hue: (value - 0.5) * 360 (same as matrix)
      // - Saturation: (value - 0.5) * 2 (same as matrix)
      // - Luminance: (value - 0.5) * 2 (same as matrix)
      final master = adjustments[0];
      double hueShift = (master['hue']! - 0.5) * _maxHueShift;
      double satShift = (master['saturation']! - 0.5) * 2.0;
      double lumShift = (master['luminance']! - 0.5) * _maxLumShift;

      // ── Channel-specific (1..6) ──
      final channelIdx = HslChannel.fromHue(h, s);
      if (channelIdx != null) {
        final ch = adjustments[channelIdx];
        hueShift += (ch['hue']! - 0.5) * _maxHueShift;
        satShift += (ch['saturation']! - 0.5) * 2.0;
        lumShift += (ch['luminance']! - 0.5) * _maxLumShift;
      }

      // ── Apply ──
      // Hue (additive shift)
      double hDeg = h * 360.0 + hueShift;
      hDeg = hDeg % 360.0;
      if (hDeg < 0) hDeg += 360.0;
      h = hDeg / 360.0;

      // Saturation (additive shift to match matrix behavior)
      s = (s + satShift).clamp(0.0, 1.0);

      // Luminance (additive shift)
      l = (l + lumShift).clamp(0.0, 1.0);

      // ── Back to RGB ──
      final rgb = HslUtils.hslToRgb(h, s, l);
      out[i] = rgb[0];
      out[i + 1] = rgb[1];
      out[i + 2] = rgb[2];
      out[i + 3] = a;
    }
    return out;
  }
}

class GrainPainter extends CustomPainter {
  final double strength;
  final ui.Image? image; // null = preview hasn't loaded yet
  final ui.Rect? imageDstRect; // where to draw the image in canvas space

  GrainPainter({required this.strength, this.image, this.imageDstRect});

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    // 1. Draw the image first (so grain can overlay it)
    if (image != null && imageDstRect != null) {
      final srcRect = ui.Rect.fromLTWH(
        0,
        0,
        image!.width.toDouble(),
        image!.height.toDouble(),
      );
      canvas.drawImageRect(image!, srcRect, imageDstRect!, ui.Paint());
    }

    // 2. Grain overlay (now blends with the image, not transparency)
    if (strength <= 0.001) return;

    final rand = math.Random(42); // fixed seed = preview matches bake perfectly

    final darkAlpha = (strength * 110).round().clamp(0, 255);
    final lightAlpha = (strength * 100).round().clamp(0, 255);

    final darkPaint = ui.Paint()
      ..color = ui.Color.fromARGB(darkAlpha, 0, 0, 0)
      ..blendMode = ui.BlendMode.overlay;

    final lightPaint = ui.Paint()
      ..color = ui.Color.fromARGB(lightAlpha, 255, 255, 255)
      ..blendMode = ui.BlendMode.overlay;

    // Density scales with strength: starts at 0.3% and goes up to 1.0% at max strength
    final numDots = (size.width * size.height * (0.003 + strength * 0.007))
        .toInt();

    for (int i = 0; i < numDots; i++) {
      final dx = rand.nextDouble() * size.width;
      final dy = rand.nextDouble() * size.height;
      // Radius ranges up to 2.5x larger at max strength
      double radius = 0.2 + rand.nextDouble() * (0.4 + strength * 2.5);

      if (rand.nextDouble() < 0.10) radius *= 2.5;

      final paint = rand.nextBool() ? darkPaint : lightPaint;
      canvas.drawCircle(ui.Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant GrainPainter oldDelegate) =>
      oldDelegate.strength != strength ||
      oldDelegate.image != image ||
      oldDelegate.imageDstRect != imageDstRect;
}
