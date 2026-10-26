import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/facilities/facility_picker_screen.dart';
import 'package:vetbiz_pro/screens/facilities/select_facility_screen.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

// RW2b2: an Other facility's own words (typeDetail) and the Ambulatory
// services label where facilities are listed, and the one shared type field
// behind every place that offers a type. Skipped until it exists.
const _skip = true;

void main() {
  final en = lookupAppLocalizations(const Locale('en'));

  group('the facility picker and Select Facility show the words and the new label', () {
    final facilities = [
      {'facilityId': 'f1', 'facilityName': 'Mwanza Pets', 'facilityType': 'Other', 'facilityTypeDetail': 'Pet shop'},
      {'facilityId': 'f2', 'facilityName': 'Moshi Mobile', 'facilityType': 'Ambulatory Vet'},
      {'facilityId': 'f3', 'facilityName': 'Ukuli', 'facilityType': 'Other'},
    ];
    Widget app(Widget Function() screen, {Object? arguments}) => MaterialApp(
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => screen(), settings: RouteSettings(name: settings.name, arguments: arguments)),
    );

    testWidgets('the picker card', (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(() => FacilityPickerScreen(facilities: facilities, role: 'admin')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Pet shop'), findsOneWidget);
      expect(find.text('Ambulatory services'), findsOneWidget);
      expect(find.text('Ambulatory Vet'), findsNothing);
      // The bare Other (no words) still shows Other.
      expect(find.text(en.facilityType_other), findsOneWidget);
    }, skip: _skip);

    testWidgets('Select Facility', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(() => const SelectFacilityScreen(), arguments: {'facilities': facilities, 'role': 'admin'}));
      await tester.pumpAndSettle();
      expect(find.text('Pet shop'), findsOneWidget);
      expect(find.text('Ambulatory services'), findsOneWidget);
    }, skip: _skip);
  });

  test('every place that offers a facility type uses the one shared field', () {
    for (final path in ['lib/screens/register/owner_steps.dart', 'lib/screens/facilities/facility_screen.dart', 'lib/main.dart']) {
      final source = File(path).readAsStringSync();
      expect(source, contains('FacilityTypeField('), reason: path);
    }
    // Only the shared field and the picker's filter menu list the types.
    final listing = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      if (f.readAsStringSync().contains('kFacilityTypes.map(')) listing.add(f.path.replaceAll('\\', '/'));
    }
    listing.sort();
    expect(listing, ['lib/screens/facilities/facility_picker_screen.dart', 'lib/widgets/facility_type_field.dart']);
  }, skip: _skip);
}
