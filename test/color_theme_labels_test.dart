import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/color_theme_labels.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';

import 'stored_labels_check.dart';

/// The colour theme names (docs/design/themes.md section 9): one label per
/// theme in AppColorTheme.all, in its order; English is the theme's name.
void main() {
  test('colour themes', () {
    checkStoredList(
      ColorThemeLabels.colorTheme,
      [for (final t in AppColorTheme.all) t.id],
      (l, v) => l.colorThemeLabel(v),
      english: {for (final t in AppColorTheme.all) t.id: t.name},
    );
  });
}
