import 'dart:convert';

class GeneratedAsset {
  final String id;
  final String filePath;
  final String category; // 'image' or 'video'
  final String prompt;
  final String? thumbnailPath;
  final DateTime createdAt;

  GeneratedAsset({
    required this.id,
    required this.filePath,
    required this.category,
    required this.prompt,
    this.thumbnailPath,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'category': category,
      'prompt': prompt,
      'thumbnailPath': thumbnailPath,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory GeneratedAsset.fromMap(Map<String, dynamic> map) {
    return GeneratedAsset(
      id: map['id'] ?? '',
      filePath: map['filePath'] ?? '',
      category: map['category'] ?? 'image',
      prompt: map['prompt'] ?? '',
      thumbnailPath: map['thumbnailPath'],
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory GeneratedAsset.fromJson(String source) => GeneratedAsset.fromMap(json.decode(source));
}
