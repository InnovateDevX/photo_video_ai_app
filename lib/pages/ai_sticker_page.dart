import 'package:flutter/material.dart';
import 'package:trail_ai_app/Core/colors.dart';
import 'package:trail_ai_app/Core/strings.dart'; // non-translatable
import 'package:localization/localization.dart';
import 'package:trail_ai_app/Core/gradient.dart';
import 'dart:io';
import 'package:trail_ai_app/Helpers/image_picker_helper.dart';
import 'package:trail_ai_app/Services/replicate_service.dart';
import 'package:trail_ai_app/Services/ad_service.dart';
import 'package:trail_ai_app/Services/content_safety_service.dart';
import 'package:trail_ai_app/Helpers/error_dialog_helper.dart';
import 'package:trail_ai_app/Services/credit_service.dart';
import 'package:trail_ai_app/Services/generation_gate.dart';
import 'package:trail_ai_app/Widgets/topbar.dart';
import 'package:trail_ai_app/pages/ai_background_page.dart';
import 'package:trail_ai_app/pages/ai_loading_screen.dart';
import 'package:trail_ai_app/pages/ai_result_screen.dart';

enum _PageState { selection, loading, result }

class AiStickerPage extends StatefulWidget {
  const AiStickerPage({super.key});

  @override
  State<AiStickerPage> createState() => _AiStickerPageState();
}

