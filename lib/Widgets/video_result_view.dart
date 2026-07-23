import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class VideoResultView extends StatefulWidget {
  final String videoUrl;
  final double borderRadius;
  final VoidCallback? onTap;

  const VideoResultView({
    super.key,
    required this.videoUrl,
    this.borderRadius = 20.0,
    this.onTap,
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

    VideoPlayerController? controller;
    if (url.startsWith('http')) {
      File? cachedFile;
      try {
        final fileInfo = await DefaultCacheManager().getFileFromCache(url);
        if (fileInfo != null && fileInfo.file.existsSync() && fileInfo.file.lengthSync() > 1024) {
          debugPrint("📦 [VideoResultView] Playing from CACHE: $url");
          cachedFile = fileInfo.file;
        } else if (fileInfo != null) {
          debugPrint("⚠️ [VideoResultView] Corrupted cache file detected (<1KB), removing...");
          await DefaultCacheManager().removeFile(url);
        }
      } catch (e) {
        debugPrint('Cache manager check failed: $e');
      }

      if (cachedFile != null) {
        try {
          controller = VideoPlayerController.file(cachedFile);
          await controller.initialize().timeout(const Duration(seconds: 4));
          if (controller.value.hasError) {
            throw Exception("Cache player has error");
          }
        } catch (e) {
          debugPrint("⚠️ [VideoResultView] Cache init failed: $e, falling back to network...");
          await DefaultCacheManager().removeFile(url);
          controller?.dispose();
          controller = null;
        }
      }

      if (controller == null) {
        debugPrint(
          "🌐 [VideoResultView] Playing from network & caching in background: $url",
        );
        DefaultCacheManager().downloadFile(url).then((_) {}).catchError((e) {
          debugPrint("❌ [VideoResultView] Background cache download failed: $e");
        });
        controller = VideoPlayerController.networkUrl(Uri.parse(url));
        await controller.initialize().timeout(const Duration(seconds: 25));
      }
    } else {
      controller = VideoPlayerController.file(File(url));
      await controller.initialize();
    }

    try {
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
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
        ),
      );
    }

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: GestureDetector(
          onTap: () {
            if (widget.onTap != null) {
              widget.onTap!();
            } else {
              if (_controller!.value.isPlaying) {
                _controller!.pause();
              } else {
                _controller!.play();
              }
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
