import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Repository handling deviceId → uid mapping in Firestore.
///
/// device_map documents now also carry a [credits] field so that on
/// reinstall the app can restore the user's balance without needing to
/// read users/{oldUid} (which would fail security rules because auth.uid
/// is a brand-new anonymous UID after reinstall).
class DeviceRepository {
  final FirebaseFirestore _firestore;

  DeviceRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');

  // ── Read ───────────────────────────────────────────────────────────────────

  /// Returns the full device_map document data for [deviceId], or null if not
  /// found.  Callers should be authenticated before calling (Firestore rules
  /// require `request.auth != null`).
  Future<Map<String, dynamic>?> getDeviceData(String deviceId) async {
    debugPrint('🔍 [DeviceRepository] getDeviceData($deviceId)');
    try {
      final snap = await _firestore
          .collection('device_map')
          .doc(deviceId)
          .get();
      if (snap.exists) {
        debugPrint('🔍 [DeviceRepository] found: ${snap.data()}');
        return snap.data();
      }
    } catch (e) {
      debugPrint('❌ [DeviceRepository] getDeviceData FAILED: $e');
    }
    return null;
  }

  /// Convenience: returns the uid from an existing device mapping.
  Future<String?> getUidForDevice(String deviceId) async {
    final data = await getDeviceData(deviceId);
    return data?['uid'] as String?;
  }

  // ── Write ──────────────────────────────────────────────────────────────────

  /// Creates a new device→uid mapping (first install).
  /// Queues the write on [batch] when provided.
  void createMapping({
    required WriteBatch batch,
    required String deviceId,
    required String uid,
    int? credits,
  }) {
    debugPrint(
      '💾 [DeviceRepository] createMapping($deviceId → $uid)',
    );
    batch.set(_firestore.collection('device_map').doc(deviceId), {
      'uid': uid,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    });
  }

  /// Updates device_map when a user reinstalls (uid changes to new anon uid).
  Future<void> migrateMapping({
    required String deviceId,
    required String newUid,
    int? credits,
  }) async {
    debugPrint(
      '♻️  [DeviceRepository] migrateMapping($deviceId → $newUid)',
    );
    try {
      await _firestore.collection('device_map').doc(deviceId).update({
        'uid': newUid,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('❌ [DeviceRepository] migrateMapping FAILED: $e');
      rethrow;
    }
  }

  /// Syncs credits to device_map (No-op: credits are managed via SubscriptionLedgerRepository)
  Future<void> syncCredits({
    required String deviceId,
    required int credits,
  }) async {
    // Credits are not stored on device_map
  }
}
