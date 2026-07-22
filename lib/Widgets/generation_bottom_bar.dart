import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vidzeon/Core/gradient.dart';
import 'package:vidzeon/Services/replicate_service.dart';
import 'package:vidzeon/Helpers/image_picker_helper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Bottom bar + integrated settings popup
// ─────────────────────────────────────────────────────────────────────────────

class GenerationBottomBar extends StatefulWidget {
  final bool isGenerating;
  final VoidCallback? onCreatePressed;
  final VoidCallback? onEditPressed;
  final VoidCallback? onVideoPressed;
  final VoidCallback? onImagePressed;

  /// Called when the user picks an image via the + button.
  /// Receives the [File] selected from gallery or camera.
  final ValueChanged<File>? onImageUploaded;

  /// The currently selected reference image (set via the + button).
  /// When non-null, the models panel filters to only [AIModelConfig.iseditable] models.
  final File? selectedImage;
  
  /// Determines if the current context expects multiple images.
  final int noOfUploadable;

  final String selectedCategory; // 'image' or 'video'
  final bool isAddSelected;
  final bool isSettingsSelected;
  final bool isEditSelected;
  final bool isImageSelected;
  final bool isVideoSelected;

  /// Live credit balance shown next to the flash icon
  final int currentCredits;

  /// Credits this generation will cost (from the selected model)
  final int creditCost;

  // ── Settings state (passed from GenerationPage) ──────────────────────────
  final List<AIModelConfig> imageModels;
  final List<AIModelConfig> videoModels;
  final AIModelConfig? selectedModel;
  final ModelOptions? modelOptions;
  final String selectedAspectRatio;
  final String selectedDuration;
  final String selectedResolution;
  final bool enhancePrompt;

  // ── Settings callbacks ────────────────────────────────────────────────────
  final ValueChanged<AIModelConfig> onModelSelected;
  final ValueChanged<String> onAspectRatioChanged;
  final ValueChanged<String> onDurationChanged;
  final ValueChanged<String> onResolutionChanged;
  final ValueChanged<bool> onEnhancePromptChanged;

  // ── Two-stage (Reel) mode ─────────────────────────────────────────────────
  /// When true, shows a unified model picker for both Stage 1 (image edit)
  /// and Stage 2 (video generation) in the same settings panel.
  final bool imageEditMode;
  final AIModelConfig? selectedImageModel;
  final AIModelConfig? selectedVideoModel;
  final ValueChanged<AIModelConfig>? onImageModelSelected;
  final ValueChanged<AIModelConfig>? onVideoModelSelected;

  /// When true, shows the first-visit intro animation overlay
  final bool showIntroAnimation;
  final bool showCategoryToggle;

  const GenerationBottomBar({
    super.key,
    required this.isGenerating,
    required this.currentCredits,
    required this.creditCost,
    required this.selectedCategory,
    required this.imageModels,
    required this.videoModels,
    required this.noOfUploadable,
    required this.selectedAspectRatio,
    required this.selectedDuration,
    required this.selectedResolution,
    required this.enhancePrompt,
    required this.onModelSelected,
    required this.onAspectRatioChanged,
    required this.onDurationChanged,
    required this.onResolutionChanged,
    required this.onEnhancePromptChanged,
    this.selectedModel,
    this.modelOptions,
    this.onCreatePressed,
    this.onEditPressed,
    this.onVideoPressed,
    this.onImagePressed,
    this.onImageUploaded,
    this.selectedImage,
    this.imageEditMode = false,
    this.selectedImageModel,
    this.selectedVideoModel,
    this.onImageModelSelected,
    this.onVideoModelSelected,
    this.isAddSelected = false,
    this.isSettingsSelected = false,
    this.isEditSelected = false,
    this.isImageSelected = false,
    this.isVideoSelected = false,
    this.showIntroAnimation = false,
    this.showCategoryToggle = true,
  });

  @override
  State<GenerationBottomBar> createState() => _GenerationBottomBarState();
}

