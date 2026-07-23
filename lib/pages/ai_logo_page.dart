import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:vidzeon/Services/media_service.dart';
import 'package:vidzeon/Services/asset_service.dart';
import 'package:vidzeon/Widgets/themed_dialog.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vidzeon/Core/colors.dart';
import 'package:vidzeon/Core/strings.dart'; // non-translatable
import 'package:vidzeon/Core/gradient.dart';
import 'package:vidzeon/Services/replicate_service.dart';
import 'package:vidzeon/Services/credit_service.dart';
import 'package:vidzeon/Services/generation_gate.dart';
import 'package:vidzeon/Services/content_safety_service.dart';
import 'package:vidzeon/Helpers/error_dialog_helper.dart';

import 'package:vidzeon/pages/upscale_page.dart';
import 'package:vidzeon/Widgets/ai_suggestion_box.dart';

enum _PageState { selection, loading, result }

class AiLogoPage extends StatefulWidget {
  const AiLogoPage({super.key});

  @override
  State<AiLogoPage> createState() => _AiLogoPageState();
}

class _AiLogoPageState extends State<AiLogoPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _promptController = TextEditingController();
  String _selectedStyle = 'Business';

  final ReplicateService _replicateService = ReplicateService();
  final CreditService _creditService = CreditService();

  _PageState _pageState = _PageState.selection;
  final List<String> _generatedLogos = [];
  int _selectedLogoIndex = 0;
  bool _isDownloading = false;
  bool _isNsfw = false;
  bool _isCancelled = false;

  final ScrollController _scrollController = ScrollController();
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
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeService() async {
    await _replicateService.initialize();
    await _creditService.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _generateLogo() async {
    if (_promptController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a description for your logo.'),
        ),
      );
      return;
    }

    final model = _replicateService.logoModel;
    if (model == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Model not configured.')));
      return;
    }

    // --- Safety Check ---
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: CircularProgressIndicator(color: Color(0xFFD66031)),
        ),
      );

      await ContentSafetyService().checkTextSafe(_promptController.text.trim());

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (e is NsfwContentException) {
        if (mounted) {
          ErrorDialogHelper.showRestrictedContentDialog(
            context,
            messageKey: e.messageKey,
          );
        }
        return;
      }
      debugPrint('⚠️ [AiLogoPage] Text safety check error: $e');
    }

    setState(() {
      _pageState = _PageState.loading;
      _isNsfw = false;
    });
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
        prompt: _promptController.text.trim(),
        extraVariables: {'style': _selectedStyle},
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
          _generatedLogos.clear();
          _generatedLogos.addAll([url, url, url, url]);
          _pageState = _PageState.result;
        });
      }
    } catch (e) {
      if (mounted) {
        _progressController.stop();

        if (_isCancelled) {
          _isCancelled = false;
          return;
        }

        if (e is NsfwContentException) {
          if (e.url != null) {
            setState(() {
              _generatedLogos.clear();
              _generatedLogos.addAll([e.url!, e.url!, e.url!, e.url!]);
              _isNsfw = true;
              _pageState = _PageState.result;
            });
          } else {
            setState(() => _pageState = _PageState.selection);
          }
          ErrorDialogHelper.showRestrictedContentDialog(
            context,
            messageKey: e.messageKey,
          );
        } else {
          setState(() => _pageState = _PageState.selection);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${AppStrings.error}${e.toString()}')),
          );
        }
      }
    }
  }

  Future<void> _downloadLogo() async {
    if (_generatedLogos.isEmpty || _isDownloading) return;
    setState(() => _isDownloading = true);
    final file = await MediaService.downloadImage(
      context,
      _generatedLogos[_selectedLogoIndex],
    );
    if (mounted) setState(() => _isDownloading = false);
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
      padding: EdgeInsets.symmetric(horizontal: sw * 0.01, vertical: sh * 0.01),
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
                    fontSize: sw * 0.03,
                    color: AppColors.secondaryTextColor(isDark),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _circleBtn(
            isDark: isDark,
            icon: Icons.close,
            onTap: () => Navigator.pop(context),
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

  Future<void> _showCancelWarningDialog(
    BuildContext context,
    bool isDark,
    double sw,
    double sh,
  ) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: EdgeInsets.all(sw * 0.06),
          decoration: BoxDecoration(
            color: AppColors.backgroundColor(isDark),
            borderRadius: BorderRadius.circular(sw * 0.05),
            border: Border.all(
              color: AppColors.creditsCardBorder(isDark),
              width: sw * 0.002,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.red,
                size: sw * 0.12,
              ),
              SizedBox(height: sh * 0.02),
              Text(
                'Cancel Generation?',
                style: TextStyle(
                  color: AppColors.textColor(isDark),
                  fontWeight: FontWeight.bold,
                  fontSize: sw * 0.045,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: sh * 0.015),
              Text(
                'Are you sure you want to cancel? Your credits have already been deducted.',
                style: TextStyle(
                  color: AppColors.secondaryTextColor(isDark),
                  fontSize: sw * 0.035,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: sh * 0.03),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, 'cancel'),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: sh * 0.015),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(sw * 0.03),
                        border: Border.all(
                          color: Colors.red.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Yes, Cancel',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                            fontSize: sw * 0.04,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: sh * 0.015),
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

    if (result == 'cancel' && mounted) {
      _replicateService.cancelActivePrediction();
      _progressController.stop();
      setState(() {
        _pageState = _PageState.selection;
        _isCancelled = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: _pageState != _PageState.loading,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_pageState == _PageState.loading) {
          final sw = MediaQuery.of(context).size.width;
          final sh = MediaQuery.of(context).size.height;
          _showCancelWarningDialog(context, isDark, sw, sh);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor(isDark),
        body: SafeArea(
          child: Column(
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.015),
              _buildTopBar(
                isDark: isDark,
                title: 'AI Logo Maker',
                subtitle: switch (_pageState) {
                  _PageState.loading =>
                    'Enhancing your image.\nThis may take a few seconds..',
                  _PageState.result => 'check_the_result',
                  _PageState.selection => 'I turn this text into a\nlogo',
                },
                onBack: switch (_pageState) {
                  _PageState.loading => () {
                    final sw = MediaQuery.of(context).size.width;
                    final sh = MediaQuery.of(context).size.height;
                    _showCancelWarningDialog(context, isDark, sw, sh);
                  },
                  _PageState.result => () => setState(
                    () => _pageState = _PageState.selection,
                  ),
                  _PageState.selection => null,
                },
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.01),
              Expanded(
                child: switch (_pageState) {
                  _PageState.loading => _buildLoadingScreen(isDark),
                  _PageState.result => _buildResultBody(isDark),
                  _PageState.selection => _buildSelectionBody(isDark),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen(bool isDark) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Processing ...',
            style: TextStyle(
              fontSize: sw * 0.05,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor(isDark),
            ),
          ),
          SizedBox(height: sh * 0.015),
          Text(
            'Transform your photo into art within\nAI filters',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: sw * 0.035,
              color: AppColors.secondaryTextColor(isDark),
            ),
          ),
          SizedBox(height: sh * 0.03),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: sw * 0.1),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: sw * 0.04,
              mainAxisSpacing: sw * 0.04,
            ),
            itemCount: 4,
            itemBuilder: (context, index) => Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey[200],
                borderRadius: BorderRadius.circular(sw * 0.04),
              ),
              child: Icon(
                Icons.image_outlined,
                color: Colors.grey[400],
                size: sw * 0.1,
              ),
            ),
          ),
          SizedBox(height: sh * 0.05),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: sw * 0.1),
            child: Column(
              children: [
                Text(
                  'Create your logo..',
                  style: TextStyle(
                    fontSize: sw * 0.04,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor(isDark),
                  ),
                ),
                SizedBox(height: sh * 0.01),
                LinearProgressIndicator(
                  value: _progressAnimation.value,
                  backgroundColor: isDark ? Colors.grey[850] : Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.orange,
                  ),
                  minHeight: sh * 0.012,
                  borderRadius: BorderRadius.circular(sw * 0.025),
                ),
                SizedBox(height: sh * 0.01),
                Text(
                  'Enhancing your image.\nThis may take a few seconds..',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: sw * 0.03,
                    color: AppColors.secondaryTextColor(isDark),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: sh * 0.05),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: sw * 0.1,
              vertical: sh * 0.02,
            ),
            child: OutlinedButton(
              onPressed: () {
                final sw = MediaQuery.of(context).size.width;
                final sh = MediaQuery.of(context).size.height;
                _showCancelWarningDialog(context, isDark, sw, sh);
              },
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, sh * 0.06),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(sw * 0.08),
                ),
                side: BorderSide(
                  color: isDark ? Colors.white : Colors.black,
                  width: sw * 0.003,
                ),
              ),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.textColor(isDark)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBody(bool isDark) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: sw * 0.05),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: sh * 0.025),
            Container(
              padding: EdgeInsets.all(sw * 0.04),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[50],
                borderRadius: BorderRadius.circular(sw * 0.06),
                border: Border.all(
                  color: Colors.orange.withValues(alpha: 0.3),
                  width: sw * 0.003,
                ),
              ),
              child: TextField(
                controller: _promptController,
                maxLines: 5,
                decoration: const InputDecoration(
                  hintText: 'eg.an astronaut flying through a galaxy',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.grey),
                ),
                style: TextStyle(color: AppColors.textColor(isDark)),
              ),
            ),
            SizedBox(height: sh * 0.03),
            Text(
              'Style:',
              style: TextStyle(
                fontSize: sw * 0.04,
                fontWeight: FontWeight.bold,
                color: AppColors.textColor(isDark),
              ),
            ),
            SizedBox(height: sh * 0.015),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _styleChip('Business Logo', 'Business', isDark),
                _styleChip('Gaming Logo', 'Gaming', isDark),
                _styleChip('Minimal', 'Minimal', isDark),
              ],
            ),
            SizedBox(height: sh * 0.03),
            AiSuggestionBox(text: AppStrings.logoSuggestion, isDark: isDark),

            SizedBox(height: sh * 0.15),

            SizedBox(height: sh * 0.02),
            GestureDetector(
              onTap: _generateLogo,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: sh * 0.02),
                decoration: ProGradientDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(sw * 0.08)),
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
                          fontSize: sw * 0.046,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: sh * 0.04),
          ],
        ),
      ),
    );
  }

  Widget _styleChip(String label, String value, bool isDark) {
    final sw = MediaQuery.of(context).size.width;
    final isSelected = _selectedStyle == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedStyle = value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: sw * 0.04, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.orange.withValues(alpha: 0.1)
              : (isDark ? Colors.grey[900] : Colors.grey[100]),
          border: Border.all(
            color: isSelected ? Colors.orange : Colors.grey[300]!,
          ),
          borderRadius: BorderRadius.circular(sw * 0.06),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.orange : AppColors.textColor(isDark),
            fontSize: sw * 0.03,
          ),
        ),
      ),
    );
  }

  Widget _buildResultBody(bool isDark) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: sw * 0.05),
      child: Column(
        children: [
          SizedBox(height: sh * 0.02),
          // Logo Grid Result
          AspectRatio(
            aspectRatio: 1,
            child: GridView.builder(
              padding: EdgeInsets.all(sw * 0.02),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: sw * 0.04,
                mainAxisSpacing: sw * 0.04,
              ),
              itemCount: 4,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final isSelected = _selectedLogoIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedLogoIndex = index),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.white,
                      borderRadius: BorderRadius.circular(sw * 0.06),
                      border: isSelected
                          ? Border.all(color: Colors.orange, width: sw * 0.008)
                          : Border.all(
                              color: Colors.grey[200]!,
                              width: sw * 0.005,
                            ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(sw * 0.06),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: _generatedLogos[index],
                            fit: BoxFit.contain,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(
                                strokeWidth: sw * 0.005,
                              ),
                            ),
                            errorWidget: (c, e, s) =>
                                const Icon(Icons.logo_dev_outlined),
                          ),
                          if (_isNsfw)
                            Positioned.fill(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 10,
                                  sigmaY: 10,
                                ),
                                child: Container(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  child: const Center(
                                    child: Icon(
                                      Icons.visibility_off,
                                      color: Colors.white,
                                      size: 32,
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
              },
            ),
          ),

          SizedBox(height: sh * 0.04),
          // Standard Actions
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  context,
                  Icons.auto_fix_high,
                  'Enhance',
                  isDark,
                  _isNsfw
                      ? () {}
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UpscalePage(
                              initialImageUrl:
                                  _generatedLogos[_selectedLogoIndex],
                            ),
                          ),
                        ),
                ),
              ),
              SizedBox(width: sw * 0.02),
              Expanded(
                child: _actionButton(
                  context,
                  Icons.keyboard_arrow_down,
                  'Png',
                  isDark,
                  () {},
                ),
              ),
              SizedBox(width: sw * 0.02),
              Expanded(
                child: _actionButton(
                  context,
                  Icons.edit,
                  'Re-Edit',
                  isDark,
                  () => setState(() => _pageState = _PageState.selection),
                ),
              ),
              SizedBox(width: sw * 0.02),
              Expanded(
                child: _actionButton(
                  context,
                  Icons.refresh,
                  'Try again',
                  isDark,
                  () => _generateLogo(),
                ),
              ),
            ],
          ),

          SizedBox(height: sh * 0.03),
          GestureDetector(
            onTap: (_isNsfw || _isDownloading) ? null : _downloadLogo,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: sh * 0.02),
              decoration: (_isNsfw || _isDownloading)
                  ? BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(sw * 0.08),
                    )
                  : ProGradientDecoration(
                      borderRadius: BorderRadius.all(
                        Radius.circular(sw * 0.08),
                      ),
                    ),
              child: Center(
                child: _isDownloading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.file_download_outlined,
                            color: Colors.white,
                          ),
                          SizedBox(width: sw * 0.02),
                          const Text(
                            'Download',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),

          SizedBox(height: sh * 0.02),
          OutlinedButton(
            onPressed: _isNsfw ? null : () {}, // Implement real share later
            style: OutlinedButton.styleFrom(
              minimumSize: Size(double.infinity, sh * 0.07),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(sw * 0.08),
              ),
              side: BorderSide(
                color: isDark ? Colors.white24 : Colors.grey[300]!,
                width: sw * 0.003,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.share_outlined, color: AppColors.textColor(isDark)),
                SizedBox(width: sw * 0.02),
                Text(
                  'Share',
                  style: TextStyle(
                    color: AppColors.textColor(isDark),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(
    BuildContext context,
    IconData icon,
    String label,
    bool isDark,
    VoidCallback onTap,
  ) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: sh * 0.015),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(sw * 0.04),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey[200]!,
            width: sw * 0.003,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: sw * 0.04, color: AppColors.textColor(isDark)),
            SizedBox(width: sw * 0.01),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textColor(isDark),
                fontSize: sw * 0.03,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
