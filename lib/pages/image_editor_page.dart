import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:trail_ai_app/pages/ai_result_screen.dart';
import 'package:trail_ai_app/Models/effect_overlay.dart';
import 'package:trail_ai_app/Widgets/effect_overlay_preview.dart';
import 'package:trail_ai_app/Services/image_editor_bloc.dart';
import 'package:trail_ai_app/Services/effect_engine.dart';
import 'package:trail_ai_app/Core/theme_notifier.dart';
import 'package:trail_ai_app/Core/editor_constants.dart';
import 'package:trail_ai_app/Widgets/editor/editor_top_bar.dart';
import 'package:trail_ai_app/Widgets/editor/editor_bottom_panel.dart';
import 'package:trail_ai_app/Widgets/editor/editor_controls.dart';
import 'package:trail_ai_app/Widgets/editor/editor_tools_grid.dart';

// ─── Enums ─────────────────────────────────────────────────────
enum _EditorTool {
  none,
  crop,
  text,
  doodle,
  selective,
  effect,
  filters,
  adjust,
  retouch,
  sticker,
  shape,
  bg,
  stroke,
}

enum _EditorSubTool {
  none,
  exposure,
  contrast,
  hsl,
  curves,
  autoAdjust,
  bgRemove,
  bgBlur,
  font,
  markup,
}

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
    with SingleTickerProviderStateMixin {
  // ── Theme Helpers ─────────────────────────────────────────────────────────
  bool get _isDark => themeNotifier.value;

  final GlobalKey<ProImageEditorState> _editorKey = GlobalKey();

  final List<EffectOverlay> _effects = const [
    EffectOverlay(
      id: 'Light Leak 01',
      category: 'lens',
      assetPath: 'assets/effects/lens/L01.png',
      thumbnailPath: 'assets/effects/lens/L01.png',
      defaultOpacity: 0.8,
      blendMode: ui.BlendMode.plus,
    ),
    EffectOverlay(
      id: 'Golden Hour',
      category: 'lens',
      assetPath: 'assets/effects/lens/L02.png',
      thumbnailPath: 'assets/effects/lens/L02.png',
      defaultOpacity: 0.5,
      blendMode: ui.BlendMode.screen,
    ),
    EffectOverlay(
      id: 'Prism',
      category: 'prism',
      assetPath: 'assets/effects/prism/P01.png',
      thumbnailPath: 'assets/effects/prism/P01.png',
      defaultOpacity: 0.7,
      blendMode: ui.BlendMode.overlay,
    ),
  ];

  late AnimationController _panelCtrl;
  bool _panelExpanded = false;

  Timer? _showOriginalTimer;
  double _baseRadius = 80.0;
  Offset _baseCenter = Offset.zero;
  bool _isResizingEdge = false;

  _EditorTool _activeTool = _EditorTool.none;
  _EditorSubTool _activeSubTool = _EditorSubTool.none;

  double _adjustValue = AppEditorConstants.defaultSliderValue;
  double _hueValue = AppEditorConstants.defaultSliderValue;
  double _satValue = AppEditorConstants.defaultSliderValue;
  double _lumValue = AppEditorConstants.defaultSliderValue;
  int _selectedHslColorIndex = 0;
  final List<Map<String, double>> _hslAdjustments = List.generate(
    7,
    (_) => {
      'hue': AppEditorConstants.defaultSliderValue,
      'saturation': AppEditorConstants.defaultSliderValue,
      'luminance': AppEditorConstants.defaultSliderValue,
    },
  );
  double _bgBlurValue = AppEditorConstants.defaultBgBlurValue;
  double _sizeValue = AppEditorConstants.defaultSizeValue;
  double _strokeValue = AppEditorConstants.defaultStrokeValue;
  String _selectedEffectTab = 'lens';
  List<double>? _selectedFilterMatrix;
  int _selectedFilterIndex = 0;

  String get _panelTitle {
    switch (_activeTool) {
      case _EditorTool.adjust:
        return 'Adjust';
      case _EditorTool.crop:
        return 'Crop';
      case _EditorTool.text:
        return _activeSubTool == _EditorSubTool.font ? 'Font' : 'Basic';
      case _EditorTool.doodle:
        return 'Draw';
      case _EditorTool.effect:
        return 'Effect';
      case _EditorTool.filters:
        return 'Filters';
      case _EditorTool.retouch:
        return 'Retouch';
      case _EditorTool.sticker:
        return 'Sticker';
      case _EditorTool.shape:
        return _activeSubTool == _EditorSubTool.markup ? 'Markup' : 'Shape';
      case _EditorTool.bg:
        return 'BG';
      case _EditorTool.stroke:
        return 'Stroke';
      default:
        return '';
    }
  }

  List<double>? _getLiveMatrix() {
    if (_activeTool == _EditorTool.filters) {
      return _selectedFilterMatrix;
    }
    if (_activeTool == _EditorTool.adjust) {
      if (_activeSubTool == _EditorSubTool.hsl) {
        return EffectEngine().buildSelectiveHSLMatrix(_hslAdjustments);
      }
      if (_activeSubTool == _EditorSubTool.exposure) {
        return EffectEngine().buildColorMatrix(
          (_adjustValue - 0.5) * 2,
          0,
          0,
          0,
        );
      } else if (_activeSubTool == _EditorSubTool.contrast) {
        return EffectEngine().buildColorMatrix(
          0,
          (_adjustValue - 0.5) * 2,
          0,
          0,
        );
      } else if (_activeSubTool == _EditorSubTool.autoAdjust) {
        return EffectEngine().buildColorMatrix(0.2, 0.2, 0.2, 0);
      }
    }
    if (_activeTool == _EditorTool.selective) {
      final state = context.read<ImageEditorBloc>().state;
      return EffectEngine().buildColorMatrix(
        state.circleBrightness,
        state.circleContrast,
        state.circleSaturation,
        state.circleHue,
      );
    }
    return null;
  }

  void _confirmCurrentTool({dynamic subEditor}) {
    final ed = _editorKey.currentState;
    if (ed == null) return;

    final isPackageTool =
        _activeTool == _EditorTool.crop ||
        _activeTool == _EditorTool.text ||
        _activeTool == _EditorTool.doodle ||
        _activeTool == _EditorTool.sticker ||
        _activeTool == _EditorTool.filters ||
        _activeTool == _EditorTool.retouch;

    if (subEditor != null && isPackageTool) {
      subEditor.done();
      setState(() {
        _activeTool = _EditorTool.none;
        _selectedFilterMatrix = null;
        _selectedFilterIndex = 0;
      });
      return;
    }

    if (_activeTool == _EditorTool.bg &&
        _activeSubTool == _EditorSubTool.bgRemove) {
      context.read<ImageEditorBloc>().add(ImageEditorRemoveBackground(ed));
    } else if (_activeTool == _EditorTool.bg &&
        _activeSubTool == _EditorSubTool.bgBlur) {
      context.read<ImageEditorBloc>().add(
        ImageEditorUpdateBgBlurIntensity(_bgBlurValue * 30),
      );
      context.read<ImageEditorBloc>().add(ImageEditorConfirmBgBlur(ed));
    } else if (_activeTool == _EditorTool.adjust &&
        _activeSubTool == _EditorSubTool.curves) {
      final matrix = EffectEngine().buildColorMatrix(
        0,
        0.2,
        0,
        (_hueValue - 0.5) * 360,
      );
      context.read<ImageEditorBloc>().add(
        ImageEditorApplyColorMatrix(ed, matrix),
      );
    } else if (_activeTool == _EditorTool.adjust &&
        _activeSubTool == _EditorSubTool.hsl) {
      final adjustments = List<Map<String, double>>.generate(
        7,
        (i) => Map<String, double>.from(_hslAdjustments[i]),
      );
      context.read<ImageEditorBloc>().add(
        ImageEditorApplySelectiveHSL(ed, adjustments),
      );
    } else if (_activeTool == _EditorTool.effect) {
      context.read<ImageEditorBloc>().add(ImageEditorConfirmOverlay(ed));
    } else if (_activeTool == _EditorTool.selective ||
        (_activeTool == _EditorTool.shape &&
            _activeSubTool == _EditorSubTool.hsl)) {
      context.read<ImageEditorBloc>().add(ImageEditorConfirmCircle(ed));
    } else {
      final matrix = _getLiveMatrix();
      if (matrix != null) {
        context.read<ImageEditorBloc>().add(
          ImageEditorApplyColorMatrix(ed, matrix),
        );
      }
    }

    setState(() {
      _activeTool = _EditorTool.none;
      _activeSubTool = _EditorSubTool.none;
      _selectedFilterMatrix = null;
      _selectedFilterIndex = 0;
      for (var adj in _hslAdjustments) {
        adj['hue'] = AppEditorConstants.defaultSliderValue;
        adj['saturation'] = AppEditorConstants.defaultSliderValue;
        adj['luminance'] = AppEditorConstants.defaultSliderValue;
      }
    });
  }

  void _cancelCurrentTool({dynamic subEditor}) {
    final isPackageTool =
        _activeTool == _EditorTool.crop ||
        _activeTool == _EditorTool.text ||
        _activeTool == _EditorTool.doodle ||
        _activeTool == _EditorTool.sticker ||
        _activeTool == _EditorTool.filters;

    if (subEditor != null && isPackageTool) {
      subEditor.close();
      setState(() {
        _activeTool = _EditorTool.none;
        _selectedFilterMatrix = null;
        _selectedFilterIndex = 0;
      });
      return;
    }
    setState(() {
      _activeTool = _EditorTool.none;
      _activeSubTool = _EditorSubTool.none;
      _selectedFilterMatrix = null;
      _selectedFilterIndex = 0;
      for (var adj in _hslAdjustments) {
        adj['hue'] = AppEditorConstants.defaultSliderValue;
        adj['saturation'] = AppEditorConstants.defaultSliderValue;
        adj['luminance'] = AppEditorConstants.defaultSliderValue;
      }
    });
    final blocState = context.read<ImageEditorBloc>().state;
    if (blocState.isCircleSelecting) {
      context.read<ImageEditorBloc>().add(
        const ImageEditorToggleCircleMode(value: false),
      );
    }
    if (blocState.isOverlaySelecting) {
      context.read<ImageEditorBloc>().add(
        const ImageEditorToggleOverlayMode(value: false),
      );
    }
    if (blocState.isBgBlurSelecting) {
      final ed = _editorKey.currentState;
      if (ed != null) {
        context.read<ImageEditorBloc>().add(
          ImageEditorToggleBgBlurMode(ed, value: false),
        );
      }
    }
  }

  void _handleShowOriginal(bool show) {
    _showOriginalTimer?.cancel();
    context.read<ImageEditorBloc>().add(ImageEditorSetShowOriginal(show));
    if (show) {
      _showOriginalTimer = Timer(const Duration(seconds: 2), () {
        if (mounted) {
          context.read<ImageEditorBloc>().add(
            const ImageEditorSetShowOriginal(false),
          );
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
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
  }

  @override
  void dispose() {
    _showOriginalTimer?.cancel();
    _panelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ImageEditorBloc, ImageEditorState>(
      listenWhen: (p, c) => c.message != null && c.message != p.message,
      listener: (ctx, state) {
        if (state.message != null) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(
              content: Text(state.message!),
              backgroundColor: AppEditorConstants.accent,
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 340, left: 20, right: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      },
      child: BlocBuilder<ImageEditorBloc, ImageEditorState>(
        builder: (context, state) => Scaffold(
          backgroundColor: AppEditorConstants.bgColor(_isDark),
          body: Stack(
            fit: StackFit.expand,
            children: [
              _buildEditor(context, state),
              EditorTopBar(
                isDark: _isDark,
                onBack: () => Navigator.pop(context),
                onUndo: () => _editorKey.currentState?.undoAction(),
                onRedo: () => _editorKey.currentState?.redoAction(),
                onReset: () {},
                onDone: () => _editorKey.currentState?.doneEditing(),
              ),
              EditorCompareButton(
                isDark: _isDark,
                showOriginal: state.showOriginal,
                onTap: () => _handleShowOriginal(!state.showOriginal),
                panelHeight: _calcPanelHeight(context),
              ),
              _buildBottomPanel(context, state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditor(BuildContext context, ImageEditorState state) {
    return ProImageEditor.file(
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
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AIResultScreen(resultImageUrl: file.path),
              ),
            );
          }
        },
      ),
      configs: ProImageEditorConfigs(
        designMode: ImageEditorDesignMode.material,
        theme: Theme.of(context).copyWith(
          canvasColor: AppEditorConstants.bgColor(_isDark),
          scaffoldBackgroundColor: AppEditorConstants.bgColor(_isDark),
          colorScheme: _isDark
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
            color: AppEditorConstants.primaryText(_isDark),
          ),
          appBarTheme: AppBarTheme(
            backgroundColor: Colors.transparent,
            foregroundColor: AppEditorConstants.primaryText(_isDark),
            elevation: 0,
          ),
          sliderTheme: SliderThemeData(
            activeTrackColor: AppEditorConstants.accent,
            thumbColor: AppEditorConstants.accent,
            inactiveTrackColor: _isDark ? Colors.white24 : Colors.black12,
            overlayColor: AppEditorConstants.accent.withAlpha(30),
          ),
        ),
        mainEditor: MainEditorConfigs(
          widgets: MainEditorWidgets(
            bottomBar: (editor, rebuildStream, key) => ReactiveWidget(
              stream: rebuildStream,
              builder: (_) => const SizedBox.shrink(),
            ),
            wrapBody: (editor, rebuildStream, content) {
              return LayoutBuilder(
                builder: (ctx, constraints) {
                  if (state.containerSize != constraints.biggest && mounted) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      context.read<ImageEditorBloc>().add(
                        ImageEditorUpdateContainerSize(constraints.biggest),
                      );
                    });
                  }
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Builder(
                        builder: (ctx) {
                          final matrix = _getLiveMatrix();
                          if (matrix != null) {
                            return ColorFiltered(
                              colorFilter: ColorFilter.matrix(matrix),
                              child: content,
                            );
                          }
                          return content;
                        },
                      ),
                      if (state.isBgBlurSelecting)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: RepaintBoundary(
                              child: Stack(
                                children: [
                                  if (state.bgBlurIntensity > 0)
                                    Positioned.fill(
                                      child: ImageFiltered(
                                        imageFilter: ui.ImageFilter.blur(
                                          sigmaX: state.bgBlurIntensity,
                                          sigmaY: state.bgBlurIntensity,
                                        ),
                                        child: _buildPreviewImage(editor),
                                      ),
                                    )
                                  else
                                    Positioned.fill(
                                      child: _buildPreviewImage(editor),
                                    ),
                                  if (state.bgBlurForegroundImage != null)
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: _ForegroundPainter(
                                          state.bgBlurForegroundImage!,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (state.isCircleSelecting)
                        _buildCircleInteractionLayer(context, state),
                      if (state.isOverlaySelecting)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: RepaintBoundary(
                              child: EffectOverlayPreview(
                                baseImage: null,
                                targetSize: state.containerSize,
                                overlayImage: state.overlayUiImage,
                                opacity: state.overlayOpacity,
                                blendMode:
                                    state.selectedEffect?.blendMode ??
                                    ui.BlendMode.screen,
                              ),
                            ),
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
                      if (state.isProcessing || state.isOverlayLoading)
                        const Center(
                          child: CircularProgressIndicator(
                            color: AppEditorConstants.accent,
                          ),
                        ),
                    ],
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
              builder: (_) => EditorSubEditorTopBar(
                title: 'Text',
                isDark: _isDark,
                onClose: editor.close,
                onDone: editor.done,
              ),
            ),
            bodyItems: (editor, rebuildStream) => [
              ReactiveWidget(
                stream: rebuildStream,
                builder: (_) =>
                    _buildSubEditorPanelOverlay(editor, rebuildStream),
              ),
            ],
            bottomBar: (editor, rebuildStream) => ReactiveWidget(
              stream: rebuildStream,
              builder: (_) => const SizedBox.shrink(),
            ),
          ),
          showTextAlignButton: false,
          showFontScaleButton: false,
          showBackgroundModeButton: false,
          enableMainEditorZoomFactor: false,
          enableTapOutsideToSave: false,
        ),
        cropRotateEditor: CropRotateEditorConfigs(
          widgets: CropRotateEditorWidgets(
            appBar: (editor, rebuildStream) => ReactiveAppbar(
              stream: rebuildStream,
              builder: (_) => EditorSubEditorTopBar(
                title: 'Crop & Rotate',
                isDark: _isDark,
                onClose: editor.close,
                onDone: editor.done,
                onUndo: editor.undoAction,
                onRedo: editor.redoAction,
              ),
            ),
            bodyItems: (editor, rebuildStream) => [
              ReactiveWidget(
                stream: rebuildStream,
                builder: (_) =>
                    _buildSubEditorPanelOverlay(editor, rebuildStream),
              ),
            ],
            bottomBar: (editor, rebuildStream) => ReactiveWidget(
              stream: rebuildStream,
              builder: (_) => const SizedBox.shrink(),
            ),
          ),
          enableGesturePop: false,
          showLayers: true,
          enableDoubleTap: false,
          enableFlipAnimation: false,
          initAspectRatio: 0.0,
        ),
        paintEditor: PaintEditorConfigs(
          widgets: PaintEditorWidgets(
            appBar: (editor, rebuildStream) => ReactiveAppbar(
              stream: rebuildStream,
              builder: (_) => EditorSubEditorTopBar(
                title: 'Paint',
                isDark: _isDark,
                onClose: editor.close,
                onDone: editor.done,
                onUndo: editor.undoAction,
                onRedo: editor.redoAction,
              ),
            ),
            bodyItems: (editor, rebuildStream) => [
              ReactiveWidget(
                stream: rebuildStream,
                builder: (_) =>
                    _buildSubEditorPanelOverlay(editor, rebuildStream),
              ),
            ],
            bottomBar: (editor, rebuildStream) => ReactiveWidget(
              stream: rebuildStream,
              builder: (_) => const SizedBox.shrink(),
            ),
          ),
          enableEdit: true,
          showToggleFillButton: false,
          showLayers: true,
        ),
        filterEditor: FilterEditorConfigs(
          widgets: FilterEditorWidgets(
            appBar: (editor, rebuildStream) => ReactiveAppbar(
              stream: rebuildStream,
              builder: (_) => EditorSubEditorTopBar(
                title: 'Filters',
                isDark: _isDark,
                onClose: editor.close,
                onDone: editor.done,
              ),
            ),
            bodyItems: (editor, rebuildStream) => [
              ReactiveWidget(
                stream: rebuildStream,
                builder: (_) =>
                    _buildSubEditorPanelOverlay(editor, rebuildStream),
              ),
            ],
            bottomBar: (editor, rebuildStream) => ReactiveWidget(
              stream: rebuildStream,
              builder: (_) => const SizedBox.shrink(),
            ),
          ),
          enableGesturePop: false,
          showLayers: true,
        ),
        stickerEditor: const StickerEditorConfigs(
          enableGesturePop: false,
          initWidth: 100,
        ),
      ),
    );
  }

  double _calcPanelHeight(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    double h = 0;
    if (_activeTool == _EditorTool.none) {
      h = _panelExpanded ? 280 : 160;
    } else if (_activeTool == _EditorTool.adjust) {
      if (_activeSubTool == _EditorSubTool.curves) {
        h = 280;
      } else if (_activeSubTool == _EditorSubTool.hsl) {
        h = 240;
      } else {
        h = 180;
      }
    } else if (_activeTool == _EditorTool.bg) {
      h = 180;
    } else if (_activeTool == _EditorTool.doodle ||
        _activeTool == _EditorTool.shape) {
      h = 260;
    } else if (_activeTool == _EditorTool.selective) {
      h = 240;
    } else if (_activeTool == _EditorTool.filters) {
      h = 220;
    } else {
      h = 200;
    }
    return h + bottomPadding;
  }

  Widget _buildBottomPanel(
    BuildContext context,
    ImageEditorState state, {
    dynamic subEditor,
    Stream<void>? rebuildStream,
  }) {
    return EditorBottomPanel(
      isDark: _isDark,
      panelController: _panelCtrl,
      panelExpanded: _panelExpanded,
      child: SafeArea(
        top: false,
        child: ReactiveWidget(
          stream: rebuildStream ?? const Stream.empty(),
          builder: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  EditorPanelHeader(
                    isDark: _isDark,
                    onConfirm: () => _confirmCurrentTool(subEditor: subEditor),
                    onCancel: () => _cancelCurrentTool(subEditor: subEditor),
                  ),
                  EditorPanelHandle(
                    isDark: _isDark,
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
              if (_activeTool != _EditorTool.none) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    EditorActionBtn(
                      icon: Icons.undo,
                      onTap: () {
                        if (subEditor != null) {
                          subEditor.undoAction();
                        } else {
                          _editorKey.currentState?.undoAction();
                        }
                      },
                      isDark: _isDark,
                    ),
                    const SizedBox(width: 16),
                    EditorActionBtn(
                      icon: Icons.redo,
                      onTap: () {
                        if (subEditor != null) {
                          subEditor.redoAction();
                        } else {
                          _editorKey.currentState?.redoAction();
                        }
                      },
                      isDark: _isDark,
                    ),
                    const SizedBox(width: 16),
                    EditorActionBtn(
                      icon: Icons.refresh,
                      onTap: () {
                        setState(() {
                          if (subEditor == null) {
                            _activeSubTool = _EditorSubTool.none;
                            _adjustValue =
                                AppEditorConstants.defaultSliderValue;
                            _hueValue = AppEditorConstants.defaultSliderValue;
                            _satValue = AppEditorConstants.defaultSliderValue;
                            _lumValue = AppEditorConstants.defaultSliderValue;
                            _bgBlurValue =
                                AppEditorConstants.defaultBgBlurValue;
                          }
                        });
                      },
                      isDark: _isDark,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ] else
                const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: _buildControls(state, subEditor: subEditor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls(ImageEditorState state, {dynamic subEditor}) {
    if (_activeTool == _EditorTool.none) {
      return EditorToolsGrid(
        tools: AppEditorConstants.mainTools,
        activeTool: _activeTool.name,
        onToolSelected: (tool) => _onToolSelected(tool, subEditor),
        expanded: _panelExpanded,
        isDark: _isDark,
      );
    }

    if (_activeTool == _EditorTool.crop && subEditor != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: AppEditorConstants.cropSubTools.map((t) {
          return Expanded(
            child: _buildToolButton(
              label: t.label,
              icon: t.icon,
              onTap: () {
                switch (t.subTool) {
                  case 'rotate':
                    subEditor.rotate();
                    break;
                  case 'flip':
                    subEditor.flip();
                    break;
                  case 'ratio':
                    subEditor.openAspectRatioOptions();
                    break;
                  case 'reset':
                    subEditor.reset();
                    break;
                }
              },
            ),
          );
        }).toList(),
      );
    }

    if (_activeTool == _EditorTool.adjust) {
      return Column(
        children: [
          if (_activeSubTool == _EditorSubTool.curves)
            _buildCurvesControls()
          else if (_activeSubTool == _EditorSubTool.hsl)
            _buildHSLControls()
          else if (_activeSubTool != _EditorSubTool.none)
            EditorSliderRow(
              label: 'Adjust',
              value: _adjustValue,
              onChanged: (v) => setState(() => _adjustValue = v),
              isDark: _isDark,
            ),
          const SizedBox(height: 24),
          Center(
            child: EditorSubToolsRow(
              tools: AppEditorConstants.adjustSubTools,
              activeSubTool: _activeSubTool.name,
              onChanged: (v) => setState(
                () => _activeSubTool = _EditorSubTool.values.firstWhere(
                  (e) => e.name == v,
                  orElse: () => _EditorSubTool.none,
                ),
              ),
              isDark: _isDark,
            ),
          ),
        ],
      );
    }

    if (_activeTool == _EditorTool.filters) {
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
        isDark: _isDark,
      );
    }

    if (_activeTool == _EditorTool.bg) {
      return Column(
        children: [
          if (_activeSubTool == _EditorSubTool.bgBlur) ...[
            EditorSliderRow(
              label: 'BG Blur',
              value: _bgBlurValue,
              onChanged: (v) => setState(() => _bgBlurValue = v),
              isDark: _isDark,
            ),
            const SizedBox(height: 24),
          ],
          Center(
            child: EditorSubToolsRow(
              tools: AppEditorConstants.bgSubTools,
              activeSubTool: _activeSubTool.name,
              onChanged: (v) => setState(
                () => _activeSubTool = _EditorSubTool.values.firstWhere(
                  (e) => e.name == v,
                  orElse: () => _EditorSubTool.none,
                ),
              ),
              isDark: _isDark,
            ),
          ),
        ],
      );
    }

    if (_activeTool == _EditorTool.effect) {
      return Column(
        children: [
          EditorEffectTabs(
            categories: AppEditorConstants.effectCategories,
            selectedCategory: _selectedEffectTab,
            onChanged: (v) => setState(() => _selectedEffectTab = v),
            isDark: _isDark,
          ),
          const SizedBox(height: 16),
          _buildEffectThumbnails(),
        ],
      );
    }

    if (_activeTool == _EditorTool.doodle) {
      return Column(
        children: [
          EditorBrushRow(
            brushes: AppEditorConstants.brushModes,
            activeMode: subEditor?.paintMode?.name ?? 'freeStyle',
            onChanged: (mode) {
              if (subEditor != null) {
                subEditor.setMode(
                  PaintMode.values.firstWhere(
                    (e) => e.name == mode,
                    orElse: () => PaintMode.freeStyle,
                  ),
                );
                setState(() {});
              }
            },
            isDark: _isDark,
          ),
          const SizedBox(height: 16),
          EditorSliderRow(
            label: 'Size',
            value: _sizeValue,
            onChanged: (v) {
              setState(() => _sizeValue = v);
              if (subEditor != null) {
                subEditor.setStrokeWidth(v * 50);
              }
            },
            isDark: _isDark,
          ),
        ],
      );
    }

    if (_activeTool == _EditorTool.shape) {
      return Column(
        children: [
          EditorShapeRow(
            shapes: AppEditorConstants.shapeModes,
            activeMode: subEditor?.paintMode?.name ?? 'circle',
            onChanged: (mode) {
              if (subEditor != null) {
                subEditor.setMode(
                  PaintMode.values.firstWhere(
                    (e) => e.name == mode,
                    orElse: () => PaintMode.circle,
                  ),
                );
                setState(() {});
              }
            },
            isDark: _isDark,
          ),
          const SizedBox(height: 16),
          EditorSliderRow(
            label: 'Stroke',
            value: _strokeValue,
            onChanged: (v) {
              setState(() => _strokeValue = v);
              if (subEditor != null) {
                subEditor.setStrokeWidth(v * 50);
              }
            },
            isDark: _isDark,
          ),
        ],
      );
    }

    if (_activeTool == _EditorTool.selective) {
      return _buildSelectiveControls(subEditor: subEditor);
    }

    return const SizedBox.shrink();
  }

  void _onToolSelected(String tool, dynamic subEditor) {
    final ed = _editorKey.currentState;
    if (ed == null) return;
    _panelCtrl.reverse();

    switch (tool) {
      case 'crop':
        ed.openCropRotateEditor();
        setState(() => _activeTool = _EditorTool.crop);
        break;
      case 'text':
        ed.openTextEditor();
        setState(() => _activeTool = _EditorTool.text);
        break;
      case 'doodle':
        ed.openPaintEditor();
        setState(() => _activeTool = _EditorTool.doodle);
        break;
      case 'sticker':
        ed.openStickerEditor();
        setState(() => _activeTool = _EditorTool.sticker);
        break;
      case 'filters':
        ed.openFilterEditor();
        setState(() => _activeTool = _EditorTool.filters);
        break;
      case 'selective':
        context.read<ImageEditorBloc>().add(
          const ImageEditorToggleCircleMode(value: true),
        );
        setState(() => _activeTool = _EditorTool.selective);
        break;
      case 'effect':
        context.read<ImageEditorBloc>().add(
          const ImageEditorToggleOverlayMode(value: true),
        );
        setState(() => _activeTool = _EditorTool.effect);
        break;
      default:
        setState(
          () => _activeTool = _EditorTool.values.firstWhere(
            (e) => e.name == tool,
            orElse: () => _EditorTool.none,
          ),
        );
    }
  }

  Widget _buildToolButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    double? width,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: width ?? (MediaQuery.of(context).size.width / 4 - 8),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: AppEditorConstants.toolBtnSize,
              height: AppEditorConstants.toolBtnSize,
              decoration: BoxDecoration(
                color: AppEditorConstants.iconBg(_isDark),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppEditorConstants.primaryText(_isDark),
                size: 24,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppEditorConstants.textDim(_isDark),
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

  Widget _buildSubEditorPanelOverlay(
    dynamic editor,
    Stream<void> rebuildStream,
  ) {
    return BlocBuilder<ImageEditorBloc, ImageEditorState>(
      bloc: context.read<ImageEditorBloc>(),
      builder: (builderCtx, state) {
        return _buildBottomPanel(
          builderCtx,
          state,
          subEditor: editor,
          rebuildStream: rebuildStream,
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
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
                    borderRadius: BorderRadius.circular(12),
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
                  onTap: () => context.read<ImageEditorBloc>().add(
                    ImageEditorSelectOverlay(e),
                  ),
                  child: Container(
                    width: 64,
                    height: 64,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: AppEditorConstants.iconBg(_isDark),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: active
                            ? AppEditorConstants.accent
                            : Colors.transparent,
                        width: 1.5,
                      ),
                      image: DecorationImage(
                        image: AssetImage(e.thumbnailPath),
                        fit: BoxFit.cover,
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

  Widget _buildSelectiveControls({dynamic subEditor}) {
    return BlocBuilder<ImageEditorBloc, ImageEditorState>(
      builder: (context, state) {
        return Column(
          children: [
            EditorSliderRow(
              label: 'Blur',
              value: state.circleBlur,
              onChanged: (v) => context.read<ImageEditorBloc>().add(
                ImageEditorUpdateCircleFilters(blur: v),
              ),
              isDark: _isDark,
            ),
            const SizedBox(height: 8),
            EditorSliderRow(
              label: 'Brightness',
              value: state.circleBrightness,
              onChanged: (v) => context.read<ImageEditorBloc>().add(
                ImageEditorUpdateCircleFilters(brightness: v),
              ),
              isDark: _isDark,
            ),
            const SizedBox(height: 8),
            EditorSliderRow(
              label: 'Contrast',
              value: state.circleContrast,
              onChanged: (v) => context.read<ImageEditorBloc>().add(
                ImageEditorUpdateCircleFilters(contrast: v),
              ),
              isDark: _isDark,
            ),
            const SizedBox(height: 8),
            EditorSliderRow(
              label: 'Saturation',
              value: state.circleSaturation,
              onChanged: (v) => context.read<ImageEditorBloc>().add(
                ImageEditorUpdateCircleFilters(saturation: v),
              ),
              isDark: _isDark,
            ),
            const SizedBox(height: 8),
            EditorSliderRow(
              label: 'Hue',
              value: state.circleHue,
              onChanged: (v) => context.read<ImageEditorBloc>().add(
                ImageEditorUpdateCircleFilters(hue: v * 360),
              ),
              isDark: _isDark,
            ),
          ],
        );
      },
    );
  }

  Widget _buildCurvesControls() {
    return Column(
      children: [
        EditorSliderRow(
          label: 'Hue',
          value: _hueValue,
          onChanged: (v) => setState(() => _hueValue = v),
          isDark: _isDark,
        ),
        const SizedBox(height: 8),
        EditorSliderRow(
          label: 'Saturation',
          value: _satValue,
          onChanged: (v) => setState(() => _satValue = v),
          isDark: _isDark,
        ),
        const SizedBox(height: 8),
        EditorSliderRow(
          label: 'Luminance',
          value: _lumValue,
          onChanged: (v) => setState(() => _lumValue = v),
          isDark: _isDark,
        ),
      ],
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
        const SizedBox(height: 16),
        EditorSliderRow(
          label: 'Hue',
          value: _hslAdjustments[_selectedHslColorIndex]['hue']!,
          onChanged: (v) => setState(
            () => _hslAdjustments[_selectedHslColorIndex]['hue'] = v,
          ),
          isDark: _isDark,
        ),
        const SizedBox(height: 8),
        EditorSliderRow(
          label: 'Sat',
          value: _hslAdjustments[_selectedHslColorIndex]['saturation']!,
          onChanged: (v) => setState(
            () => _hslAdjustments[_selectedHslColorIndex]['saturation'] = v,
          ),
          isDark: _isDark,
        ),
        const SizedBox(height: 8),
        EditorSliderRow(
          label: 'Lum',
          value: _hslAdjustments[_selectedHslColorIndex]['luminance']!,
          onChanged: (v) => setState(
            () => _hslAdjustments[_selectedHslColorIndex]['luminance'] = v,
          ),
          isDark: _isDark,
        ),
      ],
    );
  }

  Widget _buildPreviewImage(dynamic editor) {
    final blocState = context.read<ImageEditorBloc>().state;
    return Image.file(blocState.imageFile, fit: BoxFit.contain);
  }

  Widget _buildCircleInteractionLayer(
    BuildContext context,
    ImageEditorState state,
  ) {
    return Positioned.fill(
      child: GestureDetector(
        onPanStart: (details) {
          final renderBox = context.findRenderObject() as RenderBox;
          final localPos = renderBox.globalToLocal(details.globalPosition);
          setState(() {
            _baseCenter = localPos;
            _isResizingEdge = false;
          });
          context.read<ImageEditorBloc>().add(
            ImageEditorUpdateCircle(center: localPos),
          );
        },
        onPanUpdate: (details) {
          final renderBox = context.findRenderObject() as RenderBox;
          final localPos = renderBox.globalToLocal(details.globalPosition);
          if (!_isResizingEdge) {
            final dx = localPos.dx - _baseCenter.dx;
            final dy = localPos.dy - _baseCenter.dy;
            _baseRadius = (dx.abs() + dy.abs()) / 2;
            _isResizingEdge = true;
          }
          context.read<ImageEditorBloc>().add(
            ImageEditorUpdateCircle(radius: _baseRadius),
          );
        },
        child: CustomPaint(
          painter: _CirclePainter(
            center: state.circleCenter,
            radius: state.circleRadius,
            accentColor: AppEditorConstants.accent,
          ),
        ),
      ),
    );
  }
}

// ─── Painters ──────────────────────────────────────────────────
class _CirclePainter extends CustomPainter {
  final Offset center;
  final double radius;
  final Color accentColor;

  _CirclePainter({
    required this.center,
    required this.radius,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = accentColor.withAlpha(60)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paint);

    final borderPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CirclePainter oldDelegate) {
    return oldDelegate.center != center || oldDelegate.radius != radius;
  }
}

class _ForegroundPainter extends CustomPainter {
  final ui.Image image;

  _ForegroundPainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );
  }

  @override
  bool shouldRepaint(covariant _ForegroundPainter oldDelegate) {
    return oldDelegate.image != image;
  }
}
