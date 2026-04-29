/// Model class representing an image within a category
class CategoryImage {
  final String imageUrl;
  final String modelUsed;
  final String prompt;

  /// Type of content: 'image' or 'video'
  final String type;

  /// Firestore document ID of the reel (used when type is 'video')
  final String? reelId;

  /// Optional thumbnail URL for videos
  final String? thumbnailUrl;

  CategoryImage({
    this.imageUrl = '',
    this.modelUsed = '',
    this.prompt = '',
    this.type = 'image',
    this.reelId,
    this.thumbnailUrl,
  });

  factory CategoryImage.fromJson(Map<String, dynamic> json) {
    return CategoryImage(
      imageUrl: json['imageUrl'] as String? ?? '',
      modelUsed: json['modelUsed'] as String? ?? '',
      prompt: json['prompt'] as String? ?? '',
      type: json['type'] as String? ?? 'image',
      reelId: json['reelId'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imageUrl': imageUrl,
      'modelUsed': modelUsed,
      'prompt': prompt,
      'type': type,
      'reelId': reelId,
      'thumbnailUrl': thumbnailUrl,
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
    final imagesList = json['images'] as List<dynamic>? ?? [];
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
