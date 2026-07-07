import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trail_ai_app/Core/routes.dart';
import 'package:video_player/video_player.dart';

// --- Data Models ---

class VideoTheme {
  final String title;
  final String thumbnailAsset;
  final String videoAsset;

  const VideoTheme({
    required this.title,
    required this.thumbnailAsset,
    required this.videoAsset,
  });
}

const List<VideoTheme> kVideoThemes = [
  VideoTheme(
    title: 'Football Fans',
    thumbnailAsset: 'assets/onboarding/frame (1).jpg',
    videoAsset: 'assets/videos/video_3.mp4',
  ),
  VideoTheme(
    title: 'Paris Tour',
    thumbnailAsset: 'assets/onboarding/frame (2).jpg',
    videoAsset: 'assets/videos/video_5.mp4',
  ),
  VideoTheme(
    title: 'Football card',
    thumbnailAsset: 'assets/onboarding/frame (3).jpg',
    videoAsset: 'assets/videos/video_6.mp4',
  ),
  VideoTheme(
    title: 'K-Pop',
    thumbnailAsset: 'assets/onboarding/frame (4).jpg',
    videoAsset: 'assets/videos/video_9.mp4',
  ),
  VideoTheme(
    title: 'Popping',
    thumbnailAsset: 'assets/onboarding/frame (5).jpg',
    videoAsset: 'assets/videos/video_4.mp4',
  ),
];

// --- Custom Hexagon ---

Path _getHexagonPath(Size size) {
  final path = Path();
  final width = size.width;
  final height = size.height;

  // Create a regular hexagon
  final centerX = width / 2;

  path.moveTo(centerX, 0); // Top
  path.lineTo(width, height * 0.25); // Top Right
  path.lineTo(width, height * 0.75); // Bottom Right
  path.lineTo(centerX, height); // Bottom
  path.lineTo(0, height * 0.75); // Bottom Left
  path.lineTo(0, height * 0.25); // Top Left
  path.close();

  return path;
}

class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return _getHexagonPath(size);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class GlowingHexagonBorder extends CustomPainter {
  final bool isSelected;
  GlowingHexagonBorder({required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    if (!isSelected) return;

    final path = _getHexagonPath(size);

    // Glowing outer shadow
    final glowPaint = Paint()
      ..color = const Color(0xFFFFB74D).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // Sharp inner border
    final borderPaint = Paint()
      ..color = const Color(0xFFFFCC80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant GlowingHexagonBorder oldDelegate) {
    return oldDelegate.isSelected != isSelected;
  }
}
// --- Main Onboarding Page ---

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  static Future<bool> hasCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('onboarding_done') ?? false;
  }

