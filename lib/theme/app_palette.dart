import 'package:flutter/material.dart';

/// The app's three brand colours, defined ONCE.
///
/// Until now each screen pasted its own copy - about 140 of them across 55
/// files, each with its own private name - so there was no single place to say
/// what the app's green IS, and nothing a colour theme could change. Every
/// definition now points here. The values are exactly the ones they replaced,
/// so nothing looks different.
///
/// Still `const` on purpose: today's colours are fixed. When the other colour
/// themes arrive (UI Settings, phase 2) these become values read at run time -
/// that is the step that needs `const` taken off the widgets using them.
class AppPalette {
  AppPalette._();

  /// Deep teal green - the main colour (the "Kilimanjaro Green" theme).
  static const Color primary = Color(0xFF2F5D62);

  /// Warm amber - highlights and call-to-action accents.
  static const Color accent = Color(0xFFFFB200);

  /// Off-white - the page background.
  static const Color background = Color(0xFFFDFDF9);
}

/// A colour theme the person can choose in UI Settings.
///
/// Only Kilimanjaro Green (today's look) is selectable so far. The others are
/// listed so the dialog shows what is coming; their swatches are previews, and
/// the full palettes are settled when they are built (phase 2).
class AppColorTheme {
  final String id;
  final String name;
  final Color primary;
  final Color accent;
  final bool available;

  const AppColorTheme({
    required this.id,
    required this.name,
    required this.primary,
    required this.accent,
    required this.available,
  });

  static const AppColorTheme kilimanjaro = AppColorTheme(
    id: 'kilimanjaro',
    name: 'Kilimanjaro Green',
    primary: AppPalette.primary,
    accent: AppPalette.accent,
    available: true,
  );

  static const AppColorTheme serengeti = AppColorTheme(
    id: 'serengeti',
    name: 'Serengeti Yellow',
    primary: Color(0xFFD9A406),
    accent: Color(0xFF6B4F1D),
    available: false,
  );

  static const AppColorTheme victoria = AppColorTheme(
    id: 'victoria',
    name: 'Victoria Blue',
    primary: Color(0xFF1E6FA8),
    accent: Color(0xFF4FB3D9),
    available: false,
  );

  static const List<AppColorTheme> all = [kilimanjaro, serengeti, victoria];

  static const String defaultId = 'kilimanjaro';

  /// The theme with this id - or today's look if it's one we don't know (an old
  /// or hand-edited saved value must never leave the app without a theme).
  static AppColorTheme byId(String? id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return kilimanjaro;
  }
}
