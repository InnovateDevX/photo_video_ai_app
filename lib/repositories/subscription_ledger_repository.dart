import 'dart:convert';
import 'dart:io' show Platform;
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SubscriptionLedgerRepository {
  final FirebaseFirestore _firestore;

  SubscriptionLedgerRepository({FirebaseFirestore? firestore})
    : _firestore =
          firestore ??
          FirebaseFirestore.instanceFor(
            app: Firebase.app(),
            databaseId: 'default',
          );

  /// Hashes a token using SHA-256
  String hashToken(String token) {
    var bytes = utf8.encode(token);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  static const String _activeLedgersKey = 'active_ledger_hashes';

  Future<void> _saveLedgerHashLocally(String tokenHash) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> current = prefs.getStringList(_activeLedgersKey) ?? [];
      if (!current.contains(tokenHash)) {
        current.add(tokenHash);
        await prefs.setStringList(_activeLedgersKey, current);
        debugPrint('💾 [Ledger] Cached ledger hash locally: $tokenHash');
      }
    } catch (e) {
      debugPrint('⚠️ [Ledger] Failed to save ledger hash locally: $e');
    }
  }

  /// Processes a purchase. Returns `(isNew, existingCredits)`.
  ///
  /// [isRestore] controls the fallback when Firestore is unreachable:
  ///   - New purchase ([isRestore]=false): fallback returns `(true, 0)` so the
  ///     caller still grants credits. Over-granting once is better than leaving
  ///     a user who just paid with nothing.
  ///   - Restore ([isRestore]=true): fallback returns `(false, 0)` — conservative.
  ///     We cannot verify whether the token was already processed, so we do NOT
  ///     grant extra credits. The user's existing balance is preserved.
  Future<(bool, int)> processPurchase({
    required String token,
    required String productId,
    required String uid,
    required int initialCredits,
    bool isRestore = false,
  }) async {
    final tokenHash = hashToken(token);
    final docRef = _firestore.collection('subscription_ledgers').doc(tokenHash);

    try {
      final result = await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);

        if (!doc.exists) {
          // New purchase — write ledger for the first time.
          transaction.set(docRef, {
            'tokenHash': tokenHash,
            'platform': Platform.isIOS ? 'ios' : 'android',
            'productId': productId,
            'active': true,
            'creditsRemaining': initialCredits,
            'currentUid': uid,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          debugPrint('🧾 [Ledger] Created NEW ledger for hash: $tokenHash');
          return (true, 0); // isNew = true, existingCredits = 0
        } else {
          // Existing purchase (Restore).
          final data = doc.data()!;
          final existingCredits = data['creditsRemaining'] as int? ?? 0;

          transaction.update(docRef, {
            'active': true,
            'currentUid': uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          debugPrint(
            '🧾 [Ledger] Updated EXISTING ledger for hash: $tokenHash. '
            'existingCredits=$existingCredits',
          );
          return (false, existingCredits); // isNew = false
        }
      });

      await _saveLedgerHashLocally(tokenHash);
      return result;
    } catch (e) {
      _logLedgerFallback(e, tokenHash, uid, productId);
      // Conservative fallback for restores: we cannot verify whether this
      // token was already processed, so default to NOT granting credits.
      // We return -1 for existingCredits to signal a network error so the 
      // caller doesn't overwrite the user's local balance with 0.
      return isRestore ? (false, -1) : (true, 0);
    }
  }

  /// Emits a single, grep-able log line when the ledger write fails.
  /// Centralised so the wording is consistent and easy to alert on.
  void _logLedgerFallback(
    Object error,
    String tokenHash,
    String uid,
    String productId,
  ) {
    final isPermissionDenied =
        error is FirebaseException && error.code == 'permission-denied';
    final hint = isPermissionDenied
        ? ' → Firestore rules for `subscription_ledgers` are likely missing. '
              'Deploy firestore.rules to fix.'
        : ' → Treat as transient. User still gets credits (over-grant, not under-grant).';
    debugPrint(
      '🚨 [Ledger] FALLBACK path hit for hash=$tokenHash uid=$uid '
      'product=$productId. error=$error.$hint',
    );
  }

  /// Syncs credits for all active ledgers associated with the given UID.
  Future<void> syncCredits(String uid, int credits) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> cachedHashes =
          prefs.getStringList(_activeLedgersKey) ?? [];

      if (cachedHashes.isEmpty) {
        debugPrint(
          '🧾 [Ledger] No cached ledger hashes found on device; skipping sync.',
        );
        return;
      }

      final batch = _firestore.batch();
      for (final hash in cachedHashes) {
        final docRef = _firestore.collection('subscription_ledgers').doc(hash);
        batch.update(docRef, {
          'creditsRemaining': credits,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      debugPrint(
        '🧾 [Ledger] Synced $credits credits directly to ${cachedHashes.length} ledgers for UID: $uid',
      );
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        debugPrint(
          '⚠️ [Ledger] syncCredits: client-side updates to ledger are not allowed by security rules (non-fatal).',
        );
      } else {
        debugPrint('❌ [Ledger] syncCredits error: $e');
      }
    }
  }
}