class _AiStickerPageState extends State<AiStickerPage>
    with SingleTickerProviderStateMixin {
  File? _selectedImage;
  bool _isTextMode = true; // true = Text mode, false = Image mode
  final TextEditingController _promptController = TextEditingController();

  String _selectedTheme = 'Classics'; // Classics, AI, Cartoon
  String _selectedMood = 'Happy'; // Happy, Sad, Angry

  final ReplicateService _replicateService = ReplicateService();
  final AdService _adService = AdService();
  final CreditService _creditService = CreditService();

  _PageState _pageState = _PageState.selection;
  String? _generatedImageUrl;
  bool _isNsfw = false;

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

  Future<void> _generateSticker() async {
    if (_isTextMode && _promptController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('enter_text'.i18n())));
      return;
    }
    if (!_isTextMode && _selectedImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('choose_image'.i18n())));
      return;
    }

    final model = _isTextMode
        ? _replicateService.stickerTextModel
        : _replicateService.stickerImageModel;

    if (model == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('no_model_selected'.i18n())));
      return;
    }

    final userText = _promptController.text.trim();

    // --- Safety Check ---
    try {
      if (_isTextMode) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => const Center(
            child: CircularProgressIndicator(color: Color(0xFFD66031)),
          ),
        );
        if (userText.isNotEmpty) {
          await ContentSafetyService().checkTextSafe(userText);
        }
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        if (e is NsfwContentException) {
          if (e.url != null) {
            setState(() {
              _generatedImageUrl = e.url;
              _isNsfw = true;
              _pageState = _PageState.result;
            });
          }
          ErrorDialogHelper.showRestrictedContentDialog(
            context,
            messageKey: e.messageKey,
          );
        } else {
          debugPrint('⚠️ [AiStickerPage] Safety check error: $e');
        }
      }
      return;
    }

    setState(() {
      _pageState = _PageState.loading;
      _isNsfw = false;
    });
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
      final userText = _promptController.text.trim();
      final url = await _replicateService.generateContent(
        modelConfig: model,
        prompt: userText.isNotEmpty ? userText : "the subject",
        extraVariables: {
          'STYLE': _selectedTheme,
          'MOOD': _selectedMood,
          'PROMPT': userText.isNotEmpty ? userText : "the subject",
        },
        referenceImage: _isTextMode ? null : _selectedImage,
      );

      if (url.isNotEmpty) {
        debugPrint('✅ [AiStickerPage] Generation successful: $url');

        // Deduct credits only if generation actually yielded a result
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
        throw Exception("Generated URL is empty");
      }
    } catch (e) {
      if (mounted) {
        _progressController.stop();

        if (e is NsfwContentException) {
          if (e.url != null) {
            setState(() {
              _generatedImageUrl = e.url;
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
        } else if (e.toString().toLowerCase().contains('timeout')) {
          setState(() => _pageState = _PageState.selection);
          ErrorDialogHelper.showTimeoutDialog(context);
        } else {
          setState(() => _pageState = _PageState.selection);
          ErrorDialogHelper.showErrorDialog(
            context,
            message: 'Something went wrong. Please try again.',
          );
        }
      }
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

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(isDark),
      body: SafeArea(
        child: Column(
          children: [
            if (_pageState == _PageState.selection) const TopBar(),
            _buildTopBar(
              isDark: isDark,
              title: switch (_pageState) {
                _PageState.loading => 'generating'.i18n(),
                _PageState.result => 'sticker_ready'.i18n(),
                _PageState.selection => 'sticker_title'.i18n(),
              },
              subtitle: switch (_pageState) {
                _PageState.loading => 'sticker_text_desc'.i18n(),
                _PageState.result => 'big_sticker_preview'.i18n(),
                _PageState.selection =>
                  _isTextMode
                      ? 'sticker_text_desc'.i18n()
                      : 'sticker_image_desc'.i18n(),
              },
              onBack: switch (_pageState) {
                _PageState.loading => () {
                  _progressController.stop();
                  setState(() => _pageState = _PageState.selection);
                },
                _PageState.result => () => setState(
                  () => _pageState = _PageState.selection,
                ),
                _PageState.selection => null,
              },
            ),
            Expanded(
              child: switch (_pageState) {
                _PageState.loading => AILoadingScreen(
                  selectedImage: _isTextMode ? null : _selectedImage,
                  progressAnimation: _progressAnimation,
                  aiTips: AppStrings.stickerAiTips
                      .map((e) => e.i18n())
                      .toList(),
                  processingTitle: 'processing_title'.i18n(),
                  applyingText: 'generating_sticker'.i18n(),
                  waitText: 'take_few_seconds'.i18n(),
                  customLogoAsset: 'assets/images/Sticker_logo.webp',
                  onCancel: () {
                    _progressController.stop();
                    setState(() => _pageState = _PageState.selection);
                  },
                ),
                _PageState.result => AIResultScreen(
                  originalImage: _isTextMode ? null : _selectedImage,
                  resultImageUrl: _generatedImageUrl!,
                  isNsfw: _isNsfw,
                  fit: BoxFit.contain,
                  customActionLabel: 'background_ai'.i18n(),
                  customActionIcon: Icons.layers_clear,
                  onCustomAction: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          AiBackgroundPage(initialImageUrl: _generatedImageUrl),
                    ),
                  ),
                  onReEdit: () =>
                      setState(() => _pageState = _PageState.selection),
                  onTryAgain: () {
                    setState(() => _pageState = _PageState.selection);
                    Future.delayed(
                      const Duration(milliseconds: 100),
                      _generateSticker,
                    );
                  },
                ),
                _PageState.selection => _buildSelectionBody(isDark),
              },
            ),
          ],
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
            // Toggle Text / Image
            Container(
              margin: EdgeInsets.symmetric(vertical: h * 0.015),
              padding: EdgeInsets.all(w * 0.01),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.circular(w * 0.08),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isTextMode = true),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: h * 0.015),
                        decoration: _isTextMode
                            ? ProGradientDecoration(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(w * 0.08),
                                ),
                              )
                            : null,
                        child: Center(
                          child: Text(
                            'sticker_text_toggle'.i18n(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isTextMode
                                  ? Colors.white
                                  : AppColors.textColor(isDark),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isTextMode = false),
                      child: Container(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        decoration: !_isTextMode
                            ? const ProGradientDecoration(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(30),
                                ),
                              )
                            : null,
                        child: Center(
                          child: Text(
                            'sticker_image_toggle'.i18n(),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: !_isTextMode
                                  ? Colors.white
                                  : AppColors.textColor(isDark),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: h * 0.01),

            if (_isTextMode) ...[
              // --- Text Area ---
              Container(
                height: h * 0.15,
                padding: EdgeInsets.all(w * 0.04),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.white,
                  borderRadius: BorderRadius.circular(w * 0.06),
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: w * 0.005,
                  ),
                ),
                child: TextField(
                  controller: _promptController,
                  maxLines: null,
                  expands: true,
                  style: TextStyle(color: AppColors.textColor(isDark)),
                  decoration: InputDecoration(
                    hintText: 'prompt_hint'.i18n(),
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: InputBorder.none,
                  ),
                ),
              ),
              SizedBox(height: h * 0.02),
            ],

            if (!_isTextMode) ...[
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
                                Image.file(
                                  _selectedImage!,
                                  fit: BoxFit.contain,
                                ),
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
                                  'tap_to_select_gallery'.i18n(),
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
                                      'choose_image'.i18n(),
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
                    if (_selectedImage == null)
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
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],

            SizedBox(height: h * 0.02),

            // --- AI Suggestion Card ---
            Container(
              padding: EdgeInsets.all(w * 0.04),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[100],
                borderRadius: BorderRadius.circular(w * 0.06),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey[300]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb,
                        color: Colors.brown,
                        size: w * 0.05,
                      ),
                      SizedBox(width: w * 0.02),
                      Text(
                        'ai_suggestion'.i18n(),
                        style: TextStyle(
                          fontSize: w * 0.04,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textColor(isDark),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: h * 0.015),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(w * 0.03),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(w * 0.025),
                    ),
                    child: Text(
                      'sticker_suggestion_desc'.i18n(),
                      style: TextStyle(
                        fontSize: w * 0.032,
                        color: AppColors.secondaryTextColor(isDark),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: h * 0.02),
            Text(
              'artistic_style'.i18n(),
              style: TextStyle(
                fontSize: w * 0.045,
                fontWeight: FontWeight.bold,
                color: AppColors.textColor(isDark),
              ),
            ),
            SizedBox(height: h * 0.01),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _moodButton(
                  "Classics",
                  "🤔",
                  _selectedTheme == "Classics",
                  () => setState(() => _selectedTheme = "Classics"),
                ),
                _moodButton(
                  "AI",
                  "🧠",
                  _selectedTheme == "AI",
                  () => setState(() => _selectedTheme = "AI"),
                ),
                _moodButton(
                  "Cartoon",
                  "⭐",
                  _selectedTheme == "Cartoon",
                  () => setState(() => _selectedTheme = "Cartoon"),
                ),
              ],
            ),
            SizedBox(height: h * 0.015),
            Text(
              'mood'.i18n(),
              style: TextStyle(
                fontSize: w * 0.045,
                fontWeight: FontWeight.bold,
                color: AppColors.textColor(isDark),
              ),
            ),
            SizedBox(height: h * 0.01),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _moodButton(
                  "Happy",
                  "😃",
                  _selectedMood == "Happy",
                  () => setState(() => _selectedMood = "Happy"),
                ),
                _moodButton(
                  "Sad",
                  "😢",
                  _selectedMood == "Sad",
                  () => setState(() => _selectedMood = "Sad"),
                ),
                _moodButton(
                  "Angry",
                  "😠",
                  _selectedMood == "Angry",
                  () => setState(() => _selectedMood = "Angry"),
                ),
              ],
            ),

            SizedBox(height: h * 0.04),
            GestureDetector(
              onTap: _generateSticker,
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
                        '${'sticker_button_text'.i18n()} ${(_isTextMode ? _replicateService.stickerTextModel : _replicateService.stickerImageModel)?.creditUsed ?? 0}',
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

  Widget _moodButton(
    String label,
    String emoji,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: w * 0.28,
        padding: EdgeInsets.symmetric(vertical: h * 0.01),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.transparent
              : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[900]
                    : Colors.white),
          borderRadius: BorderRadius.circular(w * 0.06),
          border: Border.all(
            color: isSelected ? Colors.orange : Colors.grey[300]!,
            width: w * 0.005,
          ),
          gradient: isSelected
              ? LinearGradient(
                  colors: [Colors.orange.shade300, Colors.deepOrange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Column(
          children: [
            Text(emoji, style: TextStyle(fontSize: w * 0.06)),
            SizedBox(height: h * 0.005),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : AppColors.textColor(
                        Theme.of(context).brightness == Brightness.dark,
                      ),
                fontSize: w * 0.03,
              ),
            ),
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
