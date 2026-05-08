import 'dart:io';
import 'package:flutter/material.dart';
import 'package:trail_ai_app/Widgets/main_navigation.dart';
import 'package:trail_ai_app/pages/login.dart';
import 'package:trail_ai_app/pages/signup_page.dart';
import 'package:trail_ai_app/pages/selection.dart';
import 'package:trail_ai_app/pages/paywall_page.dart';
import 'package:trail_ai_app/pages/trending_see_all_page.dart';
import 'package:trail_ai_app/pages/all_ai_tools_page.dart';
import 'package:trail_ai_app/pages/outfit_change_page.dart';
import 'package:trail_ai_app/pages/upscale_page.dart';
import 'package:trail_ai_app/pages/language_settings_page.dart';
import 'package:trail_ai_app/pages/ai_restore_page.dart';
import 'package:trail_ai_app/pages/ai_headshot_page.dart';
import 'package:trail_ai_app/pages/ai_sticker_page.dart';
import 'package:trail_ai_app/pages/ai_background_page.dart';
import 'package:trail_ai_app/pages/collage_page.dart';
import 'package:trail_ai_app/pages/ai_logo_page.dart';
import 'package:trail_ai_app/pages/ai_filter_page.dart';
import 'package:trail_ai_app/pages/image_editor_page.dart';
import 'package:trail_ai_app/pages/effect_editor_page.dart';

class AppRoutes {
  static const String home = '/home';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String imageGen = '/imageGen';
  static const String seeAll = '/seeAll';
  static const String paywall = '/paywall';
  static const String allTools = '/allTools';
  static const String outfitChange = '/outfitChange';
  static const String upscale = '/upscale';
  static const String language = '/language';
  static const String restore = '/restore';
  static const String headshot = '/headshot';
  static const String sticker = '/sticker';
  static const String background = '/background';
  static const String collage = '/collage';
  static const String logo = '/logo';
  static const String filter = '/filter';
  static const String imageEditor = '/imageEditor';
  static const String effectOverlay = '/effectOverlay';
}

Map<String, WidgetBuilder> getAppRoutes() {
  return {
    AppRoutes.login: (context) => const LoginPage(),
    AppRoutes.signup: (context) => const SignupPage(),
    AppRoutes.home: (context) => const MainNavigation(),
    AppRoutes.imageGen: (context) => const Selection(),
    AppRoutes.seeAll: (context) => const TrendingSeeAllPage(),
    AppRoutes.paywall: (context) => const PaywallPage(),
    AppRoutes.allTools: (context) => const AllAiToolsPage(),
    AppRoutes.outfitChange: (context) => const OutfitChangePage(),
    AppRoutes.upscale: (context) => const UpscalePage(),
    AppRoutes.language: (context) => const LanguageSettingsPage(),
    AppRoutes.restore: (context) => const AiRestorePage(),
    AppRoutes.headshot: (context) => const AiHeadshotPage(),
    AppRoutes.sticker: (context) => const AiStickerPage(),
    AppRoutes.background: (context) => const AiBackgroundPage(),
    AppRoutes.collage: (context) => const AiCollagePage(),
    AppRoutes.logo: (context) => const AiLogoPage(),
    AppRoutes.filter: (context) => const AiFilterPage(),
    AppRoutes.imageEditor: (context) => ImageEditorPage(imageFile: File('')),
    AppRoutes.effectOverlay: (context) => EffectEditorPage(imageFile: ModalRoute.of(context)!.settings.arguments as File),
  };
}
