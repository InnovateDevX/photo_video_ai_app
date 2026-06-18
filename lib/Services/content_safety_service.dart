import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'remote_config_service.dart';

/// Exception thrown when content is flagged by Azure Content Safety.
class NsfwContentException implements Exception {
  final String messageKey;
  final String? url;
  NsfwContentException(this.messageKey, {this.url});

  @override
  String toString() => messageKey;
}

class ContentSafetyService {
  static final ContentSafetyService _instance =
      ContentSafetyService._internal();
  factory ContentSafetyService() => _instance;
  ContentSafetyService._internal();

  /// Loads a text asset from the bundle.
  Future<String> _loadAssetString(String path) async {
    return await rootBundle.loadString(path);
  }
  /// Cache for the loaded local NSFW word list (loaded once from assets)
  List<String>? _cachedLocalWordlist;
  bool _wordlistLoaded = false;

  /// Loads all words from assets/nsfw_wordlist.json into a flat list.
  Future<List<String>> _loadLocalWordlist() async {
    if (_wordlistLoaded) return _cachedLocalWordlist ?? [];
    try {
      final jsonStr = await _loadAssetString('assets/nsfw_wordlist.json');
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      final Set<String> words = {};
      for (final entry in data.values) {
        if (entry is List) {
          for (final word in entry) {
            if (word is String && word.trim().isNotEmpty) {
              words.add(word.trim().toLowerCase());
            }
          }
        }
      }
      _cachedLocalWordlist = words.toList();
      _wordlistLoaded = true;
      debugPrint(
        '🛡️ [ContentSafetyService] Loaded ${_cachedLocalWordlist!.length} local NSFW words.',
      );
    } catch (e) {
      debugPrint('❌ [ContentSafetyService] Failed to load nsfw_wordlist.json: $e');
      _cachedLocalWordlist = [];
      _wordlistLoaded = true;
    }
    return _cachedLocalWordlist!;
  }

  /// Checks text against local wordlist. Returns matched word or null.
  String? _localWordlistMatch(String text, List<String> wordlist) {
    final lowerText = text.toLowerCase();
    for (final word in wordlist) {
      // Match whole-word or substring (single-character words always substring)
      if (word.length <= 2) {
        // Short words: exact word boundary match to avoid false positives
        final pattern = RegExp(r'\b' + RegExp.escape(word) + r'\b');
        if (pattern.hasMatch(lowerText)) return word;
      } else {
        if (lowerText.contains(word)) return word;
      }
    }
    return null;
  }

