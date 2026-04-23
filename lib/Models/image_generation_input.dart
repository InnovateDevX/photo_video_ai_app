/// Data model passed to [ReplicateService] for every generation request.
class ImageGenerationInput {
  /// The text prompt describing what to generate.
  final String prompt;

  /// The Replicate model identifier string, e.g. 'stability-ai/sdxl'.
  final String modelId;

  /// Output width in pixels (used for image generation).
  final int width;

  /// Output height in pixels (used for image generation).
  final int height;

  /// Aspect ratio string, e.g. '1:1', '16:9'. Used by some models instead of w/h.
  final String? aspectRatio;

  /// Whether this is a video generation (true) or image generation (false).
  final bool isVideo;

  /// Optional base64-encoded image string for img2img / edit workflows.
  /// Include the data URI prefix: 'data:image/jpeg;base64,...'
  final String? inputImageBase64;

  /// Negative prompt (unsupported by all models, ignored if not applicable).
  final String? negativePrompt;

  const ImageGenerationInput({
    required this.prompt,
    required this.modelId,
    this.width = 1024,
    this.height = 1024,
    this.aspectRatio,
    this.isVideo = false,
    this.inputImageBase64,
    this.negativePrompt,
  });

  /// Convert to a Map for serialisation / logging.
  Map<String, dynamic> toMap() => {
    'prompt': prompt,
    'modelId': modelId,
    'width': width,
    'height': height,
    if (aspectRatio != null) 'aspectRatio': aspectRatio,
    'isVideo': isVideo,
    if (inputImageBase64 != null) 'hasInputImage': true,
    if (negativePrompt != null) 'negativePrompt': negativePrompt,
  };

  @override
  String toString() => 'ImageGenerationInput(${toMap()})';
}
