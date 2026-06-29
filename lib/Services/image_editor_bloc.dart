import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:image_background_remover/image_background_remover.dart';
import 'package:trail_ai_app/Services/effect_engine.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trail_ai_app/Models/effect_overlay.dart';
import 'package:flutter/foundation.dart';
import 'package:trail_ai_app/Helpers/image_picker_helper.dart';
import 'package:trail_ai_app/Models/curves_data.dart';
import 'package:trail_ai_app/Services/curves_processor.dart';
import 'package:http/http.dart' as http;
import 'package:trail_ai_app/Services/replicate_service.dart';
import 'package:trail_ai_app/Services/remote_config_service.dart';
import 'package:trail_ai_app/Models/history_entry.dart';
import 'package:trail_ai_app/Services/effect_service.dart';

// ─────────────────────────────────────────────
// EVENTS
// ─────────────────────────────────────────────

abstract class ImageEditorEvent extends Equatable {
  const ImageEditorEvent();
  @override
  List<Object?> get props => [];
}

class ImageEditorInit extends ImageEditorEvent {
  final File imageFile;
  const ImageEditorInit(this.imageFile);
}

class ImageEditorUpdateContainerSize extends ImageEditorEvent {
  final Size size;
  const ImageEditorUpdateContainerSize(this.size);
}

class ImageEditorToggleCircleMode extends ImageEditorEvent {
  final bool? value;
  const ImageEditorToggleCircleMode({this.value});
}

class ImageEditorUpdateCircle extends ImageEditorEvent {
  final Offset? center;
  final double? radius;
  final bool? editInside;
  const ImageEditorUpdateCircle({this.center, this.radius, this.editInside});
}

class ImageEditorUpdateCircleFilters extends ImageEditorEvent {
  final double? blur;
  final double? brightness;
  final double? contrast;
  final double? saturation;
  final double? hue;
  const ImageEditorUpdateCircleFilters({
    this.blur,
    this.brightness,
    this.contrast,
    this.saturation,
    this.hue,
  });
}

class ImageEditorConfirmCircle extends ImageEditorEvent {
  final ProImageEditorState editor;
  const ImageEditorConfirmCircle(this.editor);
}

class ImageEditorToggleOverlayMode extends ImageEditorEvent {
  final bool? value;
  const ImageEditorToggleOverlayMode({this.value});
}

class ImageEditorSelectOverlay extends ImageEditorEvent {
  final EffectOverlay? effect;
  final bool isPortrait;
  const ImageEditorSelectOverlay(this.effect, {this.isPortrait = true});
  @override
  List<Object?> get props => [effect, isPortrait];
}

class ImageEditorUpdateOverlayOpacity extends ImageEditorEvent {
  final double opacity;
  const ImageEditorUpdateOverlayOpacity(this.opacity);
}

class ImageEditorConfirmOverlay extends ImageEditorEvent {
  final ProImageEditorState editor;
  const ImageEditorConfirmOverlay(this.editor);
}

class ImageEditorToggleBgBlurMode extends ImageEditorEvent {
  final ProImageEditorState editor;
  final bool? value;
  const ImageEditorToggleBgBlurMode(this.editor, {this.value});
}

class ImageEditorUpdateBgBlurIntensity extends ImageEditorEvent {
  final double intensity;
  const ImageEditorUpdateBgBlurIntensity(this.intensity);
}

class ImageEditorConfirmBgBlur extends ImageEditorEvent {
  final ProImageEditorState editor;
  const ImageEditorConfirmBgBlur(this.editor);
}

class ImageEditorToggleBgRemoveMode extends ImageEditorEvent {
  final ProImageEditorState editor;
  final bool? value;
  const ImageEditorToggleBgRemoveMode(this.editor, {this.value});
}

class ImageEditorConfirmBgRemove extends ImageEditorEvent {
  final ProImageEditorState editor;
  const ImageEditorConfirmBgRemove(this.editor);
}

class ImageEditorRemoveBackground extends ImageEditorEvent {
  final ProImageEditorState editor;
  const ImageEditorRemoveBackground(this.editor);
}

class ImageEditorChangeBackground extends ImageEditorEvent {
  final ProImageEditorState editor;
  const ImageEditorChangeBackground(this.editor);
}

class ImageEditorApplyColorMatrix extends ImageEditorEvent {
  final ProImageEditorState editor;
  final List<double> matrix;
  const ImageEditorApplyColorMatrix(this.editor, this.matrix);
}

class ImageEditorApplySelectiveHSL extends ImageEditorEvent {
  final ProImageEditorState editor;
  final List<Map<String, double>> adjustments;
  const ImageEditorApplySelectiveHSL(this.editor, this.adjustments);
}

class ImageEditorApplyCurves extends ImageEditorEvent {
  final ProImageEditorState editor;
  final CurvesData curves;
  const ImageEditorApplyCurves(this.editor, this.curves);
}

/// Generic event for per-pixel adjust tools (grain, vignette, sharpen, etc.).
class ImageEditorApplyPixelEffect extends ImageEditorEvent {
  final ProImageEditorState editor;

  /// One of: 'grain', 'vignette', 'sharpen', 'denoise', 'clarity',
  ///          'vibrance', 'convex', 'skinTone'
  final String effectName;

  /// Normalised strength value 0.0–1.0 (0.5 = neutral slider mid-point).
  final double strength;
  const ImageEditorApplyPixelEffect(
    this.editor,
    this.effectName,
    this.strength,
  );
  @override
  List<Object?> get props => [effectName, strength];
}

class ImageEditorSetShowOriginal extends ImageEditorEvent {
  final bool value;
  const ImageEditorSetShowOriginal(this.value);
}

class ImageEditorApplyRetouch extends ImageEditorEvent {
  final ProImageEditorState editor;
  final double strength;
  const ImageEditorApplyRetouch(this.editor, this.strength);
  @override
  List<Object?> get props => [strength];
}

class ImageEditorConfirmFrame extends ImageEditorEvent {
  final ProImageEditorState editor;
  final String frameUrl;
  const ImageEditorConfirmFrame(this.editor, this.frameUrl);
  @override
  List<Object?> get props => [frameUrl];
}

// ── Undo / Redo Events ───────────────────────
class ImageEditorUndo extends ImageEditorEvent {
  final ProImageEditorState editor;
  const ImageEditorUndo(this.editor);
  @override
  List<Object?> get props => [];
}

class ImageEditorRedo extends ImageEditorEvent {
  final ProImageEditorState editor;
  const ImageEditorRedo(this.editor);
  @override
  List<Object?> get props => [];
}

// ── Reset Event ───────────────────────────────
class ImageEditorReset extends ImageEditorEvent {
  final ProImageEditorState editor;
  const ImageEditorReset(this.editor);
  @override
  List<Object?> get props => [];
}

// ─────────────────────────────────────────────
// STATE
// ─────────────────────────────────────────────

class ImageEditorState extends Equatable {
  final File imageFile;
  final bool showOriginal;
  final Size containerSize;

  // Circle state
  final bool isCircleSelecting;
  final Offset circleCenter;
  final double circleRadius;
  final bool editInsideCircle;
  final double circleBlur;
  final double circleBrightness;
  final double circleContrast;
  final double circleSaturation;
  final double circleHue;

  // Bg Blur state
  final bool isBgBlurSelecting;
  final double bgBlurIntensity;
  final ui.Image? bgBlurForegroundImage;
  final ui.Image? bgBlurBackgroundImage;
  final bool isProcessing;

  // Overlay state
  final bool isOverlaySelecting;
  final EffectOverlay? selectedEffect;
  final double overlayOpacity;
  final ui.Image? overlayUiImage;
  final bool isOverlayLoading;

  // Bg Remove state
  final bool isBgRemoveSelecting;
  final ui.Image? bgRemovePreviewImage;

  final String? message;
  final Size? bgBlurSourceSize;
  final double imageAspectRatio;

  // History stack state
  final bool canUndo;
  final bool canRedo;

  /// One-shot trigger: the page listens to this and closes any active tool panel.
  /// Auto-resets to false on the next state emission (see copyWith).
  final bool closeToolTrigger;

