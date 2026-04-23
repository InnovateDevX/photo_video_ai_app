/// Core data model containing user profile and settings schemas.
class UserModel {
  final String uid;
  final Map<String, dynamic> profile;
  final Map<String, dynamic> settings;
  final Map<String, dynamic> appData;

  UserModel({
    required this.uid,
    required this.profile,
    required this.settings,
    required this.appData,
  });

  factory UserModel.fromMap(String id, Map<String, dynamic> map) {
    return UserModel(
      uid: id,
      profile: Map<String, dynamic>.from(map['profile'] ?? {}),
      settings: Map<String, dynamic>.from(map['settings'] ?? {}),
      appData: Map<String, dynamic>.from(map['app_data'] ?? {}),
    );
  }
}
