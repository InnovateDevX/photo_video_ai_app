import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../Models/reel.dart';
import '../Core/user_session.dart';
import 'dart:async';

class ReelService {
  final FirebaseFirestore _firestore;

  // Static caches to ensure we don't recreate streams or re-fetch legacy reels
  static final Map<String, Stream<List<Reel>>> _likedStreamCache = {};
  static final Map<String, Stream<List<Reel>>> _savedStreamCache = {};

  ReelService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Get a stream of all reels
  Stream<List<Reel>> getReelsStream() {
    return _firestore.collection('reels').snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Reel.fromFirestore(doc.id, doc.data()))
          .toList();
    });
  }

  /// Get a chunk of reels for pagination (optional, using stream for simplicity now)
  Future<List<Reel>> getReels() async {
    final querySnapshot = await _firestore.collection('reels').get();
    return querySnapshot.docs
        .map((doc) => Reel.fromFirestore(doc.id, doc.data()))
        .toList();
  }

  /// User likes a reel — also writes a snapshot of the reel data so the
  /// profile page can read liked_reels in ONE query without a secondary fetch.
  Future<void> likeReel(String reelId, Reel reel) async {
    final uid = UserSession.instance.uid;
    if (uid == null) return;

    final userLikeRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('liked_reels')
        .doc(reelId);
    final reelRef = _firestore.collection('reels').doc(reelId);

    final batch = _firestore.batch();

    final snapshotData = {
      ...reel.toFirestore(),
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Write ONLY to Liked subcollection
    batch.set(userLikeRef, snapshotData);

    // Increment ONLY likesCount
    batch.update(reelRef, {
      'likesCount': FieldValue.increment(1),
    });

    await batch.commit();
    debugPrint(
      '✅ [ReelService] likeReel: Atomic commit successful',
    );
    debugPrint(
      '📍 [ReelService] User Like Path: users/$uid/liked_reels/$reelId',
    );
    debugPrint('📍 [ReelService] Global Reel Path: reels/$reelId');
  }

  /// User unlikes a reel
  Future<void> unlikeReel(String reelId) async {
    final uid = UserSession.instance.uid;
    if (uid == null) return;

    final userLikeRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('liked_reels')
        .doc(reelId);
    final reelRef = _firestore.collection('reels').doc(reelId);

    final batch = _firestore.batch();
    batch.delete(userLikeRef);
    batch.update(reelRef, {
      'likesCount': FieldValue.increment(-1),
    });

    await batch.commit();
    debugPrint(
      '✅ [ReelService] unlikeReel: Optimistic batch commit successful',
    );
  }

  /// Check if user liked a reel
  Stream<bool> isReelLiked(String reelId) {
    final uid = UserSession.instance.uid;
    if (uid == null) return Stream.value(false);

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('liked_reels')
        .doc(reelId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// User saves a reel — also writes a snapshot of the reel data so the
  /// profile page can read saved_reels in ONE query without a secondary fetch.
  Future<void> saveReel(String reelId, Reel reel) async {
    final uid = UserSession.instance.uid;
    if (uid == null) return;

    final userSaveRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('saved_reels')
        .doc(reelId);
    final reelRef = _firestore.collection('reels').doc(reelId);

    final batch = _firestore.batch();

    // Always write the saved_reels doc — this is the critical write.
    batch.set(userSaveRef, {
      ...reel.toFirestore(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Increment counter
    batch.update(reelRef, {'savedCount': FieldValue.increment(1)});

    await batch.commit();
    debugPrint('✅ [ReelService] saveReel: Atomic commit successful');
    debugPrint(
      '📍 [ReelService] User Save Path: users/$uid/saved_reels/$reelId',
    );
    debugPrint('📍 [ReelService] Global Reel Path: reels/$reelId');
  }

  /// Check if user saved a reel
  Stream<bool> isReelSaved(String reelId) {
    final uid = UserSession.instance.uid;
    if (uid == null) return Stream.value(false);

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('saved_reels')
        .doc(reelId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  /// User unsaves a reel
  Future<void> unsaveReel(String reelId) async {
    final uid = UserSession.instance.uid;
    if (uid == null) return;

    final userSaveRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('saved_reels')
        .doc(reelId);
    final reelRef = _firestore.collection('reels').doc(reelId);

    final batch = _firestore.batch();
    batch.delete(userSaveRef);
    batch.update(reelRef, {
      'savedCount': FieldValue.increment(-1),
    });

    await batch.commit();
    debugPrint(
      '✅ [ReelService] unsaveReel: Optimistic batch commit successful',
    );
  }

  /// Get a stream of the user's liked reels.
  Stream<List<Reel>> getLikedReelsStream() {
    final uid = UserSession.instance.uid;
    if (uid == null) return Stream.value([]);

    debugPrint(
      '🔄 [ReelService] getLikedReelsStream: Creating new stream for uid: $uid',
    );

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('liked_reels')
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          debugPrint(
            '📥 [ReelService] getLikedReelsStream: Snapshot received with ${snapshot.docs.length} docs, fromCache: ${snapshot.metadata.isFromCache}',
          );
          final reels = <Reel>[];

          for (final doc in snapshot.docs) {
            final data = doc.data();

            // 1. Check if denormalized data is present and valid
            final videoUrl = data['videoUrl'] as String?;
            if (videoUrl != null && videoUrl.isNotEmpty) {
              final reel = Reel.fromFirestore(doc.id, data);
              reels.add(reel);
              continue;
            }

            // 2. Fallback: create a placeholder reel
            final fallbackReel = Reel(
              id: doc.id,
              videoUrl: '',
              videoPrompt: data['videoPrompt'] ?? data['prompt'] ?? '',
              thumbnailUrl: data['thumbnailUrl'],
              imagePrompt: data['imagePrompt'] ?? '',
              imageEdit: data['imageEdit'] ?? false,
              type: data['type'] ?? 'video',
              isEditable: data['isEditable'] ?? false,
              likesCount: data['likesCount'] ?? 0,
              savedCount: data['savedCount'] ?? 0,
            );
            reels.add(fallbackReel);
          }

          return reels;
        })
        .handleError((error) {
          debugPrint('❌ [ReelService] getLikedReelsStream error: $error');
          return <Reel>[];
        });
  }

  /// Get a stream of the user's saved reels.
  Stream<List<Reel>> getSavedReelsStream() {
    final uid = UserSession.instance.uid;
    if (uid == null) return Stream.value([]);

    debugPrint(
      '🔄 [ReelService] getSavedReelsStream: Creating new stream for uid: $uid',
    );

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('saved_reels')
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) {
          debugPrint(
            '📥 [ReelService] getSavedReelsStream: Snapshot received with ${snapshot.docs.length} docs, fromCache: ${snapshot.metadata.isFromCache}',
          );
          final reels = <Reel>[];

          for (final doc in snapshot.docs) {
            final data = doc.data();

            final videoUrl = data['videoUrl'] as String?;
            if (videoUrl != null && videoUrl.isNotEmpty) {
              final reel = Reel.fromFirestore(doc.id, data);
              reels.add(reel);
              continue;
            }

            final fallbackReel = Reel(
              id: doc.id,
              videoUrl: '',
              videoPrompt: data['videoPrompt'] ?? data['prompt'] ?? '',
              thumbnailUrl: data['thumbnailUrl'],
              imagePrompt: data['imagePrompt'] ?? '',
              imageEdit: data['imageEdit'] ?? false,
              type: data['type'] ?? 'video',
              isEditable: data['isEditable'] ?? false,
              likesCount: data['likesCount'] ?? 0,
              savedCount: data['savedCount'] ?? 0,
            );
            reels.add(fallbackReel);
          }

          return reels;
        })
        .handleError((error) {
          debugPrint('❌ [ReelService] getSavedReelsStream error: $error');
          return <Reel>[];
        });
  }

  /// Force an immediate fetch of saved reels and return the data
  Future<List<Reel>> fetchSavedReelsOnce() async {
    final uid = UserSession.instance.uid;
    if (uid == null) return [];

    debugPrint(
      '🔄 [ReelService] fetchSavedReelsOnce: Fetching immediately for uid: $uid',
    );

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('saved_reels')
          .get();

      debugPrint(
        '📥 [ReelService] fetchSavedReelsOnce: Got ${snapshot.docs.length} docs',
      );

      final reels = <Reel>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final videoUrl = data['videoUrl'] as String?;
        if (videoUrl != null && videoUrl.isNotEmpty) {
          reels.add(Reel.fromFirestore(doc.id, data));
        } else {
          reels.add(
            Reel(
              id: doc.id,
              videoUrl: '',
              videoPrompt: data['videoPrompt'] ?? data['prompt'] ?? '',
              thumbnailUrl: data['thumbnailUrl'],
              imagePrompt: data['imagePrompt'] ?? '',
              imageEdit: data['imageEdit'] ?? false,
              type: data['type'] ?? 'video',
              isEditable: data['isEditable'] ?? false,
              likesCount: data['likesCount'] ?? 0,
              savedCount: data['savedCount'] ?? 0,
            ),
          );
        }
      }
      return reels;
    } catch (e) {
      debugPrint('❌ [ReelService] fetchSavedReelsOnce error: $e');
      return [];
    }
  }

  /// Force an immediate fetch of liked reels and return the data
  Future<List<Reel>> fetchLikedReelsOnce() async {
    final uid = UserSession.instance.uid;
    if (uid == null) return [];

    debugPrint(
      '🔄 [ReelService] fetchLikedReelsOnce: Fetching immediately for uid: $uid',
    );

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('liked_reels')
          .get();

      debugPrint(
        '📥 [ReelService] fetchLikedReelsOnce: Got ${snapshot.docs.length} docs',
      );

      final reels = <Reel>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final videoUrl = data['videoUrl'] as String?;
        if (videoUrl != null && videoUrl.isNotEmpty) {
          reels.add(Reel.fromFirestore(doc.id, data));
        } else {
          reels.add(
            Reel(
              id: doc.id,
              videoUrl: '',
              videoPrompt: data['videoPrompt'] ?? data['prompt'] ?? '',
              thumbnailUrl: data['thumbnailUrl'],
              imagePrompt: data['imagePrompt'] ?? '',
              imageEdit: data['imageEdit'] ?? false,
              type: data['type'] ?? 'video',
              isEditable: data['isEditable'] ?? false,
              likesCount: data['likesCount'] ?? 0,
              savedCount: data['savedCount'] ?? 0,
            ),
          );
        }
      }
      return reels;
    } catch (e) {
      debugPrint('❌ [ReelService] fetchLikedReelsOnce error: $e');
      return [];
    }
  }

  /// Add a new reel (Admin/Utility)
  Future<void> addReel({
    required String videoUrl,
    required String videoPrompt,
    String imagePrompt = '',
    bool imageEdit = false,
    String type = 'video',
    bool isEditable = false,
  }) async {
    await _firestore.collection('reels').add({
      'videoUrl': videoUrl,
      'videoPrompt': videoPrompt,
      'imagePrompt': imagePrompt,
      'imageEdit': imageEdit,
      'type': type,
      'isEditable': isEditable,
      'likesCount': 0,
      'savedCount': 0,
    });
  }
}
