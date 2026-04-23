import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:io';
import 'package:image_collage_widget/utils/collage_type.dart';
import 'package:trail_ai_app/Services/ad_service.dart';
import 'package:trail_ai_app/Services/credit_service.dart';
import 'package:trail_ai_app/Services/generation_gate.dart';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// EVENTS
// ─────────────────────────────────────────────

abstract class CollageEvent extends Equatable {
  const CollageEvent();
  @override
  List<Object?> get props => [];
}

/// Fired on page enter to ensure services are ready.
class CollageInit extends CollageEvent {
  const CollageInit();
}

/// Fired when the user selects a new collage type from the template strip.
class CollageTypeSelected extends CollageEvent {
  final CollageType collageType;
  final int imageCount;
  const CollageTypeSelected(this.collageType, this.imageCount);
  @override
  List<Object?> get props => [collageType, imageCount];
}

/// Fired when the user taps "Generate / Save collage".
/// [context] is needed to drive [GenerationGate] dialogs.
class CollageGenerateRequested extends CollageEvent {
  final BuildContext context;
  const CollageGenerateRequested(this.context);
  @override
  List<Object?> get props => []; // context intentionally excluded
}

/// Fired when an image is picked for a specific slot.
class CollageImagePicked extends CollageEvent {
  final int index;
  final File file;
  const CollageImagePicked(this.index, this.file);
  @override
  List<Object?> get props => [index, file];
}

/// Fired after the collage widget has rendered and we have a result image path.
class CollageRendered extends CollageEvent {
  final String imagePath;
  const CollageRendered(this.imagePath);
  @override
  List<Object?> get props => [imagePath];
}

/// Fired when the user wants to start over.
class CollageReset extends CollageEvent {
  const CollageReset();
}

// ─────────────────────────────────────────────
// STATES
// ─────────────────────────────────────────────

abstract class CollageState extends Equatable {
  const CollageState();
  @override
  List<Object?> get props => [];
}

/// Loading services / initializing.
class CollageInitial extends CollageState {
  const CollageInitial();
}

/// Initial / editing state – the collage widget is visible.
class CollageSelecting extends CollageState {
  final CollageType selectedType;
  final int imageCount;
  final int credits;
  final List<File?> selectedImages;

  const CollageSelecting({
    this.selectedType = CollageType.vSplit,
    this.imageCount = 2,
    this.credits = 0,
    // Initialize with max size (9), all nulls
    this.selectedImages = const [
      null, null, null,
      null, null, null,
      null, null, null,
    ],
  });

  /// Get only the images needed for current template (no trailing nulls)
  List<File?> get imagesForCurrentTemplate {
    return selectedImages.take(imageCount).toList();
  }

  /// Check if at least one slot is filled to allow generation
  bool get canGenerate {
    return selectedImages.any((f) => f != null);
  }

  CollageSelecting copyWith({
    CollageType? selectedType,
    int? imageCount,
    int? credits,
    List<File?>? selectedImages,
  }) {
    return CollageSelecting(
      selectedType: selectedType ?? this.selectedType,
      imageCount: imageCount ?? this.imageCount,
      credits: credits ?? this.credits,
      selectedImages: selectedImages ?? this.selectedImages,
    );
  }

  @override
  List<Object?> get props => [selectedType, imageCount, credits, selectedImages];
}

/// Gate / credit check is running (brief interstitial).
class CollageCheckingGate extends CollageState {
  final List<File?> selectedImages;
  final CollageType selectedType;
  final int imageCount;

  const CollageCheckingGate({
    required this.selectedImages,
    required this.selectedType,
    required this.imageCount,
  });

  @override
  List<Object?> get props => [selectedImages, selectedType, imageCount];
}

/// Generation was blocked (not enough credits / ad declined).
class CollageGateBlocked extends CollageState {
  const CollageGateBlocked();
}

/// Collage has been accepted; widget should render & save the image.
class CollageRendering extends CollageState {
  final List<File?> selectedImages;
  final CollageType selectedType;
  final int imageCount;

  const CollageRendering({
    required this.selectedImages,
    required this.selectedType,
    required this.imageCount,
  });

  @override
  List<Object?> get props => [selectedImages, selectedType, imageCount];
}

/// Final result is ready to display.
class CollageResult extends CollageState {
  final String imagePath;
  const CollageResult(this.imagePath);
  @override
  List<Object?> get props => [imagePath];
}

