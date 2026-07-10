import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:trail_ai_app/Core/colors.dart';
import 'dart:ui';
import 'package:trail_ai_app/Core/gradient.dart';
import 'package:localization/localization.dart';
import 'package:trail_ai_app/Services/media_service.dart';
import 'package:trail_ai_app/pages/upscale_page.dart';
import 'package:video_player/video_player.dart';
import 'package:trail_ai_app/Services/review_service.dart';
import 'package:trail_ai_app/Services/asset_service.dart';
import 'package:trail_ai_app/Services/subscription_service.dart';
import '../Helpers/feedback_helper.dart';
class AIResultScreen extends StatefulWidget {
  final File? originalImage;
  final String resultImageUrl;
  final VoidCallback? onReEdit;
  final VoidCallback? onTryAgain;

  // Custom Primary Action (Optional)
  final String? customActionLabel;
  final IconData? customActionIcon;
  final VoidCallback? onCustomAction;
  final VoidCallback? onBack;

  // Visual Customization
  final BoxFit fit;
  final bool isNsfw;
  final bool hideEnhance;

  const AIResultScreen({
    super.key,
    this.originalImage,
    required this.resultImageUrl,
    this.onReEdit,
    this.onTryAgain,
    this.customActionLabel,
    this.customActionIcon,
    this.onCustomAction,
    this.fit = BoxFit.contain, // Default to contain to ensure it's not cropped
    this.isNsfw = false,
    this.onBack,
    this.hideEnhance = false,
  });

  @override
  State<AIResultScreen> createState() => _AIResultScreenState();
}

class _AIResultScreenState extends State<AIResultScreen> {
  bool _isDownloading = false;
  bool _isSharing = false;
  bool _showOriginal = false;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isImageLoaded = false;
  bool? _isLiked;
  bool _isNsfw = false;

