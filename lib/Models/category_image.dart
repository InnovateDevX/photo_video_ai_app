import 'package:flutter/foundation.dart';

/// Sanitizes a Firebase Storage URL by properly encoding the object path portion.
///
/// Firebase Storage URLs have the format:
///   https://firebasestorage.googleapis.com/v0/b/<bucket>/o/<encoded-path>?alt=media&token=<token>
///
/// This function handles ALL of the following cases:
///   • Already-encoded URLs (no-op, returned unchanged)
///   • URLs with raw spaces or other un-encoded characters from Remote Config
///   • URLs where + is unencoded (should be %2B in paths)
///   • URLs with parentheses, apostrophes, and other special chars
String sanitizeFirebaseUrl(String url) {
  if (url.isEmpty) return url;

  // ── Step 1: pre-process raw spaces so Uri.parse does not throw ──────────
  // Some URLs pasted into Firebase Remote Config may contain literal spaces.
  // Uri.parse will throw a FormatException on them, so replace before parsing.
  final preProcessed = url
      .trim()
      .replaceAll(' ', '%20')
      .replaceAll('\t', '%09')
      .replaceAll('\n', '')
      .replaceAll('\r', '');

  try {
    final uri = Uri.parse(preProcessed);

    // ── Step 2: verify this is a Firebase Storage URL ──────────────────────
    // Path structure: /v0/b/<bucket>/o/<object-path>
    // pathSegments:   [v0, b, bucket, o, ...object-path decoded segments]
    if (!uri.host.contains('firebasestorage.googleapis.com')) {
      return preProcessed;
    }

    // pathSegments.length >= 5 guarantees [v0, b, bucket, o, <object>]
    if (uri.pathSegments.length < 5 ||
        uri.pathSegments[0] != 'v0' ||
        uri.pathSegments[1] != 'b' ||
        uri.pathSegments[3] != 'o') {
      return preProcessed;
    }

    // ── Step 3: extract & re-encode the object path ────────────────────────
    final bucket = uri.pathSegments[2];
    final pathPrefix = '/v0/b/$bucket/o/';

    // uri.path preserves percent-encoding, giving us the raw encoded object path.
    // If the object path starts after pathPrefix we can substring safely.
    if (!uri.path.startsWith(pathPrefix)) return preProcessed;
    final encodedPath = uri.path.substring(pathPrefix.length);

    // Decode then re-encode to normalise any partially-encoded or unencoded chars.
    //   Uri.decodeComponent  →  reverses %XX escapes
    //   Uri.encodeComponent  →  re-encodes everything (space→%20, +→%2B, etc.)
    // This is idempotent: already-correct URLs are returned unchanged.
    String properlyEncodedPath;
    try {
      final decoded = Uri.decodeComponent(encodedPath);
      properlyEncodedPath = Uri.encodeComponent(decoded);
    } catch (_) {
      // Malformed %-sequence — use the already pre-processed path as-is
      properlyEncodedPath = encodedPath;
    }

    // ── Step 4: reconstruct ────────────────────────────────────────────────
    final sb = StringBuffer()
      ..write('${uri.scheme}://${uri.host}')
      ..write(pathPrefix)
      ..write(properlyEncodedPath);
    if (uri.query.isNotEmpty) {
      sb.write('?${uri.query}');
    }
    return sb.toString();
  } catch (e) {
    debugPrint('⚠️ [sanitizeFirebaseUrl] Failed to parse URL: $e\n  URL: $url');
    // Last resort: return the pre-processed string (spaces replaced with %20)
    return preProcessed;
  }
}



/// Model class representing an image within a category
class CategoryImage {
  final String title;
  final String imageUrl;
  final String? videoUrl;
  final String modelUsed;
  final String prompt;
  final String videoModelUsed;
  final String videoPrompt;

  /// Type of content: 'image', 'video', or 'category'
  final String type;

  /// Firestore document ID of the reel (used when type is 'video')
  final String? reelId;

  /// Optional thumbnail URL for videos
  final String? thumbnailUrl;

  /// Optional list of image URLs for slideshow
  final List<String>? imageUrls;

  /// The name of the category (used when type is 'category')
  final String? categoryName;

  /// Whether the image model is editable / image-to-image
  final bool isEditable;

  /// Number of uploadable images the model supports
  final int noOfUploadable;

