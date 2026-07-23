import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vidzeon/Core/colors.dart';
import 'package:vidzeon/Core/gradient.dart';
import '../Helpers/feedback_helper.dart';
import '../Services/replicate_service.dart';
import '../Services/credit_service.dart';
import '../Services/generation_gate.dart';
import '../Widgets/main_navigation.dart';
import '../Widgets/generation_bottom_bar.dart';

import '../Widgets/prompt_input.dart';
import '../Widgets/video_result_view.dart';
import '../Widgets/themed_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:ui';
import '../Services/background_generation_service.dart';
import '../Helpers/image_picker_helper.dart';
import '../Services/content_safety_service.dart';
import '../Helpers/error_dialog_helper.dart';
import '../Services/media_service.dart';
import '../Services/data_service.dart';
import '../Services/remote_config_service.dart';
import '../Helpers/image_dedup_helper.dart';
import '../Models/category_image.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class GenerationPage extends StatefulWidget {
  final String initialCategory;
  final String? initialPrompt;
  final bool initialIsEditable;

  /// When true, activates the two-stage image-edit → video pipeline.
  final bool imageEditMode;

  /// Prompt for Stage 1 (image editing). Only used when [imageEditMode] is true.
  final String imagePrompt;

  /// Prompt for Stage 2 (video generation). Only used when [imageEditMode] is true.
  final String videoPrompt;

  /// Initial model ID to pre-select (e.g., from category image click)
  final String? initialModelId;
  final String? initialImageModelId;

  /// Whether to automatically trigger the image picker upon entering the page
  final bool autoTriggerImagePicker;

  final String? initialImageUrl;
  final bool showCategoryToggle;

  /// Set to true when this page is pre-built inside MainNavigation's IndexedStack.
  /// When true, the first-visit intro animation is only triggered by MainNavigation
  /// calling [GenerationPageState.onTabActivated()] rather than from initState.
  final bool isEmbeddedAsTab;
  final String? sourceCategoryName;
  final int noOfUploadable;

  const GenerationPage({
    super.key,
    this.initialCategory = 'image',
    this.initialPrompt,
    this.initialIsEditable = false,
    this.imageEditMode = false,
    this.imagePrompt = '',
    this.videoPrompt = '',
    this.initialModelId,
    this.initialImageModelId,
    this.autoTriggerImagePicker = false,
    this.initialImageUrl,
    this.isEmbeddedAsTab = false,
    this.showCategoryToggle = true,
    this.sourceCategoryName,
    this.noOfUploadable = 1,
  });

  @override
  State<GenerationPage> createState() => GenerationPageState();
}

// Public so MainNavigation can hold a GlobalKey<GenerationPageState>.
class GenerationPageState extends State<GenerationPage> {
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _promptFocusNode = FocusNode();
  final TextEditingController _widthController = TextEditingController(
    text: "1024",
  );
  final TextEditingController _heightController = TextEditingController(
    text: "1024",
  );

  final ReplicateService _replicateService = ReplicateService();
  final CreditService _creditService = CreditService();

  bool _isGenerating = false;
  String? _generatedImageUrl;
  String? _generatedVideoUrl;
  String? _previousImageUrl;
  String? _previousVideoUrl;
  bool _isResultFromGeneration = false;
  bool _showFullScreenPreview = false;

  bool _isNsfw = false;
  bool? _isLiked;
  bool _isDownloading = false;

  String? _currentPollUrl;
  String? _currentCancelUrl;
  bool _isCancelled = false;

  // Reference images picked via + button
  List<File> _selectedImages = [];

  // Fingerprints (SHA-256 + perceptual dHash) of [_selectedImages], used to
  // detect duplicate uploads. Kept in lock-step with [_selectedImages].
  List<ImageFingerprint> _selectedImageHashes = [];

  /// Handles a newly picked image. Computes a fingerprint, blocks duplicates
  /// (exact-byte match via SHA-256, or visually-identical via dHash), and
  /// appends to [_selectedImages] + [_selectedImageHashes] only when unique.
  /// Also auto-switches to an editable model if the current model does not
  /// support image input.
  Future<void> _onImageUploaded(File file) async {
    // ── 0. Auto-switch to an editable model if needed ─────────────────────
    if (_selectedModel != null && !_selectedModel!.iseditable) {
      final editableModels = _selectedCategory == 'image'
          ? _replicateService.imageModels.where((m) => m.iseditable).toList()
          : _replicateService.videoModels.where((m) => m.iseditable).toList();
      if (editableModels.isNotEmpty && mounted) {
        setState(() {
          _selectedModel = editableModels.first;
          _syncOptionsToModel();
        });
      }
    }

    // ── 1. Compute fingerprint of the new file ────────────────────────
    ImageFingerprint fingerprint;
    try {
      fingerprint = await ImageDedupHelper.fingerprint(file);
    } catch (e) {
      debugPrint('⚠️ [GenerationPage] Failed to fingerprint image: $e');
      // Fail-open: if we can't hash it, just allow the upload so the user
      // isn't blocked by an infrastructure error.
      if (mounted) {
        setState(() {
          _selectedImages = [..._selectedImages, file];
        });
      }
      return;
    }

    // ── 2. Check against already-selected images ──────────────────────
    final dup = await ImageDedupHelper.isDuplicate(
      candidate: fingerprint,
      existing: _selectedImageHashes,
    );

    if (dup.isDuplicate) {
      debugPrint(
        '🚫 [GenerationPage] Duplicate image blocked (${dup.reason}).',
      );
      if (!mounted) return;
      final message = dup.reason == 'exact'
          ? 'This photo has already been added. Please pick a different image.'
          : 'This photo looks identical to one you\'ve already added. Please pick a different image.';
      showThemedDialog(
        context,
        title: 'Duplicate Photo',
        message: message,
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.orange,
      );
      return;
    }

    // ── 3. Unique — append file + fingerprint ─────────────────────────
    if (mounted) {
      setState(() {
        _selectedImages = [..._selectedImages, file];
        _selectedImageHashes = [..._selectedImageHashes, fingerprint];
      });
    }
  }

