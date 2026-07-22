import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:vidzeon/Models/reel.dart';
import 'package:vidzeon/Services/reel_service.dart';
import 'package:vidzeon/Widgets/reel_video_player.dart';
import 'package:vidzeon/pages/generation_page.dart';
import 'package:vidzeon/Services/auth_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:vidzeon/Core/gradient.dart';
import 'package:vidzeon/Widgets/firebase_image.dart';

import 'package:vidzeon/Services/replicate_service.dart';

class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key});

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  final ReelService _reelService = ReelService();
  final AuthService _authService = AuthService();

  late PageController _pageController;
  late Future<List<Reel>> _reelsFuture;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    // Cache the future so it doesn't restart on every rebuild
    _reelsFuture = _reelService.getReels();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<List<Reel>>(
        future: _reelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.video_library_outlined,
                    size: MediaQuery.of(context).size.width * 0.12,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  Text(
                    'No reels found',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              ),
            );
          }

          final reels = snapshot.data!;

          return PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(),
            itemCount: reels.length,
            onPageChanged: (index) {
              setState(() => _currentPage = index);
              // Preload the next reel's video into cache for instant swipe
              if (index + 1 < reels.length) {
                DefaultCacheManager()
                    .getSingleFile(reels[index + 1].videoUrl)
                    .then(
                      (_) => debugPrint('📦 [Reels] Preloaded next reel video'),
                    )
                    .catchError((_) {});
              }
            },
            itemBuilder: (context, index) {
              return ReelItemWidget(
                reel: reels[index],
                reelService: _reelService,
                isActive: index == _currentPage,
              );
            },
          );
        },
      ),
    );
  }
}

class ReelItemWidget extends StatefulWidget {
  final Reel reel;
  final ReelService reelService;
  final bool isActive;

  const ReelItemWidget({
    super.key,
    required this.reel,
    required this.reelService,
    this.isActive = true,
  });

  @override
  State<ReelItemWidget> createState() => _ReelItemWidgetState();
}

class _ReelItemWidgetState extends State<ReelItemWidget> {
  void _useTemplate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GenerationPage(
          showCategoryToggle: false,
          initialPrompt: widget.reel.videoPrompt,
          initialCategory: widget.reel.imageEdit ? 'image' : widget.reel.type,
          initialIsEditable: widget.reel.isEditable,
          imageEditMode: widget.reel.imageEdit,
          imagePrompt: widget.reel.imagePrompt,
          videoPrompt: widget.reel.videoPrompt,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final reel = widget.reel;
    final reelService = widget.reelService;

    // Calculate dynamic credit cost
    final replicateService = ReplicateService();
    int creditCost = 0;
    if (reel.imageEdit) {
      final imgCost = replicateService.imageModels.isNotEmpty
          ? replicateService.imageModels.first.creditUsed
          : 0;
      final vidCost = replicateService.videoModels.isNotEmpty
          ? replicateService.videoModels.first.creditUsed
          : 0;
      creditCost = imgCost + vidCost;
    } else {
      if (reel.type == 'video') {
        creditCost = replicateService.videoModels.isNotEmpty
            ? replicateService.videoModels.first.creditUsed
            : 0;
      } else {
        creditCost = replicateService.imageModels.isNotEmpty
            ? replicateService.imageModels.first.creditUsed
            : 0;
      }
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        // Only load video player for the active page — prevents resource fight
        // Disable play/pause gesture to allow PageView swipe gestures to work properly
        if (widget.isActive)
          ReelVideoPlayer(
            videoUrl: reel.videoUrl,
            seamlessLoop: true,
            enablePlayPauseGesture: false,
            placeholder: reel.previewUrl.isNotEmpty
                ? SizedBox.expand(
                    child: FirebaseImage(
                      url: reel.previewUrl,
                      fit: BoxFit.cover,
                    ),
                  )
                : null,
          )
        else
          Container(color: Colors.black),

        // Gradient overlay for better text visibility
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: sh * 0.35,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.8),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Bottom Content (Prompt & Button)
        Positioned(
          bottom: sh * 0.16, // Responsively positioned above bottom bar
          left: sw * 0.04,
          right: sw * 0.04,
          child: Container(
            padding: EdgeInsets.all(sw * 0.04),
            decoration: BoxDecoration(
              // Enhanced glassmorphism card effect
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(sw * 0.07),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: sw * 0.0035,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Craft your masterpiece\'s',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: sw * 0.045,
                  ),
                ),
                SizedBox(height: sh * 0.01),
                Text(
                  reel.videoPrompt,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: sw * 0.035,
                    height: 1.4,
                  ),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: sh * 0.025),
                GestureDetector(
                  onTap: () => _useTemplate(context),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: sh * 0.017),
                    decoration: ProGradientDecoration(
                      borderRadius: BorderRadius.all(
                        Radius.circular(sw * 0.06),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        'Use template',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: sw * 0.04,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Side Action Bar
        Positioned(
          top: sh * 0.35, // Responsively centered vertically
          right: sw * 0.03,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LikeButton(reel: reel, reelService: reelService),
              SizedBox(height: sh * 0.03),
              _ActionButton(
                icon: Icons.share_outlined,
                label: 'Share',
                onTap: () {
                  Share.share("Check out this creation! ${reel.videoUrl}");
                },
              ),
              SizedBox(height: sh * 0.03),
              _SaveButton(reel: reel, reelService: reelService),
            ],
          ),
        ),
      ],
    );
  }
}

class _LikeButton extends StatelessWidget {
  final Reel reel;
  final ReelService reelService;

  const _LikeButton({required this.reel, required this.reelService});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder reacts immediately when likedReelsNotifier changes
    return ValueListenableBuilder<List<Reel>>(
      valueListenable: reelService.likedReelsNotifier,
      builder: (context, likedReels, _) {
        final isLiked = likedReels.any((r) => r.id == reel.id);
        return _ActionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_outline,
          color: isLiked ? Colors.red : Colors.white,
          label: _formatCount(reel.likesCount + (isLiked ? 1 : 0)),
          onTap: () {
            if (isLiked) {
              reelService.unlikeReel(reel.id);
            } else {
              reelService.likeReel(reel.id, reel);
            }
          },
        );
      },
    );
  }
}

class _SaveButton extends StatelessWidget {
  final Reel reel;
  final ReelService reelService;

  const _SaveButton({required this.reel, required this.reelService});

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder reacts immediately when savedReelsNotifier changes
    return ValueListenableBuilder<List<Reel>>(
      valueListenable: reelService.savedReelsNotifier,
      builder: (context, savedReels, _) {
        final isSaved = savedReels.any((r) => r.id == reel.id);
        return _ActionButton(
          icon: isSaved ? Icons.bookmark : Icons.bookmark_outline,
          color: isSaved ? Colors.yellow : Colors.white,
          label: _formatCount(reel.savedCount + (isSaved ? 1 : 0)),
          onTap: () {
            if (isSaved) {
              reelService.unsaveReel(reel.id);
            } else {
              reelService.saveReel(reel.id, reel);
            }
          },
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    this.color = Colors.white,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 36),
          SizedBox(height: MediaQuery.of(context).size.height * 0.005),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

String _formatCount(int count) {
  if (count <= 0) return '0';
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M';
  } else if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}K';
  }
  return count.toString();
}
