import 'dart:io';
import 'package:flutter/material.dart';
import 'package:vidzeon/Widgets/themed_dialog.dart';
import 'package:vidzeon/Core/colors.dart';
import 'package:vidzeon/Core/strings.dart'; // non-translatable
import 'package:vidzeon/Core/gradient.dart';
import 'package:vidzeon/Helpers/image_picker_helper.dart';
import 'package:vidzeon/Services/replicate_service.dart';
import 'package:vidzeon/Services/credit_service.dart';
import 'package:vidzeon/Services/generation_gate.dart';
import 'package:vidzeon/Services/media_service.dart';
import 'package:vidzeon/pages/ai_loading_screen.dart';
import 'package:vidzeon/pages/ai_result_screen.dart';
import 'package:vidzeon/Services/content_safety_service.dart';
import 'package:vidzeon/Helpers/error_dialog_helper.dart';

import 'package:vidzeon/Widgets/cancel_dialog.dart';
import 'package:vidzeon/Widgets/ai_suggestion_box.dart';

enum _PageState { selection, loading, result }

class AiBackgroundPage extends StatefulWidget {
  final String? initialImageUrl;
  const AiBackgroundPage({super.key, this.initialImageUrl});

  @override
  State<AiBackgroundPage> createState() => _AiBackgroundPageState();
}