  CategoryImage({
    this.title = '',
    this.imageUrl = '',
    this.videoUrl,
    this.modelUsed = '',
    this.prompt = '',
    this.videoModelUsed = '',
    this.videoPrompt = '',
    this.type = 'image',
    this.reelId,
    this.thumbnailUrl,
    this.categoryName,
    this.isEditable = false,
    this.imageUrls,
    this.noOfUploadable = 1,
  });

  factory CategoryImage.fromJson(Map<String, dynamic> json) {
    final parsedVideoUrl =
        json['videoUrl'] as String? ?? json['reelUrl'] as String?;
    final parsedReelId = json['reelId'] as String?;
    final determinedType =
        (parsedVideoUrl != null && parsedVideoUrl.trim().isNotEmpty)
            ? 'video'
            : (json['type'] as String? ??
                ((parsedReelId != null) ? 'video' : 'image'));

    List<String>? parsedImageUrls;
    String parsedImageUrl = '';

    final dynamic imageUrlData = json['imageUrl'];
    if (imageUrlData is List) {
      parsedImageUrls = imageUrlData
          .map((e) => sanitizeFirebaseUrl(e.toString()))
          .toList();
      if (parsedImageUrls.isNotEmpty) {
        parsedImageUrl = parsedImageUrls.first;
      }
    } else if (imageUrlData is String) {
      parsedImageUrl = sanitizeFirebaseUrl(imageUrlData);
      parsedImageUrls = [parsedImageUrl];
    } else if (json['imageUrls'] is List) {
      parsedImageUrls = (json['imageUrls'] as List)
          .map((e) => sanitizeFirebaseUrl(e.toString()))
          .toList();
      if (parsedImageUrls.isNotEmpty) {
        parsedImageUrl = parsedImageUrls.first;
      }
    } else {
      parsedImageUrl = sanitizeFirebaseUrl(json['imageUrl'] as String? ?? '');
      if (parsedImageUrl.isNotEmpty) {
        parsedImageUrls = [parsedImageUrl];
      }
    }

    return CategoryImage(
      title: json['title'] as String? ?? '',
      imageUrl: parsedImageUrl,
      imageUrls: parsedImageUrls,
      videoUrl: parsedVideoUrl != null
          ? sanitizeFirebaseUrl(parsedVideoUrl)
          : null,
      modelUsed: json['modelUsed'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      videoModelUsed: json['videoModelUsed'] as String? ?? '',
      videoPrompt: json['videoPrompt'] as String? ?? '',
      type: determinedType,
      reelId: parsedReelId,
      thumbnailUrl: json['thumbnailUrl'] != null
          ? sanitizeFirebaseUrl(json['thumbnailUrl'] as String)
          : null,
      categoryName: json['categoryName'] as String?,
      isEditable: (json['isEditable'] ?? json['iseditable']) as bool? ?? false,
      noOfUploadable: json['no_of_uploadable'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (title.isNotEmpty) 'title': title,
      'imageUrl': imageUrl,
      if (videoUrl != null) 'videoUrl': videoUrl,
      'modelUsed': modelUsed,
      'prompt': prompt,
      if (videoModelUsed.isNotEmpty) 'videoModelUsed': videoModelUsed,
      if (videoPrompt.isNotEmpty) 'videoPrompt': videoPrompt,
      'type': type,
      if (reelId != null) 'reelId': reelId,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (categoryName != null) 'categoryName': categoryName,
      'isEditable': isEditable,
      if (imageUrls != null) 'imageUrls': imageUrls,
      if (noOfUploadable != 1) 'no_of_uploadable': noOfUploadable,
    };
  }
}

/// Model class representing a category with its images
class CategoryData {
  final String name;
  final bool shuffle;
  final List<CategoryImage> images;

  CategoryData({
    required this.name,
    this.shuffle = false,
    required this.images,
  });

  factory CategoryData.fromJson(Map<String, dynamic> json) {
    final imagesList =
        (json['images'] as List<dynamic>?) ??
        (json['items'] as List<dynamic>?) ??
        [];
    return CategoryData(
      name: json['name'] as String? ?? '',
      shuffle: json['shuffle'] as bool? ?? false,
      images: imagesList
          .map((img) => CategoryImage.fromJson(img as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'shuffle': shuffle,
      'images': images.map((img) => img.toJson()).toList(),
    };
  }
}
