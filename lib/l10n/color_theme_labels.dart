import '../theme/app_palette.dart';
import 'app_localizations.dart';
import 'stored_labels.dart';

/// The colour themes' shown names, by theme id (docs/design/themes.md
/// section 9). The id is what is saved on the device and never changes;
/// AppColorTheme.name stays the English, technical name. An id with no
/// label (a theme added later) comes back as given, so the caller falls
/// back to the theme's own name.
class ColorThemeLabels {
  ColorThemeLabels._();

  static final colorTheme = StoredLabelTable({
    AppColorTheme.pasture.id: (l) => l.uiSettings_themePasture,
    AppColorTheme.clinic.id: (l) => l.uiSettings_themeClinic,
    AppColorTheme.harvest.id: (l) => l.uiSettings_themeHarvest,
    AppColorTheme.ledger.id: (l) => l.uiSettings_themeLedger,
  });
}

extension ColorThemeLabelsOf on AppLocalizations {
  String colorThemeLabel(String id) => ColorThemeLabels.colorTheme.labelOf(this, id);
}
