import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../Models/effect_overlay.dart';
import '../Services/effect_engine.dart';

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
      
      // Decode the overlay asset
      _overlayImage = await _engine.decodeImageFromAsset(effect.assetPath);
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
    final file = File('${tempDir.path}/effect_export_${DateTime.now().millisecondsSinceEpoch}.png');
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
