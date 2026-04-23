import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:trail_ai_app/Services/remote_config_service.dart';
import 'package:flutter/foundation.dart';
import '../Core/directory.dart';

/// Centralized data caching service for Firebase resources.
class DataService {
  static final DataService _instance = DataService._internal();
  factory DataService() => _instance;
  DataService._internal();

  // --- Cache ---
  List<String> categories = [];
  List<Reference> trendingItems = [];
  List<Reference> trending2Items = [];
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
        final List<dynamic> parsed = json.decode(jsonStr);
        categories = parsed.cast<String>();
        debugPrint('📦 [DataService] Categories cached: ${categories.length}');
      }
    } catch (e) {
      debugPrint('❌ [DataService] Failed to fetch categories: $e');
    }
  }

  Future<void> _fetchInitialTrending() async {
    try {
      final results = await Future.wait([
        FirebaseStorage.instance
            .ref(AppDirectories.trendingDirectory)
            .list(const ListOptions(maxResults: 10)),
        FirebaseStorage.instance
            .ref(AppDirectories.trendingDirectory2)
            .list(const ListOptions(maxResults: 10)),
      ]);

      trendingItems = results[0].items;
      trending2Items = results[1].items;

      debugPrint('📦 [DataService] Initial trending items cached.');
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

  void updateTrendingCache(
    List<Reference> newItems, {
    bool isGallery2 = false,
  }) {
    if (isGallery2) {
      trending2Items = newItems;
    } else {
      trendingItems = newItems;
    }
  }
}
