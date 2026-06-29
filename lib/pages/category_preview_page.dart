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
    return Scaffold(
      backgroundColor: Colors.black, // Immersive preview
      body: PageView.builder(
        controller: _pageController,
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
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
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

    return Stack(
      fit: StackFit.expand,
      children: [
        // Media Layer
        if (videoUrl != null && videoUrl!.isNotEmpty)
          ReelVideoPlayer(
            videoUrl: videoUrl!,
            seamlessLoop: true,
            mute: false,
            placeholder: (imageUrl != null && imageUrl!.isNotEmpty)
                ? SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.only(top: h * 0.1),
                      child: CachedNetworkImage(
                        imageUrl: imageUrl!,
                        fit: BoxFit.contain,
                        alignment: Alignment.topCenter,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.error_outline, color: Colors.white),
                      ),
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
          )
        else if (imageUrl != null && imageUrl!.isNotEmpty)
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.only(top: h * 0.1),
              child: CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.error_outline, color: Colors.white),
              ),
            ),
          )
        else
          const Center(child: Icon(Icons.broken_image, color: Colors.white)),

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
                colors: [Colors.black.withOpacity(0.6), Colors.transparent],
              ),
            ),
          ),
        ),

        // Back Button
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 10,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),

        // Bottom Info & Button
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.9), Colors.transparent],
              ),
            ),
            padding: EdgeInsets.fromLTRB(w * 0.05, 0, w * 0.05, w * 0.08),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null && title!.isNotEmpty) ...[
                  Text(
                    title!,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: w * 0.06,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: h * 0.008),
                ],
                if (prompt != null && prompt!.isNotEmpty) ...[
                  Text(
                    'Prompt',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: w * 0.035,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: h * 0.005),
                  Text(
                    useTwoStage ? (videoPrompt ?? prompt!) : prompt!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white, fontSize: w * 0.04),
                  ),
                  SizedBox(height: h * 0.042),
                ] else
                  SizedBox(height: h * 0.02),
                SizedBox(
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
              ],
            ),
          ),
        ),
      ],
    );
  }
}
