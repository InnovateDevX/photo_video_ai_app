import 'dart:ui';
import 'package:flutter/material.dart';

class AppGradients {
  static const LinearGradient proGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF991B1B), // 0% — deep red
      Color(0xFFF97316), // 100% — orange
    ],
  );

  /// Gaussian blur sigma applied by [ProGradientDecoration]
  static const double blurSigma = 6.0;
}

/// Drop-in replacement for [BoxDecoration] that automatically applies
/// a Gaussian blur to [AppGradients.proGradient].
///
/// Usage — anywhere you previously had:
///   BoxDecoration(gradient: AppGradients.proGradient, borderRadius: r)
/// Use:
///   ProGradientDecoration(borderRadius: r)
class ProGradientDecoration extends Decoration {
  const ProGradientDecoration({
    this.borderRadius = BorderRadius.zero,
    this.shape = BoxShape.rectangle,
    this.border,
    this.boxShadow,
    this.blurSigma,
    this.color,
  });

  final BorderRadius borderRadius;
  final BoxShape shape;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final double? blurSigma;
  final Color? color;

  ProGradientDecoration copyWith({
    BorderRadius? borderRadius,
    BoxShape? shape,
    Border? border,
    List<BoxShadow>? boxShadow,
    double? blurSigma,
    Color? color,
  }) {
    return ProGradientDecoration(
      borderRadius: borderRadius ?? this.borderRadius,
      shape: shape ?? this.shape,
      border: border ?? this.border,
      boxShadow: boxShadow ?? this.boxShadow,
      blurSigma: blurSigma ?? this.blurSigma,
      color: color ?? this.color,
    );
  }

  @override
  EdgeInsetsGeometry get padding => EdgeInsets.zero;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _ProGradientPainter(this);
}

class _ProGradientPainter extends BoxPainter {
  const _ProGradientPainter(this.d);
  final ProGradientDecoration d;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration cfg) {
    final rect = offset & (cfg.size ?? Size.zero);
    final rrect = d.shape == BoxShape.circle
        ? RRect.fromRectXY(rect, rect.shortestSide / 2, rect.shortestSide / 2)
        : d.borderRadius.toRRect(rect);

    // 1 — box shadows (drawn before clip so they appear outside the shape)
    if (d.boxShadow != null) {
      for (final shadow in d.boxShadow!) {
        canvas.drawRRect(
          rrect.shift(shadow.offset).inflate(shadow.spreadRadius),
          shadow.toPaint(),
        );
      }
    }

    // 2 — clip to shape so blur doesn't bleed outside the boundary
    canvas.save();
    canvas.clipRRect(rrect);

    // 3 — draw the gradient inside a blurred layer
    final sigma = d.blurSigma ?? AppGradients.blurSigma;

    if (d.color != null) {
      canvas.drawRRect(rrect, Paint()..color = d.color!);
    } else {
      canvas.saveLayer(
        rect.inflate(sigma * 2),
        Paint()..imageFilter = ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      );
      canvas.drawRect(
        rect.inflate(sigma * 2), // inflate so blur edges don't fade at boundary
        Paint()
          ..shader = AppGradients.proGradient.createShader(
            rect.inflate(sigma * 2),
          ),
      );
      canvas.restore(); // end saveLayer
    }

    canvas.restore(); // end clipRRect

    // 4 — border on top
    d.border?.paint(
      canvas,
      rect,
      shape: d.shape,
      borderRadius: d.shape == BoxShape.circle ? null : d.borderRadius,
    );
  }
}
