import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoBanner extends StatefulWidget {
  final String videoUrl;

  const VideoBanner({super.key, required this.videoUrl});

  @override
  State<VideoBanner> createState() => _VideoBannerState();
}

class _VideoBannerState extends State<VideoBanner> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {
          _initialized = true;
        });
        _controller.setLooping(true);
        _controller.setVolume(0.0);
        _controller.addListener(() {
          if (!mounted) return;
          final value = _controller.value;
          if (value.duration > Duration.zero &&
              value.position >=
                  value.duration - const Duration(milliseconds: 50)) {
            _controller.seekTo(Duration.zero);
            _controller.play();
          }
        });
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initialized) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(
          MediaQuery.of(context).size.width * 0.06,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.45,
          width: MediaQuery.of(context).size.width * 1,
          child: VideoPlayer(_controller),
        ),
      );
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }
}
