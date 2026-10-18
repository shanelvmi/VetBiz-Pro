import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';

/// T1 (docs/design/themes.md sections 2, 9 and 10.5): the four themes, the
/// ids saved by older builds, and the choice surviving a restart.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// A provider that has finished reading its saved settings.
  Future<UiSettingsProvider> loaded() async {
    final p = UiSettingsProvider();
    while (!p.loaded) {
      await Future<void>.delayed(Duration.zero);
    }
    return p;
  }

  group('the four themes (D10, exact)', () {
    test('ids and order are pinned', () {
      expect(AppColorTheme.all.map((t) => t.id), ['pasture', 'clinic', 'harvest', 'ledger']);
      expect(AppColorTheme.defaultId, 'pasture');
    });

    test('base colours', () {
      final want = {
        'pasture': (0xFF2F5D62, 0xFFFFB200, 0xFFFDFDF9),
        'clinic': (0xFF0F4C81, 0xFF5BC0EB, 0xFFF6F9FC),
        'harvest': (0xFF4A3426, 0xFFE3A72F, 0xFFFBF7F0),
        'ledger': (0xFF1E293B, 0xFF8B9CFF, 0xFFF8FAFC),
      };
      for (final t in AppColorTheme.all) {
        final w = want[t.id]!;
        expect((t.primary.toARGB32(), t.accent.toARGB32(), t.background.toARGB32()), w, reason: t.id);
      }
    });

    test('Pasture is today\'s AppPalette', () {
      const p = AppColorTheme.pasture;
      expect(p.primary, AppPalette.primary);
      expect(p.accent, AppPalette.accent);
      expect(p.background, AppPalette.background);
    });
  });

  group('byId and legacy ids', () {
    test('every current id finds its own theme', () {
      for (final t in AppColorTheme.all) {
        expect(AppColorTheme.byId(t.id), same(t));
      }
    });

    test('kilimanjaro, serengeti, victoria, null and unknown ids give Pasture', () {
      for (final id in ['kilimanjaro', 'serengeti', 'victoria', null, 'x', '']) {
        expect(AppColorTheme.byId(id), same(AppColorTheme.pasture), reason: '$id');
      }
      expect(AppColorTheme.isLegacyId('kilimanjaro'), isTrue);
      expect(AppColorTheme.isLegacyId('serengeti'), isFalse);
      expect(AppColorTheme.isLegacyId(null), isFalse);
    });
  });

  group('the saved choice (SharedPreferences ui_color_theme)', () {
    test('nothing saved: Pasture', () async {
      final ui = await loaded();
      expect(ui.colorTheme.id, 'pasture');
    });

    test('a chosen theme is saved and restored after a restart', () async {
      final before = await loaded();
      await before.setColorTheme('clinic');
      expect(before.colorTheme.id, 'clinic');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ui_color_theme'), 'clinic');
      final after = await loaded();
      expect(after.colorTheme.id, 'clinic');
    });

    test('every theme survives a restart', () async {
      for (final t in AppColorTheme.all.reversed) {
        await (await loaded()).setColorTheme(t.id);
        expect((await loaded()).colorTheme.id, t.id);
      }
    });

    test('a saved kilimanjaro loads as Pasture and is rewritten once', () async {
      SharedPreferences.setMockInitialValues({'ui_color_theme': 'kilimanjaro'});
      final ui = await loaded();
      expect(ui.colorTheme.id, 'pasture');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ui_color_theme'), 'pasture');
    });

    test('a saved unknown id loads as Pasture and is left as it was', () async {
      SharedPreferences.setMockInitialValues({'ui_color_theme': 'victoria'});
      final ui = await loaded();
      expect(ui.colorTheme.id, 'pasture');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ui_color_theme'), 'victoria');
    });
  });
}
