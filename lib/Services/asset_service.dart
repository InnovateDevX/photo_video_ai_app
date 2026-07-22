import 'package:firebase_core/firebase_core.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import 'package:vidzeon/Models/user_asset.dart';

class AssetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Saves a persistent copy of the downloaded asset to Firebase Storage and Firestore.
  /// Only stores if the user is authenticated (not guest).
  Future<void> saveUserAsset(File file, String type) async {
    final user = _auth.currentUser;
    if (user == null || user.isAnonymous) return;

    final String assetId = const Uuid().v4();
    final String extension = file.path.split('.').last;
    final String storagePath = 'users/${user.uid}/assets/$assetId.$extension';

    try {
      // 1. Upload to Storage
      final ref = _storage.ref().child(storagePath);
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();

      // 2. Log to Firestore
      final asset = UserAsset(
        id: assetId,
        url: downloadUrl,
        type: type,
        createdAt: DateTime.now(),
      );

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('assets')
          .doc(assetId)
          .set(asset.toMap());

      debugPrint('✅ [AssetService] Successfully saved to Database.');
      debugPrint(
        '📍 [AssetService] Firestore Path: users/${user.uid}/assets/$assetId',
      );
    } catch (e) {
      debugPrint('❌ [AssetService] Failed to save asset: $e');
    }
  }

  /// Returns a stream of persistent assets for the current user.
  Stream<List<UserAsset>> getUserAssetsStream() {
    final user = _auth.currentUser;
    if (user == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('assets')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => UserAsset.fromFirestore(doc))
              .toList();
        });
  }
}
