import 'dart:convert';
import 'package:flutter/material.dart';
import '../Core/colors.dart';
import '../Core/directory.dart';
import '../Core/routes.dart';
import 'package:localization/localization.dart';

import 'settings_page.dart';
import '../Widgets/ai_tools_grid.dart';
import '../Services/credit_service.dart';
import '../Services/remote_config_service.dart';
import '../Widgets/main_navigation.dart';
import '../pages/ai_tool_demo_page.dart';
import '../pages/generation_page.dart';

// ─── Data Model ───────────────────────────────────────────────────────────────
class _ToolEntry {
  final AiTool tool;
  final String subtitle;
  final Color iconBg;
  // 'all' means appears in every tab
  final String category; // 'video' | 'image' | 'all'
  final bool isPopular;

  const _ToolEntry({
    required this.tool,
    required this.subtitle,
    required this.iconBg,
    this.category = 'all',
    this.isPopular = false,
  });
}

// ─── Tool Registry ────────────────────────────────────────────────────────────
List<_ToolEntry> _buildRegistry(BuildContext context) => [
  _ToolEntry(
    tool: AiTool(
      id: 'video',
      label: 'ai_video_tool'.i18n(),
      imagePath: AppDirectories.iconAiVideo,
      initialCategory: 'video',
    ),
    subtitle: 'Create stunning videos',
    iconBg: const Color(0xFF1A3A2A),
    category: 'video',
    isPopular: true,
  ),
  _ToolEntry(
    tool: AiTool(
      id: 'image',
      label: 'tool_ai_image'.i18n(),
      imagePath: AppDirectories.iconAiImage,
    ),
    subtitle: 'Generate amazing images',
    iconBg: const Color(0xFF1A2A3E),
    category: 'image',
    isPopular: true,
  ),
  _ToolEntry(
    tool: AiTool(
      id: 'upscale',
      label: 'tool_upscale'.i18n(),
      imagePath: AppDirectories.iconUpscale,
      route: AppRoutes.upscale,
    ),
    subtitle: 'Enhance image quality',
    iconBg: const Color(0xFF3A1A0A),
    category: 'all',
    isPopular: true,
  ),
  _ToolEntry(
    tool: AiTool(
      id: 'background',
      label: 'background_ai'.i18n(),
      imagePath: AppDirectories.iconBgAi,
      route: AppRoutes.background,
    ),
    subtitle: 'Remove or change background',
    iconBg: const Color(0xFF2A1A3E),
    category: 'all',
    isPopular: true,
  ),
  _ToolEntry(
    tool: AiTool(
      id: 'cloth',
      label: 'clothswap'.i18n(),
      imagePath: AppDirectories.iconCloth,
      route: AppRoutes.outfitChange,
    ),
    subtitle: 'Try different outfits instantly',
    iconBg: const Color(0xFF2E1A00),
    category: 'all',
  ),
  _ToolEntry(
    tool: AiTool(
      id: 'restore',
      label: 'ai_restore'.i18n(),
      imagePath: AppDirectories.iconRestore,
      route: AppRoutes.restore,
    ),
    subtitle: 'Restore old or damaged photos',
    iconBg: const Color(0xFF1A2E1A),
    category: 'all',
  ),
  _ToolEntry(
    tool: AiTool(
      id: 'filter',
      label: 'ai_filter_style'.i18n(),
      imagePath: AppDirectories.iconFilterStyle,
      route: AppRoutes.filter,
    ),
    subtitle: 'Apply stunning AI filters',
    iconBg: const Color(0xFF2A1E00),
    category: 'all',
  ),
  _ToolEntry(
    tool: AiTool(
      id: 'headshot',
      label: 'ai_headshot'.i18n(),
      imagePath: AppDirectories.iconHeadshot,
      route: AppRoutes.headshot,
    ),
    subtitle: 'Professional AI headshots',
    iconBg: const Color(0xFF002E2E),
    category: 'all',
  ),
  _ToolEntry(
    tool: AiTool(
      id: 'sticker',
      label: 'ai_sticker'.i18n(),
      imagePath: AppDirectories.iconSticker,
      route: AppRoutes.sticker,
    ),
    subtitle: 'Create custom AI stickers',
    iconBg: const Color(0xFF2A2A2A),
    category: 'all',
  ),
  _ToolEntry(
    tool: AiTool(
      id: 'collage',
      label: 'pic_collage'.i18n(),
      imagePath: AppDirectories.iconPicCollage,
      route: AppRoutes.collage,
    ),
    subtitle: 'Create beautiful collages',
    iconBg: const Color(0xFF2A001A),
    category: 'all',
  ),
  _ToolEntry(
    tool: AiTool(
      id: 'logo',
      label: 'ai_logo'.i18n(),
      imagePath: AppDirectories.iconLogo,
      route: AppRoutes.logo,
    ),
    subtitle: 'Design unique logos',
    iconBg: const Color(0xFF002A1A),
    category: 'all',
  ),
];

