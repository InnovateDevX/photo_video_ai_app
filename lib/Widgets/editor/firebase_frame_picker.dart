import 'package:flutter/material.dart';
import 'package:trail_ai_app/Core/editor_constants.dart';
import 'package:trail_ai_app/Services/firebase_frame_service.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FirebaseFramePicker extends StatefulWidget {
  final bool isDark;
  final double imageAspectRatio;
  final ValueChanged<String?> onFrameSelected;
  final String? selectedFrameUrl;

  const FirebaseFramePicker({
    super.key,
    required this.isDark,
    required this.imageAspectRatio,
    required this.onFrameSelected,
    this.selectedFrameUrl,
  });

  @override
  State<FirebaseFramePicker> createState() => _FirebaseFramePickerState();
}

class _FirebaseFramePickerState extends State<FirebaseFramePicker> {
  final FirebaseFrameService _frameService = FirebaseFrameService();
  bool _isLoading = false;
  List<String> _frameUrls = [];
  String _currentRatioFolder = '1x1';

  @override
  void initState() {
    super.initState();
    _loadFrames();
  }

  Future<void> _loadFrames() async {
    setState(() => _isLoading = true);
    _currentRatioFolder = _frameService.getClosestRatioFolder(
      widget.imageAspectRatio,
    );

    final urls = await _frameService.fetchFrames(_currentRatioFolder);

    if (mounted) {
      setState(() {
        _frameUrls = urls;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppEditorConstants.accent),
      );
    }

    if (_frameUrls.isEmpty) {
      return Center(
        child: Text(
          'No frames available.',
          style: TextStyle(color: AppEditorConstants.textDim(widget.isDark)),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // "None" option
          GestureDetector(
            onTap: () => widget.onFrameSelected(null),
            child: Container(
              width: 64,
              height: 64,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: AppEditorConstants.iconBg(widget.isDark),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.selectedFrameUrl == null
                      ? AppEditorConstants.accent
                      : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.block,
                  color: AppEditorConstants.textDim(widget.isDark),
                  size: 24,
                ),
              ),
            ),
          ),

          // Frame Thumbnails
          ..._frameUrls.map((url) {
            final isActive = widget.selectedFrameUrl == url;

            return GestureDetector(
              onTap: () => widget.onFrameSelected(url),
              child: Container(
                width: 64,
                height: 64,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: AppEditorConstants.iconBg(widget.isDark),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive
                        ? AppEditorConstants.accent
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppEditorConstants.iconBg(widget.isDark),
                    ),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.error),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
