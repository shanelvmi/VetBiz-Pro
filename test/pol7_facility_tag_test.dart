// POL7: the facility type is a neutral hairline tag in secondary text for
// every type (it was green, blue or purple by type), every theme, Light
// and Dark; the words shown are unchanged.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/widgets/facility_type_tag.dart';

void main() {
  for (final theme in AppColorTheme.all) {
    for (final b in Brightness.values) {
      testWidgets('${theme.name} ${b.name}: one neutral look for every type', (tester) async {
        final c = AppColors.fromTheme(theme, brightness: b);
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.build(theme, b),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Column(children: [
              FacilityTypeTag(type: 'Agrovet'),
              FacilityTypeTag(type: 'Vet Clinic'),
              FacilityTypeTag(type: 'Other', typeDetail: 'Pet shop'),
            ]),
          ),
        ));
        for (final word in ['Agrovet', 'Vet Clinic', 'Pet shop']) {
          final text = tester.widget<Text>(find.textContaining(word));
          expect(text.style!.color, c.textSecondary, reason: word);
        }
        for (final box in tester.widgetList<Container>(find.descendant(of: find.byType(FacilityTypeTag), matching: find.byType(Container)))) {
          final d = box.decoration! as BoxDecoration;
          expect(d.color, isNull);
          expect((d.border! as Border).top.color, c.border);
        }
      });
    }
  }
}
