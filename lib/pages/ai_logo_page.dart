import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:trail_ai_app/Core/colors.dart';
import 'package:trail_ai_app/Core/strings.dart'; // non-translatable
import 'package:localization/localization.dart';
import 'package:trail_ai_app/Core/gradient.dart';
import 'package:trail_ai_app/Services/replicate_service.dart';
import 'package:trail_ai_app/Services/ad_service.dart';
import 'package:trail_ai_app/Services/credit_service.dart';
import 'package:trail_ai_app/Services/generation_gate.dart';
import 'package:trail_ai_app/Services/content_safety_service.dart';
import 'package:trail_ai_app/Widgets/topbar.dart';
import 'package:trail_ai_app/pages/upscale_page.dart';

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
  final AdService _adService = AdService();
  final CreditService _creditService = CreditService();

  _PageState _pageState = _PageState.selection;
  final List<String> _generatedLogos = []; 
  int _selectedLogoIndex = 0;

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
        prompt:
            'logo design, ${_promptController.text}, $_selectedStyle style, professional minimalist logo, white background',
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
          _generatedLogos.clear();
          _generatedLogos.addAll([url, url, url, url]);
          _pageState = _PageState.result;
        });
      }
    } catch (e) {
      if (mounted) {
        _progressController.stop();
        setState(() => _pageState = _PageState.selection);
        
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
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${AppStrings.error}${e.toString()}')),
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
              title: 'logo_maker_title'.i18n(),
              subtitle: switch (_pageState) {
                _PageState.loading => 'enhancing_logo'.i18n(),
                _PageState.result => 'check_the_result'.i18n(),
                _PageState.selection => 'logo_maker_desc'.i18n(),
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
                _PageState.loading => _buildLoadingScreen(isDark),
                _PageState.result => _buildResultBody(isDark),
                _PageState.selection => _buildSelectionBody(isDark),
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen(bool isDark) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'processing_title'.i18n(),
          style: TextStyle(
            fontSize: sw * 0.05,
            fontWeight: FontWeight.bold,
            color: AppColors.textColor(isDark),
          ),
        ),
        SizedBox(height: sh * 0.02),
        Text(
          'Transform your photo into art within\nAI filters',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: sw * 0.035,
            color: AppColors.secondaryTextColor(isDark),
          ),
        ),
        SizedBox(height: sh * 0.05),
        // Mock skeleton/loading grid
        GridView.builder(
          shrinkWrap: true,
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
        SizedBox(height: sh * 0.1),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: sw * 0.1),
          child: Column(
            children: [
              Text(
                'creating_logo'.i18n(),
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
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                minHeight: sh * 0.012,
                borderRadius: BorderRadius.circular(sw * 0.025),
              ),
              SizedBox(height: sh * 0.01),
              Text(
                'enhancing_logo'.i18n(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: sw * 0.03,
                  color: AppColors.secondaryTextColor(isDark),
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: sw * 0.1,
            vertical: sh * 0.04,
          ),
          child: OutlinedButton(
            onPressed: () {
              _progressController.stop();
              setState(() => _pageState = _PageState.selection);
            },
            style: OutlinedButton.styleFrom(
              minimumSize: Size(double.infinity, sh * 0.06),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(sw * 0.08),
              ),
              side: BorderSide(color: isDark ? Colors.white : Colors.black, width: sw * 0.003),
            ),
            child: Text(
              'cancel'.i18n(),
              style: TextStyle(color: AppColors.textColor(isDark)),
            ),
          ),
        ),
      ],
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

            // --- Text Input Area ---
            Container(
              padding: EdgeInsets.all(sw * 0.04),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[50],
                borderRadius: BorderRadius.circular(sw * 0.06),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
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

            // --- Style Selection ---
            Text(
              'logo_style'.i18n(),
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
                _styleChip('business_logo'.i18n(), 'Business', isDark),
                _styleChip('gaming_logo'.i18n(), 'Gaming', isDark),
                _styleChip('minimal_logo'.i18n(), 'Minimal', isDark),
              ],
            ),

            SizedBox(height: sh * 0.03),

            // --- AI Suggestion Card ---
            Container(
              padding: EdgeInsets.all(sw * 0.04),
              decoration: BoxDecoration(
                color: isDark ? Colors.white : Colors.black,
                borderRadius: BorderRadius.circular(sw * 0.06),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.grey[300]!,
                ),
                boxShadow: isDark
                    ? null
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb,
                        color: Colors.orange,
                        size: sw * 0.05,
                      ),
                      SizedBox(width: sw * 0.02),
                      Text(
                        'ai_suggestion'.i18n(),
                        style: TextStyle(
                          fontSize: sw * 0.04,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.black : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: sh * 0.015),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(sw * 0.03),
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(sw * 0.025),
                    ),
                    child: Text(
                      'logo_suggestion'.i18n(),
                      style: TextStyle(
                        fontSize: sw * 0.032,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),

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
                        'Generate ⚡ ${(_replicateService.logoModel?.creditUsed ?? 0)}'.i18n(),
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
              ? Colors.orange.withOpacity(0.1)
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
                          : Border.all(color: Colors.grey[200]!, width: sw * 0.005),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(sw * 0.06),
                      child: CachedNetworkImage(
                        imageUrl: _generatedLogos[index],
                        fit: BoxFit.contain,
                        placeholder: (context, url) => Center(
                          child: CircularProgressIndicator(strokeWidth: sw * 0.005),
                        ),
                        errorWidget: (c, e, s) =>
                            const Icon(Icons.logo_dev_outlined),
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
                  'enhance'.i18n(),
                  isDark,
                  () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UpscalePage(
                        initialImageUrl: _generatedLogos[_selectedLogoIndex],
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
                  're_edit'.i18n(),
                  isDark,
                  () => setState(() => _pageState = _PageState.selection),
                ),
              ),
              SizedBox(width: sw * 0.02),
              Expanded(
                child: _actionButton(
                  context,
                  Icons.refresh,
                  'try_again'.i18n(),
                  isDark,
                  () => _generateLogo(),
                ),
              ),
            ],
          ),

          SizedBox(height: sh * 0.03),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: sh * 0.02),
              decoration: ProGradientDecoration(
                borderRadius: BorderRadius.all(Radius.circular(sw * 0.08)),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.file_download_outlined, color: Colors.white),
                    SizedBox(width: sw * 0.02),
                    Text(
                      'download'.i18n(),
                      style: const TextStyle(
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
            onPressed: () {},
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
                  'share'.i18n(),
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
