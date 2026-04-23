class Reel {
  final String id;
  final String videoUrl;

  /// Optional thumbnail/preview image URL. For images this is the same as
  /// [videoUrl]. For videos it is a separate still frame stored in Firestore.
  final String? thumbnailUrl;

  /// Prompt used for the final video generation (Stage 2).
  final String videoPrompt;

  /// Prompt used for the image-edit step (Stage 1), only relevant when [imageEdit] is true.
  final String imagePrompt;

  /// When true, tapping "Use Template" triggers a two-stage pipeline:
  /// image-edit (using [imagePrompt]) → video generation (using [videoPrompt]).
  final bool imageEdit;

  final String type; // 'image' or 'video'
  final bool isEditable;
  final int likesCount;
  final int savedCount;

  Reel({
    required this.id,
    required this.videoUrl,
    required this.videoPrompt,
    this.thumbnailUrl,
    this.imagePrompt = '',
    this.imageEdit = false,
    this.type = 'video',
    this.isEditable = false,
    this.likesCount = 0,
    this.savedCount = 0,
  });

  /// Returns the best available preview URL:
  /// – For images, the video/image URL itself works fine.
  /// – For videos, prefers [thumbnailUrl] when available; falls back to [videoUrl].
  String get previewUrl => thumbnailUrl?.isNotEmpty == true ? thumbnailUrl! : videoUrl;

  factory Reel.fromFirestore(String id, Map<String, dynamic> data) {
    return Reel(
      id: id,
      videoUrl: data['videoUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'],
      // Backward-compatible: fall back to old 'prompt' key for existing docs
      videoPrompt: data['videoPrompt'] ?? data['prompt'] ?? '',
      imagePrompt: data['imagePrompt'] ?? '',
      imageEdit: data['imageEdit'] ?? false,
      type: data['type'] ?? 'video',
      isEditable: data['isEditable'] ?? false,
      likesCount: data['likesCount'] ?? 0,
      savedCount: data['savedCount'] ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'videoUrl': videoUrl,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      'videoPrompt': videoPrompt,
      'imagePrompt': imagePrompt,
      'imageEdit': imageEdit,
      'type': type,
      'isEditable': isEditable,
      'likesCount': likesCount,
      'savedCount': savedCount,
    };
  }
}
