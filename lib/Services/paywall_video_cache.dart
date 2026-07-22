import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

import 'remote_config_service.dart';

/// Singleton that pre-loads the paywall hero video from Remote Config.
///
/// Call [preload] during the splash screen (fire-and-forget with `unawaited`).
/// By the time the paywall is opened, [controller] will be initialised and
/// ready to play — resulting in seamless, instant playback.
class PaywallVideoCache {
  static final PaywallVideoCache _instance = PaywallVideoCache._internal();
  factory PaywallVideoCache() => _instance;
  PaywallVideoCache._internal();

  VideoPlayerController? _controller;
  bool _isReady = false;

  /// The pre-initialised controller. Will be `null` if preloading is still
  /// in progress or if no URL is configured.
  VideoPlayerController? get controller => _isReady ? _controller : null;

  /// Whether the controller is initialised and ready to play.
  bool get isReady => _isReady;

  Future<void>? _preloadFuture;

  /// Pre-downloads the video and initialises the [VideoPlayerController].
  ///
  /// Safe to call multiple times — subsequent calls will return the existing
  /// preloading Future or complete immediately if already ready.
  Future<void> preload() {
    if (_isReady) return Future.value();
    _preloadFuture ??= _doPreload();
    return _preloadFuture!;
  }

  Future<void> _doPreload() async {
    try {
      final url = RemoteConfigService().paywallVideoUrl;
      if (url.isEmpty) {
        debugPrint('🎬 [PaywallVideoCache] No URL configured — skipping preload');
        return;
      }

      debugPrint('🎬 [PaywallVideoCache] Preloading video: $url');

      // Download (or retrieve from disk cache) via flutter_cache_manager
      final File cachedFile = await DefaultCacheManager().getSingleFile(url);

      debugPrint('🎬 [PaywallVideoCache] Cached file: ${cachedFile.path}');

      // Dispose any previous controller before creating a new one
      await _disposeController();

      _controller = VideoPlayerController.file(
        cachedFile,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await _controller!.initialize();
      _controller!.setLooping(true);
      _controller!.setVolume(0); // muted
      _isReady = true;

      debugPrint('🎬 [PaywallVideoCache] Controller ready ✅');
    } catch (e) {
      debugPrint('🎬 [PaywallVideoCache] Preload failed (non-fatal): $e');
      _isReady = false;
      _preloadFuture = null; // Allow retrying on failure
    }
  }

  /// Disposes the cached controller and resets state.
  /// Call this when the app signs out or you need a fresh controller.
  Future<void> reset() async {
    await _disposeController();
    _isReady = false;
    _preloadFuture = null;
    debugPrint('🎬 [PaywallVideoCache] Reset');
  }

  Future<void> _disposeController() async {
    try {
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;
  }
}