  const ImageEditorState({
    required this.imageFile,
    this.showOriginal = false,
    this.containerSize = Size.zero,
    this.isCircleSelecting = false,
    this.circleCenter = Offset.zero,
    this.circleRadius = 80.0,
    this.editInsideCircle = true,
    this.circleBlur = 0.0,
    this.circleBrightness = 0.5,
    this.circleContrast = 0.5,
    this.circleSaturation = 0.5,
    this.circleHue = 0.5,
    this.isBgBlurSelecting = false,
    this.bgBlurIntensity = 0.0,
    this.bgBlurForegroundImage,
    this.bgBlurBackgroundImage,
    this.isProcessing = false,
    this.isOverlaySelecting = false,
    this.selectedEffect,
    this.overlayOpacity = 0.8,
    this.overlayUiImage,
    this.isOverlayLoading = false,
    this.isBgRemoveSelecting = false,
    this.bgRemovePreviewImage,
    this.bgBlurSourceSize,
    this.imageAspectRatio = 1.0,
    this.message,
    this.canUndo = false,
    this.canRedo = false,
    this.closeToolTrigger = false,
  });

  ImageEditorState copyWith({
    File? imageFile,
    bool? showOriginal,
    Size? containerSize,
    bool? isCircleSelecting,
    Offset? circleCenter,
    double? circleRadius,
    bool? editInsideCircle,
    double? circleBlur,
    double? circleBrightness,
    double? circleContrast,
    double? circleSaturation,
    double? circleHue,
    bool? isBgBlurSelecting,
    double? bgBlurIntensity,
    ui.Image? bgBlurForegroundImage,
    bool clearBgBlurForegroundImage = false,
    ui.Image? bgBlurBackgroundImage,
    bool clearBgBlurBackgroundImage = false,
    bool? isProcessing,
    bool? isOverlaySelecting,
    EffectOverlay? selectedEffect,
    bool clearSelectedEffect = false,
    double? overlayOpacity,
    ui.Image? overlayUiImage,
    bool clearOverlayUiImage = false,
    bool? isOverlayLoading,
    bool? isBgRemoveSelecting,
    ui.Image? bgRemovePreviewImage,
    bool clearBgRemovePreviewImage = false,
    Size? bgBlurSourceSize,
    double? imageAspectRatio,
    String? message,
    bool clearMessage = false,
    bool? canUndo,
    bool? canRedo,
    // closeToolTrigger uses a one-shot pattern: defaults to false,
    // so it auto-resets on the next unrelated state emission.
    bool? closeToolTrigger,
  }) {
    return ImageEditorState(
      imageFile: imageFile ?? this.imageFile,
      showOriginal: showOriginal ?? this.showOriginal,
      containerSize: containerSize ?? this.containerSize,
      isCircleSelecting: isCircleSelecting ?? this.isCircleSelecting,
      circleCenter: circleCenter ?? this.circleCenter,
      circleRadius: circleRadius ?? this.circleRadius,
      editInsideCircle: editInsideCircle ?? this.editInsideCircle,
      circleBlur: circleBlur ?? this.circleBlur,
      circleBrightness: circleBrightness ?? this.circleBrightness,
      circleContrast: circleContrast ?? this.circleContrast,
      circleSaturation: circleSaturation ?? this.circleSaturation,
      circleHue: circleHue ?? this.circleHue,
      isBgBlurSelecting: isBgBlurSelecting ?? this.isBgBlurSelecting,
      bgBlurIntensity: bgBlurIntensity ?? this.bgBlurIntensity,
      bgBlurForegroundImage: clearBgBlurForegroundImage
          ? null
          : (bgBlurForegroundImage ?? this.bgBlurForegroundImage),
      bgBlurBackgroundImage: clearBgBlurBackgroundImage
          ? null
          : (bgBlurBackgroundImage ?? this.bgBlurBackgroundImage),
      isProcessing: isProcessing ?? this.isProcessing,
      isOverlaySelecting: isOverlaySelecting ?? this.isOverlaySelecting,
      selectedEffect: clearSelectedEffect
          ? null
          : (selectedEffect ?? this.selectedEffect),
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
      overlayUiImage: clearOverlayUiImage
          ? null
          : (overlayUiImage ?? this.overlayUiImage),
      isOverlayLoading: isOverlayLoading ?? this.isOverlayLoading,
      isBgRemoveSelecting: isBgRemoveSelecting ?? this.isBgRemoveSelecting,
      bgRemovePreviewImage: clearBgRemovePreviewImage
          ? null
          : (bgRemovePreviewImage ?? this.bgRemovePreviewImage),
      bgBlurSourceSize: bgBlurSourceSize ?? this.bgBlurSourceSize,
      imageAspectRatio: imageAspectRatio ?? this.imageAspectRatio,
      message: clearMessage ? null : (message ?? this.message),
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      closeToolTrigger: closeToolTrigger ?? false, // one-shot: auto-reset
    );
  }

  @override
  List<Object?> get props => [
    imageFile,
    showOriginal,
    containerSize,
    isCircleSelecting,
    circleCenter,
    circleRadius,
    editInsideCircle,
    circleBlur,
    circleBrightness,
    circleContrast,
    circleSaturation,
    circleHue,
    isBgBlurSelecting,
    bgBlurIntensity,
    bgBlurForegroundImage,
    bgBlurBackgroundImage,
    isBgRemoveSelecting,
    bgRemovePreviewImage,
    bgBlurSourceSize,
    imageAspectRatio,
    isProcessing,
    isOverlaySelecting,
    selectedEffect,
    overlayOpacity,
    overlayUiImage,
    isOverlayLoading,
    message,
    canUndo,
    canRedo,
    closeToolTrigger,
  ];
}

// ─────────────────────────────────────────────
// BLOC
// ─────────────────────────────────────────────

class ImageEditorBloc extends Bloc<ImageEditorEvent, ImageEditorState> {
  // ── History Stack ──────────────────────────

  final List<HistoryEntry> _undoStack = [];
  final List<HistoryEntry> _redoStack = [];
  static const int _maxHistoryEntries = 20;

  bool get _canUndo => _undoStack.isNotEmpty;
  bool get _canRedo => _redoStack.isNotEmpty;

  /// Push a new entry onto the undo stack.
  /// Clears the redo stack (a new edit invalidates redo) and deletes the
  /// on-disk file for each evicted redo entry to avoid storage leaks.
  /// Evicts and deletes the oldest undo entry when the stack exceeds the cap.
  Future<void> _pushUndo(HistoryEntry entry) async {
    _undoStack.add(entry);
    if (_undoStack.length > _maxHistoryEntries) {
      final evicted = _undoStack.removeAt(0);
      unawaited(evicted.deleteFile());
    }
    // Evict redo stack — a new edit makes all redo entries invalid.
    for (final e in _redoStack) {
      unawaited(e.deleteFile());
    }
    _redoStack.clear();
  }

  /// Push a new entry onto the redo stack (used during undo/redo).
  /// Evicts and deletes the oldest entry when the stack exceeds the cap.
  Future<void> _pushRedo(HistoryEntry entry) async {
    _redoStack.add(entry);
    if (_redoStack.length > _maxHistoryEntries) {
      final evicted = _redoStack.removeAt(0);
      unawaited(evicted.deleteFile());
    }
  }

  ImageEditorBloc(File initialFile)
    : super(ImageEditorState(imageFile: initialFile)) {
    on<ImageEditorInit>(_onInit);
    on<ImageEditorUpdateContainerSize>(_onUpdateContainerSize);
    on<ImageEditorToggleCircleMode>(_onToggleCircleMode);
    on<ImageEditorUpdateCircle>(_onUpdateCircle);
    on<ImageEditorUpdateCircleFilters>(_onUpdateCircleFilters);
    on<ImageEditorConfirmCircle>(_onConfirmCircle);
    on<ImageEditorToggleOverlayMode>(_onToggleOverlayMode);
    on<ImageEditorSelectOverlay>(_onSelectOverlay);
    on<ImageEditorUpdateOverlayOpacity>(_onUpdateOverlayOpacity);
    on<ImageEditorConfirmOverlay>(_onConfirmOverlay);
    on<ImageEditorToggleBgBlurMode>(_onToggleBgBlurMode);
    on<ImageEditorUpdateBgBlurIntensity>(_onUpdateBgBlurIntensity);
    on<ImageEditorConfirmBgBlur>(_onConfirmBgBlur);
    on<ImageEditorToggleBgRemoveMode>(_onToggleBgRemoveMode);
    on<ImageEditorConfirmBgRemove>(_onConfirmBgRemove);
    on<ImageEditorRemoveBackground>(_onRemoveBackground);
    on<ImageEditorChangeBackground>(_onChangeBackground);
    on<ImageEditorApplyColorMatrix>(_onApplyColorMatrix);
    on<ImageEditorApplySelectiveHSL>(_onApplySelectiveHSL);
    on<ImageEditorApplyCurves>(_onApplyCurves);
    on<ImageEditorApplyPixelEffect>(_onApplyPixelEffect);
    on<ImageEditorSetShowOriginal>(_onSetShowOriginal);
    on<ImageEditorApplyRetouch>(_onApplyRetouch);
    on<ImageEditorConfirmFrame>(_onConfirmFrame);
    // History events
    on<ImageEditorUndo>(_onUndo);
    on<ImageEditorRedo>(_onRedo);
    on<ImageEditorReset>(_onReset);
  }

