import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:image_picker/image_picker.dart';

import 'package:trail_ai_app/Core/gradient.dart';
import 'package:trail_ai_app/pages/home_page.dart';
import 'package:trail_ai_app/pages/all_ai_tools_page.dart';
import 'package:trail_ai_app/pages/selection.dart';
import 'package:trail_ai_app/pages/settings_page.dart';
import 'package:trail_ai_app/pages/reels_page.dart';
import 'package:trail_ai_app/pages/profile_page.dart';
import 'package:trail_ai_app/pages/image_editor_page.dart';

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
        _buildNavItem('assets/iconoir_home.png', 0, isDark),
        _buildNavItem('assets/Group 48095579.png', 1, isDark),
        _buildCentralItem(isDark),
        _buildNavItem('assets/iconamoon_profile-light.png', 3, isDark),
        _buildNavItem('assets/weui_setting-outlined.png', 4, isDark),
      ],
    );

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      extendBody: true, // Always extend body to allow the blur/glass effect
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: (h * 0.09).clamp(60.0, 100.0) +
                MediaQuery.of(context).padding.bottom,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.7)
                  : Colors.white.withValues(alpha: 0.85),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  width: 1,
                ),
              ),
              boxShadow: [
                if (!isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 15,
                    offset: const Offset(0, -5),
                  ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: 8 + MediaQuery.of(context).padding.bottom,
              ),
              child: navRow,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(String assetPath, int index, bool isDark) {
    bool isSelected = _currentIndex == index;
    final iconSize = (MediaQuery.of(context).size.width * 0.06).clamp(
      24.0,
      32.0,
    );
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        child: Image.asset(
          assetPath,
          color: isSelected
              ? (isDark ? Colors.white : Colors.black)
              : Colors.grey.withValues(alpha: 0.5),
          width: iconSize,
          height: iconSize,
        ),
      ),
    );
  }

  Widget _buildCentralItem(bool isDark) {
    final w = MediaQuery.of(context).size.width;
    final outerSize = (w * 0.14).clamp(50.0, 70.0);
    final innerSize = (w * 0.11).clamp(40.0, 56.0);
    final iconSize = (w * 0.07).clamp(24.0, 36.0);

    return GestureDetector(
      onTap: _onCentralButtonTapped,
      child: SizedBox(
        width: w * 0.16,
        height: w * 0.16,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: outerSize,
              height: outerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              child: Center(
                child: Container(
                  width: innerSize,
                  height: innerSize,
                  decoration: const ProGradientDecoration(
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Icon(Icons.add, color: Colors.white, size: iconSize),
          ],
        ),
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
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: EdgeInsets.fromLTRB(
                w * 0.05,
                w * 0.04,
                w * 0.05,
                w * 0.06,
              ),
              decoration: const BoxDecoration(
                color: Color.fromRGBO(0, 0, 0, 0.5),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                      borderRadius: BorderRadius.circular(99),
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
                  const SizedBox(height: 8),
                  const Text(
                    'Choose an image to edit',
                    style: TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
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
                  const SizedBox(height: 16),
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

    // Pick image
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
      maxHeight: 1024,
    );

    if (pickedFile == null || !mounted) return;

    // Navigate to image editor
    final result = await Navigator.push<File?>(
      context,
      MaterialPageRoute(
        builder: (_) => ImageEditorPage(imageFile: File(pickedFile.path)),
      ),
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
            const SizedBox(height: 8),
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
