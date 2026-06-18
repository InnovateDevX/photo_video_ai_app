import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:localization/localization.dart';
import 'package:trail_ai_app/Core/colors.dart';
import 'package:trail_ai_app/Core/gradient.dart';
import 'package:trail_ai_app/Core/routes.dart';
import 'package:trail_ai_app/Services/profile_service.dart';
import 'package:trail_ai_app/Services/reel_service.dart';
import 'package:trail_ai_app/Services/local_storage_service.dart';
import 'package:trail_ai_app/Models/reel.dart';
import 'package:trail_ai_app/Models/generated_asset.dart';
import 'package:trail_ai_app/pages/edit_profile_page.dart';
import 'package:trail_ai_app/pages/ai_result_screen.dart';
import 'package:trail_ai_app/pages/reels_page.dart';
import 'package:trail_ai_app/Services/thumbnail_service.dart';
import 'package:trail_ai_app/Widgets/profile_header.dart';
import 'package:trail_ai_app/Widgets/stats_row.dart';
import 'package:trail_ai_app/Widgets/pro_pill.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  int _selectedTabIndex = 0; // 0: My Assets, 1: Collections, 2: Liked
  final ProfileService _profileService = ProfileService();
  final ReelService _reelService = ReelService();
  static final _processingIds = <String>{};

  late Stream<List<Reel>> _likedReelsStream;
  late Stream<List<Reel>> _savedReelsStream;

  String? _lastUid;
  bool _streamsInitialized = false;
  StreamSubscription<User?>? _authSubscription;

  void _ensureStreamsInitialized(String? currentUid) {
    if (!_streamsInitialized || _lastUid != currentUid) {
      debugPrint(
        '🔄 [ProfilePage] UID changed or first run. Re-initializing streams for: $currentUid',
      );
      setState(() {
        _lastUid = currentUid;
        // Use local notifier streams — no Firebase needed
        _likedReelsStream = Stream.value(_reelService.likedReelsNotifier.value);
        _savedReelsStream = Stream.value(_reelService.savedReelsNotifier.value);
        _streamsInitialized = true;
      });
    }
  }

  /// Force refresh the streams from local notifiers
  void _refreshStreams() {
    debugPrint(
      '🔄 [ProfilePage] Refreshing streams for tab $_selectedTabIndex',
    );
    setState(() {
      _likedReelsStream = Stream.value(_reelService.likedReelsNotifier.value);
      _savedReelsStream = Stream.value(_reelService.savedReelsNotifier.value);
    });
  }

  @override
  void initState() {
    super.initState();
    // Initial setup
    _ensureStreamsInitialized(FirebaseAuth.instance.currentUser?.uid);

    // Listen for auth changes (Login/Logout)
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        _ensureStreamsInitialized(user?.uid);
      }
    });

    // Pre-fetch reels on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _reelService.fetchSavedReelsOnce();
      _reelService.fetchLikedReelsOnce();
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    final user = FirebaseAuth.instance.currentUser;
    _ensureStreamsInitialized(user?.uid);

    final isGuest = user == null || user.isAnonymous;

    return StreamBuilder<Map<String, dynamic>?>(
      stream: _profileService.getProfileStream(user?.uid ?? ''),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final userName = profile?['displayName'] ?? user?.displayName;
        final displayName =
            (userName != null && userName.toString().trim().isNotEmpty)
            ? userName.toString()
            : 'guest'.i18n();

        final handle = profile != null && profile['username'] != null
            ? '@${profile['username']}'
            : '@${displayName.toLowerCase().replaceAll(' ', '')}';

        final rawBio = profile?['bio'] ?? '';
        final bio = rawBio.isNotEmpty
            ? rawBio
            : 'default_bio'.i18n([displayName]);
        final photoUrl = profile?['photoUrl'] ?? user?.photoURL;

        return Scaffold(
          backgroundColor: AppColors.backgroundColor(isDark),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Header with Gradient and Avatar
                ProfileHeader(
                  w: w,
                  h: h,
                  isDark: isDark,
                  displayName: displayName,
                  handle: handle,
                  bio: bio,
                  photoUrl: photoUrl,
                  isGuest: isGuest,
                  proPill: ProPill(w: w, h: h, isDark: isDark),
                ),

                SizedBox(height: h * 0.03),

                // Stats Row
                StatsRow(
                  w: w,
                  h: h,
                  isDark: isDark,
                  savedReelsStream: _savedReelsStream,
                  likedReelsStream: _likedReelsStream,
                ),

                SizedBox(height: h * 0.03),

                // Edit / Log In Button
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: w * 0.05),
                  child: Row(
                    children: [
                      if (!isGuest)
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      EditProfilePage(initialProfile: profile),
                                ),
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: h * 0.02),
                              decoration: ProGradientDecoration(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(w * 0.08),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'edit_profile_button'.i18n(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: w * 0.04,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (isGuest)
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                Navigator.pushNamed(context, AppRoutes.login),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: h * 0.02),
                              decoration: ProGradientDecoration(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(w * 0.08),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  'login_button_label'.i18n(),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: w * 0.04,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                SizedBox(height: h * 0.03),

                // Tabs
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: w * 0.05),
                  child: Row(
                    children: [
                      _buildTab(0, 'my_assets_tab'.i18n(), w, h, isDark),
                      SizedBox(width: w * 0.06),
                      _buildTab(1, 'collections_tab'.i18n(), w, h, isDark),
                      SizedBox(width: w * 0.06),
                      _buildTab(2, 'liked_tab'.i18n(), w, h, isDark),
                    ],
                  ),
                ),

                SizedBox(height: h * 0.02),

                // Grid Content
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: w * 0.05),
                  child: _selectedTabIndex == 0
                      ? _buildPersistentAssetsGrid(w, h, isDark)
                      : _buildReelsGrid(
                          w,
                          h,
                          isDark,
                          _selectedTabIndex == 1
                              ? _savedReelsStream
                              : _likedReelsStream,
                        ),
                ),

                SizedBox(height: h * 0.15),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPersistentAssetsGrid(double w, double h, bool isDark) {
    return ValueListenableBuilder<List<GeneratedAsset>>(
      valueListenable: LocalStorageService().assetsNotifier,
      builder: (context, assets, child) {
        if (assets.isEmpty) {
          return Padding(
            padding: EdgeInsets.only(top: h * 0.05),
            child: Text(
              "no_generated_assets".i18n(),
              style: TextStyle(
                color: AppColors.textColor(isDark).withValues(alpha: 0.6),
                fontSize: w * 0.04,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: w * 0.03,
            mainAxisSpacing: w * 0.03,
            childAspectRatio: 0.9,
          ),
          itemCount: assets.length,
          itemBuilder: (context, index) {
            final asset = assets[index];
            final file = File(asset.filePath);

            if (asset.category == 'video' &&
                asset.thumbnailPath == null &&
                !_processingIds.contains(asset.id)) {
              _processingIds.add(asset.id);
              ThumbnailService().processGeneratedAsset(asset);
            }

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (innerContext) => Scaffold(
                      backgroundColor: AppColors.backgroundColor(isDark),
                      appBar: AppBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        leading: IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new,
                            color: AppColors.textColor(isDark),
                          ),
                          onPressed: () => Navigator.pop(innerContext),
                        ),
                        title: Text(
                          'result_appbar_title'.i18n(),
                          style: TextStyle(color: AppColors.textColor(isDark)),
                        ),
                      ),
                      body: SafeArea(
                        child: AIResultScreen(resultImageUrl: asset.filePath),
                      ),
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.profileGridItemBackground(isDark),
                  borderRadius: BorderRadius.circular(w * 0.03),
                  border: Border.all(
                    color: AppColors.profileGridItemBorder(isDark),
                    width: w * 0.003,
                  ),
                ),
                clipBehavior: Clip.hardEdge,
                child: !file.existsSync()
                    ? Icon(
                        Icons.broken_image,
                        color: AppColors.textColor(isDark).withValues(alpha: 0.5),
                      )
                    : asset.category == 'image'
                    ? Image.file(file, fit: BoxFit.cover)
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          if (asset.thumbnailPath != null &&
                              File(asset.thumbnailPath!).existsSync())
                            Image.file(
                              File(asset.thumbnailPath!),
                              fit: BoxFit.cover,
                            )
                          else
                            Container(color: Colors.black),
                          Center(
                            child: Icon(
                              Icons.play_circle_fill,
                              color: Colors.white,
                              size: w * 0.08,
                            ),
                          ),
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }


  Widget _buildLocalAssetsGrid(double w, double h, bool isDark) {
    return ValueListenableBuilder<List<GeneratedAsset>>(
      valueListenable: LocalStorageService().assetsNotifier,
      builder: (context, assets, child) {
        if (assets.isEmpty) {
          return Padding(
            padding: EdgeInsets.only(top: h * 0.05),
            child: Text(
              "no_generated_assets".i18n(),
              style: TextStyle(
                color: AppColors.textColor(isDark).withValues(alpha: 0.6),
                fontSize: w * 0.04,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: w * 0.03,
            mainAxisSpacing: w * 0.03,
            childAspectRatio: 0.9,
          ),
          itemCount: assets.length,
          itemBuilder: (context, index) {
            final asset = assets[index];
            final file = File(asset.filePath);

            if (asset.category == 'video' &&
                asset.thumbnailPath == null &&
                !_processingIds.contains(asset.id)) {
              _processingIds.add(asset.id);
              ThumbnailService().processGeneratedAsset(asset);
            }

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (innerContext) => Scaffold(
                      backgroundColor: AppColors.backgroundColor(isDark),
                      appBar: AppBar(
                        backgroundColor: Colors.transparent,
                        elevation: 0,
                        leading: IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new,
                            color: AppColors.textColor(isDark),
                          ),
                          onPressed: () => Navigator.pop(innerContext),
                        ),
                        title: Text(
                          'result_appbar_title'.i18n(),
                          style: TextStyle(color: AppColors.textColor(isDark)),
                        ),
                      ),
                      body: SafeArea(
                        child: AIResultScreen(resultImageUrl: asset.filePath),
                      ),
                    ),
                  ),
                );
              },
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.profileGridItemBackground(isDark),
                  borderRadius: BorderRadius.circular(w * 0.03),
                  border: Border.all(
                    color: AppColors.profileGridItemBorder(isDark),
                    width: w * 0.003,
                  ),
                ),
                clipBehavior: Clip.hardEdge,
                child: !file.existsSync()
                    ? Icon(
                        Icons.broken_image,
                        color: AppColors.textColor(
                          isDark,
                        ).withValues(alpha: 0.5),
                      )
                    : asset.category == 'image'
                    ? Image.file(file, fit: BoxFit.cover)
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          if (asset.thumbnailPath != null &&
                              File(asset.thumbnailPath!).existsSync())
                            Image.file(
                              File(asset.thumbnailPath!),
                              fit: BoxFit.cover,
                            )
                          else
                            Container(color: Colors.black),
                          Center(
                            child: Icon(
                              Icons.play_circle_fill,
                              color: Colors.white,
                              size: w * 0.08,
                            ),
                          ),
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }

  void _openReelViewer(
    BuildContext context,
    List<Reel> reels,
    int initialIndex,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _ReelViewerPage(reels: reels, initialIndex: initialIndex),
      ),
    );
  }

  /// Builds the liked or saved reels grid, reactively listening to local storage notifiers.
  Widget _buildReelsGrid(
    double w,
    double h,
    bool isDark,
    Stream<List<Reel>> stream, // kept for API compat but no longer used
  ) {
    final user = FirebaseAuth.instance.currentUser;
    final notifier = _selectedTabIndex == 1
        ? _reelService.savedReelsNotifier
        : _reelService.likedReelsNotifier;

    return ValueListenableBuilder<List<Reel>>(
      valueListenable: notifier,
      builder: (context, reels, _) {
        if (reels.isEmpty) {
          return Padding(
            padding: EdgeInsets.only(top: h * 0.05),
            child: Text(
              _selectedTabIndex == 1
                  ? 'No saved reels yet'
                  : 'No liked reels yet',
              style: TextStyle(
                color: AppColors.textColor(isDark).withValues(alpha: 0.5),
                fontSize: w * 0.04,
              ),
              textAlign: TextAlign.center,
            ),
          );
        }

        return GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: w * 0.02,
            mainAxisSpacing: w * 0.02,
            childAspectRatio: 0.65,
          ),
          itemCount: reels.length,
          itemBuilder: (context, index) {
            final reel = reels[index];
            final isVideo = reel.type == 'video';

            if (isVideo &&
                reel.thumbnailUrl == null &&
                !_processingIds.contains(reel.id)) {
              _processingIds.add(reel.id);
              ThumbnailService().processReelThumbnail(reel, user?.uid);
            }

            final thumbUrl = reel.thumbnailUrl?.isNotEmpty == true
                ? reel.thumbnailUrl!
                : (isVideo ? null : reel.videoUrl);

            return GestureDetector(
              onTap: () {
                // FIX: Open the full-screen reel viewer instead of AIResultScreen
                // so the user gets the same swipeable experience as the main feed.
                _openReelViewer(context, reels, index);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(w * 0.025),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Thumbnail
                    if (thumbUrl != null)
                      CachedNetworkImage(
                        imageUrl: thumbUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey.shade900,
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: Colors.white38,
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) =>
                            _videoFallbackTile(w),
                      )
                    else
                      _videoFallbackTile(w),

                    // Dark gradient overlay
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 60,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [Colors.black87, Colors.transparent],
                          ),
                        ),
                      ),
                    ),

                    // Play icon
                    if (isVideo)
                      const Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                          size: 34,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 8),
                          ],
                        ),
                      ),

                    // Video badge
                    if (isVideo)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.videocam,
                            color: Colors.white70,
                            size: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _videoFallbackTile(double w) {
    return Container(
      color: const Color(0xFF1C1C1E),
      child: const Center(
        child: Icon(Icons.play_circle_outline, color: Colors.white30, size: 36),
      ),
    );
  }

  Widget _buildLoginPrompt(double w, double h, bool isDark) {
    return Container(
      height: h * 0.4,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.profileStatCardBackground(isDark),
        borderRadius: BorderRadius.circular(w * 0.05),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      padding: EdgeInsets.all(w * 0.08),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(w * 0.04),
            decoration: BoxDecoration(
              color: AppColors.videoCategoryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _selectedTabIndex == 1
                  ? Icons.collections_bookmark
                  : Icons.favorite,
              color: AppColors.videoCategoryColor,
              size: w * 0.1,
            ),
          ),
          SizedBox(height: h * 0.03),
          Text(
            _selectedTabIndex == 1
                ? 'login_to_view_collections'.i18n()
                : 'login_to_view_liked'.i18n(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: w * 0.045,
              fontWeight: FontWeight.bold,
              color: AppColors.textColor(isDark),
            ),
          ),
          SizedBox(height: h * 0.01),
          Text(
            'sign_in_to_sync_message'.i18n(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: w * 0.035,
              color: AppColors.textColor(isDark).withValues(alpha: 0.6),
            ),
          ),
          SizedBox(height: h * 0.04),
          GestureDetector(
            onTap: () {
              Navigator.pushNamed(context, AppRoutes.login);
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: h * 0.018),
              decoration: ProGradientDecoration(
                borderRadius: BorderRadius.circular(w * 0.08),
              ),
              child: Center(
                child: Text(
                  'sign_in_now'.i18n(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label, double w, double h, bool isDark) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () {
        debugPrint('🖱️ [ProfilePage] Tab Clicked: Index $index ($label)');
        setState(() => _selectedTabIndex = index);
        // Refresh streams when switching to Collections or Liked tabs
        if (index == 1 || index == 2) {
          _refreshStreams();
        }
      },
      child: isSelected
          ? Container(
              padding: EdgeInsets.symmetric(
                horizontal: w * 0.04,
                vertical: h * 0.01,
              ),
              decoration: ProGradientDecoration(
                borderRadius: BorderRadius.all(Radius.circular(w * 0.05)),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: w * 0.035,
                ),
              ),
            )
          : Text(
              label,
              style: TextStyle(
                color: AppColors.profileTabInactiveText(isDark),
                fontWeight: FontWeight.w500,
                fontSize: w * 0.035,
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Full-screen reel viewer
// ─────────────────────────────────────────────────────────────────────────────

class _ReelViewerPage extends StatefulWidget {
  final List<Reel> reels;
  final int initialIndex;

  const _ReelViewerPage({required this.reels, required this.initialIndex});

  @override
  State<_ReelViewerPage> createState() => _ReelViewerPageState();
}

class _ReelViewerPageState extends State<_ReelViewerPage> {
  late final PageController _pageController;
  final ReelService _reelService = ReelService();

  @override
  void initState() {
    super.initState();
    final initialPage = widget.reels.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.reels.length - 1);
    _pageController = PageController(initialPage: initialPage);
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
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            itemCount: widget.reels.length,
            itemBuilder: (context, index) {
              if (index >= widget.reels.length) return const SizedBox.shrink();
              return ReelItemWidget(
                reel: widget.reels[index],
                reelService: _reelService,
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
