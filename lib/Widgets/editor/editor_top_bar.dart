import 'package:flutter/material.dart';
import 'package:trail_ai_app/Core/editor_constants.dart';
import 'package:trail_ai_app/Core/gradient.dart';

/// Custom top bar widget for the image editor
/// Provides undo, redo, reset, and done actions
class EditorTopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final VoidCallback? onReset;
  final VoidCallback onDone;
  final bool isDark;
  final bool showUndoRedo;

  const EditorTopBar({
    super.key,
    required this.onBack,
    this.onUndo,
    this.onRedo,
    this.onReset,
    required this.onDone,
    required this.isDark,
    this.showUndoRedo = true,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final primaryText = AppEditorConstants.primaryText(isDark);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: topPadding + 8,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppEditorConstants.darkBg.withAlpha(220),
              AppEditorConstants.darkBg.withAlpha(120),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _TopBarBtn(
              icon: Icons.arrow_back_ios_new,
              onTap: onBack,
              primaryText: primaryText,
            ),
            if (showUndoRedo)
              Row(
                children: [
                  _TopBarBtn(
                    icon: Icons.undo,
                    onTap: onUndo ?? () {},
                    primaryText: primaryText,
                  ),
                  const SizedBox(width: 20),
                  _TopBarBtn(
                    icon: Icons.redo,
                    onTap: onRedo ?? () {},
                    primaryText: primaryText,
                  ),
                  const SizedBox(width: 20),
                  _TopBarBtn(
                    icon: Icons.refresh,
                    onTap: onReset ?? () {},
                    primaryText: primaryText,
                  ),
                ],
              )
            else
              const SizedBox.shrink(),
            _TopBarBtn(
              icon: Icons.check,
              onTap: onDone,
              primaryText: primaryText,
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom sub-editor top bar (for text, crop, paint, filter editors)
class EditorSubEditorTopBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String title;
  final VoidCallback onClose;
  final VoidCallback onDone;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool isDark;

  const EditorSubEditorTopBar({
    super.key,
    required this.title,
    required this.onClose,
    required this.onDone,
    this.onUndo,
    this.onRedo,
    required this.isDark,
  });

  @override
  Size get preferredSize => const Size.fromHeight(110);

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final primaryText = AppEditorConstants.primaryText(isDark);

    return PreferredSize(
      preferredSize: Size.fromHeight(topPadding + 64),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: topPadding + 8,
          left: 16,
          right: 16,
          bottom: 16,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppEditorConstants.darkBg.withAlpha(220),
              AppEditorConstants.darkBg.withAlpha(120),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _TopBarBtn(
              icon: Icons.arrow_back_ios_new,
              onTap: onClose,
              primaryText: primaryText,
            ),
            if (onUndo != null && onRedo != null)
              Row(
                children: [
                  _TopBarBtn(
                    icon: Icons.undo,
                    onTap: onUndo!,
                    primaryText: primaryText,
                  ),
                  const SizedBox(width: 20),
                  _TopBarBtn(
                    icon: Icons.redo,
                    onTap: onRedo!,
                    primaryText: primaryText,
                  ),
                ],
              )
            else
              Text(
                title,
                style: TextStyle(
                  color: primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            _TopBarBtn(
              icon: Icons.check,
              onTap: onDone,
              primaryText: primaryText,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBarBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color primaryText;

  const _TopBarBtn({
    required this.icon,
    required this.onTap,
    required this.primaryText,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: primaryText, size: 22),
      ),
    );
  }
}

/// Compare button widget for showing original image
class EditorCompareButton extends StatelessWidget {
  final bool showOriginal;
  final VoidCallback onTap;
  final double panelHeight;
  final bool isDark;

  const EditorCompareButton({
    super.key,
    required this.showOriginal,
    required this.onTap,
    required this.panelHeight,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final primaryText = AppEditorConstants.primaryText(isDark);

    return Positioned(
      right: 16,
      bottom: panelHeight + 16,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primaryText.withAlpha(30),
            shape: BoxShape.circle,
            border: Border.all(color: primaryText.withAlpha(60), width: 1),
          ),
          child: Icon(
            Icons.compare,
            color: showOriginal ? AppEditorConstants.accent : primaryText,
            size: 20,
          ),
        ),
      ),
    );
  }
}