  Future<void> _onInit(
    ImageEditorInit event,
    Emitter<ImageEditorState> emit,
  ) async {
    try {
      BackgroundRemover.instance.initializeOrt();
    } catch (e) {
      // ISSUE #6 FIX: Log the failure instead of silently swallowing it.
      // The background remover tool will show a graceful error when tapped.
      debugPrint(
        '⚠️ [ImageEditorBloc] ONNX runtime failed to initialise: $e\n'
        'Background removal and BG blur tools will be unavailable.',
      );
    }

    try {
      final bytes = await event.imageFile.readAsBytes();

      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final ar = image.width / image.height;
      emit(state.copyWith(imageAspectRatio: ar));
      image.dispose();
    } catch (e) {
      debugPrint('Error detecting image aspect ratio: $e');
    }
  }

  void _onUpdateContainerSize(
    ImageEditorUpdateContainerSize event,
    Emitter<ImageEditorState> emit,
  ) {
    if (state.circleCenter == Offset.zero) {
      emit(
        state.copyWith(
          containerSize: event.size,
          circleCenter: Offset(event.size.width / 2, event.size.height / 2),
        ),
      );
    } else {
      emit(state.copyWith(containerSize: event.size));
    }
  }

  void _onToggleCircleMode(
    ImageEditorToggleCircleMode event,
    Emitter<ImageEditorState> emit,
  ) {
    final newValue = event.value ?? !state.isCircleSelecting;
    if (!newValue) {
      if (state.isProcessing) {
        emit(state.copyWith(isCircleSelecting: false));
        return;
      }
      emit(
        state.copyWith(
          isCircleSelecting: false,
          circleBlur: 0.0,
          circleBrightness: 0.5,
          circleContrast: 0.5,
          circleSaturation: 0.5,
          circleHue: 0.5,
        ),
      );
    } else {
      emit(
        state.copyWith(
          isCircleSelecting: true,
          isOverlaySelecting: false,
          isBgBlurSelecting: false,
        ),
      );
    }
  }

  void _onUpdateCircle(
    ImageEditorUpdateCircle event,
    Emitter<ImageEditorState> emit,
  ) {
    emit(
      state.copyWith(
        circleCenter: event.center,
        circleRadius: event.radius,
        editInsideCircle: event.editInside,
      ),
    );
  }

  void _onUpdateCircleFilters(
    ImageEditorUpdateCircleFilters event,
    Emitter<ImageEditorState> emit,
  ) {
    emit(
      state.copyWith(
        circleBlur: event.blur,
        circleBrightness: event.brightness,
        circleContrast: event.contrast,
        circleSaturation: event.saturation,
        circleHue: event.hue,
      ),
    );
  }