  static Future<void> markCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
  }

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _totalPages = 3;

  // Video State
  VideoPlayerController? _videoController;
  int _selectedVideoIndex = 0;
  bool _isVideoInitialized = false;

  // Timers
  Timer? _videoCycleTimer;
  Timer? _pageAdvanceTimer;

  @override
  void initState() {
    super.initState();
    _initVideo(kVideoThemes[_selectedVideoIndex].videoAsset);
    _startVideoCycleTimer();
    _startPageTimer(15); // Wait 15 seconds on the first page
  }

  void _startVideoCycleTimer() {
    _videoCycleTimer?.cancel();
    _videoCycleTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_currentPage == 0) {
        final nextIndex = (_selectedVideoIndex + 1) % kVideoThemes.length;
        _onVideoSelected(nextIndex);
      }
    });
  }

  void _startPageTimer(int seconds) {
    _pageAdvanceTimer?.cancel();
    _pageAdvanceTimer = Timer(Duration(seconds: seconds), () {
      _nextPage();
    });
  }

  Future<void> _initVideo(String path) async {
    final oldController = _videoController;

    // We use asset if available, but for graceful fallback if asset doesn't exist during dev
    // we wrap it. You should ensure the assets exist.
    final controller = VideoPlayerController.asset(path);

    try {
      await controller.initialize();
      controller.setLooping(true);
      controller.play();
      setState(() {
        _videoController = controller;
        _isVideoInitialized = true;
      });
    } catch (e) {
      debugPrint("Video initialization failed for $path: $e");
      setState(() {
        _videoController = controller;
        _isVideoInitialized = false;
      });
    }

    if (oldController != null) {
      oldController.dispose();
    }
  }

  void _onVideoSelected(int index) {
    if (_selectedVideoIndex == index) return;
    setState(() {
      _selectedVideoIndex = index;
      _isVideoInitialized = false;
    });
    _initVideo(kVideoThemes[index].videoAsset);
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
    if (index == 1) {
      _startPageTimer(5); // 5 seconds on Rate App
    } else if (index == 2) {
      _startPageTimer(5); // 5 seconds on Trial
    }
  }

  Future<void> _finishOnboarding() async {
    await OnboardingPage.markCompleted();
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  @override
  void dispose() {
    _videoCycleTimer?.cancel();
    _pageAdvanceTimer?.cancel();
    _pageController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Force using timers
                onPageChanged: _onPageChanged,
                children: [
                  _buildVideoThemePage(w, h),
                  _buildRateAppPage(w, h),
                  _buildTrialPage(w, h),
                ],
              ),
            ),
            _buildBottomControls(w, h),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControls(double w, double h) {
    if (_currentPage == 0) return const SizedBox.shrink();

    final isLastPage = _currentPage == _totalPages - 1;

    return Container(
      padding: EdgeInsets.fromLTRB(w * 0.06, h * 0.01, w * 0.06, h * 0.01),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Action Button
          SizedBox(
            width: w * 0.8,
            height: 56,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLastPage ? 'Get Started' : 'Next',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildVideoThemePage(double w, double h) {
    return Column(
      children: [
        const SizedBox(height: 20),

        // Top Video Area
        Expanded(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: w * 0.04),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF161616),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white10),
            ),
            clipBehavior: Clip.hardEdge,
            child: _isVideoInitialized && _videoController != null
                ? SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController!.value.size.width,
                        height: _videoController!.value.size.height,
                        child: VideoPlayer(_videoController!),
                      ),
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.video_library,
                          color: Colors.white24,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Add video at\n${kVideoThemes[_selectedVideoIndex].videoAsset}",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 20),

        // Thumbnail Row
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: w * 0.04),
            itemCount: kVideoThemes.length,
            itemBuilder: (context, index) {
              final theme = kVideoThemes[index];
              final isSelected = index == _selectedVideoIndex;

              return GestureDetector(
                onTap: () => _onVideoSelected(index),
                child: Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Hexagon Thumbnail
                      Container(
                        width: 76, // 64 inner + padding
                        height: 86, // 74 inner + padding
                        padding: const EdgeInsets.all(
                          6,
                        ), // Margin for outer glow to bleed into
                        child: CustomPaint(
                          painter: GlowingHexagonBorder(isSelected: isSelected),
                          child: ClipPath(
                            clipper: HexagonClipper(),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(
                                  color: const Color(0xFF2A2A2A),
                                  child: Image.asset(
                                    theme.thumbnailAsset,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, error, stackTrace) =>
                                        const Center(
                                          child: Icon(
                                            Icons.image,
                                            size: 20,
                                            color: Colors.white24,
                                          ),
                                        ),
                                  ),
                                ),
                                Container(
                                  color: Colors.black26,
                                  child: const Center(
                                    child: Icon(
                                      Icons.play_arrow,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // Text Area (Moved below thumbnails)
        Text(
          "SELECT YOUR VIDEO THEME",
          style: TextStyle(
            color: Colors.white,
            fontSize: w * 0.055,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: w * 0.1),
          child: Text(
            "Transform your photos with top trending choreographies and visual effects in seconds.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white60,
              fontSize: w * 0.035,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Start Creating Button
        SizedBox(
          width: w * 0.8,
          height: 56,
          child: ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  "Start Creating",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRateAppPage(double w, double h) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFFFCC80), size: 100),
          const SizedBox(height: 24),
          Text(
            "Rate our App",
            style: TextStyle(
              color: Colors.white,
              fontSize: w * 0.065,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: w * 0.1),
            child: Text(
              "Your feedback helps us improve and bring you more amazing features!",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: w * 0.04),
            ),
          ),
          const SizedBox(height: 32),
          // Fake stars
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Icon(
                  Icons.star_border_rounded,
                  color: Colors.white54,
                  size: 40,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialPage(double w, double h) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.celebration_rounded,
            color: Color(0xFFFFCC80),
            size: 80,
          ),
          const SizedBox(height: 24),
          Text(
            "Your 7 day trial\nhas started",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: w * 0.07,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Enjoy full access to all premium features.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60, fontSize: w * 0.04),
          ),
        ],
      ),
    );
  }

  // Removed _buildSharedBottomSection as requested
}
