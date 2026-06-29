import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:trail_ai_app/Core/colors.dart';
import 'package:trail_ai_app/Core/gradient.dart';
import 'package:trail_ai_app/Core/strings.dart'; // non-translatable
import 'package:localization/localization.dart';
import 'package:trail_ai_app/Widgets/topbar.dart';
import 'package:trail_ai_app/Services/replicate_service.dart';
import 'package:trail_ai_app/Services/credit_service.dart';
import 'package:trail_ai_app/Services/ad_service.dart';
import 'package:trail_ai_app/Services/generation_gate.dart';
import 'package:trail_ai_app/pages/ai_loading_screen.dart';
import 'package:trail_ai_app/pages/ai_result_screen.dart';
import 'package:trail_ai_app/Helpers/image_picker_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;
import 'package:trail_ai_app/Services/content_safety_service.dart';
import 'package:trail_ai_app/Helpers/error_dialog_helper.dart';

// ── Page state ─────────────────────────────────────────────────────────────
enum _PageState { selection, loading, result }

class OutfitChangePage extends StatefulWidget {
  const OutfitChangePage({super.key});

  @override
  State<OutfitChangePage> createState() => _OutfitChangePageState();
}

class _OutfitChangePageState extends State<OutfitChangePage>
    with SingleTickerProviderStateMixin {
  // ── Services ───────────────────────────────────────────────────────────────
  final CreditService _creditService = CreditService();
  final ReplicateService _replicateService = ReplicateService();
  final AdService _adService = AdService();

  // ── Selection state ────────────────────────────────────────────────────────
  File? _selectedImage;
  List<String> categories = [];
  Map<String, List<Reference>> _categoryToRefs = {};
  Map<String, List<String>> _categoryToUrls = {};
  List<Reference> _outfitRefs = [];
  List<String> _outfitUrls = [];
  int _selectedCategoryIndex = 0;
  int _selectedOutfitIndex = 0;
  bool _isLoadingOutfits = false;
  bool _isLoadingCategories = true;

  // ── Page state ─────────────────────────────────────────────────────────────
  _PageState _pageState = _PageState.selection;
  String? _generatedImageUrl;

  // ── Progress animation ─────────────────────────────────────────────────────
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _replicateService.initialize().then((_) {
      if (mounted) setState(() {});
    });
    _fetchCategories();

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

  Future<void> _fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
      _isLoadingOutfits = true;
    });
    try {
      final result = await FirebaseStorage.instance.ref('Outfits').listAll();
      final folderNames = result.prefixes.map((ref) => ref.name).toList();

      Map<String, List<Reference>> refsMap = {};
      Map<String, List<String>> urlsMap = {};

      if (folderNames.isNotEmpty) {
        // 1. Fetch ONLY the first category completely to immediately unblock the UI
        final firstCat = folderNames.first;
        final firstCatResult = await FirebaseStorage.instance
            .ref('Outfits/$firstCat')
            .listAll();
        final firstRefs = firstCatResult.items;
        final firstUrls = await _runWithConcurrencyLimit<String, Reference>(
          items: firstRefs,
          concurrency: 5,
          worker: (ref) async {
            try {
              return await ref.getDownloadURL().timeout(
                const Duration(seconds: 10),
                onTimeout: () => '',
              );
            } catch (_) {
              return '';
            }
          },
        );

        final List<Reference> validFirstRefs = [];
        final List<String> validFirstUrls = [];
        for (int i = 0; i < firstRefs.length; i++) {
          if (firstUrls[i].isNotEmpty) {
            validFirstRefs.add(firstRefs[i]);
            validFirstUrls.add(firstUrls[i]);
          }
        }

        refsMap[firstCat] = validFirstRefs;
        urlsMap[firstCat] = validFirstUrls;

        if (mounted) {
          setState(() {
            categories = folderNames;
            _categoryToRefs = refsMap;
            _categoryToUrls = urlsMap;

            _selectedCategoryIndex = 0;
            _outfitRefs = validFirstRefs;
            _outfitUrls = validFirstUrls;

            _isLoadingCategories = false;
            _isLoadingOutfits = false; // UI is instantly ready!
          });
        }

        // 2. Fetch all other categories concurrently in the background
        final remainingCategories = folderNames.skip(1).toList();
        if (remainingCategories.isNotEmpty) {
          await Future.wait(
            remainingCategories.map((category) async {
              try {
                final catResult = await FirebaseStorage.instance
                    .ref('Outfits/$category')
                    .listAll();
                final refs = catResult.items;
                final urls = await _runWithConcurrencyLimit<String, Reference>(
                  items: refs,
                  concurrency: 5,
                  worker: (ref) async {
                    try {
                      return await ref.getDownloadURL().timeout(
                        const Duration(seconds: 10),
                        onTimeout: () => '',
                      );
                    } catch (_) {
                      return '';
                    }
                  },
                );

                final List<Reference> validRefs = [];
                final List<String> validUrls = [];
                for (int i = 0; i < refs.length; i++) {
                  if (urls[i].isNotEmpty) {
                    validRefs.add(refs[i]);
                    validUrls.add(urls[i]);
                  }
                }

                if (mounted) {
                  setState(() {
                    _categoryToRefs[category] = validRefs;
                    _categoryToUrls[category] = validUrls;
                    // Live-update the UI if the user already clicked this background-loading category
                    if (categories[_selectedCategoryIndex] == category) {
                      _outfitRefs = validRefs;
                      _outfitUrls = validUrls;
                    }
                  });
                }
              } catch (e) {
                debugPrint('Error fetching background category $category: $e');
              }
            }),
          );
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingCategories = false;
            _isLoadingOutfits = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching catalog: $e');
      if (mounted) {
        setState(() {
          _isLoadingCategories = false;
          _isLoadingOutfits = false;
        });
      }
    }
  }

  // ── Image pick ─────────────────────────────────────────────────────────────

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

  Future<void> _generateOutfit() async {
    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('please_upload_photo_first'.i18n())),
      );
      return;
    }
    if (_replicateService.clothModel == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('app_config_not_ready'.i18n())));
      return;
    }
    if (_outfitRefs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('select_category_with_outfits'.i18n())),
      );
      return;
    }



    // 1. Enter Loading State FIRST
    setState(() => _pageState = _PageState.loading);
    _progressController.forward(from: 0);

    // 2. Check GenerationGate (shows ads or paywall)
    final cost = _replicateService.clothModel?.creditUsed ?? 50;
    final canProceed = await GenerationGate.check(
      context: context,
      adService: _adService,
      creditService: _creditService,
      creditCost: cost,
    );
    if (!canProceed) {
      _progressController.stop();
      if (mounted) setState(() => _pageState = _PageState.selection);
      return;
    }

    try {
      final outfitLabel = _outfitRefs[_selectedOutfitIndex].name;
      final prompt =
          'A person wearing ${categories[_selectedCategoryIndex]} style $outfitLabel';

      final outfitRef = _outfitRefs[_selectedOutfitIndex];
      final outfitUrl = await outfitRef.getDownloadURL();
      final response = await http.get(Uri.parse(outfitUrl));
      if (response.statusCode != 200) {
        throw Exception('Failed to download the selected outfit.');
      }

      final originalName = outfitRef.name;
      final extension = originalName.contains('.')
          ? originalName.split('.').last
          : 'png';
      final tempDir = Directory.systemTemp;
      final tempFile = File(
        '${tempDir.path}/outfit_${DateTime.now().millisecondsSinceEpoch}.$extension',
      );
      await tempFile.writeAsBytes(response.bodyBytes);

      final resultUrl = await _replicateService.generateContent(
        modelConfig: _replicateService.clothModel!,
        prompt: prompt,
        images: [_selectedImage!, tempFile],
      );

      await _creditService.deductCredits(cost);

      if (mounted) {
        _progressController.stop();
        setState(() {
          _generatedImageUrl = resultUrl;
          _pageState = _PageState.result;
        });
      }
    } catch (e) {
      if (mounted) {
        _progressController.stop();
        setState(() => _pageState = _PageState.selection);
        if (e is NsfwContentException) {
          ErrorDialogHelper.showRestrictedContentDialog(context, messageKey: e.messageKey);
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  // ── Shared top bar (back + title/subtitle + close) ─────────────────────────

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
          Column(
            children: [
              Text(
                'outfit_change_title'.i18n(),
                style: TextStyle(
                  fontSize: sw * 0.048,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor(isDark),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: sw * 0.032,
                  color: AppColors.secondaryTextColor(isDark),
                ),
              ),
            ],
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(isDark),
      body: SafeArea(
        child: Column(
          children: [
            // Credits top bar
            const TopBar(),

            // Navigation bar (changes subtitle per state)
            _buildTopBar(
              isDark: isDark,
              subtitle: switch (_pageState) {
                _PageState.loading => 'outfit_processing_subtitle'.i18n(),
                _PageState.result => 'outfit_result_subtitle'.i18n(),
                _PageState.selection => 'outfit_selection_subtitle'.i18n(),
              },
              onBack: switch (_pageState) {
                _PageState.loading => () {
                  _progressController.stop();
                  setState(() => _pageState = _PageState.selection);
                },
                _PageState.result => () => setState(
                  () => _pageState = _PageState.selection,
                ),
                _PageState.selection => null, // defaults to Navigator.pop
              },
            ),

            // Page body — swap between the three screens
            Expanded(
              child: switch (_pageState) {
                _PageState.loading => AILoadingScreen(
                  selectedImage: _selectedImage,
                  progressAnimation: _progressAnimation,
                  aiTips: AppStrings.outfitAiTips.map((e) => e.i18n()).toList(),
                  processingTitle: 'processing_title'.i18n(),
                  applyingText: 'applying_outfit'.i18n(),
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
                      _generateOutfit,
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

  // ── Selection body ─────────────────────────────────────────────────────────

  Widget _buildSelectionBody(bool isDark) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return SingleChildScrollView(
      child: Column(
        children: [
          // Image Preview
          Container(
            margin: EdgeInsets.all(sw * 0.04),
            height: sh * 0.32,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(sw * 0.06),
              color: AppColors.tileBackgroundColor(isDark),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(sw * 0.06),
              child: _selectedImage != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(_selectedImage!, fit: BoxFit.contain),
                      ],
                    )
                  : Center(
                      child: Icon(
                        Icons.person_outline,
                        size: sw * 0.25,
                        color: AppColors.iconColor(
                          isDark,
                        ).withValues(alpha: 0.3),
                      ),
                    ),
            ),
          ),

          // Upload Button
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: sw * 0.04),
              padding: EdgeInsets.symmetric(vertical: sh * 0.022),
              decoration: BoxDecoration(
                color: AppColors.tileBackgroundColor(isDark),
                borderRadius: BorderRadius.circular(sw * 0.05),
                border: Border.all(
                  color: AppColors.creditsCardBorder(
                    isDark,
                  ).withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.upload, color: AppColors.textColor(isDark)),
                  SizedBox(width: sw * 0.03),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'upload_photo_title'.i18n(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textColor(isDark),
                          fontSize: sw * 0.04,
                        ),
                      ),
                      Text(
                        'upload_photo_desc'.i18n(),
                        style: TextStyle(
                          fontSize: sw * 0.03,
                          color: AppColors.secondaryTextColor(isDark),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: sh * 0.02),

          // Categories
          _isLoadingCategories
              ? const Center(child: CircularProgressIndicator())
              : categories.isEmpty
              ? Center(
                  child: Text(
                    'no_categories_found'.i18n(),
                    style: TextStyle(color: AppColors.textColor(isDark)),
                  ),
                )
              : SizedBox(
                  height: sh * 0.05,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: sw * 0.03),
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final isSelected = _selectedCategoryIndex == index;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            final selectedCat = categories[index];
                            _selectedCategoryIndex = index;
                            _selectedOutfitIndex = 0;
                            _outfitRefs = _categoryToRefs[selectedCat] ?? [];
                            _outfitUrls = _categoryToUrls[selectedCat] ?? [];
                          });
                        },
                        child: Container(
                          margin: EdgeInsets.symmetric(horizontal: sw * 0.01),
                          padding: EdgeInsets.symmetric(horizontal: sw * 0.05),
                          decoration: isSelected
                              ? ProGradientDecoration(
                                  borderRadius: BorderRadius.circular(
                                    sw * 0.05,
                                  ),
                                )
                              : BoxDecoration(
                                  color: AppColors.tileBackgroundColor(isDark),
                                  borderRadius: BorderRadius.circular(
                                    sw * 0.05,
                                  ),
                                  border: Border.all(
                                    color: AppColors.creditsCardBorder(isDark),
                                  ),
                                ),
                          alignment: Alignment.center,
                          child: Text(
                            categories[index],
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.secondaryTextColor(isDark),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: sw * 0.035,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

          SizedBox(height: sh * 0.02),

          // Outfits Grid
          _isLoadingOutfits
              ? const Center(child: CircularProgressIndicator())
              : _outfitRefs.isEmpty
              ? Center(
                  child: Text(
                    'no_outfits_found'.i18n(),
                    style: TextStyle(color: AppColors.textColor(isDark)),
                  ),
                )
              : SizedBox(
                  height: (sw * 0.3) * 2 + (sw * 0.03),
                  child: GridView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: sw * 0.04),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: sw * 0.03,
                      mainAxisSpacing: sw * 0.03,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: _outfitRefs.length,
                    itemBuilder: (context, index) {
                      final isSelected = _selectedOutfitIndex == index;
                      return GestureDetector(
                        onTap: () =>
                            setState(() => _selectedOutfitIndex = index),
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.tileBackgroundColor(isDark),
                                borderRadius: BorderRadius.circular(sw * 0.06),
                                border: Border.all(
                                  color: AppColors.creditsCardBorder(isDark),
                                  width: sw * 0.002,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(sw * 0.06),
                                child: CachedNetworkImage(
                                  imageUrl: _outfitUrls[index],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  placeholder: (context, url) => Center(
                                    child: SizedBox(
                                      width: sw * 0.05,
                                      height: sw * 0.05,
                                      child: CircularProgressIndicator(
                                        strokeWidth: sw * 0.005,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.error_outline),
                                ),
                              ),
                            ),
                            if (isSelected)
                              ShaderMask(
                                blendMode: BlendMode.srcIn,
                                shaderCallback: (bounds) => AppGradients
                                    .proGradient
                                    .createShader(bounds),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      sw * 0.06,
                                    ),
                                    border: Border.all(
                                      color: Colors.white,
                                      width: sw * 0.008,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

          SizedBox(height: sh * 0.04),

          // Create Button
          Padding(
            padding: EdgeInsets.symmetric(horizontal: sw * 0.04),
            child: GestureDetector(
              onTap: _generateOutfit,
              child: Container(
                width: double.infinity,
                height: sh * 0.07,
                decoration: ProGradientDecoration(
                  borderRadius: BorderRadius.all(Radius.circular(sw * 0.07)),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'create'.i18n(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: sw * 0.045,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: sw * 0.02),
                      Icon(Icons.bolt, color: Colors.white, size: sw * 0.05),
                      Text(
                        '${_replicateService.clothModel?.creditUsed ?? 0}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: sw * 0.045,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: sh * 0.025),
        ],
      ),
    );
  }

  /// Runs a list of async workers with a concurrency limit.
  Future<List<T>> _runWithConcurrencyLimit<T, Y>({
    required List<Y> items,
    required Future<T> Function(Y item) worker,
    required int concurrency,
  }) async {
    if (items.isEmpty) return [];

    final List<T?> results = List<T?>.filled(items.length, null);
    int nextIndex = 0;

    Future<void> runWorker() async {
      while (nextIndex < items.length) {
        final index = nextIndex++;
        results[index] = await worker(items[index]);
      }
    }

    final futures = <Future<void>>[];
    final activeWorkers = concurrency < items.length
        ? concurrency
        : items.length;
    for (int i = 0; i < activeWorkers; i++) {
      futures.add(runWorker());
    }

    await Future.wait(futures);
    return results.cast<T>();
  }
}
