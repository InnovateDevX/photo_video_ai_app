import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:trail_ai_app/Core/colors.dart';
import 'package:trail_ai_app/Core/gradient.dart';
import 'package:localization/localization.dart';
import 'package:trail_ai_app/Services/replicate_service.dart';
import 'package:trail_ai_app/Helpers/image_picker_helper.dart';

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

  const GenerationBottomBar({
    super.key,
    required this.isGenerating,
    required this.currentCredits,
    required this.creditCost,
    required this.selectedCategory,
    required this.imageModels,
    required this.videoModels,
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
  });

  @override
  State<GenerationBottomBar> createState() => _GenerationBottomBarState();
}

class _GenerationBottomBarState extends State<GenerationBottomBar> {
  // ── Colors that match the bar ─────────────────────────────────────────────
  static const _sheetBg = Color.fromRGBO(0, 0, 0, 0.45);
  static Color _cardBg(bool isDark) => isDark
      ? const Color.fromRGBO(40, 40, 40, 0.95)
      : const Color.fromRGBO(255, 255, 255, 0.95);
  static const _pillBg = Color.fromRGBO(255, 255, 255, 0.12);
  static Color _selectedCell(bool isDark) => isDark
      ? const Color.fromRGBO(80, 80, 80, 1.0)
      : const Color.fromRGBO(230, 230, 230, 1.0);

