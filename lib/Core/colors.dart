import 'package:flutter/material.dart';

class AppColors {
  // Scaffold Background
  static Color backgroundColor(bool isDark) {
    return isDark ? const Color(0xFF161616) : Colors.white;
  }

  // Primary Text Color (Titles, Main Labels)
  static Color textColor(bool isDark) {
    return isDark ? Colors.white : Colors.black87;
  }

  // Secondary Text Color (Version text, subtler labels)
  static Color secondaryTextColor(bool isDark) {
    return isDark ? Colors.grey.shade400 : Colors.grey.shade600;
  }

  // Settings Tile Container Background
  static Color tileBackgroundColor(bool isDark) {
    return isDark ? const Color(0xFF242424) : const Color(0xFFEFEFEF);
  }

  // Icon Color
  static Color iconColor(bool isDark) {
    return isDark ? Colors.white70 : Colors.black54;
  }

  // Chevron Color
  static Color chevronColor(bool isDark) {
    return isDark ? Colors.grey.shade600 : Colors.grey.shade400;
  }

  // Credits Card Background
  static Color creditsCardBackground(bool isDark) {
    return isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF7F7F7);
  }

  // Credits Card Border
  static Color creditsCardBorder(bool isDark) {
    return isDark ? const Color(0xFF333333) : Colors.grey.shade200;
  }

  // Credits Pill Background
  static Color creditsPillBackground(bool isDark) {
    return isDark ? const Color(0xFF2C2C2C) : Colors.white;
  }

  // Credits Pill Text
  static Color creditsPillText(bool isDark) {
    return isDark ? Colors.white : Colors.black;
  }

  // Profile Specific Colors
  static Color profileAvatarBackground(bool isDark) {
    return isDark ? Colors.grey[800]! : Colors.grey[200]!;
  }

  static Color profileHandle(bool isDark) {
    return isDark ? Colors.grey[400]! : Colors.grey[500]!;
  }

  static Color profileStatCardBackground(bool isDark) {
    return isDark ? Colors.grey[900]! : const Color(0xFFEBEBEB);
  }

  static Color profileTabInactiveText(bool isDark) {
    return isDark ? Colors.grey[400]! : Colors.grey[700]!;
  }

  static Color profileGridItemBackground(bool isDark) {
    return isDark ? Colors.grey[850]! : const Color(0xFFF3F3F3);
  }

  static Color profileGridItemBorder(bool isDark) {
    return isDark
        ? Colors.grey[700]!
        : const Color(0xFFE46633).withValues(alpha: 0.3);
  }

  // Category Colors
  static const Color videoCategoryColor = Color(0xFFF16E14);
  static const Color imageCategoryColor = Color(0xFF5BAAF5);

  // Tool Item Background
  static Color toolItemBackground(bool isDark) {
    return isDark ? const Color(0xFF1E1E1E) : const Color(0xFFEFEFEF);
  }
}
