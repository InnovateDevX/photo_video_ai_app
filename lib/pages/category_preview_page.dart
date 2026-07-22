import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:vidzeon/Widgets/firebase_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vidzeon/Widgets/reel_video_player.dart';
import 'package:vidzeon/pages/generation_page.dart';
import 'package:vidzeon/Services/replicate_service.dart';
import 'package:vidzeon/Models/category_image.dart';
import 'package:vidzeon/Models/reel.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:vidzeon/Services/data_service.dart';
import 'package:vidzeon/Core/colors.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class CategoryPreviewPage extends StatefulWidget {
  final List<dynamic> items;
  final int initialIndex;

  const CategoryPreviewPage({
    super.key,
    required this.items,
    this.initialIndex = 0,
  });

  @override
  State<CategoryPreviewPage> createState() => _CategoryPreviewPageState();
}

class _CategoryPreviewPageState extends State<CategoryPreviewPage> {
  late PageController _pageController;
  bool _hasSwiped = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    _checkSwipeStatus();
  }

  Future<void> _checkSwipeStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _hasSwiped = prefs.getBool('has_swiped_category_preview') ?? false;
      });
    }
  }

  void _onPageChanged(int index) async {
    if (!_hasSwiped) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_swiped_category_preview', true);
      if (mounted) {
        setState(() {
          _hasSwiped = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppColors.backgroundColor(isDark), // Immersive preview
      body: PageView.builder(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.items.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          return _PreviewPageItem(item: item, hideSwipeText: _hasSwiped);
        },
      ),
    );
  }
}

class _PreviewPageItem extends StatefulWidget {
  final dynamic item;
  final bool hideSwipeText;

  const _PreviewPageItem({required this.item, this.hideSwipeText = false});

  @override
  State<_PreviewPageItem> createState() => _PreviewPageItemState();
}

class _PreviewPageItemState extends State<_PreviewPageItem> {
  bool _isLoading = true;
  String? title;
  String? imageUrl;
  String? videoUrl;
  String? prompt;
  String? modelId;
  String? videoPrompt;
  String? videoModelId;
  String? type;
  bool isEditable = false;
  bool imageEditMode = false;
  int noOfUploadable = 1;
  List<String>? imageUrls;
  late PageController _imagePageController;
  Timer? _slideshowTimer;
  int _currentImageIndex = 0;
  bool _localHideSwipeText = false;
  String? categoryName;

  @override
  void initState() {
    super.initState();
    _localHideSwipeText = widget.hideSwipeText;
    _imagePageController = PageController();
    _resolveItemProperties();
  }

