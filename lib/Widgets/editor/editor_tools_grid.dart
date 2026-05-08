import 'dart:io';
import 'package:flutter/material.dart';
import 'package:trail_ai_app/Core/editor_constants.dart';

/// Main tools grid for the image editor
/// Shows all available editing tools
class EditorToolsGrid extends StatelessWidget {
  final List<EditorToolData> tools;
  final String activeTool;
  final ValueChanged<String> onToolSelected;
  final bool expanded;
  final bool isDark;

  const EditorToolsGrid({
    super.key,
    required this.tools,
    required this.activeTool,
    required this.onToolSelected,
    required this.expanded,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final displayTools = expanded ? tools : tools.take(4).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 0,
        runSpacing: 20,
        alignment: WrapAlignment.spaceEvenly,
        children: displayTools.map((t) {
          return _ToolButton(
            tool: t,
            isActive: activeTool == t.tool,
            onTap: () => onToolSelected(t.tool),
            isDark: isDark,
          );
        }).toList(),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  final EditorToolData tool;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDark;

  const _ToolButton({
    required this.tool,
    required this.isActive,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: screenWidth / 4 - 8,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppEditorConstants.toolBtnSize,
              height: AppEditorConstants.toolBtnSize,
              decoration: BoxDecoration(
                color: isActive
                    ? AppEditorConstants.accent
                    : AppEditorConstants.iconBg(isDark),
                shape: BoxShape.circle,
              ),
              child: Icon(
                tool.icon,
                color: AppEditorConstants.primaryText(isDark),
                size: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tool.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isActive
                    ? AppEditorConstants.accent
                    : AppEditorConstants.textDim(isDark),
                fontSize: AppEditorConstants.toolLabelSize,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Filter thumbnails widget
class EditorFilterThumbnails extends StatelessWidget {
  final List<FilterDefinition> filters;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final File imageFile;
  final bool isDark;

  const EditorFilterThumbnails({
    super.key,
    required this.filters,
    required this.selectedIndex,
    required this.onChanged,
    required this.imageFile,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: filters.asMap().entries.map((entry) {
          final i = entry.key;
          final f = entry.value;
          final active = selectedIndex == i;

          return GestureDetector(
            onTap: () => onChanged(i),
            child: Container(
              width: 64,
              height: 64,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: AppEditorConstants.iconBg(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      active ? AppEditorConstants.accent : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColorFiltered(
                      colorFilter: f.matrix != null
                          ? ColorFilter.matrix(f.matrix!)
                          : const ColorFilter.mode(
                              Colors.transparent, BlendMode.dst),
                      child: Image.file(
                        imageFile,
                        fit: BoxFit.cover,
                        cacheWidth: 150, // Optimize for thumbnails
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withAlpha(180),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Text(
                          f.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Effect thumbnails widget
class EditorEffectThumbnails extends StatelessWidget {
  final List<String> effectIds;
  final String? selectedEffectId;
  final ValueChanged<String?> onChanged;
  final bool isDark;

  const EditorEffectThumbnails({
    super.key,
    required this.effectIds,
    this.selectedEffectId,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // None option
          GestureDetector(
            onTap: () => onChanged(null),
            child: Container(
              width: 64,
              height: 64,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: AppEditorConstants.iconBg(isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selectedEffectId == null
                      ? AppEditorConstants.accent
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.block,
                  color: AppEditorConstants.textDim(isDark),
                  size: 24,
                ),
              ),
            ),
          ),
          // Effect thumbnails
          ...effectIds.map((id) {
            final active = selectedEffectId == id;

            return GestureDetector(
              onTap: () => onChanged(id),
              child: Container(
                width: 64,
                height: 64,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: AppEditorConstants.iconBg(isDark),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: active
                        ? AppEditorConstants.accent
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Text(
                    id,
                    style: TextStyle(
                      color: active
                          ? AppEditorConstants.accent
                          : AppEditorConstants.textDim(isDark),
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
