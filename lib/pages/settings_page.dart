import 'package:flutter/material.dart';
import 'package:trail_ai_app/Core/theme_notifier.dart';
import 'package:trail_ai_app/Core/colors.dart';
import 'package:trail_ai_app/Core/gradient.dart';
import 'package:trail_ai_app/Core/strings.dart'; // AppStrings.appVersion
import 'package:localization/localization.dart';
import 'package:trail_ai_app/Core/routes.dart';
import 'package:trail_ai_app/Services/credit_service.dart';
import 'package:trail_ai_app/Services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:trail_ai_app/Services/remote_config_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:trail_ai_app/Widgets/main_navigation.dart';
import 'package:share_plus/share_plus.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Could not launch URL')));
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: \$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final bool darkTheme = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(darkTheme),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            SizedBox(height: h * 0.02),

            // App Bar (Back Button + Title)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: w * 0.05),
              child: Row(
                children: [
                  Material(
                    color: darkTheme ? Colors.grey[850] : Colors.grey[200],
                    shape: const CircleBorder(),
                    clipBehavior: Clip.hardEdge,
                    child: InkWell(
                      onTap: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          final navState = context
                              .findAncestorStateOfType<MainNavigationState>();
                          if (navState != null) {
                            navState.switchTab(0);
                          } else {
                            Navigator.pushReplacementNamed(
                              context,
                              AppRoutes.home,
                            );
                          }
                        }
                      },
                      child: Padding(
                        padding: EdgeInsets.all(w * 0.03),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          size: w * 0.05,
                          color: AppColors.textColor(darkTheme),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: w * 0.04), // Space between button and title
                  Text(
                    'settings_title'.i18n(),
                    style: TextStyle(
                      fontSize: w * 0.055,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textColor(darkTheme),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: h * 0.025),

            // Credits card
            Padding(
              padding: EdgeInsets.symmetric(horizontal: w * 0.05),
              child: _CreditsCard(w: w, h: h, isDark: darkTheme),
            ),

            SizedBox(height: h * 0.03),

            // Scrollable list
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: w * 0.05,
                  right: w * 0.05,
                  bottom: h * 0.15,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // General section
                    _sectionHeader('general'.i18n(), darkTheme),
                    _settingsTile(
                      isDark: darkTheme,
                      icon: Image.asset(
                        'assets/mdi_theme-light-dark.png',
                        width: w * 0.055,
                        height: w * 0.055,
                        color: AppColors.iconColor(darkTheme),
                      ),
                      label: 'Dark Theme',
                      trailing: GestureDetector(
                        onTap: () => themeNotifier.toggleTheme(!darkTheme),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: w * 0.13,
                          height: h * 0.04,
                          decoration: darkTheme
                              ? ProGradientDecoration(
                                  borderRadius: BorderRadius.circular(h * 0.02),
                                )
                              : BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(h * 0.04),
                                ),
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            alignment: darkTheme
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.all(MediaQuery.of(context).size.width * 0.005),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: h * 0.02),

                    // Help Center section
                    _sectionHeader('help_center'.i18n(), darkTheme),
                    _settingsTile(
                      isDark: darkTheme,
                      icon: Icon(
                        Icons.share_outlined,
                        size: w * 0.055,
                        color: AppColors.iconColor(darkTheme),
                      ),
                      label: 'share_app'.i18n(),
                      onTap: () {
                        final url = RemoteConfigService().shareAppUrl;
                        if (url.isNotEmpty) {
                          Share.share(url);
                        } else {
                          debugPrint(
                            'Share App URL is not configured in Remote Config.',
                          );
                        }
                      },
                    ),
                    _settingsTile(
                      isDark: darkTheme,
                      icon: Icon(
                        Icons.shield_outlined,
                        size: w * 0.055,
                        color: AppColors.iconColor(darkTheme),
                      ),
                      label: 'privacy_policy'.i18n(),
                      onTap: () =>
                          _launchUrl(RemoteConfigService().privacyPolicyUrl),
                    ),
                    _settingsTile(
                      isDark: darkTheme,
                      icon: Icon(
                        Icons.person_outline,
                        size: w * 0.055,
                        color: AppColors.iconColor(darkTheme),
                      ),
                      label: 'customer_support'.i18n(),
                      onTap: () =>
                          _launchUrl(RemoteConfigService().customerSupportUrl),
                    ),
                    _settingsTile(
                      isDark: darkTheme,
                      icon: Icon(
                        Icons.language_outlined,
                        size: w * 0.055,
                        color: AppColors.iconColor(darkTheme),
                      ),
                      label: 'language'.i18n(),
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.language),
                    ),
                    _settingsTile(
                      isDark: darkTheme,
                      icon: Icon(
                        Icons.help_outline,
                        size: w * 0.055,
                        color: AppColors.iconColor(darkTheme),
                      ),
                      label: 'faq'.i18n(),
                      onTap: () => _launchUrl(RemoteConfigService().faqUrl),
                    ),
                    _settingsTile(
                      isDark: darkTheme,
                      icon: Icon(
                        Icons.description_outlined,
                        size: w * 0.055,
                        color: AppColors.iconColor(darkTheme),
                      ),
                      label: 'terms_of_use'.i18n(),
                      onTap: () =>
                          _launchUrl(RemoteConfigService().termsOfUseUrl),
                    ),
                    _settingsTile(
                      isDark: darkTheme,
                      icon: Icon(
                        Icons.star_outline,
                        size: w * 0.055,
                        color: AppColors.iconColor(darkTheme),
                      ),
                      label: 'rate_us'.i18n(),
                      onTap: () => debugPrint('Rate Us tapped'),
                    ),

                    SizedBox(height: h * 0.03),

                    // Login button
                    _LoginButton(w: w, h: h),

                    SizedBox(height: h * 0.02),

                    // Version
                    Center(
                      child: Text(
                        AppStrings.appVersion,
                        style: TextStyle(
                          color: AppColors.secondaryTextColor(darkTheme),
                          fontSize: w * 0.03,
                        ),
                      ),
                    ),

                    SizedBox(height: h * 0.02),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: MediaQuery.of(context).size.width * 0.038,
          fontWeight: FontWeight.w600,
          color: AppColors.textColor(isDark),
        ),
      ),
    );
  }

  Widget _settingsTile({
    required Widget icon,
    required String label,
    required bool isDark,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: sh * 0.075,
        margin: EdgeInsets.only(bottom: sh * 0.015),
        padding: EdgeInsets.symmetric(
          horizontal: sw * 0.04,
        ),
        decoration: BoxDecoration(
          color: AppColors.tileBackgroundColor(isDark),
          borderRadius: BorderRadius.circular(sw * 0.08),
        ),
        child: Row(
          children: [
            icon,
            SizedBox(width: sw * 0.04),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: sw * 0.038,
                  color: AppColors.textColor(isDark),
                ),
              ),
            ),
            trailing ??
                Icon(
                  Icons.chevron_right,
                  color: AppColors.chevronColor(isDark),
                  size: sw * 0.055,
                ),
          ],
        ),
      ),
    );
  }
}

