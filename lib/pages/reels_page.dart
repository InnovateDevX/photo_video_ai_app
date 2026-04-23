import 'package:flutter/material.dart';
import 'package:trail_ai_app/Models/reel.dart';
import 'package:trail_ai_app/Services/reel_service.dart';
import 'package:trail_ai_app/Widgets/reel_video_player.dart';
import 'package:trail_ai_app/pages/generation_page.dart';
import 'package:trail_ai_app/Services/auth_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trail_ai_app/Core/gradient.dart';
import 'package:localization/localization.dart';

class ReelsPage extends StatefulWidget {
  const ReelsPage({super.key});

  @override
  State<ReelsPage> createState() => _ReelsPageState();
}

class _ReelsPageState extends State<ReelsPage> {
  final ReelService _reelService = ReelService();
  final AuthService _authService = AuthService();

  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_authService.currentUser == null) {
      return Center(child: Text('sign_in_to_view_gallery'.i18n()));
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: StreamBuilder<List<Reel>>(
        stream: _reelService.getReelsStream(),
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
                    size: MediaQuery.of(context).size.width * 0.15,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                  Text(
                    'no_reels_found'.i18n(),
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
            itemCount: reels.length,
            itemBuilder: (context, index) {
              return ReelItemWidget(
                reel: reels[index],
                reelService: _reelService,
              );
            },
          );
        },
      ),
    );
  }
}

class ReelItemWidget extends StatelessWidget {
  final Reel reel;
  final ReelService reelService;

  const ReelItemWidget({
    super.key,
    required this.reel,
    required this.reelService,
  });

  void _useTemplate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GenerationPage(
          initialPrompt: reel.videoPrompt,
          initialCategory: reel.imageEdit ? 'image' : reel.type,
          initialIsEditable: reel.isEditable,
          imageEditMode: reel.imageEdit,
          imagePrompt: reel.imagePrompt,
          videoPrompt: reel.videoPrompt,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background Video
        ReelVideoPlayer(videoUrl: reel.videoUrl),

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
          bottom: sh * 0.1, // Responsively positioned above bottom bar
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
                  'craft_masterpiece'.i18n(),
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
                        'use_template'.i18n(),
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
                icon: Icons.download_outlined,
                label: 'share_action'.i18n(),
                onTap: () {
                  Share.share("${'share_message'.i18n()} ${reel.videoUrl}");
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
    return StreamBuilder<bool>(
      stream: reelService.isReelLiked(reel.id),
      builder: (context, snapshot) {
        final isLiked = snapshot.data ?? false;
        return _ActionButton(
          icon: isLiked ? Icons.favorite : Icons.favorite_outline,
          color: isLiked ? Colors.red : Colors.white,
          label: _formatCount(reel.likesCount),
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
    return StreamBuilder<bool>(
      stream: reelService.isReelSaved(reel.id),
      builder: (context, snapshot) {
        final isSaved = snapshot.data ?? false;
        return _ActionButton(
          icon: isSaved ? Icons.bookmark : Icons.bookmark_outline,
          color: isSaved ? Colors.yellow : Colors.white,
          label: _formatCount(reel.savedCount),
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
          const SizedBox(height: 4),
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
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}k';
  }
  return count.toString();
}
