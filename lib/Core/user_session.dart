/// Holds the stable device + user identity resolved at startup by [AppInitializer].
///
/// With the MIGRATION approach:
/// - [uid] always equals [FirebaseAuth.instance.currentUser.uid] so all
///   Firestore security rules (auth.uid == uid) pass without changes.
/// - [deviceId] is the hardware device ID (survives reinstall) needed by
///   [CreditService] to keep device_map.credits in sync for future restores.
class UserSession {
  UserSession._();
  static final UserSession instance = UserSession._();

  /// The canonical user id — always == FirebaseAuth.currentUser.uid.
  String? uid;

  /// The stable hardware device ID.  Set by [AppInitializer].
  String? deviceId;

  bool get isReady => uid != null;
}
