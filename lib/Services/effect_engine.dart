import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/services.dart';

class EffectEngine {
  static final EffectEngine _instance = EffectEngine._internal();
  factory EffectEngine() => _instance;
  EffectEngine._internal();

  /// Decodes an image from a local file path.
  Future<ui.Image> decodeImageFromFile(File file) async {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Decodes an image from a Flutter asset path.
  Future<ui.Image> decodeImageFromAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// Composites a base image with an overlay effect.
  Future<ui.Image> composite({
    required ui.Image baseImage,
    required ui.Image overlayImage,
    required double opacity,
    required ui.BlendMode blendMode,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final baseSize = ui.Size(
      baseImage.width.toDouble(),
      baseImage.height.toDouble(),
    );
    canvas.drawImage(baseImage, ui.Offset.zero, ui.Paint());

    final overlayPaint = ui.Paint()
      ..color = ui.Color.fromRGBO(255, 255, 255, opacity)
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

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final fullRect = ui.Rect.fromLTWH(0, 0, imgW, imgH);
    final circlePath = ui.Path()
      ..addOval(ui.Rect.fromCircle(center: center, radius: radius));

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
    canvas.save();
    canvas.clipPath(adjustPath);

    final ui.Paint drawPaint = ui.Paint();
    if (brightness != 0 || contrast != 0 || saturation != 0 || hue != 0) {
      drawPaint.colorFilter = ui.ColorFilter.matrix(
        buildColorMatrix(brightness, contrast, saturation, hue),
      );
    }
    if (blur > 0) {
      drawPaint.imageFilter = ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur);
    }

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

  /// Blurs the background and overlays a sharp foreground subject.
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
    final paint = ui.Paint()
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: blurIntensity,
        sigmaY: blurIntensity,
      );
    canvas.drawImage(baseImage, ui.Offset.zero, paint);

    // 2. Draw sharp foreground
    final fw = foregroundImage.width.toDouble();
    final fh = foregroundImage.height.toDouble();
    double scale = width / fw;
    if (height / fh < scale) scale = height / fh;

    canvas.save();
    canvas.translate(width / 2, height / 2);
    canvas.scale(scale);
    canvas.translate(-fw / 2, -fh / 2);
    canvas.drawImage(foregroundImage, ui.Offset.zero, ui.Paint());
    canvas.restore();

    final picture = recorder.endRecording();
    return await picture.toImage(width.toInt(), height.toInt());
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
  static const List<double> _hueCenters = [
    0, // Master – unused but kept for alignment
    0, // Red
    60, // Yellow
    120, // Green
    180, // Cyan
    240, // Blue
    300, // Magenta
  ];

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

    final byteData = await srcImg.toByteData();
    if (byteData == null) throw Exception('Failed to read image pixels');
    final pixels = byteData.buffer.asUint32List();
    final outBytes = Uint8List(w * h * 4);

    // Pre‑compute adjustment parameters
    final List<_HSLDelta> deltas = [];
    for (int i = 0; i < 7; i++) {
      final adj = adjustments[i];
      deltas.add(
        _HSLDelta(
          hueShift: (adj['hue']! - 0.5) * 360.0,
          satMult: 1.0 + (adj['saturation']! - 0.5) * 2.0,
          lumShift: (adj['luminance']! - 0.5).clamp(-0.5, 0.5),
        ),
      );
    }

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final idx = y * w + x;
        final pixel = pixels[idx];

        final a = (pixel >> 24) & 0xFF;
        final r = (pixel >> 16) & 0xFF;
        final g = (pixel >> 8) & 0xFF;
        final b = pixel & 0xFF;

        // ─── RGBA → HSL ─────────────────────────────────────────────
        double rf = r / 255.0;
        double gf = g / 255.0;
        double bf = b / 255.0;

        final maxC = math.max(rf, math.max(gf, bf));
        final minC = math.min(rf, math.min(gf, bf));
        final delta = maxC - minC;

        double hh = 0.0;
        double ss = 0.0;
        double ll = (maxC + minC) / 2.0;

        if (delta != 0) {
          ss = ll <= 0.5 ? delta / (maxC + minC) : delta / (2.0 - maxC - minC);

          if (rf == maxC) {
            hh = (gf - bf) / delta + (gf < bf ? 6.0 : 0.0);
          } else if (gf == maxC) {
            hh = (bf - rf) / delta + 2.0;
          } else {
            hh = (rf - gf) / delta + 4.0;
          }
          hh *= 60.0;
        }

        // ─── Accumulate adjustments ─────────────────────────────────
        double hueAccum = 0.0;
        double satAccum = 1.0;
        double lumAccum = 0.0;

        // Master (index 0) – always applied
        final m = deltas[0];
        hueAccum += m.hueShift;
        satAccum *= m.satMult;
        lumAccum += m.lumShift;

        // Selective colours (indices 1‑6)
        for (int ci = 1; ci <= 6; ci++) {
          final d = deltas[ci];
          final wgt = _hueWeight(hh, _hueCenters[ci], 30);
          if (wgt > 0) {
            hueAccum += d.hueShift * wgt;
            // Lerp saturation multiplier
            satAccum = 1.0 + (satAccum - 1.0) + (d.satMult - 1.0) * wgt;
            lumAccum += d.lumShift * wgt;
          }
        }

        // ─── Apply ──────────────────────────────────────────────────
        hh = (hh + hueAccum) % 360.0;
        if (hh < 0) hh += 360.0;
        ss = (ss * satAccum).clamp(0.0, 1.0);
        ll = (ll + lumAccum).clamp(0.0, 1.0);

        // ─── HSL → RGBA ─────────────────────────────────────────────
        int rr, gg, bb;
        if (ss == 0) {
          final v = (ll * 255).round().clamp(0, 255);
          rr = v;
          gg = v;
          bb = v;
        } else {
          final q = ll < 0.5 ? ll * (1.0 + ss) : ll + ss - ll * ss;
          final p = 2.0 * ll - q;
          final hk = hh / 360.0;

          rr = _hueToRgb(p, q, hk + 1.0 / 3.0);
          gg = _hueToRgb(p, q, hk);
          bb = _hueToRgb(p, q, hk - 1.0 / 3.0);
        }

        final outIdx = idx * 4;
        outBytes[outIdx] = rr;
        outBytes[outIdx + 1] = gg;
        outBytes[outIdx + 2] = bb;
        outBytes[outIdx + 3] = a;
      }
    }

    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      outBytes,
      w,
      h,
      ui.PixelFormat.rgba8888,
      (image) => completer.complete(image),
    );
    return completer.future;
  }

  /// Returns a weight [0‑1] for how much a given hue is affected by a
  /// colour range centred at [centerHue] with a [halfWidth]° core.
  /// A 10° soft falloff is applied beyond the core.
  static double _hueWeight(
    double pixelHue,
    double centerHue,
    double halfWidth,
  ) {
    double diff = (pixelHue - centerHue) % 360.0;
    if (diff < 0) diff += 360.0;
    if (diff > 180) diff = 360.0 - diff;

    if (diff <= halfWidth) return 1.0;
    final falloff = halfWidth + 15.0;
    if (diff >= falloff) return 0.0;
    return 1.0 - (diff - halfWidth) / (falloff - halfWidth);
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

  List<double> _buildSingleSelectiveMatrix(int colorIndex, double h, double s, double l) {
    // Photoshop-style Selective Matrix:
    // Target pixels where the selected color is dominant.
    
    int p = 0, s1 = 1, s2 = 2; 
    bool isSecondary = false;

    switch (colorIndex) {
      case 1: p = 0; s1 = 1; s2 = 2; break; // Red
      case 2: p = 2; s1 = 0; s2 = 1; isSecondary = true; break; // Yellow
      case 3: p = 1; s1 = 0; s2 = 2; break; // Green
      case 4: p = 0; s1 = 1; s2 = 2; isSecondary = true; break; // Cyan
      case 5: p = 2; s1 = 0; s2 = 1; break; // Blue
      case 6: p = 1; s1 = 0; s2 = 2; isSecondary = true; break; // Magenta
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
    final t = 0.5 * (1.0 - c) * 255;
    final b = brightness * 255;

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

/// Helper class for per‑pixel HSL deltas.
class _HSLDelta {
  final double hueShift;
  final double satMult;
  final double lumShift;
  const _HSLDelta({
    required this.hueShift,
    required this.satMult,
    required this.lumShift,
  });
}
