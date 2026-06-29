import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:trail_ai_app/Core/editor_constants.dart';
import 'package:trail_ai_app/Services/firebase_sticker_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

const String _kEmojiCategory = 'emoji';

class FirebaseStickerPicker extends StatefulWidget {
  final dynamic subEditor;
  final bool isDark;
  final VoidCallback? onDone;
  final Function(dynamic)? onStickerAdded;
  final dynamic editorState;

  const FirebaseStickerPicker({
    super.key,
    required this.subEditor,
    this.isDark = true,
    this.onDone,
    this.onStickerAdded,
    this.editorState,
  });

  @override
  State<FirebaseStickerPicker> createState() => FirebaseStickerPickerState();
}

class FirebaseStickerPickerState extends State<FirebaseStickerPicker> {
  final FirebaseStickerService _stickerService = FirebaseStickerService();

  // Tab list — starts with just [Emoji] until Firebase returns the full list
  List<String> _categories = [_kEmojiCategory];
  // Start on the first tab
  int _selectedCategoryIndex = 0;

  bool _isLoadingCategories = false;
  bool _categoriesLoaded = false;

  // Which category is currently loading its sticker list
  String? _loadingCategory;

  // URL cache: fullPath -> download URL (prevents repeat getDownloadURL calls)
  final Map<String, String> _urlCache = {};
  // Future cache: fullPath -> Future<String> (prevents new Futures on rebuild)
  final Map<String, Future<String>> _urlFutureCache = {};

  // Track currently selected sticker URL
  String? _selectedStickerUrl;

  /// Current opacity for stickers (0.0 – 1.0).
  double _opacity = 1.0;

  /// Track the last added sticker layer by ID so we can replace it even if modified
  String? _lastAddedLayerId;

  /// Updates the opacity of the last added sticker layer in real-time.
  void _updateLastStickerOpacity(double opacity) {
    if (widget.editorState == null || _lastAddedLayerId == null) return;

    try {
      // Get the active layers from the editor
      final layers = widget.editorState.activeLayers;
      if (layers == null || layers.isEmpty) return;

      // Find the last WidgetLayer (sticker) that was added matching the id
      for (int i = layers.length - 1; i >= 0; i--) {
        final layer = layers[i];
        if (layer is WidgetLayer && layer.id == _lastAddedLayerId) {
          // Get the current widget from the layer
          final currentWidget = layer.widget;
          if (currentWidget is Opacity) {
            // Replace the layer with a new one with updated opacity
            // but preserve the original position, scale, rotation, and id
            final newWidget = Opacity(
              opacity: opacity,
              child: currentWidget.child,
            );
            widget.editorState.replaceLayer(
              index: i,
              layer: WidgetLayer(
                id: layer.id,
                widget: newWidget,
                offset: layer.offset,
                scale: layer.scale,
                rotation: layer.rotation,
              ),
            );
            debugPrint(
              '[FirebaseStickerPicker] Updated sticker opacity to $opacity',
            );
            break;
          }
        }
      }
    } catch (e) {
      debugPrint('[FirebaseStickerPicker] Error updating sticker opacity: $e');
    }
  }

  /// Cancels the current sticker selection by removing the active sticker layer.
  void cancelCurrentSticker() {
    if (widget.editorState != null && _lastAddedLayerId != null) {
      widget.editorState.activeLayers.removeWhere((l) => l.id == _lastAddedLayerId);
      // Trigger editor redraw using undo/redo
      widget.editorState.undoAction();
      widget.editorState.redoAction();
    }
  }

  /// Called externally (e.g. by tick mark) to clear the selection highlight.
  void clearSelection() {
    _lastAddedLayerId = null;
    if (mounted) setState(() => _selectedStickerUrl = null);
  }

  @override
  void initState() {
    super.initState();
    // Load category tab names in the background (lightweight single listAll)
    _loadCategories();
    // Automatically load emojis when the sticker picker is opened
    _loadCategory(_kEmojiCategory);
  }

  // ─── Category list ─────────────────────────────────────────────────────────

