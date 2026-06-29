import 'package:flutter/material.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:trail_ai_app/Core/editor_constants.dart';
import 'package:trail_ai_app/Core/gradient.dart';

class CropBottomPanel extends StatefulWidget {
  final dynamic editor;
  final bool isDark;

  const CropBottomPanel({
    super.key,
    required this.editor,
    required this.isDark,
  });

  @override
  State<CropBottomPanel> createState() => _CropBottomPanelState();
}

class _CropBottomPanelState extends State<CropBottomPanel> {
  bool get _isDark => widget.isDark;

  // ── helpers ────────────────────────────────────────────────────────────

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        padding: const EdgeInsets.all(1.5),
        decoration: const ProGradientDecoration(shape: BoxShape.circle),
        child: Container(
          decoration: BoxDecoration(
            color: AppEditorConstants.iconBg(_isDark),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: AppEditorConstants.primaryText(_isDark),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _ratioBtn(String label, double ratio, IconData icon) {
    final double current = widget.editor.aspectRatio ?? -1.0;
    final bool active =
        (ratio < 0 && current < 0) ||
        (ratio > 0 && (current - ratio).abs() < 0.01);

    return GestureDetector(
      onTap: () {
        widget.editor.updateAspectRatio(ratio);
        widget.editor.setState(() {});
        setState(() {});
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              padding: active ? const EdgeInsets.all(2) : EdgeInsets.zero,
              decoration: active
                  ? const ProGradientDecoration(shape: BoxShape.circle)
                  : BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppEditorConstants.iconBg(_isDark),
                    ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active ? Colors.black87 : Colors.transparent,
                ),
                child: Icon(
                  icon,
                  color: active
                      ? Colors.white
                      : AppEditorConstants.primaryText(_isDark),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: active
                    ? AppEditorConstants.accent
                    : AppEditorConstants.textDim(_isDark),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final double bottom = MediaQuery.of(context).padding.bottom;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        clipBehavior: Clip.hardEdge,
        padding: const EdgeInsets.only(top: 2),
        decoration: const BoxDecoration(
          gradient: AppGradients.proGradient,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppEditorConstants.panelRadius),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppEditorConstants.panelBg(_isDark),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppEditorConstants.panelRadius),
            ),
          ),
          padding: EdgeInsets.fromLTRB(16, 14, 16, 16 + bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppEditorConstants.textDim(_isDark).withAlpha(100),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // ── ROW 1: ✓ | undo | redo | reset | rotateCCW | rotateCW | flipV | flipH | ✕ ───────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // ✓ Apply
                    _iconBtn(Icons.check, () => widget.editor.done()),

                    const SizedBox(width: 8),

                    // Undo
                    _iconBtn(Icons.undo, () {
                      try {
                        widget.editor.undoAction();
                      } catch (_) {}
                      setState(() {});
                    }),

                    const SizedBox(width: 8),

                    // Redo
                    _iconBtn(Icons.redo, () {
                      try {
                        widget.editor.redoAction();
                      } catch (_) {}
                      setState(() {});
                    }),

                    const SizedBox(width: 8),

                    // Reset
                    _iconBtn(Icons.rotate_right, () {
                      try {
                        widget.editor.reset();
                      } catch (_) {}
                      setState(() {});
                    }),

                    const SizedBox(width: 8),

                    // Rotate CCW
                    _iconBtn(
                      Icons.rotate_90_degrees_ccw_outlined,
                      () {
                        final dynamic ed = widget.editor;
                        if (ed.cropRotateEditorConfigs.rotateDirection == RotateDirection.left) {
                          ed.rotate();
                        } else {
                          ed.rotationCount -= 2;
                          ed.rotate();
                        }
                      },
                    ),

                    const SizedBox(width: 8),

                    // Rotate CW
                    _iconBtn(
                      Icons.rotate_90_degrees_cw_outlined,
                      () {
                        final dynamic ed = widget.editor;
                        if (ed.cropRotateEditorConfigs.rotateDirection == RotateDirection.right) {
                          ed.rotate();
                        } else {
                          ed.rotationCount -= 2;
                          ed.rotate();
                        }
                      },
                    ),

                    const SizedBox(width: 8),

                    // Flip Vertical
                    _iconBtn(Icons.align_vertical_center, () {
                      widget.editor.flipY = !(widget.editor.flipY as bool);
                      try {
                        (widget.editor as dynamic).cropRotateEditorCallbacks
                            ?.handleFlip(
                              widget.editor.flipX,
                              widget.editor.flipY,
                            );
                      } catch (_) {}
                      widget.editor.setState(() {});
                      setState(() {});
                    }),

                    const SizedBox(width: 8),

                    // Flip Horizontal
                    _iconBtn(
                      Icons.align_horizontal_center,
                      () => widget.editor.flip(),
                    ),

                    const SizedBox(width: 8),

                    // ✕ Cancel
                    _iconBtn(Icons.close, () => widget.editor.close()),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── ROW 2: aspect ratio buttons ───────────────────────────────
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ratioBtn('Original', -1.0, Icons.crop_free),
                    _ratioBtn('1:1', 1.0, Icons.crop_square),
                    _ratioBtn('4:5', 4 / 5, Icons.crop_portrait),
                    _ratioBtn('16:9', 16 / 9, Icons.crop_landscape),
                    _ratioBtn('9:16', 9 / 16, Icons.crop_portrait),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
