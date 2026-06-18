import 'dart:async';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

/// Result of a paginated sticker fetch.
class StickerPage {
  final List<Reference> refs;
  final String? nextPageToken; // null means no more pages
  StickerPage({required this.refs, this.nextPageToken});
}

class FirebaseStickerService {
  static final FirebaseStickerService _instance =
      FirebaseStickerService._internal();
  factory FirebaseStickerService() => _instance;
  FirebaseStickerService._internal();

  static const int pageSize = 30;

  // Accumulated refs per category (all pages fetched so far)
  final Map<String, List<Reference>> _cachedStickers = {};
  // Next page tokens per category (null = no more pages / not yet fetched)
  final Map<String, String?> _nextPageTokens = {};
  // Which categories have had their FIRST page fetched
  final Set<String> _firstPageFetched = {};
  // Whether there are more pages available for a category
  final Map<String, bool> _hasMorePages = {};

  List<String> _cachedCategories = [];
  bool _isCategoriesLoaded = false;
  bool _isLoadingCategories = false;

  // Track which categories are currently loading to prevent duplicate calls
  final Set<String> _loadingCategories = {};

  Map<String, List<Reference>> get cachedStickers => _cachedStickers;
  List<String> get cachedCategories => _cachedCategories;

  /// Returns the refs fetched so far for a category.
  List<Reference> refsForCategory(String category) =>
      _cachedStickers[category] ?? [];

  /// Returns true if a first page has been fetched for this category.
  bool hasFirstPage(String category) => _firstPageFetched.contains(category);

  /// Returns true if more pages are available for this category.
  bool hasMorePages(String category) => _hasMorePages[category] ?? false;

  /// Returns true if the given category is currently loading.
  bool isLoadingCategory(String category) =>
      _loadingCategories.contains(category);

  /// Fetch only the list of category names (subfolders) from Firebase Storage.
  Future<List<String>> fetchCategories({bool forceRefresh = false}) async {
    if (_isCategoriesLoaded && !forceRefresh && _cachedCategories.isNotEmpty) {
      return _cachedCategories;
    }
    if (_isLoadingCategories) {
      while (_isLoadingCategories) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _cachedCategories;
    }
    _isLoadingCategories = true;
    try {
      debugPrint('[FirebaseStickerService] Fetching sticker categories...');
      final ListResult result = await FirebaseStorage.instance
          .ref('stickers')
          .listAll()
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw TimeoutException('listAll timed out for stickers root'),
          );
      _cachedCategories = result.prefixes.map((ref) => ref.name).toList();
      _isCategoriesLoaded = true;
      debugPrint(
        '[FirebaseStickerService] Loaded ${_cachedCategories.length} categories.',
      );
    } catch (e) {
      debugPrint('[FirebaseStickerService] Error listing categories: $e');
    } finally {
      _isLoadingCategories = false;
    }
    return _cachedCategories;
  }

  /// Fetch the FIRST page (up to [pageSize]) of sticker refs for a category.
  /// Safe to call multiple times — returns immediately if already loaded.
  Future<List<Reference>> fetchFirstPage(
    String category, {
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _firstPageFetched.contains(category)) {
      return _cachedStickers[category] ?? [];
    }
    if (_loadingCategories.contains(category)) {
      while (_loadingCategories.contains(category)) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _cachedStickers[category] ?? [];
    }
    _loadingCategories.add(category);
    try {
      debugPrint(
        '[FirebaseStickerService] Fetching first $pageSize refs for "$category"...',
      );
      final result = await FirebaseStorage.instance
          .ref('stickers/$category')
          .list(ListOptions(maxResults: pageSize))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () =>
                throw TimeoutException('list() timed out for $category'),
          );
      final refs = result.items;
      _cachedStickers[category] = List<Reference>.from(refs);
      _nextPageTokens[category] = result.nextPageToken;
      _hasMorePages[category] = result.nextPageToken != null;
      _firstPageFetched.add(category);
      debugPrint(
        '[FirebaseStickerService] First page for "$category": ${refs.length} refs, '
        'hasMore: ${result.nextPageToken != null}.',
      );
    } catch (e) {
      debugPrint(
        '[FirebaseStickerService] Error fetching first page for "$category": $e',
      );
      _cachedStickers.putIfAbsent(category, () => []);
      _hasMorePages[category] = false;
      _firstPageFetched.add(category); // mark done even on error
    } finally {
      _loadingCategories.remove(category);
    }
    return _cachedStickers[category]!;
  }

  /// Fetch the NEXT page of refs for a category and append to cache.
  /// Returns false if there are no more pages.
  Future<bool> fetchNextPage(String category) async {
    if (_loadingCategories.contains(category)) return false;
    if (!(_hasMorePages[category] ?? false)) return false;

    final pageToken = _nextPageTokens[category];
    if (pageToken == null) return false;

    _loadingCategories.add(category);
    try {
      debugPrint(
        '[FirebaseStickerService] Fetching next page for "$category" (token: $pageToken)...',
      );
      final result = await FirebaseStorage.instance
          .ref('stickers/$category')
          .list(ListOptions(maxResults: pageSize, pageToken: pageToken))
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw TimeoutException(
              'list() next page timed out for $category',
            ),
          );
      final newRefs = result.items;
      _cachedStickers[category]!.addAll(newRefs);
      _nextPageTokens[category] = result.nextPageToken;
      _hasMorePages[category] = result.nextPageToken != null;
      debugPrint(
        '[FirebaseStickerService] Next page for "$category": +${newRefs.length} refs, '
        'total: ${_cachedStickers[category]!.length}, hasMore: ${result.nextPageToken != null}.',
      );
      return true;
    } catch (e) {
      debugPrint(
        '[FirebaseStickerService] Error fetching next page for "$category": $e',
      );
      _hasMorePages[category] = false;
      return false;
    } finally {
      _loadingCategories.remove(category);
    }
  }

  // ── Legacy accessor kept for backward compatibility (app_initializer) ───────
  // Returns whatever refs have been fetched so far (may be empty on first call).
  Future<List<Reference>> fetchStickersForCategory(
    String category, {
    bool forceRefresh = false,
  }) => fetchFirstPage(category, forceRefresh: forceRefresh);
}
