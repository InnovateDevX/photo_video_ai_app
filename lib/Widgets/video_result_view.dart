import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class VideoResultView extends StatefulWidget {
  final String videoUrl;
  final double borderRadius;

  const VideoResultView({
    super.key,
    required this.videoUrl,
    this.borderRadius = 20.0,
  });

  @override
  State<VideoResultView> createState() => _VideoResultViewState();
}

class _VideoResultViewState extends State<VideoResultView> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void didUpdateWidget(VideoResultView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    final url = widget.videoUrl;

    // Dispose previous controller if it exists
    if (_controller != null) {
      final oldController = _controller!;
      setState(() {
        _isInitialized = false;
        _controller = null;
      });
      await oldController.dispose();
    }

    if (!mounted) return;

    VideoPlayerController controller;
    if (url.startsWith('http')) {
      try {
        // Cache the video file to prevent buffering during playback
        final file = await DefaultCacheManager().getSingleFile(url);
        controller = VideoPlayerController.file(file);
      } catch (e) {
        debugPrint('Cache manager failed: $e');
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
      }
    } else {
      controller = VideoPlayerController.file(File(url));
    }

    try {
      await controller.initialize();
      if (mounted && url == widget.videoUrl) {
        setState(() {
          _controller = controller;
          _isInitialized = true;
        });
        controller.setLooping(true);
        controller.play();

        // Listen to playback position for the UI updates (play/pause toggle, progress)
        controller.addListener(() {
          if (mounted) setState(() {});
        });
      } else {
        await controller.dispose();
      }
    } catch (e) {
      debugPrint('❌ [VideoResultView] Initialization failed: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration position) {
    final minutes = position.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = position.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.01),
            Text(
              "Preparing video...",
              style: TextStyle(
                color: Colors.white70,
                fontSize: MediaQuery.of(context).size.height * 0.015,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: GestureDetector(
          onTap: () {
            if (_controller!.value.isPlaying) {
              _controller!.pause();
            } else {
              _controller!.play();
            }
          },
          child: AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_controller!),
                if (!_controller!.value.isPlaying)
                  Container(
                    padding: EdgeInsets.all(
                      MediaQuery.of(context).size.width * 0.04,
                    ),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 48,
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.black87, Colors.transparent],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                    padding: const EdgeInsets.only(
                      top: 24,
                      bottom: 8,
                      left: 8,
                      right: 8,
                    ),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            if (_controller!.value.isPlaying) {
                              _controller!.pause();
                            } else {
                              _controller!.play();
                            }
                          },
                          child: Icon(
                            _controller!.value.isPlaying
                                ? Icons.pause
                                : Icons.play_arrow,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.02,
                        ),
                        Expanded(
                          child: VideoProgressIndicator(
                            _controller!,
                            allowScrubbing: true,
                            padding: EdgeInsets.symmetric(
                              vertical:
                                  MediaQuery.of(context).size.height * 0.01,
                            ),
                            colors: const VideoProgressColors(
                              playedColor: Colors.orange,
                              bufferedColor: Colors.white38,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.02,
                        ),
                        Text(
                          "${_formatDuration(_controller!.value.position)} / ${_formatDuration(_controller!.value.duration)}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
