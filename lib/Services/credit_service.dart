import 'dart:async';
import 'package:vidzeon/Services/remote_config_service.dart';
import 'package:flutter/foundation.dart';
import '../Core/user_session.dart';
import '../repositories/device_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/subscription_ledger_repository.dart';

/// Manages the user's credit balance backed by Firestore.
/// Keeps a local in-memory cache so UI reads are instant.
class CreditService {
  // Singleton
  static final CreditService _instance = CreditService._internal();
  factory CreditService() => _instance;
  CreditService._internal();

  final UserRepository _userRepository = UserRepository();
  final DeviceRepository _deviceRepository = DeviceRepository();

  int _credits = 0;
  bool _initialized = false;
  Future<void>? _initFuture; // guards against concurrent initialize() calls
  StreamSubscription<int?>? _firestoreSubscription;

  final StreamController<int> _creditStreamController =
      StreamController<int>.broadcast();

  final StreamController<int> _deductionController =
      StreamController<int>.broadcast();

  /// Live stream of the credit balance — use StreamBuilder in UI
  Stream<int> get creditStream => _creditStreamController.stream;

  /// Stream of deduction amounts — used for UI animations/feedback
  Stream<int> get onCreditDeducted => _deductionController.stream;

  /// Current credit balance (synchronous, from local cache)
  int get credits => _credits;

  // ── Initialization ────────────────────────────────────────────────────────

  Future<void> initialize() {
    if (_initialized) return Future.value();
    _initFuture ??= _doInitialize();
    return _initFuture!;
  }

  Future<void> _doInitialize() async {
    // Use the UID resolved by AppInitializer (survives reinstall).
    // The previous version bailed silently if uid was null, which meant
    // a purchase completing before AppInitializer finished would skip
    // credit grants entirely. Now we wait — up to ~3s — for the uid to
    // appear, so a purchase that fires "too early" still works.
    String? uid = UserSession.instance.uid;
    int attempts = 0;
    while (uid == null && attempts < 12) {
      await Future.delayed(const Duration(milliseconds: 250));
      uid = UserSession.instance.uid;
      attempts++;
    }

    if (uid == null) {
      debugPrint(
        '❌ [CreditService] UserSession.uid never resolved after 3s — aborting init.',
      );
      _initFuture = null; // allow a retry next time initialize() is called
      return;
    }

    debugPrint('💳 [CreditService] Initializing for uid=$uid...');

    // Initialize balance from RemoteConfig (not linked to user document)
    final initial = _readInitialCreditsFromRemoteConfig();
    _credits = initial;

    _initialized = true;
    _creditStreamController.add(_credits);
    debugPrint('💳 [CreditService] Initialized — balance: $_credits');
  }

  // ── Credit operations ─────────────────────────────────────────────────────

  /// Whether the user can afford a generation that costs [cost] credits
  bool hasEnoughCredits(int cost) => _credits >= cost;

  /// Deduct [cost] credits after a successful generation
  Future<void> deductCredits(int cost) async {
    if (cost <= 0) return;
    final newBalance = (_credits - cost).clamp(0, _credits);
    _credits = newBalance;
    _deductionController.add(cost); // Notify deduction for UI feedback
    _creditStreamController.add(_credits);
    debugPrint('💳 [CreditService] Deducted $cost — new balance: $_credits');
    await _persistToFirestore();
  }

  /// Add [amount] credits. Self-heals if not yet initialized.
  Future<void> addCredits(int amount) async {
    if (amount <= 0) return;
    await initialize(); // idempotent: returns immediately if already init'd
    _credits += amount;
    _creditStreamController.add(_credits);
    debugPrint('💳 [CreditService] Added $amount — new balance: $_credits');
    await _persistToFirestore();
  }

  /// Forcefully set a specific balance
  Future<void> setCredits(int amount) async {
    _credits = amount.clamp(0, 999999);
    _creditStreamController.add(_credits);
    debugPrint('💳 [CreditService] Set balance to $_credits');
    await _persistToFirestore();
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _persistToFirestore() async {
    final uid = UserSession.instance.uid;
    if (uid == null) {
      debugPrint(
        '⚠️ [CreditService] Cannot persist — UserSession.uid not set.',
      );
      return;
    }
    try {
      // Sync credits ONLY to subscription ledger (not user data)
      await SubscriptionLedgerRepository().syncCredits(uid, _credits);
    } catch (e) {
      debugPrint(
        '❌ [CreditService] Failed to sync credits to subscription ledger: $e',
      );
    }
  }

  int _readInitialCreditsFromRemoteConfig() {
    return RemoteConfigService().initialCredits;
  }

  /// Resets the service state for logout.
  /// Cancels subscriptions but keeps the service reusable for re-login.
  void resetForLogout() {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
    _initialized = false;
    _initFuture = null;
    _credits = 0;
    debugPrint('💳 [CreditService] Reset for logout');
  }

  void dispose() {
    _firestoreSubscription?.cancel();
    _creditStreamController.close();
  }
}
