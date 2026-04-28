import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';

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
  String? _initializedUrl;

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
      controller = VideoPlayerController.networkUrl(Uri.parse(url));
    } else {
      controller = VideoPlayerController.file(File(url));
    }

    try {
      await controller.initialize();
      if (mounted && url == widget.videoUrl) {
        setState(() {
          _controller = controller;
          _isInitialized = true;
          _initializedUrl = url;
        });
        controller.setLooping(true);
        controller.play();
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

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
        ),
      );
    }

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: AspectRatio(
          aspectRatio: _controller!.value.aspectRatio,
          child: VideoPlayer(_controller!),
        ),
      ),
    );
  }
}
