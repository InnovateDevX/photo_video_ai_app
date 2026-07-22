import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:shimmer/shimmer.dart';
import '../../Models/category_image.dart';

/// A universal image widget for Firebase Storage URLs.
///
/// Wraps [CachedNetworkImage] with:
///   • Automatic URL sanitization via [sanitizeFirebaseUrl]
///   • One automatic cache-clear-and-retry on load failure
///     (cures stale bad cache entries written before the URL fix)
///   • A shimmer placeholder and a broken-image error widget by default
class FirebaseImage extends StatefulWidget {
  const FirebaseImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.alignment = Alignment.center,
    this.errorWidget,
    this.placeholder,
    this.isDark = true,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Alignment alignment;

  /// Custom error widget. If null, a broken-image icon is shown.
  final Widget Function(BuildContext context, String url, Object error)?
      errorWidget;

  /// Custom placeholder. If null, a shimmer is shown.
  final Widget Function(BuildContext context, String url)? placeholder;

  final bool isDark;

  @override
  State<FirebaseImage> createState() => _FirebaseImageState();
}

class _FirebaseImageState extends State<FirebaseImage> {
  late String _sanitizedUrl;
  bool _retried = false;

  @override
  void initState() {
    super.initState();
    _sanitizedUrl = sanitizeFirebaseUrl(widget.url);
  }

  @override
  void didUpdateWidget(covariant FirebaseImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      _sanitizedUrl = sanitizeFirebaseUrl(widget.url);
      _retried = false;
    }
  }

  Future<void> _handleError(Object error) async {
    if (_retried || !mounted) return;
    debugPrint(
      '🖼️ [FirebaseImage] Load error for URL: ${_sanitizedUrl.length > 120 ? "${_sanitizedUrl.substring(0, 120)}..." : _sanitizedUrl}\n'
      '   Error: $error\n'
      '   → Clearing cache and retrying...',
    );
    // Remove the stale/broken cache entry
    try {
      await DefaultCacheManager().removeFile(_sanitizedUrl);
    } catch (_) {}
    if (mounted) {
      setState(() => _retried = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sanitizedUrl.isEmpty) return _buildError(context, _sanitizedUrl, 'Empty URL');

    return CachedNetworkImage(
      // Adding `?retry=1` as a cache-buster after the first failure so the
      // cache manager treats it as a fresh entry.
      key: ValueKey('$_sanitizedUrl${_retried ? "_r1" : ""}'),
      imageUrl: _retried ? '$_sanitizedUrl&_r=1' : _sanitizedUrl,
      fit: widget.fit,
      width: widget.width,
      height: widget.height,
      alignment: widget.alignment,
      placeholder: widget.placeholder ??
          (context, url) => _buildShimmer(context),
      errorWidget: (context, url, error) {
        if (!_retried) {
          // Trigger async cache clear + setState on next frame
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _handleError(error),
          );
          // Meanwhile show shimmer while retry is in progress
          return _buildShimmer(context);
        }
        // After retry also failed, show the error widget
        debugPrint(
          '🖼️ [FirebaseImage] ❌ Retry also failed for: ${_sanitizedUrl.length > 80 ? "${_sanitizedUrl.substring(0, 80)}..." : _sanitizedUrl}',
        );
        return widget.errorWidget?.call(context, url, error) ??
            _buildError(context, url, error);
      },
    );
  }

  Widget _buildShimmer(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: widget.isDark ? Colors.grey[850]! : Colors.grey[300]!,
      highlightColor: widget.isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: Container(color: Colors.white),
    );
  }

  Widget _buildError(BuildContext context, String url, Object error) {
    return Container(
      color: widget.isDark ? Colors.grey[900] : Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.broken_image_outlined,
          color: Colors.grey[600],
          size: 32,
        ),
      ),
    );
  }
}
