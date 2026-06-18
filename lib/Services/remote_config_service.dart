import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final FirebaseRemoteConfig _remoteConfig = FirebaseRemoteConfig.instance;
  bool _isInitialized = false;

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
        'initial_credits': 100,
        'trending_data': '{}',
        'categories': '[]',
        'reels_data': '[]',
        'pro_weekly': '',
        'pro_yearly': '',
        'pro_monthly': '',
        'ultra_weekly': '',
        'ultra_yearly': '',
        'ultra_monthly': '',
        'privacy_policy_url': '',
        'customer_support_url': '',
        'faq_url': '',
        'terms_of_use_url': '',
        'rc_android_key': '', // Add in Firebase Remote Config
        'rc_ios_key': '',
        'rc_credits_map': '{}',
        'google_cloud_api_key': '', // Add in Firebase Remote Config
        'tool_badges': '{}',
      });

      // 2. Configure Settings
      await _remoteConfig.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: kDebugMode
              ? Duration.zero
              : const Duration(hours: 1),
        ),
      );

      // 3. Single Fetch & Activate
      final activated = await _remoteConfig.fetchAndActivate();
      debugPrint(
        '🔧 [RemoteConfigService] fetchAndActivate() success: $activated',
      );
      debugPrint('   Last fetch status: ${_remoteConfig.lastFetchStatus}');

      _isInitialized = true;
    } catch (e) {
      // If initialization fails (e.g. throttling or network), we still allow the app to proceed
      // with defaults or previously cached values.
      debugPrint('⚠️ [RemoteConfigService] Initialization failed: $e');
      debugPrint('   Proceeding with cached/default values.');
      _isInitialized =
          true; // Still mark as initialized to prevent redundant fetch attempts
    }
  }

  // --- Getters ---

  String getString(String key) => _remoteConfig.getString(key);
  int getInt(String key) => _remoteConfig.getInt(key);
  bool getBool(String key) => _remoteConfig.getBool(key);
  double getDouble(String key) => _remoteConfig.getDouble(key);

  // Type-safe Convenience Getters
  String get replicateAuthToken => getString('replicate_auth_token');
  String get imageModelsJson => getString('replicate_image_models');
  String get videoModelsJson => getString('replicate_video_models');
  String get clothModelJson => getString('replicate_cloth_model');
  String get upscaleModelJson => getString('replicate_upscale_model');
  String get restoreModelJson => getString('replicate_restore_model');
  String get headshotModelJson => getString('replicate_headshot_model');
  String get stickerImageModelJson =>
      getString('replicate_sticker_image_model');
  String get stickerTextModelJson => getString('replicate_sticker_text_model');
  String get removeBgModelJson => getString('replicate_remove_bg_model');
  String get blurBgModelJson => getString('replicate_blur_bg_model');
  String get backgroundModelJson => getString('replicate_background_model');
  String get collageModelJson => getString('replicate_collage_model');
  String get logoModelJson => getString('replicate_logo_model');
  String get filterModelJson => getString('replicate_filter_model');
  String get retouchModelJson => getString('replicate_retouch_model');
  String get filterStylesJson => getString('replicate_filter_styles');
  String get rewardedAdUnitId =>
      getString('admob_rewarded_interstitial_ad_unit_id');
  int get initialCredits => getInt('initial_credits');
  String get categoriesJson => getString('categories');
  String get toolBadgesJson => getString('tool_badges');
  String get trendingDataJson => getString('trending_data');
  String get reelsJson => getString('reels_data');

  // Pricing
  String get proWeekly => getString('pro_weekly');
  String get proYearly => getString('pro_yearly');
  String get proMonthly => getString('pro_monthly');
  String get ultraWeekly => getString('ultra_weekly');
  String get ultraYearly => getString('ultra_yearly');
  String get ultraMonthly => getString('ultra_monthly');

  String get privacyPolicyUrl => getString('privacy_policy_url');
  String get customerSupportUrl => getString('customer_support_url');
  String get faqUrl => getString('faq_url');
  String get termsOfUseUrl => getString('terms_of_use_url');

  String get rcAndroidKey => getString('rc_android_key');
  String get rcIosKey => getString('rc_ios_key');
  String get rcCreditsMapJson => getString('rc_credits_map');

  String get googleCloudApiKey => getString('google_cloud_api_key');
}
