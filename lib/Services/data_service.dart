import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:trail_ai_app/Services/remote_config_service.dart';
import 'package:flutter/foundation.dart';
import '../Models/category_image.dart';

/// Centralized data caching service for Firebase resources.
class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  // --- Cache ---
  List<String> categories = [];
  List<CategoryData> categoryData =
      []; // New: structured category data with images
  List<CategoryImage> trendingItems = [];
  final Map<String, String> _urlCache = {};

  // --- Per-category cache ---
  final Map<String, List<Reference>> categoryItems = {};
  final Map<String, String?> categoryNextPageTokens = {};

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  // --- Failure tracking ---
  final Set<String> _failedCategories = {};
  bool isCategoryFailed(String category) =>
      _failedCategories.contains(category);

  // --- Initial Data Loading ---

  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('📦 [DataService] Pre-fetching initial data...');

    try {
      await Future.wait([_fetchCategories(), _fetchInitialTrending()]);
      _isInitialized = true;
      debugPrint('📦 [DataService] Initialization complete.');
    } catch (e) {
      debugPrint('❌ [DataService] Initialization failed: $e');
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final config = RemoteConfigService();
      await config.initialize();

      final jsonStr = config.categoriesJson;
      if (jsonStr.isNotEmpty && jsonStr != '[]') {
        final dynamic parsed = json.decode(jsonStr);

        // Check if it's the new structured format or legacy string array
        if (parsed is List) {
          // Check if first item is an object (new format) or string (legacy)
          if (parsed.isNotEmpty && parsed[0] is Map) {
            categoryData = parsed.map((cat) {
              final data = CategoryData.fromJson(cat as Map<String, dynamic>);
              if (data.shuffle) {
                data.images.shuffle();
              }
              return data;
            }).toList();
            categories = categoryData.map((c) => c.name).toList();
            debugPrint(
              '📦 [DataService] Structured categories cached: ${categories.length} (shuffled if enabled)',
            );
          } else {
            // Legacy format: ["Action", "Adventure", ...]
            categories = parsed.cast<String>();
            debugPrint(
              '📦 [DataService] Categories cached (legacy): ${categories.length}',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ [DataService] Failed to fetch categories: $e');
    }
  }

  /// Get category images with metadata for a specific category
  List<CategoryImage> getCategoryImages(String categoryName) {
    final category = categoryData.firstWhere(
      (c) => c.name.toLowerCase() == categoryName.toLowerCase(),
      orElse: () => CategoryData(name: categoryName, images: []),
    );
    return category.images;
  }

  /// Get image metadata for a specific image URL within a category
  CategoryImage? getImageMetadata(String categoryName, String imageUrl) {
    final images = getCategoryImages(categoryName);
    try {
      return images.firstWhere((img) => img.imageUrl == imageUrl);
    } catch (e) {
      return null;
    }
  }

  Future<void> _fetchInitialTrending() async {
    try {
      debugPrint('📦 [DataService] Starting _fetchInitialTrending...');
      final config = RemoteConfigService();
      final jsonStr = config.trendingDataJson;
      debugPrint('📦 [DataService] fetched trendingDataJson length: ${jsonStr.length}');
      debugPrint('📦 [DataService] trendingDataJson preview: ${jsonStr.substring(0, jsonStr.length > 100 ? 100 : jsonStr.length)}');
      if (jsonStr.isNotEmpty && jsonStr != '{}') {
        final dynamic parsed = json.decode(jsonStr);
        debugPrint('📦 [DataService] parsed JSON type: ${parsed.runtimeType}');
        if (parsed is Map<String, dynamic>) {
          final data = CategoryData.fromJson(parsed);
          debugPrint('📦 [DataService] data.images length: ${data.images.length}');
          if (data.shuffle) {
            data.images.shuffle();
          }
          trendingItems = data.images;
        } else if (parsed is List) {
          debugPrint('📦 [DataService] Parsed JSON is a List. Parsing directly.');
          final items = parsed.map((img) => CategoryImage.fromJson(img as Map<String, dynamic>)).toList();
          trendingItems = items;
        } else {
          debugPrint('📦 [DataService] ERROR: parsed JSON is neither Map nor List');
        }
        
        debugPrint(
          '📦 [DataService] Remote config trending items cached: ${trendingItems.length}',
        );
      } else {
        debugPrint('📦 [DataService] JSON is empty or "{}"');
      }
    } catch (e) {
      debugPrint('❌ [DataService] Failed to fetch initial trending: $e');
    }
  }

  // --- Per-category Pagination ---

  /// Fetches next page of images for a category folder: `categories/<category>/`
  Future<List<Reference>> fetchCategoryPage(
    String category, {
    int pageSize = 12,
  }) async {
    final pageToken = categoryNextPageTokens[category];
    // If we already received a null token, there are no more pages
    if (categoryNextPageTokens.containsKey(category) && pageToken == null) {
      return [];
    }

    if (_failedCategories.contains(category)) {
      return [];
    }

    try {
      final path = 'categories/$category/';
      final options = ListOptions(maxResults: pageSize, pageToken: pageToken);
      final result = await FirebaseStorage.instance.ref(path).list(options);

      final existing = categoryItems[category] ?? [];
      categoryItems[category] = [...existing, ...result.items];
      categoryNextPageTokens[category] = result.nextPageToken;

      debugPrint(
        '📦 [DataService] Fetched ${result.items.length} items for "$category". '
        'HasMore: ${result.nextPageToken != null}',
      );
      return result.items;
    } catch (e) {
      debugPrint('❌ [DataService] Failed to fetch category "$category": $e');
      _failedCategories.add(category);
      return [];
    }
  }

  bool hasCategoryMore(String category) {
    if (!categoryNextPageTokens.containsKey(category)) return true;
    return categoryNextPageTokens[category] != null;
  }

  // --- URL Caching ---

  String? getCachedURL(Reference ref) {
    return _urlCache[ref.fullPath];
  }

  Future<String> getDownloadURL(Reference ref) async {
    final path = ref.fullPath;
    if (_urlCache.containsKey(path)) {
      return _urlCache[path]!;
    }

    if (_failedCategories.contains(path)) {
      throw Exception("Failed to fetch URL previously.");
    }

    try {
      final url = await ref.getDownloadURL();
      _urlCache[path] = url;
      return url;
    } catch (e) {
      debugPrint('❌ [DataService] Failed to fetch URL for $path: $e');
      _failedCategories.add(
        path,
      ); // Re-using this set or could create a new one
      rethrow;
    }
  }


}