  void _onRemoveImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      if (index < _selectedImageHashes.length) {
        _selectedImageHashes.removeAt(index);
      }
    });

    // Auto-switch back to a non-editable model when all images are cleared
    // (only if the current model requires image input).
    if (_selectedImages.isEmpty &&
        _selectedModel != null &&
        _selectedModel!.iseditable) {
      final nonEditableModels = _selectedCategory == 'image'
          ? _replicateService.imageModels.where((m) => !m.iseditable).toList()
          : _replicateService.videoModels.where((m) => !m.iseditable).toList();
      if (nonEditableModels.isNotEmpty && mounted) {
        setState(() {
          _selectedModel = nonEditableModels.first;
          _syncOptionsToModel();
        });
      }
    }
  }

  // Selection State
  late String _selectedCategory; // 'image' or 'video'
  String _selectedIcon = 'image'; // 'add', 'settings', 'edit', 'image', 'video'
  AIModelConfig? _selectedModel;
  String _selectedAspectRatio = '9:16';
  String _selectedDuration = '5s';
  String _selectedResolution = '720p';
  bool _enhancePrompt = false;

  // Two-stage pipeline model selection (used only in imageEditMode)
  AIModelConfig? _selectedImageModel; // Stage 1 — image edit
  AIModelConfig? _selectedVideoModel; // Stage 2 — video generation

  // First-visit intro animation flag
  bool _showIntroAnimation = false;
  bool _didCheckFirstVisit = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;

    if (widget.initialPrompt != null) {
      _promptController.text = widget.initialPrompt!;
    }
    if (widget.initialImageUrl != null) {
      if (widget.initialCategory == 'image') {
        _generatedImageUrl = widget.initialImageUrl;
      } else {
        _generatedVideoUrl = widget.initialImageUrl;
      }
    }

    // Portrait aspect ratio for Reel templates (both image edit & video)
    if (widget.imageEditMode) {
      _selectedAspectRatio = '9:16';
    }

    _initializeService();

    // When pushed directly (not pre-built as a tab), check first visit immediately.
    // When embedded as a tab in IndexedStack, MainNavigation calls onTabActivated()
    // at the moment the tab becomes visible.
    if (!widget.isEmbeddedAsTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_didCheckFirstVisit) {
          _didCheckFirstVisit = true;
          _checkFirstVisit();
        }
      });
    }

    // Auto-trigger image picker if requested by tool or imageEditMode
    if (widget.imageEditMode ||
        widget.initialIsEditable ||
        widget.autoTriggerImagePicker) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerAutoImagePicker();
      });
    }
  }

  /// Called by MainNavigation when this tab becomes the active/visible one.
  /// This is the correct place to start first-visit flows for tab-embedded pages.
  void onTabActivated() {
    if (!_didCheckFirstVisit) {
      _didCheckFirstVisit = true;
      _checkFirstVisit();
    }
  }

  Future<void> _triggerAutoImagePicker() async {
    if (!mounted) return;
    final file = await ImagePickerHelper.pickAndCropImage(context);
    if (file != null && mounted) {
      _onImageUploaded(file);
    }
  }

  /// Checks if this is the first visit to the generation page
  Future<void> _checkFirstVisit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool('has_seen_generation_intro') ?? false;
      if (!hasSeen && mounted) {
        setState(() => _showIntroAnimation = true);
        await prefs.setBool('has_seen_generation_intro', true);
      }
    } catch (e) {
      debugPrint('⚠️ [GenerationPage] Error checking first visit: $e');
    }
  }

  Future<void> _initializeService() async {
    await _replicateService.initialize();
    await _creditService.initialize();
    if (mounted) {
      setState(() {
        // If initialModelId is provided, try to find and select that model
        if (widget.initialModelId != null) {
          _selectModelById(widget.initialModelId!);
        } else {
          _updateSelectedModel();
        }

        // If initialImageModelId is provided (specifically for stage 1 of two-stage pipeline)
        if (widget.initialImageModelId != null) {
          final imgModelMatch = _replicateService.imageModels.where(
            (m) => m.id == widget.initialImageModelId,
          );
          if (imgModelMatch.isNotEmpty) {
            _selectedImageModel = imgModelMatch.first;
          }
        }

        // For two-stage pipeline, initialize both models
        if (widget.imageEditMode) {
          if (_replicateService.imageModels.isNotEmpty) {
            _selectedImageModel ??= _replicateService.imageModels.first;
          }
          if (_replicateService.videoModels.isNotEmpty) {
            _selectedVideoModel ??= _replicateService.videoModels.first;
          }
        }
      });
    }
  }

  /// Selects a model by its ID from the available models
  void _selectModelById(String modelId) {
    // Try to find in image models first
    final imageModel = _replicateService.imageModels.where(
      (m) => m.id == modelId,
    );
    if (imageModel.isNotEmpty) {
      _selectedCategory = 'image';
      _selectedModel = imageModel.first;
      if (widget.imageEditMode) {
        _selectedImageModel = imageModel.first;
      }
      _syncOptionsToModel();
      return;
    }

    // Try to find in video models
    final videoModel = _replicateService.videoModels.where(
      (m) => m.id == modelId,
    );
    if (videoModel.isNotEmpty) {
      _selectedCategory = 'video';
      _selectedModel = videoModel.first;
      if (widget.imageEditMode) {
        _selectedVideoModel = videoModel.first;
      }
      _syncOptionsToModel();
      return;
    }

    // Model not found, use default
    debugPrint('⚠️ [GenerationPage] Model not found: $modelId');
    _updateSelectedModel();
  }

  /// Updates [_selectedModel] based on [_selectedCategory].
  /// Must be called inside a [setState] block (or followed by one).
  void _updateSelectedModel() {
    final models = _selectedCategory == 'image'
        ? _replicateService.imageModels
        : _replicateService.videoModels;

    if (models.isNotEmpty) {
      _selectedModel = models.first;
    } else {
      _selectedModel = null;
    }
    _syncOptionsToModel();
  }

  void _syncOptionsToModel() {
    // In imageEditMode, settings like duration/aspect-ratio are governed by the video model (Stage 2)
    final model = widget.imageEditMode ? _selectedVideoModel : _selectedModel;
    if (model == null) return;
    final options = model.options;

    if (options.hasDurations) {
      if (!options.durations.contains(_selectedDuration)) {
        _selectedDuration = options.durations.first;
      }
    }
    if (options.hasResolutions) {
      if (!options.resolutions.contains(_selectedResolution)) {
        _selectedResolution = options.resolutions.first;
      }
    }
    if (options.hasAspectRatios) {
      if (options.aspectRatios.contains('9:16')) {
        _selectedAspectRatio = '9:16';
      } else if (!options.aspectRatios.contains(_selectedAspectRatio)) {
        final fallback = options.aspectRatios.first;
        debugPrint(
          '🔄 [GenerationPage] aspect_ratio "$_selectedAspectRatio" not in '
          '${model.name} options; switching to "$fallback".',
        );
        _selectedAspectRatio = fallback;
      }
    } else if (model.supportsAspectRatio == false &&
        _selectedAspectRatio.isNotEmpty) {
      // Model doesn't expose aspect_ratio options AND its template doesn't
      // use {{aspect_ratio}} either. Drop the local default to avoid
      // sending a key Replicate will reject.
      debugPrint(
        '🔄 [GenerationPage] ${model.name} has no aspect_ratio support; '
        'clearing _selectedAspectRatio.',
      );
      _selectedAspectRatio = '';
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _promptFocusNode.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  int get _noOfUploadable {
    // If the caller explicitly requested multiple slots (e.g., from a Category
    // that defines "no_of_uploadable: 2"), respect that first.
    if (widget.noOfUploadable > 1) {
      return widget.noOfUploadable;
    }

    // If coming from a category preview (where showCategoryToggle is hidden),
    // strictly enforce the default of 1 unless explicitly overridden above.
    if (!widget.showCategoryToggle) {
      return widget.noOfUploadable;
    }

    // Otherwise, fall back to the model's own template-derived slot count.
    if (_selectedModel != null && _selectedModel!.iseditable) {
      final modelSlots = _selectedModel!.noOfUploadable;
      return modelSlots > 0 ? modelSlots : 1;
    }
    return 1;
  }

  int get _effectiveCreditCost {
    if (widget.imageEditMode) {
      final imageModel = _selectedImageModel ?? _selectedModel;
      final videoModel =
          _selectedVideoModel ?? _replicateService.videoModels.firstOrNull;
      if (imageModel == null || videoModel == null) return 0;

      final imgCost = imageModel.computeCreditCost(
        resolution: _selectedResolution,
      );
      final vidCost = videoModel.computeCreditCost(
        duration: _selectedDuration,
        resolution: _selectedResolution,
      );
      return imgCost + vidCost;
    }

    if (_selectedModel == null) return 0;

    if (_selectedCategory == 'video') {
      return _selectedModel!.computeCreditCost(
        duration: _selectedDuration,
        resolution: _selectedResolution,
      );
    }

    return _selectedModel!.computeCreditCost(resolution: _selectedResolution);
  }

  Future<void> _generateContent() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (widget.imageEditMode) {
      await _generateTwoStage();
      return;
    }

    String prompt = _promptController.text.trim();
    if (_enhancePrompt && prompt.isNotEmpty) {
      prompt =
          '$prompt, masterpiece, best quality, highly detailed, 4k, 8k, ultra-detailed, cinematic lighting, photorealistic';
    }

    if (prompt.isEmpty) {
      showThemedDialog(
        context,
        title: 'Error',
        message: 'Please enter a prompt',
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
      return;
    }

    if (_selectedModel == null) {
      showThemedDialog(
        context,
        title: 'Error',
        message: 'No model selected or available',
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
      return;
    }

    // --- Safety Check ---
    try {
      // Show checking overlay
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFD66031)),
        ),
      );

      await ContentSafetyService().checkTextSafe(prompt);

      if (mounted) Navigator.pop(context); // Remove loading
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        setState(() => _isGenerating = false);
        if (e is NsfwContentException) {
          if (e.url != null) {
            setState(() {
              _generatedImageUrl = e.url;
              _isNsfw = true;
            });
          }
          ErrorDialogHelper.showRestrictedContentDialog(
            context,
            messageKey: e.messageKey,
          );
        } else {
          ErrorDialogHelper.showErrorDialog(
            context,
            title: 'Something went wrong',
            message:
                'We encountered an error while processing your request. Please try again.',
          );
        }
      }
      return;
    }

    debugPrint('🔥 [GenerationPage] _generateContent called');

    // Dismiss keyboard to show progress clearly
    FocusScope.of(context).unfocus();

    // ── 1. Ad gate (Check BEFORE clearing state) ───────────────────────────
    debugPrint('🔥 [GenerationPage] Checking GenerationGate...');
    final canProceed = await GenerationGate.check(
      context: context,
      creditService: _creditService,
      creditCost: _effectiveCreditCost,
    );
    debugPrint('🔥 [GenerationPage] GenerationGate result: $canProceed');

    if (!canProceed) {
      return;
    }

    // ── 2. Progress state (immediate feedback) ───────────────────────────────
    setState(() {
      _isGenerating = true;
      _isNsfw = false;
      _isLiked = null;
      _previousImageUrl = _generatedImageUrl;
      _previousVideoUrl = _generatedVideoUrl;
      if (_selectedCategory == 'image') {
        _generatedImageUrl = null;
      } else {
        _generatedVideoUrl = null;
      }
    });

    if (!mounted) return;



    // ── 4. Local Execution (Wait Here) ──────────────────────────────────────
    try {
      _isCancelled = false;
      int? width;
      int? height;
      String? aspectRatio;

      if (_selectedModel!.supportsAspectRatio ||
          _selectedModel!.supportsDimensions) {
        aspectRatio = _selectedAspectRatio;
      }

      final url = await _replicateService.generateContent(
        modelConfig: _selectedModel!,
        prompt: prompt,
        aspectRatio: aspectRatio,
        width: width,
        height: height,
        referenceImage: _selectedImages.isNotEmpty
            ? _selectedImages.first
            : null,
        images: _selectedImages.isNotEmpty ? _selectedImages : null,
        extraVariables: _selectedCategory == 'video'
            ? {
                'duration': int.tryParse(_selectedDuration.replaceAll('s', '')),
                'resolution': _selectedResolution,
              }
            : null,
        onPredictionStarted: (String pollUrl, String cancelUrl) {
          if (mounted) {
            _currentPollUrl = pollUrl;
            _currentCancelUrl = cancelUrl;
          }
        },
      );

      // Deduct credits on success
      await _creditService.deductCredits(_effectiveCreditCost);

      if (mounted) {
        setState(() {
          if (_selectedCategory == 'image') {
            _generatedImageUrl = url;
          } else {
            _generatedVideoUrl = url;
          }
          _isResultFromGeneration = true;
        });

        // Also save locally immediately for "My Assets"
        BackgroundGenerationService().saveAndNotifyAsset(
          url: url,
          category: _selectedCategory,
          prompt: prompt,
        );
      }
    } catch (e) {
      if (mounted) {
        if (_isCancelled) {
          _isCancelled = false;
          setState(() {
            _generatedImageUrl = _previousImageUrl;
            _generatedVideoUrl = _previousVideoUrl;
          });
          return;
        }
        if (e is NsfwContentException) {
          if (e.url != null) {
            setState(() {
              _generatedImageUrl = e.url;
              _isNsfw = true;
            });
          } else {
            setState(() {
              _generatedImageUrl = _previousImageUrl;
              _generatedVideoUrl = _previousVideoUrl;
            });
          }
          ErrorDialogHelper.showRestrictedContentDialog(
            context,
            messageKey: e.messageKey,
          );
        } else {
          setState(() {
            _generatedImageUrl = _previousImageUrl;
            _generatedVideoUrl = _previousVideoUrl;
          });
          ErrorDialogHelper.showErrorDialog(
            context,
            title: 'Something went wrong',
            message:
                'We encountered an error while processing your request. Please try again.',
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
        _promptFocusNode.unfocus();
      }
    }
  }

  // ── Two-stage pipeline ──────────────────────────────────────────────────────
  // Stage 1: image model + imagePrompt + uploaded photo  → edited image URL
  // Stage 2: first video model + videoPrompt + temp file  → final video URL
  Future<void> _generateTwoStage() async {
    FocusManager.instance.primaryFocus?.unfocus();

    String actualImagePrompt = widget.imagePrompt;
    String actualVideoPrompt = widget.videoPrompt;
    if (_enhancePrompt) {
      if (actualImagePrompt.isNotEmpty) {
        actualImagePrompt =
            '$actualImagePrompt, masterpiece, best quality, highly detailed, 4k, 8k, ultra-detailed, cinematic lighting, photorealistic';
      }
      if (actualVideoPrompt.isNotEmpty) {
        actualVideoPrompt =
            '$actualVideoPrompt, masterpiece, best quality, highly detailed, 4k, 8k, ultra-detailed, cinematic lighting, photorealistic';
      }
    }
    if (_selectedImages.isEmpty) {
      showThemedDialog(
        context,
        title: 'Upload Photo',
        message: 'Please upload a photo to use the two-stage pipeline.',
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
      return;
    }

    if (_selectedModel == null) {
      showThemedDialog(
        context,
        title: 'Error',
        message: 'No model selected or available',
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
      return;
    }

    final imageModel = _selectedImageModel ?? _selectedModel!;
    final videoModel =
        _selectedVideoModel ?? _replicateService.videoModels.firstOrNull;
    if (videoModel == null) {
      showThemedDialog(
        context,
        title: 'Error',
        message: 'No video model available.',
        icon: Icons.error_outline,
        iconColor: Colors.red,
      );
      return;
    }

    // --- Safety Check ---

    // Credit gate — charge cost of both models
    final totalCost = _effectiveCreditCost;

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    // ── 1. Ad gate (Check BEFORE clearing state) ───────────────────────────
    final canProceed = await GenerationGate.check(
      context: context,
      creditService: _creditService,
      creditCost: totalCost,
    );

    if (!canProceed) {
      return;
    }

    // ── 2. Progress state (immediate feedback) ───────────────────────────────
    setState(() {
      _selectedCategory = 'video';
      _isGenerating = true;
      _isNsfw = false;
      _previousImageUrl = _generatedImageUrl;
      _previousVideoUrl = _generatedVideoUrl;
      _generatedImageUrl = null;
      _generatedVideoUrl = null;
    });

    if (!mounted) return;



    // ── 4. Local Execution (Wait Here) ──────────────────────────────────────
    try {
      _isCancelled = false;
      // Stage 1: Image Edit
      final editedImageUrl = await _replicateService.generateContent(
        modelConfig: imageModel,
        prompt: actualImagePrompt,
        referenceImage: _selectedImages.isNotEmpty
            ? _selectedImages.first
            : null,
        aspectRatio: imageModel.supportsAspectRatio
            ? _selectedAspectRatio
            : null,
      );

      final tempFile = await _downloadToTempFile(editedImageUrl);

      // Stage 2: Video Generation
      final videoUrl = await _replicateService.generateContent(
        modelConfig: videoModel,
        prompt: actualVideoPrompt,
        referenceImage: tempFile,
        aspectRatio: videoModel.supportsAspectRatio
            ? _selectedAspectRatio
            : null,
        extraVariables: {
          'duration': int.tryParse(_selectedDuration.replaceAll('s', '')),
          'resolution': _selectedResolution,
        },
      );

      // Deduct credits on success
      await _creditService.deductCredits(totalCost);

      if (mounted) {
        setState(() {
          _generatedVideoUrl = videoUrl;
          _selectedCategory = 'video';
          _isResultFromGeneration = true;
        });

        // Also save locally immediately for "My Assets"
        BackgroundGenerationService().saveAndNotifyAsset(
          url: videoUrl,
          category: 'video',
          prompt: widget.videoPrompt,
        );
      }

      // Clean up temp file
      try {
        await tempFile.delete();
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        if (_isCancelled) {
          _isCancelled = false;
          setState(() {
            _generatedImageUrl = _previousImageUrl;
            _generatedVideoUrl = _previousVideoUrl;
          });
          return;
        }
        if (e is NsfwContentException) {
          if (e.url != null) {
            setState(() {
              _generatedImageUrl = e.url;
              _isNsfw = true;
            });
          } else {
            setState(() {
              _generatedImageUrl = _previousImageUrl;
              _generatedVideoUrl = _previousVideoUrl;
            });
          }
          ErrorDialogHelper.showRestrictedContentDialog(
            context,
            messageKey: e.messageKey,
          );
        } else {
          setState(() {
            _generatedImageUrl = _previousImageUrl;
            _generatedVideoUrl = _previousVideoUrl;
          });
          ErrorDialogHelper.showErrorDialog(
            context,
            title: 'Something went wrong',
            message:
                'We encountered an error while processing your request. Please try again.',
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
        _promptFocusNode.unfocus();
      }
    }
  }

  /// Downloads [url] to a temporary file and returns the [File].
  Future<File> _downloadToTempFile(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to download edited image: ${response.statusCode}',
      );
    }
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/stage1_edited_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(response.bodyBytes);
    return file;
  }

  Future<void> _onAnimatePressed() async {
    if (_generatedImageUrl == null) return;

    setState(() {
      _isDownloading = true;
    });

    try {
      final tempFile = await _downloadToTempFile(_generatedImageUrl!);

      // Compute fingerprint for the freshly-downloaded reference image so the
      // dedup list stays in lock-step with [_selectedImages].
      ImageFingerprint? fingerprint;
      try {
        fingerprint = await ImageDedupHelper.fingerprint(tempFile);
      } catch (e) {
        debugPrint(
          '⚠️ [GenerationPage] Failed to fingerprint animated image: $e',
        );
      }

      if (mounted) {
        setState(() {
          _selectedImages = [tempFile];
          _selectedImageHashes = fingerprint != null ? [fingerprint] : [];
          _selectedCategory = 'video';
          _updateSelectedModel();
          _isDownloading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
        ErrorDialogHelper.showErrorDialog(
          context,
          message: 'Failed to prepare image for animation: $e',
        );
      }
    }
  }

  Future<bool> _onWillPop() async {
    if (!_isGenerating) return true;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: EdgeInsets.all(sw * 0.06),
          decoration: BoxDecoration(
            color: AppColors.tileBackgroundColor(isDark),
            borderRadius: BorderRadius.circular(
              MediaQuery.of(context).size.width * 0.06,
            ),
            border: Border.all(
              color: AppColors.creditsCardBorder(isDark),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: EdgeInsets.all(sw * 0.04),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9800).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_motion_rounded,
                  color: const Color(0xFFFF9800),
                  size: sw * 0.08,
                ),
              ),
              SizedBox(height: sh * 0.025),
              Text(
                'Generation in Progress',
                style: TextStyle(
                  color: AppColors.textColor(isDark),
                  fontSize: sw * 0.055,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: sh * 0.015),
              Text(
                'You have a generation running. Leaving this screen will cancel the request entirely and refund your credits.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.secondaryTextColor(isDark),
                  fontSize: sw * 0.035,
                  height: 1.5,
                ),
              ),
              SizedBox(height: sh * 0.04),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, 'cancel_request'),
                    child: Container(
                      height: sh * 0.065,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          MediaQuery.of(context).size.width * 0.04,
                        ),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Leave & Cancel',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: sw * 0.04,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.015),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: sh * 0.015),
                    ),
                    onPressed: () => Navigator.pop(ctx, 'wait'),
                    child: Text(
                      'Stay & Wait',
                      style: TextStyle(
                        color: AppColors.secondaryTextColor(isDark),
                        fontWeight: FontWeight.w600,
                        fontSize: sw * 0.038,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (result == 'cancel_request') {
      _replicateService.cancelActivePrediction();
      setState(() {
        _isGenerating = false;
        _currentPollUrl = null;
        _currentCancelUrl = null;
        _isCancelled = true;
        _generatedImageUrl = _previousImageUrl;
        _generatedVideoUrl = _previousVideoUrl;
      });
      return true;
    }

    return false; // User selected 'wait' or dismissed dialog
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: !_isGenerating && !_showFullScreenPreview,
      onPopInvokedWithResult: (didPop, dynamic dynamicResult) async {
        if (didPop) return;
        if (_showFullScreenPreview) {
          setState(() => _showFullScreenPreview = false);
          return;
        }
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.pop(context);
        }
      },
      child: StreamBuilder<int>(
        stream: _creditService.creditStream,
        initialData: _creditService.credits,
        builder: (context, snapshot) {
          final currentCredits = snapshot.data ?? 0;
          return Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: AppColors.backgroundColor(isDark),
            body: SafeArea(
              bottom: false,
              child: Stack(
                children: [
                  Column(
                    children: [
                      // Content Display & Floating Header — hidden when keyboard is open
                      if (MediaQuery.of(context).viewInsets.bottom == 0)
                        Expanded(
                          child: Stack(
                            children: [
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: screenWidth * 0.02,
                                ),
                                child: _buildContentDisplay(
                                  screenWidth,
                                  screenHeight,
                                  isDark,
                                ),
                              ),
                              Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: _buildHeader(
                                  screenWidth,
                                  screenHeight,
                                  isDark,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        const Spacer(),

                      // Prompt Input
                      PromptInput(
                        screenWidth: screenWidth,
                        screenHeight: screenHeight,
                        isDark: isDark,
                        controller: _promptController,
                        focusNode: _promptFocusNode,
                        selectedImages: _selectedImages,
                        noOfUploadable: _noOfUploadable,
                        onRemoveImage: _onRemoveImage,
                        onAddImagePressed: () async {
                          final file = await ImagePickerHelper.pickAndCropImage(
                            context,
                          );
                          if (file != null) {
                            _onImageUploaded(file);
                          }
                        },
                        showCategoryToggle: widget.showCategoryToggle,
                        selectedCategory: _selectedCategory,
                        onCategoryChanged: (cat) {
                          setState(() {
                            _selectedCategory = cat;
                            _updateSelectedModel();
                          });
                        },
                      ),
                      SizedBox(height: screenHeight * 0.015),
                      Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: GenerationBottomBar(
                          isGenerating: _isGenerating,
                          selectedCategory: _selectedCategory,
                          isSettingsSelected: _selectedIcon == 'settings',
                          isEditSelected: _selectedIcon == 'edit',
                          isImageSelected: _selectedCategory == 'image',
                          isVideoSelected: _selectedCategory == 'video',
                          currentCredits: currentCredits,
                          creditCost: _effectiveCreditCost,
                          showCategoryToggle: widget.showCategoryToggle,
                          noOfUploadable: _noOfUploadable,
                          // Models
                          imageModels: _replicateService.imageModels,
                          videoModels: _replicateService.videoModels,
                          selectedModel: _selectedModel,
                          modelOptions: _selectedModel?.options,
                          selectedImage: _selectedImages.isNotEmpty
                              ? _selectedImages.first
                              : null,
                          imageEditMode: widget.imageEditMode,
                          selectedImageModel: _selectedImageModel,
                          selectedVideoModel: _selectedVideoModel,
                          onImageModelSelected: (m) => setState(() {
                            _selectedImageModel = m;
                            _syncOptionsToModel();
                          }),
                          onVideoModelSelected: (m) => setState(() {
                            _selectedVideoModel = m;
                            _syncOptionsToModel();
                          }),
                          onModelSelected: (m) => setState(() {
                            _selectedModel = m;
                            _syncOptionsToModel();
                          }),
                          // Settings state
                          selectedAspectRatio: _selectedAspectRatio,
                          selectedDuration: _selectedDuration,
                          selectedResolution: _selectedResolution,
                          enhancePrompt: _enhancePrompt,
                          onAspectRatioChanged: (v) =>
                              setState(() => _selectedAspectRatio = v),
                          onDurationChanged: (v) =>
                              setState(() => _selectedDuration = v),
                          onResolutionChanged: (v) =>
                              setState(() => _selectedResolution = v),
                          onEnhancePromptChanged: (v) =>
                              setState(() => _enhancePrompt = v),
                          // Actions
                          onCreatePressed: _generateContent,
                          onEditPressed: () =>
                              setState(() => _selectedIcon = 'edit'),
                          onImageUploaded: _onImageUploaded,
                          onImagePressed: () {
                            setState(() {
                              _selectedCategory = 'image';
                              _updateSelectedModel();
                            });
                          },
                          onVideoPressed: () {
                            setState(() {
                              _selectedCategory = 'video';
                              _updateSelectedModel();
                            });
                          },
                          // First-visit intro animation
                          showIntroAnimation: _showIntroAnimation,
                        ),
                      ),
                    ],
                  ),
                if (_showFullScreenPreview)
                  _buildFullScreenPreviewOverlay(
                    screenWidth,
                    screenHeight,
                    isDark,
                  ),
              ],
            ),
          ),
        );
      },
      ),
    );
  }

  Future<void> _downloadContent() async {
    if (_isDownloading) return;
    setState(() {
      _isDownloading = true;
    });

    if (_selectedCategory == 'image' && _generatedImageUrl != null) {
      await MediaService.downloadImage(context, _generatedImageUrl!);
    } else if (_selectedCategory == 'video' && _generatedVideoUrl != null) {
      await MediaService.downloadVideo(context, _generatedVideoUrl!);
    }

    if (mounted) {
      setState(() => _isDownloading = false);
    }
  }

  Widget _buildHeader(double screenWidth, double screenHeight, bool isDark) {
    final hasResult = (_generatedImageUrl != null && _generatedImageUrl!.isNotEmpty) ||
        (_generatedVideoUrl != null && _generatedVideoUrl!.isNotEmpty);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.02,
        vertical: screenHeight * 0.008,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () async {
              final navState = context
                  .findAncestorStateOfType<MainNavigationState>();
              final canPop = await Navigator.maybePop(context);
              if (!canPop && mounted && navState != null) {
                navState.switchTab(0);
              }
            },
            child: Container(
              padding: EdgeInsets.all(screenWidth * 0.02),
              decoration: BoxDecoration(
                color: AppColors.tileBackgroundColor(isDark).withValues(alpha: 0.8),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: AppColors.textColor(isDark),
                size: screenWidth * 0.05,
              ),
            ),
          ),
          Row(
            children: [
              if (hasResult) ...[
                GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    setState(() {
                      _showFullScreenPreview = true;
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.all(screenWidth * 0.02),
                    decoration: BoxDecoration(
                      color: AppColors.tileBackgroundColor(isDark).withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.fullscreen,
                      color: AppColors.textColor(isDark),
                      size: screenWidth * 0.05,
                    ),
                  ),
                ),
                SizedBox(width: screenWidth * 0.03),
              ],
              if (hasResult && _isResultFromGeneration) ...[
                GestureDetector(
                  onTap: _generateContent,
                  child: Container(
                    padding: EdgeInsets.all(screenWidth * 0.02),
                    decoration: BoxDecoration(
                      color: AppColors.tileBackgroundColor(isDark).withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.refresh,
                      color: AppColors.textColor(isDark),
                      size: screenWidth * 0.05,
                    ),
                  ),
                ),
                SizedBox(width: screenWidth * 0.03),
                GestureDetector(
                  onTap: _downloadContent,
                  child: Container(
                    padding: EdgeInsets.all(screenWidth * 0.02),
                    decoration: BoxDecoration(
                      color: AppColors.tileBackgroundColor(isDark).withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: _isDownloading
                        ? SizedBox(
                            width: screenWidth * 0.05,
                            height: screenWidth * 0.05,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            Icons.download,
                            color: AppColors.textColor(isDark),
                            size: screenWidth * 0.05,
                          ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContentDisplay(
    double screenWidth,
    double screenHeight,
    bool isDark,
  ) {
    if (_isGenerating) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            SizedBox(height: screenHeight * 0.02),
            Text(
              'Generating $_selectedCategory...',
              style: TextStyle(
                color: AppColors.secondaryTextColor(isDark),
                fontSize: screenWidth * 0.04,
              ),
            ),
          ],
        ),
      );
    }

    return (_selectedCategory == 'image'
            ? _generatedImageUrl != null && _generatedImageUrl!.isNotEmpty
            : _generatedVideoUrl != null && _generatedVideoUrl!.isNotEmpty)
        ? _buildResultView(screenWidth, screenHeight, isDark)
        : _buildPlaceholder(screenWidth, screenHeight, isDark);
  }

  Widget _buildResultView(
    double screenWidth,
    double screenHeight,
    bool isDark,
  ) {
    Widget resultWidget;
    if (_selectedCategory == 'image' &&
        _generatedImageUrl != null &&
        _generatedImageUrl!.isNotEmpty) {
      Widget imageWidget;

      imageWidget = CachedNetworkImage(
        imageUrl: _generatedImageUrl!,
        width: double.infinity,
        fit: BoxFit.contain,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => const Icon(Icons.error_outline),
      );

      if (_isNsfw) {
        imageWidget = ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: imageWidget,
        );
      }

      resultWidget = Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(screenWidth * 0.06),
          child: Stack(
            alignment: Alignment.center,
            children: [
              imageWidget,
              if (_isNsfw)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: Center(
                    child: Icon(
                      Icons.visibility_off,
                      color: Colors.white,
                      size: MediaQuery.of(context).size.width * 0.12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    } else {
      resultWidget = VideoResultView(
        videoUrl: _generatedVideoUrl!,
        borderRadius: screenWidth * 0.06,
        onTap: () {
          FocusScope.of(context).unfocus();
          setState(() {
            _showFullScreenPreview = true;
          });
        },
      );

      if (_isNsfw) {
        resultWidget = Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(screenWidth * 0.06),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: resultWidget,
                ),
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: Center(
                    child: Icon(
                      Icons.visibility_off,
                      color: Colors.white,
                      size: MediaQuery.of(context).size.width * 0.12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              setState(() {
                _showFullScreenPreview = true;
              });
            },
            child: resultWidget,
          ),
        ),
        if (_isLiked == null && !_isNsfw && _isResultFromGeneration) ...[
          SizedBox(height: screenHeight * 0.015),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Was this generation helpful?',
                style: TextStyle(
                  color: AppColors.secondaryTextColor(isDark),
                  fontSize: screenWidth * 0.038,
                ),
              ),
              SizedBox(width: screenWidth * 0.03),
              GestureDetector(
                onTap: (_isLiked != null || _isNsfw)
                    ? null
                    : () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        setState(() => _isLiked = true);
                        FeedbackHelper.showThumbsUpDialog(
                          context,
                          isDark: isDark,
                        );
                      },
                child: Container(
                  padding: EdgeInsets.all(
                    MediaQuery.of(context).size.width * 0.02,
                  ),
                  decoration: BoxDecoration(
                    color: _isLiked == true
                        ? Colors.green.withValues(alpha: 0.2)
                        : (isDark ? Colors.white12 : Colors.grey.shade200),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isLiked == true
                        ? Icons.thumb_up_rounded
                        : Icons.thumb_up_outlined,
                    color: _isLiked == true
                        ? Colors.green
                        : AppColors.textColor(isDark),
                    size: MediaQuery.of(context).size.width * 0.05,
                  ),
                ),
              ),
              SizedBox(width: screenWidth * 0.03),
              GestureDetector(
                onTap: (_isLiked != null || _isNsfw)
                    ? null
                    : () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        setState(() => _isLiked = false);
                        FeedbackHelper.showThumbsDownDialog(
                          context,
                          isDark: isDark,
                        );
                      },
                child: Container(
                  padding: EdgeInsets.all(
                    MediaQuery.of(context).size.width * 0.02,
                  ),
                  decoration: BoxDecoration(
                    color: _isLiked == false
                        ? Colors.red.withValues(alpha: 0.2)
                        : (isDark ? Colors.white12 : Colors.grey.shade200),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isLiked == false
                        ? Icons.thumb_down_rounded
                        : Icons.thumb_down_outlined,
                    color: _isLiked == false
                        ? Colors.red
                        : AppColors.textColor(isDark),
                    size: MediaQuery.of(context).size.width * 0.05,
                  ),
                ),
              ),
              SizedBox(width: screenWidth * 0.03),
              GestureDetector(
                onTap: (_isLiked != null || _isNsfw)
                    ? null
                    : () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        setState(() => _isNsfw = true);
                        showThemedDialog(
                          context,
                          title: 'Flagged',
                          message: 'Content flagged as inappropriate.',
                          icon: Icons.flag_outlined,
                          iconColor: Colors.red,
                        );
                      },
                child: Container(
                  padding: EdgeInsets.all(
                    MediaQuery.of(context).size.width * 0.02,
                  ),
                  decoration: BoxDecoration(
                    color: _isNsfw
                        ? Colors.red.withValues(alpha: 0.2)
                        : (isDark ? Colors.white12 : Colors.grey.shade200),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isNsfw ? Icons.flag_rounded : Icons.flag_outlined,
                    color: _isNsfw ? Colors.red : AppColors.textColor(isDark),
                    size: MediaQuery.of(context).size.width * 0.05,
                  ),
                ),
              ),
            ],
          ),
        ],

        SizedBox(height: screenHeight * 0.01),
      ],
    );
  }

  Widget _buildPlaceholder(
    double screenWidth,
    double screenHeight,
    bool isDark,
  ) {
    return _SlideshowPlaceholder(
      screenWidth: screenWidth,
      screenHeight: screenHeight,
      isDark: isDark,
      category: _selectedCategory,
      onPromptTap: (prompt) {
        setState(() {
          _promptController.text = prompt;
        });
      },
    );
  }

  Widget _buildFullScreenPreviewOverlay(
    double screenWidth,
    double screenHeight,
    bool isDark,
  ) {
    final mediaUrl =
        _selectedCategory == 'image' ? _generatedImageUrl : _generatedVideoUrl;
    if (mediaUrl == null || mediaUrl.isEmpty) return const SizedBox.shrink();

    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.95),
        child: SafeArea(
          child: Stack(
            children: [
              // Main content positioned higher towards top of screen
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(
                    top: screenHeight * 0.07,
                    left: screenWidth * 0.04,
                    right: screenWidth * 0.04,
                    bottom: screenHeight * 0.04,
                  ),
                  child: _selectedCategory == 'image'
                      ? InteractiveViewer(
                          maxScale: 4.0,
                          child: CachedNetworkImage(
                            imageUrl: mediaUrl,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(color: Colors.white),
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.error_outline,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : VideoResultView(
                          videoUrl: mediaUrl,
                          borderRadius: screenWidth * 0.04,
                        ),
                ),
              ),

              // Premium Glassmorphism Close Button at top right
              Positioned(
                top: screenWidth * 0.03,
                right: screenWidth * 0.04,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _showFullScreenPreview = false;
                    });
                  },
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: EdgeInsets.all(screenWidth * 0.028),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.35),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: screenWidth * 0.055,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideshowPlaceholder extends StatefulWidget {
  final double screenWidth;
  final double screenHeight;
  final bool isDark;
  final String category;
  final ValueChanged<String>? onPromptTap;

  const _SlideshowPlaceholder({
    required this.screenWidth,
    required this.screenHeight,
    required this.isDark,
    required this.category,
    this.onPromptTap,
  });

  @override
  State<_SlideshowPlaceholder> createState() => _SlideshowPlaceholderState();
}