  Future<void> _onConfirmCircle(
    ImageEditorConfirmCircle event,
    Emitter<ImageEditorState> emit,
  ) async {
    final editor = event.editor;
    final currentImage = editor.stateManager.activeBackgroundImage;
    if (currentImage == null || state.containerSize == Size.zero) {
      emit(state.copyWith(isCircleSelecting: false));
      return;
    }

    emit(state.copyWith(isProcessing: true));

    try {
      // Capture bytes BEFORE the edit (will be pushed after success)
      final bytesBefore = await currentImage.safeByteArray();

      final codec = await ui.instantiateImageCodec(bytesBefore);
      final ui.Image baseUiImage = (await codec.getNextFrame()).image;

      final imgW = baseUiImage.width.toDouble();
      final imgH = baseUiImage.height.toDouble();
      final cW = state.containerSize.width;
      final cH = state.containerSize.height;
      final imgAR = imgW / imgH;
      final conAR = cW / cH;

      double renderedW, renderedH, offsetX, offsetY;
      if (imgAR > conAR) {
        renderedW = cW;
        renderedH = cW / imgAR;
        offsetX = 0;
        offsetY = (cH - renderedH) / 2;
      } else {
        renderedH = cH;
        renderedW = cH * imgAR;
        offsetX = (cW - renderedW) / 2;
        offsetY = 0;
      }

      final scale = imgW / renderedW;
      final imgCx = (state.circleCenter.dx - offsetX) * scale;
      final imgCy = (state.circleCenter.dy - offsetY) * scale;
      final imgRadius = state.circleRadius * scale;

      final resultImg = await EffectEngine().applyCircleAdjustment(
        srcImg: baseUiImage,
        center: Offset(imgCx, imgCy),
        radius: imgRadius,
        editInside: state.editInsideCircle,
        blur: state.circleBlur * 30,
        brightness: (state.circleBrightness - 0.5) * 2,
        contrast: (state.circleContrast - 0.5) * 2,
        saturation: (state.circleSaturation - 0.5) * 2,
        hue: (state.circleHue - 0.5) * 360,
      );

      final resultBytes = await EffectEngine().exportToBytes(resultImg);
      final dir = await getTemporaryDirectory();
      final outFile = File(
        '${dir.path}/circle_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await outFile.writeAsBytes(resultBytes);

      editor.stateManager.updateBackgroundImages(
        oldImage: currentImage.copyWith(),
        newImage: EditorImage.file(outFile),
      );

      // ── Push to history AFTER success ─────
      await _pushUndo(
        await HistoryEntry.fromBytes(bytes: bytesBefore, label: 'Circle'),
      );

      emit(
        state.copyWith(
          isProcessing: false,
          isCircleSelecting: false,
          message: 'Applied!',
          canUndo: _canUndo,
          canRedo: _canRedo,
        ),
      );
      editor.setState(() {});
      baseUiImage.dispose();
      resultImg.dispose();
    } catch (e, stackTrace) {
      debugPrint('Error in _onConfirmCircle: $e\n$stackTrace');
      emit(state.copyWith(isProcessing: false, message: 'Error: $e'));
    }
  }

  void _onToggleOverlayMode(
    ImageEditorToggleOverlayMode event,
    Emitter<ImageEditorState> emit,
  ) {
    final newValue = event.value ?? !state.isOverlaySelecting;
    if (!newValue) {
      if (state.isProcessing) {
        emit(state.copyWith(isOverlaySelecting: false));
        return;
      }
      final oldImg = state.overlayUiImage;
      emit(
        state.copyWith(
          isOverlaySelecting: false,
          clearSelectedEffect: true,
          clearOverlayUiImage: true,
          isOverlayLoading: false,
        ),
      );
      oldImg?.dispose();
    } else {
      emit(
        state.copyWith(
          isOverlaySelecting: true,
          isCircleSelecting: false,
          isBgBlurSelecting: false,
        ),
      );
    }
  }

  Future<void> _onSelectOverlay(
    ImageEditorSelectOverlay event,
    Emitter<ImageEditorState> emit,
  ) async {
    emit(
      state.copyWith(
        isOverlayLoading: true,
        selectedEffect: event.effect,
        overlayOpacity: event.effect?.defaultOpacity ?? state.overlayOpacity,
      ),
    );

    if (event.effect == null) {
      _disposeOverlayImage();
      emit(state.copyWith(clearOverlayUiImage: true, isOverlayLoading: false));
      return;
    }

    try {
      final oldImage = state.overlayUiImage;
      final path = event.effect!.getEffectivePath(event.isPortrait);
      final filename = path.split('/').last.split('.').first;
      final index = int.tryParse(filename.replaceAll(RegExp(r'\D'), '')) ?? 1;

      ui.Image? newImage;
      try {
        final bytes = await EffectService().getEffectImage(
          category: event.effect!.category,
          index: index,
          isPortrait: event.isPortrait,
        );
        if (bytes != null && bytes.isNotEmpty) {
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          newImage = frame.image;
        } else {
          debugPrint('No bytes received from Firebase Storage for effect: ${event.effect!.id}');
        }
      } catch (e) {
        debugPrint('Failed to load overlay from Firebase: $e');
      }

      emit(state.copyWith(overlayUiImage: newImage, isOverlayLoading: false));
      _disposeImage(oldImage);
    } catch (e, stackTrace) {
      debugPrint('Error in _onSelectOverlay: $e\n$stackTrace');
      emit(
        state.copyWith(
          isOverlayLoading: false,
          message: 'Error loading overlay: $e',
        ),
      );
    }
  }

  void _disposeImage(ui.Image? image) {
    if (image == null) return;
    try {
      image.dispose();
    } catch (_) {
      // Image already disposed or in invalid state
    }
  }

  void _disposeOverlayImage() {
    _disposeImage(state.overlayUiImage);
  }

  void _onUpdateOverlayOpacity(
    ImageEditorUpdateOverlayOpacity event,
    Emitter<ImageEditorState> emit,
  ) {
    emit(state.copyWith(overlayOpacity: event.opacity));
  }

  Future<void> _onConfirmOverlay(
    ImageEditorConfirmOverlay event,
    Emitter<ImageEditorState> emit,
  ) async {
    final editor = event.editor;
    final currentImage = editor.stateManager.activeBackgroundImage;
    final overlayUiImage = state.overlayUiImage;
    final selectedEffect = state.selectedEffect;

    // Check if overlay is still loading
    if (state.isOverlayLoading) {
      emit(state.copyWith(message: 'Please wait for effect to load'));
      return;
    }

    // Check for null values and provide user feedback
    if (currentImage == null) {
      emit(
        state.copyWith(
          isOverlaySelecting: false,
          message: 'No image to apply effect',
        ),
      );
      return;
    }
    if (selectedEffect == null) {
      emit(state.copyWith(message: 'Please select an effect first'));
      return;
    }
    if (overlayUiImage == null) {
      emit(
        state.copyWith(
          message: 'Effect image not loaded. Please try selecting again',
        ),
      );
      return;
    }

    // Check for valid image dimensions safely
    int overlayW = 0;
    int overlayH = 0;
    try {
      overlayW = overlayUiImage.width;
      overlayH = overlayUiImage.height;
    } catch (e) {
      emit(
        state.copyWith(
          message:
              'Effect image is invalid or has been disposed. Please select the effect again.',
        ),
      );
      return;
    }

    if (overlayW <= 0 || overlayH <= 0) {
      emit(state.copyWith(message: 'Invalid effect image dimensions'));
      return;
    }

    emit(state.copyWith(isProcessing: true));

    try {
      final bytesBefore = await currentImage.safeByteArray();

      // Validate base bytes are not empty
      if (bytesBefore.isEmpty) {
        emit(
          state.copyWith(isProcessing: false, message: 'Failed to read image'),
        );
        return;
      }

      final codec = await ui.instantiateImageCodec(bytesBefore);
      final frame = await codec.getNextFrame();
      final baseUiImage = frame.image;

      // Validate decoded image has valid dimensions
      if (baseUiImage.width <= 0 || baseUiImage.height <= 0) {
        baseUiImage.dispose();
        emit(
          state.copyWith(
            isProcessing: false,
            message: 'Invalid image dimensions',
          ),
        );
        return;
      }

      final resultUiImage = await EffectEngine().composite(
        baseImage: baseUiImage,
        overlayImage: overlayUiImage,
        opacity: state.overlayOpacity,
        blendMode: selectedEffect.blendMode,
      );

      // Validate result image
      if (resultUiImage.width <= 0 || resultUiImage.height <= 0) {
        baseUiImage.dispose();
        resultUiImage.dispose();
        emit(
          state.copyWith(
            isProcessing: false,
            message: 'Failed to create effect',
          ),
        );
        return;
      }

      final resultBytes = await EffectEngine().exportToBytes(resultUiImage);
      final dir = await getTemporaryDirectory();
      final outFile = File(
        '${dir.path}/overlay_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await outFile.writeAsBytes(resultBytes);

      editor.stateManager.updateBackgroundImages(
        oldImage: currentImage.copyWith(),
        newImage: EditorImage.file(outFile),
      );

      // ── Push to history AFTER success ─────
      await _pushUndo(
        await HistoryEntry.fromBytes(bytes: bytesBefore, label: 'Overlay'),
      );

      final oldOverlay = state.overlayUiImage;
      emit(
        state.copyWith(
          isProcessing: false,
          isOverlaySelecting: false,
          clearSelectedEffect: true,
          clearOverlayUiImage: true,
          message: 'Overlay applied!',
          canUndo: _canUndo,
          canRedo: _canRedo,
        ),
      );
      editor.setState(() {});
      baseUiImage.dispose();
      resultUiImage.dispose();
      oldOverlay?.dispose();
    } catch (e, stackTrace) {
      debugPrint('Error in _onConfirmOverlay: $e\n$stackTrace');
      emit(state.copyWith(isProcessing: false, message: 'Error: $e'));
    }
  }

  Future<void> _onConfirmFrame(
    ImageEditorConfirmFrame event,
    Emitter<ImageEditorState> emit,
  ) async {
    final editor = event.editor;
    final currentImage = editor.stateManager.activeBackgroundImage;

    if (currentImage == null) {
      emit(state.copyWith(message: 'No image to apply frame'));
      return;
    }

    emit(state.copyWith(isProcessing: true, message: 'Applying frame...'));

    try {
      final bytesBefore = await currentImage.safeByteArray();
      if (bytesBefore.isEmpty) {
        emit(
          state.copyWith(isProcessing: false, message: 'Failed to read image'),
        );
        return;
      }

      // Download the frame image bytes
      final response = await http.get(Uri.parse(event.frameUrl));
      if (response.statusCode != 200) {
        emit(
          state.copyWith(
            isProcessing: false,
            message: 'Failed to download frame',
          ),
        );
        return;
      }
      final frameBytes = response.bodyBytes;

      // Decode base image
      final baseCodec = await ui.instantiateImageCodec(bytesBefore);
      final baseFrame = await baseCodec.getNextFrame();
      final baseUiImage = baseFrame.image;

      // Decode frame image
      final frameCodec = await ui.instantiateImageCodec(frameBytes);
      final frameImageFrame = await frameCodec.getNextFrame();
      final frameUiImage = frameImageFrame.image;

      // Extract scaling and translation from interactive viewer
      double scale = 1.0;
      ui.Offset translation = ui.Offset.zero;
      final viewerState = editor.interactiveViewer.currentState;
      if (viewerState != null) {
        scale = viewerState.scaleFactor;
        translation = viewerState.offset;
      }

      // Calculate factor between logical canvas size and original image pixels
      final constraints = state.containerSize;
      final imgAR = state.imageAspectRatio > 0 ? state.imageAspectRatio : 1.0;
      final conAR = constraints.width / constraints.height;

      Size renderedSize = Size.zero;
      if (imgAR > conAR) {
        renderedSize = Size(constraints.width, constraints.width / imgAR);
      } else {
        renderedSize = Size(constraints.height * imgAR, constraints.height);
      }

      double factor = 1.0;
      if (renderedSize.width > 0) {
        factor = baseUiImage.width.toDouble() / renderedSize.width;
      }

      final highResTranslation = ui.Offset(
        translation.dx * factor,
        translation.dy * factor,
      );

      // Composite using EffectEngine
      final resultUiImage = await EffectEngine().composite(
        baseImage: baseUiImage,
        overlayImage: frameUiImage,
        opacity: 1.0,
        blendMode: ui.BlendMode.srcOver,
        scale: scale,
        translation: highResTranslation,
      );

      final resultBytes = await EffectEngine().exportToBytes(resultUiImage);
      final dir = await getTemporaryDirectory();
      final outFile = File(
        '${dir.path}/frame_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await outFile.writeAsBytes(resultBytes);

      editor.stateManager.updateBackgroundImages(
        oldImage: currentImage.copyWith(),
        newImage: EditorImage.file(outFile),
      );

      // Reset the interactive viewer transformations back to identity
      editor.interactiveViewer.currentState?.reset();

      // Push to history
      await _pushUndo(
        await HistoryEntry.fromBytes(bytes: bytesBefore, label: 'Frames'),
      );

      emit(
        state.copyWith(
          isProcessing: false,
          message: 'Frame applied!',
          canUndo: _canUndo,
          canRedo: _canRedo,
          closeToolTrigger: true,
        ),
      );

      editor.setState(() {});
      baseUiImage.dispose();
      frameUiImage.dispose();
      resultUiImage.dispose();
    } catch (e, stackTrace) {
      debugPrint('Error in _onConfirmFrame: $e\n$stackTrace');
      emit(state.copyWith(isProcessing: false, message: 'Error: $e'));
    }
  }

  Future<void> _onToggleBgBlurMode(
    ImageEditorToggleBgBlurMode event,
    Emitter<ImageEditorState> emit,
  ) async {
    final newValue = event.value ?? !state.isBgBlurSelecting;
    if (!newValue) {
      emit(
        state.copyWith(
          isBgBlurSelecting: false,
          bgBlurIntensity: 0.0,
          clearBgBlurForegroundImage: true,
          clearBgBlurBackgroundImage: true,
        ),
      );
      return;
    }

    emit(state.copyWith(isBgBlurSelecting: true, isProcessing: true));

    final editor = event.editor;
    final currentImage = editor.stateManager.activeBackgroundImage;
    if (currentImage == null) {
      emit(state.copyWith(isProcessing: false, isBgBlurSelecting: false));
      return;
    }

    try {
      final bytesBefore = await currentImage.safeByteArray();

      final replicateService = ReplicateService();
      await replicateService.initialize();
      final model = replicateService.blurBgModel;
      if (model == null) {
        throw Exception('Blur Background AI model config not found.');
      }

      // Write bytes to temp file to send to Replicate
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/temp_bg_blur_input_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(bytesBefore);

      final url = await replicateService.generateContent(
        modelConfig: model,
        prompt: 'blur background',
        referenceImage: tempFile,
      );

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to download generated background: ${response.statusCode}',
        );
      }
      final resultBytes = response.bodyBytes;

      editor.stateManager.updateBackgroundImages(
        oldImage: currentImage.copyWith(),
        newImage: EditorImage.memory(resultBytes),
      );

      // ── Push to history ─────
      await _pushUndo(
        await HistoryEntry.fromBytes(bytes: bytesBefore, label: 'BG Blur'),
      );

      emit(
        state.copyWith(
          isProcessing: false,
          isBgBlurSelecting: false,
          message: 'Background blurred!',
          canUndo: _canUndo,
          canRedo: _canRedo,
        ),
      );
      editor.setState(() {});
    } catch (e, stackTrace) {
      debugPrint('Error in _onToggleBgBlurMode: $e\n$stackTrace');
      emit(
        state.copyWith(
          isProcessing: false,
          isBgBlurSelecting: false,
          message: 'Error: $e',
        ),
      );
    }
  }

  void _onUpdateBgBlurIntensity(
    ImageEditorUpdateBgBlurIntensity event,
    Emitter<ImageEditorState> emit,
  ) {
    // Redundant for online execution
  }

  Future<void> _onConfirmBgBlur(
    ImageEditorConfirmBgBlur event,
    Emitter<ImageEditorState> emit,
  ) async {
    // Redundant for online execution
  }

  Future<void> _onToggleBgRemoveMode(
    ImageEditorToggleBgRemoveMode event,
    Emitter<ImageEditorState> emit,
  ) async {
    final newValue = event.value ?? !state.isBgRemoveSelecting;
    if (!newValue) {
      if (state.isProcessing) {
        emit(state.copyWith(isBgRemoveSelecting: false));
        return;
      }
      final oldImg = state.bgRemovePreviewImage;
      emit(
        state.copyWith(
          isBgRemoveSelecting: false,
          clearBgRemovePreviewImage: true,
        ),
      );
      oldImg?.dispose();
      return;
    }

    emit(
      state.copyWith(
        isBgRemoveSelecting: true,
        isBgBlurSelecting: false,
        isCircleSelecting: false,
        isOverlaySelecting: false,
        isProcessing: true,
      ),
    );

    final editor = event.editor;
    final currentImage = editor.stateManager.activeBackgroundImage;
    if (currentImage == null) {
      emit(state.copyWith(isProcessing: false, isBgRemoveSelecting: false));
      return;
    }

    try {
      final bytes = await currentImage.safeByteArray();

      final oldImg = state.bgRemovePreviewImage;
      final newImg = await BackgroundRemover.instance.removeBg(bytes);
      emit(state.copyWith(bgRemovePreviewImage: newImg, isProcessing: false));
      oldImg?.dispose();
    } catch (e, stackTrace) {
      debugPrint('Error in _onToggleBgRemoveMode: $e\n$stackTrace');
      emit(
        state.copyWith(
          isProcessing: false,
          isBgRemoveSelecting: false,
          message: 'Error: $e',
        ),
      );
    }
  }

  Future<void> _onConfirmBgRemove(
    ImageEditorConfirmBgRemove event,
    Emitter<ImageEditorState> emit,
  ) async {
    // Redundant for online execution
  }

  Future<void> _onRemoveBackground(
    ImageEditorRemoveBackground event,
    Emitter<ImageEditorState> emit,
  ) async {
    final editor = event.editor;
    final currentImage = editor.stateManager.activeBackgroundImage;
    if (currentImage == null) return;

    emit(state.copyWith(isProcessing: true));

    try {
      final bytesBefore = await currentImage.safeByteArray();

      final replicateService = ReplicateService();
      await replicateService.initialize();
      final model = replicateService.removeBgModel;
      if (model == null) {
        throw Exception('Remove Background AI model config not found.');
      }

      // Write bytes to temp file to send to Replicate
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/temp_bg_remove_input_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(bytesBefore);

      final url = await replicateService.generateContent(
        modelConfig: model,
        prompt: 'remove background, clean cutout',
        referenceImage: tempFile,
      );

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception(
          'Failed to download generated background: ${response.statusCode}',
        );
      }
      final resultBytes = response.bodyBytes;

      editor.stateManager.updateBackgroundImages(
        oldImage: currentImage.copyWith(),
        newImage: EditorImage.memory(resultBytes),
      );

      // ── Push to history AFTER success ─────
      await _pushUndo(
        await HistoryEntry.fromBytes(bytes: bytesBefore, label: 'Remove BG'),
      );

      emit(
        state.copyWith(
          isProcessing: false,
          message: 'Background removed!',
          canUndo: _canUndo,
          canRedo: _canRedo,
        ),
      );
      editor.setState(() {});
    } catch (e, stackTrace) {
      debugPrint('Error in _onRemoveBackground: $e\n$stackTrace');
      emit(state.copyWith(isProcessing: false, message: 'Error: $e'));
    }
  }