  /// Returns true if the [text] contains sexual content.
  /// Throws [NsfwContentException] if flagged.
  Future<void> checkTextSafe(String text) async {
    // ── Step 1: Local wordlist check (instant, offline-first) ──────────────
    debugPrint('🛡️ [ContentSafetyService] Step 1: Local wordlist check...');
    final wordlist = await _loadLocalWordlist();
    final matchedWord = _localWordlistMatch(text, wordlist);
    if (matchedWord != null) {
      debugPrint(
        '🚫 [ContentSafetyService] BLOCKED by local wordlist: "$matchedWord"',
      );
      throw NsfwContentException('restricted_content_detected');
    }
    debugPrint('✅ [ContentSafetyService] Local wordlist: CLEAN');

    // ── Step 2: Google Cloud Natural Language API (network) ─────────────────
    final config = RemoteConfigService();
    final apiKey = config.googleCloudApiKey;
    final maskedKey = apiKey.length > 8
        ? '${apiKey.substring(0, 4)}...${apiKey.substring(apiKey.length - 4)}'
        : (apiKey.isEmpty ? 'EMPTY' : 'SHORT_KEY');

    debugPrint(
      '🛡️ [ContentSafetyService] Step 2: Google Cloud Language API Key: $maskedKey (length: ${apiKey.length})',
    );

    if (apiKey.isEmpty) {
      debugPrint(
        '⚠️ [ContentSafetyService] Google Cloud Language API key not found. Skipping network check.',
      );
      return;
    }

    final uri = Uri.parse(
      'https://language.googleapis.com/v2/documents:moderateText?key=$apiKey',
    );

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final body = jsonEncode({
      'document': {'type': 'PLAIN_TEXT', 'content': text},
    });

    try {
      debugPrint(
        '🛡️ [ContentSafetyService] Requesting Google Cloud Language for text: "$text"',
      );
      final response = await http.post(uri, headers: headers, body: body);

      debugPrint(
        '🛡️ [ContentSafetyService] Response status: ${response.statusCode}',
      );
      debugPrint(
        '🛡️ [ContentSafetyService] Raw Response body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (_isTextSexualContent(json)) {
          debugPrint(
            '🚫 [ContentSafetyService] NSFW content detected by Google Cloud Language!',
          );
          throw NsfwContentException('restricted_content_detected');
        }
        debugPrint('✅ [ContentSafetyService] Google Cloud Language: CLEAN');
      } else {
        debugPrint(
          '⚠️ [ContentSafetyService] Google Language check failed [${response.statusCode}]: ${response.body}',
        );
      }
    } catch (e) {
      if (e is NsfwContentException) rethrow;
      debugPrint('❌ [ContentSafetyService] Error checking content safety: $e');
    }
  }

  /// Helper to check a [File] for safety.
  Future<void> checkImageFileSafe(File file) async {
    final bytes = await file.readAsBytes();
    await checkImageSafe(bytes);
  }

  /// Returns true if the [imageBytes] contains sexual content.
  /// Throws [NsfwContentException] if flagged.
  Future<void> checkImageSafe(Uint8List imageBytes) async {
    final config = RemoteConfigService();
    final apiKey = config.googleCloudApiKey;
    final maskedKey = apiKey.length > 8
        ? '${apiKey.substring(0, 4)}...${apiKey.substring(apiKey.length - 4)}'
        : (apiKey.isEmpty ? 'EMPTY' : 'SHORT_KEY');

    debugPrint(
      '🛡️ [ContentSafetyService] checkImageSafe: API Key: $maskedKey (length: ${apiKey.length})',
    );

    if (apiKey.isEmpty) {
      debugPrint(
        '⚠️ [ContentSafetyService] Google Cloud Vision API key not found. Skipping image check.',
      );
      throw NsfwContentException('google_cloud_credentials_missing');
    }

    final uri = Uri.parse(
      'https://vision.googleapis.com/v1/images:annotate?key=$apiKey',
    );

    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final body = jsonEncode({
      'requests': [
        {
          'image': {'content': base64Encode(imageBytes)},
          'features': [
            {'type': 'SAFE_SEARCH_DETECTION'},
          ],
        },
      ],
    });

    try {
      debugPrint(
        '🛡️ [ContentSafetyService] Requesting Google Cloud Vision for image check...',
      );
      final response = await http.post(uri, headers: headers, body: body);

      debugPrint(
        '🛡️ [ContentSafetyService] Response status: ${response.statusCode}',
      );
      debugPrint(
        '🛡️ [ContentSafetyService] Raw Response body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (_isImageSexualContent(json)) {
          debugPrint(
            '🚫 [ContentSafetyService] NSFW image detected by Google Cloud Vision!',
          );
          throw NsfwContentException('nsfw_image_detected');
        }
        debugPrint('✅ [ContentSafetyService] Image is safe.');
      } else {
        debugPrint(
          '⚠️ [ContentSafetyService] Google Vision image check failed [${response.statusCode}]: ${response.body}',
        );
      }
    } catch (e) {
      if (e is NsfwContentException) rethrow;
      debugPrint('❌ [ContentSafetyService] Error checking image safety: $e');
    }
  }

  bool _isTextSexualContent(Map<String, dynamic> json) {
    if (json.containsKey('moderationCategories')) {
      final categories = json['moderationCategories'] as List<dynamic>;
      debugPrint(
        '🛡️ [ContentSafetyService] Moderation categories count: ${categories.length}',
      );

      final List<String> catLogs = [];
      bool shouldFlag = false;
      String? flaggedCategory;

      final restrictedKeywords = [
        'sexual',
        'adult',
        'racy',
        'toxic',
        'profanity',
        'derogatory',
      ];

      for (final cat in categories) {
        final name = cat['name'] as String?;
        final confidence = cat['confidence'] as num?;
        if (name != null && confidence != null) {
          catLogs.add('$name: $confidence');

          final lowerName = name.toLowerCase();

          // Check if category name matches any restricted keyword
          final isRestricted = restrictedKeywords.any(
            (kw) => lowerName.contains(kw),
          );

          // Lower threshold to 0.15
          if (isRestricted && confidence >= 0.15) {
            shouldFlag = true;
            flaggedCategory = '$name ($confidence)';
          }
        }
      }

      // Print in chunks if too long
      final logStr = catLogs.join(', ');
      debugPrint('   -> Categories: $logStr');

      if (shouldFlag) {
        debugPrint(
          '   💥 FLAGGED: Category $flaggedCategory exceeds threshold',
        );
        return true;
      }
    } else {
      debugPrint(
        '🛡️ [ContentSafetyService] No moderationCategories found in response.',
      );
    }
    return false;
  }

  bool _isImageSexualContent(Map<String, dynamic> json) {
    if (json.containsKey('responses') &&
        (json['responses'] as List).isNotEmpty) {
      final response = json['responses'][0];
      if (response.containsKey('safeSearchAnnotation')) {
        final safeSearch =
            response['safeSearchAnnotation'] as Map<String, dynamic>;
        final adult = safeSearch['adult'] as String?;
        final racy = safeSearch['racy'] as String?;
        final violence = safeSearch['violence'] as String?;

        debugPrint(
          '🛡️ [ContentSafetyService] SafeSearchAnnotation: adult=$adult, racy=$racy, violence=$violence',
        );

        final unsafeValues = ['LIKELY', 'VERY_LIKELY'];

        if (unsafeValues.contains(adult) ||
            unsafeValues.contains(racy) ||
            unsafeValues.contains(violence)) {
          debugPrint(
            '   💥 FLAGGED: Unsafe value found in SafeSearchAnnotation.',
          );
          return true;
        }
      } else {
        debugPrint(
          '🛡️ [ContentSafetyService] No safeSearchAnnotation found in response.',
        );
      }
    } else {
      debugPrint('🛡️ [ContentSafetyService] Empty or missing responses list.');
    }
    return false;
  }
}
