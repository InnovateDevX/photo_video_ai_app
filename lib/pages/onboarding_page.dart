import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trail_ai_app/Core/routes.dart';

/// Onboarding data model
class OnboardingSlide {
  final String imagePath; // local asset path
  final String title;
  final String subtitle;

  const OnboardingSlide({
    required this.imagePath,
    required this.title,
    required this.subtitle,
  });
}

/// The 3 onboarding slides — swap the imagePaths with your actual asset paths
const List<OnboardingSlide> kOnboardingSlides = [
  OnboardingSlide(
    imagePath: 'assets/onboarding/onboarding_1.webp',
    title: 'Bring your photos to Life',
    subtitle:
        '"Bring your captured moments to life with beautiful motion and realistic animation."',
  ),
  OnboardingSlide(
    imagePath: 'assets/onboarding/2.webp',
    title: 'Create with AI',
    subtitle:
        '"Generate stunning images and videos in seconds with the power of AI."',
  ),
  OnboardingSlide(
    imagePath: 'assets/onboarding/3.webp',
    title: 'Express your Style',
    subtitle:
        '"Choose from dozens of styles and filters to make every creation uniquely yours."',
  ),
];

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  /// Returns true if the user has already completed onboarding
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
  final PageController _controller = PageController();
  int _currentPage = 0;

  void _next() {
    if (_currentPage < kOnboardingSlides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await OnboardingPage.markCompleted();
    if (mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.home);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final isLastPage = _currentPage == kOnboardingSlides.length - 1;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Full-screen PageView ────────────────────────────────────────────
          PageView.builder(
            controller: _controller,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemCount: kOnboardingSlides.length,
            itemBuilder: (context, index) {
              final slide = kOnboardingSlides[index];
              return _OnboardingSlideView(slide: slide);
            },
          ),

          // ── Bottom overlay (gradient + dots + button) ──────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                w * 0.06,
                h * 0.07,
                w * 0.06,
                h * 0.045,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.97),
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Title ────────────────────────────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: Text(
                      kOnboardingSlides[_currentPage].title,
                      key: ValueKey(_currentPage),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: w * 0.065,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                  ),
                  SizedBox(height: h * 0.015),

                  // ── Subtitle ─────────────────────────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: Text(
                      kOnboardingSlides[_currentPage].subtitle,
                      key: ValueKey('sub_$_currentPage'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: w * 0.038,
                        height: 1.5,
                      ),
                    ),
                  ),
                  SizedBox(height: h * 0.03),

                  // ── Page Indicators ──────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(kOnboardingSlides.length, (i) {
                      final isActive = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: EdgeInsets.symmetric(horizontal: w * 0.01),
                        width: isActive ? w * 0.07 : w * 0.022,
                        height: w * 0.022,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(w * 0.02),
                          color: isActive
                              ? const Color(0xFFFF9800)
                              : Colors.white30,
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: h * 0.03),

                  // ── Action Button ────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: h * 0.065,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(w * 0.04),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF6B00), Color(0xFFFF9800)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF9800).withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(w * 0.04),
                          onTap: _next,
                          child: Center(
                            child: Text(
                              isLastPage ? 'Get Started' : 'Next',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: w * 0.048,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Skip (not on last page) ───────────────────────────────
                  if (!isLastPage) ...[
                    SizedBox(height: h * 0.012),
                    TextButton(
                      onPressed: _finish,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: w * 0.038,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingSlideView extends StatelessWidget {
  final OnboardingSlide slide;

  const _OnboardingSlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image (fill entire screen)
        Image.asset(
          slide.imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Placeholder gradient when image not yet added
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A1A2E),
                    Color(0xFF16213E),
                    Color(0xFF0F3460),
                  ],
                ),
              ),
              child: const Center(
                child: Icon(Icons.image, color: Colors.white24, size: 64),
              ),
            );
          },
        ),
        // Top dark vignette
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [Colors.black.withOpacity(0.45), Colors.transparent],
            ),
          ),
        ),
      ],
    );
  }
}
