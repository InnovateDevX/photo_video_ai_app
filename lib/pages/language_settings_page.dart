import 'package:flutter/material.dart';
import 'package:trail_ai_app/Core/colors.dart';
import 'package:trail_ai_app/Core/locale_notifier.dart';
import 'package:localization/localization.dart';

class LanguageSettingsPage extends StatefulWidget {
  const LanguageSettingsPage({super.key});

  @override
  State<LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  /// Each entry maps a display name to its locale code.
  final List<Map<String, String>> _languages = [
    {'name': 'Nepal', 'flag': '🇳🇵', 'code': '(नेपाली)', 'locale': 'ne'},
    {'name': 'Français', 'flag': '🇫🇷', 'code': '(Salut)', 'locale': 'fr'},
    {'name': 'Espanola', 'flag': '🇪🇸', 'code': '(Hola)', 'locale': 'es'},
    {'name': 'English', 'flag': '🇬🇧', 'code': '(Hi)', 'locale': 'en'},
    {'name': 'Hindi', 'flag': '🇮🇳', 'code': '(नमस्ते)', 'locale': 'hi'},
    {'name': 'Indonesian', 'flag': '🇮🇩', 'code': '(Halo)', 'locale': 'id'},
    {'name': 'Turkish', 'flag': '🇹🇷', 'code': '(Merhaba)', 'locale': 'tr'},
    {'name': 'Chinese', 'flag': '🇨🇳', 'code': '(你好)', 'locale': 'zh'},
    {'name': 'Portuguese', 'flag': '🇧🇷', 'code': '(Olá)', 'locale': 'pt'},
    {'name': 'Deutsch', 'flag': '🇩🇪', 'code': '(Hallo)', 'locale': 'de'},
  ];

  String _selectedLanguage = 'English';

  @override
  void initState() {
    super.initState();
    // Reflect the currently active locale on page open.
    final currentCode = localeNotifier.value.languageCode;
    final match = _languages.firstWhere(
      (l) => l['locale'] == currentCode,
      orElse: () => _languages.firstWhere((l) => l['locale'] == 'en'),
    );
    _selectedLanguage = match['name']!;
  }

  void _onLanguageTap(Map<String, String> lang) {
    setState(() => _selectedLanguage = lang['name']!);
    localeNotifier.setLocale(Locale(lang['locale']!));
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    final bool darkTheme = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor(darkTheme),
      body: SafeArea(
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
                      onTap: () => Navigator.pop(context),
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
                  Expanded(
                    child: Center(
                      child: ValueListenableBuilder<Locale>(
                        valueListenable: localeNotifier,
                        builder: (context, locale, _) => Text(
                          'choose_language'.i18n(),
                          style: TextStyle(
                            fontSize: w * 0.05,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textColor(darkTheme),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: w * 0.11), // To balance the back button
                ],
              ),
            ),

            SizedBox(height: h * 0.02),

            // Language List
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: w * 0.05),
                itemCount: _languages.length,
                itemBuilder: (context, index) {
                  final lang = _languages[index];
                  final isSelected = _selectedLanguage == lang['name'];
                  return GestureDetector(
                    onTap: () => _onLanguageTap(lang),
                    child: Container(
                      margin: EdgeInsets.only(bottom: h * 0.015),
                      padding: EdgeInsets.symmetric(
                        horizontal: w * 0.04,
                        vertical: h * 0.017,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tileBackgroundColor(darkTheme),
                        borderRadius: BorderRadius.circular(w * 0.08),
                        border: isSelected
                            ? Border.all(color: Colors.green, width: 1.5)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Text(
                            lang['flag']!,
                            style: TextStyle(fontSize: w * 0.06),
                          ),
                          SizedBox(width: w * 0.04),
                          Expanded(
                            child: Text(
                              lang['name']!,
                              style: TextStyle(
                                fontSize: w * 0.038,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textColor(darkTheme),
                              ),
                            ),
                          ),
                          if (lang['code']!.isNotEmpty) ...[
                            Text(
                              lang['code']!,
                              style: TextStyle(
                                fontSize: w * 0.035,
                                color: AppColors.secondaryTextColor(darkTheme),
                              ),
                            ),
                            SizedBox(width: w * 0.02),
                          ],
                          if (isSelected) ...[
                            Icon(
                              Icons.check_circle,
                              color: Colors.green,
                              size: w * 0.055,
                            ),
                          ] else
                            Icon(
                              Icons.chevron_right,
                              color: AppColors.chevronColor(darkTheme),
                              size: w * 0.055,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
