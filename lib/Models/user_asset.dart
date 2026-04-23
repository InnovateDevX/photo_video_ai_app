import 'package:cloud_firestore/cloud_firestore.dart';

class UserAsset {
  final String id;
  final String url;
  final String type; // 'image' or 'video'
  final String? thumbnailUrl;
  final DateTime createdAt;

  UserAsset({
    required this.id,
    required this.url,
    required this.type,
    this.thumbnailUrl,
    required this.createdAt,
  });

  factory UserAsset.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserAsset(
      id: doc.id,
      url: data['url'] ?? '',
      type: data['type'] ?? 'image',
      thumbnailUrl: data['thumbnailUrl'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      'type': type,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
