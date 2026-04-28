import 'dart:io';
import 'package:trail_ai_app/Services/remote_config_service.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:trail_ai_app/Core/user_session.dart';
import 'package:trail_ai_app/Services/base64_firebase_storage_service.dart';
import 'package:trail_ai_app/Services/base64_image_encoder.dart';
import 'package:trail_ai_app/Services/storage_service.dart';
import 'package:trail_ai_app/Services/content_safety_service.dart';

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
        final placeholder = '{{${entry.key}}}';
        // Exact match replacement (e.g., used for "scale": "{{scale}}" to keep it as an int)
        if (result == placeholder) {
          result = entry.value;
          break; // Stop looking if the whole value is replaced
        }
        // Partial string replacement
        if (result is String && result.contains(placeholder)) {
          result = result.replaceAll(placeholder, entry.value.toString());
        }
      }
      return result;
    }
    return source;
  }

  bool get supportsAspectRatio {
    final templateStr = jsonEncode(requestBodyTemplate);
    return templateStr.contains('{{aspect_ratio}}');
  }

  bool get supportsDimensions {
    final templateStr = jsonEncode(requestBodyTemplate);
    return templateStr.contains('{{width}}') &&
        templateStr.contains('{{height}}');
  }
}

class ReplicateService {
  static const bool kUploadBase64ToFirebase = true;

  static final ReplicateService _instance = ReplicateService._internal();
  factory ReplicateService() => _instance;
  ReplicateService._internal();

  String _authToken = '';
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
    if (aspectRatio != null) variables['aspect_ratio'] = aspectRatio;
    if (width != null) variables['width'] = width;
    if (height != null) variables['height'] = height;
    if (extraVariables != null) {
      variables.addAll(extraVariables);
    }

    final requestInput = modelConfig.createRequestBody(variables);
    Map<String, dynamic> finalBody = Map.from(requestInput);
    final List<String> rawBase64s = [];
    final List<String> imageUrls = [];

    // ── Pre-upload images to Firebase to get public URIs ──────────────────────
    if (modelConfig.iseditable && referenceImage != null) {
      try {
        debugPrint(
          '☁️ [ReplicateService] Uploading reference image to Storage...',
        );
        final url = await StorageService().uploadFile(referenceImage);
        imageUrls.add(url);

        // Comprehensive mapping to all possible template placeholders
        final List<String> imageKeys = [
          'image',
          'image_url',
          'input_image',
          'start_image',
          'end_image',
          'reference_image',
          'prompt_image',
        ];
        for (final k in imageKeys) {
          variables[k] = url;
        }

        // Also handle the specific case for models like Seedance
        variables['reference_images'] = [url];
        debugPrint('✅ [ReplicateService] Image uploaded and mapped: $url');
      } catch (e) {
        debugPrint('❌ [ReplicateService] Image upload failed: $e');
        throw Exception('Failed to upload reference image: $e');
      }
    }

    if (images != null && images.isNotEmpty) {
      try {
        debugPrint(
          '☁️ [ReplicateService] Uploading ${images.length} images to Storage...',
        );
        final urls = await StorageService().uploadFiles(images);
        variables['images'] = urls;
        variables['image_urls'] = urls;
        variables['reference_images'] = urls;
        debugPrint('✅ [ReplicateService] ${urls.length} images uploaded.');
      } catch (e) {
        debugPrint('❌ [ReplicateService] Images upload failed: $e');
        throw Exception('Failed to upload secondary images: $e');
      }
    }

    // Re-create body with updated variables (now containing URLs)
    finalBody = modelConfig.createRequestBody(variables);

