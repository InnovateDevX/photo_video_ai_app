import 'package:flutter/material.dart';
import 'package:vidzeon/Widgets/themed_dialog.dart';
import 'package:vidzeon/Core/colors.dart';
import 'package:vidzeon/Core/strings.dart'; // non-translatable
import 'package:vidzeon/Core/gradient.dart';
import 'dart:io';
import 'package:vidzeon/Helpers/image_picker_helper.dart';
import 'package:vidzeon/Services/replicate_service.dart';
import 'package:vidzeon/Services/credit_service.dart';
import 'package:vidzeon/Services/generation_gate.dart';
import 'package:vidzeon/pages/ai_loading_screen.dart';
import 'package:vidzeon/pages/ai_result_screen.dart';
import 'package:vidzeon/Services/content_safety_service.dart';
import 'package:vidzeon/Helpers/error_dialog_helper.dart';
import 'package:vidzeon/Widgets/topbar.dart';
import 'package:vidzeon/Widgets/cancel_dialog.dart';
import 'package:vidzeon/Widgets/ai_suggestion_box.dart';

enum _PageState { selection, loading, result }

class AiHeadshotPage extends StatefulWidget {
  const AiHeadshotPage({super.key});

  @override
  State<AiHeadshotPage> createState() => _AiHeadshotPageState();
}

class _AiHeadshotPageState extends State<AiHeadshotPage>
    with SingleTickerProviderStateMixin {
  File? _selectedImage;

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

  Future<void> _generateHeadshot() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first.')),
      );
      return;
    }

    final model = _replicateService.headshotModel;
    if (model == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Model not configured.')));
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
        prompt:
            'professional business headshot, linkedin profile picture, highly detailed',
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
        } else if (e.toString().toLowerCase().contains('timeout')) {
          ErrorDialogHelper.showTimeoutDialog(context);
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
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
          Future.delayed(const Duration(milliseconds: 100), _generateHeadshot);
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
              const TopBar(),
              _buildTopBar(
                isDark: isDark,
                title: 'Professional Headshot',
                subtitle: switch (_pageState) {
                  _PageState.loading => 'Processing ......',
                  _PageState.result =>
                    'Here\'s your business headshot tailored just for you',
                  _PageState.selection =>
                    'Convert any photo into a professional business portrait',
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
                    applyingText: 'generating_headshot',
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
                borderRadius: BorderRadius.circular(w * 0.06),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey[300]!,
                  width: w * 0.003,
                ),
              ),
              child: Stack(
                children: [
                  _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(w * 0.06),
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
                              Icon(
                                Icons.camera_alt_outlined,
                                size: w * 0.12,
                                color: isDark
                                    ? Colors.white30
                                    : Colors.grey[400],
                              ),
                              SizedBox(height: h * 0.01),
                              Text(
                                'Tap to select from gallery',
                                style: TextStyle(
                                  fontSize: w * 0.035,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey[500],
                                ),
                              ),
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
                          ),
                        ),
                  Positioned(
                    bottom: w * 0.03,
                    right: w * 0.03,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: _buildSmallCardIcon(
                            context,
                            Icons.find_replace_outlined,
                            isDark,
                          ),
                        ),
                        SizedBox(width: w * 0.02),
                        GestureDetector(
                          onTap: () {},
                          child: _buildSmallCardIcon(
                            context,
                            Icons.view_sidebar_outlined,
                            isDark,
                          ),
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
              text: AppStrings.headshotSuggestionDesc,
              isDark: isDark,
            ),

            SizedBox(height: h * 0.04),
            GestureDetector(
              onTap: _generateHeadshot,
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
                        'Create Headshot ⚡',
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