  Future<void> _loadCategories() async {
    if (_categoriesLoaded || _isLoadingCategories || !mounted) return;
    setState(() => _isLoadingCategories = true);
    try {
      final cats = await _stickerService.fetchCategories();
      if (!mounted) return;
      final rest = cats
          .where((c) => c.toLowerCase() != _kEmojiCategory)
          .toList();
      setState(() {
        _categories = [_kEmojiCategory, ...rest];
        _isLoadingCategories = false;
        _categoriesLoaded = true;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  // ─── On-demand sticker load (only when tab is tapped) ─────────────────────

  Future<void> _loadCategory(String category) async {
    // Already loaded or currently loading — nothing to do
    if (_stickerService.hasFirstPage(category)) return;
    if (_loadingCategory == category) return;

    setState(() => _loadingCategory = category);
    await _stickerService.fetchFirstPage(category);
    if (mounted) setState(() => _loadingCategory = null);
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxHeight < AppEditorConstants.h(context, 0.1)) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.max,
          children: [
            SizedBox(height: AppEditorConstants.h(context, 0.012)),

            // ── Opacity slider ────────────────────────────────────────────
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppEditorConstants.w(context, 0.04),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.opacity,
                    size: AppEditorConstants.sp(context, 16),
                    color: AppEditorConstants.textDim(isDark),
                  ),
                  SizedBox(width: AppEditorConstants.w(context, 0.02)),
                  Text(
                    'Opacity',
                    style: TextStyle(
                      color: AppEditorConstants.textDim(isDark),
                      fontSize: AppEditorConstants.sp(context, 12),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Expanded(
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 8,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 16,
                        ),
                        activeTrackColor: AppEditorConstants.accent,
                        inactiveTrackColor: isDark
                            ? Colors.white24
                            : Colors.black26,
                        thumbColor: AppEditorConstants.accent,
                        overlayColor: AppEditorConstants.accent.withValues(
                          alpha: 0.2,
                        ),
                      ),
                      child: Slider(
                        value: _opacity,
                        min: 0.1,
                        max: 1.0,
                        onChanged: (v) {
                          setState(() => _opacity = v);
                          _updateLastStickerOpacity(v);
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: AppEditorConstants.w(context, 0.01)),
                  Text(
                    '${(_opacity * 100).round()}%',
                    style: TextStyle(
                      color: AppEditorConstants.textActive(isDark),
                      fontSize: AppEditorConstants.sp(context, 12),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: AppEditorConstants.h(context, 0.008)),

            // Category tabs
            _buildCategoryTabs(isDark),
            SizedBox(height: AppEditorConstants.h(context, 0.02)),

            // Sticker grid — dynamic height for responsiveness
            Expanded(child: _buildStickersGrid(isDark)),
            SizedBox(height: AppEditorConstants.h(context, 0.015)),
          ],
        );
      },
    );
  }

  // ─── Category tab bar ──────────────────────────────────────────────────────

  Widget _buildCategoryTabs(bool isDark) {
    return SizedBox(
      height: AppEditorConstants.h(context, 0.045),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: AppEditorConstants.w(context, 0.04),
        ),
        itemCount: _categories.length + (_isLoadingCategories ? 1 : 0),
        itemBuilder: (context, index) {
          // Trailing shimmer while category names load
          if (_isLoadingCategories && index == _categories.length) {
            return Row(
              children: List.generate(
                3,
                (_) => Shimmer.fromColors(
                  baseColor: isDark ? Colors.white10 : Colors.black12,
                  highlightColor: isDark ? Colors.white24 : Colors.black26,
                  child: Container(
                    width: AppEditorConstants.w(context, 0.15),
                    height: AppEditorConstants.h(context, 0.02),
                    margin: EdgeInsets.only(
                      right: AppEditorConstants.w(context, 0.06),
                      top: AppEditorConstants.h(context, 0.012),
                      bottom: AppEditorConstants.h(context, 0.012),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(
                        AppEditorConstants.w(context, 0.01),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          final isSelected = _selectedCategoryIndex == index;
          final categoryName = _categories[index];

          return GestureDetector(
            onTap: () {
              setState(() => _selectedCategoryIndex = index);
              // ✅ ONLY load stickers when this tab is tapped
              _loadCategory(categoryName);
            },
            child: Container(
              margin: EdgeInsets.only(
                right: AppEditorConstants.w(context, 0.06),
              ),
              alignment: Alignment.center,
              child: Text(
                categoryName.toUpperCase(),
                style: TextStyle(
                  color: isSelected
                      ? AppEditorConstants.textActive(isDark)
                      : AppEditorConstants.textDim(isDark),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: AppEditorConstants.sp(context, 14),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ─── Sticker grid ──────────────────────────────────────────────────────────

  Widget _buildStickersGrid(bool isDark) {
    if (_selectedCategoryIndex >= _categories.length) {
      return const SizedBox.shrink();
    }
    final category = _categories[_selectedCategoryIndex];

    // Still loading the first page for this category
    final bool isLoading = _loadingCategory == category;
    final bool hasData = _stickerService.hasFirstPage(category);
    final List<Reference> refs = _stickerService.refsForCategory(category);

    if (isLoading || !hasData) {
      // Show a prompt to tap the tab if nothing is selected yet,
      // or a shimmer while the selected tab is loading
      return isLoading ? _buildGridShimmer(isDark) : _buildTapPrompt(isDark);
    }

    if (refs.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      padding: EdgeInsets.only(
        left: AppEditorConstants.w(context, 0.04),
        right: AppEditorConstants.w(context, 0.04),
        top: AppEditorConstants.h(context, 0.01),
        bottom:
            MediaQuery.of(context).padding.bottom +
            AppEditorConstants.h(context, 0.025),
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: AppEditorConstants.w(context, 0.03),
        mainAxisSpacing: AppEditorConstants.h(context, 0.015),
        childAspectRatio: 1.0,
      ),
      itemCount: refs.length,
      itemBuilder: (context, index) {
        final ref = refs[index];
        final cachedUrl = _urlCache[ref.fullPath];

        if (cachedUrl != null) {
          return _buildStickerCell(isDark, cachedUrl);
        }

        // Cache the Future so rebuilds reuse it
        final future = _urlFutureCache.putIfAbsent(
          ref.fullPath,
          () => ref.getDownloadURL().then((u) {
            _urlCache[ref.fullPath] = u;
            return u;
          }),
        );

        return FutureBuilder<String>(
          future: future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return _buildCellShimmer(isDark);
            return _buildStickerCell(isDark, snapshot.data!);
          },
        );
      },
    );
  }

  // ─── Cells ─────────────────────────────────────────────────────────────────

  Widget _buildStickerCell(bool isDark, String url) {
    return GestureDetector(
      onTap: () {
        if (mounted) {
          setState(() {
            _selectedStickerUrl = url;
          });
        }
        debugPrint('[FirebaseStickerPicker] Sticker tapped, URL: $url');

        // Create the sticker widget using CachedNetworkImage for instant loading
        // Wrap in Opacity so the user-chosen opacity is baked into the layer.
        final stickerWidget = Opacity(
          opacity: _opacity,
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.contain,
            width: AppEditorConstants.w(context, 0.4),
            height: AppEditorConstants.w(context, 0.4),
            errorWidget: (context, url, error) =>
                const Icon(Icons.broken_image, color: Colors.red),
          ),
        );

        // Try to add the sticker
        try {
          if (widget.subEditor != null) {
            debugPrint(
              '[FirebaseStickerPicker] Calling addSticker on subEditor',
            );
            widget.subEditor.addSticker(stickerWidget);
            if (widget.onStickerAdded != null) {
              widget.onStickerAdded!(stickerWidget);
            }
          } else if (widget.editorState != null) {
            debugPrint(
              '[FirebaseStickerPicker] Calling addLayer/replaceLayer on editorState directly',
            );
            
            WidgetLayer layer = WidgetLayer(widget: stickerWidget);
            int existingIndex = -1;
            
            if (_lastAddedLayerId != null) {
              final List layers = widget.editorState.activeLayers;
              existingIndex = layers.indexWhere((l) => l.id == _lastAddedLayerId);
            }

            if (existingIndex != -1) {
              // Preserve the position, scale, and rotation of the previous sticker
              final oldLayer = widget.editorState.activeLayers[existingIndex];
              if (oldLayer is WidgetLayer) {
                layer = WidgetLayer(
                  id: oldLayer.id,
                  widget: stickerWidget,
                  offset: oldLayer.offset,
                  scale: oldLayer.scale,
                  rotation: oldLayer.rotation,
                );
              }
              widget.editorState.replaceLayer(
                index: existingIndex,
                layer: layer,
              );
            } else {
              widget.editorState.addLayer(layer);
            }
            
            _lastAddedLayerId = layer.id;

            if (widget.onStickerAdded != null) {
              widget.onStickerAdded!(layer);
            }
          }
        } catch (e) {
          debugPrint('[FirebaseStickerPicker] Error calling addSticker: $e');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : Colors.white70,
          borderRadius: BorderRadius.circular(
            AppEditorConstants.w(context, 0.03),
          ),
          border: Border.all(
            color: _selectedStickerUrl == url
                ? AppEditorConstants.accent
                : (isDark ? Colors.white10 : Colors.black12),
            width: _selectedStickerUrl == url ? 2.0 : 1.0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            AppEditorConstants.w(context, 0.03),
          ),
          child: Padding(
            padding: EdgeInsets.all(AppEditorConstants.w(context, 0.02)),
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              placeholder: (context, url) => Center(
                child: SizedBox(
                  width: AppEditorConstants.w(context, 0.05),
                  height: AppEditorConstants.w(context, 0.05),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
              errorWidget: (context, url, error) => Icon(
                Icons.broken_image,
                color: Colors.red,
                size: AppEditorConstants.w(context, 0.05),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCellShimmer(bool isDark) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.white10 : Colors.black12,
      highlightColor: isDark ? Colors.white24 : Colors.black26,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            AppEditorConstants.w(context, 0.03),
          ),
        ),
      ),
    );
  }

  Widget _buildGridShimmer(bool isDark) {
    return GridView.builder(
      padding: EdgeInsets.only(
        left: AppEditorConstants.w(context, 0.04),
        right: AppEditorConstants.w(context, 0.04),
        top: AppEditorConstants.h(context, 0.01),
        bottom:
            MediaQuery.of(context).padding.bottom +
            AppEditorConstants.h(context, 0.025),
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: AppEditorConstants.w(context, 0.03),
        mainAxisSpacing: AppEditorConstants.h(context, 0.015),
        childAspectRatio: 1.0,
      ),
      itemCount: 8,
      itemBuilder: (context, index) => _buildCellShimmer(isDark),
    );
  }

  /// Shown when no category has been tapped yet
  Widget _buildTapPrompt(bool isDark) {
    return Center(
      child: Text(
        'Tap a category above to browse stickers',
        style: TextStyle(
          color: AppEditorConstants.textDim(isDark),
          fontSize: AppEditorConstants.sp(context, 13),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