class _CreditsCard extends StatelessWidget {
  const _CreditsCard({required this.w, required this.h, required this.isDark});
  final double w;
  final double h;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: CreditService().creditStream,
      initialData: CreditService().credits,
      builder: (context, snapshot) {
        final credits = snapshot.data ?? 0;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: w * 0.04,
            vertical: h * 0.015,
          ),
          decoration: BoxDecoration(
            color: AppColors.creditsCardBackground(isDark),
            borderRadius: BorderRadius.circular(w * 0.04),
            border: Border.all(color: AppColors.creditsCardBorder(isDark)),
          ),
          child: Row(
            children: [
              // Gradient dot
              Container(
                width: w * 0.08,
                height: w * 0.08,
                decoration: const ProGradientDecoration(shape: BoxShape.circle),
              ),
              SizedBox(width: w * 0.03),
              Expanded(
                child: Text(
                  'my_credits'.i18n(),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: w * 0.04,
                    color: AppColors.textColor(isDark),
                  ),
                ),
              ),
              // Combined Credits + Pro Pill
              Container(
                decoration: BoxDecoration(
                  color: AppColors.creditsPillBackground(isDark),
                  borderRadius: BorderRadius.circular(w * 0.08),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Credits part
                    Padding(
                      padding: EdgeInsets.only(
                        left: w * 0.03,
                        right: w * 0.02,
                        top: h * 0.005,
                        bottom: h * 0.005,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.bolt,
                            color: AppColors.creditsPillText(isDark),
                            size: w * 0.045,
                          ),
                          SizedBox(width: MediaQuery.of(context).size.width * 0.01),
                          Text(
                            '$credits',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: w * 0.035,
                              color: AppColors.creditsPillText(isDark),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Pro badge part
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: w * 0.04,
                        vertical: 6,
                      ),
                      decoration: ProGradientDecoration(
                        borderRadius: BorderRadius.all(
                          Radius.circular(w * 0.08),
                        ),
                      ),
                      child: Text(
                        'pro_label'.i18n(),
                        style: TextStyle(
                          color: Colors
                              .white, // Pro gradient text is fine as white
                          fontWeight: FontWeight.bold,
                          fontSize: w * 0.032,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------- Login Button ----------
class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.w, required this.h});
  final double w;
  final double h;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        final user = snapshot.data;
        final isGuest = user == null || user.isAnonymous;

        return GestureDetector(
          onTap: () async {
            if (isGuest) {
              Navigator.pushNamed(context, AppRoutes.login);
            } else {
              // Sign out and re-initialize to get a fresh anonymous session
              await AuthService().signOut();
              // To ensure the app resets gracefully to the home page:
              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil(AppRoutes.home, (route) => false);
              }
            }
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: h * 0.018),
            decoration: ProGradientDecoration(
              borderRadius: BorderRadius.all(Radius.circular(w * 0.08)),
              blurSigma: 15.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isGuest ? Icons.login : Icons.logout,
                  color: Colors.white,
                  size: w * 0.05,
                ),
                SizedBox(width: w * 0.02),
                Text(
                  isGuest ? 'login'.i18n() : 'Log Out',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: w * 0.04,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
