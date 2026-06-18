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
import '../Widgets/topbar.dart';
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

  /// Whether to automatically trigger the image picker upon entering the page
  final bool autoTriggerImagePicker;

  const GenerationPage({
    super.key,
    this.initialCategory = 'image',
    this.initialPrompt,
    this.initialIsEditable = false,
    this.imageEditMode = false,
    this.imagePrompt = '',
    this.videoPrompt = '',
    this.initialModelId,
    this.autoTriggerImagePicker = false,
  });

  @override
  State<GenerationPage> createState() => _GenerationPageState();
}

class _GenerationPageState extends State<GenerationPage> {
  final TextEditingController _promptController = TextEditingController();
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
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  bool _hasImagesArray(AIModelConfig model) {
    return jsonEncode(model.requestBodyTemplate).contains('"images"');
  }

  Future<void> _generateContent() async {
    if (widget.imageEditMode) {
      await _generateTwoStage();
      return;
    }

    final prompt = _promptController.text.trim();
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
          ErrorDialogHelper.showRestrictedContentDialog(context, messageKey: e.messageKey);
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Generation failed: $e')));
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
                    borderRadius: BorderRadius.circular(24),
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
                                borderRadius: BorderRadius.circular(16),
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
                          const SizedBox(height: 12),

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

      if (_selectedModel!.supportsDimensions) {
        width = int.tryParse(_widthController.text) ?? 1024;
        height = int.tryParse(_heightController.text) ?? 1024;
      } else if (_selectedModel!.supportsAspectRatio) {
        aspectRatio = _selectedAspectRatio;
      }

      final Map<String, dynamic> extraVariables = {};
      if (_selectedCategory == 'video') {
        final durInt = int.tryParse(_selectedDuration.replaceAll('s', ''));
        if (durInt != null) extraVariables['duration'] = durInt;
        extraVariables['resolution'] = _selectedResolution;
      }

      // Deduct credits immediately
      await _creditService.deductCredits(_selectedModel?.creditUsed ?? 0);

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
      int? width;
      int? height;
      String? aspectRatio;

      if (_selectedModel!.supportsDimensions) {
        width = int.tryParse(_widthController.text) ?? 1024;
        height = int.tryParse(_heightController.text) ?? 1024;
      } else if (_selectedModel!.supportsAspectRatio) {
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
        if (e is NsfwContentException) {
          if (e.url != null && _selectedCategory == 'image') {
            setState(() {
              _generatedImageUrl = e.url;
              _isNsfw = true;
            });
          }
          ErrorDialogHelper.showRestrictedContentDialog(context, messageKey: e.messageKey);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${'error'.i18n()}${e.toString()}')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ── Two-stage pipeline ──────────────────────────────────────────────────────
  // Stage 1: image model + imagePrompt + uploaded photo  → edited image URL
  // Stage 2: first video model + videoPrompt + temp file  → final video URL
  Future<void> _generateTwoStage() async {
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
    try {
      // Show checking overlay
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFD66031)),
        ),
      );

      if (widget.imagePrompt.trim().isNotEmpty) {
        await ContentSafetyService().checkTextSafe(widget.imagePrompt);
      }
      if (widget.videoPrompt.trim().isNotEmpty) {
        await ContentSafetyService().checkTextSafe(widget.videoPrompt);
      }
      if (_selectedImage != null) {
        await ContentSafetyService().checkImageFileSafe(_selectedImage!);
      }

      if (mounted) Navigator.pop(context); // Remove loading
    } catch (e) {
      if (mounted) Navigator.pop(context); // Remove loading
      if (e is NsfwContentException) {
        if (mounted) {
          ErrorDialogHelper.showRestrictedContentDialog(context, messageKey: e.messageKey);
        }
        return;
      }
      debugPrint('⚠️ [GenerationPage] Two-stage safety check error: $e');
    }

