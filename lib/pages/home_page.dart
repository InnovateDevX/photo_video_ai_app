import 'package:trail_ai_app/Models/category_image.dart';
import 'package:trail_ai_app/Models/reel.dart';
import 'package:trail_ai_app/Widgets/topbar.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trail_ai_app/Services/remote_config_service.dart';
import 'package:trail_ai_app/Services/thumbnail_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:trail_ai_app/pages/generation_page.dart';

import 'package:trail_ai_app/pages/trending_see_all_page.dart';
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import 'package:localization/localization.dart';
import '../Core/directory.dart';
import '../Core/routes.dart';
import '../Core/gradient.dart';
import '../Core/colors.dart';
import '../Services/credit_service.dart';
import '../Services/data_service.dart';
import '../Widgets/main_navigation.dart';
import '../Widgets/ai_tools_grid.dart';

// ── Per-category gallery state controller ────────────────────────────────────
class _CategoryGalleryController {
  final List<dynamic> items = []; // Can be Reference or CategoryImage
  bool isLoading = false;
  bool hasMore = true;
  final ScrollController scrollController = ScrollController();

  void dispose() => scrollController.dispose();
}

// ── Sticky Header Delegate for Categories ────────────────────────────────────
class _StickyCategoryDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickyCategoryDelegate({required this.child, required this.height});

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return child;
  }

  @override
  bool shouldRebuild(_StickyCategoryDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  final ValueNotifier<int> _selectedCategoryIndex = ValueNotifier<int>(0);
  List<String> categories = [];

  // --- Trending 1 Pagination State ---
  final int _pageSize = 10;
  final List<Reference> _trendingItems = [];
  String? _trendingNextPageToken;
  bool _isLoadingTrending = false;
  bool _hasMoreTrending = true;
  final ScrollController _trendingScrollController = ScrollController();

  // --- Per-category gallery controllers ---
  final Map<String, _CategoryGalleryController> _categoryControllers = {};
  final Map<String, GlobalKey> _categoryKeys = {};

  final ScrollController _mainScrollController = ScrollController();
  final ScrollController _categoryTabScrollController = ScrollController();
  bool _isAutoScrolling = false;

  @override
  void initState() {
    super.initState();
    CreditService().initialize();

    final dataService = DataService();
    if (dataService.categories.isNotEmpty) {
      categories = List.from(dataService.categories);
      _initializeCategoryMeta();
    } else {
      _fetchCategories();
    }

    if (dataService.trendingItems.isNotEmpty) {
      _trendingItems.addAll(dataService.trendingItems);
    } else {
      _fetchTrendingPage();
    }

    _trendingScrollController.addListener(() {
      if (_trendingScrollController.position.pixels >=
          _trendingScrollController.position.maxScrollExtent - 200) {
        _fetchTrendingPage();
      }
    });

    _mainScrollController.addListener(_onMainScroll);

    _selectedCategoryIndex.addListener(_scrollToActiveTab);
  }

  void _scrollToActiveTab() {
    if (_categoryTabScrollController.hasClients) {
      // Approximate position: each chip is roughly 100-120px wide
      final double targetOffset = _selectedCategoryIndex.value * 110.0;
      final double viewportWidth = MediaQuery.of(context).size.width;

      // Center the chip
      final double centeredOffset = targetOffset - (viewportWidth / 2) + 55.0;

      _categoryTabScrollController.animateTo(
        centeredOffset.clamp(
          0.0,
          _categoryTabScrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _onMainScroll() {
    if (_isAutoScrolling || categories.isEmpty) return;

    int? activeIndex;
    double minDistance = double.infinity;

    // The threshold is the top of the viewport plus the sticky header height
    final double threshold =
        MediaQuery.of(context).padding.top +
        (MediaQuery.of(context).size.height * 0.15);

    for (int i = 0; i < categories.length; i++) {
      final key = _categoryKeys[categories[i]];
      if (key == null) continue;

      final context = key.currentContext;
      if (context == null) continue;

      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null) continue;

      // Get the position of the section relative to the screen
      final position = renderBox.localToGlobal(Offset.zero).dy;

      // We want the category that is closest to our threshold (the top of the list area)
      final distance = (position - threshold).abs();

      if (position < threshold + 100 && distance < minDistance) {
        minDistance = distance;
        activeIndex = i;
      }
    }

    if (activeIndex != null && activeIndex != _selectedCategoryIndex.value) {
      _selectedCategoryIndex.value = activeIndex;
    }
  }

  void _initializeCategoryMeta() {
    for (var cat in categories) {
      _categoryKeys[cat] = GlobalKey();
      // REMOVED: _loadCategoryIfNeeded(cat); - Now loading on-demand in build
    }
  }

  @override
  void dispose() {
    _trendingScrollController.dispose();
    _mainScrollController.dispose();
    _categoryTabScrollController.dispose();
    _selectedCategoryIndex.dispose();
    for (final ctrl in _categoryControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  // ── Trending ───────────────────────────────────────────────────────────────

  Future<void> _fetchTrendingPage() async {
    if (_isLoadingTrending || !_hasMoreTrending) return;
    setState(() => _isLoadingTrending = true);

    try {
      final options = ListOptions(
        maxResults: _pageSize,
        pageToken: _trendingNextPageToken,
      );
      final listResult = await FirebaseStorage.instance
          .ref(AppDirectories.trendingDirectory)
          .list(options);

      if (mounted) {
        setState(() {
          _trendingItems.addAll(listResult.items);
          DataService().updateTrendingCache(_trendingItems);
          if (listResult.nextPageToken != null) {
            _trendingNextPageToken = listResult.nextPageToken;
          } else {
            _hasMoreTrending = false;
          }
        });
      }
    } catch (e) {
      debugPrint('Error fetching trending: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Trending Error: ${e.toString().replaceAll('com.google.firebase.storage.', '')}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
            action: SnackBarAction(
              label: 'Dismiss',
              onPressed: () {},
              textColor: Colors.white,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingTrending = false);
    }
  }

  // ── Categories ────────────────────────────────────────────────────────────

  Future<void> _fetchCategories() async {
    try {
      final config = RemoteConfigService();
      await config.initialize();

      final categoriesJson = config.categoriesJson;
      if (categoriesJson.isEmpty || categoriesJson == '[]') return;

      final List<dynamic> parsedCategories = json.decode(categoriesJson);

      if (mounted) {
        setState(() {
          categories = parsedCategories.cast<String>();
          DataService().categories = categories;
          _initializeCategoryMeta();
        });
      }
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  // ── Per-category gallery ──────────────────────────────────────────────────

  _CategoryGalleryController _controllerFor(String category) {
    if (!_categoryControllers.containsKey(category)) {
      final ctrl = _CategoryGalleryController();
      _categoryControllers[category] = ctrl;

      ctrl.scrollController.addListener(() {
        if (ctrl.scrollController.position.pixels >=
            ctrl.scrollController.position.maxScrollExtent - 200) {
          _loadCategoryIfNeeded(category);
        }
      });

      final cached = DataService().categoryItems[category];
      if (cached != null && cached.isNotEmpty) {
        ctrl.items.addAll(cached);
        ctrl.hasMore = DataService().hasCategoryMore(category);
      }
    }
    return _categoryControllers[category]!;
  }

  Future<void> _loadCategoryIfNeeded(String category) async {
    final ctrl = _controllerFor(category);

    // If we have structured data for this category, we don't need to fetch from Storage
    if (DataService().categoryData.isNotEmpty) {
      final structuredImages = DataService().getCategoryImages(category);
      if (structuredImages.isNotEmpty && ctrl.items.isEmpty) {
        setState(() {
          ctrl.items.addAll(structuredImages);
          ctrl.hasMore = false; // Structured data is loaded all at once for now
        });
        return;
      }
      if (structuredImages.isNotEmpty) return;
    }

    if (ctrl.isLoading ||
        !ctrl.hasMore ||
        DataService().isCategoryFailed(category)) {
      return;
    }

    setState(() => ctrl.isLoading = true);

    try {
      final newItems = await DataService().fetchCategoryPage(category);
      if (mounted) {
        setState(() {
          ctrl.items.addAll(newItems);
          ctrl.hasMore = DataService().hasCategoryMore(category);
        });
      }
    } finally {
      if (mounted) setState(() => ctrl.isLoading = false);
    }
  }

  void _onCategoryTapped(int index) async {
    _isAutoScrolling = true;
    _selectedCategoryIndex.value = index;
    final category = categories[index];

    final key = _categoryKeys[category];
    if (key != null && key.currentContext != null) {
      await Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
        alignment: 0.1, // Scroll so the section is near the top
      );
    } else {
      // The category widget hasn't been built yet because of lazy loading.
      // Perform a seamless continuous scroll to quickly glide down or up and locate it.
      await _findAndScrollToCategory(index, category);
    }

    // Give it a small delay to ensure physics have settled before re-enabling listener
    await Future.delayed(const Duration(milliseconds: 100));
    _isAutoScrolling = false;
  }

  Future<void> _findAndScrollToCategory(
    int targetIndex,
    String category,
  ) async {
    final h = MediaQuery.of(context).size.height;
    // Estimate target offset to determine which direction we need to search
    final estimatedOffset = (h * 0.45) + (targetIndex * h * 0.42);

    int maxAttempts = 20;

    while (_categoryKeys[category]?.currentContext == null && maxAttempts > 0) {
      maxAttempts--;

      final currentMax = _mainScrollController.position.maxScrollExtent;
      final currentMin = _mainScrollController.position.minScrollExtent;
      final currentOffset = _mainScrollController.offset;
      final isScrollingDown = estimatedOffset > currentOffset;

      if (isScrollingDown) {
        // Stop if we hit the absolute bottom and it's still not expanding
        if (currentOffset >= currentMax && maxAttempts < 19) break;

        await _mainScrollController.animateTo(
          (currentOffset + h * 1.2).clamp(0.0, currentMax),
          duration: const Duration(milliseconds: 100),
          curve: Curves.linear,
        );
      } else {
        // Stop if we hit the absolute top
        if (currentOffset <= currentMin && maxAttempts < 19) break;

        await _mainScrollController.animateTo(
          (currentOffset - h * 1.2).clamp(currentMin, currentMax),
          duration: const Duration(milliseconds: 100),
          curve: Curves.linear,
        );
      }
    }

    // Now that the widget is forced into the tree, gently decelerate and snap to its exact position.
    final exactKey = _categoryKeys[category];
    if (exactKey != null && exactKey.currentContext != null) {
      await Scrollable.ensureVisible(
        exactKey.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final h = MediaQuery.of(context).size.height;
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(isDark),
      body: SafeArea(
        child: CustomScrollView(
          controller: _mainScrollController,
          slivers: [
            // --- Top Bar ---
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.only(top: h * 0.01, bottom: h * 0.02),
                child: const TopBar(),
              ),
            ),

            // --- Trending Banner ---
            SliverToBoxAdapter(
              child: SizedBox(
                height: h * 0.18,
                child: _trendingItems.isEmpty && _isLoadingTrending
                    ? _buildShimmerLoading(isDark, w, h)
                    : _trendingItems.isEmpty
                    ? const Center(child: Text('No images found'))
                    : ListView.builder(
                        controller: _trendingScrollController,
                        scrollDirection: Axis.horizontal,
                        padding: EdgeInsets.symmetric(horizontal: w * 0.04),
                        itemCount:
                            _trendingItems.length + (_hasMoreTrending ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _trendingItems.length) {
                            return Padding(
                              padding: EdgeInsets.all(w * 0.02),
                              child: _buildSingleShimmerBlock(
                                isDark,
                                width: w * 0.3,
                              ),
                            );
                          }
                          return Container(
                            margin: EdgeInsets.only(right: w * 0.03),
                            child: trendingView(context, _trendingItems[index]),
                          );
                        },
                      ),
              ),
            ),

            SliverToBoxAdapter(child: SizedBox(height: h * 0.03)),

            // --- Quick AI Tools ---
            SliverToBoxAdapter(child: _buildQuickAiTools(context, isDark)),

            // --- Sticky Category Chips ---
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickyCategoryDelegate(
                height: h * 0.085,
                child: Container(
                  color: AppColors.backgroundColor(isDark),
                  alignment: Alignment.center,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _selectedCategoryIndex,
                    builder: (context, selectedIndex, _) {
                      return ListView.builder(
                        controller: _categoryTabScrollController,
                        padding: EdgeInsets.symmetric(horizontal: w * 0.04),
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: EdgeInsets.only(right: w * 0.025),
                            child: categoryChip(
                              label: categories[index],
                              isSelected: selectedIndex == index,
                              onTap: () => _onCategoryTapped(index),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),

            // --- Lazy Loaded Category Galleries ---
            if (categories.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(w * 0.05),
                  child: _buildShimmerLoading(isDark, w, h),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final category = categories[index];
                  return _buildCategorySection(category, isDark, h, w);
                }, childCount: categories.length),
              ),

            SliverToBoxAdapter(child: SizedBox(height: h * 0.05)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(
    String category,
    bool isDark,
    double h,
    double w,
  ) {
    final ctrl = _controllerFor(category);

    // TRIGGER: Load data only when the section is built and empty.
    // Wrap in a conditional to prevent flooding the post-frame queue on every scroll event.
    if (ctrl.items.isEmpty &&
        !ctrl.isLoading &&
        ctrl.hasMore &&
        !DataService().isCategoryFailed(category)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCategoryIfNeeded(category);
      });
    }

    return Padding(
      key: _categoryKeys[category],
      padding: EdgeInsets.only(top: h * 0.035),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.symmetric(horizontal: w * 0.05),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  category,
                  style: TextStyle(
                    fontSize: w * 0.048,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textColor(isDark),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            TrendingSeeAllPage(categoryName: category),
                      ),
                    );
                  },
                  child: Text(
                    'see_all'.i18n(),
                    style: TextStyle(
                      fontSize: w * 0.034,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFF9800),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: h * 0.02),

          // Horizontal Gallery
          SizedBox(
            height: h * 0.32,
            child: ctrl.items.isEmpty && ctrl.isLoading
                ? _buildShimmerLoading(isDark, w, h)
                : ctrl.items.isEmpty
                ? Center(
                    child: Text(
                      'No images in "$category"',
                      style: TextStyle(
                        color: AppColors.secondaryTextColor(isDark),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: ctrl.scrollController,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: w * 0.04),
                    itemCount: ctrl.items.length + (ctrl.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == ctrl.items.length) {
                        return Padding(
                          padding: EdgeInsets.all(w * 0.02),
                          child: _buildSingleShimmerBlock(
                            isDark,
                            width: w * 0.45,
                          ),
                        );
                      }
                      return Container(
                        margin: EdgeInsets.only(right: w * 0.035),
                        child: trendingView2(context, ctrl.items[index]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Chip helper ───────────────────────────────────────────────────────────

  Widget categoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: w * 0.06,
            vertical: h * 0.012,
          ),
          decoration: isSelected
              ? ProGradientDecoration(
                  borderRadius: BorderRadius.circular(w * 0.06),
                )
              : BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(w * 0.06),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? Colors.white : AppColors.textColor(isDark),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: w * 0.038,
            ),
          ),
        ),
      ),
    );
  }

  // ── Shimmer Helpers ────────────────────────────────────────────────────────

  Widget _buildShimmerLoading(bool isDark, double w, double h) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: w * 0.02),
      itemCount: 4,
      itemBuilder: (context, index) => Padding(
        padding: EdgeInsets.only(right: w * 0.02),
        child: _buildSingleShimmerBlock(isDark, width: w * 0.35),
      ),
    );
  }

  Widget _buildSingleShimmerBlock(bool isDark, {required double width}) {
    final baseColor = isDark ? Colors.grey[850]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: double.infinity,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(width * 0.1),
        ),
      ),
    );
  }
}

// ── Quick AI Tools widget ─────────────────────────────────────────────────────

Widget _buildQuickAiTools(BuildContext context, bool isDark) {
  final w = MediaQuery.of(context).size.width;
  final h = MediaQuery.of(context).size.height;

  final tools = [
    AiTool(
      'tool_upscale'.i18n(),
      AppDirectories.iconUpscale,
      route: AppRoutes.upscale,
    ),
    AiTool('tool_re_edit'.i18n(), AppDirectories.iconReEdit),
    AiTool('tool_ai_image'.i18n(), AppDirectories.iconAiImage),
    AiTool(
      'tool_ai_video'.i18n(),
      AppDirectories.iconAiVideo,
      initialCategory: 'video',
    ),
    AiTool(
      'tool_cloth'.i18n(),
      AppDirectories.iconCloth,
      route: AppRoutes.outfitChange,
    ),
    AiTool(
      'tool_bg_ai'.i18n(),
      AppDirectories.iconBgAi,
      route: AppRoutes.background,
    ),
  ];

  return Padding(
    padding: EdgeInsets.symmetric(horizontal: w * 0.05),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'quick_ai_tools'.i18n(),
              style: TextStyle(
                fontSize: w * 0.046,
                fontWeight: FontWeight.bold,
                color: AppColors.textColor(isDark),
              ),
            ),
            GestureDetector(
              onTap: () {
                final navState = context
                    .findAncestorStateOfType<MainNavigationState>();
                if (navState != null) {
                  navState.switchTab(5);
                } else {
                  Navigator.pushNamed(context, AppRoutes.allTools);
                }
              },
              child: Text(
                'see_all'.i18n(),
                style: TextStyle(
                  fontSize: w * 0.036,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFF9800),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: h * 0.018),
        AiToolsGrid(
          tools: tools,
          isDark: isDark,
          crossAxisCount: 3,
          childAspectRatio: 2.1,
          mainAxisSpacing: h * 0.012,
        ),
        SizedBox(height: h * 0.025),
      ],
    ),
  );
}

// ── Image tile widgets ────────────────────────────────────────────────────────

Widget trendingView(BuildContext context, Reference ref) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final w = MediaQuery.of(context).size.width;
  final cachedUrl = DataService().getCachedURL(ref);

  Widget buildImage(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(w * 0.04),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, url) => Shimmer.fromColors(
          baseColor: isDark ? Colors.grey[850]! : Colors.grey[300]!,
          highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
          child: Container(color: Colors.white),
        ),
        errorWidget: (context, url, error) => const Icon(Icons.error_outline),
      ),
    );
  }

  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GenerationPage()),
      );
    },
    child: cachedUrl != null
        ? buildImage(cachedUrl)
        : FutureBuilder<String>(
            future: DataService().getDownloadURL(ref),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(strokeWidth: w * 0.005),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const Icon(Icons.broken_image, color: Colors.grey);
              }
              return buildImage(snapshot.data!);
            },
          ),
  );
}