  @override
  void initState() {
    super.initState();
    _isNsfw = widget.isNsfw;
    _checkAndInitVideo();
    _checkAndInitImage();
    // Trigger in-app review check after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ReviewService().requestReviewIfAppropriate(context);
    });
  }

  void _checkAndInitImage() {
    final isVideo = widget.resultImageUrl.toLowerCase().endsWith('.mp4');
    if (isVideo) return;
    
    if (!widget.resultImageUrl.startsWith('http')) {
      _isImageLoaded = true;
      return;
    }

    final imageProvider = CachedNetworkImageProvider(widget.resultImageUrl);
    final imageStream = imageProvider.resolve(const ImageConfiguration());
    final listener = ImageStreamListener(
      (info, synchronousCall) {
        if (mounted && !_isImageLoaded) setState(() => _isImageLoaded = true);
      },
      onError: (error, stackTrace) {
        if (mounted && !_isImageLoaded) setState(() => _isImageLoaded = true); // allow interaction even on error
      },
    );
    imageStream.addListener(listener);
  }

  void _checkAndInitVideo() {
    if (widget.resultImageUrl.toLowerCase().endsWith('.mp4')) {
      if (widget.resultImageUrl.startsWith('http')) {
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.resultImageUrl),
        );
      } else {
        _videoController = VideoPlayerController.file(
          File(widget.resultImageUrl),
        );
      }
      _videoController!.initialize().then((_) {
        _videoController!.setLooping(true);
        if (mounted) {
          setState(() => _isVideoInitialized = true);
          _videoController!.play();
        }
      });
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _downloadImage() async {
    setState(() => _isDownloading = true);
    File? file;
    final isVideo = widget.resultImageUrl.toLowerCase().endsWith('.mp4');

    if (isVideo) {
      file = await MediaService.downloadVideo(
        context,
        widget.resultImageUrl,
        isLocal: !widget.resultImageUrl.startsWith('http'),
      );
    } else {
      file = await MediaService.downloadImage(
        context,
        widget.resultImageUrl,
        isLocal: !widget.resultImageUrl.startsWith('http'),
      );
    }

    // Persist to cloud if user is logged in
    if (file != null) {
      await AssetService().saveUserAsset(file, isVideo ? 'video' : 'image');
    }

    if (mounted) setState(() => _isDownloading = false);
  }

  Future<void> _shareImage() async {
    setState(() => _isSharing = true);
    try {
      if (widget.resultImageUrl.toLowerCase().endsWith('.mp4')) {
        await MediaService.shareVideo(
          context,
          widget.resultImageUrl,
          isLocal: !widget.resultImageUrl.startsWith('http'),
        );
      } else {
        await MediaService.shareImage(
          context,
          widget.resultImageUrl,
          isLocal: !widget.resultImageUrl.startsWith('http'),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    final bool isVideo = widget.resultImageUrl.toLowerCase().endsWith('.mp4');
    final bool canInteract = isVideo ? _isVideoInitialized : _isImageLoaded;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(isDark),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: sw * 0.04, vertical: sh * 0.01),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: widget.onBack ?? () => Navigator.pop(context),
                    child: Container(
                      padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : Colors.grey.shade200,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        color: AppColors.textColor(isDark),
                        size: 20,
                      ),
                    ),
                  ),
                  if (!_isNsfw && _isLiked == null)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isNsfw = true;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Content flagged as inappropriate.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        FeedbackHelper.showFeedbackSheet(
                          context,
                          isDark: isDark,
                          assetUrl: widget.resultImageUrl,
                        );
                      },
                      child: Container(
                        padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white12 : Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.flag_outlined,
                          color: AppColors.textColor(isDark),
                          size: 20,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: sw * 0.04),
                child: Column(
                  children: [
                    SizedBox(height: sh * 0.02),

                    // Media Display Container
                    _buildMediaDisplay(sw, sh, isDark, isVideo),

                    SizedBox(height: sh * 0.02),

                    if (canInteract && _isLiked == null && !_isNsfw) ...[
                      // Feedback row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Was this generation helpful?',
                            style: TextStyle(
                              color: AppColors.secondaryTextColor(isDark),
                              fontSize: sw * 0.038,
                            ),
                          ),
                          SizedBox(width: sw * 0.03),
                          GestureDetector(
                            onTap: () {
                              setState(() => _isLiked = true);
                              FeedbackHelper.showThumbsUpDialog(
                                context,
                                isDark: isDark,
                                assetUrl: widget.resultImageUrl,
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
                              decoration: BoxDecoration(
                                color: _isLiked == true
                                    ? Colors.green.withValues(alpha: 0.2)
                                    : (isDark ? Colors.white12 : Colors.grey.shade200),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isLiked == true ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                                color: _isLiked == true ? Colors.green : AppColors.textColor(isDark),
                                size: 20,
                              ),
                            ),
                          ),
                          SizedBox(width: sw * 0.03),
                          GestureDetector(
                            onTap: () {
                              setState(() => _isLiked = false);
                              FeedbackHelper.showThumbsDownDialog(
                                context,
                                isDark: isDark,
                                assetUrl: widget.resultImageUrl,
                              );
                            },
                            child: Container(
                              padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.02),
                              decoration: BoxDecoration(
                                color: _isLiked == false
                                    ? Colors.red.withValues(alpha: 0.2)
                                    : (isDark ? Colors.white12 : Colors.grey.shade200),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _isLiked == false ? Icons.thumb_down_rounded : Icons.thumb_down_outlined,
                                color: _isLiked == false ? Colors.red : AppColors.textColor(isDark),
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: sh * 0.02),
                    ],

                    if (canInteract) ...[
                      // Action Pills (Enhance/Try Again)
                      if (widget.onReEdit != null || widget.onTryAgain != null)
                        _buildActionPills(sw, sh, isDark, isVideo),

                      SizedBox(height: sh * 0.04),
                    ],
                  ],
                ),
              ),
            ),

            // 3. Persistent Bottom Buttons
            if (canInteract) _buildBottomButtons(sw, sh, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaDisplay(double sw, double sh, bool isDark, bool isVideo) {
    Widget mediaWidget;

    // If it's the original image comparison (only for images)
    if (widget.originalImage != null && !isVideo) {
      mediaWidget = GestureDetector(
        onTapDown: (_) => setState(() => _showOriginal = true),
        onTapUp: (_) => setState(() => _showOriginal = false),
        onTapCancel: () => setState(() => _showOriginal = false),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              maxScale: 3.5,
              child: Center(
                child: _showOriginal
                    ? Image.file(widget.originalImage!, fit: widget.fit)
                    : widget.resultImageUrl.startsWith('http')
                    ? CachedNetworkImage(
                        imageUrl: widget.resultImageUrl,
                        fit: widget.fit,
                        placeholder: (context, url) =>
                            _buildPlaceholder(isDark),
                      )
                    : Image.file(
                        File(widget.resultImageUrl),
                        fit: widget.fit,
                      ),
              ),
            ),
            Positioned(
              bottom: sw * 0.03,
              right: sw * 0.03,
              child: Container(
                padding: EdgeInsets.all(sw * 0.02),
                decoration: BoxDecoration(
                  color: Colors.black.withAlpha(120),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.compare,
                  color: Colors.white,
                  size: sw * 0.05,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Default Video/Image Display
      mediaWidget = isVideo
          ? (_isVideoInitialized && _videoController != null
              ? AspectRatio(
                  aspectRatio: _videoController!.value.aspectRatio > 0
                      ? _videoController!.value.aspectRatio
                      : 1.0,
                  child: FittedBox(
                    fit: widget.fit,
                    child: SizedBox(
                      width: _videoController!.value.size.width > 0
                          ? _videoController!.value.size.width
                          : 100, // Fallback width
                      height: _videoController!.value.size.height > 0
                          ? _videoController!.value.size.height
                          : 100, // Fallback height
                      child: VideoPlayer(_videoController!),
                    ),
                  ),
                )
              : _buildPlaceholder(isDark))
          : InteractiveViewer(
              maxScale: 3.0,
              child: widget.resultImageUrl.startsWith('http')
                  ? CachedNetworkImage(
                      imageUrl: widget.resultImageUrl,
                      fit: widget.fit,
                      placeholder: (context, url) =>
                          _buildPlaceholder(isDark),
                      errorWidget: (context, url, err) =>
                          const Icon(Icons.error_outline),
                    )
                  : Image.file(
                      File(widget.resultImageUrl),
                      fit: widget.fit,
                    ),
            );
    }

    if (_isNsfw) {
      mediaWidget = IgnorePointer(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: mediaWidget,
            ),
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: Icon(
                  Icons.visibility_off,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: widget.originalImage != null && !isVideo ? sh * 0.75 : sh * 0.72,
      ), // Flexible vertical limit
      child: _mediaWrapper(child: mediaWidget, isDark: isDark),
    );
  }

  Widget _mediaWrapper({required Widget child, required bool isDark}) {
    final bool showWatermark = !SubscriptionService().isSubscribed;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.06),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.06),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (showWatermark)
              Positioned(
                right: 20,
                bottom: 20,
                child: IgnorePointer(
                  child: Image.asset(
                    'assets/images/watermark.png',
                    width: 120,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: Colors.black12,
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildActionPills(double sw, double sh, bool isDark, bool isVideo) {
    return Row(
      children: [
        if (!isVideo && !widget.hideEnhance)
          _actionPill(
            context: context,
            isDark: isDark,
            icon: widget.customActionIcon ?? Icons.auto_fix_high,
            label: widget.customActionLabel ?? 'enhance'.i18n(),
            onTap:
                widget.onCustomAction ??
                () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UpscalePage(
                      initialImageUrl: widget.resultImageUrl.startsWith('http')
                          ? widget.resultImageUrl
                          : null,
                    ),
                  ),
                ),
          ),
        if (!isVideo && (widget.onReEdit != null || widget.onTryAgain != null))
          SizedBox(width: sw * 0.02),
        if (widget.onReEdit != null)
          _actionPill(
            context: context,
            isDark: isDark,
            icon: Icons.edit_rounded,
            label: 're_edit'.i18n(),
            onTap: widget.onReEdit!,
          ),
        if (widget.onReEdit != null && widget.onTryAgain != null)
          SizedBox(width: sw * 0.02),
        if (widget.onTryAgain != null)
          _actionPill(
            context: context,
            isDark: isDark,
            icon: Icons.refresh_rounded,
            label: 'try_again'.i18n(),
            onTap: widget.onTryAgain!,
          ),
      ],
    );
  }

  Widget _buildBottomButtons(double sw, double sh, bool isDark) {
    return Container(
      padding: EdgeInsets.only(
        left: sw * 0.04,
        right: sw * 0.04,
        bottom: Platform.isIOS ? 34 : 20,
        top: sh * 0.02,
      ),
      color: AppColors.backgroundColor(isDark),
      child: Row(
        children: [
          // Download Button
          Expanded(
            child: GestureDetector(
              onTap: (_isDownloading || widget.isNsfw) ? null : _downloadImage,
              child: Container(
                height: sh * 0.07,
                decoration: widget.isNsfw 
                  ? BoxDecoration(
                      color: Colors.grey,
                      borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.07),
                    )
                  : ProGradientDecoration(
                      borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.07),
                    ),
                child: Center(
                  child: _isDownloading
                      ? SizedBox(
                          width: sw * 0.05,
                          height: sw * 0.05,
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.download_rounded,
                              color: Colors.white,
                              size: sw * 0.055,
                            ),
                            SizedBox(width: sw * 0.02),
                            Text(
                              'download'.i18n(),
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: sw * 0.04,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),

          SizedBox(width: sw * 0.03),

          // Share Button
          Expanded(
            child: GestureDetector(
              onTap: (widget.isNsfw || _isSharing) ? null : _shareImage,
              child: Container(
                height: sh * 0.07,
                decoration: BoxDecoration(
                  color: (isDark || widget.isNsfw)
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(MediaQuery.of(context).size.width * 0.07),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.1),
                    width: sw * 0.003,
                  ),
                ),
                child: Center(
                  child: _isSharing
                      ? SizedBox(
                          width: sw * 0.05,
                          height: sw * 0.05,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textColor(isDark),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.share_rounded,
                              color: AppColors.textColor(isDark).withValues(alpha: widget.isNsfw ? 0.3 : 1.0),
                              size: sw * 0.055,
                            ),
                            SizedBox(width: sw * 0.02),
                            Text(
                              'share'.i18n(),
                              style: TextStyle(
                                color: AppColors.textColor(isDark).withValues(alpha: widget.isNsfw ? 0.3 : 1.0),
                                fontWeight: FontWeight.bold,
                                fontSize: sw * 0.04,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionPill({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: sh * 0.07,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(sw * 0.04),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
              width: sw * 0.003,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: sw * 0.052, color: AppColors.textColor(isDark)),
              SizedBox(width: sw * 0.02),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: sw * 0.038,
                    color: AppColors.textColor(isDark),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
