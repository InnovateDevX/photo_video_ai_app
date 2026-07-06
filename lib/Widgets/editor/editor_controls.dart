import 'package:flutter/material.dart';
import 'package:trail_ai_app/Core/editor_constants.dart';

/// Reusable slider row widget for editor controls
class EditorSliderRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final bool isDark;

  const EditorSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppEditorConstants.primaryText(isDark);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppEditorConstants.w(context, 0.05),
        vertical: AppEditorConstants.h(context, 0.015),
      ),
      child: Row(
        children: [
          SizedBox(
            width: AppEditorConstants.w(context, 0.18),
            child: Text(
              label,
              style: TextStyle(
                color: primaryText,
                fontSize: AppEditorConstants.sp(context, 12),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                activeTrackColor: primaryText,
                inactiveTrackColor: Colors.white24,
                thumbColor: primaryText,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(value: value, min: 0, max: 1, onChanged: onChanged),
            ),
          ),
          SizedBox(
            width: AppEditorConstants.sp(context, 44),
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: primaryText,
                fontSize: AppEditorConstants.sp(context, 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mini slider row for compact controls
class EditorMiniSliderRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final bool isDark;

  const EditorMiniSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppEditorConstants.primaryText(isDark);

    return Row(
      children: [
        SizedBox(
          width: AppEditorConstants.sp(context, 60),
          child: Text(
            label,
            style: TextStyle(
              color: primaryText,
              fontSize: AppEditorConstants.sp(context, 11),
            ),
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              activeTrackColor: primaryText,
              inactiveTrackColor: Colors.white24,
              thumbColor: primaryText,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
            ),
            child: Slider(value: value, min: 0, max: 1, onChanged: onChanged),
          ),
        ),
        SizedBox(
          width: AppEditorConstants.sp(context, 40),
          child: Text(
            '${(value * 100).round()}%',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: primaryText,
              fontSize: AppEditorConstants.sp(context, 11),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dual slider row for controls with two values
class EditorDualSliderRow extends StatelessWidget {
  final String leftLabel;
  final double leftValue;
  final ValueChanged<double> leftOnChanged;
  final String rightLabel;
  final double rightValue;
  final ValueChanged<double> rightOnChanged;
  final bool isDark;

  const EditorDualSliderRow({
    super.key,
    required this.leftLabel,
    required this.leftValue,
    required this.leftOnChanged,
    required this.rightLabel,
    required this.rightValue,
    required this.rightOnChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppEditorConstants.w(context, 0.05),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EditorMiniSliderRow(
            label: leftLabel,
            value: leftValue,
            onChanged: leftOnChanged,
            isDark: isDark,
          ),
          SizedBox(height: AppEditorConstants.h(context, 0.01)),
          EditorMiniSliderRow(
            label: rightLabel,
            value: rightValue,
            onChanged: rightOnChanged,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

/// HSL color dots selector
class EditorColorDots extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool isDark;

  const EditorColorDots({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final hslColors = AppEditorConstants.hslColors;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: hslColors.asMap().entries.map((entry) {
          final i = entry.key;
          final c = entry.value;
          final active = selectedIndex == i;
          final isWhite = c == Colors.white;

          return GestureDetector(
            onTap: () => onChanged(i),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppEditorConstants.w(context, 0.015),
              ),
              child: Container(
                width: AppEditorConstants.sp(context, 20),
                height: AppEditorConstants.sp(context, 20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.withAlpha(isWhite || active ? 255 : 100),
                  border: Border.all(
                    color: active ? AppEditorConstants.accent : Colors.white24,
                    width: active ? 2.5 : 1.5,
                  ),
                  boxShadow: active
                      ? [BoxShadow(color: c.withAlpha(100), blurRadius: 8)]
                      : null,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Sub tools row horizontal scroll
class EditorSubToolsRow extends StatelessWidget {
  final List<EditorSubToolData> tools;
  final String activeSubTool;
  final ValueChanged<String> onChanged;
  final bool isDark;

  const EditorSubToolsRow({
    super.key,
    required this.tools,
    required this.activeSubTool,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Each item gets a fixed width based on screen size so text is never clipped.
    // The row is horizontally scrollable, fulfilling the user's request for a
    // horizontal scroll list that never cuts off any tool.
    final itemW = AppEditorConstants.w(context, 0.18).clamp(64.0, 90.0);
    return SizedBox(
      // Constrain the height explicitly so nothing in the outer Column overflows
      height: 88,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: tools.length,
        itemBuilder: (context, index) {
          final t = tools[index];
          final active = activeSubTool == t.subTool;

          return GestureDetector(
            onTap: () => onChanged(t.subTool),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: itemW,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: AppEditorConstants.sp(context, 44),
                    height: AppEditorConstants.sp(context, 44),
                    decoration: BoxDecoration(
                      color: active
                          ? AppEditorConstants.accent.withAlpha(20)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: t.icon is IconData
                        ? Icon(
                            t.icon as IconData,
                            size: AppEditorConstants.sp(context, 22),
                            color: active
                                ? AppEditorConstants.accent
                                : AppEditorConstants.textDim(isDark),
                          )
                        : Padding(
                            padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.025),
                            child: Image.asset(
                              t.icon as String,
                              color: active
                                  ? AppEditorConstants.accent
                                  : AppEditorConstants.textDim(isDark),
                              fit: BoxFit.contain,
                            ),
                          ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.005),
                  Text(
                    t.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: active
                          ? AppEditorConstants.accent
                          : AppEditorConstants.textDim(isDark),
                      fontSize: AppEditorConstants.sp(context, 10),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Brush mode row for paint editor
class EditorBrushRow extends StatelessWidget {
  final List<BrushModeData> brushes;
  final String activeMode;
  final ValueChanged<String> onChanged;
  final bool isDark;

  const EditorBrushRow({
    super.key,
    required this.brushes,
    required this.activeMode,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: brushes.map((b) {
          final active = activeMode == b.mode;

          return GestureDetector(
            onTap: () => onChanged(b.mode),
            child: Container(
              width: 56,
              height: 56,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: active
                    ? AppEditorConstants.accent
                    : AppEditorConstants.iconBg(isDark),
                borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.035),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: AppEditorConstants.accent.withAlpha(80),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                b.icon,
                color: active
                    ? Colors.white
                    : AppEditorConstants.primaryText(isDark).withAlpha(150),
                size: 24,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Shape mode row for shape editor
class EditorShapeRow extends StatelessWidget {
  final List<ShapeModeData> shapes;
  final String activeMode;
  final ValueChanged<String> onChanged;
  final bool isDark;

  const EditorShapeRow({
    super.key,
    required this.shapes,
    required this.activeMode,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: shapes.map((s) {
          final active = activeMode == s.mode;

          return GestureDetector(
            onTap: () => onChanged(s.mode),
            child: Container(
              width: 56,
              height: 56,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: active
                    ? AppEditorConstants.accent
                    : AppEditorConstants.iconBg(isDark),
                borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.035),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: AppEditorConstants.accent.withAlpha(80),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                s.icon,
                color: active
                    ? Colors.white
                    : AppEditorConstants.primaryText(isDark).withAlpha(150),
                size: 24,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Effect categories tabs
class EditorEffectTabs extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onChanged;
  final bool isDark;

  const EditorEffectTabs({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: categories.map((cat) {
          final active = selectedCategory == cat;

          return GestureDetector(
            onTap: () => onChanged(cat),
            child: Padding(
              padding: EdgeInsets.only(
                right: AppEditorConstants.w(context, 0.05),
              ),
              child: Text(
                cat.toUpperCase(),
                style: TextStyle(
                  color: active
                      ? AppEditorConstants.accent
                      : AppEditorConstants.textDim(isDark),
                  fontSize: AppEditorConstants.sp(context, 12),
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Unified tab switcher for Markup and Shape
class EditorPaintTabs extends StatelessWidget {
  final EditorSubTool activeTab;
  final ValueChanged<EditorSubTool> onChanged;
  final bool isDark;

  const EditorPaintTabs({
    super.key,
    required this.activeTab,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTab('Markup', EditorSubTool.markup),
        SizedBox(width: AppEditorConstants.w(context, 0.08)),
        _buildTab('Shape', EditorSubTool.shape),
      ],
    );
  }

  Widget _buildTab(String label, EditorSubTool tab) {
    final active = activeTab == tab;
    return GestureDetector(
      onTap: () => onChanged(tab),
      child: Text(
        label,
        style: TextStyle(
          color: active
              ? AppEditorConstants.accent
              : AppEditorConstants.textDim(isDark),
          fontSize: 14,
          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }
}

/// Tab switcher for Text editor (Font vs Basic)
class EditorTextTabs extends StatelessWidget {
  final EditorSubTool activeTab;
  final ValueChanged<EditorSubTool> onChanged;
  final bool isDark;

  const EditorTextTabs({
    super.key,
    required this.activeTab,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildTab('Font', EditorSubTool.textFont),
        SizedBox(width: AppEditorConstants.w(context, 0.08)),
        _buildTab('Basic', EditorSubTool.textStyle),
      ],
    );
  }

  Widget _buildTab(String label, EditorSubTool tab) {
    final active = activeTab == tab;
    return GestureDetector(
      onTap: () => onChanged(tab),
      child: Text(
        label,
        style: TextStyle(
          color: active
              ? AppEditorConstants.accent
              : AppEditorConstants.textDim(isDark),
          fontSize: 14,
          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }
}

/// Individual font selection card
class EditorFontCard extends StatelessWidget {
  final String fontFamily;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;
  final TextStyle fontStyle;

  const EditorFontCard({
    super.key,
    required this.fontFamily,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
    required this.fontStyle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppEditorConstants.accent
              : AppEditorConstants.iconBg(isDark),
          borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.05),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFD66031), Color(0xFFB54D26)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Center(
          child: Text(
            fontFamily,
            style: fontStyle.copyWith(
              color: isSelected
                  ? Colors.white
                  : AppEditorConstants.primaryText(isDark),
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}

/// premium color picker row
class EditorColorRow extends StatelessWidget {
  final Color selectedColor;
  final ValueChanged<Color> onChanged;
  final bool isDark;

  const EditorColorRow({
    super.key,
    required this.selectedColor,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      Colors.white,
      const Color(0xFF007AFF), // Blue
      const Color(0xFFFF3B30), // Red
      const Color(0xFF4CD964), // Green
      const Color(0xFFFFCC00), // Yellow
      const Color(0xFF5856D6), // Purple
      const Color(0xFF333333), // Dark Grey
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: colors.map((c) {
          final active = selectedColor == c;
          return GestureDetector(
            onTap: () => onChanged(c),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c,
                  border: Border.all(
                    color: active ? Colors.white : Colors.white24,
                    width: active ? 2 : 1,
                  ),
                  boxShadow: active
                      ? [BoxShadow(color: c.withAlpha(80), blurRadius: 6)]
                      : null,
                ),
                child: active
                    ? Center(
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
