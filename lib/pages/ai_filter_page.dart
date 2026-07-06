import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:trail_ai_app/Core/colors.dart';
import 'package:trail_ai_app/Core/strings.dart'; // non-translatable
import 'package:localization/localization.dart';
import 'package:trail_ai_app/Core/gradient.dart';
import 'package:trail_ai_app/Helpers/image_picker_helper.dart';
import 'package:trail_ai_app/Models/filter_style.dart';
import 'package:trail_ai_app/Services/replicate_service.dart';
import 'package:trail_ai_app/Services/ad_service.dart';
import 'package:trail_ai_app/Services/credit_service.dart';
import 'package:trail_ai_app/Services/generation_gate.dart';
import 'package:trail_ai_app/Services/remote_config_service.dart';
import 'package:trail_ai_app/Widgets/topbar.dart';
import 'package:trail_ai_app/pages/ai_loading_screen.dart';
import 'package:trail_ai_app/pages/ai_result_screen.dart';
import 'package:trail_ai_app/Services/content_safety_service.dart';
import 'package:trail_ai_app/Helpers/error_dialog_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';

enum _PageState { selection, loading, result }

class AiFilterPage extends StatefulWidget {
  const AiFilterPage({super.key});

  @override
  State<AiFilterPage> createState() => _AiFilterPageState();
}