class _AiBackgroundPageState extends State<AiBackgroundPage>
    with SingleTickerProviderStateMixin {
  File? _selectedImage;
  String _selectedStyle = 'Blur'; // 'Blur' or 'Remove'
  bool _isLoadingInitial = false;

  final ReplicateService _replicateService = ReplicateService();

  final CreditService _creditService = CreditService();

  _PageState _pageState = _PageState.selection;
  String? _generatedImageUrl;
  bool _isCancelled = false;

  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _initializeService();

    if (widget.initialImageUrl != null) {
      _selectedStyle = 'Remove';
      _loadInitialImage(widget.initialImageUrl!);
    }

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 45),
    );
    _progressAnimation = Tween<double>(begin: 0.0, end: 0.92).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    await _replicateService.initialize();
    await _creditService.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _loadInitialImage(String url) async {
    setState(() => _isLoadingInitial = true);
    final file = await MediaService.getCachedOrDownloadFile(url);
    if (file != null && mounted) {
      setState(() {
        _selectedImage = file;
        _isLoadingInitial = false;
      });
    } else if (mounted) {
      setState(() => _isLoadingInitial = false);
    }
  }

  Future<void> _pickImage() async {
    final File? croppedFile = await ImagePickerHelper.pickAndCropImage(context);
    if (croppedFile != null && mounted) {
      setState(() {
        _selectedImage = croppedFile;
        _generatedImageUrl = null;
        _pageState = _PageState.selection;
      });
    }
  }

  Future<void> _generateBackground() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Choose image')));
      return;
    }

    final model = _selectedStyle == 'Blur'
        ? _replicateService.blurBgModel
        : _replicateService.removeBgModel;
    if (model == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No model selected or available')));
      return;
    }

    setState(() => _pageState = _PageState.loading);
    _progressController.forward(from: 0);

    final canProceed = await GenerationGate.check(
      context: context,
      creditService: _creditService,
      creditCost: model.creditUsed,
    );
    if (!canProceed) {
      _progressController.stop();
      if (mounted) setState(() => _pageState = _PageState.selection);
      return;
    }

    try {
      _isCancelled = false;
      final url = await _replicateService.generateContent(
        modelConfig: model,
        prompt: _selectedStyle == 'Blur'
            ? 'blur background'
            : 'remove background, clean cutout',
        referenceImage: _selectedImage,
      );

      await _creditService.deductCredits(model.creditUsed);
      if (mounted) {
        showThemedDialog(
          context,
          title: 'Success',
          message: 'Credits deducted',
          icon: Icons.check_circle_outline,
          iconColor: Colors.green,
        );
      }

      if (mounted) {
        _progressController.stop();
        setState(() {
          _generatedImageUrl = url;
          _pageState = _PageState.result;
        });
      }
    } catch (e) {
      if (mounted) {
        _progressController.stop();
        setState(() => _pageState = _PageState.selection);

        if (_isCancelled) {
          _isCancelled = false;
          return;
        }

        if (e is NsfwContentException) {
          ErrorDialogHelper.showRestrictedContentDialog(
            context,
            messageKey: e.messageKey,
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error${e.toString()}')));
        }
      }
    }
  }

  Future<void> _showCancelWarningDialog() async {
    final shouldCancel = await showCancelDialog(context);
    if (shouldCancel && mounted) {
      _replicateService.cancelActivePrediction();
      _progressController.stop();
      setState(() {
        _pageState = _PageState.selection;
        _isCancelled = true;
      });
    }
  }

  Widget _buildTopBar({
    required bool isDark,
    required String title,
    required String subtitle,
    VoidCallback? onBack,
  }) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: sw * 0.04, vertical: sh * 0.01),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _circleBtn(
            isDark: isDark,
            icon: Icons.arrow_back_ios_new,
            onTap: onBack ?? () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: sw * 0.048,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor(isDark),
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: sw * 0.032,
                    color: AppColors.secondaryTextColor(isDark),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          _circleBtn(
            isDark: isDark,
            icon: Icons.close,
            onTap: _pageState == _PageState.loading
                ? _showCancelWarningDialog
                : () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _circleBtn({
    required bool isDark,
    required IconData icon,
    required VoidCallback onTap,
  }) {
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

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (_pageState == _PageState.result && _generatedImageUrl != null) {
      return AIResultScreen(
        originalImage: _selectedImage,
        resultImageUrl: _generatedImageUrl!,
        onReEdit: () => setState(() => _pageState = _PageState.selection),
        onTryAgain: () {
          setState(() => _pageState = _PageState.selection);
          Future.delayed(
            const Duration(milliseconds: 100),
            _generateBackground,
          );
        },
        onBack: () => setState(() => _pageState = _PageState.selection),
      );
    }

    return PopScope(
      canPop: _pageState != _PageState.loading,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_pageState == _PageState.loading) {
          _showCancelWarningDialog();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor(isDark),
        body: SafeArea(
          child: Column(
            children: [
              _buildTopBar(
                isDark: isDark,
                title: 'Background AI',
                subtitle: switch (_pageState) {
                  _PageState.loading => 'Processing Photo',
                  _PageState.result => 'Check the Result',
                  _PageState.selection =>
                    'Blur Background', // Or key 'blur_background'
                },
                onBack: switch (_pageState) {
                  _PageState.loading => _showCancelWarningDialog,
                  _PageState.result => () => setState(
                    () => _pageState = _PageState.selection,
                  ),
                  _PageState.selection => null,
                },
              ),
              Expanded(
                child: switch (_pageState) {
                  _PageState.loading => AILoadingScreen(
                    selectedImage: _selectedImage,
                    progressAnimation: _progressAnimation,
                    aiTips: AppStrings.outfitAiTips,
                    processingTitle: 'Processing ...',
                    applyingText: 'Processing Photo',
                    waitText: 'This may take a few seconds..',
                    onCancel: _showCancelWarningDialog,
                  ),
                  _PageState.result => const SizedBox.shrink(),
                  _PageState.selection => _buildSelectionBody(isDark),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionBody(bool isDark) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final boxSize = (w * 0.9 - w * 0.04) / 2.2;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: w * 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: h * 0.025),

            // --- Image Upload Card ---
            Container(
              height: h * 0.35,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[50],
                borderRadius: BorderRadius.circular(w * 0.05),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey[300]!,
                  width: w * 0.003,
                ),
              ),
              child: Stack(
                children: [
                  _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(w * 0.05),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.file(_selectedImage!, fit: BoxFit.contain),
                              Positioned(
                                top: w * 0.03,
                                right: w * 0.03,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedImage = null),
                                  child: Container(
                                    padding: EdgeInsets.all(w * 0.02),
                                    decoration: const BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: w * 0.04,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _isLoadingInitial
                                  ? const CircularProgressIndicator()
                                  : Icon(
                                      Icons.camera_alt_outlined,
                                      size: w * 0.12,
                                      color: isDark
                                          ? Colors.white30
                                          : Colors.grey[400],
                                    ),
                              SizedBox(height: h * 0.01),
                              Text(
                                _isLoadingInitial
                                    ? "Downloading sticker..."
                                    : 'Tap to select from gallery',
                                style: TextStyle(
                                  fontSize: w * 0.035,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey[500],
                                ),
                              ),
                              if (!_isLoadingInitial) ...[
                                SizedBox(height: h * 0.025),
                                GestureDetector(
                                  onTap: _pickImage,
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: w * 0.1,
                                      vertical: h * 0.014,
                                    ),
                                    decoration: ProGradientDecoration(
                                      borderRadius: BorderRadius.all(
                                        Radius.circular(w * 0.08),
                                      ),
                                    ),
                                    child: Text(
                                      'Choose image',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: w * 0.038,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                  Positioned(
                    bottom: w * 0.03,
                    right: w * 0.03,
                    child: Row(
                      children: [
                        _buildSmallCardIcon(
                          context,
                          Icons.find_replace_outlined,
                          isDark,
                        ),
                        SizedBox(width: w * 0.02),
                        _buildSmallCardIcon(
                          context,
                          Icons.view_sidebar_outlined,
                          isDark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: h * 0.03),

            // --- AI Suggestion Card ---
            AiSuggestionBox(
              text: AppStrings.backgroundAiSuggestion,
              isDark: isDark,
            ),

            SizedBox(height: h * 0.03),

            // --- Style Selection ---
            Padding(
              padding: EdgeInsets.only(top: boxSize * 0.15),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStyleOption('Blur Background', 'Blur', isDark),
                  ),
                  SizedBox(width: w * 0.04),
                  Expanded(
                    child: _buildStyleOption(
                      'Remove Background',
                      'Remove',
                      isDark,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: h * 0.04),
            GestureDetector(
              onTap: _generateBackground,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: h * 0.02),
                decoration: ProGradientDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(w * 0.08)),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Generate',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: w * 0.046,
                        ),
                      ),
                    ],
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

  Widget _buildStyleOption(String label, String value, bool isDark) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final isSelected = _selectedStyle == value;
    final boxSize = (w * 0.9 - w * 0.04) / 2.2;
    final imagePath = value == 'Blur'
        ? 'assets/images/blur_bg.png'
        : 'assets/images/remove_bg.png';

    return GestureDetector(
      onTap: () => setState(() => _selectedStyle = value),
      child: Column(
        children: [
          SizedBox(
            width: boxSize,
            height: boxSize,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                // --- Image as the box with conditional outline ---
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(w * 0.06),
                      border: isSelected
                          ? Border.all(color: Colors.orange, width: w * 0.005)
                          : Border.all(
                              color: Colors.transparent,
                              width: w * 0.005,
                            ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(w * 0.055),
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.image_not_supported),
                      ),
                    ),
                  ),
                ),

                // --- Check icon on top-right ---
                if (isSelected)
                  Positioned(
                    top: -w * 0.01,
                    right: -w * 0.01,
                    child: Container(
                      padding: EdgeInsets.all(w * 0.002),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: w * 0.01,
                            offset: Offset(0, w * 0.005),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.orange,
                        size: w * 0.055,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: h * 0.015),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textColor(isDark),
              fontSize: w * 0.032,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSmallCardIcon(BuildContext context, IconData icon, bool isDark) {
    final w = MediaQuery.of(context).size.width;
    return Container(
      padding: EdgeInsets.all(w * 0.02),
      decoration: BoxDecoration(
        color: isDark ? Colors.black45 : Colors.white70,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: w * 0.003),
      ),
      child: Icon(
        icon,
        size: w * 0.045,
        color: isDark ? Colors.white70 : Colors.black87,
      ),
    );
  }
}

/// A simple painter to draw a checkered pattern for "Remove Background" preview.
class CheckedPatternPainter extends CustomPainter {
  final bool isDark;
  final double screenWidth;
  CheckedPatternPainter({required this.isDark, required this.screenWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05);
    final double step = screenWidth * 0.025;

    for (double i = 0; i < size.width; i += step) {
      for (double j = 0; j < size.height; j += step) {
        if ((i / step).floor() % 2 == (j / step).floor() % 2) {
          canvas.drawRect(Rect.fromLTWH(i, j, step, step), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
