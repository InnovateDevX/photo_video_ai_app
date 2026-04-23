import 'package:localization/localization.dart';

/// Configures the [LocalJsonLocalization] delegate with the asset directory
/// containing the translated JSON files (assets/i18n/).
///
/// Call [LocalizationService.init] once at app startup, before [runApp].
/// Then add [LocalJsonLocalization.delegate] to [MaterialApp.localizationsDelegates]
/// and list your supported locales in [MaterialApp.supportedLocales].
///
/// Example in MaterialApp:
/// ```dart
/// localizationsDelegates: [
///   GlobalMaterialLocalizations.delegate,
///   GlobalWidgetsLocalizations.delegate,
///   GlobalCupertinoLocalizations.delegate,
///   LocalJsonLocalization.delegate,
/// ],
/// supportedLocales: const [
///   Locale('en'), Locale('es'), Locale('fr'), Locale('hi'), Locale('ne'),
///   Locale('zh'), Locale('de'), Locale('id'), Locale('pt'), Locale('tr'),
/// ],
/// ```
class LocalizationService {
  LocalizationService._();

  static void init() {
    // Point the delegate to the directory that holds the JSON translation files.
    // File naming convention: <languageCode>.json  (e.g. en.json, es.json, …)
    LocalJsonLocalization.delegate.directories = ['assets/i18n'];
  }
}
