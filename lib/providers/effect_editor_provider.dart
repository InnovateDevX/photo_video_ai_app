import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../Models/effect_overlay.dart';
import '../Services/effect_engine.dart';
import '../Services/effect_service.dart';

class EffectEditorProvider extends ChangeNotifier {
  final EffectEngine _engine = EffectEngine();

  File? _baseImageFile;
  ui.Image? _baseImage;
  ui.Image? _overlayImage;

  EffectOverlay? _selectedEffect;
  double _opacity = 0.8;
  bool _isLoading = false;

  File? get baseImageFile => _baseImageFile;
  ui.Image? get baseImage => _baseImage;
  ui.Image? get overlayImage => _overlayImage;
  EffectOverlay? get selectedEffect => _selectedEffect;
  double get opacity => _opacity;
  bool get isLoading => _isLoading;

  /// Initialize the editor with a base image.
  Future<void> setBaseImage(File file) async {
    _isLoading = true;
    notifyListeners();

    try {
      _baseImageFile = file;
      _baseImage = await _engine.decodeImageFromFile(file);
    } catch (e) {
      debugPrint('Error loading base image: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Select an effect to apply.
  Future<void> selectEffect(EffectOverlay effect) async {
    _isLoading = true;
    _selectedEffect = effect;
    notifyListeners();

    try {
      // Release old overlay memory
      _overlayImage?.dispose();

      final isPortrait =
          _baseImage == null || _baseImage!.width < _baseImage!.height;
      final path = effect.getEffectivePath(isPortrait);
      final filename = path.split('/').last.split('.').first;
      final index = int.tryParse(filename.replaceAll(RegExp(r'\D'), '')) ?? 1;

      ui.Image? newImage;
      try {
        final bytes = await EffectService().getEffectImage(
          category: effect.category,
          index: index,
          isPortrait: isPortrait,
        );
        if (bytes != null && bytes.isNotEmpty) {
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          newImage = frame.image;
        }
      } catch (e) {
        debugPrint(
          'Failed to load overlay from Firebase, falling back to local asset: $e',
        );
      }

      newImage ??= await _engine.decodeImageFromAsset(path);

      _overlayImage = newImage;
      _opacity = effect.defaultOpacity;
    } catch (e) {
      debugPrint('Error loading effect: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update opacity.
  void setOpacity(double value) {
    _opacity = value;
    notifyListeners();
  }

  /// Clear current effect.
  void clearEffect() {
    _selectedEffect = null;
    _overlayImage?.dispose();
    _overlayImage = null;
    notifyListeners();
  }

  /// Export the high-resolution final image.
  Future<File> exportFinalImage() async {
    if (_baseImage == null) {
      throw Exception('No base image loaded');
    }

    ui.Image finalUiImage;

    if (_overlayImage != null && _selectedEffect != null) {
      finalUiImage = await _engine.composite(
        baseImage: _baseImage!,
        overlayImage: _overlayImage!,
        opacity: _opacity,
        blendMode: _selectedEffect!.blendMode,
      );
    } else {
      finalUiImage = _baseImage!;
    }

    final bytes = await _engine.exportToBytes(finalUiImage);

    // Save to a temporary file
    final tempDir = Directory.systemTemp;
    final file = File(
      '${tempDir.path}/effect_export_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes);

    // Dispose the exported image if it's a new one
    if (finalUiImage != _baseImage) {
      finalUiImage.dispose();
    }

    return file;
  }

  @override
  void dispose() {
    _baseImage?.dispose();
    _overlayImage?.dispose();
    super.dispose();
  }
}
