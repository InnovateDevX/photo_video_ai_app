import 'package:flutter/material.dart';
import '../Models/effect_overlay.dart';

class EffectSelectorBar extends StatelessWidget {
  final List<EffectOverlay> effects;
  final EffectOverlay? selectedEffect;
  final Function(EffectOverlay) onEffectSelected;
  final VoidCallback onClear;

  const EffectSelectorBar({
    super.key,
    required this.effects,
    this.selectedEffect,
    required this.onEffectSelected,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: effects.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildClearItem();
          }
          final effect = effects[index - 1];
          final isSelected = selectedEffect?.id == effect.id;

          return _buildEffectItem(effect, isSelected);
        },
      ),
    );
  }

  Widget _buildClearItem() {
    return GestureDetector(
      onTap: onClear,
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(12),
          border: selectedEffect == null
              ? Border.all(color: Colors.blueAccent, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.block, color: Colors.white, size: 30),
            SizedBox(height: 8),
            Text('None', style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildEffectItem(EffectOverlay effect, bool isSelected) {
    return GestureDetector(
      onTap: () => onEffectSelected(effect),
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(color: Colors.blueAccent, width: 2)
              : Border.all(color: Colors.transparent, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Thumbnail with better error handling
            _EffectThumbnail(
              thumbnailPath: effect.thumbnailPath,
              effectId: effect.id,
            ),
            // Name Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
            ),
            Positioned(
              bottom: 8,
              left: 4,
              right: 4,
              child: Text(
                effect.id.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget to load effect thumbnail with graceful fallback
class _EffectThumbnail extends StatelessWidget {
  final String thumbnailPath;
  final String effectId;

  const _EffectThumbnail({required this.thumbnailPath, required this.effectId});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      thumbnailPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        // Show a colored placeholder based on effect category
        final isLens =
            effectId.toLowerCase().contains('light') ||
            effectId.toLowerCase().contains('golden');
        final isPrism = effectId.toLowerCase().contains('prism');

        Color placeholderColor;
        IconData placeholderIcon;

        if (isLens) {
          placeholderColor = const Color(0xFFFFB347); // Orange for lens
          placeholderIcon = Icons.wb_sunny;
        } else if (isPrism) {
          placeholderColor = const Color(0xFFC77DFF); // Purple for prism
          placeholderIcon = Icons.auto_awesome;
        } else {
          placeholderColor = Colors.grey;
          placeholderIcon = Icons.filter;
        }

        return Container(
          color: placeholderColor.withOpacity(0.3),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(placeholderIcon, color: placeholderColor, size: 24),
                const SizedBox(height: 4),
                Text(
                  effectId.substring(0, effectId.length.clamp(0, 8)),
                  style: TextStyle(
                    color: placeholderColor,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(seconds: 1),
          curve: Curves.easeOut,
          child: child,
        );
      },
    );
  }
}
