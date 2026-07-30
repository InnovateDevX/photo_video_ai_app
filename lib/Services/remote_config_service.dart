import 'dart:async';
import 'dart:convert';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  FirebaseRemoteConfig get _remoteConfig => FirebaseRemoteConfig.instance;
  bool _isInitialized = false;
  StreamSubscription<RemoteConfigUpdate>? _configUpdateSubscription;

  /// Keys for every Remote Config string we cache locally as a safety net.
  static const List<String> _cacheableStringKeys = [
    'replicate_image_models',
    'replicate_video_models',
    'replicate_cloth_model',
    'replicate_upscale_model',
    'replicate_restore_model',
    'replicate_headshot_model',
    'replicate_sticker_image_model',
    'replicate_sticker_text_model',
    'replicate_remove_bg_model',
    'replicate_blur_bg_model',
    'replicate_background_model',
    'replicate_collage_model',
    'replicate_logo_model',
    'replicate_filter_model',
    'replicate_retouch_model',
    'replicate_filter_styles',
    'tool_demos',
    'trending_data',
    'categories',
    'reels_data',
    'watermark_url',
    'generation_page_image',
    'generation_page_video',
    'paywall_video_url',
    'share_app_url',
    'privacy_policy_url',
    'customer_support_url',
    'faq_url',
    'terms_of_use_url',
    'admob_rewarded_interstitial_ad_unit_id',
    'rc_credits_map',
    'tool_badges',
    'popular_ai_tools',
    'paywall_weekly_features',
    'paywall_monthly_features',
  ];

  /// Prefix used to namespace our SharedPreferences cache entries.
  static const String _prefsPrefix = 'rc_cache:';

  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('🔧 [RemoteConfigService] Initializing...');

    try {
      // 1. Set Defaults
      await _remoteConfig.setDefaults({
        'replicate_auth_token': '',
        'replicate_image_models': '[]',
        'replicate_video_models': '[]',
        'replicate_cloth_model': '{}',
        'replicate_upscale_model': '{}',
        'replicate_restore_model': '{}',
        'replicate_headshot_model': '{}',
        'replicate_sticker_image_model': '{}',
        'replicate_sticker_text_model': '{}',
        'replicate_remove_bg_model': '{}',
        'replicate_blur_bg_model': '{}',
        'replicate_background_model': '{}',
        'replicate_collage_model': '{}',
        'replicate_logo_model': '{}',
        'replicate_filter_model': '{}',
        'replicate_retouch_model': '{}',
        'replicate_filter_styles': '[]',
        'tool_demos': '{}',
        'admob_rewarded_interstitial_ad_unit_id': '',
        'initial_credits': 0,
        'trending_data': '{}',
        'categories': '[]',
        'reels_data': '[]',
        'pro_weekly': 'vidzeon_pro_weekly',
        'pro_yearly': 'vidzeon_pro_yearly',
        'pro_monthly': 'vidzeon_pro_monthly',
        'ultra_weekly': '',
        'ultra_yearly': '',
        'ultra_monthly': '',
        'privacy_policy_url': '',
        'customer_support_url': '',
        'faq_url': '',
        'terms_of_use_url': '',
        'rc_android_key': '',
        'rc_ios_key': '',
        'rc_credits_map': '{}',
        'google_cloud_api_key': '',
        'tool_badges': '{}',
        'nsfw_text_threshold': 0.65,
        'nsfw_image_unsafe_values': '["VERY_LIKELY"]',
        'share_app_url': '',
        'show_ads': false,
        'dark_theme': true,
        'watermark_url': '',
        'paywall_video_url': '',
        'paywall_weekly_features': '[]',
        'paywall_monthly_features': '[]',
        'generation_page_image': '',
        'generation_page_video': '',
        'popular_ai_tools': '',
      });

      // 2. Configure Settings - Force Duration.zero to fetch on every app open
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: Duration.zero,
        ),
      );

      // 3. Force Fetch & Activate from network
      final activated = await _remoteConfig.fetchAndActivate();
      debugPrint(
        '🔧 [RemoteConfigService] Fresh launch fetch successful: $activated',
      );
      debugPrint('   Last fetch status: ${_remoteConfig.lastFetchStatus}');

      // 4. Overwrite local SharedPreferences cache with the new network values
      await _persistStringKeysToCache(_cacheableStringKeys);

      // 5. Setup Real-time updates while active
      _listenForRealtimeUpdates();

      _isInitialized = true;
    } catch (e) {
      // If fetching fails or gets throttled by Firebase, fallback gracefully to cached keys
      debugPrint('⚠️ [RemoteConfigService] Launch fetch failed/throttled: $e');
      debugPrint('   Proceeding with SharedPreferences cache / defaults.');
      _isInitialized = true;
    }
  }

  /// Real-time stream listener for live edits pushed from Firebase Console
  void _listenForRealtimeUpdates() {
    _configUpdateSubscription?.cancel();
    _configUpdateSubscription = _remoteConfig.onConfigUpdated.listen(
      (event) async {
        debugPrint('⚡ [RemoteConfigService] Real-time config update detected!');
        await _remoteConfig.activate();
        await _persistStringKeysToCache(_cacheableStringKeys);
      },
      onError: (error) {
        debugPrint(
          '⚠️ [RemoteConfigService] Real-time update stream error: $error',
        );
      },
    );
  }

  /// Force-fetches the latest Remote Config values from the network.
  Future<bool> refresh() async {
    try {
      final activated = await _remoteConfig.fetchAndActivate();
      debugPrint(
        '🔧 [RemoteConfigService] refresh() activated: $activated | status: ${_remoteConfig.lastFetchStatus}',
      );
      if (activated) {
        await _persistStringKeysToCache(_cacheableStringKeys);
      }
      return activated;
    } catch (e) {
      debugPrint('⚠️ [RemoteConfigService] refresh() failed: $e');
      return false;
    }
  }

  /// Writes each Remote Config string to SharedPreferences
  Future<void> _persistStringKeysToCache(List<String> keys) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final key in keys) {
        final value = _remoteConfig.getString(key);
        if (value.isNotEmpty && value != '[]' && value != '{}') {
          await prefs.setString('$_prefsPrefix$key', value);
        }
      }
      debugPrint(
        '💾 [RemoteConfigService] Updated ${keys.length} keys in SharedPreferences cache.',
      );
    } catch (e) {
      debugPrint('⚠️ [RemoteConfigService] Failed to persist cache: $e');
    }
  }

  Future<String?> _readCachedString(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_prefsPrefix$key');
    } catch (e) {
      debugPrint(
        '⚠️ [RemoteConfigService] Failed to read cache for "$key": $e',
      );
      return null;
    }
  }

  Future<String> _getStringWithCacheFallback(String key) async {
    final live = _remoteConfig.getString(key);
    final isMissing =
        live.isEmpty || live == '[]' || live == '{}' || live == '""';
    if (!isMissing) return live;

    final cached = await _readCachedString(key);
    if (cached != null && cached.isNotEmpty) {
      debugPrint('📦 [RemoteConfigService] Using cached value for "$key".');
      return cached;
    }
    return live;
  }

  // --- Getters ---
  String getString(String key) => _remoteConfig.getString(key);
  int getInt(String key) => _remoteConfig.getInt(key);
  bool getBool(String key) => _remoteConfig.getBool(key);
  double getDouble(String key) => _remoteConfig.getDouble(key);

  Future<String> _async(String key) => _getStringWithCacheFallback(key);

  Future<String> get popularAiToolsAsync => _async('popular_ai_tools');
  String get popularAiTools => getString('popular_ai_tools');
  String get replicateAuthToken => getString('replicate_auth_token');
  String get watermarkUrl => getString('watermark_url');

  Future<String> get imageModelsJsonAsync => _async('replicate_image_models');
  String get imageModelsJson => getString('replicate_image_models');

  Future<String> get videoModelsJsonAsync => _async('replicate_video_models');
  String get videoModelsJson => getString('replicate_video_models');

  Future<String> get clothModelJsonAsync => _async('replicate_cloth_model');
  String get clothModelJson => getString('replicate_cloth_model');

  Future<String> get upscaleModelJsonAsync => _async('replicate_upscale_model');
  String get upscaleModelJson => getString('replicate_upscale_model');

  Future<String> get restoreModelJsonAsync => _async('replicate_restore_model');
  String get restoreModelJson => getString('replicate_restore_model');

  Future<String> get headshotModelJsonAsync =>
      _async('replicate_headshot_model');
  String get headshotModelJson => getString('replicate_headshot_model');

  Future<String> get stickerImageModelJsonAsync =>
      _async('replicate_sticker_image_model');
  String get stickerImageModelJson =>
      getString('replicate_sticker_sticker_image_model');

  Future<String> get stickerTextModelJsonAsync =>
      _async('replicate_sticker_text_model');
  String get stickerTextModelJson => getString('replicate_sticker_text_model');

  Future<String> get removeBgModelJsonAsync =>
      _async('replicate_remove_bg_model');
  String get removeBgModelJson => getString('replicate_remove_bg_model');

  Future<String> get blurBgModelJsonAsync => _async('replicate_blur_bg_model');
  String get blurBgModelJson => getString('replicate_blur_bg_model');

  Future<String> get backgroundModelJsonAsync =>
      _async('replicate_background_model');
  String get backgroundModelJson => getString('replicate_background_model');

  Future<String> get collageModelJsonAsync => _async('replicate_collage_model');
  String get collageModelJson => getString('replicate_collage_model');

  Future<String> get logoModelJsonAsync => _async('replicate_logo_model');
  String get logoModelJson => getString('replicate_logo_model');

  Future<String> get filterModelJsonAsync => _async('replicate_filter_model');
  String get filterModelJson => getString('replicate_filter_model');

  Future<String> get retouchModelJsonAsync => _async('replicate_retouch_model');
  String get retouchModelJson => getString('replicate_retouch_model');

  Future<String> get filterStylesJsonAsync => _async('replicate_filter_styles');
  String get filterStylesJson => getString('replicate_filter_styles');

  String get rewardedAdUnitId =>
      getString('admob_rewarded_interstitial_ad_unit_id');
  int get initialCredits => getInt('initial_credits');
  String get categoriesJson => getString('categories');
  String get toolBadgesJson => getString('tool_badges');
  String get trendingDataJson => getString('trending_data');
  String get reelsJson => getString('reels_data');

  String get proWeekly => getString('pro_weekly');
  String get proMonthly => getString('pro_monthly');

  String get privacyPolicyUrl => getString('privacy_policy_url');
  String get customerSupportUrl => getString('customer_support_url');
  String get faqUrl => getString('faq_url');
  String get termsOfUseUrl => getString('terms_of_use_url');
  String get shareAppUrl => getString('share_app_url');

  String get rcAndroidKey => getString('rc_android_key');
  String get rcIosKey => getString('rc_ios_key');
  String get rcCreditsMapJson => getString('rc_credits_map');

  String get googleCloudApiKey => getString('google_cloud_api_key');

  bool get showAds => getBool('show_ads');
  bool get isDarkThemeDefault => getBool('dark_theme');

  String get paywallVideoUrl => getString('paywall_video_url');

  Future<List<String>> get paywallWeeklyFeatures async =>
      _decodeFeatureList(await _async('paywall_weekly_features'), const []);

  Future<List<String>> get paywallMonthlyFeatures async =>
      _decodeFeatureList(await _async('paywall_monthly_features'), const []);

  List<String> _decodeFeatureList(String raw, List<String> fallback) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final features = decoded
            .whereType<String>()
            .map((feature) => feature.trim())
            .where((feature) => feature.isNotEmpty)
            .toList(growable: false);
        if (features.isNotEmpty) return features;
      }
    } catch (e) {
      debugPrint('⚠️ [RemoteConfigService] Invalid paywall features JSON: $e');
    }
    return List<String>.unmodifiable(fallback);
  }

  String get generationPageImage => getString('generation_page_image');
  String get generationPageVideo => getString('generation_page_video');

  void dispose() {
    _configUpdateSubscription?.cancel();
  }
}
