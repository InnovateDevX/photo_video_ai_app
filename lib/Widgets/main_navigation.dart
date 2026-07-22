import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gal/gal.dart';

import 'package:vidzeon/Core/gradient.dart';
import 'package:vidzeon/Core/colors.dart';
import 'package:vidzeon/Services/subscription_service.dart';
import 'package:vidzeon/Widgets/main_navigation_with_paywall.dart';
import 'package:vidzeon/pages/home_page.dart';
import 'package:vidzeon/pages/all_ai_tools_page.dart';
import 'package:vidzeon/pages/generation_page.dart';
import 'package:vidzeon/pages/reels_page.dart';
import 'package:vidzeon/pages/profile_page.dart';
import 'package:adjust_sdk/adjust.dart';
import 'package:adjust_sdk/adjust_event.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => MainNavigationState();
}

class MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  // GlobalKeys let us call methods on the page states when tabs become active.
  final _generationKey = GlobalKey<GenerationPageState>();
  final _allAiToolsKey = GlobalKey<AllAiToolsPageState>();

  late final List<Widget> _pages;

  /// Tracks whether the user was subscribed when this widget was built.
  /// Used to detect a live revocation (true → false transition) vs.
  /// a normal non-subscribed startup (false at init).
  late bool _wasSubscribed;
  StreamSubscription<bool>? _subRevocationSub;

  @override
  void initState() {
    super.initState();
    _pages = [
      const Homepage(),
      const ReelsPage(),
      GenerationPage(key: _generationKey, isEmbeddedAsTab: true),
      const ProfilePage(),
      AllAiToolsPage(key: _allAiToolsKey, isEmbeddedAsTab: true),
    ];
    _requestPermissions();

    // Snapshot the subscription state at mount time.
    _wasSubscribed = SubscriptionService().isSubscribed;

    // Listen for live subscription revocation (cancellation / expiry).
    // When the stream emits false AND the user was previously subscribed,
    // replace this route with MainNavigationWithPaywall so the paywall
    // reappears immediately without requiring a restart.
    _subRevocationSub = SubscriptionService().subscriptionStream.listen((
      isSubscribed,
    ) {
      if (!isSubscribed && _wasSubscribed && mounted) {
        debugPrint(
          '🛒 [MainNavigation] Subscription revoked — showing paywall.',
        );
        // Lazy import avoids a circular dependency at the top of the file.
        Navigator.of(context).pushReplacement(
          PageRouteBuilder<void>(
            pageBuilder: (ctx, anim, secondaryAnim) =>
                const MainNavigationWithPaywall(),
            transitionsBuilder: (ctx, anim, secondaryAnim, child) =>
                FadeTransition(
                  opacity: CurvedAnimation(parent: anim, curve: Curves.easeIn),
                  child: child,
                ),
            transitionDuration: const Duration(milliseconds: 400),
          ),
        );
      }
      // Keep _wasSubscribed in sync for the next transition.
      _wasSubscribed = isSubscribed;
    });
  }

  void switchTab(int index) {
    setState(() {
      _currentIndex = index;
    });
    // Notify the relevant page that it just became visible.
    if (index == 1) {
      // Reels tab clicked - track Adjust event
      final adjustEvent = AdjustEvent('wn44jx');
      Adjust.trackEvent(adjustEvent);
    } else if (index == 2) {
      _generationKey.currentState?.onTabActivated();
    } else if (index == 4) {
      _allAiToolsKey.currentState?.onTabActivated();
    }
    print('swiching tab $index');
  }

  @override
  void dispose() {
    _subRevocationSub?.cancel();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }
    } catch (e) {
      debugPrint('📸 [MainNavigation] Failed to request gallery access: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    final navRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildNavItem('assets/iconoir_home.svg', 0, isDark),
        _buildCentralItem(isDark),
        _buildNavItem('assets/Group 48095580.svg', 1, isDark),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(isDark),
      extendBody: true, // Always extend body to allow the blur/glass effect
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _currentIndex == 2
          ? null
          : Padding(
              padding: EdgeInsets.only(
                left: w * 0.09,
                right: w * 0.09,
                bottom: MediaQuery.of(context).padding.bottom > 0
                    ? MediaQuery.of(context).padding.bottom
                    : h * 0.03,
              ),
              child: Container(
                height: h * 0.083, // Slightly larger height
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(w * 0.09),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(w * 0.09),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(w * 0.09),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : Colors.white.withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                      ),
                      child: navRow,
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildNavItem(String assetPath, int index, bool isDark) {
    final size = MediaQuery.of(context).size;
    final w = size.width;

    final bool isSelected = _currentIndex == index;

    final iconSize = w * 0.07; // Increased icon size
    final horizontalPadding = w * 0.032; // Increased padding
    final verticalPadding = w * 0.022; // Increased padding

    return GestureDetector(
      onTap: () => switchTab(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.08))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(w * 0.06),
        ),
        child: SvgPicture.asset(
          assetPath,
          width: iconSize,
          height: iconSize,
          colorFilter: ColorFilter.mode(
            isSelected
                ? (isDark ? Colors.white : Colors.black)
                : (isDark ? Colors.white54 : Colors.black54),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }

  Widget _buildCentralItem(bool isDark) {
    final w = MediaQuery.of(context).size.width;

    final circleSize = w * 0.135; // Increased circle size
    final iconSize = w * 0.07; // Increased icon size

    return GestureDetector(
      onTap: () => switchTab(2),
      child: Container(
        width: circleSize,
        height: circleSize,
        decoration: const ProGradientDecoration(shape: BoxShape.circle),
        child: Icon(Icons.add, color: Colors.white, size: iconSize),
      ),
    );
  }
}