  @override
  void didUpdateWidget(covariant _PreviewPageItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hideSwipeText != oldWidget.hideSwipeText) {
      _localHideSwipeText = widget.hideSwipeText;
    }
  }

  @override
  void dispose() {
    _slideshowTimer?.cancel();
    _imagePageController.dispose();
    super.dispose();
  }

  void _startSlideshow() {
    if (imageUrls != null && imageUrls!.length > 1) {
      _slideshowTimer = Timer.periodic(const Duration(milliseconds: 1500), (
        timer,
      ) {
        if (mounted && _imagePageController.hasClients) {
          int nextIndex = (_currentImageIndex + 1) % imageUrls!.length;
          _imagePageController.animateToPage(
            nextIndex,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }

  Future<void> _resolveItemProperties() async {
    final item = widget.item;

    if (item is Reference) {
      try {
        final url = DataService().getCachedURL(item);
        if (mounted) {
          setState(() {
            imageUrl = url;
            type = 'image';
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    } else if (item is CategoryImage) {
      title = item.title;
      prompt = item.prompt;
      modelId = item.modelUsed;
      videoPrompt = item.videoPrompt;
      videoModelId = item.videoModelUsed;
      type = item.type;
      isEditable = item.isEditable;
      noOfUploadable = item.noOfUploadable;
      categoryName = item.categoryName;

      final reelId = item.reelId;

      if (type == 'video' && item.videoUrl == null) {
        if (item.imageUrl.endsWith('.mp4')) {
          videoUrl = item.imageUrl;
        } else {
          imageUrl = item.thumbnailUrl ?? item.imageUrl;
        }
      } else {
        imageUrl = item.imageUrl;
        videoUrl = item.videoUrl;
      }

      imageUrls = item.imageUrls;
      if (imageUrls != null && imageUrls!.length > 1) {
        _startSlideshow();
        // Pre-cache subsequent images for smoother transitions
        for (int i = 1; i < imageUrls!.length; i++) {
          final url = sanitizeFirebaseUrl(imageUrls![i]);
          DefaultCacheManager()
              .downloadFile(url)
              .catchError(
                (_) => DefaultCacheManager().getFileStream(url).first,
              );
        }
      }

      if (reelId != null) {
        // We need to fetch the reel from Firestore to get full details (like videoUrl if missing, or imageEditMode)
        try {
          final reelDoc = await FirebaseFirestore.instanceFor(
            app: Firebase.app(),
            databaseId: 'default',
          ).collection('reels').doc(reelId).get();
          if (reelDoc.exists && mounted) {
            final reel = Reel.fromFirestore(reelDoc.id, reelDoc.data()!);
            setState(() {
              imageUrl = reel.thumbnailUrl;
              videoUrl = reel.videoUrl;
              prompt = reel.imagePrompt.isNotEmpty
                  ? reel.imagePrompt
                  : reel.videoPrompt;
              videoPrompt = reel.videoPrompt;
              type = 'video';
              imageEditMode = reel.imageEdit;
              _isLoading = false;
            });
            return;
          }
        } catch (e) {
          debugPrint('Error fetching reel for preview item: $e');
        }
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } else {
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
    final textColor = AppColors.textColor(isDark);
    final secondaryTextColor = AppColors.secondaryTextColor(isDark);

    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: textColor));
    }

    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    // Check if this should trigger the two-stage pipeline
    final bool useTwoStage =
        (imageEditMode || isEditable) &&
        (prompt != null && prompt!.isNotEmpty) &&
        (videoPrompt != null && videoPrompt!.isNotEmpty);

    // Calculate dynamic credit cost
    final replicateService = ReplicateService();
    int creditCost = 0;

    final allModels = [
      ...replicateService.imageModels,
      ...replicateService.videoModels,
    ];

    if (useTwoStage) {
      int imgCost = 0;
      int vidCost = 0;

      if (modelId != null && modelId!.isNotEmpty) {
        final match = allModels.where(
          (m) =>
              m.id == modelId || m.name.toLowerCase() == modelId!.toLowerCase(),
        );
        if (match.isNotEmpty) imgCost = match.first.creditUsed;
      }
      if (videoModelId != null && videoModelId!.isNotEmpty) {
        final match = allModels.where(
          (m) =>
              m.id == videoModelId ||
              m.name.toLowerCase() == videoModelId!.toLowerCase(),
        );
        if (match.isNotEmpty) vidCost = match.first.creditUsed;
      }

      if (imgCost == 0 && replicateService.imageModels.isNotEmpty) {
        imgCost = replicateService.imageModels.first.creditUsed;
      }
      if (vidCost == 0 && replicateService.videoModels.isNotEmpty) {
        vidCost = replicateService.videoModels.first.creditUsed;
      }

      creditCost = imgCost + vidCost;
    } else {
      final relevantModelId =
          (type == 'video' && videoModelId != null && videoModelId!.isNotEmpty)
          ? videoModelId
          : modelId;
      if (relevantModelId != null && relevantModelId.isNotEmpty) {
        final match = allModels.where(
          (m) =>
              m.id == relevantModelId ||
              m.name.toLowerCase() == relevantModelId.toLowerCase(),
        );
        if (match.isNotEmpty) {
          creditCost = match.first.creditUsed;
        }
      }
      if (creditCost == 0) {
        if (type == 'video') {
          creditCost = replicateService.videoModels.isNotEmpty
              ? replicateService.videoModels.first.creditUsed
              : 0;
        } else {
          creditCost = replicateService.imageModels.isNotEmpty
              ? replicateService.imageModels.first.creditUsed
              : 0;
        }
      }
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Media Layer
              if (videoUrl != null && videoUrl!.isNotEmpty)
                ReelVideoPlayer(
                  videoUrl: videoUrl!,
                  seamlessLoop: true,
                  mute: false,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  placeholder: (imageUrl != null && imageUrl!.isNotEmpty)
                      ? SizedBox.expand(
                          child: FirebaseImage(
                            url: imageUrl!,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            isDark: isDark,
                          ),
                        )
                      : Center(
                          child: CircularProgressIndicator(color: textColor),
                        ),
                )
              else if (imageUrls != null && imageUrls!.length > 1)
                Stack(
                  fit: StackFit.expand,
                  children: [
                    NotificationListener<ScrollNotification>(
                      onNotification: (ScrollNotification notification) {
                        if (notification is UserScrollNotification) {
                          _slideshowTimer?.cancel();
                          _slideshowTimer = null;
                          if (!_localHideSwipeText) {
                            SharedPreferences.getInstance().then((prefs) {
                              prefs.setBool(
                                'has_swiped_category_preview',
                                true,
                              );
                            });
                            setState(() {
                              _localHideSwipeText = true;
                            });
                          }
                        }
                        return false;
                      },
                      child: PageView.builder(
                        controller: _imagePageController,
                        physics: const BouncingScrollPhysics(),
                        itemCount: imageUrls!.length,
                        onPageChanged: (index) {
                          setState(() {
                            _currentImageIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          return FirebaseImage(
                            url: imageUrls![index],
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            isDark: isDark,
                          );
                        },
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(imageUrls!.length, (index) {
                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4.0),
                            width: _currentImageIndex == index ? 8.0 : 6.0,
                            height: _currentImageIndex == index ? 8.0 : 6.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentImageIndex == index
                                  ? (isDark ? Colors.white : Colors.black)
                                  : (isDark ? Colors.white38 : Colors.black38),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                )
              else if (imageUrl != null && imageUrl!.isNotEmpty)
                FirebaseImage(
                  url: imageUrl!,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  isDark: isDark,
                )
              else
                Center(child: Icon(Icons.broken_image, color: textColor)),

              // Top gradient for back button visibility
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: h * 0.15,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        isDark
                            ? Colors.black.withValues(alpha: 0.6)
                            : Colors.white.withValues(alpha: 0.9),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Swipe Text Box
              if (!_localHideSwipeText)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 15,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.4)
                            : Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(
                          MediaQuery.of(context).size.width * 0.05,
                        ),
                        border: Border.all(
                          color: isDark ? Colors.white24 : Colors.black12,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.swipe,
                            color: secondaryTextColor,
                            size: 16,
                          ),
                          SizedBox(
                            width: MediaQuery.of(context).size.width * 0.02,
                          ),
                          Text(
                            'Swipe left or right to see more',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // Back Button
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 10,
                child: IconButton(
                  icon: Icon(Icons.arrow_back_ios_new, color: textColor),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),

        // Bottom Info & Button
        Container(
          decoration: BoxDecoration(color: AppColors.backgroundColor(isDark)),
          padding: EdgeInsets.fromLTRB(w * 0.05, h * 0.02, w * 0.05, w * 0.08),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (title != null && title!.isNotEmpty) ...[
                Text(
                  title!,
                  style: TextStyle(
                    color: textColor,
                    fontSize: w * 0.06,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: h * 0.008),
              ],
              SizedBox(height: h * 0.02),
              SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: h * 0.065,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF9800), // App orange
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(w * 0.03),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GenerationPage(
                            showCategoryToggle: false,
                            initialCategory: (videoUrl != null && videoUrl!.isNotEmpty)
                                ? 'video'
                                : (useTwoStage
                                    ? 'video'
                                    : (type ?? 'image')),
                            initialPrompt: useTwoStage
                                ? videoPrompt
                                : ((type == 'video' || (videoUrl != null && videoUrl!.isNotEmpty)) && videoPrompt != null && videoPrompt!.isNotEmpty
                                      ? videoPrompt
                                      : prompt ?? ''),
                            initialModelId: useTwoStage
                                ? videoModelId
                                : ((type == 'video' || (videoUrl != null && videoUrl!.isNotEmpty)) && videoModelId != null && videoModelId!.isNotEmpty
                                      ? videoModelId
                                      : modelId),
                            initialIsEditable: isEditable,
                            imageEditMode: useTwoStage,
                            imagePrompt: prompt ?? '',
                            videoPrompt: videoPrompt ?? '',
                            initialImageUrl: (videoUrl != null && videoUrl!.isNotEmpty)
                                ? videoUrl
                                : (type == 'video' ? videoUrl : imageUrl),
                            initialImageModelId: useTwoStage ? modelId : null,
                            sourceCategoryName: categoryName,
                            noOfUploadable: noOfUploadable,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'Try this style',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: w * 0.045,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
