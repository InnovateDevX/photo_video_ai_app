import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:trail_ai_app/Services/remote_config_service.dart';

/// Service for managing Google AdMob rewarded interstitial ads
/// Ad unit IDs are fetched from Firebase Remote Config
class AdService {
  // Singleton pattern
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  RewardedInterstitialAd? _rewardedInterstitialAd;
  bool _isAdLoaded = false;
  String _rewardedAdUnitId = '';

  /// Initialize the ad service and fetch ad unit IDs from Remote Config
  Future<void> initialize() async {
    debugPrint('🚀 [AdService] Initializing AdService...');
    await _fetchAdUnitIdsFromRemoteConfig();
    await loadRewardedAd();
  }

  /// Fetch ad unit IDs from Firebase Remote Config
  Future<void> _fetchAdUnitIdsFromRemoteConfig() async {
    debugPrint('🔧 [AdService] ========================================');
    debugPrint('🔧 [AdService] FETCHING AD CONFIG FROM REMOTE CONFIG');

    try {
      final config = RemoteConfigService();
      
      // Ensure RemoteConfigService is initialized
      await config.initialize();

      // Get the ad unit ID from Remote Config
      _rewardedAdUnitId = config.rewardedAdUnitId;
      
      debugPrint(
        '🔧 [AdService] Retrieved ad unit ID length: ${_rewardedAdUnitId.length}',
      );

      // STRICT MODE: No fallback to test IDs
      if (_rewardedAdUnitId.isEmpty) {
        debugPrint('❌ [AdService] Remote Config ad unit ID is EMPTY');
        debugPrint('❌ [AdService] Will NOT load ads - configuration required');
      } else {
        debugPrint('✅ [AdService] Using Remote Config ad unit ID');
      }

      debugPrint(
        '🔧 [AdService] Final ad unit ID: ${_rewardedAdUnitId.isNotEmpty ? "${_rewardedAdUnitId.substring(0, 10)}..." : "EMPTY"}',
      );
      debugPrint('🔧 [AdService] ========================================');
    } catch (e, stackTrace) {
      debugPrint('❌ [AdService] Error fetching Remote Config: $e');
      debugPrint('❌ [AdService] Stack trace: $stackTrace');
      debugPrint('❌ [AdService] Ads disabled due to configuration error');
      _rewardedAdUnitId = ''; // Ensure explicitly empty on error
    }
  }

