import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../Models/effect_overlay.dart';
import '../Services/effect_service.dart';

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
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: selectedEffect == null
                    ? Border.all(color: Colors.blueAccent, width: 2)
                    : Border.all(color: Colors.transparent, width: 2),
              ),
              child: const Center(
                child: Icon(Icons.block, color: Colors.white, size: 30),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'None',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEffectItem(EffectOverlay effect, bool isSelected) {
    return GestureDetector(
      onTap: () => onEffectSelected(effect),
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: Colors.blueAccent, width: 2)
                    : Border.all(color: Colors.transparent, width: 2),
              ),
              clipBehavior: Clip.antiAlias,
              child: _EffectThumbnail(
                thumbnailPath: effect.thumbnailPath,
                effectId: effect.id,
                category: effect.category,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 80,
              child: Text(
                effect.id.toUpperCase(),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? Colors.blueAccent : Colors.white70,
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
  final String category;

  const _EffectThumbnail({
    required this.thumbnailPath,
    required this.effectId,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    final index = int.tryParse(thumbnailPath.split('/').last.split('.').first.replaceAll(RegExp(r'\D'), '')) ?? 1;
    return FutureBuilder<String?>(
      future: EffectService().getEffectThumbnailUrl(
        category: category,
        index: index,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
            ),
          );
        }
        final url = snapshot.data;
        if (url == null) {
          return _buildFallback();
        }
        return CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (context, url) => const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
            ),
          ),
          errorWidget: (context, url, error) => _buildFallback(),
        );
      },
    );
  }

  Widget _buildFallback() {
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
      color: placeholderColor.withValues(alpha: 0.3),
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
  }
}
