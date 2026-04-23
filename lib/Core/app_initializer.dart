import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../Services/remote_config_service.dart';
import '../Core/user_session.dart';
import '../Services/device_service.dart';
import '../Services/auth_service.dart';
import '../Services/data_service.dart';
import '../repositories/device_repository.dart';
import '../repositories/user_repository.dart';
import '../Services/localization_service.dart';
import '../Services/notification_service.dart';
import '../Services/subscription_service.dart';

class AppInitializer {
  final DeviceService _deviceService;
  final AuthService _authService;
  final DeviceRepository _deviceRepository;
  final UserRepository _userRepository;
  final FirebaseFirestore _firestore;

  AppInitializer({
    DeviceService? deviceService,
    AuthService? authService,
    DeviceRepository? deviceRepository,
    UserRepository? userRepository,
    FirebaseFirestore? firestore,
  }) : _deviceService = deviceService ?? DeviceService(),
       _authService = authService ?? AuthService(),
       _deviceRepository = deviceRepository ?? DeviceRepository(),
       _userRepository = userRepository ?? UserRepository(),
       _firestore = firestore ?? FirebaseFirestore.instance;

  Future<String?> initializeUser() async {
    debugPrint('🚀 [AppInitializer] Starting user initialization…');
    
    // ── Step 0: Initialize Remote Config ──────────────────────────────────
    // Do this first so other services can use it immediately.
    await RemoteConfigService().initialize();
    await SubscriptionService().initialize();
    LocalizationService.init();

    try {
      // ── Step 1: Stable hardware device ID ─────────────────────────────────
      final String deviceId = await _deviceService.getDeviceId();
      debugPrint('📱 [AppInitializer] Device ID: $deviceId');

      // ── Step 2: Establish Firebase Auth session FIRST ─────────────────────
      // All Firestore reads/writes require an authenticated caller.
      String authUid;
      if (_authService.currentUser != null) {
        authUid = _authService.currentUser!.uid;
        debugPrint('🔐 [AppInitializer] Reusing existing auth uid: $authUid');
      } else {
        final credential = await _authService.signInAnonymously();
        authUid = credential.user!.uid;
        debugPrint('🔐 [AppInitializer] New anonymous auth uid: $authUid');
      }

      // ── Step 3: Look up device_map (now allowed — auth session active) ────
      final deviceData = await _deviceRepository.getDeviceData(deviceId);

      final String uid; // always == authUid going forward

      if (deviceData != null) {
        // ── RETURN / REINSTALL: migrate credits to the new auth uid ──────────
        final int restoredCredits =
            (deviceData['credits'] as int?) ?? _readInitialCredits();
        debugPrint(
          '♻️  [AppInitializer] Returning device – restoring $restoredCredits credits → uid=$authUid',
        );

        // Create a fresh user doc under the NEW auth uid with restored credits.
        // Uses merge:true so it's idempotent if the doc already exists
        // (e.g. in a loop crash re-run).
        await _userRepository.createUserIfMissing(
          authUid,
          initialCredits: restoredCredits,
        );

        // Point device_map to the new auth uid.
        await _deviceRepository.migrateMapping(
          deviceId: deviceId,
          newUid: authUid,
          credits: restoredCredits,
        );

        uid = authUid;
        debugPrint(
          '✅ [AppInitializer] Restoration complete. uid=$uid, credits=$restoredCredits',
        );
      } else {
        // ── NEW DEVICE: create everything atomically ───────────────────────
        debugPrint('🆕 [AppInitializer] New device → uid=$authUid');
        final int initialCredits = _readInitialCredits();

        final batch = _firestore.batch();
        _deviceRepository.createMapping(
          batch: batch,
          deviceId: deviceId,
          uid: authUid,
          credits: initialCredits,
        );
        await _userRepository.createUserIfMissing(
          authUid,
          batch: batch,
          initialCredits: initialCredits,
        );
        await batch.commit();

        uid = authUid;
        debugPrint(
          '✅ [AppInitializer] New user created. uid=$uid, credits=$initialCredits',
        );
      }

      // ── Step 4: Publish session for the whole app ─────────────────────────
      UserSession.instance.uid = uid;
      UserSession.instance.deviceId = deviceId;
      
      // Sync identity with RevenueCat
      unawaited(SubscriptionService().logIn(uid));

      // ── Step 4.5: Sync FCM Token ──────────────────────────────────────────
      // Now that UID is set, we can link the device token to the Firestore doc.
      unawaited(NotificationService().syncTokenNow());

      // ── Step 5: Pre-fetch global data ──────────────────────────────────────
      await DataService().initialize();

      // ── Step 6: Pre-cache demo images in background ───────────────────────
      unawaited(_precacheDemoImages());

      debugPrint('🏁 [AppInitializer] Done. uid=$uid, deviceId=$deviceId');
      return uid;
    } catch (e, stack) {
      debugPrint('❌ [AppInitializer] FAILED: $e\n$stack');

      // Fallback: salvage whatever Auth session we can.
      try {
        String? fallbackUid = _authService.currentUser?.uid;
        if (fallbackUid == null) {
           final credential = await _authService.signInAnonymously();
           fallbackUid = credential.user?.uid;
        }
        if (fallbackUid != null) UserSession.instance.uid = fallbackUid;
        return fallbackUid;
      } catch (_) {
        return null;
      }
    }
  }

  int _readInitialCredits() {
    return RemoteConfigService().initialCredits;
  }

  /// Pre-caches AI tool demo images from Remote Config JSON
  Future<void> _precacheDemoImages() async {
    try {
      final jsonStr = RemoteConfigService().getString('tool_demos');
      if (jsonStr.isEmpty || jsonStr == '{}' || jsonStr == '[]') return;

      final Map<String, dynamic> configMap = jsonDecode(jsonStr);
      final Set<String> imageUrls = {};

      for (var toolKey in configMap.keys) {
        final toolData = configMap[toolKey];
        if (toolData is Map<String, dynamic>) {
          final String? url = toolData['imageUrl'] ?? toolData['imageurl'];
          if (url != null && url.isNotEmpty) {
            imageUrls.add(url);
          }
        }
      }

      if (imageUrls.isEmpty) return;

      debugPrint('🖼️ [AppInitializer] Pre-caching ${imageUrls.length} demo images...');
      
      final cacheManager = DefaultCacheManager();
      for (final url in imageUrls) {
        // Use a safe async wrapper to prevent one failure from stopping the loop
        () async {
          try {
            await cacheManager.downloadFile(url);
          } catch (e) {
            debugPrint('⚠️ [AppInitializer] Pre-cache failed for $url: $e');
          }
        }();
      }
    } catch (e) {
      debugPrint('⚠️ [AppInitializer] Error during pre-caching setup: $e');
    }
  }
}
