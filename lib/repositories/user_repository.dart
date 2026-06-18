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
          // Doc missing → create with both required fields (satisfies hasAll rule)
          tx.set(docRef, {
            'credits': credits,
            'created_at': FieldValue.serverTimestamp(),
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
}
