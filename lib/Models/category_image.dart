/// Model class representing an image within a category
class CategoryImage {
  final String imageUrl;
  final String? videoUrl;
  final String modelUsed;
  final String prompt;

  /// Type of content: 'image', 'video', or 'category'
  final String type;

  /// Firestore document ID of the reel (used when type is 'video')
  final String? reelId;

  /// Optional thumbnail URL for videos
  final String? thumbnailUrl;

  /// The name of the category (used when type is 'category')
  final String? categoryName;

  /// Whether the image model is editable / image-to-image
  final bool isEditable;

  CategoryImage({
    this.imageUrl = '',
    this.videoUrl,
    this.modelUsed = '',
    this.prompt = '',
    this.type = 'image',
    this.reelId,
    this.thumbnailUrl,
    this.categoryName,
    this.isEditable = false,
  });

  factory CategoryImage.fromJson(Map<String, dynamic> json) {
    final parsedVideoUrl = json['videoUrl'] as String? ?? json['reelUrl'] as String?;
    final parsedReelId = json['reelId'] as String?;
    final determinedType = json['type'] as String? ?? 
        ((parsedVideoUrl != null || parsedReelId != null) ? 'video' : 'image');

    return CategoryImage(
      imageUrl: json['imageUrl'] as String? ?? '',
      videoUrl: parsedVideoUrl,
      modelUsed: json['modelUsed'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      type: determinedType,
      reelId: parsedReelId,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      categoryName: json['categoryName'] as String?,
      isEditable: (json['isEditable'] ?? json['iseditable']) as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imageUrl': imageUrl,
      if (videoUrl != null) 'videoUrl': videoUrl,
      'modelUsed': modelUsed,
      'prompt': prompt,
      'type': type,
      if (reelId != null) 'reelId': reelId,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (categoryName != null) 'categoryName': categoryName,
      'isEditable': isEditable,
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
    final imagesList = (json['images'] as List<dynamic>?) ?? (json['items'] as List<dynamic>?) ?? [];
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
