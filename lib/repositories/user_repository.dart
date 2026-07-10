import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../Models/user_model.dart';
import '../Services/remote_config_service.dart';

/// Repository handling user document creation and retrieval.
class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // ── Document creation ───────────────────────────────────────────────────

  /// Creates a base user document with initial credits.
  /// Uses [batch] when called from AppInitializer (avoids nested transaction.get).
  Future<void> createUserIfMissing(
    String uid, {
    Transaction? transaction,
    WriteBatch? batch,
    int? initialCredits,
  }) async {
    final creditsToAssign = initialCredits ?? RemoteConfigService().initialCredits;
    debugPrint(
      '💾 [UserRepository] createUserIfMissing(uid=$uid, initialCredits=$creditsToAssign)',
    );
    final docRef = _firestore.collection('users').doc(uid);
    // Only write the two fields the Firestore rules permit on create
    final data = {
      'created_at': FieldValue.serverTimestamp(),
      'credits': creditsToAssign,
      'isPro': false,
      'proProductId': null,
      'proPurchasedAt': null,
      'proExpiresAt': null,
    };

    try {
      if (batch != null) {
        // merge:true → if the doc already exists, fields already present
        // (e.g. credits) are LEFT UNTOUCHED. Missing fields are added.
        batch.set(docRef, data, SetOptions(merge: true));
        debugPrint(
          '💾 [UserRepository] batch.set(merge) queued for users/$uid ✅',
        );
      } else if (transaction != null) {
        transaction.set(docRef, data);
        debugPrint(
          '💾 [UserRepository] transaction.set() called for users/$uid ✅',
        );
      } else {
        // Standalone — retry with exponential backoff for transient errors
        const maxAttempts = 3;
        for (int attempt = 1; attempt <= maxAttempts; attempt++) {
          try {
            await _firestore.runTransaction((tx) async {
              final snapshot = await tx.get(docRef);
              debugPrint(
                '💾 [UserRepository] Standalone tx (attempt $attempt): doc exists=${snapshot.exists}',
              );
              if (!snapshot.exists) {
                tx.set(docRef, data);
                debugPrint('💾 [UserRepository] Standalone tx: set() called ✅');
              } else {
                final existingData = snapshot.data();
                final updateData = <String, dynamic>{};
                if (existingData != null) {
                  if (!existingData.containsKey('isPro')) updateData['isPro'] = false;
                  if (!existingData.containsKey('proProductId')) updateData['proProductId'] = null;
                  if (!existingData.containsKey('proPurchasedAt')) updateData['proPurchasedAt'] = null;
                  if (!existingData.containsKey('proExpiresAt')) updateData['proExpiresAt'] = null;
                }
                if (updateData.isNotEmpty) {
                  tx.update(docRef, updateData);
                  debugPrint('💾 [UserRepository] Standalone tx: missing pro fields added ✅');
                }
              }
            });
            debugPrint(
              '💾 [UserRepository] Standalone transaction committed ✅',
            );
            break; // success — stop retrying
          } catch (txError) {
            final isTransient =
                txError.toString().contains('unavailable') ||
                txError.toString().contains('UNAVAILABLE');
            if (isTransient && attempt < maxAttempts) {
              final delay = Duration(seconds: attempt * 2); // 2s, 4s
              debugPrint(
                '⚠️ [UserRepository] Transient error (attempt $attempt/$maxAttempts). '
                'Retrying in ${delay.inSeconds}s...',
              );
              await Future.delayed(delay);
            } else {
              // Non-transient or max retries exhausted — log and continue
              debugPrint(
                '⚠️ [UserRepository] createUserIfMissing gave up after $attempt attempt(s): $txError',
              );
              // Don't rethrow — user still has local credit state
            }
          }
        }
      }
    } catch (e, stack) {
      debugPrint('❌ [UserRepository] createUserIfMissing FAILED: $e');
      debugPrint('❌ [UserRepository] Stack: $stack');
      rethrow;
    }
  }

  // ── Credits ─────────────────────────────────────────────────────────────

  /// Returns the current credit balance for [uid] from Firestore.
  Future<int?> getCredits(String uid) async {
    debugPrint('🔍 [UserRepository] getCredits(uid=$uid)');
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final credits = doc.data()?['credits'] as int?;
        debugPrint('🔍 [UserRepository] Credits: $credits');
        return credits;
      }
    } catch (e, stack) {
      debugPrint('❌ [UserRepository] getCredits FAILED: $e');
      debugPrint('❌ [UserRepository] Stack: $stack');
    }
    return null;
  }

  /// Updates the credit balance for [uid] in Firestore.
  /// Creates the document with [created_at] if it doesn't exist yet (new user).
  /// Only updates [credits] if the document already exists (existing user).
  Future<void> setCredits(String uid, int credits) async {
    debugPrint('💾 [UserRepository] setCredits(uid=$uid, credits=$credits)');
    try {
      final docRef = _firestore.collection('users').doc(uid);
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (snap.exists) {
          // Doc exists → only update credits (don't touch created_at)
          tx.update(docRef, {'credits': credits});
        } else {
          // Doc missing → create with required fields
          tx.set(docRef, {
            'credits': credits,
            'created_at': FieldValue.serverTimestamp(),
            'isPro': false,
            'proProductId': null,
            'proPurchasedAt': null,
            'proExpiresAt': null,
          });
        }
      });
      debugPrint('💾 [UserRepository] Credits updated to $credits ✅');
    } catch (e, stack) {
      debugPrint('❌ [UserRepository] setCredits FAILED: $e');
      debugPrint('❌ [UserRepository] Stack: $stack');
      rethrow;
    }
  }

  /// Atomically increments or decrements the credit balance using FieldValue.increment.
  Future<void> adjustCredits(String uid, int delta) async {
    debugPrint('💾 [UserRepository] adjustCredits(uid=$uid, delta=$delta)');
    try {
      await _firestore.collection('users').doc(uid).update({
        'credits': FieldValue.increment(delta),
      });
      debugPrint('💾 [UserRepository] Credits adjusted by $delta ✅');
    } catch (e, stack) {
      debugPrint('❌ [UserRepository] adjustCredits FAILED: $e');
      debugPrint('❌ [UserRepository] Stack: $stack');
      rethrow;
    }
  }

  // ── Tokens ──────────────────────────────────────────────────────────────

  /// Saves or updates the FCM registration token for the user.
  Future<void> updateFcmToken(String uid, String token) async {
    debugPrint('💾 [UserRepository] updateFcmToken(uid=$uid)');
    try {
      await _firestore.collection('users').doc(uid).update({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
      debugPrint('💾 [UserRepository] FCM Token updated successfully ✅');
    } catch (e) {
      debugPrint(
        '⚠️ [UserRepository] Failed to update FCM token (doc might not exist yet): $e',
      );
      // If doc doesn't exist, we don't want to crash — tokens are secondary to credit initialization.
    }
  }

  // ── User retrieval ───────────────────────────────────────────────────────

  /// Retrieves the populated UserModel from Firestore.
  Future<UserModel?> getUser(String uid) async {
    debugPrint('🔍 [UserRepository] getUser(uid=$uid)');
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      debugPrint('🔍 [UserRepository] users/$uid exists: ${doc.exists}');
      if (doc.exists) {
        return UserModel.fromMap(doc.id, doc.data()!);
      }
    } catch (e, stack) {
      debugPrint('❌ [UserRepository] getUser FAILED: $e');
      debugPrint('❌ [UserRepository] Stack: $stack');
    }
    return null;
  }

  /// Returns a live stream of the credit balance.
  Stream<int?> watchCredits(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.data()?['credits'] as int?);
  }

  // ── Pro Status ──────────────────────────────────────────────────────────

  /// Updates the pro subscription status for [uid] in Firestore.
  Future<void> updateProStatus(
    String uid,
    bool isPro, {
    String? productId,
    DateTime? expiresAt,
  }) async {
    debugPrint(
      '💾 [UserRepository] updateProStatus(uid=$uid, isPro=$isPro, product=$productId)',
    );
    try {
      final Map<String, dynamic> data = {
        'isPro': isPro,
        'proPurchasedAt': FieldValue.serverTimestamp(),
      };
      if (productId != null) data['proProductId'] = productId;
      if (expiresAt != null) data['proExpiresAt'] = Timestamp.fromDate(expiresAt);

      await _firestore.collection('users').doc(uid).set(
        data,
        SetOptions(merge: true),
      );
      debugPrint('💾 [UserRepository] Pro status updated ✅');
    } catch (e, stack) {
      debugPrint('❌ [UserRepository] updateProStatus FAILED: $e');
      debugPrint('❌ [UserRepository] Stack: $stack');
    }
  }

  /// Returns the current pro status for [uid].
  Future<bool> getProStatus(String uid) async {
    debugPrint('🔍 [UserRepository] getProStatus(uid=$uid)');
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        final isPro = doc.data()?['isPro'] as bool? ?? false;
        debugPrint('🔍 [UserRepository] isPro: $isPro');
        return isPro;
      }
    } catch (e) {
      debugPrint('❌ [UserRepository] getProStatus FAILED: $e');
    }
    return false;
  }
}