    // Credit gate — charge cost of both models
    final totalCost = (imageModel.creditUsed) + (videoModel.creditUsed);

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    // ── 1. Progress state ───────────────────────────────────────────────────
    setState(() {
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
                  borderRadius: BorderRadius.circular(24),
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
                              borderRadius: BorderRadius.circular(16),
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
                        const SizedBox(height: 12),

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
      await _creditService.deductCredits(totalCost);

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
        imagePrompt: widget.imagePrompt,
        videoPrompt: widget.videoPrompt,
        referenceImage: _selectedImage,
        aspectRatio: _selectedAspectRatio,
      );
      return;
    }

    // ── 4. Local Execution (Wait Here) ──────────────────────────────────────
    try {
      // Stage 1: Image Edit
      final editedImageUrl = await _replicateService.generateContent(
        modelConfig: imageModel,
        prompt: widget.imagePrompt,
        referenceImage: _selectedImage,
        aspectRatio: imageModel.supportsAspectRatio
            ? _selectedAspectRatio
            : null,
      );

      final tempFile = await _downloadToTempFile(editedImageUrl);

      // Stage 2: Video Generation
      final videoUrl = await _replicateService.generateContent(
        modelConfig: videoModel,
        prompt: widget.videoPrompt,
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
        if (e is NsfwContentException) {
          if (e.url != null && _selectedCategory == 'image') {
            setState(() {
              _generatedImageUrl = e.url;
              _isNsfw = true;
            });
          }
          ErrorDialogHelper.showRestrictedContentDialog(context, messageKey: e.messageKey);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Two-stage error: ${e.toString()}')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<int>(
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
                      selectedImage: _selectedImage,
                      onRemoveImage: () =>
                          setState(() => _selectedImage = null),
                    ),
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
                    onDownload: () {
                      setState(() => _showMenu = false);
                      // TODO: Implement batch download
                    },
                    onDelete: () {
                      setState(() {
                        _showMenu = false;
                        _generatedImageUrl = null;
                        _generatedVideoUrl = null;
                        _isLiked = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
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
          const TopBar(),
          SizedBox(height: screenHeight * 0.012),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
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

  Widget _buildResultView(double screenWidth, double screenHeight, bool isDark) {
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
                  child: const Center(
                    child: Icon(
                      Icons.visibility_off,
                      color: Colors.white,
                      size: 48,
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
    }

    return Column(
      children: [
        Expanded(child: resultWidget),
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
              onTap: () {
                setState(() => _isLiked = true);
                FeedbackHelper.showThumbsUpDialog(context, isDark: isDark);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isLiked == true
                      ? Colors.green.withValues(alpha: 0.2)
                      : (isDark ? Colors.white12 : Colors.grey.shade200),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isLiked == true ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                  color: _isLiked == true ? Colors.green : AppColors.textColor(isDark),
                  size: 20,
                ),
              ),
            ),
            SizedBox(width: screenWidth * 0.03),
            GestureDetector(
              onTap: () {
                setState(() => _isLiked = false);
                FeedbackHelper.showThumbsDownDialog(context, isDark: isDark);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isLiked == false
                      ? Colors.red.withValues(alpha: 0.2)
                      : (isDark ? Colors.white12 : Colors.grey.shade200),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isLiked == false ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
                  color: _isLiked == false ? Colors.red : AppColors.textColor(isDark),
                  size: 20,
                ),
              ),
            ),
          ],
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _selectedCategory == 'image'
                ? Icons.image_outlined
                : Icons.videocam_outlined,
            color: AppColors.iconColor(isDark).withValues(alpha: 0.5),
            size: screenWidth * 0.2,
          ),
          SizedBox(height: screenHeight * 0.02),
          Text(
            '${'enter_prompt_hint'.i18n()} $_selectedCategory',
            style: TextStyle(
              color: AppColors.secondaryTextColor(isDark),
              fontSize: screenWidth * 0.04,
            ),
          ),
        ],
      ),
    );
  }
}
