import 'package:flutter/material.dart';

/// Editor design tokens following the same pattern as AppColors
/// Used across all image editor widgets and sub-editors
class AppEditorConstants {
  AppEditorConstants._();

  // ─── Accent Color ───────────────────────────────────────────
  static const Color accent = Color(0xFFD66031);

  // ─── Dark Theme Colors ──────────────────────────────────────
  static const Color darkBg = Color(0xFF0A0A0A);
  static const Color darkPanelBg = Color(0xFF0A0A0A);
  static const Color darkIconBg = Color(0xFF1E1E1E);
  static const Color darkTextDim = Color(0xFF888888);
  static const Color darkTextActive = Color(0xFFD66031);
  static const Color darkWhite = Colors.white;

  // ─── Light Theme Colors ──────────────────────────────────────
  static const Color lightBg = Color(0xFFF5F5F5);
  static const Color lightPanelBg = Color(0xFFFFFFFF);
  static const Color lightIconBg = Color(0xFFE8E8E8);
  static const Color lightTextDim = Color(0xFF666666);
  static const Color lightTextActive = Color(0xFFD66031);
  static const Color lightBlack = Color(0xFF1A1A1A);

  // ─── Helper Methods ──────────────────────────────────────────
  static Color bgColor(bool isDark) => isDark ? darkBg : lightBg;
  static Color panelBg(bool isDark) => isDark ? darkPanelBg : lightPanelBg;
  static Color iconBg(bool isDark) => isDark ? darkIconBg : lightIconBg;
  static Color textDim(bool isDark) => isDark ? darkTextDim : lightTextDim;
  static Color textActive(bool isDark) =>
      isDark ? darkTextActive : lightTextActive;
  static Color primaryText(bool isDark) => isDark ? darkWhite : lightBlack;

  // ─── Dimension Constants ─────────────────────────────────────
  static const double panelRadius = 28.0;
  static const double panelHandleWidth = 40.0;
  static const double panelHandleHeight = 4.0;
  static const double actionBtnSize = 48.0;
  static const double toolBtnSize = 56.0;
  static const double toolLabelSize = 11.0;

  // ─── Panel Animation ────────────────────────────────────────
  static const double collapsedFrac = 0.22;
  static const double expandedFrac = 0.48;

  // ─── Slider Defaults ─────────────────────────────────────────
  static const double defaultSliderValue = 0.5;
  static const double defaultOpacityValue = 0.95;
  static const double defaultSizeValue = 0.05;
  static const double defaultStrokeValue = 0.02;
  static const double defaultBgBlurValue = 0.2;

  // ─── HSL Colors ─────────────────────────────────────────────
  static const List<Color> hslColors = [
    Colors.white, // Master
    Colors.red,
    Colors.yellow,
    Colors.green,
    Colors.cyan,
    Colors.blue,
    Colors.purple, // Magenta
  ];

  // ─── Brush Modes ─────────────────────────────────────────────
  static const List<BrushModeData> brushModes = [
    BrushModeData(icon: Icons.block, mode: 'eraser'),
    BrushModeData(icon: Icons.edit, mode: 'freeStyle'),
    BrushModeData(icon: Icons.brush, mode: 'line'),
    BrushModeData(icon: Icons.horizontal_rule, mode: 'dashLine'),
    BrushModeData(icon: Icons.gesture, mode: 'freeStyleAlt'),
  ];

  // ─── Shape Modes ─────────────────────────────────────────────
  static const List<ShapeModeData> shapeModes = [
    ShapeModeData(icon: Icons.circle_outlined, mode: 'circle'),
    ShapeModeData(icon: Icons.crop_square_outlined, mode: 'rect'),
    ShapeModeData(icon: Icons.change_history_outlined, mode: 'arrow'),
    ShapeModeData(icon: Icons.star_border, mode: 'star'),
  ];

  // ─── Effect Categories ───────────────────────────────────────
  static const List<String> effectCategories = [
    'lens',
    'prism',
    'grain',
    'dust',
  ];

