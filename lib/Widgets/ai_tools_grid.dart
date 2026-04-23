import 'package:flutter/material.dart';
import '../Core/colors.dart';
import '../pages/generation_page.dart';
import '../pages/ai_tool_demo_page.dart';

class AiTool {
  final String label;
  final String imagePath;
  final String? route;
  final String? initialCategory;

  const AiTool(
    this.label,
    this.imagePath, {
    this.route,
    this.initialCategory,
  });
}

class AiToolsGrid extends StatelessWidget {
  final List<AiTool> tools;
  final bool isDark;
  final int crossAxisCount;
  final double childAspectRatio;
  final double? mainAxisSpacing;

  const AiToolsGrid({
    super.key,
    required this.tools,
    required this.isDark,
    this.crossAxisCount = 2,
    this.childAspectRatio = 3.3,
    this.mainAxisSpacing,
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