// ─── Badge helper ─────────────────────────────────────────────────────────────
// Returns only the first badge text string for a tool id (without emoji prefix).
// The badge text from Remote Config may already contain an emoji so we strip
// leading emoji/whitespace and let _buildBadge re-add the correct one.
Map<String, String> _loadFirstBadge() {
  try {
    final str = RemoteConfigService().toolBadgesJson;
    if (str.isEmpty) return {};
    final map = jsonDecode(str) as Map<String, dynamic>;
    final result = <String, String>{};
    for (final entry in map.entries) {
      if (entry.value is List) {
        final list = entry.value as List;
        for (final b in list) {
          String raw = '';
          if (b is String) raw = b;
          if (b is Map) raw = b['text']?.toString() ?? '';
          if (raw.isNotEmpty) {
            // Strip leading emoji characters so we only store the word (e.g. "Trend", "Popular")
            final stripped = raw
                .replaceAll(
                  RegExp(
                    r'^[\s\u{1F300}-\u{1FFFF}\u{2600}-\u{27BF}⭐🔥]+',
                    unicode: true,
                  ),
                  '',
                )
                .trim();
            result[entry.key] = stripped.isEmpty ? raw.trim() : stripped;
            break;
          }
        }
      }
    }
    return result;
  } catch (_) {
    return {};
  }
}

// ─── Page ─────────────────────────────────────────────────────────────────────
class AllAiToolsPage extends StatefulWidget {
  const AllAiToolsPage({super.key});

  @override
  State<AllAiToolsPage> createState() => _AllAiToolsPageState();
}

class _AllAiToolsPageState extends State<AllAiToolsPage> {
  final CreditService _creditService = CreditService();
  final TextEditingController _searchController = TextEditingController();

  List<_ToolEntry> _registry = [];
  Map<String, String> _badges = {};

  String _selectedCategory = 'all';
  String _searchQuery = '';

  static const List<Map<String, String>> _categories = [
    {'key': 'all', 'label': 'All'},
    {'key': 'video', 'label': 'Video'},
    {'key': 'image', 'label': 'Image'},
  ];

  // Popular Picks accent border colors per tool id
  static const Map<String, Color> _accentColors = {
    'video': Color(0xFF00C853),
    'image': Color(0xFF2196F3),
    'upscale': Color(0xFFFF9800),
    'background': Color(0xFF9C27B0),
  };

