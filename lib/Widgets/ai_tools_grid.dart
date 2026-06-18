import 'dart:convert';
import 'package:flutter/material.dart';
import '../Core/colors.dart';
import '../Services/remote_config_service.dart';
import '../pages/generation_page.dart';
import '../pages/ai_tool_demo_page.dart';

class AiTool {
  final String id;
  final String label;
  final String imagePath;
  final String? route;
  final String? initialCategory;
  final bool autoTriggerImagePicker;

  const AiTool({
    required this.id,
    required this.label,
    required this.imagePath,
    this.route,
    this.initialCategory,
    this.autoTriggerImagePicker = false,
  });
}

class AiToolsGrid extends StatelessWidget {
  final List<AiTool> tools;
  final bool isDark;
  final int crossAxisCount;
  final double childAspectRatio;
  final double? mainAxisSpacing;
  final bool showBadges;

  const AiToolsGrid({
    super.key,
    required this.tools,
    required this.isDark,
    this.crossAxisCount = 2,
    this.childAspectRatio = 3.3,
    this.mainAxisSpacing,
    this.showBadges = false,
  });

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final spacing = mainAxisSpacing ?? w * 0.03;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tools.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: w * 0.03,
        mainAxisSpacing: spacing,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) {
        final tool = tools[index];

        List<Widget> badgeWidgets = [];
        if (showBadges) {
          try {
            final String badgesStr = RemoteConfigService().toolBadgesJson;
            if (badgesStr.isNotEmpty) {
              final toolBadges = jsonDecode(badgesStr) as Map<String, dynamic>;
              final toolSpecificBadges = toolBadges[tool.id];
              
              if (toolSpecificBadges is List) {
                for (var badge in toolSpecificBadges) {
                  String text = '';
                  if (badge is String) {
                    text = badge;
                  } else if (badge is Map) {
                    text = badge['text']?.toString() ?? '';
                  }
                  
                  if (text.isNotEmpty) {
                    badgeWidgets.add(
                      Padding(
                        padding: EdgeInsets.only(bottom: w * 0.005),
                        child: Text(
                          text,
                          style: TextStyle(
                            fontSize: w * 0.022,
                            color: AppColors.secondaryTextColor(isDark),
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    );
                  }
                }
              }
            }
          } catch (e) {
            debugPrint('Error parsing tool_badges: $e');
          }
        }

        return GestureDetector(
          onTap: () {
            if (tool.route != null && AiToolDemoPage.hasDemo(tool)) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AiToolDemoPage(tool: tool),
                ),
              );
            } else if (tool.route != null) {
              Navigator.pushNamed(context, tool.route!);
            } else {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => GenerationPage(
                    initialCategory: tool.initialCategory ?? 'image',
                    autoTriggerImagePicker: tool.autoTriggerImagePicker,
                  ),
                ),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.toolItemBackground(isDark),
              borderRadius: BorderRadius.circular(w * 0.02),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.grey.shade300,
                width: w * 0.003,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: w * 0.02),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Image.asset(
                    tool.imagePath,
                    width: w * 0.075,
                    height: w * 0.075,
                  ),
                  SizedBox(width: w * 0.015),
                  Expanded(
                    child: Text(
                      tool.label,
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                      style: TextStyle(
                        fontSize: w * 0.03,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textColor(isDark),
                        height: 1.1,
                      ),
                    ),
                  ),
                  if (badgeWidgets.isNotEmpty) ...[
                    SizedBox(width: w * 0.01),
                    Container(
                      padding: EdgeInsets.only(left: w * 0.01),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: badgeWidgets,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
