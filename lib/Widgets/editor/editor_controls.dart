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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(
                color: primaryText,
                fontSize: 12,
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
            width: 44,
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(color: primaryText, fontSize: 12),
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
          width: 60,
          child: Text(
            label,
            style: TextStyle(color: primaryText, fontSize: 11),
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
          width: 40,
          child: Text(
            '${(value * 100).round()}%',
            textAlign: TextAlign.right,
            style: TextStyle(color: primaryText, fontSize: 11),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          EditorMiniSliderRow(
            label: leftLabel,
            value: leftValue,
            onChanged: leftOnChanged,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
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

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: hslColors.asMap().entries.map((entry) {
        final i = entry.key;
        final c = entry.value;
        final active = selectedIndex == i;
        final isWhite = c == Colors.white;

        return GestureDetector(
          onTap: () => onChanged(i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Container(
              width: 20,
              height: 20,
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: tools.map((t) {
          final active = activeSubTool == t.subTool;

          return GestureDetector(
            onTap: () => onChanged(t.subTool),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 72,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: active
                          ? AppEditorConstants.accent.withAlpha(30)
                          : AppEditorConstants.iconBg(isDark),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: active
                            ? AppEditorConstants.accent
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      t.icon,
                      color: active
                          ? AppEditorConstants.accent
                          : AppEditorConstants.primaryText(
                              isDark,
                            ).withAlpha(180),
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    t.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active
                          ? AppEditorConstants.accent
                          : AppEditorConstants.textDim(isDark),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    ? AppEditorConstants.accent.withAlpha(30)
                    : AppEditorConstants.iconBg(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active
                      ? AppEditorConstants.accent
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Icon(
                b.icon,
                color: active
                    ? AppEditorConstants.accent
                    : AppEditorConstants.primaryText(isDark).withAlpha(180),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    ? AppEditorConstants.accent.withAlpha(30)
                    : AppEditorConstants.iconBg(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: active
                      ? AppEditorConstants.accent
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Icon(
                s.icon,
                color: active
                    ? AppEditorConstants.accent
                    : AppEditorConstants.primaryText(isDark).withAlpha(180),
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
              padding: const EdgeInsets.only(right: 20),
              child: Text(
                cat.toUpperCase(),
                style: TextStyle(
                  color: active
                      ? AppEditorConstants.accent
                      : AppEditorConstants.textDim(isDark),
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