Widget trendingView2(BuildContext context, dynamic item) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final w = MediaQuery.of(context).size.width;

  String? imageUrl;
  String? prompt;
  String? modelId;
  String? type;
  String? reelId;

  if (item is Reference) {
    imageUrl = DataService().getCachedURL(item);
  } else if (item is CategoryImage) {
    prompt = item.prompt;
    modelId = item.modelUsed;
    reelId = item.reelId;
    type = item.type;

    if (reelId != null) {
      imageUrl = item.thumbnailUrl;
      type = 'video';
    } else {
      imageUrl = item.type == 'video' ? item.thumbnailUrl : item.imageUrl;
    }
  }

  Widget buildImage(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(w * 0.05),
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, url) => Shimmer.fromColors(
          baseColor: isDark ? Colors.grey[850]! : Colors.grey[300]!,
          highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
          child: Container(color: Colors.white),
        ),
        errorWidget: (context, url, error) => const Icon(Icons.error_outline),
      ),
    );
  }

  // Handle video tap - fetch reel from Firestore and navigate
  void handleVideoTap() async {
    if (item is CategoryImage && reelId != null) {
      try {
        final reelDoc = await FirebaseFirestore.instance
            .collection('reels')
            .doc(reelId)
            .get();

        if (reelDoc.exists && context.mounted) {
          final reel = Reel.fromFirestore(reelDoc.id, reelDoc.data()!);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GenerationPage(
                initialCategory: 'video',
                initialPrompt: reel.videoPrompt,
                imageEditMode: reel.imageEdit,
                imagePrompt: reel.imagePrompt,
                videoPrompt: reel.videoPrompt,
              ),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error fetching reel: $e');
      }
    }
  }

  // If we have a reelId but no imageUrl, we need to fetch the reel and generate thumbnail
  if (item is CategoryImage &&
      reelId != null &&
      (imageUrl == null || imageUrl.isEmpty)) {
    return _ReelThumbnailWidget(
      reelId: reelId,
      videoUrl: item.imageUrl.isNotEmpty
          ? item.imageUrl
          : null, // Pass the URL from the JSON so we can start immediately
      isDark: isDark,
      w: w,
      onTap: () => handleVideoTap(),
    );
  }

  return GestureDetector(
    onTap: () {
      if (item is CategoryImage) {
        if (reelId != null) {
          handleVideoTap();
        } else {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => GenerationPage(
                initialCategory: type ?? 'image',
                initialPrompt: prompt ?? '',
                initialModelId: modelId,
              ),
            ),
          );
        }
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const GenerationPage()),
        );
      }
    },
    child: imageUrl != null
        ? buildImage(imageUrl)
        : (item is Reference
              ? FutureBuilder<String>(
                  future: DataService().getDownloadURL(item),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          strokeWidth: w * 0.005,
                        ),
                      );
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return const Icon(Icons.broken_image, color: Colors.grey);
                    }
                    return buildImage(snapshot.data!);
                  },
                )
              : const Icon(Icons.broken_image, color: Colors.grey)),
  );
}

