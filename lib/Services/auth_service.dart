import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:vidzeon/Core/user_session.dart';
import 'package:vidzeon/Services/credit_service.dart';
import 'package:vidzeon/repositories/user_repository.dart';
import 'package:vidzeon/Services/local_storage_service.dart';

/// Service responsible for Firebase Authentication.
/// Architecture Decision: Dependency injection ready structure.
class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  /// Starts an anonymous Firebase session.
  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  /// Ends the current Firebase session.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Deletes user's local app data and session while leaving credits and subscription ledgers intact.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    
    // Clear user local app data (generated assets, media files)
    try {
      await LocalStorageService().clearAllData();
    } catch (e) {
      debugPrint('⚠️ [AuthService] Failed to clear local app data: $e');
    }

    if (user != null) {
      final uid = user.uid;
      
      // Delete user profile document in Firestore (leaves subscription_ledgers intact)
      try {
        await UserRepository().deleteUser(uid);
      } catch (e) {
        debugPrint('⚠️ [AuthService] Failed to delete user doc: $e');
      }
      
      // Delete the Firebase Auth user
      try {
        await user.delete();
      } catch (e) {
        debugPrint('⚠️ [AuthService] Failed to delete auth user: $e');
      }
      
      // Clear local session (credits in subscription ledgers remain safe)
      UserSession.instance.uid = null;
      UserSession.instance.deviceId = null;
    }
  }

  /// Signs out and performs cleanup to prevent permission errors.
  /// This clears UserSession and cancels Firestore subscriptions
  /// before signing out to avoid permission denied errors.
  Future<void> signOutWithCleanup() async {
    // 1. Clear UserSession.uid first to prevent Firestore operations
    //    from using stale credentials
    UserSession.instance.uid = null;
    UserSession.instance.deviceId = null;

    // 2. Cancel Firestore subscriptions to prevent permission errors
    //    after authentication state changes
    CreditService().resetForLogout();

    // 3. Sign out from Firebase
    await _auth.signOut();
  }

  /// Performs cleanup before login to prevent permission errors
  /// when switching from a guest or previous user session.
  Future<void> prepareForLogin() async {
    // Reset CreditService to cancel old subscriptions before
    // the UID changes
    CreditService().resetForLogout();
    debugPrint('🔑 [AuthService] Prepared for login - reset CreditService');
  }

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