class _SlideshowPlaceholderState extends State<_SlideshowPlaceholder> {
  Timer? _timer;
  int _currentIndex = 0;
  List<CategoryImage> _images = [];

  @override
  void initState() {
    super.initState();
    _loadImages();
  }

  @override
  void didUpdateWidget(covariant _SlideshowPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) {
      _loadImages();
    }
  }

  void _loadImages() {
    final dataService = DataService();
    final configService = RemoteConfigService();

    if (widget.category == 'image') {
      final genPageImage = configService.generationPageImage;
      if (genPageImage.isNotEmpty) {
        _timer?.cancel();
        setState(() {
          _images = [
            CategoryImage(
              imageUrl: genPageImage,
              prompt: '', // Fallback hint will be shown
              type: widget.category,
            ),
          ];
          _currentIndex = 0;
        });
        return;
      }
    } else if (widget.category == 'video') {
      final genPageVideo = configService.generationPageVideo;
      if (genPageVideo.isNotEmpty) {
        _timer?.cancel();
        setState(() {
          _images = [
            CategoryImage(
              imageUrl: '',
              videoUrl: genPageVideo,
              videoPrompt: '', // Fallback hint will be shown
              type: widget.category,
            ),
          ];
          _currentIndex = 0;
        });
        return;
      }
    }

    // Get images for the current category, or trending if not found
    var fetchedImages = dataService.getCategoryImages(widget.category);
    if (fetchedImages.isEmpty) {
      fetchedImages = dataService.trendingItems;
    }

    // Filter out images with invalid URLs or missing prompts
    final validImages = fetchedImages.where((img) {
      if (widget.category == 'video') {
        final hasVideo =
            img.videoUrl != null &&
            img.videoUrl!.isNotEmpty &&
            img.videoUrl!.startsWith('http');
        final hasPrompt =
            img.videoPrompt.trim().isNotEmpty || img.prompt.trim().isNotEmpty;
        return hasVideo && hasPrompt;
      } else {
        final hasImage =
            img.imageUrl.isNotEmpty && img.imageUrl.startsWith('http');
        final hasPrompt = img.prompt.trim().isNotEmpty;
        return hasImage && hasPrompt;
      }
    }).toList();

    // Copy and shuffle images to make it interesting
    _images = List.from(validImages)..shuffle();

    _timer?.cancel();
    if (_images.isNotEmpty) {
      _timer = Timer.periodic(const Duration(seconds: 38), (timer) {
        if (mounted) {
          setState(() {
            _currentIndex = (_currentIndex + 1) % _images.length;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_images.isEmpty) {
      // Fallback to original placeholder if no images
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.category == 'image'
                    ? Icons.image_outlined
                    : Icons.videocam_outlined,
                color: AppColors.iconColor(
                  widget.isDark,
                ).withValues(alpha: 0.5),
                size: widget.screenWidth * 0.2,
              ),
              SizedBox(height: widget.screenHeight * 0.02),
              Text(
                'Enter a prompt to generate a ${widget.category}',
                style: TextStyle(
                  color: AppColors.secondaryTextColor(widget.isDark),
                  fontSize: widget.screenWidth * 0.04,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final currentImage = _images[_currentIndex];
    final String promptToUse = widget.category == 'video'
        ? (currentImage.videoPrompt.isNotEmpty
              ? currentImage.videoPrompt
              : currentImage.prompt)
        : currentImage.prompt;
    final String keyString = widget.category == 'video'
        ? (currentImage.videoUrl ?? currentImage.imageUrl)
        : currentImage.imageUrl;

    final double videoWidth = widget.screenWidth * 0.90;
    final double videoHeight = widget.screenHeight * 0.45;

    final double maxImageSize =
        (widget.screenWidth * 0.85 < widget.screenHeight * 0.42)
        ? widget.screenWidth * 0.85
        : widget.screenHeight * 0.42;

    return GestureDetector(
      onTap: () => widget.onPromptTap?.call(promptToUse),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(seconds: 1),
                child:
                    (currentImage.videoUrl != null &&
                        currentImage.videoUrl!.isNotEmpty)
                    ? Container(
                        key: ValueKey<String>(keyString),
                        width: videoWidth,
                        height: videoHeight,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(
                            MediaQuery.of(context).size.width * 0.05,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: VideoResultView(
                          videoUrl: currentImage.videoUrl!,
                          borderRadius: 0,
                        ),
                      )
                    : Container(
                        key: ValueKey<String>(keyString),
                        width: maxImageSize,
                        height: maxImageSize,
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? const Color(0xFF161616)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(
                            MediaQuery.of(context).size.width * 0.06,
                          ),
                          image: DecorationImage(
                            image: CachedNetworkImageProvider(
                              currentImage.imageUrl,
                            ),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
              ),
              SizedBox(height: widget.screenHeight * 0.03),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Padding(
                  key: ValueKey<String>(promptToUse),
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.screenWidth * 0.1,
                  ),
                  child: Text(
                    promptToUse.isNotEmpty
                        ? promptToUse
                        : 'Enter a prompt to generate a ${widget.category}',
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.secondaryTextColor(widget.isDark),
                      fontSize: widget.screenWidth * 0.038,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
