import 'dart:io';
import 'package:flutter/material.dart';
import 'package:trail_ai_app/Core/colors.dart';
import 'package:trail_ai_app/Core/gradient.dart';
import 'package:localization/localization.dart';
import '../Helpers/feedback_helper.dart';
import '../Services/replicate_service.dart';
import '../Services/ad_service.dart';
import '../Services/credit_service.dart';
import '../Services/generation_gate.dart';
import '../Widgets/generation_bottom_bar.dart';
import '../Widgets/menu_overlay.dart';
import '../Widgets/prompt_input.dart';
import '../Widgets/video_result_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'dart:ui';
import '../Services/background_generation_service.dart';
import '../Helpers/image_picker_helper.dart';
import '../Services/content_safety_service.dart';
import '../Helpers/error_dialog_helper.dart';
import '../Services/media_service.dart';
import '../Services/data_service.dart';
import '../Services/subscription_service.dart';
import '../Models/category_image.dart';
import 'dart:async';

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
  });

  @override
  State<GenerationPage> createState() => _GenerationPageState();
}

class _GenerationPageState extends State<GenerationPage> {
  final TextEditingController _promptController = TextEditingController();
  final FocusNode _promptFocusNode = FocusNode();
  final TextEditingController _widthController = TextEditingController(
    text: "1024",
  );
  final TextEditingController _heightController = TextEditingController(
    text: "1024",
  );

  final ReplicateService _replicateService = ReplicateService();
  final AdService _adService = AdService();
  final CreditService _creditService = CreditService();

  bool _isGenerating = false;
  String? _generatedImageUrl;
  String? _generatedVideoUrl;
  bool _showMenu = false;
  bool _isNsfw = false;
  bool? _isLiked;
  bool _isDownloading = false;

  String? _currentPollUrl;
  String? _currentCancelUrl;
  bool _isCancelled = false;

  // Reference image picked via + button
  File? _selectedImage;

  void _onImageUploaded(File file) {
    setState(() => _selectedImage = file);
  }

  // Selection State
  late String _selectedCategory; // 'image' or 'video'
  String _selectedIcon = 'image'; // 'add', 'settings', 'edit', 'image', 'video'
  AIModelConfig? _selectedModel;
  String _selectedAspectRatio = '16:9';
  String _selectedDuration = '5s';
  String _selectedResolution = '720p';
  bool _enhancePrompt = false;

  // Two-stage pipeline model selection (used only in imageEditMode)
  AIModelConfig? _selectedImageModel; // Stage 1 — image edit
  AIModelConfig? _selectedVideoModel; // Stage 2 — video generation

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

