import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:trail_ai_app/Core/colors.dart';

class ReelVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final Widget? placeholder;
  final bool seamlessLoop;
  const ReelVideoPlayer({
    super.key, 
    required this.videoUrl, 
    this.placeholder,
    this.seamlessLoop = false,
  });

  @override
  State<ReelVideoPlayer> createState() => _ReelVideoPlayerState();
}

class _ReelVideoPlayerState extends State<ReelVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isLooping = false;
  bool _isBuffering = false;

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
    if (widget.seamlessLoop && value.isInitialized && value.duration > Duration.zero) {
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
    try {
      final uri = Uri.parse(widget.videoUrl);
      _controller =
          VideoPlayerController.networkUrl(
              uri,
              videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
            )
            ..initialize()
                .then((_) {
                  // Ensure the first frame is shown after the video is initialized
                  if (mounted) {
                    setState(() {
                      _isInitialized = true;
                    });
                    
                    // Disable native looping if we are doing manual seamless looping
                    // to avoid fighting between the two mechanisms.
                    _controller!.setLooping(!widget.seamlessLoop);
                    _controller!.setVolume(0.0);
                    _controller!.addListener(_videoListener);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) _controller!.play();
                    });
                  }
                })
                .catchError((e) {
                  debugPrint("Video play error: $e");
                });
    } catch (e) {
      debugPrint("Invalid Video URL parsing error: $e");
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
    if (!_isInitialized) {
      return Container(
        color: AppColors.backgroundColor(
          Theme.of(context).brightness == Brightness.dark,
        ),
        child: widget.placeholder ?? const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Stack(
        fit: StackFit.expand,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          ),
          if (_isBuffering)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          if (!_isPlaying && !_isBuffering)
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
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
            ),
        ],
      ),
    );
  }
}
