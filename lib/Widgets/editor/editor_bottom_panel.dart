import 'package:flutter/material.dart';
import 'package:vidzeon/Core/editor_constants.dart';
import 'package:vidzeon/Core/gradient.dart';

/// Swipeable bottom panel for the image editor
/// Contains controls for the active tool
class EditorBottomPanel extends StatefulWidget {
  final Widget child;
  final bool isDark;
  final AnimationController panelController;
  final bool panelExpanded;
  final double? collapsedHeight;
  final double? expandedHeight;

  const EditorBottomPanel({
    super.key,
    required this.child,
    required this.isDark,
    required this.panelController,
    required this.panelExpanded,
    this.collapsedHeight,
    this.expandedHeight,
    this.usePositioned = true,
  });

  final bool usePositioned;

  @override
  State<EditorBottomPanel> createState() => _EditorBottomPanelState();
}

class _EditorBottomPanelState extends State<EditorBottomPanel> {
  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final staticContent = Container(
      decoration: BoxDecoration(
        color: AppEditorConstants.panelBg(widget.isDark),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppEditorConstants.panelRadius),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: (bottomPadding > 0) ? bottomPadding : 12.0,
      ),
      child: widget.child,
    );

    final targetBaseH =
        widget.collapsedHeight ?? (screenH * AppEditorConstants.collapsedFrac);
    final targetMaxH =
        widget.expandedHeight ?? (screenH * AppEditorConstants.expandedFrac);

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 300),
      curve: Curves.fastOutSlowIn,
      tween: Tween<double>(begin: targetBaseH, end: targetBaseH),
      builder: (context, animatedBaseH, _) {
        return TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 300),
          curve: Curves.fastOutSlowIn,
          tween: Tween<double>(begin: targetMaxH, end: targetMaxH),
          builder: (context, animatedMaxH, _) {
            return AnimatedBuilder(
              animation: widget.panelController,
              child: staticContent,
              builder: (context, child) {
                final panelH =
                    animatedBaseH +
                    (animatedMaxH - animatedBaseH) *
                        widget.panelController.value +
                    bottomPadding;

                final panelWidget = Container(
                  clipBehavior: Clip.hardEdge,
                  padding: const EdgeInsets.only(top: 2),
                  decoration: const BoxDecoration(
                    gradient: AppGradients.proGradient,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(AppEditorConstants.panelRadius),
                    ),
                  ),
                  child: child,
                );

                if (widget.usePositioned) {
                  return Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: panelH,
                    child: panelWidget,
                  );
                } else {
                  return SizedBox(height: panelH, child: panelWidget);
                }
              },
            );
          },
        );
      },
    );
  }
}

/// Panel handle widget
class EditorPanelHandle extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;
  final AnimationController panelController;

  const EditorPanelHandle({
    super.key,
    required this.isDark,
    required this.onTap,
    required this.panelController,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(
          top: 12,
          bottom: 8,
        ),
        child: Container(
          width: AppEditorConstants.panelHandleWidth,
          height: AppEditorConstants.panelHandleHeight,
          decoration: BoxDecoration(
            color: isDark ? Colors.white38 : Colors.black26,
            borderRadius: BorderRadius.circular(
              AppEditorConstants.panelHandleHeight / 2,
            ),
          ),
        ),
      ),
    );
  }
}

/// Action button row for confirm/cancel in panel header
class EditorPanelHeader extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool isDark;

  const EditorPanelHeader({
    super.key,
    required this.onConfirm,
    required this.onCancel,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: 20,
            top: 12,
          ),
          child: EditorActionBtn(
            icon: Icons.check,
            onTap: onConfirm,
            isDark: isDark,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(
            right: 20,
            top: 12,
          ),
          child: EditorActionBtn(
            icon: Icons.close,
            onTap: onCancel,
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

/// Action button for panel header
class EditorActionBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isDark;
  final bool filled;

  const EditorActionBtn({
    super.key,
    required this.icon,
    required this.onTap,
    required this.isDark,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: AppEditorConstants.actionBtnSize,
        height: AppEditorConstants.actionBtnSize,
        decoration: BoxDecoration(
          color: filled
              ? AppEditorConstants.accent
              : AppEditorConstants.iconBg(isDark),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: filled
              ? Colors.white
              : (isDark ? Colors.white : Colors.black87),
          size: 20,
        ),
      ),
    );
  }
}
