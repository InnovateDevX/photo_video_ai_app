import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:io';
import 'dart:async';
import 'package:visibility_detector/visibility_detector.dart';

class ReelVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final Widget? placeholder;
  final bool seamlessLoop;
  final bool enablePlayPauseGesture;
  final bool showOverlayControls;
  final BorderRadiusGeometry? borderRadius;
  final bool mute;
  final BoxFit fit;
  final AlignmentGeometry alignment;

  const ReelVideoPlayer({
    super.key,
    required this.videoUrl,
    this.placeholder,
    this.seamlessLoop = false,
    this.enablePlayPauseGesture = true,
    this.showOverlayControls = true,
    this.borderRadius,
    this.mute = false,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
  });

  @override
  State<ReelVideoPlayer> createState() => _ReelVideoPlayerState();
}

class _ReelVideoPlayerState extends State<ReelVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  bool _isPlaying = false;
  bool _isLooping = false;
  bool _isBuffering = false;
  bool _isVisible = false;

  void _videoListener() {
    if (!mounted || _controller == null) return;

    final value = _controller!.value;

    // Sync play state to UI without spamming builds
    if (value.isPlaying != _isPlaying || value.isBuffering != _isBuffering) {
      setState(() {
        _isPlaying = value.isPlaying;
        _isBuffering = value.isBuffering;
      });
    }

    // Seamless loop logic: restart slightly before the end to avoid pause
    if (widget.seamlessLoop &&
        value.isInitialized &&
        value.duration > Duration.zero) {
      // 40ms buffer (~1-2 frames) ensures we play till the end without hitting native pause
      if (value.position >= value.duration - const Duration(milliseconds: 40)) {
        if (!_isLooping) {
          _isLooping = true;
          _controller!.seekTo(Duration.zero).then((_) {
            _isLooping = false;
          });
          _controller!.play();
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      File? videoFile;
      try {
        final fileInfo = await DefaultCacheManager().getFileFromCache(widget.videoUrl);
        if (fileInfo != null && fileInfo.file.existsSync() && fileInfo.file.lengthSync() > 1024) {
          debugPrint("📦 [VideoPlayer] Playing from CACHE: ${widget.videoUrl}");
          videoFile = fileInfo.file;
        } else if (fileInfo != null) {
          debugPrint("⚠️ [VideoPlayer] Corrupted cache file detected (<1KB), removing...");
          await DefaultCacheManager().removeFile(widget.videoUrl);
        }
      } catch (e) {
        debugPrint("⚠️ [VideoPlayer] Cache check error: $e");
      }

      if (videoFile == null) {
        debugPrint(
          "🌐 [VideoPlayer] Cache miss, playing from network & downloading to cache in background: ${widget.videoUrl}",
        );
        // Trigger background cache download without awaiting it, so we don't block playback!
        DefaultCacheManager().downloadFile(widget.videoUrl).catchError((e) {
          debugPrint("❌ [VideoPlayer] Background cache download failed: $e");
          return null;
        });
      }

      if (!mounted) return;

      // 2. Try initializing with cache file, fallback to network if it fails or times out
      bool initialized = false;
      if (videoFile != null) {
        try {
          _controller = VideoPlayerController.file(
            videoFile,
            videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
          );
          await _controller!.initialize().timeout(const Duration(seconds: 4));
          if (_controller!.value.hasError) {
            throw Exception("Controller initialization reported error: ${_controller!.value.errorDescription}");
          }
          initialized = true;
        } catch (e) {
          debugPrint("⚠️ [VideoPlayer] Cache init failed or timed out: $e. Falling back to network...");
          try {
            await DefaultCacheManager().removeFile(widget.videoUrl);
          } catch (_) {}
          _controller?.dispose();
          _controller = null;
        }
      }

      if (!initialized) {
        if (!mounted) return;
        _controller = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl),
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        await _controller!.initialize().timeout(const Duration(seconds: 25));
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });

        _controller!.setLooping(!widget.seamlessLoop);
        _controller!.setVolume(widget.mute ? 0.0 : 1.0);
        _controller!.addListener(_videoListener);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _isVisible) _controller!.play();
        });
      }
    } catch (e) {
      debugPrint("❌ [VideoPlayer] Initialization error: $e");
      if (mounted) {
        setState(() => _hasError = true);
      }
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;
    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    // On error, show the placeholder (shimmer) or just shrink away cleanly
    if (_hasError) {
      return SizedBox.expand(
        child: widget.placeholder ?? const SizedBox.expand(),
      );
    }

    if (!_isInitialized) {
      return SizedBox.expand(
        child: widget.placeholder ??
            const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    final videoWidget = LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth == double.infinity
            ? null
            : constraints.maxWidth;
        final h = constraints.maxHeight == double.infinity
            ? null
            : constraints.maxHeight;

        Widget content = FittedBox(
          fit: widget.fit,
          alignment: widget.alignment,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
            child: VideoPlayer(_controller!),
          ),
        );

        if (w != null && h != null) {
          content = SizedBox(width: w, height: h, child: content);
        }

        return Stack(
          alignment: Alignment.center,
          children: [
            content,
            if (widget.showOverlayControls && _isBuffering)
              const CircularProgressIndicator(color: Colors.white),
            if (widget.showOverlayControls && !_isPlaying && !_isBuffering)
              Container(
                padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
                decoration: const BoxDecoration(
                  color: Colors.black45,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 64,
                  color: Colors.white,
                ),
              ),
          ],
        );
      },
    );

    Widget finalWidget = videoWidget;
    if (widget.enablePlayPauseGesture) {
      finalWidget = GestureDetector(
        onTap: _togglePlayPause,
        child: videoWidget,
      );
    } else {
      // Use IgnorePointer instead of AbsorbPointer to allow gestures to pass through
      // This is important for PageView swipe gestures in ReelsPage
      finalWidget = IgnorePointer(child: videoWidget);
    }

    if (widget.borderRadius != null) {
      finalWidget = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: finalWidget,
      );
    }

    return VisibilityDetector(
      key: Key(widget.videoUrl),
      onVisibilityChanged: (info) {
        if (!mounted) return;
        final isVisible =
            info.visibleFraction > 0.3; // Play if at least 30% visible
        if (isVisible != _isVisible) {
          _isVisible = isVisible;
          if (_isInitialized && _controller != null) {
            if (_isVisible) {
              _controller!.play();
            } else {
              _controller!.pause();
            }
          }
        }
      },
      child: finalWidget,
    );
  }
}
