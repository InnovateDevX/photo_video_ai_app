import 'dart:async';
import 'package:trail_ai_app/Services/remote_config_service.dart';
import 'package:flutter/foundation.dart';
import '../Core/user_session.dart';
import '../repositories/device_repository.dart';
import '../repositories/user_repository.dart';

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
    // Falls back to null if AppInitializer hasn't run yet.
    final uid = UserSession.instance.uid;
    if (uid == null) {
      debugPrint(
        '⚠️ [CreditService] UserSession.uid not set — cannot initialize.',
      );
      return;
    }

    debugPrint('💳 [CreditService] Initializing for uid=$uid...');

    // Fetch current balance from Firestore
    final remoteCredits = await _userRepository.getCredits(uid);

    if (remoteCredits == null) {
      // User doc doesn't have credits yet — seed with initial value
      final initial = _readInitialCreditsFromRemoteConfig();
      debugPrint(
        '💳 [CreditService] No credits field found — seeding with $initial',
      );
      await _userRepository.setCredits(uid, initial);
      _credits = initial;
    } else {
      _credits = remoteCredits;
    }

    _initialized = true;
    _creditStreamController.add(_credits);
    debugPrint('💳 [CreditService] Initialized — balance: $_credits');

    // Subscribe to live Firestore updates (e.g. admin edits from console)
    _firestoreSubscription?.cancel();
    _firestoreSubscription = _userRepository.watchCredits(uid).listen((value) {
      if (value != null && value != _credits) {
        _credits = value;
        _creditStreamController.add(_credits);
        debugPrint(
          '💳 [CreditService] Live update from Firestore — balance: $_credits',
        );
      }
    });
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

  /// Add [amount] credits
  Future<void> addCredits(int amount) async {
    if (amount <= 0) return;
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
      await _userRepository.setCredits(uid, _credits);
    } catch (e) {
      debugPrint(
        '❌ [CreditService] Failed to persist credits to Firestore: $e',
      );
    }

    // Keep device_map.credits in sync so future reinstalls restore correctly.
    final deviceId = UserSession.instance.deviceId;
    if (deviceId != null) {
      await _deviceRepository.syncCredits(
        deviceId: deviceId,
        credits: _credits,
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