  // ─── Filter Definitions ─────────────────────────────────────
  static const List<FilterDefinition> filters = [
    FilterDefinition(name: 'None', matrix: null),
    FilterDefinition(
      name: 'Classic',
      matrix: [
        0.9,
        0,
        0,
        0,
        0,
        0,
        0.9,
        0,
        0,
        0,
        0,
        0,
        0.9,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'Sepia',
      matrix: [
        0.393,
        0.769,
        0.189,
        0,
        0,
        0.349,
        0.686,
        0.168,
        0,
        0,
        0.272,
        0.534,
        0.131,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'Gray',
      matrix: [
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'Cool',
      matrix: [1, 0, 0, 0, 0, 0, 1, 0, 0, 10, 0, 0, 1, 0, 30, 0, 0, 0, 1, 0],
    ),
    FilterDefinition(
      name: 'Warm',
      matrix: [1, 0, 0, 0, 30, 0, 1, 0, 0, 10, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0],
    ),
    FilterDefinition(
      name: 'Lomo',
      matrix: [
        1.2,
        0.1,
        0.1,
        0,
        -10,
        0.1,
        1.2,
        0.1,
        0,
        -10,
        0.1,
        0.1,
        1.2,
        0,
        -10,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'Vinty',
      matrix: [
        0.9,
        0.2,
        -0.1,
        0,
        0,
        0.1,
        0.8,
        0.1,
        0,
        0,
        -0.1,
        0.2,
        0.7,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
  ];

  // ─── Tool Data ───────────────────────────────────────────────
  static const List<EditorToolData> mainTools = [
    EditorToolData(tool: 'crop', label: 'Crop', icon: Icons.crop),
    EditorToolData(tool: 'text', label: 'Text', icon: Icons.title),
    EditorToolData(tool: 'doodle', label: 'Doodle', icon: Icons.edit),
    EditorToolData(tool: 'selective', label: 'Selective', icon: Icons.adjust),
    EditorToolData(
      tool: 'effect',
      label: 'Effect',
      icon: Icons.auto_awesome_mosaic,
    ),
    EditorToolData(
      tool: 'filters',
      label: 'Filters',
      icon: Icons.filter_b_and_w,
    ),
    EditorToolData(tool: 'adjust', label: 'Adjust', icon: Icons.tune),
    EditorToolData(
      tool: 'retouch',
      label: 'Retouch',
      icon: Icons.face_retouching_natural,
    ),
    EditorToolData(
      tool: 'sticker',
      label: 'Sticker',
      icon: Icons.emoji_emotions_outlined,
    ),
    EditorToolData(
      tool: 'shape',
      label: 'Shape',
      icon: Icons.category_outlined,
    ),
    EditorToolData(tool: 'bg', label: 'BG', icon: Icons.layers_outlined),
    EditorToolData(tool: 'stroke', label: 'Stroke', icon: Icons.brush_outlined),
  ];

  // ─── Sub Tools - Adjust ─────────────────────────────────────
  static const List<EditorSubToolData> adjustSubTools = [
    EditorSubToolData(subTool: 'none', label: 'None', icon: Icons.block),
    EditorSubToolData(
      subTool: 'exposure',
      label: 'Exposure',
      icon: Icons.light_mode_outlined,
    ),
    EditorSubToolData(subTool: 'hsl', label: 'HSL', icon: Icons.lens_blur),
    EditorSubToolData(
      subTool: 'autoAdjust',
      label: 'Auto Adjust',
      icon: Icons.auto_awesome,
    ),
    EditorSubToolData(
      subTool: 'contrast',
      label: 'Contrast',
      icon: Icons.contrast,
    ),
    EditorSubToolData(
      subTool: 'curves',
      label: 'Curves',
      icon: Icons.show_chart,
    ),
  ];

  // ─── Sub Tools - Background ─────────────────────────────────
  static const List<EditorSubToolData> bgSubTools = [
    EditorSubToolData(subTool: 'none', label: 'None', icon: Icons.block),
    EditorSubToolData(
      subTool: 'bgRemove',
      label: 'BG Remove',
      icon: Icons.layers_clear,
    ),
    EditorSubToolData(subTool: 'bgBlur', label: 'BG Blur', icon: Icons.blur_on),
  ];

  // ─── Crop Sub Tools ─────────────────────────────────────────
  static const List<EditorSubToolData> cropSubTools = [
    EditorSubToolData(
      subTool: 'rotate',
      label: 'Rotate',
      icon: Icons.rotate_right,
    ),
    EditorSubToolData(subTool: 'flip', label: 'Flip', icon: Icons.flip),
    EditorSubToolData(
      subTool: 'ratio',
      label: 'Ratio',
      icon: Icons.aspect_ratio,
    ),
    EditorSubToolData(
      subTool: 'reset',
      label: 'Reset',
      icon: Icons.restart_alt,
    ),
  ];

  // ─── Panel Heights ───────────────────────────────────────────
  static const Map<String, double> panelHeights = {
    'none': 160.0,
    'none_expanded': 280.0,
    'adjust_curves': 280.0,
    'adjust_hsl': 240.0,
    'adjust_default': 180.0,
    'bg': 180.0,
    'doodle': 260.0,
    'shape': 260.0,
    'selective': 240.0,
    'filters': 220.0,
    'default': 200.0,
  };
}

/// Data classes for editor configuration
class BrushModeData {
  final IconData icon;
  final String mode;
  const BrushModeData({required this.icon, required this.mode});
}

class ShapeModeData {
  final IconData icon;
  final String mode;
  const ShapeModeData({required this.icon, required this.mode});
}

class FilterDefinition {
  final String name;
  final List<double>? matrix;
  const FilterDefinition({required this.name, this.matrix});
}

class EditorToolData {
  final String tool;
  final String label;
  final IconData icon;
  const EditorToolData({
    required this.tool,
    required this.label,
    required this.icon,
  });
}

class EditorSubToolData {
  final String subTool;
  final String label;
  final IconData icon;
  const EditorSubToolData({
    required this.subTool,
    required this.label,
    required this.icon,
  });
}
