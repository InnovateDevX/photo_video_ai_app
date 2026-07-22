import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vidzeon/Core/editor_constants.dart';

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
    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: AppEditorConstants.w(context, 0.03),
          vertical: 8,
        ),
        itemCount: tools.length,
        itemBuilder: (context, index) {
          final t = tools[index];
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: AppEditorConstants.w(context, 0.02),
            ),
            child: _ToolButton(
              tool: t,
              isActive: activeTool == t.tool,
              onTap: () => onToolSelected(t.tool),
              isDark: isDark,
            ),
          );
        },
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
    final btnSize = AppEditorConstants.sp(
      context,
      AppEditorConstants.toolBtnSize,
    );

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: btnSize,
              height: btnSize,
              decoration: BoxDecoration(
                color: isActive
                    ? AppEditorConstants.accent
                    : AppEditorConstants.iconBg(isDark),
                shape: BoxShape.circle,
              ),
              child: tool.icon is IconData
                  ? Icon(
                      tool.icon as IconData,
                      color: AppEditorConstants.primaryText(isDark),
                      size: btnSize * 0.5,
                    )
                  : Padding(
                      padding: EdgeInsets.all(btnSize * 0.22),
                      child: Image.asset(
                        tool.icon as String,
                        color: AppEditorConstants.primaryText(isDark),
                        fit: BoxFit.contain,
                      ),
                    ),
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.01),
            Text(
              tool.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isActive
                    ? AppEditorConstants.textActive(isDark)
                    : AppEditorConstants.textDim(isDark),
                fontSize: AppEditorConstants.sp(
                  context,
                  AppEditorConstants.toolLabelSize,
                ),
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: filters.asMap().entries.map((entry) {
          final i = entry.key;
          final f = entry.value;
          final active = selectedIndex == i;

          return GestureDetector(
            onTap: () => onChanged(i),
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppEditorConstants.iconBg(isDark),
                      borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.03),
                      border: Border.all(
                        color: active
                            ? AppEditorConstants.accent
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.025),
                      child: ColorFiltered(
                        colorFilter: f.matrix != null
                            ? ColorFilter.matrix(f.matrix!)
                            : const ColorFilter.mode(
                                Colors.transparent,
                                BlendMode.dst,
                              ),
                        child: Image.file(
                          imageFile,
                          fit: BoxFit.cover,
                          cacheWidth: 150, // Optimize for thumbnails
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.0075),
                  SizedBox(
                    width: 64,
                    child: Text(
                      f.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active
                            ? AppEditorConstants.accent
                            : (isDark ? Colors.white70 : Colors.black87),
                        fontSize: 9,
                        fontWeight: active ? FontWeight.bold : FontWeight.w500,
                      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.03),
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
                  borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.03),
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
