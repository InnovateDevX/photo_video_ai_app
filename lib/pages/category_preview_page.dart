import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trail_ai_app/Widgets/reel_video_player.dart';
import 'package:trail_ai_app/pages/generation_page.dart';
import 'package:trail_ai_app/Services/replicate_service.dart';
import 'package:trail_ai_app/Models/category_image.dart';
import 'package:trail_ai_app/Models/reel.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:trail_ai_app/Services/data_service.dart';
import 'package:trail_ai_app/Core/colors.dart';

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

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
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
        itemBuilder: (context, index) {
          final item = widget.items[index];
          return _PreviewPageItem(item: item);
        },
      ),
    );
  }
}

class _PreviewPageItem extends StatefulWidget {
  final dynamic item;

  const _PreviewPageItem({required this.item});

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

  @override
  void initState() {
    super.initState();
    _resolveItemProperties();
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

      if (reelId != null) {
        // We need to fetch the reel from Firestore to get full details (like videoUrl if missing, or imageEditMode)
        try {
          final reelDoc = await FirebaseFirestore.instance
              .collection('reels')
              .doc(reelId)
              .get();
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
    final iconColor = AppColors.iconColor(isDark);

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: textColor),
      );
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
        final match = allModels.where((m) => m.id == modelId || m.name.toLowerCase() == modelId!.toLowerCase());
        if (match.isNotEmpty) imgCost = match.first.creditUsed;
      }
      if (videoModelId != null && videoModelId!.isNotEmpty) {
        final match = allModels.where((m) => m.id == videoModelId || m.name.toLowerCase() == videoModelId!.toLowerCase());
        if (match.isNotEmpty) vidCost = match.first.creditUsed;
      }
      
      if (imgCost == 0 && replicateService.imageModels.isNotEmpty) imgCost = replicateService.imageModels.first.creditUsed;
      if (vidCost == 0 && replicateService.videoModels.isNotEmpty) vidCost = replicateService.videoModels.first.creditUsed;
      
      creditCost = imgCost + vidCost;
    } else {
      final relevantModelId = (type == 'video' && videoModelId != null && videoModelId!.isNotEmpty) ? videoModelId : modelId;
      if (relevantModelId != null && relevantModelId.isNotEmpty) {
        final match = allModels.where((m) => m.id == relevantModelId || m.name.toLowerCase() == relevantModelId.toLowerCase());
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
                  fit: BoxFit.contain,
                  placeholder: (imageUrl != null && imageUrl!.isNotEmpty)
                      ? SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: EdgeInsets.only(top: h * 0.02),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl!,
                              fit: BoxFit.contain,
                              alignment: Alignment.topCenter,
                              placeholder: (context, url) => Center(
                                child: CircularProgressIndicator(color: textColor),
                              ),
                              errorWidget: (context, url, error) =>
                                  Icon(Icons.error_outline, color: textColor),
                            ),
                          ),
                        )
                      : Center(
                          child: CircularProgressIndicator(color: textColor),
                        ),
                )
              else if (imageUrl != null && imageUrl!.isNotEmpty)
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: EdgeInsets.only(top: h * 0.02),
                    child: CachedNetworkImage(
                      imageUrl: imageUrl!,
                      fit: BoxFit.contain,
                      alignment: Alignment.topCenter,
                      placeholder: (context, url) => Center(
                        child: CircularProgressIndicator(color: textColor),
                      ),
                      errorWidget: (context, url, error) =>
                          Icon(Icons.error_outline, color: textColor),
                    ),
                  ),
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
                        isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.9),
                        Colors.transparent
                      ],
                    ),
                  ),
                ),
              ),

              // Swipe Text Box
              Positioned(
                top: MediaQuery.of(context).padding.top + 15,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.05),
                      border: Border.all(color: isDark ? Colors.white24 : Colors.black12, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.swipe, color: secondaryTextColor, size: 16),
                        SizedBox(width: MediaQuery.of(context).size.width * 0.02),
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
          decoration: BoxDecoration(
            color: AppColors.backgroundColor(isDark),
          ),
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
              if (prompt != null && prompt!.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(w * 0.03),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(w * 0.02),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Prompt',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: w * 0.035,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: h * 0.005),
                      Text(
                        useTwoStage ? (videoPrompt ?? prompt!) : prompt!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textColor, fontSize: w * 0.04),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: h * 0.042),
              ] else
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
                            initialCategory: useTwoStage
                                ? 'video'
                                : (type ?? 'image'),
                            initialPrompt: useTwoStage
                                ? videoPrompt
                                : (type == 'video' && videoPrompt != null
                                      ? videoPrompt
                                      : prompt ?? ''),
                            initialModelId: useTwoStage
                                ? videoModelId
                                : (type == 'video' && videoModelId != null
                                      ? videoModelId
                                      : modelId),
                            initialIsEditable: isEditable,
                            imageEditMode: useTwoStage,
                            imagePrompt: prompt ?? '',
                            videoPrompt: videoPrompt ?? '',
                            initialImageUrl: type == 'video' ? videoUrl : imageUrl,
                            initialImageModelId: useTwoStage ? modelId : null,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'Try this style ⚡ $creditCost',
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
