import 'package:flutter/widgets.dart';

import '../config/app_defaults.dart';
import 'app_localizations.dart';

export 'app_localizations.dart';
export 'stored_labels.dart';

/// `context.l10n.someKey` in widgets.
extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

/// The texts for the current language, for code with no BuildContext
/// (FriendlyError, and AppFeedback calls made after an await).
///
/// UiSettingsProvider keeps it in step with the language chosen in
/// Settings, and moves it BEFORE notifying listeners, so anything that
/// rebuilds on that change already reads the new language.
class L10n {
  L10n._();

  static Locale _locale = const Locale(AppDefaults.defaultLanguage);

  static Locale get locale => _locale;

  static AppLocalizations get current => lookupAppLocalizations(_locale);

  static void setLocale(Locale locale) => _locale = locale;
}
