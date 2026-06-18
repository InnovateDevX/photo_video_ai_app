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

  // ─── Responsive Scaling ──────────────────────────────────────
  static double h(BuildContext context, double p) =>
      MediaQuery.of(context).size.height * p;
  static double w(BuildContext context, double p) =>
      MediaQuery.of(context).size.width * p;
  static double sp(BuildContext context, double s) =>
      (MediaQuery.of(context).size.width / 375.0) * s;

  // ─── Panel Animation ────────────────────────────────────────
  static const double collapsedFrac = 0.28;
  static const double expandedFrac = 0.65;

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
    BrushModeData(icon: Icons.circle_outlined, mode: 'circle'),
    BrushModeData(icon: Icons.crop_square_outlined, mode: 'rect'),
    BrushModeData(
      icon: Icons.change_history_outlined,
      mode: 'custom1',
    ), // Triangle
    BrushModeData(icon: Icons.north_east, mode: 'arrow'),
    BrushModeData(icon: Icons.maximize, mode: 'line'),
    BrushModeData(icon: Icons.linear_scale, mode: 'dashLine'),
    BrushModeData(icon: Icons.more_horiz, mode: 'dashDotLine'),
    BrushModeData(icon: Icons.hexagon_outlined, mode: 'hexagon'),
    BrushModeData(icon: Icons.polyline, mode: 'polygon'),
  ];

  // ─── Shape Modes ─────────────────────────────────────────────
  static const List<ShapeModeData> shapeModes = [
    ShapeModeData(icon: Icons.block, mode: 'eraser'),
    ShapeModeData(icon: Icons.circle, mode: 'circle'),
    ShapeModeData(icon: Icons.square, mode: 'rect'),
    ShapeModeData(icon: Icons.change_history, mode: 'custom1'), // Triangle
    ShapeModeData(icon: Icons.star, mode: 'star'),
    ShapeModeData(icon: Icons.north_east, mode: 'arrow'),
    ShapeModeData(icon: Icons.hexagon, mode: 'hexagon'),
  ];

  // ─── Effect Categories ───────────────────────────────────────
  static const List<String> effectCategories = [
    'Butterfly',
    'Flower',
    'Heart',
    'Neon Light',
    'Star',
  ];

  // ─── Filter Definitions ─────────────────────────────────────
  static const List<FilterDefinition> filters = [
    FilterDefinition(name: 'None', matrix: null),

    // Clean / basic
    FilterDefinition(
      name: 'Classic',
      matrix: [
        0.95,
        0,
        0,
        0,
        0,
        0,
        0.95,
        0,
        0,
        0,
        0,
        0,
        0.95,
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
      name: 'Mono',
      matrix: [
        0.33,
        0.33,
        0.33,
        0,
        0,
        0.33,
        0.33,
        0.33,
        0,
        0,
        0.33,
        0.33,
        0.33,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ],
    ),

    // Warm / cinematic
    FilterDefinition(
      name: 'Warm',
      matrix: [
        1.08,
        0,
        0,
        0,
        10,
        0,
        1.02,
        0,
        0,
        6,
        0,
        0,
        0.92,
        0,
        -2,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'Sunset',
      matrix: [
        1.12,
        0,
        0,
        0,
        18,
        0,
        0.95,
        0,
        0,
        6,
        0,
        0,
        0.86,
        0,
        -6,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'Golden',
      matrix: [
        1.12,
        0,
        0,
        0,
        16,
        0,
        1.06,
        0,
        0,
        8,
        0,
        0,
        0.92,
        0,
        -6,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'Moody',
      matrix: [
        0.92,
        0,
        0,
        0,
        -6,
        0,
        0.98,
        0,
        0,
        0,
        0,
        0,
        1.08,
        0,
        8,
        0,
        0,
        0,
        1,
        0,
      ],
    ),

    // Film styles
    FilterDefinition(
      name: 'Kodak Gold',
      matrix: [
        1.10,
        0.03,
        0.02,
        0,
        8,
        0.02,
        1.04,
        0.02,
        0,
        4,
        0.00,
        0.02,
        0.94,
        0,
        -2,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'Kodak Portra',
      matrix: [
        1.05,
        0.02,
        0.01,
        0,
        4,
        0.01,
        1.00,
        0.02,
        0,
        2,
        0.00,
        0.01,
        1.02,
        0,
        2,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'Kodachrome',
      matrix: [
        1.15,
        -0.03,
        -0.02,
        0,
        10,
        -0.02,
        1.08,
        -0.02,
        0,
        4,
        -0.02,
        -0.04,
        1.18,
        0,
        6,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'Fuji Pro',
      matrix: [
        0.98,
        0.00,
        0.02,
        0,
        2,
        0.00,
        1.06,
        0.00,
        0,
        0,
        0.02,
        0.00,
        1.02,
        0,
        6,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'Ilford',
      matrix: [
        1.15,
        0,
        0,
        0,
        -10,
        0,
        1.15,
        0,
        0,
        -10,
        0,
        0,
        1.15,
        0,
        -10,
        0,
        0,
        0,
        1,
        0,
      ],
    ),

    // Polaroid / retro
    FilterDefinition(
      name: 'Polaroid',
      matrix: [
        1.22,
        -0.04,
        -0.04,
        0,
        6,
        -0.04,
        1.16,
        -0.03,
        0,
        6,
        -0.02,
        -0.02,
        1.18,
        0,
        10,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'Vintage',
      matrix: [
        0.92,
        0.08,
        0.02,
        0,
        8,
        0.04,
        0.88,
        0.04,
        0,
        6,
        0.02,
        0.06,
        0.80,
        0,
        4,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'Fade',
      matrix: [
        0.90,
        0,
        0,
        0,
        18,
        0,
        0.90,
        0,
        0,
        18,
        0,
        0,
        0.90,
        0,
        18,
        0,
        0,
        0,
        1,
        0,
      ],
    ),

    // Modern / stylized
    FilterDefinition(
      name: 'Vivid',
      matrix: [
        1.18,
        0,
        0,
        0,
        0,
        0,
        1.18,
        0,
        0,
        0,
        0,
        0,
        1.18,
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
      name: 'Vivid Plus',
      matrix: [
        1.28,
        0,
        0,
        0,
        -10,
        0,
        1.28,
        0,
        0,
        -10,
        0,
        0,
        1.28,
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
      name: 'Teal Orange',
      matrix: [
        1.08,
        0,
        0,
        0,
        0,
        0,
        0.96,
        0,
        0,
        -8,
        0,
        0,
        1.12,
        0,
        10,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'Noir',
      matrix: [
        1.40,
        0,
        0,
        0,
        -20,
        0,
        1.40,
        0,
        0,
        -20,
        0,
        0,
        1.40,
        0,
        -20,
        0,
        0,
        0,
        1,
        0,
      ],
    ),

    // Soft aesthetic
    FilterDefinition(
      name: 'Dreamy',
      matrix: [
        1.08,
        0,
        0,
        0,
        12,
        0,
        1.04,
        0,
        0,
        10,
        0,
        0,
        1.08,
        0,
        14,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'Milky',
      matrix: [
        1.00,
        0,
        0,
        0,
        24,
        0,
        1.00,
        0,
        0,
        24,
        0,
        0,
        1.00,
        0,
        24,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'Rosy',
      matrix: [
        1.03,
        0.00,
        0.00,
        0,
        2,
        0.00,
        0.92,
        0.00,
        0,
        2,
        0.00,
        0.00,
        0.96,
        0,
        2,
        0,
        0,
        0,
        1,
        0,
      ],
    ),

    // Urban / Street Aesthetic Pack
    FilterDefinition(
      name: 'Urban Matte',
      matrix: [
        0.98,
        0,
        0,
        0,
        6,
        0,
        0.98,
        0,
        0,
        4,
        0,
        0,
        0.95,
        0,
        8,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'Street Neon',
      matrix: [
        1.15,
        0,
        0,
        0,
        -5,
        0,
        1.05,
        0,
        0,
        0,
        0,
        0,
        1.20,
        0,
        10,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'Concrete',
      matrix: [
        0.95,
        0,
        0,
        0,
        -2,
        0,
        0.95,
        0,
        0,
        -2,
        0,
        0,
        0.98,
        0,
        4,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'City Night',
      matrix: [
        0.85,
        0,
        0,
        0,
        -10,
        0,
        0.88,
        0,
        0,
        -8,
        0,
        0,
        1.10,
        0,
        12,
        0,
        0,
        0,
        1,
        0,
      ],
    ),

    // Cinematic / Viral Trend Filters
    FilterDefinition(
      name: 'Cinematic Blue',
      matrix: [
        1.05,
        0,
        0,
        0,
        -8,
        0,
        1.00,
        0,
        0,
        0,
        0,
        0,
        1.20,
        0,
        18,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'TikTok Pop',
      matrix: [
        1.18,
        0,
        0,
        0,
        5,
        0,
        1.12,
        0,
        0,
        5,
        0,
        0,
        1.25,
        0,
        8,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'Instagram Warm',
      matrix: [
        1.12,
        0,
        0,
        0,
        10,
        0,
        1.05,
        0,
        0,
        6,
        0,
        0,
        0.92,
        0,
        -4,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'Film Grain Lite',
      matrix: [
        0.98,
        0.02,
        0,
        0,
        2,
        0.02,
        0.98,
        0,
        0,
        2,
        0,
        0,
        0.98,
        0,
        2,
        0,
        0,
        0,
        1,
        0,
      ],
    ),

    // Aesthetic Soft / Viral Portrait Style
    FilterDefinition(
      name: 'Soft Glow',
      matrix: [
        1.08,
        0,
        0,
        0,
        12,
        0,
        1.04,
        0,
        0,
        10,
        0,
        0,
        1.08,
        0,
        12,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'Pastel Dream',
      matrix: [
        0.95,
        0,
        0,
        0,
        18,
        0,
        0.90,
        0,
        0,
        18,
        0,
        0,
        0.95,
        0,
        20,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'Cream Tone',
      matrix: [
        1.05,
        0,
        0,
        0,
        20,
        0,
        1.02,
        0,
        0,
        18,
        0,
        0,
        0.90,
        0,
        10,
        0,
        0,
        0,
        1,
        0,
      ],
    ),

    // Night / Low Light Trending Looks
    FilterDefinition(
      name: 'Neon Night',
      matrix: [
        0.90,
        0,
        0,
        0,
        -8,
        0,
        0.95,
        0,
        0,
        0,
        0,
        0,
        1.30,
        0,
        18,
        0,
        0,
        0,
        1,
        0,
      ],
    ),
    FilterDefinition(
      name: 'Dark Chrome',
      matrix: [
        0.85,
        0,
        0,
        0,
        -10,
        0,
        0.90,
        0,
        0,
        -8,
        0,
        0,
        1.15,
        0,
        10,
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
    EditorToolData(
      tool: 'doodle',
      label: 'Doodle',
      icon: 'assets/image-editor-icons/arcticons_ar-doodle.png',
    ),
    EditorToolData(tool: 'selective', label: 'Selective', icon: Icons.adjust),
    EditorToolData(
      tool: 'effect',
      label: 'Effect',
      icon: 'assets/image-editor-icons/effects.png',
    ),
    EditorToolData(
      tool: 'filters',
      label: 'Filters',
      icon: 'assets/image-editor-icons/ion_color-filter-outline.png',
    ),
    EditorToolData(tool: 'adjust', label: 'Adjust', icon: Icons.tune),
    EditorToolData(
      tool: 'retouch',
      label: 'Retouch',
      icon: 'assets/image-editor-icons/tdesign_filter-3.png',
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
    EditorToolData(tool: 'frames', label: 'Frames', icon: Icons.crop_original),
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

    EditorSubToolData(subTool: 'grain', label: 'Grain', icon: Icons.grain),

    EditorSubToolData(
      subTool: 'vignette',
      label: 'Vignette',
      icon: Icons.circle_outlined,
    ),

    EditorSubToolData(
      subTool: 'sharpen',
      label: 'Sharpen',
      icon: Icons.auto_fix_high,
    ),

    EditorSubToolData(
      subTool: 'denoise',
      label: 'Denoise',
      icon: Icons.blur_on,
    ),

    EditorSubToolData(
      subTool: 'clarity',
      label: 'Clarity',
      icon: Icons.visibility,
    ),

    EditorSubToolData(
      subTool: 'temperature',
      label: 'Temperature',
      icon: Icons.thermostat,
    ),

    EditorSubToolData(
      subTool: 'vibrance',
      label: 'Vibration', // match screenshot text
      icon: Icons.wb_sunny_outlined,
    ),

    EditorSubToolData(
      subTool: 'saturation',
      label: 'Saturation',
      icon: Icons.water_drop_outlined,
    ),

    EditorSubToolData(
      subTool: 'skinTone',
      label: 'Skin Tone',
      icon: Icons.face,
    ),

    EditorSubToolData(
      subTool: 'curves',
      label: 'Curve',
      icon: Icons.show_chart,
    ),

    EditorSubToolData(subTool: 'tone', label: 'Tone', icon: Icons.tune),
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
  // ─── Fonts ──────────────────────────────────────────────────
  static const List<String> fontFamilies = [
    'Roboto',
    'Montserrat',
    'Poppins',
    'Open Sans',
    'Inter',
    'Lato',
    'Oswald',
    'Playfair Display',
    'Lora',
    'Merriweather',
    'PT Serif',
    'EB Garamond',
    'Cinzel',
    'Bebas Neue',
    'Righteous',
    'Lobster',
    'Abril Fatface',
    'Pacifico',
    'Dancing Script',
    'Caveat',
    'Satisfy',
    'Great Vibes',
    'Sacramento',
    'Schoolbell',
    'Bangers',
    'Sigmar',
    'Kelly Slab',
    'Sansita Swashed',
    'Sedan',
    'Ubuntu Mono',
    'Source Code Pro',
    'Courier Prime',
    'Press Start 2P',
    'Monoton',
    'Fredoka',
    'Alfa Slab One',
    'Aladin',
    'Amatic SC',
  ];
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
  final dynamic icon;
  const EditorToolData({
    required this.tool,
    required this.label,
    required this.icon,
  });
}

class EditorSubToolData {
  final String subTool;
  final String label;
  final dynamic icon;
  const EditorSubToolData({
    required this.subTool,
    required this.label,
    required this.icon,
  });
}

enum EditorTool {
  none,
  adjust,
  crop,
  text,
  doodle,
  effect,
  filters,
  retouch,
  sticker,
  shape,
  bg,
  selective,
  frames,
}

enum EditorSubTool {
  none,
  exposure,
  contrast,
  hsl,
  curves,
  autoAdjust,
  bgRemove,
  bgBlur,
  textFont,
  textStyle,
  markup,
  shape,
  // New adjust sub-tools
  grain,
  vignette,
  sharpen,
  denoise,
  clarity,
  temperature,
  vibrance,
  saturation,
  skinTone,
  tone,
}
