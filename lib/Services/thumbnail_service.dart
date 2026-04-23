import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:path_provider/path_provider.dart';
import 'package:trail_ai_app/Models/generated_asset.dart';
import 'package:trail_ai_app/Models/reel.dart';
import 'package:trail_ai_app/Models/user_asset.dart';
import 'package:trail_ai_app/Services/local_storage_service.dart';

class ThumbnailService {
  static final ThumbnailService _instance = ThumbnailService._internal();
  factory ThumbnailService() => _instance;
  ThumbnailService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Extracts the first frame of a video (URL or local path) and saves it to a file.
  Future<File?> _extractFrame(String videoPath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final thumbnailsDir = Directory('${appDir.path}/thumbnails');
      if (!await thumbnailsDir.exists()) {
        await thumbnailsDir.create(recursive: true);
      }

      final String? thumbPath = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: thumbnailsDir.path,
        imageFormat: ImageFormat.JPEG,
        maxHeight: 480,
        quality: 75,
      );

      if (thumbPath != null) {
        return File(thumbPath);
      }
    } catch (e) {
      debugPrint('❌ [ThumbnailService] extraction failed: $e');
    }
    return null;
  }

  /// Process a local GeneratedAsset: Generate thumbnail and save path in SharedPreferences.
  Future<void> processGeneratedAsset(GeneratedAsset asset) async {
    if (asset.category != 'video' || asset.thumbnailPath != null) return;

    final file = File(asset.filePath);
    if (!await file.exists()) return;

    debugPrint(
      '🎥 [ThumbnailService] Generating local thumbnail for ${asset.id}',
    );
    final thumbFile = await _extractFrame(asset.filePath);
    if (thumbFile != null) {
      await LocalStorageService().updateAssetThumbnail(
        asset.id,
        thumbFile.path,
      );
      debugPrint(
        '✅ [ThumbnailService] Local thumbnail saved: ${thumbFile.path}',
      );
    }
  }

  /// Process a cloud UserAsset: Generate thumbnail, save locally, upload to Storage, and update Firestore.
  Future<void> processUserAsset(String uid, UserAsset asset) async {
    if (asset.type != 'video' || asset.thumbnailUrl != null) return;

    debugPrint(
      '🎥 [ThumbnailService] Generating cloud thumbnail for Asset ${asset.id}',
    );
    final thumbFile = await _extractFrame(asset.url);
    if (thumbFile != null) {
      try {
        // Upload to Firebase Storage
        final storageRef = _storage.ref().child(
          'users/$uid/thumbnails/${asset.id}.jpg',
        );
        await storageRef.putFile(thumbFile);
        final downloadUrl = await storageRef.getDownloadURL();

        // Update Firestore
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('assets')
            .doc(asset.id)
            .update({'thumbnailUrl': downloadUrl});

        debugPrint(
          '✅ [ThumbnailService] Cloud asset thumbnail synced: $downloadUrl',
        );
      } catch (e) {
        debugPrint('❌ [ThumbnailService] Sync failed: $e');
      }
    }
  }

  // Track which reels we've already requested thumbnail generation for
  // to prevent duplicate requests across rebuilds
  static final Set<String> _processingReelIds = {};

  /// Process a public Reel: Generate thumbnail, upload to Storage, and update Firestore.
  /// FIX: Removed backfill to liked/saved subcollections to prevent infinite snapshot loops.
  Future<void> processReelThumbnail(Reel reel, String? uid) async {
    if (reel.type != 'video' || reel.thumbnailUrl != null) return;
    
    // Prevent duplicate processing
    if (_processingReelIds.contains(reel.id)) return;
    _processingReelIds.add(reel.id);

    debugPrint('🎥 [ThumbnailService] Generating thumbnail for Reel ${reel.id}');
    final thumbFile = await _extractFrame(reel.videoUrl);
    if (thumbFile != null) {
      try {
        final storageRef = _storage.ref().child(
          'reels/thumbnails/${reel.id}.jpg',
        );
        await storageRef.putFile(thumbFile);
        final downloadUrl = await storageRef.getDownloadURL();

        // Only update the canonical public reel doc
        await _firestore.collection('reels').doc(reel.id).update({
          'thumbnailUrl': downloadUrl,
        });
        
        debugPrint('✅ [ThumbnailService] Reel thumbnail synced to public storage.');
      } catch (e) {
        if (e.toString().contains('unauthorized') && uid != null) {
          debugPrint('⚠️ [ThumbnailService] Public storage unauthorized, saving to private folder...');
          try {
            // Fallback: save to private storage if public upload fails
            final privateRef = _storage.ref().child('users/$uid/thumbnails/${reel.id}.jpg');
            await privateRef.putFile(thumbFile);
            final downloadUrl = await privateRef.getDownloadURL();

            // Backfill the user's mirrored copies safely using merge
            final batch = _firestore.batch();
            final userRef = _firestore.collection('users').doc(uid);
            
            batch.set(userRef.collection('liked_reels').doc(reel.id), {'thumbnailUrl': downloadUrl}, SetOptions(merge: true));
            batch.set(userRef.collection('saved_reels').doc(reel.id), {'thumbnailUrl': downloadUrl}, SetOptions(merge: true));
            
            await batch.commit();
            debugPrint('✅ [ThumbnailService] Private thumbnail synced and mirrored.');
          } catch (privateError) {
            debugPrint('❌ [ThumbnailService] Private sync failed: $privateError');
          }
        } else {
          debugPrint('❌ [ThumbnailService] Reel sync failed: $e');
        }
      } finally {
        _processingReelIds.remove(reel.id);
      }
    } else {
      _processingReelIds.remove(reel.id);
    }
  }
}