/// Widget that fetches reel from Firestore and generates thumbnail if needed
class _ReelThumbnailWidget extends StatefulWidget {
  final String reelId;
  final String?
  videoUrl; // Optional: if we have it already, we can skip fetching Firestore for the thumbnail
  final bool isDark;
  final double w;
  final VoidCallback onTap;

  const _ReelThumbnailWidget({
    required this.reelId,
    this.videoUrl,
    required this.isDark,
    required this.w,
    required this.onTap,
  });

  @override
  State<_ReelThumbnailWidget> createState() => _ReelThumbnailWidgetState();
}

class _ReelThumbnailWidgetState extends State<_ReelThumbnailWidget> {
  String? _thumbnailUrl;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  Future<void> _loadThumbnail() async {
    debugPrint(
      '🔄 [_ReelThumbnailWidget] Initializing for reel: ${widget.reelId}',
    );

    // If we already have the videoUrl, we can start generating immediately
    if (widget.videoUrl != null &&
        widget.videoUrl!.isNotEmpty &&
        widget.videoUrl!.startsWith('http')) {
      _generateFromUrl(widget.videoUrl!);
    }

    try {
      final reelDoc = await FirebaseFirestore.instance
          .collection('reels')
          .doc(widget.reelId)
          .get();

      if (!reelDoc.exists) {
        if (mounted) {
          setState(() {
            _error = 'Reel not found';
            _isLoading = false;
          });
        }
        return;
      }

      final reel = Reel.fromFirestore(reelDoc.id, reelDoc.data()!);
      debugPrint(
        '🔄 [_ReelThumbnailWidget] Reel fetched: ${reel.id}, Type: ${reel.type}',
      );

      // Check if videoUrl is actually a video file
      final isVideoFile =
          reel.videoUrl.toLowerCase().contains('.mp4') ||
          reel.videoUrl.toLowerCase().contains('.mov') ||
          reel.videoUrl.toLowerCase().contains('.webm');

      // If it's an image reel AND the videoUrl is NOT a video file, use it directly
      // Otherwise, generate a thumbnail from the video
      if (reel.type == 'image' && !isVideoFile) {
        debugPrint(
          '🔄 [_ReelThumbnailWidget] Image reel detected, using videoUrl as thumbnail.',
        );
        if (mounted) {
          setState(() {
            debugPrint(
              '[DEBUG] Setting thumbnailUrl: ${reel.videoUrl}, isLoading: false',
            );
            _thumbnailUrl = reel.videoUrl;
            _isLoading = false;
          });
        }
        return;
      }

      // If we don't have a thumbnail yet and weren't already generating from the passed URL
      if (reel.thumbnailUrl == null &&
          (_thumbnailUrl == null || !_thumbnailUrl!.startsWith('http'))) {
        _generateFromUrl(reel.videoUrl);
      } else if (reel.thumbnailUrl != null) {
        if (mounted) {
          setState(() {
            _thumbnailUrl = reel.thumbnailUrl;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ [_ReelThumbnailWidget] Error loading thumbnail: $e');
      if (mounted && _thumbnailUrl == null) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _generateFromUrl(String url) async {
    try {
      // Create a temporary reel object for the service
      final tempReel = Reel(id: widget.reelId, videoUrl: url, videoPrompt: '');

      final uid = FirebaseAuth.instance.currentUser?.uid;
      final generatedUrl = await ThumbnailService().processReelThumbnail(
        tempReel,
        uid,
      );

      if (mounted && generatedUrl != null) {
        debugPrint(
          '🔄 [_ReelThumbnailWidget] Thumbnail process complete. URL: $generatedUrl',
        );
        setState(() {
          _thumbnailUrl = generatedUrl;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [_ReelThumbnailWidget] Error generating from URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: widget.w * 0.45,
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.grey[850] : Colors.grey[300],
            borderRadius: BorderRadius.circular(widget.w * 0.05),
          ),
          child: Center(
            child: CircularProgressIndicator(
              strokeWidth: widget.w * 0.005,
              color: widget.isDark ? Colors.white70 : Colors.grey[600],
            ),
          ),
        ),
      );
    }

    if (_error != null || _thumbnailUrl == null) {
      return GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: widget.w * 0.45,
          decoration: BoxDecoration(
            color: widget.isDark ? Colors.grey[850] : Colors.grey[300],
            borderRadius: BorderRadius.circular(widget.w * 0.05),
          ),
          child: const Center(
            child: Icon(Icons.videocam_off, color: Colors.grey),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.w * 0.05),
        child: CachedNetworkImage(
          imageUrl: _thumbnailUrl!,
          fit: BoxFit.cover,
          placeholder: (context, url) => Shimmer.fromColors(
            baseColor: widget.isDark ? Colors.grey[850]! : Colors.grey[300]!,
            highlightColor: widget.isDark
                ? Colors.grey[700]!
                : Colors.grey[100]!,
            child: Container(color: Colors.white),
          ),
          errorWidget: (context, url, error) => const Icon(Icons.error_outline),
        ),
      ),
    );
  }
}
