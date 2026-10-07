/// Country and money defaults. The app serves Tanzania today; a per-facility
/// currency needs a data-model change (Phase 2 step 2H), so these are fixed.
class AppDefaults {
  AppDefaults._();

  static const String currencyCode = 'TZS';

  /// As shown on screen, before an amount: "Tsh 12,500".
  static const String currencySymbol = 'Tsh';

  /// Tanzania, without the '+' (client_duplicate_matcher.dart, register_screen.dart).
  static const String countryCallingCode = '255';

  static const String timezone = 'Africa/Dar_es_Salaam';

  /// Number formatting locale. Pinned, so amounts don't change shape when
  /// the app's language changes.
  static const String numberLocale = 'en_US';

  static const String defaultLanguage = 'en';
  static const List<String> supportedLanguages = ['en', 'sw'];
}
