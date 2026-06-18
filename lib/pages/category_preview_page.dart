import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:trail_ai_app/Widgets/reel_video_player.dart';
import 'package:trail_ai_app/pages/generation_page.dart';
import 'package:trail_ai_app/Services/replicate_service.dart';

class CategoryPreviewPage extends StatelessWidget {
  final String? imageUrl;
  final String? videoUrl;
  final String? prompt;
  final String? modelId;
  final String? type;
  final bool isEditable;
  final bool imageEditMode;
  final VoidCallback? onTryStyle;

  const CategoryPreviewPage({
    super.key,
    this.imageUrl,
    this.videoUrl,
    this.prompt,
    this.modelId,
    this.type,
    this.isEditable = false,
    this.imageEditMode = false,
    this.onTryStyle,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    // Calculate dynamic credit cost
    final replicateService = ReplicateService();
    int creditCost = 0;
    if (imageEditMode) {
      final imgCost = replicateService.imageModels.isNotEmpty
          ? replicateService.imageModels.first.creditUsed
          : 0;
      final vidCost = replicateService.videoModels.isNotEmpty
          ? replicateService.videoModels.first.creditUsed
          : 0;
      creditCost = imgCost + vidCost;
    } else {
      if (modelId != null) {
        final allModels = [
          ...replicateService.imageModels,
          ...replicateService.videoModels,
        ];
        final match = allModels.where((m) => m.id == modelId);
        if (match.isNotEmpty) {
          creditCost = match.first.creditUsed;
        }
      }
      if (creditCost == 0) {
        if (type == 'video') {
          creditCost = replicateService.videoModels.isNotEmpty
              ? replicateService.videoModels.first.creditUsed
              : 0;
        } else {
          creditCost = replicateService.imageModels.isNotEmpty
              ? replicateService.imageModels.first.creditUsed
              : 0;
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.black, // Immersive preview
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Media Layer
          if (videoUrl != null && videoUrl!.isNotEmpty)
            ReelVideoPlayer(
              videoUrl: videoUrl!,
              seamlessLoop: true,
              placeholder: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else if (imageUrl != null && imageUrl!.isNotEmpty)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(top: h * 0.1),
                child: CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.contain,
                  alignment: Alignment.topCenter,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (context, url, error) =>
                      const Icon(Icons.error_outline, color: Colors.white),
                ),
              ),
            )
          else
            const Center(child: Icon(Icons.broken_image, color: Colors.white)),

          // Top gradient for back button visibility
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: h * 0.15,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                ),
              ),
            ),
          ),

          // Back Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          // Bottom Info & Button
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.9), Colors.transparent],
                ),
              ),
              padding: EdgeInsets.fromLTRB(w * 0.05, 0, w * 0.05, w * 0.08),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (prompt != null && prompt!.isNotEmpty) ...[
                    // Small gap so Prompt sits close to image; larger gap before button
                    SizedBox(height: h * 0.008),
                    Text(
                      'Prompt',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: w * 0.035,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: h * 0.005),
                    Text(
                      prompt!,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: w * 0.04),
                    ),
                    SizedBox(height: h * 0.042),
                  ] else
                    SizedBox(height: h * 0.02),
                  SizedBox(
                    width: double.infinity,
                    height: h * 0.065,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF9800), // App orange
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(w * 0.03),
                        ),
                      ),
                      onPressed: () {
                        if (onTryStyle != null) {
                          onTryStyle!();
                        } else {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GenerationPage(
                                initialCategory: type ?? 'image',
                                initialPrompt: prompt ?? '',
                                initialModelId: modelId,
                                initialIsEditable: isEditable,
                              ),
                            ),
                          );
                        }
                      },
                      child: Text(
                        'Try this style ⚡ $creditCost',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: w * 0.045,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
