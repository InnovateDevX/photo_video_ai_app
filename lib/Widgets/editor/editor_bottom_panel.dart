import 'package:flutter/material.dart';
import 'package:trail_ai_app/Core/editor_constants.dart';
import 'package:trail_ai_app/Core/gradient.dart';

/// Swipeable bottom panel for the image editor
/// Contains controls for the active tool
class EditorBottomPanel extends StatefulWidget {
  final Widget child;
  final bool isDark;
  final AnimationController panelController;
  final bool panelExpanded;

  const EditorBottomPanel({
    super.key,
    required this.child,
    required this.isDark,
    required this.panelController,
    required this.panelExpanded,
  });

  @override
  State<EditorBottomPanel> createState() => _EditorBottomPanelState();
}

class _EditorBottomPanelState extends State<EditorBottomPanel> {
  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;

    return AnimatedBuilder(
      animation: widget.panelController,
      builder: (context, child) {
        final frac =
            AppEditorConstants.collapsedFrac +
            (AppEditorConstants.expandedFrac -
                    AppEditorConstants.collapsedFrac) *
                widget.panelController.value;
        final bottomPadding = MediaQuery.of(context).padding.bottom;
        final panelH = screenH * frac + bottomPadding;

        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: panelH,
          child: child!,
        );
      },
      child: GestureDetector(
        onVerticalDragUpdate: (d) {
          final delta = -d.primaryDelta! / screenH;
          widget.panelController.value = (widget.panelController.value + delta)
              .clamp(0.0, 1.0);
        },
        onVerticalDragEnd: (d) {
          if (d.primaryVelocity! < -300) {
            widget.panelController.animateTo(1.0, curve: Curves.easeOut);
          } else if (d.primaryVelocity! > 300) {
            widget.panelController.animateTo(0.0, curve: Curves.easeOut);
          } else if (widget.panelController.value > 0.5) {
            widget.panelController.animateTo(1.0, curve: Curves.easeOut);
          } else {
            widget.panelController.animateTo(0.0, curve: Curves.easeOut);
          }
        },
        child: Container(
          padding: const EdgeInsets.only(top: 2),
          decoration: const BoxDecoration(
            gradient: AppGradients.proGradient,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppEditorConstants.panelRadius),
            ),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppEditorConstants.panelBg(widget.isDark),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppEditorConstants.panelRadius),
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
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
        padding: const EdgeInsets.only(top: 16),
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
          padding: const EdgeInsets.only(left: 16, top: 16),
          child: EditorActionBtn(
            icon: Icons.check,
            onTap: onConfirm,
            isDark: isDark,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 16),
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
