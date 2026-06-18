import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Service to load effect images from Firebase Storage
/// This enables lazy-loading of effect assets to reduce APK size
class EffectService {
  static final EffectService _instance = EffectService._internal();
  factory EffectService() => _instance;
  EffectService._internal();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Cache for downloaded effect images
  final Map<String, Uint8List> _imageCache = {};

  // Cache for download URLs
  final Map<String, String> _urlCache = {};

  // Base path in Firebase Storage where effects are stored
  static const String _basePath = 'effects';

  /// Get all available effect categories
  /// Returns a list of effect metadata that can be used to load images on demand
  List<Map<String, dynamic>> getEffectCategories() {
    // These should match the folder structure in Firebase Storage
    return [
      {'category': 'Butterfly', 'count': 9},
      {'category': 'Flower', 'count': 7},
      {'category': 'Heart', 'count': 8},
      {'category': 'Neon Light', 'count': 6},
      {'category': 'Star', 'count': 7},
    ];
  }

  /// Get effect image data from Firebase Storage
  /// [category] - The effect category (e.g., 'Butterfly', 'Flower')
  /// [index] - The effect index (1-based)
  /// [isPortrait] - Whether to use portrait or square variant
  Future<Uint8List?> getEffectImage({
    required String category,
    required int index,
    bool isPortrait = true,
  }) async {
    final folder = isPortrait ? 'potrait' : 'square';
    final cacheKey = '${category}_${index}_$folder';

    // Return cached image if available
    if (_imageCache.containsKey(cacheKey)) {
      return _imageCache[cacheKey];
    }

    try {
      final path = '$_basePath/$folder/$category/$index.png';
      final ref = _storage.ref().child(path);
      final data = await ref.getData();

      if (data != null) {
        _imageCache[cacheKey] = data;
      }
      return data;
    } catch (e) {
      debugPrint('Error loading effect image: $e');
      return null;
    }
  }

  /// Get effect thumbnail URL for lazy loading in grid
  Future<String?> getEffectThumbnailUrl({
    required String category,
    required int index,
  }) async {
    final cacheKey = '${category}_${index}_thumb';

    if (_urlCache.containsKey(cacheKey)) {
      return _urlCache[cacheKey];
    }

    try {
      // Try portrait first, then square
      String path = '$_basePath/potrait/$category/$index.png';
      var ref = _storage.ref().child(path);

      try {
        await ref.getMetadata();
      } catch (_) {
        // Fallback to square
        path = '$_basePath/square/$category/$index.png';
        ref = _storage.ref().child(path);
      }

      final url = await ref.getDownloadURL();
      _urlCache[cacheKey] = url;
      return url;
    } catch (e) {
      debugPrint('Error getting thumbnail URL: $e');
      return null;
    }
  }

  /// Preload effects for a specific category (for better UX)
  Future<void> preloadCategory(
    String category, {
    bool isPortrait = true,
  }) async {
    final effects = getEffectCategories();
    final categoryInfo = effects.firstWhere(
      (e) => e['category'] == category,
      orElse: () => {'count': 0},
    );

    final count = categoryInfo['count'] as int;
    for (int i = 1; i <= count; i++) {
      await getEffectImage(
        category: category,
        index: i,
        isPortrait: isPortrait,
      );
    }
  }

  /// Clear cache to free memory
  void clearCache() {
    _imageCache.clear();
    _urlCache.clear();
  }

  /// Get cache size in bytes
  int get cacheSize {
    int size = 0;
    for (final data in _imageCache.values) {
      size += data.length;
    }
    return size;
  }
}