class _GenerationBottomBarState extends State<GenerationBottomBar>
    with TickerProviderStateMixin {
  bool _addSelected = false;

  // Intro animation state
  int _introStep =
      0; // 0 = category, 1 = settings, 2 = add, 3 = create, 4 = done
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;
  Timer? _introTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.12,
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(_pulseController!);

    // Start pulsing if intro animation is enabled
    if (widget.showIntroAnimation) {
      _pulseController!.repeat(reverse: true);
      _startIntroTimer();
    }
  }

  void _startIntroTimer() {
    _introTimer?.cancel();
    _introTimer = Timer.periodic(const Duration(milliseconds: 2500), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_introStep >= 3) {
        t.cancel();
        setState(() => _introStep = 4); // done
        _pulseController?.stop();
      } else {
        setState(() => _introStep++);
      }
    });
  }

  String _introStepLabel() {
    switch (_introStep) {
      case 0:
        return 'Switch between Image & Video modes';
      case 1:
        return 'Adjust model & generation settings';
      case 2:
        return 'Upload a reference image (optional)';
      case 3:
        return 'Tap here to generate your content!';
      default:
        return '';
    }
  }

  @override
  void didUpdateWidget(covariant GenerationBottomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pulseController == null) return;
    if (widget.showIntroAnimation && !_pulseController!.isAnimating) {
      _pulseController!.repeat(reverse: true);
      _startIntroTimer();
    } else if (!widget.showIntroAnimation && _pulseController!.isAnimating) {
      _pulseController!.stop();
      _pulseController!.reset();
      _introTimer?.cancel();
    }
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    _pulseController?.dispose();
    super.dispose();
  }

  /// Shows a small bottom sheet for source selection, then calls the picker.
  Future<void> _pickImage() async {
    final File? croppedFile = await ImagePickerHelper.pickAndCropImage(context);

    if (croppedFile != null) {
      if (mounted) {
        setState(() => _addSelected = true);
      }
      widget.onImageUploaded?.call(croppedFile);
    }
  }

  // ── Public entry point ────────────────────────────────────────────────────
  void _openSettingsSheet() {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    String activePage = 'main';
    AIModelConfig? currentModel = widget.selectedModel;
    AIModelConfig? currentVideoModel = widget.selectedVideoModel;
    String currentAspectRatio = widget.selectedAspectRatio;
    String currentDuration = widget.selectedDuration;
    String currentResolution = widget.selectedResolution;
    bool currentEnhancePrompt = widget.enhancePrompt;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            // ── Responsive Themed Grid Card ───────────────────────────────
            Widget buildThemedGridCard({
              required String label,
              String? subLabel,
              Widget? icon,
              required bool isSelected,
              required VoidCallback onTap,
            }) {
              // Divider logic based on screenshot:
              //   If subLabel: Label -> Divider -> SubLabel
              //   If !subLabel: Icon -> Divider -> Label
              return GestureDetector(
                onTap: onTap,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1C1C1E) : Colors.white10,
                    borderRadius: BorderRadius.circular(w * 0.05),
                    border: Border.all(
                      color: isSelected
                          ? (AppGradients.proGradient.colors.isNotEmpty
                                ? AppGradients.proGradient.colors.first
                                : Colors.orange)
                          : Colors.white.withValues(alpha: 0.08),
                      width: isSelected ? w * 0.005 : w * 0.002,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (subLabel != null) ...[
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: w * 0.034,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            height: 1.1,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.visible,
                        ),
                      ] else ...[
                        if (icon != null) icon else SizedBox(height: w * 0.05),
                      ],
                      // Responsive Divider Line
                      Container(
                        width: w * 0.1,
                        height: w * 0.003,
                        color: Colors.white.withValues(alpha: 0.15),
                        margin: EdgeInsets.symmetric(vertical: w * 0.02),
                      ),
                      if (subLabel != null) ...[
                        Text(
                          subLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: w * 0.026,
                            color: Colors.white54,
                          ),
                          maxLines: 1,
                        ),
                      ] else ...[
                        Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: w * 0.038,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }

            Widget buildAspectRatioIcon(
              String ratio,
              double w,
              bool isSelected,
            ) {
              double width = w * 0.08;
              double height = w * 0.08;

              final parts = ratio.split(':');
              if (parts.length == 2) {
                final rw = double.tryParse(parts[0]) ?? 1;
                final rh = double.tryParse(parts[1]) ?? 1;
                if (rw > rh) {
                  height = width * (rh / rw);
                } else if (rh > rw) {
                  width = height * (rw / rh);
                }
              }

              return Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(w * 0.005),
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.white54,
                    width: w * 0.004,
                  ),
                ),
              );
            }

            // ── Responsive Header ──────────────────────────────────────────
            Widget buildHeader(String title, VoidCallback onBack) {
              return Padding(
                padding: EdgeInsets.only(bottom: w * 0.05),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: GestureDetector(
                        onTap: onBack,
                        child: Container(
                          padding: EdgeInsets.all(w * 0.025),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            size: w * 0.04,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: w * 0.045,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          padding: EdgeInsets.all(w * 0.025),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            size: w * 0.04,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            // ── Responsive Option Panel ─────────────────────────────────────
            Widget buildOptionPanel({
              required String title,
              required List<String> options,
              required String selectedValue,
              required ValueChanged<String> onSelected,
              String? subLabelSuffix,
            }) {
              return Column(
                children: [
                  buildHeader(title, () => setSheet(() => activePage = 'main')),
                  Expanded(
                    child: GridView.builder(
                      padding: EdgeInsets.only(
                        left: w * 0.01,
                        right: w * 0.01,
                        top: w * 0.01,
                        bottom:
                            MediaQuery.of(context).padding.bottom + w * 0.04,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: w * 0.03,
                        mainAxisSpacing: w * 0.03,
                        childAspectRatio: 1.0, // Square boxes for ratios
                      ),
                      itemCount: options.length,
                      itemBuilder: (_, i) {
                        final opt = options[i];
                        final isSelected = selectedValue == opt;
                        final isAspectRatio = title == 'Aspect Ratio';

                        return buildThemedGridCard(
                          label: opt,
                          subLabel: subLabelSuffix,
                          icon: isAspectRatio
                              ? buildAspectRatioIcon(opt, w, isSelected)
                              : null,
                          isSelected: isSelected,
                          onTap: () {
                            onSelected(opt);
                            setSheet(() => activePage = 'main');
                          },
                        );
                      },
                    ),
                  ),
                ],
              );
            }

            // Models sub-panel
            Widget buildModelsPanel() {
              // In imageEditMode (two-step), always show ALL video models
              // without the iseditable filter (video models don't have iseditable=true)
              final allModels = widget.selectedCategory == 'video'
                  ? widget.videoModels
                  : widget.imageModels;
              var models =
                  (!widget.imageEditMode &&
                          widget.selectedCategory == 'image' &&
                          widget.selectedImage != null)
                      ? allModels.where((m) => m.iseditable).toList()
                      : allModels;
                      
              if (widget.noOfUploadable > 1) {
                models = models.where((m) => m.supportsMultipleImages).toList();
              }

              return Column(
                children: [
                  buildHeader(
                    'Models',
                    () => setSheet(() => activePage = 'main'),
                  ),
                  Expanded(
                    child: models.isEmpty
                        ? Center(
                            child: Text(
                              'No models configured',
                              style: const TextStyle(color: Colors.white54),
                            ),
                          )
                        : GridView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: EdgeInsets.only(
                              left: w * 0.01,
                              right: w * 0.01,
                              top: w * 0.01,
                              bottom:
                                  MediaQuery.of(context).padding.bottom +
                                  w * 0.04,
                            ),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: w * 0.03,
                                  mainAxisSpacing: w * 0.03,
                                  childAspectRatio: 0.82,
                                ),
                            itemCount: models.length,
                            itemBuilder: (_, i) {
                              final m = models[i];
                              final isSel = widget.imageEditMode
                                  ? currentVideoModel?.id == m.id
                                  : currentModel?.id == m.id;
                              return buildThemedGridCard(
                                label: m.name,
                                subLabel: '${m.creditUsed} Credits',
                                isSelected: isSel,
                                icon: m.iconUrl != null && m.iconUrl!.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(
                                          w * 0.02,
                                        ),
                                        child: CachedNetworkImage(
                                          imageUrl: m.iconUrl!,
                                          width: w * 0.08,
                                          height: w * 0.08,
                                          fit: BoxFit.contain,
                                          errorWidget: (_, _, _) => Icon(
                                            Icons.smart_toy_outlined,
                                            size: w * 0.07,
                                            color: Colors.white54,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        Icons.smart_toy_outlined,
                                        size: w * 0.07,
                                        color: Colors.white54,
                                      ),
                                onTap: () {
                                  if (widget.imageEditMode) {
                                    widget.onVideoModelSelected?.call(m);
                                    setSheet(() {
                                      currentVideoModel = m;
                                      activePage = 'main';
                                    });
                                  } else {
                                    widget.onModelSelected(m);
                                    setSheet(() {
                                      currentModel = m;
                                      activePage = 'main';
                                    });
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              );
            }

            // Responsive Settings List Tile
            Widget buildSettingsNavigationTile({
              required IconData icon,
              required String label,
              required String value,
              required VoidCallback onTap,
            }) {
              return Padding(
                padding: EdgeInsets.only(bottom: w * 0.03),
                child: GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: w * 0.04,
                      vertical: w * 0.04,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(w * 0.04),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.05),
                        width: w * 0.002,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(icon, size: w * 0.05, color: Colors.white70),
                        SizedBox(width: w * 0.03),
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: w * 0.038,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Text(
                          value,
                          style: TextStyle(
                            fontSize: w * 0.035,
                            color: Colors.white54,
                          ),
                        ),
                        SizedBox(width: w * 0.02),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.white24,
                          size: w * 0.05,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Responsive Toggle Tile
            Widget buildToggleTile({
              required IconData icon,
              required String label,
              required bool value,
              required ValueChanged<bool> onChanged,
            }) {
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: w * 0.04,
                  vertical: w * 0.02,
                ),
                margin: EdgeInsets.only(top: w * 0.02),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(w * 0.04),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                    width: w * 0.002,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: w * 0.05, color: Colors.white70),
                    SizedBox(width: w * 0.03),
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: w * 0.038,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => onChanged(!value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 52,
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            MediaQuery.of(context).size.width * 0.04,
                          ),
                          gradient: value ? AppGradients.proGradient : null,
                          color: value
                              ? null
                              : Colors.white.withValues(alpha: 0.12),
                          border: Border.all(
                            color: value
                                ? Colors.orange.withValues(alpha: 0.4)
                                : Colors.white24,
                            width: 1.5,
                          ),
                          boxShadow: value
                              ? [
                                  BoxShadow(
                                    color: Colors.orange.withValues(
                                      alpha: 0.25,
                                    ),
                                    blurRadius: 10,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          alignment: value
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 5,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            // ── Main settings list ──────────────────────────────────────────
            Widget buildMainPanel() {
              // Gating logic: in imageEditMode, we base capabilities on the relevant stage model
              final currentOptions = widget.imageEditMode
                  ? currentVideoModel?.options
                  : currentModel?.options;

              final showAspectRatio = widget.imageEditMode
                  ? (currentVideoModel?.supportsAspectRatio == true)
                  : (currentModel?.supportsAspectRatio == true);

              return Column(
                children: [
                  Center(
                    child: Container(
                      width: w * 0.1,
                      height: w * 0.01,
                      margin: EdgeInsets.only(bottom: w * 0.06, top: w * 0.02),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(w * 0.1),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.only(
                        bottom:
                            MediaQuery.of(context).padding.bottom + w * 0.04,
                      ),
                      children: [
                        if (widget.imageEditMode) ...[
                          buildSettingsNavigationTile(
                            icon: Icons.videocam_outlined,
                            label: 'Model',
                            value: currentVideoModel?.name ?? 'Default',
                            onTap: () => setSheet(() => activePage = 'model'),
                          ),
                        ] else ...[
                          buildSettingsNavigationTile(
                            icon: Icons.view_in_ar_outlined,
                            label: 'Model',
                            value: currentModel?.name ?? 'Default',
                            onTap: () => setSheet(() => activePage = 'model'),
                          ),
                        ],
                        if (showAspectRatio)
                          buildSettingsNavigationTile(
                            icon: Icons.aspect_ratio_outlined,
                            label: 'Aspect Ratio',
                            value: currentAspectRatio,
                            onTap: () =>
                                setSheet(() => activePage = 'aspect_ratio'),
                          ),
                        if (currentOptions?.hasDurations == true)
                          buildSettingsNavigationTile(
                            icon: Icons.timer_outlined,
                            label: 'Duration',
                            value: currentDuration,
                            onTap: () =>
                                setSheet(() => activePage = 'duration'),
                          ),
                        if (currentOptions?.hasResolutions == true)
                          buildSettingsNavigationTile(
                            icon: Icons.high_quality_outlined,
                            label: 'Resolution',
                            value: currentResolution,
                            onTap: () =>
                                setSheet(() => activePage = 'resolution'),
                          ),
                        buildToggleTile(
                          icon: Icons.auto_awesome_outlined,
                          label: 'Enhance Prompt',
                          value: currentEnhancePrompt,
                          onChanged: (v) {
                            widget.onEnhancePromptChanged(v);
                            setSheet(() => currentEnhancePrompt = v);
                          },
                        ),
                        SizedBox(height: w * 0.06),
                      ],
                    ),
                  ),
                ],
              );
            }

            // Route logic
            Widget body;
            // Compute options based on current mode
            final activeOptions = widget.imageEditMode
                ? currentVideoModel?.options
                : currentModel?.options;

            final List<String> aspectRatioOptionsList =
                activeOptions?.aspectRatios ?? [];
            final aspectRatioChoicesList = aspectRatioOptionsList.isNotEmpty
                ? aspectRatioOptionsList
                : ['9:16', '1:1', '16:9', '4:3', '3:4'];

            switch (activePage) {
              case 'model':
                body = buildModelsPanel();
                break;
              case 'aspect_ratio':
                body = buildOptionPanel(
                  title: 'Aspect Ratio',
                  options: aspectRatioChoicesList,
                  selectedValue: currentAspectRatio,
                  onSelected: (v) {
                    widget.onAspectRatioChanged(v);
                    setSheet(() => currentAspectRatio = v);
                  },
                );
                break;
              case 'duration':
                body = buildOptionPanel(
                  title: 'Duration',
                  options: activeOptions?.durations ?? const ['5s', '10s'],
                  selectedValue: currentDuration,
                  onSelected: (v) {
                    widget.onDurationChanged(v);
                    setSheet(() => currentDuration = v);
                  },
                  subLabelSuffix: 'Duration',
                );
                break;
              case 'resolution':
                body = buildOptionPanel(
                  title: 'Resolution',
                  options:
                      activeOptions?.resolutions ??
                      const ['480p', '720p', '1080p'],
                  selectedValue: currentResolution,
                  onSelected: (v) {
                    widget.onResolutionChanged(v);
                    setSheet(() => currentResolution = v);
                  },
                );
                break;
              default:
                body = buildMainPanel();
            }

            return Container(
              height: h * 0.55,
              padding: EdgeInsets.fromLTRB(w * 0.04, w * 0.02, w * 0.04, 0),
              decoration: BoxDecoration(
                color: const Color(0xFF121212),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(w * 0.1),
                ),
                border: Border.all(
                  color: AppGradients.proGradient.colors.first.withValues(
                    alpha: 0.3,
                  ),
                  width: w * 0.003,
                ),
              ),
              child: body,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    // Determine if we should show the intro overlay
    final bool showIntroOverlay = widget.showIntroAnimation && _introStep < 4;

    Widget buildAddButton() => _buildIntroTarget(
      isTarget: showIntroOverlay && _introStep == 2,
      isDark: isDark,
      screenWidth: screenWidth,
      child: _buildIcon(
        context,
        Icons.add_photo_alternate_outlined,
        isSelected: _addSelected,
        onTap: _pickImage,
        size: screenWidth * 0.07,
      ),
    );

    Widget buildSettingsButton() => _buildIntroTarget(
      isTarget: showIntroOverlay && _introStep == 1,
      isDark: isDark,
      screenWidth: screenWidth,
      child: GestureDetector(
        onTap: _openSettingsSheet,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.03,
            vertical: screenHeight * 0.012,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(screenWidth * 0.06),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Model: ${widget.imageEditMode ? (widget.selectedVideoModel?.name ?? 'Select') : (widget.selectedModel?.name ?? 'Select')}',
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: screenWidth * 0.032,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: screenWidth * 0.01),
              Icon(
                Icons.keyboard_arrow_down,
                color: isDark ? Colors.white : Colors.black87,
                size: screenWidth * 0.045,
              ),
            ],
          ),
        ),
      ),
    );

    Widget buildCreateButton() => _buildIntroTarget(
      isTarget: showIntroOverlay && _introStep == 3,
      isDark: isDark,
      screenWidth: screenWidth,
      isCreateButton: true,
      child: GestureDetector(
        onTap: widget.isGenerating ? null : widget.onCreatePressed,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: widget.isGenerating ? 0.6 : 1.0,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.09,
              vertical: screenHeight * 0.012,
            ),
            decoration: ProGradientDecoration(
              borderRadius: BorderRadius.circular(screenWidth * 0.06),
              boxShadow: [
                BoxShadow(
                  color: AppGradients.proGradient.colors.first.withValues(
                    alpha: 0.3,
                  ),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isGenerating) ...[
                  SizedBox(
                    width: screenWidth * 0.045,
                    height: screenWidth * 0.045,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.02),
                ],
                Text(
                  widget.isGenerating ? 'Creating...' : 'Create',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: screenWidth * 0.04,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final bottomBar = Container(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.only(
        left: screenWidth * 0.04,
        right: screenWidth * 0.04,
        top: isKeyboardOpen ? screenHeight * 0.012 : screenHeight * 0.02,
        bottom: isKeyboardOpen
            ? 0
            : MediaQuery.of(context).padding.bottom + screenHeight * 0.03,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE5E5EA),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(
            screenWidth * (isKeyboardOpen ? 0.04 : 0.06),
          ),
          topRight: Radius.circular(
            screenWidth * (isKeyboardOpen ? 0.04 : 0.06),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [buildSettingsButton()]),
            ),
          ),
          SizedBox(width: screenWidth * 0.03),
          buildCreateButton(),
        ],
      ),
    );

    if (!showIntroOverlay) return bottomBar;

    // Show tooltip above bar with current step label
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Tooltip callout
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: Container(
            key: ValueKey(_introStep),
            margin: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.06,
              vertical: screenHeight * 0.008,
            ),
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenHeight * 0.012,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6A00),
              borderRadius: BorderRadius.circular(screenWidth * 0.04),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6A00).withOpacity(0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  Icons.touch_app_rounded,
                  color: Colors.white,
                  size: screenWidth * 0.045,
                ),
                SizedBox(width: screenWidth * 0.025),
                Expanded(
                  child: Text(
                    _introStepLabel(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: screenWidth * 0.034,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                // Step dots
                Row(
                  children: List.generate(
                    4,
                    (i) => Container(
                      margin: EdgeInsets.only(left: screenWidth * 0.01),
                      width: screenWidth * 0.018,
                      height: screenWidth * 0.018,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i == _introStep
                            ? Colors.white
                            : Colors.white.withOpacity(0.4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        bottomBar,
      ],
    );
  }

  /// Builds a widget with intro animation highlight (pulsing glow border)
  Widget _buildIntroTarget({
    required bool isTarget,
    required Widget child,
    bool isCreateButton = false,
    bool isDark = false,
    double screenWidth = 0,
  }) {
    if (!isTarget || _pulseAnimation == null) {
      return child;
    }

    return AnimatedBuilder(
      animation: _pulseAnimation!,
      builder: (context, innerChild) {
        return Transform.scale(
          scale: _pulseAnimation!.value,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: isCreateButton
                  ? BorderRadius.circular(screenWidth * 0.06)
                  : BorderRadius.circular(screenWidth * 0.08),
              border: Border.all(color: const Color(0xFFFF6A00), width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6A00).withOpacity(0.5),
                  blurRadius: 16,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: innerChild,
          ),
        );
      },
      child: child,
    );
  }
}

Widget _buildIcon(
  BuildContext context,
  IconData icon, {
  bool isSelected = false,
  VoidCallback? onTap,
  double? size,
}) {
  final w = MediaQuery.of(context).size.width;
  final bool isDark = Theme.of(context).brightness == Brightness.dark;
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.all(w * 0.02),
      decoration: BoxDecoration(
        color: isSelected
            ? (isDark
                  ? const Color.fromRGBO(255, 255, 255, 0.45)
                  : Colors.black26)
            : (isDark
                  ? const Color.fromRGBO(255, 255, 255, 0.2)
                  : Colors.black12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: isSelected
            ? (isDark ? Colors.white : Colors.black)
            : (isDark ? Colors.white : Colors.black87),
        size: size ?? (w * 0.05),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widget: image source tile (Gallery / Camera)
// ─────────────────────────────────────────────────────────────────────────────
