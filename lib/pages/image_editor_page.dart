import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vidzeon/pages/ai_result_screen.dart';
import 'package:vidzeon/Models/effect_overlay.dart';
import 'package:vidzeon/Widgets/effect_overlay_preview.dart';
import 'package:vidzeon/Services/image_editor_bloc.dart';
import 'package:vidzeon/Services/effect_engine.dart';
import 'package:vidzeon/Models/curves_data.dart';
import 'package:vidzeon/Widgets/curves_editor.dart';
import 'package:vidzeon/Services/curves_processor.dart';
import 'package:vidzeon/Core/theme_notifier.dart';
import 'package:vidzeon/Core/editor_constants.dart';
import 'package:vidzeon/Widgets/editor/editor_top_bar.dart';
import 'package:vidzeon/Widgets/editor/editor_bottom_panel.dart';
import 'package:vidzeon/Widgets/editor/editor_controls.dart';
import 'package:vidzeon/Widgets/editor/editor_tools_grid.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vidzeon/Widgets/editor/crop_bottom_panel.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vidzeon/Widgets/editor/firebase_sticker_picker.dart';
import 'package:vidzeon/Widgets/editor/firebase_frame_picker.dart';
import 'package:vidzeon/Widgets/themed_dialog.dart';

import 'package:pro_image_editor/core/models/layers/layer_interaction.dart';
import 'package:vidzeon/Services/effect_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
class ImageEditorPage extends StatelessWidget {
  final File imageFile;
  const ImageEditorPage({super.key, required this.imageFile});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) =>
          ImageEditorBloc(imageFile)..add(ImageEditorInit(imageFile)),
      child: const _ImageEditorView(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
class _ImageEditorView extends StatefulWidget {
  const _ImageEditorView();
  @override
  State<_ImageEditorView> createState() => _ImageEditorViewState();
}

class _ImageEditorViewState extends State<_ImageEditorView>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // ── Theme Helpers ─────────────────────────────────────────────────────────
  bool get _isDark => themeNotifier.value;

  final GlobalKey<ProImageEditorState> _editorKey = GlobalKey();
  final GlobalKey<FirebaseStickerPickerState> _stickerPickerKey = GlobalKey();

  /// Controls the scroll position of the bottom panel content.
  /// Reset to top when switching between Font and Basic tabs in text editor.
  final ScrollController _panelScrollCtrl = ScrollController();

  /// Tracks stickers added during the current tool session so they can be discarded on cancel
  final List<dynamic> _unconfirmedStickers = [];

  /// Whether the software keyboard is currently visible.
  /// Updated via [WidgetsBindingObserver.didChangeMetrics] for reliability.
  bool _keyboardVisible = false;

  /// Flag to prevent duplicate dialogs when Android back button is pressed
  bool _isHandlingBack = false;

  /// Flag to show a loading overlay while shapes/doodles are being baked
  /// (rasterized) into the base image after the paint editor closes.
  bool _isBakingPaint = false;

  /// Captures the paint editor's body size at the moment the user taps the
  /// tick button. The paint editor has a different body size than the main
  /// editor (because it has its own app bar / bottom panel), so the bake
  /// function needs the *paint* editor's body to convert the layer's
  /// body-space offset into the image's pixel space correctly.
  /// Set in [_confirmCurrentTool] right before `subEditor.done()` and
  /// consumed/cleared inside [_bakePaintLayersIntoImage].
  Size? _paintEditorBodySize;

  final List<EffectOverlay> _effects = const [
    // ── Butterfly ──────────────────────────────────────────────
    EffectOverlay(
      id: 'Butterfly 1',
      category: 'Butterfly',
      assetPath: 'assets/effects/potrait/Butterfly/1.png',
      portraitPath: 'assets/effects/potrait/Butterfly/1.png',
      squarePath: 'assets/effects/square/Butterfly/1.png',
      thumbnailPath: 'assets/effects/potrait/Butterfly/1.png',
      blendMode: ui.BlendMode.screen,
    ),
    EffectOverlay(
      id: 'Butterfly 2',
      category: 'Butterfly',
      assetPath: 'assets/effects/potrait/Butterfly/2.png',
      portraitPath: 'assets/effects/potrait/Butterfly/2.png',
      squarePath: 'assets/effects/square/Butterfly/2.png',
      thumbnailPath: 'assets/effects/potrait/Butterfly/2.png',
      blendMode: ui.BlendMode.screen,
    ),
    // ── Flower ─────────────────────────────────────────────────
    EffectOverlay(
      id: 'Flower 1',
      category: 'Flower',
      assetPath: 'assets/effects/potrait/Flower/1.png',
      portraitPath: 'assets/effects/potrait/Flower/1.png',
      squarePath: 'assets/effects/square/Flower/1.png',
      thumbnailPath: 'assets/effects/potrait/Flower/1.png',
      blendMode: ui.BlendMode.screen,
    ),
    // ── Heart ──────────────────────────────────────────────────
    EffectOverlay(
      id: 'Heart 1',
      category: 'Heart',
      assetPath: 'assets/effects/potrait/Heart/1.png',
      portraitPath: 'assets/effects/potrait/Heart/1.png',
      squarePath: 'assets/effects/square/Heart/1.png',
      thumbnailPath: 'assets/effects/potrait/Heart/1.png',
      blendMode: ui.BlendMode.screen,
    ),
    // ── Neon Light ──────────────────────────────────────────────
    EffectOverlay(
      id: 'Neon 1',
      category: 'Neon Light',
      assetPath: 'assets/effects/potrait/Neon Light/1.png',
      portraitPath: 'assets/effects/potrait/Neon Light/1.png',
      squarePath:
          'assets/effects/potrait/Neon Light/1.png', // Fallback to potrait if missing in square
      thumbnailPath: 'assets/effects/potrait/Neon Light/1.png',
      blendMode: ui.BlendMode.plus,
    ),
    // ── Star ───────────────────────────────────────────────────
    EffectOverlay(
      id: 'Star 1',
      category: 'Star',
      assetPath: 'assets/effects/potrait/Star/1.png',
      portraitPath: 'assets/effects/potrait/Star/1.png',
      squarePath: 'assets/effects/square/Star/1.png',
      thumbnailPath: 'assets/effects/potrait/Star/1.png',
      blendMode: ui.BlendMode.plus,
    ),
  ];

  late AnimationController _panelCtrl;
  bool _panelExpanded = false;

  Timer? _showOriginalTimer;
  double _initialRadius = 80.0;

  EditorTool _activeTool = EditorTool.none;
  EditorSubTool _activeSubTool = EditorSubTool.none;

  double _adjustValue = AppEditorConstants.defaultSliderValue;
  CurvesData _curvesData = CurvesData();
  Uint8List? _curvesBaseBytes;
  int _curvesBaseW = 0;
  int _curvesBaseH = 0;
  ui.Image? _curvesPreviewImage;
  Timer? _previewDebounce;
  int _selectedHslColorIndex = 0;
  final List<Map<String, double>> _hslAdjustments = List.generate(
    7,
    (_) => {
      'hue': AppEditorConstants.defaultSliderValue,
      'saturation': AppEditorConstants.defaultSliderValue,
      'luminance': AppEditorConstants.defaultSliderValue,
    },
  );
  // HSL live preview state
  Uint8List? _hslBaseBytes;
  int _hslBaseWidth = 0;
  int _hslBaseHeight = 0;
  ui.Image? _hslPreviewImage;
  Timer? _hslPreviewDebounce;
  // Grain live preview state
  ui.Image? _grainPreviewImage;
  double _sizeValue = AppEditorConstants.defaultSizeValue;
  double _strokeValue = AppEditorConstants.defaultStrokeValue;
  double _opacityValue = AppEditorConstants.defaultOpacityValue;
  Color _paintColor = Colors.white;
  String _selectedEffectTab = 'Butterfly';
  String? _selectedFrameUrl;
  List<double>? _selectedFilterMatrix;
  int _selectedFilterIndex = 0;
  String _selectedFontFamily = 'Roboto';
  Color _textColor = Colors.white;
  double _textOpacity = 1.0;
  TextAlign _textAlign = TextAlign.center;
  bool _isBold = false;
  bool _isItalic = false;
  bool _isUnderlined = false;

  bool get _isPackageEditorActive =>
      _activeTool == EditorTool.crop ||
      _activeTool == EditorTool.text ||
      _activeTool == EditorTool.doodle ||
      _activeTool == EditorTool.shape ||
      _activeTool == EditorTool.filters;

  List<double>? _getLiveMatrix() {
    if (_activeTool == EditorTool.filters) {
      return _selectedFilterMatrix;
    }
    if (_activeTool == EditorTool.adjust) {
      if (_activeSubTool == EditorSubTool.exposure) {
        // Exposure: use brightness with a small contrast boost to make changes more visible
        final brightness = (_adjustValue - 0.5) * 6; // Range: -3 to +3
        final contrast =
            _adjustValue * 0.15; // Small contrast boost (0 to 0.15)
        return EffectEngine().buildColorMatrix(brightness, contrast, 0, 0);
      } else if (_activeSubTool == EditorSubTool.contrast) {
        return EffectEngine().buildContrastMatrix((_adjustValue - 0.5) * 2);
      } else if (_activeSubTool == EditorSubTool.autoAdjust) {
        // Auto adjust uses slider value: 0 = no change, 1 = full auto enhancement
        final strength = _adjustValue;
        return EffectEngine().buildColorMatrix(
          strength * 0.3,
          strength * 0.3,
          strength * 0.3,
          0,
        );
      } else if (_activeSubTool == EditorSubTool.saturation) {
        return EffectEngine().buildSaturationMatrix((_adjustValue - 0.5) * 2);
      } else if (_activeSubTool == EditorSubTool.temperature) {
        return EffectEngine().buildTemperatureMatrix((_adjustValue - 0.5) * 2);
      } else if (_activeSubTool == EditorSubTool.tone) {
        return EffectEngine().buildToneMatrix((_adjustValue - 0.5) * 2);
      } else if (_activeSubTool == EditorSubTool.vibrance) {
        // Vibrance: slider 0-1 maps to -1 to 1 strength
        return EffectEngine().buildVibranceMatrix((_adjustValue - 0.5) * 2);
      } else if (_activeSubTool == EditorSubTool.skinTone) {
        // Skin tone: slider 0-1 maps to -1 to 1 strength
        final shift = (_adjustValue - 0.5) * 2;
        final rBoost = shift * 0.08;
        final gBoost = shift * 0.04;
        final bBoost = -shift * 0.08;
        return <double>[
          1,
          0,
          0,
          0,
          rBoost,
          0,
          1,
          0,
          0,
          gBoost,
          0,
          0,
          1,
          0,
          bBoost,
          0,
          0,
          0,
          1,
          0,
        ];
      }
    }
    return null;
  }

  Future<void> _confirmCurrentTool({dynamic subEditor}) async {
    final ed = _editorKey.currentState;
    debugPrint(
      '[Confirm] _confirmCurrentTool called. activeTool=$_activeTool, activeSubTool=$_activeSubTool, ed=$ed',
    );
    if (ed == null) return;

    if (_activeTool == EditorTool.sticker) {
      _lockAllWidgetLayers();
      _stickerPickerKey.currentState?.clearSelection();
      _unconfirmedStickers.clear();
      _resetStateAfterToolClosed();
      return;
    }

    final isPackageTool =
        _activeTool == EditorTool.crop ||
        _activeTool == EditorTool.text ||
        _activeTool == EditorTool.doodle ||
        _activeTool == EditorTool.shape ||
        _activeTool == EditorTool.filters ||
        _activeTool == EditorTool.retouch;

    // NOTE: We must capture the paint editor's body size BEFORE calling
    // `subEditor.done()` (or `paintEditor.currentState?.done()`), because
    // the paint editor is destroyed during `done()` and the body size is
    // only valid while it's still mounted.  The bake function (which runs
    // from the `.then(...)` of `openPaintEditor()`) needs this size to map
    // the layer's body-space offset into the image's pixel space.
    // Implementation is in [_capturePaintEditorBodySize].

    if (subEditor != null && isPackageTool) {
      try {
        _capturePaintEditorBodySize(subEditor, ed);
        subEditor.done();
      } catch (e) {
        debugPrint('Error confirming subEditor: $e');
      }
      return;
    } else if (isPackageTool) {
      if (_activeTool == EditorTool.shape || _activeTool == EditorTool.doodle) {
        // Lock all paint layers before calling done to prevent movement after tick
        _lockAllPaintLayers();
        _capturePaintEditorBodySize(subEditor, ed);
        ed.paintEditor.currentState?.done();
      } else if (_activeTool == EditorTool.crop) {
        ed.cropRotateEditor.currentState?.done();
      } else if (_activeTool == EditorTool.text) {
        ed.textEditor.currentState?.done();
      } else if (_activeTool == EditorTool.filters) {
        ed.filterEditor.currentState?.done();
      }
      return;
    }

    if (_activeTool == EditorTool.bg &&
        _activeSubTool == EditorSubTool.bgRemove) {
      // Immediate online trigger, confirm redundant
    } else if (_activeTool == EditorTool.bg &&
        _activeSubTool == EditorSubTool.bgBlur) {
      // Immediate online trigger, confirm redundant
    } else if (_activeTool == EditorTool.adjust &&
        _activeSubTool == EditorSubTool.curves) {
      context.read<ImageEditorBloc>().add(
        ImageEditorApplyCurves(ed, _curvesData.copy()),
      );
    } else if (_activeTool == EditorTool.adjust &&
        _activeSubTool == EditorSubTool.hsl) {
      final adjustments = List<Map<String, double>>.generate(
        7,
        (i) => Map<String, double>.from(_hslAdjustments[i]),
      );
      context.read<ImageEditorBloc>().add(
        ImageEditorApplySelectiveHSL(ed, adjustments),
      );
    } else if (_activeTool == EditorTool.adjust &&
        const {
          'grain',
          'vignette',
          'sharpen',
          'denoise',
          'clarity',
          'vibrance',
          'skinTone',
        }.contains(_activeSubTool.name)) {
      debugPrint(
        '[Adjust] Dispatching pixel effect: ${_activeSubTool.name}, strength: $_adjustValue',
      );
      context.read<ImageEditorBloc>().add(
        ImageEditorApplyPixelEffect(ed, _activeSubTool.name, _adjustValue),
      );
    } else if (_activeTool == EditorTool.effect) {
      context.read<ImageEditorBloc>().add(ImageEditorConfirmOverlay(ed));
    } else if (_activeTool == EditorTool.frames) {
      if (_selectedFrameUrl != null) {
        context.read<ImageEditorBloc>().add(
          ImageEditorConfirmFrame(ed, _selectedFrameUrl!),
        );
      }
    } else if (_activeTool == EditorTool.selective ||
        (_activeTool == EditorTool.shape &&
            _activeSubTool == EditorSubTool.hsl)) {
      context.read<ImageEditorBloc>().add(ImageEditorConfirmCircle(ed));
    } else if (_activeTool == EditorTool.retouch) {
      context.read<ImageEditorBloc>().add(
        ImageEditorApplyRetouch(ed, _adjustValue),
      );
    } else {
      final matrix = _getLiveMatrix();
      debugPrint(
        '[Adjust] Matrix tool: ${_activeSubTool.name}, matrix: ${matrix != null ? "not null" : "null"}',
      );
      if (matrix != null) {
        context.read<ImageEditorBloc>().add(
          ImageEditorApplyColorMatrix(ed, matrix),
        );
      }
    }

    _resetSubToolStateAndKeepPanel();
  }

  void _resetSubToolStateAndKeepPanel() {
    if (!mounted) return;
    _resetBlocSubEditorModes();
    _disposeHslPreview();
    _disposeGrainPreview();
    _disposeCurvesPreview();
    setState(() {
      _curvesData = CurvesData();
      _activeSubTool = EditorSubTool.none;
      _selectedFilterMatrix = null;
      _selectedFilterIndex = 0;
      _selectedFrameUrl = null;
      _adjustValue = AppEditorConstants.defaultSliderValue;
      for (var adj in _hslAdjustments) {
        adj['hue'] = AppEditorConstants.defaultSliderValue;
        adj['saturation'] = AppEditorConstants.defaultSliderValue;
        adj['luminance'] = AppEditorConstants.defaultSliderValue;
      }
    });
    // Reset zoom/pan when applying tool
    _editorKey.currentState?.interactiveViewer.currentState?.reset();
  }

  void _cancelCurrentTool({dynamic subEditor}) {
    if (!mounted) return;

    final isPackageTool =
        _activeTool == EditorTool.doodle ||
        _activeTool == EditorTool.text ||
        _activeTool == EditorTool.crop ||
        _activeTool == EditorTool.shape ||
        _activeTool == EditorTool.sticker ||
        _activeTool == EditorTool.filters ||
        _activeTool == EditorTool.retouch;

    if (subEditor != null && isPackageTool) {
      try {
        subEditor.close();
      } catch (e) {
        debugPrint('Error closing subEditor: $e');
      }
      return;
    }

    if (_activeTool == EditorTool.shape || _activeTool == EditorTool.doodle) {
      _editorKey.currentState?.paintEditor.currentState?.close();
      return;
    } else if (_activeTool == EditorTool.crop) {
      _editorKey.currentState?.cropRotateEditor.currentState?.close();
      return;
    } else if (_activeTool == EditorTool.text) {
      _editorKey.currentState?.textEditor.currentState?.close();
      return;
    } else if (_activeTool == EditorTool.filters) {
      _editorKey.currentState?.filterEditor.currentState?.close();
      return;
    }

    if (_activeTool == EditorTool.sticker) {
      final ed = _editorKey.currentState;
      if (ed != null) {
        _stickerPickerKey.currentState?.cancelCurrentSticker();
      }
      _unconfirmedStickers.clear();
      _stickerPickerKey.currentState?.clearSelection();
    }

    _resetStateAfterToolClosed();
  }

  void _resetStateAfterToolClosed() {
    if (!mounted) return;
    _resetBlocSubEditorModes();
    // Close the bottom panel when tool is closed
    _panelCtrl.reverse();
    _disposeHslPreview();
    _disposeGrainPreview();
    _disposeCurvesPreview();
    setState(() {
      _curvesData = CurvesData();
      _activeTool = EditorTool.none;
      _activeSubTool = EditorSubTool.none;
      _selectedFilterMatrix = null;
      _selectedFilterIndex = 0;
      _selectedFrameUrl = null;
      for (var adj in _hslAdjustments) {
        adj['hue'] = AppEditorConstants.defaultSliderValue;
        adj['saturation'] = AppEditorConstants.defaultSliderValue;
        adj['luminance'] = AppEditorConstants.defaultSliderValue;
      }
    });
    // Reset zoom/pan when closing tool
    _editorKey.currentState?.interactiveViewer.currentState?.reset();
  }

  /// Captures the paint editor's body size at the moment the user taps
  /// the tick button. The paint editor has a different body size than
  /// the main editor (because it has its own app bar / bottom panel),
  /// so the bake function (see [_bakePaintLayersIntoImage]) needs the
  /// *paint* editor's body to convert the layer's body-space offset
  /// into the image's pixel space correctly.
  ///
  /// Must be called BEFORE `subEditor.done()` (or
  /// `paintEditor.currentState?.done()`), because the paint editor is
  /// destroyed during `done()` and the body size is only valid while
  /// it's still mounted.
  void _capturePaintEditorBodySize(dynamic subEditor, ProImageEditorState ed) {
    if (_activeTool != EditorTool.shape && _activeTool != EditorTool.doodle) {
      _paintEditorBodySize = null;
      return;
    }
    try {
      // Prefer reading the live subEditor (when the bottom panel is the
      // source of the tick) — it carries the freshest constraints.
      final dynamic state = subEditor ?? ed.paintEditor.currentState;
      final dynamic body = state?.editorBodySize;
      if (body is Size && body.width > 0 && body.height > 0) {
        _paintEditorBodySize = body;
      }
    } catch (_) {
      // The field is only present on PaintEditorState; ignore on others.
    }
  }

  /// Locks every TextLayer in the editor so it cannot be moved, scaled,
  /// rotated, selected, or re-edited after placement.
  void _lockAllTextLayers() {
    final ed = _editorKey.currentState;
    if (ed == null) return;
    final lockedInteraction = LayerInteraction.fromDefaultValue(false);
    for (int i = 0; i < ed.activeLayers.length; i++) {
      final layer = ed.activeLayers[i];
      if (layer is TextLayer) {
        ed.replaceLayer(
          index: i,
          layer: layer..interaction = lockedInteraction,
        );
      }
    }
  }

  /// Locks every PaintLayer in the editor so doodles/shapes cannot be moved,
  /// scaled, rotated, selected, or re-edited after placement.
  void _lockAllPaintLayers() {
    final ed = _editorKey.currentState;
    if (ed == null) return;
    final lockedInteraction = LayerInteraction.fromDefaultValue(false);
    for (int i = 0; i < ed.activeLayers.length; i++) {
      final layer = ed.activeLayers[i];
      if (layer is PaintLayer) {
        ed.replaceLayer(
          index: i,
          layer: layer..interaction = lockedInteraction,
        );
      }
    }
  }

  /// Locks every WidgetLayer in the editor so stickers cannot be moved, scaled,
  /// rotated, selected, or re-edited after placement.
  void _lockAllWidgetLayers() {
    final ed = _editorKey.currentState;
    if (ed == null) return;
    final lockedInteraction = LayerInteraction.fromDefaultValue(false);
    for (int i = 0; i < ed.activeLayers.length; i++) {
      final layer = ed.activeLayers[i];
      if (layer is WidgetLayer) {
        ed.replaceLayer(
          index: i,
          layer: layer..interaction = lockedInteraction,
        );
      }
    }
  }

  void _resetBlocSubEditorModes() {
    if (!mounted) return;
    final bloc = context.read<ImageEditorBloc>();
    final blocState = bloc.state;

    if (blocState.isCircleSelecting) {
      bloc.add(const ImageEditorToggleCircleMode(value: false));
    }
    if (blocState.isOverlaySelecting) {
      bloc.add(const ImageEditorToggleOverlayMode(value: false));
    }
    if (blocState.isBgBlurSelecting) {
      final ed = _editorKey.currentState;
      if (ed != null) {
        bloc.add(ImageEditorToggleBgBlurMode(ed, value: false));
      }
    }
    if (blocState.isBgRemoveSelecting) {
      final ed = _editorKey.currentState;
      if (ed != null) {
        bloc.add(ImageEditorToggleBgRemoveMode(ed, value: false));
      }
    }
  }

  void _handleShowOriginal(bool show) {
    _showOriginalTimer?.cancel();
    context.read<ImageEditorBloc>().add(ImageEditorSetShowOriginal(show));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _panelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 0.0,
    );
    _panelCtrl.addListener(() {
      final expanded = _panelCtrl.value > 0.5;
      if (expanded != _panelExpanded) {
        setState(() => _panelExpanded = expanded);
      }
    });
    // ISSUE #4 FIX: Purge orphaned editor temp files from previous sessions
    // to prevent indefinite storage bloat on the device.
    unawaited(_cleanEditorTempFiles());
  }

  @override
  void didChangeMetrics() {
    final bottom = WidgetsBinding
        .instance
        .platformDispatcher
        .views
        .first
        .viewInsets
        .bottom;
    final isVisible = bottom > 0;
    if (_keyboardVisible != isVisible) {
      setState(() {
        _keyboardVisible = isVisible;
      });
    }
  }

  /// Deletes leftover temporary image files created by the editor in previous
  /// sessions.  Only files that match known editor prefixes are removed so
  /// other app temp files are left untouched.
  Future<void> _cleanEditorTempFiles() async {
    try {
      final dir = await getTemporaryDirectory();
      const editorPrefixes = [
        'circle_',
        'overlay_',
        'adjust_',
        'hsl_',
        'curves_',
        'rembg_preview_',
        'change_bg_',
        'history_',
        'grain_',
        'vignette_',
        'sharpen_',
        'denoise_',
        'clarity_',
        'vibrance_',
        'skinTone_',
        'edit_',
      ];
      final entities = dir.listSync();
      for (final entity in entities) {
        if (entity is File) {
          final name = entity.uri.pathSegments.last;
          final isEditorFile = editorPrefixes.any(
            (prefix) => name.startsWith(prefix),
          );
          if (isEditorFile) {
            try {
              await entity.delete();
            } catch (_) {
              /* ignore individual file errors */
            }
          }
        }
      }
      debugPrint('🗑️  [ImageEditorPage] Editor temp files purged.');
    } catch (e) {
      debugPrint('⚠️ [ImageEditorPage] Failed to clean temp files: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _showOriginalTimer?.cancel();
    _panelCtrl.dispose();
    _panelScrollCtrl.dispose();
    _disposeHslPreview();
    _disposeCurvesPreview();
    _disposeGrainPreview();
    super.dispose();
  }

  bool _isDialogShowing = false;

  void _showDiscardDialog() {
    if (_isDialogShowing) return;
    _isDialogShowing = true;
    final isDark = _isDark;
    final w = MediaQuery.of(context).size.width;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: EdgeInsets.all(w * 0.05),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF202020) : Colors.white,
            borderRadius: BorderRadius.circular(w * 0.05),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.black12,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 15,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(w * 0.04),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.redAccent,
                  size: w * 0.1,
                ),
              ),
              SizedBox(height: w * 0.04),
              Text(
                'Discard Changes?',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: w * 0.05,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: w * 0.02),
              Text(
                'Are you sure you want to exit the editor? Any unsaved edits will be lost.',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: w * 0.038,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: w * 0.06),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(
                          color: isDark ? Colors.white30 : Colors.black26,
                        ),
                        padding: EdgeInsets.symmetric(vertical: w * 0.035),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(w * 0.03),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: w * 0.04,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: w * 0.03),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        if (mounted) Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: w * 0.035),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(w * 0.03),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Discard',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: w * 0.04,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      _isDialogShowing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ImageEditorBloc, ImageEditorState>(
      listenWhen: (p, c) =>
          (c.message != null && c.message != p.message) ||
          (c.closeToolTrigger && !p.closeToolTrigger),
      listener: (ctx, state) {
        if (state.message != null) {
          showThemedDialog(
            ctx,
            title: 'Notice',
            message: state.message!,
            icon: Icons.info_outline,
            iconColor: Colors.blue,
          );
          if (state.message == 'Background removed!' ||
              state.message == 'Background blurred!') {
            setState(() {
              _activeSubTool = EditorSubTool.none;
            });
          }
        }
        if (state.closeToolTrigger) {
          _resetStateAfterToolClosed();
        }
      },
      child: BlocBuilder<ImageEditorBloc, ImageEditorState>(
        builder: (ctx, state) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_isHandlingBack) return;
            _isHandlingBack = true;
            if (_activeTool != EditorTool.none) {
              _cancelCurrentTool(subEditor: null);
            } else {
              _showDiscardDialog();
            }
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) _isHandlingBack = false;
            });
          },
          child: Scaffold(
            backgroundColor: _isDark ? const Color(0xFF161616) : Colors.white,
            body: Stack(
              fit: StackFit.expand,
              children: [
                _buildEditor(context, state),
                if (_activeTool == EditorTool.none) ...[
                  EditorTopBar(
                    isDark: _isDark,
                    onBack: _showDiscardDialog,
                    canUndo: state.canUndo,
                    canRedo: state.canRedo,
                    isProcessing: state.isProcessing,
                    onUndo: () {
                      final ed = _editorKey.currentState;
                      if (ed != null) {
                        context.read<ImageEditorBloc>().add(
                          ImageEditorUndo(ed),
                        );
                      }
                    },
                    onRedo: () {
                      final ed = _editorKey.currentState;
                      if (ed != null) {
                        context.read<ImageEditorBloc>().add(
                          ImageEditorRedo(ed),
                        );
                      }
                    },
                    onReset: () {
                      final ed = _editorKey.currentState;
                      if (ed != null) {
                        context.read<ImageEditorBloc>().add(
                          ImageEditorReset(ed),
                        );
                      }
                    },
                    onDone: () => _editorKey.currentState?.doneEditing(),
                  ),
                  EditorCompareButton(
                    isDark: _isDark,
                    showOriginal: state.showOriginal,
                    onCompareChanged: _handleShowOriginal,
                    panelHeight:
                        _calcPanelHeight(context) +
                        MediaQuery.of(context).padding.bottom,
                  ),
                ],
                if (!_isPackageEditorActive) _buildBottomPanel(context, state),
                if (state.isProcessing)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withAlpha(100),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: AppEditorConstants.accent,
                        ),
                      ),
                    ),
                  ),
                // Show a dedicated overlay while we rasterize paint layers
                // into the background image.  We don't reuse state.isProcessing
                // because the bake runs locally on the page state, not via
                // the bloc, and we want the indicator up the moment the
                // paint editor closes so the user gets immediate feedback.
                if (_isBakingPaint)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        color: Colors.black.withAlpha(100),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppEditorConstants.accent,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(BuildContext context, ImageEditorState state) {
    final isDark = _isDark;
    return AnimatedBuilder(
      animation: _panelCtrl,
      builder: (animCtx, _) {
        final isPaintTool =
            _activeTool == EditorTool.shape || _activeTool == EditorTool.doodle;
        final collapsedH = isPaintTool
            ? 0.0
            : _calcPanelHeight(animCtx, expanded: false) +
                  MediaQuery.of(animCtx).padding.bottom;
        // When a tool panel is open we compress the image area from
        // both sides: the panel already occupies the bottom, and we now add
        // a top inset so the image fits entirely in the space between the
        // status bar and the panel.  ProImageEditor uses BoxFit.contain
        // internally so the image automatically scales down to fill the
        // smaller container — creating the "zoom out & push up" effect.
        final isToolActive = _activeTool != EditorTool.none;
        final statusBarH = MediaQuery.of(animCtx).padding.top;
        // Add a small extra buffer (8 px) so the image doesn't press right
        // against the status bar when a tool is open.
        final topPad = isToolActive ? statusBarH + 8.0 : 0.0;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          padding: EdgeInsets.only(top: topPad, bottom: collapsedH),
          child: ProImageEditor.file(
            state.imageFile,
            key: _editorKey,
            callbacks: ProImageEditorCallbacks(
              onImageEditingComplete: (Uint8List bytes) async {
                final dir = await getTemporaryDirectory();
                final file = File(
                  '${dir.path}/edit_${DateTime.now().millisecondsSinceEpoch}.png',
                );
                await file.writeAsBytes(bytes);
                if (mounted) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            AIResultScreen(resultImageUrl: file.path),
                      ),
                    );
                  });
                }
              },
              mainEditorCallbacks: MainEditorCallbacks(
                onAfterViewInit: () {
                  _editorKey.currentState?.isPopScopeDisabled = true;
                },
              ),
            ),
            configs: ProImageEditorConfigs(
              designMode: ImageEditorDesignMode.material,
              layerInteraction: LayerInteractionConfigs(
                selectable: _activeTool == EditorTool.frames
                    ? LayerInteractionSelectable.disabled
                    : LayerInteractionSelectable.auto,
                enableMobilePinchRotate: _activeTool != EditorTool.frames,
                enableMobilePinchScale: _activeTool != EditorTool.frames,
              ),
              theme: Theme.of(context).copyWith(
                canvasColor: Theme.of(context).scaffoldBackgroundColor,
                scaffoldBackgroundColor: isDark
                    ? const Color(0xFF161616)
                    : Colors.white,
                colorScheme: isDark
                    ? const ColorScheme.dark(
                        primary: AppEditorConstants.accent,
                        secondary: AppEditorConstants.accent,
                        surface: AppEditorConstants.darkPanelBg,
                      )
                    : const ColorScheme.light(
                        primary: AppEditorConstants.accent,
                        secondary: AppEditorConstants.accent,
                        surface: AppEditorConstants.lightPanelBg,
                      ),
                iconTheme: IconThemeData(
                  color: AppEditorConstants.primaryText(isDark),
                ),
                appBarTheme: AppBarTheme(
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppEditorConstants.primaryText(isDark),
                  elevation: 0,
                ),
                bottomAppBarTheme: const BottomAppBarThemeData(
                  color: Colors.transparent,
                  elevation: 0,
                ),
                bottomSheetTheme: const BottomSheetThemeData(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                ),
                sliderTheme: SliderThemeData(
                  activeTrackColor: AppEditorConstants.accent,
                  thumbColor: AppEditorConstants.accent,
                  inactiveTrackColor: isDark ? Colors.white24 : Colors.black12,
                  overlayColor: AppEditorConstants.accent.withAlpha(30),
                ),
              ),
              mainEditor: MainEditorConfigs(
                enableZoom:
                    _activeTool == EditorTool.frames ||
                    _activeTool == EditorTool.selective,
                editorMinScale: _activeTool == EditorTool.frames ? 0.1 : 1.0,
                boundaryMargin:
                    _activeTool == EditorTool.frames ||
                        _activeTool == EditorTool.selective
                    ? const EdgeInsets.all(double.infinity)
                    : EdgeInsets.zero,
                style: MainEditorStyle(
                  background: isDark ? const Color(0xFF161616) : Colors.white,
                  bottomBarBackground: Colors.transparent,
                ),
                widgets: MainEditorWidgets(
                  appBar: (editor, rebuildStream) => ReactiveAppbar(
                    stream: rebuildStream,
                    builder: (_) => const PreferredSize(
                      preferredSize: Size.zero,
                      child: SizedBox.shrink(),
                    ),
                  ),
                  bottomBar: (editor, rebuildStream, key) => ReactiveWidget(
                    stream: rebuildStream,
                    builder: (_) => const SizedBox.shrink(),
                  ),
                  wrapBody: (editor, rebuildStream, content) {
                    return BlocBuilder<ImageEditorBloc, ImageEditorState>(
                      builder: (blocCtx, state) {
                        return LayoutBuilder(
                          builder: (layoutCtx, constraints) {
                            if (state.containerSize != constraints.biggest &&
                                mounted) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                blocCtx.read<ImageEditorBloc>().add(
                                  ImageEditorUpdateContainerSize(
                                    constraints.biggest,
                                  ),
                                );
                              });
                            }

                            final imgAR = state.imageAspectRatio > 0
                                ? state.imageAspectRatio
                                : 1.0;
                            final conAR =
                                constraints.maxWidth / constraints.maxHeight;

                            Size renderedSize = Size.zero;
                            if (imgAR > conAR) {
                              renderedSize = Size(
                                constraints.maxWidth,
                                constraints.maxWidth / imgAR,
                              );
                            } else {
                              renderedSize = Size(
                                constraints.maxHeight * imgAR,
                                constraints.maxHeight,
                              );
                            }

                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                if (state.isBgBlurSelecting &&
                                    state.bgBlurBackgroundImage != null &&
                                    state.bgBlurForegroundImage != null)
                                  Positioned.fill(
                                    child: CustomPaint(
                                      painter: _BgBlurPainter(
                                        backgroundImage:
                                            state.bgBlurBackgroundImage!,
                                        foregroundImage:
                                            state.bgBlurForegroundImage!,
                                        intensity: state.bgBlurIntensity,
                                        sourceSize: state.bgBlurSourceSize,
                                      ),
                                    ),
                                  )
                                else
                                  Builder(
                                    builder: (builderCtx) {
                                      Widget previewContent = content;

                                      if (_activeTool == EditorTool.selective) {
                                        final selMatrix = EffectEngine()
                                            .buildColorMatrix(
                                              (state.circleBrightness - 0.5) *
                                                  2,
                                              (state.circleContrast - 0.5) * 2,
                                              (state.circleSaturation - 0.5) *
                                                  2,
                                              (state.circleHue - 0.5) * 360,
                                            );

                                        previewContent = Stack(
                                          children: [
                                            previewContent,
                                            Positioned.fill(
                                              child: ClipPath(
                                                clipper: _CircleClipper(
                                                  center: state.circleCenter,
                                                  radius: state.circleRadius,
                                                  editInside:
                                                      state.editInsideCircle,
                                                ),
                                                child: Builder(
                                                  builder: (context) {
                                                    final colorFilter =
                                                        ColorFilter.matrix(
                                                          selMatrix,
                                                        );
                                                    final ui.ImageFilter
                                                    finalFilter;
                                                    if (state.circleBlur > 0) {
                                                      finalFilter = ui.ImageFilter.compose(
                                                        outer: colorFilter,
                                                        inner: ui.ImageFilter.blur(
                                                          sigmaX:
                                                              state.circleBlur *
                                                              30,
                                                          sigmaY:
                                                              state.circleBlur *
                                                              30,
                                                          tileMode:
                                                              ui.TileMode.decal,
                                                        ),
                                                      );
                                                    } else {
                                                      finalFilter = colorFilter;
                                                    }
                                                    return BackdropFilter(
                                                      filter: finalFilter,
                                                      child:
                                                          const SizedBox.expand(),
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }

                                      // ── Live preview for Curves ──
                                      if (_activeTool == EditorTool.adjust &&
                                          _activeSubTool ==
                                              EditorSubTool.curves) {
                                        if (_curvesPreviewImage != null) {
                                          previewContent = Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              previewContent,
                                              Positioned.fill(
                                                child: RawImage(
                                                  image: _curvesPreviewImage,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ],
                                          );
                                        } else {
                                          previewContent = const Center(
                                            child: CircularProgressIndicator(),
                                          );
                                        }
                                      }

                                      // ── Live preview for HSL per-pixel tool ──
                                      if (_activeSubTool == EditorSubTool.hsl &&
                                          _hslPreviewImage != null) {
                                        previewContent = Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            previewContent,
                                            Positioned.fill(
                                              child: RawImage(
                                                image: _hslPreviewImage,
                                                fit: BoxFit.contain,
                                              ),
                                            ),
                                          ],
                                        );
                                      }

                                      // ── Live preview for matrix tools ──
                                      final matrix = _getLiveMatrix();
                                      if (matrix != null) {
                                        previewContent = ColorFiltered(
                                          colorFilter: ColorFilter.matrix(
                                            matrix,
                                          ),
                                          child: previewContent,
                                        );
                                      }

                                      // ── Live preview for pixel-based tools ──
                                      if (_activeTool == EditorTool.adjust) {
                                        // Vignette: gradient overlay
                                        if (_activeSubTool ==
                                                EditorSubTool.vignette &&
                                            _adjustValue > 0) {
                                          previewContent = Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              previewContent,
                                              Positioned.fill(
                                                child: IgnorePointer(
                                                  child: DecoratedBox(
                                                    decoration: BoxDecoration(
                                                      gradient: RadialGradient(
                                                        center:
                                                            Alignment.center,
                                                        radius: 0.75,
                                                        colors: [
                                                          Colors.transparent,
                                                          Colors.black
                                                              .withAlpha(
                                                                (_adjustValue *
                                                                        220)
                                                                    .toInt(),
                                                              ),
                                                        ],
                                                        stops: const [0.4, 1.0],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }

                                        if (_activeSubTool ==
                                                EditorSubTool.sharpen &&
                                            _adjustValue > 0) {
                                          final contrastBoost =
                                              _adjustValue * 0.45;
                                          final sharpenMatrix = EffectEngine()
                                              .buildColorMatrix(
                                                0.02,
                                                contrastBoost,
                                                -_adjustValue * 0.05,
                                                0,
                                              );
                                          previewContent = ColorFiltered(
                                            colorFilter: ColorFilter.matrix(
                                              sharpenMatrix,
                                            ),
                                            child: previewContent,
                                          );
                                        }

                                        // Grain: Seeded overlay noise on the image canvas directly
                                        if (_activeSubTool ==
                                                EditorSubTool.grain &&
                                            _adjustValue > 0) {
                                          if (_grainPreviewImage != null) {
                                            previewContent = LayoutBuilder(
                                              builder: (context, constraints) {
                                                final fitted = applyBoxFit(
                                                  BoxFit.contain,
                                                  Size(
                                                    _grainPreviewImage!.width
                                                        .toDouble(),
                                                    _grainPreviewImage!.height
                                                        .toDouble(),
                                                  ),
                                                  constraints.biggest,
                                                );
                                                final dstRect = Alignment.center
                                                    .inscribe(
                                                      fitted.destination,
                                                      Offset.zero &
                                                          constraints.biggest,
                                                    );
                                                return CustomPaint(
                                                  painter: GrainPainter(
                                                    strength: _adjustValue,
                                                    image: _grainPreviewImage,
                                                    imageDstRect: dstRect,
                                                  ),
                                                  size: constraints.biggest,
                                                );
                                              },
                                            );
                                          }
                                        }

                                        // Denoise: 3x3 blur approximation
                                        if (_activeSubTool ==
                                                EditorSubTool.denoise &&
                                            _adjustValue > 0) {
                                          final sigma = _adjustValue * 1.5;
                                          previewContent = ImageFiltered(
                                            imageFilter: ui.ImageFilter.blur(
                                              sigmaX: sigma,
                                              sigmaY: sigma,
                                              tileMode: ui.TileMode.decal,
                                            ),
                                            child: previewContent,
                                          );
                                        }

                                        if (_activeSubTool ==
                                                EditorSubTool.clarity &&
                                            _adjustValue > 0) {
                                          final contrastBoost =
                                              _adjustValue * 0.18;
                                          final clarityMatrix = EffectEngine()
                                              .buildColorMatrix(
                                                0,
                                                contrastBoost,
                                                -_adjustValue * 0.02,
                                                0,
                                              );
                                          previewContent = ColorFiltered(
                                            colorFilter: ColorFilter.matrix(
                                              clarityMatrix,
                                            ),
                                            child: previewContent,
                                          );
                                        }
                                      }

                                      Widget finalContent = ClipRect(
                                        clipper: CenterRectClipper(
                                          width: renderedSize.width,
                                          height: renderedSize.height,
                                        ),
                                        child: previewContent,
                                      );
                                      return finalContent;
                                    },
                                  ),
                                if (state.isCircleSelecting)
                                  _buildCircleInteractionLayer(
                                    layoutCtx,
                                    state,
                                  ),
                                if (state.isOverlaySelecting)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: RepaintBoundary(
                                        child: EffectOverlayPreview(
                                          baseImage: null,
                                          targetSize: renderedSize,
                                          overlayImage: state.overlayUiImage,
                                          opacity: state.overlayOpacity,
                                          blendMode:
                                              state.selectedEffect?.blendMode ??
                                              ui.BlendMode.screen,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (state.isOverlayLoading)
                                  const Center(
                                    child: CircularProgressIndicator(
                                      color: AppEditorConstants.accent,
                                    ),
                                  ),
                                if (_activeTool == EditorTool.frames &&
                                    _selectedFrameUrl != null)
                                  Positioned(
                                    left:
                                        (constraints.maxWidth -
                                            renderedSize.width) /
                                        2,
                                    top:
                                        (constraints.maxHeight -
                                            renderedSize.height) /
                                        2,
                                    width: renderedSize.width,
                                    height: renderedSize.height,
                                    child: IgnorePointer(
                                      child: CachedNetworkImage(
                                        imageUrl: _selectedFrameUrl!,
                                        fit: BoxFit.fill,
                                        fadeInDuration: Duration.zero,
                                      ),
                                    ),
                                  ),
                                if (state.isBgRemoveSelecting &&
                                    state.bgRemovePreviewImage != null)
                                  Positioned.fill(
                                    child: RawImage(
                                      image: state.bgRemovePreviewImage,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                if (state.showOriginal)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: Image.file(
                                        state.imageFile,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              textEditor: TextEditorConfigs(
                widgets: TextEditorWidgets(
                  appBar: (editor, rebuildStream) => ReactiveAppbar(
                    stream: rebuildStream,
                    builder: (_) => const PreferredSize(
                      preferredSize: Size.zero,
                      child: SizedBox.shrink(),
                    ),
                  ),
                  // Wrap the text editor body so the image is visible behind
                  // the text field — users can see exactly where text lands.
                  wrapBody: (editorState, rebuildStream, content) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // Show the current image as background
                        Image.file(
                          state.imageFile,
                          fit: BoxFit.contain,
                          gaplessPlayback: true,
                        ),
                        // Semi-transparent dark overlay for contrast when typing
                        Container(color: Colors.black.withValues(alpha: 0.25)),
                        // The text editor content (text field, color picker, etc.)
                        content,
                      ],
                    );
                  },
                  bottomBar: (editor, rebuildStream) => ReactiveWidget(
                    stream: rebuildStream,
                    builder: (context) => Builder(
                      builder: (innerContext) {
                        if (_keyboardVisible) return const SizedBox.shrink();
                        return _buildSubEditorPanelOverlay(
                          editor,
                          rebuildStream,
                          usePositioned: false,
                        );
                      },
                    ),
                  ),
                ),
                initialBackgroundColorMode: LayerBackgroundMode.onlyColor,
                style: TextEditorStyle(
                  // Keep background dark/light so the scaffold color matches;
                  // the image is rendered by wrapBody instead.
                  background: isDark ? const Color(0xFF161616) : Colors.white,
                  appBarBackground: Colors.transparent,
                  bottomBarBackground: Colors.transparent,
                ),
                showTextAlignButton: false,
                showFontScaleButton: false,
                showBackgroundModeButton: false,
                enableMainEditorZoomFactor: false,
                enableTapOutsideToSave: false,
              ),
              cropRotateEditor: CropRotateEditorConfigs(
                style: CropRotateEditorStyle(
                  background: isDark ? const Color(0xFF161616) : Colors.white,
                  bottomBarBackground: Colors.transparent,
                ),
                widgets: CropRotateEditorWidgets(
                  appBar: (editor, rebuildStream) => ReactiveAppbar(
                    stream: rebuildStream,
                    builder: (_) => const PreferredSize(
                      preferredSize: Size.zero,
                      child: SizedBox.shrink(),
                    ),
                  ),
                  bottomBar: (editor, rebuildStream) => ReactiveWidget(
                    stream: rebuildStream,
                    builder: (context) {
                      if (MediaQuery.of(context).viewInsets.bottom > 0) {
                        return const SizedBox.shrink();
                      }
                      // Use a safe area at the bottom if needed, but CropBottomPanel
                      // handles its own padding.
                      return CropBottomPanel(editor: editor, isDark: isDark);
                    },
                  ),
                ),
                enableGesturePop: false,
                showLayers: true,
                enableDoubleTap: false,
                enableFlipAnimation: false,
                initAspectRatio: 0.0,
              ),
              paintEditor: PaintEditorConfigs(
                safeArea: const EditorSafeArea.none(),
                enableZoom: false,
                style: PaintEditorStyle(
                  background: isDark ? const Color(0xFF161616) : Colors.white,
                  bottomBarBackground: Colors.transparent,
                ),
                initialPaintMode: _activeTool == EditorTool.shape
                    ? PaintMode.circle
                    : PaintMode.freeStyle,
                isInitiallyFilled: _activeTool == EditorTool.shape,
                customPathBuilders: {PaintMode.custom1: triangleBuilder},
                widgets: PaintEditorWidgets(
                  appBar: (editor, rebuildStream) => ReactiveAppbar(
                    stream: rebuildStream,
                    builder: (_) => PreferredSize(
                      preferredSize: Size.fromHeight(topPad),
                      child: const SizedBox.shrink(),
                    ),
                  ),
                  bodyItems: (editor, rebuildStream) => [],
                  bottomBar: (editor, rebuildStream) => ReactiveWidget(
                    stream: rebuildStream,
                    builder: (context) {
                      if (MediaQuery.of(context).viewInsets.bottom > 0) {
                        return const SizedBox.shrink();
                      }
                      return _buildSubEditorPanelOverlay(
                        editor,
                        rebuildStream,
                        usePositioned: false,
                      );
                    },
                  ),
                ),
                tools: _activeTool == EditorTool.doodle
                    ? const [PaintMode.freeStyle, PaintMode.eraser]
                    : const [
                        PaintMode.circle,
                        PaintMode.rect,
                        PaintMode.arrow,
                        PaintMode.line,
                        PaintMode.dashLine,
                        PaintMode.dashDotLine,
                        PaintMode.hexagon,
                        PaintMode.polygon,
                        PaintMode.eraser,
                        PaintMode.custom1,
                      ],
                enableEdit: true,
                showToggleFillButton: false,
                showLayers: true,
              ),
              filterEditor: FilterEditorConfigs(
                style: FilterEditorStyle(
                  background: isDark ? const Color(0xFF161616) : Colors.white,
                ),
                widgets: FilterEditorWidgets(
                  appBar: (editor, rebuildStream) => ReactiveAppbar(
                    stream: rebuildStream,
                    builder: (_) => const PreferredSize(
                      preferredSize: Size.zero,
                      child: SizedBox.shrink(),
                    ),
                  ),
                  bodyItems: (editor, rebuildStream) => [
                    ReactiveWidget(
                      stream: rebuildStream,
                      builder: (context) => _buildSubEditorPanelOverlay(
                        editor,
                        rebuildStream,
                        usePositioned: true,
                      ),
                    ),
                  ],
                  bottomBar: (editor, rebuildStream) => ReactiveWidget(
                    stream: rebuildStream,
                    builder: (context) {
                      if (MediaQuery.of(context).viewInsets.bottom > 0) {
                        return const SizedBox.shrink();
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                enableGesturePop: false,
                showLayers: true,
              ),
              emojiEditor: const EmojiEditorConfigs(enableGesturePop: false),
              stickerEditor: StickerEditorConfigs(
                style: const StickerEditorStyle(
                  showDragHandle: false,
                  bottomSheetBackgroundColor: Colors.transparent,
                ),
                builder: (setLayer, scrollController) {
                  return AnnotatedRegion<SystemUiOverlayStyle>(
                    value: SystemUiOverlayStyle.light,
                    child: Scaffold(
                      backgroundColor: Colors.transparent,
                      appBar: const PreferredSize(
                        preferredSize: Size.zero,
                        child: SizedBox.shrink(),
                      ),
                      body: Stack(
                        children: [
                          Positioned.fill(
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(color: Colors.transparent),
                            ),
                          ),
                          _buildSubEditorPanelOverlay(
                            _StickerEditorProxy(
                              setLayer,
                              context,
                              editorState: _editorKey.currentState,
                            ),
                            const Stream.empty(),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  double _calcPanelHeight(BuildContext context, {bool? expanded}) {
    final screenH = MediaQuery.of(context).size.height;
    final isExpanded = expanded ?? (_panelCtrl.value > 0.5);
    double h = 0;

    if (_activeTool == EditorTool.none) {
      h = screenH * (isExpanded ? 0.30 : 0.20);
    } else {
      if (_activeTool == EditorTool.adjust) {
        if (_activeSubTool == EditorSubTool.curves) {
          h = screenH * (isExpanded ? 0.55 : 0.50);
        } else if (_activeSubTool == EditorSubTool.hsl) {
          h = screenH * (isExpanded ? 0.55 : 0.50);
        } else if (_activeSubTool == EditorSubTool.none) {
          h = screenH * (isExpanded ? 0.40 : 0.35);
        } else {
          h = screenH * (isExpanded ? 0.45 : 0.40);
        }
      } else if (_activeTool == EditorTool.bg) {
        h = screenH * 0.35;
      } else if (_activeTool == EditorTool.doodle ||
          _activeTool == EditorTool.shape) {
        h = screenH * (_activeTool == EditorTool.doodle ? 0.42 : 0.48);
      } else if (_activeTool == EditorTool.selective) {
        h = screenH * 0.55;
      } else if (_activeTool == EditorTool.filters) {
        h = screenH * 0.38;
      } else if (_activeTool == EditorTool.effect) {
        h = screenH * 0.50;
      } else if (_activeTool == EditorTool.crop) {
        h = screenH * 0.35;
      } else if (_activeTool == EditorTool.text) {
        h = screenH * (isExpanded ? 0.55 : 0.40);
      } else if (_activeTool == EditorTool.sticker) {
        h = screenH * (isExpanded ? 0.55 : 0.45);
      } else {
        h = screenH * 0.35;
      }

      if (isExpanded &&
          _activeTool != EditorTool.adjust &&
          _activeTool != EditorTool.text &&
          _activeTool != EditorTool.sticker) {
        h = h * 1.2;
      }
    }

    // Safeguard to ensure panel height never exceeds 75% of screen height
    if (h > screenH * 0.75) {
      h = screenH * 0.75;
    }
    return h;
  }

  Widget _buildBottomPanel(
    BuildContext context,
    ImageEditorState state, {
    dynamic subEditor,
    Stream<void>? rebuildStream,
    bool usePositioned = true,
  }) {
    final isDark = _isDark;
    return EditorBottomPanel(
      isDark: isDark,
      panelController: _panelCtrl,
      panelExpanded: _panelExpanded,
      collapsedHeight: _calcPanelHeight(context, expanded: false),
      expandedHeight: _calcPanelHeight(context, expanded: true),
      usePositioned: usePositioned,
      child: ReactiveWidget(
        stream: rebuildStream ?? const Stream.empty(),
        builder: (_) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                if (_activeTool != EditorTool.none)
                  EditorPanelHeader(
                    isDark: isDark,
                    onConfirm: () => _confirmCurrentTool(subEditor: subEditor),
                    onCancel: () => _cancelCurrentTool(subEditor: subEditor),
                  ),
                EditorPanelHandle(
                  isDark: isDark,
                  panelController: _panelCtrl,
                  onTap: () {
                    if (_panelCtrl.value > 0.5) {
                      _panelCtrl.animateTo(0.0, curve: Curves.easeOut);
                    } else {
                      _panelCtrl.animateTo(1.0, curve: Curves.easeOut);
                    }
                  },
                ),
              ],
            ),
            // Show undo/redo/reset row for all active tools EXCEPT:
            //  - text  → manages its own done/cancel flow
            //  - crop  → has its own undo/redo/reset inside CropBottomPanel
            //  - filters → applied immediately; no in-panel undo needed
            if (_activeTool != EditorTool.none &&
                _activeTool != EditorTool.text &&
                _activeTool != EditorTool.crop &&
                _activeTool != EditorTool.filters &&
                _activeTool != EditorTool.selective) ...[
              SizedBox(height: MediaQuery.of(context).size.height * 0.01),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (subEditor != null) ...[
                    EditorActionBtn(
                      icon: Icons.undo,
                      onTap: () {
                        try {
                          (subEditor as dynamic).undoAction();
                        } catch (_) {
                          // Action not supported by this sub-editor
                        }
                      },
                      isDark: isDark,
                    ),
                    SizedBox(width: AppEditorConstants.w(context, 0.04)),
                    EditorActionBtn(
                      icon: Icons.redo,
                      onTap: () {
                        try {
                          (subEditor as dynamic).redoAction();
                        } catch (_) {
                          // Action not supported by this sub-editor
                        }
                      },
                      isDark: isDark,
                    ),
                    SizedBox(width: AppEditorConstants.w(context, 0.04)),
                  ],
                  EditorActionBtn(
                    icon: Icons.rotate_right,
                    onTap: () {
                      setState(() {
                        if (subEditor == null) {
                          // Reset local UI state for custom tool panels
                          _activeSubTool = EditorSubTool.none;
                          _adjustValue = AppEditorConstants.defaultSliderValue;
                          _curvesData = CurvesData();
                          _disposeHslPreview();
                          _disposeCurvesPreview();
                          _disposeGrainPreview();

                          // Reset all panel state variables to default
                          _sizeValue = AppEditorConstants.defaultSizeValue;
                          _strokeValue = AppEditorConstants.defaultStrokeValue;
                          _opacityValue =
                              AppEditorConstants.defaultOpacityValue;
                          _paintColor = Colors.white;
                          _selectedEffectTab = 'Butterfly';
                          _selectedFrameUrl = null;
                          _selectedFilterMatrix = null;
                          _selectedFilterIndex = 0;
                          _selectedFontFamily = 'Roboto';
                          _textColor = Colors.white;
                          _textOpacity = 1.0;
                          _textAlign = TextAlign.center;
                          _isBold = false;
                          _isItalic = false;
                          _isUnderlined = false;
                          _selectedHslColorIndex = 0;
                          for (var adj in _hslAdjustments) {
                            adj['hue'] = AppEditorConstants.defaultSliderValue;
                            adj['saturation'] =
                                AppEditorConstants.defaultSliderValue;
                            adj['luminance'] =
                                AppEditorConstants.defaultSliderValue;
                          }

                          if (_activeTool == EditorTool.sticker) {
                            final ed = _editorKey.currentState;
                            if (ed != null) {
                              final layersToRemove = ed.activeLayers
                                  .where(
                                    (l) =>
                                        l is WidgetLayer &&
                                        l.interaction.enableMove,
                                  )
                                  .toList();
                              for (var layer in layersToRemove) {
                                ed.removeLayer(layer);
                              }
                              _unconfirmedStickers.clear();
                              _stickerPickerKey.currentState?.clearSelection();
                            }
                          }
                        } else {
                          // For sub-editors (doodle/shape), call their reset
                          // or fallback to undoing all actions if reset is not supported
                          try {
                            final dynamic ed = subEditor;
                            try {
                              ed.reset();
                            } on NoSuchMethodError {
                              while (ed.canUndo == true) {
                                ed.undoAction();
                              }
                            }
                          } catch (_) {
                            // Method not supported
                          }
                        }
                      });
                    },
                    isDark: isDark,
                  ),
                ],
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.015),
            ] else
              SizedBox(height: MediaQuery.of(context).size.height * 0.01),
            if (_activeTool == EditorTool.sticker)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppEditorConstants.w(context, 0.04),
                  ),
                  child: _buildControls(state, subEditor: subEditor),
                ),
              )
            else
              Expanded(
                child: SingleChildScrollView(
                  controller: _panelScrollCtrl,
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppEditorConstants.w(context, 0.04),
                      0,
                      AppEditorConstants.w(context, 0.04),
                      12,
                    ),
                    child: _buildControls(state, subEditor: subEditor),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(ImageEditorState state, {dynamic subEditor}) {
    final isDark = _isDark;
    if (_activeTool == EditorTool.none) {
      return EditorToolsGrid(
        tools: AppEditorConstants.mainTools,
        activeTool: _activeTool.name,
        onToolSelected: (tool) => _onToolSelected(tool, subEditor),
        expanded: _panelExpanded,
        isDark: isDark,
      );
    }

    if (_activeTool == EditorTool.adjust) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_activeSubTool == EditorSubTool.curves)
            _buildCurvesControls()
          else if (_activeSubTool == EditorSubTool.hsl)
            _buildHSLControls()
          else if (_activeSubTool != EditorSubTool.none)
            EditorSliderRow(
              label: _subToolLabel(_activeSubTool),
              value: _adjustValue,
              onChanged: (v) => setState(() => _adjustValue = v),
              isDark: isDark,
            ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          // Full-width so the horizontal ListView inside can measure correctly
          EditorSubToolsRow(
            tools: AppEditorConstants.adjustSubTools,
            activeSubTool: _activeSubTool.name,
            onChanged: (v) {
              final newSubTool = EditorSubTool.values.firstWhere(
                (e) => e.name == v,
                orElse: () => EditorSubTool.none,
              );
              setState(() {
                _adjustValue = AppEditorConstants.defaultSliderValue;
                _activeSubTool = newSubTool;
              });
              if (newSubTool == EditorSubTool.hsl) {
                _initHslPreview();
              } else {
                _disposeHslPreview();
              }
              if (newSubTool == EditorSubTool.curves) {
                _initCurvesPreview();
              } else {
                _disposeCurvesPreview();
              }
              if (newSubTool == EditorSubTool.grain) {
                _initGrainPreview();
              } else {
                _disposeGrainPreview();
              }
            },
            isDark: isDark,
          ),
          SizedBox(height: MediaQuery.of(context).size.height * 0.01),
        ],
      );
    }

    if (_activeTool == EditorTool.filters) {
      return EditorFilterThumbnails(
        filters: AppEditorConstants.filters,
        selectedIndex: _selectedFilterIndex,
        onChanged: (i) {
          setState(() {
            _selectedFilterIndex = i;
            _selectedFilterMatrix = AppEditorConstants.filters[i].matrix;
          });
          if (subEditor != null) {
            final matrix = AppEditorConstants.filters[i].matrix;
            if (matrix == null) {
              subEditor.setFilter(PresetFilters.none);
            } else {
              subEditor.setFilter(
                FilterModel(
                  name: AppEditorConstants.filters[i].name,
                  filters: [matrix],
                ),
              );
            }
          }
        },
        imageFile: state.imageFile,
        isDark: isDark,
      );
    }

    if (_activeTool == EditorTool.bg) {
      return Column(
        children: [
          Center(
            child: EditorSubToolsRow(
              tools: AppEditorConstants.bgSubTools,
              activeSubTool: _activeSubTool.name,
              onChanged: (v) {
                final newSubTool = EditorSubTool.values.firstWhere(
                  (e) => e.name == v,
                  orElse: () => EditorSubTool.none,
                );
                setState(() => _activeSubTool = newSubTool);
                if (newSubTool == EditorSubTool.bgBlur) {
                  final ed = _editorKey.currentState;
                  if (ed != null) {
                    context.read<ImageEditorBloc>().add(
                      ImageEditorToggleBgBlurMode(ed, value: true),
                    );
                  }
                } else if (newSubTool == EditorSubTool.bgRemove) {
                  final ed = _editorKey.currentState;
                  if (ed != null) {
                    context.read<ImageEditorBloc>().add(
                      ImageEditorRemoveBackground(ed),
                    );
                  }
                } else {
                  final ed = _editorKey.currentState;
                  if (ed != null) {
                    context.read<ImageEditorBloc>().add(
                      ImageEditorToggleBgBlurMode(ed, value: false),
                    );
                    context.read<ImageEditorBloc>().add(
                      ImageEditorToggleBgRemoveMode(ed, value: false),
                    );
                  }
                }
              },
              isDark: isDark,
            ),
          ),
        ],
      );
    }

    if (_activeTool == EditorTool.effect) {
      return Column(
        children: [
          EditorEffectTabs(
            categories: AppEditorConstants.effectCategories,
            selectedCategory: _selectedEffectTab,
            onChanged: (v) => setState(() => _selectedEffectTab = v),
            isDark: isDark,
          ),
          if (state.selectedEffect != null) ...[
            SizedBox(height: MediaQuery.of(context).size.height * 0.02),
            EditorSliderRow(
              label: 'Intensity',
              value: state.overlayOpacity,
              onChanged: (v) => context.read<ImageEditorBloc>().add(
                ImageEditorUpdateOverlayOpacity(v),
              ),
              isDark: isDark,
            ),
          ],
          SizedBox(height: MediaQuery.of(context).size.height * 0.02),
          _buildEffectThumbnails(),
        ],
      );
    }

    if (_activeTool == EditorTool.doodle || _activeTool == EditorTool.shape) {
      return _buildPaintControls(subEditor: subEditor);
    }

    if (_activeTool == EditorTool.selective) {
      return _buildSelectiveControls(subEditor: subEditor);
    }

    if (_activeTool == EditorTool.text && subEditor != null) {
      return _buildTextPanel(subEditor);
    }

    if (_activeTool == EditorTool.frames) {
      return FirebaseFramePicker(
        isDark: isDark,
        imageAspectRatio: state.imageAspectRatio,
        selectedFrameUrl: _selectedFrameUrl,
        onFrameSelected: (url) {
          setState(() => _selectedFrameUrl = url);
        },
      );
    }

    if (_activeTool == EditorTool.sticker) {
      return _buildStickerPicker(subEditor);
    }

    return const SizedBox.shrink();
  }

  void _onToolSelected(String tool, dynamic subEditor) {
    final ed = _editorKey.currentState;
    if (ed == null) return;
    _panelCtrl.reverse();

    switch (tool) {
      case 'crop':
        setState(() => _activeTool = EditorTool.crop);
        if (subEditor == null) {
          ed.openCropRotateEditor().then((_) {
            _resetStateAfterToolClosed();
          });
        }
        break;
      case 'text':
        setState(() {
          _activeTool = EditorTool.text;
          _activeSubTool = EditorSubTool.textStyle;
        });
        if (subEditor == null) {
          ed.openTextEditor().then((_) {
            // Lock all text layers so they can't be moved, re-edited, or
            // selected after the tick is clicked — they are permanent once placed.
            _lockAllTextLayers();
            _resetStateAfterToolClosed();
          });
        }
        break;
      case 'doodle':
        setState(() {
          _activeTool = EditorTool.doodle;
          _activeSubTool = EditorSubTool.markup;
        });
        if (subEditor != null) {
          subEditor.setFill(false);
          subEditor.setMode(PaintMode.freeStyle);
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _editorKey.currentState?.openPaintEditor().then((_) async {
              // After the paint editor closes, bake the new paint layers
              // into the background image so they become permanent raster
              // pixels and don't shift/resize when the editor layout
              // changes (e.g. when the bottom panel collapses).
              await _bakePaintLayersIntoImage();
              // Lock any leftover paint layers (defensive) and reset state.
              _lockAllPaintLayers();
              _resetStateAfterToolClosed();
            });
          });
        }
        break;
      case 'shape':
        setState(() {
          _activeTool = EditorTool.shape;
          _activeSubTool = EditorSubTool.shape;
        });
        if (subEditor != null) {
          subEditor.setFill(true);
          subEditor.setMode(PaintMode.circle);
          subEditor.setColor(_paintColor);
          subEditor.setOpacity(_opacityValue);
          subEditor.setStrokeWidth(_strokeValue * 50);
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _editorKey.currentState?.openPaintEditor().then((_) async {
              // After the paint editor closes, bake the new shape layers
              // into the background image so they become permanent raster
              // pixels and don't shift/resize when the editor layout
              // changes (e.g. when the bottom panel collapses).
              await _bakePaintLayersIntoImage();
              // Lock any leftover paint layers (defensive) and reset state.
              _lockAllPaintLayers();
              _resetStateAfterToolClosed();
            });
          });
        }
        break;
      case 'sticker':
        setState(() => _activeTool = EditorTool.sticker);
        _panelCtrl.forward();
        break;
      case 'filters':
        setState(() => _activeTool = EditorTool.filters);
        if (subEditor == null) {
          ed.openFilterEditor().then((_) {
            _resetStateAfterToolClosed();
          });
        }
        break;
      case 'selective':
        context.read<ImageEditorBloc>().add(
          const ImageEditorToggleCircleMode(value: true),
        );
        setState(() => _activeTool = EditorTool.selective);
        break;
      case 'effect':
        context.read<ImageEditorBloc>().add(
          const ImageEditorToggleOverlayMode(value: true),
        );
        setState(() => _activeTool = EditorTool.effect);
        break;
      case 'bg':
        setState(() => _activeTool = EditorTool.bg);
        break;
      case 'retouch':
        context.read<ImageEditorBloc>().add(ImageEditorApplyRetouch(ed, 0.5));
        break;
      default:
        setState(
          () => _activeTool = EditorTool.values.firstWhere(
            (e) => e.name == tool,
            orElse: () => EditorTool.none,
          ),
        );
    }
  }

  Widget _buildSubEditorPanelOverlay(
    dynamic editor,
    Stream<void> rebuildStream, {
    bool usePositioned = true,
  }) {
    return BlocBuilder<ImageEditorBloc, ImageEditorState>(
      bloc: context.read<ImageEditorBloc>(),
      builder: (builderCtx, state) {
        return _buildBottomPanel(
          builderCtx,
          state,
          subEditor: editor,
          rebuildStream: rebuildStream,
          usePositioned: usePositioned,
        );
      },
    );
  }

  Widget _buildEffectThumbnails() {
    final effects = _effects
        .where((e) => e.category == _selectedEffectTab)
        .toList();
    return BlocBuilder<ImageEditorBloc, ImageEditorState>(
      builder: (context, state) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.read<ImageEditorBloc>().add(
                  const ImageEditorSelectOverlay(null),
                ),
                child: Container(
                  width: 64,
                  height: 64,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: AppEditorConstants.iconBg(_isDark),
                    borderRadius: BorderRadius.circular(
                      MediaQuery.of(context).size.width * 0.03,
                    ),
                    border: Border.all(
                      color: state.selectedEffect == null
                          ? AppEditorConstants.accent
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.block,
                      color: AppEditorConstants.textDim(_isDark),
                      size: 24,
                    ),
                  ),
                ),
              ),
              ...effects.map((e) {
                final active = state.selectedEffect?.id == e.id;
                return GestureDetector(
                  onTap: () {
                    // Use actual image aspect ratio to decide between portrait and square effects
                    final isPortrait = state.imageAspectRatio < 0.95;
                    context.read<ImageEditorBloc>().add(
                      ImageEditorSelectOverlay(e, isPortrait: isPortrait),
                    );
                  },
                  child: Container(
                    width: 64,
                    height: 64,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: AppEditorConstants.iconBg(_isDark),
                      borderRadius: BorderRadius.circular(
                        MediaQuery.of(context).size.width * 0.03,
                      ),
                      border: Border.all(
                        color: active
                            ? AppEditorConstants.accent
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        MediaQuery.of(context).size.width * 0.03,
                      ),
                      child: FutureBuilder<String?>(
                        future: EffectService().getEffectThumbnailUrl(
                          category: e.category,
                          index:
                              int.tryParse(
                                e.assetPath
                                    .split('/')
                                    .last
                                    .split('.')
                                    .first
                                    .replaceAll(RegExp(r'\D'), ''),
                              ) ??
                              1,
                        ),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          }
                          final url = snapshot.data;
                          if (url == null) {
                            return Center(
                              child: Icon(
                                Icons.image_not_supported,
                                color: AppEditorConstants.textDim(_isDark),
                                size: 20,
                              ),
                            );
                          }
                          return CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: Icon(
                                Icons.error_outline,
                                color: AppEditorConstants.textDim(_isDark),
                                size: 20,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaintControls({dynamic subEditor}) {
    final isDark = _isDark;
    final isDoodle = _activeTool == EditorTool.doodle;

    return Column(
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.01),
        EditorColorRow(
          selectedColor: _paintColor,
          onChanged: (c) {
            setState(() => _paintColor = c);
            if (subEditor != null) {
              subEditor.setColor(c);
            }
          },
          isDark: isDark,
        ),
        EditorDualSliderRow(
          leftLabel: 'Opacity',
          leftValue: _opacityValue,
          leftOnChanged: (v) {
            setState(() => _opacityValue = v);
            if (subEditor != null) {
              subEditor.setOpacity(v);
            }
          },
          rightLabel: isDoodle ? 'Sizes' : 'Stroke',
          rightValue: isDoodle ? _sizeValue : _strokeValue,
          rightOnChanged: (v) {
            setState(() {
              if (isDoodle) {
                _sizeValue = v;
              } else {
                _strokeValue = v;
              }
            });
            if (subEditor != null) {
              subEditor.setStrokeWidth(v * 50);
            }
          },
          isDark: isDark,
        ),
        if (!isDoodle) ...[
          SizedBox(height: MediaQuery.of(context).size.height * 0.015),
          EditorShapeRow(
            shapes: AppEditorConstants.shapeModes,
            activeMode:
                subEditor?.paintMode?.toString().split('.').last ?? 'circle',
            onChanged: (mode) {
              if (subEditor != null) {
                final isEraser = mode == 'eraser';
                subEditor.setFill(
                  !isEraser,
                ); // Shape is filled, eraser is outline/not filled
                subEditor.setMode(
                  PaintMode.values.firstWhere(
                    (e) => e.toString().split('.').last == mode,
                    orElse: () => PaintMode.circle,
                  ),
                );
                setState(() {});
              }
            },
            isDark: isDark,
          ),
        ],
      ],
    );
  }

  Widget _buildSelectiveControls({dynamic subEditor}) {
    return BlocBuilder<ImageEditorBloc, ImageEditorState>(
      builder: (context, state) {
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                EditorActionBtn(
                  icon: Icons.restore,
                  isDark: _isDark,
                  onTap: () {
                    final bloc = context.read<ImageEditorBloc>();
                    final sz = MediaQuery.of(context).size;
                    bloc.add(
                      const ImageEditorUpdateCircleFilters(
                        blur: 0,
                        brightness: 0.5,
                        contrast: 0.5,
                        saturation: 0.5,
                        hue: 0.5,
                      ),
                    );
                    bloc.add(
                      ImageEditorUpdateCircle(
                        center: Offset(sz.width / 2, sz.height / 2),
                        radius: 100,
                      ),
                    );
                  },
                ),
                SizedBox(width: MediaQuery.of(context).size.width * 0.04),
                _buildModeToggle(
                  label: 'Inside',
                  active: state.editInsideCircle,
                  onTap: () => context.read<ImageEditorBloc>().add(
                    const ImageEditorUpdateCircle(editInside: true),
                  ),
                ),
                SizedBox(width: MediaQuery.of(context).size.width * 0.04),
                _buildModeToggle(
                  label: 'Outside',
                  active: !state.editInsideCircle,
                  onTap: () => context.read<ImageEditorBloc>().add(
                    const ImageEditorUpdateCircle(editInside: false),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.02),
            EditorSliderRow(
              label: 'Blur',
              value: state.circleBlur,
              onChanged: (v) => context.read<ImageEditorBloc>().add(
                ImageEditorUpdateCircleFilters(blur: v),
              ),
              isDark: _isDark,
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.01),
            EditorSliderRow(
              label: 'Brightness',
              value: state.circleBrightness,
              onChanged: (v) => context.read<ImageEditorBloc>().add(
                ImageEditorUpdateCircleFilters(brightness: v),
              ),
              isDark: _isDark,
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.01),
            EditorSliderRow(
              label: 'Contrast',
              value: state.circleContrast,
              onChanged: (v) => context.read<ImageEditorBloc>().add(
                ImageEditorUpdateCircleFilters(contrast: v),
              ),
              isDark: _isDark,
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.01),
            EditorSliderRow(
              label: 'Saturation',
              value: state.circleSaturation,
              onChanged: (v) => context.read<ImageEditorBloc>().add(
                ImageEditorUpdateCircleFilters(saturation: v),
              ),
              isDark: _isDark,
            ),
            SizedBox(height: MediaQuery.of(context).size.height * 0.01),
            EditorSliderRow(
              label: 'Hue',
              value: state.circleHue,
              onChanged: (v) => context.read<ImageEditorBloc>().add(
                ImageEditorUpdateCircleFilters(hue: v),
              ),
              isDark: _isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStickerPicker(dynamic subEditor) {
    final isDark = _isDark;
    return FirebaseStickerPicker(
      key: _stickerPickerKey,
      subEditor: subEditor,
      isDark: isDark,
      editorState: _editorKey.currentState,
      onStickerAdded: (layer) {
        if (layer != null) {
          _unconfirmedStickers.clear();
          _unconfirmedStickers.add(layer);
        }
      },
      onDone: () {
        if (subEditor != null) {
          try {
            subEditor.done();
          } catch (e) {
            debugPrint('Error calling done on sticker subEditor: $e');
          }
        } else {
          _confirmCurrentTool();
        }
      },
    );
  }

  /// Returns a human-readable label for the active adjust sub-tool.
  String _subToolLabel(EditorSubTool subTool) {
    const labels = <EditorSubTool, String>{
      EditorSubTool.exposure: 'Exposure',
      EditorSubTool.contrast: 'Contrast',
      EditorSubTool.saturation: 'Saturation',
      EditorSubTool.temperature: 'Temperature',
      EditorSubTool.tone: 'Tone',
      EditorSubTool.grain: 'Grain',
      EditorSubTool.vignette: 'Vignette',
      EditorSubTool.sharpen: 'Sharpen',
      EditorSubTool.denoise: 'Denoise',
      EditorSubTool.clarity: 'Clarity',
      EditorSubTool.vibrance: 'Vibrance',
      EditorSubTool.skinTone: 'Skin Tone',
      EditorSubTool.autoAdjust: 'Auto Adjust',
    };
    return labels[subTool] ?? 'Adjust';
  }

  Widget _buildCurvesControls() {
    return CurvesEditor(
      data: _curvesData,
      isDark: _isDark,
      onChanged: (data) {
        setState(() => _curvesData = data);
        _debounceCurvesPreview();
      },
    );
  }

  Widget _buildHSLControls() {
    return Column(
      children: [
        EditorColorDots(
          selectedIndex: _selectedHslColorIndex,
          onChanged: (i) => setState(() => _selectedHslColorIndex = i),
          isDark: _isDark,
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.02),
        EditorSliderRow(
          label: 'Hue',
          value: _hslAdjustments[_selectedHslColorIndex]['hue']!,
          onChanged: (v) {
            setState(() => _hslAdjustments[_selectedHslColorIndex]['hue'] = v);
            _triggerHslPreview();
          },
          isDark: _isDark,
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.01),
        EditorSliderRow(
          label: 'Sat',
          value: _hslAdjustments[_selectedHslColorIndex]['saturation']!,
          onChanged: (v) {
            setState(
              () => _hslAdjustments[_selectedHslColorIndex]['saturation'] = v,
            );
            _triggerHslPreview();
          },
          isDark: _isDark,
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.01),
        EditorSliderRow(
          label: 'Lum',
          value: _hslAdjustments[_selectedHslColorIndex]['luminance']!,
          onChanged: (v) {
            setState(
              () => _hslAdjustments[_selectedHslColorIndex]['luminance'] = v,
            );
            _triggerHslPreview();
          },
          isDark: _isDark,
        ),
      ],
    );
  }

  /// Triggers the HSL live preview with debouncing for smooth performance.
  void _triggerHslPreview() {
    _hslPreviewDebounce?.cancel();
    _hslPreviewDebounce = Timer(const Duration(milliseconds: 30), () {
      _updateHslPreview();
    });
  }

  /// Initializes HSL preview by scaling down the base image to max 360px and caching its bytes.
  Future<void> _initHslPreview() async {
    final ed = _editorKey.currentState;
    if (ed == null) return;

    final currentImage = ed.stateManager.activeBackgroundImage;
    if (currentImage == null) return;

    try {
      final bytes = await currentImage.safeByteArray();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final srcImg = frame.image;

      final double w = srcImg.width.toDouble();
      final double h = srcImg.height.toDouble();
      double scale = 1.0;
      if (w > h) {
        if (w > 360) scale = 360 / w;
      } else {
        if (h > 360) scale = 360 / h;
      }
      final int targetW = (w * scale).round();
      final int targetH = (h * scale).round();

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        srcImg,
        ui.Rect.fromLTWH(0, 0, w, h),
        ui.Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      final picture = recorder.endRecording();
      final scaledImg = await picture.toImage(targetW, targetH);

      final byteData = await scaledImg.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      srcImg.dispose();
      scaledImg.dispose();

      if (byteData != null && mounted) {
        setState(() {
          _hslBaseBytes = byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          );
          _hslBaseWidth = targetW;
          _hslBaseHeight = targetH;
        });

        // Trigger HSL processing if adjustments are not neutral
        if (!HslProcessor.isNeutral(_hslAdjustments)) {
          _updateHslPreview();
        }
      }
    } catch (e) {
      debugPrint('Error initializing HSL preview: $e');
    }
  }

  /// Updates the HSL live preview image using per-pixel processing.
  Future<void> _updateHslPreview() async {
    if (_hslBaseBytes == null || _hslBaseWidth == 0 || _hslBaseHeight == 0) {
      return;
    }

    // Check if adjustments are neutral - skip processing and clear preview image
    if (HslProcessor.isNeutral(_hslAdjustments)) {
      if (_hslPreviewImage != null) {
        setState(() {
          _hslPreviewImage?.dispose();
          _hslPreviewImage = null;
        });
      }
      return;
    }

    try {
      // Apply HSL processing synchronously on downscaled raw bytes
      final processedBytes = HslProcessor.apply(
        _hslBaseBytes!,
        _hslAdjustments,
      );

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        processedBytes,
        _hslBaseWidth,
        _hslBaseHeight,
        ui.PixelFormat.rgba8888,
        (image) => completer.complete(image),
      );
      final newPreviewImg = await completer.future;

      if (mounted) {
        setState(() {
          _hslPreviewImage?.dispose();
          _hslPreviewImage = newPreviewImg;
        });
      }
    } catch (e) {
      debugPrint('Error updating HSL preview: $e');
    }
  }

  /// Disposes of HSL preview resources.
  void _disposeHslPreview() {
    _hslPreviewDebounce?.cancel();
    _hslPreviewDebounce = null;
    _hslPreviewImage?.dispose();
    _hslPreviewImage = null;
    _hslBaseBytes = null;
    _hslBaseWidth = 0;
    _hslBaseHeight = 0;
  }

  void _debounceCurvesPreview() {
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 50), () {
      _updateCurvesPreview();
    });
  }

  Future<void> _initCurvesPreview() async {
    final ed = _editorKey.currentState;
    if (ed == null) return;

    final currentImage = ed.stateManager.activeBackgroundImage;
    if (currentImage == null) return;

    try {
      final bytes = await currentImage.safeByteArray();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final srcImg = frame.image;

      final double w = srcImg.width.toDouble();
      final double h = srcImg.height.toDouble();
      double scale = 1.0;
      if (w > h) {
        if (w > 800) scale = 800 / w;
      } else {
        if (h > 800) scale = 800 / h;
      }
      final int targetW = (w * scale).round();
      final int targetH = (h * scale).round();

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        srcImg,
        ui.Rect.fromLTWH(0, 0, w, h),
        ui.Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      final picture = recorder.endRecording();
      final scaledImg = await picture.toImage(targetW, targetH);

      final byteData = await scaledImg.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      );

      srcImg.dispose();
      scaledImg.dispose();

      if (byteData != null && mounted) {
        setState(() {
          _curvesBaseBytes = byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          );
          _curvesBaseW = targetW;
          _curvesBaseH = targetH;
        });
        _updateCurvesPreview();
      }
    } catch (e) {
      debugPrint('Error initializing curves preview: $e');
    }
  }

  Future<void> _updateCurvesPreview() async {
    if (_curvesBaseBytes == null || _curvesBaseW == 0 || _curvesBaseH == 0) {
      return;
    }
    try {
      final processed = CurvesProcessor.apply(_curvesBaseBytes!, _curvesData);
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        processed,
        _curvesBaseW,
        _curvesBaseH,
        ui.PixelFormat.rgba8888,
        (img) => completer.complete(img),
      );
      final newImg = await completer.future;
      if (mounted) {
        setState(() {
          _curvesPreviewImage?.dispose();
          _curvesPreviewImage = newImg;
        });
      }
    } catch (e) {
      debugPrint('Error updating curves preview: $e');
    }
  }

  void _disposeCurvesPreview() {
    _previewDebounce?.cancel();
    _previewDebounce = null;
    _curvesPreviewImage?.dispose();
    _curvesPreviewImage = null;
    _curvesBaseBytes = null;
    _curvesBaseW = 0;
    _curvesBaseH = 0;
  }

  /// Initializes Grain preview by scaling down the base image to max 360px and caching it.
  Future<void> _initGrainPreview() async {
    final ed = _editorKey.currentState;
    if (ed == null) return;

    final currentImage = ed.stateManager.activeBackgroundImage;
    if (currentImage == null) return;

    try {
      final bytes = await currentImage.safeByteArray();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final srcImg = frame.image;

      final double w = srcImg.width.toDouble();
      final double h = srcImg.height.toDouble();
      double scale = 1.0;
      if (w > h) {
        if (w > 360) scale = 360 / w;
      } else {
        if (h > 360) scale = 360 / h;
      }
      final int targetW = (w * scale).round();
      final int targetH = (h * scale).round();

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImageRect(
        srcImg,
        ui.Rect.fromLTWH(0, 0, w, h),
        ui.Rect.fromLTWH(0, 0, targetW.toDouble(), targetH.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      final picture = recorder.endRecording();
      final scaledImg = await picture.toImage(targetW, targetH);

      srcImg.dispose();

      if (mounted) {
        setState(() {
          _grainPreviewImage = scaledImg;
        });
      }
    } catch (e) {
      debugPrint('Error initializing Grain preview: $e');
    }
  }

  /// Disposes of Grain preview resources.
  void _disposeGrainPreview() {
    _grainPreviewImage?.dispose();
    _grainPreviewImage = null;
  }

  Widget _buildCircleInteractionLayer(
    BuildContext context,
    ImageEditorState state,
  ) {
    return Positioned.fill(
      child: GestureDetector(
        onScaleStart: (details) {
          _initialRadius = state.circleRadius;
        },
        onScaleUpdate: (details) {
          if (details.pointerCount == 1) {
            // Drag to move
            context.read<ImageEditorBloc>().add(
              ImageEditorUpdateCircle(center: details.localFocalPoint),
            );
          } else if (details.pointerCount == 2) {
            // Pinch to resize
            final newRadius = (_initialRadius * details.scale).clamp(
              20.0,
              500.0,
            );
            context.read<ImageEditorBloc>().add(
              ImageEditorUpdateCircle(radius: newRadius),
            );
          }
        },
        child: CustomPaint(
          painter: _CirclePainter(
            center: state.circleCenter,
            radius: state.circleRadius,
            accentColor: AppEditorConstants.accent,
            editInside: state.editInsideCircle,
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? AppEditorConstants.accent
              : AppEditorConstants.iconBg(_isDark),
          borderRadius: BorderRadius.circular(
            MediaQuery.of(context).size.width * 0.05,
          ),
          border: Border.all(
            color: active ? AppEditorConstants.accent : Colors.white24,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppEditorConstants.textDim(_isDark),
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildTextPanel(dynamic subEditor) {
    return Column(
      children: [
        EditorTextTabs(
          activeTab: _activeSubTool,
          onChanged: (v) {
            setState(() => _activeSubTool = v);
            // Automatically expand for font grid, and collapse for basic controls
            if (v == EditorSubTool.textFont) {
              if (_panelCtrl.value < 1.0) {
                _panelCtrl.animateTo(1.0, curve: Curves.easeOutCubic);
              }
            } else if (v == EditorSubTool.textStyle) {
              if (_panelCtrl.value > 0.0) {
                _panelCtrl.animateTo(0.0, curve: Curves.easeOutCubic);
              }
            }
            // Force the text editor's ReactiveWidget to rebuild so it picks
            // up the new _activeSubTool and renders the correct panel content.
            // The bottom bar builder depends on _buildTextPanel which reads
            // _activeSubTool, but it's wrapped in ReactiveWidget(rebuildStream).
            try {
              // Call setState on the TextEditorState to emit on its rebuildStream
              (subEditor as dynamic).setState(() {});
            } catch (_) {}
            // Reset scroll position after rebuild to prevent blank space
            // caused by stale scroll offset when switching content height.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_panelScrollCtrl.hasClients) {
                _panelScrollCtrl.jumpTo(0);
              }
            });
          },
          isDark: _isDark,
        ),
        SizedBox(height: AppEditorConstants.h(context, 0.012)),
        _activeSubTool == EditorSubTool.textFont
            ? _buildFontGrid(subEditor)
            : _buildTextBasicPanel(subEditor),
      ],
    );
  }

  Widget _buildFontGrid(dynamic subEditor) {
    return SizedBox(
      height: AppEditorConstants.h(context, 0.35),
      child: GridView.builder(
        shrinkWrap: false,
        physics: const BouncingScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 2.8,
          crossAxisSpacing: AppEditorConstants.w(context, 0.02),
          mainAxisSpacing: AppEditorConstants.h(context, 0.012),
        ),
        itemCount: AppEditorConstants.fontFamilies.length,
        itemBuilder: (context, index) {
          final font = AppEditorConstants.fontFamilies[index];
          final isSelected = _selectedFontFamily == font;
          return EditorFontCard(
            fontFamily: font,
            isSelected: isSelected,
            isDark: _isDark,
            fontStyle: () {
              try {
                return GoogleFonts.getFont(font);
              } catch (e) {
                return const TextStyle();
              }
            }(),
            onTap: () {
              setState(() => _selectedFontFamily = font);
              _updateTextStyle(subEditor);
            },
          );
        },
      ),
    );
  }

  Widget _buildTextBasicPanel(dynamic subEditor) {
    final isDark = _isDark;
    return Column(
      children: [
        EditorColorRow(
          selectedColor: _textColor,
          onChanged: (c) {
            setState(() => _textColor = c);
            try {
              subEditor.primaryColor = c.withValues(alpha: _textOpacity);
            } catch (_) {}
            _updateTextStyle(subEditor);
          },
          isDark: isDark,
        ),
        EditorSliderRow(
          label: 'Opacity',
          value: _textOpacity,
          onChanged: (v) {
            setState(() => _textOpacity = v);
            try {
              subEditor.primaryColor = _textColor.withValues(alpha: v);
            } catch (_) {}
            _updateTextStyle(subEditor);
          },
          isDark: isDark,
        ),
        SizedBox(height: AppEditorConstants.h(context, 0.02)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Style Buttons
            _buildStyleToggle(
              icon: Icons.format_bold,
              active: _isBold,
              onTap: () {
                setState(() => _isBold = !_isBold);
                _updateTextStyle(subEditor);
              },
            ),
            SizedBox(width: AppEditorConstants.w(context, 0.02)),
            _buildStyleToggle(
              icon: Icons.format_italic,
              active: _isItalic,
              onTap: () {
                setState(() => _isItalic = !_isItalic);
                _updateTextStyle(subEditor);
              },
            ),
            SizedBox(width: AppEditorConstants.w(context, 0.02)),
            _buildStyleToggle(
              icon: Icons.format_underlined,
              active: _isUnderlined,
              onTap: () {
                setState(() => _isUnderlined = !_isUnderlined);
                _updateTextStyle(subEditor);
              },
            ),
            SizedBox(width: AppEditorConstants.w(context, 0.04)),
            // Alignment Buttons
            _buildAlignBtn(
              icon: Icons.format_align_left,
              active: _textAlign == TextAlign.left,
              onTap: () {
                setState(() => _textAlign = TextAlign.left);
                _updateTextAlign(subEditor, TextAlign.left);
              },
            ),
            _buildAlignBtn(
              icon: Icons.format_align_center,
              active: _textAlign == TextAlign.center,
              onTap: () {
                setState(() => _textAlign = TextAlign.center);
                _updateTextAlign(subEditor, TextAlign.center);
              },
            ),
            _buildAlignBtn(
              icon: Icons.format_align_right,
              active: _textAlign == TextAlign.right,
              onTap: () {
                setState(() => _textAlign = TextAlign.right);
                _updateTextAlign(subEditor, TextAlign.right);
              },
            ),
            _buildAlignBtn(
              icon: Icons.format_align_justify,
              active: _textAlign == TextAlign.justify,
              onTap: () {
                setState(() => _textAlign = TextAlign.justify);
                _updateTextAlign(subEditor, TextAlign.justify);
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStyleToggle({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: AppEditorConstants.sp(context, 38),
        height: AppEditorConstants.sp(context, 38),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? AppEditorConstants.accent
              : AppEditorConstants.iconBg(_isDark),
          gradient: active
              ? const LinearGradient(
                  colors: [Color(0xFFD66031), Color(0xFFB54D26)],
                )
              : null,
        ),
        child: Icon(
          icon,
          color: active
              ? Colors.white
              : AppEditorConstants.primaryText(_isDark),
          size: 20,
        ),
      ),
    );
  }

  Widget _buildAlignBtn({
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: active
              ? AppEditorConstants.accent.withAlpha(40)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(
            MediaQuery.of(context).size.width * 0.01,
          ),
        ),
        child: Icon(
          icon,
          color: active
              ? AppEditorConstants.accent
              : AppEditorConstants.primaryText(_isDark).withAlpha(150),
          size: 22,
        ),
      ),
    );
  }

  void _updateTextStyle(dynamic subEditor) {
    final style = GoogleFonts.getFont(
      _selectedFontFamily,
      fontWeight: _isBold ? FontWeight.bold : FontWeight.normal,
      fontStyle: _isItalic ? FontStyle.italic : FontStyle.normal,
      decoration: _isUnderlined
          ? TextDecoration.underline
          : TextDecoration.none,
      decorationColor: _textColor.withValues(alpha: _textOpacity),
      color: _textColor.withValues(alpha: _textOpacity),
    );
    try {
      subEditor.setTextStyle(style);
    } catch (_) {
      // Fallback or dynamic update
    }
  }

  void _updateTextAlign(dynamic subEditor, TextAlign align) {
    try {
      // The TextEditorState has a public `align` field and public `setState`
      (subEditor as dynamic).align = align;
      (subEditor as dynamic).setState(() {});
    } catch (_) {
      // Alignment update not supported
    }
  }

  /// Bakes all current [PaintLayer]s (shapes/doodles) into the background
  /// image as rasterized pixels, then removes those layers from the editor
  /// stack. This is what prevents the shapes from "shifting" or "resizing"
  /// when the editor's container resizes after the paint editor closes.
  ///
  /// **Why this version uses the library's own path builders.** The
  /// library's `PaintLayer.offset` and `PaintLayer.size` are expressed in
  /// **body coordinates** (the main editor's body), and the base image
  /// is fit with `BoxFit.contain` inside that body. So to map a layer
  /// into the base image's pixel space we:
  ///   1. Compute the image's rect inside the body using `BoxFit.contain`
  ///      math (the same math the editor uses).
  ///   2. Compute the body-to-image scale (`imageSize / imageRectSize`).
  ///   3. Translate the layer's center from body coords into the body-
  ///      local image-rect, then scale by the body-to-image scale.
  ///   4. Draw the layer's path via the library's own
  ///      [PathBuilderBase.fromMode] (so we honor the triangle custom
  ///      builder, opacity, eraser, freeStyle collection, etc.) at the
  ///      computed image-space position and size, using the
  ///      `bodyToImageScale` as the builder's scale factor.
  ///
  /// We deliberately avoid `ed.captureEditorImage()` because that method
  /// itself calls `Navigator.pop` when it sees `isSubEditorOpen`, and
  /// the `.then(...)` callback fires before the paint editor's close
  /// animation finishes — that double-pop takes the user back to the
  /// Home page.
  Future<void> _bakePaintLayersIntoImage() async {
    final ed = _editorKey.currentState;
    if (ed == null) return;

    final paintLayers = ed.activeLayers.whereType<PaintLayer>().toList();
    if (paintLayers.isEmpty) {
      debugPrint('[BakePaint] No paint layers to bake.');
      return;
    }

    if (!mounted) return;
    setState(() => _isBakingPaint = true);

    ui.Image? baseUiImage;
    try {
      final currentImage = ed.stateManager.activeBackgroundImage;
      if (currentImage == null) {
        debugPrint('[BakePaint] No background image available.');
        return;
      }

      // Decode the base image.
      final baseBytes = await currentImage.safeByteArray();
      final baseCodec = await ui.instantiateImageCodec(baseBytes);
      final baseFrame = await baseCodec.getNextFrame();
      baseUiImage = baseFrame.image;

      final baseSize = Size(
        baseUiImage.width.toDouble(),
        baseUiImage.height.toDouble(),
      );

      // ───────────────────────────────────────────────────────────
      // IMPORTANT — use the *paint editor's* body size, not the main
      // editor's.  The library converts the layer's offset/size from
      // paint-editor-body coords into main-editor-body coords by
      // multiplying by `mainEditorSizeFactor` (which is a single double
      // derived from the ratio of the two body sizes).  That single
      // double is *only* correct when the body widths AND heights share
      // the same ratio.  In our case the paint editor has its own app
      // bar + bottom panel so the body sizes are different — the
      // library's multiplication makes the layer land at the wrong
      // (x, y) and (w, h) in the image.
      //
      // To fix this we:
      //   1. Capture the paint editor's body size at tick time
      //      (see [_capturePaintEditorBodySize]).
      //   2. Reverse the library's `mainEditorSizeFactor` (= layer.scale)
      //      on the layer's `offset` and `size` to recover the
      //      paint-editor-body coordinates the user actually drew at.
      //   3. Run the same `applyBoxFit` math the user saw while drawing,
      //      using the paint editor's body size — so the body-to-image
      //      scale matches what the user actually saw.
      //   4. Convert and draw the layer into the image.
      // ───────────────────────────────────────────────────────────
      final bodySize = _paintEditorBodySize ?? ed.sizesManager.bodySize;
      _paintEditorBodySize = null; // consume so we don't leak between sessions

      // Find the base image's rect inside the body (BoxFit.contain) and
      // the body-to-image scale.  This is the same `applyBoxFit` math
      // the editor itself uses to render the background.
      final FittedSizes fitted = applyBoxFit(
        BoxFit.contain,
        baseSize,
        bodySize,
      );
      final Rect imageRectInBody = Alignment.center.inscribe(
        fitted.destination,
        Offset.zero & bodySize,
      );
      final double bodyToImageScale = baseSize.width / imageRectInBody.width;

      // Look up the registered PaintEditorConfigs so custom path
      // builders (e.g. the triangle) are honored.
      final paintConfigs = ed.configs.paintEditor;

      // Composite: draw base image, then each paint layer on top.
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawImage(baseUiImage, Offset.zero, Paint());

      for (final layer in paintLayers) {
        try {
          // Reverse the library's mainEditorSizeFactor (== layer.scale)
          // to recover the layer's offset/size in the *paint editor's*
          // body coordinates.  In the paint editor the user drew at
          // these exact coordinates — so converting from here into
          // image pixels gives us a pixel-perfect bake.
          final double reverseFactor = layer.scale == 0.0
              ? 1.0
              : 1.0 / layer.scale;
          final Offset paintEditorOffset = layer.offset * reverseFactor;
          final Size paintEditorSize = layer.size * reverseFactor;

          // Layer's center in *paint editor* body coords:
          //   bodyX = paintEditorOffset.dx + bodyW/2
          //   bodyY = paintEditorOffset.dy + bodyH/2
          // Convert to image coords using the paint editor's
          // `bodyToImageScale`:
          //   imageX = (bodyX - imageRectInBody.left) * bodyToImageScale
          //   imageY = (bodyY - imageRectInBody.top)  * bodyToImageScale
          final double layerCenterBodyX =
              paintEditorOffset.dx + bodySize.width / 2.0;
          final double layerCenterBodyY =
              paintEditorOffset.dy + bodySize.height / 2.0;
          final double layerCenterImgX =
              (layerCenterBodyX - imageRectInBody.left) * bodyToImageScale;
          final double layerCenterImgY =
              (layerCenterBodyY - imageRectInBody.top) * bodyToImageScale;
          final Size layerSizeImg = paintEditorSize * bodyToImageScale;

          if (layerSizeImg.width <= 0 || layerSizeImg.height <= 0) continue;

          final Offset layerTopLeftImg = Offset(
            layerCenterImgX - layerSizeImg.width / 2.0,
            layerCenterImgY - layerSizeImg.height / 2.0,
          );

          canvas.save();
          canvas.translate(layerTopLeftImg.dx, layerTopLeftImg.dy);

          // Apply the layer's opacity via saveLayer so transparent
          // strokes blend with the base image (and any previously
          // rendered layers).
          final opacity = layer.opacity.clamp(0.0, 1.0);
          if (opacity < 1.0) {
            canvas.saveLayer(
              Rect.fromLTWH(0, 0, layerSizeImg.width, layerSizeImg.height),
              Paint()..color = Color.fromRGBO(255, 255, 255, opacity),
            );
          }

          // Use the body-to-image scale for the path builder so the
          // path is rendered at the correct image-pixel size. The
          // layer's offsets (in `layer.item.offsets`) are in body
          // coords (the library translates them to be relative to the
          // layerRect's top-left in `_transformPaintedModelToLayer`).
          // Multiplying by `bodyToImageScale` puts them in image coords.
          final pathBuilder = PathBuilderBase.fromMode(
            item: layer.item,
            scale: bodyToImageScale,
            paintEditorConfigs: paintConfigs,
          );
          pathBuilder.draw(canvas: canvas, size: layerSizeImg);

          if (opacity < 1.0) canvas.restore();
          canvas.restore();
        } catch (e) {
          debugPrint('[BakePaint] Error rendering layer: $e');
        }
      }

      final picture = recorder.endRecording();
      final resultImage = await picture.toImage(
        baseUiImage.width,
        baseUiImage.height,
      );

      // Export to a temp PNG file and swap it in as the new background.
      final resultBytes = await EffectEngine().exportToBytes(resultImage);
      final dir = await getTemporaryDirectory();
      final outFile = File(
        '${dir.path}/paint_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await outFile.writeAsBytes(resultBytes);

      ed.stateManager.updateBackgroundImages(
        oldImage: currentImage.copyWith(),
        newImage: EditorImage.file(outFile),
      );

      // Remove the now-baked paint layers from the layer stack so they
      // don't render twice (once baked into the image, once as vectors).
      for (final layer in paintLayers) {
        try {
          ed.removeLayer(layer);
        } catch (e) {
          debugPrint('[BakePaint] Error removing layer: $e');
        }
      }

      // Dispose the heavy intermediates.
      resultImage.dispose();

      debugPrint(
        '[BakePaint] Successfully baked ${paintLayers.length} layer(s).',
      );
    } catch (e, stackTrace) {
      debugPrint('[BakePaint] Error: $e\n$stackTrace');
    } finally {
      baseUiImage?.dispose();
      if (mounted) {
        setState(() => _isBakingPaint = false);
      }
    }
  }
}

class _CirclePainter extends CustomPainter {
  final Offset center;
  final double radius;
  final Color accentColor;
  final bool editInside;

  _CirclePainter({
    required this.center,
    required this.radius,
    required this.accentColor,
    required this.editInside,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Visual feedback for the excluded area (Dimming)
    final maskAlpha = 140;
    if (editInside) {
      final fullPath = Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      final circlePath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: radius));
      final outerPath = Path.combine(
        PathOperation.difference,
        fullPath,
        circlePath,
      );
      canvas.drawPath(
        outerPath,
        Paint()..color = Colors.black.withAlpha(maskAlpha),
      );

      // Highlight the active area (inside)
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = accentColor.withAlpha(30),
      );
    } else {
      // Dim the inside
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Colors.black.withAlpha(maskAlpha),
      );

      // Highlight the active area (outside)
      final fullPath = Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      final circlePath = Path()
        ..addOval(Rect.fromCircle(center: center, radius: radius));
      final outerPath = Path.combine(
        PathOperation.difference,
        fullPath,
        circlePath,
      );
      canvas.drawPath(outerPath, Paint()..color = accentColor.withAlpha(20));
    }

    final borderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius, borderPaint);

    // Add mode label
    final textPainter = TextPainter(
      text: TextSpan(
        text: editInside ? 'INSIDE' : 'OUTSIDE',
        style: TextStyle(
          color: accentColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      center - Offset(textPainter.width / 2, radius + 15),
    );
  }

  @override
  bool shouldRepaint(_CirclePainter oldDelegate) {
    return oldDelegate.center != center || oldDelegate.radius != radius;
  }
}

class _CircleClipper extends CustomClipper<Path> {
  final Offset center;
  final double radius;
  final bool editInside;

  _CircleClipper({
    required this.center,
    required this.radius,
    required this.editInside,
  });

  @override
  Path getClip(Size size) {
    if (editInside) {
      return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    }
    // For "editOutside", clip is the entire size (no clip in the inside)
    return Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
  }

  @override
  bool shouldReclip(_CircleClipper oldClipper) {
    return oldClipper.center != center ||
        oldClipper.radius != radius ||
        oldClipper.editInside != editInside;
  }
}

class _BgBlurPainter extends CustomPainter {
  final ui.Image backgroundImage;
  final ui.Image foregroundImage;
  final double intensity;
  final Size? sourceSize;

  _BgBlurPainter({
    required this.backgroundImage,
    required this.foregroundImage,
    required this.intensity,
    this.sourceSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double imgW = sourceSize?.width ?? backgroundImage.width.toDouble();
    final double imgH = sourceSize?.height ?? backgroundImage.height.toDouble();
    final Size imageSize = Size(imgW, imgH);

    final FittedSizes fittedSizes = applyBoxFit(
      BoxFit.contain,
      imageSize,
      size,
    );
    final Rect destRect = Alignment.center.inscribe(
      fittedSizes.destination,
      Offset.zero & size,
    );

    // 1. Draw background (blurred if intensity > 0)
    if (intensity > 0.01) {
      final sigma = intensity * 40.0;
      canvas.saveLayer(
        destRect,
        Paint()
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: ui.TileMode.decal,
          ),
      );
      canvas.drawImageRect(
        backgroundImage,
        Rect.fromLTWH(
          0,
          0,
          backgroundImage.width.toDouble(),
          backgroundImage.height.toDouble(),
        ),
        destRect,
        Paint()..filterQuality = ui.FilterQuality.medium,
      );
      canvas.restore();
    } else {
      // Clean background (no blur)
      canvas.drawImageRect(
        backgroundImage,
        Rect.fromLTWH(
          0,
          0,
          backgroundImage.width.toDouble(),
          backgroundImage.height.toDouble(),
        ),
        destRect,
        Paint()..filterQuality = ui.FilterQuality.medium,
      );
    }

    // 2. Draw sharp foreground subject
    canvas.drawImageRect(
      foregroundImage,
      Rect.fromLTWH(
        0,
        0,
        foregroundImage.width.toDouble(),
        foregroundImage.height.toDouble(),
      ),
      destRect,
      Paint()..filterQuality = ui.FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(covariant _BgBlurPainter oldDelegate) {
    return oldDelegate.backgroundImage != backgroundImage ||
        oldDelegate.foregroundImage != foregroundImage ||
        oldDelegate.intensity != intensity ||
        oldDelegate.sourceSize != sourceSize;
  }
}

class _TrianglePathBuilder extends PathBuilderBase {
  _TrianglePathBuilder({
    required super.paintEditorConfigs,
    required super.item,
    required super.scale,
  });

  @override
  Path build() {
    path.reset();
    if (offsets.length < 2) return path;

    final start = this.start;
    final end = this.end;

    final rect = Rect.fromPoints(start, end);

    path.moveTo(rect.center.dx, rect.top);
    path.lineTo(rect.right, rect.bottom);
    path.lineTo(rect.left, rect.bottom);
    path.close();

    return path;
  }
}

PathBuilderBase triangleBuilder({
  required PaintedModel item,
  required double scale,
  required PaintEditorConfigs paintEditorConfigs,
}) {
  return _TrianglePathBuilder(
    item: item,
    scale: scale,
    paintEditorConfigs: paintEditorConfigs,
  );
}

class _StickerEditorProxy {
  final void Function(WidgetLayer) setLayer;
  final BuildContext context;
  final ProImageEditorState? editorState;

  _StickerEditorProxy(this.setLayer, this.context, {this.editorState});

  void addSticker(Widget widget) {
    if (editorState != null) {
      editorState!.addLayer(WidgetLayer(widget: widget));
    } else {
      setLayer(WidgetLayer(widget: widget));
    }
  }

  void done() => Navigator.pop(context);
  void close() => Navigator.pop(context);
}

class CenterRectClipper extends CustomClipper<Rect> {
  final double width;
  final double height;

  CenterRectClipper({required this.width, required this.height});

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(
      (size.width - width) / 2,
      (size.height - height) / 2,
      width,
      height,
    );
  }

  @override
  bool shouldReclip(CenterRectClipper oldClipper) {
    return width != oldClipper.width || height != oldClipper.height;
  }
}
