import 'package:flutter/material.dart';

/// The app's three brand colours, defined ONCE.
///
/// Until now each screen pasted its own copy - about 140 of them across 55
/// files, each with its own private name - so there was no single place to say
/// what the app's green IS, and nothing a colour theme could change. Every
/// definition now points here. The values are exactly the ones they replaced,
/// so nothing looks different.
///
/// These are the Pasture theme's colours (the default). Screens read the
/// chosen theme through `context.colors`; only what must stay Pasture in
/// every theme reads these directly (receipts and PDFs, the loading screen,
/// docs/design/themes.md section 8).
class AppPalette {
  AppPalette._();

  /// Deep teal green - the main colour (the "Kilimanjaro Green" theme).
  static const Color primary = Color(0xFF2F5D62);

  /// Warm amber - highlights and call-to-action accents.
  static const Color accent = Color(0xFFFFB200);

  /// Off-white - the page background.
  static const Color background = Color(0xFFFDFDF9);
}

/// A colour theme the person can choose in UI Settings
/// (docs/design/themes.md, RUNBOOK2 D10).
///
/// A theme is only its three base colours. Every brand-linked role (the
/// sidebar hover, the login teal, the quick-action tints...) is derived from
/// them in `AppColors.fromTheme`, so adding a theme is one entry in [all]
/// plus its label in `colorThemeLabel`. [name] is the English, technical
/// name; what is shown comes from the ARB through `colorThemeLabel`.
class AppColorTheme {
  final String id;
  final String name;
  final Color primary;
  final Color accent;
  final Color background;

  const AppColorTheme({
    required this.id,
    required this.name,
    required this.primary,
    required this.accent,
    required this.background,
  });

  /// Today's look, exactly (the old "Kilimanjaro Green").
  static const AppColorTheme pasture = AppColorTheme(
    id: 'pasture',
    name: 'Pasture',
    primary: AppPalette.primary,
    accent: AppPalette.accent,
    background: AppPalette.background,
  );

  static const AppColorTheme clinic = AppColorTheme(
    id: 'clinic',
    name: 'Clinic',
    primary: Color(0xFF0F4C81),
    accent: Color(0xFF5BC0EB),
    background: Color(0xFFF6F9FC),
  );

  static const AppColorTheme harvest = AppColorTheme(
    id: 'harvest',
    name: 'Harvest',
    primary: Color(0xFF4A3426),
    accent: Color(0xFFE3A72F),
    background: Color(0xFFFBF7F0),
  );

  static const AppColorTheme ledger = AppColorTheme(
    id: 'ledger',
    name: 'Ledger',
    primary: Color(0xFF1E293B),
    accent: Color(0xFF8B9CFF),
    background: Color(0xFFF8FAFC),
  );

  static const List<AppColorTheme> all = [pasture, clinic, harvest, ledger];

  static const String defaultId = 'pasture';

  /// Ids saved by older builds -> the theme they now mean. Only
  /// `kilimanjaro` was ever selectable (so ever saved); `serengeti` and
  /// `victoria` never were, and fall back like any unknown id.
  static const Map<String, String> legacyIds = {'kilimanjaro': 'pasture'};

  /// True when [id] is an old id that [byId] maps to a current theme.
  static bool isLegacyId(String? id) => legacyIds.containsKey(id);

  /// The theme with this id - or Pasture if it's one we don't know (an old
  /// or hand-edited saved value must never leave the app without a theme).
  static AppColorTheme byId(String? id) {
    final current = legacyIds[id] ?? id;
    for (final t in all) {
      if (t.id == current) return t;
    }
    return pasture;
  }
}
