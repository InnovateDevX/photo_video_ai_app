import 'dart:io';
import 'package:flutter/material.dart';
import 'package:trail_ai_app/Core/colors.dart';
import 'package:trail_ai_app/Core/gradient.dart';
import 'package:localization/localization.dart';
import '../Services/replicate_service.dart';
import '../Services/ad_service.dart';
import '../Services/credit_service.dart';
import '../Services/generation_gate.dart';
import '../Widgets/generation_bottom_bar.dart';
import '../Widgets/topbar.dart';
import 'package:video_player/video_player.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import '../Services/background_generation_service.dart';
import '../Services/content_safety_service.dart';

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

  const GenerationPage({
    super.key,
    this.initialCategory = 'image',
    this.initialPrompt,
    this.initialIsEditable = false,
    this.imageEditMode = false,
    this.imagePrompt = '',
    this.videoPrompt = '',
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

  // Video Player State
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory;
    if (widget.initialPrompt != null) {
      _promptController.text = widget.initialPrompt!;
    }
    _initializeService();

    if (widget.imageEditMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "🎨 Two-stage mode: Upload a photo → AI edits it → generates a video!",
            ),
            duration: Duration(seconds: 5),
          ),
        );
      });
    } else if (widget.initialIsEditable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Template loaded! Upload your photo to use this style.",
            ),
            duration: Duration(seconds: 4),
          ),
        );
      });
    }
  }

  Future<void> _initializeService() async {
    await _replicateService.initialize();
    await _creditService.initialize();
    if (mounted) {
      setState(() => _updateSelectedModel());
    }
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
    if (_selectedModel == null) return;
    final options = _selectedModel!.options;

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
    _videoController?.dispose();
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

    debugPrint('🔥 [GenerationPage] _generateContent called');

    // Dismiss keyboard to show progress clearly
    FocusScope.of(context).unfocus();

    // ── 1. Progress state (immediate feedback) ───────────────────────────────
    setState(() {
      _isGenerating = true;
      if (_selectedCategory == 'image') {
        _generatedImageUrl = null;
      } else {
        _generatedVideoUrl = null;
        _isVideoInitialized = false;
        _videoController?.dispose();
        _videoController = null;
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

    // ── 3. Background Activity Prompt (Video only) ──────────────────────────
    bool runInBackground = false;
    if (_selectedCategory == 'video') {
      final bool isDark = Theme.of(context).brightness == Brightness.dark;
      final sw = MediaQuery.of(context).size.width;

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
                        color: Colors.black.withOpacity(0.3),
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
                          color: const Color(0xFFFF9800).withOpacity(0.1),
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

      debugPrint(
        '🔥 [GenerationPage] Calling ReplicateService.generateContent...',
      );
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('credit_deducted'.i18n())));
      }

      if (mounted) {
        setState(() {
          if (_selectedCategory == 'image') {
            _generatedImageUrl = url;
          } else {
            _generatedVideoUrl = url;
          }
        });

        if (_selectedCategory == 'video') {
          _initializeVideoPlayer(url);
        }
      }
    } catch (e) {
      if (mounted) {
        if (e is NsfwContentException) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('restricted_content_detected'.i18n()),
              content: Text('restricted_content_detected'.i18n()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('ok'.i18n()),
                ),
              ],
            ),
          );
        } else if (e.toString().toLowerCase().contains('timeout')) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('timeout_title'.i18n()),
              content: Text('timeout_message'.i18n()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('ok'.i18n()),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${'error'.i18n()}${e.toString()}')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
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

    final videoModels = _replicateService.videoModels;
    if (videoModels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No video model available.')),
      );
      return;
    }

    // Credit gate — charge cost of both models
    final totalCost =
        (_selectedModel?.creditUsed ?? 0) + (videoModels.first.creditUsed);

    // Dismiss keyboard
    FocusScope.of(context).unfocus();

    // ── 1. Progress state ───────────────────────────────────────────────────
    setState(() {
      _isGenerating = true;
      _generatedImageUrl = null;
      _generatedVideoUrl = null;
      _isVideoInitialized = false;
      _videoController?.dispose();
      _videoController = null;
    });

    // ── 2. Ad gate ──────────────────────────────────────────────────────────
    final canProceed = await GenerationGate.check(
      context: context,
      adService: _adService,
      creditService: _creditService,
      creditCost: totalCost,
    );

    if (!canProceed) {
      setState(() => _isGenerating = false);
      return;
    }

    try {
      // ── Stage 1: image editing ──────────────────────────────────────────
      debugPrint(
        '🎨 [TwoStage] Stage 1 — image editing with model: ${_selectedModel!.name}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎨 Stage 1/2: Editing your photo…'),
            duration: Duration(seconds: 3),
          ),
        );
      }

      final editedImageUrl = await _replicateService.generateContent(
        modelConfig: _selectedModel!,
        prompt: widget.imagePrompt,
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
      );

      debugPrint('✅ [TwoStage] Stage 1 result: $editedImageUrl');

      // Download the edited image to a temp file for Stage 2
      final tempFile = await _downloadToTempFile(editedImageUrl);
      debugPrint('✅ [TwoStage] Temp file saved: ${tempFile.path}');

      // ── Stage 2: video generation ───────────────────────────────────────
      debugPrint(
        '🎬 [TwoStage] Stage 2 — video generation with model: ${videoModels.first.name}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🎬 Stage 2/2: Generating video…'),
            duration: Duration(seconds: 3),
          ),
        );
      }

      final videoUrl = await _replicateService.generateContent(
        modelConfig: videoModels.first,
        prompt: widget.videoPrompt,
        referenceImage:
            videoModels.first.iseditable && !_hasImagesArray(videoModels.first)
            ? tempFile
            : null,
        images:
            videoModels.first.iseditable && _hasImagesArray(videoModels.first)
            ? [tempFile]
            : null,
      );

      debugPrint('✅ [TwoStage] Final video URL: $videoUrl');

      // Deduct total credits
      await _creditService.deductCredits(totalCost);

      if (mounted) {
        setState(() {
          _selectedCategory = 'video';
          _generatedVideoUrl = videoUrl;
        });
        _initializeVideoPlayer(videoUrl);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('credit_deducted'.i18n())));
      }

      // Clean up temp file
      try {
        await tempFile.delete();
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        if (e is NsfwContentException) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('restricted_content_detected'.i18n()),
              content: Text('restricted_content_detected'.i18n()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('ok'.i18n()),
                ),
              ],
            ),
          );
        } else if (e.toString().toLowerCase().contains('timeout')) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('timeout_title'.i18n()),
              content: Text('timeout_message'.i18n()),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('ok'.i18n()),
                ),
              ],
            ),
          );
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

  Future<void> _initializeVideoPlayer(String url) async {
    try {
      final uri = Uri.parse(url);
      final controller = VideoPlayerController.networkUrl(
        uri,
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      _videoController = controller;

      await controller.initialize();

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
        await controller.setLooping(true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) controller.play();
        });

        controller.addListener(() {
          if (!mounted) return;
          final value = controller.value;
          if (value.position >= value.duration &&
              value.duration > Duration.zero) {
            controller.seekTo(Duration.zero);
            controller.play();
          }
        });
      }
    } catch (e) {
      debugPrint('Error initializing generated video player: $e');
    }
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
                    _buildHeader(
                      screenWidth,
                      screenHeight,
                      currentCredits,
                      isDark,
                    ),

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
                    _buildPromptInput(screenWidth, screenHeight, isDark),
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
                        creditCost: _selectedModel?.creditUsed ?? 0,
                        // Models
                        imageModels: _replicateService.imageModels,
                        videoModels: _replicateService.videoModels,
                        selectedModel: _selectedModel,
                        modelOptions: _selectedModel?.options,
                        selectedImage: _selectedImage,
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
                            _videoController?.pause();
                          });
                        },
                        onVideoPressed: () {
                          setState(() {
                            _selectedCategory = 'video';
                            _updateSelectedModel();
                            if (_isVideoInitialized &&
                                _videoController != null) {
                              _videoController!.play();
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),

                // Menu Overlay
                if (_showMenu)
                  _buildMenuOverlay(screenWidth, screenHeight, isDark),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    double screenWidth,
    double screenHeight,
    int currentCredits,
    bool isDark,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenHeight * 0.012,
      ),
      child: Column(
        children: [
          topBar(context, credits: currentCredits),
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
        ? _buildResultView(screenWidth)
        : _buildPlaceholder(screenWidth, screenHeight, isDark);
  }

  Widget _buildResultView(double screenWidth) {
    if (_selectedCategory == 'image') {
      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(screenWidth * 0.06),
          child: CachedNetworkImage(
            imageUrl: _generatedImageUrl!,
            width: double.infinity,
            fit: BoxFit.cover,
            placeholder: (context, url) =>
                const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) =>
                const Icon(Icons.error_outline),
          ),
        ),
      );
    } else {
      if (_isVideoInitialized && _videoController != null) {
        return Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(screenWidth * 0.06),
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
        );
      } else {
        return const Center(child: CircularProgressIndicator());
      }
    }
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
            color: AppColors.iconColor(isDark).withOpacity(0.5),
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

  Widget _buildPromptInput(
    double screenWidth,
    double screenHeight,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.04,
            vertical: screenHeight * 0.01,
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(screenWidth * 0.02),
                decoration: const ProGradientDecoration(shape: BoxShape.circle),
                child: Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: screenWidth * 0.04,
                ),
              ),
              SizedBox(width: screenWidth * 0.02),
              Text(
                'describe_content'.i18n(),
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: screenWidth * 0.038,
                  color: AppColors.textColor(isDark),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
          child: Container(
            padding: EdgeInsets.all(screenWidth * 0.03),
            decoration: BoxDecoration(
              color: AppColors.tileBackgroundColor(isDark),
              borderRadius: BorderRadius.circular(screenWidth * 0.05),
              border: Border.all(color: AppColors.creditsCardBorder(isDark)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reference image thumbnail inside the prompt box
                if (_selectedImage != null) ...[
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          screenWidth * 0.025,
                        ),
                        child: Image.file(
                          _selectedImage!,
                          height: screenWidth * 0.2,
                          width: screenWidth * 0.2,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: screenWidth * 0.005,
                        right: screenWidth * 0.005,
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedImage = null),
                          child: Container(
                            padding: EdgeInsets.all(screenWidth * 0.008),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: Colors.white,
                              size: screenWidth * 0.035,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: screenHeight * 0.01),
                ],
                TextField(
                  controller: _promptController,
                  maxLines: 4, // Increased slightly for better multiline feel
                  minLines: 1,
                  style: TextStyle(
                    color: AppColors.textColor(isDark),
                    fontSize: screenWidth * 0.04, // Slightly larger text
                  ),
                  decoration: InputDecoration(
                    hintText: 'prompt_placeholder'.i18n(),
                    hintStyle: TextStyle(
                      color: AppColors.secondaryTextColor(
                        isDark,
                      ).withOpacity(0.5),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: screenHeight * 0.01,
                      horizontal: screenWidth * 0.01,
                    ), // Better text positioning
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuOverlay(
    double screenWidth,
    double screenHeight,
    bool isDark,
  ) {
    return Positioned(
      top: screenHeight * 0.075,
      right: screenWidth * 0.04,
      child: Container(
        width: screenWidth * 0.5,
        padding: EdgeInsets.all(screenWidth * 0.04),
        decoration: BoxDecoration(
          color: AppColors.creditsCardBackground(isDark),
          borderRadius: BorderRadius.circular(screenWidth * 0.04),
          border: Border.all(color: AppColors.creditsCardBorder(isDark)),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: screenWidth * 0.025,
                offset: Offset(0, screenHeight * 0.005),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMenuItem(
              Icons.refresh,
              'recreate'.i18n(),
              screenWidth,
              isDark: isDark,
            ),
            SizedBox(height: screenHeight * 0.015),
            _buildMenuItem(
              Icons.settings,
              'use_setting'.i18n(),
              screenWidth,
              isDark: isDark,
            ),
            SizedBox(height: screenHeight * 0.015),
            _buildMenuItem(
              Icons.download,
              'download_batch'.i18n(),
              screenWidth,
              isDark: isDark,
            ),
            SizedBox(height: screenHeight * 0.015),
            _buildMenuItem(
              Icons.delete,
              'delete'.i18n(),
              screenWidth,
              isRed: true,
              isDark: isDark,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    IconData icon,
    String text,
    double screenWidth, {
    bool isRed = false,
    bool isDark = false,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          color: isRed ? Colors.red : AppColors.textColor(isDark),
          size: screenWidth * 0.045,
        ),
        SizedBox(width: screenWidth * 0.03),
        Text(
          text,
          style: TextStyle(
            color: isRed ? Colors.red : AppColors.textColor(isDark),
            fontWeight: FontWeight.w500,
            fontSize: screenWidth * 0.038,
          ),
        ),
      ],
    );
  }
}
