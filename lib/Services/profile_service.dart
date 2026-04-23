import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class ProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Checks if a username is available.
  Future<bool> isUsernameAvailable(String username) async {
    final cleanUsername = username.toLowerCase().trim();
    if (cleanUsername.isEmpty) return false;
    
    final doc = await _firestore.collection('usernames').doc(cleanUsername).get();
    return !doc.exists;
  }

  /// Claims a username and updates the user profile atomically.
  Future<void> saveProfile({
    required String uid,
    required String currentUsername,
    required String newUsername,
    required String displayName,
    required String bio,
    String? photoUrl,
  }) async {
    final cleanNewUsername = newUsername.toLowerCase().trim();
    final cleanCurrentUsername = currentUsername.toLowerCase().trim();

    final userRef = _firestore.collection('users').doc(uid);
    final newUsernameRef = _firestore.collection('usernames').doc(cleanNewUsername);
    final oldUsernameRef = cleanCurrentUsername.isNotEmpty ? _firestore.collection('usernames').doc(cleanCurrentUsername) : null;

    await _firestore.runTransaction((transaction) async {
      // If changing username, check availability inside transaction
      if (cleanNewUsername != cleanCurrentUsername) {
        final newUsernameDoc = await transaction.get(newUsernameRef);
        if (newUsernameDoc.exists) {
          throw Exception("Username is already taken.");
        }
      }

      // Update users doc (merge true to keep credits)
      final profileData = {
        'username': cleanNewUsername,
        'displayName': displayName,
        'bio': bio,
      };
      // only include photoUrl if it's explicitly passed (don't overwrite it with null if we didn't upload a new one)
      if (photoUrl != null) {
        profileData['photoUrl'] = photoUrl;
      }

      transaction.set(userRef, {
        'profile': profileData
      }, SetOptions(merge: true));

      // Claim new username
      if (cleanNewUsername != cleanCurrentUsername) {
        transaction.set(newUsernameRef, {'uid': uid});
        
        // Release old username
        if (oldUsernameRef != null) {
          transaction.delete(oldUsernameRef);
        }
      }
    });
  }

  /// Uploads a profile picture to Firebase Storage and returns the download URL
  Future<String> uploadProfilePicture(String uid, File imageFile) async {
    final ext = imageFile.path.split('.').last;
    final fileName = 'profile_${const Uuid().v4()}.$ext';
    final ref = _storage.ref().child('profiles/$uid/$fileName');
    
    await ref.putFile(imageFile);
    return await ref.getDownloadURL();
  }

  /// Get profile stream
  Stream<Map<String, dynamic>?> getProfileStream(String uid) {
    if (uid.isEmpty) return Stream.value(null);

    return _firestore.collection('users').doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null && doc.data()!.containsKey('profile')) {
        return Map<String, dynamic>.from(doc.data()!['profile'] as Map);
      }
      return null;
    });
  }
}