  @override
  void initState() {
    super.initState();
    _creditService.initialize();
    _badges = _loadFirstBadge();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_registry.isEmpty) {
      _registry = _buildRegistry(context);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ─── Computed Lists ───────────────────────────────────────────────────────

  List<_ToolEntry> get _popularTools =>
      _registry.where((e) => e.isPopular).toList();

  List<_ToolEntry> get _filteredTools {
    final q = _searchQuery.toLowerCase().trim();
    return _registry.where((e) {
      // Tab filter: 'all' tab shows everything;
      // 'video'/'image' tabs show tools with that category OR 'all' category
      final matchCat =
          _selectedCategory == 'all' ||
          e.category == _selectedCategory ||
          e.category == 'all';
      final matchSearch =
          q.isEmpty ||
          e.tool.label.toLowerCase().contains(q) ||
          e.subtitle.toLowerCase().contains(q);
      return matchCat && matchSearch;
    }).toList();
  }

  // ─── Navigation ───────────────────────────────────────────────────────────

  void _navigateToTool(AiTool tool) {
    if (tool.route != null && AiToolDemoPage.hasDemo(tool)) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => AiToolDemoPage(tool: tool)),
      );
    } else if (tool.route != null) {
      Navigator.pushNamed(context, tool.route!);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              GenerationPage(initialCategory: tool.initialCategory ?? 'image'),
        ),
      );
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(isDark),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(isDark, sw, sh),
            _buildSearchBar(isDark, sw, sh),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.only(bottom: sh * 0.15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: sh * 0.025),
                    _buildPopularSection(isDark, sw, sh),
                    SizedBox(height: sh * 0.025),
                    _buildCategoryTabs(isDark, sw, sh),
                    SizedBox(height: sh * 0.018),
                    _buildToolsList(isDark, sw, sh),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────
  Widget _buildHeader(bool isDark, double sw, double sh) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: sw * 0.04,
        vertical: sh * 0.015,
      ),
      child: Row(
        children: [
          _circleButton(
            isDark: isDark,
            sw: sw,
            icon: Icons.arrow_back_ios_new,
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                final nav = context
                    .findAncestorStateOfType<MainNavigationState>();
                if (nav != null) {
                  nav.switchTab(0);
                } else {
                  Navigator.pushReplacementNamed(context, AppRoutes.home);
                }
              }
            },
          ),
          Expanded(
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  fontSize: sw * 0.055,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textColor(isDark),
                ),
                children: const [
                  TextSpan(text: 'All '),
                  TextSpan(
                    text: 'AI',
                    style: TextStyle(color: Color(0xFFFF4500)),
                  ),
                  TextSpan(text: ' Tools'),
                ],
              ),
            ),
          ),
          _circleButton(
            isDark: isDark,
            sw: sw,
            icon: Icons.settings_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton({
    required bool isDark,
    required double sw,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: sw * 0.1,
        height: sw * 0.1,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.grey.shade200,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: sw * 0.045, color: AppColors.textColor(isDark)),
      ),
    );
  }

  // ── Search Bar ─────────────────────────────────────────────────────────────
  Widget _buildSearchBar(bool isDark, double sw, double sh) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: sw * 0.04),
      child: Container(
        height: sh * 0.055,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF222222) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(sw * 0.04),
          border: Border.all(
            color: isDark ? const Color(0xFF333333) : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: sw * 0.04),
            Icon(
              Icons.search,
              color: AppColors.secondaryTextColor(isDark),
              size: sw * 0.05,
            ),
            SizedBox(width: sw * 0.03),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(
                  color: AppColors.textColor(isDark),
                  fontSize: sw * 0.038,
                ),
                decoration: InputDecoration(
                  hintText: 'Search tools...',
                  hintStyle: TextStyle(
                    color: AppColors.secondaryTextColor(isDark),
                    fontSize: sw * 0.038,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Popular Picks ──────────────────────────────────────────────────────────
  Widget _buildPopularSection(bool isDark, double sw, double sh) {
    final popular = _popularTools;
    if (popular.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: sw * 0.04),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              SizedBox(width: sw * 0.02),
              Text(
                'Popular Picks',
                style: TextStyle(
                  color: AppColors.textColor(isDark),
                  fontSize: sw * 0.045,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: sh * 0.015),
        SizedBox(
          height: sh * 0.22,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: sw * 0.04),
            separatorBuilder: (_, _) => SizedBox(width: sw * 0.03),
            itemCount: popular.length,
            itemBuilder: (_, i) =>
                _buildPopularCard(popular[i], isDark, sw, sh),
          ),
        ),
      ],
    );
  }

  Widget _buildPopularCard(
    _ToolEntry entry,
    bool isDark,
    double sw,
    double sh,
  ) {
    final badgeText = _badges[entry.tool.id];
    final accentColor = _accentColors[entry.tool.id] ?? const Color(0xFF444444);

    return GestureDetector(
      onTap: () => _navigateToTool(entry.tool),
      child: Container(
        width: sw * 0.35,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1C) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(sw * 0.05),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
        padding: EdgeInsets.all(sw * 0.035),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon box
            Container(
              width: sw * 0.12,
              height: sw * 0.12,
              decoration: BoxDecoration(
                color: entry.iconBg,
                borderRadius: BorderRadius.circular(sw * 0.03),
              ),
              padding: EdgeInsets.all(sw * 0.02),
              child: Image.asset(entry.tool.imagePath, fit: BoxFit.contain),
            ),
            const Spacer(),
            Text(
              entry.tool.label,
              style: TextStyle(
                color: AppColors.textColor(isDark),
                fontSize: sw * 0.034,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: sh * 0.004),
            Text(
              entry.subtitle,
              style: TextStyle(
                color: AppColors.secondaryTextColor(isDark),
                fontSize: sw * 0.027,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (badgeText != null) ...[
              SizedBox(height: sh * 0.007),
              _buildBadge(badgeText, sw),
            ],
          ],
        ),
      ),
    );
  }

  // ── Category Tabs ──────────────────────────────────────────────────────────
  Widget _buildCategoryTabs(bool isDark, double sw, double sh) {
    return SizedBox(
      height: sh * 0.045,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: sw * 0.04),
        separatorBuilder: (_, _) => SizedBox(width: sw * 0.025),
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final isSelected = _selectedCategory == cat['key'];
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat['key']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(horizontal: sw * 0.05),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFF4500)
                    : (isDark ? const Color(0xFF222222) : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(sw * 0.06),
                border: isSelected
                    ? null
                    : Border.all(
                        color: isDark
                            ? const Color(0xFF333333)
                            : Colors.grey.shade300,
                      ),
              ),
              alignment: Alignment.center,
              child: Text(
                cat['label']!,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : AppColors.secondaryTextColor(isDark),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: sw * 0.035,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Tools List (2-column cards) ────────────────────────────────────────────
  Widget _buildToolsList(bool isDark, double sw, double sh) {
    final tools = _filteredTools;
    if (tools.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: sh * 0.06),
        child: Center(
          child: Text(
            'No tools found',
            style: TextStyle(color: AppColors.secondaryTextColor(isDark)),
          ),
        ),
      );
    }

    // Group into rows of 2
    final rows = <List<_ToolEntry>>[];
    for (var i = 0; i < tools.length; i += 2) {
      rows.add(
        tools.sublist(i, (i + 2 <= tools.length) ? i + 2 : tools.length),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: sw * 0.04),
      child: Column(
        children: rows.map((row) {
          return Padding(
            padding: EdgeInsets.only(bottom: sw * 0.03),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildToolCard(row[0], isDark, sw, sh)),
                SizedBox(width: sw * 0.03),
                row.length > 1
                    ? Expanded(child: _buildToolCard(row[1], isDark, sw, sh))
                    : const Expanded(child: SizedBox()),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildToolCard(_ToolEntry entry, bool isDark, double sw, double sh) {
    final badgeText = _badges[entry.tool.id];

    return GestureDetector(
      onTap: () => _navigateToTool(entry.tool),
      child: Container(
        padding: EdgeInsets.all(sw * 0.035),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1C) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(sw * 0.04),
          border: Border.all(
            color: isDark ? const Color(0xFF2E2E2E) : Colors.grey.shade300,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: sw * 0.1,
                  height: sw * 0.1,
                  decoration: BoxDecoration(
                    color: entry.iconBg,
                    borderRadius: BorderRadius.circular(sw * 0.025),
                  ),
                  padding: EdgeInsets.all(sw * 0.017),
                  child: Image.asset(entry.tool.imagePath, fit: BoxFit.contain),
                ),
                const Spacer(),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.secondaryTextColor(isDark),
                  size: sw * 0.045,
                ),
              ],
            ),
            SizedBox(height: sh * 0.01),
            Text(
              entry.tool.label,
              style: TextStyle(
                color: AppColors.textColor(isDark),
                fontSize: sw * 0.034,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: sh * 0.003),
            Text(
              entry.subtitle,
              style: TextStyle(
                color: AppColors.secondaryTextColor(isDark),
                fontSize: sw * 0.027,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (badgeText != null) ...[
              SizedBox(height: sh * 0.006),
              _buildBadge(badgeText, sw),
            ],
          ],
        ),
      ),
    );
  }

  // ── Badge ──────────────────────────────────────────────────────────────────
  Widget _buildBadge(String text, double sw) {
    // text here is already stripped of leading emoji by _loadFirstBadge
    final isPopular = text.toLowerCase().contains('popular');
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(isPopular ? '⭐' : '🔥', style: TextStyle(fontSize: sw * 0.028)),
        SizedBox(width: sw * 0.01),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              color: isPopular
                  ? const Color(0xFFFFB800)
                  : const Color(0xFFFF4500),
              fontSize: sw * 0.028,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
