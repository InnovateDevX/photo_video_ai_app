import 'dart:typed_data';
import 'dart:ui' as ui;
import '../Models/curves_data.dart';

class CurvesProcessor {
  /// Applies curves via 256-entry LUT. O(n) per pixel, extremely fast.
  static Uint8List apply(Uint8List rgba, CurvesData curves) {
    final mLut = _buildLut(curves.master);
    final rLut = _buildLut(curves.red);
    final gLut = _buildLut(curves.green);
    final bLut = _buildLut(curves.blue);

    final out = Uint8List(rgba.length);

    for (int i = 0; i < rgba.length; i += 4) {
      final r = rgba[i];
      final g = rgba[i + 1];
      final b = rgba[i + 2];
      final a = rgba[i + 3];

      // Combine: channel curve + master curve - identity (Photoshop-style)
      out[i] = (rLut[r] + mLut[r] - r).clamp(0, 255);
      out[i + 1] = (gLut[g] + mLut[g] - g).clamp(0, 255);
      out[i + 2] = (bLut[b] + mLut[b] - b).clamp(0, 255);
      out[i + 3] = a;
    }
    return out;
  }

  static List<int> _buildLut(List<ui.Offset> points) {
    final lut = List<int>.filled(256, 0);
    if (points.length < 2) {
      for (int i = 0; i < 256; i++) {
        lut[i] = i;
      }
      return lut;
    }

    final sorted = List<ui.Offset>.from(points)
      ..sort((a, b) => a.dx.compareTo(b.dx));

    for (int i = 0; i < 256; i++) {
      final x = i / 255.0;
      lut[i] = (_interpolate(sorted, x) * 255.0).round().clamp(0, 255);
    }
    return lut;
  }

  static double _interpolate(List<ui.Offset> sorted, double x) {
    if (x <= sorted.first.dx) return sorted.first.dy;
    if (x >= sorted.last.dx) return sorted.last.dy;

    for (int i = 0; i < sorted.length - 1; i++) {
      final a = sorted[i];
      final b = sorted[i + 1];
      if (x >= a.dx && x <= b.dx) {
        final t = (x - a.dx) / (b.dx - a.dx);
        return a.dy + (b.dy - a.dy) * t;
      }
    }
    return sorted.last.dy;
  }
}
