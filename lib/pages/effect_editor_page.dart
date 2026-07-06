import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../Models/effect_overlay.dart';
import '../providers/effect_editor_provider.dart';
import '../Widgets/effect_overlay_preview.dart';
import '../Widgets/effect_selector_bar.dart';

class EffectEditorPage extends StatefulWidget {
  final File imageFile;

  const EffectEditorPage({super.key, required this.imageFile});

  @override
  State<EffectEditorPage> createState() => _EffectEditorPageState();
}

class _EffectEditorPageState extends State<EffectEditorPage> {
  late EffectEditorProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = EffectEditorProvider();
    _provider.setBaseImage(widget.imageFile);
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  final List<EffectOverlay> _effects = const [
    // ── Butterfly ──────────────────────────────────────────────
    EffectOverlay(
      id: 'Butterfly 1',
      category: 'Butterfly',
      assetPath: 'assets/effects/potrait/Butterfly/1.png',
      portraitPath: 'assets/effects/potrait/Butterfly/1.png',
      squarePath: 'assets/effects/square/Butterfly/1.png',
      thumbnailPath: 'assets/effects/potrait/Butterfly/1.png',
      blendMode: ui.BlendMode.screen,
    ),
    EffectOverlay(
      id: 'Butterfly 2',
      category: 'Butterfly',
      assetPath: 'assets/effects/potrait/Butterfly/2.png',
      portraitPath: 'assets/effects/potrait/Butterfly/2.png',
      squarePath: 'assets/effects/square/Butterfly/2.png',
      thumbnailPath: 'assets/effects/potrait/Butterfly/2.png',
      blendMode: ui.BlendMode.screen,
    ),
    // ── Flower ─────────────────────────────────────────────────
    EffectOverlay(
      id: 'Flower 1',
      category: 'Flower',
      assetPath: 'assets/effects/potrait/Flower/1.png',
      portraitPath: 'assets/effects/potrait/Flower/1.png',
      squarePath: 'assets/effects/square/Flower/1.png',
      thumbnailPath: 'assets/effects/potrait/Flower/1.png',
      blendMode: ui.BlendMode.screen,
    ),
    // ── Heart ──────────────────────────────────────────────────
    EffectOverlay(
      id: 'Heart 1',
      category: 'Heart',
      assetPath: 'assets/effects/potrait/Heart/1.png',
      portraitPath: 'assets/effects/potrait/Heart/1.png',
      squarePath: 'assets/effects/square/Heart/1.png',
      thumbnailPath: 'assets/effects/potrait/Heart/1.png',
      blendMode: ui.BlendMode.screen,
    ),
    // ── Neon Light ──────────────────────────────────────────────
    EffectOverlay(
      id: 'Neon 1',
      category: 'Neon Light',
      assetPath: 'assets/effects/potrait/Neon Light/1.png',
      portraitPath: 'assets/effects/potrait/Neon Light/1.png',
      squarePath: 'assets/effects/potrait/Neon Light/1.png',
      thumbnailPath: 'assets/effects/potrait/Neon Light/1.png',
      blendMode: ui.BlendMode.plus,
    ),
    // ── Star ───────────────────────────────────────────────────
    EffectOverlay(
      id: 'Star 1',
      category: 'Star',
      assetPath: 'assets/effects/potrait/Star/1.png',
      portraitPath: 'assets/effects/potrait/Star/1.png',
      squarePath: 'assets/effects/square/Star/1.png',
      thumbnailPath: 'assets/effects/potrait/Star/1.png',
      blendMode: ui.BlendMode.plus,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return ChangeNotifierProvider.value(
      value: _provider,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Overlays',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          actions: [
            TextButton(
              onPressed: _exportImage,
              child: const Text(
                'SAVE',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // Preview Area
            Expanded(
              child: Consumer<EffectEditorProvider>(
                builder: (context, provider, child) {
                  return EffectOverlayPreview(
                    baseImage: provider.baseImage,
                    overlayImage: provider.overlayImage,
                    opacity: provider.opacity,
                    blendMode:
                        provider.selectedEffect?.blendMode ??
                        ui.BlendMode.screen,
                  );
                },
              ),
            ),

            // Controls Area
            Container(
              padding: EdgeInsets.all(w * 0.05),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.8),
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(w * 0.03),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Opacity Slider
                  Consumer<EffectEditorProvider>(
                    builder: (context, provider, child) {
                      if (provider.selectedEffect == null) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Intensity',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                              Text(
                                '${(provider.opacity * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          Slider(
                            value: provider.opacity,
                            min: 0.0,
                            max: 1.0,
                            activeColor: Colors.blueAccent,
                            onChanged: (val) => provider.setOpacity(val),
                          ),
                        ],
                      );
                    },
                  ),

                  SizedBox(height: MediaQuery.of(context).size.height * 0.01),

                  // Effect Selector
                  Consumer<EffectEditorProvider>(
                    builder: (context, provider, child) {
                      return EffectSelectorBar(
                        effects: _effects,
                        selectedEffect: provider.selectedEffect,
                        onEffectSelected: (effect) =>
                            provider.selectEffect(effect),
                        onClear: () => provider.clearEffect(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportImage() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final exportedFile = await _provider.exportFinalImage();

      if (mounted) {
        Navigator.pop(context); // Close loading
        // For now, just show a success snackbar. In a real app, you'd navigate to a share screen.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Image exported to ${exportedFile.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }
}