    // ── Base64 Fallback check (only if no URL was obtained) ──────────────────
    if (modelConfig.iseditable &&
        referenceImage != null &&
        variables['image'] == null) {
      debugPrint(
        '🖼 [ReplicateService] No URL available, falling back to base64 encoding...',
      );
      try {
        final encoded = await Base64ImageEncoder.encodeFile(referenceImage);
        final rawBase64 = encoded.split(',').last;
        rawBase64s.add(encoded);

        bool templateIncludesDataUriPrefix(dynamic v) {
          const placeholder = '{{image}}';
          if (v is String) {
            return v.contains(placeholder) &&
                v.contains('data:') &&
                v.contains('base64,');
          }
          if (v is Map<String, dynamic>) {
            return v.values.any(templateIncludesDataUriPrefix);
          }
          if (v is List) return v.any(templateIncludesDataUriPrefix);
          return false;
        }

        final hasPrefix = templateIncludesDataUriPrefix(finalBody);
        final base64ForTemplate = hasPrefix ? rawBase64 : encoded;

        finalBody = modelConfig._replaceValues(finalBody, {
          'image': base64ForTemplate,
        });
        debugPrint('✅ [ReplicateService] Reference image injected as base64.');
      } catch (e) {
        debugPrint('❌ [ReplicateService] Base64 fallback failed: $e');
      }
    }

    // ── Prune Unfulfilled Placeholders ──────────────────────────────────────
    debugPrint(
      '🧹 [ReplicateService] Pruning request body of empty placeholders...',
    );
    finalBody = _pruneBody(finalBody) ?? finalBody;

    if (kUploadBase64ToFirebase && rawBase64s.isNotEmpty) {
      await _saveBase64ToFirebase(rawBase64s: rawBase64s);
    }

    return _createPrediction(modelConfig.url, finalBody, onProgress);
  }

  Future<void> _saveBase64ToFirebase({required List<String> rawBase64s}) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uid = UserSession.instance.uid ?? 'anon';

      for (int i = 0; i < rawBase64s.length; i++) {
        final s = rawBase64s[i];
        debugPrint('📋 [Firebase] String[$i] length=${s.length}');
        debugPrint(
          '📋 [Firebase] String[$i] prefix (first 50 chars): ${s.substring(0, s.length.clamp(0, 50))}',
        );
        debugPrint(
          '📋 [Firebase] String[$i] starts with data:image = ${s.startsWith('data:image')}',
        );
      }

      await Base64FirebaseStorageService.instance.uploadRawBase64s(
        folderPath: 'base64_logs/$uid/$timestamp',
        rawBase64s: rawBase64s,
        filePrefix: 'raw_base64',
      );

      debugPrint(
        '✅ [ReplicateService] Uploaded base64 (ts=$timestamp) to Firebase.',
      );
    } catch (e) {
      debugPrint('⚠️ [ReplicateService] Base64 upload failed: $e');
    }
  }

  Future<String> _createPrediction(
    String url,
    Map<String, dynamic> requestBody,
    Function(double)? onProgress,
  ) async {
    try {
      final cleanUrl = url.trim();
      debugPrint('🌐 [ReplicateService] POST $cleanUrl');
      debugPrint(
        '📦 [ReplicateService] Request Body: ${jsonEncode(requestBody)}',
      );

      final response = await http.post(
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
        return _extractOutput(data['output']);
      }

      final getUrl = data['urls']?['get'];
      if (getUrl != null) {
        return await _pollForResult(getUrl, onProgress);
      }

      throw Exception('No output or poll URL found');
    } catch (e) {
      debugPrint('❌ [ReplicateService] Error: $e');
      rethrow;
    }
  }

  String _extractOutput(dynamic output) {
    if (output is List && output.isNotEmpty) {
      return output[0].toString();
    } else if (output is String) {
      return output;
    }
    throw Exception('Unknown output format: $output');
  }

  Future<String> _pollForResult(
    String url,
    Function(double)? onProgress,
  ) async {
    final cleanUrl = url.trim();
    debugPrint('⏳ [ReplicateService] Polling: $cleanUrl');

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

      final response = await http.get(
        Uri.parse(cleanUrl),
        headers: {'Authorization': 'Bearer $_authToken'},
      );

      if (response.statusCode != 200) continue;

      final data = jsonDecode(response.body);
      final status = data['status'];

      debugPrint('   Status: $status');

      if (status == 'succeeded') {
        return _extractOutput(data['output']);
      } else if (status == 'failed' || status == 'canceled') {
        throw Exception('Generation $status: ${data['error']}');
      }
    }

    throw Exception('Timeout waiting for generation');
  }
}
