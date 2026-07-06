import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';

import 'package:trail_ai_app/Core/gradient.dart';
import 'package:trail_ai_app/Core/colors.dart';
import 'package:trail_ai_app/pages/home_page.dart';
import 'package:trail_ai_app/pages/all_ai_tools_page.dart';
import 'package:trail_ai_app/pages/selection.dart';
import 'package:trail_ai_app/pages/settings_page.dart';
import 'package:trail_ai_app/pages/reels_page.dart';
import 'package:trail_ai_app/pages/profile_page.dart';
import 'package:trail_ai_app/pages/image_editor_page.dart';
import 'package:trail_ai_app/Helpers/image_picker_helper.dart';

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

    final size = MediaQuery.of(context).size;
    final w = size.width;
    final h = size.height;

    final navRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildNavItem('assets/iconoir_home.svg', 0, isDark),
        _buildNavItem('assets/Group 48095580.svg', 1, isDark),
        _buildCentralItem(isDark),
        _buildNavItem('assets/iconamoon_profile-light.svg', 3, isDark),
        _buildNavItem('assets/weui_setting-outlined.svg', 4, isDark),
      ],
    );

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(isDark),
      extendBody: true, // Always extend body to allow the blur/glass effect
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Padding(
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
      onTap: () => setState(() => _currentIndex = index),
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
      onTap: _onCentralButtonTapped,
      child: Container(
        width: circleSize,
        height: circleSize,
        decoration: const ProGradientDecoration(shape: BoxShape.circle),
        child: Icon(Icons.add, color: Colors.white, size: iconSize),
      ),
    );
  }

  Future<void> _onCentralButtonTapped() async {
    // Show image source selection bottom sheet
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final w = MediaQuery.of(ctx).size.width;
        return ClipRRect(
          borderRadius: BorderRadius.vertical(top: Radius.circular(MediaQuery.of(context).size.width * 0.06)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                w * 0.05,
                w * 0.04,
                w * 0.05,
                w * 0.06,
              ),
              decoration: BoxDecoration(
                color: Color.fromRGBO(0, 0, 0, 0.5),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(MediaQuery.of(context).size.width * 0.06),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: w * 0.1,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.2475),
                    ),
                  ),
                  const Text(
                    'Create New',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  const Text(
                    'Choose an image to edit',
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                  Row(
                    children: [
                      Expanded(
                        child: _SourceTile(
                          icon: Icons.photo_library_outlined,
                          label: 'Gallery',
                          onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                        ),
                      ),
                      SizedBox(width: w * 0.04),
                      Expanded(
                        child: _SourceTile(
                          icon: Icons.camera_alt_outlined,
                          label: 'Camera',
                          onTap: () => Navigator.pop(ctx, ImageSource.camera),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.white54, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (source == null) return;

    // Pick image using helper to include safety check
    final File? pickedFile = await ImagePickerHelper.pickImage(
      context: context,
      crop: false,
      source: source,
    );

    if (pickedFile == null || !mounted) return;

    // Navigate to image editor
    final result = await Navigator.push<File?>(
      context,
      MaterialPageRoute(builder: (_) => ImageEditorPage(imageFile: pickedFile)),
    );

    // Optionally navigate to selection page after editing
    if (result != null && mounted) {
      setState(() => _currentIndex = 2);
    }
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: w * 0.05),
        decoration: BoxDecoration(
          color: const Color.fromRGBO(255, 255, 255, 0.12),
          borderRadius: BorderRadius.circular(w * 0.04),
          border: Border.all(
            color: const Color.fromRGBO(255, 255, 255, 0.2),
            width: 0.8,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: w * 0.08),
            SizedBox(height: MediaQuery.of(context).size.height * 0.01),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