  Future<void> _onChangeBackground(
    ImageEditorChangeBackground event,
    Emitter<ImageEditorState> emit,
  ) async {
    final editor = event.editor;
    final BuildContext context = editor.context;

    final pickedFile = await ImagePickerHelper.pickImage(
      context: context,
      crop: false,
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return;

    final currentImage = editor.stateManager.activeBackgroundImage;
    if (currentImage == null) return;

    emit(state.copyWith(isProcessing: true));

    try {
      final bytesBefore = await currentImage.safeByteArray();

      final ui.Image foregroundImage = await BackgroundRemover.instance
          .removeBg(bytesBefore);
      final bgBytes = await pickedFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bgBytes);
      final bgFrame = await codec.getNextFrame();
      final ui.Image backgroundImage = bgFrame.image;

      final resultImg = await EffectEngine().applyBackgroundBlurExport(
        baseImage: backgroundImage, // Using new bg as base
        foregroundImage: foregroundImage,
        blurIntensity: 0, // No blur, just replace
      );

      final resultBytes = await EffectEngine().exportToBytes(resultImg);
      final dir = await getTemporaryDirectory();
      final outputFile = File(
        '${dir.path}/change_bg_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await outputFile.writeAsBytes(resultBytes);

      editor.stateManager.updateBackgroundImages(
        oldImage: currentImage.copyWith(),
        newImage: EditorImage.file(outputFile),
      );

      // ── Push to history AFTER success ─────
      await _pushUndo(
        await HistoryEntry.fromBytes(bytes: bytesBefore, label: 'Change BG'),
      );

      emit(
        state.copyWith(
          isProcessing: false,
          message: 'Background changed!',
          canUndo: _canUndo,
          canRedo: _canRedo,
        ),
      );
      editor.setState(() {});
      foregroundImage.dispose();
      backgroundImage.dispose();
      resultImg.dispose();
    } catch (e, stackTrace) {
      debugPrint('Error in _onChangeBackground: $e\n$stackTrace');
      emit(state.copyWith(isProcessing: false, message: 'Error: $e'));
    }
  }

  Future<void> _onApplyColorMatrix(
    ImageEditorApplyColorMatrix event,
    Emitter<ImageEditorState> emit,
  ) async {
    final editor = event.editor;
    final currentImage = editor.stateManager.activeBackgroundImage;
    if (currentImage == null) return;

    emit(state.copyWith(isProcessing: true));

    try {
      final bytesBefore = await currentImage.safeByteArray();

      final codec = await ui.instantiateImageCodec(bytesBefore);
      final frame = await codec.getNextFrame();
      final baseUiImage = frame.image;

      final resultImg = await EffectEngine().applyGlobalAdjustment(
        srcImg: baseUiImage,
        matrix: event.matrix,
      );

      final resultBytes = await EffectEngine().exportToBytes(resultImg);
      final dir = await getTemporaryDirectory();
      final outputFile = File(
        '${dir.path}/adjust_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await outputFile.writeAsBytes(resultBytes);

      editor.stateManager.updateBackgroundImages(
        oldImage: currentImage.copyWith(),
        newImage: EditorImage.file(outputFile),
      );

      // ── Push to history AFTER success ─────
      await _pushUndo(
        await HistoryEntry.fromBytes(bytes: bytesBefore, label: 'Adjust'),
      );

      emit(
        state.copyWith(
          isProcessing: false,
          message: 'Adjustment applied!',
          canUndo: _canUndo,
          canRedo: _canRedo,
        ),
      );
      editor.setState(() {});
      baseUiImage.dispose();
      resultImg.dispose();
    } catch (e, stackTrace) {
      debugPrint('Error in _onApplyColorMatrix: $e\n$stackTrace');
      emit(state.copyWith(isProcessing: false, message: 'Error: $e'));
    }
  }

  Future<void> _onApplySelectiveHSL(
    ImageEditorApplySelectiveHSL event,
    Emitter<ImageEditorState> emit,
  ) async {
    final editor = event.editor;
    final currentImage = editor.stateManager.activeBackgroundImage;
    if (currentImage == null) return;

    debugPrint(
      '[HSL debug] _onApplySelectiveHSL adjustments: ${event.adjustments}',
    );

    emit(state.copyWith(isProcessing: true));

    try {
      final bytesBefore = await currentImage.safeByteArray();

      final codec = await ui.instantiateImageCodec(bytesBefore);
      final frame = await codec.getNextFrame();
      final baseUiImage = frame.image;

      debugPrint(
        '[HSL debug] baseUiImage size: ${baseUiImage.width}x${baseUiImage.height}',
      );

      final resultImg = await EffectEngine().applySelectiveHSLAdjustment(
        srcImg: baseUiImage,
        adjustments: event.adjustments,
      );

      debugPrint(
        '[HSL debug] resultImg size: ${resultImg.width}x${resultImg.height}',
      );

      final resultBytes = await EffectEngine().exportToBytes(resultImg);
      final dir = await getTemporaryDirectory();
      final outputFile = File(
        '${dir.path}/hsl_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await outputFile.writeAsBytes(resultBytes);

      debugPrint('[HSL debug] saved modified image to ${outputFile.path}');

      editor.stateManager.updateBackgroundImages(
        oldImage: currentImage.copyWith(),
        newImage: EditorImage.file(outputFile),
      );

      // ── Push to history AFTER success ─────
      await _pushUndo(
        await HistoryEntry.fromBytes(bytes: bytesBefore, label: 'HSL'),
      );

      emit(
        state.copyWith(
          isProcessing: false,
          message: 'HSL adjustment applied!',
          canUndo: _canUndo,
          canRedo: _canRedo,
        ),
      );
      editor.setState(() {});
      baseUiImage.dispose();
      resultImg.dispose();
    } catch (e, stackTrace) {
      debugPrint('Error in _onApplySelectiveHSL: $e\n$stackTrace');
      emit(state.copyWith(isProcessing: false, message: 'Error: $e'));
    }
  }

  Future<void> _onApplyCurves(
    ImageEditorApplyCurves event,
    Emitter<ImageEditorState> emit,
  ) async {
    final editor = event.editor;
    final currentImage = editor.stateManager.activeBackgroundImage;
    if (currentImage == null) return;

    emit(state.copyWith(isProcessing: true));

    try {
      final bytesBefore = await currentImage.safeByteArray();
      final codec = await ui.instantiateImageCodec(bytesBefore);
      final frame = await codec.getNextFrame();
      final srcImg = frame.image;

      final bd = await srcImg.toByteData(format: ui.ImageByteFormat.rawRgba);
      final pixels = bd!.buffer.asUint8List();

      // Run on low-end: use compute() for full-res
      final processed = await compute(
        (msg) => CurvesProcessor.apply(
          msg['bytes'] as Uint8List,
          msg['curves'] as CurvesData,
        ),
        {'bytes': pixels, 'curves': event.curves},
      );

      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        processed,
        srcImg.width,
        srcImg.height,
        ui.PixelFormat.rgba8888,
        completer.complete,
      );
      final resultImg = await completer.future;

      final resultBytes = await EffectEngine().exportToBytes(resultImg);
      final dir = await getTemporaryDirectory();
      final outputFile = File(
        '${dir.path}/curves_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await outputFile.writeAsBytes(resultBytes);

      editor.stateManager.updateBackgroundImages(
        oldImage: currentImage.copyWith(),
        newImage: EditorImage.file(outputFile),
      );

      // ── Push to history AFTER success ─────
      await _pushUndo(
        await HistoryEntry.fromBytes(bytes: bytesBefore, label: 'Curves'),
      );

      emit(
        state.copyWith(
          isProcessing: false,
          message: 'Curves applied',
          canUndo: _canUndo,
          canRedo: _canRedo,
        ),
      );
      editor.setState(() {});
      srcImg.dispose();
      resultImg.dispose();
    } catch (e, stackTrace) {
      debugPrint('Error in _onApplyCurves: $e\n$stackTrace');
      emit(state.copyWith(isProcessing: false, message: 'Error: $e'));
    }
  }

  Future<void> _onApplyPixelEffect(
    ImageEditorApplyPixelEffect event,
    Emitter<ImageEditorState> emit,
  ) async {
    final editor = event.editor;
    final currentImage = editor.stateManager.activeBackgroundImage;
    if (currentImage == null) return;

    emit(state.copyWith(isProcessing: true));

    try {
      final bytesBefore = await currentImage.safeByteArray();
      final codec = await ui.instantiateImageCodec(bytesBefore);
      final frame = await codec.getNextFrame();
      final srcUiImage = frame.image;

      // Map slider value [0.0–1.0] to a signed strength [-1, 1] or [0, 1]
      // depending on the effect.  Neutral is 0.5 (mid-slider).
      final raw = event.strength;

      ui.Image resultImg;
      String successMsg;

      switch (event.effectName) {
        case 'grain':
          // 0.0–1.0: 0 = no grain, 1 = heavy grain
          resultImg = await EffectEngine().applyGrain(srcUiImage, raw);
          successMsg = 'Grain applied!';
          break;
        case 'vignette':
          // 0.0–1.0: 0 = none, 1 = heavy
          resultImg = await EffectEngine().applyVignette(srcUiImage, raw);
          successMsg = 'Vignette applied!';
          break;
        case 'sharpen':
          // 0.0–1.0: 0 = none, 1 = max sharpness
          resultImg = await EffectEngine().applySharpen(srcUiImage, raw);
          successMsg = 'Sharpen applied!';
          break;
        case 'denoise':
          // 0.0–1.0: 0 = none, 1 = strong denoise
          resultImg = await EffectEngine().applyDenoise(srcUiImage, raw);
          successMsg = 'Denoise applied!';
          break;
        case 'clarity':
          // 0.0–1.0: 0 = none, 1 = max clarity
          resultImg = await EffectEngine().applyClarity(srcUiImage, raw);
          successMsg = 'Clarity applied!';
          break;
        case 'vibrance':
          // Slider 0–1; map to [-1, 1] (centre = neutral)
          resultImg = await EffectEngine().applyVibrance(
            srcUiImage,
            (raw - 0.5) * 2,
          );
          successMsg = 'Vibrance applied!';
          break;
        case 'skinTone':
          // Slider 0–1; map to [-1, 1] (centre = neutral)
          resultImg = await EffectEngine().applySkinTone(
            srcUiImage,
            (raw - 0.5) * 2,
          );
          successMsg = 'Skin Tone applied!';
          break;
        default:
          srcUiImage.dispose();
          emit(state.copyWith(isProcessing: false, message: 'Unknown effect'));
          return;
      }

      final resultBytes = await EffectEngine().exportToBytes(resultImg);
      final dir = await getTemporaryDirectory();
      final outputFile = File(
        '${dir.path}/${event.effectName}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await outputFile.writeAsBytes(resultBytes);

      editor.stateManager.updateBackgroundImages(
        oldImage: currentImage.copyWith(),
        newImage: EditorImage.file(outputFile),
      );

      // ── Push to history AFTER success ─────
      await _pushUndo(
        await HistoryEntry.fromBytes(
          bytes: bytesBefore,
          label: event.effectName,
        ),
      );

      emit(
        state.copyWith(
          isProcessing: false,
          message: successMsg,
          canUndo: _canUndo,
          canRedo: _canRedo,
        ),
      );
      editor.setState(() {});
      srcUiImage.dispose();
      resultImg.dispose();
    } catch (e, stackTrace) {
      debugPrint(
        'Error in _onApplyPixelEffect (${event.effectName}): $e\n$stackTrace',
      );
      emit(state.copyWith(isProcessing: false, message: 'Error: $e'));
    }
  }

  Future<void> _onApplyRetouch(
    ImageEditorApplyRetouch event,
    Emitter<ImageEditorState> emit,
  ) async {
    final editor = event.editor;
    final currentImage = editor.stateManager.activeBackgroundImage;
    if (currentImage == null) return;

    emit(state.copyWith(isProcessing: true));

    File? tempFile;
    Uint8List? bytesBefore;
    try {
      debugPrint(
        '🔍 [Retouch] _onApplyRetouch called, strength=${event.strength}',
      );

      // Capture bytes before edit
      bytesBefore = await currentImage.safeByteArray();

      // Ensure ReplicateService is initialized before accessing retouchModel
      await ReplicateService().initialize();
      debugPrint('🔍 [Retouch] ReplicateService initialized');

      final model = ReplicateService().retouchModel;
      debugPrint('🔍 [Retouch] retouchModel = $model');
      if (model == null) {
        final rawJson = RemoteConfigService().retouchModelJson;
        debugPrint(
          '🔍 [Retouch] ⚠️ retouchModelJson from Remote Config: $rawJson',
        );
        throw Exception(
          'Retouch model not configured in Firebase Remote Config',
        );
      }
      debugPrint(
        '🔍 [Retouch] Model loaded: id=${model.id}, name=${model.name}, url=${model.url}',
      );
      debugPrint(
        '🔍 [Retouch] Request body template: ${model.requestBodyTemplate}',
      );

      final bytes = bytesBefore; // same as current image
      final dir = await getTemporaryDirectory();
      tempFile = File(
        '${dir.path}/retouch_input_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(bytes);
      debugPrint(
        '🔍 [Retouch] Temp file written: ${tempFile.path} (${bytes.length} bytes)',
      );

      // ── Encode image as base64 data URI ───────────────────────────────────
      final base64Str = base64Encode(bytes);
      final dataUri = 'data:image/png;base64,$base64Str';
      debugPrint('🔍 [Retouch] Base64 encoded: ${base64Str.length} chars');

      // ── Build request body from config template ──────────────────────────
      final variables = <String, dynamic>{'image': dataUri};
      final requestBody = model.createRequestBody(variables);
      debugPrint('🔍 [Retouch] Request body: ${jsonEncode(requestBody)}');

      // ── POST to Replicate API ────────────────────────────────────────────
      final authToken = RemoteConfigService().replicateAuthToken;
      debugPrint('🔍 [Retouch] POST ${model.url}');
      final postResponse = await http.post(
        Uri.parse(model.url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode(requestBody),
      );

      debugPrint(
        '🔍 [Retouch] POST response status: ${postResponse.statusCode}',
      );
      if (postResponse.statusCode != 200 && postResponse.statusCode != 201) {
        throw Exception('Failed to start retouch: ${postResponse.body}');
      }

      final postData = jsonDecode(postResponse.body);

      // If output is already available, use it directly
      if (postData['output'] != null) {
        final outputUrl = _extractRetouchOutput(postData['output']);
        debugPrint('🔍 [Retouch] Output ready immediately: $outputUrl');
        final resultBytes = await _downloadRetouchResult(outputUrl);
        _applyRetouchResult(
          editor,
          currentImage,
          resultBytes,
          emit,
          bytesBefore,
        );
        return;
      }

      // Otherwise get the polling URL
      final getUrl = postData['urls']?['get'] as String?;
      if (getUrl == null) {
        throw Exception('No output or poll URL in response: $postData');
      }
      debugPrint('🔍 [Retouch] Polling URL: $getUrl');

      // ── Poll for result ───────────────────────────────────────────────────
      const int maxRetries = 60;
      String? outputUrl;
      for (int i = 0; i < maxRetries; i++) {
        await Future.delayed(const Duration(seconds: 2));
        debugPrint('🔍 [Retouch] Poll attempt ${i + 1}/$maxRetries');

        final pollResponse = await http.get(
          Uri.parse(getUrl),
          headers: {'Authorization': 'Bearer $authToken'},
        );
        if (pollResponse.statusCode != 200) continue;

        final pollData = jsonDecode(pollResponse.body);
        final status = pollData['status'] as String?;
        debugPrint('🔍 [Retouch] Poll status: $status');

        if (status == 'succeeded') {
          outputUrl = _extractRetouchOutput(pollData['output']);
          break;
        } else if (status == 'failed' || status == 'canceled') {
          throw Exception('Retouch $status: ${pollData['error']}');
        }
      }

      if (outputUrl == null) {
        throw Exception('Timeout waiting for retouch result');
      }

      // ── Download result ──────────────────────────────────────────────────
      final resultBytes = await _downloadRetouchResult(outputUrl);
      _applyRetouchResult(editor, currentImage, resultBytes, emit, bytesBefore);
    } catch (e, stackTrace) {
      debugPrint('🔍 [Retouch] ❌ Error: $e\n$stackTrace');
      emit(state.copyWith(isProcessing: false, message: 'Error: $e'));
    } finally {
      if (tempFile != null && await tempFile.exists()) {
        try {
          await tempFile.delete();
          debugPrint('🔍 [Retouch] Temp file cleaned up');
        } catch (_) {}
      }
    }
  }

  /// Extracts the output URL from Replicate's response (handles list or string).
  String _extractRetouchOutput(dynamic output) {
    if (output is List && output.isNotEmpty) {
      return output[0].toString();
    } else if (output is String) {
      return output;
    }
    throw Exception('Unknown retouch output format: $output');
  }

  /// Downloads the retouched image bytes from the output URL.
  Future<Uint8List> _downloadRetouchResult(String url) async {
    debugPrint('🔍 [Retouch] Downloading result from: $url');
    final response = await http.get(Uri.parse(url));
    debugPrint('🔍 [Retouch] Download response status: ${response.statusCode}');
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to download retouched image (HTTP ${response.statusCode})',
      );
    }
    debugPrint('🔍 [Retouch] Downloaded ${response.bodyBytes.length} bytes');
    return response.bodyBytes;
  }

  /// Applies the downloaded retouched image to the editor.
  void _applyRetouchResult(
    ProImageEditorState editor,
    EditorImage currentImage,
    Uint8List resultBytes,
    Emitter<ImageEditorState> emit,
    Uint8List? bytesBefore,
  ) {
    editor.stateManager.updateBackgroundImages(
      oldImage: currentImage.copyWith(),
      newImage: EditorImage.memory(resultBytes),
    );

    // ── Push to history AFTER success ─────
    if (bytesBefore != null) {
      // Fire-and-forget: the async write is quick and the entry is only
      // needed on undo — safe to not await here since we already set state.
      HistoryEntry.fromBytes(
        bytes: bytesBefore,
        label: 'Retouch',
      ).then((entry) => _pushUndo(entry));
    }

    emit(
      state.copyWith(
        isProcessing: false,
        message: 'Retouch applied!',
        canUndo: _canUndo,
        canRedo: _canRedo,
      ),
    );
    editor.setState(() {});
    debugPrint('🔍 [Retouch] ✅ Success');
  }

  void _onSetShowOriginal(
    ImageEditorSetShowOriginal event,
    Emitter<ImageEditorState> emit,
  ) {
    emit(state.copyWith(showOriginal: event.value));
  }

  // ── Undo Handler ───────────────────────────
  Future<void> _onUndo(
    ImageEditorUndo event,
    Emitter<ImageEditorState> emit,
  ) async {
    // Guard: cannot undo while processing or when stack is empty
    if (state.isProcessing || _undoStack.isEmpty) return;

    final editor = event.editor;

    emit(state.copyWith(isProcessing: true));

    try {
      final currentBytes = await editor.stateManager.activeBackgroundImage
          ?.safeByteArray();

      // If we can't read current bytes, abort (prevents restoring blank)
      if (currentBytes == null || currentBytes.isEmpty) {
        emit(state.copyWith(isProcessing: false));
        return;
      }

      // Push current state to redo stack
      await _pushRedo(
        await HistoryEntry.fromBytes(bytes: currentBytes, label: 'Undo'),
      );

      // Pop from undo stack
      final target = _undoStack.removeLast();
      final targetBytes = await target.loadBytes();
      if (targetBytes == null || targetBytes.isEmpty) {
        // Temp file was deleted; undo cannot proceed — revert redo entry.
        _redoStack.removeLast();
        emit(
          state.copyWith(
            isProcessing: false,
            message: 'Undo history file missing — cannot undo this step',
          ),
        );
        return;
      }

      final oldImage = editor.stateManager.activeBackgroundImage;
      if (oldImage == null) {
        // Revert redo push
        final redoEntry = _redoStack.removeLast();
        unawaited(redoEntry.deleteFile());
        emit(state.copyWith(isProcessing: false));
        return;
      }

      editor.stateManager.updateBackgroundImages(
        oldImage: oldImage.copyWith(),
        newImage: EditorImage.memory(targetBytes),
      );

      // Signal the page to close any active tool panel
      emit(
        state.copyWith(
          isProcessing: false,
          canUndo: _canUndo,
          canRedo: _canRedo,
          closeToolTrigger: true,
        ),
      );
      editor.setState(() {});
    } catch (e, stackTrace) {
      debugPrint('Error in _onUndo: $e\n$stackTrace');
      emit(state.copyWith(isProcessing: false, message: 'Undo error: $e'));
    }
  }

  // ── Redo Handler ───────────────────────────
  Future<void> _onRedo(
    ImageEditorRedo event,
    Emitter<ImageEditorState> emit,
  ) async {
    // Guard: cannot redo while processing or when stack is empty
    if (state.isProcessing || _redoStack.isEmpty) return;

    final editor = event.editor;

    emit(state.copyWith(isProcessing: true));

    try {
      final currentBytes = await editor.stateManager.activeBackgroundImage
          ?.safeByteArray();

      if (currentBytes == null || currentBytes.isEmpty) {
        emit(state.copyWith(isProcessing: false));
        return;
      }

      // Push current state to undo stack
      await _pushUndo(
        await HistoryEntry.fromBytes(bytes: currentBytes, label: 'Redo'),
      );

      // Pop from redo stack
      final target = _redoStack.removeLast();
      final targetBytes = await target.loadBytes();
      if (targetBytes == null || targetBytes.isEmpty) {
        // Temp file was deleted; redo cannot proceed — revert undo entry.
        _undoStack.removeLast();
        emit(
          state.copyWith(
            isProcessing: false,
            message: 'Redo history file missing — cannot redo this step',
          ),
        );
        return;
      }

      final oldImage = editor.stateManager.activeBackgroundImage;
      if (oldImage == null) {
        // Revert undo push
        final undoEntry = _undoStack.removeLast();
        unawaited(undoEntry.deleteFile());
        emit(state.copyWith(isProcessing: false));
        return;
      }

      editor.stateManager.updateBackgroundImages(
        oldImage: oldImage.copyWith(),
        newImage: EditorImage.memory(targetBytes),
      );

      // Signal the page to close any active tool panel
      emit(
        state.copyWith(
          isProcessing: false,
          canUndo: _canUndo,
          canRedo: _canRedo,
          closeToolTrigger: true,
        ),
      );
      editor.setState(() {});
    } catch (e, stackTrace) {
      debugPrint('Error in _onRedo: $e\n$stackTrace');
      emit(state.copyWith(isProcessing: false, message: 'Redo error: $e'));
    }
  }

  // ── Reset Handler ───────────────────────────
  Future<void> _onReset(
    ImageEditorReset event,
    Emitter<ImageEditorState> emit,
  ) async {
    // Guard: cannot reset while processing
    if (state.isProcessing) return;

    final editor = event.editor;
    final currentImage = editor.stateManager.activeBackgroundImage;
    if (currentImage == null) return;

    emit(state.copyWith(isProcessing: true));

    try {
      // Read the original image file
      final originalBytes = await state.imageFile.readAsBytes();
      if (originalBytes.isEmpty) {
        emit(
          state.copyWith(
            isProcessing: false,
            message: 'Failed to read original image',
          ),
        );
        return;
      }

      // Push current state to history before resetting
      final currentBytes = await currentImage.safeByteArray();
      if (currentBytes.isNotEmpty) {
        await _pushUndo(
          await HistoryEntry.fromBytes(bytes: currentBytes, label: 'Reset'),
        );
      }

      // Reset to original image
      editor.stateManager.updateBackgroundImages(
        oldImage: currentImage.copyWith(),
        newImage: EditorImage.memory(originalBytes),
      );

      // Rewind the package-editor's layer history to the initial state so
      // all text / sticker / doodle layers placed on top of the background
      // are also cleared — otherwise layers remain after a background reset.
      try {
        final sm = editor.stateManager;
        while (sm.canUndo) {
          sm.undo();
        }
      } catch (_) {
        // If history rewind fails we still complete the reset below
      }

      // Clear BLoC history stacks after reset (keeps only the reset point)
      for (final e in _undoStack) {
        unawaited(e.deleteFile());
      }
      _undoStack.clear();
      for (final e in _redoStack) {
        unawaited(e.deleteFile());
      }
      _redoStack.clear();

      emit(
        state.copyWith(
          isProcessing: false,
          message: 'Reset to original!',
          canUndo: _canUndo,
          canRedo: _canRedo,
          closeToolTrigger: true,
        ),
      );
      editor.setState(() {});
    } catch (e, stackTrace) {
      debugPrint('Error in _onReset: $e\n$stackTrace');
      emit(state.copyWith(isProcessing: false, message: 'Reset error: $e'));
    }
  }

  @override
  Future<void> close() {
    state.bgBlurForegroundImage?.dispose();
    state.bgBlurBackgroundImage?.dispose();
    state.overlayUiImage?.dispose();
    state.bgRemovePreviewImage?.dispose();
    try {
      BackgroundRemover.instance.dispose();
    } catch (_) {}

    // ISSUE #3 FIX: Delete all backing temp files from history stacks
    // so they do not accumulate indefinitely on the device.
    for (final e in _undoStack) {
      unawaited(e.deleteFile());
    }
    _undoStack.clear();
    for (final e in _redoStack) {
      unawaited(e.deleteFile());
    }
    _redoStack.clear();
    return super.close();
  }
}
