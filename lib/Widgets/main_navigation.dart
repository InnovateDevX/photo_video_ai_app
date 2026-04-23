import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';

import 'package:trail_ai_app/Core/gradient.dart';
import 'package:trail_ai_app/pages/home_page.dart';
import 'package:trail_ai_app/pages/all_ai_tools_page.dart';
import 'package:trail_ai_app/pages/selection.dart';
import 'package:trail_ai_app/pages/settings_page.dart';
import 'package:trail_ai_app/pages/reels_page.dart';
import 'package:trail_ai_app/pages/profile_page.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => MainNavigationState();
}

class MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  final List<Widget> _pages = const [
    Homepage(),
    ReelsPage(),
    Selection(),
    ProfilePage(),
    SettingsPage(),
    AllAiToolsPage(),
  ];

  void switchTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _requestPermissions();
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
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;

    final navRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildNavItem('assets/iconoir_home.png', 0),
        _buildNavItem('assets/Group 48095579.png', 1),
        _buildCentralItem(),
        _buildNavItem('assets/iconamoon_profile-light.png', 3),
        _buildNavItem('assets/weui_setting-outlined.png', 4),
      ],
    );

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      // extendBody only in dark so the blur picks up the page content behind
      extendBody: isDark,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: isDark
          // ── Dark mode: frosted-glass glossy bar ──────────────────────────
          ? ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  height: h * 0.09,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.08),
                        Colors.white.withValues(alpha: 0.03),
                      ],
                    ),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.18),
                        width: 0.8,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: navRow,
                  ),
                ),
              ),
            )
          // ── Light mode: original solid dark bar ──────────────────────────
          : Container(
              height: h * 0.09,
              decoration: BoxDecoration(
                color: const Color(0xFF151515),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: Offset(w * 0.02, h * 0.02),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: navRow,
              ),
            ),
    );
  }

  Widget _buildNavItem(String assetPath, int index) {
    bool isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Image.asset(
        assetPath,
        color: isSelected ? Colors.white : Colors.grey.shade600,
        width: MediaQuery.of(context).size.width * 0.065,
        height: MediaQuery.of(context).size.width * 0.065, // Use width-based square sizing
      ),
    );
  }

  Widget _buildCentralItem() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = 2; // Index of ImageGen
        });
      },
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.16,
        height: MediaQuery.of(context).size.width * 0.16,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Border container
            Container(
              width: MediaQuery.of(context).size.width * 0.16,
              height: MediaQuery.of(context).size.width * 0.16,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color.fromARGB(
                  255,
                  190,
                  190,
                  190,
                ).withValues(alpha: 0.8),
              ),
              child: Center(
                // Gradient circle background inside the border
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.12,
                    height: MediaQuery.of(context).size.width * 0.12,
                    decoration: const ProGradientDecoration(
                      shape: BoxShape.circle,
                    ),
                  ),
              ),
            ),
            // Icon rendered separately on top
            Icon(
              Icons.add,
              color: Colors.white,
              size: MediaQuery.of(context).size.width * 0.08,
            ),
          ],
        ),
      ),
    );
  }
}
