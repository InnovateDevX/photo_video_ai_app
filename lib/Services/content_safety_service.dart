import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'remote_config_service.dart';

/// Exception thrown when content is flagged by Azure Content Safety.
class NsfwContentException implements Exception {
  final String message;
  NsfwContentException(this.message);

  @override
  String toString() => message;
}

class ContentSafetyService {
  static final ContentSafetyService _instance =
      ContentSafetyService._internal();
  factory ContentSafetyService() => _instance;
  ContentSafetyService._internal();

  /// Returns true if the [text] contains sexual content (severity > 1).
  /// Throws [NsfwContentException] if flagged.
  Future<void> checkTextSafe(String text) async {
    final config = RemoteConfigService();
    final endpoint = config.azureContentSafetyEndpoint;
    final key = config.azureContentSafetyKey;

    if (endpoint.isEmpty || key.isEmpty) {
      debugPrint(
        '⚠️ [ContentSafetyService] Azure credentials not found. Skipping check.',
      );
      return;
    }

    final uri = Uri.parse(
      '$endpoint/contentSafety/text:analyze?api-version=2024-09-01',
    );

    final headers = {
      'Ocp-Apim-Subscription-Key': key,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final body = jsonEncode({
      'text': text,
      'categories': ['Sexual'],
    });

    try {
      debugPrint('🛡️ [ContentSafetyService] Checking text safety...');
      final response = await http.post(uri, headers: headers, body: body);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (_isSexualContent(json)) {
          debugPrint('🚫 [ContentSafetyService] NSFW content detected!');
          throw NsfwContentException('restricted_content_detected');
        }
        debugPrint('✅ [ContentSafetyService] Content is safe.');
      } else {
        debugPrint(
          '⚠️ [ContentSafetyService] Azure check failed [${response.statusCode}]: ${response.body}',
        );
        // We don't block if the service fails, to avoid breaking the app.
      }
    } catch (e) {
      if (e is NsfwContentException) rethrow;
      debugPrint('❌ [ContentSafetyService] Error checking content safety: $e');
    }
  }

  /// Returns true if the [imageBytes] contains sexual content (severity > 1).
  /// Throws [NsfwContentException] if flagged.
  Future<void> checkImageSafe(Uint8List imageBytes) async {
    final config = RemoteConfigService();
    final endpoint = config.azureContentSafetyEndpoint;
    final key = config.azureContentSafetyKey;

    if (endpoint.isEmpty || key.isEmpty) {
      debugPrint(
        '⚠️ [ContentSafetyService] Azure credentials not found. Skipping image check.',
      );
      return;
    }

    final uri = Uri.parse(
      '$endpoint/contentSafety/image:analyze?api-version=2024-09-01',
    );

    final headers = {
      'Ocp-Apim-Subscription-Key': key,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final body = jsonEncode({
      'image': {'content': base64Encode(imageBytes)},
      'categories': ['Sexual'],
    });

    try {
      debugPrint('🛡️ [ContentSafetyService] Checking image safety...');
      final response = await http.post(uri, headers: headers, body: body);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (_isSexualContent(json)) {
          debugPrint('🚫 [ContentSafetyService] NSFW image detected!');
          throw NsfwContentException('restricted_content_detected');
        }
        debugPrint('✅ [ContentSafetyService] Image is safe.');
      } else {
        debugPrint(
          '⚠️ [ContentSafetyService] Azure image check failed [${response.statusCode}]: ${response.body}',
        );
      }
    } catch (e) {
      if (e is NsfwContentException) rethrow;
      debugPrint('❌ [ContentSafetyService] Error checking image safety: $e');
    }
  }

  bool _isSexualContent(Map<String, dynamic> json) {
    if (json.containsKey('categoriesAnalysis')) {
      final categories = json['categoriesAnalysis'] as List<dynamic>;
      for (final cat in categories) {
        if (cat['category'] == 'Sexual' && (cat['severity'] as num) > 1) {
          return true;
        }
      }
    }
    return false;
  }
}