class _AiFilterPageState extends State<AiFilterPage>
    with SingleTickerProviderStateMixin {
  File? _selectedImage;
  List<FilterStyle> _styles = [];
  FilterStyle? _selectedStyle;

  final ReplicateService _replicateService = ReplicateService();
  final AdService _adService = AdService();
  final CreditService _creditService = CreditService();
  final RemoteConfigService _remoteConfig = RemoteConfigService();

  _PageState _pageState = _PageState.selection;
  String? _generatedImageUrl;

  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _initialize();

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

  Future<void> _initialize() async {
    await _replicateService.initialize();
    await _creditService.initialize();
    _loadStyles();
    if (mounted) setState(() {});
  }

  void _loadStyles() {
    final jsonStr = _remoteConfig.filterStylesJson;
    try {
      final List<dynamic> list = jsonDecode(jsonStr);
      _styles = list.map((e) => FilterStyle.fromJson(e)).toList();
      if (_styles.isNotEmpty) {
        _selectedStyle = _styles.first;
      }
    } catch (e) {
      debugPrint('❌ [AiFilterPage] Error parsing styles: $e');
      _styles = [];
    }
  }

  Future<void> _pickImage() async {
    final File? croppedFile = await ImagePickerHelper.pickAndCropImage(context);
    if (croppedFile != null && mounted) {
      setState(() {
        _selectedImage = croppedFile;
        _pageState = _PageState.selection;
      });
    }
  }

  Future<void> _generateFilter() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an image.')));
      return;
    }

    if (_selectedStyle == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a style.')));
      return;
    }

    final model = _replicateService.filterModel;
    if (model == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Model configuration missing.')),
      );
      return;
    }



    setState(() => _pageState = _PageState.loading);
    _progressController.forward(from: 0);

    final canProceed = await GenerationGate.check(
      context: context,
      adService: _adService,
      creditService: _creditService,
      creditCost: model.creditUsed,
    );

    if (!canProceed) {
      _progressController.stop();
      if (mounted) setState(() => _pageState = _PageState.selection);
      return;
    }

    try {
      final url = await _replicateService.generateContent(
        modelConfig: model,
        prompt: _selectedStyle!.prompt,
        extraVariables: {
          'STYLE': _selectedStyle!.name,
          'PROMPT': _selectedStyle!.prompt,
        },
        referenceImage: _selectedImage,
      );

      if (url.isNotEmpty) {
        await _creditService.deductCredits(model.creditUsed);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('credit_deducted'.i18n())));
          _progressController.stop();
          setState(() {
            _generatedImageUrl = url;
            _pageState = _PageState.result;
          });
        }
      } else {
        throw Exception("Empty URL returned");
      }
    } catch (e) {
      if (mounted) {
        _progressController.stop();
        setState(() => _pageState = _PageState.selection);

        if (e is NsfwContentException) {
          ErrorDialogHelper.showRestrictedContentDialog(context, messageKey: e.messageKey);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${'error'.i18n()}${e.toString()}')),
          );
        }
      }
    }
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
            _generateFilter,
          );
        },
        onBack: () => setState(() => _pageState = _PageState.selection),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(isDark),
      body: SafeArea(
        child: Column(
          children: [
            if (_pageState == _PageState.selection) const TopBar(),
            _buildCustomNav(isDark),
            Expanded(
              child: switch (_pageState) {
                _PageState.loading => AILoadingScreen(
                  selectedImage: _selectedImage,
                  progressAnimation: _progressAnimation,
                  aiTips: AppStrings.stickerAiTips
                      .map((e) => e.i18n())
                      .toList(), // Reusing tips for now
                  processingTitle: 'filter_processing'.i18n(),
                  applyingText: 'filter_applying'.i18n(),
                  waitText: 'take_few_seconds'.i18n(),
                  onCancel: () {
                    _progressController.stop();
                    setState(() => _pageState = _PageState.selection);
                  },
                ),
                _PageState.result => const SizedBox.shrink(),
                _PageState.selection => _buildSelectionBody(isDark),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomNav(bool isDark) {
    final sw = MediaQuery.of(context).size.width;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: sw * 0.04, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _navCircleBtn(
            isDark,
            Icons.arrow_back_ios_new,
            () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'ai_filter_title'.i18n(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor(isDark),
                  ),
                ),
                Text(
                  'ai_filter_desc'.i18n(),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.secondaryTextColor(isDark),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          _navCircleBtn(isDark, Icons.close, () => Navigator.pop(context)),
        ],
      ),
    );
  }

  Widget _navCircleBtn(bool isDark, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
        decoration: BoxDecoration(
          color: AppColors.tileBackgroundColor(isDark),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Icon(icon, size: 18, color: AppColors.textColor(isDark)),
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
            SizedBox(height: h * 0.02),
            // Image card
            Container(
              height: h * 0.35,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[50],
                borderRadius: BorderRadius.circular(w * 0.06),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
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
                            ],
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.camera_alt_outlined,
                                size: 50,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                              Text(
                                'tap_to_select_gallery'.i18n(),
                                style: TextStyle(color: Colors.grey[500]),
                              ),
                              SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                              GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  decoration: ProGradientDecoration(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(w * 0.08),
                                    ),
                                  ),
                                  child: Text(
                                    'choose_image'.i18n(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                  if (_selectedImage != null)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedImage = null),
                        child: Container(
                          padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.015),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  if (_selectedImage == null)
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Row(
                        children: [
                          _actionIcon(Icons.qr_code_scanner, isDark),
                          SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                          _actionIcon(Icons.crop_original, isDark),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: h * 0.02),
            // Suggestion
            Container(
              padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.04),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[100],
                borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.05),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.lightbulb,
                        color: Colors.orange,
                        size: 20,
                      ),
                      SizedBox(width: MediaQuery.of(context).size.width * 0.02),
                      Text(
                        'ai_suggestion'.i18n(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textColor(isDark),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.03),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.02),
                    ),
                    child: Text(
                      'ai_filter_suggestion'.i18n(),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.secondaryTextColor(isDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: h * 0.02),
            // Artistic Style
            Text(
              'artistic_style'.i18n(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textColor(isDark),
              ),
            ),
            SizedBox(height: h * 0.015),
            SizedBox(
              height: 140,
              child: _styles.isEmpty
                  ? Center(
                      child: Text(
                        "No styles configured",
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _styles.length,
                      itemBuilder: (context, index) {
                        final style = _styles[index];
                        final isSelected = _selectedStyle?.id == style.id;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedStyle = style),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 90,
                                height: 90,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.04),
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.orange
                                        : Colors.grey.withValues(alpha: 0.2),
                                    width: 2,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.035),
                                  child: style.thumbnailUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: style.thumbnailUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) =>
                                              Container(
                                                color: Colors.grey[300],
                                              ),
                                          errorWidget: (context, url, err) =>
                                              Container(
                                                color: Colors.grey[400],
                                                child: const Icon(Icons.style),
                                              ),
                                        )
                                      : Container(
                                          color: Colors.grey[300],
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                              Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: SizedBox(
                                  width: 90,
                                  child: Text(
                                    style.name,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      color: isSelected
                                          ? Colors.orange
                                          : AppColors.textColor(isDark),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            SizedBox(height: h * 0.04),
            // Generate button
            GestureDetector(
              onTap: _generateFilter,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: ProGradientDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(w * 0.08)),
                ),
                child: Center(
                  child: Text(
                    '${'generate_filter'.i18n()} ${_replicateService.filterModel?.creditUsed ?? 0}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
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

  Widget _actionIcon(IconData icon, bool isDark) {
    return Container(
      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.015),
      decoration: BoxDecoration(
        color: isDark ? Colors.black45 : Colors.white70,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24),
      ),
      child: Icon(
        icon,
        size: 16,
        color: isDark ? Colors.white70 : Colors.black87,
      ),
    );
  }
}
