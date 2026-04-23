class FilterStyle {
  final String id;
  final String name;
  final String prompt;
  final String thumbnailUrl;

  FilterStyle({
    required this.id,
    required this.name,
    required this.prompt,
    required this.thumbnailUrl,
  });

  factory FilterStyle.fromJson(Map<String, dynamic> json) {
    return FilterStyle(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed Style',
      prompt: json['prompt'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'prompt': prompt,
      'thumbnail_url': thumbnailUrl,
    };
  }
}
