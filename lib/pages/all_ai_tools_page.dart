import 'package:flutter/material.dart';
import '../Core/colors.dart';
import '../Core/directory.dart';
import '../Core/routes.dart';
import '../Core/strings.dart'; // non-translatable
import 'package:localization/localization.dart';

import 'settings_page.dart';
import '../Widgets/topbar.dart';
import '../Widgets/ai_tools_grid.dart';
import '../Services/credit_service.dart';

class AllAiToolsPage extends StatefulWidget {
  const AllAiToolsPage({super.key});

  @override
  State<AllAiToolsPage> createState() => _AllAiToolsPageState();
}

class _AllAiToolsPageState extends State<AllAiToolsPage> {
  final CreditService _creditService = CreditService();

  @override
  void initState() {
    super.initState();
    _creditService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(isDark),
      body: SafeArea(
        child: Column(
          children: [
            // Credits top bar
            const TopBar(),

            // Navigation Bar Area
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: w * 0.04,
                vertical: h * 0.015,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Material(
                    color: isDark ? Colors.grey[850] : Colors.grey[200],
                    shape: const CircleBorder(),
                    clipBehavior: Clip.hardEdge,
                    child: InkWell(
                      onTap: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          Navigator.pushReplacementNamed(
                            context,
                            AppRoutes.home,
                          );
                        }
                      },
                      child: Padding(
                        padding: EdgeInsets.all(w * 0.03),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          size: w * 0.05,
                          color: AppColors.textColor(isDark),
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'all_ai_tools'.i18n(),
                    style: TextStyle(
                      fontSize: w * 0.05,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textColor(isDark),
                    ),
                  ),
                  Material(
                    color: isDark ? Colors.grey[850] : Colors.grey[200],
                    shape: const CircleBorder(),
                    clipBehavior: Clip.hardEdge,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsPage(),
                          ),
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.all(w * 0.03),
                        child: Icon(
                          Icons.settings_outlined,
                          size: w * 0.05,
                          color: AppColors.textColor(isDark),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: w * 0.04),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: h * 0.02),
                    // Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white : Colors.grey[200],
                        borderRadius: BorderRadius.circular(w * 0.06),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: w * 0.04,
                        vertical: h * 0.013,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            size: w * 0.06,
                          ),
                          SizedBox(width: w * 0.02),
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: AppStrings.searchToolsHint,
                                hintStyle: TextStyle(
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[600],
                                  fontSize: w * 0.035,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                              ),
                              style: TextStyle(
                                color: AppColors.textColor(isDark),
                                fontSize: w * 0.035,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.mic_none_outlined,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            size: w * 0.06,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: h * 0.03),

                    // Video Category
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: w * 0.04,
                        vertical: h * 0.007,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.videoCategoryColor,
                        borderRadius: BorderRadius.circular(w * 0.04),
                      ),
                      child: Text(
                        'video_category'.i18n(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: w * 0.03,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: h * 0.02),
                    AiToolsGrid(isDark: isDark, tools: [
                      AiTool(
                        'ai_video_tool'.i18n(),
                        AppDirectories.iconAiVideo,
                        initialCategory: 'video',
                      ),
                    ]),

                    SizedBox(height: h * 0.03),

                    // Image Category
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: w * 0.04,
                        vertical: h * 0.007,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.imageCategoryColor,
                        borderRadius: BorderRadius.circular(w * 0.04),
                      ),
                      child: Text(
                        'image_category'.i18n(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: w * 0.03,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: h * 0.02),
                    AiToolsGrid(isDark: isDark, tools: [
                      AiTool(
                        'tool_ai_image'.i18n(),
                        AppDirectories.iconAiImage,
                      ),
                      AiTool(
                        'tool_upscale'.i18n(),
                        AppDirectories.iconUpscale,
                        route: AppRoutes.upscale,
                      ),
                      AiTool(
                        'clothswap'.i18n(),
                        AppDirectories.iconCloth,
                        route: AppRoutes.outfitChange,
                      ),
                      AiTool(
                        'background_ai'.i18n(),
                        AppDirectories.iconBgAi,
                        route: AppRoutes.background,
                      ),
                      AiTool(
                        'ai_filter_style'.i18n(),
                        AppDirectories.iconFilterStyle,
                        route: AppRoutes.filter,
                      ),
                      AiTool('ai_restore'.i18n(), AppDirectories.iconRestore, route: AppRoutes.restore),
                      AiTool('ai_sticker'.i18n(), AppDirectories.iconSticker, route: AppRoutes.sticker),
                      AiTool(
                        'ai_headshot'.i18n(),
                        AppDirectories.iconHeadshot,
                        route: AppRoutes.headshot,
                      ),
                      AiTool(
                        'pic_collage'.i18n(),
                        AppDirectories.iconPicCollage,
                        route: AppRoutes.collage,
                      ),
                      AiTool(
                        'ai_logo'.i18n(),
                        AppDirectories.iconLogo,
                        route: AppRoutes.logo,
                      ),
                    ]),

                    SizedBox(height: h * 0.04),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
