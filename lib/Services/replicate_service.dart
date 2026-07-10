import 'dart:io';
import 'package:trail_ai_app/Services/remote_config_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:trail_ai_app/Services/base64_image_encoder.dart';
import 'package:trail_ai_app/Services/content_safety_service.dart';
import 'package:trail_ai_app/Services/cancellation_manager.dart';

/// Options supported by a specific AI model
class ModelOptions {
  final List<String> durations;
  final List<String> resolutions;
  final List<String> aspectRatios;

  const ModelOptions({
    this.durations = const [],
    this.resolutions = const [],
    this.aspectRatios = const [],
  });

  bool get hasDurations => durations.isNotEmpty;
  bool get hasResolutions => resolutions.isNotEmpty;
  bool get hasAspectRatios => aspectRatios.isNotEmpty;

  factory ModelOptions.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const ModelOptions();
    return ModelOptions(
      durations:
          (json['durations'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      resolutions:
          (json['resolutions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      aspectRatios:
          (json['aspect_ratios'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

/// Configuration for a specific AI model
class AIModelConfig {
  final String id;
  final bool iseditable;
  final String name;
  final String url;
  final Map<String, dynamic> requestBodyTemplate;
  final int creditUsed;
  final String? iconUrl;
  final bool firstFrameEnabled;
  final bool lastFrameEnabled;
  final ModelOptions options;

  AIModelConfig({
    required this.id,
    required this.name,
    required this.iseditable,
    required this.url,
    required this.requestBodyTemplate,
    this.creditUsed = 0,
    this.iconUrl,
    this.firstFrameEnabled = false,
    this.lastFrameEnabled = false,
    this.options = const ModelOptions(),
  });

  factory AIModelConfig.fromJson(Map<String, dynamic> json) {
    return AIModelConfig(
      iseditable: (json['iseditable'] as bool?) ?? false,
      id: json['id'] as String,
      name: json['name'] as String,
      url: json['url'] as String,
      requestBodyTemplate: json['request_body'] as Map<String, dynamic>,
      creditUsed: (json['credit_used'] as num?)?.toInt() ?? 0,
      iconUrl: json['icon_url'] as String?,
      firstFrameEnabled: (json['first_frame_enabled'] as bool?) ?? false,
      lastFrameEnabled: (json['last_frame_enabled'] as bool?) ?? false,
      options: ModelOptions.fromJson(json['options'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> createRequestBody(Map<String, dynamic> variables) {
    return _replaceValues(requestBodyTemplate, variables);
  }

  dynamic _replaceValues(dynamic source, Map<String, dynamic> variables) {
    if (source is Map<String, dynamic>) {
      return source.map(
        (key, value) => MapEntry(key, _replaceValues(value, variables)),
      );
    } else if (source is List) {
      return source.map((item) => _replaceValues(item, variables)).toList();
    } else if (source is String) {
      dynamic result = source;
      for (final entry in variables.entries) {
        final keyUpper = entry.key.toUpperCase();
        final keyLower = entry.key.toLowerCase();
        final placeholderOriginal = '{{${entry.key}}}';
        final placeholderUpper = '{{$keyUpper}}';
        final placeholderLower = '{{$keyLower}}';

        // Exact match replacement (e.g., used for "scale": "{{scale}}" to keep it as an int)
        if (result == placeholderOriginal ||
            result == placeholderUpper ||
            result == placeholderLower) {
          result = entry.value;
          break; // Stop looking if the whole value is replaced
        }
        // Partial string replacement
        if (result is String) {
          result = result
              .replaceAll(placeholderOriginal, entry.value.toString())
              .replaceAll(placeholderUpper, entry.value.toString())
              .replaceAll(placeholderLower, entry.value.toString());
        }
      }
      return result;
    }
    return source;
  }

  bool get supportsAspectRatio {
    final templateStr = jsonEncode(requestBodyTemplate);
    return templateStr.contains('{{aspect_ratio}}') || supportsDimensions;
  }

  bool get supportsDimensions {
    final templateStr = jsonEncode(requestBodyTemplate);
    return templateStr.contains('{{width}}') &&
        templateStr.contains('{{height}}');
  }
}

class ReplicateService {
  static final ReplicateService _instance = ReplicateService._internal();
  factory ReplicateService() => _instance;
  ReplicateService._internal();

  String _authToken = '';
  String get authToken => _authToken;

  // ── Active prediction tracking (for cancellation on app minimize/exit) ──
  String? _currentPollUrl;
  String? _currentCancelUrl;

  /// Cancels the currently active prediction (if any) by sending a POST to its cancel URL.
  /// Also closes any tracked HTTP client to abort in-flight requests.
  /// If [cancelUrl] is provided, it cancels that specific URL; otherwise cancels the stored one.
  Future<void> cancelActivePrediction({String? cancelUrl}) async {
    final targetUrl = cancelUrl ?? _currentCancelUrl;
    if (targetUrl != null && targetUrl.isNotEmpty) {
      await cancelPrediction(targetUrl);
    }
    // Also close any tracked HTTP clients to abort in-flight polling
    CancellationManager().cancelAll();
    _currentPollUrl = null;
    _currentCancelUrl = null;
  }

  List<AIModelConfig> _imageModels = [];
  List<AIModelConfig> _videoModels = [];
  AIModelConfig? _clothModel;
  AIModelConfig? _upscaleModel;
  AIModelConfig? _restoreModel;
  AIModelConfig? _headshotModel;
  AIModelConfig? _stickerImageModel;
  AIModelConfig? _stickerTextModel;
  AIModelConfig? _removeBgModel;
  AIModelConfig? _blurBgModel;
  AIModelConfig? _backgroundModel;
  AIModelConfig? _collageModel;
  AIModelConfig? _logoModel;
  AIModelConfig? _filterModel;
  AIModelConfig? _retouchModel;
  bool _isInitialized = false;

  List<AIModelConfig> get imageModels => _imageModels;
  List<AIModelConfig> get videoModels => _videoModels;
  AIModelConfig? get clothModel => _clothModel;
  AIModelConfig? get upscaleModel => _upscaleModel;
  AIModelConfig? get restoreModel => _restoreModel;
  AIModelConfig? get headshotModel => _headshotModel;
  AIModelConfig? get stickerImageModel => _stickerImageModel;
  AIModelConfig? get stickerTextModel => _stickerTextModel;
  AIModelConfig? get removeBgModel => _removeBgModel;
  AIModelConfig? get blurBgModel => _blurBgModel;
  AIModelConfig? get backgroundModel => _backgroundModel;
  AIModelConfig? get collageModel => _collageModel;
  AIModelConfig? get logoModel => _logoModel;
  AIModelConfig? get filterModel => _filterModel;
  AIModelConfig? get retouchModel => _retouchModel;

  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('🔧 [ReplicateService] Starting initialization...');
    final config = RemoteConfigService();

    // Ensure RemoteConfigService is initialized (usually done in AppInitializer,
    // but we call it here just in case).
    await config.initialize();

    try {
      _authToken = config.replicateAuthToken;
      debugPrint(
        '🔑 [ReplicateService] Auth token length: ${_authToken.length}',
      );

      final imageModelsJson = config.imageModelsJson;
      final videoModelsJson = config.videoModelsJson;
      final clothModelJson = config.clothModelJson;
      final upscaleModelJson = config.upscaleModelJson;
      final restoreModelJson = config.restoreModelJson;
      final headshotModelJson = config.headshotModelJson;
      final stickerImageModelJson = config.stickerImageModelJson;
      final stickerTextModelJson = config.stickerTextModelJson;
      final removeBgModelJson = config.removeBgModelJson;
      final blurBgModelJson = config.blurBgModelJson;
      final backgroundModelJson = config.backgroundModelJson;
      final collageModelJson = config.collageModelJson;
      final logoModelJson = config.logoModelJson;
      final filterModelJson = config.filterModelJson;
      final retouchModelJson = config.retouchModelJson;

      debugPrint(
        '📦 [ReplicateService] replicate_image_models raw (first 200 chars): '
        '${imageModelsJson.substring(0, imageModelsJson.length.clamp(0, 200))}',
      );
      debugPrint(
        '📦 [ReplicateService] replicate_video_models raw (first 200 chars): '
        '${videoModelsJson.substring(0, videoModelsJson.length.clamp(0, 200))}',
      );

      _imageModels = _parseModels('image', imageModelsJson);
      _videoModels = _parseModels('video', videoModelsJson);

      _upscaleModel = _parseSingleModel('Upscale', upscaleModelJson);
      _restoreModel = _parseSingleModel('Restore', restoreModelJson);
      _headshotModel = _parseSingleModel('Headshot', headshotModelJson);
      _stickerImageModel = _parseSingleModel(
        'StickerImage',
        stickerImageModelJson,
      );
      _stickerTextModel = _parseSingleModel(
        'StickerText',
        stickerTextModelJson,
      );
      _removeBgModel = _parseSingleModel('RemoveBG', removeBgModelJson);
      _blurBgModel = _parseSingleModel('BlurBG', blurBgModelJson);
      _backgroundModel = _parseSingleModel('Background', backgroundModelJson);
      _collageModel = _parseSingleModel('Collage', collageModelJson);
      _logoModel = _parseSingleModel('Logo', logoModelJson);
      _filterModel = _parseSingleModel('Filter', filterModelJson);
      _retouchModel = _parseSingleModel('Retouch', retouchModelJson);
      _clothModel = _parseSingleModel('Cloth', clothModelJson);

      debugPrint(
        '✅ [ReplicateService] Image models loaded: ${_imageModels.length}',
      );
      for (final m in _imageModels) {
        debugPrint('   🖼  ${m.id} — ${m.name} (credits: ${m.creditUsed})');
      }
      debugPrint(
        '✅ [ReplicateService] Video models loaded: ${_videoModels.length}',
      );
      for (final m in _videoModels) {
        debugPrint('   🎬 ${m.id} — ${m.name} (credits: ${m.creditUsed})');
      }

      _isInitialized = true;
    } catch (e, stack) {
      debugPrint('❌ [ReplicateService] Initialization failed: $e');
      debugPrint('   Stack: $stack');
    }
  }

  AIModelConfig? _parseSingleModel(String name, String jsonStr) {
    if (jsonStr.isEmpty || jsonStr == '{}') return null;
    try {
      final config = AIModelConfig.fromJson(jsonDecode(jsonStr));
      debugPrint('✅ [ReplicateService] $name model loaded: ${config.name}');
      return config;
    } catch (e) {
      debugPrint('❌ [ReplicateService] Failed to parse $name model: $e');
      return null;
    }
  }

  List<AIModelConfig> _parseModels(String tag, String jsonStr) {
    debugPrint(
      '🔍 [ReplicateService] Parsing $tag models (length=${jsonStr.length})...',
    );
    if (jsonStr.isEmpty || jsonStr == '[]') {
      debugPrint(
        '⚠️  [ReplicateService] $tag JSON is empty/default — nothing to parse.',
      );
      return [];
    }
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      debugPrint(
        '🔍 [ReplicateService] $tag JSON decoded — ${list.length} item(s).',
      );
      final result = <AIModelConfig>[];
      for (int i = 0; i < list.length; i++) {
        try {
          result.add(AIModelConfig.fromJson(list[i]));
          debugPrint('   [$i] ✔ Parsed: ${list[i]['id']}');
        } catch (e) {
          debugPrint('   [$i] ✘ Failed to parse item: $e\n   Item: ${list[i]}');
        }
      }
      return result;
    } catch (e) {
      debugPrint('❌ [ReplicateService] Failed to decode $tag JSON: $e');
      return [];
    }
  }

  /// Recursively removes any keys from a Map/List whose values contain unreplaced placeholders.
  dynamic _pruneBody(dynamic body) {
    if (body is Map<String, dynamic>) {
      final pruned = <String, dynamic>{};
      body.forEach((key, value) {
        final newVal = _pruneBody(value);
        if (newVal != null) {
          // If the value is a string containing {{ or }}, it means it's an unfulfilled placeholder
          if (newVal is String &&
              (newVal.contains('{{') || newVal.contains('}}'))) {
            debugPrint('🧹 [ReplicateService] Pruning unfulfilled key: $key');
          } else {
            pruned[key] = newVal;
          }
        }
      });
      return pruned.isEmpty ? null : pruned;
    } else if (body is List) {
      final pruned = body
          .map((item) => _pruneBody(item))
          .where(
            (item) =>
                item != null &&
                !(item is String &&
                    (item.contains('{{') || item.contains('}}'))),
          )
          .toList();
      return pruned.isEmpty ? null : pruned;
    }
    return body;
  }

  Future<String> generateContent({
    required AIModelConfig modelConfig,
    required String prompt,
    String? aspectRatio,
    int? width,
    int? height,
    File? referenceImage,
    List<File>? images,
    Map<String, dynamic>? extraVariables,
    Function(double)? onProgress,
    Function(String pollUrl, String cancelUrl)? onPredictionStarted,
  }) async {
    if (!_isInitialized) {
      debugPrint(
        '🔧 [ReplicateService] Not initialized, calling initialize()...',
      );
      await initialize();
    }

    // ── Content Safety Check ────────────────────────────────────────────────
    await ContentSafetyService().checkTextSafe(prompt);

    if (referenceImage != null) {
      final bytes = await referenceImage.readAsBytes();
      await ContentSafetyService().checkImageSafe(bytes);
    }

    if (images != null && images.isNotEmpty) {
      for (final img in images) {
        final bytes = await img.readAsBytes();
        await ContentSafetyService().checkImageSafe(bytes);
      }
    }

    debugPrint(
      '🚀 [ReplicateService] Generating with model: ${modelConfig.name}',
    );

    final variables = <String, dynamic>{'prompt': prompt, 'PROMPT': prompt};
    if (aspectRatio != null) {
      variables['aspect_ratio'] = aspectRatio;
      if (modelConfig.supportsDimensions && (width == null || height == null)) {
        switch (aspectRatio) {
          case '1:1':
            width = 1024;
            height = 1024;
            break;
          case '16:9':
            width = 1344;
            height = 768;
            break;
          case '9:16':
            width = 768;
            height = 1344;
            break;
          case '4:3':
            width = 1152;
            height = 864;
            break;
          case '3:4':
            width = 864;
            height = 1152;
            break;
          case '2:3':
            width = 832;
            height = 1216;
            break;
          case '3:2':
            width = 1216;
            height = 832;
            break;
        }
      }
    }
    if (width != null) variables['width'] = width;
    if (height != null) variables['height'] = height;
    if (extraVariables != null) {
      variables.addAll(extraVariables);
    }

    final requestInput = modelConfig.createRequestBody(variables);
    Map<String, dynamic> finalBody = Map.from(requestInput);

    final List<String> rawBase64s = [];
    final List<String> imageUrls = [];

    /// Returns the data URI prefix (everything up to and including `;base64,`)
    /// from a template value string that embeds a placeholder with a prefix.
    /// e.g. `"data:image/jpeg;base64,{{image}}"` → `"data:image/jpeg;base64,"`
    /// Returns null if no valid data URI prefix is found.
    String? extractEmbeddedDataUriPrefix(String val) {
      const placeholders = [
        '{{image}}',
        '{{image_url}}',
        '{{input_image}}',
        '{{start_image}}',
        '{{end_image}}',
        '{{reference_image}}',
        '{{prompt_image}}',
        '{{cloth_image}}',
        '{{garm_image}}',
        '{{dress_image}}',
        '{{garment}}',
        '{{garment_image}}',
      ];
      for (final p in placeholders) {
        if (val.contains(p)) {
          // Find the data URI prefix before the placeholder
          final idx = val.indexOf(p);
          if (idx >= 0) {
            final prefix = val.substring(0, idx);
            if (prefix.startsWith('data:') && prefix.endsWith(';base64,')) {
              return prefix;
            }
          }
        }
      }
      return null;
    }

    /// Injects a base64 data URI into the request body JSON for a specific placeholder.
    ///
    /// Handles the case where the template has a hardcoded prefix like:
    /// "data:image/jpeg;base64,{{image}}" - we need to remove the prefix and replace
    /// just the placeholder with the full data URI (which has the correct MIME type).
    Map<String, dynamic> injectBase64IntoBody(
      Map<String, dynamic> body,
      String placeholder,
      String fullDataUri, // e.g. "data:image/png;base64,iVBOR..."
    ) {
      final jsonStr = jsonEncode(body);
      final ph = '{{$placeholder}}';

      // If the placeholder doesn't exist in the serialized body, return unchanged
      if (!jsonStr.contains(ph)) return body;

      // Find the position of the placeholder in the JSON string
      final phIdx = jsonStr.indexOf(ph);
      String result;

      // Check if there's a hardcoded data URI prefix before the placeholder
      if (phIdx >= 10) {
        // Look backwards from the placeholder to find a potential data URI prefix
        final segment = jsonStr.substring(0, phIdx);
        // Search for the unescaped or escaped pattern
        int prefixStart = segment.lastIndexOf('data:');
        if (prefixStart == -1) {
          prefixStart = segment.lastIndexOf('data\\u003a');
        }

        if (prefixStart >= 0) {
          final possiblePrefix = segment.substring(prefixStart);
          // Check if it ends with the base64 suffix comma right before the placeholder
          if (possiblePrefix.endsWith(',') ||
              possiblePrefix.endsWith('\\u002c')) {
            // Found a pattern like: data:image/jpeg;base64,{{image}}
            // Remove the prefix and just keep the placeholder part
            result = jsonStr.replaceFirst(possiblePrefix + ph, fullDataUri);
            debugPrint(
              '🔄 [ReplicateService] Removed hardcoded prefix and replaced "$ph" with data URI',
            );
            return jsonDecode(result) as Map<String, dynamic>;
          }
        }
      }

      // Simple placeholder replacement - the full data URI already has the correct MIME type
      result = jsonStr.replaceAll(ph, fullDataUri);
      debugPrint('🔄 [ReplicateService] Replaced "$ph" with full data URI');
      return jsonDecode(result) as Map<String, dynamic>;
    }

    // ── Base64 Encoding for single reference image ──────────────────────────
    if (referenceImage != null) {
      debugPrint('🖼 [ReplicateService] Encoding reference image to base64...');
      try {
        final encoded = await Base64ImageEncoder.encodeFile(referenceImage);
        rawBase64s.add(encoded);

        finalBody = injectBase64IntoBody(finalBody, 'image', encoded);
        // Also inject for all single-image placeholder variants
        for (final ph in [
          'image_url',
          'input_image',
          'start_image',
          'end_image',
          'reference_image',
          'prompt_image',
        ]) {
          finalBody = injectBase64IntoBody(finalBody, ph, encoded);
        }
        debugPrint('✅ [ReplicateService] Reference image injected as base64.');
      } catch (e) {
        debugPrint('❌ [ReplicateService] Base64 fallback failed: $e');
      }
    }

    // ── Base64 Encoding for multiple images ─────────────────────────────────
    if (images != null && images.isNotEmpty) {
      debugPrint(
        '🖼 [ReplicateService] Encoding ${images.length} images to base64...',
      );
      try {
        final List<String> encodedImagesWithPrefix = [];
        final List<String> rawImages = [];
        for (final img in images) {
          final encoded = await Base64ImageEncoder.encodeFile(img);
          encodedImagesWithPrefix.add(encoded);
          rawImages.add(encoded.split(',').last);
          rawBase64s.add(encoded);
        }

        // Inject the images list (use jsonEncode for valid JSON array syntax)
        final imagesJson = jsonEncode(encodedImagesWithPrefix);
        finalBody = injectBase64IntoBody(finalBody, 'images', imagesJson);
        finalBody = injectBase64IntoBody(finalBody, 'image_urls', imagesJson);

        if (encodedImagesWithPrefix.isNotEmpty) {
          // First image → primary image placeholders
          final firstEncoded = encodedImagesWithPrefix.first;
          for (final ph in [
            'image',
            'image_url',
            'input_image',
            'start_image',
            'end_image',
            'reference_image',
            'prompt_image',
          ]) {
            finalBody = injectBase64IntoBody(finalBody, ph, firstEncoded);
          }

          // Second image → cloth/garment placeholders
          if (encodedImagesWithPrefix.length > 1) {
            final secondEncoded = encodedImagesWithPrefix[1];
            for (final ph in [
              'image2',
              'cloth_image',
              'garm_image',
              'dress_image',
              'garment',
              'garment_image',
            ]) {
              finalBody = injectBase64IntoBody(finalBody, ph, secondEncoded);
            }
          }
        }

        debugPrint(
          '✅ [ReplicateService] ${encodedImagesWithPrefix.length} images injected as base64.',
        );
      } catch (e) {
        debugPrint(
          '❌ [ReplicateService] Base64 fallback for images failed: $e',
        );
      }
    }

    // ── Prune Unfulfilled Placeholders ──────────────────────────────────────
    debugPrint(
      '🧹 [ReplicateService] Pruning request body of empty placeholders...',
    );
    finalBody = _pruneBody(finalBody) ?? finalBody;

    // Fallback: Ensure 'prompt' is included in 'input' if it's missing but provided to the method.
    // We do this AFTER pruning because an unfulfilled template might have caused the prompt field to be dropped entirely.
    if (finalBody.containsKey('input') &&
        finalBody['input'] is Map<String, dynamic>) {
      final inputMap = finalBody['input'] as Map<String, dynamic>;
      if (!inputMap.containsKey('prompt') && prompt.isNotEmpty) {
        inputMap['prompt'] = prompt;
        debugPrint(
          '⚠️ [ReplicateService] Re-injected prompt after pruning to satisfy API validation.',
        );
      }
    }

    final url = await _createPrediction(
      modelConfig.url,
      finalBody,
      onProgress,
      onPredictionStarted,
    );

    // --- Safety Check on Generated Image ---
    if (url.isNotEmpty) {
      final lowerUrl = url.toLowerCase();
      // Skip safety check for video files as Cloud Vision expects images
      if (!lowerUrl.endsWith('.mp4') &&
          !lowerUrl.endsWith('.mov') &&
          !lowerUrl.endsWith('.webm')) {
        try {
          // Check Content-Length first to avoid OOM on very large images
          const int maxSafetyCheckBytes = 10 * 1024 * 1024; // 10 MB cap
          final headResponse = await http.head(Uri.parse(url));
          final contentLength = int.tryParse(
            headResponse.headers['content-length'] ?? '',
          );

          if (contentLength != null && contentLength > maxSafetyCheckBytes) {
            debugPrint(
              '⚠️ [ReplicateService] Image too large for safety check '
              '(${(contentLength / 1024 / 1024).toStringAsFixed(1)} MB). Skipping.',
            );
          } else {
            debugPrint(
              '🛡️ [ReplicateService] Safety checking generated image...',
            );
            final response = await http.get(Uri.parse(url));
            if (response.statusCode == 200) {
              await ContentSafetyService().checkImageSafe(response.bodyBytes);
            }
          }
        } catch (e) {
          if (e is NsfwContentException) {
            throw NsfwContentException(
              'generated_content_restricted',
              url: url,
            );
          }
          debugPrint(
            '⚠️ [ReplicateService] Generated image safety check error: $e',
          );
        }
      }
    }

    return url;
  }

  Future<String> _createPrediction(
    String url,
    Map<String, dynamic> requestBody,
    Function(double)? onProgress,
    Function(String, String)? onPredictionStarted,
  ) async {
    try {
      final cleanUrl = url.trim();
      debugPrint('🌐 [ReplicateService] POST $cleanUrl');
      debugPrint(
        '📦 [ReplicateService] Request Body: ${jsonEncode(requestBody)}',
      );

      final client = CancellationManager().createClient();
      try {
        final response = await client.post(
          Uri.parse(cleanUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_authToken',
          },
          body: jsonEncode(requestBody),
        );

        if (response.statusCode != 200 && response.statusCode != 201) {
          throw Exception('Failed to start generation: ${response.body}');
        }

        final data = jsonDecode(response.body);

        if (data['output'] != null) {
          return extractOutput(data['output']);
        }

        final getUrl = data['urls']?['get'];
        final cancelUrl = data['urls']?['cancel'];

        // Store the active prediction URLs for cancellation on app minimize/exit
        _currentPollUrl = getUrl;
        _currentCancelUrl = cancelUrl;

        if (getUrl != null) {
          if (onPredictionStarted != null && cancelUrl != null) {
            onPredictionStarted(getUrl, cancelUrl);
          }
          return await pollForResult(getUrl, onProgress);
        }

        throw Exception('No output or poll URL found');
      } finally {
        CancellationManager().unregisterClient(client);
      }
    } catch (e) {
      debugPrint('❌ [ReplicateService] Error: $e');
      rethrow;
    }
  }

  String extractOutput(dynamic output) {
    if (output is List && output.isNotEmpty) {
      return output[0].toString();
    } else if (output is String) {
      return output;
    }
    throw Exception('Unknown output format: $output');
  }

  /// Cancels an active prediction by sending a POST to its cancel URL
  Future<void> cancelPrediction(String cancelUrl) async {
    try {
      debugPrint(
        '🚫 [ReplicateService] POST $cancelUrl (Canceling prediction)',
      );
      final response = await http.post(
        Uri.parse(cancelUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_authToken',
        },
        body: jsonEncode({}),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        debugPrint(
          '⚠️ [ReplicateService] Failed to cancel prediction: ${response.statusCode} - ${response.body}',
        );
      } else {
        debugPrint('✅ [ReplicationService] Prediction cancelled successfully.');
      }
    } catch (e) {
      debugPrint('❌ [ReplicateService] Error cancelling prediction: $e');
    }
  }

  Future<String> pollForResult(String url, Function(double)? onProgress) async {
    final cleanUrl = url.trim();
    debugPrint('⏳ [ReplicateService] Polling: $cleanUrl');

    final client = CancellationManager().createClient();
    try {
      const int maxRetries = 60;
      for (int i = 0; i < maxRetries; i++) {
        // Calculate approximate progress
        // Video generation usually takes 30-90 seconds.
        // We'll advance progress slowly until it hits ~95%
        if (onProgress != null) {
          double progress = (i / maxRetries) * 1.0;
          onProgress(progress);
        }

        await Future.delayed(const Duration(seconds: 2));

        final response = await client.get(
          Uri.parse(cleanUrl),
          headers: {'Authorization': 'Bearer $_authToken'},
        );

        if (response.statusCode != 200) continue;

        final data = jsonDecode(response.body);
        final status = data['status'];

        debugPrint('   Status: $status');

        if (status == 'succeeded') {
          return extractOutput(data['output']);
        } else if (status == 'failed' || status == 'canceled') {
          throw Exception('Generation $status: ${data['error']}');
        }
      }

      throw Exception('Timeout waiting for generation');
    } finally {
      CancellationManager().unregisterClient(client);
    }
  }
}
