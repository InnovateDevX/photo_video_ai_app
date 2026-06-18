import 'dart:ui';
import 'package:equatable/equatable.dart';

class EffectOverlay extends Equatable {
  final String id;
  final String category;
  final String? portraitPath;
  final String? squarePath;
  final String assetPath;
  final String thumbnailPath;
  final double defaultOpacity;
  final BlendMode blendMode;

  const EffectOverlay({
    required this.id,
    required this.category,
    this.portraitPath,
    this.squarePath,
    required this.assetPath,
    required this.thumbnailPath,
    this.defaultOpacity = 1.0,
    this.blendMode = BlendMode.screen,
  });

  String getEffectivePath(bool isPortrait) {
    if (isPortrait && portraitPath != null) return portraitPath!;
    if (!isPortrait && squarePath != null) return squarePath!;
    return assetPath;
  }

  factory EffectOverlay.fromJson(Map<String, dynamic> json) {
    return EffectOverlay(
      id: json['id'] as String,
      category: json['category'] as String,
      assetPath: json['assetPath'] as String,
      portraitPath: json['portraitPath'] as String?,
      squarePath: json['squarePath'] as String?,
      thumbnailPath: json['thumbnailPath'] as String,
      defaultOpacity: (json['defaultOpacity'] as num?)?.toDouble() ?? 1.0,
      blendMode: _parseBlendMode(json['blendMode'] as String?),
    );
  }

  static BlendMode _parseBlendMode(String? mode) {
    switch (mode?.toLowerCase()) {
      case 'screen':
        return BlendMode.screen;
      case 'overlay':
        return BlendMode.overlay;
      case 'plus':
      case 'add':
        return BlendMode.plus;
      case 'multiply':
        return BlendMode.multiply;
      case 'lighten':
        return BlendMode.lighten;
      case 'darken':
        return BlendMode.darken;
      default:
        return BlendMode.screen;
    }
  }

  @override
  List<Object?> get props => [
    id,
    category,
    assetPath,
    thumbnailPath,
    defaultOpacity,
    blendMode,
  ];

  @override
  String toString() =>
      'EffectOverlay(id: $id, category: $category, blendMode: $blendMode)';
}
