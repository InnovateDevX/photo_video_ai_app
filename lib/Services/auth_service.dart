import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:trail_ai_app/Core/user_session.dart';
import 'package:trail_ai_app/Services/credit_service.dart';

/// Service responsible for Firebase Authentication.
/// Architecture Decision: Dependency injection ready structure.
class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _auth = auth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  /// Starts an anonymous Firebase session.
  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  /// Sign in with Email and Password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign up with Email and Password
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final authorization = await googleUser.authorizationClient
          .authorizationForScopes(['email', 'profile']);

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: authorization?.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      if (e is GoogleSignInException &&
          e.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }
      rethrow;
    }
  }

  /// Ends the current Firebase session.
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
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

    // 3. Sign out from Firebase and Google
    await _googleSignIn.signOut();
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
