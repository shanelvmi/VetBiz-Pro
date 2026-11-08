// FX1: the facility picker (the screen a signed-in admin with several
// facilities sees; FIN1 removed Select Facility, which nothing routed to) fed web-shaped and odd data. Each case
// must show the cards (with safe text for what is usable) or the friendly
// empty or error state, and never throw. In a release build a throw is the
// grey box the owner saw on the phone.
//
// _failsToday names the cases that fail on today's code: they are skipped until
// the fix (empty it to see them fail).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/screens/facilities/facility_picker_screen.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';

const _failsToday = <String>{};

Map<dynamic, dynamic> _item(Object? id, Object? name, {Object? type = 'Agrovet', Object? typeDetail}) =>
    <dynamic, dynamic>{'facilityId': id, 'name': name, 'type': type, 'typeDetail': typeDetail};

Widget _app(Widget Function() screen, {Object? arguments}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      theme: AppTheme.build(AppColorTheme.pasture, Brightness.light),
      onGenerateRoute: (settings) =>
          MaterialPageRoute<void>(settings: RouteSettings(name: settings.name, arguments: arguments), builder: (_) => screen()),
    );

Future<Object?> _pump(WidgetTester tester, Widget app, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(app);
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return tester.takeException();
}

/// The facility picker, given [facilities] as its caller would.
void _picker(String name, List<Object?> facilities, Size size, {List<String> cards = const []}) {
  testWidgets('Facility picker at ${size.width.toInt()}: $name', (tester) async {
    // Passed as dynamic: today's picker takes List<Map<String, dynamic>>.
    final dynamic list = facilities;
    final error = await _pump(tester, _app(() => FacilityPickerScreen(facilities: list, role: 'admin')), size);
    expect(error, isNull, reason: '$error');
    for (final card in cards) {
      expect(find.text(card), findsOneWidget, reason: card);
    }
  }, skip: _failsToday.contains('Facility picker at ${size.width.toInt()}: $name'));
}

void main() {
  for (final size in [const Size(390, 844), const Size(1200, 800)]) {
    _picker('two facilities', <Map<String, dynamic>>[
      {'facilityId': 'f1', 'facilityName': 'Kilimo Agrovet', 'facilityType': 'Agrovet', 'facilityTypeDetail': null},
      {'facilityId': 'f2', 'facilityName': 'Mifugo Clinic', 'facilityType': 'Vet Clinic', 'facilityTypeDetail': null},
    ], size, cards: ['Kilimo Agrovet', 'Mifugo Clinic']);
    _picker('odd names, types and details', <Map<String, dynamic>>[
      <String, dynamic>{'facilityId': 'f1', 'facilityName': 12, 'facilityType': {'a': 1}, 'facilityTypeDetail': {'b': 2}},
      <String, dynamic>{'facilityId': 'f2', 'facilityName': null, 'facilityType': null, 'facilityTypeDetail': 5},
    ], size, cards: ['12']);
    _picker('web-shaped items (stored keys, Map<dynamic, dynamic>), one without an id', [
      _item('f1', 'Kilimo Agrovet'),
      _item(null, 'No id'),
      _item('f2', 'Mifugo Clinic'),
    ], size, cards: ['Kilimo Agrovet', 'Mifugo Clinic']);
  }
}
