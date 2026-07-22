import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vidzeon/Widgets/collage_grid.dart';
import 'package:image_collage_widget/utils/collage_type.dart';
import 'package:vidzeon/Core/colors.dart';
import 'package:vidzeon/Core/gradient.dart';

import 'package:vidzeon/Services/credit_service.dart';
import 'package:vidzeon/Models/collage_template.dart';

import 'package:vidzeon/pages/ai_loading_screen.dart';
import 'package:vidzeon/pages/ai_result_screen.dart';
import '../Services/collage_bloc.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/rendering.dart';

// ─────────────────────────────────────────────
// Entry point – injects the BLoC
// ─────────────────────────────────────────────

class AiCollagePage extends StatelessWidget {
  const AiCollagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CollageBloc(creditService: CreditService()),
      child: const _AiCollageView(),
    );
  }
}

// ─────────────────────────────────────────────
// Internal view – consumes the BLoC
// ─────────────────────────────────────────────

class _AiCollageView extends StatefulWidget {
  const _AiCollageView();

  @override
  State<_AiCollageView> createState() => _AiCollageViewState();
}

class _AiCollageViewState extends State<_AiCollageView>
    with SingleTickerProviderStateMixin {
  /// A GlobalKey lets us capture the [RepaintBoundary] as an image.
  final GlobalKey _collageKey = GlobalKey();

  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  /// Maps template index → [CollageTemplate] for the template strip.
  final List<CollageTemplate> _templates = [
    CollageTemplate(
      type: CollageType.vSplit,
      icon: 'assets/icons/Newest Button.png',
      mask: 'assets/masks/mask_v_split.png',
      jsonPath: 'assets/masks/mask_v_split.json',
    ),
    CollageTemplate(
      type: CollageType.fourSquare,
      icon: 'assets/icons/Newest Button-1.png',
      mask: 'assets/masks/mask_4_square.png',
      jsonPath: 'assets/masks/mask_4_square.json',
    ),
    CollageTemplate(
      type: CollageType.threeVertical,
      icon: 'assets/icons/Newest Button-2.png',
      mask: 'assets/masks/mask_3_left_big.png',
      jsonPath: 'assets/masks/mask_3_left_big.json',
    ),
    CollageTemplate(
      type: CollageType.rightBig,
      icon: 'assets/icons/Newest Button-3.png',
      mask: 'assets/masks/mask_6_right_big.png',
      jsonPath: 'assets/masks/mask_6_right_big.json',
    ),
    CollageTemplate(
      type: CollageType.leftBig,
      icon: 'assets/icons/Newest Button-4.png',
      mask: 'assets/masks/mask_6_left_big.png',
      jsonPath: 'assets/masks/mask_6_left_big.json',
    ),
    CollageTemplate(
      type: CollageType.fourLeftBig,
      icon: 'assets/icons/Newest Button-5.png',
      mask: 'assets/masks/mask_4_left_big.png',
      jsonPath: 'assets/masks/mask_4_left_big.json',
    ),
    CollageTemplate(
      type: CollageType.vMiddleTwo,
      icon: 'assets/icons/Newest Button-6.png',
      mask: 'assets/masks/mask_7_mixed.png',
      jsonPath: 'assets/masks/mask_7_mixed.json',
    ),
    CollageTemplate(
      type: CollageType.nineSquare,
      icon: 'assets/icons/Newest Button-7.png',
      mask: 'assets/masks/mask_9_square.png',
      jsonPath: 'assets/masks/mask_9_square.json',
    ),
  ];

  // ── lifecycle ─────────────────────────────

  @override
  void initState() {
    super.initState();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 0.92).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
    );

    // Load JSON slot paths then initialize BLoC
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.wait(_templates.map((t) => t.loadSlots()));
      if (mounted) {
        context.read<CollageBloc>().add(const CollageInit());
        setState(() {}); // refresh after slots are loaded
      }
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  // ── helpers ───────────────────────────────

  Future<void> _triggerSave() async {
    // Instruct the collage widget to save/export its current image.
    final path = await _captureCollage();
    if (path != null && mounted) {
      context.read<CollageBloc>().add(CollageRendered(path));
    } else if (mounted) {
      context.read<CollageBloc>().add(CollageReset());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save collage. Try again.')),
      );
    }
  }

  Future<String?> _captureCollage() async {
    try {
      final boundary =
          _collageKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) return null;

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final String path =
          '${directory.path}/collage_${DateTime.now().millisecondsSinceEpoch}.png';
      final File file = File(path);
      await file.writeAsBytes(pngBytes);

      return path;
    } catch (e) {
      debugPrint("Error capturing collage: $e");
      return null;
    }
  }

  // ── build ─────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<CollageBloc, CollageState>(
      listenWhen: (_, current) =>
          current is CollageRendering ||
          current is CollageResult ||
          current is CollageError,
      listener: (context, state) async {
        if (state is CollageRendering) {
          _progressController.forward(from: 0);
          // Briefly wait for loading screen to mount and UI to stabilize.
          await Future.delayed(const Duration(milliseconds: 500));
          if (context.mounted) {
            await _triggerSave();
          }
        }
        if (state is CollageResult) {
          _progressController.stop();
        }
        if (state is CollageError) {
          _progressController.stop();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error${state.message}')),
            );
          }
        }
      },
      builder: (context, state) {
        final selectedType = state is CollageSelecting
            ? state.selectedType
            : state is CollageCheckingGate
            ? state.selectedType
            : state is CollageRendering
            ? state.selectedType
            : CollageType.vSplit;

        return Scaffold(
          backgroundColor: AppColors.backgroundColor(isDark),
          body: SafeArea(
            child: Column(
              children: [
                // ── Global credits top-bar ──
                SizedBox(height: MediaQuery.of(context).size.height * 0.015),

                // ── Page-level top bar ──
                _TopBar(
                  isDark: isDark,
                  state: state,
                  imageCount: state is CollageSelecting
                      ? state.imageCount
                      : CollageBloc.getImageCount(selectedType),
                  onBack: () {
                    if (state is CollageResult || state is CollageRendering) {
                      context.read<CollageBloc>().add(const CollageReset());
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.01),

                // ── Body ──
                Expanded(
                  child: Stack(
                    children: [
                      // 1. Selection Grid (Always in tree for screenshotting)
                      _buildSelectionBody(context, state, isDark, selectedType),

                      // 2. Loading Overlay
                      if (state is CollageCheckingGate ||
                          state is CollageRendering)
                        Container(
                          color: AppColors.backgroundColor(isDark),
                          child: AILoadingScreen(
                            selectedImage: state is CollageCheckingGate
                                ? state.selectedImages.firstWhere(
                                    (f) => f != null,
                                    orElse: () => null,
                                  )
                                : state is CollageRendering
                                ? state.selectedImages.firstWhere(
                                    (f) => f != null,
                                    orElse: () => null,
                                  )
                                : null,
                            progressAnimation: _progressAnimation,
                            onCancel: () {
                              _progressController.stop();
                              context.read<CollageBloc>().add(
                                const CollageReset(),
                              );
                            },
                            aiTips: [
                              'Use a mix of Photos',
                              'Face clearly visible.',
                              'Include diverse scenes',
                            ],
                            processingTitle: 'processing_photos',
                            applyingText: 'uploading_photo',
                            waitText: 'checking_image_quality',
                          ),
                        ),

                      // 3. Result Overlay
                      if (state is CollageResult)
                        Positioned.fill(
                          child: Container(
                            color: AppColors.backgroundColor(isDark),
                            child: AIResultScreen(
                              originalImage: null,
                              resultImageUrl: state.imagePath,
                              onReEdit: () => context.read<CollageBloc>().add(
                                const CollageReset(),
                              ),
                              onTryAgain: () => context.read<CollageBloc>().add(
                                const CollageReset(),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectionBody(
    BuildContext context,
    CollageState state,
    bool isDark,
    CollageType selectedType,
  ) {
    final isProcessing =
        state is CollageCheckingGate || state is CollageRendering;
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: w * 0.04),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: h * 0.02),

            // ── Collage widget ──
            ClipRRect(
              borderRadius: BorderRadius.circular(w * 0.06),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: RepaintBoundary(
                  key: _collageKey,
                  child:
                      _templates
                          .firstWhere((t) => t.type == selectedType)
                          .slots
                          .isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : CollageGrid(
                          template: _templates.firstWhere(
                            (t) => t.type == selectedType,
                          ),
                          isExporting: state is CollageRendering,
                          selectedImages: state is CollageSelecting
                              ? state.imagesForCurrentTemplate
                              : state is CollageCheckingGate
                              ? state.selectedImages
                              : state is CollageRendering
                              ? state.selectedImages
                              : [],
                          onImagePicked: (index, file) {
                            context.read<CollageBloc>().add(
                              CollageImagePicked(index, file),
                            );
                          },
                        ),
                ),
              ),
            ),

            SizedBox(height: h * 0.025),

            // ── Template strip ─────────────────────────────────────────
            Text(
              'Suggested Templates:',
              style: TextStyle(
                fontSize: w * 0.04,
                fontWeight: FontWeight.bold,
                color: AppColors.textColor(isDark),
              ),
            ),
            SizedBox(height: h * 0.012),
            SizedBox(
              height: w * 0.18,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _templates.length,
                separatorBuilder: (_, _) => SizedBox(width: w * 0.03),
                itemBuilder: (_, i) {
                  final t = _templates[i];
                  final isSelected = selectedType == t.type;
                  return GestureDetector(
                    onTap: isProcessing
                        ? null
                        : () => context.read<CollageBloc>().add(
                            CollageTypeSelected(t.type, t.imageCount),
                          ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: w * 0.18,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(w * 0.04),
                        border: Border.all(
                          color: isSelected
                              ? Colors.orange
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(w * 0.04 - 2.5),
                        child: Image.asset(
                          t.icon,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: isDark
                                    ? Colors.grey[900]
                                    : Colors.grey[100],
                                child: Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    size: w * 0.1,
                                    color: isSelected
                                        ? Colors.orange
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            SizedBox(height: h * 0.025),

            Center(
              child: Text(
                'Estimated processing time 5-10 seconds',
                style: TextStyle(
                  fontSize: w * 0.03,
                  color: AppColors.secondaryTextColor(isDark),
                ),
              ),
            ),

            SizedBox(height: h * 0.018),

            // ── Generate button ────────────────────────────────────────
            GestureDetector(
              onTap: isProcessing
                  ? null
                  : () {
                      if (state is CollageSelecting && !state.canGenerate) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please add at least one image to the collage first',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      context.read<CollageBloc>().add(
                        CollageGenerateRequested(context),
                      );
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: h * 0.02),
                decoration: ProGradientDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(w * 0.08)),
                ).copyWith(color: isProcessing ? Colors.grey.shade600 : null),
                child: Center(
                  child: isProcessing
                      ? SizedBox(
                          width: w * 0.06,
                          height: w * 0.06,
                          child: CircularProgressIndicator(
                            strokeWidth: w * 0.005,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'Save Collage',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: w * 0.046,
                          ),
                        ),
                ),
              ),
            ),

            SizedBox(height: h * 0.04),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Top-bar widget
// ─────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final bool isDark;
  final CollageState state;
  final VoidCallback onBack;
  final int? imageCount;

  const _TopBar({
    required this.isDark,
    required this.state,
    required this.onBack,
    this.imageCount,
  });

  String get _subtitle {
    if (state is CollageCheckingGate || state is CollageRendering) {
      return 'Processing Photos';
    }
    if (state is CollageResult) return 'Check the result';
    if (imageCount != null) {
      return '$imageCount images';
    }
    return 'Create stunning photo collages\nwith AI';
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: sw * 0.04, vertical: sh * 0.01),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _CircleBtn(
            isDark: isDark,
            icon: Icons.arrow_back_ios_new,
            onTap: onBack,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Pic Collage',
                  style: TextStyle(
                    fontSize: sw * 0.048,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor(isDark),
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  _subtitle,
                  style: TextStyle(
                    fontSize: sw * 0.032,
                    color: AppColors.secondaryTextColor(isDark),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _CircleBtn(
            isDark: isDark,
            icon: Icons.close,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final bool isDark;
  final IconData icon;
  final VoidCallback onTap;

  const _CircleBtn({
    required this.isDark,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(sw * 0.022),
        decoration: BoxDecoration(
          color: AppColors.tileBackgroundColor(isDark),
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.creditsCardBorder(isDark).withValues(alpha: 0.4),
          ),
        ),
        child: Icon(icon, size: sw * 0.045, color: AppColors.textColor(isDark)),
      ),
    );
  }
}
