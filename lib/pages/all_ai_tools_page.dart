import 'dart:convert';
import 'package:flutter/material.dart';
import '../Core/colors.dart';
import '../Core/directory.dart';
import '../Core/routes.dart';
import 'package:vidzeon/Widgets/ai_tools_grid.dart';
import '../Widgets/pro_pill.dart';
import '../Services/credit_service.dart';
import '../Services/remote_config_service.dart';
import '../Widgets/main_navigation.dart';
import 'package:vidzeon/pages/ai_tool_demo_page.dart';
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

  _ToolEntry copyWith({bool? isPopular}) {
    return _ToolEntry(
      tool: tool,
      subtitle: subtitle,
      iconBg: iconBg,
      category: category,
      isPopular: isPopular ?? this.isPopular,
    );
  }
}

// ─── Tool Registry ────────────────────────────────────────────────────────────
List<_ToolEntry> _buildRegistry(BuildContext context) {
  final popularStr = RemoteConfigService().popularAiTools;
  final popularIds = popularStr.isEmpty
      ? ['video', 'image', 'upscale', 'background']
      : popularStr.split(',').map((e) => e.trim()).toList();

  final rawEntries = [
    _ToolEntry(
      tool: AiTool(
        id: 'video',
        label: 'AI Video',
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
        label: 'AI Image',
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
        label: 'Upscale',
        imagePath: AppDirectories.iconUpscale,
        route: AppRoutes.upscale,
      ),
      subtitle: 'Enhance image quality',
      iconBg: const Color(0xFF3A1A0A),
      category: 'image',
      isPopular: true,
    ),
    _ToolEntry(
      tool: AiTool(
        id: 're_edit',
        label: 'Re-Edit',
        imagePath: AppDirectories.iconReEdit,
      ),
      subtitle: 'Edit images with premium tools',
      iconBg: const Color(0xFF1E2A38),
      category: 'image',
    ),
    _ToolEntry(
      tool: AiTool(
        id: 'background',
        label: 'Background AI',
        imagePath: AppDirectories.iconBgAi,
        route: AppRoutes.background,
      ),
      subtitle: 'Remove or change background',
      iconBg: const Color(0xFF2A1A3E),
      category: 'image',
      isPopular: true,
    ),
    _ToolEntry(
      tool: AiTool(
        id: 'cloth',
        label: 'Cloth-Changer',
        imagePath: AppDirectories.iconCloth,
        route: AppRoutes.outfitChange,
      ),
      subtitle: 'Try different outfits instantly',
      iconBg: const Color(0xFF2E1A00),
      category: 'image',
    ),
    _ToolEntry(
      tool: AiTool(
        id: 'restore',
        label: 'Restore AI',
        imagePath: AppDirectories.iconRestore,
        route: AppRoutes.restore,
      ),
      subtitle: 'Restore old or damaged photos',
      iconBg: const Color(0xFF1A2E1A),
      category: 'image',
    ),
    _ToolEntry(
      tool: AiTool(
        id: 'filter',
        label: 'AI Filter Style',
        imagePath: AppDirectories.iconFilterStyle,
        route: AppRoutes.filter,
      ),
      subtitle: 'Apply stunning AI filters',
      iconBg: const Color(0xFF2A1E00),
      category: 'image',
    ),
    _ToolEntry(
      tool: AiTool(
        id: 'headshot',
        label: 'Headshot Pic AI',
        imagePath: AppDirectories.iconHeadshot,
        route: AppRoutes.headshot,
      ),
      subtitle: 'Professional AI headshots',
      iconBg: const Color(0xFF002E2E),
      category: 'image',
    ),
    // _ToolEntry(
    //   tool: AiTool(
    //     id: 'sticker',
    //     label: 'Sticker AI',
    //     imagePath: AppDirectories.iconSticker,
    //     route: AppRoutes.sticker,
    //   ),
    //   subtitle: 'Create custom AI stickers',
    //   iconBg: const Color(0xFF2A2A2A),
    //   category: 'image',
    // ),
    _ToolEntry(
      tool: AiTool(
        id: 'collage',
        label: 'Pic Collage',
        imagePath: AppDirectories.iconPicCollage,
        route: AppRoutes.collage,
      ),
      subtitle: 'Create beautiful collages',
      iconBg: const Color(0xFF2A001A),
      category: 'image',
    ),
    _ToolEntry(
      tool: AiTool(
        id: 'logo',
        label: 'Logo AI',
        imagePath: AppDirectories.iconLogo,
        route: AppRoutes.logo,
      ),
      subtitle: 'Design unique logos',
      iconBg: const Color(0xFF002A1A),
      category: 'image',
    ),
  ];

  return rawEntries
      .map((e) => e.copyWith(isPopular: popularIds.contains(e.tool.id)))
      .toList();
}

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
  /// Set to true when this page is pre-built inside MainNavigation's IndexedStack.
  /// When true, the intro scroll is only triggered by MainNavigation
  /// calling [AllAiToolsPageState.onTabActivated()] rather than from initState.
  final bool isEmbeddedAsTab;

  const AllAiToolsPage({super.key, this.isEmbeddedAsTab = false});

  @override
  State<AllAiToolsPage> createState() => AllAiToolsPageState();
}

// Public so MainNavigation can hold a GlobalKey<AllAiToolsPageState>.
class AllAiToolsPageState extends State<AllAiToolsPage> {
  final CreditService _creditService = CreditService();
  final ScrollController _popularScrollController = ScrollController();
  List<_ToolEntry> _registry = [];
  Map<String, String> _badges = {};
  bool _didAutoScroll = false;

  String _selectedCategory = 'all';

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

    // For direct pushes (not pre-built as tab), trigger scroll immediately.
    // For tab mode, MainNavigation calls onTabActivated().
    if (!widget.isEmbeddedAsTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_didAutoScroll) _doScroll();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_registry.isEmpty) {
      _registry = _buildRegistry(context);
    }
  }

  /// Called by MainNavigation when the user switches to this tab.
  void onTabActivated() {
    if (!_didAutoScroll) _doScroll();
  }

  void _doScroll() {
    _didAutoScroll = true;
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted && _popularScrollController.hasClients) {
        final sw = MediaQuery.of(context).size.width;
        _popularScrollController.animateTo(
          sw * 0.38,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _popularScrollController.dispose();
    super.dispose();
  }

  // ─── Computed Lists ───────────────────────────────────────────────────────

  List<_ToolEntry> get _popularTools =>
      _registry.where((e) => e.isPopular).toList();

  List<_ToolEntry> get _filteredTools {
    return _registry.where((e) {
      // Tab filter: 'all' tab shows everything;
      // 'video'/'image' tabs show tools with that category OR 'all' category
      return _selectedCategory == 'all' ||
          e.category == _selectedCategory ||
          e.category == 'all';
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
          builder: (_) => GenerationPage(
            showCategoryToggle: false,
            initialCategory: tool.initialCategory ?? 'image',
          ),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: sh * 0.025),
                  _buildPopularSection(isDark, sw, sh),
                  SizedBox(height: sh * 0.025),
                  _buildCategoryTabs(isDark, sw, sh),
                  SizedBox(height: sh * 0.018),
                  Expanded(child: _buildToolsList(isDark, sw, sh)),
                ],
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
          // Pro pill on the right — opens paywall for non-subscribers.
          ProPill(w: sw, h: sh, isDark: isDark),
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
            controller: _popularScrollController,
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

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: sw * 0.04,
        right: sw * 0.04,
        bottom: sh * 0.15,
      ),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
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
      },
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