/// Something went wrong.
class CollageError extends CollageState {
  final String message;
  const CollageError(this.message);
  @override
  List<Object?> get props => [message];
}

// ─────────────────────────────────────────────
// BLOC
// ─────────────────────────────────────────────

class CollageBloc extends Bloc<CollageEvent, CollageState> {
  final AdService _adService;
  final CreditService _creditService;

  /// Credit cost for saving/exporting a collage (no Replicate call needed).
  static const int kCollageCreditCost = 1;

  CollageBloc({
    required AdService adService,
    required CreditService creditService,
  }) : _adService = adService,
       _creditService = creditService,
       super(const CollageInitial()) {
    on<CollageInit>(_onInit);
    on<CollageTypeSelected>(_onTypeSelected);
    on<CollageImagePicked>(_onImagePicked);
    on<CollageGenerateRequested>(_onGenerateRequested);
    on<CollageRendered>(_onRendered);
    on<CollageReset>(_onReset);
  }

  // ── handlers ──────────────────────────────

  Future<void> _onInit(CollageInit event, Emitter<CollageState> emit) async {
    try {
      await _creditService.initialize();
      await _adService.initialize();
      emit(CollageSelecting(credits: _creditService.credits));
    } catch (e) {
      emit(CollageError("Initialization failed: $e"));
    }
  }

  void _onTypeSelected(CollageTypeSelected event, Emitter<CollageState> emit) {
    if (state is CollageSelecting) {
      final s = state as CollageSelecting;
      emit(s.copyWith(
        selectedType: event.collageType,
        imageCount: event.imageCount,
        selectedImages: List<File?>.filled(9, null),
      ));
    }
  }

  void _onImagePicked(CollageImagePicked event, Emitter<CollageState> emit) {
    if (state is CollageSelecting) {
      final s = state as CollageSelecting;
      final newImages = List<File?>.from(s.selectedImages);
      if (event.index < newImages.length) {
        newImages[event.index] = event.file;
        emit(s.copyWith(selectedImages: newImages));
      }
    }
  }

  Future<void> _onGenerateRequested(
    CollageGenerateRequested event,
    Emitter<CollageState> emit,
  ) async {
    final s = state as CollageSelecting;
    emit(CollageCheckingGate(
      selectedImages: s.selectedImages,
      selectedType: s.selectedType,
      imageCount: s.imageCount,
    ));

    final canProceed = await GenerationGate.check(
      context: event.context,
      adService: _adService,
      creditService: _creditService,
      creditCost: kCollageCreditCost,
    );

    if (!canProceed) {
      emit(const CollageGateBlocked());
      // Bounce back to selection after a brief pause so the UI doesn't flash.
      await Future.delayed(const Duration(milliseconds: 300));
      emit(CollageSelecting(
        credits: _creditService.credits,
        selectedType: s.selectedType,
        imageCount: s.imageCount,
        selectedImages: s.selectedImages,
      ));
      return;
    }

    final gateState = state as CollageCheckingGate;
    // Gate passed → tell the UI to trigger the collage widget's save/render.
    emit(CollageRendering(
      selectedImages: gateState.selectedImages,
      selectedType: gateState.selectedType,
      imageCount: gateState.imageCount,
    ));
  }

  Future<void> _onRendered(
    CollageRendered event,
    Emitter<CollageState> emit,
  ) async {
    try {
      await _creditService.deductCredits(kCollageCreditCost);
      emit(CollageResult(event.imagePath));
    } catch (e) {
      emit(CollageError(e.toString()));
    }
  }

  void _onReset(CollageReset event, Emitter<CollageState> emit) {
    emit(CollageSelecting(credits: _creditService.credits));
  }

  // ── helpers exposed to the UI ─────────────

  /// Live credit count for the top-bar StreamBuilder.
  Stream<int> get creditStream => _creditService.creditStream;
  int get credits => _creditService.credits;

  /// Returns the number of images required for a given CollageType.
  static int getImageCount(CollageType type) {
    return switch (type) {
      CollageType.vSplit => 2,
      CollageType.fourSquare => 4,
      CollageType.threeVertical => 3,
      CollageType.rightBig => 6,
      CollageType.leftBig => 6,
      CollageType.fourLeftBig => 4,
      CollageType.vMiddleTwo => 7,
      CollageType.nineSquare => 9,
      _ => 1,
    };
  }
}
