import 'package:cloud_firestore/cloud_firestore.dart';

/// Core data model containing user profile and settings schemas.
class UserModel {
  final String uid;
  final Map<String, dynamic> profile;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> appData;

  // Subscription fields
  final bool isPro;
  final String? proProductId;
  final DateTime? proPurchasedAt;
  final DateTime? proExpiresAt;

  UserModel({
    required this.uid,
    required this.profile,
    required this.settings,
    required this.appData,
    this.isPro = false,
    this.proProductId,
    this.proPurchasedAt,
    this.proExpiresAt,
  });

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      uid: id,
      profile: Map<String, dynamic>.from(map['profile'] ?? {}),
      settings: Map<String, dynamic>.from(map['settings'] ?? {}),
      appData: Map<String, dynamic>.from(map['app_data'] ?? {}),
      isPro: map['isPro'] ?? false,
      proProductId: map['proProductId'] as String?,
      proPurchasedAt: (map['proPurchasedAt'] as Timestamp?)?.toDate(),
      proExpiresAt: (map['proExpiresAt'] as Timestamp?)?.toDate(),
    );
  }
}