    // Auto-trigger image picker if requested by tool or imageEditMode
    if (widget.imageEditMode ||
        widget.initialIsEditable ||
        widget.autoTriggerImagePicker) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _triggerAutoImagePicker();
      });
    }
  }

  Future<void> _triggerAutoImagePicker() async {
    if (!mounted) return;
    final file = await ImagePickerHelper.pickAndCropImage(context);
    if (file != null && mounted) {
      setState(() => _selectedImage = file);
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
      if (!options.aspectRatios.contains(_selectedAspectRatio)) {
        _selectedAspectRatio = options.aspectRatios.first;
      }
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

  bool _hasImagesArray(AIModelConfig model) {
    return jsonEncode(model.requestBodyTemplate).contains('"images"');
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('please_enter_prompt'.i18n())));
      return;
    }

    if (_selectedModel == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('no_model_selected'.i18n())));
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

    // ── 1. Progress state (immediate feedback) ───────────────────────────────
    setState(() {
      _isGenerating = true;
      _isNsfw = false;
      _isLiked = null;
      if (_selectedCategory == 'image') {
        _generatedImageUrl = null;
      } else {
        _generatedVideoUrl = null;
      }
    });

    // ── 2. Ad gate ──────────────────────────────────────────────────────────
    debugPrint('🔥 [GenerationPage] Checking GenerationGate...');
    final canProceed = await GenerationGate.check(
      context: context,
      adService: _adService,
      creditService: _creditService,
      creditCost: _selectedModel?.creditUsed ?? 0,
    );
    debugPrint('🔥 [GenerationPage] GenerationGate result: $canProceed');

    if (!canProceed) {
      setState(() => _isGenerating = false);
      return;
    }

    if (!mounted) return;

    // ── 3. Background Activity Prompt (Video only) ──────────────────────────
    bool runInBackground = false;
    if (_selectedCategory == 'video') {
      final bool isDark = Theme.of(context).brightness == Brightness.dark;

      runInBackground =
          await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) {
              final sw = MediaQuery.of(context).size.width;
              final sh = MediaQuery.of(context).size.height;
              return Dialog(
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
                      // Icon Header
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

                      // Title
                      Text(
                        'generating'.i18n(),
                        style: TextStyle(
                          color: AppColors.textColor(isDark),
                          fontSize: sw * 0.055,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: sh * 0.015),

                      // Description
                      Text(
                        'Video generation usually takes 1-3 minutes. You can wait here or continue using the app while it runs in the background. We will notify you when it is ready.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.secondaryTextColor(isDark),
                          fontSize: sw * 0.035,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: sh * 0.04),

                      // Actions
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Run in Background (Primary)
                          GestureDetector(
                            onTap: () => Navigator.pop(context, true),
                            child: Container(
                              height: sh * 0.065,
                              decoration: ProGradientDecoration(
                                borderRadius: BorderRadius.circular(
                                  MediaQuery.of(context).size.width * 0.04,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'Run in Background',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: sw * 0.04,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.015,
                          ),

                          // Wait Here (Secondary)
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                vertical: sh * 0.015,
                              ),
                            ),
                            onPressed: () => Navigator.pop(context, false),
                            child: Text(
                              'Wait Here',
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
              );
            },
          ) ??
          false;
    }

    if (runInBackground) {
      int? width;
      int? height;
      String? aspectRatio;

      if (_selectedModel!.supportsAspectRatio ||
          _selectedModel!.supportsDimensions) {
        aspectRatio = _selectedAspectRatio;
      }

      final Map<String, dynamic> extraVariables = {};
      if (_selectedCategory == 'video') {
        final durInt = int.tryParse(_selectedDuration.replaceAll('s', ''));
        if (durInt != null) extraVariables['duration'] = durInt;
        extraVariables['resolution'] = _selectedResolution;
      }

      // Deduct credits immediately
      _creditService.deductCredits(_selectedModel?.creditUsed ?? 0);

      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Generation started in background. Credits deducted.',
            ),
          ),
        );
        Navigator.pop(context); // Exit page
      }

      BackgroundGenerationService().startBackgroundGeneration(
        category: _selectedCategory,
        modelConfig: _selectedModel!,
        prompt: prompt,
        aspectRatio: aspectRatio,
        width: width,
        height: height,
        referenceImage:
            _selectedModel!.iseditable && !_hasImagesArray(_selectedModel!)
            ? _selectedImage
            : null,
        images:
            _selectedModel!.iseditable &&
                _hasImagesArray(_selectedModel!) &&
                _selectedImage != null
            ? [_selectedImage!]
            : null,
        extraVariables: extraVariables,
      );
      return;
    }

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
        referenceImage:
            _selectedModel!.iseditable && !_hasImagesArray(_selectedModel!)
            ? _selectedImage
            : null,
        images:
            _selectedModel!.iseditable &&
                _hasImagesArray(_selectedModel!) &&
                _selectedImage != null
            ? [_selectedImage!]
            : null,
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
      await _creditService.deductCredits(_selectedModel?.creditUsed ?? 0);

      if (mounted) {
        setState(() {
          if (_selectedCategory == 'image') {
            _generatedImageUrl = url;
          } else {
            _generatedVideoUrl = url;
          }
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
          return;
        }
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
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload a photo to use the two-stage pipeline.'),
        ),
      );
      return;
    }

    if (_selectedModel == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('no_model_selected'.i18n())));
      return;
    }

    final imageModel = _selectedImageModel ?? _selectedModel!;
    final videoModel =
        _selectedVideoModel ?? _replicateService.videoModels.firstOrNull;
    if (videoModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No video model available.')),
      );
      return;
    }

    // --- Safety Check ---

    // Credit gate — charge cost of both models
    final totalCost = (imageModel.creditUsed) + (videoModel.creditUsed);

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    setState(() {
      _selectedCategory = 'video';
      _isGenerating = true;
      _isNsfw = false;
      _generatedImageUrl = null;
      _generatedVideoUrl = null;
    });

    // ── 2. Ad gate ──────────────────────────────────────────────────────────
    final canProceed = await GenerationGate.check(
      context: context,
      adService: _adService,
      creditService: _creditService,
      creditCost: totalCost,
    );

    if (!canProceed) {
      if (mounted) setState(() => _isGenerating = false);
      return;
    }

    if (!mounted) return;

    // ── 3. Background Activity Prompt ──────────────────────────────────────────
    bool runInBackground = false;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    runInBackground =
        await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            final sw = MediaQuery.of(context).size.width;
            final sh = MediaQuery.of(context).size.height;
            return Dialog(
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
                    // Icon Header
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

                    // Title
                    Text(
                      'generating'.i18n(),
                      style: TextStyle(
                        color: AppColors.textColor(isDark),
                        fontSize: sw * 0.055,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: sh * 0.015),

                    // Description
                    Text(
                      'Template generation involves multiple AI stages and may take 2-4 minutes. You can wait here or continue using the app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.secondaryTextColor(isDark),
                        fontSize: sw * 0.035,
                        height: 1.5,
                      ),
                    ),
                    SizedBox(height: sh * 0.04),

                    // Actions
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Run in Background (Primary)
                        GestureDetector(
                          onTap: () => Navigator.pop(context, true),
                          child: Container(
                            height: sh * 0.065,
                            decoration: ProGradientDecoration(
                              borderRadius: BorderRadius.circular(
                                MediaQuery.of(context).size.width * 0.04,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Run in Background',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: sw * 0.04,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.015,
                        ),

                        // Wait Here (Secondary)
                        TextButton(
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: sh * 0.015),
                          ),
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(
                            'Wait Here',
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
            );
          },
        ) ??
        false;

    if (!mounted) return;

    if (runInBackground) {
      // Deduct credits immediately
      _creditService.deductCredits(totalCost);

      if (mounted) {
        setState(() => _isGenerating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Two-stage generation started in background. Credits deducted.',
            ),
          ),
        );
        Navigator.pop(context); // Exit page
      }

      BackgroundGenerationService().startTwoStageBackgroundGeneration(
        imageModel: imageModel,
        videoModel: videoModel,
        imagePrompt: actualImagePrompt,
        videoPrompt: actualVideoPrompt,
        referenceImage: _selectedImage,
        aspectRatio: _selectedAspectRatio,
      );
      return;
    }

    // ── 4. Local Execution (Wait Here) ──────────────────────────────────────
    try {
      _isCancelled = false;
      // Stage 1: Image Edit
      final editedImageUrl = await _replicateService.generateContent(
        modelConfig: imageModel,
        prompt: actualImagePrompt,
        referenceImage: _selectedImage,
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
          return;
        }
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

      if (mounted) {
        setState(() {
          _selectedImage = tempFile;
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
                'You have a generation running. Would you like to continue it in the background or cancel the request entirely?',
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
                  if (_currentPollUrl != null) ...[
                    GestureDetector(
                      onTap: () => Navigator.pop(ctx, 'background'),
                      child: Container(
                        height: sh * 0.065,
                        decoration: ProGradientDecoration(
                          borderRadius: BorderRadius.circular(
                            MediaQuery.of(context).size.width * 0.04,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Run in Background',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: sw * 0.04,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.015,
                    ),
                  ],
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
                          'Cancel Generation',
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
                      'Continue Waiting',
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

    if (result == 'background') {
      if (_currentPollUrl != null) {
        BackgroundGenerationService().takeOverGeneration(
          pollUrl: _currentPollUrl!,
          category: _selectedCategory,
          prompt: _promptController.text.trim(),
        );
      }
      setState(() {
        _isGenerating = false;
        _currentPollUrl = null;
        _currentCancelUrl = null;
      });
      return true;
    } else if (result == 'cancel_request') {
      _replicateService.cancelActivePrediction();
      setState(() {
        _isGenerating = false;
        _currentPollUrl = null;
        _currentCancelUrl = null;
        _isCancelled = true;
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
      canPop: !_isGenerating,
      onPopInvoked: (didPop) async {
        if (didPop) return;
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
                      _buildHeader(screenWidth, screenHeight, isDark),

                      // Content Display — hidden when keyboard is open
                      if (MediaQuery.of(context).viewInsets.bottom == 0)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.04,
                            ),
                            child: _buildContentDisplay(
                              screenWidth,
                              screenHeight,
                              isDark,
                            ),
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
                        selectedImage: _selectedImage,
                        onRemoveImage: () =>
                            setState(() => _selectedImage = null),
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
                          creditCost: widget.imageEditMode
                              ? (_selectedImageModel?.creditUsed ?? 0) +
                                    (_selectedVideoModel?.creditUsed ?? 0)
                              : (_selectedModel?.creditUsed ?? 0),
                          // Models
                          imageModels: _replicateService.imageModels,
                          videoModels: _replicateService.videoModels,
                          selectedModel: _selectedModel,
                          modelOptions: _selectedModel?.options,
                          selectedImage: _selectedImage,
                          imageEditMode: widget.imageEditMode,
                          selectedImageModel: _selectedImageModel,
                          selectedVideoModel: _selectedVideoModel,
                          onImageModelSelected: (m) =>
                              setState(() => _selectedImageModel = m),
                          onVideoModelSelected: (m) =>
                              setState(() => _selectedVideoModel = m),
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
                        ),
                      ),
                    ],
                  ),

                  // Menu Overlay Background
                  if (_showMenu)
                    Positioned.fill(
                      child: GestureDetector(
                        onTap: () => setState(() => _showMenu = false),
                        behavior: HitTestBehavior.opaque,
                        child: const SizedBox.expand(),
                      ),
                    ),

                  // Menu Overlay
                  if (_showMenu)
                    MenuOverlay(
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
                      isDark: isDark,
                      onRecreate: () {
                        setState(() => _showMenu = false);
                        _generateContent();
                      },
                      onUseSettings: () {
                        setState(() => _showMenu = false);
                        // TODO: Implement using settings from generated content
                      },
                      onDownload: () async {
                        if (_isDownloading) return;
                        setState(() {
                          _isDownloading = true;
                          _showMenu = false;
                        });

                        // Fire-and-forget background download with progress notification
                        if (_selectedCategory == 'image' &&
                            _generatedImageUrl != null) {
                          MediaService.downloadImageInBackground(
                            _generatedImageUrl!,
                          );
                        } else if (_selectedCategory == 'video' &&
                            _generatedVideoUrl != null) {
                          MediaService.downloadVideoInBackground(
                            _generatedVideoUrl!,
                          );
                        }

                        if (mounted) {
                          setState(() => _isDownloading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Download started. Check notifications for progress.',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                      onDelete: () {
                        setState(() {
                          _showMenu = false;
                          _generatedImageUrl = null;
                          _generatedVideoUrl = null;
                          _isLiked = null;
                        });
                      },
                      isDownloading: _isDownloading,
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(double screenWidth, double screenHeight, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenHeight * 0.012,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  padding: EdgeInsets.all(screenWidth * 0.02),
                  decoration: BoxDecoration(
                    color: AppColors.tileBackgroundColor(isDark),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    color: AppColors.textColor(isDark),
                    size: screenWidth * 0.05,
                  ),
                ),
              ),
              if (_generatedImageUrl != null || _generatedVideoUrl != null)
                GestureDetector(
                  onTap: () => setState(() => _showMenu = !_showMenu),
                  child: Container(
                    padding: EdgeInsets.all(screenWidth * 0.02),
                    decoration: BoxDecoration(
                      color: AppColors.tileBackgroundColor(isDark),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.menu,
                      color: AppColors.textColor(isDark),
                      size: screenWidth * 0.05,
                    ),
                  ),
                ),
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
              '${'generating'.i18n()} $_selectedCategory...',
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
            ? _generatedImageUrl != null
            : _generatedVideoUrl != null)
        ? _buildResultView(screenWidth, screenHeight, isDark)
        : _buildPlaceholder(screenWidth, screenHeight, isDark);
  }

  Widget _buildResultView(
    double screenWidth,
    double screenHeight,
    bool isDark,
  ) {
    Widget resultWidget;
    if (_selectedCategory == 'image') {
      Widget imageWidget = CachedNetworkImage(
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
              if (!SubscriptionService().isSubscribed)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: IgnorePointer(
                    child: Image.asset(
                      'assets/images/watermark.png',
                      width: 100,
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
      );

      if (!SubscriptionService().isSubscribed) {
        resultWidget = Stack(
          alignment: Alignment.center,
          children: [
            resultWidget,
            Positioned(
              right: 16,
              bottom: 16,
              child: IgnorePointer(
                child: Image.asset(
                  'assets/images/watermark.png',
                  width: 100,
                ),
              ),
            ),
          ],
        );
      }

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
              if (!SubscriptionService().isSubscribed)
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: IgnorePointer(
                    child: Image.asset(
                      'assets/images/watermark.png',
                      width: 100,
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
        Expanded(child: resultWidget),
        if (_isLiked == null && !_isNsfw) ...[
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Content flagged as inappropriate.'),
                            backgroundColor: Colors.red,
                          ),
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
        if (_selectedCategory == 'image' && _generatedImageUrl != null)
          Padding(
            padding: EdgeInsets.only(top: screenHeight * 0.02),
            child: SizedBox(
              width: screenWidth * 0.6,
              child: ElevatedButton.icon(
                onPressed: _isDownloading ? null : _onAnimatePressed,
                icon: _isDownloading
                    ? SizedBox(
                        width: MediaQuery.of(context).size.width * 0.05,
                        height: MediaQuery.of(context).size.width * 0.05,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome, color: Colors.white),
                label: Text(
                  _isDownloading ? 'Preparing...' : 'Animate Image',
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD66031),
                  padding: EdgeInsets.symmetric(vertical: screenHeight * 0.015),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(screenWidth * 0.03),
                  ),
                ),
              ),
            ),
          ),
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
    // Get images for the current category, or trending if not found
    var fetchedImages = dataService.getCategoryImages(widget.category);
    if (fetchedImages.isEmpty) {
      fetchedImages = dataService.trendingItems;
    }

    // Filter out images with invalid URLs or missing prompts
    final validImages = fetchedImages
        .where(
          (img) =>
              img.imageUrl.isNotEmpty &&
              img.imageUrl.startsWith('http') &&
              img.prompt.trim().isNotEmpty,
        )
        .toList();

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
                '${'enter_prompt_hint'.i18n()} ${widget.category}',
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

    return GestureDetector(
      onTap: () => widget.onPromptTap?.call(currentImage.prompt),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(seconds: 1),
                child: Container(
                  key: ValueKey<String>(currentImage.imageUrl),
                  width: widget.screenWidth * 0.85,
                  height: widget.screenWidth * 0.85,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      MediaQuery.of(context).size.width * 0.06,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    image: DecorationImage(
                      image: CachedNetworkImageProvider(currentImage.imageUrl),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              SizedBox(height: widget.screenHeight * 0.03),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Padding(
                  key: ValueKey<String>(currentImage.prompt),
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.screenWidth * 0.1,
                  ),
                  child: Text(
                    currentImage.prompt.isNotEmpty
                        ? currentImage.prompt
                        : '${'enter_prompt_hint'.i18n()} ${widget.category}',
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
