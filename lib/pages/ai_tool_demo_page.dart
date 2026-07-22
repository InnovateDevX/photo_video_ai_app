import 'package:flutter/material.dart';
import 'package:vidzeon/Core/gradient.dart';
import 'package:vidzeon/Services/remote_config_service.dart';
import 'package:vidzeon/Services/replicate_service.dart';
import 'package:vidzeon/Widgets/ai_tools_grid.dart';
import 'package:vidzeon/Widgets/reel_video_player.dart';
import 'package:vidzeon/pages/generation_page.dart';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';

class AiToolDemoPage extends StatefulWidget {
  final AiTool tool;

  const AiToolDemoPage({super.key, required this.tool});

  static bool hasDemo(AiTool tool) {
    final rc = RemoteConfigService();
    try {
      final jsonStr = rc.getString('tool_demos');
      if (jsonStr.isNotEmpty && jsonStr != '[]' && jsonStr != '{}') {
        final Map<String, dynamic> configMap = jsonDecode(jsonStr);
        final String searchKey = tool.route ?? tool.label;
        if (configMap.containsKey(searchKey)) {
          final toolData = configMap[searchKey] as Map<String, dynamic>;
          final String? url = toolData['videoUrl'] ?? toolData['videourl'];
          final String? img = toolData['imageUrl'] ?? toolData['imageurl'];
          return (url != null && url.isNotEmpty) ||
              (img != null && img.isNotEmpty);
        }
      }
    } catch (e) {
      debugPrint("Error checking tool_demos: $e");
    }
    return false;
  }

  @override
  State<AiToolDemoPage> createState() => _AiToolDemoPageState();
}

class _AiToolDemoPageState extends State<AiToolDemoPage> {
  String? _videoUrl;
  String? _imageUrl;
  String _description = "";
  int _creditCost = 0;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _loadDemoConfig();
  }

  Future<void> _loadDemoConfig() async {
    // 1. Fetch URLs and metadata synchronously so the UI renders the image immediately
    final rc = RemoteConfigService();
    Map<String, dynamic>? currentToolData;

    try {
      final jsonStr = rc.getString('tool_demos');
      if (jsonStr.isNotEmpty && jsonStr != '[]' && jsonStr != '{}') {
        final Map<String, dynamic> configMap = jsonDecode(jsonStr);
        final String searchKey = widget.tool.route ?? widget.tool.label;
        if (configMap.containsKey(searchKey)) {
          currentToolData = configMap[searchKey] as Map<String, dynamic>;
          _videoUrl =
              currentToolData['videoUrl'] ?? currentToolData['videourl'];
          _imageUrl =
              currentToolData['imageUrl'] ?? currentToolData['imageurl'];
          _description =
              currentToolData['description'] ?? "Experience the power of AI.";
        }
      }
    } catch (e) {
      debugPrint("Error parsing tool_demos synchronously: $e");
    }

    // IMMEDIATELY fall back if videoUrl is unavailable despite checks
    if (_videoUrl == null || _videoUrl!.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _proceedToTool();
      });
      return;
    }

    // 2. Fetch dynamic credit cost asynchronously using initialized services
    final rs = ReplicateService();
    await rs.initialize();

    AIModelConfig? modelConfig;
    switch (widget.tool.route) {
      case '/upscale':
        modelConfig = rs.upscaleModel;
        break;
      case '/outfitChange':
        modelConfig = rs.clothModel;
        break;
      case '/background':
        modelConfig = rs.backgroundModel;
        break;
      case '/restore':
        modelConfig = rs.restoreModel;
        break;
      case '/headshot':
        modelConfig = rs.headshotModel;
        break;
      // case '/sticker':
      //   modelConfig = rs.stickerTextModel ?? rs.stickerImageModel;
      //   break;
      case '/collage':
        modelConfig = rs.collageModel;
        break;
      case '/logo':
        modelConfig = rs.logoModel;
        break;
    }

    if (modelConfig == null) {
      if (widget.tool.initialCategory == 'video' && rs.videoModels.isNotEmpty) {
        modelConfig = rs.videoModels.first;
      } else if (widget.tool.initialCategory == 'image' &&
          rs.imageModels.isNotEmpty) {
        modelConfig = rs.imageModels.first;
      }
    }

    if (modelConfig != null) {
      _creditCost = modelConfig.creditUsed;
    } else {
      _creditCost = 10;
    }

    if (currentToolData != null) {
      final configKey = currentToolData['configKey'];
      if (configKey != null && configKey is String && configKey.isNotEmpty) {
        final configStr = rc.getString(configKey);
        if (configStr.isNotEmpty && configStr != '{}' && configStr != '[]') {
          try {
            final decoded = jsonDecode(configStr);
            if (decoded is Map<String, dynamic> &&
                decoded.containsKey('credit_used')) {
              _creditCost = (decoded['credit_used'] as num).toInt();
            } else if (decoded is List &&
                decoded.isNotEmpty &&
                decoded.first is Map<String, dynamic> &&
                decoded.first.containsKey('credit_used')) {
              _creditCost = (decoded.first['credit_used'] as num).toInt();
            }
          } catch (e) {
            /* ignore parse error */
          }
        }
      }
    }

    if (mounted) setState(() {});
  }

  Future<void> _proceedToTool() async {
    if (_isNavigating) return;

    if (mounted) {
      setState(() => _isNavigating = true);
    }

    // Give the system a moment to dispose of the video hardware
    await Future.delayed(const Duration(milliseconds: 150));

    if (!mounted) return;

    if (widget.tool.route != null) {
      Navigator.pushReplacementNamed(context, widget.tool.route!);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => GenerationPage(
            showCategoryToggle: false,
            initialCategory: widget.tool.initialCategory ?? 'image',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // If videoUrl is null, we return a blank loading screen briefly while it falls back
    if ((_videoUrl == null || _videoUrl!.isEmpty) &&
        (_imageUrl == null || _imageUrl!.isEmpty)) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final sw = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Video, delayed to avoid MediaCodec freezing during page transition
          FutureBuilder(
            future: Future.delayed(const Duration(milliseconds: 350)),
            builder: (context, snapshot) {
              final Widget placeholderWidget =
                  _imageUrl != null && _imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: _imageUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorWidget: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    )
                  : const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );

              if (snapshot.connectionState == ConnectionState.done &&
                  _videoUrl != null &&
                  _videoUrl!.isNotEmpty) {
                return ReelVideoPlayer(
                  videoUrl: _videoUrl!,
                  placeholder: placeholderWidget,
                  seamlessLoop: true,
                  fit: BoxFit.cover,
                );
              }

              return Container(color: Colors.black, child: placeholderWidget);
            },
          ),

          // Gradient overlay for better text visibility
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 350,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.95),
                    Colors.black.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Top Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: EdgeInsets.all(
                  MediaQuery.of(context).size.width * 0.02,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white70,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.black,
                  size: 20,
                ),
              ),
            ),
          ),

          // Bottom Content (Title, text, and Button)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.tool.label,
                  style: TextStyle(
                    color: const Color(0xFFFF4500),
                    fontWeight: FontWeight.bold,
                    fontSize: sw * 0.05,
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                Text(
                  _description,
                  style: TextStyle(color: Colors.white, fontSize: sw * 0.038),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.025),
                GestureDetector(
                  onTap: _proceedToTool,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: ProGradientDecoration(
                      borderRadius: BorderRadius.circular(sw * 0.08),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Generate",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: sw * 0.045,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