  /// Load a rewarded interstitial ad
  Future<void> loadRewardedAd() async {
    // Stop if no ad unit ID is configured
    if (_rewardedAdUnitId.isEmpty) {
      debugPrint(
        '⚠️ [AdService] Skipping ad load: No ad unit ID configured in Remote Config',
      );
      _rewardedInterstitialAd = null;
      _isAdLoaded = false;
      return;
    }

    debugPrint('📱 [AdService] ============ LOADING AD ============');
    debugPrint(
      '📱 [AdService] Ad unit ID: ${_rewardedAdUnitId.substring(0, 30)}...',
    );
    debugPrint('📱 [AdService] Current load status: $_isAdLoaded');
    debugPrint(
      '📱 [AdService] Current ad instance: ${_rewardedInterstitialAd != null ? "EXISTS" : "NULL"}',
    );

    final startTime = DateTime.now();

    try {
      await RewardedInterstitialAd.load(
        adUnitId: _rewardedAdUnitId,
        request: const AdRequest(),
        rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            final duration = DateTime.now().difference(startTime);
            debugPrint(
              '✅ [AdService] ========================================',
            );
            debugPrint('✅ [AdService] REWARDED INTERSTITIAL AD LOADED!');
            debugPrint('✅ [AdService] Load time: ${duration.inMilliseconds}ms');
            debugPrint('✅ [AdService] Ad object: ${ad.toString()}');
            debugPrint(
              '✅ [AdService] ========================================',
            );
            _rewardedInterstitialAd = ad;
            _isAdLoaded = true;
          },
          onAdFailedToLoad: (error) {
            final duration = DateTime.now().difference(startTime);
            debugPrint(
              '❌ [AdService] ========================================',
            );
            debugPrint('❌ [AdService] FAILED TO LOAD REWARDED INTERSTITIAL AD');
            debugPrint(
              '❌ [AdService] Time until failure: ${duration.inMilliseconds}ms',
            );
            debugPrint('❌ [AdService] Error code: ${error.code}');
            debugPrint('❌ [AdService] Error domain: ${error.domain}');
            debugPrint('❌ [AdService] Error message: ${error.message}');
            debugPrint('❌ [AdService] Response info: ${error.responseInfo}');
            debugPrint(
              '❌ [AdService] ========================================',
            );
            _rewardedInterstitialAd = null;
            _isAdLoaded = false;
          },
        ),
      );
      debugPrint('📱 [AdService] Ad.load() method completed');
    } catch (e, stackTrace) {
      debugPrint('❌ [AdService] Exception during ad load: $e');
      debugPrint('❌ [AdService] Stack trace: $stackTrace');
      _rewardedInterstitialAd = null;
      _isAdLoaded = false;
    }
  }

  /// Show the rewarded interstitial ad
  /// Returns "true" if reward earned, "false" if failed/cancelled
  /// Returns "null" if ads are not configured (should show specific dialog)
  Future<bool?> showRewardedAd() async {
    debugPrint('🔍 [AdService] ========================================');
    debugPrint('🔍 [AdService] SHOW REWARDED AD CALLED');
    debugPrint(
      '🔍 [AdService] Configured ID: ${_rewardedAdUnitId.isNotEmpty ? "YES" : "NO"}',
    );

    // Check if configured first
    if (_rewardedAdUnitId.isEmpty) {
      debugPrint('❌ [AdService] Ad unit ID missing - cannot show ad');
      return null; // Signals "Not Configured" state
    }

    debugPrint('🔍 [AdService] Is ad loaded: $_isAdLoaded');
    debugPrint(
      '🔍 [AdService] Ad instance exists: ${_rewardedInterstitialAd != null}',
    );
    debugPrint('🔍 [AdService] ========================================');

    if (!_isAdLoaded || _rewardedInterstitialAd == null) {
      debugPrint('⚠️ [AdService] No ad loaded, attempting to load now...');
      debugPrint('⚠️ [AdService] Current time: ${DateTime.now()}');

      await loadRewardedAd();

      // Wait up to 15 seconds for the ad to load with progress updates
      debugPrint('⏳ [AdService] Waiting for ad to load (up to 15 seconds)...');
      for (int i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 500));

        // Log progress every second
        if (i % 2 == 0) {
          debugPrint(
            '⏳ [AdService] Waiting... ${(i + 1) * 0.5}s / 15s - Loaded: $_isAdLoaded',
          );
        }

        if (_isAdLoaded && _rewardedInterstitialAd != null) {
          debugPrint(
            '✅ [AdService] Ad loaded successfully after ${(i + 1) * 0.5} seconds!',
          );
          break;
        }
      }

      if (!_isAdLoaded || _rewardedInterstitialAd == null) {
        debugPrint('❌ [AdService] ========================================');
        debugPrint('❌ [AdService] AD STILL NOT LOADED AFTER 15 SECONDS');
        debugPrint('❌ [AdService] Final status - isLoaded: $_isAdLoaded');
        debugPrint(
          '❌ [AdService] Final status - ad exists: ${_rewardedInterstitialAd != null}',
        );
        debugPrint('❌ [AdService] Ad unit ID used: $_rewardedAdUnitId');
        debugPrint('❌ [AdService] ========================================');
        return false; // Signals "Failed to Load" state
      }
    }

    // Track if user earned the reward
    bool rewardEarned = false;

    // Completer that resolves when ad is dismissed
    final completer = Completer<bool>();

    // Set up callbacks BEFORE showing the ad
    _rewardedInterstitialAd!
        .fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('📺 [AdService] Ad showed full screen content');
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('📱 [AdService] Ad dismissed, reward earned: $rewardEarned');
        ad.dispose();
        _rewardedInterstitialAd = null;
        _isAdLoaded = false;
        // Complete with reward status when ad is dismissed
        if (!completer.isCompleted) {
          completer.complete(rewardEarned);
        }
        // Preload next ad
        loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('❌ [AdService] Ad failed to show: ${error.message}');
        ad.dispose();
        _rewardedInterstitialAd = null;
        _isAdLoaded = false;
        if (!completer.isCompleted) {
          completer.complete(false);
        }
      },
      onAdImpression: (ad) {
        debugPrint('👁️ [AdService] Ad impression recorded');
      },
    );

    debugPrint('🎬 [AdService] Showing rewarded interstitial ad now...');

    // Show the ad
    _rewardedInterstitialAd!.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint(
          '🎉 [AdService] User earned reward: ${reward.amount} ${reward.type}',
        );
        rewardEarned = true;
        // Don't complete here - wait for ad dismissal
      },
    );

    // Wait for the ad to be dismissed or timeout after 120 seconds
    try {
      return await completer.future.timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          debugPrint('⚠️ [AdService] Ad timeout');
          return rewardEarned;
        },
      );
    } catch (e) {
      debugPrint('❌ [AdService] Error showing ad: $e');
      return false;
    }
  }

  /// Check if an ad is ready to show
  bool get isAdReady => _isAdLoaded && _rewardedInterstitialAd != null;

  /// Dispose the ad service
  void dispose() {
    _rewardedInterstitialAd?.dispose();
    _rewardedInterstitialAd = null;
  }
}
