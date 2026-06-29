import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:trail_ai_app/Models/category_image.dart';
import 'package:trail_ai_app/pages/category_preview_page.dart';
import 'package:trail_ai_app/Services/data_service.dart';
import 'package:trail_ai_app/pages/generation_page.dart';
import '../Core/colors.dart';
import 'settings_page.dart';
import '../Widgets/reel_video_player.dart';

class TrendingSeeAllPage extends StatefulWidget {
  final String? categoryName;

  const TrendingSeeAllPage({super.key, this.categoryName});

  @override
  State<TrendingSeeAllPage> createState() => _TrendingSeeAllPageState();
}

class _TrendingSeeAllPageState extends State<TrendingSeeAllPage> {
  final int _pageSize = 10;
  final List<dynamic> _items = []; // Can be Reference or CategoryImage
  String? _nextPageToken;
  bool _isLoading = false;
  bool _hasMore = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchPage();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        _fetchPage();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchPage() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Simulate network delay to test loading states and stress test smoothly
      await Future.delayed(const Duration(milliseconds: 800));

      List<dynamic> allItems = [];
      if (widget.categoryName != null) {
        allItems = DataService().getCategoryImages(widget.categoryName!);
      } else {
        allItems = DataService().trendingItems;
      }

      // Slice the next chunk of items
      final nextItems = allItems.skip(_items.length).take(_pageSize).toList();

      setState(() {
        _items.addAll(nextItems);
        // We have more items if we haven't reached the total length
        _hasMore = _items.length < allItems.length;
      });
    } catch (e) {
      debugPrint('Error fetching items: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    final title = widget.categoryName ?? 'Nano Banan  Pro';

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(isDark),
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar Area
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: sw * 0.04,
                vertical: sh * 0.015,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Material(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey[200],
                    shape: const CircleBorder(),
                    clipBehavior: Clip.hardEdge,
                    child: InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Padding(
                        padding: EdgeInsets.all(sw * 0.03),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          size: sw * 0.05,
                          color: AppColors.textColor(isDark),
                        ),
                      ),
                    ),
                  ),
                  Material(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.grey[200],
                    shape: const CircleBorder(),
                    clipBehavior: Clip.hardEdge,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsPage(),
                          ),
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.all(sw * 0.03),
                        child: Icon(
                          Icons.settings_outlined,
                          size: sw * 0.05,
                          color: AppColors.textColor(isDark),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Header Content
            SizedBox(height: sh * 0.01),
            Text(
              title,
              style: TextStyle(
                fontSize: sw * 0.065,
                fontWeight: FontWeight.w900,
                color: AppColors.textColor(isDark),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Trending apps now a click\naway',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: sw * 0.038,
                color: AppColors.secondaryTextColor(isDark),
                height: 1.2,
              ),
            ),
            SizedBox(height: sh * 0.035),

            // Grid content
            Expanded(
              child: _items.isEmpty && _isLoading
                  ? _buildShimmerGrid(isDark, sw, sh)
                  : _items.isEmpty
                  ? Center(
                      child: Text(
                        "No items available in $title",
                        style: TextStyle(color: AppColors.textColor(isDark)),
                      ),
                    )
                  : GridView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(horizontal: sw * 0.04),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: sw * 0.04,
                        mainAxisSpacing: sh * 0.02,
                        childAspectRatio: 0.72,
                      ),
                      itemCount: _items.length + (_hasMore ? 2 : 0),
                      itemBuilder: (context, index) {
                        if (index >= _items.length) {
                          return _buildShimmerCard(isDark, sw);
                        }
                        return _TrendingSeeAllCard(
                          items: _items,
                          index: index,
                          isDark: isDark,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Shimmer Loading ---
  Widget _buildShimmerGrid(bool isDark, double sw, double sh) {
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: sw * 0.04),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: sw * 0.04,
        mainAxisSpacing: sh * 0.02,
        childAspectRatio: 0.72,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return _buildShimmerCard(isDark, sw);
      },
    );
  }

  Widget _buildShimmerCard(bool isDark, double sw) {
    final baseColor = isDark ? Colors.grey[850]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(sw * 0.05),
        ),
      ),
    );
  }
}

class _TrendingSeeAllCard extends StatelessWidget {
  final List<dynamic> items;
  final int index;
  final bool isDark;

  const _TrendingSeeAllCard({
    required this.items,
    required this.index,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final item = items[index];
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    String? imageUrl;
    String? videoUrl;
    String? prompt;
    String? modelId;
    String? type;
    String? reelId;
    String? categoryName;

    if (item is Reference) {
      // FutureBuilder will handle the URL fetch
    } else if (item is CategoryImage) {
      prompt = item.prompt;
      modelId = item.modelUsed;
      reelId = item.reelId;
      type = item.type;
      categoryName = item.categoryName;
      videoUrl = item.videoUrl;

      if (type == 'video' && videoUrl == null) {
        if (item.imageUrl.endsWith('.mp4')) {
          videoUrl = item.imageUrl;
        } else {
          imageUrl = item.thumbnailUrl ?? item.imageUrl;
        }
      } else {
        imageUrl = item.imageUrl;
      }
    }

    void handleVideoTap() {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CategoryPreviewPage(items: items, initialIndex: index),
        ),
      );
    }

    Widget buildMedia() {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (item is CategoryImage) {
            if (type == 'category' && categoryName != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      TrendingSeeAllPage(categoryName: categoryName),
                ),
              );
            } else if (reelId != null) {
              handleVideoTap();
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CategoryPreviewPage(items: items, initialIndex: index),
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
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(sw * 0.05),
                child: (videoUrl != null && videoUrl.isNotEmpty)
                    ? ReelVideoPlayer(
                        videoUrl: videoUrl,
                        seamlessLoop: true,
                        enablePlayPauseGesture: false,
                        borderRadius: BorderRadius.circular(sw * 0.05),
                        placeholder: (imageUrl != null && imageUrl.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Shimmer.fromColors(
                                  baseColor: isDark
                                      ? Colors.grey[850]!
                                      : Colors.grey[300]!,
                                  highlightColor: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[100]!,
                                  child: Container(color: Colors.white),
                                ),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.error_outline),
                              )
                            : Shimmer.fromColors(
                                baseColor: isDark
                                    ? Colors.grey[850]!
                                    : Colors.grey[300]!,
                                highlightColor: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey[100]!,
                                child: Container(color: Colors.white),
                              ),
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl ?? '',
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: isDark
                              ? Colors.grey[850]!
                              : Colors.grey[300]!,
                          highlightColor: isDark
                              ? Colors.grey[700]!
                              : Colors.grey[100]!,
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error_outline),
                      ),
              ),
            ),

            // Bottom text with Gradient overlay
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: sh * 0.1,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(sw * 0.05),
                    bottomRight: Radius.circular(sw * 0.05),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                padding: EdgeInsets.all(sw * 0.03),
                alignment: Alignment.bottomLeft,
                child: Text(
                  'GENERATE UNLIMITED\nVIDEOS WITH',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: sw * 0.025,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (item is CategoryImage) {
      return buildMedia();
    }

    return FutureBuilder<String>(
      future: (item as Reference).getDownloadURL(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[200],
              borderRadius: BorderRadius.circular(sw * 0.05),
            ),
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: sw * 0.005,
                color: Colors.orange,
              ),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[200],
              borderRadius: BorderRadius.circular(sw * 0.05),
            ),
            child: Icon(
              Icons.broken_image,
              size: sw * 0.1,
              color: Colors.grey[400],
            ),
          );
        }

        return buildMedia();
      },
    );
  }
}
