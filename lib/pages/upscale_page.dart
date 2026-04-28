import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import '../Core/colors.dart';
import '../Core/strings.dart'; // non-translatable
import 'package:localization/localization.dart';
import '../Core/gradient.dart';
import '../Core/directory.dart';
import '../Services/data_service.dart';
import 'dart:io';
import '../Helpers/image_picker_helper.dart';
import '../Services/replicate_service.dart';
import '../Services/ad_service.dart';
import '../Services/credit_service.dart';
import '../Services/generation_gate.dart';
import '../pages/ai_loading_screen.dart';
import '../pages/ai_result_screen.dart';
import '../Widgets/topbar.dart';
import '../Services/media_service.dart';

enum _PageState { selection, loading, result }

class UpscalePage extends StatefulWidget {
  final String? initialImageUrl;
  const UpscalePage({super.key, this.initialImageUrl});

  @override
  State<UpscalePage> createState() => _UpscalePageState();
}

class _UpscalePageState extends State<UpscalePage>
    with SingleTickerProviderStateMixin {
  int _selectedUpscaleFactor = 0;
  final List<String> _factors = AppStrings.upscaleFactors;
  File? _selectedImage;
  late Future<String> _upscalePreviewUrl;

  final ReplicateService _replicateService = ReplicateService();
  final AdService _adService = AdService();
  final CreditService _creditService = CreditService();

  _PageState _pageState = _PageState.selection;
  String? _generatedImageUrl;

  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _fetchUpscalePreview();
    _initializeService();

    if (widget.initialImageUrl != null) {
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

  Future<void> _loadInitialImage(String url) async {
    final file = await MediaService.downloadToTempFile(url);
    if (file != null && mounted) {
      setState(() {
        _selectedImage = file;
      });
    }
  }

  Future<void> _initializeService() async {
    await _replicateService.initialize();
    await _creditService.initialize();
    if (mounted) setState(() {});
  }

  void _fetchUpscalePreview() {
    _upscalePreviewUrl = FirebaseStorage.instance
        .ref(AppDirectories.upscaleDirectory)
        .list(ListOptions(maxResults: 1))
        .then((result) {
          if (result.items.isNotEmpty) {
            return DataService().getDownloadURL(result.items.first);
          }
          throw 'No upscale previews available.';
        });
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

  Future<void> _generateUpscale() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an image first.')),
      );
      return;
    }

    final model = _replicateService.upscaleModel;
    if (model == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upscale model not configured.')),
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
      final scaleStr = _factors[_selectedUpscaleFactor].replaceAll(
        RegExp(r'[^0-9]'),
        '',
      );
      final scaleFactor = int.tryParse(scaleStr) ?? 2;

      final url = await _replicateService.generateContent(
        modelConfig: model,
        prompt: 'upscale',
        referenceImage: _selectedImage,
        extraVariables: {'scale': scaleFactor},
      );

      await _creditService.deductCredits(model.creditUsed);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('credit_deducted'.i18n())),
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
        if (e.toString().toLowerCase().contains('timeout')) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text(AppStrings.timeoutTitle),
              content: const Text(AppStrings.timeoutMessage),
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
    }
  }

  Widget _buildTopBar({
    required bool isDark,
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
                  'tool_upscale'.i18n(),
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
            color: AppColors.creditsCardBorder(isDark).withOpacity(0.4),
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
            const TopBar(),
            SizedBox(height: MediaQuery.of(context).size.height * 0.015),
            _buildTopBar(
              isDark: isDark,
              subtitle: switch (_pageState) {
                _PageState.loading => 'outfit_processing_subtitle'.i18n(),
                _PageState.result => 'outfit_result_subtitle'.i18n(),
                _PageState.selection => 'upscale_subtitle'.i18n(),
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
            SizedBox(height: MediaQuery.of(context).size.height * 0.01),
            Expanded(
              child: switch (_pageState) {
                _PageState.loading => AILoadingScreen(
                  selectedImage: _selectedImage,
                  progressAnimation: _progressAnimation,
                  aiTips: AppStrings.outfitAiTips.map((e) => e.i18n()).toList(),
                  processingTitle: 'processing_title'.i18n(),
                  applyingText: 'Processing ...'.i18n(), // Or 'upscaling_photo' if added
                  waitText: 'take_few_seconds'.i18n(),
                  onCancel: () {
                    _progressController.stop();
                    setState(() => _pageState = _PageState.selection);
                  },
                ),
                _PageState.result => AIResultScreen(
                  originalImage: _selectedImage,
                  resultImageUrl: _generatedImageUrl!,
                  onReEdit: () =>
                      setState(() => _pageState = _PageState.selection),
                  onTryAgain: () {
                    setState(() => _pageState = _PageState.selection);
                    Future.delayed(
                      const Duration(milliseconds: 100),
                      _generateUpscale,
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: h * 0.025),

            // --- Image Upload Card ---
            Container(
              width: double.infinity,
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
                              Image.file(_selectedImage!, fit: BoxFit.cover),
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
                  Positioned(
                    bottom: w * 0.03,
                    right: w * 0.03,
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: _buildSmallCardIcon(context, Icons.grid_view, isDark),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: h * 0.03),

            // --- Upscale Options ---
            Text(
              'upscale_options'.i18n(),
              style: TextStyle(
                fontSize: w * 0.045,
                fontWeight: FontWeight.bold,
                color: AppColors.textColor(isDark),
              ),
            ),
            SizedBox(height: h * 0.015),
            Row(
              children: List.generate(_factors.length, (index) {
                final isSelected = _selectedUpscaleFactor == index;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedUpscaleFactor = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(
                        right: index < _factors.length - 1 ? w * 0.03 : 0,
                      ),
                      padding: EdgeInsets.symmetric(vertical: h * 0.018),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(w * 0.08),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : (isDark ? Colors.white24 : Colors.grey[300]!),
                          width: w * 0.004,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          _factors[index].i18n(),
                          style: TextStyle(
                            color: isSelected
                                ? (isDark ? Colors.black : Colors.white)
                                : AppColors.textColor(isDark),
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: w * 0.038,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
            SizedBox(height: h * 0.03),

            // --- Before/After Showcase ---
            FutureBuilder<String>(
              future: _upscalePreviewUrl,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildPlaceholder(h, w, isDark, isLoading: true);
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return _buildPlaceholder(h, w, isDark);
                }
                return ClipRRect(
                  borderRadius: BorderRadius.circular(w * 0.06),
                  child: CachedNetworkImage(
                    imageUrl: snapshot.data!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: isDark ? Colors.grey[850]! : Colors.grey[300]!,
                      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                      child: Container(
                        height: h * 0.22,
                        color: Colors.white,
                      ),
                    ),
                    errorWidget: (context, url, error) => _buildPlaceholder(h, w, isDark),
                  ),
                );
              },
            ),

            SizedBox(height: h * 0.012),
            Center(
              child: Text(
                'upscale_processing_time'.i18n(),
                style: TextStyle(
                  fontSize: w * 0.032,
                  color: AppColors.secondaryTextColor(isDark),
                ),
              ),
            ),

            SizedBox(height: h * 0.025),
            GestureDetector(
              onTap: _generateUpscale,
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
                        '${'upscale_button_text'.i18n()} ${_replicateService.upscaleModel?.creditUsed ?? 0}',
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

  Widget _buildPlaceholder(
    double h,
    double w,
    bool isDark, {
    bool isLoading = false,
  }) {
    return Container(
      height: h * 0.22,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[200],
        borderRadius: BorderRadius.circular(w * 0.04),
      ),
      child: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : Icon(
                Icons.image_outlined,
                size: w * 0.12,
                color: isDark ? Colors.white24 : Colors.grey[400],
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
