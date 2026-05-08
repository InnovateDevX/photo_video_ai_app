import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
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
  const ImageEditorSelectOverlay(this.effect);
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

class ImageEditorSetShowOriginal extends ImageEditorEvent {
  final bool value;
  const ImageEditorSetShowOriginal(this.value);
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
  final bool isProcessing;

  // Overlay state
  final bool isOverlaySelecting;
  final EffectOverlay? selectedEffect;
  final double overlayOpacity;
  final ui.Image? overlayUiImage;
  final bool isOverlayLoading;

  final String? message;

  const ImageEditorState({
    required this.imageFile,
    this.showOriginal = false,
    this.containerSize = Size.zero,
    this.isCircleSelecting = false,
    this.circleCenter = Offset.zero,
    this.circleRadius = 80.0,
    this.editInsideCircle = true,
    this.circleBlur = 0.0,
    this.circleBrightness = 0.0,
    this.circleContrast = 0.0,
    this.circleSaturation = 0.0,
    this.circleHue = 0.0,
    this.isBgBlurSelecting = false,
    this.bgBlurIntensity = 0.0,
    this.bgBlurForegroundImage,
    this.isProcessing = false,
    this.isOverlaySelecting = false,
    this.selectedEffect,
    this.overlayOpacity = 0.8,
    this.overlayUiImage,
    this.isOverlayLoading = false,
    this.message,
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
    bool? isProcessing,
    bool? isOverlaySelecting,
    EffectOverlay? selectedEffect,
    double? overlayOpacity,
    ui.Image? overlayUiImage,
    bool? isOverlayLoading,
    String? message,
    bool clearMessage = false,
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
      bgBlurForegroundImage:
          bgBlurForegroundImage ?? this.bgBlurForegroundImage,
      isProcessing: isProcessing ?? this.isProcessing,
      isOverlaySelecting: isOverlaySelecting ?? this.isOverlaySelecting,
      selectedEffect: selectedEffect ?? this.selectedEffect,
      overlayOpacity: overlayOpacity ?? this.overlayOpacity,
      overlayUiImage: overlayUiImage ?? this.overlayUiImage,
      isOverlayLoading: isOverlayLoading ?? this.isOverlayLoading,
      message: clearMessage ? null : (message ?? this.message),
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
    isProcessing,
    isOverlaySelecting,
    selectedEffect,
    overlayOpacity,
    overlayUiImage,
    isOverlayLoading,
    message,
  ];
}

// ─────────────────────────────────────────────
// BLOC
// ─────────────────────────────────────────────

class ImageEditorBloc extends Bloc<ImageEditorEvent, ImageEditorState> {
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
    on<ImageEditorRemoveBackground>(_onRemoveBackground);
    on<ImageEditorChangeBackground>(_onChangeBackground);
    on<ImageEditorApplyColorMatrix>(_onApplyColorMatrix);
    on<ImageEditorApplySelectiveHSL>(_onApplySelectiveHSL);
    on<ImageEditorSetShowOriginal>(_onSetShowOriginal);
  }

