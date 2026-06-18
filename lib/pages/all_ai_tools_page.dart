import 'package:flutter/material.dart';
import '../Core/colors.dart';
import '../Core/directory.dart';
import '../Core/routes.dart';
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
    final screenW = MediaQuery.of(context).size.width;
    final w = screenW > 0 ? screenW : 375.0;
    final screenH = MediaQuery.of(context).size.height;
    final h = screenH > 0 ? screenH : 812.0;

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
                    AiToolsGrid(
                      showBadges: true,
                      isDark: isDark,
                      tools: [
                        AiTool(
                          id: 'video',
                          label: 'ai_video_tool'.i18n(),
                          imagePath: AppDirectories.iconAiVideo,
                          initialCategory: 'video',
                        ),
                      ],
                    ),

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
                    AiToolsGrid(
                      showBadges: true,
                      isDark: isDark,
                      tools: [
                        AiTool(
                          id: 'image',
                          label: 'tool_ai_image'.i18n(),
                          imagePath: AppDirectories.iconAiImage,
                        ),
                        AiTool(
                          id: 'upscale',
                          label: 'tool_upscale'.i18n(),
                          imagePath: AppDirectories.iconUpscale,
                          route: AppRoutes.upscale,
                        ),
                        AiTool(
                          id: 'cloth',
                          label: 'clothswap'.i18n(),
                          imagePath: AppDirectories.iconCloth,
                          route: AppRoutes.outfitChange,
                        ),
                        AiTool(
                          id: 'background',
                          label: 'background_ai'.i18n(),
                          imagePath: AppDirectories.iconBgAi,
                          route: AppRoutes.background,
                        ),
                        AiTool(
                          id: 'filter',
                          label: 'ai_filter_style'.i18n(),
                          imagePath: AppDirectories.iconFilterStyle,
                          route: AppRoutes.filter,
                        ),
                        AiTool(
                          id: 'restore',
                          label: 'ai_restore'.i18n(),
                          imagePath: AppDirectories.iconRestore,
                          route: AppRoutes.restore,
                        ),
                        AiTool(
                          id: 'sticker',
                          label: 'ai_sticker'.i18n(),
                          imagePath: AppDirectories.iconSticker,
                          route: AppRoutes.sticker,
                        ),
                        AiTool(
                          id: 'headshot',
                          label: 'ai_headshot'.i18n(),
                          imagePath: AppDirectories.iconHeadshot,
                          route: AppRoutes.headshot,
                        ),
                        AiTool(
                          id: 'collage',
                          label: 'pic_collage'.i18n(),
                          imagePath: AppDirectories.iconPicCollage,
                          route: AppRoutes.collage,
                        ),
                        AiTool(
                          id: 'logo',
                          label: 'ai_logo'.i18n(),
                          imagePath: AppDirectories.iconLogo,
                          route: AppRoutes.logo,
                        ),
                      ],
                    ),

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