  bool _addSelected = false;

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
                          : Colors.white.withOpacity(0.08),
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
                        color: Colors.white.withOpacity(0.15),
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
                            color: Colors.white.withOpacity(0.08),
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
                            color: Colors.white.withOpacity(0.08),
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
                      padding: EdgeInsets.all(w * 0.01),
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
                        final isAspectRatio = title == 'aspect_ratio'.i18n();

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
              if (widget.imageEditMode) {
                // Unified panel: Stage 1 (Image Edit) + Stage 2 (Video)
                return Column(
                  children: [
                    buildHeader(
                      'Models',
                      () => setSheet(() => activePage = 'main'),
                    ),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          // Stage 1 label
                          Padding(
                            padding: EdgeInsets.only(
                              bottom: w * 0.02,
                              top: w * 0.01,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: w * 0.03,
                                    vertical: w * 0.012,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFFF9800,
                                    ).withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(
                                      w * 0.03,
                                    ),
                                  ),
                                  child: Text(
                                    'Stage 1 — Image Edit',
                                    style: TextStyle(
                                      color: const Color(0xFFFF9800),
                                      fontWeight: FontWeight.bold,
                                      fontSize: w * 0.033,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.only(bottom: w * 0.04),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: w * 0.03,
                                  mainAxisSpacing: w * 0.03,
                                  childAspectRatio: 0.82,
                                ),
                            itemCount: widget.imageModels.length,
                            itemBuilder: (_, i) {
                              final m = widget.imageModels[i];
                              final isSel =
                                  widget.selectedImageModel?.id == m.id;
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
                                  widget.onImageModelSelected?.call(m);
                                  setSheet(() => activePage = 'main');
                                },
                              );
                            },
                          ),
                          // Stage 2 label
                          Padding(
                            padding: EdgeInsets.only(bottom: w * 0.02),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: w * 0.03,
                                    vertical: w * 0.012,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(
                                      w * 0.03,
                                    ),
                                  ),
                                  child: Text(
                                    'Stage 2 — Video Generation',
                                    style: TextStyle(
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: w * 0.033,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.zero,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: w * 0.03,
                                  mainAxisSpacing: w * 0.03,
                                  childAspectRatio: 0.82,
                                ),
                            itemCount: widget.videoModels.length,
                            itemBuilder: (_, i) {
                              final m = widget.videoModels[i];
                              final isSel =
                                  widget.selectedVideoModel?.id == m.id;
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
                                  widget.onVideoModelSelected?.call(m);
                                  setSheet(() => activePage = 'main');
                                },
                              );
                            },
                          ),
                          SizedBox(height: w * 0.04),
                        ],
                      ),
                    ),
                  ],
                );
              }

              // Standard single-category model list
              final allModels = widget.selectedCategory == 'video'
                  ? widget.videoModels
                  : widget.imageModels;
              final models = widget.selectedImage != null
                  ? allModels.where((m) => m.iseditable).toList()
                  : allModels;

              return Column(
                children: [
                  buildHeader(
                    'models'.i18n(),
                    () => setSheet(() => activePage = 'main'),
                  ),
                  Expanded(
                    child: models.isEmpty
                        ? Center(
                            child: Text(
                              'no_models_configured'.i18n(),
                              style: const TextStyle(color: Colors.white54),
                            ),
                          )
                        : GridView.builder(
                            padding: EdgeInsets.all(w * 0.01),
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
                              final isSel = widget.selectedModel?.id == m.id;
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
                                  widget.onModelSelected(m);
                                  setSheet(() => activePage = 'main');
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
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(w * 0.04),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.05),
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
                  vertical: w * 0.005,
                ),
                margin: EdgeInsets.only(top: w * 0.02),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(w * 0.04),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.05),
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
                    Switch(
                      value: value,
                      onChanged: onChanged,
                      activeThumbColor: Colors.white,
                      activeTrackColor: AppGradients.proGradient.colors.first,
                    ),
                  ],
                ),
              );
            }

            // ── Main settings list ──────────────────────────────────────────
            Widget buildMainPanel() {
              // Gating logic: in imageEditMode, we base capabilities on the relevant stage model
              final currentOptions = widget.imageEditMode
                  ? widget.selectedVideoModel?.options
                  : widget.modelOptions;

              final List<String> aspectRatioOptions =
                  currentOptions?.aspectRatios ?? [];
              final showAspectRatio = currentOptions?.hasAspectRatios == true;

              final aspectRatioChoices = aspectRatioOptions.isNotEmpty
                  ? aspectRatioOptions
                  : ['9:16', '1:1', '16:9', '4:3', '3:4'];

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
                      padding: EdgeInsets.zero,
                      children: [
                        buildSettingsNavigationTile(
                          icon: Icons.view_in_ar_outlined,
                          label: widget.imageEditMode
                              ? 'Stage 1 — Image Model'
                              : 'model'.i18n(),
                          value: widget.imageEditMode
                              ? (widget.selectedImageModel?.name ?? 'Default')
                              : (widget.selectedModel?.name ?? 'Default'),
                          onTap: () => setSheet(() => activePage = 'model'),
                        ),
                        if (widget.imageEditMode)
                          buildSettingsNavigationTile(
                            icon: Icons.videocam_outlined,
                            label: 'Stage 2 — Video Model',
                            value: widget.selectedVideoModel?.name ?? 'Default',
                            onTap: () => setSheet(() => activePage = 'model'),
                          ),
                        if (showAspectRatio)
                          buildSettingsNavigationTile(
                            icon: Icons.aspect_ratio_outlined,
                            label: 'aspect_ratio'.i18n(),
                            value: widget.selectedAspectRatio,
                            onTap: () =>
                                setSheet(() => activePage = 'aspect_ratio'),
                          ),
                        if (currentOptions?.hasDurations == true)
                          buildSettingsNavigationTile(
                            icon: Icons.timer_outlined,
                            label: 'duration'.i18n(),
                            value: widget.selectedDuration,
                            onTap: () =>
                                setSheet(() => activePage = 'duration'),
                          ),
                        if (currentOptions?.hasResolutions == true)
                          buildSettingsNavigationTile(
                            icon: Icons.high_quality_outlined,
                            label: 'resolution'.i18n(),
                            value: widget.selectedResolution,
                            onTap: () =>
                                setSheet(() => activePage = 'resolution'),
                          ),
                        buildToggleTile(
                          icon: Icons.auto_awesome_outlined,
                          label: 'enhance_prompt'.i18n(),
                          value: widget.enhancePrompt,
                          onChanged: widget.onEnhancePromptChanged,
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
                ? widget.selectedVideoModel?.options
                : widget.modelOptions;

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
                  title: 'aspect_ratio'.i18n(),
                  options: aspectRatioChoicesList,
                  selectedValue: widget.selectedAspectRatio,
                  onSelected: widget.onAspectRatioChanged,
                );
                break;
              case 'duration':
                body = buildOptionPanel(
                  title: 'duration'.i18n(),
                  options: activeOptions?.durations ?? const ['5s', '10s'],
                  selectedValue: widget.selectedDuration,
                  onSelected: widget.onDurationChanged,
                  subLabelSuffix: 'Duration',
                );
                break;
              case 'resolution':
                body = buildOptionPanel(
                  title: 'resolution'.i18n(),
                  options:
                      activeOptions?.resolutions ??
                      const ['480p', '720p', '1080p'],
                  selectedValue: widget.selectedResolution,
                  onSelected: widget.onResolutionChanged,
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
                  color: AppGradients.proGradient.colors.first.withOpacity(0.3),
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

    return Container(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.only(
        left: screenWidth * 0.04,
        right: screenWidth * 0.04,
        top: isKeyboardOpen ? screenHeight * 0.012 : screenHeight * 0.02,
        bottom: isKeyboardOpen
            ? 0 // Sitting flush against the keyboard
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
          // Left icons - Wrapped in Expanded + SingleChildScrollView to prevent overflow
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildIcon(
                    context,
                    Icons.add,
                    isSelected: _addSelected,
                    onTap: _pickImage,
                  ),
                  SizedBox(width: screenWidth * 0.02),
                  _buildIcon(
                    context,
                    Icons.tune,
                    isSelected: widget.isSettingsSelected,
                    onTap: _openSettingsSheet,
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  // Video / Image pill
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(screenWidth * 0.06),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCategoryIcon(
                          icon: Icons.videocam,
                          isSelected: widget.isVideoSelected,
                          onTap: widget.onVideoPressed,
                          screenWidth: screenWidth,
                        ),
                        _buildCategoryIcon(
                          icon: Icons.photo_outlined,
                          isSelected: widget.isImageSelected,
                          onTap: widget.onImagePressed,
                          screenWidth: screenWidth,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: screenWidth * 0.03),
          // Create button
          GestureDetector(
            onTap: widget.isGenerating ? null : widget.onCreatePressed,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: widget.isGenerating ? 0.6 : 1.0,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.05,
                  vertical: screenHeight * 0.012,
                ),
                decoration: ProGradientDecoration(
                  borderRadius: BorderRadius.circular(screenWidth * 0.06),
                  boxShadow: [
                    BoxShadow(
                      color: AppGradients.proGradient.colors.first.withOpacity(
                        0.3,
                      ),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.isGenerating ? 'creating'.i18n() : 'create'.i18n(),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: screenWidth * 0.04,
                      ),
                    ),
                    if (!widget.isGenerating) ...[
                      SizedBox(width: screenWidth * 0.02),
                      Icon(
                        Icons.flash_on,
                        color: Colors.yellowAccent,
                        size: screenWidth * 0.045,
                      ),
                      Text(
                        '${widget.creditCost}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth * 0.04,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryIcon({
    required IconData icon,
    required bool isSelected,
    required VoidCallback? onTap,
    required double screenWidth,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.all(screenWidth * 0.02),
        decoration: isSelected
            ? ProGradientDecoration(
                borderRadius: BorderRadius.circular(screenWidth * 0.05),
              )
            : const BoxDecoration(shape: BoxShape.circle),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.white54,
          size: screenWidth * 0.045,
        ),
      ),
    );
  }
}

Widget _buildIcon(
  BuildContext context,
  IconData icon, {
  bool isSelected = false,
  VoidCallback? onTap,
}) {
  final w = MediaQuery.of(context).size.width;
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: EdgeInsets.all(w * 0.02),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color.fromRGBO(255, 255, 255, 0.45)
            : const Color.fromRGBO(255, 255, 255, 0.2),
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: Colors.white,
        size: w * 0.05,
      ), // Reduced from 0.06
    ),
  );
}


// ─────────────────────────────────────────────────────────────────────────────
// Helper widget: image source tile (Gallery / Camera)
// ─────────────────────────────────────────────────────────────────────────────