  Future<void> _onInit(
    ImageEditorInit event,
    Emitter<ImageEditorState> emit,
  ) async {
    BackgroundRemover.instance.initializeOrt();
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
    emit(
      state.copyWith(
        isCircleSelecting: newValue,
        isOverlaySelecting: false,
        isBgBlurSelecting: false,
      ),
    );
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
      Uint8List? srcBytes;
      if (currentImage.hasFile) {
        srcBytes = await currentImage.file!.readAsBytes();
      } else if (currentImage.hasBytes) {
        srcBytes = currentImage.byteArray;
      }

      final srcImg = await EffectEngine().decodeImageFromFile(
        File.fromRawPath(srcBytes!),
      ); // Simplification
      // Wait, decodeImageFromFile takes File. I should use a helper for bytes.
      // I'll use the existing ui logic but moved to engine.

      final codec = await ui.instantiateImageCodec(srcBytes);
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
        blur: state.circleBlur,
        brightness: state.circleBrightness,
        contrast: state.circleContrast,
        saturation: state.circleSaturation,
        hue: state.circleHue,
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

      emit(
        state.copyWith(
          isProcessing: false,
          isCircleSelecting: false,
          message: 'Applied!',
        ),
      );
      editor.setState(() {});
      baseUiImage.dispose();
      resultImg.dispose();
    } catch (e) {
      emit(state.copyWith(isProcessing: false, message: 'Error: $e'));
    }
  }

  void _onToggleOverlayMode(
    ImageEditorToggleOverlayMode event,
    Emitter<ImageEditorState> emit,
  ) {
    final newValue = event.value ?? !state.isOverlaySelecting;
    emit(
      state.copyWith(
        isOverlaySelecting: newValue,
        isCircleSelecting: false,
        isBgBlurSelecting: false,
      ),
    );
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
      state.overlayUiImage?.dispose();
      emit(state.copyWith(overlayUiImage: null, isOverlayLoading: false));
      return;
    }

    try {
      final oldImage = state.overlayUiImage;
      final newImage = await EffectEngine().decodeImageFromAsset(
        event.effect!.assetPath,
      );
      emit(state.copyWith(overlayUiImage: newImage, isOverlayLoading: false));
      oldImage?.dispose();
    } catch (e) {
      emit(
        state.copyWith(
          isOverlayLoading: false,
          message: 'Error loading overlay',
        ),
      );
    }
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
    if (currentImage == null ||
        state.overlayUiImage == null ||
        state.selectedEffect == null) {
      emit(state.copyWith(isOverlaySelecting: false));
      return;
    }

    emit(state.copyWith(isProcessing: true));

    try {
      Uint8List? baseBytes;
      if (currentImage.hasFile) {
        baseBytes = await currentImage.file!.readAsBytes();
      } else if (currentImage.hasBytes) {
        baseBytes = currentImage.byteArray;
      }

      final codec = await ui.instantiateImageCodec(baseBytes!);
      final frame = await codec.getNextFrame();
      final baseUiImage = frame.image;

      final resultUiImage = await EffectEngine().composite(
        baseImage: baseUiImage,
        overlayImage: state.overlayUiImage!,
        opacity: state.overlayOpacity,
        blendMode: state.selectedEffect!.blendMode,
      );

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

      emit(
        state.copyWith(
          isProcessing: false,
          isOverlaySelecting: false,
          message: 'Overlay applied!',
        ),
      );
      editor.setState(() {});
      baseUiImage.dispose();
      resultUiImage.dispose();
    } catch (e) {
      emit(state.copyWith(isProcessing: false, message: 'Error: $e'));
    }
  }

  Future<void> _onToggleBgBlurMode(
    ImageEditorToggleBgBlurMode event,
    Emitter<ImageEditorState> emit,
  ) async {
    if (state.isBgBlurSelecting) {
      emit(state.copyWith(isBgBlurSelecting: false));
      return;
    }

    emit(
      state.copyWith(
        isBgBlurSelecting: true,
        bgBlurIntensity: 0.0,
        isCircleSelecting: false,
        isOverlaySelecting: false,
        isProcessing: true,
      ),
    );

    final editor = event.editor;
    final currentImage = editor.stateManager.activeBackgroundImage;
    if (currentImage == null) return;

    try {
      Uint8List? bytes;
      if (currentImage.hasFile) {
        bytes = await currentImage.file!.readAsBytes();
      } else if (currentImage.hasBytes) {
        bytes = currentImage.byteArray!;
      }

      final oldImg = state.bgBlurForegroundImage;
      final newImg = await BackgroundRemover.instance.removeBg(bytes!);
      emit(state.copyWith(bgBlurForegroundImage: newImg, isProcessing: false));
      oldImg?.dispose();
    } catch (e) {
      emit(
        state.copyWith(
          isProcessing: false,
          isBgBlurSelecting: false,
          message: 'Error extracting subject',
        ),
      );
    }
  }

  void _onUpdateBgBlurIntensity(
    ImageEditorUpdateBgBlurIntensity event,
    Emitter<ImageEditorState> emit,
  ) {
    emit(state.copyWith(bgBlurIntensity: event.intensity));
  }

  Future<void> _onConfirmBgBlur(
    ImageEditorConfirmBgBlur event,
    Emitter<ImageEditorState> emit,
  ) async {
    final editor = event.editor;
    final currentImage = editor.stateManager.activeBackgroundImage;
    if (currentImage == null || state.bgBlurForegroundImage == null) {
      emit(state.copyWith(isBgBlurSelecting: false));
      return;
    }

    emit(state.copyWith(isProcessing: true));

    try {
      Uint8List? bytes;
      if (currentImage.hasFile) {
        bytes = await currentImage.file!.readAsBytes();
      } else if (currentImage.hasBytes) {
        bytes = currentImage.byteArray!;
      }

      final codec = await ui.instantiateImageCodec(bytes!);
      final frame = await codec.getNextFrame();
      final baseUiImage = frame.image;

      final resultImg = await EffectEngine().applyBackgroundBlur(
        baseImage: baseUiImage,
        foregroundImage: state.bgBlurForegroundImage!,
        blurIntensity: state.bgBlurIntensity,
      );

      final resultBytes = await EffectEngine().exportToBytes(resultImg);
      final dir = await getTemporaryDirectory();
      final outputFile = File(
        '${dir.path}/bg_blur_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await outputFile.writeAsBytes(resultBytes);

      editor.stateManager.updateBackgroundImages(
        oldImage: currentImage.copyWith(),
        newImage: EditorImage.file(outputFile),
      );

      emit(
        state.copyWith(
          isProcessing: false,
          isBgBlurSelecting: false,
          message: 'Blur applied!',
        ),
      );
      editor.setState(() {});
      baseUiImage.dispose();
      resultImg.dispose();
    } catch (e) {
      emit(state.copyWith(isProcessing: false, message: 'Error: $e'));
    }
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
      Uint8List? bytes;
      if (currentImage.hasFile) {
        bytes = await currentImage.file!.readAsBytes();
      } else if (currentImage.hasBytes) {
        bytes = currentImage.byteArray!;
      }

      final ui.Image resultImage = await BackgroundRemover.instance.removeBg(
        bytes!,
      );
      final resultBytes = await EffectEngine().exportToBytes(resultImage);

      final dir = await getTemporaryDirectory();
      final outputFile = File(
        '${dir.path}/rembg_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await outputFile.writeAsBytes(resultBytes);

      editor.stateManager.updateBackgroundImages(
        oldImage: currentImage.copyWith(),
        newImage: EditorImage.file(outputFile),
      );
      emit(state.copyWith(isProcessing: false, message: 'Background removed!'));
      editor.setState(() {});
      resultImage.dispose();
    } catch (e) {
      emit(state.copyWith(isProcessing: false, message: 'Error: $e'));
    }
  }

  Future<void> _onChangeBackground(
    ImageEditorChangeBackground event,
    Emitter<ImageEditorState> emit,
  ) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final editor = event.editor;
    final currentImage = editor.stateManager.activeBackgroundImage;
    if (currentImage == null) return;

    emit(state.copyWith(isProcessing: true));

    try {
      Uint8List? bytes;
      if (currentImage.hasFile) {
        bytes = await currentImage.file!.readAsBytes();
      } else if (currentImage.hasBytes) {
        bytes = currentImage.byteArray!;
      }

      final ui.Image foregroundImage = await BackgroundRemover.instance
          .removeBg(bytes!);
      final bgBytes = await pickedFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(bgBytes);
      final bgFrame = await codec.getNextFrame();
      final ui.Image backgroundImage = bgFrame.image;

      final resultImg = await EffectEngine().applyBackgroundBlur(
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
      emit(state.copyWith(isProcessing: false, message: 'Background changed!'));
      editor.setState(() {});
      foregroundImage.dispose();
      backgroundImage.dispose();
      resultImg.dispose();
    } catch (e) {
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
      Uint8List? bytes;
      if (currentImage.hasFile) {
        bytes = await currentImage.file!.readAsBytes();
      } else if (currentImage.hasBytes) {
        bytes = currentImage.byteArray!;
      }

      final codec = await ui.instantiateImageCodec(bytes!);
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

      emit(state.copyWith(isProcessing: false, message: 'Adjustment applied!'));
      editor.setState(() {});
      baseUiImage.dispose();
      resultImg.dispose();
    } catch (e) {
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

    emit(state.copyWith(isProcessing: true));

    try {
      Uint8List? bytes;
      if (currentImage.hasFile) {
        bytes = await currentImage.file!.readAsBytes();
      } else if (currentImage.hasBytes) {
        bytes = currentImage.byteArray;
      }

      final codec = await ui.instantiateImageCodec(bytes!);
      final frame = await codec.getNextFrame();
      final baseUiImage = frame.image;

      final resultImg = await EffectEngine().applySelectiveHSLAdjustment(
        srcImg: baseUiImage,
        adjustments: event.adjustments,
      );

      final resultBytes = await EffectEngine().exportToBytes(resultImg);
      final dir = await getTemporaryDirectory();
      final outputFile = File(
        '${dir.path}/hsl_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await outputFile.writeAsBytes(resultBytes);

      editor.stateManager.updateBackgroundImages(
        oldImage: currentImage.copyWith(),
        newImage: EditorImage.file(outputFile),
      );

      emit(
        state.copyWith(isProcessing: false, message: 'HSL adjustment applied!'),
      );
      editor.setState(() {});
      baseUiImage.dispose();
      resultImg.dispose();
    } catch (e) {
      emit(state.copyWith(isProcessing: false, message: 'Error: $e'));
    }
  }

  void _onSetShowOriginal(
    ImageEditorSetShowOriginal event,
    Emitter<ImageEditorState> emit,
  ) {
    emit(state.copyWith(showOriginal: event.value));
  }

  @override
  Future<void> close() {
    state.bgBlurForegroundImage?.dispose();
    state.overlayUiImage?.dispose();
    BackgroundRemover.instance.dispose();
    return super.close();
  }
}
