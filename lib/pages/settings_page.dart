import 'package:flutter/material.dart';
import 'package:vidzeon/Core/theme_notifier.dart';
import 'package:vidzeon/Core/colors.dart';
import 'package:vidzeon/Core/gradient.dart';
// AppStrings.appVersion

import 'package:vidzeon/Core/routes.dart';
import 'package:vidzeon/Services/review_service.dart';
import 'package:vidzeon/Services/credit_service.dart';
import 'package:vidzeon/Services/auth_service.dart';
import 'package:vidzeon/Services/remote_config_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vidzeon/Widgets/main_navigation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vidzeon/Services/subscription_service.dart';
import 'package:vidzeon/Helpers/error_dialog_helper.dart';
import 'package:vidzeon/Widgets/themed_dialog.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = '${info.appName} v${info.version}(${info.buildNumber})';
      });
    }
  }

  Future<void> _launchUrl(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          showThemedDialog(
            context,
            title: 'Error',
            message: 'Could not launch URL',
            icon: Icons.error_outline,
            iconColor: Colors.red,
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
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
                    'Settings',
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
                    _sectionHeader('General', darkTheme),
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
                              padding: EdgeInsets.all(
                                MediaQuery.of(context).size.width * 0.005,
                              ),
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

                    // Subscription section
                    _sectionHeader('Subscription', darkTheme),
                    _settingsTile(
                      isDark: darkTheme,
                      icon: Icon(
                        Icons.restore,
                        size: w * 0.055,
                        color: AppColors.iconColor(darkTheme),
                      ),
                      label: 'Restore Purchases',
                      onTap: () async {
                        try {
                          ErrorDialogHelper.showLoadingDialog(
                            context,
                            message: 'Restoring purchases...',
                          );
                          final result = await SubscriptionService()
                              .restorePurchases();
                          if (context.mounted) {
                            ErrorDialogHelper.hideLoadingDialog(context);
                            if (result.success) {
                              ErrorDialogHelper.showSuccessDialog(
                                context,
                                title: 'Success',
                                message: result.message,
                              );
                            } else {
                              ErrorDialogHelper.showErrorDialog(
                                context,
                                title: 'Restore Failed',
                                message: result.message,
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ErrorDialogHelper.hideLoadingDialog(context);
                            ErrorDialogHelper.showErrorDialog(
                              context,
                              title: 'Error',
                              message: 'Failed to restore: $e',
                            );
                          }
                        }
                      },
                    ),
                    _settingsTile(
                      isDark: darkTheme,
                      icon: Icon(
                        Icons.cancel_presentation_outlined,
                        size: w * 0.055,
                        color: AppColors.iconColor(darkTheme),
                      ),
                      label: 'Cancel Subscription',
                      onTap: () {
                        ErrorDialogHelper.showConfirmationDialog(
                          context,
                          title: 'Cancel Subscription',
                          message:
                              'You will be redirected to the Google Play Store to manage or cancel your active subscriptions. Do you want to proceed?',
                          confirmText: 'Proceed',
                          onConfirm: () async {
                            const url =
                                'https://play.google.com/store/account/subscriptions';
                            if (await canLaunchUrl(Uri.parse(url))) {
                              await launchUrl(
                                Uri.parse(url),
                                mode: LaunchMode.externalApplication,
                              );
                            }
                          },
                        );
                      },
                    ),

                    SizedBox(height: h * 0.02),

                    // Help Center section
                    _sectionHeader('Help Center', darkTheme),
                    _settingsTile(
                      isDark: darkTheme,
                      icon: Icon(
                        Icons.share_outlined,
                        size: w * 0.055,
                        color: AppColors.iconColor(darkTheme),
                      ),
                      label: 'Share App',
                      onTap: () async {
                        try {
                          String url = "";
                          if (url.isEmpty) {
                            PackageInfo packageInfo =
                                await PackageInfo.fromPlatform();
                            print(packageInfo.packageName);
                            String packageName = packageInfo.packageName;
                            url =
                                "https://play.google.com/store/apps/details?id=$packageName";
                            print(url);
                          }

                          String subject = "Check out this Amazing App!";
                          String message = "Download this awesome app: $url";

                          await Share.share(message, subject: subject);
                        } catch (e) {
                          if (context.mounted) {
                            showThemedDialog(
                              context,
                              title: 'Error',
                              message: "Error sharing app: $e",
                              icon: Icons.error_outline,
                              iconColor: Colors.red,
                            );
                          }
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
                      label: 'Privacy Policy',
                      onTap: () =>
                          _launchUrl(RemoteConfigService().privacyPolicyUrl),
                    ),

                    _settingsTile(
                      isDark: darkTheme,
                      icon: Icon(
                        Icons.description_outlined,
                        size: w * 0.055,
                        color: AppColors.iconColor(darkTheme),
                      ),
                      label: 'Terms of Use',
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
                      label: 'Rate us',
                      onTap: () => ReviewService().openStoreListing(),
                    ),

                    SizedBox(height: h * 0.02),

                    // Account section (Replaced standalone Delete Button)
                    _sectionHeader('Account', darkTheme),
                    _settingsTile(
                      isDark: darkTheme,
                      icon: Icon(
                        Icons.delete_outline,
                        size: w * 0.055,
                        color: AppColors.iconColor(darkTheme),
                      ),
                      label: 'Delete Data',
                      onTap: () {
                        ErrorDialogHelper.showConfirmationDialog(
                          context,
                          title: 'Delete Data',
                          message:
                              'Are you sure you want to delete your Data? This action cannot be undone.',
                          confirmText: 'Delete',
                          onConfirm: () async {
                            ErrorDialogHelper.showLoadingDialog(
                              context,
                              message: 'Deleting Data...',
                            );
                            await AuthService().deleteAccount();
                            if (context.mounted) {
                              ErrorDialogHelper.hideLoadingDialog(context);
                              // Generate a new session by navigating home
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                AppRoutes.home,
                                (route) => false,
                              );
                            }
                          },
                        );
                      },
                    ),

                    SizedBox(height: h * 0.02),

                    // Version
                    if (_version.isNotEmpty)
                      Center(
                        child: Text(
                          _version,
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
        padding: EdgeInsets.symmetric(horizontal: sw * 0.04),
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
    return ValueListenableBuilder<bool>(
      valueListenable: SubscriptionService().isSubscribedNotifier,
      builder: (context, isSubscribed, _) {
        return StreamBuilder<int>(
          stream: CreditService().creditStream,
          initialData: CreditService().credits,
          builder: (context, snapshot) {
            final credits = snapshot.data ?? 0;
            return GestureDetector(
              onTap: isSubscribed
                  ? null
                  : () => Navigator.pushNamed(context, AppRoutes.paywall),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: w * 0.04,
                  vertical: h * 0.015,
                ),
                decoration: BoxDecoration(
                  color: AppColors.creditsCardBackground(isDark),
                  borderRadius: BorderRadius.circular(w * 0.04),
                  border: Border.all(
                    color: AppColors.creditsCardBorder(isDark),
                  ),
                ),
                child: Row(
                  children: [
                    // Gradient dot
                    Container(
                      width: w * 0.08,
                      height: w * 0.08,
                      decoration: const ProGradientDecoration(
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: w * 0.03),
                    Expanded(
                      child: Text(
                        'My Credits',
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
                              right: isSubscribed ? w * 0.03 : w * 0.02,
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
                                SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.01,
                                ),
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
                          if (!isSubscribed)
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
                                'Pro',
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
              ),
            );
          },
        );
      },
    );
  }
}
